<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%@ page import="com.examora.model.User" %>
<%@ page import="com.examora.model.Quiz" %>
<%@ page import="com.examora.util.ValidationUtil" %>
<%@ page import="java.util.List" %>
<%
    User currentUser = (User) session.getAttribute("user");
    if (currentUser == null || !currentUser.isAdmin()) {
        response.sendRedirect("../LoginServlet");
        return;
    }
    String group = (String) request.getAttribute("group");
    String grade = (String) request.getAttribute("grade");
    Quiz quiz = (Quiz) request.getAttribute("quiz");
    List<Quiz> quizzes = (List<Quiz>) request.getAttribute("quizzes");
    List<String> grades = (List<String>) request.getAttribute("grades");
    List<User> recipients = (List<User>) request.getAttribute("recipients");
    List<List<String>> batches = (List<List<String>>) request.getAttribute("batches");
    String subject = (String) request.getAttribute("subject");
    String body = (String) request.getAttribute("body");
    String error = (String) request.getAttribute("error");

    if (group == null) group = "unpaid";
    String[][] groups = {
        {"unpaid", "Tagihan Belum Dibayar", "bi-receipt"},
        {"quota_empty", "Kuota/Poin Habis", "bi-battery"},
        {"exam", "Pengingat Exam", "bi-pencil-square"},
        {"new_module", "Modul/Materi Baru", "bi-journal-plus"}
    };
%>
<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Pengingat Email - Exatuy</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.2/dist/css/bootstrap.min.css" rel="stylesheet">
    <link href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.1/font/bootstrap-icons.css" rel="stylesheet">
    <link href="../assets/css/style.css" rel="stylesheet">
    <link rel="icon" type="image/svg+xml" href="../assets/img/favicon.svg?v=4">
<link href="../assets/css/handdrawn.css" rel="stylesheet">
</head>
<body>
    <%@ include file="sidebar.jsp" %>

    <div class="main-content">
        <div class="mb-4">
            <h1 class="h3 mb-0">Pengingat Email Massal</h1>
            <p class="text-muted mb-0">Pilih grup, periksa penerima, lalu buka Gmail. Semua alamat masuk ke kolom BCC.</p>
        </div>

        <% if (error != null) { %>
        <div class="alert alert-danger">
            <i class="bi bi-exclamation-triangle me-2"></i><%= ValidationUtil.sanitizeHtml(error) %>
        </div>
        <% } %>

        <ul class="nav nav-pills mb-3 flex-wrap gap-2">
            <% for (String[] g : groups) { %>
            <li class="nav-item">
                <a class="nav-link <%= g[0].equals(group) ? "active" : "" %>" href="../BulkEmailServlet?group=<%= g[0] %>">
                    <i class="bi <%= g[2] %> me-1"></i><%= g[1] %>
                </a>
            </li>
            <% } %>
        </ul>

        <% if ("exam".equals(group)) { %>
        <form method="get" action="../BulkEmailServlet" class="row g-2 align-items-end mb-3">
            <input type="hidden" name="group" value="exam">
            <div class="col-sm-8 col-lg-5">
                <label for="quizId" class="form-label">Exam aktif</label>
                <select id="quizId" name="quizId" class="form-select" onchange="this.form.submit()">
                    <% if (quizzes == null || quizzes.isEmpty()) { %>
                    <option value="">Tidak ada exam aktif</option>
                    <% } else { for (Quiz q : quizzes) { %>
                    <option value="<%= q.getId() %>" <%= quiz != null && q.getId().equals(quiz.getId()) ? "selected" : "" %>><%= ValidationUtil.sanitizeHtml(q.getTitle()) %></option>
                    <% } } %>
                </select>
            </div>
        </form>
        <% } else if ("new_module".equals(group)) { %>
        <form method="get" action="../BulkEmailServlet" class="row g-2 align-items-end mb-3">
            <input type="hidden" name="group" value="new_module">
            <div class="col-sm-6 col-lg-3">
                <label for="grade" class="form-label">Jenjang</label>
                <select id="grade" name="grade" class="form-select" onchange="this.form.submit()">
                    <option value="">Semua siswa</option>
                    <% if (grades != null) { for (String g : grades) { %>
                    <option value="<%= ValidationUtil.sanitizeHtml(g) %>" <%= g.equals(grade) ? "selected" : "" %>><%= ValidationUtil.sanitizeHtml(g) %></option>
                    <% } } %>
                </select>
            </div>
        </form>
        <% } %>

        <div class="row g-4">
            <div class="col-lg-7">
                <div class="card h-100">
                    <div class="card-header">
                        <h6 class="mb-0"><i class="bi bi-envelope me-2"></i>Isi Email</h6>
                    </div>
                    <div class="card-body">
                        <div class="mb-3">
                            <label for="subject" class="form-label">Subjek</label>
                            <input type="text" id="subject" class="form-control" value="<%= ValidationUtil.sanitizeHtml(subject) %>">
                        </div>
                        <div class="mb-3">
                            <label for="body" class="form-label">Isi pesan</label>
                            <textarea id="body" class="form-control" rows="8"><%= ValidationUtil.sanitizeHtml(body) %></textarea>
                        </div>

                        <% if (batches == null || batches.isEmpty()) { %>
                        <div class="empty-state">
                            <i class="bi bi-inbox"></i>
                            <p class="mb-0">Tidak ada penerima di grup ini</p>
                        </div>
                        <% } else { %>
                        <p class="small text-muted mb-2">
                            Maksimal 40 penerima per tautan Gmail. Klik setiap tombol untuk membuka satu draf.
                        </p>
                        <div class="d-flex flex-wrap gap-2">
                            <% for (int i = 0; i < batches.size(); i++) { %>
                            <button type="button" class="btn btn-primary gmail-batch"
                                    data-bcc="<%= ValidationUtil.sanitizeHtml(String.join(",", batches.get(i))) %>">
                                <i class="bi bi-google me-2"></i>Buka Gmail<%= batches.size() > 1 ? " (batch " + (i + 1) + ")" : "" %>
                                &middot; <%= batches.get(i).size() %> penerima
                            </button>
                            <% } %>
                        </div>
                        <% } %>
                    </div>
                </div>
            </div>

            <div class="col-lg-5">
                <div class="card h-100">
                    <div class="card-header d-flex justify-content-between align-items-center">
                        <h6 class="mb-0"><i class="bi bi-people me-2"></i>Penerima</h6>
                        <span class="badge bg-secondary"><%= recipients != null ? recipients.size() : 0 %></span>
                    </div>
                    <div class="card-body p-0" style="max-height: 420px; overflow-y: auto;">
                        <% if (recipients == null || recipients.isEmpty()) { %>
                        <div class="empty-state p-4">
                            <i class="bi bi-person-x"></i>
                            <p class="mb-0">Belum ada siswa yang cocok dengan kriteria grup ini</p>
                        </div>
                        <% } else { %>
                        <ul class="list-group list-group-flush">
                            <% for (User r : recipients) { %>
                            <li class="list-group-item">
                                <div class="fw-semibold"><%= ValidationUtil.sanitizeHtml(r.getName()) %></div>
                                <small class="text-muted text-break"><%= ValidationUtil.sanitizeHtml(r.getEmail()) %></small>
                            </li>
                            <% } %>
                        </ul>
                        <% } %>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.2/dist/js/bootstrap.bundle.min.js"></script>
    <script>
        document.querySelectorAll('.gmail-batch').forEach(function (btn) {
            btn.addEventListener('click', function () {
                var url = 'https://mail.google.com/mail/?view=cm&fs=1'
                    + '&bcc=' + encodeURIComponent(btn.dataset.bcc)
                    + '&su=' + encodeURIComponent(document.getElementById('subject').value)
                    + '&body=' + encodeURIComponent(document.getElementById('body').value);
                window.open(url, '_blank', 'noopener');
            });
        });
    </script>
</body>
</html>
