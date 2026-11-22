package com.examora.service;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;

/**
 * PRD #17 — validasi kategori pengumuman &amp; jenjang sebelum masuk database.
 */
class ApiServiceValidationTest {

    @Test
    @DisplayName("kategori resmi dipertahankan apa adanya")
    void kategoriResmiDipertahankan() {
        assertEquals("Info Exam", ApiService.normalizeCategory("Info Exam"));
        assertEquals("Jadwal GMeet", ApiService.normalizeCategory("jadwal gmeet"));
        assertEquals("Tagihan & Kuota", ApiService.normalizeCategory("Tagihan & Kuota"));
        assertEquals("Umum", ApiService.normalizeCategory("Umum"));
    }

    @Test
    @DisplayName("kategori tak dikenal dinormalkan ke Umum")
    void kategoriTakDikenalMenjadiUmum() {
        assertEquals("Umum", ApiService.normalizeCategory(null));
        assertEquals("Umum", ApiService.normalizeCategory(""));
        assertEquals("Umum", ApiService.normalizeCategory("Promo"));
        // Spasi berlebih & beda kapitalisasi tetap diterima (input pengguna dimaafkan).
        assertEquals("Info Exam", ApiService.normalizeCategory(" info exam "));
    }

    @Test
    @DisplayName("jenjang valid dipertahankan, lainnya ALL")
    void jenjangValidDipertahankan() {
        assertEquals("ALL", ApiService.normalizeGrade("all"));
        assertEquals("SD-4", ApiService.normalizeGrade("sd-4"));
        assertEquals("SMP-9", ApiService.normalizeGrade(" SMP-9 "));
        assertEquals("ALL", ApiService.normalizeGrade(null));
        assertEquals("ALL", ApiService.normalizeGrade("Kelas 4"));
        assertEquals("ALL", ApiService.normalizeGrade("SD-9"));
    }

    @Test
    @DisplayName("audiens dinormalkan ke all/participants/admins")
    void audiensDinormalkan() {
        assertEquals("all", ApiService.normalizeTargetAudience("All"));
        assertEquals("participants", ApiService.normalizeTargetAudience(" Participants "));
        assertEquals("admins", ApiService.normalizeTargetAudience("ADMINS"));
        assertEquals("all", ApiService.normalizeTargetAudience(null));
        assertEquals("all", ApiService.normalizeTargetAudience(""));
        assertEquals("all", ApiService.normalizeTargetAudience("pengunjung"));
    }
}
