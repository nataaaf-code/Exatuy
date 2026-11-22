package com.examora.controller;

import org.junit.jupiter.api.Test;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

import static org.junit.jupiter.api.Assertions.*;

class BulkEmailServletTest {

    @Test
    void splitsRecipientsIntoBatchesOfForty() {
        List<String> emails = new ArrayList<>();
        for (int i = 0; i < 85; i++) {
            emails.add("siswa" + i + "@mail.com");
        }

        List<List<String>> batches = BulkEmailServlet.batches(emails, BulkEmailServlet.BATCH_SIZE);

        assertEquals(3, batches.size());
        assertEquals(40, batches.get(0).size());
        assertEquals(40, batches.get(1).size());
        assertEquals(5, batches.get(2).size());
        assertEquals("siswa84@mail.com", batches.get(2).get(4));
    }

    @Test
    void noRecipientsMeansNoBatches() {
        assertTrue(BulkEmailServlet.batches(Collections.emptyList(), 40).isEmpty());
    }
}
