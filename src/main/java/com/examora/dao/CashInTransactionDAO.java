package com.examora.dao;

import com.examora.model.CashInTransaction;
import com.examora.util.DBUtil;

import java.math.BigDecimal;
import java.sql.*;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * CashInTransactionDAO - Handles queries & aggregation for Cash-In Financial Report
 * (transactions table: completed / pending / failed) and student quota checkout orders.
 */
public class CashInTransactionDAO {

    /**
     * Summary stats for the 3 cash-in status cards (Berhasil, Pending, Gagal).
     */
    public static class StatusSummary {
        private BigDecimal completedAmount = BigDecimal.ZERO;
        private int completedCount = 0;
        private BigDecimal pendingAmount = BigDecimal.ZERO;
        private int pendingCount = 0;
        private BigDecimal failedAmount = BigDecimal.ZERO;
        private int failedCount = 0;

        public BigDecimal getCompletedAmount() { return completedAmount; }
        public void setCompletedAmount(BigDecimal v) { this.completedAmount = v != null ? v : BigDecimal.ZERO; }
        public int getCompletedCount() { return completedCount; }
        public void setCompletedCount(int c) { this.completedCount = c; }

        public BigDecimal getPendingAmount() { return pendingAmount; }
        public void setPendingAmount(BigDecimal v) { this.pendingAmount = v != null ? v : BigDecimal.ZERO; }
        public int getPendingCount() { return pendingCount; }
        public void setPendingCount(int c) { this.pendingCount = c; }

        public BigDecimal getFailedAmount() { return failedAmount; }
        public void setFailedAmount(BigDecimal v) { this.failedAmount = v != null ? v : BigDecimal.ZERO; }
        public int getFailedCount() { return failedCount; }
        public void setFailedCount(int c) { this.failedCount = c; }

        public int getTotalCount() { return completedCount + pendingCount + failedCount; }
    }

    private void ensureTableExists(Connection conn) {
        String ddl = "CREATE TABLE IF NOT EXISTS transactions (" +
                "id INT AUTO_INCREMENT PRIMARY KEY, " +
                "order_id VARCHAR(50) NOT NULL UNIQUE, " +
                "student_id INT NOT NULL, " +
                "points_purchased INT NOT NULL, " +
                "amount DECIMAL(12,2) NOT NULL, " +
                "status ENUM('completed', 'pending', 'failed') NOT NULL DEFAULT 'pending', " +
                "payment_method VARCHAR(30) DEFAULT 'QRIS', " +
                "sumopod_payment_id VARCHAR(100) DEFAULT NULL, " +
                "payment_link_url TEXT DEFAULT NULL, " +
                "paid_at DATETIME DEFAULT NULL, " +
                "created_at DATETIME DEFAULT CURRENT_TIMESTAMP, " +
                "FOREIGN KEY (student_id) REFERENCES users(id) ON DELETE CASCADE" +
                ") ENGINE=InnoDB";
        try (Statement stmt = conn.createStatement()) {
            stmt.execute(ddl);
        } catch (SQLException ignored) {
            // Table may already exist
        }
    }

    /**
     * Find transactions with optional filters: status, startDate (yyyy-MM-dd),
     * endDate (yyyy-MM-dd), month (yyyy-MM), and search query (student name/email/order_id).
     */
    public List<CashInTransaction> findFiltered(String status, String startDate, String endDate,
                                                String month, String search) {
        List<CashInTransaction> list = new ArrayList<>();
        StringBuilder sql = new StringBuilder(
            "SELECT t.*, u.name AS student_name, u.email AS student_email, u.tag AS student_tag " +
            "FROM transactions t " +
            "LEFT JOIN users u ON t.student_id = u.id " +
            "WHERE 1=1 "
        );
        List<Object> params = new ArrayList<>();

        if (status != null && !status.trim().isEmpty() && !"all".equalsIgnoreCase(status.trim())) {
            sql.append("AND t.status = ? ");
            params.add(status.trim().toLowerCase());
        }

        appendDateAndSearchFilters(sql, params, startDate, endDate, month, search);
        sql.append("ORDER BY t.created_at DESC, t.id DESC");

        try (Connection conn = DBUtil.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql.toString())) {

            bindParams(stmt, params);
            try (ResultSet rs = stmt.executeQuery()) {
                while (rs.next()) {
                    list.add(mapRow(rs));
                }
            }
        } catch (SQLException e) {
            // Gracefully return empty list if table has not been migrated yet
        }
        return list;
    }

    /**
     * Compute aggregate totals and counts for completed, pending, and failed statuses
     * matching the active date/month/search filters (ignores status filter so all 3 cards stay visible).
     */
    public StatusSummary getSummary(String startDate, String endDate, String month, String search) {
        StatusSummary summary = new StatusSummary();
        StringBuilder sql = new StringBuilder(
            "SELECT t.status, COUNT(*) AS tx_count, COALESCE(SUM(t.amount), 0) AS tx_total " +
            "FROM transactions t " +
            "LEFT JOIN users u ON t.student_id = u.id " +
            "WHERE 1=1 "
        );
        List<Object> params = new ArrayList<>();
        appendDateAndSearchFilters(sql, params, startDate, endDate, month, search);
        sql.append("GROUP BY t.status");

        try (Connection conn = DBUtil.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql.toString())) {

            bindParams(stmt, params);
            try (ResultSet rs = stmt.executeQuery()) {
                while (rs.next()) {
                    String st = rs.getString("status");
                    int count = rs.getInt("tx_count");
                    BigDecimal total = rs.getBigDecimal("tx_total");
                    if ("completed".equalsIgnoreCase(st)) {
                        summary.setCompletedCount(count);
                        summary.setCompletedAmount(total);
                    } else if ("pending".equalsIgnoreCase(st)) {
                        summary.setPendingCount(count);
                        summary.setPendingAmount(total);
                    } else if ("failed".equalsIgnoreCase(st)) {
                        summary.setFailedCount(count);
                        summary.setFailedAmount(total);
                    }
                }
            }
        } catch (SQLException e) {
            // Gracefully return Rp 0 summary if table does not exist yet
        }
        return summary;
    }

    /**
     * Find transactions for a specific student (for checkout history).
     */
    public List<CashInTransaction> findByStudentId(int studentId) {
        List<CashInTransaction> list = new ArrayList<>();
        String sql = "SELECT t.*, u.name AS student_name, u.email AS student_email, u.tag AS student_tag " +
                     "FROM transactions t " +
                     "LEFT JOIN users u ON t.student_id = u.id " +
                     "WHERE t.student_id = ? " +
                     "ORDER BY t.created_at DESC LIMIT 20";

        try (Connection conn = DBUtil.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {

            stmt.setInt(1, studentId);
            try (ResultSet rs = stmt.executeQuery()) {
                while (rs.next()) {
                    list.add(mapRow(rs));
                }
            }
        } catch (SQLException e) {
            // Return empty list if table doesn't exist yet
        }
        return list;
    }

    /**
     * Create a new pending transaction (for student quota checkout).
     */
    public CashInTransaction create(CashInTransaction tx) throws SQLException {
        try (Connection conn = DBUtil.getConnection()) {
            ensureTableExists(conn);

            String sql = "INSERT INTO transactions " +
                         "(order_id, student_id, points_purchased, amount, status, payment_method, sumopod_payment_id, payment_link_url) " +
                         "VALUES (?, ?, ?, ?, ?, ?, ?, ?)";

            try (PreparedStatement stmt = conn.prepareStatement(sql, Statement.RETURN_GENERATED_KEYS)) {
                stmt.setString(1, tx.getOrderId());
                stmt.setInt(2, tx.getStudentId());
                stmt.setInt(3, tx.getPointsPurchased());
                stmt.setBigDecimal(4, tx.getAmount());
                stmt.setString(5, tx.getStatus() != null ? tx.getStatus() : "pending");
                stmt.setString(6, tx.getPaymentMethod() != null ? tx.getPaymentMethod() : "QRIS");
                stmt.setString(7, tx.getSumopodPaymentId());
                stmt.setString(8, tx.getPaymentLinkUrl());

                stmt.executeUpdate();
                try (ResultSet keys = stmt.getGeneratedKeys()) {
                    if (keys.next()) {
                        tx.setId(keys.getInt(1));
                    }
                }
            }
            return tx;
        }
    }

    private void appendDateAndSearchFilters(StringBuilder sql, List<Object> params,
                                            String startDate, String endDate,
                                            String month, String search) {
        if (month != null && month.trim().matches("\\d{4}-\\d{2}")) {
            sql.append("AND DATE_FORMAT(t.created_at, '%Y-%m') = ? ");
            params.add(month.trim());
        } else {
            if (startDate != null && startDate.trim().matches("\\d{4}-\\d{2}-\\d{2}")) {
                sql.append("AND DATE(t.created_at) >= ? ");
                params.add(startDate.trim());
            }
            if (endDate != null && endDate.trim().matches("\\d{4}-\\d{2}-\\d{2}")) {
                sql.append("AND DATE(t.created_at) <= ? ");
                params.add(endDate.trim());
            }
        }

        if (search != null && !search.trim().isEmpty()) {
            String like = "%" + search.trim() + "%";
            sql.append("AND (t.order_id LIKE ? OR u.name LIKE ? OR u.email LIKE ? OR t.sumopod_payment_id LIKE ?) ");
            params.add(like);
            params.add(like);
            params.add(like);
            params.add(like);
        }
    }

    private void bindParams(PreparedStatement stmt, List<Object> params) throws SQLException {
        for (int i = 0; i < params.size(); i++) {
            stmt.setObject(i + 1, params.get(i));
        }
    }

    private CashInTransaction mapRow(ResultSet rs) throws SQLException {
        CashInTransaction tx = new CashInTransaction();
        tx.setId(rs.getInt("id"));
        tx.setOrderId(rs.getString("order_id"));
        tx.setStudentId(rs.getInt("student_id"));
        tx.setStudentName(rs.getString("student_name"));
        tx.setStudentEmail(rs.getString("student_email"));
        tx.setStudentTag(rs.getString("student_tag"));
        tx.setPointsPurchased(rs.getInt("points_purchased"));
        tx.setAmount(rs.getBigDecimal("amount"));
        tx.setStatus(rs.getString("status"));
        try {
            tx.setPaymentMethod(rs.getString("payment_method"));
        } catch (SQLException ignored) {
            tx.setPaymentMethod("QRIS");
        }
        tx.setSumopodPaymentId(rs.getString("sumopod_payment_id"));
        tx.setPaymentLinkUrl(rs.getString("payment_link_url"));
        Timestamp paid = rs.getTimestamp("paid_at");
        if (paid != null) tx.setPaidAt(paid.toLocalDateTime());
        Timestamp created = rs.getTimestamp("created_at");
        if (created != null) tx.setCreatedAt(created.toLocalDateTime());
        return tx;
    }
}
