package com.examora.controller;

import com.examora.service.PaymentGatewayService;
import com.google.gson.JsonElement;
import com.google.gson.JsonObject;
import com.google.gson.JsonParser;

import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.logging.Level;
import java.util.logging.Logger;

/**
 * Webhook gerbang pembayaran (PRD FR-007, gap #8).
 *
 * Gateway mengirim HTTP POST saat status pembayaran berubah:
 *   payment.completed -> transaksi lunas + poin ditambahkan (idempoten)
 *   payment.failed / payment.expired -> transaksi gagal
 *
 * Permintaan diverifikasi lewat header X-Webhook-Token yang dibandingkan dengan
 * Webhook Token di halaman Pengaturan Pembayaran. Tidak memakai sesi maupun CSRF.
 */
@WebServlet("/SumopodWebhookServlet")
public class SumopodWebhookServlet extends HttpServlet {
    private static final Logger LOGGER = Logger.getLogger(SumopodWebhookServlet.class.getName());
    private static final int MAX_BODY_BYTES = 64 * 1024;

    private PaymentGatewayService paymentGatewayService;

    /** Isi notifikasi yang dipakai aplikasi. */
    static class Event {
        final String type;
        final String orderId;
        final String paymentId;

        Event(String type, String orderId, String paymentId) {
            this.type = type;
            this.orderId = orderId;
            this.paymentId = paymentId;
        }
    }

    @Override
    public void init() throws ServletException {
        paymentGatewayService = new PaymentGatewayService();
    }

    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        if (!paymentGatewayService.verifyWebhookToken(request.getHeader("X-Webhook-Token"))) {
            reply(response, HttpServletResponse.SC_UNAUTHORIZED, "invalid webhook token");
            return;
        }

        byte[] body = request.getInputStream().readNBytes(MAX_BODY_BYTES + 1);
        if (body.length > MAX_BODY_BYTES) {
            reply(response, HttpServletResponse.SC_REQUEST_ENTITY_TOO_LARGE, "payload too large");
            return;
        }

        Event event = parseEvent(new String(body, StandardCharsets.UTF_8));
        if (event == null) {
            reply(response, HttpServletResponse.SC_BAD_REQUEST, "invalid payload");
            return;
        }

        try {
            if (!isPaymentStatusEvent(event.type)) {
                // payment.test dan event lain cukup diterima supaya tidak dikirim ulang
                reply(response, HttpServletResponse.SC_OK, "ignored");
                return;
            }

            String orderId = resolveOrderId(event);
            if (orderId == null) {
                reply(response, HttpServletResponse.SC_NOT_FOUND, "unknown order");
                return;
            }

            if ("payment.completed".equals(event.type)) {
                paymentGatewayService.settle(orderId);
            } else {
                paymentGatewayService.markFailed(orderId);
            }
            LOGGER.info("Webhook pembayaran diproses: " + event.type + " untuk " + orderId);
            reply(response, HttpServletResponse.SC_OK, "ok");
        } catch (PaymentGatewayService.ServiceException e) {
            // 5xx membuat gateway mencatat kegagalan sehingga notifikasi bisa dikirim ulang
            LOGGER.log(Level.WARNING, "Webhook pembayaran gagal diproses", e);
            reply(response, HttpServletResponse.SC_INTERNAL_SERVER_ERROR, "processing failed");
        }
    }

    private String resolveOrderId(Event event) throws PaymentGatewayService.ServiceException {
        if (event.orderId != null && paymentGatewayService.findOrder(event.orderId) != null) {
            return event.orderId;
        }
        return event.paymentId != null ? paymentGatewayService.findOrderIdByPaymentId(event.paymentId) : null;
    }

    static boolean isPaymentStatusEvent(String type) {
        return "payment.completed".equals(type) || "payment.failed".equals(type) || "payment.expired".equals(type);
    }

    /**
     * Baca notifikasi {"event_type": "...", "data": {"payment_id": "...", "order_id": "..."}}.
     *
     * @return null bila bukan JSON object atau jenis event tidak ada
     */
    static Event parseEvent(String json) {
        JsonObject root;
        try {
            root = JsonParser.parseString(json).getAsJsonObject();
        } catch (Exception e) {
            return null;
        }
        String type = text(root, "event_type", "event", "type");
        if (type == null) {
            return null;
        }
        JsonObject data = root.has("data") && root.get("data").isJsonObject() ? root.getAsJsonObject("data") : root;
        return new Event(type, text(data, "order_id"), text(data, "payment_id"));
    }

    private static String text(JsonObject json, String... keys) {
        for (String key : keys) {
            JsonElement value = json.get(key);
            if (value != null && value.isJsonPrimitive() && !value.getAsString().isBlank()) {
                return value.getAsString();
            }
        }
        return null;
    }

    private void reply(HttpServletResponse response, int status, String message) throws IOException {
        JsonObject json = new JsonObject();
        json.addProperty("ok", status == HttpServletResponse.SC_OK);
        json.addProperty("message", message);
        response.setStatus(status);
        response.setContentType("application/json");
        response.setCharacterEncoding("UTF-8");
        response.getWriter().write(json.toString());
    }
}
