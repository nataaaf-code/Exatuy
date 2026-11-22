<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%@ page import="com.examora.model.User" %>
<%@ page import="com.examora.model.Quiz" %>
<%@ page import="com.examora.service.UserService" %>
<%@ page import="java.time.LocalDateTime" %>
<%@ page import="java.time.ZoneId" %>
<%@ page import="java.time.ZonedDateTime" %>
<%@ page import="java.time.format.DateTimeFormatter" %>
<%@ page import="java.util.List" %>
<%@ page import="java.util.ArrayList" %>
<%@ page import="java.util.Arrays" %>
<%@ page import="java.util.HashSet" %>
<%@ page import="com.examora.util.ValidationUtil" %>
<%
    User currentUser = (User) session.getAttribute("user");
    if (currentUser == null || !currentUser.isAdmin()) {
        response.sendRedirect("../LoginServlet");
        return;
    }
    Quiz quiz = (Quiz) request.getAttribute("quiz");
    boolean isEdit = quiz != null && quiz.getId() != null;
    String error = (String) request.getAttribute("error");

    // Get all tags
    UserService userService = new UserService();
    List<String> tags = null;
    try {
        tags = userService.getAllTags();
    } catch (Exception e) {
        // Ignore
    }

    // Format deadline for separate date and time inputs (in Jakarta timezone)
    ZoneId jakartaZone = ZoneId.of("Asia/Jakarta");

    // Extract deadline components
    String deadlineDate = "";
    String deadlineHour = "";
    String deadlineMinute = "";

    if (isEdit && quiz.getDeadline() != null) {
        ZonedDateTime zdt = quiz.getDeadline().atZone(ZoneId.systemDefault()).withZoneSameInstant(jakartaZone);
        deadlineDate = zdt.format(DateTimeFormatter.ofPattern("yyyy-MM-dd"));
        deadlineHour = String.format("%02d", zdt.getHour());
        deadlineMinute = String.valueOf(zdt.getMinute());
    }

    // Extract start time components
    String startTimeDate = "";
    String startTimeHour = "";
    String startTimeMinute = "";

    if (isEdit && quiz.getStartTime() != null) {
        ZonedDateTime zdt = quiz.getStartTime().atZone(ZoneId.systemDefault()).withZoneSameInstant(jakartaZone);
        startTimeDate = zdt.format(DateTimeFormatter.ofPattern("yyyy-MM-dd"));
        startTimeHour = String.format("%02d", zdt.getHour());
        startTimeMinute = String.valueOf(zdt.getMinute());
    }

    // Get exemption time value
    String exemptionTimeValue = "";
    if (isEdit && quiz.getExemptionTime() != null) {
        exemptionTimeValue = String.valueOf(quiz.getExemptionTime());
    }

    // Get current target tags as a Set for multi-select
    HashSet<String> currentTargetTags = new HashSet<>();
    if (isEdit && quiz.getTargetTag() != null && !quiz.getTargetTag().isEmpty() && !"ALL".equals(quiz.getTargetTag())) {
        String[] tagArray = quiz.getTargetTag().split(",");
        for (String tag : tagArray) {
            currentTargetTags.add(tag.trim());
        }
    }
%>
<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title><%= isEdit ? "Edit" : "Buat" %> Quiz - Exatuy</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
    <link href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.10.0/font/bootstrap-icons.css" rel="stylesheet">
    <link href="../assets/css/style.css" rel="stylesheet">
    <link rel="icon" type="image/svg+xml" type="image/svg+xml" href="../assets/img/favicon.svg?v=3">
    <style>
        .deadline-container {
            border: 1px solid #dee2e6;
            border-radius: 0.375rem;
            padding: 1rem;
            background: #f8f9fa;
        }
        .deadline-container input[type="date"],
        .deadline-container select {
            background: white;
        }
        .deadline-container .form-label {
            font-weight: 500;
            color: #495057;
        }
    </style>
<link href="../assets/css/handdrawn.css" rel="stylesheet">
</head>
<body>
    <!-- Sidebar -->
    <%@ include file="sidebar.jsp" %>

    <!-- Main Content -->
    <div class="main-content">
        <div class="d-flex justify-content-between align-items-center mb-4">
            <div>
                <h1 class="h3 mb-0"><%= isEdit ? "Edit" : "Buat" %> Quiz</h1>
                <nav aria-label="breadcrumb">
                    <ol class="breadcrumb mb-0">
                        <li class="breadcrumb-item"><a href="../AdminServlet?action=dashboard">Dashboard</a></li>
                        <li class="breadcrumb-item"><a href="../QuizServlet?action=list">Quiz</a></li>
                        <li class="breadcrumb-item active"><%= isEdit ? "Edit" : "Buat" %></li>
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

        <div class="row">
            <div class="col-lg-8">
                <div class="card">
                    <div class="card-body">
                        <form action="../QuizServlet" method="post">
                        <input type="hidden" name="csrfToken" value="<%= session.getAttribute("csrfToken") %>" />
                            <input type="hidden" name="action" value="<%= isEdit ? "update" : "create" %>">
                            <% if (isEdit) { %>
                            <input type="hidden" name="id" value="<%= quiz.getId() %>">
                            <% } %>

                            <div class="mb-3">
                                <label for="title" class="form-label">Judul Quiz <span class="text-danger">*</span></label>
                                <input type="text" class="form-control" id="title" name="title" required
                                       value="<%= isEdit ? ValidationUtil.sanitizeHtml(quiz.getTitle()) : "" %>"
                                       placeholder="Contoh: Ujian Tengah Semester Matematika">
                            </div>

                            <div class="mb-3">
                                <label for="subject" class="form-label">Mata Pelajaran</label>
                                <% String currentSubject = isEdit && quiz.getSubject() != null ? quiz.getSubject() : ""; %>
                                <select class="form-select" id="subject" name="subject">
                                    <option value="">-- Pilih Mata Pelajaran --</option>
                                    <option value="Matematika" <%= "Matematika".equalsIgnoreCase(currentSubject) ? "selected" : "" %>>Matematika</option>
                                    <option value="IPA" <%= "IPA".equalsIgnoreCase(currentSubject) ? "selected" : "" %>>IPA</option>
                                    <option value="Bahasa Indonesia" <%= "Bahasa Indonesia".equalsIgnoreCase(currentSubject) ? "selected" : "" %>>Bahasa Indonesia</option>
                                    <option value="Bahasa Inggris" <%= "Bahasa Inggris".equalsIgnoreCase(currentSubject) ? "selected" : "" %>>Bahasa Inggris</option>
                                    <option value="IPS" <%= "IPS".equalsIgnoreCase(currentSubject) ? "selected" : "" %>>IPS</option>
                                    <option value="Umum" <%= "Umum".equalsIgnoreCase(currentSubject) ? "selected" : "" %>>Umum</option>
                                </select>
                                <div class="form-text">Digunakan untuk filter mata pelajaran pada Rekap Nilai (Transcript).</div>
                            </div>

                            <div class="mb-3">
                                <label for="description" class="form-label">Deskripsi</label>
                                <textarea class="form-control" id="description" name="description" rows="3"
                                          placeholder="Deskripsi singkat tentang quiz ini"><%= isEdit && quiz.getDescription() != null ? ValidationUtil.sanitizeHtml(quiz.getDescription()) : "" %></textarea>
                            </div>

                            <div class="row">
                                <div class="col-md-6">
                                    <div class="mb-3">
                                        <label for="duration" class="form-label">Durasi (menit) <span class="text-danger">*</span></label>
                                        <input type="number" class="form-control" id="duration" name="duration"
                                               min="1" max="180" required
                                               value="<%= isEdit ? quiz.getDuration() : 30 %>">
                                        <div class="form-text">Durasi maksimal 180 menit (3 jam)</div>
                                    </div>
                                </div>
                                <div class="col-md-6">
                                    <div class="mb-3">
                                        <label class="form-label">Deadline Quiz <span class="text-muted">(opsional)</span></label>
                                        <!-- Date Input -->
                                        <div class="mb-2">
                                            <input type="date" class="form-control" name="deadlineDate"
                                                   id="deadlineDate" value="<%= deadlineDate %>"
                                                   placeholder="Pilih tanggal deadline">
                                        </div>
                                        <!-- Time Input -->
                                        <div class="row g-2">
                                            <div class="col-6">
                                                <select class="form-select" name="deadlineHour" id="deadlineHour">
                                                    <option value="">Jam</option>
                                                    <% for (int h = 0; h <= 23; h++) { %>
                                                        <option value="<%= h %>" <%= deadlineHour.equals(String.format("%02d", h)) ? "selected" : "" %>>
                                                            <%= String.format("%02d", h) %>
                                                        </option>
                                                    <% } %>
                                                </select>
                                            </div>
                                            <div class="col-6">
                                                <select class="form-select" name="deadlineMinute" id="deadlineMinute">
                                                    <option value="">Menit</option>
                                                    <option value="0" <%= "0".equals(deadlineMinute) ? "selected" : "" %>>00</option>
                                                    <option value="15" <%= "15".equals(deadlineMinute) ? "selected" : "" %>>15</option>
                                                    <option value="30" <%= "30".equals(deadlineMinute) ? "selected" : "" %>>30</option>
                                                    <option value="45" <%= "45".equals(deadlineMinute) ? "selected" : "" %>>45</option>
                                                </select>
                                            </div>
                                        </div>
                                        <div class="form-text mt-2">
                                            <i class="bi bi-info-circle me-1"></i>
                                            WIB (00-23) • Kosongkan jika tidak ada deadline
                                        </div>
                                    </div>
                                </div>
                            </div>

                            <!-- Start Time (Auto-Publish Schedule) -->
                            <div class="row">
                                <div class="col-md-6">
                                    <div class="mb-3">
                                        <label class="form-label">
                                            <i class="bi bi-clock-history me-1"></i>Waktu Mulai (Auto-Publish)
                                            <span class="text-muted">(opsional)</span>
                                        </label>
                                        <div class="deadline-container">
                                            <!-- Date Input -->
                                            <div class="mb-2">
                                                <input type="date" class="form-control" name="startTimeDate"
                                                       id="startTimeDate" value="<%= startTimeDate %>"
                                                       placeholder="Pilih tanggal mulai">
                                            </div>
                                            <!-- Time Input -->
                                            <div class="row g-2">
                                                <div class="col-6">
                                                    <select class="form-select" name="startTimeHour" id="startTimeHour">
                                                        <option value="">Jam</option>
                                                        <% for (int h = 0; h <= 23; h++) { %>
                                                            <option value="<%= h %>" <%= startTimeHour.equals(String.format("%02d", h)) ? "selected" : "" %>>
                                                                <%= String.format("%02d", h) %>
                                                            </option>
                                                        <% } %>
                                                    </select>
                                                </div>
                                                <div class="col-6">
                                                    <select class="form-select" name="startTimeMinute" id="startTimeMinute">
                                                        <option value="">Menit</option>
                                                        <option value="0" <%= "0".equals(startTimeMinute) ? "selected" : "" %>>00</option>
                                                        <option value="15" <%= "15".equals(startTimeMinute) ? "selected" : "" %>>15</option>
                                                        <option value="30" <%= "30".equals(startTimeMinute) ? "selected" : "" %>>30</option>
                                                        <option value="45" <%= "45".equals(startTimeMinute) ? "selected" : "" %>>45</option>
                                                    </select>
                                                </div>
                                            </div>
                                        </div>
                                        <div class="form-text mt-2">
                                            <i class="bi bi-info-circle me-1"></i>
                                            Quiz akan otomatis publish pada waktu ini. Kosongkan jika ingin manual publish.
                                        </div>
                                    </div>
                                </div>
                            </div>

                            <div class="mb-3">
                                <label class="form-label">Target Peserta <span class="text-muted">(opsional)</span></label>
                                <div class="border rounded p-3" style="max-height: 200px; overflow-y: auto;">
                                    <div class="form-check mb-2">
                                        <input class="form-check-input" type="checkbox" id="tagAll" name="targetTags" value="ALL"
                                               <%= currentTargetTags.isEmpty() ? "checked" : "" %>>
                                        <label class="form-check-label" for="tagAll">
                                            <strong>-- Semua Peserta --</strong>
                                        </label>
                                    </div>
                                    <hr class="my-2">
                                    <% if (tags != null && !tags.isEmpty()) {
                                        for (String tag : tags) { %>
                                    <div class="form-check">
                                        <input class="form-check-input target-tag-checkbox" type="checkbox" id="tag<%= ValidationUtil.sanitizeHtml(tag.replace("-", "")) %>" name="targetTags" value="<%= ValidationUtil.sanitizeHtml(tag) %>"
                                               <%= currentTargetTags.contains(tag) ? "checked" : "" %>>
                                        <label class="form-check-label" for="tag<%= ValidationUtil.sanitizeHtml(tag.replace("-", "")) %>">
                                            <%= ValidationUtil.sanitizeHtml(tag) %>
                                        </label>
                                    </div>
                                    <% }
                                    } else { %>
                                    <div class="text-muted small">Belum ada tag tersedia</div>
                                    <% } %>
                                </div>
                                <div class="form-text">Pilih satu atau beberapa tag untuk membatasi quiz hanya untuk peserta tertentu. Pilih "Semua Peserta" untuk semua user</div>
                            </div>

                            <!-- Quiz Enhancement Options -->
                            <div class="mb-3">
                                <label class="form-label">Pengaturan Quiz</label>
                                <div class="border rounded p-3">
                                    <div class="form-check mb-2">
                                        <input class="form-check-input" type="checkbox" id="shuffleQuestions" name="shuffleQuestions"
                                               <%= !isEdit || (quiz.getShuffleQuestions() == null || quiz.getShuffleQuestions()) ? "checked" : "" %>>
                                        <label class="form-check-label" for="shuffleQuestions">
                                            <i class="bi bi-shuffle me-1"></i> <strong>Acak Urutan Soal</strong>
                                        </label>
                                        <div class="form-text ms-4">Soal akan ditampilkan dalam urutan acak untuk setiap peserta</div>
                                    </div>
                                    <div class="form-check">
                                        <input class="form-check-input" type="checkbox" id="showReview" name="showReview"
                                               <%= !isEdit || (quiz.getShowReview() == null || quiz.getShowReview()) ? "checked" : "" %>>
                                        <label class="form-check-label" for="showReview">
                                            <i class="bi bi-eye me-1"></i> <strong>Tampilkan Pembahasan</strong>
                                        </label>
                                        <div class="form-text ms-4">Peserta dapat melihat pembahasan jawaban setelah submit quiz</div>
                                    </div>
                                </div>
                            </div>

                            <% if (isEdit) { %>
                            <div class="mb-3">
                                <label for="exemptionTime" class="form-label">
                                    <i class="bi bi-clock me-1"></i>Waktu Pengerjaan Peserta Dikecualikan
                                    <span class="text-muted">(menit)</span>
                                </label>
                                <input type="number" class="form-control" id="exemptionTime" name="exemptionTime"
                                       min="1" max="180"
                                       value="<%= exemptionTimeValue %>"
                                       placeholder="Default: 10 menit">
                                <div class="form-text">Waktu pengerjaan acak untuk peserta yang dikecualikan (auto 100). Kosongkan untuk default 10 menit.</div>
                            </div>
                            <% } %>


                            <div class="d-flex gap-2">
                                <button type="submit" class="btn btn-primary">
                                    <i class="bi bi-check-lg me-2"></i><%= isEdit ? "Update" : "Simpan" %>
                                </button>
                                <a href="../QuizServlet?action=list" class="btn btn-outline-secondary">
                                    <i class="bi bi-x-lg me-2"></i>Batal
                                </a>
                                <% if (!isEdit) { %>
                                <button type="submit" name="addQuestions" value="true" class="btn btn-success">
                                    <i class="bi bi-list-check me-2"></i>Simpan & Tambah Soal
                                </button>
                                <% } %>
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
                            <li class="mb-2"><i class="bi bi-check text-success me-2"></i>Buat judul yang jelas dan deskriptif</li>
                            <li class="mb-2"><i class="bi bi-check text-success me-2"></i>Tentukan durasi yang sesuai dengan jumlah soal</li>
                            <li class="mb-2"><i class="bi bi-check text-success me-2"></i>Set deadline agar peserta tahu batas waktu</li>
                            <li class="mb-2"><i class="bi bi-check text-success me-2"></i>Setelah membuat quiz, tambahkan soal-soal</li>
                            <li class="mb-2"><i class="bi bi-check text-success me-2"></i>Publish quiz setelah semua soal selesai</li>
                        </ul>
                    </div>
                </div>

                <div class="card mt-3">
                    <div class="card-header">
                        <h6 class="mb-0"><i class="bi bi-clock me-2"></i>Info Deadline</h6>
                    </div>
                    <div class="card-body">
                        <p class="small text-muted mb-0">
                            Deadline adalah batas waktu terakhir peserta dapat mengerjakan quiz.
                            Setelah deadline, quiz tidak akan muncul di daftar quiz peserta.
                        </p>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/js/bootstrap.bundle.min.js"></script>
    <script>
        // Handle checkbox behavior for target tags
        document.addEventListener('DOMContentLoaded', function() {
            const tagAllCheckbox = document.getElementById('tagAll');
            const tagCheckboxes = document.querySelectorAll('.target-tag-checkbox');

            // When "Semua Peserta" is checked, uncheck all other tags
            tagAllCheckbox.addEventListener('change', function() {
                if (this.checked) {
                    tagCheckboxes.forEach(function(cb) {
                        cb.checked = false;
                    });
                }
            });

            // When any specific tag is checked, uncheck "Semua Peserta"
            tagCheckboxes.forEach(function(cb) {
                cb.addEventListener('change', function() {
                    if (this.checked) {
                        tagAllCheckbox.checked = false;
                    }
                    // If no specific tag is selected, check "Semua Peserta"
                    const anyChecked = Array.from(tagCheckboxes).some(function(c) {
                        return c.checked;
                    });
                    if (!anyChecked) {
                        tagAllCheckbox.checked = true;
                    }
                });
            });

            // Handle form submission - combine deadline date and time
            const form = document.querySelector('form[action="../QuizServlet"]');
            if (form) {
                form.addEventListener('submit', function(e) {
                    const deadlineDate = document.getElementById('deadlineDate').value;
                    const deadlineHour = document.getElementById('deadlineHour').value;
                    const deadlineMinute = document.getElementById('deadlineMinute').value;

                    // If date is set but time is not, default to 23:59
                    if (deadlineDate && (!deadlineHour || deadlineHour === '') && (!deadlineMinute || deadlineMinute === '')) {
                        document.getElementById('deadlineHour').value = '23';
                        document.getElementById('deadlineMinute').value = '59';
                    }

                    // Create hidden input for deadline datetime
                    if (deadlineDate && deadlineDate !== '' && deadlineHour && deadlineHour !== '' && deadlineMinute && deadlineMinute !== '') {
                        let deadlineInput = document.getElementById('deadlineDateTime');
                        if (!deadlineInput) {
                            deadlineInput = document.createElement('input');
                            deadlineInput.type = 'hidden';
                            deadlineInput.name = 'deadline';
                            deadlineInput.id = 'deadlineDateTime';
                            form.appendChild(deadlineInput);
                        }
                        const paddedMinute = deadlineMinute.padStart(2, '0');
                        deadlineInput.value = deadlineDate + 'T' + deadlineHour + ':' + paddedMinute;
                    }

                    // Handle start time
                    const startTimeDate = document.getElementById('startTimeDate').value;
                    const startTimeHour = document.getElementById('startTimeHour').value;
                    const startTimeMinute = document.getElementById('startTimeMinute').value;

                    if (startTimeDate && startTimeDate !== '' && startTimeHour && startTimeHour !== '' && startTimeMinute && startTimeMinute !== '') {
                        let startTimeInput = document.getElementById('startTimeDateTime');
                        if (!startTimeInput) {
                            startTimeInput = document.createElement('input');
                            startTimeInput.type = 'hidden';
                            startTimeInput.name = 'startTime';
                            startTimeInput.id = 'startTimeDateTime';
                            form.appendChild(startTimeInput);
                        }
                        const paddedStartMinute = startTimeMinute.padStart(2, '0');
                        startTimeInput.value = startTimeDate + 'T' + startTimeHour + ':' + paddedStartMinute;
                    }
                });
            }
        });
    </script>
</body>
</html>
