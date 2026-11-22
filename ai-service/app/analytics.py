"""Analitik & prediksi siswa berisiko remedial (PRD FR-006, item #7).

Modul ini adalah lapisan penyaji: seluruh pelatihan model (LR vs RF, tuning
hyperparameter, evaluasi before/after feature engineering, pencegahan data
leakage) dijalankan oleh `scripts/ds_pipeline.py` dan disimpan sebagai artefak
JSON di `reports/ds_model_comparison.json`. Bila artefak belum ada, modul ini
membangunnya sekali agar endpoint langsung bisa dipakai.
"""

from __future__ import annotations

import json
from functools import lru_cache
from typing import Any

from .config import REPORT_DIR

REPORT_PATH = REPORT_DIR / "ds_model_comparison.json"


def ensure_report() -> dict:
    if REPORT_PATH.exists():
        return json.loads(REPORT_PATH.read_text(encoding="utf-8"))
    from scripts.ds_pipeline import build_report

    return build_report()


@lru_cache(maxsize=1)
def _cached_report() -> dict:
    return ensure_report()


def reload_report() -> dict:
    _cached_report.cache_clear()
    return _cached_report()


def _recommendations(report: dict) -> list[str]:
    recommendations: list[str] = []
    topics = report.get("hardest_topics") or []
    if topics:
        top = topics[0]
        recommendations.append(
            f"Prioritaskan sesi remedial topik {top['topic']} ({top['kelompok']}) "
            f"karena rata-rata error {top['rata_rata_error']:.0%}."
        )
    risky = [s for s in report.get("at_risk_students", []) if s["predicted_label"] == "at_risk"]
    if risky:
        recommendations.append(
            f"Hubungi {len(risky)} siswa berisiko (skor prediksi di bawah KKM {report.get('kkm')}) "
            f"untuk sesi konsultasi individual."
        )
    impact = report.get("feature_engineering_impact") or {}
    if impact:
        recommendations.append(
            "Pertahankan fitur hasil rekayasa (speed_accuracy_index, error_pressure): "
            f"F1 naik {impact.get('delta_f1', 0):+.3f} dibanding fitur mentah."
        )
    recommendations.append(
        "Tinjau ulang batas kuota 12 poin per bulan bagi siswa dengan utilization rate tinggi "
        "agar tidak kehabisan kuota sebelum exam berikutnya."
    )
    return recommendations


def build_payload(grade_level: str | None = None, top_n: int = 5) -> dict[str, Any]:
    report = _cached_report()
    at_risk = report.get("at_risk_students", [])
    if grade_level:
        grade = grade_level.strip().upper()
        at_risk = [s for s in at_risk if str(s["grade_level"]).upper() == grade]

    balance = report.get("class_balance", {})
    total = report.get("n_students", len(at_risk)) or 1
    risky_count = sum(1 for s in at_risk if s["predicted_label"] == "at_risk")

    return {
        "dummy_data": bool(report.get("dummy_data", True)),
        "kpi": {
            "total_siswa": report.get("n_students"),
            "siswa_difilter": len(at_risk),
            "siswa_berisiko": risky_count,
            "persentase_berisiko": round(risky_count / (len(at_risk) or 1) * 100, 2),
            "kkm": report.get("kkm"),
            "class_balance": balance,
            "model_terbaik": report.get("best_model"),
            "dampak_feature_engineering": report.get("feature_engineering_impact"),
            "keterbatasan": report.get("keterbatasan"),
        },
        "hardest_topics": report.get("hardest_topics", []),
        "at_risk_students": at_risk[: max(1, top_n)],
        "model_comparison": report.get("model_comparison", []),
        "recommendations": _recommendations(report),
    }
