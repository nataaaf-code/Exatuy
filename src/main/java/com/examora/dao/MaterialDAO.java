package com.examora.dao;

import com.examora.model.Material;
import com.examora.util.DBUtil;

import java.sql.*;
import java.util.ArrayList;
import java.util.List;

public class MaterialDAO {
    private static final String VISIBLE_TO_STUDENT = "m.is_active = TRUE AND ("
            + "m.target_tags IS NULL OR TRIM(m.target_tags) = '' "
            + "OR UPPER(TRIM(m.target_tags)) = 'ALL' "
            + "OR FIND_IN_SET(?, REPLACE(m.target_tags, ', ', ',')) > 0)";

    public List<Material> findAll() throws SQLException {
        List<Material> list = new ArrayList<>();
        String sql = "SELECT m.*, mc.nama as category_name FROM materials m " +
                     "LEFT JOIN material_categories mc ON m.category_id = mc.id " +
                     "ORDER BY m.created_at DESC";
        try (Connection conn = DBUtil.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql);
             ResultSet rs = stmt.executeQuery()) {
            while (rs.next()) list.add(mapRow(rs));
        }
        return list;
    }

    public List<Material> findByCategoryId(int categoryId) throws SQLException {
        List<Material> list = new ArrayList<>();
        String sql = "SELECT m.*, mc.nama as category_name FROM materials m " +
                     "LEFT JOIN material_categories mc ON m.category_id = mc.id " +
                     "WHERE m.category_id = ? AND m.is_active = TRUE ORDER BY m.created_at DESC";
        try (Connection conn = DBUtil.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setInt(1, categoryId);
            try (ResultSet rs = stmt.executeQuery()) {
                while (rs.next()) list.add(mapRow(rs));
            }
        }
        return list;
    }

    public List<Material> findByJenjang(String jenjang) throws SQLException {
        List<Material> list = new ArrayList<>();
        String sql = "SELECT m.*, mc.nama as category_name FROM materials m " +
                     "JOIN material_categories mc ON m.category_id = mc.id " +
                     "WHERE mc.jenjang = ? AND m.is_active = TRUE ORDER BY mc.mata_pelajaran, m.created_at DESC";
        try (Connection conn = DBUtil.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setString(1, jenjang);
            try (ResultSet rs = stmt.executeQuery()) {
                while (rs.next()) list.add(mapRow(rs));
            }
        }
        return list;
    }

    public List<Material> findByTag(String userTag) throws SQLException {
        List<Material> list = new ArrayList<>();
        String sql = "SELECT m.*, mc.nama as category_name FROM materials m " +
                     "JOIN material_categories mc ON m.category_id = mc.id " +
                     "WHERE " + VISIBLE_TO_STUDENT + " " +
                     "ORDER BY mc.jenjang, mc.mata_pelajaran, m.created_at DESC";
        try (Connection conn = DBUtil.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setString(1, userTag == null ? "" : userTag.trim());
            try (ResultSet rs = stmt.executeQuery()) {
                while (rs.next()) list.add(mapRow(rs));
            }
        }
        return list;
    }

    public Material findVisibleById(int id, String userTag) throws SQLException {
        String sql = "SELECT m.*, mc.nama as category_name FROM materials m " +
                     "JOIN material_categories mc ON m.category_id = mc.id " +
                     "WHERE m.id = ? AND " + VISIBLE_TO_STUDENT;
        try (Connection conn = DBUtil.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setInt(1, id);
            stmt.setString(2, userTag == null ? "" : userTag.trim());
            try (ResultSet rs = stmt.executeQuery()) {
                return rs.next() ? mapRow(rs) : null;
            }
        }
    }

    public Material findById(int id) throws SQLException {
        String sql = "SELECT m.*, mc.nama as category_name FROM materials m " +
                     "LEFT JOIN material_categories mc ON m.category_id = mc.id " +
                     "WHERE m.id = ?";
        try (Connection conn = DBUtil.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setInt(1, id);
            try (ResultSet rs = stmt.executeQuery()) {
                return rs.next() ? mapRow(rs) : null;
            }
        }
    }

    public void incrementViewCount(int id) throws SQLException {
        String sql = "UPDATE materials SET view_count = view_count + 1 WHERE id = ?";
        try (Connection conn = DBUtil.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setInt(1, id);
            stmt.executeUpdate();
        }
    }

    public void create(Material material) throws SQLException {
        String sql = "INSERT INTO materials (category_id, title, content, summary, file_path, file_type, file_size, " +
                     "target_tags, generated_by, is_generated) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)";
        try (Connection conn = DBUtil.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setInt(1, material.getCategoryId());
            stmt.setString(2, material.getTitle());
            stmt.setString(3, material.getContent());
            stmt.setString(4, material.getSummary());
            stmt.setString(5, material.getFilePath());
            stmt.setString(6, material.getFileType());
            stmt.setLong(7, material.getFileSize() != null ? material.getFileSize() : 0L);
            stmt.setString(8, material.getTargetTags());
            if (material.getGeneratedById() != null) {
                stmt.setInt(9, material.getGeneratedById());
            } else {
                stmt.setNull(9, Types.INTEGER);
            }
            stmt.setBoolean(10, material.getIsGenerated() != null ? material.getIsGenerated() : false);
            stmt.executeUpdate();
        }
    }

    public void update(Material material) throws SQLException {
        String sql = "UPDATE materials SET title=?, content=?, summary=?, file_path=?, file_type=?, " +
                     "file_size=?, target_tags=?, is_active=? WHERE id=?";
        try (Connection conn = DBUtil.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setString(1, material.getTitle());
            stmt.setString(2, material.getContent());
            stmt.setString(3, material.getSummary());
            stmt.setString(4, material.getFilePath());
            stmt.setString(5, material.getFileType());
            stmt.setLong(6, material.getFileSize() != null ? material.getFileSize() : 0L);
            stmt.setString(7, material.getTargetTags());
            stmt.setBoolean(8, material.getIsActive() != null ? material.getIsActive() : true);
            stmt.setInt(9, material.getId());
            stmt.executeUpdate();
        }
    }

    public void delete(int id) throws SQLException {
        String sql = "UPDATE materials SET is_active = FALSE WHERE id = ?";
        try (Connection conn = DBUtil.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setInt(1, id);
            stmt.executeUpdate();
        }
    }

    public void logDownload(int materialId, Integer userId) throws SQLException {
        String sql = "INSERT INTO material_downloads (material_id, user_id) VALUES (?, ?)";
        try (Connection conn = DBUtil.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setInt(1, materialId);
            if (userId == null) stmt.setNull(2, Types.INTEGER);
            else stmt.setInt(2, userId);
            stmt.executeUpdate();
        }
        String sql2 = "UPDATE materials SET download_count = download_count + 1 WHERE id = ?";
        try (Connection conn = DBUtil.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql2)) {
            stmt.setInt(1, materialId);
            stmt.executeUpdate();
        }
    }

    private Material mapRow(ResultSet rs) throws SQLException {
        Material m = new Material();
        m.setId(rs.getInt("id"));
        m.setCategoryId(rs.getInt("category_id"));
        m.setCategoryName(rs.getString("category_name"));
        m.setTitle(rs.getString("title"));
        m.setContent(rs.getString("content"));
        m.setSummary(rs.getString("summary"));
        m.setFilePath(rs.getString("file_path"));
        m.setFileType(rs.getString("file_type"));
        m.setFileSize(rs.getLong("file_size"));
        m.setTargetTags(rs.getString("target_tags"));
        m.setGeneratedById(rs.getInt("generated_by"));
        m.setGeneratedByName(rs.getString("generated_by"));
        m.setIsGenerated(rs.getBoolean("is_generated"));
        m.setViewCount(rs.getInt("view_count"));
        m.setDownloadCount(rs.getInt("download_count"));
        m.setIsActive(rs.getBoolean("is_active"));
        m.setCreatedAt(rs.getTimestamp("created_at") != null ? rs.getTimestamp("created_at").toLocalDateTime() : null);
        m.setUpdatedAt(rs.getTimestamp("updated_at") != null ? rs.getTimestamp("updated_at").toLocalDateTime() : null);
        return m;
    }
}
