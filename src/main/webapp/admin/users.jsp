<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%@ page import="com.examora.model.User" %>
<%@ page import="com.examora.util.ValidationUtil" %>
<%@ page import="java.util.List" %>
<%!
    // JSP function to escape HTML
    public String esc(String input) {
        return ValidationUtil.sanitizeHtml(input);
    }
    // JSP function to escape for JavaScript strings
    public String escJs(String input) {
        if (input == null) return "";
        return input
            .replace("\\", "\\\\")
            .replace("\"", "\\\"")
            .replace("'", "\\'")
            .replace("\n", "\\n")
            .replace("\r", "\\r")
            .replace("<", "\\x3c")
            .replace(">", "\\x3e");
    }
%>
<%
    User currentUser = (User) session.getAttribute("user");
    if (currentUser == null || !currentUser.isAdmin()) {
        response.sendRedirect("../LoginServlet");
        return;
    }
    List<User> users = (List<User>) request.getAttribute("users");
    List<String> tags = (List<String>) request.getAttribute("tags");
    String roleFilter = (String) request.getAttribute("roleFilter");
    String tagFilter = (String) request.getAttribute("tagFilter");
    String success = (String) request.getAttribute("success");
    String error = (String) request.getAttribute("error");
    String csrfToken = (String) session.getAttribute("csrfToken");

    // Pagination variables
    int currentPage = request.getAttribute("currentPage") != null ? (Integer) request.getAttribute("currentPage") : 1;
    int totalPages = request.getAttribute("totalPages") != null ? (Integer) request.getAttribute("totalPages") : 1;
    int totalUsers = request.getAttribute("totalUsers") != null ? (Integer) request.getAttribute("totalUsers") : 0;
    int pageSize = request.getAttribute("pageSize") != null ? (Integer) request.getAttribute("pageSize") : 50;

    // Google Drive users data
    List<User> usersWithGdrive = (List<User>) request.getAttribute("usersWithGdrive");
    int totalGdriveUsers = request.getAttribute("totalGdriveUsers") != null ? (Integer) request.getAttribute("totalGdriveUsers") : 0;
%>
<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Kelola User - Exatuy</title>
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
                <h1 class="h3 mb-0">Kelola User</h1>
                <nav aria-label="breadcrumb">
                    <ol class="breadcrumb mb-0">
                        <li class="breadcrumb-item"><a href="../AdminServlet?action=dashboard">Dashboard</a></li>
                        <li class="breadcrumb-item active">User</li>
                    </ol>
                </nav>
            </div>
            <div class="d-flex gap-2 flex-wrap">
                <button type="button" class="btn btn-outline-danger" data-bs-toggle="modal" data-bs-target="#gdriveLinksModal">
                    <i class="bi bi-google me-2"></i>Link Google Drive
                </button>
                <a href="../AdminServlet?action=downloadTemplate" class="btn btn-outline-success">
                    <i class="bi bi-file-earmark-spreadsheet me-2"></i>Template CSV
                </a>
                <button type="button" class="btn btn-outline-info" data-bs-toggle="modal" data-bs-target="#createTagModal">
                    <i class="bi bi-tag me-2"></i>Kelola Tag
                </button>
                <button type="button" class="btn btn-outline-primary" data-bs-toggle="modal" data-bs-target="#importCsvModal">
                    <i class="bi bi-upload me-2"></i>Import CSV
                </button>
                <button type="button" class="btn btn-primary" data-bs-toggle="modal" data-bs-target="#createUserModal">
                    <i class="bi bi-person-plus me-2"></i>Tambah User
                </button>
            </div>
        </div>

        <% if (success != null) { %>
        <div class="alert alert-success alert-dismissible fade show">
            <i class="bi bi-check-circle me-2"></i><%= esc(success) %>
            <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
        </div>
        <% } %>

        <% if (error != null) { %>
        <div class="alert alert-danger alert-dismissible fade show">
            <i class="bi bi-exclamation-triangle me-2"></i><%= esc(error) %>
            <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
        </div>
        <% } %>

        <!-- Filter -->
        <div class="card mb-4">
            <div class="card-body">
                <form method="get" action="../AdminServlet" class="row g-3 align-items-center">
                    <input type="hidden" name="action" value="users">
                    <div class="col-auto">
                        <label class="form-label mb-0"><i class="bi bi-funnel me-2"></i>Filter:</label>
                    </div>
                    <div class="col-auto">
                        <select name="role" class="form-select" onchange="this.form.submit()">
                            <option value="">Semua Role</option>
                            <option value="admin" <%= "admin".equals(roleFilter) ? "selected" : "" %>>Admin</option>
                            <option value="peserta" <%= "peserta".equals(roleFilter) ? "selected" : "" %>>Peserta</option>
                        </select>
                    </div>
                    <div class="col-auto">
                        <select name="tag" class="form-select" onchange="this.form.submit()">
                            <option value="">Semua Tag</option>
                            <% if (tags != null) {
                                for (String tag : tags) { %>
                            <option value="<%= esc(tag) %>" <%= tag.equals(tagFilter) ? "selected" : "" %>><%= esc(tag) %></option>
                            <% }
                            } %>
                        </select>
                    </div>
                    <div class="col-auto">
                        <a href="../AdminServlet?action=users" class="btn btn-outline-secondary">
                            <i class="bi bi-arrow-counterclockwise me-1"></i>Reset
                        </a>
                    </div>
                </form>
            </div>
        </div>

        <!-- User Stats -->
        <div class="row mb-4">
            <div class="col-md-4">
                <div class="card stat-card bg-primary text-white">
                    <div class="card-body">
                        <div class="d-flex justify-content-between align-items-center">
                            <div>
                                <p class="mb-1 opacity-75">Total User</p>
                                <h2 class="stat-value mb-0"><%= totalUsers %></h2>
                            </div>
                            <i class="bi bi-people stat-icon"></i>
                        </div>
                    </div>
                </div>
            </div>
            <div class="col-md-4">
                <div class="card stat-card bg-success text-white">
                    <div class="card-body">
                        <div class="d-flex justify-content-between align-items-center">
                            <div>
                                <p class="mb-1 opacity-75">Admin</p>
                                <h2 class="stat-value mb-0">
                                    <%= users != null ? users.stream().filter(u -> u.isAdmin()).count() : 0 %>
                                </h2>
                            </div>
                            <i class="bi bi-person-badge stat-icon"></i>
                        </div>
                    </div>
                </div>
            </div>
            <div class="col-md-4">
                <div class="card stat-card bg-info text-white">
                    <div class="card-body">
                        <div class="d-flex justify-content-between align-items-center">
                            <div>
                                <p class="mb-1 opacity-75">Peserta</p>
                                <h2 class="stat-value mb-0">
                                    <%= users != null ? users.stream().filter(u -> u.isPeserta()).count() : 0 %>
                                </h2>
                            </div>
                            <i class="bi bi-mortarboard stat-icon"></i>
                        </div>
                    </div>
                </div>
            </div>
        </div>

        <!-- User List -->
        <div class="card">
            <div class="card-header d-flex justify-content-between align-items-center">
                <h6 class="mb-0"><i class="bi bi-people me-2"></i>Daftar User</h6>
                <span class="badge bg-primary">
                    Menampilkan <%= ((currentPage - 1) * pageSize) + 1 %> - <%= Math.min(currentPage * pageSize, totalUsers) %> dari <%= totalUsers %>
                </span>
            </div>
            <div class="card-body">
                <% if (users != null && !users.isEmpty()) { %>
                <div class="table-responsive">
                    <table class="table table-hover">
                        <thead>
                            <tr>
                                <th>#</th>
                                <th>Nama</th>
                                <th>Email</th>
                                <th>Role</th>
                                <th>Tag</th>
                                <th>Terdaftar</th>
                                <th>Aksi</th>
                            </tr>
                        </thead>
                        <tbody>
                            <% int no = 1; for (User user : users) { %>
                            <tr>
                                <td><%= no++ %></td>
                                <td>
                                    <div class="d-flex align-items-center">
                                        <div class="avatar-circle bg-<%= user.isAdmin() ? "primary" : "success" %> text-white me-2">
                                            <%= user.getName() != null && user.getName().length() > 0 ?
                                                esc(user.getName().substring(0, 1).toUpperCase()) : "U" %>
                                        </div>
                                        <strong><%= esc(user.getName()) %></strong>
                                    </div>
                                </td>
                                <td><%= esc(user.getEmail()) %></td>
                                <td>
                                    <% if (user.isAdmin()) { %>
                                    <span class="badge bg-primary"><i class="bi bi-shield-check me-1"></i>Admin</span>
                                    <% } else { %>
                                    <span class="badge bg-success"><i class="bi bi-person me-1"></i>Peserta</span>
                                    <% } %>
                                </td>
                                <td>
                                    <% if (user.getTag() != null && !user.getTag().isEmpty()) { %>
                                    <span class="badge bg-info"><i class="bi bi-tag me-1"></i><%= esc(user.getTag()) %></span>
                                    <% } else { %>
                                    <span class="text-muted">-</span>
                                    <% } %>
                                </td>
                                <td><%= user.getCreatedAt() != null ? user.getCreatedAt().toLocalDate() : "-" %></td>
                                <td>
                                    <div class="btn-group btn-group-sm">
                                        <button type="button" class="btn btn-outline-info" title="Detail"
                                                data-user-id="<%= user.getId() %>"
                                                data-user-name="<%= escJs(user.getName()) %>"
                                                data-user-email="<%= escJs(user.getEmail()) %>"
                                                data-user-role="<%= escJs(user.getRole()) %>"
                                                data-user-tag="<%= escJs(user.getTag()) %>"
                                                data-user-date="<%= user.getCreatedAt() != null ? user.getCreatedAt().toLocalDate() : "-" %>"
                                                data-user-gdrive="<%= escJs(user.getGdriveLink()) %>"
                                                onclick="showUserDetailFromData(this)">
                                            <i class="bi bi-eye"></i>
                                        </button>
                                        <button type="button" class="btn btn-outline-warning" title="Edit"
                                                data-user-id="<%= user.getId() %>"
                                                data-user-name="<%= escJs(user.getName()) %>"
                                                data-user-email="<%= escJs(user.getEmail()) %>"
                                                data-user-role="<%= escJs(user.getRole()) %>"
                                                data-user-tag="<%= escJs(user.getTag()) %>"
                                                data-user-gdrive="<%= escJs(user.getGdriveLink()) %>"
                                                onclick="showEditModalFromData(this)">
                                            <i class="bi bi-pencil"></i>
                                        </button>
                                        <button type="button" class="btn btn-outline-secondary" title="Reset Password"
                                                data-user-id="<%= user.getId() %>"
                                                data-user-name="<%= escJs(user.getName()) %>"
                                                onclick="showResetPasswordModalFromData(this)">
                                            <i class="bi bi-key"></i>
                                        </button>
                                        <% if (user.isPeserta()) { %>
                                        <button type="button" class="btn btn-outline-secondary" title="Atur PIN"
                                                data-user-id="<%= user.getId() %>"
                                                data-user-name="<%= escJs(user.getName()) %>"
                                                onclick="showSetPinModalFromData(this)">
                                            <i class="bi bi-123"></i>
                                        </button>
                                        <% } %>
                                        <% if (!user.isAdmin() || !user.getEmail().equals("admin@examora.com")) { %>
                                        <button type="button" class="btn btn-outline-danger" title="Hapus"
                                                data-user-id="<%= user.getId() %>"
                                                data-user-name="<%= escJs(user.getName()) %>"
                                                onclick="confirmDeleteFromData(this)">
                                            <i class="bi bi-trash"></i>
                                        </button>
                                        <% } %>
                                    </div>
                                </td>
                            </tr>
                            <% } %>
                        </tbody>
                    </table>
                </div>
                <% } else { %>
                <div class="text-center py-5">
                    <i class="bi bi-people display-1 text-muted mb-3 d-block"></i>
                    <h4 class="text-muted">Tidak ada user</h4>
                    <p class="text-muted">Belum ada user terdaftar dalam sistem.</p>
                </div>
                <% } %>
            </div>
            <% if (totalPages > 1) { %>
            <div class="card-footer">
                <nav aria-label="Page navigation">
                    <ul class="pagination justify-content-center mb-0">
                        <!-- First Page -->
                        <li class="page-item <%= currentPage == 1 ? "disabled" : "" %>">
                            <a class="page-link" href="?action=users&page=1<%= roleFilter != null ? "&role=" + esc(roleFilter) : "" %><%= tagFilter != null ? "&tag=" + esc(tagFilter) : "" %>">
                                <i class="bi bi-chevron-double-left"></i>
                            </a>
                        </li>
                        <!-- Previous Page -->
                        <li class="page-item <%= currentPage == 1 ? "disabled" : "" %>">
                            <a class="page-link" href="?action=users&page=<%= currentPage - 1 %><%= roleFilter != null ? "&role=" + esc(roleFilter) : "" %><%= tagFilter != null ? "&tag=" + esc(tagFilter) : "" %>">
                                <i class="bi bi-chevron-left"></i>
                            </a>
                        </li>
                        <%-- Page Numbers --%>
                        <%
                            int startPage = Math.max(1, currentPage - 2);
                            int endPage = Math.min(totalPages, currentPage + 2);
                            if (startPage > 1) {
                        %>
                        <li class="page-item disabled"><span class="page-link">...</span></li>
                        <% } %>
                        <% for (int i = startPage; i <= endPage; i++) { %>
                        <li class="page-item <%= i == currentPage ? "active" : "" %>">
                            <a class="page-link" href="?action=users&page=<%= i %><%= roleFilter != null ? "&role=" + esc(roleFilter) : "" %><%= tagFilter != null ? "&tag=" + esc(tagFilter) : "" %>"><%= i %></a>
                        </li>
                        <% } %>
                        <% if (endPage < totalPages) { %>
                        <li class="page-item disabled"><span class="page-link">...</span></li>
                        <% } %>
                        <!-- Next Page -->
                        <li class="page-item <%= currentPage == totalPages ? "disabled" : "" %>">
                            <a class="page-link" href="?action=users&page=<%= currentPage + 1 %><%= roleFilter != null ? "&role=" + esc(roleFilter) : "" %><%= tagFilter != null ? "&tag=" + esc(tagFilter) : "" %>">
                                <i class="bi bi-chevron-right"></i>
                            </a>
                        </li>
                        <!-- Last Page -->
                        <li class="page-item <%= currentPage == totalPages ? "disabled" : "" %>">
                            <a class="page-link" href="?action=users&page=<%= totalPages %><%= roleFilter != null ? "&role=" + esc(roleFilter) : "" %><%= tagFilter != null ? "&tag=" + esc(tagFilter) : "" %>">
                                <i class="bi bi-chevron-double-right"></i>
                            </a>
                        </li>
                    </ul>
                </nav>
            </div>
            <% } %>
        </div>
    </div>

    <!-- User Detail Modal -->
    <div class="modal fade" id="userDetailModal" tabindex="-1">
        <div class="modal-dialog">
            <div class="modal-content">
                <div class="modal-header">
                    <h5 class="modal-title"><i class="bi bi-person-circle me-2"></i>Detail User</h5>
                    <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                </div>
                <div class="modal-body">
                    <div class="text-center mb-3">
                        <div class="avatar-circle-lg bg-primary text-white mx-auto">
                            <span id="modalAvatar">U</span>
                        </div>
                        <h5 class="mt-2" id="modalName">User Name</h5>
                    </div>
                    <table class="table table-borderless">
                        <tr>
                            <td class="text-muted">Email:</td>
                            <td id="modalEmail">email@example.com</td>
                        </tr>
                        <tr>
                            <td class="text-muted">Role:</td>
                            <td id="modalRole">Peserta</td>
                        </tr>
                        <tr>
                            <td class="text-muted">Tag:</td>
                            <td id="modalTag">-</td>
                        </tr>
                        <tr>
                            <td class="text-muted">Google Drive:</td>
                            <td id="modalGdrive">-</td>
                        </tr>
                        <tr>
                            <td class="text-muted">Terdaftar:</td>
                            <td id="modalDate">2024-01-01</td>
                        </tr>
                    </table>
                </div>
                <div class="modal-footer">
                    <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Tutup</button>
                </div>
            </div>
        </div>
    </div>

    <!-- Delete Confirmation Modal -->
    <div class="modal fade" id="deleteModal" tabindex="-1">
        <div class="modal-dialog modal-dialog-centered">
            <div class="modal-content">
                <div class="modal-header bg-danger text-white">
                    <h5 class="modal-title"><i class="bi bi-exclamation-triangle me-2"></i>Konfirmasi Hapus</h5>
                    <button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal"></button>
                </div>
                <div class="modal-body">
                    <p>Apakah Anda yakin ingin menghapus user <strong id="deleteUserName"></strong>?</p>
                    <p class="text-muted small mb-0">
                        <i class="bi bi-info-circle me-1"></i>
                        Semua riwayat ujian user ini juga akan dihapus.
                    </p>
                </div>
                <div class="modal-footer">
                    <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Batal</button>
                    <form action="../AdminServlet" method="post" style="display: inline;" id="deleteUserForm">
                        <input type="hidden" name="csrfToken" value="<%= csrfToken %>">
                        <input type="hidden" name="action" value="deleteUser">
                        <input type="hidden" name="userId" id="deleteUserId">
                        <button type="submit" class="btn btn-danger">
                            <i class="bi bi-trash me-1"></i>Ya, Hapus
                        </button>
                    </form>
                </div>
            </div>
        </div>
    </div>

    <!-- Create User Modal -->
    <div class="modal fade" id="createUserModal" tabindex="-1">
        <div class="modal-dialog">
            <div class="modal-content">
                <div class="modal-header bg-primary text-white">
                    <h5 class="modal-title"><i class="bi bi-person-plus me-2"></i>Tambah User Baru</h5>
                    <button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal"></button>
                </div>
                <form action="../AdminServlet" method="post">
                    <input type="hidden" name="csrfToken" value="<%= csrfToken %>">
                    <input type="hidden" name="action" value="createUser">
                    <div class="modal-body">
                        <div class="mb-3">
                            <label class="form-label">Nama Lengkap</label>
                            <input type="text" class="form-control" name="name" required maxlength="100">
                        </div>
                        <div class="mb-3">
                            <label class="form-label">Email</label>
                            <input type="email" class="form-control" name="email" required maxlength="100">
                        </div>
                        <div class="mb-3">
                            <label class="form-label">Password</label>
                            <input type="password" class="form-control" name="password" required minlength="6" maxlength="100">
                            <small class="text-muted">Minimal 6 karakter</small>
                        </div>
                        <div class="mb-3">
                            <label class="form-label">Role</label>
                            <select class="form-select" name="role" required>
                                <option value="peserta">Peserta</option>
                                <option value="admin">Admin</option>
                            </select>
                        </div>
                        <div class="mb-3">
                            <label class="form-label">Tag</label>
                            <div class="input-group">
                                <select class="form-select" name="tag" id="createTagSelect">
                                    <option value="">-- Tanpa Tag --</option>
                                    <% if (tags != null) {
                                        for (String tag : tags) { %>
                                    <option value="<%= esc(tag) %>"><%= esc(tag) %></option>
                                    <% }
                                    } %>
                                </select>
                                <button type="button" class="btn btn-outline-secondary" onclick="showNewTagInput()">
                                    <i class="bi bi-plus"></i> Tag Baru
                                </button>
                            </div>
                            <div id="newTagInputWrapper" class="mt-2" style="display: none;">
                                <input type="text" class="form-control" name="newTag" id="newTagInput"
                                       placeholder="Masukkan nama tag baru" maxlength="50">
                                <small class="text-muted">Tag baru akan digunakan untuk user ini</small>
                            </div>
                        </div>
                        <div class="mb-3">
                            <label class="form-label">Link Google Drive</label>
                            <input type="url" class="form-control" name="gdriveLink" placeholder="https://drive.google.com/..." maxlength="500">
                            <small class="text-muted">Opsional: Link ke folder/file Google Drive user</small>
                        </div>
                    </div>
                    <div class="modal-footer">
                        <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Batal</button>
                        <button type="submit" class="btn btn-primary">
                            <i class="bi bi-check-lg me-1"></i>Simpan
                        </button>
                    </div>
                </form>
            </div>
        </div>
    </div>

    <!-- Edit User Modal -->
    <div class="modal fade" id="editUserModal" tabindex="-1">
        <div class="modal-dialog">
            <div class="modal-content">
                <div class="modal-header bg-warning">
                    <h5 class="modal-title"><i class="bi bi-pencil me-2"></i>Edit User</h5>
                    <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                </div>
                <form action="../AdminServlet" method="post">
                    <input type="hidden" name="csrfToken" value="<%= csrfToken %>">
                    <input type="hidden" name="action" value="editUser">
                    <input type="hidden" name="userId" id="editUserId">
                    <div class="modal-body">
                        <div class="mb-3">
                            <label class="form-label">Nama Lengkap</label>
                            <input type="text" class="form-control" name="name" id="editName" required maxlength="100">
                        </div>
                        <div class="mb-3">
                            <label class="form-label">Email</label>
                            <input type="email" class="form-control" name="email" id="editEmail" required maxlength="100">
                        </div>
                        <div class="mb-3">
                            <label class="form-label">Role</label>
                            <select class="form-select" name="role" id="editRole" required>
                                <option value="peserta">Peserta</option>
                                <option value="admin">Admin</option>
                            </select>
                        </div>
                        <div class="mb-3">
                            <label class="form-label">Tag</label>
                            <div class="input-group">
                                <select class="form-select" name="tag" id="editTagSelect">
                                    <option value="">-- Tanpa Tag --</option>
                                    <% if (tags != null) {
                                        for (String tag : tags) { %>
                                    <option value="<%= esc(tag) %>"><%= esc(tag) %></option>
                                    <% }
                                    } %>
                                </select>
                                <button type="button" class="btn btn-outline-secondary" onclick="showEditNewTagInput()">
                                    <i class="bi bi-plus"></i> Tag Baru
                                </button>
                            </div>
                            <button type="button" class="btn btn-outline-danger btn-sm mt-2" onclick="clearEditTag()">
                                <i class="bi bi-x-circle me-1"></i>Hapus Tag Pengguna Ini
                            </button>
                            <span id="editTagClearedNote" class="badge bg-secondary ms-2" style="display:none;">
                                Tag akan dihapus saat disimpan
                            </span>
                            <div id="editNewTagInputWrapper" class="mt-2" style="display: none;">
                                <input type="text" class="form-control" name="newTag" id="editNewTagInput"
                                       placeholder="Masukkan nama tag baru" maxlength="50">
                            </div>
                        </div>
                        <div class="mb-3">
                            <label class="form-label">Link Google Drive</label>
                            <input type="url" class="form-control" name="gdriveLink" id="editGdriveLink" placeholder="https://drive.google.com/..." maxlength="500">
                            <small class="text-muted">Opsional: Link ke folder/file Google Drive user</small>
                        </div>
                    </div>
                    <div class="modal-footer">
                        <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Batal</button>
                        <button type="submit" class="btn btn-warning">
                            <i class="bi bi-check-lg me-1"></i>Update
                        </button>
                    </div>
                </form>
            </div>
        </div>
    </div>

    <!-- Reset Password Modal -->
    <div class="modal fade" id="resetPasswordModal" tabindex="-1">
        <div class="modal-dialog">
            <div class="modal-content">
                <div class="modal-header bg-secondary text-white">
                    <h5 class="modal-title"><i class="bi bi-key me-2"></i>Reset Password</h5>
                    <button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal"></button>
                </div>
                <form action="../AdminServlet" method="post">
                    <input type="hidden" name="csrfToken" value="<%= csrfToken %>">
                    <input type="hidden" name="action" value="resetPassword">
                    <input type="hidden" name="userId" id="resetPasswordUserId">
                    <div class="modal-body">
                        <p>Reset password untuk: <strong id="resetPasswordUserName"></strong></p>
                        <div class="mb-3">
                            <label class="form-label">Password Baru</label>
                            <input type="password" class="form-control" name="newPassword" required minlength="6" maxlength="100">
                            <small class="text-muted">Minimal 6 karakter</small>
                        </div>
                    </div>
                    <div class="modal-footer">
                        <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Batal</button>
                        <button type="submit" class="btn btn-primary">
                            <i class="bi bi-check-lg me-1"></i>Reset Password
                        </button>
                    </div>
                </form>
            </div>
        </div>
    </div>

    <!-- Set PIN Modal -->
    <div class="modal fade" id="setPinModal" tabindex="-1">
        <div class="modal-dialog">
            <div class="modal-content">
                <div class="modal-header bg-secondary text-white">
                    <h5 class="modal-title"><i class="bi bi-123 me-2"></i>Atur PIN Siswa</h5>
                    <button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal"></button>
                </div>
                <form action="../AdminServlet" method="post">
                    <input type="hidden" name="csrfToken" value="<%= csrfToken %>">
                    <input type="hidden" name="action" value="setPin">
                    <input type="hidden" name="userId" id="setPinUserId">
                    <div class="modal-body">
                        <p>PIN login untuk: <strong id="setPinUserName"></strong></p>
                        <div class="mb-3">
                            <label for="newPin" class="form-label">PIN Baru</label>
                            <input type="password" class="form-control" id="newPin" name="pin" required
                                   inputmode="numeric" pattern="\d{6}" minlength="6" maxlength="6" autocomplete="off">
                            <small class="text-muted">6 digit angka. Siswa login dengan email + PIN ini.</small>
                        </div>
                    </div>
                    <div class="modal-footer">
                        <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Batal</button>
                        <button type="submit" class="btn btn-primary">
                            <i class="bi bi-check-lg me-1"></i>Simpan PIN
                        </button>
                    </div>
                </form>
            </div>
        </div>
    </div>

    <!-- Create Tag Modal -->
    <div class="modal fade" id="createTagModal" tabindex="-1">
        <div class="modal-dialog">
            <div class="modal-content">
                <div class="modal-header bg-info text-white">
                    <h5 class="modal-title"><i class="bi bi-tag me-2"></i>Kelola Tag</h5>
                    <button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal"></button>
                </div>
                <div class="modal-body">
                    <!-- Existing Tags -->
                    <div class="mb-4">
                        <h6 class="text-muted mb-3">
                            <i class="bi bi-collection me-1"></i>Tag yang Tersedia
                            <% if (tags != null && !tags.isEmpty()) { %>
                            <span class="badge bg-secondary ms-2"><%= tags.size() %> tag</span>
                            <% } %>
                        </h6>
                        <div id="existingTagsList" class="d-flex flex-wrap gap-2">
                            <% if (tags != null && !tags.isEmpty()) {
                                for (String tag : tags) { %>
                            <span class="badge bg-light text-dark border p-2 d-flex align-items-center gap-1" data-tag="<%= esc(tag) %>">
                                <i class="bi bi-tag-fill text-info me-1"></i>
                                <span class="tag-name"><%= esc(tag) %></span>
                                <button type="button" class="btn-close btn-close-dark ms-2" style="font-size: 0.6rem;"
                                        onclick="deleteTag('<%= esc(tag) %>')" title="Hapus tag"></button>
                            </span>
                            <% }
                            } else { %>
                            <span class="text-muted fst-italic">Belum ada tag</span>
                            <% } %>
                        </div>
                    </div>

                    <!-- Add New Tag Form -->
                    <div class="border-top pt-3">
                        <h6 class="text-muted mb-3"><i class="bi bi-plus-circle me-1"></i>Tambah Tag Baru</h6>
                        <form id="createTagForm" onsubmit="return createTag(event)">
                            <input type="hidden" name="csrfToken" id="createTagCsrf" value="<%= csrfToken %>">
                            <div class="input-group">
                                <span class="input-group-text"><i class="bi bi-tag"></i></span>
                                <input type="text" class="form-control" id="newTagName"
                                       placeholder="Nama tag baru (contoh: Kelas A, Divisi IT)" required maxlength="50">
                                <button type="submit" class="btn btn-info text-white">
                                    <i class="bi bi-plus-lg me-1"></i>Tambah
                                </button>
                            </div>
                        </form>
                    </div>

                    <!-- Info -->
                    <div class="alert alert-warning mt-3 mb-0 small">
                        <i class="bi bi-exclamation-triangle me-1"></i>
                        <strong>Catatan:</strong> Menghapus tag akan menghapus tag tersebut dari semua user yang memilikinya.
                    </div>
                </div>
                <div class="modal-footer">
                    <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Tutup</button>
                </div>
            </div>
        </div>
    </div>

    <!-- Import CSV Modal -->
    <div class="modal fade" id="importCsvModal" tabindex="-1">
        <div class="modal-dialog">
            <div class="modal-content">
                <div class="modal-header bg-primary text-white">
                    <h5 class="modal-title"><i class="bi bi-upload me-2"></i>Import User dari CSV</h5>
                    <button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal"></button>
                </div>
                <form action="../AdminServlet" method="post" enctype="multipart/form-data" id="importCsvForm">
                    <input type="hidden" name="csrfToken" value="<%= csrfToken %>">
                    <input type="hidden" name="action" value="importUsers">
                    <div class="modal-body">
                        <div class="alert alert-info">
                            <i class="bi bi-info-circle me-2"></i>
                            <strong>Format CSV:</strong>
                            <ul class="mb-0 mt-2 small">
                                <li><strong>nama</strong> - Nama lengkap user</li>
                                <li><strong>email</strong> - Email user (harus unik)</li>
                                <li><strong>password</strong> - Password (minimal 6 karakter)</li>
                                <li><strong>role</strong> - Role: "peserta" atau "admin" (default: peserta)</li>
                                <li><strong>tag</strong> - Tag user (opsional)</li>
                                <li><strong>gdriveLink</strong> - Link Google Drive user (opsional)</li>
                            </ul>
                        </div>

                        <div class="mb-3">
                            <label class="form-label">Pilih File CSV</label>
                            <input type="file" class="form-control" name="csvFile" accept=".csv" required>
                            <small class="text-muted">Format file: .csv (Max 5MB)</small>
                        </div>

                        <div class="form-check mb-3">
                            <input class="form-check-input" type="checkbox" name="skipHeader" id="skipHeader" checked>
                            <label class="form-check-label" for="skipHeader">
                                Lewati baris pertama (header)
                            </label>
                        </div>

                        <div class="form-check">
                            <input class="form-check-input" type="checkbox" name="updateExisting" id="updateExisting">
                            <label class="form-check-label" for="updateExisting">
                                Update user jika email sudah ada
                            </label>
                        </div>

                        <div id="importPreview" class="mt-3" style="display: none;">
                            <h6>Preview Data:</h6>
                            <div class="table-responsive" style="max-height: 200px;">
                                <table class="table table-sm table-bordered" id="previewTable">
                                    <thead class="table-light">
                                        <tr><th>Nama</th><th>Email</th><th>Role</th><th>Tag</th><th>GDrive</th></tr>
                                    </thead>
                                    <tbody></tbody>
                                </table>
                            </div>
                        </div>
                    </div>
                    <div class="modal-footer">
                        <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Batal</button>
                        <button type="submit" class="btn btn-primary">
                            <i class="bi bi-upload me-1"></i>Import
                        </button>
                    </div>
                </form>
            </div>
        </div>
    </div>

    <!-- Import Result Modal -->
    <div class="modal fade" id="importResultModal" tabindex="-1">
        <div class="modal-dialog modal-lg">
            <div class="modal-content">
                <div class="modal-header">
                    <h5 class="modal-title"><i class="bi bi-check-circle me-2"></i>Hasil Import</h5>
                    <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                </div>
                <div class="modal-body" id="importResultBody">
                    <!-- Will be filled dynamically -->
                </div>
                <div class="modal-footer">
                    <button type="button" class="btn btn-primary" data-bs-dismiss="modal">Tutup</button>
                </div>
            </div>
        </div>
    </div>

    <style>
        .avatar-circle {
            width: 40px;
            height: 40px;
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
            font-weight: bold;
            font-size: 1rem;
        }
        .avatar-circle-lg {
            width: 80px;
            height: 80px;
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
            font-weight: bold;
            font-size: 2rem;
        }
    </style>

    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/js/bootstrap.bundle.min.js"></script>
    <script>
        // CSRF Token for AJAX requests
        const csrfToken = "<%= csrfToken != null ? csrfToken : "" %>";

        // Helper function to escape HTML in JavaScript
        function escapeHtml(text) {
            if (!text) return "";
            const div = document.createElement('div');
            div.textContent = text;
            return div.innerHTML;
        }

        // New functions using data attributes (more secure)
        function showUserDetailFromData(btn) {
            const name = btn.dataset.userName || '';
            const email = btn.dataset.userEmail || '';
            const role = btn.dataset.userRole || '';
            const tag = btn.dataset.userTag || '';
            const date = btn.dataset.userDate || '-';
            const gdriveLink = btn.dataset.userGdrive || '';

            document.getElementById('modalAvatar').textContent = name.charAt(0).toUpperCase();
            document.getElementById('modalName').textContent = name;
            document.getElementById('modalEmail').textContent = email;
            document.getElementById('modalRole').innerHTML = role === 'admin'
                ? '<span class="badge bg-primary"><i class="bi bi-shield-check me-1"></i>Admin</span>'
                : '<span class="badge bg-success"><i class="bi bi-person me-1"></i>Peserta</span>';
            document.getElementById('modalTag').innerHTML = tag && tag.trim() !== ''
                ? '<span class="badge bg-info"><i class="bi bi-tag me-1"></i>' + escapeHtml(tag) + '</span>'
                : '<span class="text-muted">-</span>';
            document.getElementById('modalGdrive').innerHTML = gdriveLink && gdriveLink.trim() !== ''
                ? '<a href="' + escapeHtml(gdriveLink) + '" target="_blank" rel="noopener noreferrer" class="btn btn-sm btn-outline-danger"><i class="bi bi-google me-1"></i>Buka Link</a>'
                : '<span class="text-muted">-</span>';
            document.getElementById('modalDate').textContent = date;

            new bootstrap.Modal(document.getElementById('userDetailModal')).show();
        }

        function confirmDeleteFromData(btn) {
            const userId = btn.dataset.userId;
            const userName = btn.dataset.userName || '';
            document.getElementById('deleteUserId').value = userId;
            document.getElementById('deleteUserName').textContent = userName;
            new bootstrap.Modal(document.getElementById('deleteModal')).show();
        }

        function showEditModalFromData(btn) {
            const userId = btn.dataset.userId;
            const name = btn.dataset.userName || '';
            const email = btn.dataset.userEmail || '';
            const role = btn.dataset.userRole || '';
            const tag = btn.dataset.userTag || '';
            const gdriveLink = btn.dataset.userGdrive || '';

            document.getElementById('editUserId').value = userId;
            document.getElementById('editName').value = name;
            document.getElementById('editEmail').value = email;
            document.getElementById('editRole').value = role;
            document.getElementById('editGdriveLink').value = gdriveLink || '';

            // Set tag select value
            var tagSelect = document.getElementById('editTagSelect');
            var tagFound = false;
            for (var i = 0; i < tagSelect.options.length; i++) {
                if (tagSelect.options[i].value === tag) {
                    tagSelect.selectedIndex = i;
                    tagFound = true;
                    break;
                }
            }
            if (!tagFound) {
                tagSelect.selectedIndex = 0; // Select "-- Tanpa Tag --"
            }

            // Hide new tag input wrapper
            document.getElementById('editNewTagInputWrapper').style.display = 'none';
            document.getElementById('editNewTagInput').value = '';

            new bootstrap.Modal(document.getElementById('editUserModal')).show();
        }

        function showResetPasswordModalFromData(btn) {
            const userId = btn.dataset.userId;
            const userName = btn.dataset.userName || '';
            document.getElementById('resetPasswordUserId').value = userId;
            document.getElementById('resetPasswordUserName').textContent = userName;
            new bootstrap.Modal(document.getElementById('resetPasswordModal')).show();
        }

        function showSetPinModalFromData(btn) {
            document.getElementById('setPinUserId').value = btn.dataset.userId;
            document.getElementById('setPinUserName').textContent = btn.dataset.userName || '';
            document.getElementById('newPin').value = '';
            new bootstrap.Modal(document.getElementById('setPinModal')).show();
        }

        // Legacy functions for backward compatibility
        function showUserDetail(id, name, email, role, tag, date, gdriveLink) {
            document.getElementById('modalAvatar').textContent = name.charAt(0).toUpperCase();
            document.getElementById('modalName').textContent = name;
            document.getElementById('modalEmail').textContent = email;
            document.getElementById('modalRole').innerHTML = role === 'admin'
                ? '<span class="badge bg-primary"><i class="bi bi-shield-check me-1"></i>Admin</span>'
                : '<span class="badge bg-success"><i class="bi bi-person me-1"></i>Peserta</span>';
            document.getElementById('modalTag').innerHTML = tag && tag.trim() !== ''
                ? '<span class="badge bg-info"><i class="bi bi-tag me-1"></i>' + escapeHtml(tag) + '</span>'
                : '<span class="text-muted">-</span>';
            document.getElementById('modalGdrive').innerHTML = gdriveLink && gdriveLink.trim() !== ''
                ? '<a href="' + escapeHtml(gdriveLink) + '" target="_blank" rel="noopener noreferrer" class="btn btn-sm btn-outline-danger"><i class="bi bi-google me-1"></i>Buka Link</a>'
                : '<span class="text-muted">-</span>';
            document.getElementById('modalDate').textContent = date;

            new bootstrap.Modal(document.getElementById('userDetailModal')).show();
        }

        function confirmDelete(userId, userName) {
            document.getElementById('deleteUserId').value = userId;
            document.getElementById('deleteUserName').textContent = userName;
            new bootstrap.Modal(document.getElementById('deleteModal')).show();
        }

        function showEditModal(userId, name, email, role, tag, gdriveLink) {
            document.getElementById('editUserId').value = userId;
            document.getElementById('editName').value = name;
            document.getElementById('editEmail').value = email;
            document.getElementById('editRole').value = role;
            document.getElementById('editGdriveLink').value = gdriveLink || '';

            // Set tag select value
            var tagSelect = document.getElementById('editTagSelect');
            var tagFound = false;
            for (var i = 0; i < tagSelect.options.length; i++) {
                if (tagSelect.options[i].value === tag) {
                    tagSelect.selectedIndex = i;
                    tagFound = true;
                    break;
                }
            }
            if (!tagFound) {
                tagSelect.selectedIndex = 0; // Select "-- Tanpa Tag --"
            }

            // Hide new tag input wrapper
            document.getElementById('editNewTagInputWrapper').style.display = 'none';
            document.getElementById('editNewTagInput').value = '';

            new bootstrap.Modal(document.getElementById('editUserModal')).show();
        }

        function showResetPasswordModal(userId, userName) {
            document.getElementById('resetPasswordUserId').value = userId;
            document.getElementById('resetPasswordUserName').textContent = userName;
            new bootstrap.Modal(document.getElementById('resetPasswordModal')).show();
        }

        function showNewTagInput() {
            var wrapper = document.getElementById('newTagInputWrapper');
            var input = document.getElementById('newTagInput');
            wrapper.style.display = 'block';
            input.focus();
            // Deselect the dropdown
            document.getElementById('createTagSelect').selectedIndex = 0;
        }

        function showEditNewTagInput() {
            var wrapper = document.getElementById('editNewTagInputWrapper');
            var input = document.getElementById('editNewTagInput');
            wrapper.style.display = 'block';
            input.focus();
            // Deselect the dropdown
            document.getElementById('editTagSelect').selectedIndex = 0;
        }

        function createTag(event) {
            event.preventDefault();
            var tagName = document.getElementById('newTagName').value.trim();

            if (!tagName) {
                alert('Nama tag tidak boleh kosong');
                return false;
            }

            // Validate tag name length
            if (tagName.length > 50) {
                alert('Nama tag maksimal 50 karakter');
                return false;
            }

            fetch('../AdminServlet?action=createTag&tagName=' + encodeURIComponent(tagName), {
                method: 'POST',
                headers: {
                    'X-CSRF-Token': csrfToken
                }
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    // Add new tag to the list with delete button
                    var tagsList = document.getElementById('existingTagsList');
                    var newBadge = document.createElement('span');
                    newBadge.className = 'badge bg-light text-dark border p-2 d-flex align-items-center gap-1';
                    newBadge.setAttribute('data-tag', tagName);
                    newBadge.innerHTML = '<i class="bi bi-tag-fill text-info me-1"></i>' +
                        '<span class="tag-name">' + escapeHtml(tagName) + '</span>' +
                        '<button type="button" class="btn-close btn-close-dark ms-2" style="font-size: 0.6rem;" onclick="deleteTag(\'' + escapeHtml(tagName) + '\')" title="Hapus tag"></button>';
                    tagsList.appendChild(newBadge);

                    // Add to both select dropdowns
                    addTagToSelect('createTagSelect', tagName);
                    addTagToSelect('editTagSelect', tagName);

                    // Clear input
                    document.getElementById('newTagName').value = '';

                    alert('Tag "' + tagName + '" berhasil dibuat!');
                } else {
                    alert('Gagal membuat tag: ' + (data.error || 'Unknown error'));
                }
            })
            .catch(error => {
                alert('Error: ' + error.message);
            });

            return false;
        }

        // Kosongkan tag pengguna yang sedang diedit (disimpan sebagai NULL di DB).
        function clearEditTag() {
            var select = document.getElementById('editTagSelect');
            if (select) { select.value = ''; }
            var input = document.getElementById('editNewTagInput');
            if (input) { input.value = ''; }
            var note = document.getElementById('editTagClearedNote');
            if (note) { note.style.display = 'inline-block'; }
        }

        function deleteTag(tagName) {
            if (!confirm('Apakah Anda yakin ingin menghapus tag "' + tagName + '"?\n\nTag akan dihapus dari semua user yang memilikinya.')) {
                return;
            }

            fetch('../AdminServlet?action=deleteTag&tagName=' + encodeURIComponent(tagName), {
                method: 'POST',
                headers: {
                    'X-CSRF-Token': csrfToken
                }
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    // Muat ulang halaman agar seluruh daftar/dropdown tag ikut bersih
                    // (tag juga dipakai di tabel user, filter, dan daftar target fitur).
                    alert('Tag "' + tagName + '" dihapus dari ' + (data.updatedUsers || 0)
                          + ' data. Halaman akan dimuat ulang.');
                    window.location.reload();
                    return;
                }
                if (false) {
                    // Remove tag from the list
                    var tagsList = document.getElementById('existingTagsList');
                    var tagBadge = tagsList.querySelector('[data-tag="' + tagName.replace(/"/g, '\\"') + '"]');
                    if (tagBadge) {
                        tagBadge.remove();
                    }

                    // Remove from both select dropdowns
                    removeTagFromSelect('createTagSelect', tagName);
                    removeTagFromSelect('editTagSelect', tagName);

                    // Check if no tags left
                    if (tagsList.children.length === 0) {
                        tagsList.innerHTML = '<span class="text-muted fst-italic">Belum ada tag</span>';
                    }

                    alert('Tag "' + tagName + '" berhasil dihapus!');
                } else {
                    alert('Gagal menghapus tag: ' + (data.error || 'Unknown error'));
                }
            })
            .catch(error => {
                alert('Error: ' + error.message);
            });
        }

        function removeTagFromSelect(selectId, tagName) {
            var select = document.getElementById(selectId);
            if (select) {
                for (var i = 0; i < select.options.length; i++) {
                    if (select.options[i].value === tagName) {
                        select.remove(i);
                        break;
                    }
                }
            }
        }

        function addTagToSelect(selectId, tagName) {
            var select = document.getElementById(selectId);
            var option = document.createElement('option');
            option.value = tagName;
            option.textContent = tagName;
            select.appendChild(option);
        }

        // Handle form submission to use new tag if provided
        document.addEventListener('DOMContentLoaded', function() {
            var createUserForm = document.querySelector('#createUserModal form');
            if (createUserForm) {
                createUserForm.addEventListener('submit', function(e) {
                    var newTagInput = document.getElementById('newTagInput');
                    var tagSelect = document.getElementById('createTagSelect');

                    if (newTagInput && newTagInput.value.trim()) {
                        // Use new tag value instead of select
                        var hiddenInput = document.createElement('input');
                        hiddenInput.type = 'hidden';
                        hiddenInput.name = 'tag';
                        hiddenInput.value = newTagInput.value.trim();
                        this.appendChild(hiddenInput);

                        // Remove select name to avoid conflict
                        tagSelect.removeAttribute('name');
                    }
                });
            }

            var editUserForm = document.querySelector('#editUserModal form');
            if (editUserForm) {
                editUserForm.addEventListener('submit', function(e) {
                    var newTagInput = document.getElementById('editNewTagInput');
                    var tagSelect = document.getElementById('editTagSelect');

                    if (newTagInput && newTagInput.value.trim()) {
                        // Use new tag value instead of select
                        var hiddenInput = document.createElement('input');
                        hiddenInput.type = 'hidden';
                        hiddenInput.name = 'tag';
                        hiddenInput.value = newTagInput.value.trim();
                        this.appendChild(hiddenInput);

                        // Remove select name to avoid conflict
                        tagSelect.removeAttribute('name');
                    }
                });
            }
        });
    </script>

    <!-- Google Drive Links Modal -->
    <div class="modal fade" id="gdriveLinksModal" tabindex="-1">
        <div class="modal-dialog modal-lg">
            <div class="modal-content">
                <div class="modal-header bg-danger text-white">
                    <h5 class="modal-title">
                        <i class="bi bi-google me-2"></i>Link Google Drive Peserta
                        <span class="badge bg-light text-danger ms-2"><%= totalGdriveUsers %> peserta</span>
                    </h5>
                    <button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal"></button>
                </div>
                <div class="modal-body">
                    <div class="table-responsive">
                        <table class="table table-hover">
                            <thead class="table-light">
                                <tr>
                                    <th>#</th>
                                    <th>Nama</th>
                                    <th>Tag</th>
                                    <th>Link Google Drive</th>
                                    <th>Aksi</th>
                                </tr>
                            </thead>
                            <tbody>
                                <% if (usersWithGdrive != null && !usersWithGdrive.isEmpty()) {
                                    int gdriveNo = 1;
                                    for (User user : usersWithGdrive) {
                                %>
                                <tr>
                                    <td><%= gdriveNo++ %></td>
                                    <td><%= esc(user.getName()) %></td>
                                    <td>
                                        <% if (user.getTag() != null && !user.getTag().isEmpty()) { %>
                                        <span class="badge bg-info"><%= esc(user.getTag()) %></span>
                                        <% } else { %>
                                        <span class="text-muted">-</span>
                                        <% } %>
                                    </td>
                                    <td>
                                        <a href="<%= esc(user.getGdriveLink()) %>" target="_blank" rel="noopener noreferrer" class="text-truncate d-inline-block" style="max-width: 250px;">
                                            <%= esc(user.getGdriveLink().length() > 40 ? user.getGdriveLink().substring(0, 40) + "..." : user.getGdriveLink()) %>
                                        </a>
                                    </td>
                                    <td>
                                        <a href="<%= esc(user.getGdriveLink()) %>" target="_blank" rel="noopener noreferrer" class="btn btn-sm btn-outline-danger">
                                            <i class="bi bi-box-arrow-up-right"></i> Buka
                                        </a>
                                    </td>
                                </tr>
                                <%      }
                                } else { %>
                                <tr>
                                    <td colspan="5" class="text-center text-muted py-4">
                                        <i class="bi bi-google display-4 d-block mb-2"></i>
                                        Belum ada user yang memiliki link Google Drive
                                    </td>
                                </tr>
                                <% } %>
                            </tbody>
                        </table>
                    </div>
                </div>
                <div class="modal-footer">
                    <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Tutup</button>
                </div>
            </div>
        </div>
    </div>
</body>
</html>
