package com.examora.dao;

import com.examora.model.User;
import com.examora.util.DBUtil;

import java.sql.*;
import java.util.ArrayList;
import java.util.List;

/**
 * Bulk Email DAO - Daftar penerima pengingat email massal per grup
 */
public class BulkEmailDAO {

    private static final String COLUMNS = "u.id, u.name, u.email";

    /**
     * Siswa yang punya transaksi pembayaran berstatus pending.
     */
    public List<User> findUnpaid() throws SQLException {
        return query("SELECT DISTINCT " + COLUMNS + " FROM users u " +
                "JOIN transactions t ON t.student_id = u.id " +
                "WHERE u.role = 'peserta' AND t.status = 'pending' ORDER BY u.name");
    }

    /**
     * Siswa dengan saldo kuota 0, termasuk yang saldonya sudah hangus tapi belum di-reset.
     */
    public List<User> findQuotaEmpty(String month) throws SQLException {
        return query("SELECT " + COLUMNS + " FROM users u WHERE u.role = 'peserta' " +
                "AND (u.quota_balance = 0 OR u.last_reset_month IS NULL OR u.last_reset_month <> ?) " +
                "ORDER BY u.name", month);
    }

    /**
     * Siswa yang bisa melihat exam ini (tag cocok / exam publik) tapi belum mengumpulkannya.
     */
    public List<User> findExamNotSubmitted(int quizId) throws SQLException {
        return query("SELECT " + COLUMNS + " FROM users u JOIN quiz q ON q.id = ? " +
                "WHERE u.role = 'peserta' " +
                "AND (q.target_tag IS NULL OR q.target_tag = '' OR q.target_tag = u.tag) " +
                "AND NOT EXISTS (SELECT 1 FROM submissions s WHERE s.quiz_id = q.id AND s.user_id = u.id " +
                "AND s.status IN ('completed', 'timeout')) " +
                "ORDER BY u.name", quizId);
    }

    /**
     * Semua siswa, atau siswa satu jenjang jika gradeLevel diisi.
     */
    public List<User> findStudents(String gradeLevel) throws SQLException {
        if (gradeLevel == null || gradeLevel.isEmpty()) {
            return query("SELECT " + COLUMNS + " FROM users u WHERE u.role = 'peserta' ORDER BY u.name");
        }
        return query("SELECT " + COLUMNS + " FROM users u WHERE u.role = 'peserta' AND u.grade_level = ? " +
                "ORDER BY u.name", gradeLevel);
    }

    /**
     * Jenjang yang sudah terisi pada data siswa, untuk pilihan filter.
     */
    public List<String> findGradeLevels() throws SQLException {
        List<String> grades = new ArrayList<>();
        try (Connection conn = DBUtil.getConnection();
             PreparedStatement stmt = conn.prepareStatement(
                     "SELECT DISTINCT grade_level FROM users WHERE role = 'peserta' " +
                     "AND grade_level IS NOT NULL AND grade_level <> '' ORDER BY grade_level");
             ResultSet rs = stmt.executeQuery()) {
            while (rs.next()) {
                grades.add(rs.getString(1));
            }
        }
        return grades;
    }

    private List<User> query(String sql, Object... params) throws SQLException {
        List<User> users = new ArrayList<>();
        try (Connection conn = DBUtil.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {
            for (int i = 0; i < params.length; i++) {
                stmt.setObject(i + 1, params[i]);
            }
            try (ResultSet rs = stmt.executeQuery()) {
                while (rs.next()) {
                    User user = new User();
                    user.setId(rs.getInt("id"));
                    user.setName(rs.getString("name"));
                    user.setEmail(rs.getString("email"));
                    users.add(user);
                }
            }
        }
        return users;
    }
}
