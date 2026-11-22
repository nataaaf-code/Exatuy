<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%@ page import="com.examora.model.User" %>
<%@ page import="com.examora.model.PaymentSetting" %>
<%@ page import="com.examora.util.ValidationUtil" %>
<%@ page import="java.math.BigDecimal" %>
<%
    User currentUser = (User) session.getAttribute("user");
    if (currentUser == null || (!currentUser.isAdmin() && !"owner".equals(currentUser.getRole()))) {
        response.sendRedirect("../LoginServlet");
        return;
    }

    PaymentSetting setting = (PaymentSetting) request.getAttribute("paymentSetting");
    if (setting == null) setting = new PaymentSetting();
    String maskedApiKey = (String) request.getAttribute("maskedApiKey");
    if (maskedApiKey == null) maskedApiKey = "";
    String webhookUrl = (String) request.getAttribute("webhookUrl");
    if (webhookUrl == null) webhookUrl = "";

    String success = (String) session.getAttribute("flashSuccess");
    String error = (String) session.getAttribute("flashError");
    if (success != null) session.removeAttribute("flashSuccess");
    if (error != null) session.removeAttribute("flashError");

    long pricePerPoint = setting.getDummyPricePerPoint().longValue();
%>
<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Pengaturan Pembayaran Online - Exatuy</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.2/dist/css/bootstrap.min.css" rel="stylesheet">
    <link href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.1/font/bootstrap-icons.css" rel="stylesheet">
    <link href="<%= request.getContextPath() %>/assets/css/style.css" rel="stylesheet">
    <link href="<%= request.getContextPath() %>/assets/css/handdrawn.css" rel="stylesheet">
    <link rel="icon" type="image/svg+xml" href="<%= request.getContextPath() %>/assets/img/favicon.svg?v=4">
    <style>
        .mode-radio-card {
            border: 2px solid #dee2e6;
            border-radius: 12px;
            padding: 1rem;
            cursor: pointer;
            transition: all 0.2s ease;
        }
        .mode-radio-card:hover {
            border-color: #4A90D9;
            background: rgba(74, 144, 217, 0.04);
        }
        .mode-radio-card.selected {
            border-color: #4A90D9;
            background: rgba(74, 144, 217, 0.08);
        }
        .sim-pkg-card {
            background: #f8f9fc;
            border: 1.5px dashed #cbd5e1;
            border-radius: 12px;
            padding: 0.9rem;
            text-align: center;
        }
    </style>
</head>
<body>
    <%@ include file="sidebar.jsp" %>

    <div class="main-content">
        <!-- Header -->
        <div class="d-flex justify-content-between align-items-start flex-wrap gap-3 mb-4">
            <div>
                <h1 class="h3 mb-1 fw-bold text-primary">
                    <i class="bi bi-credit-card-2-front me-2"></i>Pengaturan Pembayaran Online
                </h1>
                <nav aria-label="breadcrumb">
                    <ol class="breadcrumb mb-0">
                        <li class="breadcrumb-item"><a href="<%= request.getContextPath() %>/AdminServlet?action=dashboard">Dashboard</a></li>
                        <li class="breadcrumb-item active">Pengaturan Pembayaran</li>
                    </ol>
                </nav>
            </div>
            <div class="d-flex flex-wrap gap-2">
                <a href="<%= request.getContextPath() %>/CashInReportServlet" class="btn btn-outline-success btn-sm">
                    <i class="bi bi-cash-coin me-1"></i>Lihat Laporan Kas Masuk
                </a>
            </div>
        </div>

        <% if (success != null) { %>
        <div class="alert alert-success alert-dismissible fade show">
            <i class="bi bi-check-circle-fill me-2"></i><%= ValidationUtil.sanitizeHtml(success) %>
            <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
        </div>
        <% } %>
        <% if (error != null) { %>
        <div class="alert alert-danger alert-dismissible fade show">
            <i class="bi bi-exclamation-triangle-fill me-2"></i><%= ValidationUtil.sanitizeHtml(error) %>
            <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
        </div>
        <% } %>

        <div class="row g-4">
            <!-- Form Konfigurasi Pembayaran -->
            <div class="col-lg-8">
                <div class="card shadow-sm">
                    <div class="card-header d-flex justify-content-between align-items-center flex-wrap gap-2">
                        <span><i class="bi bi-shield-lock me-2"></i>Konfigurasi Gerbang Pembayaran Online</span>
                        <% if (setting.isConfigured()) { %>
                            <span class="badge bg-success text-white">
                                <i class="bi bi-check-circle me-1"></i>Terkonfigurasi (<%= setting.isLiveMode() ? "LIVE" : "SANDBOX" %>)
                            </span>
                        <% } else { %>
                            <span class="badge bg-warning text-dark">
                                <i class="bi bi-exclamation-triangle me-1"></i>API Key Belum Diisi
                            </span>
                        <% } %>
                    </div>
                    <div class="card-body">
                        <form method="post" action="<%= request.getContextPath() %>/PaymentSettingsServlet">
                            <input type="hidden" name="csrfToken" value="<%= session.getAttribute("csrfToken") %>">

                            <!-- API Key Pembayaran -->
                            <div class="mb-4">
                                <label for="sumopodApiKey" class="form-label fw-bold">
                                    API Key Pembayaran Online (<code>X-Api-Key</code>)
                                </label>
                                <% if (setting.isConfigured()) { %>
                                <div class="alert alert-light border py-2 px-3 mb-2 d-flex justify-content-between align-items-center flex-wrap gap-2">
                                    <span class="small">
                                        <i class="bi bi-key-fill text-success me-1"></i>
                                        API Key tersimpan (terenkripsi AES-256): <code><%= ValidationUtil.sanitizeHtml(maskedApiKey) %></code>
                                    </span>
                                    <div class="form-check form-check-inline mb-0">
                                        <input class="form-check-input" type="checkbox" id="clearApiKey" name="clearApiKey" value="true">
                                        <label class="form-check-label small text-danger" for="clearApiKey">Hapus API Key</label>
                                    </div>
                                </div>
                                <% } %>
                                <div class="input-group">
                                    <span class="input-group-text"><i class="bi bi-key"></i></span>
                                    <input type="password" class="form-control" id="sumopodApiKey" name="sumopodApiKey"
                                           autocomplete="off"
                                           placeholder="<%= setting.isConfigured() ? "Biarkan kosong jika tidak ingin mengganti API Key" : "Masukkan API Key dari dashboard sumopod.com" %>">
                                    <button class="btn btn-outline-secondary" type="button" onclick="toggleSecret('sumopodApiKey', this)" title="Tampilkan/sembunyikan">
                                        <i class="bi bi-eye"></i>
                                    </button>
                                </div>
                                <div class="form-text">
                                    <i class="bi bi-lock-fill text-success me-1"></i>
                                    API Key otomatis dienkripsi menggunakan <strong>AES-256-GCM</strong> sebelum disimpan ke database.
                                </div>
                            </div>

                            <!-- Webhook Token -->
                            <div class="mb-4">
                                <label for="sumopodWebhookToken" class="form-label fw-bold">
                                    Webhook Verification Token (<code>X-Webhook-Token</code>)
                                </label>
                                <div class="input-group">
                                    <span class="input-group-text"><i class="bi bi-broadcast"></i></span>
                                    <input type="password" class="form-control" id="sumopodWebhookToken" name="sumopodWebhookToken"
                                           autocomplete="off"
                                           value="<%= ValidationUtil.sanitizeHtml(setting.getSumopodWebhookToken() != null ? setting.getSumopodWebhookToken() : "") %>"
                                           placeholder="whtok_...">
                                    <button class="btn btn-outline-secondary" type="button" onclick="toggleSecret('sumopodWebhookToken', this)" title="Tampilkan/sembunyikan">
                                        <i class="bi bi-eye"></i>
                                    </button>
                                </div>
                                <div class="form-text">Digunakan untuk memverifikasi keaslian notifikasi webhook <code>payment.completed</code>, <code>payment.failed</code>, dan <code>payment.expired</code>.</div>
                            </div>

                            <!-- Mode Pembayaran: Sandbox vs Live -->
                            <div class="mb-4">
                                <label class="form-label fw-bold">Mode Pembayaran</label>
                                <div class="row g-3">
                                    <div class="col-sm-6">
                                        <label class="mode-radio-card d-block w-100 <%= !setting.isLiveMode() ? "selected" : "" %>" id="cardSandbox">
                                            <div class="form-check">
                                                <input class="form-check-input" type="radio" name="paymentMode" id="modeSandbox"
                                                       value="sandbox" <%= !setting.isLiveMode() ? "checked" : "" %> onchange="updateModeCards()">
                                                <span class="fw-bold"><i class="bi bi-bug me-1 text-warning"></i>Sandbox (Simulasi)</span>
                                            </div>
                                            <small class="text-muted d-block mt-1">Gunakan untuk pengujian pembayaran dummy tanpa transaksi uang sungguhan.</small>
                                        </label>
                                    </div>
                                    <div class="col-sm-6">
                                        <label class="mode-radio-card d-block w-100 <%= setting.isLiveMode() ? "selected" : "" %>" id="cardLive">
                                            <div class="form-check">
                                                <input class="form-check-input" type="radio" name="paymentMode" id="modeLive"
                                                       value="live" <%= setting.isLiveMode() ? "checked" : "" %> onchange="updateModeCards()">
                                                <span class="fw-bold"><i class="bi bi-lightning-charge-fill me-1 text-success"></i>Live (Produksi)</span>
                                            </div>
                                            <small class="text-muted d-block mt-1">Transaksi QRIS / Virtual Account nyata via gerbang pembayaran.</small>
                                        </label>
                                    </div>
                                </div>
                            </div>

                            <!-- Harga Dummy per Poin & Batas Kuota -->
                            <div class="row g-3 mb-4">
                                <div class="col-md-7">
                                    <label for="dummyPricePerPoint" class="form-label fw-bold">
                                        Harga Dummy per Poin (IDR)
                                    </label>
                                    <div class="input-group">
                                        <span class="input-group-text">Rp</span>
                                        <input type="number" class="form-control" id="dummyPricePerPoint" name="dummyPricePerPoint"
                                               min="0" step="500" required value="<%= pricePerPoint %>" oninput="updatePricePreview()">
                                        <span class="input-group-text">/ poin</span>
                                    </div>
                                    <div class="form-text">Nilai default: Rp 10.000 / poin. Dapat diubah kapan saja oleh pengajar.</div>
                                </div>
                                <div class="col-md-5">
                                    <label for="maxQuotaPerMonth" class="form-label fw-bold">
                                        Batas Maksimal Kuota / Bulan
                                    </label>
                                    <div class="input-group">
                                        <input type="number" class="form-control" id="maxQuotaPerMonth" name="maxQuotaPerMonth"
                                               min="1" max="12" required value="<%= setting.getMaxQuotaPerMonth() %>">
                                        <span class="input-group-text">Poin</span>
                                    </div>
                                    <div class="form-text">Aturan PRD: maks. 12 poin, reset tgl 1 pukul 00:00 WIB.</div>
                                </div>
                            </div>

                            <!-- Live Preview Paket Harga -->
                            <div class="mb-4">
                                <label class="form-label fw-bold small text-muted text-uppercase">Pratinjau Harga Paket di Halaman Siswa</label>
                                <div class="row g-2">
                                    <div class="col-4">
                                        <div class="sim-pkg-card">
                                            <div class="small text-muted">Paket 4 Poin</div>
                                            <div class="fw-bold text-primary" id="preview4">Rp <%= String.format("%,.0f", BigDecimal.valueOf(pricePerPoint * 4)) %></div>
                                        </div>
                                    </div>
                                    <div class="col-4">
                                        <div class="sim-pkg-card">
                                            <div class="small text-muted">Paket 8 Poin</div>
                                            <div class="fw-bold text-primary" id="preview8">Rp <%= String.format("%,.0f", BigDecimal.valueOf(pricePerPoint * 8)) %></div>
                                        </div>
                                    </div>
                                    <div class="col-4">
                                        <div class="sim-pkg-card">
                                            <div class="small text-muted">Paket 12 Poin</div>
                                            <div class="fw-bold text-primary" id="preview12">Rp <%= String.format("%,.0f", BigDecimal.valueOf(pricePerPoint * 12)) %></div>
                                        </div>
                                    </div>
                                </div>
                            </div>

                            <div class="d-flex flex-wrap gap-2">
                                <button type="submit" class="btn btn-primary">
                                    <i class="bi bi-save me-2"></i>Simpan Pengaturan Pembayaran
                                </button>
                                <a href="<%= request.getContextPath() %>/PaymentSettingsServlet?action=checkout" class="btn btn-outline-secondary">
                                    <i class="bi bi-eye me-1"></i>Pratinjau Halaman Checkout Siswa
                                </a>
                            </div>
                        </form>
                    </div>
                </div>
            </div>

            <!-- Panel Informasi Webhook & Aturan Kuota -->
            <div class="col-lg-4">
                <div class="card shadow-sm mb-4">
                    <div class="card-header">
                        <h6 class="mb-0"><i class="bi bi-link-45deg me-2"></i>Endpoint Webhook Pembayaran</h6>
                    </div>
                    <div class="card-body">
                        <p class="small text-muted mb-2">Salin URL berikut ke dashboard <strong>Gerbang Pembayaran</strong> untuk menerima pembaruan status transaksi secara otomatis:</p>
                        <div class="input-group input-group-sm mb-3">
                            <input type="text" class="form-control font-monospace" id="webhookUrlInput" value="<%= ValidationUtil.sanitizeHtml(webhookUrl) %>" readonly>
                            <button class="btn btn-outline-primary" type="button" onclick="copyWebhookUrl()" title="Salin URL">
                                <i class="bi bi-clipboard"></i>
                            </button>
                        </div>
                        <div class="small text-muted">
                            <strong>Event yang didukung:</strong>
                            <ul class="mb-0 mt-1 ps-3">
                                <li><code>payment.completed</code> &rarr; status <strong>Berhasil</strong> + tambah poin</li>
                                <li><code>payment.failed</code> &rarr; status <strong>Gagal</strong></li>
                                <li><code>payment.expired</code> &rarr; status <strong>Gagal</strong></li>
                            </ul>
                        </div>
                    </div>
                </div>

                <div class="card shadow-sm">
                    <div class="card-header">
                        <h6 class="mb-0"><i class="bi bi-info-circle me-2"></i>Aturan Dompet Kuota</h6>
                    </div>
                    <div class="card-body small text-muted">
                        <ul class="list-unstyled mb-0">
                            <li class="mb-2"><i class="bi bi-check-circle-fill text-success me-2"></i>Saldo maksimal siswa: <strong>12 poin / bulan</strong>.</li>
                            <li class="mb-2"><i class="bi bi-check-circle-fill text-success me-2"></i>Setiap sesi <strong>Exam</strong> atau <strong>Google Meet</strong> memotong <strong>1 poin</strong>.</li>
                            <li class="mb-2"><i class="bi bi-check-circle-fill text-success me-2"></i>Saldo tidak diakumulasi (<em>non-rollover</em>) dan otomatis reset ke <strong>0</strong> setiap <strong>tanggal 1 pukul 00:00 WIB</strong>.</li>
                            <li><i class="bi bi-check-circle-fill text-success me-2"></i>Jika API Key belum diisi, siswa melihat pesan bahwa sistem pembayaran sedang dikonfigurasi pengajar.</li>
                        </ul>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.2/dist/js/bootstrap.bundle.min.js"></script>
    <script>
        function toggleSecret(inputId, btn) {
            const input = document.getElementById(inputId);
            const icon = btn.querySelector('i');
            if (input.type === 'password') {
                input.type = 'text';
                icon.className = 'bi bi-eye-slash';
            } else {
                input.type = 'password';
                icon.className = 'bi bi-eye';
            }
        }
        function updateModeCards() {
            const isLive = document.getElementById('modeLive').checked;
            document.getElementById('cardSandbox').classList.toggle('selected', !isLive);
            document.getElementById('cardLive').classList.toggle('selected', isLive);
        }
        function formatRupiah(num) {
            return 'Rp ' + Math.round(num).toLocaleString('id-ID');
        }
        function updatePricePreview() {
            const unit = parseFloat(document.getElementById('dummyPricePerPoint').value) || 0;
            document.getElementById('preview4').textContent = formatRupiah(unit * 4);
            document.getElementById('preview8').textContent = formatRupiah(unit * 8);
            document.getElementById('preview12').textContent = formatRupiah(unit * 12);
        }
        function copyWebhookUrl() {
            const input = document.getElementById('webhookUrlInput');
            input.select();
            navigator.clipboard?.writeText(input.value);
        }
    </script>
</body>
</html>
