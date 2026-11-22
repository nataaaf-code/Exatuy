package com.examora.controller;

import com.examora.dao.SettingsDAO;
import com.examora.model.User;
import com.examora.service.AuditService;
import com.examora.service.QuotaService;
import com.examora.service.UserService;
import com.examora.util.RateLimiter;

import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;
import java.io.IOException;

/**
 * Login Servlet - Handles user authentication with rate limiting protection
 */
@WebServlet("/LoginServlet")
public class LoginServlet extends HttpServlet {
    private UserService userService;
    private AuditService auditService;
    private SettingsDAO settingsDAO;
    private QuotaService quotaService;

    @Override
    public void init() throws ServletException {
        userService = new UserService();
        auditService = new AuditService();
        settingsDAO = new SettingsDAO();
        quotaService = new QuotaService();
    }

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        HttpSession session = request.getSession(false);
        if (session != null && session.getAttribute("user") != null) {
            User user = (User) session.getAttribute("user");
            redirectToDashboard(request, response, user);
            return;
        }

        // Handle registration disabled error
        String error = request.getParameter("error");
        if ("registration_disabled".equals(error)) {
            request.setAttribute("error", "Registrasi pengguna baru saat ini dinonaktifkan. Silakan hubungi administrator.");
        }

        // Pass registration enabled setting to JSP
        request.setAttribute("registrationEnabled", settingsDAO.isRegistrationEnabled());

        request.getRequestDispatcher("/common/login.jsp").forward(request, response);
    }

    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        String email = request.getParameter("email");
        String password = request.getParameter("password");

        if (email == null || email.trim().isEmpty() ||
            password == null || password.trim().isEmpty()) {
            request.setAttribute("error", "Email dan password harus diisi");
            request.getRequestDispatcher("/common/login.jsp").forward(request, response);
            return;
        }

        email = email.trim().toLowerCase();

        // Get client IP for rate limiting (check proxy headers first)
        String clientIp = getClientIp(request);

        // Check rate limit by IP first
        RateLimiter.RateLimitResult ipLimit = RateLimiter.checkLoginAllowed(clientIp);
        if (!ipLimit.isAllowed()) {
            request.setAttribute("error", ipLimit.getMessage());
            request.setAttribute("locked", true);
            request.getRequestDispatcher("/common/login.jsp").forward(request, response);
            return;
        }

        // Check rate limit by email
        RateLimiter.RateLimitResult emailLimit = RateLimiter.checkLoginAllowed(email);
        if (!emailLimit.isAllowed()) {
            request.setAttribute("error", emailLimit.getMessage());
            request.setAttribute("locked", true);
            request.getRequestDispatcher("/common/login.jsp").forward(request, response);
            return;
        }

        try {
            User user = userService.authenticate(email, password);

            // Invalidate old session to prevent session fixation attacks
            HttpSession oldSession = request.getSession(false);
            if (oldSession != null) {
                oldSession.invalidate();
            }

            // Create new session with new ID
            HttpSession session = request.getSession(true);
            session.setAttribute("user", user);
            session.setAttribute("userId", user.getId());
            session.setAttribute("userName", user.getName());
            session.setAttribute("userRole", user.getRole());
            session.setAttribute("csrfToken", com.examora.util.PasswordUtil.generateToken());

            // Reset rate limit on successful login
            RateLimiter.resetAttempts(email);
            RateLimiter.resetAttempts(clientIp);

            // Fail-safe reset kuota bulanan bila scheduler terlewat (mis. server tidur di hosting gratis)
            if (user.isPeserta()) {
                try {
                    quotaService.getBalance(user.getId());
                } catch (QuotaService.ServiceException quotaEx) {
                    System.err.println("Warning: Failed to check monthly quota reset: " + quotaEx.getMessage());
                }
            }

            // Audit log for successful login
            try {
                auditService.logLogin(user, request, true, null);
            } catch (Exception auditEx) {
                // Log audit failure but don't fail the login
                System.err.println("Warning: Failed to log audit: " + auditEx.getMessage());
            }

            redirectToDashboard(request, response, user);

        } catch (UserService.ServiceException e) {
            // Record failed attempt for both IP and email
            boolean ipLocked = RateLimiter.recordFailedAttempt(clientIp);
            boolean emailLocked = RateLimiter.recordFailedAttempt(email);

            // Handle expected authentication errors (wrong password, user not found, etc.)
            try {
                // Audit log for failed login (create temporary user object for logging)
                User failedUser = new User();
                failedUser.setEmail(email);
                auditService.logLogin(failedUser, request, false, e.getMessage());
            } catch (Exception auditEx) {
                // Log audit failure but continue with error handling
                System.err.println("Warning: Failed to log audit: " + auditEx.getMessage());
            }

            // Check if lockout was triggered
            if (ipLocked || emailLocked) {
                request.setAttribute("error", "Terlalu banyak percobaan login yang gagal. Akun terkunci selama 15 menit.");
                request.setAttribute("locked", true);
            } else {
                // Show remaining attempts
                int remainingByIp = RateLimiter.getRemainingAttempts(clientIp);
                int remainingByEmail = RateLimiter.getRemainingAttempts(email);
                int remaining = Math.min(remainingByIp, remainingByEmail);

                String errorMsg = e.getMessage();
                if (remaining > 0 && remaining <= 3) {
                    errorMsg += " (Peringatan: " + remaining + " percobaan tersisa sebelum akun terkunci)";
                }
                request.setAttribute("error", errorMsg);
            }

            request.setAttribute("email", email);
            request.getRequestDispatcher("/common/login.jsp").forward(request, response);

        } catch (Exception e) {
            // Catch any unexpected errors
            System.err.println("Unexpected error during login: " + e.getMessage());
            e.printStackTrace();

            // Still record the attempt
            RateLimiter.recordFailedAttempt(clientIp);

            request.setAttribute("error", "Terjadi kesalahan pada server. Silakan coba lagi nanti.");
            request.setAttribute("email", email);
            request.getRequestDispatcher("/common/login.jsp").forward(request, response);
        }
    }

    /**
     * Get client IP address, checking for proxy headers
     */
    private String getClientIp(HttpServletRequest request) {
        String ip = request.getHeader("X-Forwarded-For");
        if (ip == null || ip.isEmpty() || "unknown".equalsIgnoreCase(ip)) {
            ip = request.getHeader("Proxy-Client-IP");
        }
        if (ip == null || ip.isEmpty() || "unknown".equalsIgnoreCase(ip)) {
            ip = request.getHeader("WL-Proxy-Client-IP");
        }
        if (ip == null || ip.isEmpty() || "unknown".equalsIgnoreCase(ip)) {
            ip = request.getHeader("HTTP_CLIENT_IP");
        }
        if (ip == null || ip.isEmpty() || "unknown".equalsIgnoreCase(ip)) {
            ip = request.getHeader("HTTP_X_FORWARDED_FOR");
        }
        if (ip == null || ip.isEmpty() || "unknown".equalsIgnoreCase(ip)) {
            ip = request.getRemoteAddr();
        }

        // For multiple proxies, first IP is the client
        if (ip != null && ip.contains(",")) {
            ip = ip.split(",")[0].trim();
        }

        return ip;
    }

    private void redirectToDashboard(HttpServletRequest request, HttpServletResponse response, User user)
            throws IOException {
        String contextPath = request.getContextPath();
        if (user.isAdmin()) {
            response.sendRedirect(contextPath + "/AdminServlet?action=dashboard");
        } else {
            response.sendRedirect(contextPath + "/ExamServlet?action=dashboard");
        }
    }
}
