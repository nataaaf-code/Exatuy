package com.examora.controller;

import com.examora.dao.CashInTransactionDAO;
import com.examora.dao.PaymentSettingDAO;
import com.examora.dao.UserDAO;
import com.examora.model.CashInTransaction;
import com.examora.model.PaymentSetting;
import com.examora.model.User;
import com.examora.service.PaymentGatewayService;
import com.examora.service.QuotaService;
import com.examora.util.CryptoUtil;

import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;

import java.io.IOException;
import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;
import java.util.logging.Level;
import java.util.logging.Logger;

/**
 * PaymentSettingsServlet - Handles:
 * 1. Admin/Teacher UI Pengaturan Pembayaran Sumopod (P0 #10)
 * 2. Student Halaman Checkout Paket Kuota (P0 #10 / FR-007)
 */
@WebServlet("/PaymentSettingsServlet")
public class PaymentSettingsServlet extends HttpServlet {
    private static final Logger LOGGER = Logger.getLogger(PaymentSettingsServlet.class.getName());
    private static final Map<Integer, Object> ORDER_LOCKS = new ConcurrentHashMap<>();

    private PaymentSettingDAO paymentSettingDAO;
    private CashInTransactionDAO transactionDAO;
    private UserDAO userDAO;
    private com.examora.service.PaymentGatewayService paymentGatewayService;
    private QuotaService quotaService;

    @Override
    public void init() throws ServletException {
        paymentSettingDAO = new PaymentSettingDAO();
        transactionDAO = new CashInTransactionDAO();
        userDAO = new UserDAO();
        paymentGatewayService = new com.examora.service.PaymentGatewayService();
        quotaService = new QuotaService();
    }

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        HttpSession session = request.getSession(false);
        User currentUser = session != null ? (User) session.getAttribute("user") : null;
        if (currentUser == null) {
            response.sendRedirect(request.getContextPath() + "/LoginServlet");
            return;
        }

        String action = request.getParameter("action");
        if ("checkout".equalsIgnoreCase(action)) {
            // F9: halaman checkout hanya untuk siswa; pengelola memakai halaman pengaturan.
            if (isAdminViewer(currentUser)) {
                response.sendRedirect(request.getContextPath() + "/PaymentSettingsServlet?action=settings");
                return;
            }
            showStudentCheckout(request, response, currentUser);
            return;
        }
        if ("pay".equalsIgnoreCase(action)) {
            showPaymentPage(request, response, currentUser);
            return;
        }

        // Admin settings page
        if (!currentUser.isAdmin() && !"owner".equals(currentUser.getRole())) {
            response.sendRedirect(request.getContextPath() + "/PaymentSettingsServlet?action=checkout");
            return;
        }

        showAdminSettings(request, response);
    }

    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        HttpSession session = request.getSession(false);
        User currentUser = session != null ? (User) session.getAttribute("user") : null;
        if (currentUser == null) {
            response.sendRedirect(request.getContextPath() + "/LoginServlet");
            return;
        }

        String action = request.getParameter("action");
        if ("createOrder".equalsIgnoreCase(action)) {
            handleCreateCheckoutOrder(request, response, currentUser);
            return;
        }
        if ("confirmPayment".equalsIgnoreCase(action)) {
            handleConfirmPayment(request, response, currentUser);
            return;
        }

        // Admin save settings
        if (!currentUser.isAdmin() && !"owner".equals(currentUser.getRole())) {
            response.sendError(HttpServletResponse.SC_FORBIDDEN, "Akses ditolak");
            return;
        }

        handleSaveSettings(request, response);
    }

    private void showAdminSettings(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        PaymentSetting setting = paymentSettingDAO.getSettings();
        String maskedApiKey = "";
        if (setting.isConfigured()) {
            try {
                String plain = CryptoUtil.decrypt(setting.getSumopodApiKeyEnc());
                maskedApiKey = CryptoUtil.maskSecret(plain);
            } catch (Exception e) {
                maskedApiKey = "•••••••• (Terenkripsi)";
            }
        }

        String scheme = request.getScheme();
        String serverName = request.getServerName();
        int serverPort = request.getServerPort();
        String contextPath = request.getContextPath();
        String portPart = (serverPort == 80 || serverPort == 443) ? "" : (":" + serverPort);
        String webhookUrl = scheme + "://" + serverName + portPart + contextPath + "/SumopodWebhookServlet";

        request.setAttribute("paymentSetting", setting);
        request.setAttribute("maskedApiKey", maskedApiKey);
        request.setAttribute("webhookUrl", webhookUrl);
        request.getRequestDispatcher("/admin/payment-settings.jsp").forward(request, response);
    }

    private void handleSaveSettings(HttpServletRequest request, HttpServletResponse response)
            throws IOException {
        HttpSession session = request.getSession();
        try {
            PaymentSetting existing = paymentSettingDAO.getSettings();

            String rawApiKey = request.getParameter("sumopodApiKey");
            String webhookToken = request.getParameter("sumopodWebhookToken");
            String mode = request.getParameter("paymentMode");
            String priceStr = request.getParameter("dummyPricePerPoint");
            String maxQuotaStr = request.getParameter("maxQuotaPerMonth");
            boolean clearApiKey = "true".equalsIgnoreCase(request.getParameter("clearApiKey"));

            PaymentSetting updated = new PaymentSetting();
            updated.setId(1);

            if (clearApiKey) {
                updated.setSumopodApiKeyEnc(null);
            } else if (rawApiKey != null && !rawApiKey.trim().isEmpty()) {
                updated.setSumopodApiKeyEnc(CryptoUtil.encrypt(rawApiKey.trim()));
            } else {
                updated.setSumopodApiKeyEnc(existing.getSumopodApiKeyEnc());
            }

            updated.setSumopodWebhookToken(webhookToken != null ? webhookToken.trim() : "");
            updated.setLiveMode("live".equalsIgnoreCase(mode));

            BigDecimal price = new BigDecimal("10000.00");
            if (priceStr != null && !priceStr.trim().isEmpty()) {
                String cleaned = priceStr.trim().replace(".", "").replace(",", ".");
                price = new BigDecimal(cleaned);
                if (price.compareTo(BigDecimal.ZERO) < 0) {
                    throw new IllegalArgumentException("Harga per poin tidak boleh negatif.");
                }
            }
            updated.setDummyPricePerPoint(price);

            int maxQuota = 12;
            if (maxQuotaStr != null && !maxQuotaStr.trim().isEmpty()) {
                maxQuota = Integer.parseInt(maxQuotaStr.trim());
                if (maxQuota < 1 || maxQuota > 12) {
                    maxQuota = 12;
                }
            }
            updated.setMaxQuotaPerMonth(maxQuota);

            paymentSettingDAO.saveSettings(updated);
            session.setAttribute("flashSuccess", "Pengaturan pembayaran Sumopod berhasil disimpan & API Key terenkripsi AES-256.");
        } catch (NumberFormatException e) {
            session.setAttribute("flashError", "Gagal menyimpan pengaturan pembayaran: harga dan batas kuota harus berupa angka.");
        } catch (IllegalArgumentException e) {
            session.setAttribute("flashError", "Gagal menyimpan pengaturan pembayaran: " + e.getMessage());
        } catch (Exception e) {
            LOGGER.log(Level.WARNING, "Gagal menyimpan pengaturan pembayaran", e);
            session.setAttribute("flashError", "Gagal menyimpan pengaturan pembayaran. Silakan coba lagi.");
        }

        response.sendRedirect(request.getContextPath() + "/PaymentSettingsServlet");
    }

    private void showStudentCheckout(HttpServletRequest request, HttpServletResponse response, User currentUser)
            throws ServletException, IOException {
        try {
            User freshUser = userDAO.findById(currentUser.getId());
            if (freshUser != null) {
                currentUser = freshUser;
                request.getSession().setAttribute("user", freshUser);
            }
        } catch (Exception ignored) {}

        PaymentSetting setting = paymentSettingDAO.getSettings();

        // Saldo dan tagihan pending dibaca dari sumber yang sama dengan validasi pesanan
        int currentBalance = currentUser.getQuotaBalance();
        int pendingPoints = 0;
        try {
            paymentGatewayService.expireStaleOrders();
            currentBalance = quotaService.getBalance(currentUser.getId());
            currentUser.setQuotaBalance(currentBalance);
            pendingPoints = paymentGatewayService.pendingPoints(currentUser.getId());
        } catch (Exception e) {
            LOGGER.log(Level.WARNING, "Gagal memuat saldo kuota untuk checkout", e);
        }
        List<CashInTransaction> history = transactionDAO.findByStudentId(currentUser.getId());

        int maxQuota = setting.getMaxQuotaPerMonth();
        int remainingCapacity = Math.max(0, maxQuota - currentBalance - pendingPoints);

        request.setAttribute("paymentSetting", setting);
        request.setAttribute("currentBalance", currentBalance);
        request.setAttribute("pendingPoints", pendingPoints);
        request.setAttribute("maxQuota", maxQuota);
        request.setAttribute("remainingCapacity", remainingCapacity);
        request.setAttribute("transactions", history);

        request.getRequestDispatcher("/user/quota-checkout.jsp").forward(request, response);
    }

    private void handleCreateCheckoutOrder(HttpServletRequest request, HttpServletResponse response, User currentUser)
            throws IOException {
        HttpSession session = request.getSession();
        String orderId = null;
        try {
            User freshUser = userDAO.findById(currentUser.getId());
            if (freshUser != null) {
                currentUser = freshUser;
                session.setAttribute("user", freshUser);
            }

            PaymentSetting setting = paymentSettingDAO.getSettings();
            if (!setting.isConfigured()) {
                session.setAttribute("flashError", "Sistem pembayaran Sumopod sedang dalam konfigurasi pengajar. Silakan hubungi pengajar.");
                response.sendRedirect(request.getContextPath() + "/PaymentSettingsServlet?action=checkout");
                return;
            }

            int points = parsePoints(request.getParameter("points"));
            String paymentMethod = request.getParameter("paymentMethod");
            if (paymentMethod == null || paymentMethod.trim().isEmpty()) {
                paymentMethod = "QRIS";
            }

            BigDecimal amount = setting.calculatePackagePrice(points);

            // Validasi dan pencatatan pesanan diproses satu per satu untuk tiap siswa, supaya
            // dua pesanan yang dibuat bersamaan tidak sama-sama lolos dari batas saldo.
            synchronized (ORDER_LOCKS.computeIfAbsent(currentUser.getId(), id -> new Object())) {
                paymentGatewayService.expireStaleOrders();
                int currentBalance = quotaService.getBalance(currentUser.getId());
                currentUser.setQuotaBalance(currentBalance);
                checkTopUpAllowed(currentBalance, paymentGatewayService.pendingPoints(currentUser.getId()),
                        points, setting.getMaxQuotaPerMonth());

                String timestamp = LocalDateTime.now().format(DateTimeFormatter.ofPattern("yyyyMMddHHmmss"));
                String shortRand = UUID.randomUUID().toString().substring(0, 6).toUpperCase();
                orderId = "INV-EXA-" + timestamp + "-" + shortRand;

                CashInTransaction tx = new CashInTransaction();
                tx.setOrderId(orderId);
                tx.setStudentId(currentUser.getId());
                tx.setPointsPurchased(points);
                tx.setAmount(amount);
                tx.setStatus("pending");
                tx.setPaymentMethod(paymentMethod.trim());

                transactionDAO.create(tx);
            }

            // Buat instruksi bayar. Pada mode sandbox, bila gateway tidak bisa dihubungi,
            // layanan memakai tagihan simulasi sehingga alur tetap bisa didemokan.
            paymentGatewayService.createCharge(orderId, amount, paymentMethod);

            session.setAttribute("flashSuccess",
                "Pesanan " + orderId + " dibuat. Selesaikan pembayaran Rp "
                + String.format("%,.0f", amount) + " untuk " + points + " poin.");
            response.sendRedirect(request.getContextPath()
                    + "/PaymentSettingsServlet?action=pay&orderId=" + java.net.URLEncoder.encode(orderId, "UTF-8"));
            return;
        } catch (IllegalArgumentException e) {
            session.setAttribute("flashError", "Gagal membuat pesanan kuota: " + e.getMessage());
        } catch (PaymentGatewayService.ServiceException e) {
            LOGGER.log(Level.WARNING, "Tagihan tidak dapat dibuat", e);
            if (orderId != null) {
                try {
                    paymentGatewayService.markFailed(orderId);
                } catch (PaymentGatewayService.ServiceException ignored) {
                    // tagihan akan ditandai gagal oleh penjadwal saat kedaluwarsa
                }
            }
            session.setAttribute("flashError",
                "Pembayaran online sedang tidak dapat dihubungi. Silakan coba lagi nanti atau hubungi pengajar.");
        } catch (Exception e) {
            LOGGER.log(Level.WARNING, "Gagal membuat pesanan kuota", e);
            session.setAttribute("flashError", "Gagal membuat pesanan kuota. Silakan coba lagi.");
        }

        response.sendRedirect(request.getContextPath() + "/PaymentSettingsServlet?action=checkout");
    }

    static int parsePoints(String value) {
        try {
            return Integer.parseInt(value == null ? "" : value.trim());
        } catch (NumberFormatException e) {
            throw new IllegalArgumentException("Jumlah poin harus berupa angka.");
        }
    }

    /**
     * Saldo + tagihan yang masih menunggu pembayaran + pembelian baru tidak boleh melebihi batas.
     */
    static void checkTopUpAllowed(int balance, int pendingPoints, int points, int maxQuota) {
        if (points < 1) {
            throw new IllegalArgumentException("Jumlah pembelian minimal 1 poin.");
        }
        if (balance + pendingPoints + points > maxQuota) {
            int maxAllowed = Math.max(0, maxQuota - balance - pendingPoints);
            throw new IllegalArgumentException(
                "Pembelian melebihi batas maksimal " + maxQuota + " poin/bulan. " +
                "Saldo Anda saat ini " + balance + " poin" +
                (pendingPoints > 0 ? " dan ada tagihan " + pendingPoints + " poin yang belum dibayar" : "") +
                ", maksimal top-up: " + maxAllowed + " poin."
            );
        }
    }

    /**
     * Halaman instruksi pembayaran (QRIS / Virtual Account) untuk satu order.
     */
    private void showPaymentPage(HttpServletRequest request, HttpServletResponse response, User currentUser)
            throws ServletException, IOException {
        String orderId = request.getParameter("orderId");
        if (orderId == null || orderId.isBlank()) {
            response.sendRedirect(request.getContextPath() + "/PaymentSettingsServlet?action=checkout");
            return;
        }

        try {
            paymentGatewayService.expireStaleOrders();
            Object[] order = paymentGatewayService.findOrder(orderId);
            boolean isOwner = order != null && ownsOrder(order, currentUser);
            boolean isAdminViewer = currentUser.isAdmin() || "owner".equals(currentUser.getRole());
            if (order == null || !String.valueOf(order[0]).equals(orderId) || (!isOwner && !isAdminViewer)) {
                request.getSession().setAttribute("flashError", "Pesanan tidak ditemukan.");
                response.sendRedirect(request.getContextPath() + "/PaymentSettingsServlet?action=checkout");
                return;
            }
            request.setAttribute("orderId", order[0]);
            request.setAttribute("paymentMethod", order[1]);
            request.setAttribute("amount", order[2]);
            request.setAttribute("qrString", order[3]);
            request.setAttribute("vaNumber", order[4]);
            request.setAttribute("status", order[5]);
            request.setAttribute("expiresAt", order[6]);
            request.setAttribute("simulated", order[7]);
            request.setAttribute("paymentUrl", order[9]);
            request.setAttribute("canSelfConfirm", isOwner && PaymentGatewayService.canSelfConfirm(
                    Boolean.TRUE.equals(order[7]), paymentGatewayService.isLiveMode()));
            request.getRequestDispatcher("/user/payment-pay.jsp").forward(request, response);
        } catch (Exception e) {
            LOGGER.log(Level.WARNING, "Gagal memuat tagihan", e);
            request.getSession().setAttribute("flashError", "Gagal memuat tagihan. Silakan coba lagi.");
            response.sendRedirect(request.getContextPath() + "/PaymentSettingsServlet?action=checkout");
        }
    }

    private static boolean ownsOrder(Object[] order, User user) {
        return user.getId() != null && user.getId().equals(order[8]);
    }

    /** F9: pengelola (admin/owner) tidak memakai halaman checkout siswa. */
    static boolean isAdminViewer(User user) {
        return user != null && (user.isAdmin() || "owner".equals(user.getRole()));
    }

    /**
     * Konfirmasi pembayaran oleh siswa: hanya untuk tagihan simulasi miliknya sendiri pada
     * mode sandbox (demo). Tagihan asli dilunasi lewat webhook gateway.
     */
    private void handleConfirmPayment(HttpServletRequest request, HttpServletResponse response, User currentUser)
            throws IOException {
        HttpSession session = request.getSession();
        String orderId = request.getParameter("orderId");
        try {
            if (orderId == null || orderId.isBlank()) {
                throw new IllegalArgumentException("Nomor pesanan tidak valid.");
            }
            paymentGatewayService.expireStaleOrders();
            Object[] order = paymentGatewayService.findOrder(orderId);
            if (order == null || !ownsOrder(order, currentUser)) {
                throw new IllegalArgumentException("Pesanan tidak ditemukan.");
            }
            if (!PaymentGatewayService.canSelfConfirm(Boolean.TRUE.equals(order[7]), paymentGatewayService.isLiveMode())) {
                throw new IllegalArgumentException(
                        "Pesanan ini dikonfirmasi otomatis setelah pembayaran diterima.");
            }
            if ("failed".equalsIgnoreCase(String.valueOf(order[5]))) {
                throw new IllegalArgumentException(
                        "Pesanan ini sudah kedaluwarsa atau dibatalkan. Silakan buat pesanan baru.");
            }
            paymentGatewayService.settle(orderId);
            session.setAttribute("flashSuccess", "Pembayaran pesanan " + orderId + " berhasil. Poin sudah ditambahkan.");
        } catch (IllegalArgumentException e) {
            session.setAttribute("flashError", "Gagal memproses pembayaran: " + e.getMessage());
        } catch (Exception e) {
            LOGGER.log(Level.WARNING, "Gagal memproses konfirmasi pembayaran", e);
            session.setAttribute("flashError", "Gagal memproses pembayaran. Silakan coba lagi.");
        }
        response.sendRedirect(request.getContextPath()
                + "/PaymentSettingsServlet?action=pay&orderId=" + java.net.URLEncoder.encode(
                        orderId == null ? "" : orderId, "UTF-8"));
    }
}
