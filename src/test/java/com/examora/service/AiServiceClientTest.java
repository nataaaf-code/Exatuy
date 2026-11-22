package com.examora.service;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * PRD #29 — konektor Java ke AI &amp; DS service (bagian yang tidak butuh jaringan).
 */
class AiServiceClientTest {

    @Test
    @DisplayName("URL dasar dinormalkan (spasi & garis miring berlebih)")
    void urlDasarDinormalkan() {
        assertEquals("http://ai-service:8000", AiServiceClient.normalizeBaseUrl("http://ai-service:8000"));
        assertEquals("http://ai-service:8000", AiServiceClient.normalizeBaseUrl("http://ai-service:8000/"));
        assertEquals("http://ai-service:8000", AiServiceClient.normalizeBaseUrl("  http://ai-service:8000//  "));
        assertEquals("http://localhost:8000", AiServiceClient.normalizeBaseUrl(null));
        assertEquals("http://localhost:8000", AiServiceClient.normalizeBaseUrl("   "));
    }

    @Test
    @DisplayName("base URL terbaca dari environment/fallback dev")
    void baseUrlTerbaca() {
        String url = AiServiceClient.defaultBaseUrl();
        assertTrue(url.startsWith("http"), "URL harus absolut: " + url);
        assertEquals(AiServiceClient.normalizeBaseUrl(url), url);
    }

    @Test
    @DisplayName("klien dibuat dengan base URL yang diminta")
    void klienMemakaiBaseUrl() {
        AiServiceClient client = new AiServiceClient("http://ai-service:8000/");
        assertEquals("http://ai-service:8000", client.getBaseUrl());
    }
}
