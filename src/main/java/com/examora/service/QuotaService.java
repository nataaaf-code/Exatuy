package com.examora.service;

import com.examora.dao.QuotaDAO;

import java.sql.SQLException;
import java.time.Instant;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;

/**
 * Quota Service - Dompet kuota/poin siswa (maks. 12 poin, non-rollover).
 * Saldo hangus setiap tanggal 1 pukul 00:00 WIB: lewat scheduler, dan
 * fail-safe lazy reset pada setiap akses dompet (termasuk saat login).
 */
public class QuotaService {
    public static final int MAX_QUOTA = 12;
    public static final ZoneId WIB = ZoneId.of("Asia/Jakarta");
    private static final DateTimeFormatter MONTH = DateTimeFormatter.ofPattern("yyyy-MM").withZone(WIB);

    private final QuotaDAO quotaDAO;

    public QuotaService() {
        this.quotaDAO = new QuotaDAO();
    }

    /**
     * Periode saldo (YYYY-MM) menurut waktu WIB.
     */
    public static String monthKey(Instant now) {
        return MONTH.format(now);
    }

    /**
     * Saldo saat ini; menjalankan lazy reset jika sudah berganti bulan.
     */
    public int getBalance(int userId) throws ServiceException {
        return change(userId, 0, null, null);
    }

    /**
     * Validasi pembelian sebelum checkout: saldo setelah top-up tidak boleh melebihi 12.
     *
     * @return saldo saat ini
     */
    public int validateTopUp(int userId, int points) throws ServiceException {
        validatePoints(points);
        int balance = getBalance(userId);
        if (balance + points > MAX_QUOTA) {
            throw new ServiceException(topUpLimitMessage(balance));
        }
        return balance;
    }

    /**
     * Tambah poin hasil pembelian.
     *
     * @return saldo baru
     */
    public int topUp(int userId, int points, String orderId) throws ServiceException {
        validatePoints(points);
        return change(userId, points, "topup", orderId);
    }

    /**
     * Potong 1 poin untuk memulai Exam ("exam") atau masuk sesi GMeet ("gmeet").
     *
     * @return saldo baru
     */
    public int consume(int userId, String reason, String referenceId) throws ServiceException {
        if (!"exam".equals(reason) && !"gmeet".equals(reason)) {
            throw new IllegalArgumentException("Unknown quota reason: " + reason);
        }
        return change(userId, -1, reason, referenceId);
    }

    /**
     * Reset massal untuk scheduler. Idempoten: hanya menyentuh siswa yang periodenya tertinggal.
     *
     * @return jumlah siswa yang direset
     */
    public int resetForCurrentMonth() throws ServiceException {
        try {
            return quotaDAO.resetAllForMonth(monthKey(Instant.now()));
        } catch (SQLException e) {
            throw new ServiceException("Gagal mereset kuota bulanan: " + e.getMessage(), e);
        }
    }

    static void validatePoints(int points) throws ServiceException {
        if (points < 1 || points > MAX_QUOTA) {
            throw new ServiceException("Jumlah poin harus antara 1 dan " + MAX_QUOTA);
        }
    }

    static String topUpLimitMessage(int balance) {
        return "Saldo kuota maksimal " + MAX_QUOTA + " poin. Saldo kamu saat ini " + balance
                + " poin, jadi maksimal bisa membeli " + (MAX_QUOTA - balance) + " poin lagi.";
    }

    private int change(int userId, int delta, String reason, String referenceId) throws ServiceException {
        try {
            return quotaDAO.applyChange(userId, delta, MAX_QUOTA, reason, referenceId, monthKey(Instant.now()));
        } catch (QuotaDAO.LimitException e) {
            if (delta < 0) {
                throw new ServiceException("Kuota/poin belajar kamu sudah habis. Silakan beli paket kuota (maks. "
                        + MAX_QUOTA + " poin) untuk mengikuti Exam atau GMeet.");
            }
            throw new ServiceException(topUpLimitMessage(e.getBalance()));
        } catch (SQLException e) {
            throw new ServiceException("Gagal memproses kuota: " + e.getMessage(), e);
        }
    }

    /**
     * Service Exception
     */
    public static class ServiceException extends Exception {
        public ServiceException(String message) {
            super(message);
        }

        public ServiceException(String message, Throwable cause) {
            super(message, cause);
        }
    }
}
