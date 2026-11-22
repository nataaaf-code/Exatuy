package com.examora.service;

import com.examora.dao.PaymentSettingDAO;
import com.examora.model.PaymentSetting;
import com.examora.util.CryptoUtil;
import com.examora.util.DBUtil;
import com.google.gson.JsonObject;
import com.google.gson.JsonParser;

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
 * Dua jenis tagihan:
 *  - **Asli**: bila API key gateway sudah diisi admin, kode memanggil endpoint
 *    gateway (sandbox atau live sesuai pengaturan, bisa ditimpa `SUMOPOD_BASE_URL`)
 *    untuk memperoleh tautan bayar dan payload QRIS. Tagihan ini hanya dilunasi
 *    lewat notifikasi webhook dari gateway.
 *  - **Simulasi**: hanya pada mode sandbox, bila panggilan gateway gagal, layanan
 *    membuat payload QRIS yang valid secara format + nomor VA internal, menandai
 *    transaksi `is_simulated = 1`, dan menyediakan tombol "sudah dibayar" untuk
 *    demo. Pada mode live, kegagalan gateway membuat pesanan gagal.
 */
public class PaymentGatewayService {

    /** Masa berlaku tagihan (menit). */
    public static final int EXPIRY_MINUTES = 30;

    /** Prefix Virtual Account internal (bukan kode bank asli). */
    private static final String VA_PREFIX = "8808";

    private static final java.util.logging.Logger LOGGER =
            java.util.logging.Logger.getLogger(PaymentGatewayService.class.getName());

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
     *
     * @throws ServiceException mode live aktif tetapi gateway tidak bisa membuat tagihan
     */
    public Charge createCharge(String orderId, BigDecimal amount, String method) throws ServiceException {
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
                persist(live, live);
                return live;
            }
            if (setting.isLiveMode()) {
                // Mode live tidak boleh jatuh ke tagihan simulasi yang tidak bisa dibayar.
                throw new ServiceException("Gerbang pembayaran tidak dapat membuat tagihan untuk " + orderId);
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
        try (Connection conn = DBUtil.getConnection()) {
            conn.setAutoCommit(false);
            try {
                int studentId;
                int points;
                boolean alreadySettled;
                String sql = "SELECT student_id, points_purchased, status, settled_at "
                        + "FROM transactions WHERE order_id = ? FOR UPDATE";
                try (PreparedStatement stmt = conn.prepareStatement(sql)) {
                    stmt.setString(1, orderId);
                    try (ResultSet rs = stmt.executeQuery()) {
                        if (!rs.next()) {
                            throw new ServiceException("Pesanan tidak ditemukan: " + orderId);
                        }
                        studentId = rs.getInt("student_id");
                        points = rs.getInt("points_purchased");
                        alreadySettled = "completed".equalsIgnoreCase(rs.getString("status"))
                                || rs.getTimestamp("settled_at") != null;
                    }
                }

                // Status lunas dan penambahan poin berada dalam satu transaksi DB, sehingga
                // notifikasi ganda tidak menambah poin dua kali dan poin tidak bisa tertinggal.
                if (!alreadySettled) {
                    try (PreparedStatement stmt = conn.prepareStatement(
                            "UPDATE transactions SET status = 'completed', paid_at = NOW(), settled_at = NOW() "
                                    + "WHERE order_id = ?")) {
                        stmt.setString(1, orderId);
                        stmt.executeUpdate();
                    }
                    int credited = quotaService.creditPurchase(conn, studentId, points, orderId);
                    if (credited < points) {
                        LOGGER.warning("Pesanan " + orderId + " lunas, tetapi hanya " + credited + " dari " + points
                                + " poin yang ditambahkan karena saldo dibatasi " + QuotaService.MAX_QUOTA + " poin");
                    }
                }
                conn.commit();
                return true;
            } catch (Exception e) {
                conn.rollback();
                throw e;
            } finally {
                conn.setAutoCommit(true);
            }
        } catch (ServiceException e) {
            throw e;
        } catch (Exception e) {
            throw new ServiceException("Gagal menyelesaikan pembayaran: " + e.getMessage(), e);
        }
    }

    /**
     * Tandai order gagal/kedaluwarsa. Order yang sudah lunas tidak pernah diturunkan.
     *
     * @return true bila status berubah dari pending menjadi failed
     */
    public boolean markFailed(String orderId) throws ServiceException {
        return update("UPDATE transactions SET status = 'failed' WHERE order_id = ? AND status = 'pending'", orderId) > 0;
    }

    /**
     * Jumlah poin pada tagihan siswa yang masih menunggu pembayaran.
     */
    public int pendingPoints(int studentId) throws ServiceException {
        try (Connection conn = DBUtil.getConnection();
             PreparedStatement stmt = conn.prepareStatement(
                     "SELECT COALESCE(SUM(points_purchased), 0) FROM transactions "
                             + "WHERE student_id = ? AND status = 'pending'")) {
            stmt.setInt(1, studentId);
            try (ResultSet rs = stmt.executeQuery()) {
                return rs.next() ? rs.getInt(1) : 0;
            }
        } catch (Exception e) {
            throw new ServiceException("Gagal memuat tagihan: " + e.getMessage(), e);
        }
    }

    /**
     * Tandai gagal semua tagihan pending yang sudah lewat batas waktu bayar.
     */
    public int expireStaleOrders() throws ServiceException {
        return update("UPDATE transactions SET status = 'failed' WHERE status = 'pending' "
                        + "AND expires_at IS NOT NULL AND expires_at < ?",
                java.sql.Timestamp.valueOf(LocalDateTime.now(ZoneId.of("Asia/Jakarta"))));
    }

    /** Order id untuk ID pembayaran dari gateway, atau null bila tidak dikenal. */
    public String findOrderIdByPaymentId(String paymentId) throws ServiceException {
        try (Connection conn = DBUtil.getConnection();
             PreparedStatement stmt = conn.prepareStatement(
                     "SELECT order_id FROM transactions WHERE sumopod_payment_id = ?")) {
            stmt.setString(1, paymentId);
            try (ResultSet rs = stmt.executeQuery()) {
                return rs.next() ? rs.getString(1) : null;
            }
        } catch (Exception e) {
            throw new ServiceException("Gagal mencari tagihan: " + e.getMessage(), e);
        }
    }

    /**
     * Tombol "Saya sudah membayar" hanya untuk tagihan simulasi pada mode sandbox (demo).
     * Tagihan asli hanya bisa dilunasi lewat notifikasi dari gateway.
     */
    public static boolean canSelfConfirm(boolean simulated, boolean liveMode) {
        return simulated && !liveMode;
    }

    public boolean isLiveMode() {
        try {
            PaymentSetting setting = paymentSettingDAO.getSettings();
            return setting != null && setting.isLiveMode();
        } catch (Exception e) {
            return true;
        }
    }

    private int update(String sql, Object param) throws ServiceException {
        try (Connection conn = DBUtil.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setObject(1, param);
            return stmt.executeUpdate();
        } catch (Exception e) {
            throw new ServiceException("Gagal memperbarui tagihan: " + e.getMessage(), e);
        }
    }

    /**
     * Ambil detail tagihan untuk ditampilkan di halaman pembayaran.
     * Urutan array: orderId, method, amount, qrString, vaNumber, status, expiresAt, isSimulated,
     * studentId, paymentLinkUrl
     */
    public Object[] findOrder(String orderId) throws ServiceException {
        try (Connection conn = DBUtil.getConnection();
             PreparedStatement stmt = conn.prepareStatement(
                     "SELECT order_id, payment_method, amount, qr_string, va_number, status, expires_at, is_simulated, "
                             + "student_id, payment_link_url FROM transactions WHERE order_id = ?")) {
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
                        rs.getBoolean("is_simulated"),
                        rs.getInt("student_id"),
                        rs.getString("payment_link_url")
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

            HttpClient client = HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(5)).build();
            HttpRequest request = HttpRequest.newBuilder()
                    .uri(URI.create(gatewayBaseUrl(System.getenv("SUMOPOD_BASE_URL"), setting.isLiveMode()) + "/payments"))
                    .timeout(Duration.ofSeconds(12))
                    .header("Content-Type", "application/json")
                    .header("X-Api-Key", apiKey)
                    .POST(HttpRequest.BodyPublishers.ofString(buildPaymentRequest(charge.orderId, charge.amount)))
                    .build();
            HttpResponse<String> response = client.send(request, HttpResponse.BodyHandlers.ofString());
            if (response.statusCode() < 200 || response.statusCode() >= 300) {
                LOGGER.warning("Gateway menolak pembuatan tagihan " + charge.orderId + ": HTTP " + response.statusCode());
                return null;
            }
            return parsePaymentResponse(charge, response.body());
        } catch (Exception e) {
            LOGGER.warning("Gateway tidak dapat dihubungi untuk " + charge.orderId + ": " + e.getClass().getSimpleName());
            return null;
        }
    }

    /** SUMOPOD_BASE_URL menimpa alamat bawaan; tanpa itu alamat mengikuti mode sandbox/live. */
    static String gatewayBaseUrl(String override, boolean liveMode) {
        if (override != null && !override.isBlank()) {
            return override.trim();
        }
        return liveMode ? "https://api-pay.sumopod.com/api/v1" : "https://api-pay-sandbox.sumopod.com/api/v1";
    }

    /** Body POST /payments. Gateway saat ini hanya mendukung QRIS. */
    static String buildPaymentRequest(String orderId, BigDecimal amount) {
        JsonObject body = new JsonObject();
        body.addProperty("order_id", orderId);
        body.addProperty("amount", amount.setScale(0, RoundingMode.HALF_UP).longValueExact());
        body.addProperty("currency", "IDR");
        body.addProperty("payment_method_type_code", "QRIS");
        return body.toString();
    }

    /**
     * Baca respons POST /payments: payment_id, payment_link_url, payment_code (payload QRIS), expires_at.
     *
     * @return null bila respons tidak berisi cara membayar
     */
    static Charge parsePaymentResponse(Charge charge, String json) {
        JsonObject root;
        try {
            root = JsonParser.parseString(json).getAsJsonObject();
        } catch (Exception e) {
            return null;
        }
        JsonObject data = root.has("data") && root.get("data").isJsonObject() ? root.getAsJsonObject("data") : root;

        Charge live = new Charge();
        live.orderId = charge.orderId;
        live.amount = charge.amount;
        live.paymentMethod = "QRIS";
        live.expiresAt = charge.expiresAt;
        live.qrString = text(data, "payment_code", "qr_string");
        live.paymentUrl = text(data, "payment_link_url", "payment_url");
        live.providerRef = text(data, "payment_id", "id");
        live.simulated = false;
        if (live.paymentUrl != null && !live.paymentUrl.startsWith("https://")) {
            live.paymentUrl = null;
        }
        if (live.qrString == null && live.paymentUrl == null) {
            return null;
        }
        try {
            live.expiresAt = LocalDateTime.ofInstant(Instant.parse(text(data, "expires_at")), ZoneId.of("Asia/Jakarta"));
        } catch (Exception e) {
            // gateway tidak mengirim expires_at yang bisa dibaca: pakai batas waktu bawaan
        }
        return live;
    }

    private static String text(JsonObject json, String... keys) {
        for (String key : keys) {
            if (json.has(key) && json.get(key).isJsonPrimitive()) {
                String value = json.get(key).getAsString();
                if (!value.isBlank()) {
                    return value;
                }
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
