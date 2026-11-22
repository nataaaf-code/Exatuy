package com.examora.model;

import java.time.LocalDateTime;
import java.time.ZoneId;
import java.time.ZonedDateTime;
import java.time.format.DateTimeFormatter;

/**
 * Quiz Model - Represents a quiz/exam in the Examora system
 */
public class Quiz {
    private Integer id;
    private String title;
    private String description;
    private Integer duration; // in minutes
    private Boolean isActive;
    private Integer createdBy;
    private String createdByName; // for display purposes
    private LocalDateTime deadline; // deadline for taking the quiz
    private LocalDateTime startTime; // scheduled start time for auto-publish
    private String targetTag; // target tag for quiz visibility (null = all users)
    private String subject; // Mata pelajaran (Matematika, IPA, dll)
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
    private Integer questionCount; // for display purposes

    // Quiz enhancement fields
    private Boolean shuffleQuestions; // whether to randomize question order
    private Boolean showReview; // whether to show answer review after submission

    // Exemption time configuration (in minutes)
    private Integer exemptionTime; // null = use default 10 minutes

    // Constructors
    public Quiz() {}

    public Quiz(String title, String description, Integer duration, Integer createdBy) {
        this.title = title;
        this.description = description;
        this.duration = duration;
        this.createdBy = createdBy;
        this.isActive = false;
    }

    // Getters and Setters
    public Integer getId() {
        return id;
    }

    public void setId(Integer id) {
        this.id = id;
    }

    public String getTitle() {
        return title;
    }

    public void setTitle(String title) {
        this.title = title;
    }

    public String getDescription() {
        return description;
    }

    public void setDescription(String description) {
        this.description = description;
    }

    public Integer getDuration() {
        return duration;
    }

    public void setDuration(Integer duration) {
        this.duration = duration;
    }

    public Boolean getIsActive() {
        return isActive;
    }

    public void setIsActive(Boolean isActive) {
        this.isActive = isActive;
    }

    public Integer getCreatedBy() {
        return createdBy;
    }

    public void setCreatedBy(Integer createdBy) {
        this.createdBy = createdBy;
    }

    public String getCreatedByName() {
        return createdByName;
    }

    public void setCreatedByName(String createdByName) {
        this.createdByName = createdByName;
    }

    public LocalDateTime getDeadline() {
        return deadline;
    }

    public void setDeadline(LocalDateTime deadline) {
        this.deadline = deadline;
    }

    public LocalDateTime getStartTime() {
        return startTime;
    }

    public void setStartTime(LocalDateTime startTime) {
        this.startTime = startTime;
    }

    public String getTargetTag() {
        return targetTag;
    }

    public void setTargetTag(String targetTag) {
        this.targetTag = targetTag;
    }

    public String getSubject() {
        return subject;
    }

    public void setSubject(String subject) {
        this.subject = subject;
    }

    /**
     * Returns explicit subject if set, otherwise infers common subjects from title/description.
     */
    public String getEffectiveSubject() {
        if (subject != null && !subject.trim().isEmpty()) {
            return subject.trim();
        }
        String text = ((title != null ? title : "") + " " + (description != null ? description : "")).toLowerCase();
        if (text.contains("matematika") || text.contains("math") || text.contains("aljabar") || text.contains("geometri") || text.contains("aritmatika")) {
            return "Matematika";
        }
        if (text.contains("ipa") || text.contains("fisika") || text.contains("biologi") || text.contains("kimia") || text.contains("sains")) {
            return "IPA";
        }
        if (text.contains("bahasa indonesia") || text.contains("b. indonesia") || text.contains("b.indo")) {
            return "Bahasa Indonesia";
        }
        if (text.contains("bahasa inggris") || text.contains("english") || text.contains("b. inggris")) {
            return "Bahasa Inggris";
        }
        if (text.contains("ips") || text.contains("sejarah") || text.contains("geografi") || text.contains("ekonomi")) {
            return "IPS";
        }
        return "Umum";
    }

    public LocalDateTime getCreatedAt() {
        return createdAt;
    }

    public void setCreatedAt(LocalDateTime createdAt) {
        this.createdAt = createdAt;
    }

    public LocalDateTime getUpdatedAt() {
        return updatedAt;
    }

    public void setUpdatedAt(LocalDateTime updatedAt) {
        this.updatedAt = updatedAt;
    }

    public Integer getQuestionCount() {
        return questionCount;
    }

    public void setQuestionCount(Integer questionCount) {
        this.questionCount = questionCount;
    }

    public Boolean getShuffleQuestions() {
        return shuffleQuestions;
    }

    public void setShuffleQuestions(Boolean shuffleQuestions) {
        this.shuffleQuestions = shuffleQuestions;
    }

    public Boolean getShowReview() {
        return showReview;
    }

    public void setShowReview(Boolean showReview) {
        this.showReview = showReview;
    }

    public Integer getExemptionTime() {
        return exemptionTime;
    }

    public void setExemptionTime(Integer exemptionTime) {
        this.exemptionTime = exemptionTime;
    }

    // Get effective exemption time in minutes (default 10 if not set)
    public int getEffectiveExemptionTime() {
        return exemptionTime != null ? exemptionTime : 10;
    }

    // Check if quiz is expired (past deadline) using WIB timezone
    // Quiz is considered expired if current time is equal to or after deadline
    public boolean isExpired() {
        if (deadline == null) {
            return false; // No deadline means never expires
        }
        // Compare using WIB (Asia/Jakarta) timezone for consistency
        ZonedDateTime now = ZonedDateTime.now(ZoneId.of("Asia/Jakarta"));
        ZonedDateTime deadlineWib = deadline.atZone(ZoneId.of("Asia/Jakarta"));
        // Expired if now is NOT before deadline (i.e., now >= deadline)
        return !now.isBefore(deadlineWib);
    }

    // Check if quiz is available (active and not expired)
    public boolean isAvailable() {
        return isActive != null && isActive && !isExpired();
    }

    // Get formatted deadline for display with WIB (Jakarta time)
    public String getFormattedDeadline() {
        if (deadline == null) {
            return "Tidak ada deadline";
        }
        // Convert to WIB (Asia/Jakarta) timezone
        ZonedDateTime wibTime = deadline.atZone(ZoneId.of("Asia/Jakarta"));
        DateTimeFormatter formatter = DateTimeFormatter.ofPattern("dd MMM yyyy HH:mm");
        return wibTime.format(formatter) + " WIB";
    }

    // Get deadline for datetime-local input (yyyy-MM-ddTHH:mm format)
    public String getDeadlineForInput() {
        if (deadline == null) {
            return "";
        }
        return deadline.format(DateTimeFormatter.ofPattern("yyyy-MM-dd'T'HH:mm"));
    }

    // Get formatted start time for display with WIB (Jakarta time)
    public String getFormattedStartTime() {
        if (startTime == null) {
            return "Tidak dijadwalkan";
        }
        ZonedDateTime wibTime = startTime.atZone(ZoneId.of("Asia/Jakarta"));
        DateTimeFormatter formatter = DateTimeFormatter.ofPattern("dd MMM yyyy HH:mm");
        return wibTime.format(formatter) + " WIB";
    }

    // Get start time for datetime-local input (yyyy-MM-ddTHH:mm format)
    public String getStartTimeForInput() {
        if (startTime == null) {
            return "";
        }
        return startTime.format(DateTimeFormatter.ofPattern("yyyy-MM-dd'T'HH:mm"));
    }

    // Get formatted deadline short version (without year if same year)
    public String getFormattedDeadlineShort() {
        if (deadline == null) {
            return "-";
        }
        ZonedDateTime wibTime = deadline.atZone(ZoneId.of("Asia/Jakarta"));
        ZonedDateTime now = ZonedDateTime.now(ZoneId.of("Asia/Jakarta"));

        DateTimeFormatter formatter;
        if (wibTime.getYear() == now.getYear()) {
            formatter = DateTimeFormatter.ofPattern("dd MMM HH:mm");
        } else {
            formatter = DateTimeFormatter.ofPattern("dd MMM yy HH:mm");
        }
        return wibTime.format(formatter) + " WIB";
    }

    // Check if quiz is visible to a specific tag
    public boolean isVisibleToTag(String userTag) {
        // If no target tag, visible to all
        if (targetTag == null || targetTag.isEmpty() || "ALL".equals(targetTag)) {
            return true;
        }
        // If user has no tag, only see quizzes for all
        if (userTag == null || userTag.isEmpty()) {
            return targetTag == null || targetTag.isEmpty() || "ALL".equals(targetTag);
        }
        // Check if user's tag is in the comma-separated list of target tags
        String[] tags = targetTag.split(",");
        for (String tag : tags) {
            if (tag.trim().equals(userTag)) {
                return true;
            }
        }
        return false;
    }

    // Check if quiz is for all tags
    public boolean isForAllTags() {
        return targetTag == null || targetTag.isEmpty() || "ALL".equals(targetTag);
    }

    @Override
    public String toString() {
        return "Quiz{" +
                "id=" + id +
                ", title='" + title + '\'' +
                ", duration=" + duration +
                ", isActive=" + isActive +
                ", deadline=" + deadline +
                ", targetTag='" + targetTag + '\'' +
                '}';
    }
}
