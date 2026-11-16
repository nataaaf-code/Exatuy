<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%@ page import="com.examora.model.User" %>
<%@ page import="com.examora.service.ChatService" %>
<%@ page import="com.examora.util.ValidationUtil" %>
<%
    String requestURI = request.getRequestURI();
    String queryString = request.getQueryString();
    User sidebarUser = (User) session.getAttribute("user");
    int chatUnreadCount = 0;
    if (sidebarUser != null && sidebarUser.isAdmin()) {
        try {
            chatUnreadCount = new ChatService().getUnreadCountForAdmin();
        } catch (Exception e) {}
    }
%>
<!-- Sidebar -->
<nav class="sidebar">
    <a href="../AdminServlet?action=dashboard" class="sidebar-brand">
        <i class="bi bi-mortarboard-fill me-2"></i>Exatuy
    </a>
    <hr class="sidebar-divider bg-white opacity-25">
    <ul class="sidebar-menu">
        <li>
            <a href="../AdminServlet?action=dashboard" <%= requestURI.contains("AdminServlet") && (queryString == null || queryString.contains("dashboard")) ? "class=\"active\"" : "" %>>
                <i class="bi bi-speedometer2"></i>Dashboard
            </a>
        </li>
        <li class="sidebar-heading text-white-50 small">PEMBELAJARAN</li>
        <li>
            <a href="../QuizServlet?action=list" <%= requestURI.contains("QuizServlet") ? "class=\"active\"" : "" %>>
                <i class="bi bi-journal-text"></i>Kelola Quiz
            </a>
        </li>
        <li>
            <a href="../AdminServlet?action=users" <%= requestURI.contains("AdminServlet") && queryString != null && queryString.contains("users") ? "class=\"active\"" : "" %>>
                <i class="bi bi-people"></i>Kelola Siswa
            </a>
        </li>
        <li>
            <a href="../AdminServlet?action=userRetake" <%= requestURI.contains("AdminServlet") && queryString != null && queryString.contains("userRetake") ? "class=\"active\"" : "" %>>
                <i class="bi bi-arrow-repeat"></i>Retake User
            </a>
        </li>
        <li><hr class="sidebar-divider bg-white opacity-25 my-2"></li>
        <li class="sidebar-heading text-white-50 small">OPERASIONAL</li>
        <li>
            <a href="../AttendanceServlet?action=list" <%= requestURI.contains("AttendanceServlet") ? "class=\"active\"" : "" %>>
                <i class="bi bi-check2-square"></i>Absensi & Kuota
            </a>
        </li>
        <li>
            <a href="../BillingServlet?action=packages" <%= requestURI.contains("BillingServlet") && queryString != null && queryString.contains("packages") ? "class=\"active\"" : "" %>>
                <i class="bi bi-box-seam"></i>Paket Kuota
            </a>
        </li>
        <li>
            <a href="../BillingServlet?action=list" <%= requestURI.contains("BillingServlet") && (queryString == null || !queryString.contains("packages")) ? "class=\"active\"" : "" %>>
                <i class="bi bi-cash-stack"></i>Tagihan
                <span class="badge bg-warning text-dark ms-auto small">BARU</span>
            </a>
        </li>
        <li>
            <a href="../FinanceServlet?action=summary" <%= requestURI.contains("FinanceServlet") ? "class=\"active\"" : "" %>>
                <i class="bi bi-wallet2"></i>Keuangan
                <span class="badge bg-warning text-dark ms-auto small">BARU</span>
            </a>
        </li>
        <li>
            <a href="../BulkEmailServlet" <%= requestURI.contains("BulkEmailServlet") ? "class=\"active\"" : "" %>>
                <i class="bi bi-envelope-paper"></i>Pengingat Email
            </a>
        </li>
        <li><hr class="sidebar-divider bg-white opacity-25 my-2"></li>
        <li class="sidebar-heading text-white-50 small">REPORTING</li>
        <li>
            <a href="../AdminServlet?action=statistics" <%= requestURI.contains("AdminServlet") && queryString != null && queryString.contains("statistics") ? "class=\"active\"" : "" %>>
                <i class="bi bi-graph-up"></i>Statistik Quiz
            </a>
        </li>
        <li>
            <a href="../TranscriptServlet?action=view" <%= requestURI.contains("TranscriptServlet") ? "class=\"active\"" : "" %>>
                <i class="bi bi-card-list"></i>Transcript Nilai
            </a>
        </li>
        <li>
            <a href="../AdminServlet?action=editScoreList" <%= requestURI.contains("AdminServlet") && queryString != null && queryString.contains("editScore") ? "class=\"active\"" : "" %>>
                <i class="bi bi-pencil-square"></i>Edit Nilai
            </a>
        </li>
        <li>
            <a href="../AdminServlet?action=gamification" <%= requestURI.contains("AdminServlet") && queryString != null && queryString.contains("gamification") ? "class=\"active\"" : "" %>>
                <i class="bi bi-trophy-fill"></i>Gamification
            </a>
        </li>
        <li><hr class="sidebar-divider bg-white opacity-25 my-2"></li>
        <li class="sidebar-heading text-white-50 small">KOMUNIKASI</li>
        <li>
            <a href="../ChatServlet?action=threads" <%= requestURI.contains("ChatServlet") ? "class=\"active\"" : "" %>>
                <i class="bi bi-chat-dots"></i>Chat
                <% if (chatUnreadCount > 0) { %><span class="badge bg-danger ms-1"><%= chatUnreadCount %></span><% } %>
            </a>
        </li>
        <li>
            <a href="../AdminServlet?action=informationBoard" <%= requestURI.contains("AdminServlet") && queryString != null && queryString.contains("informationBoard") ? "class=\"active\"" : "" %>>
                <i class="bi bi-megaphone-fill"></i>Information Board
            </a>
        </li>
        <li><hr class="sidebar-divider bg-white opacity-25 my-2"></li>
        <li>
            <a href="../AdminServlet?action=settings" <%= requestURI.contains("AdminServlet") && queryString != null && queryString.contains("settings") ? "class=\"active\"" : "" %>>
                <i class="bi bi-gear"></i>Pengaturan
            </a>
        </li>
        <li>
            <a href="../AuditServlet" <%= requestURI.contains("AuditServlet") ? "class=\"active\"" : "" %>>
                <i class="bi bi-clipboard-data"></i>Audit Log
            </a>
        </li>
        <li class="mt-auto">
            <a href="../LogoutServlet" class="text-danger">
                <i class="bi bi-box-arrow-left"></i>Logout
            </a>
        </li>
    </ul>
    <div class="sidebar-footer text-white-50 small">
        <div class="d-flex align-items-center">
            <div class="bg-white bg-opacity-20 rounded-circle d-flex align-items-center justify-content-center me-2"
                 style="width: 32px; height: 32px; font-size: 0.8rem;">
                <%= ValidationUtil.sanitizeHtml(sidebarUser != null && sidebarUser.getName() != null ? sidebarUser.getName().substring(0, 1).toUpperCase() : "U") %>
            </div>
            <div class="overflow-hidden">
                <div class="text-white fw-bold text-truncate"><%= ValidationUtil.sanitizeHtml(sidebarUser != null ? sidebarUser.getName() : "User") %></div>
                <div class="text-white-50 text-truncate" style="font-size: 0.75rem;"><%= ValidationUtil.sanitizeHtml(sidebarUser != null ? sidebarUser.getEmail() : "") %></div>
            </div>
        </div>
    </div>
</nav>

<!-- Sidebar Overlay -->
<div class="sidebar-overlay d-lg-none" id="sidebarOverlay"></div>

<!-- Mobile Sidebar Toggle -->
<button class="sidebar-toggle" type="button" id="sidebarToggle">
    <span class="sidebar-toggle-bar"></span>
    <span class="sidebar-toggle-bar"></span>
    <span class="sidebar-toggle-bar"></span>
</button>

<script>
const sidebarToggle = document.getElementById('sidebarToggle');
const sidebar = document.querySelector('.sidebar');
const sidebarOverlay = document.getElementById('sidebarOverlay');

function toggleSidebar() {
    sidebar.classList.toggle('show');
    sidebarOverlay.classList.toggle('show');
}

function closeSidebar() {
    sidebar.classList.remove('show');
    sidebarOverlay.classList.remove('show');
}

sidebarToggle?.addEventListener('click', toggleSidebar);
sidebarOverlay?.addEventListener('click', closeSidebar);

const sidebarLinks = document.querySelectorAll('.sidebar-menu a');
sidebarLinks.forEach(link => {
    link.addEventListener('click', function() {
        if (window.innerWidth < 992) {
            closeSidebar();
        }
    });
});

window.addEventListener('resize', function() {
    if (window.innerWidth >= 992) {
        sidebar.classList.remove('show');
        sidebarOverlay.classList.remove('show');
    }
});
</script>
