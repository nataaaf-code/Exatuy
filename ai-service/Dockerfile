# Exatuy AI & DS microservice (FastAPI + Uvicorn)
FROM python:3.12-slim

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    TZ=Asia/Jakarta

WORKDIR /app

# Dependensi sistem minimal (faiss-cpu & numpy sudah wheel binary)
RUN apt-get update && apt-get install -y --no-install-recommends \
        libgomp1 \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt ./
RUN pip install --upgrade pip && pip install -r requirements.txt

COPY app ./app
COPY scripts ./scripts
COPY data ./data
COPY tests ./tests
COPY pyrightconfig.json ./

# Artefak model ikut disalin bila sudah dilatih di mesin pengembang;
# bila tidak ada, service tetap jalan (klasifikasi memakai fallback heuristik
# dan model sentimen dilatih saat pertama kali dipanggil).
COPY models ./models
COPY reports ./reports

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
    CMD python -c "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:8000/health', timeout=3).status==200 else 1)"

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
