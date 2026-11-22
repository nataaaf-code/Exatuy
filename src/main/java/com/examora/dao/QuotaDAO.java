package com.examora.dao;

import com.examora.util.DBUtil;

import java.sql.*;

/**
 * Quota DAO - Dompet kuota/poin siswa beserta log mutasinya
 */
public class QuotaDAO {

    /**
     * Saldo berada di luar rentang 0..max setelah perubahan.
     */
    public static class LimitException extends Exception {
        private final int balance;

        public LimitException(int balance) {
            super("Quota limit exceeded");
            this.balance = balance;
        }

        /** Saldo saat ini (sudah termasuk reset bulanan) */
        public int getBalance() {
            return balance;
        }
    }

    /**
     * Ubah saldo secara atomik. Jika periode saldo bukan bulan berjalan, saldo
     * dihanguskan dulu (lazy reset) sebelum perubahan diterapkan.
     * delta = 0 hanya menjalankan lazy reset dan mengembalikan saldo.
     *
     * @return saldo baru
     */
    public int applyChange(int userId, int delta, int max, String reason, String referenceId, String month)
            throws SQLException, LimitException {
        Connection conn = null;
        try {
            conn = DBUtil.getConnection();
            conn.setAutoCommit(false);

            int balance = lockBalance(conn, userId, month);

            int newBalance = balance + delta;
            if (newBalance < 0 || newBalance > max) {
                // Reset bulanan tetap disimpan walaupun perubahan ditolak
                updateBalance(conn, userId, balance, month);
                conn.commit();
                throw new LimitException(balance);
            }

            updateBalance(conn, userId, newBalance, month);
            if (delta != 0) {
                insertLog(conn, userId, delta, newBalance, reason, referenceId);
            }

            conn.commit();
            return newBalance;
        } catch (SQLException e) {
            if (conn != null) {
                try { conn.rollback(); } catch (SQLException ex) { }
            }
            throw e;
        } finally {
            if (conn != null) {
                try { conn.setAutoCommit(true); conn.close(); } catch (SQLException e) { }
            }
        }
    }

    /**
     * Tambah poin hasil pembelian di dalam transaksi milik pemanggil (tanpa commit),
     * supaya status pembayaran dan saldo berubah bersamaan. Saldo dibatasi sampai max.
     *
     * @return jumlah poin yang benar-benar ditambahkan
     */
    public int creditCapped(Connection conn, int userId, int points, int max, String referenceId, String month)
            throws SQLException {
        int balance = lockBalance(conn, userId, month);
        int credited = Math.max(0, Math.min(points, max - balance));

        updateBalance(conn, userId, balance + credited, month);
        if (credited > 0) {
            insertLog(conn, userId, credited, balance + credited, "topup", referenceId);
        }
        return credited;
    }

    /**
     * Kunci baris saldo siswa dan terapkan lazy reset bulanan.
     *
     * @return saldo untuk periode berjalan (belum disimpan)
     */
    private int lockBalance(Connection conn, int userId, String month) throws SQLException {
        int balance;
        String lastMonth;
        try (PreparedStatement stmt = conn.prepareStatement(
                "SELECT quota_balance, last_reset_month FROM users WHERE id = ? FOR UPDATE")) {
            stmt.setInt(1, userId);
            try (ResultSet rs = stmt.executeQuery()) {
                if (!rs.next()) {
                    throw new SQLException("User not found: " + userId);
                }
                balance = rs.getInt("quota_balance");
                lastMonth = rs.getString("last_reset_month");
            }
        }

        boolean newPeriod = !month.equals(lastMonth);
        if (newPeriod && balance > 0) {
            insertLog(conn, userId, -balance, 0, "monthly_reset", lastMonth);
        }
        return newPeriod ? 0 : balance;
    }

    /**
     * Hanguskan saldo semua siswa yang periodenya bukan bulan berjalan.
     *
     * @return jumlah siswa yang direset
     */
    public int resetAllForMonth(String month) throws SQLException {
        String stale = "role = 'peserta' AND (last_reset_month IS NULL OR last_reset_month <> ?)";
        Connection conn = null;
        try {
            conn = DBUtil.getConnection();
            conn.setAutoCommit(false);

            try (PreparedStatement stmt = conn.prepareStatement(
                    "INSERT INTO quota_logs (user_id, change_amount, balance_after, reason, reference_id) " +
                    "SELECT id, -quota_balance, 0, 'monthly_reset', last_reset_month FROM users " +
                    "WHERE quota_balance > 0 AND " + stale)) {
                stmt.setString(1, month);
                stmt.executeUpdate();
            }

            int updated;
            try (PreparedStatement stmt = conn.prepareStatement(
                    "UPDATE users SET quota_balance = 0, last_reset_month = ? WHERE " + stale)) {
                stmt.setString(1, month);
                stmt.setString(2, month);
                updated = stmt.executeUpdate();
            }

            conn.commit();
            return updated;
        } catch (SQLException e) {
            if (conn != null) {
                try { conn.rollback(); } catch (SQLException ex) { }
            }
            throw e;
        } finally {
            if (conn != null) {
                try { conn.setAutoCommit(true); conn.close(); } catch (SQLException e) { }
            }
        }
    }

    private void updateBalance(Connection conn, int userId, int balance, String month) throws SQLException {
        try (PreparedStatement stmt = conn.prepareStatement(
                "UPDATE users SET quota_balance = ?, last_reset_month = ? WHERE id = ?")) {
            stmt.setInt(1, balance);
            stmt.setString(2, month);
            stmt.setInt(3, userId);
            stmt.executeUpdate();
        }
    }

    private void insertLog(Connection conn, int userId, int change, int balanceAfter, String reason,
                           String referenceId) throws SQLException {
        try (PreparedStatement stmt = conn.prepareStatement(
                "INSERT INTO quota_logs (user_id, change_amount, balance_after, reason, reference_id) " +
                "VALUES (?, ?, ?, ?, ?)")) {
            stmt.setInt(1, userId);
            stmt.setInt(2, change);
            stmt.setInt(3, balanceAfter);
            stmt.setString(4, reason);
            stmt.setString(5, referenceId);
            stmt.executeUpdate();
        }
    }
}
