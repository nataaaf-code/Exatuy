"""Skema JSON (kontrak API) untuk AI & DS microservice Exatuy.

Kontrak ini dipublikasikan otomatis oleh FastAPI pada `/openapi.json` dan
`/docs`, serta didokumentasikan manual pada README.md (item #31).
"""

from __future__ import annotations

from enum import Enum
from typing import Any, Literal

from pydantic import BaseModel, Field


class Intent(str, Enum):
    """Kelas intent (PRD FR-005: minimal 4 kelas + out_of_context)."""

    tanya_materi = "tanya_materi"
    pembahasan_soal = "pembahasan_soal"
    info_kuota_pembayaran = "info_kuota_pembayaran"
    jadwal_pengumuman = "jadwal_pengumuman"
    out_of_context = "out_of_context"


class Role(str, Enum):
    student = "student"
    teacher = "teacher"


GRADE_LEVELS = ("SD-1", "SD-2", "SD-3", "SD-4", "SD-5", "SD-6", "SMP-7", "SMP-8", "SMP-9")


# --------------------------------------------------------------------------- #
# Chat & routing (#2)
# --------------------------------------------------------------------------- #
class ChatRequest(BaseModel):
    message: str = Field(..., min_length=1, max_length=2000, description="Pesan siswa")
    user_id: int | None = Field(default=None, description="ID siswa (opsional)")
    role: Role = Role.student
    grade_level: str | None = Field(default=None, description="Jenjang, mis. SD-4 / SMP-8")

    model_config = {
        "json_schema_extra": {
            "examples": [
                {"message": "Kak, kenapa 3/4 + 1/2 jadi 5/4?", "grade_level": "SD-4"},
                {"message": "Sisa kuota saya berapa ya?", "user_id": 12},
            ]
        }
    }


class SourceChunk(BaseModel):
    """Potongan konteks kurikulum yang dipakai RAG (dapat ditelusuri)."""

    doc_id: str
    title: str
    grade_level: str
    subject: str
    score: float
    snippet: str


class ChatResponse(BaseModel):
    intent: Intent
    confidence: float = Field(..., ge=0.0, le=1.0)
    routed_to: str = Field(..., description="Handler/modul tujuan routing")
    blocked: bool = Field(default=False, description="True bila guardrail menolak")
    guardrail_reason: str | None = None
    answer: str
    sources: list[SourceChunk] = Field(default_factory=list)
    cached: bool = False
    provider: str = Field(default="fallback", description="gemini | fallback | template")


# --------------------------------------------------------------------------- #
# Quiz explainer (#1 + #3, #26)
# --------------------------------------------------------------------------- #
class ExplainRequest(BaseModel):
    question: str = Field(..., min_length=1, max_length=4000)
    options: list[str] = Field(default_factory=list)
    student_answer: str | None = None
    correct_answer: str | None = None
    subject: str | None = Field(default=None, description="mis. Matematika / IPA")
    grade_level: str | None = Field(default=None, description="mis. SD-4 / SMP-8")
    question_id: int | None = None

    model_config = {
        "json_schema_extra": {
            "examples": [
                {
                    "question": "Hasil dari 3/4 + 1/2 adalah ...",
                    "options": ["5/6", "5/4", "4/6", "1/4"],
                    "student_answer": "5/6",
                    "correct_answer": "5/4",
                    "subject": "Matematika",
                    "grade_level": "SD-4",
                }
            ]
        }
    }


class ExplainResponse(BaseModel):
    explanation: str
    steps: list[str] = Field(default_factory=list)
    sources: list[SourceChunk] = Field(default_factory=list)
    provider: str = Field(default="fallback", description="gemini | fallback")
    cached: bool = False
    degraded_reason: str | None = Field(
        default=None, description="Alasan fallback statis dipakai (rate limit/timeout)"
    )


# --------------------------------------------------------------------------- #
# Sentimen ulasan siswa (#4)
# --------------------------------------------------------------------------- #
class SentimentRequest(BaseModel):
    texts: list[str] = Field(..., min_length=1, max_length=200)
    student_id: int | None = None


class SentimentItem(BaseModel):
    text: str
    label: Literal["positif", "negatif"]
    confidence: float = Field(..., ge=0.0, le=1.0)
    probabilities: dict[str, float] = Field(default_factory=dict)


class SentimentResponse(BaseModel):
    results: list[SentimentItem]
    summary: dict[str, Any]


# --------------------------------------------------------------------------- #
# Webhook messaging (#22)
# --------------------------------------------------------------------------- #
class MessagingWebhookRequest(BaseModel):
    platform: Literal["telegram", "whatsapp"] = "telegram"
    payload: dict[str, Any] = Field(default_factory=dict, description="Payload mentah platform")


class MessagingWebhookResponse(BaseModel):
    ok: bool
    platform: str
    chat_id: str | None = None
    incoming_text: str | None = None
    intent: Intent | None = None
    reply: str | None = None
    delivered: bool = False
    detail: str | None = None


# --------------------------------------------------------------------------- #
# Health (#21) & analytics (#7)
# --------------------------------------------------------------------------- #
class HealthResponse(BaseModel):
    status: Literal["ok", "degraded"]
    service: str
    version: str
    components: dict[str, Any]


class AtRiskStudent(BaseModel):
    student_id: int
    grade_level: str
    risk_score: float
    predicted_label: Literal["at_risk", "aman"]
    reason: str


class AnalyticsResponse(BaseModel):
    dummy_data: bool = Field(
        default=True, description="Seluruh dataset sintetis berlabel dummy_data = true"
    )
    kpi: dict[str, Any]
    hardest_topics: list[dict[str, Any]]
    at_risk_students: list[AtRiskStudent]
    model_comparison: list[dict[str, Any]]
    recommendations: list[str]
