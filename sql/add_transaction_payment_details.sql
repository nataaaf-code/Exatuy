-- ============================================================
-- Detail pembayaran pada tabel `transactions` (QRIS / Virtual Account)
-- ------------------------------------------------------------
-- Masalah yang diperbaiki: checkout siswa dulu hanya membuat baris `pending`
-- dengan `payment_link_url` palsu (https://sumopod.com/pay/INV-...) dan tanpa
-- QR/VA sama sekali, sehingga siswa tidak punya cara membayar.
--
-- Kolom baru:
--   qr_string      : payload QRIS (EMVCo) yang bisa dirender jadi QR
--   va_number      : nomor Virtual Account
--   expires_at     : batas waktu pembayaran
--   settled_at     : waktu transaksi ditandai selesai (idempotensi)
--   is_simulated   : 1 = dibuat tanpa API key Sumopod (mode simulasi/demo)
--
-- Idempotent: aman dijalankan berulang.
-- ============================================================

DELIMITER //

DROP PROCEDURE IF EXISTS add_transaction_payment_details //
CREATE PROCEDURE add_transaction_payment_details()
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_schema = DATABASE() AND table_name = 'transactions'
                     AND column_name = 'qr_string') THEN
        ALTER TABLE transactions ADD COLUMN qr_string VARCHAR(1024) DEFAULT NULL
            COMMENT 'Payload QRIS (EMVCo) untuk dirender menjadi QR';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_schema = DATABASE() AND table_name = 'transactions'
                     AND column_name = 'va_number') THEN
        ALTER TABLE transactions ADD COLUMN va_number VARCHAR(64) DEFAULT NULL
            COMMENT 'Nomor Virtual Account';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_schema = DATABASE() AND table_name = 'transactions'
                     AND column_name = 'expires_at') THEN
        ALTER TABLE transactions ADD COLUMN expires_at DATETIME DEFAULT NULL
            COMMENT 'Batas waktu pembayaran';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_schema = DATABASE() AND table_name = 'transactions'
                     AND column_name = 'settled_at') THEN
        ALTER TABLE transactions ADD COLUMN settled_at DATETIME DEFAULT NULL
            COMMENT 'Waktu transaksi diselesaikan (idempotensi webhook)';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_schema = DATABASE() AND table_name = 'transactions'
                     AND column_name = 'is_simulated') THEN
        ALTER TABLE transactions ADD COLUMN is_simulated TINYINT(1) NOT NULL DEFAULT 0
            COMMENT '1 = tanpa API key Sumopod (mode simulasi/demo)';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.statistics
                   WHERE table_schema = DATABASE() AND table_name = 'transactions'
                     AND index_name = 'idx_transactions_settled') THEN
        ALTER TABLE transactions ADD INDEX idx_transactions_settled (settled_at);
    END IF;
END //

DELIMITER ;

CALL add_transaction_payment_details();
DROP PROCEDURE IF EXISTS add_transaction_payment_details;
