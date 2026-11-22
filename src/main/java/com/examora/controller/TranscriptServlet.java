package com.examora.controller;

import com.examora.dao.QuizDAO;
import com.examora.dao.SettingsDAO;
import com.examora.dao.SubmissionDAO;
import com.examora.model.Quiz;
import com.examora.model.User;
import com.examora.service.UserService;

import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;

import java.io.IOException;
import java.io.PrintWriter;
import java.sql.SQLException;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Date;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.TreeSet;

/**
 * TranscriptServlet - Displays a score matrix (rows = participants, columns = quizzes)
 * for admin (all participants) and peserta (own row only), plus CSV/Excel export.
 */
@WebServlet("/TranscriptServlet")
public class TranscriptServlet extends HttpServlet {
    private QuizDAO quizDAO;
    private SubmissionDAO submissionDAO;
    private UserService userService;
    private SettingsDAO settingsDAO;

    @Override
    public void init() throws ServletException {
        quizDAO = new QuizDAO();
        submissionDAO = new SubmissionDAO();
        userService = new UserService();
        settingsDAO = new SettingsDAO();
    }

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        String action = request.getParameter("action");
        HttpSession session = request.getSession();
        User user = (User) session.getAttribute("user");

        if (user == null) {
            response.sendRedirect("LoginServlet");
            return;
        }

        boolean isAdmin = "admin".equals(user.getRole());

        // Default action depends on role
        if (action == null || action.isEmpty()) {
            action = isAdmin ? "view" : "mine";
        }

        try {
            if ("export".equals(action)) {
                handleExport(request, response, user, isAdmin);
                return;
            }

            // Peserta requesting action=view -> redirect to their own transcript
            if ("view".equals(action) && !isAdmin) {
                response.sendRedirect("TranscriptServlet?action=mine");
                return;
            }

            // Admin requesting action=mine -> treat as view (no forced userId)
            if ("mine".equals(action) && isAdmin) {
                action = "view";
            }

            if ("view".equals(action)) {
                buildTranscript(request, user, false);
                request.getRequestDispatcher("/admin/transcript.jsp").forward(request, response);
            } else if ("mine".equals(action)) {
                buildTranscript(request, user, true);
                request.getRequestDispatcher("/user/transcript.jsp").forward(request, response);
            } else {
                if (isAdmin) {
                    response.sendRedirect("TranscriptServlet?action=view");
                } else {
                    response.sendRedirect("TranscriptServlet?action=mine");
                }
            }
        } catch (Exception e) {
            e.printStackTrace();
            request.setAttribute("error", "Gagal memuat transcript: " + e.getMessage());
            if (isAdmin) {
                request.getRequestDispatcher("/admin/transcript.jsp").forward(request, response);
            } else {
                request.getRequestDispatcher("/user/transcript.jsp").forward(request, response);
            }
        }
    }

    /**
     * Build transcript matrix data and attach to request attributes.
     * If forceOwnUserId is true, userIdFilter is set to the logged-in user id
     * (for peserta view).
     */
    private void buildTranscript(HttpServletRequest request, User user, boolean forceOwnUserId) throws SQLException {
        // Parse filters
        List<Integer> quizIdFilter = parseQuizIds(request.getParameterValues("quizIds"));
        String tagFilter = request.getParameter("tagFilter");
        String subjectFilter = request.getParameter("subjectFilter");
        String userIdParam = request.getParameter("userIdFilter");
        String sortBy = request.getParameter("sortBy");

        Integer userIdFilter = null;
        if (forceOwnUserId) {
            userIdFilter = user.getId();
        } else if (userIdParam != null && !userIdParam.trim().isEmpty()) {
            try {
                userIdFilter = Integer.parseInt(userIdParam.trim());
            } catch (NumberFormatException ignored) {
                // invalid -> ignore
            }
        }

        // Determine which quizzes to show as columns.
        // Filter by subjectFilter first if specified, then by quizIdFilter if specified.
        List<Quiz> allQuizzes = filterOutTestQuizzes(quizDAO.findAll());
        Set<String> allSubjectsSet = new TreeSet<>(String.CASE_INSENSITIVE_ORDER);
        allSubjectsSet.add("Matematika");
        allSubjectsSet.add("IPA");
        for (Quiz q : allQuizzes) {
            String eff = q.getEffectiveSubject();
            if (eff != null && !eff.isEmpty()) {
                allSubjectsSet.add(eff);
            }
        }
        List<String> allSubjects = new ArrayList<>(allSubjectsSet);

        List<Quiz> subjectFilteredQuizzes = filterQuizzesBySubject(allQuizzes, subjectFilter);
        List<Quiz> columnQuizzes;
        if (quizIdFilter != null && !quizIdFilter.isEmpty()) {
            Set<Integer> filterSet = new LinkedHashSet<>(quizIdFilter);
            columnQuizzes = new ArrayList<>();
            for (Quiz q : subjectFilteredQuizzes) {
                if (q.getId() != null && filterSet.contains(q.getId())) {
                    columnQuizzes.add(q);
                }
            }
        } else {
            columnQuizzes = subjectFilteredQuizzes;
        }

        // Fetch raw score rows (only for the columns we care about)
        List<Integer> quizIdsForQuery = new ArrayList<>();
        for (Quiz q : columnQuizzes) {
            if (q.getId() != null) quizIdsForQuery.add(q.getId());
        }
        List<Map<String, Object>> rows;
        if (subjectFilter != null && !subjectFilter.trim().isEmpty() && quizIdsForQuery.isEmpty()) {
            // Subject selected has no matching quizzes -> return empty result so empty state renders
            rows = new ArrayList<>();
        } else {
            rows = submissionDAO.getTranscriptScores(
                    quizIdsForQuery.isEmpty() ? null : quizIdsForQuery,
                    tagFilter,
                    userIdFilter
            );
        }

        // Build matrix: userId -> (quizId -> submission map)
        // Use LinkedHashMap to preserve DB order (already ordered by user name then submission time desc)
        Map<Integer, Map<String, Object>> usersIndex = new LinkedHashMap<>();
        Map<Integer, Map<Integer, Map<String, Object>>> scoreMatrix = new LinkedHashMap<>();

        for (Map<String, Object> row : rows) {
            Integer uId = toInt(row.get("userId"));
            Integer qId = toInt(row.get("quizId"));

            // qId == null means LEFT JOIN miss (peserta with no matching
            // submission). Skip the score slot but still register the user.
            if (qId != null) {
                // Keep first per (user, quiz) since rows are ordered by submitted_at DESC
                Map<Integer, Map<String, Object>> userScores = scoreMatrix.computeIfAbsent(uId, k -> new LinkedHashMap<>());
                if (!userScores.containsKey(qId)) {
                    userScores.put(qId, row);
                }
            }

            if (!usersIndex.containsKey(uId)) {
                Map<String, Object> u = new LinkedHashMap<>();
                u.put("userId", uId);
                u.put("userName", row.get("userName"));
                u.put("userEmail", row.get("userEmail"));
                u.put("userTag", row.get("userTag"));
                usersIndex.put(uId, u);
            }
        }

        // Build per-user averages.
        // userAverages: simple average of attempted quizzes (used in personal transcript).
        // userOverallAverages: weighted by total available quizzes — unattempted count as 0
        //   (used in admin matrix so comparison reflects participation, not just score quality).
        int totalColumnQuizzes = columnQuizzes.size();
        Map<Integer, Double> userAverages = new LinkedHashMap<>();
        Map<Integer, Double> userOverallAverages = new LinkedHashMap<>();
        Map<Integer, Integer> userAttemptCounts = new LinkedHashMap<>();
        for (Map.Entry<Integer, Map<Integer, Map<String, Object>>> entry : scoreMatrix.entrySet()) {
            double sum = 0;
            int count = 0;
            for (Map<String, Object> sub : entry.getValue().values()) {
                Object s = sub.get("score");
                if (s != null) {
                    sum += ((Number) s).doubleValue();
                    count++;
                }
            }
            userAverages.put(entry.getKey(), count > 0 ? (sum / count) : 0.0);
            userAttemptCounts.put(entry.getKey(), count);
            userOverallAverages.put(entry.getKey(), totalColumnQuizzes > 0 ? (sum / totalColumnQuizzes) : 0.0);
        }

        // Apply optional sort (reorders usersIndex + scoreMatrix in lockstep)
        applySort(usersIndex, scoreMatrix, totalColumnQuizzes, sortBy);

        // Preserve filter selections for the form
        request.setAttribute("allQuizzes", allQuizzes);
        request.setAttribute("columnQuizzes", columnQuizzes);
        request.setAttribute("usersIndex", usersIndex);
        request.setAttribute("scoreMatrix", scoreMatrix);
        request.setAttribute("userAverages", userAverages);
        request.setAttribute("userOverallAverages", userOverallAverages);
        request.setAttribute("userAttemptCounts", userAttemptCounts);
        request.setAttribute("totalColumnQuizzes", totalColumnQuizzes);
        request.setAttribute("allSubjects", allSubjects);
        request.setAttribute("selectedSubjectFilter", subjectFilter != null ? subjectFilter.trim() : "");
        request.setAttribute("selectedTagFilter", tagFilter != null ? tagFilter : "");
        request.setAttribute("selectedUserIdFilter", userIdFilter != null ? String.valueOf(userIdFilter) : "");
        request.setAttribute("selectedQuizIds", quizIdFilter != null ? quizIdFilter : new ArrayList<Integer>());
        request.setAttribute("selectedSortBy", sortBy != null ? sortBy : "");

        // Tags & participants for admin filter dropdowns
        try {
            request.setAttribute("allTags", userService.getAllTags());
        } catch (Exception e) {
            request.setAttribute("allTags", new ArrayList<String>());
        }
        if (!forceOwnUserId) {
            try {
                request.setAttribute("allParticipants", userService.getUsersByRole("peserta"));
            } catch (Exception e) {
                request.setAttribute("allParticipants", new ArrayList<User>());
            }
        }

        // Transcript branding (configurable via admin settings)
        loadTranscriptBranding(request);
    }

    /**
     * Load transcript branding settings (org name, url, signer name/title, signature image)
     * and attach to request attributes with sensible defaults.
     */
    private void loadTranscriptBranding(HttpServletRequest request) {
        String orgName = settingsDAO.getSetting("transcript_org_name");
        String orgUrl = settingsDAO.getSetting("transcript_org_url");
        String signerName = settingsDAO.getSetting("transcript_signer_name");
        String signerTitle = settingsDAO.getSetting("transcript_signer_title");
        String signaturePath = settingsDAO.getSetting("transcript_signature_path");

        request.setAttribute("transcriptOrgName", (orgName != null && !orgName.trim().isEmpty()) ? orgName.trim() : "IDS Cyber Security");
        request.setAttribute("transcriptOrgUrl", (orgUrl != null && !orgUrl.trim().isEmpty()) ? orgUrl.trim() : "ids-cybersecurity.com");
        request.setAttribute("transcriptSignerName", signerName != null ? signerName.trim() : "");
        request.setAttribute("transcriptSignerTitle", signerTitle != null ? signerTitle.trim() : "");
        request.setAttribute("transcriptSignaturePath", signaturePath != null ? signaturePath.trim() : "");
    }

    /**
     * Filter quizzes by subject (case-insensitive match against effective subject).
     */
    private List<Quiz> filterQuizzesBySubject(List<Quiz> quizzes, String subjectFilter) {
        if (subjectFilter == null || subjectFilter.trim().isEmpty()) {
            return quizzes;
        }
        String target = subjectFilter.trim();
        List<Quiz> result = new ArrayList<>();
        for (Quiz q : quizzes) {
            if (target.equalsIgnoreCase(q.getEffectiveSubject())) {
                result.add(q);
            }
        }
        return result;
    }

    /**
     * Exclude quizzes whose title starts with "Test Quiz" (case-insensitive)
     * from the transcript — these are placeholder/trial quizzes that should
     * not appear in a participant's official score transcript.
     */
    private List<Quiz> filterOutTestQuizzes(List<Quiz> quizzes) {
        List<Quiz> filtered = new ArrayList<>();
        if (quizzes == null) return filtered;
        for (Quiz q : quizzes) {
            String title = q.getTitle();
            if (title == null) {
                filtered.add(q);
                continue;
            }
            if (title.trim().toLowerCase().startsWith("test quiz")) {
                continue;
            }
            filtered.add(q);
        }
        return filtered;
    }

    /**
     * Handle CSV / Excel export. Uses the same filter parameters as the view.
     */
    private void handleExport(HttpServletRequest request, HttpServletResponse response, User user, boolean isAdmin)
            throws ServletException, IOException, SQLException {
        String format = request.getParameter("format");
        if (format == null) format = "csv";

        // Peserta can only export their own data
        List<Integer> quizIdFilter = parseQuizIds(request.getParameterValues("quizIds"));
        String tagFilter = request.getParameter("tagFilter");
        String subjectFilter = request.getParameter("subjectFilter");
        String userIdParam = request.getParameter("userIdFilter");
        String sortBy = request.getParameter("sortBy");

        Integer userIdFilter = null;
        if (!isAdmin) {
            userIdFilter = user.getId();
        } else if (userIdParam != null && !userIdParam.trim().isEmpty()) {
            try {
                userIdFilter = Integer.parseInt(userIdParam.trim());
            } catch (NumberFormatException ignored) {
                // invalid -> ignore
            }
        }

        // Determine column quizzes (filtered by subject if specified)
        List<Quiz> allQuizzes = filterOutTestQuizzes(quizDAO.findAll());
        List<Quiz> subjectFilteredQuizzes = filterQuizzesBySubject(allQuizzes, subjectFilter);
        List<Quiz> columnQuizzes;
        if (quizIdFilter != null && !quizIdFilter.isEmpty()) {
            Set<Integer> filterSet = new LinkedHashSet<>(quizIdFilter);
            columnQuizzes = new ArrayList<>();
            for (Quiz q : subjectFilteredQuizzes) {
                if (q.getId() != null && filterSet.contains(q.getId())) {
                    columnQuizzes.add(q);
                }
            }
        } else {
            columnQuizzes = subjectFilteredQuizzes;
        }

        List<Integer> quizIdsForQuery = new ArrayList<>();
        for (Quiz q : columnQuizzes) {
            if (q.getId() != null) quizIdsForQuery.add(q.getId());
        }
        List<Map<String, Object>> rows;
        if (subjectFilter != null && !subjectFilter.trim().isEmpty() && quizIdsForQuery.isEmpty()) {
            rows = new ArrayList<>();
        } else {
            rows = submissionDAO.getTranscriptScores(
                    quizIdsForQuery.isEmpty() ? null : quizIdsForQuery,
                    tagFilter,
                    userIdFilter
            );
        }

        // Build ordered users + score lookup
        Map<Integer, Map<String, Object>> usersIndex = new LinkedHashMap<>();
        Map<Integer, Map<Integer, Map<String, Object>>> scoreMatrix = new LinkedHashMap<>();
        for (Map<String, Object> row : rows) {
            Integer uId = toInt(row.get("userId"));
            Integer qId = toInt(row.get("quizId"));
            // qId == null means LEFT JOIN miss (peserta with no matching
            // submission). Skip the score slot but still register the user.
            if (qId != null) {
                Map<Integer, Map<String, Object>> userScores = scoreMatrix.computeIfAbsent(uId, k -> new LinkedHashMap<>());
                if (!userScores.containsKey(qId)) {
                    userScores.put(qId, row);
                }
            }
            if (!usersIndex.containsKey(uId)) {
                Map<String, Object> u = new LinkedHashMap<>();
                u.put("userId", uId);
                u.put("userName", row.get("userName"));
                u.put("userEmail", row.get("userEmail"));
                u.put("userTag", row.get("userTag"));
                usersIndex.put(uId, u);
            }
        }

        // Apply same sort as the view so export order matches the page
        applySort(usersIndex, scoreMatrix, columnQuizzes.size(), sortBy);

        String titleSuffix = isAdmin ? "admin" : sanitizeFileName(user.getName());

        if ("xls".equalsIgnoreCase(format)) {
            exportToExcel(response, usersIndex, scoreMatrix, columnQuizzes, titleSuffix);
        } else {
            exportToCSV(response, usersIndex, scoreMatrix, columnQuizzes, titleSuffix);
        }
    }

    private void exportToCSV(HttpServletResponse response,
                             Map<Integer, Map<String, Object>> usersIndex,
                             Map<Integer, Map<Integer, Map<String, Object>>> scoreMatrix,
                             List<Quiz> columnQuizzes,
                             String titleSuffix) throws IOException {
        response.setContentType("text/csv; charset=UTF-8");
        response.setHeader("Content-Disposition", "attachment; filename=\"transcript_" + titleSuffix + ".csv\"");

        PrintWriter writer = response.getWriter();
        writer.write('\ufeff'); // UTF-8 BOM for Excel

        int totalQuizzes = columnQuizzes.size();

        // Header
        StringBuilder header = new StringBuilder();
        header.append("No,Nama,Email,Tag");
        for (Quiz q : columnQuizzes) {
            header.append(",").append(escapeCSV(q.getTitle()));
        }
        header.append(",Selesai,Rata-rata");
        writer.println(header.toString());

        // Data rows
        int no = 1;
        for (Map.Entry<Integer, Map<String, Object>> entry : usersIndex.entrySet()) {
            Integer uId = entry.getKey();
            Map<String, Object> u = entry.getValue();
            Map<Integer, Map<String, Object>> userScores = scoreMatrix.get(uId);

            StringBuilder line = new StringBuilder();
            line.append(no++).append(",");
            line.append(escapeCSV(asString(u.get("userName")))).append(",");
            line.append(escapeCSV(asString(u.get("userEmail")))).append(",");
            line.append(escapeCSV(asString(u.get("userTag"))));

            double sum = 0;
            int count = 0;
            for (Quiz q : columnQuizzes) {
                line.append(",");
                Map<String, Object> sub = userScores != null ? userScores.get(q.getId()) : null;
                if (sub != null && sub.get("score") != null) {
                    double s = ((Number) sub.get("score")).doubleValue();
                    line.append(String.format("%.2f", s));
                    sum += s;
                    count++;
                } else {
                    line.append("-");
                }
            }
            // Weighted average: unattempted quizzes count as 0
            double weighted = totalQuizzes > 0 ? sum / totalQuizzes : 0;
            line.append(",").append(count).append("/").append(totalQuizzes);
            line.append(",").append(String.format("%.2f", weighted));
            writer.println(line.toString());
        }

        writer.flush();
        writer.close();
    }

    private void exportToExcel(HttpServletResponse response,
                               Map<Integer, Map<String, Object>> usersIndex,
                               Map<Integer, Map<Integer, Map<String, Object>>> scoreMatrix,
                               List<Quiz> columnQuizzes,
                               String titleSuffix) throws IOException {
        response.setContentType("application/vnd.ms-excel; charset=UTF-8");
        response.setHeader("Content-Disposition", "attachment; filename=\"transcript_" + titleSuffix + ".xls\"");

        PrintWriter writer = response.getWriter();
        writer.write('\ufeff'); // UTF-8 BOM

        writer.println("<html xmlns:o=\"urn:schemas-microsoft-com:office:office\"");
        writer.println("xmlns:x=\"urn:schemas-microsoft-com:office:excel\"");
        writer.println("xmlns=\"http://www.w3.org/TR/REC-html40\">");
        writer.println("<head><meta charset=\"UTF-8\"><!--[if gte mso 9]><xml>");
        writer.println("<x:ExcelWorkbook><x:ExcelWorksheets><x:ExcelWorksheet>");
        writer.println("<x:Name>Transcript</x:Name>");
        writer.println("<x:WorksheetOptions><x:DisplayGridlines/></x:WorksheetOptions>");
        writer.println("</x:ExcelWorksheet></x:ExcelWorksheets></x:ExcelWorkbook></xml>");
        writer.println("<![endif]--></head><body>");

        int totalQuizzes = columnQuizzes.size();

        writer.println("<table border=\"1\">");
        writer.println("<tr>");
        writer.println("<th>No</th><th>Nama</th><th>Email</th><th>Tag</th>");
        for (Quiz q : columnQuizzes) {
            writer.println("<th>" + escapeHTML(q.getTitle()) + "</th>");
        }
        writer.println("<th>Selesai</th><th>Rata-rata</th>");
        writer.println("</tr>");

        int no = 1;
        for (Map.Entry<Integer, Map<String, Object>> entry : usersIndex.entrySet()) {
            Integer uId = entry.getKey();
            Map<String, Object> u = entry.getValue();
            Map<Integer, Map<String, Object>> userScores = scoreMatrix.get(uId);

            writer.println("<tr>");
            writer.println("<td>" + no++ + "</td>");
            writer.println("<td>" + escapeHTML(asString(u.get("userName"))) + "</td>");
            writer.println("<td>" + escapeHTML(asString(u.get("userEmail"))) + "</td>");
            writer.println("<td>" + escapeHTML(asString(u.get("userTag"))) + "</td>");

            double sum = 0;
            int count = 0;
            for (Quiz q : columnQuizzes) {
                Map<String, Object> sub = userScores != null ? userScores.get(q.getId()) : null;
                if (sub != null && sub.get("score") != null) {
                    double s = ((Number) sub.get("score")).doubleValue();
                    writer.println("<td>" + String.format("%.2f", s) + "</td>");
                    sum += s;
                    count++;
                } else {
                    writer.println("<td>-</td>");
                }
            }
            // Weighted average: unattempted quizzes count as 0
            double weighted = totalQuizzes > 0 ? sum / totalQuizzes : 0;
            writer.println("<td>" + count + "/" + totalQuizzes + "</td>");
            writer.println("<td>" + String.format("%.2f", weighted) + "</td>");
            writer.println("</tr>");
        }

        writer.println("</table>");
        writer.println("<p style=\"font-size:9pt;margin-top:8px;color:#888;\">Diekspor pada: "
                + new SimpleDateFormat("dd/MM/yyyy HH:mm").format(new Date()) + "</p>");
        writer.println("</body></html>");

        writer.flush();
        writer.close();
    }

    // ----- Helpers -----

    /**
     * Reorder usersIndex + scoreMatrix (in lockstep) by the requested sort key.
     * Supported values: "avg-desc", "avg-asc", "count-desc", "count-asc".
     * Null/empty/"name" = no-op (keep DB order, which is name ASC).
     * Ties are broken by user name (case-insensitive) for stable ordering.
     *
     * Averages used for sorting are weighted by total column quizzes
     * (unattempted count as 0), matching the "Rata-rata" column shown in the
     * matrix and CSV/Excel export.
     */
    private void applySort(Map<Integer, Map<String, Object>> usersIndex,
                           Map<Integer, Map<Integer, Map<String, Object>>> scoreMatrix,
                           int totalColumnQuizzes,
                           String sortBy) {
        if (sortBy == null) return;
        sortBy = sortBy.trim();
        if (sortBy.isEmpty() || "name".equals(sortBy)) return;

        // Pre-compute avg + count + name per user (used by comparators)
        Map<Integer, Double> avgs = new HashMap<>();
        Map<Integer, Integer> counts = new HashMap<>();
        Map<Integer, String> names = new HashMap<>();
        for (Integer uId : usersIndex.keySet()) {
            Map<Integer, Map<String, Object>> userScores = scoreMatrix.get(uId);
            double sum = 0;
            int count = 0;
            if (userScores != null) {
                for (Map<String, Object> sub : userScores.values()) {
                    Object s = sub.get("score");
                    if (s != null) {
                        sum += ((Number) s).doubleValue();
                        count++;
                    }
                }
            }
            avgs.put(uId, totalColumnQuizzes > 0 ? sum / totalColumnQuizzes : 0.0);
            counts.put(uId, count);
            Object nm = usersIndex.get(uId).get("userName");
            names.put(uId, nm == null ? "" : nm.toString());
        }

        List<Integer> sortedIds = new ArrayList<>(usersIndex.keySet());
        switch (sortBy) {
            case "avg-desc":
                sortedIds.sort((a, b) -> {
                    int c = Double.compare(avgs.get(b), avgs.get(a));
                    return c != 0 ? c : names.get(a).compareToIgnoreCase(names.get(b));
                });
                break;
            case "avg-asc":
                sortedIds.sort((a, b) -> {
                    int c = Double.compare(avgs.get(a), avgs.get(b));
                    return c != 0 ? c : names.get(a).compareToIgnoreCase(names.get(b));
                });
                break;
            case "count-desc":
                sortedIds.sort((a, b) -> {
                    int c = Integer.compare(counts.get(b), counts.get(a));
                    return c != 0 ? c : names.get(a).compareToIgnoreCase(names.get(b));
                });
                break;
            case "count-asc":
                sortedIds.sort((a, b) -> {
                    int c = Integer.compare(counts.get(a), counts.get(b));
                    return c != 0 ? c : names.get(a).compareToIgnoreCase(names.get(b));
                });
                break;
            default:
                return; // unknown value — no-op
        }

        // Rebuild both maps in the sorted order so iteration stays in lockstep
        Map<Integer, Map<String, Object>> newUsers = new LinkedHashMap<>();
        Map<Integer, Map<Integer, Map<String, Object>>> newMatrix = new LinkedHashMap<>();
        for (Integer id : sortedIds) {
            newUsers.put(id, usersIndex.get(id));
            newMatrix.put(id, scoreMatrix.getOrDefault(id, new LinkedHashMap<>()));
        }
        usersIndex.clear();
        usersIndex.putAll(newUsers);
        scoreMatrix.clear();
        scoreMatrix.putAll(newMatrix);
    }

    private List<Integer> parseQuizIds(String[] values) {
        List<Integer> result = new ArrayList<>();
        if (values == null) return result;
        Set<Integer> seen = new TreeSet<>();
        for (String v : values) {
            if (v == null) continue;
            v = v.trim();
            if (v.isEmpty()) continue;
            try {
                Integer i = Integer.parseInt(v);
                if (i > 0 && seen.add(i)) {
                    result.add(i);
                }
            } catch (NumberFormatException ignored) {
                // skip invalid
            }
        }
        return result;
    }

    private Integer toInt(Object o) {
        if (o == null) return null;
        if (o instanceof Integer) return (Integer) o;
        if (o instanceof Number) return ((Number) o).intValue();
        try {
            return Integer.parseInt(o.toString());
        } catch (NumberFormatException e) {
            return null;
        }
    }

    private String asString(Object o) {
        return o == null ? "" : o.toString();
    }

    private String escapeCSV(String value) {
        if (value == null) return "";
        if (value.contains(",") || value.contains("\"") || value.contains("\n")) {
            return "\"" + value.replace("\"", "\"\"") + "\"";
        }
        return value;
    }

    private String escapeHTML(String value) {
        if (value == null) return "";
        return value.replace("&", "&amp;")
                    .replace("<", "&lt;")
                    .replace(">", "&gt;")
                    .replace("\"", "&quot;")
                    .replace("'", "&#39;");
    }

    private String sanitizeFileName(String name) {
        if (name == null) return "user";
        return name.replaceAll("[\\\\/:*?\"<>|]", "")
                   .replaceAll("\\s+", "_")
                   .trim();
    }
}
