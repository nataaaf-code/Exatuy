package com.examora.dao;

import com.examora.util.DBUtil;

import java.sql.*;
import java.util.ArrayList;
import java.util.List;

/**
 * MeetLinkDAO — CRUD tautan Google Meet / Drive yang dibuat pengajar.
 *
 * Tautan dipilih untuk siswa berdasarkan kelas (`target_tag`) dan jenjang
 * (`target_grade`); baris dengan target kosong/ALL berlaku untuk semua.
 */
public class MeetLinkDAO {

    public static class MeetLink {
        public Integer id;
        public String title;
        public String url;
        public String targetTag;
        public String targetGrade = "ALL";
        public String scheduleInfo;
        public Boolean isActive = true;
        public String createdAt;
    }

    private static final String COLUMNS =
            "id, title, url, target_tag, target_grade, schedule_info, is_active, created_at";

    public List<MeetLink> findAll() throws SQLException {
        List<MeetLink> list = new ArrayList<>();
        try (Connection conn = DBUtil.getConnection();
             Statement stmt = conn.createStatement();
             ResultSet rs = stmt.executeQuery(
                     "SELECT " + COLUMNS + " FROM meet_links ORDER BY is_active DESC, id DESC")) {
            while (rs.next()) {
                list.add(map(rs));
            }
        }
        return list;
    }

    /**
     * Tautan aktif yang paling relevan untuk seorang siswa.
     * Prioritas: cocok kelas + jenjang > cocok jenjang > berlaku umum.
     */
    public MeetLink findForStudent(String tag, String gradeLevel) throws SQLException {
        String sql = "SELECT " + COLUMNS + " FROM meet_links WHERE is_active = 1 "
                + "AND (target_grade IS NULL OR target_grade = '' OR UPPER(target_grade) = 'ALL' "
                + "     OR UPPER(target_grade) = UPPER(COALESCE(?, ''))) "
                + "AND (target_tag IS NULL OR target_tag = '' OR target_tag = COALESCE(?, '')) "
                + "ORDER BY (target_tag = COALESCE(?, '')) DESC, (UPPER(target_grade) = UPPER(COALESCE(?, ''))) DESC, id DESC "
                + "LIMIT 1";
        try (Connection conn = DBUtil.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setString(1, gradeLevel);
            stmt.setString(2, tag);
            stmt.setString(3, tag);
            stmt.setString(4, gradeLevel);
            try (ResultSet rs = stmt.executeQuery()) {
                return rs.next() ? map(rs) : null;
            }
        }
    }

    public MeetLink findById(Integer id) throws SQLException {
        try (Connection conn = DBUtil.getConnection();
             PreparedStatement stmt = conn.prepareStatement(
                     "SELECT " + COLUMNS + " FROM meet_links WHERE id = ?")) {
            stmt.setInt(1, id);
            try (ResultSet rs = stmt.executeQuery()) {
                return rs.next() ? map(rs) : null;
            }
        }
    }

    public void create(MeetLink link, Integer createdBy) throws SQLException {
        String sql = "INSERT INTO meet_links (title, url, target_tag, target_grade, schedule_info, is_active, created_by) "
                + "VALUES (?, ?, ?, ?, ?, ?, ?)";
        try (Connection conn = DBUtil.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {
            bindCommon(stmt, link);
            stmt.setInt(7, createdBy == null ? 0 : createdBy);
            stmt.executeUpdate();
        }
    }

    public void update(MeetLink link) throws SQLException {
        String sql = "UPDATE meet_links SET title = ?, url = ?, target_tag = ?, target_grade = ?, "
                + "schedule_info = ?, is_active = ? WHERE id = ?";
        try (Connection conn = DBUtil.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {
            bindCommon(stmt, link);
            stmt.setInt(7, link.id);
            stmt.executeUpdate();
        }
    }

    public void delete(Integer id) throws SQLException {
        try (Connection conn = DBUtil.getConnection();
             PreparedStatement stmt = conn.prepareStatement("DELETE FROM meet_links WHERE id = ?")) {
            stmt.setInt(1, id);
            stmt.executeUpdate();
        }
    }

    public void toggleActive(Integer id) throws SQLException {
        try (Connection conn = DBUtil.getConnection();
             PreparedStatement stmt = conn.prepareStatement(
                     "UPDATE meet_links SET is_active = NOT is_active WHERE id = ?")) {
            stmt.setInt(1, id);
            stmt.executeUpdate();
        }
    }

    private void bindCommon(PreparedStatement stmt, MeetLink link) throws SQLException {
        stmt.setString(1, link.title);
        stmt.setString(2, link.url);
        if (link.targetTag == null || link.targetTag.isBlank()) {
            stmt.setNull(3, Types.VARCHAR);
        } else {
            stmt.setString(3, link.targetTag.trim());
        }
        stmt.setString(4, link.targetGrade == null || link.targetGrade.isBlank() ? "ALL" : link.targetGrade.trim().toUpperCase());
        stmt.setString(5, link.scheduleInfo);
        stmt.setBoolean(6, link.isActive == null || link.isActive);
    }

    private MeetLink map(ResultSet rs) throws SQLException {
        MeetLink link = new MeetLink();
        link.id = rs.getInt("id");
        link.title = rs.getString("title");
        link.url = rs.getString("url");
        link.targetTag = rs.getString("target_tag");
        link.targetGrade = rs.getString("target_grade");
        link.scheduleInfo = rs.getString("schedule_info");
        link.isActive = rs.getBoolean("is_active");
        Timestamp ts = rs.getTimestamp("created_at");
        link.createdAt = ts == null ? "-" : ts.toLocalDateTime().toString().replace('T', ' ');
        return link;
    }
}
