package com.examora.dao;

import com.examora.model.Question;
import com.examora.util.DBUtil;

import java.sql.*;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * Question Data Access Object - Handles database operations for questions
 */
public class QuestionDAO {

    /**
     * Create a new question
     */
    public Question create(Question question) throws SQLException {
        String sql = "INSERT INTO questions (quiz_id, question_text, image_path, option_a, option_b, option_c, option_d, correct_answer, question_order, category_id, is_bank_question, explanation) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)";

        try (Connection conn = DBUtil.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql, Statement.RETURN_GENERATED_KEYS)) {

            if (question.getQuizId() != null) {
                stmt.setInt(1, question.getQuizId());
            } else {
                stmt.setNull(1, Types.INTEGER);
            }
            stmt.setString(2, question.getQuestionText());
            stmt.setString(3, question.getImagePath());
            stmt.setString(4, question.getOptionA());
            stmt.setString(5, question.getOptionB());
            stmt.setString(6, question.getOptionC());
            stmt.setString(7, question.getOptionD());
            stmt.setString(8, question.getCorrectAnswer());
            stmt.setInt(9, question.getQuestionOrder() != null ? question.getQuestionOrder() : 0);
            if (question.getCategoryId() != null) {
                stmt.setInt(10, question.getCategoryId());
            } else {
                stmt.setNull(10, Types.INTEGER);
            }
            stmt.setBoolean(11, question.getQuizId() == null);
            stmt.setString(12, question.getExplanation());

            int affectedRows = stmt.executeUpdate();

            if (affectedRows == 0) {
                throw new SQLException("Creating question failed, no rows affected.");
            }

            try (ResultSet generatedKeys = stmt.getGeneratedKeys()) {
                if (generatedKeys.next()) {
                    question.setId(generatedKeys.getInt(1));
                } else {
                    throw new SQLException("Creating question failed, no ID obtained.");
                }
            }

            return question;
        }
    }

    public Integer findCategoryIdByName(String name) throws SQLException {
        try (Connection conn = DBUtil.getConnection();
             PreparedStatement stmt = conn.prepareStatement(
                     "SELECT id FROM question_categories WHERE name = ? LIMIT 1")) {
            stmt.setString(1, name);
            try (ResultSet rs = stmt.executeQuery()) {
                return rs.next() ? rs.getInt(1) : null;
            }
        }
    }

    /**
     * Find question by ID
     */
    public Question findById(Integer id) throws SQLException {
        String sql = "SELECT * FROM questions WHERE id = ?";

        try (Connection conn = DBUtil.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {

            stmt.setInt(1, id);

            try (ResultSet rs = stmt.executeQuery()) {
                if (rs.next()) {
                    return mapResultSetToQuestion(rs);
                }
            }
        }
        return null;
    }

    /**
     * Get all questions for a quiz
     */
    public List<Question> findByQuizId(Integer quizId) throws SQLException {
        String sql = "SELECT * FROM questions WHERE quiz_id = ? ORDER BY question_order, id";
        List<Question> questions = new ArrayList<>();

        try (Connection conn = DBUtil.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {

            stmt.setInt(1, quizId);

            try (ResultSet rs = stmt.executeQuery()) {
                while (rs.next()) {
                    questions.add(mapResultSetToQuestion(rs));
                }
            }
        }
        return questions;
    }

    /**
     * Find question by ID without correct answer (safe for exam use)
     */
    public Question findByIdForExam(Integer id) throws SQLException {
        String sql = "SELECT id, quiz_id, question_text, image_path, option_a, option_b, option_c, option_d, question_order FROM questions WHERE id = ?";

        try (Connection conn = DBUtil.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {

            stmt.setInt(1, id);

            try (ResultSet rs = stmt.executeQuery()) {
                if (rs.next()) {
                    Question question = new Question();
                    question.setId(rs.getInt("id"));
                    question.setQuizId(rs.getInt("quiz_id"));
                    question.setQuestionText(rs.getString("question_text"));
                    question.setImagePath(rs.getString("image_path"));
                    question.setOptionA(rs.getString("option_a"));
                    question.setOptionB(rs.getString("option_b"));
                    question.setOptionC(rs.getString("option_c"));
                    question.setOptionD(rs.getString("option_d"));
                    question.setQuestionOrder(rs.getInt("question_order"));
                    return question;
                }
            }
        }
        return null;
    }

    /**
     * Get questions for a quiz (without correct answers - for taking exam)
     * @param quizId the quiz ID
     * @param shuffle whether to shuffle question order (if false, order by question_order)
     */
    public List<Question> findByQuizIdForExam(Integer quizId, boolean shuffle) throws SQLException {
        String orderBy = shuffle ? "RAND()" : "question_order, id";
        String sql = "SELECT id, quiz_id, question_text, image_path, option_a, option_b, option_c, option_d, question_order FROM questions WHERE quiz_id = ? ORDER BY " + orderBy;
        List<Question> questions = new ArrayList<>();

        try (Connection conn = DBUtil.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {

            stmt.setInt(1, quizId);

            try (ResultSet rs = stmt.executeQuery()) {
                while (rs.next()) {
                    Question q = new Question();
                    q.setId(rs.getInt("id"));
                    q.setQuizId(rs.getInt("quiz_id"));
                    q.setQuestionText(rs.getString("question_text"));
                    q.setImagePath(rs.getString("image_path"));
                    q.setOptionA(rs.getString("option_a"));
                    q.setOptionB(rs.getString("option_b"));
                    q.setOptionC(rs.getString("option_c"));
                    q.setOptionD(rs.getString("option_d"));
                    q.setQuestionOrder(rs.getInt("question_order"));
                    questions.add(q);
                }
            }
        }
        return questions;
    }

    /**
     * Get questions for a quiz (without correct answers - for taking exam)
     * Uses a deterministic seed so the same submission always gets the same order
     * @param quizId the quiz ID
     * @param seed deterministic seed (use submission ID)
     */
    public List<Question> findByQuizIdForExam(Integer quizId, int seed) throws SQLException {
        String sql = "SELECT id, quiz_id, question_text, image_path, option_a, option_b, option_c, option_d, question_order FROM questions WHERE quiz_id = ? ORDER BY RAND(?)";
        List<Question> questions = new ArrayList<>();

        try (Connection conn = DBUtil.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {

            stmt.setInt(1, quizId);
            stmt.setInt(2, seed);

            try (ResultSet rs = stmt.executeQuery()) {
                while (rs.next()) {
                    Question q = new Question();
                    q.setId(rs.getInt("id"));
                    q.setQuizId(rs.getInt("quiz_id"));
                    q.setQuestionText(rs.getString("question_text"));
                    q.setImagePath(rs.getString("image_path"));
                    q.setOptionA(rs.getString("option_a"));
                    q.setOptionB(rs.getString("option_b"));
                    q.setOptionC(rs.getString("option_c"));
                    q.setOptionD(rs.getString("option_d"));
                    q.setQuestionOrder(rs.getInt("question_order"));
                    questions.add(q);
                }
            }
        }
        return questions;
    }

    /**
     * Get questions for a quiz (without correct answers - for taking exam)
     * Legacy method with default shuffle behavior (shuffles by default)
     */
    public List<Question> findByQuizIdForExam(Integer quizId) throws SQLException {
        return findByQuizIdForExam(quizId, true);
    }

    /**
     * Update question
     */
    public boolean update(Question question) throws SQLException {
        String sql = "UPDATE questions SET question_text = ?, image_path = ?, option_a = ?, option_b = ?, option_c = ?, option_d = ?, correct_answer = ?, question_order = ?, category_id = ?, is_bank_question = ?, explanation = ? WHERE id = ?";

        try (Connection conn = DBUtil.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {

            stmt.setString(1, question.getQuestionText());
            stmt.setString(2, question.getImagePath());
            stmt.setString(3, question.getOptionA());
            stmt.setString(4, question.getOptionB());
            stmt.setString(5, question.getOptionC());
            stmt.setString(6, question.getOptionD());
            stmt.setString(7, question.getCorrectAnswer());
            stmt.setInt(8, question.getQuestionOrder() != null ? question.getQuestionOrder() : 0);
            if (question.getCategoryId() != null) {
                stmt.setInt(9, question.getCategoryId());
            } else {
                stmt.setNull(9, Types.INTEGER);
            }
            stmt.setBoolean(10, false);
            stmt.setString(11, question.getExplanation());
            stmt.setInt(12, question.getId());

            return stmt.executeUpdate() > 0;
        }
    }

    /**
     * Delete question
     */
    public boolean delete(Integer id) throws SQLException {
        String sql = "DELETE FROM questions WHERE id = ?";

        try (Connection conn = DBUtil.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {

            stmt.setInt(1, id);
            return stmt.executeUpdate() > 0;
        }
    }

    /**
     * Delete all questions for a quiz
     */
    public boolean deleteByQuizId(Integer quizId) throws SQLException {
        String sql = "DELETE FROM questions WHERE quiz_id = ?";

        try (Connection conn = DBUtil.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {

            stmt.setInt(1, quizId);
            return stmt.executeUpdate() > 0;
        }
    }

    /**
     * Count questions for a quiz
     */
    public int countByQuizId(Integer quizId) throws SQLException {
        String sql = "SELECT COUNT(*) FROM questions WHERE quiz_id = ?";

        try (Connection conn = DBUtil.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {

            stmt.setInt(1, quizId);

            try (ResultSet rs = stmt.executeQuery()) {
                if (rs.next()) {
                    return rs.getInt(1);
                }
            }
        }
        return 0;
    }

    /**
     * Get correct answers for a quiz (for scoring)
     */
    public List<Question> getCorrectAnswers(Integer quizId) throws SQLException {
        String sql = "SELECT id, correct_answer FROM questions WHERE quiz_id = ?";
        List<Question> questions = new ArrayList<>();

        try (Connection conn = DBUtil.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {

            stmt.setInt(1, quizId);

            try (ResultSet rs = stmt.executeQuery()) {
                while (rs.next()) {
                    Question q = new Question();
                    q.setId(rs.getInt("id"));
                    q.setCorrectAnswer(rs.getString("correct_answer"));
                    questions.add(q);
                }
            }
        }
        return questions;
    }

    /**
     * Map ResultSet to Question object
     */
    private Question mapResultSetToQuestion(ResultSet rs) throws SQLException {
        Question question = new Question();
        question.setId(rs.getInt("id"));

        int quizId = rs.getInt("quiz_id");
        if (!rs.wasNull()) {
            question.setQuizId(quizId);
        }

        question.setQuestionText(rs.getString("question_text"));
        question.setImagePath(rs.getString("image_path"));
        question.setOptionA(rs.getString("option_a"));
        question.setOptionB(rs.getString("option_b"));
        question.setOptionC(rs.getString("option_c"));
        question.setOptionD(rs.getString("option_d"));
        question.setCorrectAnswer(rs.getString("correct_answer"));
        question.setQuestionOrder(rs.getInt("question_order"));

        int categoryId = rs.getInt("category_id");
        if (!rs.wasNull()) {
            question.setCategoryId(categoryId);
        }

        Timestamp createdAt = rs.getTimestamp("created_at");
        if (createdAt != null) {
            question.setCreatedAt(createdAt.toLocalDateTime());
        }

        // New fields for quiz enhancements
        question.setExplanation(rs.getString("explanation"));
        question.setTotalAttempts(rs.getInt("total_attempts"));
        question.setCorrectAttempts(rs.getInt("correct_attempts"));
        question.setDifficultyIndex(rs.getDouble("difficulty_index"));

        return question;
    }

    // ==================== Question Statistics Methods ====================

    /**
     * Update question statistics (increment attempts and correct attempts)
     * @param questionId the question ID
     * @param isCorrect whether the answer was correct
     */
    public boolean updateStatistics(Integer questionId, boolean isCorrect) throws SQLException {
        String sql = "UPDATE questions SET " +
                     "total_attempts = total_attempts + 1, " +
                     "correct_attempts = correct_attempts + IF(?, 1, 0), " +
                     "difficulty_index = (total_attempts - correct_attempts) / (total_attempts + 1) " +
                     "WHERE id = ?";

        try (Connection conn = DBUtil.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {

            stmt.setBoolean(1, isCorrect);
            stmt.setInt(2, questionId);

            return stmt.executeUpdate() > 0;
        }
    }

    /**
     * Batch update question statistics
     * @param answers Map of questionId to isCorrect
     */
    public void batchUpdateStatistics(Map<Integer, Boolean> answers) throws SQLException {
        String sql = "UPDATE questions SET " +
                     "total_attempts = total_attempts + 1, " +
                     "correct_attempts = correct_attempts + IF(?, 1, 0), " +
                     "difficulty_index = (total_attempts - correct_attempts) / (total_attempts + 1) " +
                     "WHERE id = ?";

        try (Connection conn = DBUtil.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {

            for (Map.Entry<Integer, Boolean> entry : answers.entrySet()) {
                stmt.setBoolean(1, entry.getValue());
                stmt.setInt(2, entry.getKey());
                stmt.addBatch();
            }

            stmt.executeBatch();
        }
    }

    /**
     * Get question statistics for a quiz
     */
    public List<Map<String, Object>> getQuestionStatistics(Integer quizId) throws SQLException {
        String sql = "SELECT q.id, q.question_text, q.correct_answer, q.total_attempts, q.correct_attempts, q.difficulty_index, " +
                     "c.name as category_name " +
                     "FROM questions q " +
                     "LEFT JOIN question_categories c ON q.category_id = c.id " +
                     "WHERE q.quiz_id = ? " +
                     "ORDER BY q.question_order, q.id";

        List<Map<String, Object>> stats = new ArrayList<>();

        try (Connection conn = DBUtil.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {

            stmt.setInt(1, quizId);

            try (ResultSet rs = stmt.executeQuery()) {
                while (rs.next()) {
                    Map<String, Object> stat = new HashMap<>();
                    stat.put("id", rs.getInt("id"));
                    stat.put("questionText", rs.getString("question_text"));
                    stat.put("correctAnswer", rs.getString("correct_answer"));
                    stat.put("totalAttempts", rs.getInt("total_attempts"));
                    stat.put("correctAttempts", rs.getInt("correct_attempts"));
                    stat.put("difficultyIndex", rs.getDouble("difficulty_index"));
                    stat.put("categoryName", rs.getString("category_name"));

                    // Calculate correct percentage
                    int total = rs.getInt("total_attempts");
                    int correct = rs.getInt("correct_attempts");
                    double percentage = (total > 0) ? (correct * 100.0 / total) : 0;
                    stat.put("correctPercentage", percentage);

                    // Determine difficulty label
                    String difficultyLabel;
                    if (total == 0) {
                        difficultyLabel = "N/A";
                    } else if (percentage >= 70) {
                        difficultyLabel = "Mudah";
                    } else if (percentage >= 40) {
                        difficultyLabel = "Sedang";
                    } else {
                        difficultyLabel = "Sulit";
                    }
                    stat.put("difficultyLabel", difficultyLabel);

                    stats.add(stat);
                }
            }
        }
        return stats;
    }

}
