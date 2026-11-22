"""Klasifikasi intent >= 4 kelas + logika routing (PRD FR-005, item #2).

Kelas: tanya_materi, pembahasan_soal, info_kuota_pembayaran,
jadwal_pengumuman, out_of_context.

Model utama: TF-IDF (word 1-2 gram) + Logistic Regression (class_weight
balanced) yang dilatih oleh `scripts/train_intent.py`. Artefak menyimpan nama
model, daftar kelas, dan metrik evaluasi sehingga prediksi dapat diaudit.
"""

from __future__ import annotations

import math
from dataclasses import dataclass, field
from functools import lru_cache
from pathlib import Path

from .config import MODEL_DIR, settings
from .schemas import Intent

MODEL_PATH = MODEL_DIR / "intent_model.joblib"

# Routing per intent -> modul/handler tujuan (kontrak dengan backend Java)
ROUTES: dict[Intent, str] = {
    Intent.tanya_materi: "rag_tutor",              # RAG + Gemini (FR-005 #3)
    Intent.pembahasan_soal: "quiz_explainer",      # pembahasan soal salah (FR-005 #1)
    Intent.info_kuota_pembayaran: "backend_kuota", # Java: QuotaService / invoice
    Intent.jadwal_pengumuman: "backend_pengumuman",# Java: InformationBoardDAO
    Intent.out_of_context: "guardrail_refusal",    # ditolak santun (FR-005 #6)
}

ROUTE_DESCRIPTIONS: dict[str, str] = {
    "rag_tutor": "Menjawab pertanyaan konsep/materi dengan konteks kurikulum (RAG).",
    "quiz_explainer": "Membahas langkah pengerjaan butir soal yang dijawab salah.",
    "backend_kuota": "Diteruskan ke data kuota/pembayaran milik backend Java.",
    "backend_pengumuman": "Diteruskan ke papan pengumuman & jadwal backend Java.",
    "guardrail_refusal": "Ditolak guardrail dan diarahkan kembali ke materi belajar.",
}


@dataclass
class IntentPrediction:
    intent: Intent
    confidence: float
    routed_to: str
    probabilities: dict[str, float] = field(default_factory=dict)
    model: str = "unknown"

    @property
    def is_confident(self) -> bool:
        return self.confidence >= settings.intent_min_confidence


def _softmax(scores: list[float]) -> list[float]:
    if not scores:
        return []
    peak = max(scores)
    exps = [math.exp(s - peak) for s in scores]
    total = sum(exps)
    return [e / total for e in exps]


# --------------------------------------------------------------------------- #
# Fallback rule-based: dipakai bila artefak model belum dilatih.
# --------------------------------------------------------------------------- #
_HEURISTIC_KEYWORDS: dict[Intent, tuple[str, ...]] = {
    Intent.info_kuota_pembayaran: (
        "kuota", "poin", "saldo", "top up", "topup", "bayar", "pembayaran",
        "invoice", "tagihan", "qris", "virtual account", "transaksi", "refund",
    ),
    Intent.jadwal_pengumuman: (
        "jadwal", "kapan", "jam berapa", "pengumuman", "gmeet", "meet",
        "tanggal", "besok", "minggu depan", "remedial", "try out", "ujian",
    ),
    Intent.pembahasan_soal: (
        "nomor", "soal", "kunci", "jawaban", "salah", "pembahasan", "opsi",
        "langkah", "koreksi", "nilai",
    ),
    Intent.tanya_materi: (
        "apa itu", "jelaskan", "materi", "pengertian", "cara menghitung",
        "rumus", "belajar", "paham", "teori", "contoh",
    ),
}


def _heuristic_predict(text: str) -> IntentPrediction:
    normalized = text.lower()
    scores: dict[Intent, float] = {}
    for intent, keywords in _HEURISTIC_KEYWORDS.items():
        scores[intent] = float(sum(1 for kw in keywords if kw in normalized))
    scores[Intent.out_of_context] = 0.4  # prior kecil agar tidak menang mudah

    best = max(scores, key=scores.get)
    total = sum(scores.values()) or 1.0
    confidence = min(0.95, 0.35 + 0.5 * (scores[best] / total)) if scores[best] else 0.3
    if scores[best] == 0:
        best, confidence = Intent.out_of_context, 0.4
    return IntentPrediction(
        intent=best,
        confidence=round(confidence, 4),
        routed_to=ROUTES[best],
        probabilities={k.value: round(v / total, 4) for k, v in scores.items()},
        model="heuristic-fallback",
    )


# --------------------------------------------------------------------------- #
# Model terlatih
# --------------------------------------------------------------------------- #
class IntentClassifier:
    def __init__(self, model_path: Path = MODEL_PATH) -> None:
        self.model_path = model_path
        self._bundle: dict | None = None

    @property
    def loaded(self) -> bool:
        return self._bundle is not None

    @property
    def model_name(self) -> str:
        if not self._bundle:
            return "heuristic-fallback"
        return str(self._bundle.get("model_name", "unknown"))

    @property
    def metrics(self) -> dict:
        if not self._bundle:
            return {}
        return dict(self._bundle.get("metrics", {}))

    def load(self) -> bool:
        if not self.model_path.exists():
            self._bundle = None
            return False
        import joblib

        self._bundle = joblib.load(self.model_path)
        return True

    def ensure_loaded(self) -> None:
        if self._bundle is None:
            self.load()

    def predict(self, text: str) -> IntentPrediction:
        self.ensure_loaded()
        if not self._bundle:
            return _heuristic_predict(text)

        pipeline = self._bundle["pipeline"]
        classes: list[str] = list(self._bundle["classes"])

        if hasattr(pipeline, "predict_proba"):
            proba_row = pipeline.predict_proba([text])[0]
            proba = {cls: float(p) for cls, p in zip(classes, proba_row)}
        else:  # LinearSVC / model tanpa predict_proba
            scores = pipeline.decision_function([text])
            if hasattr(scores[0], "__len__"):
                probs = _softmax(list(scores[0]))
            else:
                probs = _softmax([float(scores[0])])
            proba = {cls: p for cls, p in zip(classes, probs)}

        best_label = max(proba, key=proba.get)
        intent = Intent(best_label)
        return IntentPrediction(
            intent=intent,
            confidence=round(proba[best_label], 4),
            routed_to=ROUTES[intent],
            probabilities={k: round(v, 4) for k, v in proba.items()},
            model=self.model_name,
        )


@lru_cache(maxsize=1)
def get_classifier() -> IntentClassifier:
    classifier = IntentClassifier()
    classifier.load()
    return classifier


def classify(text: str) -> IntentPrediction:
    return get_classifier().predict(text)
