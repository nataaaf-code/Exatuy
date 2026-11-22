<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%@ page import="com.examora.model.User" %>
<%@ page import="com.examora.model.PaymentSetting" %>
<%@ page import="com.examora.model.CashInTransaction" %>
<%@ page import="com.examora.util.ValidationUtil" %>
<%@ page import="java.util.List" %>
<%@ page import="java.math.BigDecimal" %>
<%
    User currentUser = (User) session.getAttribute("user");
    if (currentUser == null) {
        response.sendRedirect("../LoginServlet");
        return;
    }

    PaymentSetting setting = (PaymentSetting) request.getAttribute("paymentSetting");
    if (setting == null) setting = new PaymentSetting();
    Integer currentBalanceAttr = (Integer) request.getAttribute("currentBalance");
    Integer maxQuotaAttr = (Integer) request.getAttribute("maxQuota");
    Integer remainingCapAttr = (Integer) request.getAttribute("remainingCapacity");
    @SuppressWarnings("unchecked")
    List<CashInTransaction> transactions = (List<CashInTransaction>) request.getAttribute("transactions");
    if (transactions == null) transactions = java.util.Collections.emptyList();

    int currentBalance = currentBalanceAttr != null ? currentBalanceAttr : currentUser.getQuotaBalance();
    int maxQuota = maxQuotaAttr != null ? maxQuotaAttr : setting.getMaxQuotaPerMonth();
    int remainingCapacity = remainingCapAttr != null ? remainingCapAttr : Math.max(0, maxQuota - currentBalance);
    long unitPrice = setting.getDummyPricePerPoint().longValue();
    int balancePct = maxQuota > 0 ? Math.min(100, (int) Math.round(currentBalance * 100.0 / maxQuota)) : 0;

    String success = (String) session.getAttribute("flashSuccess");
    String error = (String) session.getAttribute("flashError");
    if (success != null) session.removeAttribute("flashSuccess");
    if (error != null) session.removeAttribute("flashError");
%>
<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Beli Paket Kuota - Exatuy</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.2/dist/css/bootstrap.min.css" rel="stylesheet">
    <link href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.1/font/bootstrap-icons.css" rel="stylesheet">
    <link href="<%= request.getContextPath() %>/assets/css/style.css" rel="stylesheet">
    <link href="<%= request.getContextPath() %>/assets/css/handdrawn.css" rel="stylesheet">
    <link rel="icon" type="image/svg+xml" href="<%= request.getContextPath() %>/assets/img/favicon.svg?v=4">
    <style>
        .pkg-card {
            border: 2px solid #dee2e6;
            border-radius: 16px;
            padding: 1.25rem;
            cursor: pointer;
            transition: all 0.2s ease;
            height: 100%;
        }
        .pkg-card:hover:not(.pkg-disabled) {
            border-color: #4A90D9;
            transform: translateY(-3px);
        }
        .pkg-card.pkg-selected {
            border-color: #4A90D9 !important;
            background: rgba(74, 144, 217, 0.08) !important;
        }
        .pkg-card.pkg-disabled {
            opacity: 0.55;
            cursor: not-allowed;
        }
    </style>
</head>
<body>
    <!-- Navbar -->
    <%@ include file="navbar.jspf" %>

    <div class="container py-4">
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

        <!-- Dompet Kuota & Countdown Reset -->
        <div class="card mb-4">
            <div class="card-body">
                <div class="row align-items-center g-3">
                    <div class="col-md-7">
                        <div class="d-flex align-items-center gap-2 mb-2 flex-wrap">
                            <h4 class="mb-0 fw-bold"><i class="bi bi-wallet2 text-primary me-2"></i>Dompet Kuota Belajar</h4>
                            <span class="badge <%= currentBalance == 0 ? "bg-danger text-white" : (currentBalance <= 3 ? "bg-warning text-dark" : "bg-success text-white") %> fs-6">
                                <%= currentBalance %> / <%= maxQuota %> Poin
                            </span>
                        </div>
                        <div class="progress mb-2" style="height: 12px;">
                            <div class="progress-bar <%= currentBalance == 0 ? "bg-danger" : (currentBalance <= 3 ? "bg-warning" : "bg-success") %>"
                                 style="width: <%= balancePct %>%"></div>
                        </div>
                        <small class="text-muted">
                            Sisa kapasitas top-up bulan ini: <strong><%= remainingCapacity %> poin</strong> (maks. <%= maxQuota %> poin aktif).
                        </small>
                    </div>
                    <div class="col-md-5 text-md-end">
                        <div class="p-3 rounded bg-light border d-inline-block text-start">
                            <div class="small text-muted mb-1">
                                <i class="bi bi-clock-history me-1 text-warning"></i>Reset Otomatis Tanggal 1 (00:00 WIB)
                            </div>
                            <div class="fw-bold text-primary fs-6" id="checkoutResetCountdown">Menghitung...</div>
                            <div class="text-muted" style="font-size:0.75rem;">Sisa poin tidak diakumulasi ke bulan depan</div>
                        </div>
                    </div>
                </div>
            </div>
        </div>

        <% if (!setting.isConfigured()) { %>
        <!-- PRD FR-007 Error Handling: API Key not configured -->
        <div class="alert alert-warning d-flex align-items-start gap-3 mb-4">
            <i class="bi bi-gear-wide-connected fs-3 flex-shrink-0"></i>
            <div>
                <h6 class="fw-bold mb-1">Sistem Pembayaran Sedang dalam Konfigurasi Pengajar</h6>
                <p class="mb-0 small">
                    Pengajar belum mengaktifkan kunci pembayaran online. Silakan hubungi pengajar Bimbel Mentari untuk informasi pengisian kuota belajar.
                </p>
            </div>
        </div>
        <% } else if (remainingCapacity <= 0) { %>
        <div class="alert alert-success d-flex align-items-center gap-3 mb-4">
            <i class="bi bi-check-circle-fill fs-3"></i>
            <div>
                <h6 class="fw-bold mb-1">Saldo Kuota Sudah Penuh (<%= currentBalance %> / <%= maxQuota %> Poin)!</h6>
                <p class="mb-0 small">Anda sudah mencapai batas maksimal <%= maxQuota %> poin bulan ini. Gunakan kuota Anda untuk mengikuti Exam atau sesi Google Meet.</p>
            </div>
        </div>
        <% } else { %>
        <!-- Form Checkout Paket Kuota -->
        <form method="post" action="<%= request.getContextPath() %>/PaymentSettingsServlet" id="checkoutForm">
            <input type="hidden" name="csrfToken" value="<%= session.getAttribute("csrfToken") %>">
            <input type="hidden" name="action" value="createOrder">

            <div class="row g-4 mb-4">
                <div class="col-lg-8">
                    <div class="card h-100">
                        <div class="card-header">
                            <h5 class="mb-0"><i class="bi bi-bag-check me-2"></i>1. Pilih Paket Kuota</h5>
                        </div>
                        <div class="card-body">
                            <div class="row g-3 mb-4">
                                <% int[] presets = {4, 8, 12};
                                   String[] labels = {"Paket Hemat", "Paket Reguler", "Paket Maksimal"};
                                   for (int i = 0; i < presets.length; i++) {
                                       int pts = presets[i];
                                       boolean allowed = pts <= remainingCapacity;
                                       BigDecimal pkgPrice = setting.calculatePackagePrice(pts);
                                %>
                                <div class="col-sm-4">
                                    <div class="pkg-card text-center <%= !allowed ? "pkg-disabled" : "" %>"
                                         id="pkgCard<%= pts %>"
                                         onclick="<%= allowed ? "selectPreset(" + pts + ")" : "" %>">
                                        <div class="small text-muted fw-semibold"><%= labels[i] %></div>
                                        <div class="fs-3 fw-bold text-primary my-1"><%= pts %> Poin</div>
                                        <div class="fw-bold">Rp <%= String.format("%,.0f", pkgPrice) %></div>
                                        <% if (!allowed) { %>
                                        <div class="badge bg-secondary mt-2">Melebihi batas 12 poin</div>
                                        <% } else { %>
                                        <div class="small text-muted mt-2">Rp <%= String.format("%,.0f", setting.getDummyPricePerPoint()) %> / poin</div>
                                        <% } %>
                                    </div>
                                </div>
                                <% } %>
                            </div>

                            <!-- Custom Points -->
                            <div class="border rounded p-3 bg-light">
                                <label for="pointsInput" class="form-label fw-bold mb-1">
                                    Atau Masukkan Jumlah Poin Kustom (1 &ndash; <%= remainingCapacity %> Poin)
                                </label>
                                <div class="input-group">
                                    <input type="number" class="form-control" id="pointsInput" name="points"
                                           min="1" max="<%= remainingCapacity %>"
                                           value="<%= Math.min(4, remainingCapacity) %>" required oninput="updateOrderSummary()">
                                    <span class="input-group-text">Poin</span>
                                </div>
                                <div class="form-text" id="capacityHint">
                                    Saldo setelah top-up: <strong id="afterBalance"><%= currentBalance + Math.min(4, remainingCapacity) %></strong> / <%= maxQuota %> Poin.
                                </div>
                            </div>
                        </div>
                    </div>
                </div>

                <!-- Ringkasan & Metode Pembayaran -->
                <div class="col-lg-4">
                    <div class="card h-100">
                        <div class="card-header">
                            <h5 class="mb-0"><i class="bi bi-credit-card me-2"></i>2. Ringkasan Bayar</h5>
                        </div>
                        <div class="card-body d-flex flex-column">
                            <div class="mb-3">
                                <label class="form-label fw-bold small">Metode Pembayaran</label>
                                <div class="form-check mb-2">
                                    <input class="form-check-input" type="radio" name="paymentMethod" id="methodQris" value="QRIS" checked>
                                    <label class="form-check-label fw-semibold" for="methodQris">
                                        <i class="bi bi-qr-code-scan me-1 text-primary"></i>QRIS (Instan)
                                    </label>
                                </div>
                                <div class="form-check">
                                    <input class="form-check-input" type="radio" name="paymentMethod" id="methodVa" value="Virtual Account">
                                    <label class="form-check-label fw-semibold" for="methodVa">
                                        <i class="bi bi-bank me-1 text-primary"></i>Virtual Account Bank
                                    </label>
                                </div>
                            </div>

                            <hr>
                            <div class="d-flex justify-content-between mb-2">
                                <span class="text-muted">Jumlah Poin</span>
                                <strong id="summaryPoints"><%= Math.min(4, remainingCapacity) %> Poin</strong>
                            </div>
                            <div class="d-flex justify-content-between mb-2">
                                <span class="text-muted">Tarif per Poin</span>
                                <span>Rp <%= String.format("%,.0f", setting.getDummyPricePerPoint()) %></span>
                            </div>
                            <div class="d-flex justify-content-between mb-3 fs-5">
                                <span class="fw-bold">Total Bayar</span>
                                <strong class="text-primary" id="summaryTotal">
                                    Rp <%= String.format("%,.0f", setting.calculatePackagePrice(Math.min(4, remainingCapacity))) %>
                                </strong>
                            </div>

                            <div class="mt-auto">
                                <button type="submit" class="btn btn-primary w-100 py-2">
                                    <i class="bi bi-shield-check me-2"></i>Bayar Online (<%= setting.isLiveMode() ? "Live" : "Sandbox" %>)
                                </button>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </form>
        <% } %>

        <!-- Riwayat Pembelian Kuota Siswa -->
        <div class="card">
            <div class="card-header">
                <h6 class="mb-0"><i class="bi bi-clock-history me-2"></i>Riwayat Pembelian Kuota Anda</h6>
            </div>
            <div class="card-body p-0">
                <% if (transactions.isEmpty()) { %>
                <div class="text-center py-4 text-muted">
                    <i class="bi bi-receipt fs-2 d-block mb-2 opacity-50"></i>
                    Belum ada riwayat pembelian kuota.
                </div>
                <% } else { %>
                <div class="table-responsive">
                    <table class="table table-hover align-middle mb-0">
                        <thead>
                            <tr>
                                <th>No. Invoice</th>
                                <th class="text-center">Poin</th>
                                <th class="text-end">Nominal</th>
                                <th class="text-center">Metode</th>
                                <th class="text-center">Status</th>
                                <th>Tanggal</th>
                            </tr>
                        </thead>
                        <tbody>
                            <% for (CashInTransaction tx : transactions) { %>
                            <tr>
                                <td class="font-monospace fw-bold small"><%= ValidationUtil.sanitizeHtml(tx.getOrderId()) %></td>
                                <td class="text-center"><span class="badge bg-primary bg-opacity-10 text-primary">+<%= tx.getPointsPurchased() %> Poin</span></td>
                                <td class="text-end fw-bold">Rp <%= String.format("%,.0f", tx.getAmount()) %></td>
                                <td class="text-center small"><%= ValidationUtil.sanitizeHtml(tx.getPaymentMethod() != null ? tx.getPaymentMethod() : "QRIS") %></td>
                                <td class="text-center"><span class="badge <%= tx.getStatusBadgeClass() %>"><%= tx.getStatusLabel() %></span></td>
                                <td class="small text-muted"><%= tx.getFormattedCreatedAt() %></td>
                            </tr>
                            <% } %>
                        </tbody>
                    </table>
                </div>
                <% } %>
            </div>
        </div>
    </div>

    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.2/dist/js/bootstrap.bundle.min.js"></script>
    <script>
        const unitPrice = <%= unitPrice %>;
        const currentBalance = <%= currentBalance %>;
        const maxQuota = <%= maxQuota %>;
        const remainingCapacity = <%= remainingCapacity %>;

        function selectPreset(pts) {
            if (pts > remainingCapacity) return;
            const input = document.getElementById('pointsInput');
            if (input) {
                input.value = pts;
                updateOrderSummary();
            }
        }

        function updateOrderSummary() {
            const input = document.getElementById('pointsInput');
            if (!input) return;
            let pts = parseInt(input.value, 10) || 1;
            if (pts < 1) pts = 1;
            if (pts > remainingCapacity) pts = remainingCapacity;

            [4, 8, 12].forEach(p => {
                const card = document.getElementById('pkgCard' + p);
                if (card) card.classList.toggle('pkg-selected', p === pts);
            });

            document.getElementById('summaryPoints').textContent = pts + ' Poin';
            document.getElementById('summaryTotal').textContent = 'Rp ' + (pts * unitPrice).toLocaleString('id-ID');
            document.getElementById('afterBalance').textContent = currentBalance + pts;
        }

        // Countdown to 1st of next month 00:00 WIB (UTC+7)
        function updateResetCountdown() {
            const el = document.getElementById('checkoutResetCountdown');
            if (!el) return;
            const nowUtcMs = Date.now();
            const wibOffsetMs = 7 * 60 * 60 * 1000;
            const nowWib = new Date(nowUtcMs + wibOffsetMs);
            const nextResetWibMs = Date.UTC(nowWib.getUTCFullYear(), nowWib.getUTCMonth() + 1, 1, 0, 0, 0) - wibOffsetMs;
            const diff = Math.max(0, nextResetWibMs - nowUtcMs);
            const days = Math.floor(diff / 86400000);
            const hours = Math.floor((diff % 86400000) / 3600000);
            const mins = Math.floor((diff % 3600000) / 60000);
            const secs = Math.floor((diff % 60000) / 1000);
            el.textContent = days + ' hari ' + String(hours).padStart(2, '0') + 'j '
                + String(mins).padStart(2, '0') + 'm ' + String(secs).padStart(2, '0') + 'd';
        }

        document.addEventListener('DOMContentLoaded', function() {
            updateOrderSummary();
            updateResetCountdown();
            setInterval(updateResetCountdown, 1000);
        });
    </script>
</body>
</html>
