package com.examora.controller;

import com.examora.dao.BulkEmailDAO;
import com.examora.dao.QuizDAO;
import com.examora.model.Quiz;
import com.examora.model.User;
import com.examora.service.QuotaService;

import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;

import java.io.IOException;
import java.time.Instant;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Locale;

/**
 * Bulk Email Servlet - Pengingat email massal via Gmail Compose dengan penerima di BCC
 */
@WebServlet("/BulkEmailServlet")
public class BulkEmailServlet extends HttpServlet {
    /** Batas penerima per tautan Gmail agar URL tidak terlalu panjang */
    static final int BATCH_SIZE = 40;

    private BulkEmailDAO bulkEmailDAO;
    private QuizDAO quizDAO;

    @Override
    public void init() throws ServletException {
        bulkEmailDAO = new BulkEmailDAO();
        quizDAO = new QuizDAO();
    }

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        HttpSession session = request.getSession(false);
        User currentUser = session != null ? (User) session.getAttribute("user") : null;
        if (currentUser == null || !currentUser.isAdmin()) {
            response.sendRedirect(request.getContextPath() + "/LoginServlet");
            return;
        }

        String group = request.getParameter("group");
        if (group == null || group.isEmpty()) {
            group = "unpaid";
        }
        String grade = request.getParameter("grade");
        Integer quizId = parseIntOrNull(request.getParameter("quizId"));

        try {
            List<Quiz> quizzes = quizDAO.findActive();
            Quiz quiz = null;
            for (Quiz q : quizzes) {
                if (quizId == null || q.getId().equals(quizId)) {
                    quiz = q;
                    break;
                }
            }

            List<User> recipients;
            String subject;
            String body;
            switch (group) {
                case "quota_empty":
                    recipients = bulkEmailDAO.findQuotaEmpty(QuotaService.monthKey(Instant.now()));
                    subject = "Kuota Belajar Exatuy Habis";
                    body = "Halo,\n\nKuota/poin belajar kamu di Exatuy sudah habis. Silakan beli paket kuota "
                            + "(maks. " + QuotaService.MAX_QUOTA + " poin) agar tetap bisa mengikuti Exam dan sesi GMeet.\n\n"
                            + "Terima kasih,\nBimbel Mentari";
                    break;
                case "exam":
                    recipients = quiz != null ? bulkEmailDAO.findExamNotSubmitted(quiz.getId()) : Collections.emptyList();
                    String title = quiz != null ? quiz.getTitle() : "";
                    String deadline = quiz != null && quiz.getDeadline() != null
                            ? " sebelum " + quiz.getDeadline().format(
                                    DateTimeFormatter.ofPattern("d MMMM yyyy HH:mm", new Locale("id", "ID"))) + " WIB"
                            : "";
                    subject = "Pengingat Exam: " + title;
                    body = "Halo,\n\nKamu belum mengerjakan exam \"" + title + "\" di Exatuy. "
                            + "Yuk kerjakan" + deadline + ".\n\nSemangat belajar,\nBimbel Mentari";
                    break;
                case "new_module":
                    recipients = bulkEmailDAO.findStudents(grade);
                    subject = "Materi Belajar Baru di Exatuy";
                    body = "Halo,\n\nAda modul/materi belajar baru di Exatuy. Silakan login untuk mempelajarinya.\n\n"
                            + "Semangat belajar,\nBimbel Mentari";
                    break;
                default:
                    group = "unpaid";
                    recipients = bulkEmailDAO.findUnpaid();
                    subject = "Pengingat Tagihan Kuota Belajar Exatuy";
                    body = "Halo,\n\nKamu masih memiliki tagihan pembelian kuota belajar yang belum dibayar. "
                            + "Silakan selesaikan pembayaran melalui tautan Sumopod di Exatuy.\n\n"
                            + "Terima kasih,\nBimbel Mentari";
            }

            List<String> emails = new ArrayList<>();
            for (User u : recipients) {
                emails.add(u.getEmail());
            }

            request.setAttribute("group", group);
            request.setAttribute("grade", grade);
            request.setAttribute("quiz", quiz);
            request.setAttribute("quizzes", quizzes);
            request.setAttribute("grades", bulkEmailDAO.findGradeLevels());
            request.setAttribute("recipients", recipients);
            request.setAttribute("batches", batches(emails, BATCH_SIZE));
            request.setAttribute("subject", subject);
            request.setAttribute("body", body);
        } catch (Exception e) {
            request.setAttribute("error", "Gagal memuat daftar penerima: " + e.getMessage());
            request.setAttribute("group", group);
        }

        request.getRequestDispatcher("/admin/bulk-email.jsp").forward(request, response);
    }

    static List<List<String>> batches(List<String> items, int size) {
        List<List<String>> result = new ArrayList<>();
        for (int i = 0; i < items.size(); i += size) {
            result.add(items.subList(i, Math.min(i + size, items.size())));
        }
        return result;
    }

    private static Integer parseIntOrNull(String value) {
        try {
            return value != null && !value.isEmpty() ? Integer.valueOf(value) : null;
        } catch (NumberFormatException e) {
            return null;
        }
    }
}
