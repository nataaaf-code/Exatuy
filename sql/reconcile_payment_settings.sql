-- ============================================================
-- Rekonsiliasi skema `payment_settings` dengan kode PaymentSettingDAO
-- ------------------------------------------------------------
-- Masalah yang diperbaiki:
--   * Database lama memakai kolom `price_per_point` dan
--     `sumopod_webhook_token_enc`, sedangkan PaymentSettingDAO
--     membaca/menulis `dummy_price_per_point` dan `sumopod_webhook_token`.
--     Akibatnya setiap SELECT/UPDATE pengaturan pembayaran gagal dengan
--     "Unknown column 'dummy_price_per_point'" dan halaman admin
--     Pengaturan Pembayaran tidak bisa dibuka.
--
-- Catatan keamanan:
--   * `sumopod_webhook_token` sengaja TIDAK diisi dari kolom `*_enc`
--     karena nilainya terenkripsi; token harus diinput ulang oleh admin
--     agar tersimpan dalam bentuk yang bisa dibandingkan saat webhook.
--
-- Idempotent: aman dijalankan berkali-kali.
-- ============================================================

DELIMITER //

DROP PROCEDURE IF EXISTS reconcile_payment_settings_columns //
CREATE PROCEDURE reconcile_payment_settings_columns()
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = DATABASE() AND table_name = 'payment_settings'
          AND column_name = 'dummy_price_per_point'
    ) THEN
        ALTER TABLE payment_settings
            ADD COLUMN dummy_price_per_point DECIMAL(12,2) NOT NULL DEFAULT 10000.00
            COMMENT 'Harga dummy default per poin (IDR)';
    END IF;

    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = DATABASE() AND table_name = 'payment_settings'
          AND column_name = 'price_per_point'
    ) THEN
        -- Backfill harga lama hanya bila kolom baru masih bernilai default.
        UPDATE payment_settings
           SET dummy_price_per_point = price_per_point
         WHERE dummy_price_per_point = 10000.00
           AND price_per_point IS NOT NULL
           AND price_per_point > 0;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = DATABASE() AND table_name = 'payment_settings'
          AND column_name = 'sumopod_webhook_token'
    ) THEN
        ALTER TABLE payment_settings
            ADD COLUMN sumopod_webhook_token VARCHAR(255) DEFAULT NULL
            COMMENT 'Token verifikasi webhook Sumopod (input ulang oleh admin)';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = DATABASE() AND table_name = 'payment_settings'
          AND column_name = 'is_live_mode'
    ) THEN
        ALTER TABLE payment_settings
            ADD COLUMN is_live_mode BOOLEAN NOT NULL DEFAULT FALSE COMMENT 'false=Sandbox, true=Live';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = DATABASE() AND table_name = 'payment_settings'
          AND column_name = 'max_quota_per_month'
    ) THEN
        ALTER TABLE payment_settings
            ADD COLUMN max_quota_per_month INT NOT NULL DEFAULT 12 COMMENT 'Batas maksimal kuota aktif per bulan';
    END IF;
END //

DELIMITER ;

CALL reconcile_payment_settings_columns();
DROP PROCEDURE IF EXISTS reconcile_payment_settings_columns;

-- Pastikan baris konfigurasi tunggal (id = 1) selalu ada.
INSERT IGNORE INTO payment_settings (id, is_live_mode, dummy_price_per_point, max_quota_per_month)
VALUES (1, FALSE, 10000.00, 12);

-- `transactions` juga perlu kolom `payment_method` (dibaca CashInTransactionDAO).
SET @has_pm := (
    SELECT COUNT(*) FROM information_schema.columns
    WHERE table_schema = DATABASE() AND table_name = 'transactions' AND column_name = 'payment_method'
);
SET @sql_pm := IF(@has_pm = 0,
    'ALTER TABLE transactions ADD COLUMN payment_method VARCHAR(30) DEFAULT ''QRIS'' COMMENT ''QRIS / Virtual Account''',
    'SELECT 1');
PREPARE stmt_pm FROM @sql_pm;
EXECUTE stmt_pm;
DEALLOCATE PREPARE stmt_pm;
