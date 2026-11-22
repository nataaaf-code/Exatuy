package com.examora.model;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;

/**
 * CashInTransaction Model - Represents a student quota purchase transaction
 * tracked in the Cash-In Financial Report (completed / pending / failed).
 */
public class CashInTransaction {
    private Integer id;
    private String orderId;
    private Integer studentId;
    private String studentName;
    private String studentEmail;
    private String studentTag;
    private int pointsPurchased;
    private BigDecimal amount;
    private String status; // completed, pending, failed
    private String paymentMethod;
    private String sumopodPaymentId;
    private String paymentLinkUrl;
    private LocalDateTime paidAt;
    private LocalDateTime createdAt;

    public CashInTransaction() {}

    public Integer getId() {
        return id;
    }

    public void setId(Integer id) {
        this.id = id;
    }

    public String getOrderId() {
        return orderId;
    }

    public void setOrderId(String orderId) {
        this.orderId = orderId;
    }

    public Integer getStudentId() {
        return studentId;
    }

    public void setStudentId(Integer studentId) {
        this.studentId = studentId;
    }

    public String getStudentName() {
        return studentName;
    }

    public void setStudentName(String studentName) {
        this.studentName = studentName;
    }

    public String getStudentEmail() {
        return studentEmail;
    }

    public void setStudentEmail(String studentEmail) {
        this.studentEmail = studentEmail;
    }

    public String getStudentTag() {
        return studentTag;
    }

    public void setStudentTag(String studentTag) {
        this.studentTag = studentTag;
    }

    public int getPointsPurchased() {
        return pointsPurchased;
    }

    public void setPointsPurchased(int pointsPurchased) {
        this.pointsPurchased = pointsPurchased;
    }

    public BigDecimal getAmount() {
        return amount != null ? amount : BigDecimal.ZERO;
    }

    public void setAmount(BigDecimal amount) {
        this.amount = amount;
    }

    public String getStatus() {
        return status;
    }

    public void setStatus(String status) {
        this.status = status;
    }

    public String getPaymentMethod() {
        return paymentMethod;
    }

    public void setPaymentMethod(String paymentMethod) {
        this.paymentMethod = paymentMethod;
    }

    public String getSumopodPaymentId() {
        return sumopodPaymentId;
    }

    public void setSumopodPaymentId(String sumopodPaymentId) {
        this.sumopodPaymentId = sumopodPaymentId;
    }

    public String getPaymentLinkUrl() {
        return paymentLinkUrl;
    }

    public void setPaymentLinkUrl(String paymentLinkUrl) {
        this.paymentLinkUrl = paymentLinkUrl;
    }

    public LocalDateTime getPaidAt() {
        return paidAt;
    }

    public void setPaidAt(LocalDateTime paidAt) {
        this.paidAt = paidAt;
    }

    public LocalDateTime getCreatedAt() {
        return createdAt;
    }

    public void setCreatedAt(LocalDateTime createdAt) {
        this.createdAt = createdAt;
    }

    public String getStatusLabel() {
        if ("completed".equalsIgnoreCase(status)) return "Berhasil";
        if ("failed".equalsIgnoreCase(status)) return "Gagal";
        return "Pending";
    }

    public String getStatusBadgeClass() {
        if ("completed".equalsIgnoreCase(status)) return "bg-success text-white";
        if ("failed".equalsIgnoreCase(status)) return "bg-danger text-white";
        return "bg-warning text-dark";
    }

    public String getFormattedCreatedAt() {
        if (createdAt == null) return "-";
        return createdAt.format(DateTimeFormatter.ofPattern("dd MMM yyyy, HH:mm"));
    }

    public String getFormattedPaidAt() {
        if (paidAt == null) return "-";
        return paidAt.format(DateTimeFormatter.ofPattern("dd MMM yyyy, HH:mm"));
    }
}
