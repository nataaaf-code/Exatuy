<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%@ page import="com.examora.model.User" %>
<%@ page import="com.examora.model.Quiz" %>
<%@ page import="com.examora.dao.SettingsDAO" %>
<%@ page import="com.examora.service.ChatService" %>
<%@ page import="com.examora.util.ValidationUtil" %>
<%@ page import="java.util.List" %>
<%@ page import="java.util.Map" %>
<%@ page import="java.util.Set" %>
<%@ page import="java.util.ArrayList" %>
<%@ page import="java.util.Comparator" %>
<%@ page import="java.time.LocalDateTime" %>
<%@ page import="java.time.ZoneId" %>
<%@ page import="java.time.format.DateTimeFormatter" %>
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

    public String gradeLetter(double score) {
        if (score >= 80) return "A";
        if (score >= 70) return "B";
        if (score >= 60) return "C";
        if (score >= 50) return "D";
        return "E";
    }

    public String gradeColorClass(String grade) {
        if (grade == null) return "grade-e";
        switch (grade) {
            case "A": return "grade-a";
            case "B": return "grade-b";
            case "C": return "grade-c";
            case "D": return "grade-d";
            default:  return "grade-e";
        }
    }
%>
<%
    User currentUser = (User) session.getAttribute("user");
    if (currentUser == null) {
        response.sendRedirect("../LoginServlet");
        return;
    }
    if (currentUser.isAdmin()) {
        response.sendRedirect("../TranscriptServlet?action=view");
        return;
    }

    List<Quiz> columnQuizzes = (List<Quiz>) request.getAttribute("columnQuizzes");
    Map<Integer, Map<String, Object>> usersIndex = (Map<Integer, Map<String, Object>>) request.getAttribute("usersIndex");
    Map<Integer, Map<Integer, Map<String, Object>>> scoreMatrix = (Map<Integer, Map<Integer, Map<String, Object>>>) request.getAttribute("scoreMatrix");
    Map<Integer, Double> userAverages = (Map<Integer, Double>) request.getAttribute("userAverages");
    Map<Integer, Double> userOverallAverages = (Map<Integer, Double>) request.getAttribute("userOverallAverages");
    List<Integer> selectedQuizIds = (List<Integer>) request.getAttribute("selectedQuizIds");
    String error = (String) request.getAttribute("error");

    if (columnQuizzes == null) columnQuizzes = List.of();
    if (usersIndex == null) usersIndex = new java.util.LinkedHashMap<>();
    if (scoreMatrix == null) scoreMatrix = new java.util.LinkedHashMap<>();
    if (userAverages == null) userAverages = new java.util.LinkedHashMap<>();
    if (userOverallAverages == null) userOverallAverages = new java.util.LinkedHashMap<>();
    if (selectedQuizIds == null) selectedQuizIds = List.of();

    // Own data
    Integer myId = currentUser.getId();
    Map<Integer, Map<String, Object>> myScores = scoreMatrix.get(myId);
    // Use overall (weighted) average — divides by total available quizzes,
    // so unattempted quizzes count as 0. Matches the admin matrix.
    Double myAvg = userOverallAverages.get(myId);
    int myTakenCount = myScores != null ? myScores.size() : 0;
    int totalQuizzes = columnQuizzes.size();
    double completionPct = totalQuizzes > 0 ? (myTakenCount * 100.0 / totalQuizzes) : 0;

    // Status derivations (academic-transcript style)
    String transcriptStatus = (totalQuizzes > 0 && myTakenCount == totalQuizzes) ? "Final" : "Interim";
    String completionStatus;
    if (myTakenCount == 0) completionStatus = "Belum Dimulai";
    else if (myTakenCount == totalQuizzes) completionStatus = "Selesai";
    else completionStatus = "Belum Selesai";

    double myHighest = 0;
    double myLowest = 0;
    if (myScores != null && !myScores.isEmpty()) {
        boolean first = true;
        for (Map<String, Object> sub : myScores.values()) {
            if (sub.get("score") instanceof Number) {
                double s = ((Number) sub.get("score")).doubleValue();
                if (s > myHighest) myHighest = s;
                if (first) { myLowest = s; first = false; }
                else if (s < myLowest) myLowest = s;
            }
        }
    }

    // Build a sorted display list: taken quizzes (by submitted_at desc) first,
    // then untaken quizzes (alphabetical) — show ALL for transparency.
    List<Quiz> sortedQuizzes = new ArrayList<>(columnQuizzes);
    sortedQuizzes.sort((a, b) -> {
        Map<String, Object> sa = myScores != null ? myScores.get(a.getId()) : null;
        Map<String, Object> sb = myScores != null ? myScores.get(b.getId()) : null;
        boolean aTaken = sa != null;
        boolean bTaken = sb != null;
        // Taken quizzes first
        if (aTaken && !bTaken) return -1;
        if (!aTaken && bTaken) return 1;
        // Both taken: sort by submittedAt desc
        if (aTaken && bTaken) {
            LocalDateTime ta = sa.get("submittedAt") instanceof LocalDateTime ? (LocalDateTime) sa.get("submittedAt") : null;
            LocalDateTime tb = sb.get("submittedAt") instanceof LocalDateTime ? (LocalDateTime) sb.get("submittedAt") : null;
            if (ta == null && tb == null) return 0;
            if (ta == null) return 1;
            if (tb == null) return -1;
            return tb.compareTo(ta); // desc
        }
        // Both untaken: sort alphabetically
        return a.getTitle().compareToIgnoreCase(b.getTitle());
    });

    DateTimeFormatter dateFormatter = DateTimeFormatter.ofPattern("dd MMM yyyy")
            .withZone(ZoneId.of("Asia/Jakarta"));
    DateTimeFormatter dateTimeFormatter = DateTimeFormatter.ofPattern("dd MMM yyyy, HH:mm")
            .withZone(ZoneId.of("Asia/Jakarta"));
    String todayStr = dateTimeFormatter.format(java.time.ZonedDateTime.now(ZoneId.of("Asia/Jakarta")));

    String myTag = currentUser.getTag() != null ? currentUser.getTag().trim() : "";
    if (myTag.isEmpty()) myTag = "&ndash;";

    // Transcript branding (from admin settings)
    String orgName = (String) request.getAttribute("transcriptOrgName");
    String orgUrl = (String) request.getAttribute("transcriptOrgUrl");
    String signerName = (String) request.getAttribute("transcriptSignerName");
    String signerTitle = (String) request.getAttribute("transcriptSignerTitle");
    String signaturePath = (String) request.getAttribute("transcriptSignaturePath");
    if (orgName == null) orgName = "IDS Cyber Security";
    if (orgUrl == null) orgUrl = "ids-cybersecurity.com";
    if (signerName == null) signerName = "";
    if (signerTitle == null) signerTitle = "";
    if (signaturePath == null) signaturePath = "";
    // Build clickable URL (prepend https:// if no protocol)
    String orgUrlHref = orgUrl;
    if (!orgUrlHref.startsWith("http://") && !orgUrlHref.startsWith("https://")) {
        orgUrlHref = "https://" + orgUrlHref;
    }

    // Settings for navbar
    boolean chatEnabled = new SettingsDAO().isChatEnabled();
    boolean fileManagementEnabled = new SettingsDAO().isFileManagementEnabled();
    int chatUnreadCount = 0;
    if (chatEnabled) {
        try {
            chatUnreadCount = new ChatService().getUnreadCountForUser(currentUser.getId());
        } catch (Exception e) {
            // ignore
        }
    }
    String gdriveLink = currentUser.getGdriveLink() != null ? currentUser.getGdriveLink().trim() : "";
    boolean hasSafeGdriveLink = gdriveLink.startsWith("https://drive.google.com/") || gdriveLink.startsWith("https://docs.google.com/");
%>
<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Transkrip Nilai - Exatuy</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
    <link href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.10.0/font/bootstrap-icons.css" rel="stylesheet">
    <link href="../assets/css/style.css" rel="stylesheet">
    <link rel="icon" type="image/svg+xml" href="../assets/img/favicon.svg?v=3">
    <style>
        :root {
            --ex-primary: #4361ee;
            --ex-primary-dark: #3651d4;
            --ex-secondary: #3f37c9;
            --ex-success: #06d6a0;
            --ex-warning: #ffd166;
            --ex-danger: #ef476f;
            --ex-ink: #1f2937;
            --ex-muted: #6b7280;
            --ex-line: #e5e7eb;
        }
        body { background: #f3f4f6; }

        /* Toolbar above the document */
        .doc-toolbar {
            display: flex; flex-wrap: wrap; gap: .5rem; align-items: center;
            justify-content: space-between; margin-bottom: 1.25rem;
        }

        /* The "paper" */
        .transcript-doc {
            background: #fff;
            max-width: 920px;
            margin: 0 auto;
            padding: 3rem 3.5rem;
            border: 1px solid var(--ex-line);
            border-radius: 14px;
            box-shadow: 0 10px 40px rgba(17,24,39,.06);
            position: relative;
        }
        .transcript-doc::before {
            content: "";
            position: absolute; top: 0; left: 0; right: 0; height: 6px;
            background: linear-gradient(90deg, var(--ex-primary) 0%, var(--ex-secondary) 100%);
            border-radius: 14px 14px 0 0;
        }

        /* Document header */
        .doc-org {
            text-align: center; font-size: .78rem; letter-spacing: .18em;
            text-transform: uppercase; color: var(--ex-muted); font-weight: 600;
        }
        .doc-org .org-mark { color: var(--ex-primary); }
        .doc-title {
            text-align: center; font-size: 1.9rem; font-weight: 800;
            letter-spacing: .04em; margin: .35rem 0 .15rem;
            color: var(--ex-ink);
        }
        .doc-subtitle {
            text-align: center; font-size: .85rem; color: var(--ex-muted);
            margin-bottom: 1.25rem;
        }
        .doc-seal {
            width: 64px; height: 64px; margin: 0 auto .5rem;
            border-radius: 50%;
            background: linear-gradient(135deg, var(--ex-primary), var(--ex-secondary));
            display: flex; align-items: center; justify-content: center;
            color: #fff; font-size: 1.6rem;
            box-shadow: 0 6px 16px rgba(67,97,238,.35);
        }
        .doc-divider {
            border: none; border-top: 2px solid var(--ex-ink);
            margin: 0 0 1.5rem; position: relative;
        }
        .doc-divider::after {
            content: ""; position: absolute; left: 0; right: 0; top: 4px;
            border-top: 1px solid var(--ex-ink);
        }

        /* Status badges */
        .status-row { display: flex; flex-wrap: wrap; gap: .6rem; align-items: center; margin-bottom: 1.75rem; }
        .status-pill {
            display: inline-flex; align-items: center; gap: .4rem;
            padding: .35rem .8rem; border-radius: 1rem;
            font-size: .76rem; font-weight: 600;
            border: 1px solid var(--ex-line); background: #fff;
        }
        .status-pill .dot { width: 8px; height: 8px; border-radius: 50%; display: inline-block; }
        .status-pill.interim   { background: #fff7e6; color: #946300; border-color: #ffd591; }
        .status-pill.interim .dot { background: #faad14; }
        .status-pill.final     { background: #e6fffb; color: #006d75; border-color: #87e8de; }
        .status-pill.final .dot { background: #08979c; }
        .status-pill.progress  { background: #eef2ff; color: #3a3f8f; border-color: #c7d2fe; }
        .status-pill.progress .dot { background: var(--ex-primary); }

        /* Completion progress bar */
        .completion-bar {
            flex: 1; min-width: 220px; max-width: 420px;
            background: #f8f9fc; border: 1px solid var(--ex-line);
            border-radius: .75rem; padding: .55rem .9rem .65rem;
        }
        .completion-head {
            display: flex; justify-content: space-between; align-items: baseline;
            margin-bottom: .4rem;
        }
        .completion-label { font-size: .68rem; font-weight: 700; letter-spacing: .1em; text-transform: uppercase; color: var(--ex-muted); }
        .completion-count { font-size: .82rem; font-weight: 700; color: var(--ex-ink); }
        .completion-count span { color: var(--ex-muted); font-weight: 500; }
        .completion-track { height: 9px; background: #e9ecf3; border-radius: 5px; overflow: hidden; }
        .completion-fill { height: 100%; border-radius: 5px; transition: width .5s ease; }
        .completion-fill.high   { background: linear-gradient(90deg, #06d6a0, #04a57f); }
        .completion-fill.mid    { background: linear-gradient(90deg, #faad14, #d48806); }
        .completion-fill.low    { background: linear-gradient(90deg, #ef476f, #b53a5b); }
        .completion-pct { font-size: .7rem; font-weight: 600; color: var(--ex-muted); margin-top: .3rem; text-align: right; }

        /* Section headings */
        .doc-section { margin-bottom: 1.75rem; }
        .section-heading {
            display: flex; align-items: center; gap: .75rem; margin-bottom: 1rem;
        }
        .section-heading .bar { width: 4px; height: 1.1rem; background: var(--ex-primary); border-radius: 2px; }
        .section-heading .text {
            font-size: .82rem; font-weight: 700; letter-spacing: .14em;
            text-transform: uppercase; color: var(--ex-ink);
        }
        .section-heading .rule { flex: 1; height: 1px; background: var(--ex-line); }

        /* Info grid (definition list) */
        .info-grid {
            display: grid; grid-template-columns: 1fr 1fr; gap: .25rem 2rem;
            font-size: .9rem;
        }
        @media (max-width: 575.98px) { .info-grid { grid-template-columns: 1fr; } }
        .info-row { display: flex; padding: .35rem 0; border-bottom: 1px dashed var(--ex-line); }
        .info-label {
            width: 150px; flex-shrink: 0; color: var(--ex-muted);
            font-weight: 600; font-size: .8rem; letter-spacing: .02em;
        }
        .info-value { color: var(--ex-ink); font-weight: 600; }
        .info-value.mono { font-variant-numeric: tabular-nums; font-family: 'SFMono-Regular', Menlo, Consolas, monospace; font-size: .85rem; }

        /* Grades table */
        .grades-table { width: 100%; border-collapse: collapse; font-size: .88rem; }
        .grades-table thead th {
            background: var(--ex-ink); color: #fff;
            font-size: .72rem; font-weight: 700; letter-spacing: .06em; text-transform: uppercase;
            padding: .65rem .7rem; text-align: left; border: none;
        }
        .grades-table thead th:first-child { border-top-left-radius: 8px; }
        .grades-table thead th:last-child  { border-top-right-radius: 8px; }
        .grades-table thead th.center { text-align: center; }
        .grades-table tbody td { padding: .7rem .7rem; border-bottom: 1px solid var(--ex-line); vertical-align: middle; }
        .grades-table tbody tr:nth-child(even) { background: #fafbfc; }
        .grades-table tbody tr:hover { background: #f1f4ff; }
        .grades-table td.center { text-align: center; }
        .grades-table td.num    { color: var(--ex-muted); font-weight: 600; width: 38px; text-align: center; }
        .grades-table td.kode   { font-family: 'SFMono-Regular', Menlo, Consolas, monospace; font-size: .78rem; color: var(--ex-muted); white-space: nowrap; }
        .grades-table td.quiz   { font-weight: 600; color: var(--ex-ink); }
        .grades-table td.nilai  { font-weight: 700; font-variant-numeric: tabular-nums; font-size: 1rem; }
        .grades-table td.nilai.good { color: #079e78; }
        .grades-table td.nilai.mid  { color: #b8860b; }
        .grades-table td.nilai.bad  { color: var(--ex-danger); }
        .grades-table td.tgl    { color: var(--ex-muted); font-size: .8rem; white-space: nowrap; }
        .grades-table tr.untaken td { color: #b0b6bf; }
        .grades-table tr.untaken .quiz { color: #9ca3af; font-style: italic; font-weight: 500; }

        /* Grade badge */
        .grade-badge {
            display: inline-flex; align-items: center; justify-content: center;
            width: 30px; height: 30px; border-radius: 8px;
            font-weight: 800; font-size: .85rem; color: #fff;
            box-shadow: 0 2px 5px rgba(0,0,0,.12);
        }
        .grade-a { background: linear-gradient(135deg, #06d6a0, #079e78); }
        .grade-b { background: linear-gradient(135deg, #4361ee, #3651d4); }
        .grade-c { background: linear-gradient(135deg, #ffd166, #f4a623); color: #5a3d00; }
        .grade-d { background: linear-gradient(135deg, #fb923c, #ea580c); }
        .grade-e { background: linear-gradient(135deg, #ef476f, #b53a5b); }
        .grade-none { background: #e5e7eb; color: #9ca3af; }

        /* Status chip in table */
        .chip { display: inline-flex; align-items: center; gap: .3rem; padding: .2rem .55rem; border-radius: 1rem; font-size: .7rem; font-weight: 600; }
        .chip-done    { background: rgba(6,214,160,.14); color: #04a57f; }
        .chip-timeout { background: rgba(239,71,111,.12); color: #b53a5b; }
        .chip-pending { background: rgba(108,117,125,.14); color: #6c757d; }
        .chip-progress{ background: rgba(67,97,238,.10); color: var(--ex-primary-dark); }
        .grades-table td.untaken { color: #9aa3b2; font-style: italic; }

        /* GPA / summary strip */
        .gpa-strip {
            display: flex; flex-wrap: wrap; gap: 1rem;
            background: linear-gradient(135deg, #f8faff, #eef2ff);
            border: 1px solid #dbe3ff; border-radius: 12px;
            padding: 1rem 1.25rem; margin-top: 1.5rem;
        }
        .gpa-item { flex: 1; min-width: 110px; }
        .gpa-item .lbl { font-size: .68rem; text-transform: uppercase; letter-spacing: .08em; color: var(--ex-muted); font-weight: 700; }
        .gpa-item .val { font-size: 1.35rem; font-weight: 800; line-height: 1.1; font-variant-numeric: tabular-nums; color: var(--ex-ink); }
        .gpa-item .val.good { color: #079e78; }
        .gpa-item .val.bad  { color: var(--ex-danger); }

        /* Footer signature — right-aligned single block */
        .doc-footer {
            display: flex; flex-wrap: wrap; justify-content: flex-end; gap: 2rem;
            margin-top: 2.5rem; padding-top: 1.5rem; border-top: 1px solid var(--ex-line);
        }
        .sig-block { text-align: right; max-width: 320px; }
        .sig-block .sig-intro { font-size: .8rem; color: var(--ex-muted); margin-bottom: .35rem; font-style: italic; }
        .sig-block .sig-name { font-weight: 700; color: var(--ex-ink); }
        .sig-block .sig-line { border-top: 1.5px solid var(--ex-ink); margin-top: .25rem; padding-top: .15rem; }
        .footer-note { font-size: .72rem; color: var(--ex-muted); text-align: center; margin-top: 1.5rem; }

        /* Signature image */
        .sig-block .sig-img {
            max-height: 64px; max-width: 180px; object-fit: contain;
            margin: 0 0 .25rem auto; display: block;
        }
        .sig-org { font-size: .8rem; font-weight: 700; color: var(--ex-ink); }
        .sig-org a { color: var(--ex-primary); text-decoration: none; word-break: break-all; }
        .sig-org a:hover { text-decoration: underline; }
        .sig-title { font-size: .72rem; color: var(--ex-muted); }

        .legend-inline { font-size: .75rem; color: var(--ex-muted); margin-top: .75rem; }
        .legend-inline .gd { display: inline-block; width: 12px; height: 12px; border-radius: 4px; margin-right: .3rem; vertical-align: middle; }

        .empty-state { text-align: center; padding: 3rem 1rem; color: var(--ex-muted); }

        @media print {
            body { background: #fff; }
            .doc-toolbar, .navbar { display: none !important; }
            .transcript-doc { box-shadow: none; border: none; max-width: 100%; padding: 0; }
        }
    </style>
<link href="../assets/css/handdrawn.css" rel="stylesheet">
</head>
<body>
    <!-- Navbar -->
    <%@ include file="navbar.jspf" %>

    <!-- Main Content -->
    <div class="container py-4">
        <!-- Toolbar -->
        <div class="doc-toolbar">
            <div>
                <h2 class="mb-0 fw-bold" style="font-size: 1.25rem;"><i class="bi bi-award me-2 text-primary"></i>Transkrip Nilai</h2>
            </div>
            <div class="d-flex gap-2 flex-wrap">
                <button type="button" class="btn btn-outline-secondary btn-sm" onclick="window.print()">
                    <i class="bi bi-printer me-1"></i>Cetak / PDF
                </button>
                <a class="btn btn-outline-success btn-sm" href="../TranscriptServlet?action=export&format=csv<% for (Integer qid : selectedQuizIds) { %>&quizIds=<%= qid %><% } %>">
                    <i class="bi bi-filetype-csv me-1"></i>CSV
                </a>
                <a class="btn btn-outline-primary btn-sm" href="../TranscriptServlet?action=export&format=xls<% for (Integer qid : selectedQuizIds) { %>&quizIds=<%= qid %><% } %>">
                    <i class="bi bi-file-earmark-excel me-1"></i>Excel
                </a>
            </div>
        </div>

        <% if (error != null) { %>
        <div class="alert alert-danger alert-dismissible fade show">
            <i class="bi bi-exclamation-triangle me-2"></i><%= ValidationUtil.sanitizeHtml(error) %>
            <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
        </div>
        <% } %>

        <!-- The transcript document -->
        <div class="transcript-doc">
            <!-- Document header -->
            <div class="doc-seal"><i class="bi bi-patch-check-fill"></i></div>
            <div class="doc-org"><span class="org-mark">EXATUY</span> &middot; Adu Pintar Tanpa Ribet</div>
            <h1 class="doc-title">TRANSKRIP NILAI</h1>
            <div class="doc-subtitle">Dokumen Resmi Hasil Evaluasi Peserta</div>
            <hr class="doc-divider">

            <!-- Status row -->
            <div class="status-row">
                <span class="status-pill <%= "Final".equals(transcriptStatus) ? "final" : "interim" %>">
                    <span class="dot"></span>Status Transkrip: <%= transcriptStatus %>
                </span>
                <div class="completion-bar">
                    <div class="completion-head">
                        <span class="completion-label">Progress Penyelesaian</span>
                        <span class="completion-count"><%= myTakenCount %><span> / <%= totalQuizzes %> quiz</span></span>
                    </div>
                    <div class="completion-track">
                        <div class="completion-fill <%= completionPct >= 75 ? "high" : (completionPct >= 40 ? "mid" : "low") %>" style="width: <%= Math.max(completionPct, 2) %>%"></div>
                    </div>
                    <div class="completion-pct"><%= String.format("%.0f", completionPct) %>% selesai</div>
                </div>
            </div>

            <!-- Student info -->
            <div class="doc-section">
                <div class="section-heading">
                    <span class="bar"></span><span class="text">Informasi Peserta</span><span class="rule"></span>
                </div>
                <div class="info-grid">
                    <div class="info-row">
                        <div class="info-label">Nama</div>
                        <div class="info-value"><%= ValidationUtil.sanitizeHtml(currentUser.getName()) %></div>
                    </div>
                    <div class="info-row">
                        <div class="info-label">Email</div>
                        <div class="info-value"><%= ValidationUtil.sanitizeHtml(currentUser.getEmail()) %></div>
                    </div>
                    <div class="info-row">
                        <div class="info-label">Tag / Kelompok</div>
                        <div class="info-value"><%= myTag %></div>
                    </div>
                </div>
            </div>

            <!-- Grades table -->
            <div class="doc-section">
                <div class="section-heading">
                    <span class="bar"></span><span class="text">Daftar Quiz dan Nilai</span><span class="rule"></span>
                </div>
                <% if (columnQuizzes.isEmpty()) { %>
                <div class="empty-state">
                    <i class="bi bi-inbox fs-1 d-block mb-2 opacity-50"></i>
                    Belum ada quiz tersedia.
                </div>
                <% } else { %>
                <div class="table-responsive">
                    <table class="grades-table">
                        <thead>
                            <tr>
                                <th class="center">No</th>
                                <th>Quiz</th>
                                <th class="center">Nilai</th>
                                <th class="center">Grade</th>
                                <th class="center">Status</th>
                                <th>Tanggal</th>
                            </tr>
                        </thead>
                        <tbody>
                            <% int no = 1;
                               for (Quiz q : sortedQuizzes) {
                                   Map<String, Object> sub = myScores != null ? myScores.get(q.getId()) : null;
                                   boolean attempted = sub != null && sub.get("score") != null;
                                   boolean isTimeout = attempted && "timeout".equals(sub.get("status"));
                                   Object scoreObj = attempted ? sub.get("score") : null;
                                   double scoreVal = scoreObj instanceof Number ? ((Number) scoreObj).doubleValue() : 0;
                                   String grade = attempted ? gradeLetter(scoreVal) : "";
                                   String gradeCls = attempted ? gradeColorClass(grade) : "";
                                   LocalDateTime submittedAt = attempted && sub.get("submittedAt") instanceof LocalDateTime ? (LocalDateTime) sub.get("submittedAt") : null;
                                   String dateStr = submittedAt != null ? dateFormatter.format(submittedAt.atZone(ZoneId.of("Asia/Jakarta"))) : "&ndash;";
                                   String nilaiCls = attempted ? (scoreVal >= 75 ? "good" : (scoreVal >= 60 ? "mid" : "bad")) : "";
                            %>
                            <tr>
                                <td class="num"><%= no++ %></td>
                                <td class="quiz<%= attempted ? "" : " untaken" %>"><%= esc(q.getTitle()) %></td>
                                <% if (attempted) { %>
                                <td class="center nilai <%= nilaiCls %>"><%= fmtScore(scoreVal) %></td>
                                <td class="center"><span class="grade-badge <%= gradeCls %>"><%= grade %></span></td>
                                <% } else { %>
                                <td class="center text-muted">&ndash;</td>
                                <td class="center text-muted">&ndash;</td>
                                <% } %>
                                <td class="center">
                                    <% if (!attempted) { %>
                                    <span class="chip chip-pending"><i class="bi bi-dash-circle"></i>Belum Dikerjakan</span>
                                    <% } else if (isTimeout) { %>
                                    <span class="chip chip-timeout" title="Dikerjakan melebihi waktu"><i class="bi bi-clock-history"></i>Timeout</span>
                                    <% } else { %>
                                    <span class="chip chip-done"><i class="bi bi-check-circle"></i>Selesai</span>
                                    <% } %>
                                </td>
                                <td class="tgl"><%= dateStr %></td>
                            </tr>
                            <% } %>
                        </tbody>
                    </table>
                </div>
                <div class="legend-inline">
                    Skala grade: <strong>A</strong> (&ge;80)
                    &middot; <strong>B</strong> (70&ndash;79)
                    &middot; <strong>C</strong> (60&ndash;69)
                    &middot; <strong>D</strong> (50&ndash;59)
                    &middot; <strong>E</strong> (&lt;50)
                </div>
                <% } %>
            </div>

            <% if (!columnQuizzes.isEmpty()) { %>
            <!-- GPA / summary strip -->
            <div class="gpa-strip">
                <div class="gpa-item">
                    <div class="lbl">Nilai Rata-rata (Semua Quiz)</div>
                    <div class="val <%= myAvg != null && myAvg > 0 ? (myAvg >= 60 ? "good" : "bad") : "" %>"><%= myAvg != null && myAvg > 0 ? fmtScore(myAvg) : "&ndash;" %></div>
                </div>
                <div class="gpa-item">
                    <div class="lbl">Tertinggi</div>
                    <div class="val good"><%= myTakenCount > 0 ? fmtScore(myHighest) : "&ndash;" %></div>
                </div>
                <div class="gpa-item">
                    <div class="lbl">Terendah</div>
                    <div class="val <%= myTakenCount > 0 ? (myLowest >= 60 ? "good" : "bad") : "" %>"><%= myTakenCount > 0 ? fmtScore(myLowest) : "&ndash;" %></div>
                </div>
                <div class="gpa-item">
                    <div class="lbl">Quiz Dikerjakan</div>
                    <div class="val"><%= myTakenCount %></div>
                </div>
            </div>
            <% } %>

            <!-- Footer / signature -->
            <div class="doc-footer">
                <div class="sig-block">
                    <div class="sig-intro">Diterbitkan secara digital oleh</div>
                    <% if (!signaturePath.isEmpty()) { %>
                    <img src="../<%= esc(signaturePath) %>" alt="Tanda tangan" class="sig-img">
                    <% } %>
                    <div class="sig-line">
                        <div class="sig-name"><%= ValidationUtil.sanitizeHtml(signerName.isEmpty() ? orgName : signerName) %></div>
                        <% if (!signerTitle.isEmpty()) { %>
                        <div class="sig-title"><%= ValidationUtil.sanitizeHtml(signerTitle) %></div>
                        <% } %>
                        <div class="sig-org"><a href="<%= esc(orgUrlHref) %>" target="_blank" rel="noopener"><%= ValidationUtil.sanitizeHtml(orgUrl) %></a></div>
                    </div>
                </div>
            </div>

            <div class="footer-note">
                <i class="bi bi-shield-check me-1"></i>
                Dokumen ini diterbitkan otomatis oleh sistem Exatuy. Verifikasi keaslian melalui akun peserta.
            </div>
        </div>

    </div>

    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/js/bootstrap.bundle.min.js"></script>
</body>
</html>
