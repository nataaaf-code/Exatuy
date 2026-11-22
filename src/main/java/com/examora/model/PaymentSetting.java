package com.examora.model;

import java.math.BigDecimal;
import java.time.LocalDateTime;

/**
 * PaymentSetting Model - Stores Sumopod payment gateway configuration
 * and dummy quota pricing controlled by admin/teacher.
 */
public class PaymentSetting {
    private int id = 1;
    private String sumopodApiKeyEnc;
    private String sumopodWebhookToken;
    private boolean liveMode;
    private BigDecimal dummyPricePerPoint = new BigDecimal("10000.00");
    private int maxQuotaPerMonth = 12;
    private LocalDateTime updatedAt;

    public PaymentSetting() {}

    public int getId() {
        return id;
    }

    public void setId(int id) {
        this.id = id;
    }

    public String getSumopodApiKeyEnc() {
        return sumopodApiKeyEnc;
    }

    public void setSumopodApiKeyEnc(String sumopodApiKeyEnc) {
        this.sumopodApiKeyEnc = sumopodApiKeyEnc;
    }

    public String getSumopodWebhookToken() {
        return sumopodWebhookToken;
    }

    public void setSumopodWebhookToken(String sumopodWebhookToken) {
        this.sumopodWebhookToken = sumopodWebhookToken;
    }

    public boolean isLiveMode() {
        return liveMode;
    }

    public void setLiveMode(boolean liveMode) {
        this.liveMode = liveMode;
    }

    public BigDecimal getDummyPricePerPoint() {
        return dummyPricePerPoint != null ? dummyPricePerPoint : new BigDecimal("10000.00");
    }

    public void setDummyPricePerPoint(BigDecimal dummyPricePerPoint) {
        this.dummyPricePerPoint = dummyPricePerPoint;
    }

    public int getMaxQuotaPerMonth() {
        return maxQuotaPerMonth > 0 ? maxQuotaPerMonth : 12;
    }

    public void setMaxQuotaPerMonth(int maxQuotaPerMonth) {
        this.maxQuotaPerMonth = maxQuotaPerMonth;
    }

    public LocalDateTime getUpdatedAt() {
        return updatedAt;
    }

    public void setUpdatedAt(LocalDateTime updatedAt) {
        this.updatedAt = updatedAt;
    }

    public boolean isConfigured() {
        return sumopodApiKeyEnc != null && !sumopodApiKeyEnc.trim().isEmpty();
    }

    public BigDecimal calculatePackagePrice(int points) {
        BigDecimal unit = getDummyPricePerPoint();
        return unit.multiply(BigDecimal.valueOf(points));
    }
}
