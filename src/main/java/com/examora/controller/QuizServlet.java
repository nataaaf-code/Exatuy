package com.examora.controller;

import com.examora.model.Quiz;
import com.examora.model.User;
import com.examora.model.Submission;
import com.examora.model.QuizExemption;
import com.examora.service.QuizService;
import com.examora.service.SubmissionService;
import com.examora.dao.QuizExemptionDAO;
import com.examora.dao.QuizParticipantDAO;

import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.time.format.DateTimeParseException;
import java.util.ArrayList;
import java.util.List;

/**
 * Quiz Servlet - Handles quiz CRUD operations for admin
 */
@WebServlet("/QuizServlet")
public class QuizServlet extends HttpServlet {
    private QuizService quizService;
    private SubmissionService submissionService;
    private QuizExemptionDAO quizExemptionDAO;
    private QuizParticipantDAO quizParticipantDAO;

    @Override
    public void init() throws ServletException {
        quizService = new QuizService();
        submissionService = new SubmissionService();
        quizExemptionDAO = new QuizExemptionDAO();
        quizParticipantDAO = new QuizParticipantDAO();
    }

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        // Require admin authentication for all QuizServlet actions
        User user = (User) request.getSession().getAttribute("user");
        if (user == null) {
            response.sendRedirect(request.getContextPath() + "/LoginServlet");
            return;
        }
        if (!user.isAdmin()) {
            response.sendRedirect(request.getContextPath() + "/ExamServlet?action=list");
            return;
        }

        String action = request.getParameter("action");

        try {
            switch (action != null ? action : "list") {
                case "list":
                    listQuizzes(request, response);
                    break;
                case "create":
                    showCreateForm(request, response);
                    break;
                case "edit":
                    showEditForm(request, response);
                    break;
                case "delete":
                    deleteQuiz(request, response);
                    break;
                case "publish":
                    publishQuiz(request, response);
                    break;
                case "unpublish":
                    unpublishQuiz(request, response);
                    break;
                case "view":
                    viewQuiz(request, response);
                    break;
                case "submissions":
                    showSubmissions(request, response);
                    break;
                default:
                    listQuizzes(request, response);
            }
        } catch (QuizService.ServiceException e) {
            request.setAttribute("error", e.getMessage());
            try {
                listQuizzes(request, response);
            } catch (QuizService.ServiceException ex) {
                throw new ServletException(ex);
            }
        }
    }

    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        // Require admin authentication for all QuizServlet actions
        User user = (User) request.getSession().getAttribute("user");
        if (user == null) {
            response.sendRedirect(request.getContextPath() + "/LoginServlet");
            return;
        }
        if (!user.isAdmin()) {
            response.sendRedirect(request.getContextPath() + "/ExamServlet?action=list");
            return;
        }

        String action = request.getParameter("action");

        try {
            switch (action != null ? action : "") {
                case "create":
                    createQuiz(request, response);
                    break;
                case "update":
                    updateQuiz(request, response);
                    break;
                case "updateExemptions":
                    updateExemptions(request, response);
                    break;
                case "updateParticipants":
                    updateParticipants(request, response);
                    break;
                default:
                    listQuizzes(request, response);
            }
        } catch (QuizService.ServiceException e) {
            request.setAttribute("error", e.getMessage());
            try {
                if ("create".equals(action)) {
                    showCreateForm(request, response);
                } else {
                    showEditForm(request, response);
                }
            } catch (QuizService.ServiceException ex) {
                throw new ServletException(ex);
            }
        }
    }

    private void listQuizzes(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException, QuizService.ServiceException {
        User user = (User) request.getSession().getAttribute("user");

        // Check if user is logged in
        if (user == null) {
            response.sendRedirect(request.getContextPath() + "/LoginServlet");
            return;
        }

        List<Quiz> quizzes;

        if (user.isAdmin()) {
            quizzes = quizService.getAllQuizzes();
        } else {
            quizzes = quizService.getQuizzesByCreator(user.getId());
        }

        request.setAttribute("quizzes", quizzes);
        request.getRequestDispatcher("/admin/quiz-list.jsp").forward(request, response);
    }

    private void showCreateForm(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        request.getRequestDispatcher("/admin/quiz-form.jsp").forward(request, response);
    }

    private void showEditForm(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException, QuizService.ServiceException {
        String idStr = request.getParameter("id");
        if (idStr == null || idStr.isEmpty()) {
            response.sendRedirect(request.getContextPath() + "/QuizServlet?action=list");
            return;
        }

        Integer id = Integer.parseInt(idStr);
        Quiz quiz = quizService.getQuizById(id);
        request.setAttribute("quiz", quiz);

        // Load participant data for manual participant selection
        try {
            List<QuizParticipantDAO.ParticipantInfo> currentParticipants = quizParticipantDAO.getParticipantsByQuizId(id);
            List<QuizParticipantDAO.ParticipantInfo> availableUsers = quizParticipantDAO.getAvailableUsers(id);
            request.setAttribute("currentParticipants", currentParticipants);
            request.setAttribute("availableUsers", availableUsers);
        } catch (Exception e) {
            // Ignore if participant tables don't exist
        }

        // Load exemption data
        try {
            List<QuizExemption> currentExemptions = quizExemptionDAO.findByQuizId(id);
            List<QuizExemptionDAO.ExemptableUser> availableExemptableUsers = quizExemptionDAO.getAvailableUsers(id);
            request.setAttribute("currentExemptions", currentExemptions);
            request.setAttribute("availableExemptableUsers", availableExemptableUsers);
        } catch (Exception e) {
            // Ignore if exemption tables don't exist
        }

        request.getRequestDispatcher("/admin/quiz-form.jsp").forward(request, response);
    }

    private void createQuiz(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException, QuizService.ServiceException {
        String title = request.getParameter("title");
        String description = request.getParameter("description");
        String durationStr = request.getParameter("duration");
        String deadlineStr = request.getParameter("deadline");
        String startTimeStr = request.getParameter("startTime");
        String[] targetTags = request.getParameterValues("targetTags");

        Integer duration = durationStr != null && !durationStr.isEmpty() ?
                Integer.parseInt(durationStr) : 30;

        LocalDateTime deadline = parseDeadline(deadlineStr);
        LocalDateTime startTime = parseDeadline(startTimeStr);

        // Handle target tags - join multiple tags with comma
        String targetTag = processTargetTags(targetTags);

        User user = (User) request.getSession().getAttribute("user");

        Quiz quiz = quizService.createQuiz(title, description, duration, user.getId(), deadline, targetTag, startTime);
        String subject = request.getParameter("subject");
        if (subject != null && !subject.trim().isEmpty()) {
            new com.examora.dao.QuizDAO().updateSubject(quiz.getId(), subject.trim());
        }

        request.setAttribute("success", "Quiz berhasil dibuat");
        response.sendRedirect(request.getContextPath() + "/QuestionServlet?action=list&quizId=" + quiz.getId());
    }

    private void updateQuiz(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException, QuizService.ServiceException {
        String idStr = request.getParameter("id");
        String title = request.getParameter("title");
        String description = request.getParameter("description");
        String durationStr = request.getParameter("duration");
        String deadlineStr = request.getParameter("deadline");
        String startTimeStr = request.getParameter("startTime");
        String[] targetTags = request.getParameterValues("targetTags");
        String exemptionTimeStr = request.getParameter("exemptionTime");

        Integer id = Integer.parseInt(idStr);
        Integer duration = durationStr != null && !durationStr.isEmpty() ?
                Integer.parseInt(durationStr) : 30;

        LocalDateTime deadline = parseDeadline(deadlineStr);
        LocalDateTime startTime = parseDeadline(startTimeStr);

        // Handle target tags - join multiple tags with comma
        String targetTag = processTargetTags(targetTags);

        // Parse exemption time (null if empty)
        Integer exemptionTime = null;
        if (exemptionTimeStr != null && !exemptionTimeStr.trim().isEmpty()) {
            try {
                exemptionTime = Integer.parseInt(exemptionTimeStr);
                if (exemptionTime < 1) {
                    exemptionTime = null;
                }
            } catch (NumberFormatException e) {
                exemptionTime = null;
            }
        }

        // Read checkbox values (null if unchecked, meaning false)
        boolean shuffleQuestions = "on".equals(request.getParameter("shuffleQuestions"));
        boolean showReview = "on".equals(request.getParameter("showReview"));

        quizService.updateQuiz(id, title, description, duration, deadline, targetTag, startTime, shuffleQuestions, showReview, exemptionTime);
        String subject = request.getParameter("subject");
        if (subject != null) {
            new com.examora.dao.QuizDAO().updateSubject(id, subject.trim());
        }

        // Process exemptions
        try {
            User currentUser = (User) request.getSession().getAttribute("user");
            String[] exemptedUserIds = request.getParameterValues("exemptedUsers");
            List<Integer> newExemptionUserIds = new ArrayList<>();

            if (exemptedUserIds != null) {
                for (String userIdStr : exemptedUserIds) {
                    newExemptionUserIds.add(Integer.parseInt(userIdStr));
                }
            }

            // Get current exemptions
            List<QuizExemption> currentExemptions = quizExemptionDAO.findByQuizId(id);
            List<Integer> currentUserIds = new ArrayList<>();
            for (QuizExemption ex : currentExemptions) {
                currentUserIds.add(ex.getUserId());
            }

            // Remove exemptions that are no longer selected
            for (QuizExemption ex : currentExemptions) {
                if (!newExemptionUserIds.contains(ex.getUserId())) {
                    quizExemptionDAO.deleteByQuizAndUser(id, ex.getUserId());
                }
            }

            // Add new exemptions
            for (Integer userId : newExemptionUserIds) {
                if (!currentUserIds.contains(userId)) {
                    QuizExemption exemption = new QuizExemption();
                    exemption.setQuizId(id);
                    exemption.setUserId(userId);
                    exemption.setExemptedBy(currentUser.getId());
                    exemption.setNotes("Exempted via quiz form");
                    quizExemptionDAO.create(exemption);
                }
            }
        } catch (Exception e) {
            // Log but don't fail the whole update
            System.err.println("Failed to update exemptions: " + e.getMessage());
        }

        // Process participants
        try {
            String[] participantIds = request.getParameterValues("participants");
            List<Integer> newParticipantUserIds = new ArrayList<>();

            if (participantIds != null) {
                for (String userIdStr : participantIds) {
                    newParticipantUserIds.add(Integer.parseInt(userIdStr));
                }
            }

            // Get current participants
            List<QuizParticipantDAO.ParticipantInfo> currentParticipants = quizParticipantDAO.getParticipantsByQuizId(id);
            List<Integer> currentParticipantUserIds = new ArrayList<>();
            for (QuizParticipantDAO.ParticipantInfo p : currentParticipants) {
                currentParticipantUserIds.add(p.userId);
            }

            // Remove participants that are no longer selected
            for (QuizParticipantDAO.ParticipantInfo p : currentParticipants) {
                if (!newParticipantUserIds.contains(p.userId)) {
                    quizParticipantDAO.removeParticipant(id, p.userId);
                }
            }

            // Add new participants
            for (Integer userId : newParticipantUserIds) {
                if (!currentParticipantUserIds.contains(userId)) {
                    quizParticipantDAO.addParticipant(id, userId);
                }
            }
        } catch (Exception e) {
            // Log but don't fail the whole update
            System.err.println("Failed to update participants: " + e.getMessage());
        }

        request.setAttribute("success", "Quiz berhasil diupdate");
        response.sendRedirect(request.getContextPath() + "/QuizServlet?action=list");
    }

    private LocalDateTime parseDeadline(String deadlineStr) {
        if (deadlineStr == null || deadlineStr.trim().isEmpty()) {
            return null;
        }

        try {
            // Try parsing with datetime-local format: yyyy-MM-ddTHH:mm
            return LocalDateTime.parse(deadlineStr, DateTimeFormatter.ISO_LOCAL_DATE_TIME);
        } catch (DateTimeParseException e1) {
            try {
                // Try parsing with space separator: yyyy-MM-dd HH:mm
                return LocalDateTime.parse(deadlineStr.replace(" ", "T"),
                    DateTimeFormatter.ISO_LOCAL_DATE_TIME);
            } catch (DateTimeParseException e2) {
                return null;
            }
        }
    }

    /**
     * Process target tags from form - join multiple tags with comma
     * Returns null if "ALL" or no tags selected (means all users)
     */
    private String processTargetTags(String[] targetTags) {
        if (targetTags == null || targetTags.length == 0) {
            return null;
        }

        // Check if "ALL" is selected
        for (String tag : targetTags) {
            if ("ALL".equals(tag)) {
                return null;
            }
        }

        // Filter out empty strings and join with comma
        StringBuilder sb = new StringBuilder();
        for (String tag : targetTags) {
            if (tag != null && !tag.trim().isEmpty()) {
                if (sb.length() > 0) {
                    sb.append(",");
                }
                sb.append(tag.trim());
            }
        }

        return sb.length() > 0 ? sb.toString() : null;
    }

    private void updateExemptions(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        String quizIdStr = request.getParameter("id");
        if (quizIdStr == null || quizIdStr.isEmpty()) {
            quizIdStr = request.getParameter("quizId");
        }

        if (quizIdStr == null || quizIdStr.isEmpty()) {
            response.sendRedirect(request.getContextPath() + "/QuizServlet?action=list");
            return;
        }

        try {
            Integer quizId = Integer.parseInt(quizIdStr);
            User currentUser = (User) request.getSession().getAttribute("user");

            // Get selected exempted users
            String[] exemptedUserIds = request.getParameterValues("exemptedUsers");
            List<Integer> newExemptionUserIds = new ArrayList<>();

            if (exemptedUserIds != null) {
                for (String userIdStr : exemptedUserIds) {
                    newExemptionUserIds.add(Integer.parseInt(userIdStr));
                }
            }

            // Get current exemptions
            List<QuizExemption> currentExemptions = quizExemptionDAO.findByQuizId(quizId);
            List<Integer> currentUserIds = new ArrayList<>();
            for (QuizExemption ex : currentExemptions) {
                currentUserIds.add(ex.getUserId());
            }

            // Remove exemptions that are no longer selected
            for (QuizExemption ex : currentExemptions) {
                if (!newExemptionUserIds.contains(ex.getUserId())) {
                    quizExemptionDAO.deleteByQuizAndUser(quizId, ex.getUserId());
                }
            }

            // Add new exemptions
            for (Integer userId : newExemptionUserIds) {
                if (!currentUserIds.contains(userId)) {
                    QuizExemption exemption = new QuizExemption();
                    exemption.setQuizId(quizId);
                    exemption.setUserId(userId);
                    exemption.setExemptedBy(currentUser.getId());
                    exemption.setNotes("Exempted via quiz form");
                    quizExemptionDAO.create(exemption);
                }
            }

            response.sendRedirect(request.getContextPath() + "/QuizServlet?action=edit&id=" + quizId + "&success=exemptions_updated");
        } catch (Exception e) {
            request.setAttribute("error", "Gagal update exemptions: " + e.getMessage());
            response.sendRedirect(request.getContextPath() + "/QuizServlet?action=list");
        }
    }

    private void updateParticipants(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        String quizIdStr = request.getParameter("id");
        if (quizIdStr == null || quizIdStr.isEmpty()) {
            quizIdStr = request.getParameter("quizId");
        }

        if (quizIdStr == null || quizIdStr.isEmpty()) {
            response.sendRedirect(request.getContextPath() + "/QuizServlet?action=list");
            return;
        }

        try {
            Integer quizId = Integer.parseInt(quizIdStr);

            // Get selected participants
            String[] participantIds = request.getParameterValues("participants");
            List<Integer> newParticipantUserIds = new ArrayList<>();

            if (participantIds != null) {
                for (String userIdStr : participantIds) {
                    newParticipantUserIds.add(Integer.parseInt(userIdStr));
                }
            }

            // Get current participants
            List<QuizParticipantDAO.ParticipantInfo> currentParticipants = quizParticipantDAO.getParticipantsByQuizId(quizId);
            List<Integer> currentUserIds = new ArrayList<>();
            for (QuizParticipantDAO.ParticipantInfo p : currentParticipants) {
                currentUserIds.add(p.userId);
            }

            // Remove participants that are no longer selected
            for (QuizParticipantDAO.ParticipantInfo p : currentParticipants) {
                if (!newParticipantUserIds.contains(p.userId)) {
                    quizParticipantDAO.removeParticipant(quizId, p.userId);
                }
            }

            // Add new participants
            for (Integer userId : newParticipantUserIds) {
                if (!currentUserIds.contains(userId)) {
                    quizParticipantDAO.addParticipant(quizId, userId);
                }
            }

            response.sendRedirect(request.getContextPath() + "/QuizServlet?action=edit&id=" + quizId + "&success=participants_updated");
        } catch (Exception e) {
            request.setAttribute("error", "Gagal update participants: " + e.getMessage());
            response.sendRedirect(request.getContextPath() + "/QuizServlet?action=list");
        }
    }

    private void deleteQuiz(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException, QuizService.ServiceException {
        String idStr = request.getParameter("id");
        if (idStr != null && !idStr.isEmpty()) {
            Integer id = Integer.parseInt(idStr);
            quizService.deleteQuiz(id);
            request.setAttribute("success", "Quiz berhasil dihapus");
        }
        response.sendRedirect(request.getContextPath() + "/QuizServlet?action=list");
    }

    private void publishQuiz(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException, QuizService.ServiceException {
        String idStr = request.getParameter("id");
        if (idStr != null && !idStr.isEmpty()) {
            Integer id = Integer.parseInt(idStr);
            quizService.publishQuiz(id);
            request.setAttribute("success", "Quiz berhasil dipublish");
        }
        response.sendRedirect(request.getContextPath() + "/QuizServlet?action=list");
    }

    private void unpublishQuiz(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException, QuizService.ServiceException {
        String idStr = request.getParameter("id");
        if (idStr != null && !idStr.isEmpty()) {
            Integer id = Integer.parseInt(idStr);
            quizService.unpublishQuiz(id);
            request.setAttribute("success", "Quiz berhasil di-unpublish");
        }
        response.sendRedirect(request.getContextPath() + "/QuizServlet?action=list");
    }

    private void viewQuiz(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException, QuizService.ServiceException {
        String idStr = request.getParameter("id");
        if (idStr == null || idStr.isEmpty()) {
            response.sendRedirect(request.getContextPath() + "/QuizServlet?action=list");
            return;
        }

        Integer id = Integer.parseInt(idStr);
        Quiz quiz = quizService.getQuizById(id);
        request.setAttribute("quiz", quiz);
        request.setAttribute("questions", quizService.getQuestions(id));
        request.getRequestDispatcher("/admin/quiz-view.jsp").forward(request, response);
    }

    private void showSubmissions(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        String idStr = request.getParameter("id");
        if (idStr == null || idStr.isEmpty()) {
            response.sendRedirect(request.getContextPath() + "/QuizServlet?action=list");
            return;
        }

        int quizId;
        try {
            quizId = Integer.parseInt(idStr);
        } catch (NumberFormatException e) {
            response.sendRedirect(request.getContextPath() + "/QuizServlet?action=list&error=invalid_quiz_id");
            return;
        }

        try {
            Quiz quiz = quizService.getQuizById(quizId);
            if (quiz == null) {
                response.sendRedirect(request.getContextPath() + "/QuizServlet?action=list&error=quiz_not_found");
                return;
            }

            request.setAttribute("quiz", quiz);

            // Get all submissions for this quiz
            java.util.List<Submission> allSubmissions = submissionService.getSubmissionsByQuizAndStatus(quizId, "completed");
            request.setAttribute("submissions", allSubmissions);

            // Get timeout submissions specifically
            java.util.List<Submission> timeoutSubmissions = submissionService.getSubmissionsByQuizAndStatus(quizId, "timeout");
            request.setAttribute("timeoutSubmissions", timeoutSubmissions);

            // Get status counts
            java.util.Map<String, Integer> statusCounts = submissionService.getStatusCounts(quizId);
            request.setAttribute("statusCounts", statusCounts);

            request.getRequestDispatcher("/admin/quiz-submissions.jsp").forward(request, response);
        } catch (Exception e) {
            request.setAttribute("error", "Gagal memuat submissions: " + e.getMessage());
            response.sendRedirect(request.getContextPath() + "/QuizServlet?action=list&error=" + e.getMessage());
        }
    }


    private void resetTimeout(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        String quizIdStr = request.getParameter("quizId");
        if (quizIdStr == null || quizIdStr.isEmpty()) {
            response.sendRedirect(request.getContextPath() + "/QuizServlet?action=list");
            return;
        }

        int quizId;
        try {
            quizId = Integer.parseInt(quizIdStr);
        } catch (NumberFormatException e) {
            response.sendRedirect(request.getContextPath() + "/QuizServlet?action=list&error=invalid_quiz_id");
            return;
        }

        try {
            // Verify quiz exists
            Quiz quiz = quizService.getQuizById(quizId);
            if (quiz == null) {
                response.sendRedirect(request.getContextPath() + "/QuizServlet?action=list&error=quiz_not_found");
                return;
            }

            // Reset all timeout submissions
            int resetCount = submissionService.resetTimeoutSubmissions(quizId);

            response.sendRedirect(request.getContextPath() + "/QuizServlet?action=submissions&id=" + quizId + "&success=" + resetCount);
        } catch (Exception e) {
            response.sendRedirect(request.getContextPath() + "/QuizServlet?action=list&error=" + e.getMessage());
        }
    }
}
