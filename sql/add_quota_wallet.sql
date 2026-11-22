-- Dompet kuota/poin siswa (maks. 12 poin, hangus tiap tanggal 1 00:00 WIB),
-- pengaturan pembayaran Sumopod, transaksi pembayaran, dan log mutasi kuota.
-- Aman dijalankan ulang.

DELIMITER //
DROP PROCEDURE IF EXISTS add_quota_wallet_columns //
CREATE PROCEDURE add_quota_wallet_columns()
BEGIN
    IF NOT EXISTS (SELECT * FROM information_schema.columns WHERE table_schema = DATABASE() AND table_name = 'users' AND column_name = 'quota_balance') THEN
        ALTER TABLE users ADD COLUMN quota_balance INT NOT NULL DEFAULT 0 COMMENT 'Saldo kuota/poin aktif (0-12)';
    END IF;
    IF NOT EXISTS (SELECT * FROM information_schema.columns WHERE table_schema = DATABASE() AND table_name = 'users' AND column_name = 'last_reset_month') THEN
        ALTER TABLE users ADD COLUMN last_reset_month CHAR(7) DEFAULT NULL COMMENT 'Periode saldo terakhir, format YYYY-MM (WIB)';
    END IF;
    IF NOT EXISTS (SELECT * FROM information_schema.columns WHERE table_schema = DATABASE() AND table_name = 'users' AND column_name = 'grade_level') THEN
        ALTER TABLE users ADD COLUMN grade_level VARCHAR(10) DEFAULT NULL COMMENT 'Jenjang siswa, contoh: SD-3 .. SMP-9';
    END IF;
END //
DELIMITER ;
CALL add_quota_wallet_columns();
DROP PROCEDURE IF EXISTS add_quota_wallet_columns;

-- Saldo selalu berada di rentang 0-12 (check constraint, PRD #30)
DELIMITER //
DROP PROCEDURE IF EXISTS add_quota_balance_check //
CREATE PROCEDURE add_quota_balance_check()
BEGIN
    IF NOT EXISTS (SELECT * FROM information_schema.table_constraints WHERE constraint_schema = DATABASE() AND table_name = 'users' AND constraint_name = 'chk_users_quota_balance') THEN
        UPDATE users SET quota_balance = LEAST(GREATEST(quota_balance, 0), 12) WHERE quota_balance < 0 OR quota_balance > 12;
        ALTER TABLE users ADD CONSTRAINT chk_users_quota_balance CHECK (quota_balance BETWEEN 0 AND 12);
    END IF;
END //
DELIMITER ;
CALL add_quota_balance_check();
DROP PROCEDURE IF EXISTS add_quota_balance_check;

CREATE TABLE IF NOT EXISTS payment_settings (
    id INT PRIMARY KEY,
    sumopod_api_key_enc TEXT DEFAULT NULL COMMENT 'API Key Sumopod terenkripsi AES-256-GCM',
    sumopod_webhook_token_enc TEXT DEFAULT NULL COMMENT 'Webhook token Sumopod terenkripsi AES-256-GCM',
    is_live_mode BOOLEAN NOT NULL DEFAULT FALSE,
    price_per_point DECIMAL(12,2) NOT NULL DEFAULT 10000.00,
    max_quota_per_month INT NOT NULL DEFAULT 12,
    updated_by INT DEFAULT NULL,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (updated_by) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB;

INSERT INTO payment_settings (id) VALUES (1)
ON DUPLICATE KEY UPDATE id = id;

CREATE TABLE IF NOT EXISTS transactions (
    id INT AUTO_INCREMENT PRIMARY KEY,
    order_id VARCHAR(50) NOT NULL UNIQUE,
    student_id INT NOT NULL,
    points_purchased INT NOT NULL,
    amount DECIMAL(12,2) NOT NULL,
    status ENUM('pending', 'completed', 'failed') NOT NULL DEFAULT 'pending',
    sumopod_payment_id VARCHAR(100) DEFAULT NULL,
    payment_link_url TEXT DEFAULT NULL,
    paid_at DATETIME DEFAULT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (student_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_tx_status (status),
    INDEX idx_tx_student (student_id),
    INDEX idx_tx_created (created_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS quota_logs (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    change_amount INT NOT NULL COMMENT 'Positif = tambah, negatif = potong/hangus',
    balance_after INT NOT NULL,
    reason ENUM('topup', 'exam', 'gmeet', 'monthly_reset') NOT NULL,
    reference_id VARCHAR(100) DEFAULT NULL COMMENT 'order_id / quiz_id / id sesi terkait',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_ql_user (user_id, created_at)
) ENGINE=InnoDB;
