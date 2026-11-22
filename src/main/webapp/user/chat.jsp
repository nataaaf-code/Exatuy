<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%@ page import="com.examora.model.User" %>
<%@ page import="com.examora.model.ChatMessage" %>
<%@ page import="com.examora.dao.SettingsDAO" %>
<%@ page import="com.examora.util.ValidationUtil" %>
<%@ page import="java.util.List" %>
<%
    User currentUser = (User) session.getAttribute("user");
    if (currentUser == null) {
        response.sendRedirect("../LoginServlet");
        return;
    }
    if (currentUser.isAdmin()) {
        response.sendRedirect("../ChatServlet?action=threads");
        return;
    }

    // Check if chat is enabled
    SettingsDAO settingsDAO = new SettingsDAO();
    boolean chatEnabled = settingsDAO.isChatEnabled();
    if (!chatEnabled) {
        response.sendRedirect("../ExamServlet?action=dashboard");
        return;
    }

    List<ChatMessage> messages = (List<ChatMessage>) request.getAttribute("messages");
    Integer unreadCount = (Integer) request.getAttribute("unreadCount");
    String success = (String) request.getAttribute("success");
    String error = (String) request.getAttribute("error");

    // Generate CSRF token
    String csrfToken = (String) session.getAttribute("csrfToken");
    if (csrfToken == null) {
        csrfToken = java.util.UUID.randomUUID().toString();
        session.setAttribute("csrfToken", csrfToken);
    }
%>
<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Chat dengan Admin - Exatuy</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
    <link href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.10.0/font/bootstrap-icons.css" rel="stylesheet">
    <link href="../assets/css/style.css" rel="stylesheet">
    <link rel="icon" type="image/svg+xml" type="image/svg+xml" href="../assets/img/favicon.svg?v=3">
    <style>
        .chat-container {
            height: calc(100vh - 250px);
            min-height: 400px;
            display: flex;
            flex-direction: column;
        }
        .chat-messages {
            flex: 1;
            overflow-y: auto;
            padding: 1rem;
            background-color: #f8f9fa;
            border-radius: 0.5rem;
        }
        .message-bubble {
            max-width: 75%;
            padding: 0.75rem 1rem;
            border-radius: 1rem;
            margin-bottom: 0.5rem;
            word-wrap: break-word;
        }
        .message-user {
            background-color: #0d6efd;
            color: white;
            margin-left: auto;
            border-bottom-right-radius: 0.25rem;
        }
        .message-admin {
            background-color: white;
            border: 1px solid #dee2e6;
            border-bottom-left-radius: 0.25rem;
        }
        .message-time {
            font-size: 0.7rem;
            opacity: 0.7;
        }
        .chat-input-area {
            background-color: white;
            padding: 1rem;
            border-top: 1px solid #dee2e6;
            border-radius: 0 0 0.5rem 0.5rem;
        }
        .chat-header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 1rem 1.5rem;
            border-radius: 0.5rem 0.5rem 0 0;
        }
        .empty-chat {
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            height: 100%;
            color: #6c757d;
        }
        .empty-chat i {
            font-size: 4rem;
            margin-bottom: 1rem;
            opacity: 0.5;
        }
        .message-sender {
            font-weight: 600;
            font-size: 0.8rem;
            margin-bottom: 0.25rem;
        }
        .message-admin .message-sender {
            color: #667eea;
        }
    </style>
<link href="../assets/css/handdrawn.css" rel="stylesheet">
</head>
<body>
    <!-- Navbar -->
    <%@ include file="navbar.jspf" %>

    <!-- Main Content -->
    <div class="container py-4">
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

        <div class="row justify-content-center">
            <div class="col-lg-8">
                <div class="card shadow-sm border-0">
                    <!-- Chat Header -->
                    <div class="chat-header">
                <%-- Mobile: Profile menu items shown in nav list --%>
                    <li class="nav-item d-md-none">
                        <hr class="my-2 border-light">
                    </li>
                    <li class="nav-item d-md-none">
                        <div class="d-flex align-items-center text-white py-2">
                            <i class="bi bi-person-circle me-2 fs-5"></i>
                            <span><%= ValidationUtil.sanitizeHtml(currentUser.getName()) %></span>
                        </div>
                    </li>
                    <li class="nav-item d-md-none">
                        <a class="nav-link" href="../ProfileServlet">
                            <i class="bi bi-person me-2"></i>Profil Saya
                        </a>
                    </li>
                    <li class="nav-item d-md-none">
                        <a class="nav-link" href="../LogoutServlet">
                            <i class="bi bi-box-arrow-left me-2"></i>Logout
                        </a>
                    </li>
                </ul>
                <%-- Desktop: Profile dropdown shown outside nav list --%>
                <div class="d-none d-md-flex align-items-center">
                    <div class="dropdown">
                        <a href="#" class="d-flex align-items-center text-white text-decoration-none dropdown-toggle" data-bs-toggle="dropdown">
                            <i class="bi bi-person-circle me-1 fs-5"></i>
                            <span><%= ValidationUtil.sanitizeHtml(currentUser.getName()) %></span>
                        </a>
                        <ul class="dropdown-menu dropdown-menu-end">
                            <li><a class="dropdown-item" href="../ProfileServlet"><i class="bi bi-person me-2"></i>Profil Saya</a></li>
                            <li><hr class="dropdown-divider"></li>
                            <li><a class="dropdown-item" href="../LogoutServlet"><i class="bi bi-box-arrow-left me-2"></i>Logout</a></li>
                        </ul>
                    </div>
                </div>
                            <div>
                                <h5 class="mb-0">Chat dengan Admin</h5>
                                <small class="opacity-75">Tanyakan pertanyaan atau konsultasi</small>
                            </div>
                        </div>
                    </div>

                    <!-- Chat Messages -->
                    <div class="chat-container">
                        <div class="chat-messages" id="chatMessages">
                            <% if (messages != null && !messages.isEmpty()) { %>
                                <% for (ChatMessage msg : messages) { %>
                                <div class="d-flex <%= msg.isFromUser() ? "justify-content-end" : "justify-content-start" %>">
                                    <div class="message-bubble <%= msg.isFromUser() ? "message-user" : "message-admin" %>">
                                        <% if (msg.isFromAdmin()) { %>
                                        <div class="message-sender">
                                            <i class="bi bi-person-badge me-1"></i><%= ValidationUtil.sanitizeHtml(msg.getSenderName() != null ? msg.getSenderName() : "Admin") %>
                                        </div>
                                        <% } %>
                                        <div class="message-text"><%= ValidationUtil.sanitizeHtml(msg.getMessageText()) %></div>
                                        <div class="message-time text-end mt-1">
                                            <%= ValidationUtil.sanitizeHtml(msg.getTimeAgo()) %>
                                        </div>
                                    </div>
                                </div>
                                <% } %>
                            <% } else { %>
                                <div class="empty-chat">
                                    <i class="bi bi-chat-dots"></i>
                                    <h5>Belum ada pesan</h5>
                                    <p>Mulai percakapan dengan admin</p>
                                </div>
                            <% } %>
                        </div>

                        <!-- Chat Input -->
                        <div class="chat-input-area">
                            <form id="chatForm" method="post" action="../ChatServlet?action=send">
                                <input type="hidden" name="csrfToken" value="<%= csrfToken %>">
                                <div class="input-group">
                                    <input type="text" class="form-control" id="messageInput" name="message"
                                           placeholder="Ketik pesan Anda..." required maxlength="5000"
                                           autocomplete="off">
                                    <button type="submit" class="btn btn-primary" id="sendBtn">
                                        <i class="bi bi-send"></i>
                                    </button>
                                </div>
                            </form>
                        </div>
                    </div>
                </div>

                <!-- Info Card -->
                <div class="card mt-3 border-0 bg-light">
                    <div class="card-body">
                        <div class="d-flex align-items-start">
                            <i class="bi bi-info-circle text-primary fs-4 me-3"></i>
                            <div>
                                <h6 class="mb-1">Tips</h6>
                                <small class="text-muted">
                                    Admin akan membalas pesan Anda sesegera mungkin.
                                    Pesan akan otomatis ter-refresh setiap 10 detik.
                                </small>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <!-- Footer -->
    <footer class="bg-light py-3 mt-auto">
        <div class="container text-center">
            <span class="text-muted">&copy; 2026 Exatuy. All rights reserved.</span>
        </div>
    </footer>

    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/js/bootstrap.bundle.min.js"></script>
    <script>
        // Scroll to bottom of chat
        function scrollToBottom() {
            const chatMessages = document.getElementById('chatMessages');
            chatMessages.scrollTop = chatMessages.scrollHeight;
        }

        // Initial scroll
        scrollToBottom();

        // Handle form submission via AJAX
        document.getElementById('chatForm').addEventListener('submit', function(e) {
            e.preventDefault();

            const messageInput = document.getElementById('messageInput');
            const csrfTokenInput = document.querySelector('input[name="csrfToken"]');
            const message = messageInput.value.trim();
            const sendBtn = document.getElementById('sendBtn');

            console.log('Message value:', message);
            console.log('CSRF token:', csrfTokenInput ? csrfTokenInput.value : 'not found');

            if (!message) {
                console.log('Message is empty, returning');
                return;
            }

            // Disable input while sending
            messageInput.disabled = true;
            sendBtn.disabled = true;

            // Use URLSearchParams for application/x-www-form-urlencoded
            const params = new URLSearchParams();
            params.append('message', message);
            params.append('csrfToken', csrfTokenInput ? csrfTokenInput.value : '');
            params.append('action', 'send');

            console.log('Sending params:', params.toString());

            fetch('../ChatServlet?action=send&ajax=true', {
                method: 'POST',
                body: params,
                headers: {
                    'Content-Type': 'application/x-www-form-urlencoded',
                    'X-Requested-With': 'XMLHttpRequest'
                }
            })
            .then(response => response.json())
            .then(data => {
                console.log('Response:', data);
                if (data.success) {
                    // Add message to chat
                    addMessageToChat(data.message);
                    messageInput.value = '';
                } else {
                    alert(data.error || 'Gagal mengirim pesan');
                }
            })
            .catch(error => {
                console.error('Error:', error);
                alert('Terjadi kesalahan. Silakan coba lagi.');
            })
            .finally(() => {
                messageInput.disabled = false;
                sendBtn.disabled = false;
                messageInput.focus();
            });
        });

        // Add message to chat UI
        function addMessageToChat(msg) {
            const chatMessages = document.getElementById('chatMessages');

            // Remove empty state if exists
            const emptyChat = chatMessages.querySelector('.empty-chat');
            if (emptyChat) {
                emptyChat.remove();
            }

            const messageDiv = document.createElement('div');
            messageDiv.className = 'd-flex justify-content-end';
            messageDiv.innerHTML = '<div class="message-bubble message-user">' +
                '<div class="message-text">' + escapeHtml(msg.messageText) + '</div>' +
                '<div class="message-time text-end mt-1">' + escapeHtml(msg.timeAgo) + '</div>' +
                '</div>';

            chatMessages.appendChild(messageDiv);
            scrollToBottom();
        }

        // Escape HTML to prevent XSS
        function escapeHtml(text) {
            const div = document.createElement('div');
            div.textContent = text;
            return div.innerHTML;
        }

        // Auto-refresh messages
        let lastMessageId = <%= messages != null && !messages.isEmpty() ? messages.get(messages.size() - 1).getId() : 0 %>;

        function refreshMessages() {
            fetch('../ChatServlet?action=thread&ajax=true')
                .then(response => response.text())
                .then(html => {
                    // Check for new messages by comparing last message ID
                    const parser = new DOMParser();
                    const doc = parser.parseFromString(html, 'text/html');
                    const messages = doc.querySelectorAll('.message-bubble');

                    if (messages.length > 0) {
                        // Reload page to get new messages (simple approach)
                        // For better UX, implement partial update
                    }
                })
                .catch(error => console.error('Refresh error:', error));
        }

        // Refresh every 5 seconds
        setInterval(refreshMessages, 5000);

        // Enter key to send
        document.getElementById('messageInput').addEventListener('keypress', function(e) {
            if (e.key === 'Enter' && !e.shiftKey) {
                e.preventDefault();
                document.getElementById('chatForm').dispatchEvent(new Event('submit'));
            }
        });
    </script>
</body>
</html>
