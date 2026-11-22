package com.examora.controller;

import com.examora.service.QuotaService;
import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.time.LocalDate;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

class GMeetServletTest {

    @Test
    void sameMeetingAndDayHaveOneReferenceAcrossRequests() {
        LocalDate day = LocalDate.of(2026, 11, 22);
        String url = "https://meet.google.com/abc-defg-hij";
        String ref = GMeetServlet.accessReference(7, url, day);

        assertEquals(ref, GMeetServlet.accessReference(7, url, day));
        assertNotEquals(ref, GMeetServlet.accessReference(8, url, day));
        assertNotEquals(ref, GMeetServlet.accessReference(7, url, day.plusDays(1)));
        assertNotEquals(ref, GMeetServlet.accessReference(7, "https://meet.google.com/new-room", day));
        assertNotEquals(ref, GMeetServlet.accessReference(null, url, day));
        assertFalse(ref.contains(url));
        assertTrue(ref.length() <= 100); // quota_logs.reference_id
    }

    @Test
    void meetingDayUsesJakartaTimeIncludingMidnight() {
        Instant beforeMidnight = Instant.parse("2026-11-22T16:59:59Z");
        Instant afterMidnight = Instant.parse("2026-11-22T17:00:00Z");
        String url = "https://meet.google.com/abc-defg-hij";

        assertNotEquals(
                GMeetServlet.accessReference(7, url, LocalDate.ofInstant(beforeMidnight, QuotaService.WIB)),
                GMeetServlet.accessReference(7, url, LocalDate.ofInstant(afterMidnight, QuotaService.WIB)));
    }
}
