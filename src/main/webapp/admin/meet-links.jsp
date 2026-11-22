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
    <link href="../assets/css/handdrawn.css" rel="stylesheet">
</head>
<body class="bg-light">
<%@ include file="sidebar.jsp" %>
<div class="main-content p-4">
    <div class="d-flex justify-content-between align-items-center mb-3 flex-wrap gap-2">
        <div>
            <h1 class="h4 mb-1"><i class="bi bi-camera-video me-2"></i>Link Google Meet</h1>
            <p class="text-muted small mb-0">Tautan ini yang muncul di menu siswa. Membuka sesi memotong 1 poin kuota.</p>
        </div>
        <span class="badge bg-secondary"><%= meetLinks.size() %> tautan</span>
    </div>

    <% if (flashSuccess != null) { %>
    <div class="alert alert-success"><i class="bi bi-check-circle me-2"></i><%= ValidationUtil.sanitizeHtml(flashSuccess) %></div>
    <% } %>
    <% if (flashError != null) { %>
    <div class="alert alert-danger"><i class="bi bi-exclamation-triangle me-2"></i><%= ValidationUtil.sanitizeHtml(flashError) %></div>
    <% } %>
    <% if (error != null) { %>
    <div class="alert alert-warning"><%= ValidationUtil.sanitizeHtml(error) %></div>
    <% } %>

    <div class="row g-3">
        <div class="col-lg-4">
            <div class="card border-0 shadow-sm">
                <div class="card-header bg-white fw-semibold">
                    <%= editing ? "Edit Tautan" : "Tambah Tautan" %>
                </div>
                <div class="card-body">
                    <form method="post" action="<%= ctx %>/MeetLinkServlet">
                        <input type="hidden" name="csrfToken" value="<%= session.getAttribute("csrfToken") %>">
                        <input type="hidden" name="action" value="<%= editing ? "update" : "create" %>">
                        <% if (editing) { %><input type="hidden" name="id" value="<%= editLink.id %>"><% } %>

                        <label class="form-label small fw-semibold">Judul Sesi *</label>
                        <input type="text" name="title" class="form-control mb-2" required maxlength="150"
                               value="<%= editing ? ValidationUtil.sanitizeHtml(editLink.title) : "" %>"
                               placeholder="GMeet Matematika SD-4">

                        <label class="form-label small fw-semibold">Tautan *</label>
                        <input type="url" name="url" class="form-control mb-2" required
                               value="<%= editing ? ValidationUtil.sanitizeHtml(editLink.url) : "" %>"
                               placeholder="https://meet.google.com/xxx-xxxx-xxx">
                        <div class="form-text mb-2">Hanya tautan meet.google.com / drive.google.com / docs.google.com yang diterima sistem.</div>

                        <label class="form-label small fw-semibold">Kelas (tag siswa)</label>
                        <input type="text" name="targetTag" class="form-control mb-2" maxlength="50"
                               value="<%= editing && editLink.targetTag != null ? ValidationUtil.sanitizeHtml(editLink.targetTag) : "" %>"
                               placeholder="SD-4 (kosongkan = semua kelas)">

                        <label class="form-label small fw-semibold">Jenjang</label>
                        <select name="targetGrade" class="form-select mb-2">
                            <% for (String g : InformationBoard.GRADES) {
                                   boolean selected = editing ? g.equalsIgnoreCase(editLink.targetGrade) : "ALL".equals(g);
                            %>
                            <option value="<%= g %>" <%= selected ? "selected" : "" %>><%= "ALL".equals(g) ? "Semua Jenjang" : g %></option>
                            <% } %>
                        </select>

                        <label class="form-label small fw-semibold">Info Jadwal</label>
                        <input type="text" name="scheduleInfo" class="form-control mb-2" maxlength="150"
                               value="<%= editing && editLink.scheduleInfo != null ? ValidationUtil.sanitizeHtml(editLink.scheduleInfo) : "" %>"
                               placeholder="Rabu 19.00 WIB">

                        <div class="form-check mb-3">
                            <input class="form-check-input" type="checkbox" name="isActive" id="isActive"
                                   <%= (!editing || Boolean.TRUE.equals(editLink.isActive)) ? "checked" : "" %>>
                            <label class="form-check-label small" for="isActive">Aktif (tampil di menu siswa)</label>
                        </div>

                        <div class="d-flex gap-2">
                            <button type="submit" class="btn btn-primary flex-fill">
                                <i class="bi bi-save me-1"></i><%= editing ? "Simpan Perubahan" : "Tambah" %>
                            </button>
                            <% if (editing) { %>
                            <a href="<%= ctx %>/MeetLinkServlet" class="btn btn-outline-secondary">Batal</a>
                            <% } %>
                        </div>
                    </form>
                </div>
            </div>
        </div>

        <div class="col-lg-8">
            <div class="card border-0 shadow-sm">
                <div class="card-header bg-white fw-semibold">Daftar Tautan</div>
                <div class="table-responsive">
                    <table class="table table-hover align-middle mb-0">
                        <thead class="table-light">
                        <tr>
                            <th>Judul</th><th>Target</th><th>Jadwal</th><th>Status</th><th class="text-end">Aksi</th>
                        </tr>
                        </thead>
                        <tbody>
                        <% if (meetLinks.isEmpty()) { %>
                        <tr><td colspan="5" class="text-center text-muted py-4">Belum ada tautan. Tambahkan di formulir kiri.</td></tr>
                        <% } %>
                        <% for (MeetLinkDAO.MeetLink link : meetLinks) { %>
                        <tr>
                            <td>
                                <div class="fw-semibold"><%= ValidationUtil.sanitizeHtml(link.title) %></div>
                                <a href="<%= ValidationUtil.sanitizeHtml(link.url) %>" target="_blank" rel="noopener noreferrer"
                                   class="small text-decoration-none text-truncate d-inline-block" style="max-width:280px;">
                                    <i class="bi bi-box-arrow-up-right me-1"></i><%= ValidationUtil.sanitizeHtml(link.url) %>
                                </a>
                            </td>
                            <td class="small">
                                <%= link.targetTag == null || link.targetTag.isBlank() ? "Semua kelas" : ValidationUtil.sanitizeHtml(link.targetTag) %>
                                <br><span class="text-muted"><%= "ALL".equalsIgnoreCase(link.targetGrade) ? "Semua jenjang" : ValidationUtil.sanitizeHtml(link.targetGrade) %></span>
                            </td>
                            <td class="small"><%= link.scheduleInfo == null ? "-" : ValidationUtil.sanitizeHtml(link.scheduleInfo) %></td>
                            <td>
                                <span class="badge <%= Boolean.TRUE.equals(link.isActive) ? "bg-success" : "bg-secondary" %>">
                                    <%= Boolean.TRUE.equals(link.isActive) ? "Aktif" : "Nonaktif" %>
                                </span>
                            </td>
                            <td class="text-end">
                                <a href="<%= ctx %>/MeetLinkServlet?edit=<%= link.id %>" class="btn btn-sm btn-outline-primary">
                                    <i class="bi bi-pencil"></i>
                                </a>
                                <form method="post" action="<%= ctx %>/MeetLinkServlet" class="d-inline">
                                    <input type="hidden" name="csrfToken" value="<%= session.getAttribute("csrfToken") %>">
                                    <input type="hidden" name="action" value="toggle">
                                    <input type="hidden" name="id" value="<%= link.id %>">
                                    <button class="btn btn-sm btn-outline-secondary" title="Aktif/nonaktifkan"><i class="bi bi-power"></i></button>
                                </form>
                                <form method="post" action="<%= ctx %>/MeetLinkServlet" class="d-inline"
                                      onsubmit="return confirm('Hapus tautan ini?');">
                                    <input type="hidden" name="csrfToken" value="<%= session.getAttribute("csrfToken") %>">
                                    <input type="hidden" name="action" value="delete">
                                    <input type="hidden" name="id" value="<%= link.id %>">
                                    <button class="btn btn-sm btn-outline-danger"><i class="bi bi-trash"></i></button>
                                </form>
                            </td>
                        </tr>
                        <% } %>
                        </tbody>
                    </table>
                </div>
            </div>
        </div>
    </div>
</div>
<script src="../assets/vendor/bootstrap.bundle.min.js"></script>
</body>
</html>
