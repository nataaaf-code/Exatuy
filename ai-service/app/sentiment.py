"""Analisis sentimen ulasan siswa: positif / negatif (PRD FR-005 #4).

Model: TF-IDF word+char n-gram + Logistic Regression dengan
`class_weight='balanced'` untuk menangani class imbalance (dataset umpan balik
asli cenderung didominasi ulasan positif). Artefak disimpan di
`models/sentiment_model.joblib` agar prediksi konsisten antar-proses.
"""

from __future__ import annotations

from functools import lru_cache
from pathlib import Path

from .config import DATA_DIR, MODEL_DIR

TRAIN_PATH = DATA_DIR / "feedback_train.csv"
MODEL_PATH = MODEL_DIR / "sentiment_model.joblib"
LABELS = ("negatif", "positif")


def train_sentiment_model(train_path: Path = TRAIN_PATH) -> dict:
    """Latih model sentimen dan simpan artefak + metrik evaluasi."""
    import joblib
    import pandas as pd
    from sklearn.feature_extraction.text import TfidfVectorizer
    from sklearn.linear_model import LogisticRegression
    from sklearn.metrics import classification_report, f1_score
    from sklearn.model_selection import cross_val_predict, train_test_split
    from sklearn.pipeline import Pipeline

    frame = pd.read_csv(train_path)
    frame = frame.dropna(subset=["text", "label"])
    x_train, x_test, y_train, y_test = train_test_split(
        frame["text"], frame["label"], test_size=0.25, random_state=42, stratify=frame["label"]
    )

    pipeline = Pipeline(
        [
            (
                "tfidf",
                TfidfVectorizer(
                    analyzer="word",
                    ngram_range=(1, 2),
                    sublinear_tf=True,
                    min_df=1,
                ),
            ),
            ("clf", LogisticRegression(max_iter=1000, class_weight="balanced", C=2.0)),
        ]
    )
    pipeline.fit(x_train, y_train)
    predictions = pipeline.predict(x_test)
    metrics = {
        "model": "tfidf+logistic-regression",
        "accuracy": round(float((predictions == y_test).mean()), 4),
        "macro_f1": round(float(f1_score(y_test, predictions, average="macro")), 4),
        "report": classification_report(y_test, predictions, output_dict=True, zero_division=0),
        "train_rows": int(len(x_train)),
        "test_rows": int(len(x_test)),
        "class_balance": frame["label"].value_counts().to_dict(),
        "dummy_data": bool(frame.get("dummy_data", pd.Series([True])).all()),
    }

    MODEL_DIR.mkdir(parents=True, exist_ok=True)
    joblib.dump({"pipeline": pipeline, "metrics": metrics, "classes": list(LABELS)}, MODEL_PATH)
    return metrics


class SentimentPredictor:
    def __init__(self, model_path: Path = MODEL_PATH) -> None:
        self.model_path = model_path
        self._bundle: dict | None = None

    def ensure_loaded(self) -> None:
        if self._bundle is not None:
            return
        if not self.model_path.exists():
            train_sentiment_model()
        import joblib

        self._bundle = joblib.load(self.model_path)

    @property
    def metrics(self) -> dict:
        self.ensure_loaded()
        return dict((self._bundle or {}).get("metrics", {}))

    def predict_one(self, text: str) -> dict:
        self.ensure_loaded()
        assert self._bundle is not None
        pipeline = self._bundle["pipeline"]
        probabilities = pipeline.predict_proba([text])[0]
        classes = list(pipeline.classes_)
        proba = {cls: round(float(p), 4) for cls, p in zip(classes, probabilities)}
        label = max(proba, key=lambda k: proba[k])
        return {"text": text, "label": label, "confidence": proba[label], "probabilities": proba}

    def predict_many(self, texts: list[str]) -> dict:
        results = [self.predict_one(t) for t in texts]
        total = len(results) or 1
        positives = sum(1 for r in results if r["label"] == "positif")
        summary = {
            "total": len(results),
            "positif": positives,
            "negatif": len(results) - positives,
            "persentase_positif": round(positives / total * 100, 2),
            "persentase_negatif": round((len(results) - positives) / total * 100, 2),
            "rata_rata_confidence": round(
                sum(r["confidence"] for r in results) / total, 4
            ),
            "model_macro_f1": self.metrics.get("macro_f1"),
        }
        return {"results": results, "summary": summary}


@lru_cache(maxsize=1)
def get_predictor() -> SentimentPredictor:
    predictor = SentimentPredictor()
    predictor.ensure_loaded()
    return predictor
