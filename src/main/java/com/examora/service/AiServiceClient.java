package com.examora.service;

import com.google.gson.Gson;
import com.google.gson.JsonObject;
import com.google.gson.JsonParser;

import java.io.IOException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.ArrayList;
import java.util.List;

/**
 * Klien HTTP dari aplikasi Java Exatuy ke AI &amp; DS microservice (FastAPI).
 *
 * PRD #29 (arsitektur hybrid) &amp; #28 (pemetaan role): satu-satunya pintu resmi
 * untuk memanggil endpoint AI dari sisi Java, sehingga konektor tidak tersebar
 * di banyak servlet.
 *
 * Konfigurasi (environment variable):
 * <ul>
 *   <li>{@code AI_SERVICE_BASE_URL} — default {@code http://localhost:8000}</li>
 *   <li>{@code AI_SERVICE_TIMEOUT_SECONDS} — default 10 detik</li>
 * </ul>
 *
 * Klien ini sengaja "fail-soft": kegagalan jaringan dilempar sebagai IOException
 * agar pemanggil dapat menampilkan fallback, bukan membuat halaman 500.
 */
public class AiServiceClient {

    private static final String DEFAULT_BASE_URL = "http://localhost:8000";
    private static final Duration DEFAULT_TIMEOUT = Duration.ofSeconds(
            Long.parseLong(System.getenv().getOrDefault("AI_SERVICE_TIMEOUT_SECONDS", "10")));
    private static final Duration HEALTH_TIMEOUT = Duration.ofSeconds(3);

    private final String baseUrl;
    private final Duration timeout;
    private final HttpClient http;
    private final Gson gson;

    public AiServiceClient() {
        this(defaultBaseUrl());
    }

    public AiServiceClient(String baseUrl) {
        this(baseUrl, DEFAULT_TIMEOUT);
    }

    public AiServiceClient(String baseUrl, Duration timeout) {
        this.baseUrl = normalizeBaseUrl(baseUrl);
        this.timeout = timeout;
        this.http = HttpClient.newBuilder()
                .connectTimeout(Duration.ofSeconds(3))
                .build();
        this.gson = new Gson();
    }

    /** URL service AI dari environment (fallback ke localhost untuk dev). */
    public static String defaultBaseUrl() {
        return System.getenv().getOrDefault("AI_SERVICE_BASE_URL", DEFAULT_BASE_URL);
    }

    /** Buang garis miring di akhir agar penggabungan path konsisten. */
    public static String normalizeBaseUrl(String url) {
        if (url == null || url.isBlank()) {
            return DEFAULT_BASE_URL;
        }
        String trimmed = url.trim();
        while (trimmed.endsWith("/")) {
            trimmed = trimmed.substring(0, trimmed.length() - 1);
        }
        return trimmed;
    }

    public String getBaseUrl() {
        return baseUrl;
    }

    /**
     * Health-check service AI (dipakai HealthServlet).
     * Mengembalikan null bila service tidak dapat dihubungi.
     */
    public JsonObject health() {
        try {
            HttpRequest request = HttpRequest.newBuilder()
                    .uri(URI.create(baseUrl + "/health"))
                    .timeout(HEALTH_TIMEOUT)
                    .GET()
                    .build();
            HttpResponse<String> response = http.send(request, HttpResponse.BodyHandlers.ofString());
            if (response.statusCode() != 200) {
                return null;
            }
            return JsonParser.parseString(response.body()).getAsJsonObject();
        } catch (Exception e) {
            return null;
        }
    }

    /**
     * POST /api/ai/chat — klasifikasi intent + routing (item #2).
     *
     * @param exatuyRole role internal aplikasi; dikonversi lewat {@link com.examora.util.RoleMapper}
     */
    public JsonObject chat(String message, Integer userId, String exatuyRole, String gradeLevel)
            throws IOException, InterruptedException {
        JsonObject body = new JsonObject();
        body.addProperty("message", message);
        body.addProperty("role", com.examora.util.RoleMapper.toAiRole(exatuyRole));
        if (userId != null) {
            body.addProperty("user_id", userId);
        }
        if (gradeLevel != null && !gradeLevel.isBlank()) {
            body.addProperty("grade_level", gradeLevel);
        }
        return post("/api/ai/chat", body);
    }

    /**
     * POST /api/ai/explain — pembahasan soal ramah anak (item #1).
     */
    public JsonObject explain(String question, List<String> options, String studentAnswer,
                              String correctAnswer, String subject, String gradeLevel)
            throws IOException, InterruptedException {
        JsonObject body = new JsonObject();
        body.addProperty("question", question);
        if (options != null && !options.isEmpty()) {
            var arr = new com.google.gson.JsonArray();
            options.forEach(arr::add);
            body.add("options", arr);
        }
        if (studentAnswer != null) {
            body.addProperty("student_answer", studentAnswer);
        }
        if (correctAnswer != null) {
            body.addProperty("correct_answer", correctAnswer);
        }
        if (subject != null) {
            body.addProperty("subject", subject);
        }
        if (gradeLevel != null) {
            body.addProperty("grade_level", gradeLevel);
        }
        return post("/api/ai/explain", body);
    }

    /**
     * POST /api/ai/sentiment — label sentimen ulasan siswa (item #4).
     */
    public JsonObject sentiment(List<String> texts, Integer studentId)
            throws IOException, InterruptedException {
        JsonObject body = new JsonObject();
        var arr = new com.google.gson.JsonArray();
        List<String> safe = texts != null ? texts : new ArrayList<>();
        safe.forEach(arr::add);
        body.add("texts", arr);
        if (studentId != null) {
            body.addProperty("student_id", studentId);
        }
        return post("/api/ai/sentiment", body);
    }

    /**
     * GET /api/ds/analytics — analitik &amp; prediksi siswa berisiko (item #7).
     */
    public JsonObject analytics(String gradeLevel, int topN) throws IOException, InterruptedException {
        StringBuilder path = new StringBuilder("/api/ds/analytics?top_n=").append(Math.max(1, topN));
        if (gradeLevel != null && !gradeLevel.isBlank()) {
            path.append("&grade_level=").append(java.net.URLEncoder.encode(gradeLevel,
                    java.nio.charset.StandardCharsets.UTF_8));
        }
        HttpRequest request = HttpRequest.newBuilder()
                .uri(URI.create(baseUrl + path))
                .timeout(timeout)
                .GET()
                .build();
        HttpResponse<String> response = http.send(request, HttpResponse.BodyHandlers.ofString());
        return parseBody(response);
    }

    private JsonObject post(String path, JsonObject body) throws IOException, InterruptedException {
        HttpRequest request = HttpRequest.newBuilder()
                .uri(URI.create(baseUrl + path))
                .timeout(timeout)
                .header("Content-Type", "application/json; charset=UTF-8")
                .POST(HttpRequest.BodyPublishers.ofString(gson.toJson(body)))
                .build();
        HttpResponse<String> response = http.send(request, HttpResponse.BodyHandlers.ofString());
        return parseBody(response);
    }

    private JsonObject parseBody(HttpResponse<String> response) throws IOException {
        if (response.statusCode() < 200 || response.statusCode() >= 300) {
            throw new IOException("AI service menjawab HTTP " + response.statusCode()
                    + ": " + truncate(response.body()));
        }
        return JsonParser.parseString(response.body()).getAsJsonObject();
    }

    private static String truncate(String value) {
        if (value == null) {
            return "";
        }
        return value.length() <= 300 ? value : value.substring(0, 300) + "...";
    }
}
