"""Webhook Telegram Bot / WhatsApp Cloud API (item #22, PRD §5.2 & FR-009).

Satu endpoint (`POST /api/ai/webhook/messaging`) menerima payload mentah dari
kedua platform, mengambil teks pesan siswa, menjalankannya melalui router
intent yang sama dengan web chat, lalu mengirim balasan bila token tersedia.

Tanpa token (mode uji/offline), endpoint tetap mengembalikan balasan yang
dihitung agar bisa diuji lewat `pytest` maupun Swagger — hanya `delivered`
yang bernilai false.
"""

from __future__ import annotations

import hmac
from dataclasses import dataclass

from .config import settings

TELEGRAM_API = "https://api.telegram.org/bot{token}/sendMessage"
WHATSAPP_API = "https://graph.facebook.com/v20.0/{phone_id}/messages"


@dataclass
class IncomingMessage:
    chat_id: str | None
    text: str | None
    platform: str


def extract_incoming(platform: str, payload: dict) -> IncomingMessage:
    """Ambil chat_id dan teks dari payload Telegram atau WhatsApp."""
    if platform == "telegram":
        message = payload.get("message") or payload.get("edited_message") or {}
        chat = message.get("chat") or {}
        chat_id = chat.get("id")
        return IncomingMessage(
            chat_id=str(chat_id) if chat_id is not None else None,
            text=(message.get("text") or "").strip() or None,
            platform=platform,
        )

    # WhatsApp Cloud API: entry[0].changes[0].value.messages[0]
    try:
        entries = payload.get("entry") or []
        changes = entries[0].get("changes") or []
        value = changes[0].get("value") or {}
        messages = value.get("messages") or []
        if messages:
            message = messages[0]
            return IncomingMessage(
                chat_id=str(message.get("from")),
                text=((message.get("text") or {}).get("body") or "").strip() or None,
                platform=platform,
            )
        # payload ringkas untuk pengujian manual: {"from": "...", "text": "..."}
        if payload.get("text"):
            return IncomingMessage(
                chat_id=str(payload.get("from", "test")),
                text=str(payload["text"]).strip(),
                platform=platform,
            )
    except (KeyError, IndexError, TypeError):
        pass
    return IncomingMessage(chat_id=None, text=None, platform=platform)


def verify_token(provided: str | None) -> bool:
    """Verifikasi token webhook Telegram (header X-Telegram-Bot-Api-Secret-Token)."""
    expected = settings.telegram_webhook_secret
    if not expected:
        return True  # mode uji: tidak ada secret yang dikonfigurasi
    if not provided:
        return False
    return hmac.compare_digest(provided, expected)


async def deliver(platform: str, chat_id: str, text: str) -> tuple[bool, str | None]:
    """Kirim balasan ke platform. Mengembalikan (delivered, detail)."""
    import httpx

    try:
        if platform == "telegram":
            if not settings.telegram_bot_token:
                return False, "TELEGRAM_BOT_TOKEN belum diset (mode uji)"
            async with httpx.AsyncClient(timeout=8) as client:
                response = await client.post(
                    TELEGRAM_API.format(token=settings.telegram_bot_token),
                    json={"chat_id": chat_id, "text": text[:4000]},
                )
                response.raise_for_status()
            return True, "sent via Telegram Bot API"

        if platform == "whatsapp":
            if not (settings.whatsapp_token and settings.whatsapp_phone_number_id):
                return False, "WHATSAPP_TOKEN / WHATSAPP_PHONE_NUMBER_ID belum diset (mode uji)"
            async with httpx.AsyncClient(timeout=8) as client:
                response = await client.post(
                    WHATSAPP_API.format(phone_id=settings.whatsapp_phone_number_id),
                    headers={"Authorization": f"Bearer {settings.whatsapp_token}"},
                    json={
                        "messaging_product": "whatsapp",
                        "to": chat_id,
                        "type": "text",
                        "text": {"body": text[:4000]},
                    },
                )
                response.raise_for_status()
            return True, "sent via WhatsApp Cloud API"
    except Exception as exc:  # jaringan / token salah
        return False, f"gagal mengirim: {type(exc).__name__}"

    return False, f"platform tidak dikenal: {platform}"
