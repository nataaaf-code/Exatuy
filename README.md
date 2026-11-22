# EXATUY - Adu Pintar Tanpa Ribet

> **Exatuy** — *Adu Pintar Tanpa Ribet*
> 
> Solusi all-in-one untuk bimbingan belajar, sekolah, dan pelatihan: manajemen siswa, sistem tagihan otomatis, presensi digital, bank soal, rapor, hingga portal orang tua.

---

## Tentang Exatuy

**Exatuy** adalah platform asesmen online modern yang digunakan dalam program **IDS Cyber Security Academy** untuk mengukur, memvalidasi, dan mendokumentasikan kompetensi peserta secara terstruktur melalui sistem quiz teori dan arena battle.

Platform ini membantu pengelola les menyelesaikan masalah operasional sehari-hari:
- **Penagihan SPP** yang selama ini manual dan melelahkan
- **Pelacakan kuota pertemuan** yang sering terlupa
- **Komunikasi berulang** dengan orang tua via WhatsApp
- **Pembuatan ujian** yang memakan waktu tiap ganti materi

Dukungan untuk berbagai jenjang: SD, SMP, SMA, dan pelatihan umum.

---

## Fitur Utama

### 📚 Manajemen Pembelajaran
- Buat dan kelola quiz dengan multiple choice dan esai singkat
- Atur durasi dan timer countdown dengan auto-submit
- Deadline per quiz dengan timezone WIB
- Gambar pada soal dan opsi jawaban
- Target quiz berdasarkan kelas/kelompok
- Shuffle urutan soal
- Show/hide pembahasan setelah selesai

### 💳 Sistem Tagihan & Kuota (Baru!)
- **Paket Sesi Belajar**: beli berbasis kuota (12, 24, atau kustom pertemuan)
- **Invoice Otomatis**: tagihan digital per periode dengan status
- **Pengingat Tagihan**: notifikasi sebelum jatuh tempo
- **Riwayat Pembayaran**: tunai atau transfer
- **Sisa Kuota Real-time**: indikator visual di dashboard

### ✅ Presensi Digital
- Absensi per pertemuan dengan kode unik
- Pengajar tandai: Hadir / Izin / Sakit / Alpa
- **Auto-potong kuota** saat siswa hadir
- Peringatan kuota menipis (sisa ≤ 2 sesi)
- Export rekap kehadiran ke PDF dan CSV

### 📝 Bank Soal & Evaluasi
- Pre-test dan post-test per topik
- Kategori soal per mata pelajaran
- Koreksi otomatis instan
- Rapor nilai per siswa (ringkasan per periode)

### 👨‍👩‍👧 Portal Orang Tua (Baru!)
- Cek jadwal kelas anak
- Pantau sisa kuota secara transparan
- Lihat riwayat presensi anak
- Akses rapor nilai anak
- Notifikasi perkembangan anak

### 💰 Pencatatan Keuangan (Baru!)
- Pemasukan otomatis dari pembayaran SPP
- Pencatatan pengeluaran operasional
- Ringkasan laba/rugi bulanan
- Export laporan keuangan

### 🏆 Gamification
- Sistem badge dan poin
- Leaderboard antar siswa
- Achievement: Perfect Score, Quick Thinker, dll

### 💬 Chat Support
- Komunikasi real-time antara orang tua/peserta dan admin
- Admin bisa membalas pesan
- Export chat ke TXT

### 🔒 Keamanan Enterprise
- Rate limiting per endpoint
- Login protection (5 gagal → lockout 15 menit)
- CSRF token di semua form
- BCrypt password hashing
- Session fixation protection
- Security headers lengkap

---

## Peran Pengguna

| Peran | Akses |
|-------|-------|
| **Owner/Admin** | Dashboard lengkap, kelola siswa, tagihan, presensi, soal, laporan keuangan, setelan |
| **Pengajar** | Input presensi, buat quiz, lihat hasil siswa, chat |
| **Siswa** | Kerjakan quiz, lihat nilai, chat admin, profil |
| **Orang Tua** | Pantau jadwal, sisa kuota, presensi, dan nilai anak |

---

## Technology Stack

| Komponen | Teknologi |
|----------|-----------|
| Backend | Java 11+, JSP, Servlet |
| Server | Apache Tomcat 10 |
| Database | MySQL 8.0 |
| Connection Pool | HikariCP |
| Frontend | HTML5, CSS3, Bootstrap 5 |
| Charts | Chart.js |
| Export PDF | iText + html2pdf.js |
| Build Tool | Maven |
| Container | Docker & Docker Compose |
| AI & DS Service | Python 3.11+ / FastAPI / scikit-learn |
| Vector Database | FAISS (default) / ChromaDB |
| LLM | Google Gemini API (`gemini-2.0-flash`) |

---

## Quick Start

```bash
cd /root/documents/tools/Exatuy/Exatuy-main
docker compose up -d
```

Akses: http://localhost:8888

---

## Default Accounts

| Role | Email | Password |
|------|-------|----------|
| Owner | owner@belajarku.id | Admin123! |
| Pengajar | pengajar@belajarku.id | Guru123! |
| Siswa Demo | siswa@belajarku.id | Siswa123! |

---

## AI & Data Science Service (FastAPI)

Arsitektur **hybrid (Opsi A)**: aplikasi inti tetap Java JSP/Servlet + Tomcat 10,
sedangkan seluruh kebutuhan Generative AI dan Data Science dilayani microservice
Python terpisah di folder **`ai-service/`** melalui REST API.

```bash
cd ai-service
python3 -m venv .venv && .venv/bin/pip install -r requirements.txt
.venv/bin/python -m scripts.train_intent     # latih & bandingkan 3 model intent
.venv/bin/python -m scripts.ds_pipeline      # dataset 50 siswa sintetis + LR vs RF
.venv/bin/uvicorn app.main:app --port 8000   # Swagger: http://localhost:8000/docs

# atau lewat Docker (profil opsional, stack utama tidak terpengaruh)
docker compose --profile ai up -d ai-service
```

### Fitur & endpoint

| Endpoint | Fungsi | Item |
|---|---|---|
| `POST /api/ai/chat` | Klasifikasi intent ≥ 4 kelas + routing + jawaban RAG | `#2` |
| `POST /api/ai/explain` | Pembahasan soal salah dengan persona "Kakak Tutor Mentari" | `#1` |
| `POST /api/ai/sentiment` | Sentimen ulasan siswa `positif`/`negatif` + agregasi | `#4` |
| `POST /api/ai/webhook/messaging` | Webhook Telegram Bot / WhatsApp Cloud API | `#22` |
| `GET /api/ds/analytics` | Topik tersulit + daftar siswa berisiko remedial | `#7` |
| `GET /health`, `GET /api/v1/health` | Health-check model, RAG, Gemini, MySQL | `#21` |
| `GET /docs` | OpenAPI/Swagger interaktif | `#31` |

### Definisi masalah AI

Siswa Bimbel Mentari belajar mandiri dan sering tidak paham **mengapa** jawabannya
salah, sementara satu pengajar membimbing ±50 siswa. Tujuannya: memberi
pembahasan instan yang kontekstual dengan Kurikulum Merdeka, menyaring pertanyaan
di luar konteks belajar, menyalurkan pertanyaan non-akademik ke modul yang tepat,
serta menandai siswa berisiko remedial sebelum evaluasi berikutnya.

### Perbandingan model NLP (Macro F1, data evaluasi terpisah 60 baris)

| Model | Macro F1 | Accuracy | Hyperparameter |
|---|---|---|---|
| TF-IDF word + Logistic Regression | 0.9314 | 0.9333 | `C=0.5`, n-gram (1,2) |
| **TF-IDF word + Linear SVC** *(dipilih)* | **0.9492** | **0.9500** | `C=3.0`, n-gram (1,2) |
| TF-IDF char_wb + Complement NB | 0.9119 | 0.9167 | `alpha=0.25` |

**Class imbalance:** `class_weight='balanced'` pada model linear + `ComplementNB`
sebagai pembanding; distribusi kelas dipantau pada laporan
`ai-service/reports/intent_model_comparison.json`.
**Hyperparameter tuning:** `GridSearchCV` (`scoring='f1_macro'`, 3-fold) hanya
pada data latih; evaluasi memakai berkas terpisah.
**Prediksi remedial (DS):** Random Forest unggul atas Logistic Regression
(F1 0.825 vs 0.760; ROC-AUC 0.925 vs 0.852) dengan *feature engineering*
meningkatkan F1 LR dari 0.760 → 0.779 dan ROC-AUC 0.852 → 0.870.

### Data dummy & keterbatasan

Seluruh dataset (intent, ulasan, profil 50 siswa) adalah **data sintetis** berlabel
eksplisit `dummy_data = true`, dibangkitkan dengan simulasi statistik ber-seed
(`numpy.default_rng(42)`) — **bukan data siswa asli** Bimbel Mentari, dan nama
disimpan anonim (`Siswa 01`). Keterbatasan utama: ukuran sampel kecil (50 siswa,
180 kalimat intent) sehingga interval kepercayaan lebar dan model rentan
overfitting pada kelas minoritas; kalibrasi ulang wajib dilakukan saat data asli
terkumpul. Kamus data lengkap ada di
[`ai-service/README.md` §9](ai-service/README.md#9-data-dictionary).

### Guardrails

Dua lapis: leksikon 8 kategori out-of-context + deteksi prompt-injection, lalu
lapis model intent dengan ambang keyakinan `0.35`. Pengujian otomatis menolak
**14/14** prompt out-of-context dan 5/5 prompt-injection sambil memastikan 8
pertanyaan sah tetap lolos (`ai-service/tests/test_guardrails.py`). Bila Gemini
kena rate limit/timeout, sistem menyajikan pembahasan statis dari materi
(`degraded_reason` terisi).

Dokumentasi teknis lengkap, kontrak JSON, dan data dictionary: **`ai-service/README.md`**.

---

## Deployment Publik

**URL produksi:** `https://exatuy.my.id` (Cloudflare → VPS ini; origin Tomcat di port `8888`).

```bash
cd Exatuy-main

# 1) WAJIB: migrasi database (idempoten, aman diulang) sebelum demo
for f in sql/add_quota_wallet.sql sql/add_student_pin.sql \
         sql/migration_payment_cashin_quota.sql sql/reconcile_payment_settings.sql \
         sql/add_transaction_payment_details.sql sql/add_announcement_category_grade.sql \
         sql/add_meet_links.sql; do
  docker exec -i examora-mysql sh -c 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" examora_db' < "$f"
done

# 2) build WAR terbaru lalu deploy
docker run --rm -v "$PWD":/app -w /app -v /root/.m2:/root/.m2 \
  maven:3.9-eclipse-temurin-11 mvn -B package -DskipTests
cp target/examora.war examora.war
docker compose up -d --build tomcat     # downtime ±10–20 detik

# 3) AI & DS service (opsional, untuk fitur AI penuh)
docker compose --profile ai up -d --build ai-service
# Swagger: http://<host>:8090/docs  (di VPS ini 8000/8001/8002 sudah terpakai)
```

Verifikasi setelah deploy:

```bash
curl -s https://exatuy.my.id/health | python3 -m json.tool   # status, DB, scheduler, AI
curl -s -o /dev/null -w '%{http_code}\n' https://exatuy.my.id/common/login.jsp
```

Catatan operasional:

* `examora.war` di root repo **harus** lebih baru dari commit terakhir — WAR lama
  membuat fitur baru (kuota, PIN, GMeet, kategori pengumuman, navbar baru) tidak muncul.
* `.env` (rahasia DB Sumopod/DSB.) tidak pernah di-commit; gunakan `.env.example`
  sebagai acuan.
* `EXATUY_ENCRYPTION_KEY` di `.env` **wajib** diisi (`openssl rand -base64 32`). Tanpa itu
  API key pembayaran tidak bisa disimpan maupun dibaca. API key yang tersimpan sebelum
  kunci ini diisi perlu diinput ulang di menu Pembayaran Online.
* Health-check memantau DB, scheduler reset kuota, dan keterjangkauan AI service;
  `ai_service.reachable: false` **bukan** kegagalan aplikasi (fitur AI bersifat opsional).

---

## License

MIT License — dibuat oleh [Re-xist](https://github.com/Re-xist)

---

**Exatuy** — Adu Pintar Tanpa Ribet
