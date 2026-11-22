-- ============================================================
-- Exatuy Migration: Payment Settings, Transactions, Quota & Subject
-- Author: Muhammad Rizal Anditama Nugraha (FS335B6Y1938)
-- Compatible with: examora_db (MySQL 8.0+)
-- Idempotent: Safe to run multiple times
-- ============================================================

USE examora_db;

-- 1. Add quota_balance, last_reset_month, grade_level to users
DROP PROCEDURE IF EXISTS migrate_rizal_columns;
DELIMITER //
CREATE PROCEDURE migrate_rizal_columns()
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = DATABASE() AND table_name = 'users' AND column_name = 'quota_balance'
    ) THEN
        ALTER TABLE users ADD COLUMN quota_balance INT NOT NULL DEFAULT 0 COMMENT 'Saldo kuota/poin aktif (0-12)';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = DATABASE() AND table_name = 'users' AND column_name = 'last_reset_month'
    ) THEN
        ALTER TABLE users ADD COLUMN last_reset_month VARCHAR(7) DEFAULT NULL COMMENT 'YYYY-MM terakhir auto-reset kuota';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = DATABASE() AND table_name = 'users' AND column_name = 'grade_level'
    ) THEN
        ALTER TABLE users ADD COLUMN grade_level VARCHAR(20) DEFAULT NULL COMMENT 'Jenjang kelas: SD-3..SMP-9';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = DATABASE() AND table_name = 'quiz' AND column_name = 'subject'
    ) THEN
        ALTER TABLE quiz ADD COLUMN subject VARCHAR(50) DEFAULT NULL COMMENT 'Mata pelajaran (Matematika, IPA, dll)';
    END IF;
END //
DELIMITER ;
CALL migrate_rizal_columns();
DROP PROCEDURE IF EXISTS migrate_rizal_columns;

-- 2. Payment Settings Table (Sumopod configuration)
CREATE TABLE IF NOT EXISTS payment_settings (
    id INT PRIMARY KEY DEFAULT 1,
    sumopod_api_key_enc TEXT DEFAULT NULL COMMENT 'API Key Sumopod terenkripsi AES-256',
    sumopod_webhook_token VARCHAR(255) DEFAULT NULL COMMENT 'Token verifikasi webhook Sumopod',
    is_live_mode BOOLEAN NOT NULL DEFAULT FALSE COMMENT 'false=Sandbox, true=Live',
    dummy_price_per_point DECIMAL(12,2) NOT NULL DEFAULT 10000.00 COMMENT 'Harga dummy default per poin (IDR)',
    max_quota_per_month INT NOT NULL DEFAULT 12 COMMENT 'Batas maksimal kuota aktif per bulan',
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

INSERT IGNORE INTO payment_settings (id, is_live_mode, dummy_price_per_point, max_quota_per_month)
VALUES (1, FALSE, 10000.00, 12);

-- 3. Transactions Table (Cash-In Financial Report & Sumopod Orders)
CREATE TABLE IF NOT EXISTS transactions (
    id INT AUTO_INCREMENT PRIMARY KEY,
    order_id VARCHAR(50) NOT NULL UNIQUE COMMENT 'Kode invoice unik (contoh: INV-EXA-20261120-001)',
    student_id INT NOT NULL,
    points_purchased INT NOT NULL COMMENT 'Jumlah kuota/poin yang dibeli (1-12)',
    amount DECIMAL(12,2) NOT NULL COMMENT 'Nominal tagihan pembayaran (IDR)',
    status ENUM('completed', 'pending', 'failed') NOT NULL DEFAULT 'pending',
    payment_method VARCHAR(30) DEFAULT 'QRIS' COMMENT 'QRIS / Virtual Account',
    sumopod_payment_id VARCHAR(100) DEFAULT NULL COMMENT 'ID transaksi dari Sumopod',
    payment_link_url TEXT DEFAULT NULL COMMENT 'Tautan halaman pembayaran Sumopod',
    paid_at DATETIME DEFAULT NULL COMMENT 'Waktu pembayaran terverifikasi',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (student_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_tx_status (status),
    INDEX idx_tx_student (student_id),
    INDEX idx_tx_created (created_at),
    INDEX idx_tx_order (order_id)
) ENGINE=InnoDB;

-- 4. Quota Logs Table (Audit mutasi kuota siswa)
CREATE TABLE IF NOT EXISTS quota_logs (
    id INT AUTO_INCREMENT PRIMARY KEY,
    student_id INT NOT NULL,
    change_amount INT NOT NULL COMMENT '+N top-up, -1 exam/gmeet, -N reset bulanan',
    activity_type VARCHAR(30) NOT NULL COMMENT 'TOPUP, USE_EXAM, USE_GMEET, MONTHLY_RESET',
    description VARCHAR(255) DEFAULT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (student_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_ql_student (student_id),
    INDEX idx_ql_type (activity_type),
    INDEX idx_ql_created (created_at)
) ENGINE=InnoDB;
