"""RAG pipeline: chunking materi Kurikulum Merdeka + vector store (item #3).

Backend yang didukung (PRD §9.2 "Vector Database: ChromaDB / FAISS"):

* ``tfidf-faiss`` (default) — TF-IDF word+char n-gram, L2-normalized, lalu
  disimpan di ``faiss.IndexFlatIP``. Sepenuhnya offline, tanpa unduhan model,
  cocok untuk deployment gratis (Render/Koyeb).
* ``chroma`` — ChromaDB persisten dengan embedding function bawaan (ONNX
  MiniLM, multibahasa cukup baik). Aktifkan lewat ``RAG_BACKEND=chroma``.

Keduanya memakai antarmuka yang sama: ``retrieve(query, top_k, grade_level,
subject)`` -> ``list[SourceChunk]`` sehingga backend bisa ditukar tanpa
mengubah router maupun prompt.
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path

from .config import KNOWLEDGE_DIR, MODEL_DIR, REPORT_DIR, settings
from .schemas import SourceChunk

INDEX_PATH = MODEL_DIR / "rag_index.joblib"
CHROMA_DIR = MODEL_DIR / "chroma"
CHROMA_COLLECTION = "kurikulum_merdeka"

_GRADE_ORDER = [
    "SD-1", "SD-2", "SD-3", "SD-4", "SD-5", "SD-6",
    "SMP-7", "SMP-8", "SMP-9",
]


@dataclass
class Chunk:
    chunk_id: str
    doc_id: str
    title: str
    grade_level: str
    subject: str
    heading: str
    text: str
    grades: tuple[str, ...]

    @property
    def searchable(self) -> str:
        return f"{self.title} {self.heading} {self.grade_level} {self.subject} {self.text}"


def _expand_grades(raw: str) -> tuple[str, ...]:
    """Ubah 'SD-3..SD-6' atau 'SEMUA' menjadi daftar jenjang."""
    raw = (raw or "").strip().upper()
    if not raw or raw.startswith("SEMUA") or raw.startswith("ALL"):
        return tuple(_GRADE_ORDER)
    parts = [p.strip() for p in raw.split("..")]
    if len(parts) == 2 and parts[0] in _GRADE_ORDER and parts[1] in _GRADE_ORDER:
        start, end = _GRADE_ORDER.index(parts[0]), _GRADE_ORDER.index(parts[1])
        return tuple(_GRADE_ORDER[start : end + 1])
    if raw in _GRADE_ORDER:
        return (raw,)
    return tuple(_GRADE_ORDER)


def _parse_front_matter(raw: str) -> tuple[dict[str, str], str]:
    meta: dict[str, str] = {}
    body = raw
    if raw.startswith("---"):
        parts = raw.split("---", 2)
        if len(parts) >= 3:
            for line in parts[1].strip().splitlines():
                if ":" in line:
                    key, value = line.split(":", 1)
                    meta[key.strip()] = value.strip()
            body = parts[2]
    return meta, body


def load_chunks(knowledge_dir: Path = KNOWLEDGE_DIR) -> list[Chunk]:
    """Baca seluruh berkas markdown, pecah per heading '## ' menjadi chunk."""
    chunks: list[Chunk] = []
    for path in sorted(knowledge_dir.glob("*.md")):
        meta, body = _parse_front_matter(path.read_text(encoding="utf-8"))
        doc_id = meta.get("doc_id", path.stem)
        title = meta.get("title", path.stem.replace("_", " ").title())
        grade_raw = meta.get("grade_level", "SEMUA")
        subject = meta.get("subject", "Umum")
        grades = _expand_grades(grade_raw)

        sections = re.split(r"\n(?=## )", body)
        for idx, section in enumerate(sections):
            section = section.strip()
            if not section:
                continue
            heading_match = re.match(r"##\s*(.+)", section)
            heading = heading_match.group(1).strip() if heading_match else title
            text = re.sub(r"^#+\s*", "", section).strip()
            if len(text) < 40:
                continue
            chunks.append(
                Chunk(
                    chunk_id=f"{doc_id}#{idx}",
                    doc_id=doc_id,
                    title=title,
                    grade_level=grade_raw,
                    subject=subject,
                    heading=heading,
                    text=text,
                    grades=grades,
                )
            )
    return chunks


# --------------------------------------------------------------------------- #
# Backend FAISS + TF-IDF
# --------------------------------------------------------------------------- #
class FaissStore:
    name = "tfidf-faiss"

    def __init__(self, chunks: list[Chunk], vectorizer, index) -> None:
        self.chunks = chunks
        self.vectorizer = vectorizer
        self.index = index

    @classmethod
    def build(cls, chunks: list[Chunk]) -> "FaissStore":
        import faiss
        import numpy as np
        from sklearn.feature_extraction.text import TfidfVectorizer
        from sklearn.preprocessing import normalize

        vectorizer = TfidfVectorizer(
            analyzer="word",
            ngram_range=(1, 2),
            min_df=1,
            sublinear_tf=True,
            lowercase=True,
        )
        matrix = vectorizer.fit_transform([c.searchable for c in chunks])
        matrix = normalize(matrix)
        dense = np.asarray(matrix.todense(), dtype="float32")
        index = faiss.IndexFlatIP(dense.shape[1])
        index.add(dense)
        return cls(chunks, vectorizer, index)

    def scores(self, query: str) -> list[float]:
        import numpy as np
        from sklearn.preprocessing import normalize

        q = normalize(self.vectorizer.transform([query]))
        dense = np.asarray(q.todense(), dtype="float32")
        # faiss mengembalikan tetangga TERURUT; skor harus dipetakan kembali ke
        # posisi chunk aslinya lewat `indices`, bukan dizip apa adanya.
        sims, indices = self.index.search(dense, len(self.chunks))
        scores = [0.0] * len(self.chunks)
        for rank, chunk_index in enumerate(indices[0]):
            if 0 <= chunk_index < len(scores):
                scores[chunk_index] = float(sims[0][rank])
        return scores

    def persist(self, path: Path = INDEX_PATH) -> None:
        import faiss
        import joblib

        path.parent.mkdir(parents=True, exist_ok=True)
        faiss.write_index(self.index, str(path.with_suffix(".faiss")))
        joblib.dump(
            {"backend": self.name, "vectorizer": self.vectorizer, "chunks": self.chunks},
            path,
        )

    @classmethod
    def load(cls, path: Path = INDEX_PATH) -> "FaissStore | None":
        import faiss
        import joblib

        if not path.exists() or not path.with_suffix(".faiss").exists():
            return None
        bundle = joblib.load(path)
        index = faiss.read_index(str(path.with_suffix(".faiss")))
        return cls(bundle["chunks"], bundle["vectorizer"], index)


# --------------------------------------------------------------------------- #
# Backend ChromaDB
# --------------------------------------------------------------------------- #
class TfidfEmbeddingFunction:
    """Embedding function ChromaDB berbasis TF-IDF milik proyek sendiri.

    Chroma 0.5+ menyediakan embedding ONNX bawaan, tetapi model MiniLM harus
    diunduh (~80 MB) dari internet saat koleksi pertama kali dibuat. Untuk
    deployment gratis/offline itulah masalah: unduhan lambat atau diblokir
    membuat `RAG_BACKEND=chroma` gagal. Kelas ini memakai vectorizer TF-IDF yang
    sudah ada sehingga Chroma benar-benar bisa dipakai tanpa unduhan apa pun.
    """

    def __init__(self, vectorizer=None) -> None:
        self.vectorizer = vectorizer

    def name(self) -> str:  # dipakai Chroma untuk menyimpan skema koleksi
        return "exatuy-tfidf"

    # Chroma 1.x membedakan embedding function "legacy" (tanpa get_config) dan
    # "baru". Kelas ini menyediakan get_config/build_from_config, jadi bukan legacy.
    @property
    def is_legacy(self) -> bool:
        return False

    # --- kontrak persistensi EmbeddingFunction Chroma 1.x --------------- #
    def get_config(self) -> dict:
        return {"implementation": "exatuy-tfidf", "vectorizer": "joblib"}

    @classmethod
    def build_from_config(cls, config: dict) -> "TfidfEmbeddingFunction":
        import joblib

        if not CHROMA_VECTORIZER_PATH.exists():
            raise FileNotFoundError(
                f"Vectorizer untuk koleksi chroma tidak ditemukan: {CHROMA_VECTORIZER_PATH}"
            )
        return cls(joblib.load(CHROMA_VECTORIZER_PATH))

    def __repr__(self) -> str:  # membantu log/debug
        return f"TfidfEmbeddingFunction(vocab={getattr(self.vectorizer, 'vocabulary_', None) and len(self.vectorizer.vocabulary_)})"

    def fit(self, texts: list[str]) -> "TfidfEmbeddingFunction":
        from sklearn.feature_extraction.text import TfidfVectorizer

        self.vectorizer = TfidfVectorizer(
            analyzer="word", ngram_range=(1, 2), min_df=1, sublinear_tf=True
        )
        self.vectorizer.fit(texts)
        return self

    def _encode(self, texts: str | list[str]) -> list[list[float]]:
        import numpy as np
        from sklearn.preprocessing import normalize

        batch = [texts] if isinstance(texts, str) else list(texts)
        matrix = normalize(self.vectorizer.transform(batch))
        return np.asarray(matrix.todense(), dtype="float32").tolist()

    # Catatan penting: Chroma 1.x mengirim `input` sebagai *daftar dokumen*
    # (bahkan untuk query) dan mengharapkan Embeddings (daftar vektor) kembali,
    # jadi `embed_query` tidak di-override — pakai default yang memanggil
    # `__call__`. Ini berbeda dengan Chroma lama yang mengirim satu string.
    def __call__(self, input: list[str] | str) -> list[list[float]]:  # noqa: A002
        return self._encode(input)

    def embed_documents(self, input: list[str] | str) -> list[list[float]]:  # noqa: A002
        return self._encode(input)

    def embed_query(self, input: list[str] | str) -> list[list[float]]:  # noqa: A002
        # Chroma 1.x memakai hasil ini langsung sebagai `query_embeddings`,
        # jadi bentuknya harus Embeddings (daftar vektor), bukan satu vektor.
        return self._encode(input)

    @property
    def default_space(self) -> str:
        return "cosine"


CHROMA_VECTORIZER_PATH = MODEL_DIR / "chroma_tfidf_vectorizer.joblib"


class ChromaStore:
    name = "chroma"

    def __init__(self, collection, chunks: list[Chunk]) -> None:
        self.collection = collection
        self.chunks = chunks
        # Ruang metrik menentukan cara jarak dikonversi menjadi similarity.
        self.space = "cosine"
        try:
            configuration = getattr(collection, "configuration", None) or {}
            self.space = str((configuration.get("hnsw") or {}).get("space", "cosine"))
        except Exception:  # pragma: no cover - versi chroma berbeda
            self.space = "cosine"

    @classmethod
    def _embedding(cls, chunks: list[Chunk] | None = None) -> TfidfEmbeddingFunction:
        """Ambil vectorizer tersimpan; bila belum ada, fit dari korpus."""
        import joblib

        if CHROMA_VECTORIZER_PATH.exists():
            return TfidfEmbeddingFunction(joblib.load(CHROMA_VECTORIZER_PATH))
        if chunks is None:
            raise FileNotFoundError(
                f"Vectorizer chroma belum ada ({CHROMA_VECTORIZER_PATH}); jalankan build_index."
            )
        function = TfidfEmbeddingFunction().fit([c.searchable for c in chunks])
        CHROMA_VECTORIZER_PATH.parent.mkdir(parents=True, exist_ok=True)
        joblib.dump(function.vectorizer, CHROMA_VECTORIZER_PATH)
        return function

    @classmethod
    def build(cls, chunks: list[Chunk], path: Path | None = None) -> "ChromaStore":
        import chromadb
        from chromadb.config import Settings as ChromaSettings

        chroma_dir = path or CHROMA_DIR
        chroma_dir.mkdir(parents=True, exist_ok=True)
        client = chromadb.PersistentClient(
            path=str(chroma_dir), settings=ChromaSettings(anonymized_telemetry=False)
        )
        existing = {c.name for c in client.list_collections()}
        if CHROMA_COLLECTION in existing:
            client.delete_collection(CHROMA_COLLECTION)
        collection = client.create_collection(
            name=CHROMA_COLLECTION,
            embedding_function=cls._embedding(chunks),
            configuration={"hnsw": {"space": "cosine"}},
        )
        collection.add(
            ids=[c.chunk_id for c in chunks],
            documents=[c.searchable for c in chunks],
            metadatas=[
                {
                    "doc_id": c.doc_id,
                    "title": c.title,
                    "grade_level": c.grade_level,
                    "subject": c.subject,
                    "heading": c.heading,
                }
                for c in chunks
            ],
        )
        return cls(collection, chunks)

    @classmethod
    def load(cls, chunks: list[Chunk], path: Path | None = None) -> "ChromaStore":
        import chromadb
        from chromadb.config import Settings as ChromaSettings

        chroma_dir = path or CHROMA_DIR
        client = chromadb.PersistentClient(
            path=str(chroma_dir), settings=ChromaSettings(anonymized_telemetry=False)
        )
        collection = client.get_or_create_collection(
            name=CHROMA_COLLECTION, embedding_function=cls._embedding(chunks)
        )
        if collection.count() == 0:
            return cls.build(chunks, path=chroma_dir)
        return cls(collection, chunks)

    def scores(self, query: str) -> list[float]:
        result = self.collection.query(
            query_texts=[query], n_results=len(self.chunks), include=["distances"]
        )
        ids = result.get("ids", [[]])[0]
        distances = result.get("distances", [[]])[0]
        score_by_id: dict[str, float] = {}
        for cid, dist in zip(ids, distances):
            distance = float(dist)
            if self.space == "cosine":
                similarity = 1.0 - distance
            else:
                # Ruang L2 dengan vektor sudah L2-normalized: d^2 = 2 - 2cos
                similarity = 1.0 - (distance / 2.0)
            score_by_id[cid] = max(0.0, similarity)
        return [score_by_id.get(c.chunk_id, 0.0) for c in self.chunks]


# --------------------------------------------------------------------------- #
# Retriever
# --------------------------------------------------------------------------- #
class Retriever:
    def __init__(self, store) -> None:
        self.store = store

    @property
    def backend(self) -> str:
        return self.store.name

    def retrieve(
        self,
        query: str,
        top_k: int | None = None,
        grade_level: str | None = None,
        subject: str | None = None,
        min_score: float | None = None,
        strict_subject: bool = False,
    ) -> list[SourceChunk]:
        top_k = top_k or settings.rag_top_k
        min_score = settings.rag_min_score if min_score is None else min_score
        grade = (grade_level or "").strip().upper()
        subject_lc = (subject or "").strip().lower()

        raw_scores = self.store.scores(query)
        scored: list[tuple[float, Chunk]] = []
        for chunk, score in zip(self.store.chunks, raw_scores):
            adjusted = score
            if grade and grade in chunk.grades:
                adjusted += 0.05  # prior jenjang (soft filter, bukan hard filter)
            if subject_lc and subject_lc in chunk.subject.lower():
                adjusted += 0.03
            scored.append((adjusted, chunk))

        # Filter mata pelajaran keras (opsional) agar pembahasan soal Matematika
        # tidak mengambil potongan materi IPA hanya karena kata "hasil" dsb.
        if strict_subject and subject_lc:
            matched = [(s, c) for s, c in scored if subject_lc in c.subject.lower()]
            if matched:
                scored = matched

        scored.sort(key=lambda pair: pair[0], reverse=True)
        picked = [(s, c) for s, c in scored[:top_k] if s >= min_score]
        return [
            SourceChunk(
                doc_id=c.doc_id,
                title=c.title,
                grade_level=c.grade_level,
                subject=c.subject,
                score=round(s, 4),
                snippet=c.text[:400],
            )
            for s, c in picked
        ]


def _build_store(chunks: list[Chunk]):
    if settings.rag_backend == "chroma":
        return ChromaStore.load(chunks)
    store = FaissStore.load()
    if store is not None:
        return store
    store = FaissStore.build(chunks)
    try:
        store.persist()
    except Exception as exc:  # pragma: no cover - IO opsional
        print(f"[rag] gagal menyimpan index: {exc}")
    return store


@lru_cache(maxsize=1)
def get_retriever() -> Retriever:
    chunks = load_chunks()
    if not chunks:
        raise RuntimeError(f"Korpus materi kosong: {KNOWLEDGE_DIR}")
    return Retriever(_build_store(chunks))


def rebuild_index() -> dict:
    """Dipakai scripts/build_index.py dan endpoint admin/debug.

    Membangun ulang backend sesuai `settings.rag_backend` sehingga perintah yang
    sama bekerja untuk FAISS maupun ChromaDB.
    """
    get_retriever.cache_clear()
    chunks = load_chunks()
    documents = len({c.doc_id for c in chunks})

    if settings.rag_backend == "chroma":
        store = ChromaStore.build(chunks)
        return {
            "backend": store.name,
            "documents": documents,
            "chunks": len(chunks),
            "index_path": str(CHROMA_DIR),
            "embedding": "exatuy-tfidf (tanpa unduhan model)",
        }

    store = FaissStore.build(chunks)
    store.persist()
    REPORT_DIR.mkdir(parents=True, exist_ok=True)
    return {
        "backend": store.name,
        "documents": documents,
        "chunks": len(chunks),
        "index_path": str(INDEX_PATH),
    }
