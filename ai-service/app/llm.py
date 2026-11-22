"""Pembahasan AI ramah anak + fallback statis (PRD FR-005 #1 & #26).

Alur:
  1. Cek cache in-memory (hindari pemanggilan Gemini berulang untuk soal sama).
  2. Bila `GEMINI_API_KEY` tersedia dan kuota per menit masih ada -> panggil
     Google Gemini API dengan prompt terstruktur (persona "Kakak Tutor Mentari").
  3. Bila key tidak ada, kena rate limit (15 RPM), atau timeout -> sajikan
     penjelasan statis terverifikasi yang disusun dari konteks RAG
     (fallback), sehingga fitur tetap berjalan (business rule FR-005).

Tidak ada API key yang di-hardcode; semuanya dari environment variable.
"""

from __future__ import annotations

import hashlib
import json
import re
import time
from collections import OrderedDict, deque
from dataclasses import dataclass, field

from .config import settings
from .schemas import SourceChunk

GEMINI_ENDPOINT = (
    "https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent"
)

PERSONA = (
    "Kamu adalah \"Kakak Tutor Mentari\", tutor bimbel yang sabar, hangat, dan "
    "ramah anak usia 8-15 tahun. Jawab dalam Bahasa Indonesia sederhana, maksimal "
    "120 kata, tanpa istilah rumit, dan selalu memakai langkah-langkah pendek. "
    "Jangan pernah membahas topik di luar pelajaran bimbel."
)

OUTPUT_CONTRACT = (
    "Balas HANYA dengan JSON valid berbentuk "
    '{"explanation": "<penjelasan singkat ramah anak>", '
    '"steps": ["langkah 1", "langkah 2", "..."]}'
)


@dataclass
class ExplanationResult:
    explanation: str
    steps: list[str] = field(default_factory=list)
    provider: str = "fallback"
    cached: bool = False
    degraded_reason: str | None = None


class RateLimiter:
    """Pembatas sederhana: maksimal N request per 60 detik (Gemini 15 RPM)."""

    def __init__(self, max_per_minute: int) -> None:
        self.max_per_minute = max(1, max_per_minute)
        self._hits: deque[float] = deque()

    def allow(self) -> bool:
        now = time.monotonic()
        while self._hits and now - self._hits[0] > 60:
            self._hits.popleft()
        if len(self._hits) >= self.max_per_minute:
            return False
        self._hits.append(now)
        return True


class ExplanationCache:
    def __init__(self, size: int) -> None:
        self.size = max(0, size)
        self._store: OrderedDict[str, ExplanationResult] = OrderedDict()

    @staticmethod
    def key(payload: dict) -> str:
        blob = json.dumps(payload, sort_keys=True, ensure_ascii=False)
        return hashlib.sha256(blob.encode("utf-8")).hexdigest()

    def get(self, key: str) -> ExplanationResult | None:
        result = self._store.get(key)
        if result is not None:
            self._store.move_to_end(key)
        return result

    def put(self, key: str, value: ExplanationResult) -> None:
        if self.size == 0:
            return
        self._store[key] = value
        self._store.move_to_end(key)
        while len(self._store) > self.size:
            self._store.popitem(last=False)


rate_limiter = RateLimiter(settings.gemini_rate_limit_per_minute)
cache = ExplanationCache(settings.explanation_cache_size)


QA_OUTPUT_CONTRACT = (
    "Balas HANYA dengan JSON valid berbentuk "
    '{"explanation": "<jawaban singkat 2-4 kalimat santai>", "steps": ["poin singkat"]}'
)

QA_INSTRUCTIONS = (
    "Tugas: jawab pertanyaan siswa HANYA berdasarkan konteks kurikulum di atas. "
    "Bila konteks tidak memuat jawabannya, katakan dengan jujur bahwa materi itu "
    "belum ada di catatan Bimbel Mentari dan sarankan bertanya ke pengajar. "
    "Jangan mengarang rumus atau fakta di luar konteks."
)


def build_qa_prompt(request_payload: dict, contexts: list[SourceChunk]) -> str:
    context_block = "\n".join(
        f"- ({c.subject} {c.grade_level}) {c.title}: {c.snippet}" for c in contexts
    ) or "- (tidak ada potongan materi yang cocok)"
    return (
        f"{PERSONA}\n\n"
        f"Konteks kurikulum:\n{context_block}\n\n"
        f"Jenjang: {request_payload.get('grade_level') or 'tidak disebutkan'}\n"
        f"Pertanyaan siswa: {request_payload['question']}\n\n"
        f"{QA_INSTRUCTIONS}\n{QA_OUTPUT_CONTRACT}"
    )


def extractive_answer(
    request_payload: dict, contexts: list[SourceChunk], reason: str | None
) -> ExplanationResult:
    """Jawaban ekstraktif dari materi (fallback statis tanpa LLM)."""
    if not contexts:
        return ExplanationResult(
            explanation=(
                "Maaf, materi untuk pertanyaan itu belum ada di catatan Bimbel "
                "Mentari. Coba tulis lebih spesifik (misal: \"pecahan senilai\") "
                "atau tanyakan langsung ke pengajar ya."
            ),
            steps=[],
            provider="fallback",
            degraded_reason=reason or "no_context",
        )

    top = contexts[0]
    sentences = [
        s.strip()
        for s in re.split(r"(?<=\.)\s+|\n", top.snippet)
        if len(s.strip()) > 30
    ][:3]
    body = " ".join(sentences) or top.snippet[:400]
    steps = [f"Sumber: {c.title} ({c.subject} {c.grade_level})" for c in contexts[:3]]
    return ExplanationResult(
        explanation=body[:800],
        steps=steps,
        provider="fallback",
        degraded_reason=reason or ("gemini_disabled" if not settings.gemini_enabled else None),
    )


async def answer_question(
    request_payload: dict, contexts: list[SourceChunk]
) -> ExplanationResult:
    """Jawab pertanyaan materi memakai RAG (+ Gemini bila tersedia)."""
    key = "qa:" + ExplanationCache.key(
        {
            "question": request_payload.get("question"),
            "grade_level": request_payload.get("grade_level"),
            "subject": request_payload.get("subject"),
            "contexts": [c.doc_id for c in contexts],
        }
    )
    cached = cache.get(key)
    if cached is not None:
        return ExplanationResult(**{**cached.__dict__, "cached": True})

    if not settings.gemini_enabled:
        result = extractive_answer(request_payload, contexts, "gemini_disabled")
        cache.put(key, result)
        return result

    if not rate_limiter.allow():
        return extractive_answer(request_payload, contexts, "rate_limit_15rpm")

    try:
        raw = await _call_gemini(build_qa_prompt(request_payload, contexts))
    except Exception as exc:
        return extractive_answer(request_payload, contexts, f"gemini_error:{type(exc).__name__}")

    parsed = _parse_json_response(raw)
    if parsed is None:
        result = ExplanationResult(explanation=raw[:800], steps=[], provider="gemini")
    else:
        explanation, steps = parsed
        result = ExplanationResult(explanation=explanation, steps=steps, provider="gemini")
    cache.put(key, result)
    return result


def build_prompt(request_payload: dict, contexts: list[SourceChunk]) -> str:
    context_block = "\n".join(
        f"- ({c.subject} {c.grade_level}) {c.title}: {c.snippet}" for c in contexts
    ) or "- (tidak ada konteks kurikulum yang cocok, jelaskan dengan prinsip umum)"

    options = request_payload.get("options") or []
    options_block = "\n".join(f"  {chr(65 + i)}. {opt}" for i, opt in enumerate(options))
    return (
        f"{PERSONA}\n\n"
        f"Konteks kurikulum (gunakan sebagai sumber utama, jangan mengarang):\n"
        f"{context_block}\n\n"
        f"Jenjang: {request_payload.get('grade_level') or 'tidak disebutkan'}\n"
        f"Mata pelajaran: {request_payload.get('subject') or 'tidak disebutkan'}\n"
        f"Soal: {request_payload['question']}\n"
        f"Pilihan jawaban:\n{options_block or '  (soal isian/esai)'}\n"
        f"Jawaban siswa: {request_payload.get('student_answer') or '-'}\n"
        f"Kunci jawaban benar: {request_payload.get('correct_answer') or '-'}\n\n"
        f"Tugas: jelaskan mengapa kunci jawaban benar dan di mana letak kekeliruan "
        f"jawaban siswa, dengan langkah pengerjaan singkat.\n{OUTPUT_CONTRACT}"
    )


def _parse_json_response(text: str) -> tuple[str, list[str]] | None:
    cleaned = text.strip()
    cleaned = re.sub(r"^```(?:json)?|```$", "", cleaned, flags=re.MULTILINE).strip()
    try:
        data = json.loads(cleaned)
    except json.JSONDecodeError:
        match = re.search(r"\{.*\}", cleaned, flags=re.DOTALL)
        if not match:
            return None
        try:
            data = json.loads(match.group(0))
        except json.JSONDecodeError:
            return None
    explanation = str(data.get("explanation", "")).strip()
    steps = [str(s).strip() for s in data.get("steps", []) if str(s).strip()]
    if not explanation:
        return None
    return explanation, steps


def fallback_explanation(
    request_payload: dict,
    contexts: list[SourceChunk],
    reason: str | None = None,
) -> ExplanationResult:
    """Penjelasan statis terverifikasi dari konteks RAG (tanpa Gemini)."""
    correct = request_payload.get("correct_answer")
    student = request_payload.get("student_answer")
    steps: list[str] = []

    if contexts:
        top = contexts[0]
        steps.append(f"Konsep kuncinya: {top.title} ({top.subject} {top.grade_level}).")
        for line in re.split(r"(?<=\.)\s+", top.snippet)[:4]:
            clean = line.strip()
            if len(clean) > 25:
                steps.append(clean)
    else:
        steps.append("Baca soal sekali lagi dan tandai informasi penting yang diberikan.")

    if correct:
        steps.append(f"Jawaban yang benar adalah {correct} — cocokkan dengan langkah di atas.")
    if student and correct and student != correct:
        steps.append(
            f"Jawabanmu ({student}) belum tepat. Cek bagian langkah yang tandanya "
            f"terbalik atau angkanya belum disamakan penyebutnya."
        )

    explanation = (
        "Ini pembahasan versi ringkas dari materi Bimbel Mentari ya: "
        + (contexts[0].snippet.split("\n")[0] if contexts else
           "kita bahas pelan-pelan dari konsep dasarnya.")
    ).strip()

    return ExplanationResult(
        explanation=explanation[:600],
        steps=steps[:6],
        provider="fallback",
        degraded_reason=reason or ("gemini_disabled" if not settings.gemini_enabled else None),
    )


async def _call_gemini(prompt: str) -> str:
    import httpx

    url = GEMINI_ENDPOINT.format(model=settings.gemini_model)
    body = {
        "contents": [{"role": "user", "parts": [{"text": prompt}]}],
        "generationConfig": {"temperature": 0.4, "maxOutputTokens": 512},
    }
    async with httpx.AsyncClient(timeout=settings.gemini_timeout_seconds) as client:
        response = await client.post(url, params={"key": settings.gemini_api_key}, json=body)
        response.raise_for_status()
        data = response.json()
    candidates = data.get("candidates") or []
    if not candidates:
        raise RuntimeError("Gemini tidak mengembalikan kandidat jawaban")
    parts = candidates[0].get("content", {}).get("parts", [])
    return "".join(part.get("text", "") for part in parts).strip()


async def generate_explanation(
    request_payload: dict, contexts: list[SourceChunk]
) -> ExplanationResult:
    key = ExplanationCache.key(
        {
            "question": request_payload.get("question"),
            "options": request_payload.get("options"),
            "student_answer": request_payload.get("student_answer"),
            "correct_answer": request_payload.get("correct_answer"),
            "grade_level": request_payload.get("grade_level"),
        }
    )
    cached = cache.get(key)
    if cached is not None:
        return ExplanationResult(**{**cached.__dict__, "cached": True})

    if not settings.gemini_enabled:
        result = fallback_explanation(request_payload, contexts, "gemini_disabled")
        cache.put(key, result)
        return result

    if not rate_limiter.allow():
        return fallback_explanation(request_payload, contexts, "rate_limit_15rpm")

    try:
        raw = await _call_gemini(build_prompt(request_payload, contexts))
    except Exception as exc:  # timeout, 429, 5xx, dsb.
        return fallback_explanation(request_payload, contexts, f"gemini_error:{type(exc).__name__}")

    parsed = _parse_json_response(raw)
    if parsed is None:
        result = ExplanationResult(
            explanation=raw[:800] or "Maaf, pembahasan belum bisa dibuat.",
            steps=[],
            provider="gemini",
        )
    else:
        explanation, steps = parsed
        result = ExplanationResult(explanation=explanation, steps=steps, provider="gemini")

    cache.put(key, result)
    return result
