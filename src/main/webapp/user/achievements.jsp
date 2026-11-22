<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%@ page import="com.examora.model.User" %>
<%@ page import="com.examora.model.Achievement" %>
<%@ page import="com.examora.model.UserAchievement" %>
<%@ page import="com.examora.util.ValidationUtil" %>
<%@ page import="java.util.List" %>
<%@ page import="java.util.Map" %>
<%@ page import="java.time.format.DateTimeFormatter" %>
<%@ page import="java.time.ZoneId" %>
<%
    User currentUser = (User) session.getAttribute("user");
    if (currentUser == null) {
        response.sendRedirect("../LoginServlet");
        return;
    }
    List<UserAchievement> userAchievements = (List<UserAchievement>) request.getAttribute("userAchievements");
    List<Achievement> allAchievements = (List<Achievement>) request.getAttribute("allAchievements");
    Integer totalPoints = (Integer) request.getAttribute("totalPoints");
    Integer achievementCount = (Integer) request.getAttribute("achievementCount");
    List<Map<String, Object>> leaderboard = (List<Map<String, Object>>) request.getAttribute("leaderboard");
    String success = (String) request.getAttribute("success");
    String error = (String) request.getAttribute("error");
    ZoneId jakartaZone = ZoneId.of("Asia/Jakarta");
    DateTimeFormatter dtf = DateTimeFormatter.ofPattern("dd MMM yyyy").withZone(jakartaZone);
%>
<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Achievements - Exatuy</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
    <link href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.10.0/font/bootstrap-icons.css" rel="stylesheet">
    <link href="../assets/css/style.css" rel="stylesheet">
<link href="../assets/css/handdrawn.css" rel="stylesheet">
</head>
<body>
    <!-- Navbar -->
    <%@ include file="navbar.jspf" %>

    <div class="container py-4">
        <% if (success != null) { %>
        <div class="alert alert-success alert-dismissible fade show">
            <i class="bi bi-check-circle me-2"></i><%= ValidationUtil.sanitizeHtml(success) %>
            <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
        </div>
        <% } %>
        <% if (error != null) { %>
        <div class="alert alert-danger alert-dismissible fade show">
            <i class="bi bi-exclamation-triangle me-2"></i><%= ValidationUtil.sanitizeHtml(error) %>
            <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
        </div>
        <% } %>

        <!-- Stats -->
        <div class="row mb-4">
            <div class="col-md-4">
                <div class="card bg-primary text-white">
                    <div class="card-body text-center">
                        <i class="bi bi-star-fill display-4 mb-2"></i>
                        <h2><%= totalPoints != null ? totalPoints : 0 %></h2>
                        <p class="mb-0">Total Points</p>
                    </div>
                </div>
            </div>
            <div class="col-md-4">
                <div class="card bg-success text-white">
                    <div class="card-body text-center">
                        <i class="bi bi-trophy-fill display-4 mb-2"></i>
                        <h2><%= achievementCount != null ? achievementCount : 0 %></h2>
                        <p class="mb-0">Achievements</p>
                    </div>
                </div>
            </div>
            <div class="col-md-4">
                <div class="card bg-info text-white">
                    <div class="card-body text-center">
                        <i class="bi bi-graph-up display-4 mb-2"></i>
                        <h2><%= allAchievements != null ? allAchievements.size() - (achievementCount != null ? achievementCount : 0) : 0 %></h2>
                        <p class="mb-0">Remaining</p>
                    </div>
                </div>
            </div>
        </div>

        <div class="row">
            <!-- My Achievements -->
            <div class="col-lg-8">
                <div class="card mb-4">
                    <div class="card-header">
                        <h5 class="mb-0"><i class="bi bi-trophy me-2"></i>My Achievements</h5>
                    </div>
                    <div class="card-body">
                        <% if (userAchievements != null && !userAchievements.isEmpty()) { %>
                        <div class="row">
                            <% for (UserAchievement ua : userAchievements) {
                                Achievement a = ua.getAchievement();
                            %>
                            <div class="col-md-4 mb-3">
                                <div class="card h-100 border-<%= ValidationUtil.sanitizeHtml(a.getColor().replace("bg-", "")) %>">
                                    <div class="card-body text-center">
                                        <span class="<%= ValidationUtil.sanitizeHtml(a.getColor()) %> text-white rounded-circle d-inline-flex align-items-center justify-content-center mb-2" style="width: 50px; height: 50px;">
                                            <i class="bi <%= ValidationUtil.sanitizeHtml(a.getIcon()) %> fs-4"></i>
                                        </span>
                                        <h6 class="card-title"><%= ValidationUtil.sanitizeHtml(a.getName()) %></h6>
                                        <p class="card-text small text-muted"><%= ValidationUtil.sanitizeHtml(a.getDescription()) %></p>
                                        <span class="badge bg-warning text-dark">+<%= a.getPoints() %> pts</span>
                                        <br><small class="text-muted">Earned: <%= ua.getEarnedAt() != null ? ua.getEarnedAt().atZone(ZoneId.systemDefault()).withZoneSameInstant(jakartaZone).format(dtf) : "-" %></small>
                                    </div>
                                </div>
                            </div>
                            <% } %>
                        </div>
                        <% } else { %>
                        <div class="text-center py-4 text-muted">
                            <i class="bi bi-trophy display-4 d-block mb-2"></i>
                            Belum ada achievement. Selesaikan quiz untuk mendapatkan badge!
                        </div>
                        <% } %>
                    </div>
                </div>

                <!-- All Achievements -->
                <div class="card">
                    <div class="card-header">
                        <h5 class="mb-0"><i class="bi bi-stars me-2"></i>All Achievements</h5>
                    </div>
                    <div class="card-body">
                        <div class="row">
                            <% if (allAchievements != null) { %>
                            <% for (Achievement a : allAchievements) {
                                boolean earned = false;
                                if (userAchievements != null) {
                                    for (UserAchievement ua : userAchievements) {
                                        if (ua.getAchievementId().equals(a.getId())) {
                                            earned = true;
                                            break;
                                        }
                                    }
                                }
                            %>
                            <div class="col-md-3 mb-3">
                                <div class="card h-100 <%= earned ? "" : "opacity-50" %>">
                                    <div class="card-body text-center">
                                        <span class="<%= ValidationUtil.sanitizeHtml(a.getColor()) %> text-white rounded-circle d-inline-flex align-items-center justify-content-center mb-2" style="width: 40px; height: 40px;">
                                            <i class="bi <%= ValidationUtil.sanitizeHtml(earned ? a.getIcon() : "bi-lock") %>"></i>
                                        </span>
                                        <h6 class="card-title small"><%= ValidationUtil.sanitizeHtml(a.getName()) %></h6>
                                        <span class="badge bg-secondary">+<%= a.getPoints() %> pts</span>
                                        <% if (earned) { %>
                                        <br><i class="bi bi-check-circle-fill text-success"></i>
                                        <% } %>
                                    </div>
                                </div>
                            </div>
                            <% } %>
                            <% } %>
                        </div>
                    </div>
                </div>
            </div>

            <!-- Leaderboard -->
            <div class="col-lg-4">
                <div class="card">
                    <div class="card-header">
                        <h5 class="mb-0"><i class="bi bi-award me-2"></i>Leaderboard</h5>
                    </div>
                    <div class="card-body">
                        <% if (leaderboard != null && !leaderboard.isEmpty()) { %>
                        <div class="list-group list-group-flush">
                            <% int rank = 1; for (Map<String, Object> entry : leaderboard) { %>
                            <div class="list-group-item d-flex justify-content-between align-items-center <%= entry.get("id").equals(currentUser.getId()) ? "list-group-item-primary" : "" %>">
                                <div>
                                    <span class="badge <%= rank == 1 ? "bg-warning" : rank == 2 ? "bg-secondary" : rank == 3 ? "bg-danger" : "bg-light text-dark" %> me-2"><%= rank %></span>
                                    <%= ValidationUtil.sanitizeHtml(String.valueOf(entry.get("name"))) %>
                                </div>
                                <span class="badge bg-primary"><%= entry.get("totalPoints") %> pts</span>
                            </div>
                            <% rank++; } %>
                        </div>
                        <% } else { %>
                        <p class="text-muted text-center">Belum ada data leaderboard</p>
                        <% } %>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/js/bootstrap.bundle.min.js"></script>
</body>
</html>
