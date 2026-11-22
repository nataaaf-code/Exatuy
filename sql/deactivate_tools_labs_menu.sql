-- Sembunyikan menu custom (link eksternal) dari tampilan user/navbar.
-- Menu yang is_active = 0 tidak dirender oleh user/navbar.jspf
-- (CustomPageDAO.findActive / findActiveForTag), tetapi tetap terlihat dan
-- bisa diaktifkan kembali dari admin: Admin > Custom Pages.
--
-- Menu yang dinonaktifkan:
--   * Tools        -> https://tools.ids-cybersec.com
--   * Labs         -> https://labs.ids-cybersec.com
--   * Nilai Tugas  -> Google Sheets rekap nilai tugas
--
-- Aman dijalankan berulang kali.

UPDATE custom_pages
   SET is_active = 0
 WHERE is_active = 1
   AND menu_name IN ('Tools', 'Labs', 'Nilai Tugas');

-- Verifikasi: hanya menu aktif yang tampil ke user
-- SELECT id, menu_name, is_active FROM custom_pages ORDER BY sort_order;
