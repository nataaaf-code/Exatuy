#!/usr/bin/env python3
"""Latih & bandingkan minimal 2 model klasifikasi intent (PRD FR-005, item #2).

Perbandingan mengikuti metrik Macro F1 (daya klasifikasi seimbang antar kelas):

  1. TF-IDF (word 1-2 gram) + Logistic Regression  [class_weight='balanced']
  2. TF-IDF (word 1-2 gram) + Linear SVC           [class_weight='balanced']
  3. TF-IDF (char 3-5 gram)  + Complement Naive Bayes

Penanganan class imbalance: `class_weight='balanced'` untuk model linear dan
`ComplementNB` yang memang dirancang untuk distribusi kelas tidak seimbang.
Hyperparameter tuning: `GridSearchCV` (scoring macro F1, 3-fold) hanya pada
data latih; evaluasi akhir memakai `data/intents_eval.csv` yang tidak pernah
dilihat model.

Jalankan:  .venv/bin/python -m scripts.train_intent
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

import pandas as pd

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app.config import DATA_DIR, MODEL_DIR, REPORT_DIR  # noqa: E402

TRAIN_PATH = DATA_DIR / "intents_train.csv"
EVAL_PATH = DATA_DIR / "intents_eval.csv"
MODEL_PATH = MODEL_DIR / "intent_model.joblib"
REPORT_PATH = REPORT_DIR / "intent_model_comparison.json"


def _candidates():
    from sklearn.feature_extraction.text import TfidfVectorizer
    from sklearn.linear_model import LogisticRegression
    from sklearn.naive_bayes import ComplementNB
    from sklearn.pipeline import Pipeline
    from sklearn.svm import LinearSVC

    return [
        {
            "name": "tfidf-word + LogisticRegression",
            "pipeline": Pipeline(
                [
                    ("tfidf", TfidfVectorizer(analyzer="word", sublinear_tf=True, min_df=1)),
                    (
                        "clf",
                        LogisticRegression(
                            max_iter=2000, class_weight="balanced", random_state=42
                        ),
                    ),
                ]
            ),
            "grid": {
                "tfidf__ngram_range": [(1, 1), (1, 2)],
                "clf__C": [0.5, 1.0, 3.0, 10.0],
            },
        },
        {
            "name": "tfidf-word + LinearSVC",
            "pipeline": Pipeline(
                [
                    ("tfidf", TfidfVectorizer(analyzer="word", sublinear_tf=True, min_df=1)),
                    ("clf", LinearSVC(class_weight="balanced", random_state=42)),
                ]
            ),
            "grid": {
                "tfidf__ngram_range": [(1, 1), (1, 2)],
                "clf__C": [0.25, 0.5, 1.0, 3.0],
            },
        },
        {
            "name": "tfidf-char + ComplementNB",
            "pipeline": Pipeline(
                [
                    (
                        "tfidf",
                        TfidfVectorizer(
                            analyzer="char_wb", ngram_range=(3, 5), sublinear_tf=True, min_df=1
                        ),
                    ),
                    ("clf", ComplementNB(alpha=0.5)),
                ]
            ),
            "grid": {"clf__alpha": [0.25, 0.5, 1.0, 2.0]},
        },
    ]


def main() -> dict:
    import joblib
    from sklearn.metrics import classification_report, confusion_matrix, f1_score
    from sklearn.model_selection import GridSearchCV

    train = pd.read_csv(TRAIN_PATH)
    evaluation = pd.read_csv(EVAL_PATH)
    for frame, name in ((train, "train"), (evaluation, "eval")):
        missing = {"text", "intent"} - set(frame.columns)
        if missing:
            raise SystemExit(f"{name} CSV kehilangan kolom: {sorted(missing)}")

    results: list[dict] = []
    best_bundle = None
    best_score = -1.0

    for candidate in _candidates():
        search = GridSearchCV(
            candidate["pipeline"],
            candidate["grid"],
            scoring="f1_macro",
            cv=3,
            n_jobs=1,
        )
        search.fit(train["text"], train["intent"])
        pipeline = search.best_estimator_
        predictions = pipeline.predict(evaluation["text"])
        macro_f1 = float(f1_score(evaluation["intent"], predictions, average="macro"))
        weighted_f1 = float(
            f1_score(evaluation["intent"], predictions, average="weighted")
        )
        accuracy = float((predictions == evaluation["intent"]).mean())

        results.append(
            {
                "model": candidate["name"],
                "macro_f1": round(macro_f1, 4),
                "weighted_f1": round(weighted_f1, 4),
                "accuracy": round(accuracy, 4),
                "best_params": {
                    key: (list(value) if isinstance(value, tuple) else value)
                    for key, value in search.best_params_.items()
                },
                "cv_macro_f1": round(float(search.best_score_), 4),
                "per_class": classification_report(
                    evaluation["intent"], predictions, output_dict=True, zero_division=0
                ),
                "confusion_matrix": confusion_matrix(
                    evaluation["intent"], predictions, labels=sorted(train["intent"].unique())
                ).tolist(),
                "labels_order": sorted(train["intent"].unique()),
            }
        )

        if macro_f1 > best_score:
            best_score = macro_f1
            best_bundle = {
                "pipeline": pipeline,
                "model_name": candidate["name"],
                "classes": sorted(train["intent"].unique()),
                "metrics": {
                    "macro_f1": round(macro_f1, 4),
                    "weighted_f1": round(weighted_f1, 4),
                    "accuracy": round(accuracy, 4),
                    "best_params": results[-1]["best_params"],
                    "train_rows": int(len(train)),
                    "eval_rows": int(len(evaluation)),
                    "class_balance_train": train["intent"].value_counts().to_dict(),
                    "dummy_data": bool(train.get("dummy_data", pd.Series([True])).all()),
                },
            }

    MODEL_DIR.mkdir(parents=True, exist_ok=True)
    joblib.dump(best_bundle, MODEL_PATH)

    report = {
        "dummy_data": True,
        "task": "klasifikasi intent percakapan siswa (5 kelas)",
        "n_train": int(len(train)),
        "n_eval": int(len(evaluation)),
        "class_balance": train["intent"].value_counts().to_dict(),
        "model_comparison": [
            {k: v for k, v in row.items() if k not in ("per_class", "confusion_matrix")}
            for row in results
        ],
        "detailed": results,
        "selected_model": best_bundle["model_name"],
        "selection_metric": "macro_f1",
        "notes": (
            "Data latih/eval adalah data sintetis berlabel dummy_data = true yang disusun "
            "manual meniru gaya bicara siswa SD/SMP. Evaluasi memakai file eval terpisah "
            "yang tidak dipakai saat tuning."
        ),
    }
    REPORT_DIR.mkdir(parents=True, exist_ok=True)
    REPORT_PATH.write_text(json.dumps(report, indent=2, ensure_ascii=False), encoding="utf-8")

    print(f"{'model':42s} {'macroF1':>8s} {'acc':>7s}")
    for row in results:
        print(f"{row['model']:42s} {row['macro_f1']:8.4f} {row['accuracy']:7.4f}")
    print(f"\nTerpilih : {best_bundle['model_name']} (macro F1 {best_score:.4f})")
    print(f"Artefak  : {MODEL_PATH}")
    print(f"Laporan  : {REPORT_PATH}")
    return report


if __name__ == "__main__":
    main()
