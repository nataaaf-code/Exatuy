"""Uji kontrak HTTP seluruh endpoint (Swagger /docs, chat, explain, sentimen,
webhook messaging, analitik DS, health)."""

from __future__ import annotations

KEYS_CHAT = {"intent", "confidence", "routed_to", "blocked", "answer", "sources", "provider"}
KEYS_EXPLAIN = {"explanation", "steps", "sources", "provider", "cached"}
KEYS_SENTIMENT = {"results", "summary"}


def test_root_dan_docs_tersedia(api_client) -> None:
    root = api_client.get("/")
    assert root.status_code == 200
    assert root.json()["docs"] == "/docs"

    docs = api_client.get("/docs")
    assert docs.status_code == 200
    assert "swagger" in docs.text.lower()

    schema = api_client.get("/openapi.json")
    assert schema.status_code == 200
    paths = schema.json()["paths"]
    for path in (
        "/api/ai/chat",
        "/api/ai/explain",
        "/api/ai/sentiment",
        "/api/ai/webhook/messaging",
        "/api/ds/analytics",
    ):
        assert path in paths


def test_health_menyertakan_komponen(api_client) -> None:
    response = api_client.get("/health")
    assert response.status_code == 200
    body = response.json()
    assert body["status"] in {"ok", "degraded"}
    for component in ("intent_classifier", "rag", "gemini"):
        assert component in body["components"]
    assert body["components"]["intent_classifier"]["trained"] is True
    assert body["components"]["rag"]["ok"] is True

    alias = api_client.get("/api/v1/health")
    assert alias.status_code == 200
    assert alias.json()["service"]


def test_chat_materi_mengembalikan_sumber_rag(api_client) -> None:
    response = api_client.post(
        "/api/ai/chat", json={"message": "jelaskan cara menjumlahkan pecahan", "grade_level": "SD-4"}
    )
    assert response.status_code == 200
    body = response.json()
    assert KEYS_CHAT <= set(body)
    assert body["intent"] == "tanya_materi"
    assert body["sources"], "jawaban materi wajib menyertakan konteks RAG"
    assert body["provider"] in {"gemini", "fallback"}


def test_chat_kuota_dirutekan_ke_backend(api_client) -> None:
    body = api_client.post("/api/ai/chat", json={"message": "sisa poin kuota saya berapa"}).json()
    assert body["intent"] == "info_kuota_pembayaran"
    assert body["routed_to"] == "backend_kuota"
    assert "backend Java" in body["answer"]


def test_chat_out_of_context(api_client) -> None:
    body = api_client.post("/api/ai/chat", json={"message": "resep nasi goreng enak"}).json()
    assert body["blocked"] is True
    assert body["intent"] == "out_of_context"
    assert body["sources"] == []


def test_chat_input_tidak_valid(api_client) -> None:
    assert api_client.post("/api/ai/chat", json={"message": ""}).status_code == 422


def test_explain_pakai_fallback_statis(api_client) -> None:
    response = api_client.post(
        "/api/ai/explain",
        json={
            "question": "Hasil dari 3/4 + 1/2 adalah ...",
            "options": ["5/6", "5/4", "4/6", "1/4"],
            "student_answer": "5/6",
            "correct_answer": "5/4",
            "subject": "Matematika",
            "grade_level": "SD-4",
        },
    )
    assert response.status_code == 200
    body = response.json()
    assert KEYS_EXPLAIN <= set(body)
    assert body["explanation"]
    assert body["provider"] in {"gemini", "fallback"}
    if body["provider"] == "fallback":
        assert body["degraded_reason"]


def test_explain_membatasi_konteks_pada_mapel_yang_sama(api_client) -> None:
    body = api_client.post(
        "/api/ai/explain",
        json={
            "question": "Hasil dari 3/4 + 1/2 adalah ...",
            "student_answer": "5/6",
            "correct_answer": "5/4",
            "subject": "Matematika",
            "grade_level": "SD-4",
        },
    ).json()
    assert body["sources"]
    assert all("matematika" in s["subject"].lower() for s in body["sources"])


def test_sentiment_positif_dan_negatif(api_client) -> None:
    response = api_client.post(
        "/api/ai/sentiment",
        json={
            "texts": [
                "penjelasan kakak sangat membantu saya paham",
                "aplikasinya sering error saat ujian",
            ]
        },
    )
    assert response.status_code == 200
    body = response.json()
    assert KEYS_SENTIMENT <= set(body)
    labels = [item["label"] for item in body["results"]]
    assert labels == ["positif", "negatif"]
    assert body["summary"]["total"] == 2


def test_webhook_telegram(api_client) -> None:
    payload = {
        "platform": "telegram",
        "payload": {
            "message": {
                "chat": {"id": 12345},
                "text": "kapan jadwal exam matematika",
            }
        },
    }
    response = api_client.post("/api/ai/webhook/messaging", json=payload)
    assert response.status_code == 200
    body = response.json()
    assert body["ok"] is True
    assert body["chat_id"] == "12345"
    assert body["intent"] == "jadwal_pengumuman"
    assert body["reply"]
    # Tanpa TELEGRAM_BOT_TOKEN (mode uji) balasan tidak terkirim sungguhan.
    assert body["delivered"] is False


def test_webhook_whatsapp_bentuk_cloud_api(api_client) -> None:
    payload = {
        "platform": "whatsapp",
        "payload": {
            "entry": [
                {
                    "changes": [
                        {
                            "value": {
                                "messages": [
                                    {
                                        "from": "628123456789",
                                        "text": {"body": "apa itu fotosintesis"},
                                    }
                                ]
                            }
                        }
                    ]
                }
            ]
        },
    }
    response = api_client.post("/api/ai/webhook/messaging", json=payload)
    assert response.status_code == 200
    body = response.json()
    assert body["chat_id"] == "628123456789"
    assert body["intent"] == "tanya_materi"


def test_webhook_tanpa_teks_diabaikan(api_client) -> None:
    response = api_client.post(
        "/api/ai/webhook/messaging",
        json={"platform": "telegram", "payload": {"update_id": 1}},
    )
    assert response.status_code == 200
    assert response.json()["ok"] is True


def test_analytics_ds_menyajikan_model_comparison(api_client) -> None:
    response = api_client.get("/api/ds/analytics", params={"top_n": 3})
    assert response.status_code == 200
    body = response.json()
    assert body["dummy_data"] is True
    assert len(body["model_comparison"]) >= 4
    assert {"LogisticRegression", "RandomForest"} <= {
        row["model"] for row in body["model_comparison"]
    }
    assert body["hardest_topics"]
    assert len(body["at_risk_students"]) <= 3
    assert body["recommendations"]


def test_routes_menampilkan_lima_intent(api_client) -> None:
    body = api_client.get("/api/ai/routes").json()
    assert len(body["routes"]) == 5
    assert body["classifier"]["trained"] is True
