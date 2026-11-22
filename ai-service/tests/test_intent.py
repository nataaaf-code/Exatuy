"""Uji kualitas & kontrak klasifikasi intent (PRD FR-005 item #2)."""

from __future__ import annotations

import pandas as pd
from sklearn.metrics import classification_report, f1_score

from app.config import DATA_DIR
from app.intent import ROUTES, classify, get_classifier
from app.schemas import Intent

EVAL_PATH = DATA_DIR / "intents_eval.csv"
MIN_MACRO_F1 = 0.85


def test_model_artifact_tersedia_dan_terlatih() -> None:
    classifier = get_classifier()
    assert classifier.loaded is True, (
        "artefak model belum ada — jalankan: python -m scripts.train_intent"
    )
    assert classifier.model_name
    assert classifier.metrics.get("macro_f1", 0) >= MIN_MACRO_F1


def test_lima_kelas_intent_terdaftar_di_routing() -> None:
    assert set(ROUTES) == set(Intent), "setiap kelas intent wajib punya tujuan routing"
    for intent, target in ROUTES.items():
        assert target, f"intent {intent} tidak punya handler"
    assert ROUTES[Intent.out_of_context] == "guardrail_refusal"


def test_macro_f1_pada_data_eval_terpisah() -> None:
    frame = pd.read_csv(EVAL_PATH)
    predictions = [classify(text).intent.value for text in frame["text"]]
    macro_f1 = f1_score(frame["intent"], predictions, average="macro")
    report = classification_report(
        frame["intent"], predictions, output_dict=True, zero_division=0
    )

    assert macro_f1 >= MIN_MACRO_F1, (
        f"macro F1 {macro_f1:.3f} < {MIN_MACRO_F1}\n"
        f"{classification_report(frame['intent'], predictions, zero_division=0)}"
    )
    # Setiap kelas harus benar-benar terprediksi (bukan hanya kelas mayoritas).
    for label in Intent:
        assert report[label.value]["support"] > 0
        assert report[label.value]["f1-score"] >= 0.6, label.value


def test_out_of_context_terdeteksi_oleh_model() -> None:
    frame = pd.read_csv(EVAL_PATH)
    out = frame[frame["intent"] == "out_of_context"]["text"]
    detected = sum(1 for text in out if classify(text).intent == Intent.out_of_context)
    assert detected / len(out) >= 0.8, f"hanya {detected}/{len(out)} out-of-context terdeteksi model"


def test_confidence_untuk_pertanyaan_jelas() -> None:
    prediction = classify("kak tolong jelaskan cara menyederhanakan pecahan")
    assert prediction.intent == Intent.tanya_materi
    assert prediction.confidence >= 0.35
    assert prediction.is_confident is True


def test_prediksi_menyertakan_probabilitas_semua_kelas() -> None:
    prediction = classify("kapan jadwal google meet minggu ini")
    assert set(prediction.probabilities) == {i.value for i in Intent}
    assert abs(sum(prediction.probabilities.values()) - 1.0) < 0.05
