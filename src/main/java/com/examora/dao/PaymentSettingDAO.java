package com.examora.dao;

import com.examora.model.PaymentSetting;
import com.examora.util.DBUtil;

import java.math.BigDecimal;
import java.sql.*;

/**
 * PaymentSettingDAO - Manages Sumopod payment gateway configuration
 * and dummy pricing in payment_settings table (singleton row id = 1).
 */
public class PaymentSettingDAO {

    /**
     * Ensure payment_settings table exists (defensive auto-bootstrap).
     */
    private void ensureTableExists(Connection conn) {
        String ddl = "CREATE TABLE IF NOT EXISTS payment_settings (" +
                "id INT PRIMARY KEY DEFAULT 1, " +
                "sumopod_api_key_enc TEXT DEFAULT NULL, " +
                "sumopod_webhook_token VARCHAR(255) DEFAULT NULL, " +
                "is_live_mode BOOLEAN NOT NULL DEFAULT FALSE, " +
                "dummy_price_per_point DECIMAL(12,2) NOT NULL DEFAULT 10000.00, " +
                "max_quota_per_month INT NOT NULL DEFAULT 12, " +
                "updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP" +
                ") ENGINE=InnoDB";
        try (Statement stmt = conn.createStatement()) {
            stmt.execute(ddl);
        } catch (SQLException ignored) {
            // Table may already exist or user lacks DDL permission
        }
    }

    /**
     * Get the current payment settings. Returns defaults if row or table is missing.
     */
    public PaymentSetting getSettings() {
        String sql = "SELECT id, sumopod_api_key_enc, sumopod_webhook_token, is_live_mode, " +
                     "dummy_price_per_point, max_quota_per_month, updated_at " +
                     "FROM payment_settings WHERE id = 1";

        try (Connection conn = DBUtil.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql);
             ResultSet rs = stmt.executeQuery()) {

            if (rs.next()) {
                return mapRow(rs);
            }
        } catch (SQLException e) {
            // Table may not exist yet; return sensible defaults gracefully
        }
        return new PaymentSetting();
    }

    /**
     * Save or update the singleton payment settings row (id = 1).
     */
    public boolean saveSettings(PaymentSetting setting) throws SQLException {
        try (Connection conn = DBUtil.getConnection()) {
            ensureTableExists(conn);

            String sql = "INSERT INTO payment_settings " +
                         "(id, sumopod_api_key_enc, sumopod_webhook_token, is_live_mode, dummy_price_per_point, max_quota_per_month) " +
                         "VALUES (1, ?, ?, ?, ?, ?) " +
                         "ON DUPLICATE KEY UPDATE " +
                         "sumopod_api_key_enc = VALUES(sumopod_api_key_enc), " +
                         "sumopod_webhook_token = VALUES(sumopod_webhook_token), " +
                         "is_live_mode = VALUES(is_live_mode), " +
                         "dummy_price_per_point = VALUES(dummy_price_per_point), " +
                         "max_quota_per_month = VALUES(max_quota_per_month)";

            try (PreparedStatement stmt = conn.prepareStatement(sql)) {
                stmt.setString(1, setting.getSumopodApiKeyEnc());
                stmt.setString(2, setting.getSumopodWebhookToken());
                stmt.setBoolean(3, setting.isLiveMode());
                stmt.setBigDecimal(4, setting.getDummyPricePerPoint());
                stmt.setInt(5, setting.getMaxQuotaPerMonth());
                return stmt.executeUpdate() > 0;
            }
        }
    }

    private PaymentSetting mapRow(ResultSet rs) throws SQLException {
        PaymentSetting s = new PaymentSetting();
        s.setId(rs.getInt("id"));
        s.setSumopodApiKeyEnc(rs.getString("sumopod_api_key_enc"));
        s.setSumopodWebhookToken(rs.getString("sumopod_webhook_token"));
        s.setLiveMode(rs.getBoolean("is_live_mode"));
        BigDecimal price = rs.getBigDecimal("dummy_price_per_point");
        s.setDummyPricePerPoint(price != null ? price : new BigDecimal("10000.00"));
        int maxQ = rs.getInt("max_quota_per_month");
        s.setMaxQuotaPerMonth(maxQ > 0 ? maxQ : 12);
        Timestamp updated = rs.getTimestamp("updated_at");
        if (updated != null) {
            s.setUpdatedAt(updated.toLocalDateTime());
        }
        return s;
    }
}
