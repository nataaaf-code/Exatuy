-- ============================================================
-- Tabel `meet_links` — pengelolaan tautan Google Meet / Drive oleh pengajar
-- ------------------------------------------------------------
-- Sebelumnya tautan hanya diambil dari kolom `users.gdrive_link` (per siswa)
-- sehingga pengajar tidak punya tempat membuat link, dan klik menu langsung
-- redirect tanpa menampilkan tautan.
--
-- Aturan visibilitas:
--   target_tag   NULL/''  = semua kelas       | contoh: 'SD-4'
--   target_grade 'ALL'    = semua jenjang     | contoh: 'SMP-8'
--
-- Idempotent.
-- ============================================================

CREATE TABLE IF NOT EXISTS meet_links (
    id INT AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(150) NOT NULL COMMENT 'Judul sesi, mis. GMeet Matematika SD-4',
    url VARCHAR(500) NOT NULL COMMENT 'Tautan https://meet.google.com/... atau drive.google.com/...',
    target_tag VARCHAR(50) DEFAULT NULL COMMENT 'NULL = semua kelas',
    target_grade VARCHAR(20) NOT NULL DEFAULT 'ALL' COMMENT 'ALL | SD-1..SD-6 | SMP-7..SMP-9',
    schedule_info VARCHAR(150) DEFAULT NULL COMMENT 'Info jadwal singkat, mis. Rabu 19.00 WIB',
    is_active TINYINT(1) NOT NULL DEFAULT 1,
    created_by INT DEFAULT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_meet_links_target (target_tag, target_grade),
    INDEX idx_meet_links_active (is_active),
    CONSTRAINT fk_meet_links_creator FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB;
