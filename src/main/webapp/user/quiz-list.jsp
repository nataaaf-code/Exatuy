<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%@ page import="com.examora.model.User" %>
<%@ page import="com.examora.model.Quiz" %>
<%@ page import="com.examora.model.Submission" %>
<%@ page import="com.examora.dao.SettingsDAO" %>
<%@ page import="com.examora.service.ChatService" %>
<%@ page import="java.util.List" %>
<%@ page import="java.util.Map" %>
<%@ page import="java.time.ZoneId" %>
<%@ page import="java.time.format.DateTimeFormatter" %>
<%@ page import="com.examora.util.ValidationUtil" %>
<%
    User currentUser = (User) session.getAttribute("user");
    if (currentUser == null) {
        response.sendRedirect("../LoginServlet");
        return;
    }
    List<Quiz> quizzes = (List<Quiz>) request.getAttribute("quizzes");
    List<Quiz> expiredQuizzes = (List<Quiz>) request.getAttribute("expiredQuizzes");
    Map<Integer, Submission> userSubmissions = (Map<Integer, Submission>) request.getAttribute("userSubmissions");
    String error = (String) request.getAttribute("error");
    String gdriveLink = currentUser.getGdriveLink() != null ? currentUser.getGdriveLink().trim() : "";
    boolean hasSafeGdriveLink = gdriveLink.startsWith("https://drive.google.com/") || gdriveLink.startsWith("https://docs.google.com/");

    @SuppressWarnings("unchecked")
    List<Integer> retakeAccessibleQuizzes = (List<Integer>) request.getAttribute("retakeAccessibleQuizzes");

    // Check if chat is enabled
    boolean chatEnabled = new SettingsDAO().isChatEnabled();

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
    DateTimeFormatter dateFormatter = DateTimeFormatter.ofPattern("dd MMM yyyy").withZone(jakartaZone);
%>
<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Quiz Tersedia - Exatuy</title>
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
        <h2 class="mb-4"><i class="bi bi-journal-text me-2"></i>Quiz Tersedia</h2>

        <% if (error != null) { %>
        <div class="alert alert-danger alert-dismissible fade show">
            <i class="bi bi-exclamation-triangle me-2"></i><%= ValidationUtil.sanitizeHtml(error) %>
            <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
        </div>
        <% } %>

        <%-- Retake Code Input Section --%>
        <div class="card mb-4 border-primary">
            <div class="card-header bg-primary text-white">
                <i class="bi bi-key-fill me-2"></i>Gunakan Kode Retake
            </div>
            <div class="card-body">
                <p class="card-text mb-3">
                    <i class="bi bi-info-circle me-2"></i>
                    Jika Anda memiliki kode retake dari admin untuk quiz yang sudah lewat deadline, masukkan kode di sini.
                </p>
                <div class="input-group" style="max-width: 500px;">
                    <input type="text" class="form-control" id="retakeCodeInput"
                           placeholder="Masukkan kode retake (contoh: RET-ABCD1234)">
                    <button class="btn btn-primary" onclick="validateRetakeCode()">
                        <i class="bi bi-check-circle me-1"></i>Gunakan Kode
                    </button>
                </div>
            </div>
        </div>

        <% if (quizzes != null && !quizzes.isEmpty()) { %>
        <div class="row g-4">
            <% for (Quiz quiz : quizzes) {
                Submission sub = userSubmissions != null ? userSubmissions.get(quiz.getId()) : null;
                boolean hasSubmitted = sub != null && sub.isCompleted();
                boolean isTimeout = sub != null && sub.isTimeout();
                String headerColor = hasSubmitted ? (isTimeout ? "warning" : "success") : "primary";
            %>
            <div class="col-md-6 col-lg-4">
                <div class="card h-100">
                    <% boolean isRetakeAccessible = retakeAccessibleQuizzes != null && retakeAccessibleQuizzes.contains(quiz.getId()); %>
                    <div class="card-header bg-<%= headerColor %> <%= isTimeout ? "text-dark" : "text-white" %>">
                        <div class="d-flex justify-content-between align-items-center">
                            <span><%= ValidationUtil.sanitizeHtml(quiz.getTitle()) %></span>
                            <div class="d-flex gap-1">
                                <% if (isRetakeAccessible) { %>
                                    <span class="badge bg-warning text-dark" title="Quiz tersedia melalui kode retake">
                                        <i class="bi bi-key-fill"></i> Retake
                                    </span>
                                <% } %>
                                <% if (isTimeout) { %>
                                    <span class="badge bg-dark">Waktu Habis</span>
                                <% } else if (hasSubmitted) { %>
                                    <span class="badge bg-light text-success">Selesai</span>
                                <% } else { %>
                                    <span class="badge bg-light text-<%= isRetakeAccessible ? "warning" : "primary" %>">
                                        <%= isRetakeAccessible ? "Extended" : "Tersedia" %>
                                    </span>
                                <% } %>
                            </div>
                        </div>
                    </div>
                    <div class="card-body">
                        <p class="card-text">
                            <%= ValidationUtil.sanitizeHtml(quiz.getDescription() != null ? quiz.getDescription() : "Tidak ada deskripsi") %>
                        </p>
                        <hr>
                        <div class="row text-center mb-3">
                            <div class="col-4">
                                <i class="bi bi-clock d-block fs-4 text-muted"></i>
                                <small><%= quiz.getDuration() %> menit</small>
                            </div>
                            <div class="col-4">
                                <i class="bi bi-question-circle d-block fs-4 text-muted"></i>
                                <small><%= quiz.getQuestionCount() %> soal</small>
                            </div>
                            <div class="col-4">
                                <% if (quiz.getDeadline() != null) { %>
                                <i class="bi bi-calendar-event d-block fs-4 text-warning"></i>
                                <small><%= quiz.getDeadline().atZone(ZoneId.systemDefault()).withZoneSameInstant(jakartaZone).format(dateFormatter) %></small>
                                <% } else { %>
                                <i class="bi bi-infinity d-block fs-4 text-success"></i>
                                <small>Tanpa batas</small>
                                <% } %>
                            </div>
                        </div>
                        <% if (quiz.getDeadline() != null && !quiz.isExpired()) { %>
                        <div class="alert alert-warning py-2 mb-3 text-center">
                            <i class="bi bi-exclamation-triangle me-1"></i>
                            Deadline: <%= quiz.getFormattedDeadline() %>
                        </div>
                        <% } %>
                        <% if (hasSubmitted) { %>
                        <div class="alert alert-<%= isTimeout ? "warning" : "success" %> py-2 mb-3 text-center">
                            <% if (isTimeout) { %>
                            <i class="bi bi-clock-history me-1"></i>
                            <strong>Waktu Habis! Nilai: <%= String.format("%.0f", sub.getScore()) %></strong>
                            <% } else { %>
                            <strong>Nilai Anda: <%= String.format("%.0f", sub.getScore()) %></strong>
                            <% } %>
                        </div>
                        <% if (isTimeout) { %>
                        <div class="alert alert-info py-2 mb-3 text-center">
                            <i class="bi bi-info-circle me-1"></i>
                            <small>Hubungi admin untuk mengizinkan retake quiz ini</small>
                        </div>
                        <% } %>
                        <a href="../ExamServlet?action=result&submissionId=<%= sub.getId() %>"
                           class="btn btn-outline-<%= isTimeout ? "warning" : "primary" %> w-100">
                            <i class="bi bi-eye me-1"></i>Lihat Hasil
                        </a>
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
        <% } %>

        <%-- Expired Quizzes Section --%>
        <% if (expiredQuizzes != null && !expiredQuizzes.isEmpty()) { %>
        <div class="row mt-4">
            <div class="col-12">
                <h4 class="mb-3">
                    <i class="bi bi-calendar-x me-2 text-danger"></i>
                    <span class="text-danger">Quiz Kadaluarsa</span>
                    <span class="badge bg-danger ms-2"><%= expiredQuizzes.size() %></span>
                </h4>
                <div class="alert alert-warning mb-3">
                    <i class="bi bi-exclamation-triangle-fill me-2"></i>
                    <strong>Perhatian:</strong> Quiz berikut sudah melewati batas waktu pengerjaan (deadline).
                    Gunakan kode retake di atas jika Anda memiliki kode dari admin.
                </div>
            </div>
        </div>
        <div class="row g-4">
            <% for (Quiz quiz : expiredQuizzes) {
                Submission sub = userSubmissions != null ? userSubmissions.get(quiz.getId()) : null;
                boolean hasSubmitted = sub != null && sub.isCompleted();
                boolean isTimeout = sub != null && sub.isTimeout();

                // Check if quiz was targeted to this user's tag
                boolean isTargetedToUser = quiz.getTargetTag() != null && !quiz.getTargetTag().trim().isEmpty() &&
                                       quiz.getTargetTag().equals(currentUser.getTag());
                boolean isPublicQuiz = quiz.getTargetTag() == null || quiz.getTargetTag().trim().isEmpty();
            %>
            <div class="col-md-6 col-lg-4">
                <div class="card h-100 border-secondary">
                    <div class="card-header bg-secondary text-white">
                        <div class="d-flex justify-content-between align-items-center">
                            <span><%= ValidationUtil.sanitizeHtml(quiz.getTitle()) %></span>
                            <div class="d-flex gap-1">
                                <span class="badge bg-danger">
                                    <i class="bi bi-calendar-x me-1"></i>Kadaluarsa
                                </span>
                                <% if (isPublicQuiz) { %>
                                <span class="badge bg-info" title="Quiz terbuka untuk semua peserta">
                                    <i class="bi bi-globe me-1"></i>Public
                                </span>
                                <% } else if (isTargetedToUser) { %>
                                <span class="badge bg-success" title="Quiz ditujukan untuk tag Anda">
                                    <i class="bi bi-check-circle me-1"></i>Untuk Anda
                                </span>
                                <% } else { %>
                                <span class="badge bg-warning text-dark" title="Quiz ditujukan untuk tag lain">
                                    <i class="bi bi-tag me-1"></i><%= ValidationUtil.sanitizeHtml(quiz.getTargetTag() != null ? quiz.getTargetTag() : "-") %>
                                </span>
                                <% } %>
                            </div>
                        </div>
                    </div>
                    <div class="card-body">
                        <p class="card-text text-muted mb-3">
                            <%= ValidationUtil.sanitizeHtml(quiz.getDescription() != null && !quiz.getDescription().isEmpty() ? quiz.getDescription() : "Tidak ada deskripsi") %>
                        </p>
                        <div class="row mb-3">
                            <div class="col-4">
                                <div class="text-center">
                                    <i class="bi bi-clock d-block fs-4 text-muted"></i>
                                    <small><%= quiz.getDuration() %> menit</small>
                                </div>
                            </div>
                            <div class="col-4">
                                <div class="text-center">
                                    <i class="bi bi-question-circle d-block fs-4 text-muted"></i>
                                    <small><%= quiz.getQuestionCount() %> soal</small>
                                </div>
                            </div>
                            <div class="col-4">
                                <div class="text-center">
                                    <i class="bi bi-calendar-event d-block fs-4 text-danger"></i>
                                    <small><%= quiz.getDeadline().atZone(ZoneId.systemDefault()).withZoneSameInstant(jakartaZone).format(dateFormatter) %></small>
                                </div>
                            </div>
                        </div>
                        <div class="alert alert-warning py-2 mb-3 text-center">
                            <i class="bi bi-exclamation-triangle me-1"></i>
                            <strong>Deadline: <%= quiz.getFormattedDeadline() %></strong>
                        </div>
                        <% if (hasSubmitted) { %>
                        <div class="alert alert-<%= isTimeout ? "warning" : "success" %> py-2 mb-3 text-center">
                            <% if (isTimeout) { %>
                            <i class="bi bi-clock-history me-1"></i>
                            <strong>Waktu Habis! Nilai: <%= String.format("%.0f", sub.getScore()) %></strong>
                            <% } else { %>
                            <strong>Nilai Anda: <%= String.format("%.0f", sub.getScore()) %></strong>
                            <% } %>
                        </div>
                        <a href="../ExamServlet?action=result&submissionId=<%= sub.getId() %>"
                           class="btn btn-outline-<%= isTimeout ? "warning" : "success" %> w-100">
                            <i class="bi bi-eye me-1"></i>Lihat Hasil
                        </a>
                        <% } else { %>
                        <div class="alert alert-secondary py-2 mb-3 text-center mb-0">
                            <i class="bi bi-x-circle me-1"></i>
                            <strong>Tidak Dikerjakan</strong>
                            <br><small class="text-muted">Deadline telah berakhir</small>
                        </div>
                        <% } %>
                    </div>
                </div>
            </div>
            <% } %>
        </div>
        <% } %>

        <%-- Empty State --%>
        <% if ((quizzes == null || quizzes.isEmpty()) && (expiredQuizzes == null || expiredQuizzes.isEmpty())) { %>
        <div class="card">
            <div class="card-body text-center py-5">
                <i class="bi bi-journal-x display-1 text-muted mb-3 d-block"></i>
                <h5 class="text-muted">Belum ada quiz tersedia</h5>
                <p class="text-muted">Quiz akan muncul di sini setelah admin mempublish.</p>
                <a href="../ExamServlet?action=dashboard" class="btn btn-primary">
                    <i class="bi bi-arrow-left me-1"></i>Kembali ke Dashboard
                </a>
            </div>
        </div>
        <% } %>
    </div>

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

        function validateRetakeCode() {
            const code = document.getElementById('retakeCodeInput').value.trim().toUpperCase();
            if (!code) {
                alert('Silakan masukkan kode retake');
                return;
            }

            // Collect ALL quiz IDs (both active and expired)
            const allQuizIds = [];

            // Add active quiz IDs
            <% if (quizzes != null) {
                for (Quiz quiz : quizzes) { %>
                    allQuizIds.push(<%= quiz.getId() %>);
                <% }
            } %>

            // Add expired quiz IDs
            <% if (expiredQuizzes != null) {
                for (Quiz quiz : expiredQuizzes) { %>
                    allQuizIds.push(<%= quiz.getId() %>);
                <% }
            } %>

            if (allQuizIds.length === 0) {
                alert('Tidak ada quiz tersedia');
                return;
            }

            // Show loading state
            const inputField = document.getElementById('retakeCodeInput');
            const originalValue = inputField.value;
            inputField.disabled = true;
            inputField.value = 'Memvalidasi...';

            // Try to validate code for each quiz
            let attempts = 0;
            let success = false;

            allQuizIds.forEach(function(quizId) {
                if (success) return;

                fetch('../ExamServlet?action=validateRetakeCode&code=' + encodeURIComponent(code) + '&quizId=' + quizId, {
                    method: 'GET'
                })
                .then(response => response.json())
                .then(data => {
                    attempts++;
                    if (data.success) {
                        success = true;
                        showRetakeSuccessModal(data.quizId);
                    } else if (attempts === allQuizIds.length && !success) {
                        inputField.disabled = false;
                        inputField.value = originalValue;
                        showRetakeErrorModal(data.message || 'Kode retake tidak valid untuk quiz manapun');
                    }
                })
                .catch(error => {
                    console.error('Error:', error);
                    attempts++;
                    if (attempts === allQuizIds.length && !success) {
                        inputField.disabled = false;
                        inputField.value = originalValue;
                        showRetakeErrorModal('Terjadi kesalahan saat memvalidasi kode');
                    }
                });
            });
        }

        function showRetakeSuccessModal(quizId) {
            var modalHtml = '<div class="modal fade" id="retakeSuccessModal" tabindex="-1" data-bs-backdrop="static" data-bs-keyboard="false">' +
                '<div class="modal-dialog modal-dialog-centered">' +
                '<div class="modal-content border-0 shadow-lg">' +
                '<div class="modal-header bg-success text-white border-0">' +
                '<h5 class="modal-title fw-bold">' +
                '<i class="bi bi-check-circle me-2"></i>Kode Retake Valid!' +
                '</h5>' +
                '</div>' +
                '<div class="modal-body text-center py-5">' +
                '<div class="mb-4">' +
                '<div class="bg-success bg-opacity-10 rounded-circle d-inline-flex align-items-center justify-content-center"' +
                'style="width: 100px; height: 100px;">' +
                '<i class="bi bi-unlock text-success" style="font-size: 3rem;"></i>' +
                '</div>' +
                '</div>' +
                '<h5 class="fw-bold mb-3">Akses Quiz Diberikan!</h5>' +
                '<p class="text-muted mb-4">Kode retake Anda berhasil divalidasi. Anda akan diarahkan ke halaman quiz dalam beberapa detik...</p>' +
                '<div class="alert alert-success d-inline-block">' +
                '<i class="bi bi-info-circle me-2"></i>' +
                '<strong>Info:</strong> Quiz akan segera dimulai. Pastikan koneksi internet stabil.' +
                '</div>' +
                '<div class="mt-4">' +
                '<div class="progress" style="height: 6px;">' +
                '<div class="progress-bar progress-bar-striped progress-bar-animated bg-success" role="progressbar"' +
                'style="width: 100%" aria-valuenow="100" aria-valuemin="0" aria-valuemax="100"></div>' +
                '</div>' +
                '</div>' +
                '</div>' +
                '</div>' +
                '</div>' +
                '</div>';

            // Remove existing modal if any
            var existingModal = document.getElementById('retakeSuccessModal');
            if (existingModal) existingModal.remove();

            document.body.insertAdjacentHTML('beforeend', modalHtml);

            var modal = new bootstrap.Modal(document.getElementById('retakeSuccessModal'));
            modal.show();

            // Auto-redirect after 2.5 seconds
            setTimeout(function() {
                window.location.href = '../ExamServlet?action=start&quizId=' + quizId;
            }, 2500);
        }

        function escapeHtml(text) {
            const div = document.createElement('div');
            div.textContent = text || '';
            return div.innerHTML;
        }

        function showRetakeErrorModal(message) {
            var modalHtml = '<div class="modal fade" id="retakeErrorModal" tabindex="-1">' +
                '<div class="modal-dialog modal-dialog-centered">' +
                '<div class="modal-content border-0 shadow-lg">' +
                '<div class="modal-header bg-danger text-white border-0">' +
                '<h5 class="modal-title fw-bold">' +
                '<i class="bi bi-x-circle me-2"></i>Kode Retake Tidak Valid' +
                '</h5>' +
                '<button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal"></button>' +
                '</div>' +
                '<div class="modal-body text-center py-5">' +
                '<div class="mb-4">' +
                '<div class="bg-danger bg-opacity-10 rounded-circle d-inline-flex align-items-center justify-content-center"' +
                'style="width: 100px; height: 100px;">' +
                '<i class="bi bi-key text-danger" style="font-size: 3rem;"></i>' +
                '</div>' +
                '</div>' +
                '<h5 class="fw-bold mb-3">Kode Tidak Dapat Digunakan</h5>' +
                '<p class="text-muted mb-4">' + escapeHtml(message) + '</p>' +
                '<div class="alert alert-warning d-inline-block">' +
                '<i class="bi bi-lightbulb me-2"></i>' +
                '<strong>Tips:</strong> Pastikan kode yang dimasukkan benar. Hubungi admin jika Anda memerlukan kode retake baru.' +
                '</div>' +
                '</div>' +
                '<div class="modal-footer border-0">' +
                '<button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Tutup</button>' +
                '<button type="button" class="btn btn-primary" onclick="closeRetakeErrorModalAndFocus()">Coba Lagi</button>' +
                '</div>' +
                '</div>' +
                '</div>' +
                '</div>';

            // Remove existing modal if any
            var existingModal = document.getElementById('retakeErrorModal');
            if (existingModal) existingModal.remove();

            document.body.insertAdjacentHTML('beforeend', modalHtml);

            var modal = new bootstrap.Modal(document.getElementById('retakeErrorModal'));
            modal.show();
        }

        function closeRetakeErrorModalAndFocus() {
            var modalElement = document.getElementById('retakeErrorModal');
            if (modalElement) {
                var modal = bootstrap.Modal.getInstance(modalElement);
                if (modal) modal.hide();
            }
            document.getElementById('retakeCodeInput').focus();
        }
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
