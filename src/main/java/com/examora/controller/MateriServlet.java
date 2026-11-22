package com.examora.controller;

import com.examora.dao.MaterialCategoryDAO;
import com.examora.dao.MaterialDAO;
import com.examora.model.Material;
import com.examora.model.MaterialCategory;
import com.examora.model.User;
import com.examora.util.ValidationUtil;

import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.MultipartConfig;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.*;

import java.io.IOException;
import java.io.InputStream;
import java.nio.file.*;
import java.sql.SQLException;
import java.util.List;
import java.util.Locale;
import java.util.UUID;

@WebServlet("/MateriServlet")
@MultipartConfig(fileSizeThreshold = 10 * 1024 * 1024, maxFileSize = 50 * 1024 * 1024, maxRequestSize = 100 * 1024 * 1024)
public class MateriServlet extends HttpServlet {
    private MaterialCategoryDAO categoryDAO;
    private MaterialDAO materialDAO;

    @Override
    public void init() throws ServletException {
        categoryDAO = new MaterialCategoryDAO();
        materialDAO = new MaterialDAO();
    }

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        HttpSession session = request.getSession(false);
        User currentUser = session == null ? null : (User) session.getAttribute("user");
        String action = request.getParameter("action");

        // Show to anyone logged in
        if (currentUser == null) {
            response.sendRedirect("../LoginServlet");
            return;
        }

        boolean isAdmin = "admin".equals(currentUser.getRole()) || "owner".equals(currentUser.getRole()) || "pengajar".equals(currentUser.getRole());

        try {
            if ("list".equals(action) || action == null) {
                showList(request, response, currentUser, isAdmin);
            } else if ("adminList".equals(action)) {
                if (!isAdmin) {
                    response.sendError(HttpServletResponse.SC_FORBIDDEN);
                    return;
                }
                showAdminList(request, response);
            } else if ("view".equals(action)) {
                int id = Integer.parseInt(request.getParameter("id"));
                Material mat = isAdmin ? materialDAO.findById(id) : materialDAO.findVisibleById(id, currentUser.getTag());
                if (mat != null && (isAdmin || Boolean.TRUE.equals(mat.getIsActive()))) {
                    materialDAO.incrementViewCount(id);
                    request.setAttribute("material", mat);
                    request.getRequestDispatcher("/user/materi-view.jsp").forward(request, response);
                } else {
                    response.sendError(HttpServletResponse.SC_NOT_FOUND);
                }
            } else if ("download".equals(action)) {
                int id = Integer.parseInt(request.getParameter("id"));
                Material mat = isAdmin ? materialDAO.findById(id) : materialDAO.findVisibleById(id, currentUser.getTag());
                if (mat == null || (!isAdmin && !Boolean.TRUE.equals(mat.getIsActive()))
                        || !isSafeFileName(mat.getFilePath())) {
                    response.sendError(HttpServletResponse.SC_NOT_FOUND);
                    return;
                }
                Path file = materialsDirectory().resolve(mat.getFilePath());
                if (!Files.isRegularFile(file)) {
                    response.sendError(HttpServletResponse.SC_NOT_FOUND);
                    return;
                }
                response.setContentType(getContentType(mat.getFilePath()));
                response.setHeader("X-Content-Type-Options", "nosniff");
                response.setHeader("Content-Disposition",
                        "attachment; filename=\"materi-" + id + "." + fileExtension(mat.getFilePath()) + "\"");
                Files.copy(file, response.getOutputStream());
                materialDAO.logDownload(id, currentUser.getId());
            } else {
                showList(request, response, currentUser, isAdmin);
            }
        } catch (Exception e) {
            request.setAttribute("error", "Error: " + e.getMessage());
            try {
                showList(request, response, currentUser, isAdmin);
            } catch (Exception ex) {
                throw new ServletException(ex);
            }
        }
    }

    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        HttpSession session = request.getSession(false);
        User currentUser = session == null ? null : (User) session.getAttribute("user");
        if (currentUser == null) {
            response.sendRedirect("../LoginServlet");
            return;
        }
        boolean isAdmin = "admin".equals(currentUser.getRole()) || "owner".equals(currentUser.getRole()) || "pengajar".equals(currentUser.getRole());
        if (!isAdmin) {
            response.sendRedirect("../LoginServlet");
            return;
        }

        String action = request.getParameter("action");
        try {
            if ("create".equals(action)) {
                createMaterial(request, response, currentUser);
            } else if ("update".equals(action)) {
                updateMaterial(request, response, currentUser);
            } else if ("delete".equals(action)) {
                int id = Integer.parseInt(request.getParameter("id"));
                materialDAO.delete(id);
                request.getSession().setAttribute("flashSuccess", "Materi berhasil dihapus");
                response.sendRedirect("../MateriServlet?action=adminList");
            } else if ("generate".equals(action)) {
                generateMaterial(request, response, currentUser);
            } else {
                response.sendRedirect("../MateriServlet?action=adminList");
            }
        } catch (Exception e) {
            request.getSession().setAttribute("flashError", "Error: " + e.getMessage());
            response.sendRedirect("../MateriServlet?action=adminList");
        }
    }

    private void showList(HttpServletRequest request, HttpServletResponse response, User user, boolean isAdmin)
            throws ServletException, IOException, SQLException {
        String tag = user.getTag();
        List<Material> materials = isAdmin ? materialDAO.findAll() : materialDAO.findByTag(tag);
        List<MaterialCategory> categories = categoryDAO.findAll();
        request.setAttribute("materials", materials);
        request.setAttribute("categories", categories);
        request.setAttribute("isAdmin", isAdmin);
        request.setAttribute("userTag", tag);
        request.getRequestDispatcher(isAdmin ? "/admin/materi-admin.jsp" : "/user/materi-list.jsp").forward(request, response);
    }

    private void showAdminList(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException, SQLException {
        List<Material> materials = materialDAO.findAll();
        List<MaterialCategory> categories = categoryDAO.findAll();
        request.setAttribute("materials", materials);
        request.setAttribute("categories", categories);
        request.getRequestDispatcher("/admin/materi-admin.jsp").forward(request, response);
    }

    private void createMaterial(HttpServletRequest request, HttpServletResponse response, User user)
            throws IOException, ServletException, SQLException {
        int categoryId = Integer.parseInt(request.getParameter("category_id"));
        String title = request.getParameter("title");
        String summary = request.getParameter("summary");
        String targetTags = request.getParameter("target_tags");
        String fileType = request.getParameter("file_type");
        String content = request.getParameter("content");
        if (title == null || title.isBlank() || title.length() > 255 || categoryDAO.findById(categoryId) == null) {
            throw new IllegalArgumentException("Judul atau kategori materi tidak valid.");
        }

        Material material = new Material();
        material.setCategoryId(categoryId);
        material.setTitle(title);
        material.setSummary(summary);
        material.setTargetTags(targetTags);
        material.setFileType(fileType);
        material.setContent(content);
        material.setIsActive(true);
        material.setIsGenerated(false);
        material.setGeneratedById(user.getId());

        // Handle file upload
        Part filePart = request.getPart("file");
        if (filePart != null && filePart.getSize() > 0) {
            String extension = fileExtension(filePart.getSubmittedFileName());
            if (!isAllowedExtension(extension)) {
                throw new IllegalArgumentException("File materi harus PDF, DOC, DOCX, JPG, atau PNG.");
            }
            String fileName = UUID.randomUUID() + "." + extension;
            Path directory = materialsDirectory();
            Files.createDirectories(directory);
            try (InputStream input = filePart.getInputStream()) {
                Files.copy(input, directory.resolve(fileName));
            }
            material.setFilePath(fileName);
            material.setFileType("jpg".equals(extension) || "jpeg".equals(extension) || "png".equals(extension)
                    ? "image" : extension);
            material.setFileSize(filePart.getSize());
        }

        materialDAO.create(material);
        request.getSession().setAttribute("flashSuccess", "Materi berhasil ditambahkan");
        response.sendRedirect("../MateriServlet?action=adminList");
    }

    private void updateMaterial(HttpServletRequest request, HttpServletResponse response, User user)
            throws IOException, ServletException, SQLException {
        int id = Integer.parseInt(request.getParameter("id"));
        String title = request.getParameter("title");
        String summary = request.getParameter("summary");
        String targetTags = request.getParameter("target_tags");
        String content = request.getParameter("content");

        Material material = materialDAO.findById(id);
        if (material != null) {
            material.setTitle(title);
            material.setSummary(summary);
            material.setTargetTags(targetTags);
            material.setContent(content);
            materialDAO.update(material);
            request.getSession().setAttribute("flashSuccess", "Materi berhasil diupdate");
        }
        response.sendRedirect("../MateriServlet?action=adminList");
    }

    private void generateMaterial(HttpServletRequest request, HttpServletResponse response, User user)
            throws ServletException, IOException, SQLException {
        int categoryId = Integer.parseInt(request.getParameter("category_id"));
        String jenjang = request.getParameter("jenjang");
        String mataPelajaran = request.getParameter("mata_pelajaran");

        MaterialCategory category = categoryDAO.findById(categoryId);
        if (category == null) {
            request.getSession().setAttribute("flashError", "Kategori tidak ditemukan");
            response.sendRedirect("../MateriServlet?action=adminList");
            return;
        }

        // Generate template content
        String content = generateSyllabusTemplate(category.getNama(), jenjang, mataPelajaran);

        Material material = new Material();
        material.setCategoryId(categoryId);
        material.setTitle("Silabus " + category.getNama());
        material.setContent(content);
        material.setSummary("Silabus otomatis untuk " + category.getNama() + " (" + jenjang + ")");
        material.setFileType("text");
        material.setTargetTags(null);
        material.setIsGenerated(true);
        material.setGeneratedById(user.getId());
        materialDAO.create(material);

        request.getSession().setAttribute("flashSuccess", "Silabus berhasil digenerate!");
        response.sendRedirect("../MateriServlet?action=adminList");
    }

    private String generateSyllabusTemplate(String categoryName, String jenjang, String mataPelajaran) {
        return "SILABUS " + categoryName.toUpperCase() + "\n" +
               "=".repeat(50) + "\n\n" +
               "Jenjang: " + jenjang + "\n" +
               "Mata Pelajaran: " + mataPelajaran + "\n\n" +
               "A. KOMPETENSI AWAL\n" +
               "- Siswa mampu memahami konsep dasar " + mataPelajaran.toLowerCase() + "\n" +
               "- Siswa mampu menerapkan pengetahuan dalam soal-soal\n\n" +
               "B. KOMPETENSI INTI\n" +
               "- KI-1: Menghargai dan menghayati ajaran agama yang dianutnya\n" +
               "- KI-2: Menunjukkan perilaku jujur, disiplin, tanggung jawab\n" +
               "- KI-3: Memahami dan menerapkan pengetahuan faktual dan konseptual\n" +
               "- KI-4: Mengolah, menalar, dan menyaji dalam ranah konkret\n\n" +
               "C. KOMPETENSI DASAR & MATERI\n" +
               "1. Pertemuan 1-4: Pengantar dan konsep dasar\n" +
               "   - Mendengarkan penjelasan materi\n" +
               "   - Diskusi kelompok\n" +
               "   - Latihan soal dasar\n\n" +
               "2. Pertemuan 5-8: Pembahasan topik utama\n" +
               "   - Pemodelan masalah\n" +
               "   - Solusi terstruktur\n" +
               "   - Pre-test dan post-test\n\n" +
               "3. Pertemuan 9-12: Review dan evaluasi\n" +
               "   - Summary materi\n" +
               "   - Try-out / simulasi ujian\n" +
               "   - Review jawaban\n\n" +
               "D. PENILAIAN\n" +
               "- Pre-test: 20%\n" +
               "- Post-test: 30%\n" +
               "- Tugas: 20%\n" +
               "- Ujian Akhir: 30%\n\n" +
               "E. INDIKATOR KETUNTASAN\n" +
               "- Minimal 70% untuk kategori LULUS\n" +
               "- Remedial bagi yang mendapat nilai < 70\n" +
               "- Pengayaan bagi yang mendapat nilai > 85\n";
    }

    private Path materialsDirectory() {
        String uploads = System.getenv("EXATUY_UPLOADS_DIR");
        if (uploads != null && !uploads.isBlank()) {
            return Paths.get(uploads, "materials");
        }
        // Keep files outside the deployed webapp so a direct URL cannot bypass tag checks.
        return Paths.get(System.getProperty("catalina.base", System.getProperty("user.home")),
                "uploads", "materials");
    }

    static String fileExtension(String name) {
        if (name == null) return "";
        int dot = name.lastIndexOf('.');
        return dot < 0 ? "" : name.substring(dot + 1).toLowerCase(Locale.ROOT);
    }

    static boolean isAllowedExtension(String extension) {
        return "pdf".equals(extension) || "doc".equals(extension) || "docx".equals(extension)
                || "jpg".equals(extension) || "jpeg".equals(extension) || "png".equals(extension);
    }

    static boolean isSafeFileName(String name) {
        return name != null && !name.isBlank() && !name.contains("/") && !name.contains("\\")
                && !name.equals(".") && !name.equals("..") && isAllowedExtension(fileExtension(name));
    }

    private String getContentType(String name) {
        switch (fileExtension(name)) {
            case "pdf": return "application/pdf";
            case "doc": return "application/msword";
            case "docx": return "application/vnd.openxmlformats-officedocument.wordprocessingml.document";
            case "png": return "image/png";
            case "jpg": case "jpeg": return "image/jpeg";
            default: return "application/octet-stream";
        }
    }
}
