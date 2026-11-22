-- ============================================================
-- P1 #17 — Kategori pengumuman sesuai PRD + filter jenjang (target_grade)
-- ------------------------------------------------------------
-- Kategori resmi (PRD FR-004 / §5.2):
--   'Info Exam', 'Jadwal GMeet', 'Tagihan & Kuota', 'Umum'
-- target_grade: 'ALL' | 'SD-1'..'SD-6' | 'SMP-7'..'SMP-9'
--
-- Idempotent: aman dijalankan berulang.
-- ============================================================

DELIMITER //

DROP PROCEDURE IF EXISTS add_announcement_category_grade //
CREATE PROCEDURE add_announcement_category_grade()
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = DATABASE() AND table_name = 'information_board'
          AND column_name = 'category'
    ) THEN
        ALTER TABLE information_board
            ADD COLUMN category VARCHAR(40) NOT NULL DEFAULT 'Umum'
            COMMENT 'Info Exam | Jadwal GMeet | Tagihan & Kuota | Umum'
            AFTER info_type;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = DATABASE() AND table_name = 'information_board'
          AND column_name = 'target_grade'
    ) THEN
        ALTER TABLE information_board
            ADD COLUMN target_grade VARCHAR(20) NOT NULL DEFAULT 'ALL'
            COMMENT 'ALL | SD-1..SD-6 | SMP-7..SMP-9'
            AFTER target_audience;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.statistics
        WHERE table_schema = DATABASE() AND table_name = 'information_board'
          AND index_name = 'idx_information_board_target_grade'
    ) THEN
        ALTER TABLE information_board
            ADD INDEX idx_information_board_target_grade (target_grade);
    END IF;
END //

DELIMITER ;

CALL add_announcement_category_grade();
DROP PROCEDURE IF EXISTS add_announcement_category_grade;

-- Backfill kategori dari `info_type` lama sebagai titik awal yang masuk akal.
UPDATE information_board
   SET category = 'Info Exam'
 WHERE category = 'Umum'
   AND (LOWER(title) LIKE '%exam%' OR LOWER(title) LIKE '%ujian%' OR LOWER(title) LIKE '%quiz%');

UPDATE information_board
   SET category = 'Jadwal GMeet'
 WHERE category = 'Umum'
   AND (LOWER(title) LIKE '%meet%' OR LOWER(title) LIKE '%jadwal%');

UPDATE information_board
   SET category = 'Tagihan & Kuota'
 WHERE category = 'Umum'
   AND (LOWER(title) LIKE '%tagihan%' OR LOWER(title) LIKE '%kuota%' OR LOWER(title) LIKE '%poin%');

-- Verifikasi:
-- SELECT id, title, category, target_grade, target_audience, is_active FROM information_board;
