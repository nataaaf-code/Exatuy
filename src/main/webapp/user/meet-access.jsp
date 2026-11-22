<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%@ page import="com.examora.util.ValidationUtil" %>
<%@ page import="com.examora.service.QuotaService" %>
<%
    com.examora.model.User currentUser = (com.examora.model.User) session.getAttribute("user");
    if (currentUser == null) { response.sendRedirect("../LoginServlet"); return; }

    String meetUrl = (String) request.getAttribute("meetUrl");
    String meetTitle = (String) request.getAttribute("meetTitle");
    String meetSchedule = (String) request.getAttribute("meetSchedule");
    Boolean available = (Boolean) request.getAttribute("meetAvailable");
    Boolean unlocked = (Boolean) request.getAttribute("unlocked");
    Boolean adminViewer = (Boolean) request.getAttribute("isAdminViewer");
    int quotaBalance = currentUser.getQuotaBalance();
    String ctx = request.getContextPath();
    String flashSuccess = (String) session.getAttribute("flashSuccess");
    if (flashSuccess != null) { session.removeAttribute("flashSuccess"); }
    String flashError = (String) session.getAttribute("flashError");
    if (flashError != null) { session.removeAttribute("flashError"); }
    boolean showLink = Boolean.TRUE.equals(unlocked) || Boolean.TRUE.equals(adminViewer);
%>
<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Sesi Google Meet - Exatuy</title>
    <link href="../assets/vendor/bootstrap.min.css" rel="stylesheet">
    <link href="../assets/vendor/bootstrap-icons.css" rel="stylesheet">
    <link href="../assets/css/handdrawn.css" rel="stylesheet">
</head>
<body class="bg-light">
<%@ include file="navbar.jspf" %>

<div class="container py-4" style="max-width: 640px;">
    <% if (flashSuccess != null) { %>
    <div class="alert alert-success"><i class="bi bi-check-circle me-2"></i><%= ValidationUtil.sanitizeHtml(flashSuccess) %></div>
    <% } %>
    <% if (flashError != null) { %>
    <div class="alert alert-warning"><i class="bi bi-exclamation-triangle me-2"></i><%= ValidationUtil.sanitizeHtml(flashError) %></div>
    <% } %>

    <div class="card border-0 shadow-sm">
        <div class="card-body">
            <h1 class="h4 mb-1"><i class="bi bi-camera-video me-2"></i>Sesi Google Meet</h1>
            <p class="text-muted small mb-3"><%= ValidationUtil.sanitizeHtml(meetTitle == null ? "Sesi Belajar" : meetTitle) %>
                <% if (meetSchedule != null && !meetSchedule.isBlank()) { %>
                &middot; <i class="bi bi-clock me-1"></i><%= ValidationUtil.sanitizeHtml(meetSchedule) %>
                <% } %>
            </p>

            <% if (!Boolean.TRUE.equals(available)) { %>
            <div class="text-center py-4">
                <i class="bi bi-calendar-x fs-1 text-muted opacity-50 d-block mb-2"></i>
                <p class="mb-1 fw-semibold">Belum ada tautan sesi untuk kelas Anda</p>
                <p class="text-muted small mb-0">Pengajar belum membuat jadwal Google Meet untuk kelas ini. Silakan cek kembali nanti.</p>
            </div>
            <% } else if (showLink) { %>
            <div class="alert alert-success small mb-3">
                <i class="bi bi-unlock me-1"></i>Akses hari ini sudah terbuka.
                Masuk kembali ke tautan yang sama tidak memotong poin lagi.
            </div>
            <div class="border rounded p-3 mb-3 bg-white">
                <div class="text-muted small mb-1">Tautan sesi</div>
                <a href="<%= ValidationUtil.sanitizeHtml(meetUrl) %>" target="_blank" rel="noopener noreferrer"
                   class="text-decoration-none fw-semibold d-block text-truncate">
                    <i class="bi bi-box-arrow-up-right me-1"></i><%= ValidationUtil.sanitizeHtml(meetUrl) %>
                </a>
                <button class="btn btn-sm btn-outline-secondary mt-2"
                        onclick="navigator.clipboard.writeText(this.previousElementSibling.href); this.textContent='Tautan tersalin';">
                    <i class="bi bi-clipboard me-1"></i>Salin tautan
                </button>
            </div>
            <a href="<%= ValidationUtil.sanitizeHtml(meetUrl) %>" target="_blank" rel="noopener noreferrer"
               class="btn btn-primary w-100">
                <i class="bi bi-box-arrow-up-right me-1"></i>Buka Google Meet
            </a>
            <% } else { %>
            <div class="alert <%= quotaBalance >= 1 ? "alert-info" : "alert-warning" %> small">
                <i class="bi bi-wallet2 me-1"></i>
                Saldo poin Anda: <strong><%= quotaBalance %> / <%= QuotaService.MAX_QUOTA %></strong>.
                Membuka tautan ini memotong <strong>1 poin sekali per hari WIB</strong>.
                <% if (quotaBalance < 1) { %>
                Poin habis — silakan <a href="<%= ctx %>/PaymentSettingsServlet?action=checkout" class="alert-link">beli paket kuota</a> dulu.
                <% } %>
            </div>
            <form method="post" action="<%= ctx %>/GMeetServlet" class="m-0">
                <input type="hidden" name="csrfToken" value="<%= session.getAttribute("csrfToken") %>">
                <button type="submit" class="btn btn-primary w-100" <%= quotaBalance < 1 ? "disabled" : "" %>>
                    <i class="bi bi-unlock me-1"></i>Tampilkan Tautan (1 Poin)
                </button>
            </form>
            <p class="text-muted small mt-2 mb-0">
                <i class="bi bi-info-circle me-1"></i>Setelah dibuka, tautan yang sama bisa diakses lagi
                dari halaman ini tanpa potongan tambahan sampai pergantian hari WIB.
            </p>
            <% } %>
        </div>
    </div>
</div>
<script src="../assets/vendor/bootstrap.bundle.min.js"></script>
</body>
</html>
