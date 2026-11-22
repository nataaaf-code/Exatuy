# Code Review & QA — PR Anggota Tim (Exatuy)

**Reviewer / Lead QA:** Amin Sumartin / Martin (`AE340B6Y0165`)
**Cakupan:** seluruh PR yang sudah ter-merge ke `main` per `c42b005`
(kuota wallet `#11–#13`, login PIN `#23`, payment & cash-in report `#8/#10/#16`,
penyesuaian exam reader `#24/#25`, penyelarasan skema `#30`).
**Metode:** pembacaan kode statis (setiap temuan disertai `file:line`), eksekusi
test Python AI service (`63 passed`), dan upaya eksekusi unit test Java lewat
Maven di container (status di §5).

Temuan dikelompokkan per tingkat: **P0** (blokir rilis), **P1** (perbaiki sebelum
demo/kuliah), **P2** (perbaikan terjadwal), **Info** (catatan/positif).

---

## 1. Ringkasan temuan

| ID | Tingkat | Ringkasan | File | PIC saran |
|---|---|---|---|---|
| F1 | **P1** | Kunci AES-256 punya nilai default hardcoded → API key Sumopod bisa didekripsi siapa pun yang punya source | `util/CryptoUtil.java:22` | Fahri |
| F2 | **P1** | Dua sumber kebenaran untuk saldo kuota (kolom `users.quota_balance` dibaca langsung vs `QuotaService`/`quota_logs`) | `controller/PaymentSettingsServlet.java:223-234` | Fahri |
| F3 | **P1** | Payment ID & `payment_link_url` Sumopod dipalsukan, tanpa panggilan API; link tidak valid | `controller/PaymentSettingsServlet.java:248-249` | Fahri |
| F4 | **P2** | CSV export rentan formula injection (`=`, `+`, `-`, `@`) | `controller/CashInReportServlet.java:115-121`, `controller/TranscriptServlet.java:672-678` | Rizal |
| F5 | **P2** | CSRF filter hanya menegakkan token bila session ada, tanpa daftar pengecualian eksplisit untuk endpoint machine-to-machine; perbandingan token bukan constant-time | `filter/CSRFProtectionFilter.java:47-53` | Yayan |
| F6 | **P2** | Body POST `saveAnswer` tidak meng-encode `selectedAnswer` → jawaban berisi `&`, `+`, `=`, `%` rusak (berdampak pada soal esai) | `webapp/user/take-exam.jsp:1341` | Rizal |
| F7 | **P2** | Pesan exception mentah ditampilkan ke pengguna lewat `flashError` | `controller/PaymentSettingsServlet.java:254-256`, `:167-169` | Rizal/Fahri |
| F8 | **P2** | PIN 4 digit + lockout hanya berbasis email/IP; tidak ada penghitung per akun, dan tidak wajib 6 digit | `service/UserService.java:284-286`, `controller/LoginServlet.java:77-92` | Fahri |
| F9 | Info | `showStudentCheckout` dapat diakses semua role yang login (termasuk admin) | `controller/PaymentSettingsServlet.java:53-57` | — |
| F10 | Info | `Integer.parseInt(getParameter("points"))` tanpa cek null → pesan error "null" ke pengguna | `controller/PaymentSettingsServlet.java:217` | Fahri |

Tidak ditemukan isu P0 (blokir rilis). Tidak ditemukan **SQL injection**: seluruh
query baru memakai `PreparedStatement` parameter terikat.

---

## 2. Detail temuan

### F1 — Default encryption key hardcoded (P1)

`util/CryptoUtil.java:22-32`

```java
private static final String DEFAULT_SECRET = "Exatuy-BimbelMentari-AES256-Key-2026";
...
String secret = System.getenv("EXATUY_ENCRYPTION_KEY");
if (secret == null || secret.trim().isEmpty()) {
    secret = System.getProperty("exatuy.encryption.key", DEFAULT_SECRET);   // <- fallback diam-diam
}
```

**Dampak.** Algoritmanya sudah benar (AES-256-GCM, IV acak 12 byte per enkripsi,
`GCMParameterSpec(128, iv)`, payload `Base64(iv + ciphertext)`). Masalahnya: bila
env var tidak diset di server, enkripsi tetap "berhasil" memakai kunci publik yang
ada di repo, sehingga `payment_settings.sumopod_api_key_enc` dapat didekripsi
siapa pun yang memegang source. Kegagalan konfigurasi ini *silent* — tidak ada
log peringatan.

**Saran.** Gagal cepat di luar mode dev, dan catat peringatan sekali:

```java
private static SecretKey getSecretKey() throws Exception {
    String secret = System.getenv("EXATUY_ENCRYPTION_KEY");
    if (secret == null || secret.isBlank()) {
        if (!"true".equals(System.getenv("EXATUY_ALLOW_DEFAULT_KEY"))) {
            throw new IllegalStateException(
                "EXATUY_ENCRYPTION_KEY belum diset — enkripsi kredensial ditolak.");
        }
        LOGGER.warning("Memakai kunci default pengembangan; JANGAN dipakai di produksi.");
        secret = System.getProperty("exatuy.encryption.key", DEFAULT_SECRET);
    }
    ...
}
```

Tambahkan juga `EXATUY_ENCRYPTION_KEY` pada `.env.example` + dokumentasi
deploy, karena tanpa itu tomcat akan gagal menyimpan pengaturan pembayaran.

### F2 — Dua sumber kebenaran saldo kuota (P1)

`controller/PaymentSettingsServlet.java:223-234`

```java
int maxQuota = setting.getMaxQuotaPerMonth();
int currentBalance = currentUser.getQuotaBalance();
if (points < 1) { ... }
if (currentBalance + points > maxQuota) { throw new IllegalArgumentException(...); }
```

**Dampak.** Aturan "saldo + pembelian ≤ 12" diimplementasikan ulang di controller,
sementara `QuotaService.validateTopUp()` (`service/QuotaService.java:45-52`) sudah
menyediakan versi otoritatif yang membaca saldo lewat `QuotaDAO.applyChange()`
(dengan `SELECT ... FOR UPDATE`). Dua jalur ini bisa menghasilkan saldo berbeda
mis. saat poin ditambahkan lewat webhook Sumopod pada request paralel, atau saat
`users.quota_balance` dan `quota_logs` tidak sinkron. Nilai `currentBalance` juga
diambil dari objek user di session yang hanya "disegarkan" best-effort
(`:177-182` menelan exception dengan `catch (Exception ignored) {}`).

**Saran.** Jadikan `QuotaService` satu-satunya pintu: panggil
`quotaService.validateTopUp(userId, points)` sebelum membuat order, dan
`quotaService.topUp(userId, points, orderId)` saat webhook `payment.completed`
terverifikasi. Jangan membaca `quota_balance` langsung di controller.

### F3 — Identitas & link pembayaran Sumopod dipalsukan (P1)

`controller/PaymentSettingsServlet.java:248-249`

```java
tx.setSumopodPaymentId((setting.isLiveMode() ? "sp_live_" : "sp_sbx_") + shortRand.toLowerCase());
tx.setPaymentLinkUrl("https://sumopod.com/pay/" + orderId);
```

**Dampak.** Tidak ada pemanggilan `POST /api/v1/payments` ke Sumopod (PRD FR-007
langkah 2). Akibatnya: (a) `payment_link_url` yang ditampilkan ke siswa menuju
URL yang tidak ada (404) sehingga alur bayar tidak bisa diselesaikan; (b)
`sumopod_payment_id` bukan ID dari gateway sehingga webhook `payment.completed`
tidak akan pernah cocok dengan transaksi; (c) laporan kas masuk
(`CashInReportServlet`) akan berisi transaksi yang tidak pernah bisa lunas.

**Saran.** Minimal: beri label jelas `(dummy)` pada kolom/link dan
nonaktifkan tombol bayar bila `setting.isLiveMode()` true, agar demo tidak
menjanjikan integrasi yang belum ada. Ideal: implementasikan klien Sumopod
(`SumopodService`) dengan `X-Api-Key` terdekripsi, simpan `payment_link_url`
dari respons gateway, dan uji webhook dengan signature/token yang benar.

### F4 — Formula injection pada ekspor CSV (P2)

`controller/CashInReportServlet.java:115-121` dan
`controller/TranscriptServlet.java:672-678`

```java
private String escapeCSV(String value) {
    if (value == null) return "";
    if (value.contains(",") || value.contains("\"") || value.contains("\n") || value.contains("\r")) {
        return "\"" + value.replace("\"", "\"\"") + "\"";
    }
    return value;
}
```

**Dampak.** Kutip sudah benar untuk pemisah kolom, tetapi nilai yang diawali
`=`, `+`, `-`, `@`, atau TAB akan dieksekusi sebagai formula saat file dibuka di
Excel/Sheets. Kolom yang bisa dikendalikan pengguna: `student_name`,
`student_email`, `student_tag`, `payment_method`, dan judul quiz. Contoh payload
nama siswa: `=HYPERLINK("http://evil.example","klik")`.

**Saran.** Awali dengan apostrof atau prefiks spasi untuk nilai berbahaya:

```java
private String escapeCSV(String value) {
    if (value == null) return "";
    String v = value;
    if (!v.isEmpty() && "=+-@\t\r".indexOf(v.charAt(0)) >= 0) {
        v = "'" + v;
    }
    if (v.contains(",") || v.contains("\"") || v.contains("\n") || v.contains("\r")) {
        return "\"" + v.replace("\"", "\"\"") + "\"";
    }
    return v;
}
```

Sebaiknya ekstrak ke satu util bersama (`util/CsvUtil.java`) supaya tidak ada dua
implementasi yang berbeda (keduanya saat ini sudah berbeda: Transcript tidak
memeriksa `\r`).

### F5 — Perilaku CSRF filter pada endpoint machine-to-machine (P2)

`filter/CSRFProtectionFilter.java:38-53`

```java
if (session != null) {
    String sessionToken = ...;
    if (sessionToken == null || requestToken == null || !sessionToken.equals(requestToken)) { ... 403 ... }
}
```

**Dampak.** Endpoint webhook (`SumopodWebhookServlet`, dan kelak webhook
Telegram/WhatsApp) lolos validasi hanya karena request server-ke-server tidak
membawa cookie session — bukan karena didaftarkan sebagai pengecualian. Kalau
nanti webhook dipanggil dari konteks browser atau proxy yang meneruskan cookie,
callback pembayaran akan ditolak 403 tanpa penjelasan. Selain itu
`String.equals` untuk token bersifat *short-circuit* (bukan constant-time).

**Saran.** Tambahkan daftar putih eksplisit + bandingkan dengan
`MessageDigest.isEqual`:

```java
private static final List<String> CSRF_EXEMPT = List.of(
    "/LoginServlet", "/RegisterServlet", "/SumopodWebhookServlet", "/api/ai/webhook/messaging");
...
if (CSRF_EXEMPT.stream().anyMatch(path::endsWith)) { chain.doFilter(request, response); return; }
...
if (sessionToken == null || requestToken == null ||
    !MessageDigest.isEqual(sessionToken.getBytes(UTF_8), requestToken.getBytes(UTF_8))) { ... }
```

Endpoint webhook harus tetap diamankan lewat token/signature milik gateway
(bukan CSRF), jadi pastikan `SumopodWebhookServlet` memverifikasi
`X-Webhook-Token`.

### F6 — `selectedAnswer` tidak di-encode saat simpan jawaban (P2)

`webapp/user/take-exam.jsp:1331-1342`

```js
body: 'submissionId=' + submissionId + '&questionId=' + questionId +
      '&selectedAnswer=' + selectedAnswer + '&csrfToken=' + encodeURIComponent(csrfToken)
```

**Dampak.** `csrfToken` sudah di-encode, tetapi `selectedAnswer` tidak. Untuk
pilihan ganda huruf A–D ini tidak terasa; untuk soal esai/isi singkat jawaban
seperti `A & B`, `x=1`, `50%`, atau `a+b` akan terpotong/berubah saat di-parse
server → jawaban tersimpan salah atau dianggap kosong, dan indikator
"tersimpan" tetap menyala (tidak ada error). Ini kelas bug yang sulit dilacak.

**Saran.**

```js
const form = new URLSearchParams({
    submissionId, questionId, selectedAnswer, csrfToken
});
fetch('../ExamServlet?action=saveAnswer', { method: 'POST', body: form, headers: { 'Content-Type': 'application/x-www-form-urlencoded' } })
```

`URLSearchParams` meng-encode seluruh nilai secara benar.

### F7 — Pesan exception mentah sampai ke pengguna (P2)

`controller/PaymentSettingsServlet.java:167-169` dan `:254-256`

```java
session.setAttribute("flashError", "Gagal menyimpan pengaturan pembayaran: " + e.getMessage());
session.setAttribute("flashError", "Gagal membuat pesanan kuota: " + e.getMessage());
```

**Dampak.** `e.getMessage()` bisa memuat detail internal (mis. pesan SQL/JDBC,
atau `NumberFormatException: For input string: "abc"`). Selain itu untuk input
`points` non-numerik, siswa melihat pesan "...: null" (lihat F10) — membingungkan.

**Saran.** Petakan ke pesan ramah: validasi input lebih dulu, dan untuk exception
tak terduga tampilkan pesan generik sambil mencatat detail ke log server
(`LOGGER.log(Level.WARNING, "checkout gagal", e)`).

### F8 — Kekuatan PIN & penghitung percobaan (P2)

`service/UserService.java:284-286`, `controller/LoginServlet.java:77-92`

```java
static boolean isValidPin(String pin) { return pin != null && pin.matches("\\d{4,6}"); }
```

**Yang sudah baik.** PIN tidak disimpan sebagai teks: `PasswordUtil.hashPassword(pin)`
(bcrypt) dan diverifikasi dengan `PasswordUtil.verifyPassword` (`:280-281`), hanya
berlaku untuk role `peserta`, dan login dibatasi `RateLimiter` ganda (IP + email,
5 kegagalan → lockout 15 menit).

**Risiko.** Ruang PIN 4 digit hanya 10.000 kombinasi; lockout saat ini di-kunci
pada `email`/IP sehingga penyerang yang memutar banyak email/IP tetap dapat
mencoba. Bila hash bocor (mis. dari dump DB), PIN 4 digit dapat dipecah lebih
cepat daripada password kuat.

**Saran.** Wajibkan 6 digit (`\\d{6}`) untuk akun baru, tambahkan penghitung
gagal per `user_id` di tabel (bukan hanya per email di memori — `RateLimiter`
in-memory akan hilang saat container restart), dan kirim ulang PIN lewat kanal
guru saat lupa.

### F9, F10 — Catatan kecil (Info)

- `PaymentSettingsServlet.java:53-57`: `action=checkout` dilayani untuk semua
  role yang login, termasuk admin. Tidak berbahaya, tetapi sebaiknya
  di-redirect ke dashboard admin agar tidak membingungkan.
- `PaymentSettingsServlet.java:217`: `Integer.parseInt(request.getParameter("points"))`
  tanpa cek `null` → ditangkap `catch (Exception e)` di `:254` dan tampil sebagai
  "null" ke pengguna. Cukup gunakan `String.valueOf(...)` yang di-trim dan
  validasi eksplisit sebelum parse.
- `controller/AuditServlet.java:269-270` membandingkan token CSRF manual di luar
  filter — setelah `CSRFProtectionFilter` diperbaiki, duplikasi ini bisa
  dihapus agar tidak ada dua perilaku.

---

## 3. Yang sudah baik (dipertahankan)

| Area | Bukti |
|---|---|
| Transaksi dompet kuota aman dari *double-spend* | `QuotaDAO.applyChange` memakai `SELECT quota_balance, last_reset_month ... FOR UPDATE` + `setAutoCommit(false)` + `commit/rollback` (`dao/QuotaDAO.java:40-89`) |
| Reset bulanan idempoten | `QuotaDAO.resetAllForMonth` hanya menyentuh siswa yang `last_reset_month <> bulan berjalan` (`:97-131`), dipanggil tiap menit oleh `AttendanceSchedulerListener:47-56` — aman terhadap restart, tidak menggandakan log |
| Batas kuota terpusat di service | `QuotaService.MAX_QUOTA = 12`, `validatePoints` 1..12, pesan pengguna deskriptif (`service/QuotaService.java:16,45-52,89-98`) |
| Deadline exam ditegakkan di server | `take-exam.jsp:1352-1355` menangani `TIME_EXPIRED` dari `ExamServlet` → jawaban otomatis dikumpulkan dan siswa dialihkan |
| Mode offline aman dari manipulasi waktu | Timer di-`freeze` saat `offline` (`take-exam.jsp:1485-1489`) lalu di-`unfreeze` + `retryFailedSaves()` saat kembali online (`:1491-1499`); validasi waktu tetap milik server |
| PIN disimpan sebagai hash | bcrypt via `PasswordUtil` (`service/UserService.java:280-281,305`) |
| Kontrol akses admin pada halaman sensitif | `CashInReportServlet:41` dan `PaymentSettingsServlet:85-88` menolak non-admin/owner dengan redirect/403 |
| Tidak ada query string-concat baru | seluruh DAO PR ini memakai `PreparedStatement` parameter terikat |
| Layer CSRF ada dan mencakup `/*` | `filter/CSRFProtectionFilter.java:15` (perbaikan di F5 bersifat penguatan, bukan penambahan) |

---

## 4. Cakupan test yang ada vs yang perlu ditambah

Sudah ada: `src/test/java/com/examora/service/QuotaServiceTest.java` dan
`UserServicePinTest.java` (unit test dengan JUnit 5 + Mockito, sesuai `pom.xml`).

Belum ada (disarankan ditambahkan pemilik fitur):

1. **Checkout kuota** (`PaymentSettingsServlet`): kasus `points` = 0, negatif,
   non-numerik, dan `saldo + points > 12` → pastikan pesan & status konsisten
   dengan `QuotaService`.
2. **CSV escaping**: nama siswa berisi `=SUM(A1:A2)`, koma, dan tanda kutip →
   hasil file harus aman dibuka di Excel (regresi untuk F4).
3. **Webhook `payment.completed`**: idempoten — dua callback identik tidak boleh
   menambah poin dua kali.
4. **Reset bulanan**: `last_reset_month` NULL, bulan lalu, dan bulan berjalan.
5. **saveAnswer dengan karakter khusus** (`&`, `=`, `%`, spasi) tetap tersimpan
   utuh (regresi untuk F6) — bisa diuji lewat unit test servlet + MockHttpServletRequest.
6. **Guardrail AI** (silang-team): 14 kasus out-of-context sudah otomatis di
   `ai-service/tests/test_guardrails.py` (70 test hijau untuk seluruh service) —
   tinggal menambah test integrasi Java → FastAPI saat konektor
   `AI_SERVICE_BASE_URL` dipakai.

---

## 5. Status eksekusi test saat review

| Suite | Perintah | Hasil |
|---|---|---|
| AI & DS service (Python) | `ai-service/.venv/bin/python -m pytest -q` | **70 passed** (~1,4 s) — termasuk uji backend ChromaDB |
| Unit test Java | `docker run --rm -v "$PWD":/app -w /app -v /root/.m2:/root/.m2 maven:3.9-eclipse-temurin-11 mvn -B test` | **4 test lulus, 0 failure** — `QuotaServiceTest` 3 test, `UserServicePinTest` 1 test (`target/surefire-reports/`) |
| Build WAR | `docker run ... maven:3.9-eclipse-temurin-11 mvn -B package -DskipTests` | **BUILD SUCCESS** → `target/examora.war` (13 MB, 22 Nov). Perhatikan: `examora.war` di root masih build lama (6 Jul) dan **belum** diperbarui, sedangkan source sudah `c42b005` → deploy akan menjalankan kode lama sampai WAR root diganti |

> Catatan penting untuk rilis: `examora.war` yang ada di folder ini **lebih tua**
> daripada source `main`. Jika container di-deploy dari WAR itu, fitur kuota,
> login PIN, dan laporan kas masuk **tidak akan muncul**. Rebuild dulu
> (`mvn clean package`) lalu `docker compose up -d --build tomcat`.

---

## 6. Checklist tindak lanjut

- [ ] **Fahri** — F1 (fail-fast kunci enkripsi), F2 (pakai `QuotaService` di
      checkout), F3 (label dummy / klien Sumopod asli), F8 (PIN 6 digit + counter per akun), F10
- [ ] **Rizal** — F4 (CSV escaping ke util bersama), F6 (`URLSearchParams`), F7 (pesan error ramah)
- [ ] **Yayan** — F5 (whitelist + constant-time compare), plus pastikan
      `SumopodWebhookServlet` memverifikasi `X-Webhook-Token`
- [ ] **Martin (QA)** — rebuild WAR & ulangi test Java, verifikasi ulang temuan
      setelah PR perbaikan, dan jalankan test integrasi Java → FastAPI
      (`ai-service`) saat konektor aktif
- [x] **Martin (QA)** — review statis seluruh PR merge, eksekusi 63 test AI service,
      dan dokumentasi item `#2/#3/#6/#22/#31` di `ai-service/README.md`

---

## 7. Putaran kedua — temuan UI & navigasi (setelah laporan pengguna)

Pengguna melaporkan: *"setiap masuk menu, menunya beda-beda tidak sinkron."*
Terbukti benar dan akar masalahnya ditemukan, bukan gejala.

### F11 (P1) — Navbar diduplikasi di 15 halaman siswa

Setiap `user/*.jsp` menulis blok `<nav>` sendiri, sehingga menu berbeda per halaman.
Bukti dari produksi (`https://exatuy.my.id`) sebelum perbaikan:

| Halaman | Menu yang dirender |
|---|---|
| Dashboard | Dashboard, Quiz, Materi, Absensi, Riwayat, Transcript Nilai, Leaderboard, Nilai Tugas, Profil, Logout |
| Quiz Tersedia | sama, **tanpa** Transcript & Leaderboard |
| Materi | hanya 5 item, **tanpa Logout** |
| Profil | **tanpa** Materi, Transcript, Leaderboard |
| Achievements | hanya Dashboard, Achievements, Riwayat, Nilai Tugas, Profil, Logout |

**Perbaikan.** Satu fragmen `user/navbar.jspf` menjadi sumber tunggal menu
(dashboard, quiz, materi, absensi, files*, riwayat, transcript, leaderboard*,
achievements, chat*, google meet/drive*, custom menu, dompet kuota, profil,
logout — *tampil sesuai pengaturan admin). 15 halaman kini memakainya:
`achievements, arena-join, attendance, attendance-history, chat, dashboard,
exam-history, exam-result, files, materi-list, materi-view, profile, quiz-list,
transcript, quota-checkout`.

Aturan teknis yang dipakai (dan perlu dipertahankan):

- fragmen memakai prefiks `_nav*` + blok `{ }` agar **tidak bentrok** dengan
  variabel yang sudah dideklarasikan halaman pemanggil (static include
  menggabungkan source ke satu method `_jspService`);
- semua nama kelas ditulis lengkap (`com.examora.dao.SettingsDAO`) supaya
  halaman pemanggil tidak wajib menambah import;
- semua tautan memakai `request.getContextPath()` supaya benar baik halaman
  dibuka lewat servlet (`/ExamServlet`) maupun JSP (`/user/files.jsp`);
- navbar `arena-lobby.jsp` / `arena-play.jsp` sengaja dibiarkan (navbar khusus
  sesi arena, bukan menu utama).

**Bukti sesudah perbaikan** (container QA, halaman dirender ulang):

```
qa_dash/list/materi/chat/profile/achieve/attendance/history/transcript
→ 12 menu identik di 9 halaman (sama persis), 0 error kompilasi JSP
```

### F12 (P2, ditemukan saat verifikasi) — link "Files" menunjuk servlet yang tidak ada

`dashboard.jsp` lama menautkan `FileManagementServlet`, sedangkan yang ada hanya
`FileServlet` tanpa penanganan `action` → tombol Files menghasilkan 404.
Navbar baru memakai `user/files.jsp` (halaman yang benar-benar ada).

### Catatan proses (bug yang saya buat sendiri lalu perbaiki)

Percobaan pertama menambahkan `int quotaBalance` di `dashboard.jsp` padahal
variabel itu sudah dideklarasikan di bawahnya → `Duplicate local variable` saat
JSP dikompilasi Jasper. Dampaknya menular: `ChatServlet` (chat dinonaktifkan →
forward ke dashboard) ikut 500. **HTTP 200 pada halaman JSP tidak membuktikan
apa pun** — buktinya harus `grep "Unable to compile class for JSP"` pada body
respons. Setelah perbaikan: 9/9 halaman bersih.

### Verifikasi fitur (container QA `exatuy-qa`, dihapus setelah selesai)

| Item | Uji | Hasil |
|---|---|---|
| `#14` GMeet potong 1 poin | POST `/GMeetServlet` dengan saldo 2 | **303 → tautan Meet**, `quota_balance` 2→1, ledger `gmeet / -1 / balance_after=1` |
| `#14` saldo habis | POST dengan saldo 0 | ditolak, 302 ke dashboard + pesan (tidak ada pemotongan) |
| `#17` kategori + jenjang | POST 2 pengumuman (Info Exam/SD-4, Jadwal GMeet/SMP-8) | siswa SD-4 **hanya melihat** pengumuman SD-4 — filter jenjang bekerja |
| `#17` UI admin | `AdminServlet?action=informationBoard` | 200, 0 error kompilasi, select Kategori & Target Jenjang berisi 4 kategori PRD |
| `#21` health | `GET /health` | `status ok`, DB 1 ms, scheduler `started: true` + `last_run_wib`, `ai_service.reachable: true` |
| Reset bulanan | scheduler tick pada user QA | `quota_logs: monthly_reset -2 → 0` (idempoten, terbukti jalan) |

Data & container QA sudah dibersihkan (`information_board` 0 baris, user QA 0,
container `exatuy-qa` dihapus); stack milik pengguna (`examora-tomcat`,
`examora-mysql`) tidak disentuh.

### Status deploy (penting)

`https://exatuy.my.id` **dilayani dari mesin ini** (Cloudflare → VPS ini; user QA
yang saya buat di DB lokal bisa login di domain tersebut). Namun WAR yang
berjalan masih build lama: 0 dari penanda perubahan baru ditemukan di HTML live.
Jadi UI **belum** ter-update di produksi sampai `examora.war` root diganti dan
container Tomcat dibangun ulang.

