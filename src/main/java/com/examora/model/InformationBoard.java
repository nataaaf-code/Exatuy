package com.examora.model;

import java.time.LocalDateTime;
import java.time.ZoneId;
import java.time.ZonedDateTime;
import java.time.format.DateTimeFormatter;

/**
 * InformationBoard Model - Represents announcements and information for users
 */
public class InformationBoard {
    private Integer id;
    private String title;
    private String content;
    private String infoType;  // announcement, info, warning, success
    private String priority;  // low, normal, high, urgent
    private String targetAudience;  // all, participants, admins
    private String category;        // Info Exam, Jadwal GMeet, Tagihan & Kuota, Umum
    private String targetGrade;     // ALL, SD-1..SD-6, SMP-7..SMP-9
    private Boolean isActive;

    /** Kategori resmi pengumuman sesuai PRD (#17). */
    public static final String[] CATEGORIES = {"Info Exam", "Jadwal GMeet", "Tagihan & Kuota", "Umum"};

    /** Pilihan jenjang untuk filter target_grade. */
    public static final String[] GRADES = {
            "ALL", "SD-1", "SD-2", "SD-3", "SD-4", "SD-5", "SD-6", "SMP-7", "SMP-8", "SMP-9"
    };
    private LocalDateTime showUntil;
    private Integer createdBy;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;

    // Display fields
    private String creatorName;
    private Integer viewCount;

    // Constructors
    public InformationBoard() {}

    public InformationBoard(String title, String content, String infoType, Integer createdBy) {
        this.title = title;
        this.content = content;
        this.infoType = infoType;
        this.priority = "normal";
        this.targetAudience = "all";
        this.isActive = true;
        this.createdBy = createdBy;
    }

    // Getters and Setters
    public Integer getId() { return id; }
    public void setId(Integer id) { this.id = id; }

    public String getTitle() { return title; }
    public void setTitle(String title) { this.title = title; }

    public String getContent() { return content; }
    public void setContent(String content) { this.content = content; }

    public String getInfoType() { return infoType; }
    public void setInfoType(String infoType) { this.infoType = infoType; }

    public String getPriority() { return priority; }
    public void setPriority(String priority) { this.priority = priority; }

    public String getTargetAudience() { return targetAudience; }
    public void setTargetAudience(String targetAudience) { this.targetAudience = targetAudience; }

    public String getCategory() { return category != null ? category : "Umum"; }
    public void setCategory(String category) { this.category = category; }

    public String getTargetGrade() { return targetGrade != null ? targetGrade : "ALL"; }
    public void setTargetGrade(String targetGrade) { this.targetGrade = targetGrade; }

    /** Tampilan jenjang: "ALL" -> "Semua Jenjang". */
    public String getTargetGradeDisplay() {
        String grade = getTargetGrade();
        return "ALL".equalsIgnoreCase(grade) ? "Semua Jenjang" : grade;
    }

    /** Warna badge kategori untuk dashboard siswa. */
    public String getCategoryBadgeClass() {
        switch (getCategory()) {
            case "Info Exam":
                return "bg-primary bg-opacity-10 text-primary";
            case "Jadwal GMeet":
                return "bg-success bg-opacity-10 text-success";
            case "Tagihan & Kuota":
                return "bg-warning bg-opacity-10 text-warning";
            default:
                return "bg-secondary bg-opacity-10 text-secondary";
        }
    }

    public Boolean getIsActive() { return isActive; }
    public void setIsActive(Boolean isActive) { this.isActive = isActive; }

    public LocalDateTime getShowUntil() { return showUntil; }
    public void setShowUntil(LocalDateTime showUntil) { this.showUntil = showUntil; }

    public Integer getCreatedBy() { return createdBy; }
    public void setCreatedBy(Integer createdBy) { this.createdBy = createdBy; }

    public LocalDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(LocalDateTime createdAt) { this.createdAt = createdAt; }

    public LocalDateTime getUpdatedAt() { return updatedAt; }
    public void setUpdatedAt(LocalDateTime updatedAt) { this.updatedAt = updatedAt; }

    public String getCreatorName() { return creatorName; }
    public void setCreatorName(String creatorName) { this.creatorName = creatorName; }

    public Integer getViewCount() { return viewCount; }
    public void setViewCount(Integer viewCount) { this.viewCount = viewCount; }

    // Utility methods
    public String getFormattedCreatedAt() {
        if (createdAt == null) return "-";
        ZonedDateTime wibTime = createdAt.atZone(ZoneId.of("Asia/Jakarta"));
        DateTimeFormatter formatter = DateTimeFormatter.ofPattern("dd MMM yyyy, HH:mm");
        return wibTime.format(formatter) + " WIB";
    }

    public String getFormattedShowUntil() {
        if (showUntil == null) return "Tidak ada batas";
        ZonedDateTime wibTime = showUntil.atZone(ZoneId.of("Asia/Jakarta"));
        DateTimeFormatter formatter = DateTimeFormatter.ofPattern("dd MMM yyyy, HH:mm");
        return wibTime.format(formatter) + " WIB";
    }

    public boolean isExpired() {
        if (showUntil == null) return false;
        return LocalDateTime.now().isAfter(showUntil);
    }

    public String getStatusBadge() {
        if (!getIsActive() || isExpired()) {
            return "<span class=\"badge bg-secondary\">Inactive</span>";
        }
        return "<span class=\"badge bg-success\">Active</span>";
    }

    public String getPriorityBadge() {
        switch (priority != null ? priority : "normal") {
            case "low":
                return "<span class=\"badge bg-info\">Low</span>";
            case "normal":
                return "<span class=\"badge bg-primary\">Normal</span>";
            case "high":
                return "<span class=\"badge bg-warning\">High</span>";
            case "urgent":
                return "<span class=\"badge bg-danger\">Urgent</span>";
            default:
                return "<span class=\"badge bg-secondary\">" + priority + "</span>";
        }
    }

    public String getTypeBadge() {
        switch (infoType != null ? infoType : "info") {
            case "announcement":
                return "<span class=\"badge bg-primary\"><i class=\"bi bi-megaphone me-1\"></i>Pengumuman</span>";
            case "info":
                return "<span class=\"badge bg-info\"><i class=\"bi bi-info-circle me-1\"></i>Info</span>";
            case "warning":
                return "<span class=\"badge bg-warning\"><i class=\"bi bi-exclamation-triangle me-1\"></i>Peringatan</span>";
            case "success":
                return "<span class=\"badge bg-success\"><i class=\"bi bi-check-circle me-1\"></i>Berhasil</span>";
            default:
                return "<span class=\"badge bg-secondary\">" + infoType + "</span>";
        }
    }

    public String getIconForDisplay() {
        switch (infoType != null ? infoType : "info") {
            case "announcement":
                return "bi-megaphone-fill text-primary";
            case "info":
                return "bi-info-circle-fill text-info";
            case "warning":
                return "bi-exclamation-triangle-fill text-warning";
            case "success":
                return "bi-check-circle-fill text-success";
            default:
                return "bi-bell-fill text-secondary";
        }
    }

    public String getTargetAudienceDisplay() {
        switch (targetAudience != null ? targetAudience : "all") {
            case "all":
                return "<i class=\"bi bi-people me-1\"></i>Semua User";
            case "participants":
                return "<i class=\"bi bi-person-check me-1\"></i>Peserta";
            case "admins":
                return "<i class=\"bi bi-shield-lock me-1\"></i>Admin";
            default:
                return targetAudience;
        }
    }

    public String getTargetAudiencePlain() {
        switch (targetAudience != null ? targetAudience : "all") {
            case "all":
                return "Semua User";
            case "participants":
                return "Peserta";
            case "admins":
                return "Admin";
            default:
                return targetAudience;
        }
    }

    public String getPriorityBadgeBg() {
        switch (priority != null ? priority : "normal") {
            case "low":
                return "bg-info bg-opacity-10";
            case "normal":
                return "bg-primary bg-opacity-10";
            case "high":
                return "bg-warning bg-opacity-10";
            case "urgent":
                return "bg-danger bg-opacity-10";
            default:
                return "bg-secondary bg-opacity-10";
        }
    }

    public String getTypeIcon() {
        switch (infoType != null ? infoType : "info") {
            case "announcement":
                return "bi-megaphone-fill";
            case "info":
                return "bi-info-circle-fill";
            case "warning":
                return "bi-exclamation-triangle-fill";
            case "success":
                return "bi-check-circle-fill";
            default:
                return "bi-bell-fill";
        }
    }

    public String getTypeIconBg() {
        switch (infoType != null ? infoType : "info") {
            case "announcement":
                return "bg-primary bg-opacity-10";
            case "info":
                return "bg-info bg-opacity-10";
            case "warning":
                return "bg-warning bg-opacity-10";
            case "success":
                return "bg-success bg-opacity-10";
            default:
                return "bg-secondary bg-opacity-10";
        }
    }

    public String getTypeIconColor() {
        switch (infoType != null ? infoType : "info") {
            case "announcement":
                return "text-primary";
            case "info":
                return "text-info";
            case "warning":
                return "text-warning";
            case "success":
                return "text-success";
            default:
                return "text-secondary";
        }
    }
}
