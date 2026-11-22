<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%@ page import="com.examora.model.User" %>
<%@ page import="com.examora.model.AttendanceRecord" %>
<%@ page import="com.examora.util.ValidationUtil" %>
<%@ page import="java.util.List" %>
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

    List<AttendanceRecord> history = (List<AttendanceRecord>) request.getAttribute("history");
    String success = (String) request.getAttribute("success");
    String error = (String) request.getAttribute("error");
    String gdriveLink = currentUser.getGdriveLink() != null ? currentUser.getGdriveLink().trim() : "";
    boolean hasSafeGdriveLink = gdriveLink.startsWith("https://drive.google.com/") || gdriveLink.startsWith("https://docs.google.com/");

    // Check if file management is enabled
    boolean fileManagementEnabled = new com.examora.dao.SettingsDAO().isFileManagementEnabled();
%>
<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Riwayat Absensi - Exatuy</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
    <link href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.10.0/font/bootstrap-icons.css" rel="stylesheet">
    <link href="../assets/css/style.css" rel="stylesheet">
    <link rel="icon" type="image/svg+xml" type="image/svg+xml" href="../assets/img/favicon.svg?v=3">
<link href="../assets/css/handdrawn.css" rel="stylesheet">
</head>
<body>
    <!-- Navbar -->
    <%@ include file="navbar.jspf" %>

    <!-- Main Content -->
    <div class="container py-4">
        <!-- Page Header -->
        <div class="row mb-4">
            <div class="col-md-6">
                <h2><i class="bi bi-clock-history me-2"></i>Riwayat Absensi</h2>
                <p class="text-muted">Daftar kehadiran Anda dalam sesi absensi</p>
            </div>
            <div class="col-md-6 text-md-end">
                <a href="../AttendanceServlet?action=view" class="btn btn-primary">
                    <i class="bi bi-check2-square me-2"></i>Absensi
                </a>
            </div>
        </div>

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

        <!-- Statistics -->
        <% if (history != null && !history.isEmpty()) {
            int presentCount = 0;
            int lateCount = 0;
            for (AttendanceRecord r : history) {
                if ("present".equals(r.getStatus())) presentCount++;
                else if ("late".equals(r.getStatus())) lateCount++;
            }
        %>
        <div class="row g-4 mb-4">
            <div class="col-md-4">
                <div class="card bg-success text-white">
                    <div class="card-body">
                        <div class="d-flex justify-content-between align-items-center">
                            <div>
                                <p class="mb-1 opacity-75">Total Hadir</p>
                                <h2 class="mb-0"><%= presentCount %></h2>
                            </div>
                            <i class="bi bi-check-circle fs-1 opacity-50"></i>
                        </div>
                    </div>
                </div>
            </div>
            <div class="col-md-4">
                <div class="card bg-warning">
                    <div class="card-body">
                        <div class="d-flex justify-content-between align-items-center">
                            <div>
                                <p class="mb-1 opacity-75">Total Terlambat</p>
                                <h2 class="mb-0"><%= lateCount %></h2>
                            </div>
                            <i class="bi bi-clock fs-1 opacity-50"></i>
                        </div>
                    </div>
                </div>
            </div>
            <div class="col-md-4">
                <div class="card bg-info text-white">
                    <div class="card-body">
                        <div class="d-flex justify-content-between align-items-center">
                            <div>
                                <p class="mb-1 opacity-75">Total Sesi</p>
                                <h2 class="mb-0"><%= history.size() %></h2>
                            </div>
                            <i class="bi bi-calendar-check fs-1 opacity-50"></i>
                        </div>
                    </div>
                </div>
            </div>
        </div>
        <% } %>

        <!-- History Table -->
        <div class="card">
            <div class="card-header">
                <h5 class="mb-0"><i class="bi bi-list-ul me-2"></i>Daftar Kehadiran</h5>
            </div>
            <div class="card-body">
                <% if (history != null && !history.isEmpty()) { %>
                <div class="table-responsive">
                    <table class="table table-hover">
                        <thead>
                            <tr>
                                <th>No</th>
                                <th>Nama Sesi</th>
                                <th>Waktu Absensi</th>
                                <th>Status</th>
                            </tr>
                        </thead>
                        <tbody>
                            <% int no = 1;
                               for (AttendanceRecord record : history) { %>
                            <tr>
                                <td><%= no++ %></td>
                                <td><%= ValidationUtil.sanitizeHtml(record.getSessionName() != null ? record.getSessionName() : "-") %></td>
                                <td><%= record.getFormattedAttendanceTime() %></td>
                                <td>
                                    <span class="badge <%= ValidationUtil.sanitizeHtml(record.getStatusBadgeClass()) %>"><%= ValidationUtil.sanitizeHtml(record.getStatusLabel()) %></span>
                                </td>
                            </tr>
                            <% } %>
                        </tbody>
                    </table>
                </div>
                <% } else { %>
                <div class="text-center py-5">
                    <i class="bi bi-calendar-x display-1 text-muted mb-3 d-block"></i>
                    <h5 class="text-muted">Belum ada riwayat absensi</h5>
                    <p class="text-muted">Riwayat absensi Anda akan muncul di sini setelah melakukan absensi.</p>
                    <a href="../AttendanceServlet?action=view" class="btn btn-primary mt-2">
                        <i class="bi bi-check2-square me-2"></i>Lakukan Absensi
                    </a>
                </div>
                <% } %>
            </div>
        </div>
    </div>

    <!-- Footer -->
    <footer class="bg-light py-3 mt-auto">
        <div class="container text-center">
            <span class="text-muted">&copy; 2026 Exatuy. All rights reserved.</span>
        </div>
    </footer>

    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/js/bootstrap.bundle.min.js"></script>
</body>
</html>
