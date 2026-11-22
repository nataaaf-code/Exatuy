<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%@ page import="com.examora.model.User" %>
<%@ page import="com.examora.model.Quiz" %>
<%@ page import="com.examora.util.ValidationUtil" %>
<%@ page import="java.util.List" %>
<%@ page import="java.util.Map" %>
<%@ page import="java.util.Set" %>
<%!
    public String esc(String input) {
        if (input == null) return "";
        return input.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace("\"", "&quot;").replace("'", "&#39;");
    }

    public String fmtScore(Object score) {
        if (score == null) return "";
        if (score instanceof Number) {
            double d = ((Number) score).doubleValue();
            if (d == Math.floor(d)) {
                return String.valueOf((int) d);
            }
            return String.format("%.2f", d);
        }
        return score.toString();
    }

    public String scoreColorClass(Object score) {
        if (score == null) return "";
        double d;
        if (score instanceof Number) {
            d = ((Number) score).doubleValue();
        } else {
            try { d = Double.parseDouble(score.toString()); } catch (NumberFormatException e) { return ""; }
        }
        if (d >= 75) return "bg-success text-white";
        if (d >= 60) return "bg-warning text-dark";
        return "bg-danger text-white";
    }
%>
<%
    User currentUser = (User) session.getAttribute("user");
    if (currentUser == null || !currentUser.isAdmin()) {
        response.sendRedirect("../LoginServlet");
        return;
    }

    List<Quiz> allQuizzes = (List<Quiz>) request.getAttribute("allQuizzes");
    List<Quiz> columnQuizzes = (List<Quiz>) request.getAttribute("columnQuizzes");
    Map<Integer, Map<String, Object>> usersIndex = (Map<Integer, Map<String, Object>>) request.getAttribute("usersIndex");
    Map<Integer, Map<Integer, Map<String, Object>>> scoreMatrix = (Map<Integer, Map<Integer, Map<String, Object>>>) request.getAttribute("scoreMatrix");
    Map<Integer, Double> userAverages = (Map<Integer, Double>) request.getAttribute("userAverages");
    Map<Integer, Double> userOverallAverages = (Map<Integer, Double>) request.getAttribute("userOverallAverages");
    Map<Integer, Integer> userAttemptCounts = (Map<Integer, Integer>) request.getAttribute("userAttemptCounts");
    int totalColumnQuizzes = columnQuizzes != null ? columnQuizzes.size() : 0;
    List<String> allTags = (List<String>) request.getAttribute("allTags");
    List<String> allSubjects = (List<String>) request.getAttribute("allSubjects");
    List<User> allParticipants = (List<User>) request.getAttribute("allParticipants");
    String selectedTagFilter = (String) request.getAttribute("selectedTagFilter");
    String selectedSubjectFilter = (String) request.getAttribute("selectedSubjectFilter");
    String selectedUserIdFilter = (String) request.getAttribute("selectedUserIdFilter");
    List<Integer> selectedQuizIds = (List<Integer>) request.getAttribute("selectedQuizIds");
    String selectedSortBy = (String) request.getAttribute("selectedSortBy");
    if (selectedSortBy == null) selectedSortBy = "";
    String error = (String) request.getAttribute("error");

    if (allQuizzes == null) allQuizzes = java.util.List.of();
    if (columnQuizzes == null) columnQuizzes = java.util.List.of();
    if (usersIndex == null) usersIndex = new java.util.LinkedHashMap<>();
    if (scoreMatrix == null) scoreMatrix = new java.util.LinkedHashMap<>();
    if (userAverages == null) userAverages = new java.util.LinkedHashMap<>();
    if (userOverallAverages == null) userOverallAverages = new java.util.LinkedHashMap<>();
    if (userAttemptCounts == null) userAttemptCounts = new java.util.LinkedHashMap<>();
    if (allTags == null) allTags = java.util.List.of();
    if (allSubjects == null) allSubjects = java.util.List.of("Matematika", "IPA");
    if (allParticipants == null) allParticipants = java.util.List.of();
    if (selectedTagFilter == null) selectedTagFilter = "";
    if (selectedSubjectFilter == null) selectedSubjectFilter = "";
    if (selectedUserIdFilter == null) selectedUserIdFilter = "";
    if (selectedQuizIds == null) selectedQuizIds = java.util.List.of();

    Set<Integer> selectedQuizSet = new java.util.HashSet<>(selectedQuizIds);
    boolean hasActiveFilter = !selectedTagFilter.isEmpty()
            || !selectedSubjectFilter.isEmpty()
            || !selectedUserIdFilter.isEmpty()
            || !selectedQuizIds.isEmpty()
            || (!selectedSortBy.isEmpty() && !"name".equals(selectedSortBy));
%>
<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Transcript Nilai - Exatuy</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
    <link href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.10.0/font/bootstrap-icons.css" rel="stylesheet">
    <link href="../assets/css/style.css" rel="stylesheet">
    <link rel="icon" type="image/svg+xml" href="../assets/img/favicon.svg?v=3">
    <style>
        .matrix-wrap { max-height: 70vh; overflow: auto; }
        .matrix-table { font-size: 0.875rem; min-width: 100%; }
        .matrix-table thead th { position: sticky; top: 0; z-index: 2; background: #0d6efd; color: #fff; vertical-align: middle; }
        .matrix-table thead th:first-child { left: 0; z-index: 3; }
        .matrix-table td, .matrix-table th { white-space: nowrap; }
        .matrix-table td.score-cell { text-align: center; font-variant-numeric: tabular-nums; }
        .quiz-col-title { max-width: 160px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; display: inline-block; max-width: 150px; vertical-align: middle; }
        .quiz-check-list { max-height: 180px; overflow-y: auto; border: 1px solid #dee2e6; border-radius: .375rem; padding: .5rem; }
        .legend-chip { display: inline-block; width: 14px; height: 14px; border-radius: .25rem; vertical-align: middle; margin-right: .25rem; }
        .quiz-check-item { padding: .125rem .25rem; border-radius: .2rem; }
        .quiz-check-item:hover { background: #f1f3f5; }
        .quiz-check-item.unmatched { display: none; }
        .filter-collapse-btn[aria-expanded="true"] .bi-chevron-down { display: none; }
        .filter-collapse-btn[aria-expanded="false"] .bi-chevron-up { display: none; }
    </style>
<link href="../assets/css/handdrawn.css" rel="stylesheet">
</head>
<body>
    <%@ include file="sidebar.jsp" %>

    <div class="main-content">
        <!-- Header -->
        <div class="d-flex justify-content-between align-items-start mb-4 flex-wrap gap-2">
            <div>
                <h1 class="h3 mb-1 fw-bold text-primary">
                    <i class="bi bi-card-list me-2"></i>Transcript Nilai
                </h1>
                <nav aria-label="breadcrumb">
                    <ol class="breadcrumb mb-0">
                        <li class="breadcrumb-item"><a href="../AdminServlet?action=dashboard" class="text-secondary" style="text-decoration: none;">Dashboard</a></li>
                        <li class="breadcrumb-item active">Transcript Nilai</li>
                    </ol>
                </nav>
            </div>
            <div class="d-flex gap-2">
                <a class="btn btn-outline-success btn-sm" href="TranscriptServlet?action=export&format=csv&tagFilter=<%= esc(selectedTagFilter) %>&subjectFilter=<%= esc(selectedSubjectFilter) %>&userIdFilter=<%= esc(selectedUserIdFilter) %>&sortBy=<%= esc(selectedSortBy) %><% for (Integer qid : selectedQuizIds) { %>&quizIds=<%= qid %><% } %>">
                    <i class="bi bi-filetype-csv me-1"></i>Export CSV
                </a>
                <a class="btn btn-outline-primary btn-sm" href="TranscriptServlet?action=export&format=xls&tagFilter=<%= esc(selectedTagFilter) %>&subjectFilter=<%= esc(selectedSubjectFilter) %>&userIdFilter=<%= esc(selectedUserIdFilter) %>&sortBy=<%= esc(selectedSortBy) %><% for (Integer qid : selectedQuizIds) { %>&quizIds=<%= qid %><% } %>">
                    <i class="bi bi-file-earmark-excel me-1"></i>Export Excel
                </a>
            </div>
        </div>

        <% if (error != null) { %>
        <div class="alert alert-danger alert-dismissible fade show">
            <i class="bi bi-exclamation-triangle me-2"></i><%= ValidationUtil.sanitizeHtml(error) %>
            <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
        </div>
        <% } %>

        <!-- Filter Card -->
        <div class="card shadow-sm mb-4">
            <div class="card-header bg-light d-flex justify-content-between align-items-center py-2">
                <span>
                    <i class="bi bi-funnel me-1"></i><strong>Filter</strong>
                    <% if (hasActiveFilter) { %><span class="badge bg-primary ms-2">Aktif</span><% } %>
                </span>
                <button class="btn btn-sm btn-link p-0 text-secondary text-decoration-none filter-collapse-btn"
                        type="button" data-bs-toggle="collapse" data-bs-target="#filterBody"
                        aria-expanded="<%= hasActiveFilter ? "false" : "true" %>" aria-controls="filterBody"
                        title="Tampilkan/sembunyikan filter">
                    <i class="bi bi-chevron-up"></i><i class="bi bi-chevron-down"></i>
                </button>
            </div>
            <div class="collapse <%= hasActiveFilter ? "" : "show" %>" id="filterBody">
                <div class="card-body">
                    <form method="get" action="TranscriptServlet" id="filterForm">
                        <input type="hidden" name="action" value="view">
                        <div class="row g-3">
                            <div class="col-sm-6 col-lg-2">
                                <label class="form-label fw-semibold small mb-1">Mata Pelajaran</label>
                                <select name="subjectFilter" class="form-select form-select-sm">
                                    <option value="">Semua Mapel</option>
                                    <% for (String subj : allSubjects) { %>
                                    <option value="<%= esc(subj) %>" <%= subj.equalsIgnoreCase(selectedSubjectFilter) ? "selected" : "" %>><%= esc(subj) %></option>
                                    <% } %>
                                </select>
                            </div>
                            <div class="col-sm-6 col-lg-2">
                                <label class="form-label fw-semibold small mb-1">Tag / Kelas</label>
                                <select name="tagFilter" class="form-select form-select-sm">
                                    <option value="">Semua Tag</option>
                                    <% for (String tag : allTags) { %>
                                    <option value="<%= esc(tag) %>" <%= tag.equals(selectedTagFilter) ? "selected" : "" %>><%= esc(tag) %></option>
                                    <% } %>
                                </select>
                            </div>
                            <div class="col-md-4 col-lg-3">
                                <label class="form-label fw-semibold small mb-1">Peserta</label>
                                <div class="input-group input-group-sm mb-1">
                                    <span class="input-group-text bg-white"><i class="bi bi-search"></i></span>
                                    <input type="text" id="participantSearch" class="form-control" placeholder="Cari nama / email peserta..." oninput="filterParticipants()">
                                </div>
                                <select name="userIdFilter" id="participantSelect" class="form-select form-select-sm">
                                    <option value="">Semua Peserta</option>
                                    <% for (User p : allParticipants) { %>
                                    <option value="<%= p.getId() %>" <%= String.valueOf(p.getId()).equals(selectedUserIdFilter) ? "selected" : "" %>><%= esc(p.getName()) %> &lt;<%= esc(p.getEmail()) %>&gt;</option>
                                    <% } %>
                                </select>
                            </div>
                            <div class="col-md-4 col-lg-2">
                                <label class="form-label fw-semibold small mb-1">Urutkan</label>
                                <select name="sortBy" class="form-select form-select-sm">
                                    <option value="" <%= selectedSortBy.isEmpty() ? "selected" : "" %>>Nama (A-Z)</option>
                                    <option value="avg-desc" <%= "avg-desc".equals(selectedSortBy) ? "selected" : "" %>>Rata-rata Tertinggi</option>
                                    <option value="avg-asc" <%= "avg-asc".equals(selectedSortBy) ? "selected" : "" %>>Rata-rata Terendah</option>
                                    <option value="count-desc" <%= "count-desc".equals(selectedSortBy) ? "selected" : "" %>>Jumlah Selesai Terbanyak</option>
                                    <option value="count-asc" <%= "count-asc".equals(selectedSortBy) ? "selected" : "" %>>Jumlah Selesai Tersedikit</option>
                                </select>
                            </div>
                            <div class="col-md-4 col-lg-3 d-flex align-items-end justify-content-lg-end gap-2">
                                <button type="submit" class="btn btn-primary btn-sm"><i class="bi bi-funnel-fill me-1"></i>Terapkan</button>
                                <a href="TranscriptServlet?action=view" class="btn btn-outline-secondary btn-sm"><i class="bi bi-arrow-counterclockwise me-1"></i>Reset</a>
                            </div>
                            <div class="col-12">
                                <label class="form-label fw-semibold small mb-1">Quiz <small class="text-muted fw-normal">(kosongkan = tampil semua, hanya centang yang ingin ditampilkan sebagai kolom)</small></label>
                                <div class="d-flex flex-wrap gap-2 mb-2 align-items-center">
                                    <div class="input-group input-group-sm" style="max-width: 280px;">
                                        <span class="input-group-text bg-white"><i class="bi bi-search"></i></span>
                                        <input type="text" id="quizSearch" class="form-control" placeholder="Cari judul quiz..." oninput="filterQuizzes()">
                                    </div>
                                    <button type="button" class="btn btn-outline-secondary btn-sm" onclick="toggleAllQuizzes(true)"><i class="bi bi-check2-all me-1"></i>Pilih semua</button>
                                    <button type="button" class="btn btn-outline-secondary btn-sm" onclick="toggleAllQuizzes(false)">Kosongkan</button>
                                    <span class="text-muted small ms-auto"><span id="quizSelectedCount">0</span> terpilih</span>
                                </div>
                                <div class="quiz-check-list">
                                    <% if (allQuizzes.isEmpty()) { %>
                                    <span class="text-muted small">Belum ada quiz.</span>
                                    <% } else { %>
                                    <% for (Quiz q : allQuizzes) { %>
                                    <div class="form-check quiz-check-item mb-0">
                                        <input class="form-check-input quiz-check" type="checkbox" name="quizIds" value="<%= q.getId() %>" id="qz_<%= q.getId() %>" <%= selectedQuizSet.contains(q.getId()) ? "checked" : "" %> onchange="updateQuizCount()">
                                        <label class="form-check-label small" for="qz_<%= q.getId() %>" title="<%= esc(q.getTitle()) %>">
                                            <%= esc(q.getTitle()) %>
                                        </label>
                                    </div>
                                    <% } %>
                                    <% } %>
                                </div>
                            </div>
                        </div>
                    </form>
                </div>
            </div>
        </div>

        <!-- Legend -->
        <div class="mb-2 small text-muted">
            <span class="legend-chip bg-success"></span>Nilai &ge; 75
            &nbsp;<span class="legend-chip bg-warning"></span>60 - 74
            &nbsp;<span class="legend-chip bg-danger"></span>&lt; 60
            &nbsp;<span class="badge bg-secondary">timeout</span> dikerjakan melebihi waktu
            &nbsp;<i class="bi bi-info-circle ms-2"></i>Rata-rata dihitung dari <strong>semua quiz</strong> (quiz yang belum dikerjakan dihitung 0)
        </div>

        <!-- Matrix Table -->
        <div class="card shadow-sm">
            <div class="card-header bg-light d-flex justify-content-between align-items-center">
                <span><i class="bi bi-table me-1"></i><strong>Matriks Nilai</strong></span>
                <span class="small text-muted">
                    <%= usersIndex.size() %> peserta &middot; <%= columnQuizzes.size() %> quiz
                </span>
            </div>
            <div class="card-body p-0">
                <% if (usersIndex.isEmpty() || columnQuizzes.isEmpty()) { %>
                <div class="text-center py-5 px-3 text-muted">
                    <i class="bi bi-inbox fs-1 d-block mb-2 opacity-50"></i>
                    <h6 class="fw-bold text-dark mb-1">Data Rekap Nilai Tidak Ditemukan</h6>
                    <p class="small mb-3">
                        <% if (hasActiveFilter) { %>
                            Tidak ada data nilai yang sesuai dengan filter yang aktif saat ini.
                        <% } else { %>
                            Belum ada data nilai peserta yang tercatat.
                        <% } %>
                    </p>
                    <% if (hasActiveFilter) { %>
                    <a href="TranscriptServlet?action=view" class="btn btn-outline-primary btn-sm">
                        <i class="bi bi-arrow-counterclockwise me-1"></i>Reset Filter
                    </a>
                    <% } %>
                </div>
                <% } else { %>
                <div class="matrix-wrap">
                    <table class="table table-bordered table-hover matrix-table mb-0">
                        <thead>
                            <tr>
                                <th>#</th>
                                <th>Nama</th>
                                <th>Email</th>
                                <th>Tag</th>
                                <% for (Quiz q : columnQuizzes) { %>
                                <th title="<%= esc(q.getTitle()) %>"><span class="quiz-col-title"><%= esc(q.getTitle()) %></span></th>
                                <% } %>
                                <th>Selesai</th>
                                <th>Rata-rata</th>
                            </tr>
                        </thead>
                        <tbody>
                            <% int no = 1; %>
                            <% for (Map.Entry<Integer, Map<String, Object>> entry : usersIndex.entrySet()) { %>
                            <%  Integer uId = entry.getKey();
                                Map<String, Object> u = entry.getValue();
                                Map<Integer, Map<String, Object>> userScores = scoreMatrix.get(uId);
                                Double avg = userOverallAverages.get(uId);
                                Integer attemptCount = userAttemptCounts.get(uId);
                                int attempts = attemptCount != null ? attemptCount : 0;
                            %>
                            <tr>
                                <td><%= no++ %></td>
                                <td class="fw-semibold"><%= ValidationUtil.sanitizeHtml(String.valueOf(u.get("userName"))) %></td>
                                <td class="text-muted small"><%= ValidationUtil.sanitizeHtml(String.valueOf(u.get("userEmail"))) %></td>
                                <td><%= ValidationUtil.sanitizeHtml(String.valueOf(u.get("userTag"))) %></td>
                                <% for (Quiz q : columnQuizzes) {
                                        Map<String, Object> sub = userScores != null ? userScores.get(q.getId()) : null;
                                        if (sub == null) { %>
                                <td class="score-cell text-muted">&ndash;</td>
                                <%      } else {
                                            String colorCls = scoreColorClass(sub.get("score"));
                                            boolean isTimeout = "timeout".equals(sub.get("status"));
                                %>
                                <td class="score-cell <%= colorCls %>">
                                    <%= fmtScore(sub.get("score")) %>
                                    <% if (isTimeout) { %><span class="badge bg-secondary ms-1" title="Timeout">T</span><% } %>
                                </td>
                                <%      }
                                    } %>
                                <td class="score-cell text-center<%= attempts < totalColumnQuizzes ? " text-warning" : " text-success" %>">
                                    <%= attempts %><span class="text-muted">/<%= totalColumnQuizzes %></span>
                                </td>
                                <td class="score-cell fw-bold <%= scoreColorClass(avg) %>">
                                    <%= avg != null && avg > 0 ? fmtScore(avg) : "&ndash;" %>
                                </td>
                            </tr>
                            <% } %>
                        </tbody>
                    </table>
                </div>
                <% } %>
            </div>
        </div>

    </div>

    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/js/bootstrap.bundle.min.js"></script>
    <script>
        // Filter dropdown peserta by name/email
        function filterParticipants() {
            const q = document.getElementById('participantSearch').value.toLowerCase().trim();
            document.querySelectorAll('#participantSelect option').forEach(opt => {
                if (!opt.value) { opt.hidden = false; return; } // always keep "Semua Peserta"
                opt.hidden = q !== '' && !opt.textContent.toLowerCase().includes(q);
            });
        }

        // Filter daftar checkbox quiz by title
        function filterQuizzes() {
            const q = document.getElementById('quizSearch').value.toLowerCase().trim();
            document.querySelectorAll('.quiz-check-item').forEach(item => {
                const text = item.textContent.toLowerCase();
                item.classList.toggle('unmatched', q !== '' && !text.includes(q));
            });
        }

        // Pilih semua / kosongkan — hanya yang sedang tampil (match search)
        function toggleAllQuizzes(check) {
            document.querySelectorAll('.quiz-check-item').forEach(item => {
                if (item.classList.contains('unmatched')) return;
                const cb = item.querySelector('.quiz-check');
                if (cb) cb.checked = check;
            });
            updateQuizCount();
        }

        function updateQuizCount() {
            const n = document.querySelectorAll('.quiz-check:checked').length;
            document.getElementById('quizSelectedCount').textContent = n;
        }

        // Init count on load
        document.addEventListener('DOMContentLoaded', updateQuizCount);
    </script>
</body>
</html>
