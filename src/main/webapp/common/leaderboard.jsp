<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%@ page import="com.examora.model.User" %>
<%@ page import="com.examora.util.ValidationUtil" %>
<%@ page import="java.util.List" %>
<%@ page import="java.util.Map" %>
<%@ page import="java.util.Date" %>
<%@ page import="java.text.SimpleDateFormat" %>
<%!
    String esc(String s) {
        if (s == null) return "";
        return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace("\"", "&quot;").replace("'", "&#39;");
    }

    String initials(String name) {
        if (name == null || name.trim().isEmpty()) return "?";
        String[] parts = name.trim().split("\\s+");
        StringBuilder sb = new StringBuilder();
        int max = Math.min(parts.length, 2);
        for (int i = 0; i < max; i++) {
            if (!parts[i].isEmpty()) sb.append(Character.toUpperCase(parts[i].charAt(0)));
        }
        return sb.length() > 0 ? sb.toString() : "?";
    }

    String fmtNum(String val) {
        if (val == null || val.trim().isEmpty()) return "&ndash;";
        try {
            String normalized = val.trim().replace(".", "").replace(",", ".");
            double d = Double.parseDouble(normalized);
            if (d == Math.floor(d)) return String.valueOf((int) d);
            return String.format("%.2f", d);
        } catch (NumberFormatException e) {
            return esc(val);
        }
    }

    double parseScore(String val) {
        if (val == null || val.trim().isEmpty()) return -1;
        try {
            String normalized = val.trim().replace(".", "").replace(",", ".");
            return Double.parseDouble(normalized);
        } catch (NumberFormatException e) {
            return -1;
        }
    }

    String scoreClass(double s) {
        if (s < 0) return "score-empty";
        if (s >= 75) return "score-high";
        if (s >= 60) return "score-mid";
        return "score-low";
    }

    String medalIcon(int rank) {
        switch (rank) {
            case 1: return "&#129351;";
            case 2: return "&#129352;";
            case 3: return "&#129353;";
            default: return "";
        }
    }

    boolean isScoreColumn(String header) {
        if (header == null) return false;
        String h = header.trim();
        try {
            int n = Integer.parseInt(h);
            return n >= 1 && n <= 99;
        } catch (NumberFormatException e) {
            return false;
        }
    }

    String tagColor(String tag) {
        if (tag == null || tag.isEmpty()) return "tag-muted";
        switch (tag.toLowerCase()) {
            case "mahasiswa": return "tag-mhs";
            case "umum": return "tag-umum";
            default: return "tag-other";
        }
    }
%>
<%
    User currentUser = (User) session.getAttribute("user");
    if (currentUser == null) {
        response.sendRedirect("../LoginServlet");
        return;
    }
    boolean isAdmin = Boolean.TRUE.equals(request.getAttribute("isAdmin"));

    List<Map<String, String>> rows = (List<Map<String, String>>) request.getAttribute("rows");
    List<String> headers = (List<String>) request.getAttribute("headers");
    Date fetchedAt = (Date) request.getAttribute("fetchedAt");
    Integer cacheTtl = (Integer) request.getAttribute("cacheTtlMin");
    Integer totalRows = (Integer) request.getAttribute("totalRows");
    Integer unmatchedCount = (Integer) request.getAttribute("unmatchedCount");
    List<String> tags = (List<String>) request.getAttribute("tags");
    String tagFilter = (String) request.getAttribute("tagFilter");
    Boolean filterFromDefault = (Boolean) request.getAttribute("filterFromDefault");
    String defaultTag = (String) request.getAttribute("defaultTag");
    String error = (String) request.getAttribute("error");
    Boolean unpublished = (Boolean) request.getAttribute("unpublished");
    Boolean published = (Boolean) request.getAttribute("published");
    if (unpublished == null) unpublished = false;
    if (published == null) published = true;

    if (rows == null) rows = List.of();
    if (headers == null) headers = List.of();
    if (fetchedAt == null) fetchedAt = new Date();
    if (cacheTtl == null) cacheTtl = 5;
    if (totalRows == null) totalRows = rows.size();
    if (unmatchedCount == null) unmatchedCount = 0;
    if (tags == null) tags = List.of();
    if (tagFilter == null) tagFilter = "";
    if (filterFromDefault == null) filterFromDefault = false;
    if (defaultTag == null) defaultTag = "";

    // Separate score columns from metadata
    List<String> scoreCols = new java.util.ArrayList<>();
    String nameCol = null, phoneCol = null, totalCol = null, avgCol = null;
    for (String h : headers) {
        String hl = h.toLowerCase().trim();
        if (hl.contains("nama") || hl.contains("name")) nameCol = h;
        else if (hl.equals("hp") || hl.contains("phone") || hl.contains("telepon") || hl.contains("no.")) phoneCol = h;
        else if (hl.contains("total")) totalCol = h;
        else if (hl.contains("rata") || hl.contains("average") || hl.contains("avg")) avgCol = h;
        else if (isScoreColumn(h)) scoreCols.add(h);
    }
    if (nameCol == null && !headers.isEmpty()) nameCol = headers.get(0);

    // Split top-3 (podium) from the rest (table)
    int podiumSize = Math.min(rows.size(), 3);
    List<Map<String, String>> podium = rows.subList(0, podiumSize);
    List<Map<String, String>> rest = rows.size() > 3 ? rows.subList(3, rows.size()) : List.of();
    int numChallenges = scoreCols.size();
%>
<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Leaderboard - Examora</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
    <link href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.10.0/font/bootstrap-icons.css" rel="stylesheet">
    <link href="../assets/css/style.css" rel="stylesheet">
    <link rel="icon" type="image/svg+xml" href="../assets/img/favicon.svg?v=3">
    <style>
        .lb-hero {
            background: linear-gradient(135deg, #1a2a6c, #4361ee 50%, #06d6a0);
            color: #fff; border-radius: 1rem; padding: 1.5rem 1.75rem; margin-bottom: 1.25rem;
        }
        .lb-hero h1 { font-size: 1.6rem; font-weight: 800; margin: 0; }
        .lb-hero p { margin: .25rem 0 0; opacity: .85; font-size: .82rem; }

        /* Tag filter bar */
        .tag-bar { display: flex; flex-wrap: wrap; gap: .5rem; align-items: center; margin-bottom: 1.25rem; }
        .tag-bar .tag-label { font-size: .8rem; color: #6c757d; margin-right: .25rem; font-weight: 600; }
        .tag-pill {
            display: inline-flex; align-items: center; gap: .35rem;
            padding: .35rem .85rem; border-radius: 999px; font-size: .82rem; font-weight: 600;
            text-decoration: none; border: 2px solid transparent; background: #f1f3f8; color: #5a6175;
            transition: all .15s ease;
        }
        .tag-pill:hover { background: #e7ebf5; color: #1a2a6c; }
        .tag-pill.active { background: #1a2a6c; color: #fff; box-shadow: 0 3px 8px rgba(26,42,108,.25); }
        .tag-pill .tag-count { font-size: .7rem; opacity: .75; }

        /* Podium */
        .podium { display: grid; grid-template-columns: repeat(3, 1fr); gap: 1rem; margin-bottom: 1.5rem; align-items: end; }
        @media (max-width: 767.98px) { .podium { grid-template-columns: 1fr; } }
        .podium-card {
            border-radius: 1rem; padding: 1.25rem 1rem; text-align: center; position: relative;
            background: #fff; border: 1px solid #eaecf3; box-shadow: 0 4px 14px rgba(26,42,108,.06);
        }
        .podium-card.p1 { border-color: #ffd700; box-shadow: 0 6px 20px rgba(255,215,0,.25); transform: scale(1.03); }
        .podium-card.p2 { border-color: #c0c0c0; }
        .podium-card.p3 { border-color: #cd7f32; }
        .podium-rank { font-size: 2.2rem; line-height: 1; margin-bottom: .5rem; }
        .podium-avatar {
            width: 56px; height: 56px; border-radius: 50%; margin: 0 auto .6rem;
            display: flex; align-items: center; justify-content: center;
            font-size: 1.3rem; font-weight: 800; color: #fff;
        }
        .podium-card.p1 .podium-avatar { background: linear-gradient(135deg,#FFD700,#FFA500); }
        .podium-card.p2 .podium-avatar { background: linear-gradient(135deg,#C0C0C0,#909090); }
        .podium-card.p3 .podium-avatar { background: linear-gradient(135deg,#CD7F32,#A0522D); }
        .podium-name { font-weight: 700; font-size: .98rem; margin: 0; }
        .podium-total { font-size: 1.8rem; font-weight: 800; margin: .35rem 0 0; }
        .podium-sub { font-size: .76rem; color: #6c757d; margin-top: .15rem; }

        /* Table */
        .lb-table-wrap { border-radius: .625rem; overflow: hidden; }
        .lb-table { font-size: .82rem; margin: 0; }
        .lb-table thead th {
            background: #1a2a6c; color: #fff; font-weight: 600;
            white-space: nowrap; padding: .6rem .5rem; border: 0;
            position: sticky; top: 0; z-index: 2;
        }
        .lb-table thead th.center, .lb-table td.center { text-align: center; }
        .lb-table tbody tr { border-bottom: 1px solid #eef0f4; }
        .lb-table tbody tr:hover { background: #f5f7ff; }
        .lb-table tbody tr:nth-child(odd) { background: #fafbff; }
        .lb-table tbody tr:nth-child(odd):hover { background: #f5f7ff; }
        .lb-table td { padding: .5rem .5rem; vertical-align: middle; }
        .rank-badge {
            display: inline-flex; align-items: center; justify-content: center;
            width: 28px; height: 28px; border-radius: 50%; font-weight: 800;
            font-size: .78rem;
        }
        .rank-1 { background: linear-gradient(135deg, #FFD700, #FFA500); color: #fff; box-shadow: 0 2px 6px rgba(255,165,0,.35); }
        .rank-2 { background: linear-gradient(135deg, #C0C0C0, #A0A0A0); color: #fff; }
        .rank-3 { background: linear-gradient(135deg, #CD7F32, #A0522D); color: #fff; }
        .rank-other { background: #e9ecf3; color: #555; }
        .score-high { background: rgba(6,214,160,.12); color: #04a57f; font-weight: 600; }
        .score-mid { background: rgba(250,173,20,.12); color: #b8860b; font-weight: 600; }
        .score-low { background: rgba(239,71,111,.10); color: #c0355a; font-weight: 600; }
        .score-empty { color: #c0c5d0; }
        .total-cell { font-weight: 800; font-size: .9rem; }
        .name-cell { font-weight: 600; }

        /* Tag badges */
        .tag-badge {
            display: inline-block; padding: .1rem .5rem; border-radius: 999px;
            font-size: .68rem; font-weight: 700; margin-left: .4rem; vertical-align: middle;
        }
        .tag-mhs { background: rgba(67,97,238,.12); color: #3a56d4; }
        .tag-umum { background: rgba(239,71,111,.12); color: #c0355a; }
        .tag-other { background: rgba(108,117,125,.15); color: #495057; }
        .tag-muted { background: #f1f3f8; color: #adb5bd; }

        .legend-row { font-size: .76rem; color: #6c757d; }
        .legend-chip { display: inline-block; width: 12px; height: 12px; border-radius: 3px; vertical-align: middle; margin-right: .2rem; }
    </style>
<link href="../assets/css/handdrawn.css" rel="stylesheet">
</head>
<body>
    <% if (isAdmin) { %>
    <%@ include file="../admin/sidebar.jsp" %>
    <% } else { %>
    <%-- Siswa memakai navbar bersama agar menu konsisten dengan halaman lain --%>
    <%@ include file="../user/navbar.jspf" %>
    <% } %>

    <div class="<%= isAdmin ? "main-content" : "container-fluid mt-3" %>">
        <!-- Hero header -->
        <div class="lb-hero d-flex justify-content-between align-items-center flex-wrap gap-2">
            <div>
                <h1><i class="bi bi-trophy-fill me-2"></i>Leaderboard Competition</h1>
                <p>Peringkat peserta berdasarkan challenge yang telah diselesaikan</p>
            </div>
            <div class="text-end" style="opacity:.85;font-size:.76rem;">
                <i class="bi bi-clock me-1"></i>Diperbarui: <%= new SimpleDateFormat("dd MMM yyyy, HH:mm").format(fetchedAt) %>
                <br>
                <span class="badge bg-light text-dark"><i class="bi bi-arrow-clockwise me-1"></i>Auto-refresh <%= cacheTtl %> menit</span>
            </div>
        </div>

        <% if (error != null) { %>
        <div class="alert alert-danger">
            <i class="bi bi-exclamation-triangle me-2"></i><%= ValidationUtil.sanitizeHtml(error) %>
        </div>
        <% } %>

        <% if (unpublished) { %>
        <!-- Unpublished: peserta see this instead of the data -->
        <div class="text-center py-5">
            <i class="bi bi-eye-slash fs-1 d-block mb-3 text-muted opacity-50"></i>
            <h4 class="text-muted">Leaderboard Belum Dipublikasi</h4>
            <p class="text-muted">Halaman leaderboard sedang disiapkan oleh admin dan belum tersedia untuk publik.</p>
            <a href="../ExamServlet?action=dashboard" class="btn btn-outline-primary mt-2">
                <i class="bi bi-house me-1"></i>Kembali ke Dashboard
            </a>
        </div>
        <% } else { %>

        <% if (!published && isAdmin) { %>
        <!-- Admin preview banner: data shown but hidden from peserta -->
        <div class="alert alert-warning d-flex align-items-center">
            <i class="bi bi-eye-slash-fill me-2 fs-5"></i>
            <div>
                <strong>Mode Preview (Unpublished).</strong>
                Leaderboard sedang disembunyikan dari peserta. Publikasikan dari
                <a href="../AdminServlet?action=settings" class="alert-link">Pengaturan Leaderboard</a>
                agar peserta dapat mengaksesnya.
            </div>
        </div>
        <% } %>

        <% if (rows.isEmpty() && totalRows == 0) { %>
        <div class="text-center py-5 text-muted">
            <i class="bi bi-inbox fs-1 d-block mb-2 opacity-50"></i>
            Belum ada data leaderboard.
        </div>
        <% } else { %>

        <!-- Tag filter bar -->
        <div class="tag-bar">
            <span class="tag-label"><i class="bi bi-funnel me-1"></i>Filter Tag:</span>
            <a class="tag-pill <%= tagFilter.isEmpty() || "all".equalsIgnoreCase(tagFilter) ? "active" : "" %>"
               href="../LeaderboardServlet?tag=all">
                Semua <span class="tag-count">(<%= totalRows %>)</span>
            </a>
            <% for (String t : tags) { %>
            <a class="tag-pill <%= t.equals(tagFilter) ? "active" : "" %>"
               href="../LeaderboardServlet?tag=<%= java.net.URLEncoder.encode(t, "UTF-8") %>">
                <%= esc(t) %>
            </a>
            <% } %>
            <% if (unmatchedCount > 0) { %>
            <a class="tag-pill <%= "unmatched".equals(tagFilter) ? "active" : "" %>"
               href="../LeaderboardServlet?tag=unmatched">
                Tanpa Tag <span class="tag-count">(<%= unmatchedCount %>)</span>
            </a>
            <% } %>
        </div>

        <% if (filterFromDefault) { %>
        <div class="alert alert-info py-2 small mb-3">
            <i class="bi bi-info-circle me-1"></i>
            Menampilkan tag <strong><%= esc(defaultTag) %></strong> sesuai pengaturan default admin.
            <a href="../LeaderboardServlet?tag=all" class="alert-link">Tampilkan semua tag</a>
        </div>
        <% } %>

        <!-- Empty filter result -->
        <% if (rows.isEmpty()) { %>
        <div class="text-center py-5 text-muted">
            <i class="bi bi-search fs-1 d-block mb-2 opacity-50"></i>
            Tidak ada peserta untuk tag <strong><%= esc(tagFilter) %></strong>.
            <br><a href="../LeaderboardServlet?tag=all" class="small">Lihat semua</a>
        </div>
        <% } else { %>

        <!-- Legend -->
        <div class="legend-row mb-2">
            <span class="legend-chip score-high"></span>Skor &ge; 75
            &nbsp;<span class="legend-chip score-mid"></span>60&ndash;74
            &nbsp;<span class="legend-chip score-low"></span>&lt; 60
            &nbsp;<span class="legend-chip score-empty border"></span>Tidak dikerjakan
        </div>

        <!-- Podium (top 3) -->
        <% if (podiumSize > 0) { %>
        <div class="podium">
            <% for (int i = 0; i < podiumSize; i++) {
                   Map<String, String> row = podium.get(i);
                   int rank = i + 1;
                   String pcls = rank == 1 ? "p1" : rank == 2 ? "p2" : "p3";
                   String totalVal = totalCol != null ? row.get(totalCol) : null;
                   double totalScore = parseScore(totalVal);
                   String avgVal = avgCol != null ? row.get(avgCol) : null;
                   String tagName = row.get("_tag");
            %>
            <div class="podium-card <%= pcls %>">
                <div class="podium-rank"><%= medalIcon(rank) %></div>
                <div class="podium-avatar"><%= esc(initials(row.get(nameCol))) %></div>
                <div class="podium-name">
                    <%= esc(row.get(nameCol)) %>
                    <% if (tagName != null && !tagName.isEmpty()) { %>
                    <span class="tag-badge <%= tagColor(tagName) %>"><%= esc(tagName) %></span>
                    <% } %>
                </div>
                <div class="podium-total"><%= totalScore >= 0 ? fmtNum(totalVal) : "&ndash;" %></div>
                <div class="podium-sub">
                    Total dari <%= numChallenges %> challenge<%= avgVal != null && !avgVal.isEmpty() ? " &middot; Rata² " + fmtNum(avgVal) : "" %>
                </div>
            </div>
            <% } %>
        </div>
        <% } %>

        <!-- Rest of leaderboard (rank 4+) -->
        <% if (!rest.isEmpty()) { %>
        <div class="card shadow-sm">
            <div class="card-body p-0">
                <div class="table-responsive lb-table-wrap" style="max-height: 65vh;">
                    <table class="table lb-table">
                        <thead>
                            <tr>
                                <th class="center" style="width: 50px;">#</th>
                                <th style="min-width: 200px;">Nama</th>
                                <% if (isAdmin && phoneCol != null) { %>
                                <th class="center" style="width: 80px;">HP</th>
                                <% } %>
                                <% for (String sc : scoreCols) { %>
                                <th class="center" title="Challenge <%= esc(sc) %>"><%= esc(sc) %></th>
                                <% } %>
                                <% if (totalCol != null) { %>
                                <th class="center" style="width: 80px;">Total</th>
                                <% } %>
                                <% if (avgCol != null) { %>
                                <th class="center" style="width: 80px;">Rata²</th>
                                <% } %>
                            </tr>
                        </thead>
                        <tbody>
                            <% int rank = 4;
                               for (Map<String, String> row : rest) {
                                   String rankCls = "rank-other";
                                   String totalVal = totalCol != null ? row.get(totalCol) : null;
                                   double totalScore = parseScore(totalVal);
                                   String tagName = row.get("_tag");
                            %>
                            <tr>
                                <td class="center">
                                    <span class="rank-badge <%= rankCls %>"><%= rank %></span>
                                </td>
                                <td class="name-cell">
                                    <%= esc(row.get(nameCol)) %>
                                    <% if (tagName != null && !tagName.isEmpty()) { %>
                                    <span class="tag-badge <%= tagColor(tagName) %>"><%= esc(tagName) %></span>
                                    <% } %>
                                </td>
                                <% if (isAdmin && phoneCol != null) { %>
                                <td class="center text-muted"><%= esc(row.get(phoneCol)) %></td>
                                <% } %>
                                <% for (String sc : scoreCols) {
                                       double s = parseScore(row.get(sc));
                                %>
                                <td class="center <%= scoreClass(s) %>"><%= s >= 0 ? fmtNum(row.get(sc)) : "&ndash;" %></td>
                                <% } %>
                                <% if (totalCol != null) { %>
                                <td class="center total-cell <%= totalScore >= 0 ? scoreClass(totalScore / Math.max(scoreCols.size(), 1)) : "" %>">
                                    <%= totalScore >= 0 ? fmtNum(totalVal) : "&ndash;" %>
                                </td>
                                <% } %>
                                <% if (avgCol != null) { %>
                                <td class="center fw-bold"><%= fmtNum(row.get(avgCol)) %></td>
                                <% } %>
                            </tr>
                            <% rank++;
                               } %>
                        </tbody>
                    </table>
                </div>
            </div>
            <div class="card-footer bg-light d-flex justify-content-between align-items-center">
                <span class="small text-muted">
                    <i class="bi bi-people me-1"></i><%= rows.size() %> peserta ditampilkan
                </span>
                <span class="small text-muted">
                    <i class="bi bi-google me-1"></i>Sumber: Google Sheets
                </span>
            </div>
        </div>
        <% } %>

        <% } // end non-empty filter %>
        <% } // end has data %>
        <% } // end not-unpublished %>
    </div>

    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/js/bootstrap.bundle.min.js"></script>
</body>
</html>
