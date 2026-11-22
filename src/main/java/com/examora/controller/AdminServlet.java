package com.examora.controller;

import com.examora.dao.AttendanceDAO;
import com.examora.dao.QuestionDAO;
import com.examora.dao.QuizDAO;
import com.examora.dao.SettingsDAO;
import com.examora.dao.SubmissionDAO;
import com.examora.dao.UserDAO;
import com.examora.model.Question;
import com.examora.model.Quiz;
import com.examora.model.Submission;
import com.examora.model.User;
import com.examora.model.InformationBoard;
import com.examora.model.UserPoints;
import com.examora.model.PointTransaction;
import com.examora.service.AttendanceService;
import com.examora.service.AuditService;
import com.examora.service.QuizService;
import com.examora.service.SubmissionService;
import com.examora.service.UserService;
import com.examora.service.ApiService;
import com.examora.service.GamificationService;
import com.examora.service.RetakeCodeService;
import com.examora.model.RetakeCode;

import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.MultipartConfig;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.Part;
import javax.imageio.ImageIO;
import java.awt.image.BufferedImage;
import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.PrintWriter;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.StandardCopyOption;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.UUID;
import java.time.LocalDateTime;
import java.util.Map;
import com.google.gson.Gson;
import com.google.gson.JsonObject;

/**
 * Admin Servlet - Handles admin dashboard and statistics
 */
@WebServlet("/AdminServlet")
@MultipartConfig(fileSizeThreshold = 1024 * 1024, maxFileSize = 5 * 1024 * 1024, maxRequestSize = 10 * 1024 * 1024)
public class AdminServlet extends HttpServlet {
    private UserService userService;
    private QuizService quizService;
    private SubmissionService submissionService;
    private AttendanceService attendanceService;
    private AuditService auditService;
    private SubmissionDAO submissionDAO;
    private AttendanceDAO attendanceDAO;
    private SettingsDAO settingsDAO;
    private QuestionDAO questionDAO;
    private ApiService apiService;
    private GamificationService gamificationService;
    private UserDAO userDAO;
    private QuizDAO quizDAO;

    @Override
    public void init() throws ServletException {
        userService = new UserService();
        quizService = new QuizService();
        submissionService = new SubmissionService();
        attendanceService = new AttendanceService();
        auditService = new AuditService();
        submissionDAO = new SubmissionDAO();
        attendanceDAO = new AttendanceDAO();
        settingsDAO = new SettingsDAO();
        questionDAO = new QuestionDAO();
        apiService = new ApiService();
        gamificationService = new GamificationService();
        userDAO = new UserDAO();
        quizDAO = new QuizDAO();
    }

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        String action = request.getParameter("action");

        // Handle flash messages from POST-Redirect-GET pattern
        if (request.getSession(false) != null) {
            jakarta.servlet.http.HttpSession session = request.getSession(false);
            String flashSuccess = (String) session.getAttribute("flashSuccess");
            String flashError = (String) session.getAttribute("flashError");
            if (flashSuccess != null) {
                request.setAttribute("success", flashSuccess);
                session.removeAttribute("flashSuccess");
            }
            if (flashError != null) {
                request.setAttribute("error", flashError);
                session.removeAttribute("flashError");
            }
        }

        try {
            if ("dashboard".equals(action) || action == null) {
                showDashboard(request, response);
            } else if ("users".equals(action)) {
                listUsers(request, response);
            } else if ("statistics".equals(action)) {
                showStatistics(request, response);
            } else if ("userDetail".equals(action)) {
                showUserDetail(request, response);
            } else if ("failedUserDetail".equals(action)) {
                showFailedUserDetail(request, response);
            } else if ("downloadTemplate".equals(action)) {
                downloadCsvTemplate(request, response);
            } else if ("resetData".equals(action)) {
                showResetDataPage(request, response);
            } else if ("settings".equals(action)) {
                showSettings(request, response);
            } else if ("gamification".equals(action)) {
                showGamification(request, response);
            } else if ("informationBoard".equals(action)) {
                showInformationBoard(request, response);
            } else if ("toggleInformationStatus".equals(action)) {
                toggleInformationStatus(request, response);
            } else if ("deleteInformation".equals(action)) {
                deleteInformation(request, response);
            } else if ("getInformationDetail".equals(action)) {
                getInformationDetail(request, response);
            } else if ("userRetake".equals(action)) {
                showUserRetakePage(request, response);
            } else if ("searchUsers".equals(action)) {
                searchUsers(request, response);
            } else if ("getUserQuizOverview".equals(action)) {
                getUserQuizOverview(request, response);
            } else if ("editScore".equals(action)) {
                showEditScorePage(request, response);
            } else if ("editScoreList".equals(action)) {
                showEditScoreList(request, response);
            } else {
                showDashboard(request, response);
            }
        } catch (Exception e) {
            request.setAttribute("error", "Error: " + e.getMessage());
            request.getRequestDispatcher("/admin/dashboard.jsp").forward(request, response);
        }
    }

    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        jakarta.servlet.http.HttpSession session = request.getSession(false);
        User sessionUser = session != null ? (User) session.getAttribute("user") : null;
        if (sessionUser == null || !sessionUser.isAdmin()) {
            response.sendError(HttpServletResponse.SC_FORBIDDEN, "Access denied");
            return;
        }

        String action = request.getParameter("action");

        try {
            if ("deleteUser".equals(action)) {
                deleteUser(request, response);
            } else if ("createUser".equals(action)) {
                createUser(request, response);
            } else if ("editUser".equals(action)) {
                editUser(request, response);
            } else if ("resetPassword".equals(action)) {
                resetPassword(request, response);
            } else if ("setPin".equals(action)) {
                setPin(request, response);
            } else if ("createTag".equals(action)) {
                createTag(request, response);
            } else if ("deleteTag".equals(action)) {
                deleteTag(request, response);
            } else if ("importUsers".equals(action)) {
                importUsersFromCsv(request, response);
            } else if ("resetQuizData".equals(action)) {
                resetQuizData(request, response);
            } else if ("resetAttendanceData".equals(action)) {
                resetAttendanceData(request, response);
            } else if ("updateSettings".equals(action)) {
                updateSettings(request, response);
            } else if ("updateTranscriptSettings".equals(action)) {
                updateTranscriptSettings(request, response);
            } else if ("updateLeaderboardSettings".equals(action)) {
                updateLeaderboardSettings(request, response);
            } else if ("retakeQuiz".equals(action)) {
                retakeQuiz(request, response);
            } else if ("batchRetakeQuiz".equals(action)) {
                batchRetakeQuiz(request, response);
            } else if ("resetTimeout".equals(action)) {
                resetTimeoutSubmission(request, response);
            } else if ("resetSubmission".equals(action)) {
                resetSubmission(request, response);
            } else if ("generateRetakeCode".equals(action)) {
                generateRetakeCode(request, response);
            } else if ("resetAllTimeout".equals(action)) {
                resetAllTimeoutSubmissions(request, response);
            } else if ("resetMultipleTimeout".equals(action)) {
                resetMultipleTimeoutSubmissions(request, response);
            } else if ("allowRetakeMultiple".equals(action)) {
                allowRetakeMultiple(request, response);
            } else if ("resetMultipleInProgress".equals(action)) {
                resetMultipleInProgressSubmissions(request, response);
            } else if ("addTimeoutSubmission".equals(action)) {
                addTimeoutSubmission(request, response);
            } else if ("createInformation".equals(action)) {
                createInformation(request, response);
            } else if ("updateInformation".equals(action)) {
                updateInformation(request, response);
            } else if ("deleteInformation".equals(action)) {
                deleteInformation(request, response);
            } else if ("toggleInformationStatus".equals(action)) {
                toggleInformationStatus(request, response);
            } else if ("getInformationDetail".equals(action)) {
                getInformationDetail(request, response);
            } else if ("awardPoints".equals(action)) {
                awardPoints(request, response);
            } else if ("toggleAnswer".equals(action)) {
                toggleAnswer(request, response);
            } else if ("overrideScore".equals(action)) {
                overrideScore(request, response);
            } else if ("createManualSubmission".equals(action)) {
                createManualSubmission(request, response);
            } else if ("saveCorrectCount".equals(action)) {
                saveCorrectCount(request, response);
            } else {
                response.sendRedirect("../AdminServlet?action=dashboard");
            }
        } catch (Exception e) {
            request.getSession().setAttribute("flashError", "Error: " + e.getMessage());
            response.sendRedirect(request.getContextPath() + "/AdminServlet?action=users");
        }
    }

    private void deleteUser(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        String ctx = request.getContextPath();
        try {
            String userIdStr = request.getParameter("userId");
            if (userIdStr == null || userIdStr.isEmpty()) {
                request.getSession().setAttribute("flashError", "User ID tidak valid");
                response.sendRedirect(ctx + "/AdminServlet?action=users");
                return;
            }

            Integer userId = Integer.parseInt(userIdStr);

            // Prevent deleting yourself
            User currentUser = (User) request.getSession().getAttribute("user");
            if (currentUser != null && currentUser.getId().equals(userId)) {
                request.getSession().setAttribute("flashError", "Tidak dapat menghapus akun Anda sendiri");
                response.sendRedirect(ctx + "/AdminServlet?action=users");
                return;
            }

            // Get user info before deletion for audit log
            User userToDelete = userService.getUserById(userId);
            String deletedUserName = userToDelete != null ? userToDelete.getEmail() : "Unknown";

            userService.deleteUser(userId);

            // Audit log
            auditService.logDelete("USER", userId, deletedUserName, currentUser, request);

            request.getSession().setAttribute("flashSuccess", "User berhasil dihapus");
            response.sendRedirect(ctx + "/AdminServlet?action=users");

        } catch (NumberFormatException e) {
            request.getSession().setAttribute("flashError", "User ID tidak valid");
            response.sendRedirect(ctx + "/AdminServlet?action=users");
        } catch (Exception e) {
            request.getSession().setAttribute("flashError", "Gagal menghapus user: " + e.getMessage());
            response.sendRedirect(ctx + "/AdminServlet?action=users");
        }
    }

    private void createUser(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        User currentUser = (User) request.getSession().getAttribute("user");
        String ctx = request.getContextPath();
        try {
            String name = request.getParameter("name");
            String email = request.getParameter("email");
            String password = request.getParameter("password");
            String role = request.getParameter("role");
            String tag = request.getParameter("tag");
            String gdriveLink = request.getParameter("gdriveLink");

            if (name == null || name.trim().isEmpty()) {
                request.getSession().setAttribute("flashError", "Nama tidak boleh kosong");
                response.sendRedirect(ctx + "/AdminServlet?action=users");
                return;
            }
            if (email == null || email.trim().isEmpty()) {
                request.getSession().setAttribute("flashError", "Email tidak boleh kosong");
                response.sendRedirect(ctx + "/AdminServlet?action=users");
                return;
            }
            if (password == null || password.trim().isEmpty()) {
                request.getSession().setAttribute("flashError", "Password tidak boleh kosong");
                response.sendRedirect(ctx + "/AdminServlet?action=users");
                return;
            }

            User newUser = userService.register(name.trim(), email.trim(), password, role != null ? role : "peserta", tag, gdriveLink);

            // Audit log
            Map<String, Object> data = new HashMap<>();
            data.put("name", name);
            data.put("email", email);
            data.put("role", role);
            data.put("tag", tag);
            auditService.logCreate("USER", newUser.getId(), email, data, currentUser, request);

            request.getSession().setAttribute("flashSuccess", "User berhasil dibuat");
            response.sendRedirect(ctx + "/AdminServlet?action=users");

        } catch (Exception e) {
            request.getSession().setAttribute("flashError", "Gagal membuat user: " + e.getMessage());
            response.sendRedirect(ctx + "/AdminServlet?action=users");
        }
    }

    private void editUser(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        User currentUser = (User) request.getSession().getAttribute("user");
        String ctx = request.getContextPath();
        try {
            String userIdStr = request.getParameter("userId");
            String name = request.getParameter("name");
            String email = request.getParameter("email");
            String role = request.getParameter("role");
            String tag = request.getParameter("tag");
            String gdriveLink = request.getParameter("gdriveLink");

            if (userIdStr == null || userIdStr.isEmpty()) {
                request.getSession().setAttribute("flashError", "User ID tidak valid");
                response.sendRedirect(ctx + "/AdminServlet?action=users");
                return;
            }

            Integer userId = Integer.parseInt(userIdStr);

            // Update user profile with tag and gdrive link
            userService.updateUserProfile(userId, name, email, role, tag, gdriveLink);

            // Audit log
            Map<String, Object> data = new HashMap<>();
            data.put("name", name);
            data.put("email", email);
            data.put("role", role);
            data.put("tag", tag);
            auditService.logUpdate("USER", userId, email, data, currentUser, request);

            request.getSession().setAttribute("flashSuccess", "User berhasil diupdate");
            response.sendRedirect(ctx + "/AdminServlet?action=users");

        } catch (NumberFormatException e) {
            request.getSession().setAttribute("flashError", "User ID tidak valid");
            response.sendRedirect(ctx + "/AdminServlet?action=users");
        } catch (Exception e) {
            request.getSession().setAttribute("flashError", "Gagal mengupdate user: " + e.getMessage());
            response.sendRedirect(ctx + "/AdminServlet?action=users");
        }
    }

    private void resetPassword(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        User currentUser = (User) request.getSession().getAttribute("user");
        String ctx = request.getContextPath();
        try {
            String userIdStr = request.getParameter("userId");
            String newPassword = request.getParameter("newPassword");

            if (userIdStr == null || userIdStr.isEmpty()) {
                request.getSession().setAttribute("flashError", "User ID tidak valid");
                response.sendRedirect(ctx + "/AdminServlet?action=users");
                return;
            }

            if (newPassword == null || newPassword.length() < 6) {
                request.getSession().setAttribute("flashError", "Password baru minimal 6 karakter");
                response.sendRedirect(ctx + "/AdminServlet?action=users");
                return;
            }

            Integer userId = Integer.parseInt(userIdStr);

            // Get user info for audit
            User targetUser = userService.getUserById(userId);
            String targetEmail = targetUser != null ? targetUser.getEmail() : "Unknown";

            userService.resetPasswordByAdmin(userId, newPassword);

            // Audit log
            auditService.log("UPDATE", "USER", userId, targetEmail + " (password reset)", null, currentUser, request);

            request.getSession().setAttribute("flashSuccess", "Password berhasil direset");
            response.sendRedirect(ctx + "/AdminServlet?action=users");

        } catch (NumberFormatException e) {
            request.getSession().setAttribute("flashError", "User ID tidak valid");
            response.sendRedirect(ctx + "/AdminServlet?action=users");
        } catch (Exception e) {
            request.getSession().setAttribute("flashError", "Gagal mereset password: " + e.getMessage());
            response.sendRedirect(ctx + "/AdminServlet?action=users");
        }
    }

    private void setPin(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        User currentUser = (User) request.getSession().getAttribute("user");
        String ctx = request.getContextPath();
        try {
            Integer userId = Integer.parseInt(request.getParameter("userId"));
            userService.setPinByAdmin(userId, request.getParameter("pin"));

            User targetUser = userService.getUserById(userId);
            String targetEmail = targetUser != null ? targetUser.getEmail() : "Unknown";
            auditService.log("UPDATE", "USER", userId, targetEmail + " (PIN set)", null, currentUser, request);

            request.getSession().setAttribute("flashSuccess", "PIN berhasil disimpan");
        } catch (NumberFormatException e) {
            request.getSession().setAttribute("flashError", "User ID tidak valid");
        } catch (Exception e) {
            request.getSession().setAttribute("flashError", "Gagal menyimpan PIN: " + e.getMessage());
        }
        response.sendRedirect(ctx + "/AdminServlet?action=users");
    }

    private void showDashboard(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        try {
            int totalUsers = userService.countByRole("peserta");
            int totalAdmins = userService.countByRole("admin");
            List<?> quizzes = quizService.getAllQuizzes();
            List<?> submissions = submissionService.getAllSubmissions();

            // Attendance statistics
            int totalAttendanceSessions = 0;
            int activeAttendanceSessions = 0;
            try {
                List<?> attendanceSessions = attendanceService.getAllSessions();
                totalAttendanceSessions = attendanceSessions.size();
                for (Object obj : attendanceSessions) {
                    com.examora.model.AttendanceSession session = (com.examora.model.AttendanceSession) obj;
                    if ("active".equals(session.getStatus())) {
                        activeAttendanceSessions++;
                    }
                }
            } catch (Exception e) {
                // Ignore attendance errors
            }

            request.setAttribute("totalUsers", totalUsers);
            request.setAttribute("totalAdmins", totalAdmins);
            request.setAttribute("totalQuizzes", quizzes.size());
            request.setAttribute("totalSubmissions", submissions.size());
            request.setAttribute("totalAttendanceSessions", totalAttendanceSessions);
            request.setAttribute("activeAttendanceSessions", activeAttendanceSessions);
            request.setAttribute("quizzes", quizzes);
            request.setAttribute("submissions", submissions);

            request.getRequestDispatcher("/admin/dashboard.jsp").forward(request, response);

        } catch (Exception e) {
            throw new ServletException("Error loading dashboard", e);
        }
    }

    private void listUsers(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        try {
            String roleFilter = request.getParameter("role");
            String tagFilter = request.getParameter("tag");

            // Pagination settings
            int pageSize = 50;
            int page = 1;
            try {
                String pageStr = request.getParameter("page");
                if (pageStr != null && !pageStr.isEmpty()) {
                    page = Integer.parseInt(pageStr);
                    if (page < 1) page = 1;
                }
            } catch (NumberFormatException e) {
                page = 1;
            }

            List<User> users;
            int totalUsers;

            if ("admin".equals(roleFilter)) {
                users = userService.getUsersByRolePaginated("admin", page, pageSize);
                totalUsers = userService.countUsersByRole("admin");
            } else if ("peserta".equals(roleFilter)) {
                users = userService.getUsersByRolePaginated("peserta", page, pageSize);
                totalUsers = userService.countUsersByRole("peserta");
            } else if (tagFilter != null && !tagFilter.isEmpty()) {
                users = userService.getUsersByTagPaginated(tagFilter, page, pageSize);
                totalUsers = userService.countUsersByTag(tagFilter);
            } else {
                users = userService.getAllUsersPaginated(page, pageSize);
                totalUsers = userService.countAllUsers();
            }

            // Calculate pagination info
            int totalPages = (int) Math.ceil((double) totalUsers / pageSize);

            // Get all tags for filter dropdown
            List<String> tags = userService.getAllTags();

            // Get all users with Google Drive link for the modal
            List<User> usersWithGdrive = userService.getAllUsersWithGdriveLink();
            int totalGdriveUsers = userService.countUsersWithGdriveLink();

            request.setAttribute("users", users);
            request.setAttribute("roleFilter", roleFilter);
            request.setAttribute("tagFilter", tagFilter);
            request.setAttribute("tags", tags);
            request.setAttribute("currentPage", page);
            request.setAttribute("totalPages", totalPages);
            request.setAttribute("totalUsers", totalUsers);
            request.setAttribute("pageSize", pageSize);
            request.setAttribute("usersWithGdrive", usersWithGdrive);
            request.setAttribute("totalGdriveUsers", totalGdriveUsers);
            request.getRequestDispatcher("/admin/users.jsp").forward(request, response);

        } catch (Exception e) {
            throw new ServletException("Error loading users", e);
        }
    }

    private void showStatistics(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        try {
            String quizIdStr = request.getParameter("quizId");
            Integer quizId = quizIdStr != null && !quizIdStr.isEmpty() ?
                    Integer.parseInt(quizIdStr) : null;

            // Always load quizzes for the dropdown
            request.setAttribute("quizzes", quizService.getAllQuizzes());

            if (quizId != null) {
                try {
                    Map<String, Object> stats = submissionService.getQuizStatistics(quizId);
                    request.setAttribute("statistics", stats);
                    request.setAttribute("selectedQuizId", quizId);

                    // Get detailed submissions list
                    List<Map<String, Object>> submissions = submissionService.getDetailedQuizResults(quizId);
                    request.setAttribute("submissions", submissions);

                    // Get timeout submissions
                    List<Submission> timeoutSubmissions = submissionService.getSubmissionsByQuizAndStatus(quizId, "timeout");
                    request.setAttribute("timeoutSubmissions", timeoutSubmissions);

                    // Get in_progress submissions (include them as failed participants)
                    List<Submission> inProgressSubmissions = submissionService.getSubmissionsByQuizAndStatus(quizId, "in_progress");
                    request.setAttribute("inProgressSubmissions", inProgressSubmissions);

                    // Get users who haven't taken the quiz yet
                    List<Map<String, Object>> notTakenUsers = submissionService.getUsersNotTakenQuiz(quizId);
                    request.setAttribute("notTakenUsers", notTakenUsers);
                } catch (Exception e) {
                    // Log the error but still show the page with an error message
                    e.printStackTrace();
                    request.setAttribute("error", "Gagal memuat statistik: " + e.getMessage());
                }
            }

            request.getRequestDispatcher("/admin/statistics.jsp").forward(request, response);

        } catch (Exception e) {
            e.printStackTrace();
            request.setAttribute("error", "Error loading statistics: " + e.getMessage());
            request.getRequestDispatcher("/admin/statistics.jsp").forward(request, response);
        }
    }

    private void showUserDetail(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        try {
            String submissionIdStr = request.getParameter("submissionId");
            if (submissionIdStr == null || submissionIdStr.isEmpty()) {
                request.setAttribute("error", "Submission ID tidak valid");
                request.getRequestDispatcher("/admin/user-detail.jsp").forward(request, response);
                return;
            }

            Integer submissionId = Integer.parseInt(submissionIdStr);
            Map<String, Object> detail = submissionService.getSubmissionDetail(submissionId);

            if (detail == null) {
                request.setAttribute("error", "Submission tidak ditemukan");
                request.getRequestDispatcher("/admin/user-detail.jsp").forward(request, response);
                return;
            }

            request.setAttribute("detail", detail);
            request.getRequestDispatcher("/admin/user-detail.jsp").forward(request, response);

        } catch (NumberFormatException e) {
            request.setAttribute("error", "Submission ID tidak valid");
            request.getRequestDispatcher("/admin/user-detail.jsp").forward(request, response);
        } catch (Exception e) {
            request.setAttribute("error", "Error loading user detail: " + e.getMessage());
            request.getRequestDispatcher("/admin/user-detail.jsp").forward(request, response);
        }
    }

    /**
     * Show detailed information for a failed user (score < 60)
     * Similar to showUserDetail but with visual indicators for failure
     */
    private void showFailedUserDetail(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        try {
            String submissionIdStr = request.getParameter("submissionId");
            if (submissionIdStr == null || submissionIdStr.isEmpty()) {
                request.setAttribute("error", "Submission ID tidak valid");
                request.getRequestDispatcher("/admin/failed-user-detail.jsp").forward(request, response);
                return;
            }

            Integer submissionId = Integer.parseInt(submissionIdStr);
            Map<String, Object> detail = submissionService.getSubmissionDetail(submissionId);

            if (detail == null) {
                request.setAttribute("error", "Submission tidak ditemukan");
                request.getRequestDispatcher("/admin/failed-user-detail.jsp").forward(request, response);
                return;
            }

            // Verify the user actually failed (score < 60)
            Submission submission = (Submission) detail.get("submission");
            if (submission != null && submission.getScore() >= 60) {
                request.setAttribute("error", "Peserta ini LULUS dengan skor " + submission.getScore());
                request.getRequestDispatcher("/admin/failed-user-detail.jsp").forward(request, response);
                return;
            }

            request.setAttribute("detail", detail);
            request.getRequestDispatcher("/admin/failed-user-detail.jsp").forward(request, response);

        } catch (NumberFormatException e) {
            request.setAttribute("error", "Submission ID tidak valid");
            request.getRequestDispatcher("/admin/failed-user-detail.jsp").forward(request, response);
        } catch (Exception e) {
            request.setAttribute("error", "Error loading failed user detail: " + e.getMessage());
            request.getRequestDispatcher("/admin/failed-user-detail.jsp").forward(request, response);
        }
    }

    /**
     * Show the inline score-editor detail page for a single submission.
     * Mirrors showUserDetail but computes the expectedScore / isOverridden flag
     * so the JSP can show the "SCORE OVERRIDDEN" badge.
     */
    private void showEditScorePage(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        try {
            String submissionIdStr = request.getParameter("submissionId");
            if (submissionIdStr == null || submissionIdStr.isEmpty()) {
                request.setAttribute("error", "Submission ID tidak valid");
                request.getRequestDispatcher("/admin/edit-score.jsp").forward(request, response);
                return;
            }

            Integer submissionId = Integer.parseInt(submissionIdStr);
            Map<String, Object> detail = submissionService.getSubmissionDetail(submissionId);

            if (detail == null) {
                request.setAttribute("error", "Submission tidak ditemukan");
                request.getRequestDispatcher("/admin/edit-score.jsp").forward(request, response);
                return;
            }

            Submission submission = (Submission) detail.get("submission");
            if (submission == null) {
                request.setAttribute("error", "Data submission tidak ditemukan");
                request.getRequestDispatcher("/admin/edit-score.jsp").forward(request, response);
                return;
            }

            if (!submission.isCompleted()) {
                request.setAttribute("error", "Submission belum selesai, tidak dapat mengedit nilai");
                request.getRequestDispatcher("/admin/edit-score.jsp").forward(request, response);
                return;
            }

            int total = submission.getTotalQuestions() != null ? submission.getTotalQuestions() : 0;
            int correct = submission.getCorrectAnswers() != null ? submission.getCorrectAnswers() : 0;
            int divisor = total > 0 ? total : 1;
            double expectedScore = Math.round(correct * 100.0 / divisor * 100.0) / 100.0;
            boolean isOverridden = Math.abs(submission.getScore() - expectedScore) > 0.01;

            request.setAttribute("detail", detail);
            request.setAttribute("expectedScore", expectedScore);
            request.setAttribute("isOverridden", isOverridden);
            request.getRequestDispatcher("/admin/edit-score.jsp").forward(request, response);

        } catch (NumberFormatException e) {
            request.setAttribute("error", "Submission ID tidak valid");
            request.getRequestDispatcher("/admin/edit-score.jsp").forward(request, response);
        } catch (Exception e) {
            request.setAttribute("error", "Error loading edit score page: " + e.getMessage());
            request.getRequestDispatcher("/admin/edit-score.jsp").forward(request, response);
        }
    }

    /**
     * Show the user-centric Edit Nilai page. Lists all participants; the
     * per-user grade modal is populated client-side via getUserQuizOverview.
     * Filtering (search + tag) is done client-side in the JSP.
     */
    private void showEditScoreList(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        try {
            List<User> pesertaUsers = userService.getUsersByRole("peserta");

            List<String> allTags;
            try {
                allTags = userService.getAllTags();
            } catch (Exception e) {
                allTags = new ArrayList<>();
            }

            request.setAttribute("pesertaUsers", pesertaUsers);
            request.setAttribute("allTags", allTags);
            request.getRequestDispatcher("/admin/edit-score-list.jsp").forward(request, response);

        } catch (Exception e) {
            request.setAttribute("error", "Error loading edit score list: " + e.getMessage());
            request.getRequestDispatcher("/admin/edit-score-list.jsp").forward(request, response);
        }
    }

    /**
     * AJAX endpoint: toggle a single answer's is_correct flag and recalculate
     * the submission score. Returns JSON with the new score and audit data.
     */
    private void toggleAnswer(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        User currentUser = (User) request.getSession().getAttribute("user");

        response.setContentType("application/json");
        response.setCharacterEncoding("UTF-8");

        try {
            String submissionIdStr = request.getParameter("submissionId");
            String questionIdStr = request.getParameter("questionId");
            String isCorrectStr = request.getParameter("isCorrect");

            if (submissionIdStr == null || submissionIdStr.isEmpty()) {
                response.getWriter().write("{\"success\":false,\"message\":\"Submission ID tidak valid\"}");
                return;
            }
            if (questionIdStr == null || questionIdStr.isEmpty()) {
                response.getWriter().write("{\"success\":false,\"message\":\"Question ID tidak valid\"}");
                return;
            }
            if (isCorrectStr == null || isCorrectStr.isEmpty()) {
                response.getWriter().write("{\"success\":false,\"message\":\"Status isCorrect tidak valid\"}");
                return;
            }

            Integer submissionId = Integer.parseInt(submissionIdStr);
            Integer questionId = Integer.parseInt(questionIdStr);
            boolean isCorrect = Boolean.parseBoolean(isCorrectStr);

            Map<String, Object> result = submissionService.toggleAnswerCorrectness(submissionId, questionId, isCorrect);

            // Audit log
            Map<String, Object> dataMap = new HashMap<>();
            dataMap.put("oldIsCorrect", result.get("oldIsCorrect"));
            dataMap.put("newIsCorrect", result.get("newIsCorrect"));
            dataMap.put("oldScore", result.get("oldScore"));
            dataMap.put("newScore", result.get("newScore"));
            auditService.log("UPDATE", "ANSWER", questionId,
                    "Toggled answer for submission #" + submissionId, dataMap, currentUser, request);

            JsonObject json = new JsonObject();
            json.addProperty("success", true);
            json.addProperty("message", "Jawaban berhasil diupdate");
            json.addProperty("newScore", (Double) result.get("newScore"));
            json.addProperty("oldScore", (Double) result.get("oldScore"));
            json.addProperty("correctAnswers", (Integer) result.get("newCorrectAnswers"));
            json.addProperty("totalQuestions", (Integer) result.get("totalQuestions"));
            response.getWriter().write(new Gson().toJson(json));

        } catch (NumberFormatException e) {
            response.getWriter().write("{\"success\":false,\"message\":\"ID tidak valid\"}");
        } catch (SubmissionService.ServiceException e) {
            response.getWriter().write("{\"success\":false,\"message\":\"" + escapeJson(e.getMessage()) + "\"}");
        } catch (Exception e) {
            response.getWriter().write("{\"success\":false,\"message\":\"" + escapeJson(e.getMessage()) + "\"}");
        }
    }

    /**
     * AJAX endpoint: override the final score for a submission without
     * modifying the underlying is_correct flags. Returns JSON with old/new score.
     */
    private void overrideScore(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        User currentUser = (User) request.getSession().getAttribute("user");

        response.setContentType("application/json");
        response.setCharacterEncoding("UTF-8");

        try {
            String submissionIdStr = request.getParameter("submissionId");
            String newScoreStr = request.getParameter("newScore");

            if (submissionIdStr == null || submissionIdStr.isEmpty()) {
                response.getWriter().write("{\"success\":false,\"message\":\"Submission ID tidak valid\"}");
                return;
            }
            if (newScoreStr == null || newScoreStr.isEmpty()) {
                response.getWriter().write("{\"success\":false,\"message\":\"Skor tidak boleh kosong\"}");
                return;
            }

            Integer submissionId = Integer.parseInt(submissionIdStr);
            double newScore = Double.parseDouble(newScoreStr);

            if (newScore < 0 || newScore > 100) {
                response.getWriter().write("{\"success\":false,\"message\":\"Skor harus berada di antara 0 dan 100\"}");
                return;
            }

            double oldScore = submissionService.overrideScore(submissionId, newScore);

            // Audit log
            Map<String, Object> dataMap = new HashMap<>();
            dataMap.put("oldScore", oldScore);
            dataMap.put("newScore", newScore);
            auditService.log("UPDATE", "SUBMISSION_SCORE", submissionId,
                    "Score overridden from " + oldScore + " to " + newScore, dataMap, currentUser, request);

            JsonObject json = new JsonObject();
            json.addProperty("success", true);
            json.addProperty("message", "Skor berhasil di-override");
            json.addProperty("oldScore", oldScore);
            json.addProperty("newScore", newScore);
            response.getWriter().write(new Gson().toJson(json));

        } catch (NumberFormatException e) {
            response.getWriter().write("{\"success\":false,\"message\":\"Nilai input tidak valid\"}");
        } catch (SubmissionService.ServiceException e) {
            response.getWriter().write("{\"success\":false,\"message\":\"" + escapeJson(e.getMessage()) + "\"}");
        } catch (Exception e) {
            response.getWriter().write("{\"success\":false,\"message\":\"" + escapeJson(e.getMessage()) + "\"}");
        }
    }

    /**
     * AJAX endpoint: create a manual "completed" submission for a user who
     * never took the quiz. Used by the "Belum Mengerjakan" section so the
     * admin can record an official score (e.g. 0). Returns JSON with the new
     * submission id so the client can redirect to the edit-score page.
     */
    private void createManualSubmission(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        User currentUser = (User) request.getSession().getAttribute("user");

        response.setContentType("application/json");
        response.setCharacterEncoding("UTF-8");

        try {
            String userIdStr = request.getParameter("userId");
            String quizIdStr = request.getParameter("quizId");
            String newScoreStr = request.getParameter("newScore");

            if (userIdStr == null || userIdStr.isEmpty()) {
                response.getWriter().write("{\"success\":false,\"message\":\"User ID tidak valid\"}");
                return;
            }
            if (quizIdStr == null || quizIdStr.isEmpty()) {
                response.getWriter().write("{\"success\":false,\"message\":\"Quiz ID tidak valid\"}");
                return;
            }
            if (newScoreStr == null || newScoreStr.isEmpty()) {
                response.getWriter().write("{\"success\":false,\"message\":\"Skor tidak boleh kosong\"}");
                return;
            }

            Integer userId = Integer.parseInt(userIdStr);
            Integer quizId = Integer.parseInt(quizIdStr);
            double newScore = Double.parseDouble(newScoreStr);

            if (newScore < 0 || newScore > 100) {
                response.getWriter().write("{\"success\":false,\"message\":\"Skor harus berada di antara 0 dan 100\"}");
                return;
            }

            Submission sub = submissionService.createManualSubmission(userId, quizId, newScore);

            // Audit log
            Map<String, Object> dataMap = new HashMap<>();
            dataMap.put("userId", userId);
            dataMap.put("quizId", quizId);
            dataMap.put("score", newScore);
            dataMap.put("totalQuestions", sub.getTotalQuestions());
            auditService.log("CREATE", "SUBMISSION_MANUAL", sub.getId(),
                    "Manual submission created for user #" + userId + " quiz #" + quizId + " with score " + newScore,
                    dataMap, currentUser, request);

            JsonObject json = new JsonObject();
            json.addProperty("success", true);
            json.addProperty("message", "Submission manual berhasil dibuat");
            json.addProperty("submissionId", sub.getId());
            json.addProperty("score", sub.getScore());
            response.getWriter().write(new Gson().toJson(json));

        } catch (NumberFormatException e) {
            response.getWriter().write("{\"success\":false,\"message\":\"Nilai input tidak valid\"}");
        } catch (SubmissionService.ServiceException e) {
            response.getWriter().write("{\"success\":false,\"message\":\"" + escapeJson(e.getMessage()) + "\"}");
        } catch (Exception e) {
            response.getWriter().write("{\"success\":false,\"message\":\"" + escapeJson(e.getMessage()) + "\"}");
        }
    }

    /**
     * AJAX endpoint: save the manual correct-count for a user/quiz pair.
     * Creates or updates the submission and recomputes the score.
     * Returns JSON with the resulting submissionId, score, and counts.
     */
    private void saveCorrectCount(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        User currentUser = (User) request.getSession().getAttribute("user");

        response.setContentType("application/json");
        response.setCharacterEncoding("UTF-8");

        try {
            String userIdStr = request.getParameter("userId");
            String quizIdStr = request.getParameter("quizId");
            String correctCountStr = request.getParameter("correctCount");

            if (userIdStr == null || userIdStr.isEmpty()) {
                response.getWriter().write("{\"success\":false,\"message\":\"User ID tidak valid\"}");
                return;
            }
            if (quizIdStr == null || quizIdStr.isEmpty()) {
                response.getWriter().write("{\"success\":false,\"message\":\"Quiz ID tidak valid\"}");
                return;
            }
            if (correctCountStr == null || correctCountStr.isEmpty()) {
                response.getWriter().write("{\"success\":false,\"message\":\"Jawaban benar tidak boleh kosong\"}");
                return;
            }

            Integer userId = Integer.parseInt(userIdStr);
            Integer quizId = Integer.parseInt(quizIdStr);
            int correctCount = Integer.parseInt(correctCountStr);

            if (correctCount < 0) {
                response.getWriter().write("{\"success\":false,\"message\":\"Jawaban benar tidak valid\"}");
                return;
            }

            // Detect whether this is a create (untaken) or update (taken) by
            // checking for an existing submission before invoking the service.
            Submission existing = submissionDAO.findByUserAndQuiz(userId, quizId);
            boolean created = existing == null;

            Submission sub = submissionService.saveCorrectCount(userId, quizId, correctCount);

            // Audit log
            Map<String, Object> dataMap = new HashMap<>();
            dataMap.put("userId", userId);
            dataMap.put("quizId", quizId);
            dataMap.put("correctCount", correctCount);
            dataMap.put("totalQuestions", sub.getTotalQuestions());
            dataMap.put("score", sub.getScore());
            auditService.log("UPDATE", "SUBMISSION_SCORE", sub.getId(),
                    "Manual correct-count: user #" + userId + " quiz #" + quizId + " correct #" + correctCount,
                    dataMap, currentUser, request);

            JsonObject json = new JsonObject();
            json.addProperty("success", true);
            json.addProperty("message", created ? "Submission berhasil dibuat" : "Skor berhasil diupdate");
            json.addProperty("submissionId", sub.getId());
            json.addProperty("score", sub.getScore());
            json.addProperty("correctAnswers", sub.getCorrectAnswers());
            json.addProperty("totalQuestions", sub.getTotalQuestions());
            json.addProperty("created", created);
            response.getWriter().write(new Gson().toJson(json));

        } catch (NumberFormatException e) {
            response.getWriter().write("{\"success\":false,\"message\":\"Nilai input tidak valid\"}");
        } catch (SubmissionService.ServiceException e) {
            response.getWriter().write("{\"success\":false,\"message\":\"" + escapeJson(e.getMessage()) + "\"}");
        } catch (Exception e) {
            response.getWriter().write("{\"success\":false,\"message\":\"" + escapeJson(e.getMessage()) + "\"}");
        }
    }

    /**
     * Escape a string so it can be embedded inside a JSON string value.
     * (Reuses the existing escapeJson method defined elsewhere in this class.)
     */

    private void createTag(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        response.setContentType("application/json");
        response.setCharacterEncoding("UTF-8");

        try {
            String tagName = request.getParameter("tagName");
            if (tagName == null || tagName.trim().isEmpty()) {
                response.getWriter().write("{\"success\": false, \"error\": \"Nama tag tidak boleh kosong\"}");
                return;
            }

            tagName = tagName.trim();

            // Check if tag already exists
            List<String> existingTags = userService.getAllTags();
            if (existingTags != null && existingTags.contains(tagName)) {
                response.getWriter().write("{\"success\": false, \"error\": \"Tag sudah ada\"}");
                return;
            }

            // Tag will be created when a user is assigned to it
            // For now, we just return success as tags are created on-demand
            response.getWriter().write("{\"success\": true, \"tagName\": \"" + tagName + "\"}");

        } catch (Exception e) {
            response.getWriter().write("{\"success\": false, \"error\": \"" + e.getMessage() + "\"}");
        }
    }

    /**
     * Delete a tag from all users
     */
    private void deleteTag(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        response.setContentType("application/json");
        response.setCharacterEncoding("UTF-8");

        try {
            String tagName = request.getParameter("tagName");
            if (tagName == null || tagName.trim().isEmpty()) {
                response.getWriter().write("{\"success\": false, \"error\": \"Nama tag tidak boleh kosong\"}");
                return;
            }

            tagName = tagName.trim();

            // Remove tag from all users
            int updatedCount = userService.removeTagFromAllUsers(tagName);

            // Log audit (entityId is null because tag doesn't have numeric ID)
            auditService.log("DELETE", "TAG", null, tagName, null, null, null, "SUCCESS", "Removed from " + updatedCount + " users");

            response.getWriter().write("{\"success\": true, \"tagName\": \"" + tagName + "\", \"updatedUsers\": " + updatedCount + "}");

        } catch (Exception e) {
            response.getWriter().write("{\"success\": false, \"error\": \"" + e.getMessage() + "\"}");
        }
    }

    /**
     * Download CSV template for user import
     */
    private void downloadCsvTemplate(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        response.setContentType("text/csv; charset=UTF-8");
        response.setHeader("Content-Disposition", "attachment; filename=\"template_import_user.csv\"");

        PrintWriter writer = response.getWriter();

        // CSV Header
        writer.println("nama,email,password,role,tag,gdriveLink");

        // Sample data rows (3 dummy users)
        writer.println("Ahmad Rizki,ahmad.rizki@email.com,Password123,peserta,TI-2024,");
        writer.println("Siti Nurhaliza,siti.nur@email.com,Password123,peserta,SI-2024,https://drive.google.com/drive/folders/xxx");
        writer.println("Budi Pratama,budi.pratama@email.com,Password123,peserta,TI-2024,");

        writer.flush();
        writer.close();
    }

    /**
     * Import users from CSV file
     */
    private void importUsersFromCsv(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        try {
            Part filePart = request.getPart("csvFile");
            if (filePart == null || filePart.getSize() == 0) {
                request.setAttribute("error", "File CSV tidak ditemukan atau kosong");
                listUsers(request, response);
                return;
            }

            boolean skipHeader = "on".equals(request.getParameter("skipHeader"));
            boolean updateExisting = "on".equals(request.getParameter("updateExisting"));

            List<String[]> users = new ArrayList<>();
            List<String> errors = new ArrayList<>();
            int successCount = 0;
            int updateCount = 0;
            int errorCount = 0;

            // Read CSV file
            try (BufferedReader reader = new BufferedReader(
                    new InputStreamReader(filePart.getInputStream(), StandardCharsets.UTF_8))) {
                String line;
                int lineNumber = 0;

                while ((line = reader.readLine()) != null) {
                    lineNumber++;

                    // Skip header if requested
                    if (skipHeader && lineNumber == 1) {
                        continue;
                    }

                    // Skip empty lines
                    if (line.trim().isEmpty()) {
                        continue;
                    }

                    // Parse CSV line (handle quoted values)
                    String[] fields = parseCsvLine(line);

                    if (fields.length < 3) {
                        errors.add("Baris " + lineNumber + ": Data tidak lengkap (minimal: nama, email, password)");
                        errorCount++;
                        continue;
                    }

                    String name = fields[0].trim();
                    String email = fields[1].trim();
                    String password = fields[2].trim();
                    String role = fields.length > 3 ? fields[3].trim() : "peserta";
                    String tag = fields.length > 4 ? fields[4].trim() : null;
                    String gdriveLink = fields.length > 5 ? fields[5].trim() : null;

                    // Validate data
                    if (name.isEmpty()) {
                        errors.add("Baris " + lineNumber + ": Nama tidak boleh kosong");
                        errorCount++;
                        continue;
                    }
                    if (email.isEmpty()) {
                        errors.add("Baris " + lineNumber + ": Email tidak boleh kosong");
                        errorCount++;
                        continue;
                    }
                    if (password.isEmpty() || password.length() < 6) {
                        errors.add("Baris " + lineNumber + ": Password minimal 6 karakter");
                        errorCount++;
                        continue;
                    }
                    if (!role.equals("admin") && !role.equals("peserta")) {
                        role = "peserta"; // Default to peserta
                    }

                    try {
                        // Check if email already exists
                        User existingUser = userService.findByEmail(email);

                        if (existingUser != null) {
                            if (updateExisting) {
                                // Update existing user
                                userService.updateUserProfile(existingUser.getId(), name, email, role, tag, gdriveLink);
                                userService.resetPasswordByAdmin(existingUser.getId(), password);
                                updateCount++;
                            } else {
                                errors.add("Baris " + lineNumber + ": Email '" + email + "' sudah terdaftar");
                                errorCount++;
                            }
                        } else {
                            // Create new user
                            userService.register(name, email, password, role, tag, gdriveLink);
                            successCount++;
                        }
                    } catch (Exception e) {
                        errors.add("Baris " + lineNumber + ": " + e.getMessage());
                        errorCount++;
                    }
                }
            }

            // Build result message
            StringBuilder resultMsg = new StringBuilder();
            resultMsg.append("Import selesai!<br>");
            resultMsg.append("- Berhasil ditambah: ").append(successCount).append(" user<br>");
            resultMsg.append("- Berhasil diupdate: ").append(updateCount).append(" user<br>");
            resultMsg.append("- Gagal: ").append(errorCount).append(" user");

            if (!errors.isEmpty()) {
                request.setAttribute("importErrors", errors);
            }

            if (errorCount > 0 && successCount == 0 && updateCount == 0) {
                request.setAttribute("error", resultMsg.toString());
            } else {
                request.setAttribute("success", resultMsg.toString());
            }

            listUsers(request, response);

        } catch (Exception e) {
            request.setAttribute("error", "Gagal import: " + e.getMessage());
            listUsers(request, response);
        }
    }

    /**
     * Parse CSV line handling quoted values
     */
    private String[] parseCsvLine(String line) {
        List<String> fields = new ArrayList<>();
        StringBuilder field = new StringBuilder();
        boolean inQuotes = false;

        for (int i = 0; i < line.length(); i++) {
            char c = line.charAt(i);

            if (c == '"') {
                inQuotes = !inQuotes;
            } else if (c == ',' && !inQuotes) {
                fields.add(field.toString());
                field = new StringBuilder();
            } else {
                field.append(c);
            }
        }
        fields.add(field.toString());

        return fields.toArray(new String[0]);
    }

    /**
     * Show reset data page
     */
    private void showResetDataPage(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        try {
            // Get current data counts
            int submissionCount = submissionDAO.countAll();
            int answerCount = submissionDAO.countAllAnswers();
            int attendanceRecordCount = attendanceDAO.countAllRecords();
            int attendanceSessionCount = attendanceDAO.countAllSessions();

            request.setAttribute("submissionCount", submissionCount);
            request.setAttribute("answerCount", answerCount);
            request.setAttribute("attendanceRecordCount", attendanceRecordCount);
            request.setAttribute("attendanceSessionCount", attendanceSessionCount);

            request.getRequestDispatcher("/admin/reset-data.jsp").forward(request, response);
        } catch (Exception e) {
            request.setAttribute("error", "Error loading reset data page: " + e.getMessage());
            request.getRequestDispatcher("/admin/dashboard.jsp").forward(request, response);
        }
    }

    /**
     * Reset quiz data (submissions and answers)
     */
    private void resetQuizData(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        User currentUser = (User) request.getSession().getAttribute("user");

        try {
            String confirmation = request.getParameter("confirmation");

            if (!"RESET QUIZ DATA".equals(confirmation)) {
                request.setAttribute("error", "Konfirmasi tidak valid. Ketik 'RESET QUIZ DATA' untuk mengkonfirmasi.");
                showResetDataPage(request, response);
                return;
            }

            // Delete all answers first (foreign key constraint)
            int answersDeleted = submissionDAO.deleteAllAnswers();
            // Then delete all submissions
            int submissionsDeleted = submissionDAO.deleteAllSubmissions();

            // Audit log
            Map<String, Object> data = new HashMap<>();
            data.put("answersDeleted", answersDeleted);
            data.put("submissionsDeleted", submissionsDeleted);
            auditService.log("DELETE", "SYSTEM", null, "Reset Quiz Data", data, currentUser, request);

            request.setAttribute("success", String.format(
                "Data quiz berhasil direset! Dihapus: %d jawaban, %d submission.",
                answersDeleted, submissionsDeleted
            ));
            showResetDataPage(request, response);

        } catch (Exception e) {
            request.setAttribute("error", "Gagal reset data quiz: " + e.getMessage());
            showResetDataPage(request, response);
        }
    }

    /**
     * Reset attendance data (records and sessions)
     */
    private void resetAttendanceData(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        User currentUser = (User) request.getSession().getAttribute("user");

        try {
            String confirmation = request.getParameter("confirmation");

            if (!"RESET ABSENSI".equals(confirmation)) {
                request.setAttribute("error", "Konfirmasi tidak valid. Ketik 'RESET ABSENSI' untuk mengkonfirmasi.");
                showResetDataPage(request, response);
                return;
            }

            // Delete all records first (foreign key constraint)
            int recordsDeleted = attendanceDAO.deleteAllRecords();
            // Then delete all sessions
            int sessionsDeleted = attendanceDAO.deleteAllSessions();

            // Audit log
            Map<String, Object> data = new HashMap<>();
            data.put("recordsDeleted", recordsDeleted);
            data.put("sessionsDeleted", sessionsDeleted);
            auditService.log("DELETE", "SYSTEM", null, "Reset Attendance Data", data, currentUser, request);

            request.setAttribute("success", String.format(
                "Data absensi berhasil direset! Dihapus: %d record, %d sesi.",
                recordsDeleted, sessionsDeleted
            ));
            showResetDataPage(request, response);

        } catch (Exception e) {
            request.setAttribute("error", "Gagal reset data absensi: " + e.getMessage());
            showResetDataPage(request, response);
        }
    }

    /**
     * Show settings page
     */
    private void showSettings(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        try {
            // Load settings
            Map<String, String> settings = settingsDAO.getAllSettings();
            request.setAttribute("settings", settings);

            // Load reset data counts
            int submissionCount = submissionDAO.countAll();
            int answerCount = submissionDAO.countAllAnswers();
            int attendanceRecordCount = attendanceDAO.countAllRecords();
            int attendanceSessionCount = attendanceDAO.countAllSessions();

            request.setAttribute("submissionCount", submissionCount);
            request.setAttribute("answerCount", answerCount);
            request.setAttribute("attendanceRecordCount", attendanceRecordCount);
            request.setAttribute("attendanceSessionCount", attendanceSessionCount);

            // Distinct peserta tags, for the leaderboard default-tag dropdown
            request.setAttribute("allTags", userDAO.findAllTags());

            request.getRequestDispatcher("/admin/settings.jsp").forward(request, response);
        } catch (Exception e) {
            request.setAttribute("error", "Error loading settings: " + e.getMessage());
            request.getRequestDispatcher("/admin/settings.jsp").forward(request, response);
        }
    }

    /**
     * Show Gamification management page
     */
    private void showGamification(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        try {
            // Get leaderboard
            List<UserPoints> leaderboard = gamificationService.getLeaderboard(100, "all_time");
            // Get recent transactions
            List<PointTransaction> transactions = gamificationService.getRecentTransactions(50);

            request.setAttribute("leaderboard", leaderboard);
            request.setAttribute("transactions", transactions);
            request.getRequestDispatcher("/admin/gamification.jsp").forward(request, response);
        } catch (GamificationService.ServiceException e) {
            request.setAttribute("error", "Error: " + e.getMessage());
            request.getRequestDispatcher("/admin/gamification.jsp").forward(request, response);
        }
    }

    /**
     * Show Information Board page
     */
    private void showInformationBoard(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        try {
            List<InformationBoard> informationList = apiService.getAllInformation();
            request.setAttribute("informationList", informationList);
            request.getRequestDispatcher("/admin/information_board.jsp").forward(request, response);
        } catch (ApiService.ServiceException e) {
            request.setAttribute("error", "Error: " + e.getMessage());
            request.getRequestDispatcher("/admin/information_board.jsp").forward(request, response);
        }
    }

    // ==================== Information Board CRUD Methods ====================

    /**
     * Create new information
     */
    private void createInformation(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        User currentUser = (User) request.getSession().getAttribute("user");
        if (currentUser == null) {
            response.sendRedirect("../common/login.jsp");
            return;
        }

        try {
            String title = request.getParameter("title");
            String content = request.getParameter("content");
            String infoType = request.getParameter("infoType");
            String priority = request.getParameter("priority");
            String targetAudience = request.getParameter("targetAudience");
            String showUntilStr = request.getParameter("showUntil");

            java.time.LocalDateTime showUntil = null;
            if (showUntilStr != null && !showUntilStr.isEmpty()) {
                showUntil = java.time.LocalDateTime.parse(showUntilStr);
            }

            apiService.createInformation(title, content, infoType, priority, targetAudience,
                    currentUser.getId(), showUntil);

            request.setAttribute("success", "Informasi '" + title + "' berhasil dibuat!");
            showInformationBoard(request, response);
        } catch (Exception e) {
            request.setAttribute("error", "Gagal membuat informasi: " + e.getMessage());
            showInformationBoard(request, response);
        }
    }

    /**
     * Update information
     */
    private void updateInformation(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        try {
            Integer id = Integer.parseInt(request.getParameter("id"));
            String title = request.getParameter("title");
            String content = request.getParameter("content");
            String infoType = request.getParameter("infoType");
            String priority = request.getParameter("priority");
            String targetAudience = request.getParameter("targetAudience");
            String isActiveStr = request.getParameter("isActive");
            String showUntilStr = request.getParameter("showUntil");

            Boolean isActive = isActiveStr != null && !isActiveStr.isEmpty();

            java.time.LocalDateTime showUntil = null;
            if (showUntilStr != null && !showUntilStr.isEmpty()) {
                showUntil = java.time.LocalDateTime.parse(showUntilStr);
            }

            apiService.updateInformation(id, title, content, infoType, priority, targetAudience,
                    isActive, showUntil);

            request.setAttribute("success", "Informasi berhasil diupdate!");
            showInformationBoard(request, response);
        } catch (Exception e) {
            request.setAttribute("error", "Gagal mengupdate informasi: " + e.getMessage());
            showInformationBoard(request, response);
        }
    }

    /**
     * Delete information
     */
    private void deleteInformation(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        try {
            Integer id = Integer.parseInt(request.getParameter("id"));
            apiService.deleteInformation(id);
            request.setAttribute("success", "Informasi berhasil dihapus!");
            showInformationBoard(request, response);
        } catch (Exception e) {
            request.setAttribute("error", "Gagal menghapus informasi: " + e.getMessage());
            showInformationBoard(request, response);
        }
    }

    /**
     * Toggle information status
     */
    private void toggleInformationStatus(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        try {
            Integer id = Integer.parseInt(request.getParameter("id"));
            boolean newStatus = apiService.toggleInformationStatus(id);
            request.setAttribute("success", "Status informasi berhasil diubah!");
            showInformationBoard(request, response);
        } catch (Exception e) {
            request.setAttribute("error", "Gagal mengubah status: " + e.getMessage());
            showInformationBoard(request, response);
        }
    }

    /**
     * Get information detail (JSON response)
     */
    private void getInformationDetail(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        try {
            Integer id = Integer.parseInt(request.getParameter("id"));
            InformationBoard info = apiService.getInformation(id);

            response.setContentType("application/json");
            response.setCharacterEncoding("UTF-8");

            // Use Gson for proper JSON serialization
            Gson gson = new Gson();
            JsonObject jsonObject = new JsonObject();
            jsonObject.addProperty("id", info.getId());
            jsonObject.addProperty("title", info.getTitle());
            jsonObject.addProperty("content", info.getContent());
            jsonObject.addProperty("infoType", info.getInfoType());
            jsonObject.addProperty("typeBadge", info.getTypeBadge());
            jsonObject.addProperty("priority", info.getPriority());
            jsonObject.addProperty("priorityBadgeBg", info.getPriorityBadgeBg());
            jsonObject.addProperty("targetAudience", info.getTargetAudience());
            jsonObject.addProperty("targetAudienceDisplay", info.getTargetAudienceDisplay());
            jsonObject.addProperty("isActive", info.getIsActive());
            jsonObject.addProperty("createdAt", info.getCreatedAt().format(java.time.format.DateTimeFormatter.ofPattern("dd MMM yyyy, HH:mm")));
            jsonObject.addProperty("showUntil", info.getShowUntil() != null ?
                info.getShowUntil().format(java.time.format.DateTimeFormatter.ofPattern("dd MMM yyyy, HH:mm")) : "");
            jsonObject.addProperty("creatorName", info.getCreatorName() != null ? info.getCreatorName() : "Admin");

            response.getWriter().write(gson.toJson(jsonObject));
        } catch (Exception e) {
            response.setStatus(HttpServletResponse.SC_INTERNAL_SERVER_ERROR);
            Gson gson = new Gson();
            JsonObject errorObj = new JsonObject();
            errorObj.addProperty("error", e.getMessage());
            response.getWriter().write(gson.toJson(errorObj));
        }
    }

    // ==================== User Retake Methods ====================

    private void showUserRetakePage(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        request.getRequestDispatcher("/admin/user-retake.jsp").forward(request, response);
    }

    private void searchUsers(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        response.setContentType("application/json");
        response.setCharacterEncoding("UTF-8");
        Gson gson = new Gson();

        try {
            String query = request.getParameter("query");
            if (query == null || query.trim().length() < 2) {
                response.getWriter().write("{\"success\":false,\"message\":\"Minimal 2 karakter\"}");
                return;
            }

            List<User> users = userDAO.searchUsers(query.trim());
            List<Map<String, Object>> userList = new ArrayList<>();
            for (User u : users) {
                Map<String, Object> map = new HashMap<>();
                map.put("id", u.getId());
                map.put("name", u.getName());
                map.put("email", u.getEmail());
                map.put("tag", u.getTag());
                userList.add(map);
            }

            Map<String, Object> result = new HashMap<>();
            result.put("success", true);
            result.put("users", userList);
            response.getWriter().write(gson.toJson(result));
        } catch (Exception e) {
            Map<String, Object> error = new HashMap<>();
            error.put("success", false);
            error.put("message", e.getMessage());
            response.getWriter().write(gson.toJson(error));
        }
    }

    private void getUserQuizOverview(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        response.setContentType("application/json");
        response.setCharacterEncoding("UTF-8");
        Gson gson = new Gson();

        try {
            String userIdStr = request.getParameter("userId");
            if (userIdStr == null || userIdStr.isEmpty()) {
                response.getWriter().write("{\"success\":false,\"message\":\"User ID tidak valid\"}");
                return;
            }

            Integer userId = Integer.parseInt(userIdStr);
            User user = userDAO.findById(userId);
            if (user == null) {
                response.getWriter().write("{\"success\":false,\"message\":\"User tidak ditemukan\"}");
                return;
            }

            List<Quiz> allQuizzes = quizDAO.findAll();
            List<Submission> submissions = submissionDAO.findByUserId(userId);

            // Map quizId -> submission
            Map<Integer, Submission> subMap = new HashMap<>();
            for (Submission sub : submissions) {
                if (!subMap.containsKey(sub.getQuizId())) {
                    subMap.put(sub.getQuizId(), sub);
                }
            }

            List<Map<String, Object>> takenQuizzes = new ArrayList<>();
            List<Map<String, Object>> untakenQuizzes = new ArrayList<>();

            for (Quiz quiz : allQuizzes) {
                if (subMap.containsKey(quiz.getId())) {
                    Submission sub = subMap.get(quiz.getId());
                    Map<String, Object> item = new HashMap<>();
                    item.put("quizId", quiz.getId());
                    item.put("quizTitle", quiz.getTitle());
                    item.put("questionCount", quiz.getQuestionCount());
                    item.put("submissionId", sub.getId());
                    item.put("score", sub.getScore());
                    item.put("correctAnswers", sub.getCorrectAnswers());
                    item.put("totalQuestions", sub.getTotalQuestions());
                    item.put("status", sub.getStatus());
                    item.put("submittedAt", sub.getSubmittedAt() != null ?
                        sub.getSubmittedAt().format(java.time.format.DateTimeFormatter.ofPattern("dd MMM yyyy, HH:mm")) : "-");
                    item.put("isRetake", sub.getIsRetake() != null ? sub.getIsRetake() : false);
                    takenQuizzes.add(item);
                } else {
                    Map<String, Object> item = new HashMap<>();
                    item.put("quizId", quiz.getId());
                    item.put("quizTitle", quiz.getTitle());
                    item.put("questionCount", quiz.getQuestionCount());
                    item.put("duration", quiz.getDuration());
                    item.put("isActive", quiz.getIsActive());
                    item.put("deadline", quiz.getDeadline() != null ?
                        quiz.getDeadline().format(java.time.format.DateTimeFormatter.ofPattern("dd MMM yyyy, HH:mm")) : "-");
                    untakenQuizzes.add(item);
                }
            }

            Map<String, Object> userData = new HashMap<>();
            userData.put("id", user.getId());
            userData.put("name", user.getName());
            userData.put("email", user.getEmail());
            userData.put("tag", user.getTag());

            Map<String, Object> result = new HashMap<>();
            result.put("success", true);
            result.put("user", userData);
            result.put("takenQuizzes", takenQuizzes);
            result.put("untakenQuizzes", untakenQuizzes);
            response.getWriter().write(gson.toJson(result));
        } catch (NumberFormatException e) {
            response.getWriter().write("{\"success\":false,\"message\":\"User ID tidak valid\"}");
        } catch (Exception e) {
            Map<String, Object> error = new HashMap<>();
            error.put("success", false);
            error.put("message", e.getMessage());
            response.getWriter().write(gson.toJson(error));
        }
    }

    // ==================== Gamification Methods ====================

    /**
     * Award points to user
     */
    private void awardPoints(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        try {
            Integer userId = Integer.parseInt(request.getParameter("userId"));
            Integer points = Integer.parseInt(request.getParameter("points"));
            String transactionType = request.getParameter("transactionType");
            String description = request.getParameter("description");

            gamificationService.addPoints(userId, points, transactionType, "manual", null, description);

            request.setAttribute("success", "Berhasil memberikan " + points + " poin!");
            showGamification(request, response);
        } catch (Exception e) {
            request.setAttribute("error", "Gagal memberikan poin: " + e.getMessage());
            showGamification(request, response);
        }
    }

    /**
     * Helper method to escape JSON strings
     */
    private String escapeJson(String value) {
        if (value == null) return "";
        return value.replace("\\", "\\\\")
                   .replace("\"", "\\\"")
                   .replace("\n", "\\n")
                   .replace("\r", "\\r")
                   .replace("\t", "\\t");
    }

    /**
     * Update settings
     */
    private void updateSettings(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        User currentUser = (User) request.getSession().getAttribute("user");

        try {
            // Update registration setting
            String regParam = request.getParameter("registrationEnabled");
            String registrationEnabled = ("true".equals(regParam) || "on".equals(regParam)) ? "true" : "false";
            settingsDAO.insertSetting("registration_enabled", registrationEnabled);

            // Update chat setting
            String chatParam = request.getParameter("chatEnabled");
            String chatEnabled = ("true".equals(chatParam) || "on".equals(chatParam)) ? "true" : "false";
            settingsDAO.insertSetting("chat_enabled", chatEnabled);

            // Update file management setting
            String fileMgmtParam = request.getParameter("fileManagementEnabled");
            String fileManagementEnabled = ("true".equals(fileMgmtParam) || "on".equals(fileMgmtParam)) ? "true" : "false";
            settingsDAO.insertSetting("file_management_enabled", fileManagementEnabled);

            // Audit log
            Map<String, Object> data = new HashMap<>();
            data.put("registration_enabled", registrationEnabled);
            data.put("chat_enabled", chatEnabled);
            data.put("file_management_enabled", fileManagementEnabled);
            auditService.log("UPDATE", "SETTINGS", null, "Updated app settings", data, currentUser, request);

            request.setAttribute("success", "Pengaturan berhasil disimpan");
            showSettings(request, response);

        } catch (Exception e) {
            request.setAttribute("error", "Gagal menyimpan pengaturan: " + e.getMessage());
            showSettings(request, response);
        }
    }

    /**
     * Update transcript branding settings (org name, url, signer, signature image).
     */
    private void updateTranscriptSettings(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        User currentUser = (User) request.getSession().getAttribute("user");

        try {
            String orgName = request.getParameter("transcriptOrgName");
            String orgUrl = request.getParameter("transcriptOrgUrl");
            String signerName = request.getParameter("transcriptSignerName");
            String signerTitle = request.getParameter("transcriptSignerTitle");
            String removeSig = request.getParameter("removeSignature");

            settingsDAO.insertSetting("transcript_org_name", orgName != null ? orgName.trim() : "");
            settingsDAO.insertSetting("transcript_org_url", orgUrl != null ? orgUrl.trim() : "");
            settingsDAO.insertSetting("transcript_signer_name", signerName != null ? signerName.trim() : "");
            settingsDAO.insertSetting("transcript_signer_title", signerTitle != null ? signerTitle.trim() : "");

            // Handle signature image
            String currentSig = settingsDAO.getSetting("transcript_signature_path");
            if ("true".equals(removeSig)) {
                settingsDAO.insertSetting("transcript_signature_path", "");
            } else {
                Part sigPart = null;
                try {
                    sigPart = request.getPart("transcriptSignature");
                } catch (Exception ignored) {
                    // No file part or not multipart — ignore
                }
                if (sigPart != null && sigPart.getSize() > 0) {
                    String savedPath = saveSignatureImage(sigPart);
                    settingsDAO.insertSetting("transcript_signature_path", savedPath);
                }
            }

            // Audit log
            Map<String, Object> data = new HashMap<>();
            data.put("transcript_org_name", orgName);
            data.put("transcript_org_url", orgUrl);
            data.put("transcript_signer_name", signerName);
            if (auditService != null) {
                auditService.log("UPDATE", "TRANSCRIPT_SETTINGS", null, "Updated transcript branding settings", data, currentUser, request);
            }

            request.setAttribute("success", "Pengaturan transkrip berhasil disimpan");
            showSettings(request, response);

        } catch (Exception e) {
            request.setAttribute("error", "Gagal menyimpan pengaturan transkrip: " + e.getMessage());
            showSettings(request, response);
        }
    }

    /**
     * Update leaderboard settings (CSV URL + default tag filter + publish state).
     */
    private void updateLeaderboardSettings(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        String csvUrl = request.getParameter("leaderboardCsvUrl");
        if (csvUrl != null) {
            csvUrl = csvUrl.trim();
        }
        String defaultTag = request.getParameter("leaderboardDefaultTag");
        if (defaultTag != null) {
            defaultTag = defaultTag.trim();
        }
        String published = request.getParameter("leaderboardPublished");

        try {
            if (csvUrl != null && !csvUrl.isEmpty()) {
                settingsDAO.insertSetting("leaderboard_csv_url", csvUrl);
            }
            // Persist the default tag. "all" / empty means no default filter.
            settingsDAO.insertSetting("leaderboard_default_tag",
                    (defaultTag == null || "all".equalsIgnoreCase(defaultTag)) ? "" : defaultTag);

            // Persist the publish flag. The checkbox/param is only sent when
            // checked, so absence means "false".
            boolean isPublished = "true".equalsIgnoreCase(published);
            settingsDAO.insertSetting("leaderboard_published", isPublished ? "true" : "false");
            // Update application scope so nav bars reflect the change immediately.
            getServletContext().setAttribute("leaderboardPublished", isPublished);

            // Force-clear the in-memory leaderboard cache so the new URL/tag
            // is reflected on the next page load instead of waiting for TTL.
            LeaderboardServlet.clearCache();

            request.setAttribute("success", isPublished
                    ? "Leaderboard berhasil dipublikasi dan kini terlihat oleh peserta."
                    : "Leaderboard berhasil di-unpublish dan kini disembunyikan dari peserta.");
        } catch (Exception e) {
            request.setAttribute("error", "Gagal menyimpan pengaturan leaderboard: " + e.getMessage());
        }
        showSettings(request, response);
    }

    // Signature upload constants (mirrors QuestionServlet pattern, dedicated subdir)
    private static final String SIG_UPLOAD_BASE_DIR = "/app/uploads";
    private static final String SIG_UPLOAD_SUBDIR = "signatures";
    private static final String SIG_WEB_PATH_PREFIX = "uploads/signatures";
    private static final long SIG_MAX_FILE_SIZE = 2 * 1024 * 1024;
    private static final Set<String> SIG_ALLOWED_MIME = new HashSet<>(Arrays.asList(
        "image/jpeg", "image/png", "image/gif", "image/webp"
    ));
    private static final Set<String> SIG_ALLOWED_EXT = new HashSet<>(Arrays.asList(
        ".jpg", ".jpeg", ".png", ".gif", ".webp"
    ));

    /**
     * Validate and save the uploaded signature image. Returns the web-accessible path.
     */
    private String saveSignatureImage(Part sigPart) throws IOException {
        if (sigPart.getSize() > SIG_MAX_FILE_SIZE) {
            throw new IOException("Ukuran tanda tangan terlalu besar. Maksimal 2MB.");
        }
        String contentType = sigPart.getContentType();
        if (contentType == null || !SIG_ALLOWED_MIME.contains(contentType.toLowerCase())) {
            throw new IOException("Tipe file tidak didukung. Gunakan JPG, PNG, GIF, atau WebP.");
        }
        String originalFileName = getSubmittedFileName(sigPart);
        String extension = "";
        if (originalFileName != null && originalFileName.contains(".")) {
            extension = originalFileName.substring(originalFileName.lastIndexOf(".")).toLowerCase();
        }
        if (!SIG_ALLOWED_EXT.contains(extension)) {
            throw new IOException("Ekstensi file tidak didukung. Gunakan .jpg, .jpeg, .png, .gif, atau .webp");
        }
        // Validate actual image content
        try (InputStream input = sigPart.getInputStream()) {
            BufferedImage image = ImageIO.read(input);
            if (image == null) {
                throw new IOException("File bukan gambar yang valid atau file rusak.");
            }
            int width = image.getWidth();
            int height = image.getHeight();
            if (width <= 0 || height <= 0 || width > 10000 || height > 10000) {
                throw new IOException("Dimensi gambar tidak valid.");
            }
        }
        Path uploadPath = Paths.get(SIG_UPLOAD_BASE_DIR, SIG_UPLOAD_SUBDIR);
        if (!Files.exists(uploadPath)) {
            Files.createDirectories(uploadPath);
        }
        String safeFileName = UUID.randomUUID().toString() + extension;
        try (InputStream input = sigPart.getInputStream()) {
            Files.copy(input, uploadPath.resolve(safeFileName), StandardCopyOption.REPLACE_EXISTING);
        }
        return SIG_WEB_PATH_PREFIX + "/" + safeFileName;
    }

    private String getSubmittedFileName(Part part) {
        String contentDisp = part.getHeader("content-disposition");
        if (contentDisp == null) return "";
        for (String s : contentDisp.split(";")) {
            s = s.trim();
            if (s.toLowerCase().startsWith("filename")) {
                int idx = s.indexOf("=");
                if (idx >= 0) {
                    String name = s.substring(idx + 1).trim();
                    if (name.startsWith("\"") && name.endsWith("\"")) {
                        name = name.substring(1, name.length() - 1);
                    }
                    name = Paths.get(name).getFileName().toString();
                    return name;
                }
            }
        }
        return "";
    }

    /**
     * Allow single user to retake a quiz
     */
    private void retakeQuiz(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        User currentUser = (User) request.getSession().getAttribute("user");

        response.setContentType("application/json");
        response.setCharacterEncoding("UTF-8");

        try {
            String submissionIdStr = request.getParameter("submissionId");
            if (submissionIdStr == null || submissionIdStr.isEmpty()) {
                response.getWriter().write("{\"success\":false,\"error\":\"Submission ID tidak valid\"}");
                return;
            }

            Integer submissionId = Integer.parseInt(submissionIdStr);

            // Delete the submission (this will also delete answers)
            boolean deleted = submissionDAO.deleteSubmission(submissionId);

            if (deleted) {
                // Audit log
                auditService.log("DELETE", "SUBMISSION", submissionId, "Quiz retake allowed", null, currentUser, request);
                response.getWriter().write("{\"success\":true,\"message\":\"Retake berhasil diizinkan\"}");
            } else {
                response.getWriter().write("{\"success\":false,\"error\":\"Gagal menghapus submission\"}");
            }

        } catch (NumberFormatException e) {
            response.getWriter().write("{\"success\":false,\"error\":\"Submission ID tidak valid\"}");
        } catch (Exception e) {
            response.getWriter().write("{\"success\":false,\"error\":\"" + e.getMessage().replace("\"", "'") + "\"}");
        }
    }

    /**
     * Allow multiple users to retake a quiz (batch)
     */
    private void batchRetakeQuiz(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        User currentUser = (User) request.getSession().getAttribute("user");

        response.setContentType("application/json");
        response.setCharacterEncoding("UTF-8");

        try {
            String[] submissionIdsStr = request.getParameterValues("submissionIds");
            if (submissionIdsStr == null || submissionIdsStr.length == 0) {
                response.getWriter().write("{\"success\":false,\"error\":\"Tidak ada submission dipilih\"}");
                return;
            }

            List<Integer> submissionIds = new ArrayList<>();
            for (String idStr : submissionIdsStr) {
                submissionIds.add(Integer.parseInt(idStr));
            }

            int deletedCount = submissionDAO.batchDeleteForRetake(submissionIds);

            // Audit log
            Map<String, Object> data = new HashMap<>();
            data.put("count", deletedCount);
            auditService.log("DELETE", "SUBMISSION_BATCH", null, "Batch quiz retake allowed", data, currentUser, request);

            response.getWriter().write("{\"success\":true,\"message\":\"Berhasil mengizinkan retake untuk " + deletedCount + " peserta\",\"deletedCount\":" + deletedCount + "}");

        } catch (Exception e) {
            response.getWriter().write("{\"success\":false,\"error\":\"" + e.getMessage().replace("\"", "'") + "\"}");
        }
    }

    private void resetTimeoutSubmission(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        User currentUser = (User) request.getSession().getAttribute("user");

        response.setContentType("application/json");
        response.setCharacterEncoding("UTF-8");

        try {
            String submissionIdStr = request.getParameter("submissionId");
            String quizIdStr = request.getParameter("quizId");

            if (submissionIdStr == null || submissionIdStr.isEmpty()) {
                response.getWriter().write("{\"success\":false,\"message\":\"Submission ID tidak valid\"}");
                return;
            }
            if (quizIdStr == null || quizIdStr.isEmpty()) {
                response.getWriter().write("{\"success\":false,\"message\":\"Quiz ID tidak valid\"}");
                return;
            }

            Integer submissionId = Integer.parseInt(submissionIdStr);
            Integer quizId = Integer.parseInt(quizIdStr);

            // Delete timeout submission
            boolean deleted = submissionDAO.deleteTimeoutSubmission(submissionId, quizId);

            if (deleted) {
                // Audit log
                auditService.log("DELETE", "SUBMISSION_TIMEOUT", submissionId, "Timeout submission reset for retake", null, currentUser, request);
                response.getWriter().write("{\"success\":true,\"message\":\"Submission timeout berhasil direset\"}");
            } else {
                response.getWriter().write("{\"success\":false,\"message\":\"Gagal mereset submission\"}");
            }

        } catch (NumberFormatException e) {
            response.getWriter().write("{\"success\":false,\"message\":\"ID tidak valid\"}");
        } catch (Exception e) {
            response.getWriter().write("{\"success\":false,\"message\":\"" + e.getMessage().replace("\"", "'") + "\"}");
        }
    }

    private void resetSubmission(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        User currentUser = (User) request.getSession().getAttribute("user");

        response.setContentType("application/json");
        response.setCharacterEncoding("UTF-8");

        try {
            String submissionIdStr = request.getParameter("submissionId");
            String quizIdStr = request.getParameter("quizId");

            if (submissionIdStr == null || submissionIdStr.isEmpty()) {
                response.getWriter().write("{\"success\":false,\"message\":\"Submission ID tidak valid\"}");
                return;
            }
            if (quizIdStr == null || quizIdStr.isEmpty()) {
                response.getWriter().write("{\"success\":false,\"message\":\"Quiz ID tidak valid\"}");
                return;
            }

            Integer submissionId = Integer.parseInt(submissionIdStr);
            Integer quizId = Integer.parseInt(quizIdStr);

            // Delete submission (works for both timeout and completed)
            boolean deleted = submissionDAO.deleteSubmissionById(submissionId, quizId);

            if (deleted) {
                // Audit log
                auditService.log("DELETE", "SUBMISSION", submissionId, "Submission reset for retake by admin", null, currentUser, request);
                response.getWriter().write("{\"success\":true,\"message\":\"Submission berhasil direset. Peserta sekarang dapat mengerjakan quiz kembali.\"}");
            } else {
                response.getWriter().write("{\"success\":false,\"message\":\"Gagal mereset submission\"}");
            }

        } catch (NumberFormatException e) {
            response.getWriter().write("{\"success\":false,\"message\":\"ID tidak valid\"}");
        } catch (Exception e) {
            response.getWriter().write("{\"success\":false,\"message\":\"" + e.getMessage().replace("\"", "'") + "\"}");
        }
    }

    private void generateRetakeCode(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        User currentUser = (User) request.getSession().getAttribute("user");

        response.setContentType("application/json");
        response.setCharacterEncoding("UTF-8");

        try {
            String userIdStr = request.getParameter("userId");
            String quizIdStr = request.getParameter("quizId");
            String validityHoursStr = request.getParameter("validityHours");

            if (userIdStr == null || userIdStr.isEmpty()) {
                response.getWriter().write("{\"success\":false,\"message\":\"User ID tidak valid\"}");
                return;
            }
            if (quizIdStr == null || quizIdStr.isEmpty()) {
                response.getWriter().write("{\"success\":false,\"message\":\"Quiz ID tidak valid\"}");
                return;
            }

            Integer userId = Integer.parseInt(userIdStr);
            Integer quizId = Integer.parseInt(quizIdStr);
            Integer validityHours = validityHoursStr != null && !validityHoursStr.isEmpty() ?
                Integer.parseInt(validityHoursStr) : null;

            RetakeCodeService retakeCodeService = new RetakeCodeService();
            RetakeCode retakeCode = retakeCodeService.generateRetakeCode(
                quizId, userId, currentUser.getId(), validityHours);

            // Audit log
            Map<String, Object> data = new HashMap<>();
            data.put("quizId", quizId);
            data.put("userId", userId);
            data.put("retakeCode", retakeCode.getRetakeCode());
            data.put("validityHours", validityHours);
            auditService.log("CREATE", "RETAKE_CODE", quizId,
                    "Admin generated retake code: " + retakeCode.getRetakeCode(), data, currentUser, request);

            response.getWriter().write("{\"success\":true,\"retakeCode\":\"" +
                retakeCode.getRetakeCode() + "\",\"message\":\"Kode retake berhasil dibuat\"}");

        } catch (NumberFormatException e) {
            response.getWriter().write("{\"success\":false,\"message\":\"ID tidak valid\"}");
        } catch (Exception e) {
            response.getWriter().write("{\"success\":false,\"message\":\"" +
                e.getMessage().replace("\"", "'") + "\"}");
        }
    }

    private void resetAllTimeoutSubmissions(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        User currentUser = (User) request.getSession().getAttribute("user");

        response.setContentType("application/json");
        response.setCharacterEncoding("UTF-8");

        try {
            String quizIdStr = request.getParameter("quizId");

            if (quizIdStr == null || quizIdStr.isEmpty()) {
                response.getWriter().write("{\"success\":false,\"message\":\"Quiz ID tidak valid\"}");
                return;
            }

            Integer quizId = Integer.parseInt(quizIdStr);

            // Delete all timeout submissions for this quiz
            int count = submissionDAO.deleteTimeoutSubmissions(quizId);

            // Audit log
            Map<String, Object> data = new HashMap<>();
            data.put("quizId", quizId);
            data.put("count", count);
            auditService.log("DELETE", "SUBMISSION_TIMEOUT_ALL", quizId, "All timeout submissions reset for quiz", data, currentUser, request);

            response.getWriter().write("{\"success\":true,\"message\":\"Semua submission timeout berhasil direset\",\"count\":" + count + "}");

        } catch (NumberFormatException e) {
            response.getWriter().write("{\"success\":false,\"message\":\"Quiz ID tidak valid\"}");
        } catch (Exception e) {
            response.getWriter().write("{\"success\":false,\"message\":\"" + e.getMessage().replace("\"", "'") + "\"}");
        }
    }

    /**
     * Reset multiple selected timeout submissions
     */
    private void resetMultipleTimeoutSubmissions(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        User currentUser = (User) request.getSession().getAttribute("user");

        response.setContentType("application/json");
        response.setCharacterEncoding("UTF-8");

        try {
            String submissionIdsStr = request.getParameter("submissionIds");

            if (submissionIdsStr == null || submissionIdsStr.isEmpty()) {
                response.getWriter().write("{\"success\":false,\"message\":\"Submission IDs tidak valid\"}");
                return;
            }

            String[] submissionIdArray = submissionIdsStr.split(",");
            int count = 0;

            for (String submissionIdStr : submissionIdArray) {
                try {
                    Integer submissionId = Integer.parseInt(submissionIdStr.trim());
                    boolean deleted = submissionDAO.deleteSubmission(submissionId);
                    if (deleted) count++;
                } catch (NumberFormatException e) {
                    // Skip invalid IDs
                }
            }

            // Audit log
            Map<String, Object> data = new HashMap<>();
            data.put("count", count);
            data.put("submissionIds", submissionIdsStr);
            auditService.log("DELETE", "SUBMISSION_TIMEOUT_MULTIPLE", null, "Multiple timeout submissions reset", data, currentUser, request);

            response.getWriter().write("{\"success\":true,\"message\":\"" + count + " submission timeout berhasil direset\",\"count\":" + count + "}");

        } catch (Exception e) {
            response.getWriter().write("{\"success\":false,\"message\":\"" + e.getMessage().replace("\"", "'") + "\"}");
        }
    }

    /**
     * Allow retake for multiple users who haven't taken the quiz
     */
    private void allowRetakeMultiple(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        User currentUser = (User) request.getSession().getAttribute("user");

        response.setContentType("application/json");
        response.setCharacterEncoding("UTF-8");

        try {
            String userIdsStr = request.getParameter("userIds");
            String quizIdStr = request.getParameter("quizId");

            if (userIdsStr == null || userIdsStr.isEmpty()) {
                response.getWriter().write("{\"success\":false,\"message\":\"User IDs tidak valid\"}");
                return;
            }

            if (quizIdStr == null || quizIdStr.isEmpty()) {
                response.getWriter().write("{\"success\":false,\"message\":\"Quiz ID tidak valid\"}");
                return;
            }

            Integer quizId = Integer.parseInt(quizIdStr);
            String[] userIdArray = userIdsStr.split(",");
            int count = 0;

            // For users who haven't taken the quiz, we just need to ensure they're not blocked
            // The actual retake allowance is implicit - they just need to not have a submission
            // This function is mainly for audit logging purposes since these users haven't taken the quiz yet

            // Audit log
            Map<String, Object> data = new HashMap<>();
            data.put("quizId", quizId);
            data.put("count", userIdArray.length);
            data.put("userIds", userIdsStr);
            auditService.log("UPDATE", "QUIZ_RETAKES_ALLOWED", quizId, "Multiple users allowed to retake quiz", data, currentUser, request);

            response.getWriter().write("{\"success\":true,\"message\":\"" + userIdArray.length + " peserta diizinkan untuk mengerjakan quiz\",\"count\":" + userIdArray.length + "}");

        } catch (NumberFormatException e) {
            response.getWriter().write("{\"success\":false,\"message\":\"ID tidak valid\"}");
        } catch (Exception e) {
            response.getWriter().write("{\"success\":false,\"message\":\"" + e.getMessage().replace("\"", "'") + "\"}");
        }
    }

    /**
     * Reset multiple in-progress submissions
     */
    private void resetMultipleInProgressSubmissions(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        User currentUser = (User) request.getSession().getAttribute("user");

        response.setContentType("application/json");
        response.setCharacterEncoding("UTF-8");

        try {
            String submissionIdsStr = request.getParameter("submissionIds");

            if (submissionIdsStr == null || submissionIdsStr.isEmpty()) {
                response.getWriter().write("{\"success\":false,\"message\":\"Submission IDs tidak valid\"}");
                return;
            }

            String[] submissionIdArray = submissionIdsStr.split(",");
            int count = 0;

            for (String submissionIdStr : submissionIdArray) {
                try {
                    Integer submissionId = Integer.parseInt(submissionIdStr.trim());
                    boolean deleted = submissionDAO.deleteSubmission(submissionId);
                    if (deleted) count++;
                } catch (NumberFormatException e) {
                    // Skip invalid IDs
                }
            }

            // Audit log
            Map<String, Object> data = new HashMap<>();
            data.put("count", count);
            data.put("submissionIds", submissionIdsStr);
            auditService.log("DELETE", "SUBMISSION_IN_PROGRESS_MULTIPLE", null, "Multiple in-progress submissions reset", data, currentUser, request);

            response.getWriter().write("{\"success\":true,\"message\":\"" + count + " submission in-progress berhasil direset\",\"count\":" + count + "}");

        } catch (Exception e) {
            response.getWriter().write("{\"success\":false,\"message\":\"" + e.getMessage().replace("\"", "'") + "\"}");
        }
    }

    /**
     * Add a timeout submission manually (for control purposes - requires manual reset before retake)
     */
    private void addTimeoutSubmission(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        User currentUser = (User) request.getSession().getAttribute("user");

        response.setContentType("application/json");
        response.setCharacterEncoding("UTF-8");

        try {
            String userIdStr = request.getParameter("userId");
            String quizIdStr = request.getParameter("quizId");

            if (userIdStr == null || userIdStr.isEmpty()) {
                response.getWriter().write("{\"success\":false,\"message\":\"User ID tidak valid\"}");
                return;
            }
            if (quizIdStr == null || quizIdStr.isEmpty()) {
                response.getWriter().write("{\"success\":false,\"message\":\"Quiz ID tidak valid\"}");
                return;
            }

            Integer userId = Integer.parseInt(userIdStr);
            Integer quizId = Integer.parseInt(quizIdStr);

            // Check if user already has a submission for this quiz
            Submission existing = submissionDAO.findByUserAndQuiz(userId, quizId);
            if (existing != null) {
                response.getWriter().write("{\"success\":false,\"message\":\"User sudah memiliki submission untuk quiz ini\"}");
                return;
            }

            // Create timeout submission
            Submission timeoutSub = new Submission();
            timeoutSub.setQuizId(quizId);
            timeoutSub.setUserId(userId);
            timeoutSub.setScore(0.0);
            timeoutSub.setTotalQuestions(0);
            timeoutSub.setCorrectAnswers(0);
            timeoutSub.setStartedAt(LocalDateTime.now());
            timeoutSub.setStatus("timeout");

            submissionDAO.create(timeoutSub);

            // Audit log
            Map<String, Object> data = new HashMap<>();
            data.put("quizId", quizId);
            data.put("userId", userId);
            auditService.log("CREATE", "SUBMISSION_TIMEOUT", timeoutSub.getId(), "Manual timeout submission created - requires reset before retake", data, currentUser, request);

            response.getWriter().write("{\"success\":true,\"message\":\"Timeout submission berhasil ditambahkan. User perlu di-reset manual sebelum bisa retake.\"}");

        } catch (NumberFormatException e) {
            response.getWriter().write("{\"success\":false,\"message\":\"ID tidak valid\"}");
        } catch (Exception e) {
            response.getWriter().write("{\"success\":false,\"message\":\"" + e.getMessage().replace("\"", "'") + "\"}");
        }
    }

    /**
     * Convert list to JSON string (improved implementation)
     */
    private String toJson(List<Map<String, Object>> list) {
        try {
            StringBuilder sb = new StringBuilder("[");
            for (int i = 0; i < list.size(); i++) {
                if (i > 0) sb.append(",");
                sb.append(toJsonObject(list.get(i)));
            }
            sb.append("]");
            return sb.toString();
        } catch (Exception e) {
            System.err.println("Error converting to JSON: " + e.getMessage());
            return "[]";
        }
    }

    /**
     * Convert map to JSON object string (improved implementation)
     */
    private String toJsonObject(Map<String, Object> map) {
        StringBuilder sb = new StringBuilder("{");
        boolean first = true;
        for (Map.Entry<String, Object> entry : map.entrySet()) {
            if (!first) sb.append(",");
            first = false;
            sb.append("\"").append(entry.getKey()).append("\":");

            Object value = entry.getValue();
            if (value instanceof String) {
                String escapedValue = escapeJsonString((String) value);
                sb.append("\"").append(escapedValue).append("\"");
            } else if (value instanceof List) {
                sb.append("[");
                List<?> list = (List<?>) value;
                for (int i = 0; i < list.size(); i++) {
                    if (i > 0) sb.append(",");
                    sb.append("\"").append(escapeJsonString(list.get(i).toString())).append("\"");
                }
                sb.append("]");
            } else {
                String escapedValue = escapeJsonString(value.toString());
                sb.append("\"").append(escapedValue).append("\"");
            }
        }
        sb.append("}");
        return sb.toString();
    }

    /**
     * Escape string for JSON (handles all special characters properly)
     */
    private String escapeJsonString(String str) {
        if (str == null) return "";

        StringBuilder result = new StringBuilder();
        for (int i = 0; i < str.length(); i++) {
            char c = str.charAt(i);
            switch (c) {
                case '\\':
                    result.append("\\\\");  // 2 backslashes -> 1 escaped backslash in JSON
                    break;
                case '"':
                    result.append("\\\"");    // 2 backslashes -> backslash + quote in output
                    break;
                case '\b':
                    result.append("\\b");
                    break;
                case '\f':
                    result.append("\\f");
                    break;
                case '\n':
                    result.append("\\n");
                    break;
                case '\r':
                    result.append("\\r");
                    break;
                case '\t':
                    result.append("\\t");
                    break;
                case '/':
                    result.append("\\/");
                    break;
                default:
                    result.append(c);
                    break;
            }
        }
        return result.toString();
    }

    /**
     * Parse JSON string to list (simple implementation)
     */
    private List<Map<String, Object>> parseJsonToList(String json) {
        List<Map<String, Object>> result = new ArrayList<>();
        // This is a simplified implementation
        // In production, use a proper JSON library like Jackson or Gson
        try {
            // Remove outer brackets and split by objects
            json = json.trim();
            if (json.startsWith("[")) {
                json = json.substring(1, json.length() - 1);
            }

            // Simple parsing - for production use proper JSON library
            String[] parts = json.split("\\},\\s*\\{");
            for (int i = 0; i < parts.length; i++) {
                String part = parts[i];
                if (!part.startsWith("{")) part = "{" + part;
                if (!part.endsWith("}")) part = part + "}";
                result.add(parseJsonToMap(part));
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
        return result;
    }

    /**
     * Parse JSON string to map (simple implementation)
     */
    private Map<String, Object> parseJsonToMap(String json) {
        Map<String, Object> result = new HashMap<>();
        json = json.trim();
        if (json.startsWith("{")) json = json.substring(1, json.length() - 1);

        // Simple parsing - for production use proper JSON library
        String[] pairs = json.split(",\\s*");
        for (String pair : pairs) {
            String[] kv = pair.split(":\\s*", 2);
            if (kv.length == 2) {
                String key = kv[0].trim().replaceAll("^\"|\"$", "");
                String value = kv[1].trim();

                if (value.startsWith("[") && value.endsWith("]")) {
                    // Array
                    List<String> list = new ArrayList<>();
                    String[] items = value.substring(1, value.length() - 1).split(",\\s*");
                    for (String item : items) {
                        if (!item.trim().isEmpty()) {
                            list.add(item.trim().replaceAll("^\"|\"$", ""));
                        }
                    }
                    result.put(key, list);
                } else {
                    // String
                    result.put(key, value.replaceAll("^\"|\"$", ""));
                }
            }
        }
        return result;
    }
}
