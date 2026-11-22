package com.examora.util;

import javax.crypto.Cipher;
import javax.crypto.SecretKey;
import javax.crypto.spec.GCMParameterSpec;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.util.Base64;
import java.util.logging.Logger;

/**
 * CryptoUtil - AES-256-GCM encryption/decryption utility for sensitive credentials
 * such as the Sumopod API key stored in payment_settings.
 */
public class CryptoUtil {
    private static final String ALGORITHM = "AES";
    private static final String TRANSFORMATION = "AES/GCM/NoPadding";
    private static final int GCM_IV_LENGTH = 12;
    private static final int GCM_TAG_LENGTH = 128;

    private static final String DEFAULT_SECRET = "Exatuy-BimbelMentari-AES256-Key-2026";
    private static final Logger LOGGER = Logger.getLogger(CryptoUtil.class.getName());
    private static volatile boolean defaultKeyWarned;

    /**
     * Kunci enkripsi diambil dari env EXATUY_ENCRYPTION_KEY, lalu system property
     * exatuy.encryption.key. Kunci bawaan yang tertulis di source hanya dipakai bila
     * EXATUY_ALLOW_DEFAULT_KEY=true (pengembangan lokal), karena siapa pun yang memegang
     * source bisa mendekripsi data yang dienkripsi dengannya.
     */
    static String resolveSecret(String envKey, String propertyKey, String allowDefault) {
        if (envKey != null && !envKey.trim().isEmpty()) {
            return envKey;
        }
        if (propertyKey != null && !propertyKey.trim().isEmpty()) {
            return propertyKey;
        }
        if ("true".equalsIgnoreCase(allowDefault)) {
            if (!defaultKeyWarned) {
                defaultKeyWarned = true;
                LOGGER.warning("Memakai kunci enkripsi bawaan untuk pengembangan. JANGAN dipakai di produksi.");
            }
            return DEFAULT_SECRET;
        }
        throw new IllegalStateException(
                "EXATUY_ENCRYPTION_KEY belum diset di server, jadi kredensial tidak dapat dienkripsi.");
    }

    /**
     * True bila server punya kunci enkripsi (atau kunci bawaan diizinkan secara eksplisit).
     */
    public static boolean isKeyConfigured() {
        try {
            getSecretKey();
            return true;
        } catch (Exception e) {
            return false;
        }
    }

    private static SecretKey getSecretKey() throws Exception {
        String secret = resolveSecret(System.getenv("EXATUY_ENCRYPTION_KEY"),
                System.getProperty("exatuy.encryption.key"), System.getenv("EXATUY_ALLOW_DEFAULT_KEY"));
        MessageDigest sha = MessageDigest.getInstance("SHA-256");
        byte[] keyBytes = sha.digest(secret.getBytes(StandardCharsets.UTF_8));
        return new SecretKeySpec(keyBytes, ALGORITHM);
    }

    /**
     * Encrypt plaintext using AES-256-GCM. Returns Base64(iv + ciphertext).
     */
    public static String encrypt(String plainText) throws Exception {
        if (plainText == null || plainText.isEmpty()) {
            return null;
        }
        byte[] iv = new byte[GCM_IV_LENGTH];
        new SecureRandom().nextBytes(iv);

        Cipher cipher = Cipher.getInstance(TRANSFORMATION);
        GCMParameterSpec spec = new GCMParameterSpec(GCM_TAG_LENGTH, iv);
        cipher.init(Cipher.ENCRYPT_MODE, getSecretKey(), spec);

        byte[] encrypted = cipher.doFinal(plainText.getBytes(StandardCharsets.UTF_8));
        byte[] combined = new byte[iv.length + encrypted.length];
        System.arraycopy(iv, 0, combined, 0, iv.length);
        System.arraycopy(encrypted, 0, combined, iv.length, encrypted.length);

        return Base64.getEncoder().encodeToString(combined);
    }

    /**
     * Decrypt Base64(iv + ciphertext) produced by encrypt().
     */
    public static String decrypt(String cipherText) throws Exception {
        if (cipherText == null || cipherText.isEmpty()) {
            return null;
        }
        byte[] combined = Base64.getDecoder().decode(cipherText);
        if (combined.length <= GCM_IV_LENGTH) {
            throw new IllegalArgumentException("Invalid encrypted payload");
        }
        byte[] iv = new byte[GCM_IV_LENGTH];
        byte[] encrypted = new byte[combined.length - GCM_IV_LENGTH];
        System.arraycopy(combined, 0, iv, 0, GCM_IV_LENGTH);
        System.arraycopy(combined, GCM_IV_LENGTH, encrypted, 0, encrypted.length);

        Cipher cipher = Cipher.getInstance(TRANSFORMATION);
        GCMParameterSpec spec = new GCMParameterSpec(GCM_TAG_LENGTH, iv);
        cipher.init(Cipher.DECRYPT_MODE, getSecretKey(), spec);

        byte[] decrypted = cipher.doFinal(encrypted);
        return new String(decrypted, StandardCharsets.UTF_8);
    }

    /**
     * Mask a secret string for safe display in UI (e.g., "sk_live_****1234").
     */
    public static String maskSecret(String secret) {
        if (secret == null || secret.isEmpty()) {
            return "";
        }
        if (secret.length() <= 8) {
            return "********";
        }
        String prefix = secret.substring(0, 4);
        String suffix = secret.substring(secret.length() - 4);
        return prefix + "••••••••" + suffix;
    }
}
