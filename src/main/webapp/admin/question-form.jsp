<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%@ page import="com.examora.model.User" %>
<%@ page import="com.examora.model.Quiz" %>
<%@ page import="com.examora.model.Question" %>
<%@ page import="com.examora.util.ValidationUtil" %>
<%
    User currentUser = (User) session.getAttribute("user");
    if (currentUser == null || !currentUser.isAdmin()) {
        response.sendRedirect("../LoginServlet");
        return;
    }
    Quiz quiz = (Quiz) request.getAttribute("quiz");
    Question question = (Question) request.getAttribute("question");
    boolean isEdit = question != null && question.getId() != null;
    String error = (String) request.getAttribute("error");
    String successParam = request.getParameter("success");

    if (quiz == null) {
        response.sendRedirect("../QuizServlet?action=list");
        return;
    }
%>
<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title><%= isEdit ? "Edit" : "Tambah" %> Soal - Exatuy</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
    <link href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.10.0/font/bootstrap-icons.css" rel="stylesheet">
    <link href="../assets/css/style.css" rel="stylesheet">
    <link rel="icon" type="image/svg+xml" type="image/svg+xml" href="../assets/img/favicon.svg?v=3">
<link href="../assets/css/handdrawn.css" rel="stylesheet">
</head>
<body>
    <!-- Sidebar -->
    <%@ include file="sidebar.jsp" %>

    <!-- Main Content -->
    <div class="main-content">
        <div class="d-flex justify-content-between align-items-center mb-4">
            <div>
                <h1 class="h3 mb-0"><%= isEdit ? "Edit" : "Tambah" %> Soal</h1>
                <nav aria-label="breadcrumb">
                    <ol class="breadcrumb mb-0">
                        <li class="breadcrumb-item"><a href="dashboard.jsp">Dashboard</a></li>
                        <li class="breadcrumb-item"><a href="../QuizServlet?action=list">Quiz</a></li>
                        <li class="breadcrumb-item"><a href="../QuestionServlet?action=list&quizId=<%= quiz.getId() %>"><%= ValidationUtil.sanitizeHtml(quiz.getTitle()) %></a></li>
                        <li class="breadcrumb-item active"><%= isEdit ? "Edit" : "Tambah" %> Soal</li>
                    </ol>
                </nav>
            </div>
        </div>

        <% if (error != null) { %>
        <div class="alert alert-danger alert-dismissible fade show">
            <i class="bi bi-exclamation-triangle me-2"></i><%= ValidationUtil.sanitizeHtml(error) %>
            <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
        </div>
        <% } %>

        <% if ("true".equals(successParam)) { %>
        <div class="alert alert-success alert-dismissible fade show">
            <i class="bi bi-check-circle me-2"></i>Pertanyaan berhasil ditambahkan. Silakan tambah pertanyaan berikutnya.
            <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
        </div>
        <% } %>

        <div class="row">
            <div class="col-lg-8">
                <div class="card">
                    <div class="card-header">
                        <h6 class="mb-0"><i class="bi bi-question-circle me-2"></i><%= ValidationUtil.sanitizeHtml(quiz.getTitle()) %></h6>
                    </div>
                    <div class="card-body">
                        <form action="../QuestionServlet" method="post" id="questionForm" enctype="multipart/form-data">
                        <input type="hidden" name="csrfToken" value="<%= session.getAttribute("csrfToken") %>" />
                            <input type="hidden" name="action" value="<%= isEdit ? "update" : "create" %>">
                            <input type="hidden" name="quizId" value="<%= quiz.getId() %>">
                            <% if (isEdit) { %>
                            <input type="hidden" name="id" value="<%= question.getId() %>">
                            <% } %>

                            <div class="mb-3">
                                <label for="questionText" class="form-label">Pertanyaan <span class="text-danger">*</span></label>
                                <textarea class="form-control" id="questionText" name="questionText" rows="3" required
                                          placeholder="Tulis pertanyaan di sini..."><%= isEdit ? ValidationUtil.sanitizeHtml(question.getQuestionText()) : "" %></textarea>
                            </div>

                            <div class="mb-3">
                                <label for="questionImage" class="form-label">Gambar Soal <span class="text-muted">(opsional)</span></label>
                                <input type="file" class="form-control" id="questionImage" name="questionImage"
                                       accept="image/jpeg,image/png,image/gif,image/webp">
                                <div class="form-text">Format: JPG, PNG, GIF, WebP. Maks 2MB.</div>
                                <% if (isEdit && question.getImagePath() != null && !question.getImagePath().isEmpty()) { %>
                                <div class="mt-2">
                                    <label class="form-check">
                                        <input type="checkbox" class="form-check-input" name="removeImage" value="true" id="removeImage">
                                        <span class="form-check-label text-danger">Hapus gambar yang ada</span>
                                    </label>
                                    <div class="mt-2">
                                        <img src="../<%= ValidationUtil.sanitizeHtml(question.getImagePath()) %>" alt="Current image"
                                             style="max-width: 200px; max-height: 150px; border-radius: 8px; border: 1px solid #dee2e6;"
                                             id="currentImage">
                                    </div>
                                </div>
                                <% } else { %>
                                <div class="mt-2" id="imagePreview" style="display: none;">
                                    <img src="" alt="Preview" id="previewImg"
                                         style="max-width: 200px; max-height: 150px; border-radius: 8px; border: 1px solid #dee2e6;">
                                </div>
                                <% } %>
                            </div>

                            <div class="row">
                                <div class="col-md-6 mb-3">
                                    <label for="optionA" class="form-label">Opsi A <span class="text-danger">*</span></label>
                                    <input type="text" class="form-control" id="optionA" name="optionA" required
                                           value="<%= isEdit ? ValidationUtil.sanitizeHtml(question.getOptionA()) : "" %>" placeholder="Jawaban A">
                                </div>
                                <div class="col-md-6 mb-3">
                                    <label for="optionB" class="form-label">Opsi B <span class="text-danger">*</span></label>
                                    <input type="text" class="form-control" id="optionB" name="optionB" required
                                           value="<%= isEdit ? ValidationUtil.sanitizeHtml(question.getOptionB()) : "" %>" placeholder="Jawaban B">
                                </div>
                                <div class="col-md-6 mb-3">
                                    <label for="optionC" class="form-label">Opsi C <span class="text-danger">*</span></label>
                                    <input type="text" class="form-control" id="optionC" name="optionC" required
                                           value="<%= isEdit ? ValidationUtil.sanitizeHtml(question.getOptionC()) : "" %>" placeholder="Jawaban C">
                                </div>
                                <div class="col-md-6 mb-3">
                                    <label for="optionD" class="form-label">Opsi D <span class="text-danger">*</span></label>
                                    <input type="text" class="form-control" id="optionD" name="optionD" required
                                           value="<%= isEdit ? ValidationUtil.sanitizeHtml(question.getOptionD()) : "" %>" placeholder="Jawaban D">
                                </div>
                            </div>

                            <div class="mb-4">
                                <label class="form-label">Jawaban Benar <span class="text-danger">*</span></label>
                                <div class="d-flex gap-3">
                                    <% String[] options = {"A", "B", "C", "D"};
                                       for (String opt : options) { %>
                                    <div class="form-check">
                                        <input class="form-check-input" type="radio" name="correctAnswer"
                                               id="answer<%= opt %>" value="<%= opt %>"
                                               <%= isEdit && opt.equals(question.getCorrectAnswer()) ? "checked" : "" %>
                                               <%= !isEdit && opt.equals("A") ? "checked" : "" %> required>
                                        <label class="form-check-label" for="answer<%= opt %>"><%= opt %></label>
                                    </div>
                                    <% } %>
                                </div>
                            </div>

                            <!-- Question Enhancement Fields -->
                            <div class="mb-3">
                                <label for="explanation" class="form-label">Pembahasan <span class="text-muted">(opsional)</span></label>
                                <textarea class="form-control" id="explanation" name="explanation" rows="3"
                                          placeholder="Penjelasan mengapa jawaban ini benar..."><%= isEdit && question.getExplanation() != null ? ValidationUtil.sanitizeHtml(question.getExplanation()) : "" %></textarea>
                                <div class="form-text">Pembahasan akan ditampilkan setelah peserta submit quiz (jika diaktifkan)</div>
                            </div>

                            <div class="d-flex gap-2">
                                <input type="hidden" name="saveAndAdd" id="saveAndAdd" value="">
                                <button type="submit" class="btn btn-primary" onclick="document.getElementById('saveAndAdd').value='';">
                                    <i class="bi bi-check-lg me-2"></i><%= isEdit ? "Update" : "Simpan" %>
                                </button>
                                <% if (!isEdit) { %>
                                <button type="submit" class="btn btn-success" onclick="document.getElementById('saveAndAdd').value='true';">
                                    <i class="bi bi-plus-lg me-2"></i>Simpan & Tambah Lagi
                                </button>
                                <% } %>
                                <a href="../QuestionServlet?action=list&quizId=<%= quiz.getId() %>" class="btn btn-outline-secondary">
                                    <i class="bi bi-x-lg me-2"></i>Batal
                                </a>
                            </div>
                        </form>
                    </div>
                </div>
            </div>

            <div class="col-lg-4">
                <div class="card">
                    <div class="card-header">
                        <h6 class="mb-0"><i class="bi bi-lightbulb me-2"></i>Panduan</h6>
                    </div>
                    <div class="card-body">
                        <ul class="list-unstyled mb-0">
                            <li class="mb-2"><i class="bi bi-check text-success me-2"></i>Tulis pertanyaan yang jelas dan tidak ambigu</li>
                            <li class="mb-2"><i class="bi bi-check text-success me-2"></i>Pastikan semua opsi jawaban terisi</li>
                            <li class="mb-2"><i class="bi bi-check text-success me-2"></i>Hanya ada satu jawaban yang benar</li>
                            <li class="mb-2"><i class="bi bi-check text-success me-2"></i>Hindari jawaban yang terlalu mirip</li>
                        </ul>
                    </div>
                </div>

                <div class="card mt-3">
                    <div class="card-header">
                        <h6 class="mb-0"><i class="bi bi-preview me-2"></i>Preview</h6>
                    </div>
                    <div class="card-body">
                        <div id="preview" class="border rounded p-3" style="min-height: 100px;">
                            <p id="previewQuestion" class="fw-bold mb-3 text-muted">Preview pertanyaan...</p>
                            <div id="previewOptions"></div>
                        </div>
                    </div>
                </div>

                <div class="card mt-3">
                    <div class="card-header">
                        <h6 class="mb-0"><i class="bi bi-lightbulb me-2"></i>Tips Pembahasan</h6>
                    </div>
                    <div class="card-body">
                        <ul class="list-unstyled mb-0 small">
                            <li class="mb-2"><i class="bi bi-check text-success me-2"></i>Jelaskan mengapa jawaban benar</li>
                            <li class="mb-2"><i class="bi bi-check text-success me-2"></i>Bisa sertakan referensi atau rumus</li>
                            <li class="mb-2"><i class="bi bi-check text-success me-2"></i>Pembahasan membantu peserta belajar</li>
                        </ul>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/js/bootstrap.bundle.min.js"></script>
    <script>
        // Live preview
        function updatePreview() {
            const questionEl = document.getElementById('questionText');
            const optAEl = document.getElementById('optionA');
            const optBEl = document.getElementById('optionB');
            const optCEl = document.getElementById('optionC');
            const optDEl = document.getElementById('optionD');

            const question = questionEl ? questionEl.value : '';
            const optA = optAEl ? (optAEl.value || '') : '';
            const optB = optBEl ? (optBEl.value || '') : '';
            const optC = optCEl ? (optCEl.value || '') : '';
            const optD = optDEl ? (optDEl.value || '') : '';
            const correct = document.querySelector('input[name="correctAnswer"]:checked');

            document.getElementById('previewQuestion').textContent = question || 'Preview pertanyaan...';
            document.getElementById('previewQuestion').classList.toggle('text-muted', !question);

            const previewOptions = document.getElementById('previewOptions');
            previewOptions.textContent = '';
            const options = [
                {label: 'A', value: optA},
                {label: 'B', value: optB},
                {label: 'C', value: optC},
                {label: 'D', value: optD}
            ];

            options.forEach(opt => {
                const isCorrect = correct && correct.value === opt.label;
                const displayValue = opt.value !== null && opt.value !== undefined && opt.value !== '' ? opt.value : '...';
                const optionDiv = document.createElement('div');
                optionDiv.className = 'mb-1' + (isCorrect ? ' text-success fw-bold' : '');
                optionDiv.textContent = opt.label + '. ' + displayValue;
                previewOptions.appendChild(optionDiv);
            });
        }

        document.querySelectorAll('input, textarea').forEach(el => {
            el.addEventListener('input', updatePreview);
        });
        document.querySelectorAll('input[type="radio"]').forEach(el => {
            el.addEventListener('change', updatePreview);
        });

        // Initial preview - wait for DOM to be fully loaded
        document.addEventListener('DOMContentLoaded', function() {
            updatePreview();
        });

        // Image preview
        document.getElementById('questionImage').addEventListener('change', function(e) {
            const file = e.target.files[0];
            if (file) {
                // Validate file size (max 2MB — PRD #19)
                if (file.size > 2 * 1024 * 1024) {
                    alert('Ukuran file terlalu besar. Maksimal 2MB.');
                    e.target.value = '';
                    return;
                }

                // Validate file type
                const validTypes = ['image/jpeg', 'image/png', 'image/gif', 'image/webp'];
                if (!validTypes.includes(file.type)) {
                    alert('Format file tidak didukung. Gunakan JPG, PNG, GIF, atau WebP.');
                    e.target.value = '';
                    return;
                }

                // Show preview
                const reader = new FileReader();
                reader.onload = function(e) {
                    const previewDiv = document.getElementById('imagePreview');
                    const previewImg = document.getElementById('previewImg');
                    const currentImg = document.getElementById('currentImage');

                    if (previewImg) {
                        previewImg.src = e.target.result;
                        previewDiv.style.display = 'block';
                    }
                    if (currentImg) {
                        currentImg.src = e.target.result;
                    }
                };
                reader.readAsDataURL(file);
            }
        });
    </script>
</body>
</html>
