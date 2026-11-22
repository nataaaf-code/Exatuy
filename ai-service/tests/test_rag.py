"""Uji pipeline RAG: chunking materi, vector store, dan relevansi retrieval (#3)."""

from __future__ import annotations

from app.config import KNOWLEDGE_DIR
from app.rag import get_retriever, load_chunks


def test_korpus_materi_terbaca_dengan_metadata() -> None:
    chunks = load_chunks()
    assert len(chunks) >= 10, "korpus materi terlalu kecil"
    assert {c.subject for c in chunks} >= {"Matematika", "IPA"}
    for chunk in chunks:
        assert chunk.doc_id and chunk.title
        assert chunk.grade_level
        assert chunk.grades, "setiap chunk wajib memetakan jenjang"
    assert KNOWLEDGE_DIR.exists()


def test_backend_vector_store_aktif() -> None:
    retriever = get_retriever()
    assert retriever.backend in {"tfidf-faiss", "chroma"}
    assert len(retriever.store.chunks) >= 10


def test_retrieval_mengambil_materi_pecahan() -> None:
    retriever = get_retriever()
    sources = retriever.retrieve("menjumlahkan pecahan dengan penyebut berbeda")
    assert sources, "retriever tidak mengembalikan konteks"
    doc_ids = [s.doc_id for s in sources]
    assert "mat-sd-pecahan" in doc_ids[:2], doc_ids
    assert all(s.score > 0 for s in sources)
    assert sources[0].snippet


def test_retrieval_mengambil_materi_ipa_dan_aljabar() -> None:
    retriever = get_retriever()
    for query, expected_doc in (
        ("proses fotosintesis tumbuhan hijau", "ipa-sd-fotosintesis"),
        ("menyelesaikan persamaan linear satu variabel", "mat-smp-aljabar"),
        ("hukum newton aksi reaksi", "ipa-smp-listrik-newton"),
    ):
        doc_ids = [s.doc_id for s in retriever.retrieve(query)]
        assert expected_doc in doc_ids[:3], f"{query} -> {doc_ids}"


def test_prior_jenjang_menaikkan_skor_chunk_yang_cocok() -> None:
    """Soft filter jenjang: chunk yang cocok dengan jenjang siswa mendapat boost."""
    retriever = get_retriever()
    query = "cara menyelesaikan pecahan dan persamaan"

    plain = {(s.doc_id, s.snippet[:40]): s.score for s in retriever.retrieve(query, top_k=10)}
    boosted = {
        (s.doc_id, s.snippet[:40]): s.score
        for s in retriever.retrieve(query, grade_level="SMP-7", top_k=10)
    }

    shared = set(plain) & set(boosted)
    assert shared, "tidak ada chunk yang bisa dibandingkan"
    matches_smp = [key for key in shared if "SMP" in key[0] or key[0].startswith("bimbel")]
    if matches_smp:
        key = matches_smp[0]
        assert boosted[key] > plain[key], "boost jenjang tidak diterapkan"
    # Urutan tetap menurun dan skor tetap valid
    scores = [s.score for s in retriever.retrieve(query, grade_level="SMP-7", top_k=4)]
    assert scores == sorted(scores, reverse=True)


def test_retrieval_tanpa_konteks_tetap_aman() -> None:
    retriever = get_retriever()
    sources = retriever.retrieve("zzz qqq xxxx", min_score=0.12)
    assert isinstance(sources, list)
