"""Guardrails penolakan out-of-context (PRD FR-005 business rule & item #6).

Dua lapis:
  1. Lapis leksikal/rule-based (file ini) — menangkap topik yang jelas di luar
     konteks belajar bimbel dan upaya prompt-injection, sebelum model ML jalan.
  2. Lapis model (app.intent) — klasifikasi intent; hasil `out_of_context` atau
     confidence rendah juga ditolak di sini.

Seluruh penolakan memakai kalimat santun dan mengarahkan siswa kembali ke
materi pelajaran (PRD: "AI wajib menolak pertanyaan di luar konteks belajar
bimbingan belajar secara santun").
"""

from __future__ import annotations

import re
import unicodedata
from dataclasses import dataclass, field

# --------------------------------------------------------------------------- #
# Leksikon topik di luar konteks bimbingan belajar
# --------------------------------------------------------------------------- #
OUT_OF_CONTEXT_LEXICON: dict[str, tuple[str, ...]] = {
    "politik_pemerintahan": (
        "presiden", "capres", "pilpres", "partai politik", "politik", "dpr",
        "menteri", "pemilu", "gubernur", "kampanye politik",
    ),
    "kuliner_resep": (
        "resep", "cara masak", "cara membuat kue", "nasi goreng", "ayam geprek",
        "bumbu", "sambal", "brownies", "martabak", "es teh", "katering",
    ),
    "hiburan_gosip": (
        "gosip", "artis", "selebriti", "pacar artis", "drakor", "film horor",
        "konser musik", "lirik lagu", "sinetron", "youtuber", "idol korea",
        "juara liga", "piala dunia", "liga champion", "pemain bola",
    ),
    "pemrograman_kode": (
        "python", "javascript", "buatkan kode", "coding", "script php", "html",
        "program komputer", "aplikasi android", "buatkan fungsi", "kode program",
        "machine learning", "database query",
    ),
    "finansial_judi": (
        "saham", "crypto", "cryptocurrency", "bitcoin", "taruhan", "judi",
        "menang taruhan", "slot online", "investasi emas", "cepat kaya",
        "trading forex", "metaverse",
    ),
    "kesehatan_gaya_hidup": (
        "diet", "menurunkan berat badan", "obat sakit", "klinik kecantikan",
        "skincare", "bulking", "gym",
    ),
    "pengetahuan_umum_luar_materi": (
        "ibukota jepang", "penemu bola lampu", "wisata di bali", "harga iphone",
        "harga tiket", "motogp", "sejarah dunia perang", "cuaca besok",
        "zodiak", "ramalan",
    ),
    "aktivitas_berbahaya": (
        "hack", "meretas", "membuat bom", "senjata", "narkoba", "miras",
        "mencuri data", "ddos", "malware",
    ),
}

# Pola prompt-injection (percobaan mengubah aturan sistem)
PROMPT_INJECTION_PATTERNS: tuple[str, ...] = (
    r"abaikan (semua )?(instruksi|aturan|perintah)",
    r"lupakan (semua )?(instruksi|aturan)",
    r"ignore (all )?(previous|prior) (instructions|prompts)",
    r"you are now",
    r"kamu sekarang adalah",
    r"tampilkan (system )?prompt",
    r"beri tahu (system )?prompt",
    r"bocorkan (system )?prompt",
    r"mode (jailbreak|developer|tanpa batas)",
    r"act as (an?|the) ",
)

REFUSAL_TEMPLATE = (
    "Maaf ya, Kakak Tutor Mentari cuma bisa bantu soal pelajaran bimbel "
    "({contoh_materi}). Pertanyaan tentang {topik} belum bisa Kakak jawab. "
    "Yuk kita lanjut belajar — kamu mau tanya materi apa hari ini?"
)

REFUSAL_LOW_CONFIDENCE = (
    "Hmm, Kakak belum yakin pertanyaan kamu masih seputar materi belajar. "
    "Coba tulis lebih spesifik ya, misalnya \"jelaskan cara menyederhanakan pecahan\" "
    "atau \"kenapa jawaban soal nomor 3 salah\"."
)

REFUSAL_PROMPT_INJECTION = (
    "Kak, Kakak Tutor Mentari hanya membantu materi pelajaran Bimbel Mentari dan "
    "nggak bisa mengubah aturan sistem. Ada materi atau soal yang mau dibahas?"
)

MATERI_CONTOH = "Matematika, IPA, Bahasa Indonesia SD 1-6 dan SMP 7-9"


@dataclass
class GuardrailDecision:
    blocked: bool
    reason: str | None = None
    category: str | None = None
    reply: str | None = None
    matched_terms: list[str] = field(default_factory=list)


def _normalize(text: str) -> str:
    text = unicodedata.normalize("NFKD", text).lower()
    text = re.sub(r"[^a-z0-9\s/]", " ", text)
    return re.sub(r"\s+", " ", text).strip()


def detect_prompt_injection(text: str) -> str | None:
    """Kembalikan pola yang cocok bila terdeteksi prompt-injection."""
    normalized = _normalize(text)
    for pattern in PROMPT_INJECTION_PATTERNS:
        if re.search(pattern, normalized):
            return pattern
    return None


def detect_out_of_context_lexicon(text: str) -> tuple[str, list[str]] | None:
    """Deteksi topik di luar konteks berdasarkan leksikon kata kunci."""
    normalized = _normalize(text)
    for category, keywords in OUT_OF_CONTEXT_LEXICON.items():
        matched = [kw for kw in keywords if kw in normalized]
        if matched:
            return category, matched
    return None


def humanize_category(category: str | None) -> str:
    if not category:
        return "topik itu"
    return category.replace("_", " ")


def check(text: str) -> GuardrailDecision:
    """Lapis 1: filter leksikal + prompt-injection.

    Lapis model (intent) dijalankan terpisah oleh app.intent / app.router.
    """
    if not text or not text.strip():
        return GuardrailDecision(
            blocked=True,
            reason="empty_message",
            category="input_tidak_valid",
            reply="Kak, pesannya masih kosong. Coba tulis pertanyaan belajarnya ya.",
        )

    injection = detect_prompt_injection(text)
    if injection:
        return GuardrailDecision(
            blocked=True,
            reason="prompt_injection",
            category="prompt_injection",
            reply=REFUSAL_PROMPT_INJECTION,
            matched_terms=[injection],
        )

    hit = detect_out_of_context_lexicon(text)
    if hit:
        category, matched = hit
        return GuardrailDecision(
            blocked=True,
            reason="out_of_context_lexicon",
            category=category,
            reply=REFUSAL_TEMPLATE.format(
                contoh_materi=MATERI_CONTOH, topik=humanize_category(category)
            ),
            matched_terms=matched,
        )

    return GuardrailDecision(blocked=False)


def refusal_for_low_confidence() -> str:
    return REFUSAL_LOW_CONFIDENCE
