package com.examora.controller;

import com.examora.dao.CashInTransactionDAO;
import com.examora.dao.PaymentSettingDAO;
import com.examora.dao.UserDAO;
import com.examora.model.CashInTransaction;
import com.examora.model.PaymentSetting;
import com.examora.model.User;
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
import java.util.UUID;

/**
 * PaymentSettingsServlet - Handles:
 * 1. Admin/Teacher UI Pengaturan Pembayaran Sumopod (P0 #10)
 * 2. Student Halaman Checkout Paket Kuota (P0 #10 / FR-007)
 */
@WebServlet("/PaymentSettingsServlet")
public class PaymentSettingsServlet extends HttpServlet {
    private PaymentSettingDAO paymentSettingDAO;
    private CashInTransactionDAO transactionDAO;
    private UserDAO userDAO;

    @Override
    public void init() throws ServletException {
        paymentSettingDAO = new PaymentSettingDAO();
        transactionDAO = new CashInTransactionDAO();
        userDAO = new UserDAO();
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
            showStudentCheckout(request, response, currentUser);
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
        } catch (Exception e) {
            session.setAttribute("flashError", "Gagal menyimpan pengaturan pembayaran: " + e.getMessage());
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
        List<CashInTransaction> history = transactionDAO.findByStudentId(currentUser.getId());

        int currentBalance = currentUser.getQuotaBalance();
        int maxQuota = setting.getMaxQuotaPerMonth();
        int remainingCapacity = Math.max(0, maxQuota - currentBalance);

        request.setAttribute("paymentSetting", setting);
        request.setAttribute("currentBalance", currentBalance);
        request.setAttribute("maxQuota", maxQuota);
        request.setAttribute("remainingCapacity", remainingCapacity);
        request.setAttribute("transactions", history);

        request.getRequestDispatcher("/user/quota-checkout.jsp").forward(request, response);
    }

    private void handleCreateCheckoutOrder(HttpServletRequest request, HttpServletResponse response, User currentUser)
            throws IOException {
        HttpSession session = request.getSession();
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

            int points = Integer.parseInt(request.getParameter("points"));
            String paymentMethod = request.getParameter("paymentMethod");
            if (paymentMethod == null || paymentMethod.trim().isEmpty()) {
                paymentMethod = "QRIS";
            }

            int maxQuota = setting.getMaxQuotaPerMonth();
            int currentBalance = currentUser.getQuotaBalance();
            if (points < 1) {
                throw new IllegalArgumentException("Jumlah pembelian minimal 1 poin.");
            }
            if (currentBalance + points > maxQuota) {
                int maxAllowed = Math.max(0, maxQuota - currentBalance);
                throw new IllegalArgumentException(
                    "Pembelian melebihi batas maksimal " + maxQuota + " poin/bulan. " +
                    "Saldo Anda saat ini " + currentBalance + " poin, maksimal top-up: " + maxAllowed + " poin."
                );
            }

            BigDecimal amount = setting.calculatePackagePrice(points);
            String timestamp = LocalDateTime.now().format(DateTimeFormatter.ofPattern("yyyyMMddHHmmss"));
            String shortRand = UUID.randomUUID().toString().substring(0, 6).toUpperCase();
            String orderId = "INV-EXA-" + timestamp + "-" + shortRand;

            CashInTransaction tx = new CashInTransaction();
            tx.setOrderId(orderId);
            tx.setStudentId(currentUser.getId());
            tx.setPointsPurchased(points);
            tx.setAmount(amount);
            tx.setStatus("pending");
            tx.setPaymentMethod(paymentMethod.trim());
            tx.setSumopodPaymentId((setting.isLiveMode() ? "sp_live_" : "sp_sbx_") + shortRand.toLowerCase());
            tx.setPaymentLinkUrl("https://sumopod.com/pay/" + orderId);

            transactionDAO.create(tx);
            session.setAttribute("flashSuccess",
                "Pesanan " + orderId + " (" + points + " Poin — Rp " + String.format("%,.0f", amount) + ") berhasil dibuat dengan status Pending.");
        } catch (Exception e) {
            session.setAttribute("flashError", "Gagal membuat pesanan kuota: " + e.getMessage());
        }

        response.sendRedirect(request.getContextPath() + "/PaymentSettingsServlet?action=checkout");
    }
}
