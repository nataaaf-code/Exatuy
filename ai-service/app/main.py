"""Exatuy AI & Data Science microservice (FastAPI).

Endpoint (semua terdokumentasi otomatis di Swagger `/docs`, item #31):

    GET  /health                        health-check ringan (item #21)
    GET  /api/v1/health                 alias health-check sesuai PRD §5.2
    POST /api/ai/chat                   intent >= 4 kelas + routing (item #2)
    POST /api/ai/explain                pembahasan soal ramah anak (FR-005 #1)
    POST /api/ai/sentiment              sentimen ulasan positif/negatif (#4)
    POST /api/ai/webhook/messaging      webhook Telegram / WhatsApp (#22)
    GET  /api/ai/webhook/messaging      verifikasi challenge WhatsApp
    GET  /api/ai/routes                 tabel routing intent (transparansi)
    GET  /api/ds/analytics              analitik & prediksi remedial (#7)
"""

from __future__ import annotations

import socket
from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException, Query, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from . import analytics, messaging
from .config import settings
from .intent import get_classifier
from .llm import generate_explanation
from .rag import get_retriever
from .router import classifier_status, handle_chat, routing_table
from .schemas import (
    AnalyticsResponse,
    ChatRequest,
    ChatResponse,
    ExplainRequest,
    ExplainResponse,
    HealthResponse,
    MessagingWebhookRequest,
    MessagingWebhookResponse,
    Role,
    SentimentRequest,
    SentimentResponse,
)
from .sentiment import get_predictor


def _db_reachable() -> dict:
    try:
        with socket.create_connection(
            (settings.mysql_host, settings.mysql_port), timeout=1.5
        ):
            return {"ok": True, "host": f"{settings.mysql_host}:{settings.mysql_port}"}
    except OSError as exc:
        return {"ok": False, "detail": str(exc)}


def _rag_status() -> dict:
    try:
        retriever = get_retriever()
        return {
            "ok": True,
            "backend": retriever.backend,
            "chunks": len(retriever.store.chunks),
            "top_k": settings.rag_top_k,
        }
    except Exception as exc:  # korpus belum siap
        return {"ok": False, "detail": str(exc)}


def _intent_status() -> dict:
    try:
        status = classifier_status()
        return {
            "ok": True,
            "model": status["model"],
            "trained": status["trained"],
            "macro_f1": (status.get("metrics") or {}).get("macro_f1"),
        }
    except Exception as exc:
        return {"ok": False, "detail": str(exc)}


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Warm-up model agar request pertama tidak lambat."""
    for name, loader in (
        ("intent", get_classifier),
        ("rag", get_retriever),
        ("sentiment", get_predictor),
    ):
        try:
            loader()
        except Exception as exc:
            print(f"[warmup] {name} gagal dimuat: {exc}")
    print(f"[startup] {settings.app_name} v{settings.version} siap")
    yield


app = FastAPI(
    title=settings.app_name,
    version=settings.version,
    description=(
        "Microservice Gen AI & Data Science untuk platform Exatuy (Capstone A26-CS007).\n\n"
        "**Kelas intent:** tanya_materi, pembahasan_soal, info_kuota_pembayaran, "
        "jadwal_pengumuman, out_of_context.\n\n"
        "**RAG:** ChromaDB/FAISS berisi ringkasan Kurikulum Merdeka SD/SMP.\n\n"
        "**Fallback:** bila Gemini rate limit/timeout, pembahasan disajikan dari "
        "materi statis terverifikasi."
    ),
    lifespan=lifespan,
    openapi_tags=[
        {"name": "health", "description": "Pemantauan status layanan"},
        {"name": "ai", "description": "Gen AI: intent routing, explainer, sentimen"},
        {"name": "messaging", "description": "Webhook Telegram / WhatsApp Cloud API"},
        {"name": "data-science", "description": "Analitik & prediksi remedial"},
    ],
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # backend Java memanggil via server-to-server; batasi di produksi
    allow_credentials=False,
    allow_methods=["GET", "POST", "OPTIONS"],
    allow_headers=["*"],
)

# Shim agar app.config.settings bisa dipakai tanpa import melingkar di tests
app.state.settings = settings


@app.get("/", tags=["health"], summary="Info layanan")
def root() -> dict:
    return {
        "service": settings.app_name,
        "version": settings.version,
        "docs": "/docs",
        "openapi": "/openapi.json",
        "endpoints": [
            "/health",
            "/api/ai/chat",
            "/api/ai/explain",
            "/api/ai/sentiment",
            "/api/ai/webhook/messaging",
            "/api/ai/routes",
            "/api/ds/analytics",
        ],
    }


@app.get("/health", response_model=HealthResponse, tags=["health"], summary="Health-check")
@app.get("/api/v1/health", response_model=HealthResponse, include_in_schema=False)
def health() -> HealthResponse:
    components: dict = {
        "intent_classifier": _intent_status(),
        "rag": _rag_status(),
        "gemini": {
            "ok": settings.gemini_enabled,
            "model": settings.gemini_model,
            "mode": "live" if settings.gemini_enabled else "fallback-statis",
        },
    }
    if settings.check_database:
        components["mysql"] = _db_reachable()

    healthy = all(
        part.get("ok", True) for name, part in components.items() if name != "gemini"
    )
    return HealthResponse(
        status="ok" if healthy else "degraded",
        service=settings.app_name,
        version=settings.version,
        components=components,
    )


@app.post("/api/ai/chat", response_model=ChatResponse, tags=["ai"], summary="Chat + intent routing")
async def chat(request: ChatRequest) -> ChatResponse:
    return await handle_chat(request)


@app.post("/api/ai/explain", response_model=ExplainResponse, tags=["ai"], summary="Pembahasan soal")
async def explain(request: ExplainRequest) -> ExplainResponse:
    try:
        retriever = get_retriever()
    except Exception as exc:
        raise HTTPException(status_code=503, detail=f"RAG belum siap: {exc}") from exc

    query = " ".join(
        part for part in [request.subject, request.question, request.correct_answer] if part
    )
    sources = retriever.retrieve(
        query,
        grade_level=request.grade_level,
        subject=request.subject,
        strict_subject=bool(request.subject),
    )
    payload = {
        "question": request.question,
        "options": request.options,
        "student_answer": request.student_answer,
        "correct_answer": request.correct_answer,
        "grade_level": request.grade_level,
        "subject": request.subject,
    }
    result = await generate_explanation(payload, sources)
    return ExplainResponse(
        explanation=result.explanation,
        steps=result.steps,
        sources=sources,
        provider=result.provider,
        cached=result.cached,
        degraded_reason=result.degraded_reason,
    )


@app.post("/api/ai/sentiment", response_model=SentimentResponse, tags=["ai"], summary="Sentimen ulasan")
def sentiment(request: SentimentRequest) -> SentimentResponse:
    predictor = get_predictor()
    output = predictor.predict_many(request.texts)
    return SentimentResponse(results=output["results"], summary=output["summary"])


@app.get("/api/ai/routes", tags=["ai"], summary="Tabel routing intent")
def routes() -> dict:
    return {
        "routes": routing_table(),
        "classifier": classifier_status(),
        "min_confidence": settings.intent_min_confidence,
    }


@app.get("/api/ai/webhook/messaging", tags=["messaging"], summary="Verifikasi WhatsApp webhook")
def verify_messaging_webhook(
    mode: str = Query(default="", alias="hub.mode"),
    token: str = Query(default="", alias="hub.verify_token"),
    challenge: str = Query(default="", alias="hub.challenge"),
):
    if mode == "subscribe" and token == settings.whatsapp_verify_token:
        return JSONResponse(content=int(challenge) if challenge.isdigit() else challenge)
    raise HTTPException(status_code=403, detail="verify_token tidak cocok")


@app.post(
    "/api/ai/webhook/messaging",
    response_model=MessagingWebhookResponse,
    tags=["messaging"],
    summary="Webhook Telegram / WhatsApp",
)
async def messaging_webhook(
    payload: MessagingWebhookRequest, request: Request
) -> MessagingWebhookResponse:
    if payload.platform == "telegram":
        provided = request.headers.get("x-telegram-bot-api-secret-token")
        if not messaging.verify_token(provided):
            raise HTTPException(status_code=401, detail="secret token webhook tidak valid")

    incoming = messaging.extract_incoming(payload.platform, payload.payload)
    if not incoming.text:
        return MessagingWebhookResponse(
            ok=True,
            platform=payload.platform,
            chat_id=incoming.chat_id,
            detail="payload tanpa teks (mis. update status) — diabaikan",
        )

    chat_response = await handle_chat(
        ChatRequest(message=incoming.text, role=Role.student)
    )

    delivered = False
    detail = "chat_id tidak tersedia"
    if incoming.chat_id:
        delivered, detail = await messaging.deliver(
            payload.platform, incoming.chat_id, chat_response.answer
        )

    return MessagingWebhookResponse(
        ok=True,
        platform=payload.platform,
        chat_id=incoming.chat_id,
        incoming_text=incoming.text,
        intent=chat_response.intent,
        reply=chat_response.answer,
        delivered=delivered,
        detail=detail,
    )


@app.get(
    "/api/ds/analytics",
    response_model=AnalyticsResponse,
    tags=["data-science"],
    summary="Analitik & prediksi siswa berisiko",
)
def ds_analytics(
    grade_level: str | None = Query(default=None, description="mis. SD-4 / SMP-8"),
    top_n: int = Query(default=5, ge=1, le=50),
) -> AnalyticsResponse:
    payload = analytics.build_payload(grade_level=grade_level, top_n=top_n)
    return AnalyticsResponse(**payload)
