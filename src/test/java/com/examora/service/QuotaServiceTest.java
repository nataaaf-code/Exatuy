package com.examora.service;

import org.junit.jupiter.api.Test;

import java.time.Instant;

import static org.junit.jupiter.api.Assertions.*;

class QuotaServiceTest {

    @Test
    void monthKeyFollowsWibNotUtc() {
        // 30 Nov 16:59:59 UTC = 30 Nov 23:59:59 WIB, 30 Nov 17:00 UTC = 1 Des 00:00 WIB
        assertEquals("2026-11", QuotaService.monthKey(Instant.parse("2026-11-30T16:59:59Z")));
        assertEquals("2026-12", QuotaService.monthKey(Instant.parse("2026-11-30T17:00:00Z")));
        assertEquals("2027-01", QuotaService.monthKey(Instant.parse("2026-12-31T17:00:00Z")));
    }

    @Test
    void pointsMustBeBetweenOneAndTwelve() {
        assertThrows(QuotaService.ServiceException.class, () -> QuotaService.validatePoints(0));
        assertThrows(QuotaService.ServiceException.class, () -> QuotaService.validatePoints(13));
        assertDoesNotThrow(() -> QuotaService.validatePoints(1));
        assertDoesNotThrow(() -> QuotaService.validatePoints(12));
    }

    @Test
    void topUpLimitMessageShowsRemainingRoom() {
        assertTrue(QuotaService.topUpLimitMessage(8).contains("maksimal bisa membeli 4 poin"));
    }
}
