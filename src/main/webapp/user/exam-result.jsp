<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%@ page import="com.examora.model.User" %>
<%@ page import="com.examora.model.Quiz" %>
<%@ page import="com.examora.model.Submission" %>
<%@ page import="com.examora.model.Answer" %>
<%@ page import="com.examora.util.ValidationUtil" %>
<%@ page import="java.util.List" %>
<%@ page import="java.time.ZoneId" %>
<%@ page import="java.time.format.DateTimeFormatter" %>
<%
    User currentUser = (User) session.getAttribute("user");
    if (currentUser == null) {
        response.sendRedirect("../LoginServlet");
        return;
    }
    Submission submission = (Submission) request.getAttribute("submission");
    Quiz quiz = (Quiz) request.getAttribute("quiz");
    if (submission == null) {
        response.sendRedirect("../ExamServlet?action=list");
        return;
    }
    List<Answer> answers = submission.getAnswers();

    // Check if review mode is enabled
    boolean showReview = quiz == null || quiz.getShowReview() == null || quiz.getShowReview();

    // Check if correct answers should be hidden (retake exploit prevention)
    boolean hideCorrectAnswers = Boolean.TRUE.equals(request.getAttribute("hideCorrectAnswers"));

    // Determine score class
    String scoreClass = "poor";
    if (submission.getScore() >= 90) scoreClass = "excellent";
    else if (submission.getScore() >= 75) scoreClass = "good";
    else if (submission.getScore() >= 60) scoreClass = "average";

    String scoreMessage = "";
    if (submission.getScore() >= 90) scoreMessage = "Luar biasa! Performa sangat baik!";
    else if (submission.getScore() >= 75) scoreMessage = "Bagus! Anda lulus dengan baik.";
    else if (submission.getScore() >= 60) scoreMessage = "Cukup baik. Masih bisa ditingkatkan.";
    else scoreMessage = "Perlu belajar lebih giat lagi.";

    String gdriveLink = currentUser.getGdriveLink() != null ? currentUser.getGdriveLink().trim() : "";
    boolean hasSafeGdriveLink = gdriveLink.startsWith("https://drive.google.com/") || gdriveLink.startsWith("https://docs.google.com/");

    ZoneId jakartaZone = ZoneId.of("Asia/Jakarta");
    DateTimeFormatter dateFormatter = DateTimeFormatter.ofPattern("dd MMM yyyy").withZone(jakartaZone);
%>
<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Hasil Ujian - Exatuy</title>
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
    <div class="container py-5">
        <!-- Result Summary -->
        <div class="result-summary mb-5 fade-in">
            <div class="row align-items-center">
                <div class="col-md-6 text-center">
                    <h2 class="mb-3">
                        <%= ValidationUtil.sanitizeHtml(submission.getQuizTitle()) %>
                        <% if (submission.getIsRetake() != null && submission.getIsRetake()) { %>
                            <span class="badge bg-warning text-dark ms-2">
                                <i class="bi bi-arrow-clockwise"></i> Retake
                            </span>
                        <% } %>
                        <% if (submission.isTimeout()) { %>
                            <span class="badge bg-danger ms-2">
                                <i class="bi bi-clock-history"></i> Timeout
                            </span>
                        <% } %>
                    </h2>
                    <div class="score-display <%= scoreClass %>">
                        <%= String.format("%.0f", submission.getScore()) %>
                    </div>
                    <p class="lead mt-2"><%= scoreMessage %></p>
                </div>
                <div class="col-md-6">
                    <div class="row text-center">
                        <div class="col-4">
                            <div class="border-end">
                                <h4><%= submission.getTotalQuestions() %></h4>
                                <small class="opacity-75">Total Soal</small>
                            </div>
                        </div>
                        <div class="col-4">
                            <div class="border-end">
                                <h4 class="text-success"><%= submission.getCorrectAnswers() %></h4>
                                <small class="opacity-75">Benar</small>
                            </div>
                        </div>
                        <div class="col-4">
                            <h4 class="text-danger"><%= submission.getTotalQuestions() - submission.getCorrectAnswers() %></h4>
                            <small class="opacity-75">Salah</small>
                        </div>
                    </div>
                    <hr class="my-3 opacity-25">
                    <div class="row">
                        <div class="col-6">
                            <i class="bi bi-clock me-2"></i>Waktu: <%= submission.getFormattedTimeSpent() %>
                        </div>
                        <div class="col-6">
                            <i class="bi bi-calendar me-2"></i><%= submission.getSubmittedAt() != null ?
                                submission.getSubmittedAt().atZone(ZoneId.systemDefault()).withZoneSameInstant(jakartaZone).format(dateFormatter) : "-" %>
                        </div>
                    </div>
                </div>
            </div>
        </div>

        <!-- Action Buttons -->
        <div class="text-center mb-4">
            <a href="../ExamServlet?action=list" class="btn btn-primary btn-lg me-2">
                <i class="bi bi-journal-text me-2"></i>Quiz Lainnya
            </a>
            <a href="../ExamServlet?action=dashboard" class="btn btn-outline-primary btn-lg">
                <i class="bi bi-house me-2"></i>Dashboard
            </a>
        </div>

        <!-- Answer Review -->
        <% if (showReview) { %>
        <div class="card">
            <div class="card-header">
                <h5 class="mb-0"><i class="bi bi-list-check me-2"></i>Review Jawaban</h5>
            </div>
            <div class="card-body">
                <% if (answers != null && !answers.isEmpty()) {
                    for (int i = 0; i < answers.size(); i++) {
                        Answer ans = answers.get(i);
                        boolean isCorrect = ans.getIsCorrect() != null && ans.getIsCorrect();
                        String userAnswer = ans.getSelectedAnswer();
                        boolean hasAnswer = userAnswer != null && !userAnswer.isEmpty();
                %>
                <div class="card mb-3 border-<%= isCorrect ? "success" : "danger" %>">
                    <div class="card-header bg-<%= isCorrect ? "success" : "danger" %> text-white py-2">
                        <div class="d-flex justify-content-between align-items-center">
                            <span><strong>Soal #<%= i + 1 %></strong></span>
                            <span>
                                <% if (isCorrect) { %>
                                <i class="bi bi-check-circle-fill me-1"></i>Benar
                                <% } else { %>
                                <i class="bi bi-x-circle-fill me-1"></i>Salah
                                <% } %>
                            </span>
                        </div>
                    </div>
                    <div class="card-body">
                        <p class="mb-3"><%= ValidationUtil.sanitizeHtml(ans.getQuestionText() != null ? ans.getQuestionText() : "Pertanyaan tidak tersedia") %></p>
                        <% if (ans.getImagePath() != null && !ans.getImagePath().isEmpty()) { %>
                        <div class="mb-3 text-center">
                            <img src="../<%= ans.getImagePath() %>" alt="Question Image"
                                 class="img-fluid rounded" style="max-width: 100%; max-height: 300px;">
                        </div>
                        <% } %>
                        <div class="row">
                            <div class="col-12">
                                <p class="mb-1">
                                    <strong>Jawaban Anda:</strong>
                                    <span class="<%= isCorrect ? "text-success" : "text-danger" %>">
                                        <%= ValidationUtil.sanitizeHtml(hasAnswer ? userAnswer + ". " + (ans.getSelectedAnswerText() != null ? ans.getSelectedAnswerText() : "") : "Tidak dijawab") %>
                                    </span>
                                </p>
                            </div>
                        </div>
                        <%-- Show explanation/solution if available --%>
                        <% if (ans.getExplanation() != null && !ans.getExplanation().isEmpty()) { %>
                        <div class="mt-3 p-2 bg-light rounded">
                            <p class="mb-0">
                                <i class="bi bi-lightbulb text-warning me-2"></i>
                                <strong>Pembahasan:</strong> <%= ValidationUtil.sanitizeHtml(ans.getExplanation()) %>
                            </p>
                        </div>
                        <% } %>
                    </div>
                </div>
                <% }
                } else { %>
                <div class="text-center py-4 text-muted">
                    <i class="bi bi-eye-slash display-4 d-block mb-2"></i>
                    Tidak ada detail jawaban tersedia.
                </div>
                <% } %>
            </div>
        </div>
        <% } else { %>
        <div class="card">
            <div class="card-body text-center py-5">
                <i class="bi bi-eye-slash display-1 text-muted mb-3 d-block"></i>
                <h5 class="text-muted">Review Jawaban Tidak Tersedia</h5>
                <p class="text-muted mb-0">Admin tidak mengaktifkan fitur review jawaban untuk quiz ini.</p>
            </div>
        </div>
        <% } %>
    </div>

    <!-- Footer -->
    <footer class="bg-light py-3 mt-auto">
        <div class="container text-center">
            <span class="text-muted">&copy; 2026 Exatuy. All rights reserved.</span>
        </div>
    </footer>

    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/js/bootstrap.bundle.min.js"></script>

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
