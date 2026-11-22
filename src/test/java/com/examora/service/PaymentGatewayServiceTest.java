package com.examora.service;

import com.google.gson.JsonObject;
import com.google.gson.JsonParser;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.time.LocalDateTime;

import static org.junit.jupiter.api.Assertions.*;

class PaymentGatewayServiceTest {

    private static PaymentGatewayService.Charge pendingCharge() {
        PaymentGatewayService.Charge charge = new PaymentGatewayService.Charge();
        charge.orderId = "INV-EXA-1";
        charge.amount = new BigDecimal("40000.00");
        charge.paymentMethod = "QRIS";
        charge.expiresAt = LocalDateTime.of(2026, 11, 23, 8, 30);
        return charge;
    }

    @Test
    void selfConfirmOnlyForSimulatedSandboxOrders() {
        assertTrue(PaymentGatewayService.canSelfConfirm(true, false));
        assertFalse(PaymentGatewayService.canSelfConfirm(false, false), "tagihan asli");
        assertFalse(PaymentGatewayService.canSelfConfirm(true, true), "mode live");
        assertFalse(PaymentGatewayService.canSelfConfirm(false, true));
    }

    @Test
    void baseUrlFollowsModeUnlessOverridden() {
        assertEquals("https://api-pay-sandbox.sumopod.com/api/v1", PaymentGatewayService.gatewayBaseUrl(null, false));
        assertEquals("https://api-pay.sumopod.com/api/v1", PaymentGatewayService.gatewayBaseUrl(" ", true));
        assertEquals("http://127.0.0.1:9/api/v1", PaymentGatewayService.gatewayBaseUrl("http://127.0.0.1:9/api/v1", true));
    }

    @Test
    void paymentRequestUsesGatewayFieldNames() {
        JsonObject body = JsonParser.parseString(
                PaymentGatewayService.buildPaymentRequest("INV-EXA-1", new BigDecimal("40000.00"))).getAsJsonObject();

        assertEquals("INV-EXA-1", body.get("order_id").getAsString());
        assertEquals(40000, body.get("amount").getAsLong());
        assertEquals("IDR", body.get("currency").getAsString());
        assertEquals("QRIS", body.get("payment_method_type_code").getAsString());
    }

    @Test
    void paymentResponseIsMappedToRealCharge() {
        String json = "{\"payment_id\":\"550e8400-e29b\",\"order_id\":\"INV-EXA-1\",\"amount\":40000,"
                + "\"payment_link_url\":\"https://pay.example.com/link/abc\",\"payment_code\":\"00020101QR\","
                + "\"status\":\"pending\",\"expires_at\":\"2026-11-23T02:00:00Z\"}";

        PaymentGatewayService.Charge live = PaymentGatewayService.parsePaymentResponse(pendingCharge(), json);

        assertNotNull(live);
        assertFalse(live.simulated);
        assertEquals("550e8400-e29b", live.providerRef);
        assertEquals("https://pay.example.com/link/abc", live.paymentUrl);
        assertEquals("00020101QR", live.qrString);
        // 02:00 UTC = 09:00 WIB
        assertEquals(LocalDateTime.of(2026, 11, 23, 9, 0), live.expiresAt);
    }

    @Test
    void paymentResponseKeepsDefaultExpiryWhenMissing() {
        PaymentGatewayService.Charge live = PaymentGatewayService.parsePaymentResponse(pendingCharge(),
                "{\"data\":{\"payment_id\":\"p1\",\"payment_link_url\":\"https://pay.example.com/x\"}}");

        assertNotNull(live);
        assertEquals("p1", live.providerRef);
        assertEquals(LocalDateTime.of(2026, 11, 23, 8, 30), live.expiresAt);
    }

    @Test
    void paymentResponseWithoutWayToPayIsRejected() {
        assertNull(PaymentGatewayService.parsePaymentResponse(pendingCharge(), "{\"payment_id\":\"p1\"}"));
        assertNull(PaymentGatewayService.parsePaymentResponse(pendingCharge(),
                "{\"payment_id\":\"p1\",\"payment_link_url\":\"javascript:alert(1)\"}"));
        assertNull(PaymentGatewayService.parsePaymentResponse(pendingCharge(), "<html>502</html>"));
    }
}
