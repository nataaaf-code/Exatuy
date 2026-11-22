package com.examora.service;

import com.examora.dao.ApiKeyDAO;
import com.examora.dao.InformationBoardDAO;
import com.examora.model.ApiKey;
import com.examora.model.InformationBoard;

import java.security.SecureRandom;
import java.sql.SQLException;
import java.util.Base64;
import java.util.List;

/**
 * ApiService - Manages API keys and Information Board
 */
public class ApiService {
    private ApiKeyDAO apiKeyDAO;
    private InformationBoardDAO informationBoardDAO;

    public ApiService() {
        this.apiKeyDAO = new ApiKeyDAO();
        this.informationBoardDAO = new InformationBoardDAO();
    }

    // ==================== API KEYS ====================

    /**
     * Create new API key with auto-generated value
     */
    public ApiKey createApiKey(String keyName, String keyType, String description,
                              Integer createdBy, Integer expiresInDays) throws ServiceException {
        try {
            // Check if key name already exists
            if (apiKeyDAO.existsByName(keyName, null)) {
                throw new ServiceException("Nama API key '" + keyName + "' sudah digunakan");
            }

            // Generate secure random key
            String keyValue = generateApiKey();

            ApiKey apiKey = new ApiKey(keyName, keyValue, keyType, createdBy);
            apiKey.setDescription(description);

            if (expiresInDays != null && expiresInDays > 0) {
                apiKey.setExpiresAt(java.time.LocalDateTime.now().plusDays(expiresInDays));
            }

            return apiKeyDAO.create(apiKey);
        } catch (SQLException e) {
            throw new ServiceException("Gagal membuat API key: " + e.getMessage(), e);
        }
    }

    /**
     * Generate secure random API key
     */
    private String generateApiKey() {
        SecureRandom random = new SecureRandom();
        byte[] keyBytes = new byte[32];
        random.nextBytes(keyBytes);
        return Base64.getUrlEncoder().withoutPadding().encodeToString(keyBytes);
    }

    /**
     * Get all API keys
     */
    public List<ApiKey> getAllApiKeys() throws ServiceException {
        try {
            return apiKeyDAO.findAll();
        } catch (SQLException e) {
            throw new ServiceException("Gagal mengambil API keys: " + e.getMessage(), e);
        }
    }

    /**
     * Get active API keys
     */
    public List<ApiKey> getActiveApiKeys() throws ServiceException {
        try {
            return apiKeyDAO.findActive();
        } catch (SQLException e) {
            throw new ServiceException("Gagal mengambil API keys aktif: " + e.getMessage(), e);
        }
    }

    /**
     * Get API key by ID
     */
    public ApiKey getApiKey(Integer id) throws ServiceException {
        try {
            ApiKey key = apiKeyDAO.findById(id);
            if (key == null) {
                throw new ServiceException("API key tidak ditemukan");
            }
            return key;
        } catch (SQLException e) {
            throw new ServiceException("Gagal mengambil API key: " + e.getMessage(), e);
        }
    }

    /**
     * Update API key
     */
    public ApiKey updateApiKey(Integer id, String keyName, String description,
                              Boolean isActive) throws ServiceException {
        try {
            ApiKey apiKey = getApiKey(id);

            // Check if new name conflicts with another key
            if (!apiKey.getKeyName().equals(keyName) && apiKeyDAO.existsByName(keyName, id)) {
                throw new ServiceException("Nama API key '" + keyName + "' sudah digunakan");
            }

            apiKey.setKeyName(keyName);
            apiKey.setDescription(description);
            apiKey.setIsActive(isActive);

            if (apiKeyDAO.update(apiKey)) {
                return apiKey;
            }
            throw new ServiceException("Gagal mengupdate API key");
        } catch (SQLException e) {
            throw new ServiceException("Gagal mengupdate API key: " + e.getMessage(), e);
        }
    }

    /**
     * Delete API key
     */
    public void deleteApiKey(Integer id) throws ServiceException {
        try {
            if (!apiKeyDAO.delete(id)) {
                throw new ServiceException("Gagal menghapus API key");
            }
        } catch (SQLException e) {
            throw new ServiceException("Gagal menghapus API key: " + e.getMessage(), e);
        }
    }

    /**
     * Validate API key
     */
    public boolean validateApiKey(String keyValue) throws ServiceException {
        try {
            ApiKey apiKey = apiKeyDAO.findByKeyValue(keyValue);
            if (apiKey == null) {
                return false;
            }

            if (!apiKey.getIsActive()) {
                return false;
            }

            if (apiKey.isExpired()) {
                return false;
            }

            // Update last used
            apiKeyDAO.updateLastUsed(apiKey.getId());
            return true;
        } catch (SQLException e) {
            throw new ServiceException("Gagal memvalidasi API key: " + e.getMessage(), e);
        }
    }

    // ==================== INFORMATION BOARD ====================

    /**
     * Create new information/announcement
     */
    public InformationBoard createInformation(String title, String content, String infoType,
                                              String priority, String targetAudience, Integer createdBy,
                                              java.time.LocalDateTime showUntil) throws ServiceException {
        return createInformation(title, content, infoType, "Umum", priority, targetAudience, "ALL",
                createdBy, showUntil);
    }

    /**
     * Create new information/announcement dengan kategori & jenjang (P1 #17).
     *
     * @param category    Info Exam | Jadwal GMeet | Tagihan & Kuota | Umum
     * @param targetGrade ALL | SD-1..SD-6 | SMP-7..SMP-9
     */
    public InformationBoard createInformation(String title, String content, String infoType,
                                              String category, String priority, String targetAudience,
                                              String targetGrade, Integer createdBy,
                                              java.time.LocalDateTime showUntil) throws ServiceException {
        try {
            InformationBoard info = new InformationBoard(title, content, infoType, createdBy);
            info.setCategory(normalizeCategory(category));
            info.setPriority(priority);
            info.setTargetAudience(targetAudience);
            info.setTargetGrade(normalizeGrade(targetGrade));
            info.setShowUntil(showUntil);

            return informationBoardDAO.create(info);
        } catch (SQLException e) {
            throw new ServiceException("Gagal membuat informasi: " + e.getMessage(), e);
        }
    }

    /**
     * Get active information for target audience (semua jenjang).
     */
    public List<InformationBoard> getActiveInformation(String targetAudience) throws ServiceException {
        return getActiveInformation(targetAudience, null);
    }

    /**
     * Get active information untuk audiens + jenjang siswa (P1 #17).
     */
    public List<InformationBoard> getActiveInformation(String targetAudience, String gradeLevel)
            throws ServiceException {
        try {
            if (gradeLevel == null || gradeLevel.isBlank()) {
                return informationBoardDAO.findActiveForTarget(targetAudience);
            }
            return informationBoardDAO.findActiveForTargetAndGrade(targetAudience, gradeLevel);
        } catch (SQLException e) {
            throw new ServiceException("Gagal mengambil informasi: " + e.getMessage(), e);
        }
    }

    /** Validasi kategori agar hanya nilai resmi PRD yang tersimpan. */
    public static String normalizeCategory(String category) {
        if (category == null) {
            return "Umum";
        }
        for (String allowed : InformationBoard.CATEGORIES) {
            if (allowed.equalsIgnoreCase(category.trim())) {
                return allowed;
            }
        }
        return "Umum";
    }

    /** Validasi jenjang agar hanya nilai yang dikenal yang tersimpan. */
    public static String normalizeGrade(String grade) {
        if (grade == null || grade.isBlank()) {
            return "ALL";
        }
        String value = grade.trim().toUpperCase();
        for (String allowed : InformationBoard.GRADES) {
            if (allowed.equals(value)) {
                return allowed;
            }
        }
        return "ALL";
    }

    /**
     * Get all information (admin view)
     */
    public List<InformationBoard> getAllInformation() throws ServiceException {
        try {
            return informationBoardDAO.findAll();
        } catch (SQLException e) {
            throw new ServiceException("Gagal mengambil semua informasi: " + e.getMessage(), e);
        }
    }

    /**
     * Get information by ID
     */
    public InformationBoard getInformation(Integer id) throws ServiceException {
        try {
            InformationBoard info = informationBoardDAO.findById(id);
            if (info == null) {
                throw new ServiceException("Informasi tidak ditemukan");
            }
            return info;
        } catch (SQLException e) {
            throw new ServiceException("Gagal mengambil informasi: " + e.getMessage(), e);
        }
    }

    /**
     * Update information
     */
    public InformationBoard updateInformation(Integer id, String title, String content, String infoType,
                                              String priority, String targetAudience, Boolean isActive,
                                              java.time.LocalDateTime showUntil) throws ServiceException {
        InformationBoard existing = getInformation(id);
        return updateInformation(id, title, content, infoType, existing.getCategory(), priority,
                targetAudience, existing.getTargetGrade(), isActive, showUntil);
    }

    /**
     * Update information termasuk kategori & jenjang (P1 #17).
     */
    public InformationBoard updateInformation(Integer id, String title, String content, String infoType,
                                              String category, String priority, String targetAudience,
                                              String targetGrade, Boolean isActive,
                                              java.time.LocalDateTime showUntil) throws ServiceException {
        try {
            InformationBoard info = getInformation(id);
            info.setTitle(title);
            info.setContent(content);
            info.setInfoType(infoType);
            info.setCategory(normalizeCategory(category));
            info.setPriority(priority);
            info.setTargetAudience(targetAudience);
            info.setTargetGrade(normalizeGrade(targetGrade));
            info.setIsActive(isActive);
            info.setShowUntil(showUntil);

            if (informationBoardDAO.update(info)) {
                return info;
            }
            throw new ServiceException("Gagal mengupdate informasi");
        } catch (SQLException e) {
            throw new ServiceException("Gagal mengupdate informasi: " + e.getMessage(), e);
        }
    }

    /**
     * Toggle active status
     */
    public boolean toggleInformationStatus(Integer id) throws ServiceException {
        try {
            return informationBoardDAO.toggleActive(id);
        } catch (SQLException e) {
            throw new ServiceException("Gagal mengubah status: " + e.getMessage(), e);
        }
    }

    /**
     * Delete information
     */
    public void deleteInformation(Integer id) throws ServiceException {
        try {
            if (!informationBoardDAO.delete(id)) {
                throw new ServiceException("Gagal menghapus informasi");
            }
        } catch (SQLException e) {
            throw new ServiceException("Gagal menghapus informasi: " + e.getMessage(), e);
        }
    }

    /**
     * Service Exception
     */
    public static class ServiceException extends Exception {
        public ServiceException(String message) {
            super(message);
        }

        public ServiceException(String message, Throwable cause) {
            super(message, cause);
        }
    }
}
