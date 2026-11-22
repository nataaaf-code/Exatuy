package com.examora.controller;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.*;

class PaymentSettingsServletTest {

    @Test
    void pointsMustBeANumber() {
        assertEquals(4, PaymentSettingsServlet.parsePoints(" 4 "));
        assertThrows(IllegalArgumentException.class, () -> PaymentSettingsServlet.parsePoints(null));
        assertThrows(IllegalArgumentException.class, () -> PaymentSettingsServlet.parsePoints(""));
        assertThrows(IllegalArgumentException.class, () -> PaymentSettingsServlet.parsePoints("abc"));
    }

    @Test
    void topUpCountsBalanceAndUnpaidOrders() {
        assertDoesNotThrow(() -> PaymentSettingsServlet.checkTopUpAllowed(8, 0, 4, 12));
        assertDoesNotThrow(() -> PaymentSettingsServlet.checkTopUpAllowed(4, 4, 4, 12));

        IllegalArgumentException overBalance = assertThrows(IllegalArgumentException.class,
                () -> PaymentSettingsServlet.checkTopUpAllowed(8, 0, 5, 12));
        assertTrue(overBalance.getMessage().contains("maksimal top-up: 4 poin"));

        IllegalArgumentException overPending = assertThrows(IllegalArgumentException.class,
                () -> PaymentSettingsServlet.checkTopUpAllowed(8, 4, 4, 12));
        assertTrue(overPending.getMessage().contains("tagihan 4 poin yang belum dibayar"));
        assertTrue(overPending.getMessage().contains("maksimal top-up: 0 poin"));
    }

    @Test
    void topUpNeedsAtLeastOnePoint() {
        assertThrows(IllegalArgumentException.class, () -> PaymentSettingsServlet.checkTopUpAllowed(0, 0, 0, 12));
        assertThrows(IllegalArgumentException.class, () -> PaymentSettingsServlet.checkTopUpAllowed(0, 0, -3, 12));
    }
}
