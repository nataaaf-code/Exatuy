package com.examora.controller;

import com.examora.dao.MeetLinkDAO;
import com.examora.model.User;

import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;

import java.io.IOException;

/**
 * MeetLinkServlet — pengelolaan tautan Google Meet / Drive oleh pengajar (admin).
 *
 * Route: /MeetLinkServlet
 *   GET  ?                     -> daftar + form (mode tambah)
 *   GET  ?edit=<id>            -> form dalam mode edit
 *   POST action=create|update|delete|toggle
 */
@WebServlet("/MeetLinkServlet")
public class MeetLinkServlet extends HttpServlet {

    private final MeetLinkDAO meetLinkDAO = new MeetLinkDAO();

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        if (!requireAdmin(request, response)) {
            return;
        }
        try {
            request.setAttribute("meetLinks", meetLinkDAO.findAll());
            String editId = request.getParameter("edit");
            if (editId != null && !editId.isBlank()) {
                request.setAttribute("editLink", meetLinkDAO.findById(Integer.parseInt(editId)));
            }
        } catch (Exception e) {
            request.setAttribute("error", "Gagal memuat tautan: " + e.getMessage());
        }
        request.getRequestDispatcher("/admin/meet-links.jsp").forward(request, response);
    }

    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        if (!requireAdmin(request, response)) {
            return;
        }
        HttpSession session = request.getSession();
        String action = request.getParameter("action");
        try {
            if ("create".equalsIgnoreCase(action)) {
                meetLinkDAO.create(readForm(request), userId(request));
                session.setAttribute("flashSuccess", "Tautan Google Meet berhasil ditambahkan.");
            } else if ("update".equalsIgnoreCase(action)) {
                MeetLinkDAO.MeetLink link = readForm(request);
                link.id = Integer.parseInt(request.getParameter("id"));
                meetLinkDAO.update(link);
                session.setAttribute("flashSuccess", "Tautan berhasil diperbarui.");
            } else if ("delete".equalsIgnoreCase(action)) {
                meetLinkDAO.delete(Integer.parseInt(request.getParameter("id")));
                session.setAttribute("flashSuccess", "Tautan dihapus.");
            } else if ("toggle".equalsIgnoreCase(action)) {
                meetLinkDAO.toggleActive(Integer.parseInt(request.getParameter("id")));
                session.setAttribute("flashSuccess", "Status tautan diubah.");
            }
        } catch (Exception e) {
            session.setAttribute("flashError", "Gagal menyimpan tautan: " + e.getMessage());
        }
        response.sendRedirect(request.getContextPath() + "/MeetLinkServlet");
    }

    private MeetLinkDAO.MeetLink readForm(HttpServletRequest request) {
        MeetLinkDAO.MeetLink link = new MeetLinkDAO.MeetLink();
        link.title = trim(request.getParameter("title"));
        link.url = trim(request.getParameter("url"));
        link.targetTag = trim(request.getParameter("targetTag"));
        link.targetGrade = trim(request.getParameter("targetGrade"));
        link.scheduleInfo = trim(request.getParameter("scheduleInfo"));
        link.isActive = request.getParameter("isActive") != null;
        return link;
    }

    private String trim(String value) {
        return value == null ? null : value.trim();
    }

    private Integer userId(HttpServletRequest request) {
        User user = (User) request.getSession().getAttribute("user");
        return user == null ? null : user.getId();
    }

    private boolean requireAdmin(HttpServletRequest request, HttpServletResponse response) throws IOException {
        HttpSession session = request.getSession(false);
        User user = session == null ? null : (User) session.getAttribute("user");
        if (user == null) {
            response.sendRedirect(request.getContextPath() + "/LoginServlet");
            return false;
        }
        if (!user.isAdmin() && !"owner".equals(user.getRole())) {
            response.sendError(HttpServletResponse.SC_FORBIDDEN, "Hanya pengajar yang boleh mengelola tautan.");
            return false;
        }
        return true;
    }
}
