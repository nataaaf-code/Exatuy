-- ============================================================================
-- Seed data demo Exatuy — akun default + 2 contoh per fitur
-- ----------------------------------------------------------------------------
-- Jalankan di database aplikasi:
--   docker exec -i examora-mysql sh -c 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" examora_db' \
--     < sql/seed_demo_data.sql
--
-- Sifat: idempotent — semua baris demo diberi awalan "DEMO ·" lalu dihapus
-- lebih dulu (urutan anak -> induk agar FK aman), sedangkan ketiga akun
-- default memakai ON DUPLICATE KEY UPDATE sehingga password selalu diset ulang.
--
-- Akun default (PRD/README):
--   Owner    owner@belajarku.id    / Admin123!
--   Pengajar pengajar@belajarku.id / Guru123!
--   Siswa    siswa@belajarku.id    / Siswa123!
-- ============================================================================

SET @month := DATE_FORMAT(CONVERT_TZ(NOW(), '+00:00', '+07:00'), '%Y-%m');

-- ---------------------------------------------------------------- 0. Bersihkan
DELETE FROM attendance_records WHERE session_id IN (SELECT id FROM attendance_sessions WHERE session_name LIKE 'DEMO ·%');
DELETE FROM attendance_sessions WHERE session_name LIKE 'DEMO ·%';
DELETE FROM questions WHERE quiz_id IN (SELECT id FROM quiz WHERE title LIKE 'DEMO ·%');
DELETE FROM quiz WHERE title LIKE 'DEMO ·%';
DELETE FROM materials WHERE title LIKE 'DEMO ·%';
DELETE FROM material_categories WHERE nama LIKE 'DEMO ·%';
DELETE FROM information_board WHERE title LIKE 'DEMO ·%';
DELETE FROM user_achievements WHERE achievement_id IN (SELECT id FROM achievements WHERE name LIKE 'DEMO ·%');
DELETE FROM achievements WHERE name LIKE 'DEMO ·%';
DELETE FROM point_transactions WHERE description LIKE 'DEMO ·%';
DELETE FROM quota_logs WHERE reference_id LIKE 'DEMO ·%';
DELETE FROM chat_messages WHERE message_text LIKE 'DEMO ·%';
DELETE FROM expenses WHERE deskripsi LIKE 'DEMO ·%';
DELETE FROM transactions WHERE order_id LIKE 'DEMO-%';
DELETE FROM invoices WHERE invoice_number LIKE 'DEMO-%';
DELETE FROM student_packages WHERE package_id IN (SELECT id FROM session_packages WHERE nama_paket LIKE 'DEMO ·%');
DELETE FROM session_packages WHERE nama_paket LIKE 'DEMO ·%';
DELETE FROM files WHERE file_name LIKE 'DEMO ·%';
DELETE FROM file_folders WHERE folder_name LIKE 'DEMO ·%';
DELETE FROM arena_sessions WHERE code LIKE 'DEMO-%';
DELETE FROM question_categories WHERE name LIKE 'DEMO ·%';

-- ------------------------------------------------------------ 1. Akun default
-- Password: hash bcrypt "$2a$" (kompatibel jBCrypt). Lihat README bagian akun default.
INSERT INTO users (name, email, password, role, tag, grade_level, quota_balance, last_reset_month, gdrive_link)
VALUES
 ('Owner BelajarKu', 'owner@belajarku.id',
  '$2a$10$4xR3vmCI0YGlswVPh3sxAefFT.YY2lQtqbrFClRxKavXGNCri5PFi', 'admin', 'Owner', NULL, 0, @month, ''),
 ('Pengajar BelajarKu', 'pengajar@belajarku.id',
  '$2a$10$xeclXwsrrIWjSLtc4g/rYO3GdBtqtj7fWxVuQpZQ37TK8xvEL8bsm', 'admin', 'Pengajar', NULL, 0, @month, ''),
 ('Siswa Demo', 'siswa@belajarku.id',
  '$2a$10$vwsjobt2ky/I7PHdPQMSqOD2gAa2tthp87cWOJNP3to5SY6mEk54O', 'peserta', 'SD-4', 'SD-4', 12, @month,
  'https://meet.google.com/demo-exatuy-siswa')
ON DUPLICATE KEY UPDATE
  name = VALUES(name), role = VALUES(role), tag = VALUES(tag),
  grade_level = VALUES(grade_level), quota_balance = VALUES(quota_balance),
  last_reset_month = VALUES(last_reset_month), gdrive_link = VALUES(gdrive_link);

SET @owner  := (SELECT id FROM users WHERE email = 'owner@belajarku.id');
SET @guru   := (SELECT id FROM users WHERE email = 'pengajar@belajarku.id');
SET @siswa  := (SELECT id FROM users WHERE email = 'siswa@belajarku.id');

-- --------------------------------------------------- 2. Bank soal + 2 kuiz
INSERT INTO question_categories (name, description, created_by) VALUES
 ('DEMO · Matematika', 'Kategori contoh: pecahan & aljabar', @owner),
 ('DEMO · IPA', 'Kategori contoh: fotosintesis & listrik', @owner);
SET @cat_mat := (SELECT id FROM question_categories WHERE name='DEMO · Matematika');
SET @cat_ipa := (SELECT id FROM question_categories WHERE name='DEMO · IPA');

INSERT INTO quiz (title, description, duration, is_active, deadline, target_tag, created_by, shuffle_questions, show_review, subject) VALUES
 ('DEMO · Kuis Matematika Pecahan', 'Kuis contoh 2 soal pecahan (SD-4)', 30, 1,
  DATE_ADD(NOW(), INTERVAL 30 DAY), 'SD-4', @guru, 1, 1, 'Matematika'),
 ('DEMO · Kuis IPA Fotosintesis', 'Kuis contoh 2 soal fotosintesis (SD-4)', 30, 1,
  DATE_ADD(NOW(), INTERVAL 30 DAY), 'SD-4', @guru, 1, 1, 'IPA');
SET @quiz_mat := (SELECT id FROM quiz WHERE title='DEMO · Kuis Matematika Pecahan');
SET @quiz_ipa := (SELECT id FROM quiz WHERE title='DEMO · Kuis IPA Fotosintesis');

INSERT INTO questions
 (quiz_id, question_text, option_a, option_b, option_c, option_d, correct_answer,
  question_order, category_id, is_bank_question, explanation)
VALUES
 (@quiz_mat, 'Hasil dari 3/4 + 1/2 adalah ...', '5/4', '5/6', '4/6', '1/4', 'A', 1, @cat_mat, 1,
  'Samakan penyebut menjadi 4: 3/4 + 2/4 = 5/4.'),
 (@quiz_mat, 'Bentuk paling sederhana dari 8/12 adalah ...', '2/3', '4/6', '3/4', '1/2', 'A', 2, @cat_mat, 1,
  'Bagi pembilang & penyebut dengan FPB(8,12)=4 sehingga 8/12 = 2/3.'),
 (@quiz_ipa, 'Bahan utama fotosintesis adalah ...', 'Air dan karbon dioksida', 'Oksigen dan glukosa', 'Nitrogen dan air', 'Glukosa dan air', 'A', 1, @cat_ipa, 1,
  'Fotosintesis memakai CO2 + H2O + cahaya → glukosa + O2.'),
 (@quiz_ipa, 'Hasil fotosintesis yang dilepas ke udara adalah ...', 'Oksigen', 'Karbon dioksida', 'Nitrogen', 'Uap air', 'A', 2, @cat_ipa, 1,
  'Oksigen (O2) dilepas melalui stomata.');

-- ------------------------------------------------------------- 3. Materi belajar
INSERT INTO material_categories (nama, deskripsi, jenjang, mata_pelajaran, created_by, is_active) VALUES
 ('DEMO · Matematika SD', 'Ringkasan materi pecahan', 'SD', 'Matematika', @guru, 1),
 ('DEMO · IPA SD', 'Ringkasan materi fotosintesis', 'SD', 'IPA', @guru, 1);
SET @mcat_mat := (SELECT id FROM material_categories WHERE nama='DEMO · Matematika SD');
SET @mcat_ipa := (SELECT id FROM material_categories WHERE nama='DEMO · IPA SD');

INSERT INTO materials (category_id, title, content, summary, target_tags, generated_by, is_generated, is_active) VALUES
 (@mcat_mat, 'DEMO · Pecahan: Penjumlahan & Penyederhanaan',
  'Pecahan menyatakan bagian dari keseluruhan (a/b). Untuk menjumlahkan, samakan penyebut dengan KPK lalu jumlahkan pembilangnya. Contoh: 3/4 + 1/2 = 3/4 + 2/4 = 5/4. Menyederhanakan pecahan dilakukan dengan membagi pembilang dan penyebut dengan FPB.',
  'Konsep dasar pecahan, penjumlahan dengan penyebut berbeda, dan cara menyederhanakan.', 'SD-4', @guru, 0, 1),
 (@mcat_ipa, 'DEMO · Fotosintesis pada Tumbuhan',
  'Fotosintesis adalah proses tumbuhan hijau membuat makanan dengan bantuan cahaya matahari. Bahan: CO2 + H2O. Alat: klorofil pada kloroplas. Hasil: glukosa dan oksigen. Reaksi: 6CO2 + 6H2O + cahaya -> C6H12O6 + 6O2.',
  'Pengertian, bahan, alat, dan hasil fotosintesis untuk jenjang SD.', 'SD-4', @guru, 0, 1);

-- ------------------------------------------------------- 4. Papan pengumuman
INSERT INTO information_board (title, content, info_type, category, priority, target_audience, target_grade, is_active, created_by) VALUES
 ('DEMO · Info Exam Matematika', 'Exam Matematika Bab Pecahan dibuka Senin pukul 08.00 WIB. Pastikan kuota minimal 1 poin.',
  'announcement', 'Info Exam', 'high', 'participants', 'ALL', 1, @guru),
 ('DEMO · Jadwal GMeet Kelas SD-4', 'Sesi Google Meet kelas SD-4 setiap Rabu pukul 19.00 WIB. Akses sesi memotong 1 poin kuota.',
  'info', 'Jadwal GMeet', 'normal', 'participants', 'SD-4', 1, @guru);

-- ------------------------------------------------------------- 5. Presensi
INSERT INTO attendance_sessions (session_name, session_code, session_date, start_time, end_time, target_tag, created_by, status, late_threshold) VALUES
 ('DEMO · Pertemuan 1 - Pecahan', 'DA1', CURDATE(), '08:00:00', '09:30:00', 'SD-4', @guru, 'closed', 15),
 ('DEMO · Pertemuan 2 - Fotosintesis', 'DA2', DATE_ADD(CURDATE(), INTERVAL 7 DAY), '08:00:00', '09:30:00', 'SD-4', @guru, 'active', 15);
SET @sess1 := (SELECT id FROM attendance_sessions WHERE session_code='DA1');
SET @sess2 := (SELECT id FROM attendance_sessions WHERE session_code='DA2');

INSERT INTO attendance_records (session_id, user_id, attendance_time, status, notes) VALUES
 (@sess1, @siswa, NOW(), 'present', 'DEMO · hadir tepat waktu'),
 (@sess2, @siswa, NOW(), 'late', 'DEMO · datang 10 menit setelah mulai');

-- ------------------------------------- 6. Paket sesi, paket siswa, tagihan
INSERT INTO session_packages (nama_paket, jumlah_sesi, harga, durasi_bulan, deskripsi, is_active) VALUES
 ('DEMO · Paket 4 Sesi', 4, 400000.00, 1, 'Paket contoh 4 pertemuan', 1),
 ('DEMO · Paket 8 Sesi', 8, 750000.00, 1, 'Paket contoh 8 pertemuan', 1);
SET @pkg4 := (SELECT id FROM session_packages WHERE nama_paket='DEMO · Paket 4 Sesi');
SET @pkg8 := (SELECT id FROM session_packages WHERE nama_paket='DEMO · Paket 8 Sesi');

INSERT INTO student_packages (student_id, package_id, total_sesi, sisa_sesi, mulai_date, berakhir_date, status) VALUES
 (@siswa, @pkg4, 4, 3, CURDATE(), DATE_ADD(CURDATE(), INTERVAL 30 DAY), 'aktif'),
 (@siswa, @pkg8, 8, 8, DATE_ADD(CURDATE(), INTERVAL 30 DAY), DATE_ADD(CURDATE(), INTERVAL 60 DAY), 'aktif');

INSERT INTO invoices (invoice_number, student_id, package_id, amount, discount, total, status, due_date, paid_at, paid_with, notes) VALUES
 ('DEMO-INV-001', @siswa, @pkg4, 400000.00, 0, 400000.00, 'lunas',
  DATE_ADD(CURDATE(), INTERVAL 7 DAY), NOW(), 'transfer', 'DEMO · tagihan lunas contoh'),
 ('DEMO-INV-002', @siswa, @pkg8, 750000.00, 0, 750000.00, 'belum_lunas',
  DATE_ADD(CURDATE(), INTERVAL 14 DAY), NULL, NULL, 'DEMO · tagihan belum lunas contoh');

-- ---------------------------------------- 7. Dompet kuota: transaksi & log
INSERT INTO transactions (order_id, student_id, points_purchased, amount, status, payment_method, sumopod_payment_id, payment_link_url, paid_at) VALUES
 ('DEMO-ORD-001', @siswa, 4, 40000.00, 'completed', 'QRIS', 'DEMO-sp-001', 'https://sumopod.com/pay/DEMO-ORD-001', NOW()),
 ('DEMO-ORD-002', @siswa, 8, 75000.00, 'pending', 'Virtual Account', 'DEMO-sp-002', 'https://sumopod.com/pay/DEMO-ORD-002', NULL);

INSERT INTO quota_logs (user_id, change_amount, balance_after, reason, reference_id) VALUES
 (@siswa, 4, 12, 'topup', 'DEMO · ORD-001'),
 (@siswa, -1, 11, 'exam', 'DEMO · akses kuis matematika');

-- --------------------------------------------------------------- 8. Chat
INSERT INTO chat_messages (user_id, sender_type, admin_id, message_text, is_read) VALUES
 (@siswa, 'user', NULL, 'DEMO · Kak, besok exam matematika jam berapa?', 1),
 (@siswa, 'admin', @guru, 'DEMO · Exam dibuka pukul 08.00 WIB, jangan lupa kuota minimal 1 poin ya.', 1);

-- ------------------------------------------------- 9. Gamifikasi: lencana
INSERT INTO achievements (name, description, icon, color, category, condition_type, condition_value, points, is_active) VALUES
 ('DEMO · Perfect Score', 'Mendapat nilai 100 pada satu kuis', 'bi-trophy', '#ffc107', 'score', 'perfect_score', 1, 50, 1),
 ('DEMO · Rajin Belajar', 'Menyelesaikan 5 kuis', 'bi-fire', '#dc3545', 'quantity', 'quiz_completed', 5, 30, 1);
SET @ach1 := (SELECT id FROM achievements WHERE name='DEMO · Perfect Score');
SET @ach2 := (SELECT id FROM achievements WHERE name='DEMO · Rajin Belajar');

INSERT INTO user_achievements (user_id, achievement_id) VALUES
 (@siswa, @ach1),
 (@siswa, @ach2);

INSERT INTO user_points (user_id, total_points, level, experience_points, user_rank, progress_to_next) VALUES
 (@siswa, 120, 2, 20, 1, 40),
 (@guru, 0, 1, 0, NULL, 0)
ON DUPLICATE KEY UPDATE total_points = VALUES(total_points), level = VALUES(level);

INSERT INTO point_transactions (user_id, points, transaction_type, source_type, source_id, description) VALUES
 (@siswa, 50, 'earn', 'achievement', @ach1, 'DEMO · lencana Perfect Score'),
 (@siswa, 30, 'earn', 'achievement', @ach2, 'DEMO · lencana Rajin Belajar');

-- ------------------------------------------------------ 10. Arena & file
INSERT INTO arena_sessions (code, quiz_id, host_id, status, current_question, question_time) VALUES
 ('DEMO-AR-1', @quiz_mat, @guru, 'waiting', 0, 20),
 ('DEMO-AR-2', @quiz_ipa, @guru, 'completed', 2, 20);

INSERT INTO file_folders (folder_name, parent_id, owner_id, quiz_id, folder_type, description) VALUES
 ('DEMO · Materi Kelas SD-4', NULL, @guru, NULL, 'folder', 'Folder contoh untuk materi'),
 ('DEMO · Lampiran Kuis', NULL, @guru, @quiz_mat, 'folder', 'Folder contoh lampiran kuis');

INSERT INTO files (file_name, original_name, file_path, file_size, file_type, mime_type, uploader_id, folder_id, quiz_id, description, is_public) VALUES
 ('DEMO · ringkasan-pecahan.pdf', 'ringkasan-pecahan.pdf', 'uploads/materials/demo-ringkasan-pecahan.pdf',
  102400, 'document', 'application/pdf', @guru, NULL, NULL, 'Contoh file materi (placeholder, bukan file fisik)', 1),
 ('DEMO · soal-matematika.png', 'soal-matematika.png', 'uploads/questions/demo-soal-matematika.png',
  51200, 'image', 'image/png', @guru, NULL, @quiz_mat, 'Contoh gambar soal (placeholder)', 1);

-- ------------------------------------------------- 11. Pengeluaran bimbel
INSERT INTO expenses (kategori, nominal, tanggal, deskripsi, created_by) VALUES
 ('Operasional', 150000.00, CURDATE(), 'DEMO · cetak modul belajar', @owner),
 ('Honor', 500000.00, CURDATE(), 'DEMO · honor pengajar bulan ini', @owner);

-- ------------------------------------------------------------------ 12. Cek
SELECT 'users' AS fitur, COUNT(*) AS jumlah FROM users WHERE email IN ('owner@belajarku.id','pengajar@belajarku.id','siswa@belajarku.id')
UNION ALL SELECT 'quiz', COUNT(*) FROM quiz WHERE title LIKE 'DEMO ·%'
UNION ALL SELECT 'questions', COUNT(*) FROM questions WHERE quiz_id IN (SELECT id FROM quiz WHERE title LIKE 'DEMO ·%')
UNION ALL SELECT 'materi', COUNT(*) FROM materials WHERE title LIKE 'DEMO ·%'
UNION ALL SELECT 'pengumuman', COUNT(*) FROM information_board WHERE title LIKE 'DEMO ·%'
UNION ALL SELECT 'presensi', COUNT(*) FROM attendance_records
UNION ALL SELECT 'tagihan', COUNT(*) FROM invoices WHERE invoice_number LIKE 'DEMO-%'
UNION ALL SELECT 'transaksi_kuota', COUNT(*) FROM transactions WHERE order_id LIKE 'DEMO-%'
UNION ALL SELECT 'quota_logs', COUNT(*) FROM quota_logs WHERE reference_id LIKE 'DEMO ·%'
UNION ALL SELECT 'chat', COUNT(*) FROM chat_messages WHERE message_text LIKE 'DEMO ·%'
UNION ALL SELECT 'achievements', COUNT(*) FROM achievements WHERE name LIKE 'DEMO ·%'
UNION ALL SELECT 'files', COUNT(*) FROM files WHERE file_name LIKE 'DEMO ·%'
UNION ALL SELECT 'arena', COUNT(*) FROM arena_sessions WHERE code LIKE 'DEMO-%'
UNION ALL SELECT 'expenses', COUNT(*) FROM expenses WHERE deskripsi LIKE 'DEMO ·%';
