"""Router percakapan: guardrails -> klasifikasi intent -> handler (item #2 & #6).

Kontrak routing (dipakai backend Java & kanal Telegram/WhatsApp):

    tanya_materi            -> rag_tutor            (RAG materi + Gemini)
    pembahasan_soal         -> quiz_explainer       (pembahasan langkah soal)
    info_kuota_pembayaran   -> backend_kuota        (data saldo/invoice dari Java)
    jadwal_pengumuman       -> backend_pengumuman   (papan pengumuman dari Java)
    out_of_context          -> guardrail_refusal    (ditolak santun)
"""

from __future__ import annotations

from . import guardrails
from .config import settings
from .intent import classify
from .llm import answer_question, generate_explanation
from .rag import get_retriever
from .schemas import ChatRequest, ChatResponse, Intent, SourceChunk

BACKEND_HANDOFF_NOTE = {
    "backend_kuota": (
        "Catatan integrasi: angka saldo, riwayat transaksi, dan tagihan yang "
        "sebenarnya diambil dari backend Java Exatuy (QuotaService / CashInTransactionDAO). "
        "Jawaban ini menjelaskan aturan umumnya."
    ),
    "backend_pengumuman": (
        "Catatan integrasi: daftar jadwal dan pengumuman terbaru diambil dari "
        "backend Java Exatuy (InformationBoardDAO) via endpoint pengumuman."
    ),
}

JENJANG_HINT = {
    Intent.tanya_materi: ("Matematika", "IPA", "Bahasa Indonesia"),
    Intent.pembahasan_soal: ("soal yang kamu kerjakan",),
    Intent.info_kuota_pembayaran: ("panduan kuota & pembayaran",),
    Intent.jadwal_pengumuman: ("jadwal kelas dan pengumuman",),
}


def _subject_hint(intent: Intent) -> str | None:
    mapping = {
        Intent.tanya_materi: None,
        Intent.info_kuota_pembayaran: "Layanan",
        Intent.jadwal_pengumuman: "Layanan",
        Intent.pembahasan_soal: None,
    }
    return mapping.get(intent)


async def handle_chat(request: ChatRequest) -> ChatResponse:
    message = request.message.strip()

    # --- Lapis 1: guardrail leksikal / prompt-injection ------------------- #
    decision = guardrails.check(message)
    if decision.blocked:
        return ChatResponse(
            intent=Intent.out_of_context,
            confidence=1.0,
            routed_to="guardrail_refusal",
            blocked=True,
            guardrail_reason=decision.reason,
            answer=decision.reply or guardrails.refusal_for_low_confidence(),
            sources=[],
            provider="guardrail",
        )

    # --- Lapis 2: klasifikasi intent ------------------------------------- #
    prediction = classify(message)

    if prediction.intent == Intent.out_of_context or not prediction.is_confident:
        return ChatResponse(
            intent=Intent.out_of_context,
            confidence=prediction.confidence,
            routed_to="guardrail_refusal",
            blocked=True,
            guardrail_reason=(
                "intent_out_of_context"
                if prediction.intent == Intent.out_of_context
                else "low_confidence"
            ),
            answer=guardrails.refusal_for_low_confidence(),
            sources=[],
            provider="guardrail",
        )

    retriever = get_retriever()
    subject_hint = _subject_hint(prediction.intent)
    sources: list[SourceChunk] = retriever.retrieve(
        message,
        grade_level=request.grade_level,
        subject=subject_hint,
        strict_subject=subject_hint is not None,
    )

    payload = {
        "question": message,
        "grade_level": request.grade_level,
        "subject": subject_hint,
    }

    if prediction.intent == Intent.pembahasan_soal:
        result = await generate_explanation(payload, sources)
        provider = result.provider
        body = result.explanation
        if result.steps:
            body += "\n\nLangkah pengerjaan:\n" + "\n".join(
                f"{i}. {step}" for i, step in enumerate(result.steps, start=1)
            )
    else:
        result = await answer_question(payload, sources)
        provider = result.provider
        body = result.explanation

    note = BACKEND_HANDOFF_NOTE.get(prediction.routed_to)
    if note:
        body = f"{body}\n\n{note}"

    return ChatResponse(
        intent=prediction.intent,
        confidence=prediction.confidence,
        routed_to=prediction.routed_to,
        blocked=False,
        answer=body,
        sources=sources,
        cached=result.cached,
        provider=provider,
    )


def routing_table() -> list[dict[str, str]]:
    """Dokumentasi routing (ditampilkan pada /api/ai/routes)."""
    from .intent import ROUTE_DESCRIPTIONS, ROUTES

    rows = []
    for intent, target in ROUTES.items():
        rows.append(
            {
                "intent": intent.value,
                "routed_to": target,
                "description": ROUTE_DESCRIPTIONS.get(target, ""),
                "contoh_materi": ", ".join(JENJANG_HINT.get(intent, ("-",))),
            }
        )
    return rows


def classifier_status() -> dict:
    from .intent import get_classifier

    classifier = get_classifier()
    return {
        "model": classifier.model_name,
        "artifact": str(classifier.model_path),
        "trained": classifier.loaded,
        "min_confidence": settings.intent_min_confidence,
        "classes": [i.value for i in Intent],
        "metrics": classifier.metrics,
    }
