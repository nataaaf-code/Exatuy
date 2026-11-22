package com.examora.controller;

import com.examora.dao.QuizParticipantDAO;
import com.examora.dao.SubmissionDAO;
import com.examora.dao.InformationBoardDAO;
import com.examora.dao.CustomPageDAO;
import com.examora.dao.QuizExemptionDAO;
import com.examora.dao.RetakeCodeDAO;
import com.examora.model.RetakeCode;
import com.examora.model.Answer;
import com.examora.model.Question;
import com.examora.model.Quiz;
import com.examora.model.Submission;
import com.examora.model.User;
import com.examora.model.InformationBoard;
import com.examora.model.CustomPage;
import com.examora.service.QuizService;
import com.examora.service.SubmissionService;
import com.examora.service.UserService;
import com.examora.service.RetakeCodeService;
import com.examora.service.AuditService;
import com.examora.service.QuotaService;
import com.examora.model.RetakeCode;

import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.sql.SQLException;
import java.time.Duration;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * Exam Servlet - Handles exam taking for participants
 */
@WebServlet("/ExamServlet")
public class ExamServlet extends HttpServlet {
    private QuizService quizService;
    private SubmissionService submissionService;
    private UserService userService;
    private QuizParticipantDAO quizParticipantDAO;
    private SubmissionDAO submissionDAO;
    private AuditService auditService;
    private InformationBoardDAO informationBoardDAO;
    private CustomPageDAO customPageDAO;
    private QuizExemptionDAO quizExemptionDAO;
    private RetakeCodeDAO retakeCodeDAO;
    private QuotaService quotaService;

    @Override
    public void init() throws ServletException {
        quizService = new QuizService();
        submissionService = new SubmissionService();
        userService = new UserService();
        quizParticipantDAO = new QuizParticipantDAO();
        submissionDAO = new SubmissionDAO();
        auditService = new AuditService();
        informationBoardDAO = new InformationBoardDAO();
        customPageDAO = new CustomPageDAO();
        quizExemptionDAO = new QuizExemptionDAO();
        retakeCodeDAO = new RetakeCodeDAO();
        quotaService = new QuotaService();
    }

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        String action = request.getParameter("action");

        try {
            switch (action != null ? action : "list") {
                case "dashboard":
                    showUserDashboard(request, response);
                    break;
                case "list":
                    listAvailableQuizzes(request, response);
                    break;
                case "start":
                    startExam(request, response);
                    break;
                case "take":
                    showExam(request, response);
                    break;
                case "getQuestionData":
                    getQuestionData(request, response);
                    break;
                case "result":
                    showResult(request, response);
                    break;
                case "history":
                    showHistory(request, response);
                    break;
                case "validateRetakeCode":
                    validateRetakeCode(request, response);
                    break;
                default:
                    showUserDashboard(request, response);
            }
        } catch (Exception e) {
            request.setAttribute("error", "Error: " + e.getMessage());
            try {
                listAvailableQuizzes(request, response);
            } catch (Exception ex) {
                throw new ServletException(ex);
            }
        }
    }

    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        String action = request.getParameter("action");

        try {
            switch (action != null ? action : "") {
                case "saveAnswer":
                    saveAnswer(request, response);
                    break;
                case "submit":
                    submitExam(request, response);
                    break;
                default:
                    listAvailableQuizzes(request, response);
            }
        } catch (Exception e) {
            response.setContentType("application/json");
            response.getWriter().write("{\"success\": false, \"message\": \"" + e.getMessage() + "\"}");
        }
    }

    private void listAvailableQuizzes(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException, QuizService.ServiceException, SubmissionService.ServiceException, UserService.ServiceException {
        User sessionUser = (User) request.getSession().getAttribute("user");

        // Check if user is logged in
        if (sessionUser == null) {
            response.sendRedirect(request.getContextPath() + "/LoginServlet");
            return;
        }

        // Refresh user data from database to get latest gdrive_link
        User user = userService.getUserById(sessionUser.getId());
        request.getSession().setAttribute("user", user);

        // Get active quizzes filtered by user's tag
        List<Quiz> quizzes = quizService.getActiveQuizzesByTag(user.getTag());

        // Additional Java-level filter to remove expired quizzes (fix timezone issues)
        if (quizzes != null && !quizzes.isEmpty()) {
            quizzes.removeIf(quiz -> quiz.isExpired());
            System.out.println("Filtered active quizzes: " + quizzes.size() + " remaining after removing expired ones");
        }

        // Filter by participant approval (manual control)
        if (quizzes != null && !quizzes.isEmpty()) {
            List<Quiz> approvedQuizzes = new ArrayList<>();
            for (Quiz quiz : quizzes) {
                try {
                    if (quizParticipantDAO.isUserAllowed(quiz.getId(), user.getId())) {
                        approvedQuizzes.add(quiz);
                    } else {
                        System.out.println("User " + user.getId() + " NOT allowed for quiz " + quiz.getId());
                    }
                } catch (Exception e) {
                    System.err.println("Error checking participant approval: " + e.getMessage());
                    // On error, allow quiz (fail open for safety)
                    approvedQuizzes.add(quiz);
                }
            }
            quizzes = approvedQuizzes;
            System.out.println("Final quizzes after participant filter: " + quizzes.size());
        }

        // Get expired quizzes filtered by user's tag
        List<Quiz> expiredQuizzes = null;
        try {
            expiredQuizzes = quizService.getExpiredQuizzesByTag(user.getTag());
        } catch (Exception e) {
            // If there's an error fetching expired quizzes, just log it and continue with empty list
            System.err.println("Error fetching expired quizzes: " + e.getMessage());
            expiredQuizzes = new ArrayList<>();
        }

        // Check for retake codes - move expired quizzes with valid retake codes to available quizzes
        @SuppressWarnings("unchecked")
        java.util.List<Integer> retakeAccessibleQuizzes = (java.util.List<Integer>) request.getSession().getAttribute("retakeAccessibleQuizzes");

        if (retakeAccessibleQuizzes != null && !retakeAccessibleQuizzes.isEmpty() && expiredQuizzes != null && !expiredQuizzes.isEmpty()) {
            // Create iterator to safely remove from list
            java.util.Iterator<Quiz> iterator = expiredQuizzes.iterator();
            while (iterator.hasNext()) {
                Quiz quiz = iterator.next();
                if (retakeAccessibleQuizzes.contains(quiz.getId())) {
                    // Check if user can retake (only allow: no submission OR timeout)
                    Submission existingSubmission = submissionService.getUserSubmission(user.getId(), quiz.getId());
                    // Only allow if: no submission OR timeout (can retake)
                    // NOT allow if: in_progress or completed
                    if (existingSubmission == null || existingSubmission.isTimeout()) {
                        // For timeout, we need to delete the old submission first
                        if (existingSubmission != null && existingSubmission.isTimeout()) {
                            try {
                                submissionDAO.deleteSubmission(existingSubmission.getId());
                                System.out.println("Deleted timeout submission " + existingSubmission.getId() + " for retake");
                            } catch (Exception e) {
                                System.err.println("Error deleting timeout submission: " + e.getMessage());
                            }
                        }
                        // Move to available quizzes
                        if (quizzes == null) {
                            quizzes = new ArrayList<>();
                        }
                        quizzes.add(quiz);
                        iterator.remove();
                        System.out.println("Moved expired quiz " + quiz.getId() + " to available quizzes due to valid retake code");
                    } else {
                        System.out.println("Quiz " + quiz.getId() + " NOT moved - user has " +
                            (existingSubmission != null ? existingSubmission.getStatus() : "no") + " submission");
                    }
                }
            }
        }

        // Get submissions for all quizzes (both active and expired)
        Map<Integer, Submission> userSubmissions = new HashMap<>();

        if (quizzes != null) {
            for (Quiz quiz : quizzes) {
                Submission submission = submissionService.getUserSubmission(user.getId(), quiz.getId());
                if (submission != null) {
                    userSubmissions.put(quiz.getId(), submission);
                }
            }
        }

        if (expiredQuizzes != null) {
            for (Quiz quiz : expiredQuizzes) {
                Submission submission = submissionService.getUserSubmission(user.getId(), quiz.getId());
                if (submission != null) {
                    userSubmissions.put(quiz.getId(), submission);
                }
            }
        }

        request.setAttribute("quizzes", quizzes);
        request.setAttribute("expiredQuizzes", expiredQuizzes);
        request.setAttribute("userSubmissions", userSubmissions);
        request.setAttribute("retakeAccessibleQuizzes", retakeAccessibleQuizzes);
        request.getRequestDispatcher("/user/quiz-list.jsp").forward(request, response);
    }

    private void showUserDashboard(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException, QuizService.ServiceException, SubmissionService.ServiceException, UserService.ServiceException {
        User sessionUser = (User) request.getSession().getAttribute("user");

        // Check if user is logged in
        if (sessionUser == null) {
            response.sendRedirect(request.getContextPath() + "/LoginServlet");
            return;
        }

        // Refresh user data from database to get latest gdrive_link
        User user = userService.getUserById(sessionUser.getId());
        request.getSession().setAttribute("user", user);

        // Get quizzes filtered by user's tag
        List<Quiz> quizzes = quizService.getActiveQuizzesByTag(user.getTag());

        // Additional Java-level filter to remove expired quizzes (fix timezone issues)
        if (quizzes != null && !quizzes.isEmpty()) {
            quizzes.removeIf(quiz -> quiz.isExpired());
            System.out.println("Dashboard: Filtered active quizzes: " + quizzes.size() + " remaining after removing expired ones");
        }

        // Filter by participant approval (manual control)
        if (quizzes != null && !quizzes.isEmpty()) {
            List<Quiz> approvedQuizzes = new ArrayList<>();
            for (Quiz quiz : quizzes) {
                try {
                    if (quizParticipantDAO.isUserAllowed(quiz.getId(), user.getId())) {
                        approvedQuizzes.add(quiz);
                    } else {
                        System.out.println("Dashboard: User " + user.getId() + " NOT allowed for quiz " + quiz.getId());
                    }
                } catch (Exception e) {
                    System.err.println("Dashboard: Error checking participant approval: " + e.getMessage());
                    approvedQuizzes.add(quiz);
                }
            }
            quizzes = approvedQuizzes;
            System.out.println("Dashboard: Final quizzes after participant filter: " + quizzes.size());
        }

        // Get expired quizzes
        List<Quiz> expiredQuizzes = null;
        try {
            expiredQuizzes = quizService.getExpiredQuizzesByTag(user.getTag());
        } catch (Exception e) {
            System.err.println("Error fetching expired quizzes: " + e.getMessage());
            expiredQuizzes = new ArrayList<>();
        }

        Map<Integer, Submission> userSubmissions = new HashMap<>();
        for (Quiz quiz : quizzes) {
            Submission submission = submissionService.getUserSubmission(user.getId(), quiz.getId());
            if (submission != null) {
                userSubmissions.put(quiz.getId(), submission);
            }
        }

        if (expiredQuizzes != null) {
            for (Quiz quiz : expiredQuizzes) {
                Submission submission = submissionService.getUserSubmission(user.getId(), quiz.getId());
                if (submission != null) {
                    userSubmissions.put(quiz.getId(), submission);
                }
            }
        }

        // Get recent submissions for the user
        List<Submission> recentSubmissions = submissionService.getUserSubmissions(user.getId());

        // Get active information boards for this user (without duplicates)
        List<InformationBoard> informationBoards = new ArrayList<>();
        try {
            String targetAudience = user.isAdmin() ? "admins" : "participants";
            // P1 #17 — saring juga berdasarkan jenjang siswa (grade_level)
            String gradeLevel = user.getGradeLevel();
            List<InformationBoard> allInfos = informationBoardDAO.findActiveForTargetAndGrade("all", gradeLevel);
            List<InformationBoard> roleInfos = informationBoardDAO.findActiveForTargetAndGrade(targetAudience, gradeLevel);

            // Use Set to track IDs and avoid duplicates
            java.util.Set<Integer> seenIds = new java.util.HashSet<>();

            if (allInfos != null) {
                for (InformationBoard info : allInfos) {
                    if (seenIds.add(info.getId())) {
                        informationBoards.add(info);
                    }
                }
            }
            if (roleInfos != null) {
                for (InformationBoard info : roleInfos) {
                    if (seenIds.add(info.getId())) {
                        informationBoards.add(info);
                    }
                }
            }
        } catch (Exception e) {
            System.err.println("Error fetching information boards: " + e.getMessage());
        }

        // Get active custom pages for navbar (filtered by user's tag)
        List<CustomPage> customPages = new ArrayList<>();
        try {
            customPages = customPageDAO.findActiveForTag(user.getTag());
        } catch (Exception e) {
            System.err.println("Error fetching custom pages: " + e.getMessage());
        }

        request.setAttribute("quizzes", quizzes);
        request.setAttribute("expiredQuizzes", expiredQuizzes);
        request.setAttribute("userSubmissions", userSubmissions);
        request.setAttribute("recentSubmissions", recentSubmissions);
        request.setAttribute("informationBoards", informationBoards);
        request.setAttribute("customPages", customPages);
        request.getRequestDispatcher("/user/dashboard.jsp").forward(request, response);
    }

    private void startExam(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException, QuizService.ServiceException, SubmissionService.ServiceException {
        String quizIdStr = request.getParameter("quizId");
        if (quizIdStr == null || quizIdStr.isEmpty()) {
            response.sendRedirect(request.getContextPath() + "/ExamServlet?action=list");
            return;
        }

        // Validate quizId format
        Integer quizId;
        try {
            quizId = Integer.parseInt(quizIdStr);
            if (quizId <= 0) {
                response.sendRedirect(request.getContextPath() + "/ExamServlet?action=list");
                return;
            }
        } catch (NumberFormatException e) {
            // Invalid quizId format - redirect to list instead of showing error
            response.sendRedirect(request.getContextPath() + "/ExamServlet?action=list");
            return;
        }

        User user = (User) request.getSession().getAttribute("user");

        // Check if user is logged in
        if (user == null) {
            response.sendRedirect(request.getContextPath() + "/LoginServlet");
            return;
        }

        Quiz quiz = quizService.getQuizById(quizId);
        if (quiz == null) {
            response.sendRedirect(request.getContextPath() + "/ExamServlet?action=list");
            return;
        }

        // Check if user is exempted from taking this quiz
        try {
            if (quizExemptionDAO.isExempted(quizId, user.getId())) {
                // User is exempted, redirect to result page
                // First ensure auto-submission exists
                try {
                    quizService.createAutoSubmissionsForExemptedUsers(quizId);
                } catch (Exception e) {
                    System.err.println("Error creating auto-submission: " + e.getMessage());
                }

                // Redirect to result page
                Submission existingSubmission = submissionService.getUserSubmission(user.getId(), quizId);
                if (existingSubmission != null) {
                    request.setAttribute("quiz", quiz);
                    request.setAttribute("submission", existingSubmission);
                    request.setAttribute("info", "Anda dikecualikan dari quiz ini. Nilai otomatis: 100");
                    showResult(request, response);
                    return;
                }
            }
        } catch (Exception e) {
            System.err.println("Error checking exemption: " + e.getMessage());
            // Continue anyway, allow user to take the quiz
        }

        // Check if user has validated retake code
        Object validatedRetakeAttr = request.getSession().getAttribute("validatedRetakeQuiz_" + quizId);
        System.out.println("DEBUG startExam: quizId=" + quizId + ", validatedRetakeAttr=" + validatedRetakeAttr);
        boolean hasValidatedRetake = validatedRetakeAttr != null;
        boolean isManuallyAllowed = false;
        boolean allowRetake = hasValidatedRetake;

        if (!hasValidatedRetake) {
            // Check if user is manually allowed (in quiz_participants)
            try {
                isManuallyAllowed = quizParticipantDAO.isUserAllowed(quizId, user.getId());
            } catch (Exception e) {
                System.err.println("Error checking manual permission: " + e.getMessage());
                // On error, assume not manually allowed
                isManuallyAllowed = false;
            }

            if (!isManuallyAllowed && quiz.isExpired()) {
                request.setAttribute("error", "Quiz sudah melewati deadline. Hubungi admin untuk kode retake.");
                try {
                    listAvailableQuizzes(request, response);
                } catch (UserService.ServiceException e) {
                    throw new ServletException(e);
                }
                return;
            }

            // If manually allowed, allow retake even without retake code
            allowRetake = isManuallyAllowed;
        }

        // For retake cases (retake code or manual permission), delete old timeout submission if exists
        if (allowRetake) {
            try {
                Submission existingSubmission = submissionService.getUserSubmission(user.getId(), quizId);
                if (existingSubmission != null && existingSubmission.isTimeout()) {
                    submissionDAO.deleteSubmission(existingSubmission.getId());
                    System.out.println("Deleted timeout submission " + existingSubmission.getId() + " for retake (allowed=" + allowRetake + ")");
                }
            } catch (Exception e) {
                System.err.println("Error deleting timeout submission: " + e.getMessage());
            }
        }

        // P1 #15 — potong 1 poin kuota saat siswa memulai Exam.
        // Percobaan ulang lewat kode retake / izin manual tidak dipotong lagi.
        if (!allowRetake) {
            try {
                quotaService.consume(user.getId(), "exam", "quiz:" + quizId);
            } catch (QuotaService.ServiceException quotaEx) {
                request.setAttribute("error", quotaEx.getMessage());
                try {
                    listAvailableQuizzes(request, response);
                } catch (UserService.ServiceException userEx) {
                    throw new ServletException(userEx);
                }
                return;
            }
        }

        Submission submission = submissionService.startQuiz(quizId, user.getId(), hasValidatedRetake);

        // Log quiz access
        java.util.Map<String, Object> logData = new java.util.HashMap<>();
        logData.put("quizId", quizId);
        logData.put("quizTitle", quiz.getTitle());
        logData.put("submissionId", submission.getId());
        logData.put("isRetake", hasValidatedRetake);
        auditService.log("CREATE", "SUBMISSION", submission.getId(), quiz.getTitle(), logData, user, request);

        request.getSession().setAttribute("currentSubmissionId", submission.getId());
        request.getSession().setAttribute("currentQuizId", quizId);
        request.getSession().setAttribute("examStartTime", System.currentTimeMillis());

        request.setAttribute("quiz", quiz);
        request.setAttribute("submission", submission);
        response.sendRedirect(request.getContextPath() + "/ExamServlet?action=take&quizId=" + quizId);
    }

    private void showExam(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException, QuizService.ServiceException, SubmissionService.ServiceException, UserService.ServiceException {
        String quizIdStr = request.getParameter("quizId");
        if (quizIdStr == null || quizIdStr.isEmpty()) {
            response.sendRedirect(request.getContextPath() + "/ExamServlet?action=list");
            return;
        }

        // Validate quizId format
        Integer quizId;
        try {
            quizId = Integer.parseInt(quizIdStr);
            if (quizId <= 0) {
                response.sendRedirect(request.getContextPath() + "/ExamServlet?action=list");
                return;
            }
        } catch (NumberFormatException e) {
            // Invalid quizId format - redirect to list instead of showing error
            response.sendRedirect(request.getContextPath() + "/ExamServlet?action=list");
            return;
        }

        User user = (User) request.getSession().getAttribute("user");

        // Check if user is logged in
        if (user == null) {
            response.sendRedirect(request.getContextPath() + "/LoginServlet");
            return;
        }

        Quiz quiz = quizService.getQuizById(quizId);

        // Check if quiz has expired (past deadline) - but allow if user has validated retake code
        boolean hasValidatedRetake = request.getSession().getAttribute("validatedRetakeQuiz_" + quizId) != null;

        if (quiz.isExpired() && !hasValidatedRetake) {
            request.setAttribute("error", "Quiz sudah melewati deadline (" + quiz.getFormattedDeadline() + ")");
            listAvailableQuizzes(request, response);
            return;
        }

        // Allow retake users to access unpublished quizzes
        if (!quiz.getIsActive() && !hasValidatedRetake) {
            request.setAttribute("error", "Quiz belum dipublish");
            listAvailableQuizzes(request, response);
            return;
        }

        Submission submission = submissionService.getUserSubmission(user.getId(), quizId);

        if (submission == null || submission.isCompleted()) {
            response.sendRedirect(request.getContextPath() + "/ExamServlet?action=list");
            return;
        }

        // Get total questions from stored question order
        String questionOrderStr = submission.getQuestionOrder();
        int totalQuestions;
        if (questionOrderStr != null && !questionOrderStr.isEmpty()) {
            totalQuestions = questionOrderStr.split(",").length;
        } else {
            List<Question> questions = submissionService.getQuestionsForExam(quizId, false);
            totalQuestions = questions != null ? questions.size() : 0;
        }

        // Check if quiz time has expired BEFORE updating activity.
        // This prevents the timer reset exploit where updateActivity adds
        // the entire absence gap as pause time, making an expired quiz appear valid.
        if (isTimeExpired(submission, quiz)) {
            // Auto-submit with timeout status
            int timeSpent = calculateTimeSpent(submission);
            submissionService.submitQuizWithTimeout(submission.getId(), timeSpent);
            request.setAttribute("error", "Waktu quiz telah habis. Jawaban Anda telah otomatis dikumpulkan.");
            response.sendRedirect(request.getContextPath() + "/ExamServlet?action=result&submissionId=" + submission.getId() + "&timeout=true");
            return;
        }

        // Update activity tracking AFTER confirming quiz is still valid.
        // Use a 120-second threshold so normal thinking time per question
        // doesn't get wrongly counted as "pause" (which inflates remaining time).
        try {
            submissionDAO.updateActivity(submission.getId(), 120);
            submission = submissionDAO.findById(submission.getId());
        } catch (Exception e) {
            System.err.println("Error updating activity: " + e.getMessage());
        }

        // Reshuffle question order on every page load so questions appear in new random order
        try {
            submissionService.reshuffleQuestionOrder(submission.getId(), quizId);
            submission = submissionDAO.findById(submission.getId());
            questionOrderStr = submission.getQuestionOrder();
            totalQuestions = (questionOrderStr != null && !questionOrderStr.isEmpty()) ? questionOrderStr.split(",").length : totalQuestions;
        } catch (Exception e) {
            System.err.println("Error reshuffling questions: " + e.getMessage());
        }

        // Only pass metadata to JSP - questions are loaded via AJAX
        request.setAttribute("quiz", quiz);
        request.setAttribute("submission", submission);
        request.setAttribute("totalQuestions", totalQuestions);

        // Calculate remaining time in seconds (server-side validation)
        int remainingTimeSeconds = calculateRemainingTime(submission, quiz);
        request.setAttribute("remainingTimeSeconds", remainingTimeSeconds);

        request.getRequestDispatcher("/user/take-exam.jsp").forward(request, response);
    }

    private void saveAnswer(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException, SubmissionService.ServiceException {
        User user = (User) request.getSession().getAttribute("user");
        String submissionIdStr = request.getParameter("submissionId");
        String questionIdStr = request.getParameter("questionId");
        String selectedAnswer = request.getParameter("selectedAnswer");

        // Validate parameters
        if (submissionIdStr == null || submissionIdStr.isEmpty()) {
            response.setContentType("application/json");
            response.getWriter().write("{\"success\": false, \"message\": \"Submission ID required\"}");
            return;
        }
        if (questionIdStr == null || questionIdStr.isEmpty()) {
            response.setContentType("application/json");
            response.getWriter().write("{\"success\": false, \"message\": \"Question ID required\"}");
            return;
        }
        if (selectedAnswer == null || selectedAnswer.isEmpty()) {
            response.setContentType("application/json");
            response.getWriter().write("{\"success\": false, \"message\": \"Answer required\"}");
            return;
        }

        // Validate answer format
        if (!selectedAnswer.matches("[ABCD]")) {
            response.setContentType("application/json");
            response.getWriter().write("{\"success\": false, \"message\": \"Invalid answer format\"}");
            return;
        }

        try {
            Integer submissionId = Integer.parseInt(submissionIdStr);
            Integer questionId = Integer.parseInt(questionIdStr);

            // Get submission and verify ownership (safe - only queries submissions table, no answers/correct_answer)
            Submission submission = submissionDAO.findById(submissionId);
            if (submission == null || !submission.getUserId().equals(user.getId())) {
                response.setContentType("application/json");
                response.getWriter().write("{\"success\": false, \"message\": \"Unauthorized\"}");
                return;
            }

            // Defense in depth: reject if already completed
            if (submission.isCompleted()) {
                response.setContentType("application/json");
                response.getWriter().write("{\"success\": false, \"message\": \"Quiz sudah selesai\"}");
                return;
            }

            // Update activity tracking (freeze timer when user is away > 120s)
            try { submissionDAO.updateActivity(submissionId, 120); } catch (Exception e) {}
            submission = submissionDAO.findById(submissionId);

            // Check if quiz time has expired (server-side validation)
            Quiz quiz = quizService.getQuizById(submission.getQuizId());
            if (isTimeExpired(submission, quiz)) {
                // Auto-submit with timeout status
                int timeSpent = calculateTimeSpent(submission);
                submissionService.submitQuizWithTimeout(submissionId, timeSpent);
                response.setContentType("application/json");
                response.getWriter().write("{\"success\": false, \"message\": \"TIME_EXPIRED\", \"redirect\": \"result?submissionId=" + submissionId + "&timeout=true\"}");
                return;
            }

            submissionService.saveAnswer(submissionId, questionId, selectedAnswer);

            response.setContentType("application/json");
            response.getWriter().write("{\"success\": true, \"message\": \"Answer saved\"}");

        } catch (NumberFormatException e) {
            response.setContentType("application/json");
            response.getWriter().write("{\"success\": false, \"message\": \"Invalid ID format\"}");
        } catch (SubmissionService.ServiceException | QuizService.ServiceException | SQLException e) {
            response.setContentType("application/json");
            response.getWriter().write("{\"success\": false, \"message\": \"" +
                e.getMessage().replace("\"", "\\\"") + "\"}");
        }
    }

    private void submitExam(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException, SubmissionService.ServiceException, SQLException {
        User user = (User) request.getSession().getAttribute("user");
        String submissionIdStr = request.getParameter("submissionId");
        String timeSpentStr = request.getParameter("timeSpent");
        String isTimeoutStr = request.getParameter("isTimeout");
        boolean isAjax = "true".equals(request.getParameter("ajax"));

        if (submissionIdStr == null || submissionIdStr.isEmpty()) {
            response.sendRedirect(request.getContextPath() + "/ExamServlet?action=list");
            return;
        }

        try {
            Integer submissionId = Integer.parseInt(submissionIdStr);
            Integer timeSpent = 0;

            if (timeSpentStr != null && !timeSpentStr.isEmpty()) {
                timeSpent = Integer.parseInt(timeSpentStr);
                if (timeSpent < 0) timeSpent = 0;
            }

            // Check if this is a timeout submission
            boolean isTimeout = "true".equals(isTimeoutStr);

            // Get submission and verify ownership (safe - only queries submissions table)
            Submission existingSubmission = submissionDAO.findById(submissionId);
            if (existingSubmission == null) {
                response.sendRedirect(request.getContextPath() + "/ExamServlet?action=list");
                return;
            }

            // Verify submission belongs to current user
            if (!existingSubmission.getUserId().equals(user.getId())) {
                response.sendRedirect(request.getContextPath() + "/ExamServlet?action=list");
                return;
            }

            // Defense in depth: prevent double-submit
            if (existingSubmission.isCompleted()) {
                if (isAjax) {
                    response.setContentType("application/json");
                    response.setCharacterEncoding("UTF-8");
                    response.getWriter().write("{\"success\": true, \"submissionId\": " + submissionId + "}");
                } else {
                    response.sendRedirect(request.getContextPath() + "/ExamServlet?action=result&submissionId=" + submissionId);
                }
                return;
            }

            // Always use the server-calculated timeSpent as the source of truth.
            // The client's timeSpent (Date.now() - startTime) resets on every page
            // reload and is unreliable — a user who reloads 2 minutes before
            // submitting would otherwise record only 2 minutes instead of the
            // real time spent since the quiz started.
            int serverTimeSpent = calculateTimeSpent(existingSubmission);
            timeSpent = serverTimeSpent;

            Submission submission;
            if (isTimeout) {
                // Submit with timeout status
                submission = submissionService.submitQuizWithTimeout(submissionId, timeSpent);
            } else {
                // Normal submit with completed status
                submission = submissionService.submitQuiz(submissionId, timeSpent);
            }

            // Log quiz submission
            try {
                Quiz quiz = quizService.getQuizById(submission.getQuizId());
                java.util.Map<String, Object> logData = new java.util.HashMap<>();
                logData.put("quizId", submission.getQuizId());
                logData.put("quizTitle", quiz != null ? quiz.getTitle() : "Unknown");
                logData.put("submissionId", submission.getId());
                logData.put("score", submission.getScore());
                logData.put("status", submission.getStatus());
                logData.put("timeSpent", timeSpent);
                logData.put("isTimeout", isTimeout);
                if (submission.getIsRetake() != null && submission.getIsRetake()) {
                    logData.put("isRetake", true);
                }
                auditService.log("UPDATE", "SUBMISSION", submission.getId(),
                    quiz != null ? quiz.getTitle() : "Quiz", logData, user, request);
            } catch (Exception e) {
                System.err.println("Error logging quiz submission: " + e.getMessage());
            }

            // Award quiz points with speed bonus
            try {
                com.examora.service.GamificationService gamificationService = new com.examora.service.GamificationService();
                Quiz quiz = quizService.getQuizById(submission.getQuizId());
                Integer durationMinutes = (quiz != null) ? quiz.getDuration() : null;

                // Only award points for completed quizzes (not timeout)
                if ("completed".equals(submission.getStatus())) {
                    // Convert Double score to Integer
                    Integer score = submission.getScore() != null ? submission.getScore().intValue() : null;

                    gamificationService.awardQuizPoints(
                        user.getId(),
                        submission.getQuizId(),
                        score,
                        submission.getTotalQuestions(),
                        timeSpent,
                        durationMinutes
                    );
                    System.out.println("Awarded quiz points to user " + user.getId() + " for quiz " + submission.getQuizId());
                }
            } catch (Exception e) {
                System.err.println("Error awarding quiz points: " + e.getMessage());
                // Don't fail the submission if point awarding fails
            }

            // Mark retake code as used if this was a retake submission
            if (submission.getIsRetake() != null && submission.getIsRetake()) {
                try {
                    RetakeCodeService retakeCodeService = new RetakeCodeService();
                    retakeCodeService.markCodeAsUsed(submission.getQuizId(), user.getId());
                    System.out.println("Marked retake code as used for submission: " + submissionId);
                } catch (Exception e) {
                    System.err.println("Error marking retake code as used: " + e.getMessage());
                }
            }

            request.getSession().removeAttribute("currentSubmissionId");
            request.getSession().removeAttribute("currentQuizId");
            request.getSession().removeAttribute("examStartTime");

            if (isAjax) {
                response.setContentType("application/json");
                response.setCharacterEncoding("UTF-8");
                response.getWriter().write("{\"success\": true, \"submissionId\": " + submissionId + "}");
            } else {
                response.sendRedirect(request.getContextPath() + "/ExamServlet?action=result&submissionId=" + submissionId);
            }

        } catch (NumberFormatException e) {
            if (isAjax) {
                response.setContentType("application/json");
                response.setCharacterEncoding("UTF-8");
                response.getWriter().write("{\"success\": false, \"message\": \"Format ID tidak valid\"}");
            } else {
                response.sendRedirect(request.getContextPath() + "/ExamServlet?action=list");
            }
        }
    }

    private void showResult(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException, SubmissionService.ServiceException, QuizService.ServiceException {
        User user = (User) request.getSession().getAttribute("user");

        // Check if user is logged in
        if (user == null) {
            response.sendRedirect(request.getContextPath() + "/LoginServlet");
            return;
        }

        String submissionIdStr = request.getParameter("submissionId");

        if (submissionIdStr == null || submissionIdStr.isEmpty()) {
            response.sendRedirect(request.getContextPath() + "/ExamServlet?action=list");
            return;
        }

        try {
            Integer submissionId = Integer.parseInt(submissionIdStr);
            Submission submission = submissionService.getResult(submissionId);

            if (submission == null) {
                response.sendRedirect(request.getContextPath() + "/ExamServlet?action=list");
                return;
            }

            // Verify submission belongs to current user (unless admin)
            if (!submission.getUserId().equals(user.getId()) && !user.isAdmin()) {
                response.sendRedirect(request.getContextPath() + "/ExamServlet?action=list");
                return;
            }

            // Block access if submission is still in_progress - answers must not be revealed
            if (submission.isInProgress()) {
                response.sendRedirect(request.getContextPath() + "/ExamServlet?action=take&quizId=" + submission.getQuizId());
                return;
            }

            // Get quiz to check showReview setting
            Quiz quiz = quizService.getQuizById(submission.getQuizId());

            // Check if this user has a valid (unused, not expired) retake code for this quiz.
            // If so, hide correct answers to prevent the retake exploit where students
            // memorize answers from the result page and retake with a perfect score.
            boolean hideCorrectAnswers = false;
            try {
                RetakeCode retakeCode = retakeCodeDAO.getByQuizAndUser(submission.getQuizId(), user.getId());
                if (retakeCode != null && retakeCode.isValid()) {
                    // Valid retake code exists and hasn't been used - hide answers
                    hideCorrectAnswers = true;
                }
            } catch (Exception e) {
                // If we can't check, don't hide answers (fail open for usability)
                System.err.println("Error checking retake code availability: " + e.getMessage());
            }

            // Get ALL questions for the quiz (not just answered ones)
            // This ensures unanswered questions are also shown in the result
            List<Answer> allAnswers = submissionService.getAllQuestionsWithAnswers(submissionId, submission.getQuizId());
            submission.setAnswers(allAnswers);

            request.setAttribute("submission", submission);
            request.setAttribute("quiz", quiz);
            request.setAttribute("hideCorrectAnswers", hideCorrectAnswers);
            request.getRequestDispatcher("/user/exam-result.jsp").forward(request, response);

        } catch (NumberFormatException e) {
            response.sendRedirect(request.getContextPath() + "/ExamServlet?action=list");
        }
    }

    private void showHistory(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException, SubmissionService.ServiceException, UserService.ServiceException {
        User sessionUser = (User) request.getSession().getAttribute("user");

        // Check if user is logged in
        if (sessionUser == null) {
            response.sendRedirect(request.getContextPath() + "/LoginServlet");
            return;
        }

        // Refresh user data from database to get latest gdrive_link
        User user = userService.getUserById(sessionUser.getId());
        request.getSession().setAttribute("user", user);

        List<Submission> submissions = submissionService.getUserSubmissions(user.getId());

        request.setAttribute("submissions", submissions);
        request.getRequestDispatcher("/user/exam-history.jsp").forward(request, response);
    }

    private void validateRetakeCode(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        User sessionUser = (User) request.getSession().getAttribute("user");

        if (sessionUser == null) {
            response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
            response.getWriter().write("{\"success\":false,\"message\":\"User tidak login\"}");
            return;
        }

        response.setContentType("application/json");
        response.setCharacterEncoding("UTF-8");

        try {
            String code = request.getParameter("code");
            String quizIdStr = request.getParameter("quizId");

            if (code == null || code.isEmpty()) {
                response.getWriter().write("{\"success\":false,\"message\":\"Kode tidak valid\"}");
                return;
            }

            RetakeCodeService retakeCodeService = new RetakeCodeService();
            RetakeCode retakeCode = retakeCodeService.validateCode(code, sessionUser.getId());

            if (retakeCode != null) {
                // Store validated quiz in session so user can proceed and also for listing
                String sessionKey = "validatedRetakeQuiz_" + retakeCode.getQuizId();
                request.getSession().setAttribute(sessionKey, retakeCode.getQuizId());
                System.out.println("DEBUG validateRetakeCode: Set session attribute " + sessionKey + " = " + retakeCode.getQuizId());

                // Also add to a list of accessible retake quizzes
                @SuppressWarnings("unchecked")
                java.util.List<Integer> retakeQuizzes = (java.util.List<Integer>) request.getSession().getAttribute("retakeAccessibleQuizzes");
                if (retakeQuizzes == null) {
                    retakeQuizzes = new java.util.ArrayList<>();
                }
                if (!retakeQuizzes.contains(retakeCode.getQuizId())) {
                    retakeQuizzes.add(retakeCode.getQuizId());
                }
                request.getSession().setAttribute("retakeAccessibleQuizzes", retakeQuizzes);

                response.getWriter().write("{\"success\":true,\"quizId\":" +
                    retakeCode.getQuizId() + ",\"message\":\"Kode retake valid\"}");
            }

        } catch (RetakeCodeService.ServiceException e) {
            response.getWriter().write("{\"success\":false,\"message\":\"" +
                e.getMessage().replace("\"", "'") + "\"}");
        } catch (Exception e) {
            response.getWriter().write("{\"success\":false,\"message\":\"Terjadi kesalahan\"}");
        }
    }

    private void getQuestionData(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        User user = (User) request.getSession().getAttribute("user");

        if (user == null) {
            response.setContentType("application/json");
            response.setCharacterEncoding("UTF-8");
            response.getWriter().write("{\"success\":false,\"message\":\"User tidak login\"}");
            return;
        }

        String quizIdStr = request.getParameter("quizId");
        String questionIndexStr = request.getParameter("index");
        String submissionIdStr = request.getParameter("submissionId");

        if (quizIdStr == null || questionIndexStr == null) {
            response.setContentType("application/json");
            response.setCharacterEncoding("UTF-8");
            response.getWriter().write("{\"success\":false,\"message\":\"Parameter tidak lengkap\"}");
            return;
        }

        try {
            int quizId = Integer.parseInt(quizIdStr);
            int questionIndex = Integer.parseInt(questionIndexStr);

            // Verify quiz exists and is accessible
            Quiz quiz = quizService.getQuizById(quizId);
            if (quiz == null) {
                response.setContentType("application/json");
                response.setCharacterEncoding("UTF-8");
                response.getWriter().write("{\"success\":false,\"message\":\"Quiz tidak ditemukan\"}");
                return;
            }

            // Get submission - prefer direct lookup by submissionId for consistency
            Submission submission = null;
            if (submissionIdStr != null && !submissionIdStr.isEmpty()) {
                try {
                    Integer subId = Integer.parseInt(submissionIdStr);
                    submission = submissionDAO.findById(subId);
                    // Verify it belongs to this user
                    if (submission != null && !submission.getUserId().equals(user.getId())) {
                        submission = null;
                    }
                } catch (NumberFormatException e) {
                    // Ignore, fall back to user+quiz lookup
                }
            }
            if (submission == null) {
                submission = submissionService.getUserSubmission(user.getId(), quizId);
            }
            if (submission == null || submission.isCompleted()) {
                response.setContentType("application/json");
                response.setCharacterEncoding("UTF-8");
                response.getWriter().write("{\"success\":false,\"message\":\"Tidak ada sesi aktif\"}");
                return;
            }

            // NOTE: updateActivity is intentionally NOT called here.
            // getQuestionData is invoked on every question navigation and during
            // client-side time sync (syncTimeFromServer). Calling updateActivity
            // that frequently with a 30-second threshold added false "pause" time
            // every time a user spent >30s reading a question, which destabilised
            // the countdown timer. Activity tracking happens in showExam (page
            // load) and saveAnswer (user interaction) instead.

            // Check if quiz time has expired
            if (isTimeExpired(submission, quiz)) {
                int timeSpent = calculateTimeSpent(submission);
                submissionService.submitQuizWithTimeout(submission.getId(), timeSpent);
                response.setContentType("application/json");
                response.setCharacterEncoding("UTF-8");
                response.getWriter().write("{\"success\":false,\"message\":\"TIME_EXPIRED\",\"redirect\":\"result?submissionId=" + submission.getId() + "&timeout=true\"}");
                return;
            }

            // Get question order from submission (stored in DB when exam started)
            String questionOrderStr = submission.getQuestionOrder();
            int totalQ;
            Integer targetQuestionId;

            if (questionOrderStr != null && !questionOrderStr.isEmpty()) {
                // Use stored question order
                String[] parts = questionOrderStr.split(",");
                totalQ = parts.length;
                if (questionIndex < 0 || questionIndex >= totalQ) {
                    response.setContentType("application/json");
                    response.setCharacterEncoding("UTF-8");
                    response.getWriter().write("{\"success\":false,\"message\":\"Soal tidak ditemukan\"}");
                    return;
                }
                targetQuestionId = Integer.parseInt(parts[questionIndex]);
            } else {
                // Old submission without stored order: generate and save it now
                List<Question> allQuestions = submissionService.getQuestionsForExam(quizId, false);
                totalQ = allQuestions.size();
                if (questionIndex < 0 || questionIndex >= totalQ) {
                    response.setContentType("application/json");
                    response.setCharacterEncoding("UTF-8");
                    response.getWriter().write("{\"success\":false,\"message\":\"Soal tidak ditemukan\"}");
                    return;
                }
                // Build and persist question order so it's consistent from now on
                StringBuilder sb = new StringBuilder();
                for (Question q : allQuestions) {
                    if (sb.length() > 0) sb.append(",");
                    sb.append(q.getId());
                }
                submissionService.saveQuestionOrder(submission.getId(), sb.toString());
                targetQuestionId = allQuestions.get(questionIndex).getId();
            }

            // Fetch the single question by ID
            Question q = submissionService.getQuestionById(targetQuestionId);
            if (q == null) {
                response.setContentType("application/json");
                response.setCharacterEncoding("UTF-8");
                response.getWriter().write("{\"success\":false,\"message\":\"Soal tidak ditemukan\"}");
                return;
            }

            // Defense in depth: null out the correct answer so it can NEVER
            // leak to the client, even if the JSON building code changes later.
            q.setCorrectAnswer(null);

            // Get saved answer for this question (safe - only loads selected_answer, never correct_answer)
            String savedAnswer = submissionService.getSavedAnswerForQuestion(submission.getId(), q.getId());

            // Build JSON response (without correctAnswer)
            StringBuilder json = new StringBuilder();
            json.append("{");
            json.append("\"success\":true,");
            json.append("\"questionId\":").append(q.getId()).append(",");
            json.append("\"questionNumber\":").append(questionIndex + 1).append(",");
            json.append("\"totalQuestions\":").append(totalQ).append(",");
            json.append("\"questionText\":").append(escapeJson(q.getQuestionText())).append(",");

            if (q.getImagePath() != null && !q.getImagePath().isEmpty()) {
                json.append("\"imagePath\":\"").append(escapeJson(q.getImagePath())).append("\",");
            }

            json.append("\"optionA\":").append(escapeJson(q.getOptionA())).append(",");
            json.append("\"optionB\":").append(escapeJson(q.getOptionB())).append(",");
            json.append("\"optionC\":").append(escapeJson(q.getOptionC())).append(",");
            json.append("\"optionD\":").append(escapeJson(q.getOptionD())).append(",");

            if (savedAnswer != null) {
                json.append("\"savedAnswer\":\"").append(savedAnswer).append("\",");
            }

            json.append("\"remainingTime\":").append(calculateRemainingTime(submission, quiz));
            json.append("}");

            response.setContentType("application/json");
            response.setCharacterEncoding("UTF-8");
            response.getWriter().write(json.toString());

        } catch (NumberFormatException e) {
            response.setContentType("application/json");
            response.setCharacterEncoding("UTF-8");
            response.getWriter().write("{\"success\":false,\"message\":\"Format parameter tidak valid\"}");
        } catch (Exception e) {
            response.setContentType("application/json");
            response.setCharacterEncoding("UTF-8");
            response.getWriter().write("{\"success\":false,\"message\":\"Terjadi kesalahan\"}");
        }
    }

    private String escapeJson(String value) {
        if (value == null) return "null";
        return "\"" + value
            .replace("\\", "\\\\")
            .replace("\"", "\\\"")
            .replace("\n", "\\n")
            .replace("\r", "\\r")
            .replace("\t", "\\t")
            + "\"";
    }

    /**
     * Check if quiz time has expired based on submission start time and quiz duration
     */
    private boolean isTimeExpired(Submission submission, Quiz quiz) {
        return calculateRemainingTime(submission, quiz) <= 0;
    }

    /**
     * Calculate time spent in seconds since submission started (minus pause)
     */
    private int calculateTimeSpent(Submission submission) {
        if (submission.getStartedAt() == null) {
            return 0;
        }
        LocalDateTime now = LocalDateTime.now();
        Duration elapsed = Duration.between(submission.getStartedAt(), now);
        int pauseSeconds = submission.getAccumulatedPauseSeconds() != null ? submission.getAccumulatedPauseSeconds() : 0;
        return (int) Math.max(0, elapsed.getSeconds() - pauseSeconds);
    }

    /**
     * Calculate remaining time in seconds
     */
    private int calculateRemainingTime(Submission submission, Quiz quiz) {
        if (submission.getStartedAt() == null || quiz.getDuration() == null) {
            return quiz.getDuration() != null ? quiz.getDuration() * 60 : 0;
        }
        LocalDateTime now = LocalDateTime.now();
        Duration elapsed = Duration.between(submission.getStartedAt(), now);
        long totalDurationSeconds = quiz.getDuration() * 60L;
        // Subtract accumulated pause time (time user was offline/tab hidden)
        int pauseSeconds = submission.getAccumulatedPauseSeconds() != null ? submission.getAccumulatedPauseSeconds() : 0;
        long remaining = totalDurationSeconds - elapsed.getSeconds() + pauseSeconds;
        return (int) Math.max(0, remaining);
    }
}
