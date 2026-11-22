"""Uji backend ChromaDB (PRD §9.2 — item #3), terpisah dari test RAG default.

Latar belakang: Chroma 1.x punya embedding ONNX bawaan yang harus diunduh (~80 MB).
Unduhan itu lambat/dapat diblokir (terbukti saat pengembangan: baru 37% dalam 5
menit), sehingga proyek memakai embedding TF-IDF sendiri. Berkas ini memastikan
backend chroma benar-benar jalan — bukan hanya terpasang — dan hasil retrievalnya
konsisten dengan backend FAISS.
"""

from __future__ import annotations

import pytest

from app.rag import CHROMA_VECTORIZER_PATH, ChromaStore, FaissStore, Retriever, load_chunks

QUERIES = {
    "menjumlahkan pecahan dengan penyebut berbeda": "mat-sd-pecahan",
    "proses fotosintesis tumbuhan hijau": "ipa-sd-fotosintesis",
    "hukum newton aksi reaksi": "ipa-smp-listrik-newton",
}


@pytest.fixture(scope="module")
def chroma_store(tmp_path_factory):
    pytest.importorskip("chromadb")
    chunks = load_chunks()
    # Vectorizer tersimpan agar `_embedding()` tidak menulis ke models/ saat test.
    if not CHROMA_VECTORIZER_PATH.exists():
        ChromaStore._embedding(chunks)  # noqa: SLF001 - menyiapkan artefak sekali
    return ChromaStore.build(chunks, path=tmp_path_factory.mktemp("chroma"))


def test_backend_berhasil_dibangun(chroma_store) -> None:
    assert chroma_store.name == "chroma"
    assert len(chroma_store.chunks) == 28
    assert chroma_store.collection.count() == 28


def test_tidak_memakai_embedding_onnx_yang_butuh_unduhan(chroma_store) -> None:
    function = chroma_store.collection._embedding_function  # noqa: SLF001
    assert type(function).__name__ == "TfidfEmbeddingFunction"
    assert function.name() == "exatuy-tfidf"


def test_ruang_metrik_cosine(chroma_store) -> None:
    assert chroma_store.space == "cosine"


@pytest.mark.parametrize("query,expected_doc", list(QUERIES.items()))
def test_retrieval_chroma_relevan(chroma_store, query, expected_doc) -> None:
    retriever = Retriever(chroma_store)
    sources = retriever.retrieve(query)
    assert sources, f"chroma tidak mengembalikan konteks untuk: {query}"
    assert expected_doc in [s.doc_id for s in sources[:2]]
    assert all(0.0 <= s.score <= 1.0 for s in sources)


def test_skor_chroma_konsisten_dengan_faiss(chroma_store) -> None:
    """Dua backend harus memberi peringkat & skor yang sama untuk korpus yang sama."""
    faiss_retriever = Retriever(FaissStore.build(load_chunks()))
    chroma_retriever = Retriever(chroma_store)
    for query in QUERIES:
        faiss_top = faiss_retriever.retrieve(query, top_k=3)
        chroma_top = chroma_retriever.retrieve(query, top_k=3)
        assert [s.doc_id for s in faiss_top] == [s.doc_id for s in chroma_top]
        assert abs(faiss_top[0].score - chroma_top[0].score) < 1e-3
