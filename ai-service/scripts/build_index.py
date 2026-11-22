#!/usr/bin/env python3
"""Bangun ulang index vektor RAG dari korpus `data/knowledge/`.

Jalankan setiap kali materi Kurikulum Merdeka diperbarui:
    .venv/bin/python -m scripts.build_index
"""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app.rag import load_chunks, rebuild_index  # noqa: E402


def main() -> None:
    chunks = load_chunks()
    print(f"Korpus: {len({c.doc_id for c in chunks})} dokumen / {len(chunks)} chunk")
    summary = rebuild_index()
    for key, value in summary.items():
        print(f"  {key}: {value}")


if __name__ == "__main__":
    main()
