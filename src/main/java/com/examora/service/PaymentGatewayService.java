package com.examora.service;

import com.examora.dao.PaymentSettingDAO;
import com.examora.model.PaymentSetting;
import com.examora.util.CryptoUtil;
import com.examora.util.DBUtil;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.time.Duration;
import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.Random;

/**
 * PaymentGatewayService — pembuatan tagihan QRIS / Virtual Account untuk checkout kuota.
 *
 * Catatan penamaan: nama vendor gateway sengaja TIDAK dipakai di kelas, pesan,
 * maupun UI (label yang tampil ke siswa hanya "Pembayaran Online"). Kredensial
 * vendor tetap dibaca dari tabel `payment_settings` (terenkripsi AES-256).
 *
 * Dua mode:
 *  - **Live**: bila API key gateway sudah diisi admin, kode memanggil endpoint
 *    gateway (`SUMOPOD_BASE_URL`, default sandbox) untuk memperoleh QR/VA asli.
 *  - **Simulasi**: bila API key belum diisi atau panggilan gagal, layanan membuat
 *    payload QRIS yang valid secara format + nomor VA internal, menandai
 *    transaksi `is_simulated = 1`, dan menyediakan tombol "sudah dibayar" untuk
 *    demo. Ini yang membuat alur checkout tetap bisa diuji tanpa kredensial.
 */
public class PaymentGatewayService {

    /** Masa berlaku tagihan (menit). */
    public static final int EXPIRY_MINUTES = 30;

    /** Prefix Virtual Account internal (bukan kode bank asli). */
    private static final String VA_PREFIX = "8808";

    private final PaymentSettingDAO paymentSettingDAO = new PaymentSettingDAO();
    private final QuotaService quotaService = new QuotaService();

    public static class Charge {
        public String orderId;
        public String paymentMethod;
        public BigDecimal amount;
        public String qrString;
        public String vaNumber;
        public String paymentUrl;
        public String providerRef;
        public LocalDateTime expiresAt;
        public boolean simulated;
    }

    // ------------------------------------------------------------------ publik

    /**
     * Buat tagihan untuk sebuah order yang sudah tercatat di tabel `transactions`.
     */
    public Charge createCharge(String orderId, BigDecimal amount, String method) {
        String paymentMethod = (method == null || method.isBlank()) ? "QRIS"
                : ("va".equalsIgnoreCase(method) || method.toLowerCase().contains("virtual")
                    ? "Virtual Account" : "QRIS");

        Charge charge = new Charge();
        charge.orderId = orderId;
        charge.amount = amount;
        charge.paymentMethod = paymentMethod;
        charge.expiresAt = LocalDateTime.now(ZoneId.of("Asia/Jakarta")).plusMinutes(EXPIRY_MINUTES);

        PaymentSetting setting;
        try {
            setting = paymentSettingDAO.getSettings();
        } catch (Exception e) {
            setting = new PaymentSetting();
        }

        boolean liveAttempted = false;
        if (setting != null && setting.isConfigured()) {
            liveAttempted = true;
            Charge live = callGateway(setting, charge);
            if (live != null) {
                persist(charge, live);
                return live;
            }
        }

        // Fallback / mode simulasi (tanpa kredensial): QRIS payload + VA internal.
        if ("Virtual Account".equals(paymentMethod)) {
            charge.vaNumber = buildVaNumber(orderId);
        } else {
            charge.qrString = buildQrisPayload(orderId, amount);
            charge.vaNumber = buildVaNumber(orderId); // cadangan bila QR gagal dipindai
        }
        charge.paymentUrl = null;
        charge.providerRef = (liveAttempted ? "sim_" : "dummy_") + shortRef(orderId);
        charge.simulated = true;
        persist(charge, charge);
        return charge;
    }

    /**
     * Tandai order lunas dan tambahkan poin ke dompet siswa.
     * Idempotent: pemanggilan kedua tidak menambah poin lagi.
     *
     * @return true bila order sekarang berstatus completed
     */
    public boolean settle(String orderId) throws ServiceException {
        Integer studentId = null;
        int points = 0;
        boolean alreadySettled;

        try (Connection conn = DBUtil.getConnection()) {
            conn.setAutoCommit(false);
            try {
                String sql = "SELECT student_id, points_purchased, status, settled_at "
                        + "FROM transactions WHERE order_id = ? FOR UPDATE";
                try (PreparedStatement stmt = conn.prepareStatement(sql)) {
                    stmt.setString(1, orderId);
                    try (ResultSet rs = stmt.executeQuery()) {
                        if (!rs.next()) {
                            conn.rollback();
                            throw new ServiceException("Pesanan tidak ditemukan: " + orderId);
                        }
                        studentId = rs.getInt("student_id");
                        points = rs.getInt("points_purchased");
                        alreadySettled = "completed".equalsIgnoreCase(rs.getString("status"))
                                || rs.getTimestamp("settled_at") != null;
                    }
                }

                if (!alreadySettled) {
                    try (PreparedStatement stmt = conn.prepareStatement(
                            "UPDATE transactions SET status = 'completed', paid_at = NOW(), settled_at = NOW() "
                                    + "WHERE order_id = ? AND settled_at IS NULL")) {
                        stmt.setString(1, orderId);
                        stmt.executeUpdate();
                    }
                }
                conn.commit();
            } catch (Exception e) {
                conn.rollback();
                throw e;
            }
        } catch (ServiceException e) {
            throw e;
        } catch (Exception e) {
            throw new ServiceException("Gagal menyelesaikan pembayaran: " + e.getMessage(), e);
        }

        if (alreadySettled) {
            return true;
        }

        // Kredit poin setelah status ter-commit (validasi ≤ 12 poin ada di QuotaService).
        try {
            quotaService.topUp(studentId, points, orderId);
        } catch (QuotaService.ServiceException e) {
            throw new ServiceException("Pembayaran diterima, tetapi poin gagal ditambahkan: " + e.getMessage(), e);
        }
        return true;
    }

    /**
     * Ambil detail tagihan untuk ditampilkan di halaman pembayaran.
     * Urutan array: orderId, method, amount, qrString, vaNumber, status, expiresAt, isSimulated
     */
    public Object[] findOrder(String orderId) throws ServiceException {
        try (Connection conn = DBUtil.getConnection();
             PreparedStatement stmt = conn.prepareStatement(
                     "SELECT order_id, payment_method, amount, qr_string, va_number, status, expires_at, is_simulated "
                             + "FROM transactions WHERE order_id = ?")) {
            stmt.setString(1, orderId);
            try (ResultSet rs = stmt.executeQuery()) {
                if (!rs.next()) {
                    return null;
                }
                java.sql.Timestamp expires = rs.getTimestamp("expires_at");
                return new Object[]{
                        rs.getString("order_id"),
                        rs.getString("payment_method"),
                        rs.getBigDecimal("amount"),
                        rs.getString("qr_string"),
                        rs.getString("va_number"),
                        rs.getString("status"),
                        expires == null ? null : expires.toLocalDateTime(),
                        rs.getBoolean("is_simulated")
                };
            }
        } catch (Exception e) {
            throw new ServiceException("Gagal memuat tagihan: " + e.getMessage(), e);
        }
    }

    /** Verifikasi token webhook gateway (constant-time). */
    public boolean verifyWebhookToken(String provided) {
        try {
            PaymentSetting setting = paymentSettingDAO.getSettings();
            String expected = setting != null ? setting.getSumopodWebhookToken() : null;
            if (expected == null || expected.isBlank()) {
                return false; // token wajib diisi admin sebelum webhook dipakai
            }
            return provided != null && java.security.MessageDigest.isEqual(
                    expected.getBytes(java.nio.charset.StandardCharsets.UTF_8),
                    provided.getBytes(java.nio.charset.StandardCharsets.UTF_8));
        } catch (Exception e) {
            return false;
        }
    }

    // ------------------------------------------------------------------ internal

    /** Panggil gateway sungguhan (dipakai hanya bila API key tersedia). */
    private Charge callGateway(PaymentSetting setting, Charge charge) {
        try {
            String apiKey = CryptoUtil.decrypt(setting.getSumopodApiKeyEnc());
            String baseUrl = System.getenv().getOrDefault("SUMOPOD_BASE_URL",
                    "https://api-pay-sandbox.sumopod.com/api/v1");

            String body = String.format(
                    "{\"order_id\":\"%s\",\"amount\":%s,\"method\":\"%s\",\"description\":\"Pembelian kuota belajar\"}",
                    charge.orderId, charge.amount.setScale(0, RoundingMode.HALF_UP).toPlainString(),
                    "Virtual Account".equals(charge.paymentMethod) ? "VA" : "QRIS");

            HttpClient client = HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(5)).build();
            HttpRequest request = HttpRequest.newBuilder()
                    .uri(URI.create(baseUrl + "/payments"))
                    .timeout(Duration.ofSeconds(12))
                    .header("Content-Type", "application/json")
                    .header("X-Api-Key", apiKey)
                    .POST(HttpRequest.BodyPublishers.ofString(body))
                    .build();
            HttpResponse<String> response = client.send(request, HttpResponse.BodyHandlers.ofString());
            if (response.statusCode() < 200 || response.statusCode() >= 300) {
                return null;
            }
            String json = response.body();
            Charge live = new Charge();
            live.orderId = charge.orderId;
            live.amount = charge.amount;
            live.paymentMethod = charge.paymentMethod;
            live.expiresAt = charge.expiresAt;
            live.qrString = extract(json, "qr_string", "qr_code", "qris");
            live.vaNumber = extract(json, "va_number", "virtual_account", "account_number");
            live.paymentUrl = extract(json, "payment_link_url", "payment_url", "url");
            live.providerRef = extract(json, "id", "payment_id", "reference");
            live.simulated = false;
            if (live.qrString == null && live.vaNumber == null && live.paymentUrl == null) {
                return null; // respons tidak berisi instruksi bayar -> pakai simulasi
            }
            return live;
        } catch (Exception e) {
            return null;
        }
    }

    /** Ekstraksi nilai string pertama yang ditemukan dari JSON sederhana. */
    private String extract(String json, String... keys) {
        if (json == null) {
            return null;
        }
        for (String key : keys) {
            java.util.regex.Matcher m = java.util.regex.Pattern
                    .compile("\"" + key + "\"\\s*:\\s*\"([^\"]+)\"")
                    .matcher(json);
            if (m.find()) {
                return m.group(1);
            }
        }
        return null;
    }

    private void persist(Charge stored, Charge charge) {
        try (Connection conn = DBUtil.getConnection();
             PreparedStatement stmt = conn.prepareStatement(
                     "UPDATE transactions SET payment_method = ?, payment_link_url = ?, qr_string = ?, "
                             + "va_number = ?, expires_at = ?, sumopod_payment_id = ?, is_simulated = ? "
                             + "WHERE order_id = ?")) {
            stmt.setString(1, stored.paymentMethod);
            stmt.setString(2, charge.paymentUrl);
            stmt.setString(3, charge.qrString);
            stmt.setString(4, charge.vaNumber);
            stmt.setTimestamp(5, java.sql.Timestamp.valueOf(stored.expiresAt));
            stmt.setString(6, charge.providerRef);
            stmt.setBoolean(7, charge.simulated);
            stmt.setString(8, stored.orderId);
            stmt.executeUpdate();
        } catch (Exception e) {
            System.err.println("PaymentGatewayService: gagal menyimpan detail tagihan: " + e.getMessage());
        }
    }

    /**
     * Payload QRIS (format EMVCo): dikenali aplikasi pemindai QRIS sebagai
     * tagihan dengan nominal tetap. CRC16-CCITT dihitung pada akhir payload.
     */
    static String buildQrisPayload(String orderId, BigDecimal amount) {
        String merchant = "EXATUYDEMO";
        String amountStr = amount.setScale(2, RoundingMode.HALF_UP).toPlainString();
        String payload = "000201"                       // versi 01
                + "010212"                              // 02 = QRIS dinamis (nominal tetap)
                + "26" + String.format("%02d", 14 + merchant.length())
                + "0016ID.CO.EXATUY.WWW" + "02" + String.format("%02d", merchant.length()) + merchant
                + "5204" + "5999"                       // kategori merchant (dummy)
                + "5303360"                             // mata uang IDR
                + "54" + String.format("%02d", amountStr.length()) + amountStr
                + "5802ID"
                + "62" + String.format("%02d", 4 + Math.min(orderId.length(), 25))
                + "05" + String.format("%02d", Math.min(orderId.length(), 25))
                + orderId.substring(0, Math.min(orderId.length(), 25))
                + "6304";
        return payload + crc16(payload);
    }

    /** Nomor VA internal: "8808" + 8 digit dari hash order + 4 digit acak tetap. */
    static String buildVaNumber(String orderId) {
        int hash = Math.abs(orderId.hashCode());
        int random = Math.abs(new Random(orderId.hashCode()).nextInt(10000));
        return VA_PREFIX + String.format("%08d", hash % 100000000) + String.format("%04d", random);
    }

    static String crc16(String data) {
        int crc = 0xFFFF;
        for (int i = 0; i < data.length(); i++) {
            crc ^= (data.charAt(i) & 0xFF) << 8;
            for (int bit = 0; bit < 8; bit++) {
                crc = (crc & 0x8000) != 0 ? ((crc << 1) ^ 0x1021) : (crc << 1);
                crc &= 0xFFFF;
            }
        }
        return String.format("%04X", crc & 0xFFFF);
    }

    private String shortRef(String orderId) {
        return Integer.toHexString(Math.abs(orderId.hashCode()));
    }

    public static class ServiceException extends Exception {
        public ServiceException(String message) { super(message); }
        public ServiceException(String message, Throwable cause) { super(message, cause); }
    }
}
