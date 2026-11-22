<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%@ page import="com.examora.model.User" %>
<%@ page import="com.examora.model.Material" %>
<%@ page import="com.examora.dao.SettingsDAO" %>
<%@ page import="com.examora.service.ChatService" %>
<%@ page import="com.examora.util.ValidationUtil" %>
<%
    User currentUser = (User) session.getAttribute("user");
    if (currentUser == null) { response.sendRedirect("../LoginServlet"); return; }
    Material material = (Material) request.getAttribute("material");
    if (material == null) { response.sendRedirect("../MateriServlet"); return; }

    boolean chatEnabled = new SettingsDAO().isChatEnabled();
    int chatUnreadCount = 0;
    if (chatEnabled) {
        try { chatUnreadCount = new ChatService().getUnreadCountForUser(currentUser.getId()); } catch (Exception e) {}
    }
%>
<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title><%= ValidationUtil.sanitizeHtml(material.getTitle()) %> - Exatuy</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
    <link href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.10.0/font/bootstrap-icons.css" rel="stylesheet">
    <link href="../assets/css/style.css" rel="stylesheet">
    <link rel="icon" type="image/svg+xml" href="../assets/img/favicon.svg?v=4">
    <style>
        .material-content {
            white-space: pre-wrap;
            font-family: 'Nunito', sans-serif;
            line-height: 1.9;
            font-size: 1.02rem;
        }
    </style>
<link href="../assets/css/handdrawn.css" rel="stylesheet">
</head>
<body>
    <!-- Navbar -->
    <%@ include file="navbar.jspf" %>

    <div class="container py-4">
        <nav aria-label="breadcrumb">
            <ol class="breadcrumb">
                <li class="breadcrumb-item"><a href="../MateriServlet">Materi Belajar</a></li>
                <li class="breadcrumb-item active"><%= ValidationUtil.sanitizeHtml(material.getTitle()) %></li>
            </ol>
        </nav>

        <div class="row">
            <div class="col-lg-9">
                <div class="card">
                    <div class="card-header">
                        <h4 class="mb-2"><%= ValidationUtil.sanitizeHtml(material.getTitle()) %></h4>
                        <div class="d-flex gap-2 flex-wrap">
                            <span class="badge badge-primary"><%= material.getCategoryName() != null ? ValidationUtil.sanitizeHtml(material.getCategoryName()) : "Materi" %></span>
                            <span class="badge bg-secondary"><%= material.getFileType() != null ? material.getFileType().toUpperCase() : "TEXT" %></span>
                            <span class="badge bg-light text-dark"><i class="bi bi-eye me-1"></i><%= material.getViewCount() != null ? material.getViewCount() : 0 %></span>
                        </div>
                    </div>
                    <div class="card-body">
                        <% if (material.getSummary() != null && !material.getSummary().isEmpty()) { %>
                        <div class="alert alert-info">
                            <i class="bi bi-info-circle me-2"></i><%= ValidationUtil.sanitizeHtml(material.getSummary()) %>
                        </div>
                        <% } %>

                        <% if (material.getContent() != null && !material.getContent().trim().isEmpty()) { %>
                        <div class="material-content"><%= ValidationUtil.sanitizeHtml(material.getContent()) %></div>
                        <% } else { %>
                        <div class="empty-state">
                            <i class="bi bi-file-earmark-text"></i>
                            <p class="mb-0">Materi ini tersedia sebagai file. Silakan unduh untuk membacanya.</p>
                        </div>
                        <% } %>
                    </div>
                </div>

                <div class="d-flex gap-2 mt-3">
                    <a href="../MateriServlet" class="btn btn-outline-secondary">
                        <i class="bi bi-arrow-left me-2"></i>Kembali
                    </a>
                    <% if (material.getFilePath() != null && !material.getFilePath().isEmpty()) { %>
                    <a href="../MateriServlet?action=download&id=<%= material.getId() %>" class="btn btn-primary">
                        <i class="bi bi-download me-2"></i>Unduh File
                    </a>
                    <% } %>
                </div>
            </div>

            <div class="col-lg-3">
                <div class="card">
                    <div class="card-header">
                        <h6 class="mb-0"><i class="bi bi-info-circle me-2"></i>Info Materi</h6>
                    </div>
                    <div class="card-body">
                        <p class="small mb-2"><strong>Kategori:</strong><br><%= material.getCategoryName() != null ? ValidationUtil.sanitizeHtml(material.getCategoryName()) : "-" %></p>
                        <p class="small mb-2"><strong>Target Kelas:</strong><br>
                            <%= material.getTargetTags() != null && !material.getTargetTags().isEmpty() ? ValidationUtil.sanitizeHtml(material.getTargetTags()) : "Semua siswa" %>
                        </p>
                        <p class="small mb-2"><strong>Dibaca:</strong><br><%= material.getViewCount() != null ? material.getViewCount() : 0 %> kali</p>
                        <p class="small mb-0"><strong>Diunduh:</strong><br><%= material.getDownloadCount() != null ? material.getDownloadCount() : 0 %> kali</p>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/js/bootstrap.bundle.min.js"></script>
</body>
</html>
