package com.examora.dao;

import com.examora.model.User;
import com.examora.util.DBUtil;

import java.sql.*;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * User Data Access Object - Handles database operations for users
 */
public class UserDAO {

    /**
     * Create a new user
     */
    public User create(User user) throws SQLException {
        String sql = "INSERT INTO users (name, email, password, role, tag, gdrive_link) VALUES (?, ?, ?, ?, ?, ?)";

        try (Connection conn = DBUtil.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql, Statement.RETURN_GENERATED_KEYS)) {

            stmt.setString(1, user.getName());
            stmt.setString(2, user.getEmail());
            stmt.setString(3, user.getPassword());
            stmt.setString(4, user.getRole());
            stmt.setString(5, user.getTag());
            stmt.setString(6, user.getGdriveLink());

            int affectedRows = stmt.executeUpdate();

            if (affectedRows == 0) {
                throw new SQLException("Creating user failed, no rows affected.");
            }

            try (ResultSet generatedKeys = stmt.getGeneratedKeys()) {
                if (generatedKeys.next()) {
                    user.setId(generatedKeys.getInt(1));
                } else {
                    throw new SQLException("Creating user failed, no ID obtained.");
                }
            }

            return user;
        }
    }

    /**
     * Find user by ID
     */
    public User findById(Integer id) throws SQLException {
        String sql = "SELECT * FROM users WHERE id = ?";

        try (Connection conn = DBUtil.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {

            stmt.setInt(1, id);

            try (ResultSet rs = stmt.executeQuery()) {
                if (rs.next()) {
                    return mapResultSetToUser(rs);
                }
            }
        }
        return null;
    }

    /**
     * Find user by email
     */
    public User findByEmail(String email) throws SQLException {
        String sql = "SELECT * FROM users WHERE email = ?";

        try (Connection conn = DBUtil.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {

            stmt.setString(1, email);

            try (ResultSet rs = stmt.executeQuery()) {
                if (rs.next()) {
                    return mapResultSetToUser(rs);
                }
            }
        }
        return null;
    }

    /**
     * Search users by name or email (peserta only)
     */
    public List<User> searchUsers(String query) throws SQLException {
        String sql = "SELECT * FROM users WHERE (name LIKE ? OR email LIKE ?) AND role = 'peserta' ORDER BY name ASC LIMIT 20";
        List<User> users = new ArrayList<>();
        String likeQuery = "%" + query + "%";

        try (Connection conn = DBUtil.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {

            stmt.setString(1, likeQuery);
            stmt.setString(2, likeQuery);

            try (ResultSet rs = stmt.executeQuery()) {
                while (rs.next()) {
                    users.add(mapResultSetToUser(rs));
                }
            }
        }
        return users;
    }

    /**
     * Find user by email and password (for authentication)
     */
    public User findByEmailAndPassword(String email, String hashedPassword) throws SQLException {
        String sql = "SELECT * FROM users WHERE email = ?";

        try (Connection conn = DBUtil.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {

            stmt.setString(1, email);

            try (ResultSet rs = stmt.executeQuery()) {
                if (rs.next()) {
                    User user = mapResultSetToUser(rs);
                    // Password verification is handled by PasswordUtil in service layer
                    return user;
                }
            }
        }
        return null;
    }

    /**
     * Get all users
     */
    public List<User> findAll() throws SQLException {
        String sql = "SELECT * FROM users ORDER BY created_at DESC";
        List<User> users = new ArrayList<>();

        try (Connection conn = DBUtil.getConnection();
             Statement stmt = conn.createStatement();
             ResultSet rs = stmt.executeQuery(sql)) {

            while (rs.next()) {
                users.add(mapResultSetToUser(rs));
            }
        }
        return users;
    }

    /**
     * Get users by role
     */
    public List<User> findByRole(String role) throws SQLException {
        String sql = "SELECT * FROM users WHERE role = ? ORDER BY created_at DESC";
        List<User> users = new ArrayList<>();

        try (Connection conn = DBUtil.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {

            stmt.setString(1, role);

            try (ResultSet rs = stmt.executeQuery()) {
                while (rs.next()) {
                    users.add(mapResultSetToUser(rs));
                }
            }
        }
        return users;
    }

    /**
     * Update user
     */
    public boolean update(User user) throws SQLException {
        String sql = "UPDATE users SET name = ?, email = ?, role = ?, tag = ?, photo = ?, gdrive_link = ? WHERE id = ?";

        try (Connection conn = DBUtil.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {

            stmt.setString(1, user.getName());
            stmt.setString(2, user.getEmail());
            stmt.setString(3, user.getRole());
            stmt.setString(4, user.getTag());
            stmt.setString(5, user.getPhoto());
            stmt.setString(6, user.getGdriveLink());
            stmt.setInt(7, user.getId());

            return stmt.executeUpdate() > 0;
        }
    }

    /**
     * Update password
     */
    public boolean updatePassword(Integer userId, String hashedPassword) throws SQLException {
        String sql = "UPDATE users SET password = ? WHERE id = ?";

        try (Connection conn = DBUtil.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {

            stmt.setString(1, hashedPassword);
            stmt.setInt(2, userId);

            return stmt.executeUpdate() > 0;
        }
    }

    /**
     * Get PIN hash (null if the user has no PIN)
     */
    public String findPinHash(Integer userId) throws SQLException {
        String sql = "SELECT pin_hash FROM users WHERE id = ?";

        try (Connection conn = DBUtil.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {

            stmt.setInt(1, userId);

            try (ResultSet rs = stmt.executeQuery()) {
                return rs.next() ? rs.getString("pin_hash") : null;
            }
        }
    }

    /**
     * Update PIN hash
     */
    public boolean updatePinHash(Integer userId, String pinHash) throws SQLException {
        String sql = "UPDATE users SET pin_hash = ? WHERE id = ?";

        try (Connection conn = DBUtil.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {

            stmt.setString(1, pinHash);
            stmt.setInt(2, userId);

            return stmt.executeUpdate() > 0;
        }
    }

    /**
     * Delete user and all associated records across dependent tables
     */
    public boolean delete(Integer id) throws SQLException {
        String[] childTables = {
            "arena_participants",
            "attendance_records",
            "chat_messages",
            "file_downloads",
            "material_downloads",
            "notification_queue",
            "point_transactions",
            "quiz_exemptions",
            "quiz_sessions",
            "submissions",
            "user_achievements",
            "user_notification_settings",
            "user_points",
            "user_quiz_access"
        };

        try (Connection conn = DBUtil.getConnection()) {
            boolean originalAutoCommit = conn.getAutoCommit();
            try {
                conn.setAutoCommit(false);

                for (String table : childTables) {
                    String deleteChildSql = "DELETE FROM " + table + " WHERE user_id = ?";
                    try (PreparedStatement stmt = conn.prepareStatement(deleteChildSql)) {
                        stmt.setInt(1, id);
                        stmt.executeUpdate();
                    }
                }

                // Handle chat_messages where user is admin_id
                String deleteAdminChatSql = "DELETE FROM chat_messages WHERE admin_id = ?";
                try (PreparedStatement stmt = conn.prepareStatement(deleteAdminChatSql)) {
                    stmt.setInt(1, id);
                    stmt.executeUpdate();
                }

                String deleteUserSql = "DELETE FROM users WHERE id = ?";
                int rows;
                try (PreparedStatement stmt = conn.prepareStatement(deleteUserSql)) {
                    stmt.setInt(1, id);
                    rows = stmt.executeUpdate();
                }

                conn.commit();
                return rows > 0;
            } catch (SQLException e) {
                conn.rollback();
                throw e;
            } finally {
                conn.setAutoCommit(originalAutoCommit);
            }
        }
    }

    /**
     * Check if email exists
     */
    public boolean emailExists(String email) throws SQLException {
        String sql = "SELECT COUNT(*) FROM users WHERE email = ?";

        try (Connection conn = DBUtil.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {

            stmt.setString(1, email);

            try (ResultSet rs = stmt.executeQuery()) {
                if (rs.next()) {
                    return rs.getInt(1) > 0;
                }
            }
        }
        return false;
    }

    /**
     * Count users by role
     */
    public int countByRole(String role) throws SQLException {
        String sql = "SELECT COUNT(*) FROM users WHERE role = ?";

        try (Connection conn = DBUtil.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {

            stmt.setString(1, role);

            try (ResultSet rs = stmt.executeQuery()) {
                if (rs.next()) {
                    return rs.getInt(1);
                }
            }
        }
        return 0;
    }

    /**
     * Get all unique tags
     */
    public List<String> findAllTags() throws SQLException {
        String sql = "SELECT DISTINCT tag FROM users WHERE tag IS NOT NULL AND tag != '' ORDER BY tag";
        List<String> tags = new ArrayList<>();

        try (Connection conn = DBUtil.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql);
             ResultSet rs = stmt.executeQuery()) {

            while (rs.next()) {
                tags.add(rs.getString("tag"));
            }
        }
        return tags;
    }

    /**
     * Get users by tag
     */
    public List<User> findByTag(String tag) throws SQLException {
        String sql = "SELECT * FROM users WHERE tag = ? ORDER BY created_at DESC";
        List<User> users = new ArrayList<>();

        try (Connection conn = DBUtil.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {

            stmt.setString(1, tag);

            try (ResultSet rs = stmt.executeQuery()) {
                while (rs.next()) {
                    users.add(mapResultSetToUser(rs));
                }
            }
        }
        return users;
    }

    /**
     * Remove a tag from all users
     */
    public int removeTagFromAll(String tag) throws SQLException {
        String sql = "UPDATE users SET tag = NULL WHERE tag = ?";

        try (Connection conn = DBUtil.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {

            stmt.setString(1, tag);
            return stmt.executeUpdate();
        }
    }

    /**
     * Map ResultSet to User object
     */
    private User mapResultSetToUser(ResultSet rs) throws SQLException {
        User user = new User();
        user.setId(rs.getInt("id"));
        user.setName(rs.getString("name"));
        user.setEmail(rs.getString("email"));
        user.setPassword(rs.getString("password"));
        user.setRole(rs.getString("role"));
        user.setTag(rs.getString("tag"));
        user.setPhoto(rs.getString("photo"));
        user.setGdriveLink(rs.getString("gdrive_link"));

        // Achievement statistics (handle null for backward compatibility)
        try {
            user.setTotalPoints(rs.getInt("total_points"));
            if (rs.wasNull()) user.setTotalPoints(0);
        } catch (SQLException e) {
            user.setTotalPoints(0);
        }

        try {
            user.setTotalQuizzes(rs.getInt("total_quizzes"));
            if (rs.wasNull()) user.setTotalQuizzes(0);
        } catch (SQLException e) {
            user.setTotalQuizzes(0);
        }

        try {
            user.setPerfectScores(rs.getInt("perfect_scores"));
            if (rs.wasNull()) user.setPerfectScores(0);
        } catch (SQLException e) {
            user.setPerfectScores(0);
        }

        user.setCreatedAt(rs.getTimestamp("created_at").toLocalDateTime());
        user.setUpdatedAt(rs.getTimestamp("updated_at").toLocalDateTime());
        return user;
    }

    /**
     * Update photo only
     */
    public boolean updatePhoto(Integer userId, String photoPath) throws SQLException {
        String sql = "UPDATE users SET photo = ? WHERE id = ?";

        try (Connection conn = DBUtil.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {

            stmt.setString(1, photoPath);
            stmt.setInt(2, userId);

            return stmt.executeUpdate() > 0;
        }
    }

    /**
     * Update user statistics for achievements
     */
    public boolean updateStatistics(Integer userId, Integer totalPoints, Integer totalQuizzes, Integer perfectScores) throws SQLException {
        String sql = "UPDATE users SET total_points = ?, total_quizzes = ?, perfect_scores = ? WHERE id = ?";

        try (Connection conn = DBUtil.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {

            stmt.setInt(1, totalPoints != null ? totalPoints : 0);
            stmt.setInt(2, totalQuizzes != null ? totalQuizzes : 0);
            stmt.setInt(3, perfectScores != null ? perfectScores : 0);
            stmt.setInt(4, userId);

            return stmt.executeUpdate() > 0;
        }
    }

    /**
     * Get all users with pagination
     */
    public List<User> findAllPaginated(int page, int pageSize) throws SQLException {
        String sql = "SELECT * FROM users ORDER BY created_at DESC LIMIT ? OFFSET ?";
        List<User> users = new ArrayList<>();
        int offset = (page - 1) * pageSize;

        try (Connection conn = DBUtil.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {

            stmt.setInt(1, pageSize);
            stmt.setInt(2, offset);

            try (ResultSet rs = stmt.executeQuery()) {
                while (rs.next()) {
                    users.add(mapResultSetToUser(rs));
                }
            }
        }
        return users;
    }

    /**
     * Count all users
     */
    public int countAll() throws SQLException {
        String sql = "SELECT COUNT(*) FROM users";

        try (Connection conn = DBUtil.getConnection();
             Statement stmt = conn.createStatement();
             ResultSet rs = stmt.executeQuery(sql)) {

            if (rs.next()) {
                return rs.getInt(1);
            }
        }
        return 0;
    }

    /**
     * Get users by role with pagination
     */
    public List<User> findByRolePaginated(String role, int page, int pageSize) throws SQLException {
        String sql = "SELECT * FROM users WHERE role = ? ORDER BY created_at DESC LIMIT ? OFFSET ?";
        List<User> users = new ArrayList<>();
        int offset = (page - 1) * pageSize;

        try (Connection conn = DBUtil.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {

            stmt.setString(1, role);
            stmt.setInt(2, pageSize);
            stmt.setInt(3, offset);

            try (ResultSet rs = stmt.executeQuery()) {
                while (rs.next()) {
                    users.add(mapResultSetToUser(rs));
                }
            }
        }
        return users;
    }

    /**
     * Count users by role for pagination
     */
    public int countByRoleFilter(String role) throws SQLException {
        String sql = "SELECT COUNT(*) FROM users WHERE role = ?";

        try (Connection conn = DBUtil.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {

            stmt.setString(1, role);

            try (ResultSet rs = stmt.executeQuery()) {
                if (rs.next()) {
                    return rs.getInt(1);
                }
            }
        }
        return 0;
    }

    /**
     * Get users by tag with pagination
     */
    public List<User> findByTagPaginated(String tag, int page, int pageSize) throws SQLException {
        String sql = "SELECT * FROM users WHERE tag = ? ORDER BY created_at DESC LIMIT ? OFFSET ?";
        List<User> users = new ArrayList<>();
        int offset = (page - 1) * pageSize;

        try (Connection conn = DBUtil.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {

            stmt.setString(1, tag);
            stmt.setInt(2, pageSize);
            stmt.setInt(3, offset);

            try (ResultSet rs = stmt.executeQuery()) {
                while (rs.next()) {
                    users.add(mapResultSetToUser(rs));
                }
            }
        }
        return users;
    }

    /**
     * Count users by tag for pagination
     */
    public int countByTagFilter(String tag) throws SQLException {
        String sql = "SELECT COUNT(*) FROM users WHERE tag = ?";

        try (Connection conn = DBUtil.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {

            stmt.setString(1, tag);

            try (ResultSet rs = stmt.executeQuery()) {
                if (rs.next()) {
                    return rs.getInt(1);
                }
            }
        }
        return 0;
    }

    /**
     * Get all users with Google Drive link
     */
    public List<User> findAllWithGdriveLink() throws SQLException {
        String sql = "SELECT * FROM users WHERE gdrive_link IS NOT NULL AND gdrive_link != '' ORDER BY name";
        List<User> users = new ArrayList<>();

        try (Connection conn = DBUtil.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql);
             ResultSet rs = stmt.executeQuery()) {

            while (rs.next()) {
                users.add(mapResultSetToUser(rs));
            }
        }
        return users;
    }

    /**
     * Count users with Google Drive link
     */
    public int countWithGdriveLink() throws SQLException {
        String sql = "SELECT COUNT(*) FROM users WHERE gdrive_link IS NOT NULL AND gdrive_link != ''";

        try (Connection conn = DBUtil.getConnection();
             Statement stmt = conn.createStatement();
             ResultSet rs = stmt.executeQuery(sql)) {

            if (rs.next()) {
                return rs.getInt(1);
            }
        }
        return 0;
    }

    /**
     * Get top users by points for leaderboard
     */
    public List<Map<String, Object>> getTopUsersByPoints(int limit) throws SQLException {
        String sql = "SELECT id, name, email, total_points, total_quizzes, perfect_scores " +
                     "FROM users WHERE role = 'peserta' " +
                     "ORDER BY total_points DESC, total_quizzes DESC " +
                     "LIMIT ?";
        List<Map<String, Object>> leaderboard = new ArrayList<>();

        try (Connection conn = DBUtil.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {

            stmt.setInt(1, limit);

            try (ResultSet rs = stmt.executeQuery()) {
                while (rs.next()) {
                    Map<String, Object> entry = new HashMap<>();
                    entry.put("id", rs.getInt("id"));
                    entry.put("name", rs.getString("name"));
                    entry.put("email", rs.getString("email"));
                    entry.put("totalPoints", rs.getInt("total_points"));
                    entry.put("totalQuizzes", rs.getInt("total_quizzes"));
                    entry.put("perfectScores", rs.getInt("perfect_scores"));
                    leaderboard.add(entry);
                }
            }
        }
        return leaderboard;
    }
}
