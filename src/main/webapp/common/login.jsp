<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="fn" uri="http://java.sun.com/jsp/jstl/functions" %>
<%@ page import="com.examora.model.User" %>
<%
    User user = (User) session.getAttribute("user");
    if (user != null) {
        response.sendRedirect(user.isAdmin() ? "../admin/dashboard.jsp" : "../user/dashboard.jsp");
        return;
    }
    pageContext.setAttribute("error", request.getAttribute("error"));
    pageContext.setAttribute("email", request.getAttribute("email"));
    Boolean regEnabled = (Boolean) request.getAttribute("registrationEnabled");
    pageContext.setAttribute("registrationEnabled", regEnabled != null && regEnabled);
%>
<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Masuk - Exatuy</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.2/dist/css/bootstrap.min.css" rel="stylesheet">
    <link href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.1/font/bootstrap-icons.css" rel="stylesheet">
    <link href="../assets/css/style.css" rel="stylesheet">
    <link rel="icon" type="image/svg+xml" href="../assets/img/favicon.svg?v=4">
    <style>
        .brand-logo {
            font-size: 2rem;
            font-weight: 800;
            background: linear-gradient(135deg, #4A90D9, #7BC67E);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            background-clip: text;
        }
        .auth-card {
            border: none;
            border-radius: 20px;
            overflow: hidden;
        }
        .auth-header {
            background: linear-gradient(135deg, #4A90D9 0%, #7BC67E 100%);
            color: white;
            padding: 2rem;
            text-align: center;
        }
        .auth-header h2 {
            font-weight: 800;
            margin-bottom: 0.25rem;
        }
        .auth-body {
            padding: 2rem;
        }
        .btn-brand {
            background: linear-gradient(135deg, #4A90D9 0%, #357ABD 100%);
            border: none;
            border-radius: 12px;
            padding: 0.75rem;
            font-weight: 700;
        }
        .btn-brand:hover {
            background: linear-gradient(135deg, #357ABD 0%, #4A90D9 100%);
            transform: translateY(-1px);
        }
    </style>
<link href="../assets/css/handdrawn.css" rel="stylesheet">
</head>
<body class="auth-page">
    <div class="container">
        <div class="row justify-content-center align-items-center min-vh-100">
            <div class="col-md-5">
                <div class="card shadow-lg auth-card">
                    <div class="auth-header">
                        <h2><i class="bi bi-mortarboard-fill me-2"></i>Exatuy</h2>
                        <p class="mb-0 opacity-75">Platform Ujian Online Modern</p>
                    </div>
                    <div class="auth-body">
                        <c:if test="${not empty error}">
                        <div class="alert alert-danger alert-dismissible fade show" role="alert">
                            <i class="bi bi-exclamation-triangle me-2"></i><c:out value="${error}"/>
                            <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
                        </div>
                        </c:if>

                        <form action="../LoginServlet" method="post">
                            <div class="mb-3">
                                <label for="email" class="form-label">Email</label>
                                <div class="input-group">
                                    <span class="input-group-text"><i class="bi bi-envelope"></i></span>
                                    <input type="email" class="form-control" id="email" name="email"
                                           value="${fn:escapeXml(email)}" required
                                           placeholder="Masukkan email">
                                </div>
                            </div>
                            <div class="mb-3">
                                <label for="password" class="form-label">Password / PIN</label>
                                <div class="input-group">
                                    <span class="input-group-text"><i class="bi bi-lock"></i></span>
                                    <input type="password" class="form-control" id="password" name="password"
                                           required placeholder="Masukkan password atau PIN siswa">
                                    <button class="btn btn-outline-secondary" type="button" id="togglePassword">
                                        <i class="bi bi-eye"></i>
                                    </button>
                                </div>
                            </div>
                            <div class="mb-3 form-check">
                                <input type="checkbox" class="form-check-input" id="remember" name="remember">
                                <label class="form-check-label" for="remember">Ingat saya</label>
                            </div>
                            <button type="submit" class="btn btn-brand btn-primary w-100">
                                <i class="bi bi-box-arrow-in-right me-2"></i>Masuk
                            </button>
                        </form>

                        <hr class="my-4">

                        <c:choose>
                            <c:when test="${registrationEnabled}">
                                <div class="text-center">
                                    <p class="mb-2">Belum punya akun?</p>
                                    <a href="../RegisterServlet" class="btn btn-outline-primary w-100">
                                        <i class="bi bi-person-plus me-2"></i>Daftar Sekarang
                                    </a>
                                </div>
                            </c:when>
                            <c:otherwise>
                                <div class="text-center text-muted">
                                    <small>Registrasi saat ini dinonaktifkan. Hubungi admin.</small>
                                </div>
                            </c:otherwise>
                        </c:choose>
                    </div>
                </div>
                <div class="text-center mt-3">
                    <a href="../index.jsp" class="text-muted text-decoration-none">
                        <i class="bi bi-house-heart me-1"></i>Kembali ke Beranda
                    </a>
                </div>
            </div>
        </div>
    </div>

    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.2/dist/js/bootstrap.bundle.min.js"></script>
    <script>
        document.getElementById('togglePassword').addEventListener('click', function() {
            const password = document.getElementById('password');
            const icon = this.querySelector('i');
            if (password.type === 'password') {
                password.type = 'text';
                icon.classList.remove('bi-eye');
                icon.classList.add('bi-eye-slash');
            } else {
                password.type = 'password';
                icon.classList.remove('bi-eye-slash');
                icon.classList.add('bi-eye');
            }
        });
    </script>
</body>
</html>
