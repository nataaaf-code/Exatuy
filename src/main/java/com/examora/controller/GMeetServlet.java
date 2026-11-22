package com.examora.controller;

import com.examora.dao.MeetLinkDAO;
import com.examora.dao.QuotaDAO;
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
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.LocalDate;

/**
 * GMeetServlet — akses sesi Google Meet / Drive siswa (PRD P1 #14).
 *
 * Perubahan perilaku: tautan TIDAK lagi langsung redirect. Setelah siswa klik
 * menu "Google Meet", sistem menampilkan halaman berisi tautan sesinya.
 *
 *   GET  /GMeetServlet  -> tampilkan tautan bila sudah dibayar pada hari WIB ini.
 *   POST /GMeetServlet  -> potong paling banyak 1 poin per tautan per hari WIB.
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
        showAccessPage(request, response);
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
        MeetTarget target = resolveTarget(user);

        if (!isAllowed(target.url)) {
            session.setAttribute("flashError",
                    "Tautan sesi belum tersedia. Hubungi pengajar untuk menjadwalkan Google Meet.");
            response.sendRedirect(request.getContextPath() + "/GMeetServlet");
            return;
        }

        // Admin/teacher bebas membuka untuk moderasi (tanpa potong poin).
        if (user.isPeserta()) {
            try {
                QuotaDAO.GMeetCharge access = quotaService.consumeGMeetOnce(user.getId(),
                        accessReference(target.id, target.url, LocalDate.now(QuotaService.WIB)));
                session.setAttribute("flashSuccess",
                        access.charged ? "Akses dibuka. 1 poin terpakai, sisa saldo " + access.balance
                                + " / " + QuotaService.MAX_QUOTA + " poin."
                                : "Akses sesi ini sudah dibuka hari ini. Tidak ada potongan poin tambahan.");
                user.setQuotaBalance(access.balance);
            } catch (QuotaService.ServiceException quotaEx) {
                session.setAttribute("flashError", quotaEx.getMessage());
                response.sendRedirect(request.getContextPath() + "/GMeetServlet");
                return;
            }
        }

        response.sendRedirect(request.getContextPath() + "/GMeetServlet");
    }

    private void showAccessPage(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        HttpSession session = request.getSession();
        User sessionUser = (User) session.getAttribute("user");
        if (sessionUser == null) {
            response.sendRedirect(request.getContextPath() + "/LoginServlet");
            return;
        }
        User user = refresh(sessionUser, session);

        MeetTarget target = resolveTarget(user);
        boolean available = isAllowed(target.url);
        boolean unlocked = !user.isPeserta();
        if (available && user.isPeserta()) {
            try {
                unlocked = quotaService.hasGMeetAccess(user.getId(),
                        accessReference(target.id, target.url, LocalDate.now(QuotaService.WIB)));
            } catch (QuotaService.ServiceException e) {
                session.setAttribute("flashError", e.getMessage());
            }
        }
        request.setAttribute("meetUrl", target.url);
        request.setAttribute("meetTitle", target.title);
        request.setAttribute("meetSchedule", target.scheduleInfo);
        request.setAttribute("meetAvailable", available);
        request.setAttribute("unlocked", unlocked);
        request.setAttribute("isAdminViewer", !user.isPeserta());
        request.getRequestDispatcher("/user/meet-access.jsp").forward(request, response);
    }

    /** Tautan aktif untuk siswa: meet_links dulu, baru kolom gdrive_link lama. */
    private MeetTarget resolveTarget(User user) {
        try {
            MeetLinkDAO.MeetLink link = meetLinkDAO.findForStudent(user.getTag(), user.getGradeLevel());
            if (link != null && isAllowed(link.url)) {
                return new MeetTarget(link.id, link.url, link.title, link.scheduleInfo);
            }
        } catch (Exception ignored) {
            // lanjut ke fallback
        }
        String url = user.getGdriveLink() == null ? "" : user.getGdriveLink().trim();
        return new MeetTarget(null, url, "Sesi Belajar Google Meet", null);
    }

    static String accessReference(Integer linkId, String url, LocalDate date) {
        try {
            byte[] digest = MessageDigest.getInstance("SHA-256")
                    .digest(url.getBytes(StandardCharsets.UTF_8));
            StringBuilder ref = new StringBuilder("meet:")
                    .append(linkId == null ? "legacy" : linkId).append(':')
                    .append(date).append(':');
            for (byte b : digest) {
                ref.append(Character.forDigit((b >>> 4) & 0xf, 16));
                ref.append(Character.forDigit(b & 0xf, 16));
            }
            return ref.toString();
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException("SHA-256 unavailable", e);
        }
    }

    private static class MeetTarget {
        final Integer id;
        final String url;
        final String title;
        final String scheduleInfo;

        MeetTarget(Integer id, String url, String title, String scheduleInfo) {
            this.id = id;
            this.url = url;
            this.title = title;
            this.scheduleInfo = scheduleInfo;
        }
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
