<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%@ page import="java.util.List" %>
<%@ page import="com.examora.dao.MeetLinkDAO" %>
<%@ page import="com.examora.util.ValidationUtil" %>
<%@ page import="com.examora.model.InformationBoard" %>
<%
    com.examora.model.User pageUser = (com.examora.model.User) session.getAttribute("user");
    if (pageUser == null || !pageUser.isAdmin()) { response.sendRedirect("../LoginServlet"); return; }

    List<MeetLinkDAO.MeetLink> meetLinks = (List<MeetLinkDAO.MeetLink>) request.getAttribute("meetLinks");
    if (meetLinks == null) meetLinks = List.of();
    MeetLinkDAO.MeetLink editLink = (MeetLinkDAO.MeetLink) request.getAttribute("editLink");
    boolean editing = editLink != null;

    String ctx = request.getContextPath();
    String flashSuccess = (String) session.getAttribute("flashSuccess");
    if (flashSuccess != null) { session.removeAttribute("flashSuccess"); }
    String flashError = (String) session.getAttribute("flashError");
    if (flashError != null) { session.removeAttribute("flashError"); }
    String error = (String) request.getAttribute("error");
%>
<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Link Google Meet - Exatuy</title>
    <link href="../assets/vendor/bootstrap.min.css" rel="stylesheet">
    <link href="../assets/vendor/bootstrap-icons.css" rel="stylesheet">
</head>
<body class="bg-light">
<%@ include file="sidebar.jsp" %>
<div class="main-content p-3 p-md-4">

    <div class="d-flex justify-content-between align-items-center mb-3 gap-2 flex-wrap">
        <div>
            <h1 class="h5 mb-0"><i class="bi bi-camera-video me-2"></i>Link Google Meet</h1>
            <small class="text-muted">Tautan yang muncul di menu siswa &middot; 1 poin sekali per hari saat dibuka</small>
        </div>
        <div class="d-flex align-items-center gap-2">
            <span class="badge bg-secondary"><%= meetLinks.size() %> tautan</span>
            <button class="btn btn-sm btn-primary" data-bs-toggle="modal" data-bs-target="#linkModal">
                <i class="bi bi-plus-lg me-1"></i>Tambah Tautan
            </button>
        </div>
    </div>

    <% if (flashSuccess != null) { %>
    <div class="alert alert-success py-2 small"><i class="bi bi-check-circle me-2"></i><%= ValidationUtil.sanitizeHtml(flashSuccess) %></div>
    <% } %>
    <% if (flashError != null) { %>
    <div class="alert alert-danger py-2 small"><i class="bi bi-exclamation-triangle me-2"></i><%= ValidationUtil.sanitizeHtml(flashError) %></div>
    <% } %>
    <% if (error != null) { %>
    <div class="alert alert-warning py-2 small"><%= ValidationUtil.sanitizeHtml(error) %></div>
    <% } %>

    <div class="card border-0 shadow-sm">
        <div class="table-responsive">
            <table class="table table-sm table-hover align-middle mb-0">
                <thead class="table-light">
                <tr>
                    <th>Judul / Tautan</th>
                    <th class="d-none d-md-table-cell">Target</th>
                    <th class="d-none d-lg-table-cell">Jadwal</th>
                    <th>Status</th>
                    <th class="text-end">Aksi</th>
                </tr>
                </thead>
                <tbody>
                <% if (meetLinks.isEmpty()) { %>
                <tr>
                    <td colspan="5" class="text-center text-muted py-4 small">
                        Belum ada tautan. Klik <strong>Tambah Tautan</strong> untuk membuat sesi pertama.
                    </td>
                </tr>
                <% } %>
                <% for (MeetLinkDAO.MeetLink link : meetLinks) {
                       String target = (link.targetTag == null || link.targetTag.isBlank())
                               ? "Semua kelas" : link.targetTag;
                       String grade = "ALL".equalsIgnoreCase(link.targetGrade) ? "Semua jenjang" : link.targetGrade;
                %>
                <tr>
                    <td style="max-width:320px;">
                        <div class="fw-semibold text-truncate"><%= ValidationUtil.sanitizeHtml(link.title) %></div>
                        <a href="<%= ValidationUtil.sanitizeHtml(link.url) %>" target="_blank" rel="noopener noreferrer"
                           class="small text-truncate d-block text-muted" title="<%= ValidationUtil.sanitizeHtml(link.url) %>">
                            <i class="bi bi-box-arrow-up-right me-1"></i><%= ValidationUtil.sanitizeHtml(link.url) %>
                        </a>
                    </td>
                    <td class="small d-none d-md-table-cell">
                        <%= ValidationUtil.sanitizeHtml(target) %><br>
                        <span class="text-muted"><%= ValidationUtil.sanitizeHtml(grade) %></span>
                    </td>
                    <td class="small d-none d-lg-table-cell">
                        <%= link.scheduleInfo == null || link.scheduleInfo.isBlank() ? "-" : ValidationUtil.sanitizeHtml(link.scheduleInfo) %>
                    </td>
                    <td>
                        <span class="badge <%= Boolean.TRUE.equals(link.isActive) ? "bg-success" : "bg-secondary" %>">
                            <%= Boolean.TRUE.equals(link.isActive) ? "Aktif" : "Nonaktif" %>
                        </span>
                    </td>
                    <td class="text-end text-nowrap">
                        <a href="<%= ctx %>/MeetLinkServlet?edit=<%= link.id %>" class="btn btn-sm btn-outline-primary py-0 px-2" title="Edit">
                            <i class="bi bi-pencil"></i>
                        </a>
                        <form method="post" action="<%= ctx %>/MeetLinkServlet" class="d-inline">
                            <input type="hidden" name="csrfToken" value="<%= session.getAttribute("csrfToken") %>">
                            <input type="hidden" name="action" value="toggle">
                            <input type="hidden" name="id" value="<%= link.id %>">
                            <button class="btn btn-sm btn-outline-secondary py-0 px-2" title="Aktif / nonaktifkan"><i class="bi bi-power"></i></button>
                        </form>
                        <form method="post" action="<%= ctx %>/MeetLinkServlet" class="d-inline"
                              onsubmit="return confirm('Hapus tautan ini?');">
                            <input type="hidden" name="csrfToken" value="<%= session.getAttribute("csrfToken") %>">
                            <input type="hidden" name="action" value="delete">
                            <input type="hidden" name="id" value="<%= link.id %>">
                            <button class="btn btn-sm btn-outline-danger py-0 px-2" title="Hapus"><i class="bi bi-trash"></i></button>
                        </form>
                    </td>
                </tr>
                <% } %>
                </tbody>
            </table>
        </div>
    </div>
</div>

<%-- Form tambah/edit ditaruh di modal supaya halaman ringkas --%>
<div class="modal fade" id="linkModal" tabindex="-1" aria-hidden="true">
    <div class="modal-dialog modal-dialog-centered modal-dialog-scrollable">
        <div class="modal-content border-0 shadow">
            <div class="modal-header py-2">
                <h6 class="modal-title mb-0">
                    <i class="bi bi-camera-video me-1"></i><%= editing ? "Edit Tautan" : "Tambah Tautan" %>
                </h6>
                <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Tutup"></button>
            </div>
            <form method="post" action="<%= ctx %>/MeetLinkServlet" class="m-0">
                <input type="hidden" name="csrfToken" value="<%= session.getAttribute("csrfToken") %>">
                <input type="hidden" name="action" value="<%= editing ? "update" : "create" %>">
                <% if (editing) { %><input type="hidden" name="id" value="<%= editLink.id %>"><% } %>
                <div class="modal-body py-2">
                    <div class="mb-2">
                        <label class="form-label small fw-semibold mb-1">Judul Sesi *</label>
                        <input type="text" name="title" class="form-control form-control-sm" required maxlength="150"
                               value="<%= editing ? ValidationUtil.sanitizeHtml(editLink.title) : "" %>"
                               placeholder="GMeet Matematika SD-4">
                    </div>
                    <div class="mb-2">
                        <label class="form-label small fw-semibold mb-1">Tautan *</label>
                        <input type="url" name="url" class="form-control form-control-sm" required
                               value="<%= editing ? ValidationUtil.sanitizeHtml(editLink.url) : "" %>"
                               placeholder="https://meet.google.com/xxx-xxxx-xxx">
                        <div class="form-text">Hanya meet.google.com / drive.google.com / docs.google.com.</div>
                    </div>
                    <div class="row g-2">
                        <div class="col-6">
                            <label class="form-label small fw-semibold mb-1">Kelas (tag)</label>
                            <input type="text" name="targetTag" class="form-control form-control-sm" maxlength="50"
                                   value="<%= editing && editLink.targetTag != null ? ValidationUtil.sanitizeHtml(editLink.targetTag) : "" %>"
                                   placeholder="SD-4">
                        </div>
                        <div class="col-6">
                            <label class="form-label small fw-semibold mb-1">Jenjang</label>
                            <select name="targetGrade" class="form-select form-select-sm">
                                <% for (String g : InformationBoard.GRADES) {
                                       boolean selected = editing ? g.equalsIgnoreCase(editLink.targetGrade) : "ALL".equals(g);
                                %>
                                <option value="<%= g %>" <%= selected ? "selected" : "" %>><%= "ALL".equals(g) ? "Semua Jenjang" : g %></option>
                                <% } %>
                            </select>
                        </div>
                    </div>
                    <div class="mb-2 mt-2">
                        <label class="form-label small fw-semibold mb-1">Info Jadwal</label>
                        <input type="text" name="scheduleInfo" class="form-control form-control-sm" maxlength="150"
                               value="<%= editing && editLink.scheduleInfo != null ? ValidationUtil.sanitizeHtml(editLink.scheduleInfo) : "" %>"
                               placeholder="Rabu 19.00 WIB">
                    </div>
                    <div class="form-check">
                        <input class="form-check-input" type="checkbox" name="isActive" id="isActive"
                               <%= (!editing || Boolean.TRUE.equals(editLink.isActive)) ? "checked" : "" %>>
                        <label class="form-check-label small" for="isActive">Aktif (tampil di menu siswa)</label>
                    </div>
                </div>
                <div class="modal-footer py-2">
                    <a href="<%= ctx %>/MeetLinkServlet" class="btn btn-sm btn-light">Batal</a>
                    <button type="submit" class="btn btn-sm btn-primary">
                        <i class="bi bi-save me-1"></i><%= editing ? "Simpan" : "Tambah" %>
                    </button>
                </div>
            </form>
        </div>
    </div>
</div>

<script src="../assets/vendor/bootstrap.bundle.min.js"></script>
<% if (editing) { %>
<script>
    // Mode edit: langsung buka modal dengan data terisi.
    (function () {
        var el = document.getElementById('linkModal');
        if (el) { new bootstrap.Modal(el).show(); }
    })();
</script>
<% } %>
</body>
</html>
