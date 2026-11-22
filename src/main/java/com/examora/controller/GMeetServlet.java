package com.examora.controller;

import com.examora.dao.MeetLinkDAO;
import com.examora.model.User;
import com.examora.service.QuotaService;
import com.examora.service.UserService;

import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;

import java.io.IOException;

/**
 * GMeetServlet — akses sesi Google Meet / Drive siswa (PRD P1 #14).
 *
 * Perubahan perilaku: tautan TIDAK lagi langsung redirect. Setelah siswa klik
 * menu "Google Meet", sistem menampilkan halaman berisi tautan sesinya.
 *
 *   GET  /GMeetServlet  -> halaman akses: tampilkan info kuota + tombol
 *                          "Tampilkan Tautan (1 Poin)" (belum memotong poin).
 *   POST /GMeetServlet  -> potong 1 poin (khusus role peserta) lalu tampilkan
 *                          kembali tautan siap diklik/di-copy.
 *
 * Sumber tautan: tabel `meet_links` yang dikelola pengajar di menu
 * "Link Google Meet"; fallback ke `users.gdrive_link` untuk data lama.
 * Hanya GET yang menampilkan halaman — pemotongan poin selalu lewat POST agar
 * tidak terpicu prefetch browser.
 */
@WebServlet("/GMeetServlet")
public class GMeetServlet extends HttpServlet {

    /** Tautan yang boleh dibuka lewat pintu berbayar ini (whitelist ketat). */
    private static final String[] ALLOWED_PREFIXES = {
            "https://meet.google.com/",
            "https://drive.google.com/",
            "https://docs.google.com/"
    };

    private QuotaService quotaService;
    private UserService userService;
    private MeetLinkDAO meetLinkDAO;

    @Override
    public void init() throws ServletException {
        quotaService = new QuotaService();
        userService = new UserService();
        meetLinkDAO = new MeetLinkDAO();
    }

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        showAccessPage(request, response, null);
    }

    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        HttpSession session = request.getSession(false);
        User sessionUser = session != null ? (User) session.getAttribute("user") : null;
        if (sessionUser == null) {
            response.sendRedirect(request.getContextPath() + "/LoginServlet");
            return;
        }

        User user = refresh(sessionUser, session);
        String link = resolveLink(user);

        if (!isAllowed(link)) {
            session.setAttribute("flashError",
                    "Tautan sesi belum tersedia. Hubungi pengajar untuk menjadwalkan Google Meet.");
            response.sendRedirect(request.getContextPath() + "/GMeetServlet");
            return;
        }

        // Admin/teacher bebas membuka untuk moderasi (tanpa potong poin).
        if (user.isPeserta()) {
            try {
                int balance = quotaService.consume(user.getId(), "gmeet", "link-access");
                session.setAttribute("flashSuccess",
                        "Akses dibuka. 1 poin terpakai, sisa saldo " + balance + " / "
                                + QuotaService.MAX_QUOTA + " poin.");
                user.setQuotaBalance(balance);
            } catch (QuotaService.ServiceException quotaEx) {
                session.setAttribute("flashError", quotaEx.getMessage());
                response.sendRedirect(request.getContextPath() + "/GMeetServlet");
                return;
            }
        }

        showAccessPage(request, response, link);
    }

    /** Tampilkan halaman akses; {@code unlockedLink} != null berarti sudah dibayar. */
    private void showAccessPage(HttpServletRequest request, HttpServletResponse response, String unlockedLink)
            throws ServletException, IOException {
        HttpSession session = request.getSession();
        User sessionUser = (User) session.getAttribute("user");
        if (sessionUser == null) {
            response.sendRedirect(request.getContextPath() + "/LoginServlet");
            return;
        }
        User user = refresh(sessionUser, session);

        MeetLinkDAO.MeetLink active = null;
        try {
            active = meetLinkDAO.findForStudent(user.getTag(), user.getGradeLevel());
        } catch (Exception ignored) {
            // Tabel meet_links belum ada -> jatuh ke gdrive_link (data lama).
        }

        String link = unlockedLink != null ? unlockedLink : resolveLink(user);
        request.setAttribute("meetUrl", link);
        request.setAttribute("meetTitle",
                active != null && active.title != null ? active.title : "Sesi Belajar Google Meet");
        request.setAttribute("meetSchedule", active != null ? active.scheduleInfo : null);
        request.setAttribute("meetAvailable", isAllowed(link));
        request.setAttribute("unlocked", unlockedLink != null);
        request.setAttribute("isAdminViewer", !user.isPeserta());
        request.getRequestDispatcher("/user/meet-access.jsp").forward(request, response);
    }

    /** Tautan aktif untuk siswa: meet_links dulu, baru kolom gdrive_link lama. */
    private String resolveLink(User user) {
        try {
            MeetLinkDAO.MeetLink link = meetLinkDAO.findForStudent(user.getTag(), user.getGradeLevel());
            if (link != null && isAllowed(link.url)) {
                return link.url;
            }
        } catch (Exception ignored) {
            // lanjut ke fallback
        }
        return user.getGdriveLink() == null ? "" : user.getGdriveLink().trim();
    }

    private User refresh(User sessionUser, HttpSession session) {
        try {
            User fresh = userService.getUserById(sessionUser.getId());
            if (fresh != null) {
                session.setAttribute("user", fresh);
                return fresh;
            }
        } catch (Exception ignored) {
            // pakai data session bila query gagal
        }
        return sessionUser;
    }

    private boolean isAllowed(String link) {
        if (link == null || link.isEmpty()) {
            return false;
        }
        for (String prefix : ALLOWED_PREFIXES) {
            if (link.startsWith(prefix)) {
                return true;
            }
        }
        return false;
    }
}
