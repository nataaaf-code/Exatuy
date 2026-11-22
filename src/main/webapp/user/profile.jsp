<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%@ page import="com.examora.model.User" %>
<%@ page import="com.examora.service.ChatService" %>
<%@ page import="com.examora.dao.SettingsDAO" %>
<%@ page import="com.examora.util.ValidationUtil" %>
<%@ page import="java.time.format.DateTimeFormatter" %>
<%@ page import="java.time.ZoneId" %>
<%
    User currentUser = (User) session.getAttribute("user");
    if (currentUser == null) {
        response.sendRedirect("../LoginServlet");
        return;
    }
    User userProfile = (User) request.getAttribute("userProfile");
    if (userProfile == null) {
        userProfile = currentUser;
    }
    String success = (String) request.getAttribute("success");
    String error = (String) request.getAttribute("error");

    // Get CSRF token from session
    String csrfToken = (String) session.getAttribute("csrfToken");

    // Check if chat is enabled
    Boolean chatEnabledAttr = (Boolean) request.getAttribute("chatEnabled");
    boolean chatEnabled = chatEnabledAttr != null && chatEnabledAttr;

    // Check if file management is enabled
    boolean fileManagementEnabled = new SettingsDAO().isFileManagementEnabled();

    // Get unread chat count
    int chatUnreadCount = 0;
    if (chatEnabled) {
        try {
            chatUnreadCount = new ChatService().getUnreadCountForUser(currentUser.getId());
        } catch (Exception e) {
            // Ignore errors
        }
    }

    ZoneId jakartaZone = ZoneId.of("Asia/Jakarta");
    DateTimeFormatter dtf = DateTimeFormatter.ofPattern("dd MMM yyyy HH:mm").withZone(jakartaZone);
%>
<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Profil Saya - Exatuy</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
    <link href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.10.0/font/bootstrap-icons.css" rel="stylesheet">
    <link href="../assets/css/style.css" rel="stylesheet">
    <link rel="icon" type="image/svg+xml" type="image/svg+xml" href="../assets/img/favicon.svg?v=3">
    <style>
        .password-toggle {
            cursor: pointer;
            position: absolute;
            right: 10px;
            top: 50%;
            transform: translateY(-50%);
            z-index: 10;
            color: #6c757d;
        }
        .password-toggle:hover {
            color: #0d6efd;
        }
        .password-wrapper {
            position: relative;
        }
        .password-wrapper input {
            padding-right: 40px;
        }
        .info-row {
            display: flex;
            justify-content: space-between;
            padding: 0.75rem 0;
            border-bottom: 1px solid #dee2e6;
        }
        .info-row:last-child {
            border-bottom: none;
        }
        .info-label {
            color: #6c757d;
            font-weight: 500;
        }
        .info-value {
            font-weight: 500;
        }
    </style>
<link href="../assets/css/handdrawn.css" rel="stylesheet">
</head>
<body>
    <!-- Navbar -->
    <%@ include file="navbar.jspf" %>

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

        <div class="row">
            <!-- Profile Info Card -->
            <div class="col-lg-4 mb-4">
                <div class="card">
                    <div class="card-body text-center">
                        <div class="mb-3">
                            <% if (userProfile.getPhoto() != null && !userProfile.getPhoto().isEmpty()) { %>
                            <img src="../uploads/<%= ValidationUtil.sanitizeHtml(userProfile.getPhoto()) %>" alt="Profile"
                                 class="rounded-circle" style="width: 120px; height: 120px; object-fit: cover;">
                            <% } else { %>
                            <div class="bg-primary text-white rounded-circle d-inline-flex align-items-center justify-content-center"
                                 style="width: 120px; height: 120px;">
                                <i class="bi bi-person-fill" style="font-size: 4rem;"></i>
                            </div>
                            <% } %>
                        </div>
                        <h4 class="mb-1"><%= ValidationUtil.sanitizeHtml(userProfile.getName()) %></h4>
                        <p class="text-muted mb-2"><%= ValidationUtil.sanitizeHtml(userProfile.getEmail()) %></p>
                        <span class="badge <%= userProfile.isAdmin() ? "bg-danger" : "bg-primary" %> mb-3">
                            <%= userProfile.isAdmin() ? "Administrator" : "Peserta" %>
                        </span>
                        <% if (userProfile.getTag() != null && !userProfile.getTag().isEmpty()) { %>
                        <br><span class="badge bg-secondary"><i class="bi bi-tag me-1"></i><%= ValidationUtil.sanitizeHtml(userProfile.getTag()) %></span>
                        <% } %>
                        <hr>
                        <div class="text-start">
                            <p class="mb-2">
                                <i class="bi bi-calendar3 me-2 text-muted"></i>
                                <small>Bergabung: <%= userProfile.getCreatedAt() != null ?
                                    userProfile.getCreatedAt().atZone(ZoneId.systemDefault()).withZoneSameInstant(jakartaZone).format(DateTimeFormatter.ofPattern("dd MMM yyyy")) : "-" %></small>
                            </p>
                            <% if (userProfile.getTotalPoints() != null && userProfile.getTotalPoints() > 0) { %>
                            <p class="mb-0">
                                <i class="bi bi-star-fill me-2 text-warning"></i>
                                <small>Total Points: <%= userProfile.getTotalPoints() %></small>
                            </p>
                            <% } %>
                        </div>
                    </div>
                </div>
            </div>

            <!-- Edit Forms -->
            <div class="col-lg-8">
                <!-- Profile Info (Read Only) -->
                <div class="card mb-4">
                    <div class="card-header">
                        <h5 class="mb-0"><i class="bi bi-person-badge me-2"></i>Informasi Akun</h5>
                    </div>
                    <div class="card-body">
                        <div class="info-row">
                            <span class="info-label"><i class="bi bi-person me-2"></i>Nama Lengkap</span>
                            <span class="info-value"><%= ValidationUtil.sanitizeHtml(userProfile.getName()) %></span>
                        </div>
                        <div class="info-row">
                            <span class="info-label"><i class="bi bi-envelope me-2"></i>Email</span>
                            <span class="info-value"><%= ValidationUtil.sanitizeHtml(userProfile.getEmail()) %></span>
                        </div>
                        <div class="info-row">
                            <span class="info-label"><i class="bi bi-shield-lock me-2"></i>Role</span>
                            <span class="info-value">
                                <span class="badge <%= userProfile.isAdmin() ? "bg-danger" : "bg-primary" %>">
                                    <%= userProfile.isAdmin() ? "Administrator" : "Peserta" %>
                                </span>
                            </span>
                        </div>
                        <% if (userProfile.getTag() != null && !userProfile.getTag().isEmpty()) { %>
                        <div class="info-row">
                            <span class="info-label"><i class="bi bi-tag me-2"></i>Tag/Kelas</span>
                            <span class="info-value"><%= ValidationUtil.sanitizeHtml(userProfile.getTag()) %></span>
                        </div>
                        <% } %>
                        <div class="info-row">
                            <span class="info-label"><i class="bi bi-calendar-check me-2"></i>Tanggal Bergabung</span>
                            <span class="info-value"><%= userProfile.getCreatedAt() != null ?
                                userProfile.getCreatedAt().atZone(ZoneId.systemDefault()).withZoneSameInstant(jakartaZone).format(DateTimeFormatter.ofPattern("dd MMM yyyy")) : "-" %></span>
                        </div>
                    </div>
                </div>

                <!-- Change Password Form -->
                <div class="card">
                    <div class="card-header bg-warning">
                        <h5 class="mb-0"><i class="bi bi-key me-2"></i>Ubah Password</h5>
                    </div>
                    <div class="card-body">
                        <form method="post" action="../ProfileServlet" id="passwordForm">
                            <input type="hidden" name="action" value="changePassword">
                            <input type="hidden" name="csrfToken" value="<%= csrfToken %>">

                            <div class="mb-3">
                                <label for="oldPassword" class="form-label">Password Lama</label>
                                <div class="password-wrapper">
                                    <input type="password" class="form-control" id="oldPassword" name="oldPassword" required>
                                    <i class="bi bi-eye-slash password-toggle" onclick="togglePassword('oldPassword', this)"></i>
                                </div>
                            </div>

                            <div class="mb-3">
                                <label for="newPassword" class="form-label">Password Baru</label>
                                <div class="password-wrapper">
                                    <input type="password" class="form-control" id="newPassword" name="newPassword"
                                           required minlength="6">
                                    <i class="bi bi-eye-slash password-toggle" onclick="togglePassword('newPassword', this)"></i>
                                </div>
                                <div class="form-text">Minimal 6 karakter</div>
                            </div>

                            <div class="mb-3">
                                <label for="confirmPassword" class="form-label">Konfirmasi Password Baru</label>
                                <div class="password-wrapper">
                                    <input type="password" class="form-control" id="confirmPassword" name="confirmPassword"
                                           required minlength="6">
                                    <i class="bi bi-eye-slash password-toggle" onclick="togglePassword('confirmPassword', this)"></i>
                                </div>
                            </div>

                            <div id="passwordStrength" class="mb-3"></div>

                            <div class="d-flex justify-content-end">
                                <button type="submit" class="btn btn-warning">
                                    <i class="bi bi-key me-1"></i>Ubah Password
                                </button>
                            </div>
                        </form>
                    </div>
                </div>
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
    <script>
        function togglePassword(inputId, icon) {
            const input = document.getElementById(inputId);
            if (input.type === 'password') {
                input.type = 'text';
                icon.classList.remove('bi-eye-slash');
                icon.classList.add('bi-eye');
            } else {
                input.type = 'password';
                icon.classList.remove('bi-eye');
                icon.classList.add('bi-eye-slash');
            }
        }

        // Password strength indicator
        document.getElementById('newPassword').addEventListener('input', function() {
            const password = this.value;
            const strengthDiv = document.getElementById('passwordStrength');
            let strength = 0;
            let message = '';
            let color = '';

            if (password.length >= 6) strength++;
            if (password.length >= 8) strength++;
            if (/[A-Z]/.test(password)) strength++;
            if (/[0-9]/.test(password)) strength++;
            if (/[^A-Za-z0-9]/.test(password)) strength++;

            if (password.length === 0) {
                message = '';
                strengthDiv.innerHTML = '';
            } else if (strength <= 2) {
                message = 'Lemah';
                color = 'danger';
            } else if (strength <= 3) {
                message = 'Sedang';
                color = 'warning';
            } else {
                message = 'Kuat';
                color = 'success';
            }

            if (message) {
                strengthDiv.innerHTML = '<div class="progress" style="height: 5px;">' +
                    '<div class="progress-bar bg-' + color + '" style="width: ' + (strength * 20) + '%"></div>' +
                    '</div>' +
                    '<small class="text-' + color + '">Kekuatan password: ' + message + '</small>';
            }
        });

        // Password match validation
        document.getElementById('passwordForm').addEventListener('submit', function(e) {
            const newPassword = document.getElementById('newPassword').value;
            const confirmPassword = document.getElementById('confirmPassword').value;

            if (newPassword !== confirmPassword) {
                e.preventDefault();
                alert('Password baru dan konfirmasi tidak cocok!');
            }
        });
    </script>
</body>
</html>
