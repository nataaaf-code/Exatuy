package com.examora.controller;

import com.examora.scheduler.AttendanceSchedulerListener;
import com.examora.service.AiServiceClient;
import com.examora.util.DBUtil;
import com.google.gson.Gson;
import com.google.gson.GsonBuilder;
import com.google.gson.JsonObject;

import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

import java.io.IOException;
import java.sql.Connection;
import java.sql.ResultSet;
import java.sql.Statement;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;

/**
 * Health Servlet — endpoint ringan untuk memantau komponen inti.
 *
 * PRD §5.2 #5 + item #21: {@code GET /health} (alias {@code GET /api/v1/health})
 * melaporkan status koneksi database, penjadwal (scheduler) reset kuota, dan
 * keterjangkauan AI &amp; DS service.
 *
 * Sengaja tanpa autentikasi (untuk uptime monitor) tetapi **tidak** membocorkan
 * kredensial: hanya status boolean, latensi, dan versi.
 */
@WebServlet(urlPatterns = {"/health", "/api/v1/health"})
public class HealthServlet extends HttpServlet {

    private static final String APP_VERSION = "1.0.0";

    private static final DateTimeFormatter WIB =
            DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss").withZone(ZoneId.of("Asia/Jakarta"));

    private final Instant startedAt = Instant.now();
    private AiServiceClient aiServiceClient;

    @Override
    public void init() throws ServletException {
        aiServiceClient = new AiServiceClient();
    }

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        JsonObject root = new JsonObject();
        JsonObject components = new JsonObject();

        JsonObject database = checkDatabase();
        components.add("database", database);

        components.add("scheduler", checkScheduler());
        components.add("ai_service", checkAiService());

        boolean healthy = database.get("ok").getAsBoolean()
                && components.getAsJsonObject("scheduler").get("started").getAsBoolean();

        root.addProperty("status", healthy ? "ok" : "degraded");
        root.addProperty("service", "Exatuy Core Web App");
        root.addProperty("version", APP_VERSION);
        root.addProperty("server", getServletContext().getServerInfo());
        root.addProperty("time_wib", WIB.format(Instant.now()));
        root.addProperty("uptime_seconds", Duration.between(startedAt, Instant.now()).getSeconds());
        root.add("components", components);

        response.setStatus(healthy ? HttpServletResponse.SC_OK : HttpServletResponse.SC_SERVICE_UNAVAILABLE);
        response.setContentType("application/json");
        response.setCharacterEncoding("UTF-8");
        response.setHeader("Cache-Control", "no-store");

        Gson gson = new GsonBuilder().setPrettyPrinting().create();
        response.getWriter().write(gson.toJson(root));
    }

    private JsonObject checkDatabase() {
        JsonObject result = new JsonObject();
        long start = System.nanoTime();
        try (Connection conn = DBUtil.getConnection();
             Statement stmt = conn.createStatement();
             ResultSet rs = stmt.executeQuery("SELECT 1")) {
            rs.next();
            long latencyMs = (System.nanoTime() - start) / 1_000_000;
            result.addProperty("ok", true);
            result.addProperty("latency_ms", latencyMs);
        } catch (Exception e) {
            result.addProperty("ok", false);
            result.addProperty("error", e.getClass().getSimpleName());
        }
        return result;
    }

    private JsonObject checkScheduler() {
        JsonObject result = new JsonObject();
        boolean started = AttendanceSchedulerListener.isStarted();
        Instant lastRun = AttendanceSchedulerListener.getLastRunAt();
        result.addProperty("started", started);
        result.addProperty("last_run_wib", lastRun != null ? WIB.format(lastRun) : null);
        if (lastRun != null) {
            long ageSeconds = Duration.between(lastRun, Instant.now()).getSeconds();
            // Tick berjalan tiap 60 detik; lebih dari 5 menit berarti macet.
            result.addProperty("stale", ageSeconds > 300);
        }
        result.addProperty("interval", "60s (reset kuota, auto-publish quiz, status presensi)");
        return result;
    }

    private JsonObject checkAiService() {
        JsonObject result = new JsonObject();
        result.addProperty("base_url", aiServiceClient.getBaseUrl());
        JsonObject aiHealth = aiServiceClient.health();
        if (aiHealth == null) {
            result.addProperty("reachable", false);
            result.addProperty("note", "AI service tidak dapat dihubungi (opsional untuk fitur non-AI)");
            return result;
        }
        result.addProperty("reachable", true);
        if (aiHealth.has("status")) {
            result.addProperty("status", aiHealth.get("status").getAsString());
        }
        if (aiHealth.has("components")) {
            result.add("components", aiHealth.getAsJsonObject("components"));
        }
        return result;
    }
}
