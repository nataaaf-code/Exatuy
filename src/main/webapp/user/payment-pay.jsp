<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%@ page import="java.math.BigDecimal" %>
<%@ page import="com.examora.util.ValidationUtil" %>
<%@ page import="com.examora.util.DBUtil" %>
<%@ page import="com.examora.model.User" %>
<%
    User currentUser = (User) session.getAttribute("user");
    if (currentUser == null) { response.sendRedirect("../LoginServlet"); return; }

    String orderId = (String) request.getAttribute("orderId");
    String method = (String) request.getAttribute("paymentMethod");
    BigDecimal amount = (BigDecimal) request.getAttribute("amount");
    String qrString = (String) request.getAttribute("qrString");
    String vaNumber = (String) request.getAttribute("vaNumber");
    String status = (String) request.getAttribute("status");
    Boolean simulated = (Boolean) request.getAttribute("simulated");
    String payMethod = (String) request.getAttribute("paymentMethod");
    boolean isVa = payMethod != null && payMethod.toLowerCase().contains("virtual");
    String ctx = request.getContextPath();
    String flashError = (String) session.getAttribute("flashError");
    if (flashError != null) { session.removeAttribute("flashError"); }
    String flashSuccess = (String) session.getAttribute("flashSuccess");
    if (flashSuccess != null) { session.removeAttribute("flashSuccess"); }
    boolean paid = "completed".equalsIgnoreCase(status);
    boolean failed = "failed".equalsIgnoreCase(status);
    boolean canSelfConfirm = Boolean.TRUE.equals(request.getAttribute("canSelfConfirm"));
    String paymentUrl = (String) request.getAttribute("paymentUrl");
%>
<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Pembayaran Kuota - Exatuy</title>
    <link href="../assets/vendor/bootstrap.min.css" rel="stylesheet">
    <link href="../assets/vendor/bootstrap-icons.css" rel="stylesheet">
    <link href="../assets/css/style.css" rel="stylesheet">
    <link href="../assets/css/handdrawn.css" rel="stylesheet">
</head>
<body class="bg-light">
<%@ include file="navbar.jspf" %>

<div class="container py-4" style="max-width: 620px;">
    <% if (flashSuccess != null) { %>
    <div class="alert alert-success"><i class="bi bi-check-circle me-2"></i><%= ValidationUtil.sanitizeHtml(flashSuccess) %></div>
    <% } %>
    <% if (flashError != null) { %>
    <div class="alert alert-danger"><i class="bi bi-exclamation-triangle me-2"></i><%= ValidationUtil.sanitizeHtml(flashError) %></div>
    <% } %>

    <div class="card border-0 shadow-sm">
        <div class="card-header bg-white border-0 pb-0">
            <h1 class="h4 mb-1"><i class="bi bi-credit-card me-2"></i>Pembayaran Kuota</h1>
            <p class="text-muted small mb-0">Pesanan <span class="font-monospace"><%= ValidationUtil.sanitizeHtml(orderId) %></span></p>
        </div>
        <div class="card-body">

            <div class="d-flex justify-content-between align-items-center border rounded p-3 mb-3">
                <div>
                    <div class="text-muted small">Total tagihan</div>
                    <div class="fs-4 fw-bold">Rp <%= String.format("%,.0f", amount) %></div>
                </div>
                <span class="badge <%= paid ? "bg-success" : (failed ? "bg-danger" : "bg-warning text-dark") %>">
                    <%= paid ? "Lunas" : (failed ? "Kedaluwarsa / gagal" : "Menunggu pembayaran") %>
                </span>
            </div>

            <% if (failed) { %>
                <div class="text-center py-3">
                    <i class="bi bi-x-circle-fill text-danger fs-1"></i>
                    <p class="mt-2 mb-1 fw-semibold">Pesanan tidak dibayar</p>
                    <p class="text-muted small">Batas waktu pembayaran sudah lewat atau pembayaran gagal. Silakan buat pesanan baru.</p>
                    <a href="<%= ctx %>/PaymentSettingsServlet?action=checkout" class="btn btn-primary">
                        <i class="bi bi-wallet2 me-1"></i>Buat Pesanan Baru
                    </a>
                </div>
            <% } else if (!paid) { %>
                <% if (paymentUrl != null && paymentUrl.startsWith("https://")) { %>
                <div class="d-grid mb-3">
                    <a href="<%= ValidationUtil.sanitizeHtml(paymentUrl) %>" target="_blank" rel="noopener" class="btn btn-success">
                        <i class="bi bi-box-arrow-up-right me-1"></i>Buka Halaman Pembayaran
                    </a>
                </div>
                <% } %>
                <% if (isVa && vaNumber != null) { %>
                <div class="text-center mb-3">
                    <p class="mb-1 text-muted small">Nomor Virtual Account</p>
                    <div class="fs-4 font-monospace fw-bold"><%= ValidationUtil.sanitizeHtml(vaNumber) %></div>
                    <button class="btn btn-sm btn-outline-secondary mt-2"
                            onclick="navigator.clipboard.writeText('<%= ValidationUtil.sanitizeHtml(vaNumber) %>'); this.textContent='Tersalin';">
                        <i class="bi bi-clipboard me-1"></i>Salin nomor
                    </button>
                </div>
                <div class="alert alert-info small">
                    <i class="bi bi-info-circle me-1"></i>
                    Transfer sesuai nominal <strong>tepat</strong> ke nomor di atas lewat aplikasi bank/e-wallet Anda.
                </div>
                <% } else if (qrString != null) { %>
                <div class="text-center mb-3">
                    <p class="mb-2 text-muted small">Pindai QRIS berikut dengan aplikasi bank / e-wallet</p>
                    <div id="qrcode" class="d-inline-block bg-white p-3 border rounded"></div>
                    <div class="mt-2">
                        <textarea class="form-control form-control-sm font-monospace" rows="3" readonly
                                  id="qrisPayload"><%= ValidationUtil.sanitizeHtml(qrString) %></textarea>
                        <button class="btn btn-sm btn-outline-secondary mt-1"
                                onclick="navigator.clipboard.writeText(document.getElementById('qrisPayload').value); this.textContent='Payload tersalin';">
                            <i class="bi bi-clipboard me-1"></i>Salin payload QRIS
                        </button>
                    </div>
                </div>
                <% } else if (paymentUrl == null) { %>
                <div class="alert alert-warning">Instruksi pembayaran tidak tersedia. Hubungi pengajar.</div>
                <% } %>

                <div class="d-flex gap-2">
                    <a href="<%= ctx %>/PaymentSettingsServlet?action=checkout" class="btn btn-outline-secondary flex-fill">
                        <i class="bi bi-arrow-left me-1"></i>Kembali
                    </a>
                    <% if (canSelfConfirm) { %>
                    <form method="post" action="<%= ctx %>/PaymentSettingsServlet" class="flex-fill m-0">
                        <input type="hidden" name="action" value="confirmPayment">
                        <input type="hidden" name="orderId" value="<%= ValidationUtil.sanitizeHtml(orderId) %>">
                        <input type="hidden" name="csrfToken" value="<%= session.getAttribute("csrfToken") %>">
                        <button type="submit" class="btn btn-primary w-100">
                            <i class="bi bi-check2-circle me-1"></i>Saya sudah membayar
                        </button>
                    </form>
                    <% } else { %>
                    <a href="<%= ctx %>/PaymentSettingsServlet?action=pay&orderId=<%= java.net.URLEncoder.encode(orderId, "UTF-8") %>" class="btn btn-primary flex-fill">
                        <i class="bi bi-arrow-repeat me-1"></i>Cek status pembayaran
                    </a>
                    <% } %>
                </div>

                <% if (canSelfConfirm) { %>
                <p class="text-muted small mt-3 mb-0">
                    <i class="bi bi-info-circle me-1"></i>
                    Mode demo: tagihan ini simulasi, sehingga tombol
                    "Saya sudah membayar" langsung menandai pesanan lunas dan menambah poin.
                </p>
                <% } else { %>
                <p class="text-muted small mt-3 mb-0">
                    <i class="bi bi-info-circle me-1"></i>
                    Status pesanan diperbarui otomatis setelah pembayaran diterima.
                </p>
                <% } %>
            <% } else { %>
                <div class="text-center py-3">
                    <i class="bi bi-check-circle-fill text-success fs-1"></i>
                    <p class="mt-2 mb-1 fw-semibold">Pembayaran berhasil</p>
                    <p class="text-muted small">Poin sudah ditambahkan ke dompet kuota Anda.</p>
                    <a href="<%= ctx %>/PaymentSettingsServlet?action=checkout" class="btn btn-primary">
                        <i class="bi bi-wallet2 me-1"></i>Lihat Dompet Kuota
                    </a>
                </div>
            <% } %>
        </div>
    </div>
</div>

<script src="../assets/vendor/bootstrap.bundle.min.js"></script>
<% if (!paid && !failed && (qrString != null) && !isVa) { %>
<script src="../assets/vendor/qrcode.min.js"></script>
<script>
    (function () {
        var el = document.getElementById('qrcode');
        var payload = document.getElementById('qrisPayload').value;
        if (window.QRCode && el) {
            new QRCode(el, { text: payload, width: 220, height: 220, correctLevel: QRCode.CorrectLevel.M });
        } else if (el) {
            el.textContent = 'QR tidak dapat dirender — gunakan payload di bawah.';
        }
    })();
</script>
<% } %>
</body>
</html>
