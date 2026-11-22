"""Konfigurasi terpusat untuk AI & DS microservice Exatuy.

Semua nilai dibaca dari environment variable agar aman di-deploy (Render/Koyeb)
tanpa mengubah kode. Tidak ada API key yang di-hardcode.
"""

from __future__ import annotations

import os
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent
DATA_DIR = BASE_DIR / "data"
MODEL_DIR = BASE_DIR / "models"
REPORT_DIR = BASE_DIR / "reports"
KNOWLEDGE_DIR = DATA_DIR / "knowledge"


def _bool(name: str, default: bool = False) -> bool:
    return os.getenv(name, str(default)).strip().lower() in {"1", "true", "yes", "on"}


class Settings:
    """Runtime settings (dibaca ulang saat proses start)."""

    app_name: str = "Exatuy AI & DS Service"
    version: str = "1.0.0"

    # --- Google Gemini (FR-005: quiz explainer) ---
    gemini_api_key: str = os.getenv("GEMINI_API_KEY", "").strip()
    gemini_model: str = os.getenv("GEMINI_MODEL", "gemini-2.0-flash").strip()
    gemini_timeout_seconds: float = float(os.getenv("GEMINI_TIMEOUT_SECONDS", "12"))
    # Gemini gratis dibatasi ~15 request/menit (PRD FR-005 Error Handling).
    gemini_rate_limit_per_minute: int = int(os.getenv("GEMINI_RATE_LIMIT_PER_MINUTE", "15"))

    # --- RAG / vector store (FR-005 #3) ---
    # tfidf-faiss  -> IndexFlatIP di atas vektor TF-IDF (offline, default)
    # chroma       -> ChromaDB persisten + embedding ONNX (butuh unduh model)
    rag_backend: str = os.getenv("RAG_BACKEND", "tfidf-faiss").strip().lower()
    rag_top_k: int = int(os.getenv("RAG_TOP_K", "4"))
    rag_min_score: float = float(os.getenv("RAG_MIN_SCORE", "0.12"))

    # --- Guardrails (FR-005 #6) ---
    # Ambang confidence minimum untuk menerima hasil klasifikasi intent.
    intent_min_confidence: float = float(os.getenv("INTENT_MIN_CONFIDENCE", "0.35"))

    # --- Webhook messaging (FR-009 / Supporting #4, item #22) ---
    telegram_bot_token: str = os.getenv("TELEGRAM_BOT_TOKEN", "").strip()
    telegram_webhook_secret: str = os.getenv("TELEGRAM_WEBHOOK_SECRET", "").strip()
    whatsapp_token: str = os.getenv("WHATSAPP_TOKEN", "").strip()
    whatsapp_phone_number_id: str = os.getenv("WHATSAPP_PHONE_NUMBER_ID", "").strip()
    whatsapp_verify_token: str = os.getenv("WHATSAPP_VERIFY_TOKEN", "exatuy-verify").strip()

    # --- Cache pembahasan AI (#26 komplementer) ---
    explanation_cache_size: int = int(os.getenv("EXPLANATION_CACHE_SIZE", "256"))

    # --- Database opsional (health-check) ---
    mysql_host: str = os.getenv("MYSQL_HOST", "mysql")
    mysql_port: int = int(os.getenv("MYSQL_PORT", "3306"))
    mysql_user: str = os.getenv("MYSQL_USER", "examora_app")
    mysql_password: str = os.getenv("MYSQL_PASSWORD", "")
    mysql_database: str = os.getenv("MYSQL_DATABASE", "examora_db")
    check_database: bool = _bool("HEALTH_CHECK_DB", False)

    @property
    def gemini_enabled(self) -> bool:
        return bool(self.gemini_api_key)


settings = Settings()
