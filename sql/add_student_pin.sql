-- PIN login siswa (email + PIN). Aman dijalankan ulang.

DELIMITER //
DROP PROCEDURE IF EXISTS add_student_pin_column //
CREATE PROCEDURE add_student_pin_column()
BEGIN
    IF NOT EXISTS (SELECT * FROM information_schema.columns WHERE table_schema = DATABASE() AND table_name = 'users' AND column_name = 'pin_hash') THEN
        ALTER TABLE users ADD COLUMN pin_hash VARCHAR(255) DEFAULT NULL COMMENT 'Hash BCrypt PIN siswa (4-6 digit)';
    END IF;
    IF NOT EXISTS (SELECT * FROM information_schema.columns WHERE table_schema = DATABASE() AND table_name = 'users' AND column_name = 'pin_failed_attempts') THEN
        ALTER TABLE users ADD COLUMN pin_failed_attempts INT NOT NULL DEFAULT 0 COMMENT 'Percobaan PIN gagal berturut-turut';
    END IF;
    IF NOT EXISTS (SELECT * FROM information_schema.columns WHERE table_schema = DATABASE() AND table_name = 'users' AND column_name = 'pin_last_failed_at') THEN
        ALTER TABLE users ADD COLUMN pin_last_failed_at DATETIME DEFAULT NULL COMMENT 'Waktu percobaan PIN gagal terakhir';
    END IF;
END //
DELIMITER ;
CALL add_student_pin_column();
DROP PROCEDURE IF EXISTS add_student_pin_column;
