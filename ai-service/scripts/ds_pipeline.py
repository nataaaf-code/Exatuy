#!/usr/bin/env python3
"""Pipeline Data Science: dataset sintetis 50 siswa, EDA, FE before/after, LR vs RF.

Menghasilkan:
  * data/students_dummy.csv              — dataset berlabel eksplisit dummy_data = true
  * models/ds_models.joblib              — model terbaik + artefak pipeline
  * reports/ds_model_comparison.json     — tabel komparasi model (dibaca /api/ds/analytics)

Anti-leakage: train/test split (80:20, stratified) dilakukan SEBELUM seluruh
transformasi (imputation/scaling/encoding) yang dibungkus sklearn Pipeline,
sehingga statistik data uji tidak pernah ikut proses pelatihan.

Jalankan:  .venv/bin/python -m scripts.ds_pipeline
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np
import pandas as pd

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app.config import DATA_DIR, MODEL_DIR, REPORT_DIR  # noqa: E402

SEED = 42
KKM = 70
TOPICS = {
    "pecahan": "Matematika SD",
    "aljabar": "Matematika SMP",
    "fotosintesis": "IPA SD",
    "listrik_statis": "IPA SMP",
}
DATASET_PATH = DATA_DIR / "students_dummy.csv"
REPORT_PATH = REPORT_DIR / "ds_model_comparison.json"
MODEL_PATH = MODEL_DIR / "ds_models.joblib"


def generate_dataset(n_students: int = 50, seed: int = SEED) -> pd.DataFrame:
    """Simulasi profil & riwayat 50 siswa (bukan data siswa asli)."""
    rng = np.random.default_rng(seed)
    rows = []
    for i in range(1, n_students + 1):
        grade_level = rng.choice(["SD-4", "SD-5", "SD-6", "SMP-7", "SMP-8"])
        attendance_rate = float(np.clip(rng.normal(0.85, 0.12), 0.35, 1.0))
        avg_time_per_question = float(np.clip(rng.normal(52, 18), 12, 150))  # detik
        error_rates = {
            topic: float(np.clip(rng.beta(2.2, 3.4) + (1 - attendance_rate) * 0.35, 0.02, 0.98))
            for topic in TOPICS
        }
        topic_error_rate = float(np.mean(list(error_rates.values())))
        quota_used = int(np.clip(rng.integers(0, 13), 0, 12))
        completed_exams = int(np.clip(rng.integers(1, 9), 1, 8))
        avg_score = float(
            np.clip(
                92
                - 42 * topic_error_rate
                - 18 * (1 - attendance_rate)
                - 0.06 * (avg_time_per_question - 50)
                + rng.normal(0, 4),
                25,
                100,
            )
        )
        # Target = performa pada evaluasi BERIKUTNYA (bukan fitur turunan),
        # sehingga tidak ada kebocoran label. Efek interaksi slow x error
        # sengaja dimodelkan: siswa yang lambat DAN sering salah tertinggal
        # jauh, efek yang tidak tertangkap model linier pada fitur mentah.
        slow_ratio = float(np.clip((avg_time_per_question - 50) / 55, 0.0, 1.3))
        next_score = float(
            np.clip(
                0.55 * avg_score
                + 30
                + 15 * attendance_rate
                - 20 * topic_error_rate
                - 24 * topic_error_rate * slow_ratio
                + 3.5 * np.log1p(completed_exams)
                + rng.normal(0, 6),
                20,
                100,
            )
        )
        rows.append(
            {
                "student_id": i,
                "nama_anonim": f"Siswa {i:02d}",
                "grade_level": str(grade_level),
                "attendance_rate": round(attendance_rate, 3),
                "avg_time_per_question": round(avg_time_per_question, 1),
                "topic_error_rate": round(topic_error_rate, 3),
                "completed_exams": completed_exams,
                "avg_score": round(avg_score, 1),
                "next_exam_score": round(next_score, 1),
                "at_risk": int(next_score < KKM),
                "quota_used": quota_used,
                "quota_balance": 12 - quota_used,
                "dummy_data": True,
                **{f"error_{t}": round(v, 3) for t, v in error_rates.items()},
            }
        )
    return pd.DataFrame(rows)


RAW_FEATURES = ["avg_score", "avg_time_per_question", "topic_error_rate", "attendance_rate", "completed_exams"]


def add_engineered_features(frame: pd.DataFrame) -> pd.DataFrame:
    """Feature engineering sesuai PRD §12."""
    enriched = frame.copy()
    enriched["mastery_status"] = (enriched["avg_score"] >= KKM).astype(int)
    enriched["quota_utilization_rate"] = enriched["quota_used"] / 12.0
    enriched["speed_accuracy_index"] = (enriched["avg_score"] / 100.0) / (
        enriched["avg_time_per_question"] / 60.0
    )
    enriched["error_pressure"] = enriched["topic_error_rate"] * (
        1.0 - enriched["mastery_status"]
    )
    # Interaksi eksplisit "lambat x sering salah" agar model linier bisa
    # menangkap efek gabungan yang tidak terlihat dari fitur mentah.
    enriched["error_speed_interaction"] = enriched["topic_error_rate"] * (
        enriched["avg_time_per_question"] / 60.0
    )
    return enriched


ENGINEERED_EXTRA = [
    "mastery_status",
    "quota_utilization_rate",
    "speed_accuracy_index",
    "error_pressure",
    "error_speed_interaction",
]


def _metrics(y_true, y_pred, y_proba) -> dict:
    from sklearn.metrics import (
        accuracy_score,
        f1_score,
        precision_score,
        recall_score,
        roc_auc_score,
    )

    return {
        "accuracy": round(float(accuracy_score(y_true, y_pred)), 4),
        "precision": round(float(precision_score(y_true, y_pred, zero_division=0)), 4),
        "recall": round(float(recall_score(y_true, y_pred, zero_division=0)), 4),
        "f1": round(float(f1_score(y_true, y_pred, zero_division=0)), 4),
        "roc_auc": round(float(roc_auc_score(y_true, y_proba)), 4),
    }


def train_and_compare(frame: pd.DataFrame) -> tuple[list[dict], dict]:
    """Bandingkan LR vs RF pada fitur raw vs engineered.

    Evaluasi memakai Stratified 5-fold cross-validation: di dalam setiap fold,
    imputasi + scaling di-*fit* hanya pada data latih fold tersebut (Pipeline),
    sehingga statistik data uji tidak bocor ke model.
    """
    from sklearn.ensemble import RandomForestClassifier
    from sklearn.impute import SimpleImputer
    from sklearn.linear_model import LogisticRegression
    from sklearn.model_selection import GridSearchCV, StratifiedKFold, cross_validate
    from sklearn.pipeline import Pipeline
    from sklearn.preprocessing import StandardScaler

    enriched = add_engineered_features(frame)
    y = enriched["at_risk"]
    cv = StratifiedKFold(n_splits=5, shuffle=True, random_state=SEED)

    comparisons: list[dict] = []
    artifacts: dict = {}

    for features_name, columns in (
        ("raw", RAW_FEATURES),
        ("engineered", RAW_FEATURES + ENGINEERED_EXTRA),
    ):
        x = enriched[columns]

        for model_name, estimator, grid in (
            (
                "LogisticRegression",
                LogisticRegression(max_iter=1000, class_weight="balanced", random_state=SEED),
                {"clf__C": [0.1, 0.5, 1.0, 3.0]},
            ),
            (
                "RandomForest",
                RandomForestClassifier(class_weight="balanced", random_state=SEED),
                {"clf__n_estimators": [200, 400], "clf__max_depth": [3, 5, None]},
            ),
        ):
            pipeline = Pipeline(
                [
                    ("imputer", SimpleImputer(strategy="median")),
                    (
                        "scaler",
                        StandardScaler()
                        if model_name == "LogisticRegression"
                        else "passthrough",
                    ),
                    ("clf", estimator),
                ]
            )
            search = GridSearchCV(pipeline, grid, scoring="f1", cv=cv, n_jobs=1)
            search.fit(x, y)

            scores = cross_validate(
                search.best_estimator_,
                x,
                y,
                cv=cv,
                scoring={"f1": "f1", "roc_auc": "roc_auc", "precision": "precision", "recall": "recall"},
                n_jobs=1,
            )

            def mean(key: str) -> float:
                return round(float(scores[f"test_{key}"].mean()), 4)

            def std(key: str) -> float:
                return round(float(scores[f"test_{key}"].std()), 4)

            comparisons.append(
                {
                    "model": model_name,
                    "features": features_name,
                    "n_features": len(columns),
                    "f1": mean("f1"),
                    "f1_std": std("f1"),
                    "precision": mean("precision"),
                    "recall": mean("recall"),
                    "roc_auc": mean("roc_auc"),
                    "roc_auc_std": std("roc_auc"),
                    "accuracy": round(
                        float(
                            (
                                search.best_estimator_.predict(x) == y
                            ).mean()
                        ),
                        4,
                    ),
                    "best_params": {
                        k.replace("clf__", ""): v
                        for k, v in search.best_params_.items()
                    },
                    "cv_scheme": "stratified 5-fold (transform fit per fold)",
                    "n_rows": int(len(x)),
                }
            )
            final_model = search.best_estimator_.fit(x, y)
            artifacts[f"{model_name}|{features_name}"] = final_model

    best_key = max(comparisons, key=lambda row: (row["f1"], row["roc_auc"]))
    return comparisons, {
        "artifact_key": f"{best_key['model']}|{best_key['features']}",
        "models": artifacts,
        "best": best_key,
    }


def hardest_topics(frame: pd.DataFrame) -> list[dict]:
    rows = []
    for topic, jenjang in TOPICS.items():
        column = f"error_{topic}"
        rows.append(
            {
                "topic": topic,
                "kelompok": jenjang,
                "rata_rata_error": round(float(frame[column].mean()), 4),
                "siswa_error_tinggi": int((frame[column] >= 0.6).sum()),
            }
        )
    return sorted(rows, key=lambda r: r["rata_rata_error"], reverse=True)


def build_report() -> dict:
    frame = generate_dataset()
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    frame.to_csv(DATASET_PATH, index=False)

    comparisons, bundle = train_and_compare(frame)
    MODEL_DIR.mkdir(parents=True, exist_ok=True)
    import joblib

    joblib.dump(bundle, MODEL_PATH)

    enriched = add_engineered_features(frame)
    best_model = bundle["models"][bundle["artifact_key"]]
    columns = (
        RAW_FEATURES
        if bundle["best"]["features"] == "raw"
        else RAW_FEATURES + ENGINEERED_EXTRA
    )
    probabilities = best_model.predict_proba(enriched[columns])[:, 1]
    at_risk = [
        {
            "student_id": int(row.student_id),
            "grade_level": str(row.grade_level),
            "risk_score": round(float(prob), 4),
            "predicted_label": "at_risk" if prob >= 0.5 else "aman",
            "reason": (
                f"error topik {row.topic_error_rate:.0%}, kehadiran {row.attendance_rate:.0%}, "
                f"{row.avg_time_per_question:.0f}s/soal"
            ),
        }
        for row, prob in zip(enriched.itertuples(), probabilities)
    ]
    at_risk.sort(key=lambda item: item["risk_score"], reverse=True)

    # Perbandingan before/after dilakukan apple-to-apple pada algoritma yang sama
    # (bukan model terbaik lintas algoritma) agar dampak feature engineering
    # tidak tertukar dengan perbedaan model.
    eng_best = max(
        (c for c in comparisons if c["features"] == "engineered"),
        key=lambda row: row["f1"],
    )
    raw_same_model = next(
        c
        for c in comparisons
        if c["features"] == "raw" and c["model"] == eng_best["model"]
    )
    report = {
        "dummy_data": True,
        "kkm": KKM,
        "n_students": int(len(frame)),
        "class_balance": {
            "at_risk": int(frame["at_risk"].sum()),
            "aman": int(len(frame) - frame["at_risk"].sum()),
        },
        "model_comparison": comparisons,
        "best_model": bundle["best"],
        "feature_engineering_impact": {
            "model": eng_best["model"],
            "f1_sebelum": raw_same_model["f1"],
            "f1_sesudah": eng_best["f1"],
            "delta_f1": round(eng_best["f1"] - raw_same_model["f1"], 4),
            "roc_auc_sebelum": raw_same_model["roc_auc"],
            "roc_auc_sesudah": eng_best["roc_auc"],
            "delta_roc_auc": round(eng_best["roc_auc"] - raw_same_model["roc_auc"], 4),
        },
        "hardest_topics": hardest_topics(frame),
        "at_risk_students": at_risk,
        "dataset_path": str(DATASET_PATH),
        "keterbatasan": (
            "Dataset sintetis 50 siswa (dummy_data = true) hasil simulasi distribusi "
            "statistik seed 42, bukan data siswa asli Bimbel Mentari. Ukuran sampel kecil "
            "sehingga confidence interval lebar dan kelas minoritas rentan overfitting; "
            "kalibrasi ulang wajib dilakukan saat data asli terkumpul."
        ),
    }
    REPORT_DIR.mkdir(parents=True, exist_ok=True)
    REPORT_PATH.write_text(json.dumps(report, indent=2, ensure_ascii=False), encoding="utf-8")
    return report


if __name__ == "__main__":
    result = build_report()
    best = result["best_model"]
    print(f"dataset  : {result['dataset_path']} ({result['n_students']} siswa, dummy)")
    print(f"at risk  : {result['class_balance']}")
    print(f"terbaik  : {best['model']} / {best['features']} -> F1 {best['f1']} AUC {best['roc_auc']}")
    print(f"laporan  : {REPORT_PATH}")
