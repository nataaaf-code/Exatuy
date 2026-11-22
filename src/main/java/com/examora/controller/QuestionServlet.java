package com.examora.controller;

import com.examora.model.Question;
import com.examora.model.Quiz;
import com.examora.service.QuizService;

import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.MultipartConfig;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.Part;
import javax.imageio.ImageIO;
import java.awt.image.BufferedImage;
import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.StandardCopyOption;
import java.util.Arrays;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.UUID;

/**
 * Question Servlet - Handles question CRUD operations
 */
@WebServlet("/QuestionServlet")
@MultipartConfig(
    fileSizeThreshold = 1024 * 1024,      // 1 MB
    maxFileSize = 1024 * 1024 * 2,        // 2 MB (batas gambar soal, PRD #19)
    maxRequestSize = 1024 * 1024 * 6      // 6 MB (gambar 2 MB + field form)
)
public class QuestionServlet extends HttpServlet {
    private QuizService quizService;

    // External upload directory (mounted volume in Docker container)
    private static final String UPLOAD_BASE_DIR = "/app/uploads";
    private static final String UPLOAD_SUBDIR = "questions";

    // Web path for accessing files via FileServlet
    private static final String WEB_PATH_PREFIX = "uploads/questions";

    // Allowed image MIME types
    private static final Set<String> ALLOWED_MIME_TYPES = new HashSet<>(Arrays.asList(
        "image/jpeg", "image/png", "image/gif", "image/webp"
    ));

    // Allowed file extensions (lowercase)
    private static final Set<String> ALLOWED_EXTENSIONS = new HashSet<>(Arrays.asList(
        ".jpg", ".jpeg", ".png", ".gif", ".webp"
    ));

    // Maximum file size: 2MB (PRD #19 — diseragamkan dengan batas upload soal)
    private static final long MAX_FILE_SIZE = 2 * 1024 * 1024;

    @Override
    public void init() throws ServletException {
        quizService = new QuizService();
    }

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        String action = request.getParameter("action");
        String quizIdStr = request.getParameter("quizId");

        if (quizIdStr == null || quizIdStr.isEmpty()) {
            response.sendRedirect(request.getContextPath() + "/QuizServlet?action=list");
            return;
        }

        try {
            Integer quizId = Integer.parseInt(quizIdStr);
            Quiz quiz = quizService.getQuizById(quizId);
            request.setAttribute("quiz", quiz);

            switch (action != null ? action : "list") {
                case "list":
                    listQuestions(request, response, quizId);
                    break;
                case "create":
                    showCreateForm(request, response, quizId);
                    break;
                case "edit":
                    showEditForm(request, response, quizId);
                    break;
                case "delete":
                    deleteQuestion(request, response, quizId);
                    break;
                default:
                    listQuestions(request, response, quizId);
            }
        } catch (QuizService.ServiceException e) {
            request.setAttribute("error", e.getMessage());
            try {
                listQuestions(request, response, Integer.parseInt(quizIdStr));
            } catch (QuizService.ServiceException ex) {
                throw new ServletException(ex);
            }
        }
    }

    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        String action = request.getParameter("action");
        String quizIdStr = request.getParameter("quizId");

        if (quizIdStr == null || quizIdStr.isEmpty()) {
            response.sendRedirect(request.getContextPath() + "/QuizServlet?action=list");
            return;
        }

        try {
            Integer quizId = Integer.parseInt(quizIdStr);
            Quiz quiz = quizService.getQuizById(quizId);
            request.setAttribute("quiz", quiz);

            switch (action != null ? action : "") {
                case "create":
                    createQuestion(request, response, quizId);
                    break;
                case "update":
                    updateQuestion(request, response, quizId);
                    break;
                default:
                    listQuestions(request, response, quizId);
            }
        } catch (QuizService.ServiceException e) {
            request.setAttribute("error", e.getMessage());
            try {
                listQuestions(request, response, Integer.parseInt(quizIdStr));
            } catch (QuizService.ServiceException ex) {
                throw new ServletException(ex);
            }
        }
    }

    private void listQuestions(HttpServletRequest request, HttpServletResponse response, Integer quizId)
            throws ServletException, IOException, QuizService.ServiceException {
        List<Question> questions = quizService.getQuestions(quizId);
        request.setAttribute("questions", questions);
        request.getRequestDispatcher("/admin/question-list.jsp").forward(request, response);
    }

    private void showCreateForm(HttpServletRequest request, HttpServletResponse response, Integer quizId)
            throws ServletException, IOException {
        request.getRequestDispatcher("/admin/question-form.jsp").forward(request, response);
    }

    private void showEditForm(HttpServletRequest request, HttpServletResponse response, Integer quizId)
            throws ServletException, IOException, QuizService.ServiceException {
        String idStr = request.getParameter("id");
        if (idStr == null || idStr.isEmpty()) {
            response.sendRedirect(request.getContextPath() + "/QuestionServlet?action=list&quizId=" + quizId);
            return;
        }

        Integer id = Integer.parseInt(idStr);
        List<Question> questions = quizService.getQuestions(quizId);
        Question question = questions.stream()
                .filter(q -> q.getId().equals(id))
                .findFirst()
                .orElse(null);

        if (question == null) {
            request.setAttribute("error", "Pertanyaan tidak ditemukan");
            listQuestions(request, response, quizId);
            return;
        }

        request.setAttribute("question", question);
        request.getRequestDispatcher("/admin/question-form.jsp").forward(request, response);
    }

    private void createQuestion(HttpServletRequest request, HttpServletResponse response, Integer quizId)
            throws ServletException, IOException, QuizService.ServiceException {
        String questionText = request.getParameter("questionText");
        String optionA = request.getParameter("optionA");
        String optionB = request.getParameter("optionB");
        String optionC = request.getParameter("optionC");
        String optionD = request.getParameter("optionD");
        String correctAnswer = request.getParameter("correctAnswer");
        String saveAndAdd = request.getParameter("saveAndAdd");

        // New enhancement fields
        String categoryIdStr = request.getParameter("categoryId");
        String explanation = request.getParameter("explanation");

        Integer categoryId = null;
        if (categoryIdStr != null && !categoryIdStr.isEmpty()) {
            try {
                categoryId = Integer.parseInt(categoryIdStr);
            } catch (NumberFormatException e) {
                // Ignore invalid category ID
            }
        }

        // Handle image upload
        String imagePath = null;
        try {
            Part imagePart = request.getPart("questionImage");
            if (imagePart != null && imagePart.getSize() > 0) {
                imagePath = saveImage(imagePart, getServletContext().getRealPath("/"));
            }
        } catch (Exception e) {
            // Log error but continue without image
            System.err.println("Error uploading image: " + e.getMessage());
        }

        quizService.addQuestion(quizId, questionText, imagePath, optionA, optionB, optionC, optionD, correctAnswer, categoryId, explanation);

        if ("true".equals(saveAndAdd)) {
            // Redirect back to create form for adding more questions
            response.sendRedirect(request.getContextPath() + "/QuestionServlet?action=create&quizId=" + quizId + "&success=true");
        } else {
            request.setAttribute("success", "Pertanyaan berhasil ditambahkan");
            response.sendRedirect(request.getContextPath() + "/QuestionServlet?action=list&quizId=" + quizId);
        }
    }

    private void updateQuestion(HttpServletRequest request, HttpServletResponse response, Integer quizId)
            throws ServletException, IOException, QuizService.ServiceException {
        String idStr = request.getParameter("id");
        String questionText = request.getParameter("questionText");
        String optionA = request.getParameter("optionA");
        String optionB = request.getParameter("optionB");
        String optionC = request.getParameter("optionC");
        String optionD = request.getParameter("optionD");
        String correctAnswer = request.getParameter("correctAnswer");
        String removeImage = request.getParameter("removeImage");

        // New enhancement fields
        String categoryIdStr = request.getParameter("categoryId");
        String explanation = request.getParameter("explanation");

        Integer categoryId = null;
        if (categoryIdStr != null && !categoryIdStr.isEmpty()) {
            try {
                categoryId = Integer.parseInt(categoryIdStr);
            } catch (NumberFormatException e) {
                // Ignore invalid category ID
            }
        }

        Integer id = Integer.parseInt(idStr);

        // Handle image upload
        String imagePath = null;
        try {
            // Check if we need to remove the existing image
            if ("true".equals(removeImage)) {
                imagePath = "";  // Empty string will clear the image
            } else {
                Part imagePart = request.getPart("questionImage");
                if (imagePart != null && imagePart.getSize() > 0) {
                    imagePath = saveImage(imagePart, getServletContext().getRealPath("/"));
                }
                // If no new image uploaded, pass null to keep existing image
            }
        } catch (Exception e) {
            System.err.println("Error uploading image: " + e.getMessage());
        }

        quizService.updateQuestion(id, questionText, imagePath, optionA, optionB, optionC, optionD, correctAnswer, categoryId, explanation);

        request.setAttribute("success", "Pertanyaan berhasil diupdate");
        response.sendRedirect(request.getContextPath() + "/QuestionServlet?action=list&quizId=" + quizId);
    }

    /**
     * Save uploaded image to external directory and return the web-accessible path
     */
    private String saveImage(Part imagePart, String webAppPath) throws IOException {
        // Validate file size
        if (imagePart.getSize() > MAX_FILE_SIZE) {
            throw new IOException("Ukuran file terlalu besar. Maksimal 2MB.");
        }

        // Validate MIME type from Part
        String contentType = imagePart.getContentType();
        if (contentType == null || !ALLOWED_MIME_TYPES.contains(contentType.toLowerCase())) {
            throw new IOException("Tipe file tidak didukung. Gunakan JPG, PNG, GIF, atau WebP.");
        }

        // Get and validate file extension
        String originalFileName = getSubmittedFileName(imagePart);
        String extension = "";
        if (originalFileName != null && originalFileName.contains(".")) {
            extension = originalFileName.substring(originalFileName.lastIndexOf(".")).toLowerCase();
        }

        // Whitelist extension check
        if (!ALLOWED_EXTENSIONS.contains(extension)) {
            throw new IOException("Ekstensi file tidak didukung. Gunakan .jpg, .jpeg, .png, .gif, atau .webp");
        }

        // Validate actual image content using ImageIO
        try (InputStream input = imagePart.getInputStream()) {
            BufferedImage image = ImageIO.read(input);
            if (image == null) {
                throw new IOException("File bukan gambar yang valid atau file rusak.");
            }

            // Additional check: verify image dimensions are reasonable
            int width = image.getWidth();
            int height = image.getHeight();
            if (width <= 0 || height <= 0 || width > 10000 || height > 10000) {
                throw new IOException("Dimensi gambar tidak valid.");
            }
        }

        // Create upload directory in external location (persists across redeployments)
        Path uploadPath = Paths.get(UPLOAD_BASE_DIR, UPLOAD_SUBDIR);
        if (!Files.exists(uploadPath)) {
            Files.createDirectories(uploadPath);
        }

        // Generate safe filename using UUID (prevents path traversal and overwrites)
        String safeFileName = UUID.randomUUID().toString() + extension;

        // Save file to external directory
        try (InputStream input = imagePart.getInputStream()) {
            Files.copy(input, uploadPath.resolve(safeFileName), StandardCopyOption.REPLACE_EXISTING);
        }

        // Return web-accessible path (served by FileServlet at /uploads/*)
        return WEB_PATH_PREFIX + "/" + safeFileName;
    }

    private String getSubmittedFileName(Part part) {
        String contentDisp = part.getHeader("content-disposition");
        if (contentDisp == null) return "";

        String[] items = contentDisp.split(";");
        for (String s : items) {
            s = s.trim();
            if (s.toLowerCase().startsWith("filename")) {
                // Handle both filename="file.jpg" and filename=file.jpg
                int idx = s.indexOf("=");
                if (idx >= 0) {
                    String name = s.substring(idx + 1).trim();
                    // Remove quotes if present
                    if (name.startsWith("\"") && name.endsWith("\"")) {
                        name = name.substring(1, name.length() - 1);
                    }
                    // Only get the filename, not the path (prevent path traversal)
                    name = Paths.get(name).getFileName().toString();
                    return name;
                }
            }
        }
        return "";
    }

    private void deleteQuestion(HttpServletRequest request, HttpServletResponse response, Integer quizId)
            throws ServletException, IOException, QuizService.ServiceException {
        String idStr = request.getParameter("id");
        if (idStr != null && !idStr.isEmpty()) {
            Integer id = Integer.parseInt(idStr);
            quizService.deleteQuestion(id);
            request.setAttribute("success", "Pertanyaan berhasil dihapus");
        }
        response.sendRedirect(request.getContextPath() + "/QuestionServlet?action=list&quizId=" + quizId);
    }
}
