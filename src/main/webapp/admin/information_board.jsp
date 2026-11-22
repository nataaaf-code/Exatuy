<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%@ page import="com.examora.model.User" %>
<%@ page import="com.examora.model.InformationBoard" %>
<%@ page import="com.examora.util.ValidationUtil" %>
<%@ page import="java.util.List" %>
<%@ page import="java.time.format.DateTimeFormatter" %>
<%
    User currentUser = (User) session.getAttribute("user");
    if (currentUser == null || !currentUser.isAdmin()) {
        response.sendRedirect("../LoginServlet");
        return;
    }

    List<InformationBoard> informationList = (List<InformationBoard>) request.getAttribute("informationList");
    if (informationList == null) informationList = List.of();

    String success = (String) request.getAttribute("success");
    String error = (String) request.getAttribute("error");
%>
<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Information Board - Admin Exatuy</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
    <link href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.10.0/font/bootstrap-icons.css" rel="stylesheet">
    <link href="../assets/css/style.css" rel="stylesheet">
    <link rel="icon" type="image/svg+xml" href="../assets/img/favicon.svg?v=3">
<link href="../assets/css/handdrawn.css" rel="stylesheet">
</head>
<body>
    <!-- Sidebar -->
    <%@ include file="sidebar.jsp" %>

    <!-- Main Content -->
    <div class="main-content">
        <div class="d-flex justify-content-between align-items-center mb-4">
            <div>
                <h1 class="h3 mb-0">Information Board</h1>
                <nav aria-label="breadcrumb">
                    <ol class="breadcrumb mb-0">
                        <li class="breadcrumb-item"><a href="../AdminServlet?action=dashboard">Dashboard</a></li>
                        <li class="breadcrumb-item active">Information Board</li>
                    </ol>
                </nav>
            </div>
            <button class="btn btn-primary" data-bs-toggle="modal" data-bs-target="#CreateInfoModal">
                <i class="bi bi-plus-lg me-2"></i>Buat Informasi Baru
            </button>
        </div>

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

        <div class="row mb-4">
            <div class="col-md-3">
                <div class="card border-primary">
                    <div class="card-body">
                        <div class="d-flex align-items-center">
                            <div class="fs-1 text-primary me-3">
                                <i class="bi bi-megaphone-fill"></i>
                            </div>
                            <div>
                                <h6 class="text-muted mb-0">Total Informasi</h6>
                                <h3 class="mb-0"><%= informationList.size() %></h3>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
            <div class="col-md-3">
                <div class="card border-success">
                    <div class="card-body">
                        <div class="d-flex align-items-center">
                            <div class="fs-1 text-success me-3">
                                <i class="bi bi-check-circle-fill"></i>
                            </div>
                            <div>
                                <h6 class="text-muted mb-0">Aktif</h6>
                                <h3 class="mb-0"><%= informationList.stream().filter(InformationBoard::getIsActive).count() %></h3>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
            <div class="col-md-3">
                <div class="card border-warning">
                    <div class="card-body">
                        <div class="d-flex align-items-center">
                            <div class="fs-1 text-warning me-3">
                                <i class="bi bi-exclamation-triangle-fill"></i>
                            </div>
                            <div>
                                <h6 class="text-muted mb-0">Urgent</h6>
                                <h3 class="mb-0"><%= informationList.stream().filter(i -> "urgent".equals(i.getPriority()) && i.getIsActive()).count() %></h3>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
            <div class="col-md-3">
                <div class="card border-info">
                    <div class="card-body">
                        <div class="d-flex align-items-center">
                            <div class="fs-1 text-info me-3">
                                <i class="bi bi-people-fill"></i>
                            </div>
                            <div>
                                <h6 class="text-muted mb-0">Target</h6>
                                <h3 class="mb-0">All Users</h3>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>

        <div class="card">
            <div class="card-header">
                <div class="row align-items-center">
                    <div class="col">
                        <h5 class="mb-0">Daftar Informasi</h5>
                    </div>
                    <div class="col-auto">
                        <input type="text" class="form-control form-control-sm" id="searchInfo" placeholder="Cari judul..." style="width: 200px;">
                    </div>
                </div>
            </div>
            <div class="card-body">
                <% if (informationList.isEmpty()) { %>
                <div class="text-center py-5">
                    <i class="bi bi-megaphone display-4 text-muted"></i>
                    <p class="text-muted mt-3">Belum ada informasi yang dibuat</p>
                </div>
                <% } else { %>
                <div class="table-responsive">
                    <table class="table table-hover" id="infoTable">
                        <thead>
                            <tr>
                                <th>Judul</th>
                                <th>Konten</th>
                                <th>Tipe</th>
                                <th>Priority</th>
                                <th>Target</th>
                                <th>Expires</th>
                                <th>Status</th>
                                <th>Aksi</th>
                            </tr>
                        </thead>
                        <tbody>
                            <% DateTimeFormatter formatter = DateTimeFormatter.ofPattern("dd MMM yyyy, HH:mm");
                               for (InformationBoard info : informationList) { %>
                            <tr data-title="<%= ValidationUtil.sanitizeHtml(info.getTitle().toLowerCase()) %>">
                                <td>
                                    <strong><%= ValidationUtil.sanitizeHtml(info.getTitle()) %></strong>
                                </td>
                                <td>
                                    <div style="max-width: 300px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap;">
                                        <%= ValidationUtil.sanitizeHtml(info.getContent()) %>
                                    </div>
                                </td>
                                <td><%= info.getTypeBadge() %></td>
                                <td>
                                    <% if ("urgent".equals(info.getPriority())) { %>
                                        <span class="badge bg-danger">Urgent</span>
                                    <% } else if ("high".equals(info.getPriority())) { %>
                                        <span class="badge bg-warning text-dark">High</span>
                                    <% } else if ("normal".equals(info.getPriority())) { %>
                                        <span class="badge bg-primary">Normal</span>
                                    <% } else { %>
                                        <span class="badge bg-secondary">Low</span>
                                    <% } %>
                                </td>
                                <td>
                                    <% if ("all".equals(info.getTargetAudience())) { %>
                                        <span class="badge bg-info">Semua</span>
                                    <% } else if ("participants".equals(info.getTargetAudience())) { %>
                                        <span class="badge bg-primary">Peserta</span>
                                    <% } else { %>
                                        <span class="badge bg-secondary">Admin</span>
                                    <% } %>
                                </td>
                                <td>
                                    <% if (info.getShowUntil() != null) { %>
                                        <%= info.getShowUntil().format(formatter) %>
                                    <% } else { %>
                                        <span class="text-muted">-</span>
                                    <% } %>
                                </td>
                                <td>
                                    <%= info.getIsActive() ?
                                        "<span class=\"badge bg-success\">Active</span>" :
                                        "<span class=\"badge bg-secondary\">Inactive</span>" %>
                                </td>
                                <td>
                                    <div class="btn-group btn-group-sm">
                                        <button class="btn btn-outline-info" onclick="viewInfo(<%= info.getId() %>)">
                                            <i class="bi bi-eye"></i>
                                        </button>
                                        <button class="btn btn-outline-primary" onclick="editInfo(<%= info.getId() %>)">
                                            <i class="bi bi-pencil"></i>
                                        </button>
                                        <button class="btn btn-outline-warning" onclick="toggleStatus(<%= info.getId() %>)">
                                            <% boolean isActive = info.getIsActive(); %>
                                            <i class="bi bi-<%= isActive ? "eye-slash" : "eye" %>"></i>
                                        </button>
                                        <button class="btn btn-outline-danger" onclick="deleteInfo(<%= info.getId() %>, '<%= ValidationUtil.sanitizeHtml(ValidationUtil.sanitizeJs(info.getTitle())) %>')">
                                            <i class="bi bi-trash"></i>
                                        </button>
                                    </div>
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

    <!-- Create Information Modal -->
    <div class="modal fade" id="CreateInfoModal" tabindex="-1">
        <div class="modal-dialog modal-lg">
            <div class="modal-content">
                <div class="modal-header">
                    <h5 class="modal-title">Buat Informasi Baru</h5>
                    <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                </div>
                <form action="../AdminServlet" method="post">
                    <div class="modal-body">
                        <input type="hidden" name="action" value="createInformation">
                        <input type="hidden" name="csrfToken" value="<%= session.getAttribute("csrfToken") != null ? session.getAttribute("csrfToken") : "" %>">
                        <div class="row">
                            <div class="col-md-8 mb-3">
                                <label class="form-label">Judul *</label>
                                <input type="text" class="form-control" name="title" required
                                       placeholder="Contoh: Maintenance Schedule">
                            </div>
                            <div class="col-md-4 mb-3">
                                <label class="form-label">Tipe *</label>
                                <select class="form-select" name="infoType" required>
                                    <option value="announcement">Announcement</option>
                                    <option value="info">Info</option>
                                    <option value="warning">Warning</option>
                                    <option value="success">Success</option>
                                </select>
                            </div>
                        </div>
                        <div class="mb-3">
                            <label class="form-label">Konten *</label>
                            <textarea class="form-control" name="content" rows="4" required
                                      placeholder="Tulis informasi yang ingin disampaikan..."></textarea>
                        </div>
                        <div class="row">
                            <div class="col-md-4 mb-3">
                                <label class="form-label">Priority *</label>
                                <select class="form-select" name="priority" required>
                                    <option value="normal">Normal</option>
                                    <option value="low">Low</option>
                                    <option value="high">High</option>
                                    <option value="urgent">Urgent</option>
                                </select>
                            </div>
                            <div class="col-md-4 mb-3">
                                <label class="form-label">Target Audience *</label>
                                <select class="form-select" name="targetAudience" required>
                                    <option value="all">Semua User</option>
                                    <option value="participants">Peserta Saja</option>
                                    <option value="admins">Admin Saja</option>
                                </select>
                            </div>
                            <div class="col-md-4 mb-3">
                                <label class="form-label">Kategori *</label>
                                <select class="form-select" name="category" required>
                                    <% for (String _cat : com.examora.model.InformationBoard.CATEGORIES) { %>
                                    <option value="<%= _cat %>"><%= _cat %></option>
                                    <% } %>
                                </select>
                            </div>
                            <div class="col-md-4 mb-3">
                                <label class="form-label">Target Jenjang *</label>
                                <select class="form-select" name="targetGrade" required>
                                    <% for (String _gr : com.examora.model.InformationBoard.GRADES) { %>
                                    <option value="<%= _gr %>"><%= "ALL".equals(_gr) ? "Semua Jenjang" : _gr %></option>
                                    <% } %>
                                </select>
                            </div>
                            <div class="col-md-4 mb-3">
                                <label class="form-label">Tampilkan Hingga</label>
                                <input type="datetime-local" class="form-control" name="showUntil">
                            </div>
                        </div>
                    </div>
                    <div class="modal-footer">
                        <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Batal</button>
                        <button type="submit" class="btn btn-primary">
                            <i class="bi bi-plus-lg me-2"></i>Buat Informasi
                        </button>
                    </div>
                </form>
            </div>
        </div>
    </div>

    <!-- View Information Modal -->
    <div class="modal fade" id="viewInfoModal" tabindex="-1">
        <div class="modal-dialog modal-lg">
            <div class="modal-content">
                <div class="modal-header">
                    <h5 class="modal-title" id="viewInfoTitle">Detail Informasi</h5>
                    <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                </div>
                <div class="modal-body" id="viewInfoContent"></div>
                <div class="modal-footer">
                    <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Tutup</button>
                </div>
            </div>
        </div>
    </div>

    <!-- Edit Information Modal -->
    <div class="modal fade" id="editInfoModal" tabindex="-1">
        <div class="modal-dialog modal-lg">
            <div class="modal-content">
                <div class="modal-header">
                    <h5 class="modal-title">Edit Informasi</h5>
                    <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                </div>
                <form action="../AdminServlet" method="post">
                    <div class="modal-body">
                        <input type="hidden" name="action" value="updateInformation">
                        <input type="hidden" name="id" id="editInfoId">
                        <input type="hidden" name="csrfToken" value="<%= session.getAttribute("csrfToken") != null ? session.getAttribute("csrfToken") : "" %>">
                        <div class="row">
                            <div class="col-md-8 mb-3">
                                <label class="form-label">Judul *</label>
                                <input type="text" class="form-control" name="title" id="editTitle" required>
                            </div>
                            <div class="col-md-4 mb-3">
                                <label class="form-label">Tipe *</label>
                                <select class="form-select" name="infoType" id="editInfoType" required>
                                    <option value="announcement">Announcement</option>
                                    <option value="info">Info</option>
                                    <option value="warning">Warning</option>
                                    <option value="success">Success</option>
                                </select>
                            </div>
                        </div>
                        <div class="mb-3">
                            <label class="form-label">Konten *</label>
                            <textarea class="form-control" name="content" id="editContent" rows="4" required></textarea>
                        </div>
                        <div class="row">
                            <div class="col-md-4 mb-3">
                                <label class="form-label">Priority *</label>
                                <select class="form-select" name="priority" id="editPriority" required>
                                    <option value="normal">Normal</option>
                                    <option value="low">Low</option>
                                    <option value="high">High</option>
                                    <option value="urgent">Urgent</option>
                                </select>
                            </div>
                            <div class="col-md-4 mb-3">
                                <label class="form-label">Target Audience *</label>
                                <select class="form-select" name="targetAudience" id="editTargetAudience" required>
                                    <option value="all">Semua User</option>
                                    <option value="participants">Peserta Saja</option>
                                    <option value="admins">Admin Saja</option>
                                </select>
                            </div>
                            <div class="col-md-4 mb-3">
                                <label class="form-label">Kategori *</label>
                                <select class="form-select" name="category" id="editCategory" required>
                                    <% for (String _cat : com.examora.model.InformationBoard.CATEGORIES) { %>
                                    <option value="<%= _cat %>"><%= _cat %></option>
                                    <% } %>
                                </select>
                            </div>
                            <div class="col-md-4 mb-3">
                                <label class="form-label">Target Jenjang *</label>
                                <select class="form-select" name="targetGrade" id="editTargetGrade" required>
                                    <% for (String _gr : com.examora.model.InformationBoard.GRADES) { %>
                                    <option value="<%= _gr %>"><%= "ALL".equals(_gr) ? "Semua Jenjang" : _gr %></option>
                                    <% } %>
                                </select>
                            </div>
                            <div class="col-md-4 mb-3">
                                <label class="form-label">Tampilkan Hingga</label>
                                <input type="datetime-local" class="form-control" name="showUntil" id="editShowUntil">
                            </div>
                        </div>
                        <div class="form-check">
                            <input class="form-check-input" type="checkbox" name="isActive" id="editIsActive" checked>
                            <label class="form-check-label" for="editIsActive">
                                Aktif
                            </label>
                        </div>
                    </div>
                    <div class="modal-footer">
                        <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Batal</button>
                        <button type="submit" class="btn btn-primary">
                            <i class="bi bi-check-lg me-2"></i>Simpan
                        </button>
                    </div>
                </form>
            </div>
        </div>
    </div>

    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/js/bootstrap.bundle.min.js"></script>
    <script>
        document.getElementById('searchInfo').addEventListener('input', function() {
            const search = this.value.toLowerCase();
            document.querySelectorAll('#infoTable tbody tr').forEach(row => {
                const title = row.dataset.title;
                row.style.display = title.includes(search) ? '' : 'none';
            });
        });

        function viewInfo(id) {
            fetch('../AdminServlet?action=getInformationDetail&id=' + id)
                .then(response => {
                    if (!response.ok) {
                        throw new Error('Gagal mengambil data');
                    }
                    return response.json();
                })
                .then(data => {
                    if (!data || data.error) {
                        alert('Gagal memuat data: ' + (data.error || 'Unknown error'));
                        return;
                    }
                    document.getElementById('viewInfoTitle').textContent = data.title || '';
                    const content = escapeHtml(data.content || '').replace(/\n/g, '<br>');
                    document.getElementById('viewInfoContent').innerHTML =
                        '<table class="table table-sm">' +
                        '<tr><th width="30%">Tipe</th><td>' + escapeHtml(data.typeBadge || '') + '</td></tr>' +
                        '<tr><th>Priority</th><td><span class="badge ' + escapeHtml(data.priorityBadgeBg || 'bg-secondary') + '">' + escapeHtml(data.priority || '') + '</span></td></tr>' +
                        '<tr><th>Target Audience</th><td>' + escapeHtml(data.targetAudience || '') + '</td></tr>' +
                        '<tr><th>Konten</th><td>' + content + '</td></tr>' +
                        '<tr><th>Dibuat oleh</th><td>' + escapeHtml(data.creatorName || 'Admin') + '</td></tr>' +
                        '<tr><th>Tanggal</th><td>' + escapeHtml(data.createdAt || '-') + '</td></tr>' +
                        '<tr><th>Status</th><td>' + (data.isActive ? 'Active' : 'Inactive') + '</td></tr>' +
                        '</table>';
                    var modal = new bootstrap.Modal(document.getElementById('viewInfoModal'));
                    if (modal) {
                        modal.show();
                    } else {
                        alert('Modal tidak ditemukan');
                    }
                })
                .catch(error => {
                    console.error('Error:', error);
                    alert('Gagal memuat detail informasi: ' + error.message);
                });
        }

        function editInfo(id) {
            fetch('../AdminServlet?action=getInformationDetail&id=' + id)
                .then(response => {
                    if (!response.ok) {
                        throw new Error('Gagal mengambil data');
                    }
                    return response.json();
                })
                .then(data => {
                    if (!data || data.error) {
                        alert('Gagal memuat data: ' + (data.error || 'Unknown error'));
                        return;
                    }
                    document.getElementById('editInfoId').value = data.id;
                    document.getElementById('editTitle').value = data.title || '';
                    document.getElementById('editContent').value = data.content || '';
                    document.getElementById('editInfoType').value = data.infoType || 'info';
                    document.getElementById('editPriority').value = data.priority || 'normal';
                    document.getElementById('editTargetAudience').value = data.targetAudience || 'all';
                    var catEl = document.getElementById('editCategory');
                    if (catEl) { catEl.value = data.category || 'Umum'; }
                    var gradeEl = document.getElementById('editTargetGrade');
                    if (gradeEl) { gradeEl.value = data.targetGrade || 'ALL'; }
                    document.getElementById('editShowUntil').value = data.showUntil || '';
                    document.getElementById('editIsActive').checked = data.isActive || false;
                    var modal = new bootstrap.Modal(document.getElementById('editInfoModal'));
                    if (modal) {
                        modal.show();
                    } else {
                        alert('Modal tidak ditemukan');
                    }
                })
                .catch(error => {
                    console.error('Error:', error);
                    alert('Gagal memuat data untuk edit: ' + error.message);
                });
        }

        function toggleStatus(id) {
            if (confirm('Ubah status informasi ini?')) {
                window.location.href = '../AdminServlet?action=toggleInformationStatus&id=' + id;
            }
        }

        function deleteInfo(id, title) {
            if (confirm('Hapus informasi "' + title + '"?')) {
                window.location.href = '../AdminServlet?action=deleteInformation&id=' + id;
            }
        }

        function escapeHtml(text) {
            const div = document.createElement('div');
            div.textContent = text == null ? '' : String(text);
            return div.innerHTML;
        }

        // Ensure Bootstrap is loaded
        document.addEventListener('DOMContentLoaded', function() {
            // Initialize Bootstrap modals if needed
            var modals = document.querySelectorAll('.modal');
            modals.forEach(function(modal) {
                new bootstrap.Modal(modal);
            });
        });
    </script>
    </script>
</body>
</html>
