package com.examora.controller;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.*;

class SumopodWebhookServletTest {

    @Test
    void readsEventTypeAndIdsFromDataObject() {
        SumopodWebhookServlet.Event event = SumopodWebhookServlet.parseEvent(
                "{\"event_type\":\"payment.completed\",\"data\":{\"payment_id\":\"550e8400\","
                        + "\"order_id\":\"INV-EXA-1\",\"amount\":40000,\"status\":\"completed\"}}");

        assertNotNull(event);
        assertEquals("payment.completed", event.type);
        assertEquals("INV-EXA-1", event.orderId);
        assertEquals("550e8400", event.paymentId);
    }

    @Test
    void readsFlatPayloadToo() {
        SumopodWebhookServlet.Event event = SumopodWebhookServlet.parseEvent(
                "{\"event\":\"payment.expired\",\"order_id\":\"INV-EXA-2\"}");

        assertNotNull(event);
        assertEquals("payment.expired", event.type);
        assertEquals("INV-EXA-2", event.orderId);
        assertNull(event.paymentId);
    }

    @Test
    void rejectsPayloadWithoutEventType() {
        assertNull(SumopodWebhookServlet.parseEvent("{\"data\":{\"order_id\":\"INV-EXA-1\"}}"));
        assertNull(SumopodWebhookServlet.parseEvent("[1,2]"));
        assertNull(SumopodWebhookServlet.parseEvent("bukan json"));
        assertNull(SumopodWebhookServlet.parseEvent(""));
    }

    @Test
    void onlyPaymentStatusEventsChangeTransactions() {
        assertTrue(SumopodWebhookServlet.isPaymentStatusEvent("payment.completed"));
        assertTrue(SumopodWebhookServlet.isPaymentStatusEvent("payment.failed"));
        assertTrue(SumopodWebhookServlet.isPaymentStatusEvent("payment.expired"));
        assertFalse(SumopodWebhookServlet.isPaymentStatusEvent("payment.test"));
        assertFalse(SumopodWebhookServlet.isPaymentStatusEvent("refund.created"));
    }
}
