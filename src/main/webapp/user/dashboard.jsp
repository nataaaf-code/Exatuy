<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%@ page import="com.examora.model.User" %>
<%@ page import="com.examora.model.Quiz" %>
<%@ page import="com.examora.model.Submission" %>
<%@ page import="com.examora.model.InformationBoard" %>
<%@ page import="com.examora.model.CustomPage" %>
<%@ page import="com.examora.service.ChatService" %>
<%@ page import="com.examora.dao.SettingsDAO" %>
<%@ page import="java.util.List" %>
<%@ page import="java.util.Map" %>
<%@ page import="com.examora.util.ValidationUtil" %>
<%
    User currentUser = (User) session.getAttribute("user");
    if (currentUser == null) {
        response.sendRedirect("../LoginServlet");
        return;
    }
    if (currentUser.isAdmin()) {
        response.sendRedirect("../AdminServlet?action=dashboard");
        return;
    }
    List<Quiz> quizzes = (List<Quiz>) request.getAttribute("quizzes");
    Map<Integer, Submission> userSubmissions = (Map<Integer, Submission>) request.getAttribute("userSubmissions");
    List<Submission> recentSubmissions = (List<Submission>) request.getAttribute("recentSubmissions");
    List<InformationBoard> informationBoards = (List<InformationBoard>) request.getAttribute("informationBoards");
    List<CustomPage> customPages = (List<CustomPage>) request.getAttribute("customPages");
    String success = (String) request.getAttribute("success");
    String error = (String) request.getAttribute("error");
    String gdriveLink = currentUser.getGdriveLink() != null ? currentUser.getGdriveLink().trim() : "";
    boolean hasSafeGdriveLink = gdriveLink.startsWith("https://drive.google.com/") || gdriveLink.startsWith("https://docs.google.com/");

    // Check if chat is enabled
    boolean chatEnabled = new SettingsDAO().isChatEnabled();

    // Check if file management is enabled
    boolean fileManagementEnabled = new SettingsDAO().isFileManagementEnabled();

    // Check if leaderboard is published/visible to peserta
    boolean leaderboardPublished = new SettingsDAO().isLeaderboardPublished();

    // Get unread chat count
    int chatUnreadCount = 0;
    if (chatEnabled) {
        try {
            chatUnreadCount = new ChatService().getUnreadCountForUser(currentUser.getId());
        } catch (Exception e) {
            // Ignore errors
        }
    }

    // Student Quota Balance (P1 #18 - Max 12 Poin / bulan)
    int quotaBalance = currentUser.getQuotaBalance();
    int maxQuota = 12;
    String quotaBadgeClass = quotaBalance == 0 ? "bg-danger text-white" : (quotaBalance <= 3 ? "bg-warning text-dark" : "bg-success text-white");
%>
<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Dashboard - Exatuy</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
    <link href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.10.0/font/bootstrap-icons.css" rel="stylesheet">
    <link href="../assets/css/style.css" rel="stylesheet">
    <link rel="icon" type="image/svg+xml" type="image/svg+xml" href="../assets/img/favicon.svg?v=3">
<link href="../assets/css/handdrawn.css" rel="stylesheet">
</head>
<body>
    <!-- Navbar -->
    <nav class="navbar navbar-expand-md navbar-dark bg-primary">
        <div class="container">
            <a class="navbar-brand fw-bold" href="../ExamServlet?action=dashboard">
                <i class="bi bi-journal-check me-2"></i>Exatuy
            </a>
            <button class="navbar-toggler" type="button" data-bs-toggle="collapse" data-bs-target="#navbarNav" aria-controls="navbarNav" aria-expanded="false" aria-label="Toggle navigation">
                <span class="navbar-toggler-icon"></span>
            </button>
            <div class="collapse navbar-collapse" id="navbarNav">
                <ul class="navbar-nav me-auto">
                    <li class="nav-item">
                        <a class="nav-link active" href="../ExamServlet?action=dashboard">
                            <i class="bi bi-house me-1"></i>Dashboard
                        </a>
                    </li>
                    <li class="nav-item">
                        <a class="nav-link" href="../ExamServlet?action=list">
                            <i class="bi bi-journal-text me-1"></i>Quiz Tersedia
                        </a>
                    </li>
                    <li class="nav-item">
                        <a class="nav-link" href="../MateriServlet">
                            <i class="bi bi-book me-1"></i>Materi
                        </a>
                    </li>
                    <li class="nav-item">
                        <a class="nav-link" href="../AttendanceServlet?action=view">
                            <i class="bi bi-check2-square me-1"></i>Absensi
                        </a>
                    </li>
                    <% if (fileManagementEnabled) { %>
                    <li class="nav-item">
                        <a class="nav-link" href="../FileManagementServlet?action=list">
                            <i class="bi bi-folder me-1"></i>Files
                        </a>
                    </li>
                    <% } %>
                    <li class="nav-item">
                        <a class="nav-link" href="../ExamServlet?action=history">
                            <i class="bi bi-clock-history me-1"></i>Riwayat
                        </a>
                    </li>
                    <li class="nav-item">
                        <a class="nav-link" href="../TranscriptServlet?action=mine">
                            <i class="bi bi-card-list me-1"></i>Transcript Nilai
                        </a>
                    </li>
                    <% if (leaderboardPublished) { %>
                    <li class="nav-item">
                        <a class="nav-link" href="../LeaderboardServlet">
                            <i class="bi bi-trophy me-1"></i>Leaderboard
                        </a>
                    </li>
                    <% } %>
                    <% if (chatEnabled) { %>
                    <li class="nav-item">
                        <a class="nav-link" href="../ChatServlet">
                            <i class="bi bi-chat-dots me-1"></i>Chat
                            <% if (chatUnreadCount > 0) { %>
                            <span class="badge bg-danger"><%= chatUnreadCount %></span>
                            <% } %>
                        </a>
                    </li>
                    <% } %>
                    <% if (hasSafeGdriveLink) { %>
                    <li class="nav-item">
                        <a class="nav-link" href="#" data-bs-toggle="modal" data-bs-target="#gdriveModal">
                            <i class="bi bi-google me-1"></i>Google Drive
                        </a>
                    </li>
                    <% } %>
                    <%@ include file="custom-menu-items.jspf" %>
                    <%-- Mobile: Quota Badge + Profile menu items shown in nav list --%>
                    <li class="nav-item d-md-none">
                        <hr class="my-2 border-light">
                    </li>
                    <li class="nav-item d-md-none mb-2">
                        <a href="../PaymentSettingsServlet?action=checkout" class="quota-header-pill d-flex align-items-center justify-content-between text-decoration-none px-3 py-2 rounded">
                            <span>
                                <i class="bi bi-coin me-1"></i>
                                <strong><%= quotaBalance %> / <%= maxQuota %> Poin</strong>
                            </span>
                            <small class="opacity-75"><i class="bi bi-clock me-1"></i><span class="quota-reset-countdown">--</span></small>
                        </a>
                    </li>
                    <li class="nav-item d-md-none">
                        <div class="d-flex align-items-center text-white py-2">
                            <i class="bi bi-person-circle me-2 fs-5"></i>
                            <span><%= ValidationUtil.sanitizeHtml(currentUser.getName()) %></span>
                        </div>
                    </li>
                    <li class="nav-item d-md-none">
                        <a class="nav-link" href="../ProfileServlet">
                            <i class="bi bi-person me-2"></i>Profil Saya
                        </a>
                    </li>
                    <li class="nav-item d-md-none">
                        <a class="nav-link" href="../LogoutServlet">
                            <i class="bi bi-box-arrow-left me-2"></i>Logout
                        </a>
                    </li>
                </ul>
                <%-- Desktop/Tablet: Quota Badge & Countdown + Profile dropdown --%>
                <div class="d-none d-md-flex align-items-center gap-3">
                    <a href="../PaymentSettingsServlet?action=checkout"
                       class="quota-header-pill d-flex align-items-center gap-2 text-decoration-none px-3 py-1 rounded-pill"
                       title="Saldo kuota aktif & hitung mundur reset tanggal 1 pukul 00:00 WIB. Klik untuk isi kuota.">
                        <span class="badge <%= quotaBadgeClass %> rounded-pill px-2 py-1">
                            <i class="bi bi-coin me-1"></i><%= quotaBalance %> / <%= maxQuota %> Poin
                        </span>
                        <small class="text-white d-none d-lg-inline" style="font-size:0.75rem; white-space:nowrap;">
                            <i class="bi bi-arrow-clockwise me-1"></i>Reset: <span class="quota-reset-countdown">--</span>
                        </small>
                    </a>
                    <div class="dropdown">
                        <a href="#" class="d-flex align-items-center text-white text-decoration-none dropdown-toggle" data-bs-toggle="dropdown">
                            <i class="bi bi-person-circle me-1 fs-5"></i>
                            <span><%= ValidationUtil.sanitizeHtml(currentUser.getName()) %></span>
                        </a>
                        <ul class="dropdown-menu dropdown-menu-end">
                            <li><a class="dropdown-item" href="../PaymentSettingsServlet?action=checkout"><i class="bi bi-wallet2 me-2"></i>Dompet Kuota (<%= quotaBalance %>/<%= maxQuota %>)</a></li>
                            <li><a class="dropdown-item" href="../ProfileServlet"><i class="bi bi-person me-2"></i>Profil Saya</a></li>
                            <li><hr class="dropdown-divider"></li>
                            <li><a class="dropdown-item" href="../LogoutServlet"><i class="bi bi-box-arrow-left me-2"></i>Logout</a></li>
                        </ul>
                    </div>
                </div>
            </div>
        </div>
    </nav>

    <!-- Main Content -->
    <div class="container py-4">
        <% if (success != null) { %>
        <div class="alert alert-success alert-dismissible fade show">
            <i class="bi bi-check-circle me-2"></i><%= ValidationUtil.sanitizeHtml(success) %>
            <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
        </div>
        <% } %>

        <% if (error != null) { %>
        <div class="alert alert-danger alert-dismissible fade show">
            <i class="bi bi-exclamation-triangle me-2"></i><%= ValidationUtil.sanitizeHtml(error) %>
            <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
        </div>
        <% } %>

        <!-- Welcome Banner -->
        <div class="card bg-primary text-white mb-4">
            <div class="card-body py-4">
                <div class="row align-items-center">
                    <div class="col-md-8">
                        <h2 class="mb-2">Selamat Datang, <%= ValidationUtil.sanitizeHtml(currentUser.getName()) %>!</h2>
                        <p class="mb-0 opacity-75">Siap untuk memulai ujian? Pilih quiz yang tersedia di bawah ini.</p>
                    </div>
                    <div class="col-md-4 text-end">
                        <i class="bi bi-mortarboard-fill" style="font-size: 4rem; opacity: 0.3;"></i>
                    </div>
                </div>
            </div>
        </div>

        <!-- Information Board (P1 #20 - Always shown with empty state if no announcements) -->
        <div class="mb-4">
            <div class="d-flex align-items-center justify-content-between flex-wrap gap-2 mb-3">
                <div class="d-flex align-items-center">
                    <h5 class="mb-0 me-2"><i class="bi bi-bell me-2 text-primary"></i>Pengumuman & Informasi</h5>
                    <% if (informationBoards != null && !informationBoards.isEmpty()) {
                           long urgentCount = informationBoards.stream().filter(i -> "urgent".equals(i.getPriority())).count();
                           if (urgentCount > 0) { %>
                        <span class="badge bg-danger bg-opacity-10 text-danger"><i class="bi bi-exclamation-circle me-1"></i><%= urgentCount %> Penting</span>
                    <%     }
                       } %>
                </div>
            </div>
            <% if (informationBoards != null && !informationBoards.isEmpty()) { %>
            <div class="row g-3">
                <% for (InformationBoard info : informationBoards) { %>
                <div class="col-12">
                    <div class="card border-0 shadow-sm <% if ("urgent".equals(info.getPriority())) { %>border-start border-4 border-danger<% } else if ("high".equals(info.getPriority())) { %>border-start border-4 border-warning<% } else if ("announcement".equals(info.getInfoType())) { %>border-start border-4 border-primary<% } else { %>border-start border-4 border-info<% } %>">
                        <div class="card-body p-4">
                            <div class="d-flex justify-content-between align-items-start">
                                <div class="flex-grow-1">
                                    <div class="mb-3">
                                        <% if ("announcement".equals(info.getInfoType())) { %>
                                            <span class="badge bg-primary bg-opacity-10 text-primary me-2"><i class="bi bi-megaphone me-1"></i>Pengumuman</span>
                                        <% } else if ("warning".equals(info.getInfoType())) { %>
                                            <span class="badge bg-warning bg-opacity-10 text-dark me-2"><i class="bi bi-exclamation-triangle me-1"></i>Peringatan</span>
                                        <% } else if ("success".equals(info.getInfoType())) { %>
                                            <span class="badge bg-success bg-opacity-10 text-success me-2"><i class="bi bi-check-circle me-1"></i>Informasi</span>
                                        <% } else { %>
                                            <span class="badge bg-info bg-opacity-10 text-info me-2"><i class="bi bi-info-circle me-1"></i>Info</span>
                                        <% } %>
                                        <% if ("urgent".equals(info.getPriority())) { %>
                                            <span class="badge bg-danger"><i class="bi bi-exclamation-circle me-1"></i>Penting</span>
                                        <% } else if ("high".equals(info.getPriority())) { %>
                                            <span class="badge bg-warning text-dark"><i class="bi bi-arrow-up-circle me-1"></i>Menengah</span>
                                        <% } else if ("normal".equals(info.getPriority())) { %>
                                            <span class="badge bg-info"><i class="bi bi-dash-circle me-1"></i>Normal</span>
                                        <% } %>
                                    </div>
                                    <h6 class="fw-bold mb-3 fs-5"><%= ValidationUtil.sanitizeHtml(info.getTitle()) %></h6>
                                    <div class="text-secondary mb-3" style="line-height: 1.6;">
                                        <%= ValidationUtil.sanitizeHtml(info.getContent()) %>
                                    </div>
                                    <small class="text-muted"><i class="bi bi-clock me-1"></i><%= info.getFormattedCreatedAt() %></small>
                                </div>
                                <button type="button" class="btn-close ms-3" data-bs-dismiss="alert" aria-label="Close" onclick="this.closest('.col-12').remove()"></button>
                            </div>
                        </div>
                    </div>
                </div>
                <% } %>
            </div>
            <% } else { %>
            <div class="card border-0 shadow-sm">
                <div class="card-body text-center py-4">
                    <i class="bi bi-megaphone text-muted opacity-50 fs-2 d-block mb-2"></i>
                    <p class="mb-0 text-muted fw-semibold">Belum ada pengumuman baru hari ini.</p>
                </div>
            </div>
            <% } %>
        </div>

        <!-- Available Quizzes -->
        <h4 class="mb-3"><i class="bi bi-journal-text me-2"></i>Quiz Tersedia</h4>

        <% if (quizzes != null && !quizzes.isEmpty()) { %>
        <div class="row g-4 mb-4">
            <% for (Quiz quiz : quizzes) {
                Submission sub = userSubmissions != null ? userSubmissions.get(quiz.getId()) : null;
                boolean hasSubmitted = sub != null && sub.isCompleted();
                boolean isTimeout = sub != null && sub.isTimeout();
            %>
            <div class="col-md-6 col-lg-4">
                <div class="card h-100 quiz-card">
                    <div class="card-body">
                        <div class="d-flex justify-content-between align-items-start mb-2">
                            <h5 class="card-title mb-0"><%= ValidationUtil.sanitizeHtml(quiz.getTitle()) %></h5>
                            <% if (isTimeout) { %>
                            <span class="badge bg-warning text-dark"><i class="bi bi-clock-history me-1"></i>Waktu Habis</span>
                            <% } else if (hasSubmitted) { %>
                            <span class="badge bg-success"><i class="bi bi-check-circle me-1"></i>Selesai</span>
                            <% } else { %>
                            <span class="badge bg-primary"><i class="bi bi-play-circle me-1"></i>Tersedia</span>
                            <% } %>
                        </div>
                        <p class="card-text text-muted small mb-3">
                            <%= ValidationUtil.sanitizeHtml(quiz.getDescription() != null && quiz.getDescription().length() > 80 ?
                                quiz.getDescription().substring(0, 80) + "..." : (quiz.getDescription() != null ? quiz.getDescription() : "Tidak ada deskripsi")) %>
                        </p>
                        <div class="d-flex justify-content-between align-items-center mb-3">
                            <span class="text-muted small">
                                <i class="bi bi-clock me-1"></i><%= quiz.getDuration() %> menit
                            </span>
                            <span class="text-muted small">
                                <i class="bi bi-question-circle me-1"></i><%= quiz.getQuestionCount() %> soal
                            </span>
                        </div>
                        <% if (isTimeout) { %>
                        <div class="alert alert-warning py-2 mb-3 text-center">
                            <i class="bi bi-clock-history me-1"></i>
                            <strong>Waktu Habis!</strong> Nilai: <%= String.format("%.0f", sub.getScore()) %>
                        </div>
                        <div class="alert alert-info py-2 mb-3 text-center">
                            <i class="bi bi-info-circle me-1"></i>
                            <small>Hubungi admin untuk mengizinkan retake quiz ini</small>
                        </div>
                        <a href="../ExamServlet?action=result&submissionId=<%= sub.getId() %>"
                           class="btn btn-outline-warning w-100">
                            <i class="bi bi-eye me-1"></i>Lihat Hasil
                        </a>
                        <% } else if (hasSubmitted) { %>
                        <div class="d-flex gap-2">
                            <a href="../ExamServlet?action=result&submissionId=<%= sub.getId() %>"
                               class="btn btn-outline-primary w-100">
                                <i class="bi bi-eye me-1"></i>Lihat Hasil
                            </a>
                        </div>
                        <div class="text-center mt-2">
                            <strong>Nilai: <%= String.format("%.0f", sub.getScore()) %></strong>
                        </div>
                        <% } else { %>
                        <button type="button" class="btn btn-primary w-100"
                                onclick="showStartQuizModal(<%= quiz.getId() %>, '<%= ValidationUtil.sanitizeHtml(ValidationUtil.sanitizeJs(quiz.getTitle())) %>', <%= quiz.getDuration() %>, <%= quiz.getQuestionCount() %>)">
                            <i class="bi bi-play-fill me-1"></i>Mulai Quiz
                        </button>
                        <% } %>
                    </div>
                </div>
            </div>
            <% } %>
        </div>
        <% } else { %>
        <div class="card">
            <div class="card-body text-center py-5">
                <i class="bi bi-journal-x display-1 text-muted mb-3 d-block"></i>
                <h5 class="text-muted">Belum ada quiz tersedia</h5>
                <p class="text-muted">Quiz akan muncul di sini setelah admin mempublish.</p>
            </div>
        </div>
        <% } %>

        <%-- Expired Quizzes Section --%>
        <%
        List<Quiz> expiredQuizzes = (List<Quiz>) request.getAttribute("expiredQuizzes");
        if (expiredQuizzes != null && !expiredQuizzes.isEmpty()) {
        %>
        <div class="row mt-4">
            <div class="col-12">
                <h4 class="mb-3">
                    <i class="bi bi-calendar-x me-2 text-danger"></i>
                    <span class="text-danger">Quiz Kadaluarsa</span>
                    <span class="badge bg-danger ms-2"><%= expiredQuizzes.size() %></span>
                </h4>
                <div class="alert alert-warning mb-3">
                    <i class="bi bi-exclamation-triangle-fill me-2"></i>
                    <strong>Perhatian:</strong> Quiz berikut sudah melewati batas waktu pengerjaan (deadline) dan tidak dapat dikerjakan lagi.
                    Jika Anda belum sempat mengerjakan, silakan hubungi admin untuk informasi lebih lanjut.
                </div>
            </div>
        </div>
        <div class="row g-4 mb-4">
            <% for (Quiz quiz : expiredQuizzes) {
                Submission sub = userSubmissions != null ? userSubmissions.get(quiz.getId()) : null;
                boolean hasSubmitted = sub != null && sub.isCompleted();
                boolean isTimeout = sub != null && sub.isTimeout();
            %>
            <div class="col-md-6 col-lg-4">
                <div class="card h-100 border-secondary">
                    <div class="card-header bg-secondary text-white">
                        <div class="d-flex justify-content-between align-items-center">
                            <span><%= ValidationUtil.sanitizeHtml(quiz.getTitle()) %></span>
                            <span class="badge bg-danger">
                                <i class="bi bi-calendar-x me-1"></i>Kadaluarsa
                            </span>
                        </div>
                    </div>
                    <div class="card-body">
                        <p class="card-text text-muted small mb-3">
                            <%= ValidationUtil.sanitizeHtml(quiz.getDescription() != null && quiz.getDescription().length() > 80 ?
                                quiz.getDescription().substring(0, 80) + "..." : (quiz.getDescription() != null ? quiz.getDescription() : "Tidak ada deskripsi")) %>
                        </p>
                        <div class="d-flex justify-content-between align-items-center mb-3">
                            <span class="text-muted small">
                                <i class="bi bi-clock me-1"></i><%= quiz.getDuration() %> menit
                            </span>
                            <span class="text-muted small">
                                <i class="bi bi-question-circle me-1"></i><%= quiz.getQuestionCount() %> soal
                            </span>
                        </div>
                        <% if (hasSubmitted) { %>
                        <div class="alert alert-success py-2 mb-3 text-center">
                            <i class="bi bi-check-circle me-1"></i>
                            <strong>Selesai!</strong> Nilai: <%= String.format("%.0f", sub.getScore()) %>
                        </div>
                        <a href="../ExamServlet?action=result&submissionId=<%= sub.getId() %>"
                           class="btn btn-outline-secondary w-100">
                            <i class="bi bi-eye me-1"></i>Lihat Hasil
                        </a>
                        <% } else if (isTimeout) { %>
                        <div class="alert alert-warning py-2 mb-3 text-center">
                            <i class="bi bi-clock-history me-1"></i>
                            <strong>Waktu Habis!</strong> Nilai: <%= String.format("%.0f", sub.getScore()) %>
                        </div>
                        <a href="../ExamServlet?action=result&submissionId=<%= sub.getId() %>"
                           class="btn btn-outline-secondary w-100">
                            <i class="bi bi-eye me-1"></i>Lihat Hasil
                        </a>
                        <% } else { %>
                        <div class="alert alert-danger py-2 mb-3 text-center">
                            <i class="bi bi-x-circle me-1"></i>
                            <strong>Belum Dikerjakan</strong>
                        </div>
                        <button class="btn btn-secondary w-100" disabled>
                            <i class="bi bi-x-lg me-1"></i>Quiz Kadaluarsa
                        </button>
                        <% } %>
                    </div>
                </div>
            </div>
            <% } %>
        </div>
        <% } %>
    </div>

    <!-- Footer -->
    <footer class="bg-light py-3 mt-auto">
        <div class="container text-center">
            <span class="text-muted">&copy; 2026 Exatuy. All rights reserved.</span>
        </div>
    </footer>

    <!-- Start Quiz Confirmation Modal -->
    <div class="modal fade" id="startQuizModal" tabindex="-1">
        <div class="modal-dialog modal-dialog-centered">
            <div class="modal-content border-0 shadow-lg">
                <div class="modal-header bg-primary text-white border-0">
                    <h5 class="modal-title">
                        <i class="bi bi-play-circle me-2"></i>Konfirmasi Mulai Quiz
                    </h5>
                    <button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal"></button>
                </div>
                <div class="modal-body text-center py-4">
                    <div class="mb-4">
                        <div class="bg-primary bg-opacity-10 rounded-circle d-inline-flex align-items-center justify-content-center"
                             style="width: 80px; height: 80px;">
                            <i class="bi bi-journal-check text-primary" style="font-size: 2.5rem;"></i>
                        </div>
                    </div>
                    <h5 class="mb-3" id="modalQuizTitle">Nama Quiz</h5>
                    <div class="row justify-content-center mb-4">
                        <div class="col-auto">
                            <div class="text-center px-3">
                                <i class="bi bi-clock text-primary fs-4"></i>
                                <div class="fw-bold" id="modalQuizDuration">30</div>
                                <small class="text-muted">menit</small>
                            </div>
                        </div>
                        <div class="col-auto">
                            <div class="text-center px-3 border-start">
                                <i class="bi bi-question-circle text-primary fs-4"></i>
                                <div class="fw-bold" id="modalQuizQuestions">10</div>
                                <small class="text-muted">soal</small>
                            </div>
                        </div>
                    </div>
                    <div class="alert alert-warning text-start mb-0">
                        <h6 class="alert-heading mb-2">
                            <i class="bi bi-exclamation-triangle me-2"></i>Perhatian!
                        </h6>
                        <ul class="mb-0 small">
                            <li>Pastikan Anda memiliki waktu yang cukup</li>
                            <li>Quiz tidak dapat dijeda setelah dimulai</li>
                            <li>Pastikan koneksi internet stabil</li>
                            <li>Jangan refresh atau tutup halaman saat mengerjakan</li>
                        </ul>
                    </div>
                </div>
                <div class="modal-footer border-0 bg-light">
                    <button type="button" class="btn btn-outline-secondary px-4" data-bs-dismiss="modal">
                        <i class="bi bi-x-lg me-1"></i>Batal
                    </button>
                    <a href="#" id="startQuizBtn" class="btn btn-primary px-4">
                        <i class="bi bi-play-fill me-1"></i>Mulai Sekarang
                    </a>
                </div>
            </div>
        </div>
    </div>

    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/js/bootstrap.bundle.min.js"></script>
    <script>
        function showStartQuizModal(quizId, title, duration, questions) {
            document.getElementById('modalQuizTitle').textContent = title;
            document.getElementById('modalQuizDuration').textContent = duration;
            document.getElementById('modalQuizQuestions').textContent = questions;
            document.getElementById('startQuizBtn').href = '../ExamServlet?action=start&quizId=' + quizId;

            var modal = new bootstrap.Modal(document.getElementById('startQuizModal'));
            modal.show();
        }

        // P1 #18: Live countdown to 1st of next month 00:00 WIB (UTC+7)
        (function initQuotaResetCountdown() {
            function tick() {
                var els = document.querySelectorAll('.quota-reset-countdown');
                if (!els.length) return;
                var nowUtcMs = Date.now();
                var wibOffsetMs = 7 * 60 * 60 * 1000;
                var nowWib = new Date(nowUtcMs + wibOffsetMs);
                var nextResetUtcMs = Date.UTC(nowWib.getUTCFullYear(), nowWib.getUTCMonth() + 1, 1, 0, 0, 0) - wibOffsetMs;
                var diff = Math.max(0, nextResetUtcMs - nowUtcMs);
                var days = Math.floor(diff / 86400000);
                var hours = Math.floor((diff % 86400000) / 3600000);
                var mins = Math.floor((diff % 3600000) / 60000);
                var label = days + 'h ' + String(hours).padStart(2, '0') + 'j ' + String(mins).padStart(2, '0') + 'm';
                els.forEach(function(el) { el.textContent = label; });
            }
            tick();
            setInterval(tick, 30000);
        })();
    </script>

    <!-- Google Drive Modal -->
    <% if (hasSafeGdriveLink) { %>
    <div class="modal fade" id="gdriveModal" tabindex="-1">
        <div class="modal-dialog modal-dialog-centered">
            <div class="modal-content border-0 shadow-lg">
                <div class="modal-header bg-danger text-white border-0">
                    <h5 class="modal-title">
                        <i class="bi bi-google me-2"></i>Google Drive - Pengumpulan Tugas
                    </h5>
                    <button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal"></button>
                </div>
                <div class="modal-body text-center py-4">
                    <div class="mb-4">
                        <div class="bg-danger bg-opacity-10 rounded-circle d-inline-flex align-items-center justify-content-center"
                             style="width: 80px; height: 80px;">
                            <i class="bi bi-folder2-open text-danger" style="font-size: 2.5rem;"></i>
                        </div>
                    </div>
                    <h5 class="mb-3">Folder Pengumpulan Tugas & Feedback</h5>
                    <p class="text-muted mb-4">
                        Ini adalah folder Google Drive pribadi Anda untuk:
                    </p>
                    <div class="text-start bg-light p-3 rounded mb-4">
                        <ul class="mb-0">
                            <li class="mb-2"><i class="bi bi-check-circle text-success me-2"></i>Mengumpulkan tugas dan assignment</li>
                            <li class="mb-2"><i class="bi bi-check-circle text-success me-2"></i>Menerima feedback dari mentor</li>
                            <li class="mb-2"><i class="bi bi-check-circle text-success me-2"></i>Melihat hasil review dan nilai</li>
                            <li><i class="bi bi-check-circle text-success me-2"></i>Dokumen pembelajaran lainnya</li>
                        </ul>
                    </div>
                    <div class="alert alert-info text-start mb-0">
                        <i class="bi bi-info-circle me-2"></i>
                        <strong>Catatan:</strong> Pastikan Anda sudah login dengan akun Google yang terdaftar untuk mengakses folder ini.
                    </div>
                </div>
                <div class="modal-footer border-0 bg-light">
                    <button type="button" class="btn btn-outline-secondary px-4" data-bs-dismiss="modal">
                        <i class="bi bi-x-lg me-1"></i>Tutup
                    </button>
                    <a href="<%= ValidationUtil.sanitizeHtml(gdriveLink) %>" target="_blank" rel="noopener noreferrer" class="btn btn-danger px-4">
                        <i class="bi bi-box-arrow-up-right me-1"></i>Buka Google Drive
                    </a>
                </div>
            </div>
        </div>
    </div>
    <% } %>
</body>
</html>
