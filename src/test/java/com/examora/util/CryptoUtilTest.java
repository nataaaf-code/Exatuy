package com.examora.util;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.*;

class CryptoUtilTest {

    @Test
    void keyComesFromEnvironmentThenSystemProperty() {
        assertEquals("kunci-env", CryptoUtil.resolveSecret("kunci-env", "kunci-prop", null));
        assertEquals("kunci-prop", CryptoUtil.resolveSecret(null, "kunci-prop", null));
        assertEquals("kunci-prop", CryptoUtil.resolveSecret("  ", "kunci-prop", "false"));
    }

    @Test
    void missingKeyIsRejectedUnlessDefaultIsAllowed() {
        assertThrows(IllegalStateException.class, () -> CryptoUtil.resolveSecret(null, null, null));
        assertThrows(IllegalStateException.class, () -> CryptoUtil.resolveSecret("", " ", "false"));
        assertNotNull(CryptoUtil.resolveSecret(null, null, "true"));
        assertNotNull(CryptoUtil.resolveSecret(null, null, "TRUE"));
    }

    @Test
    void encryptedValueCanBeDecryptedWithConfiguredKey() throws Exception {
        String previous = System.getProperty("exatuy.encryption.key");
        System.setProperty("exatuy.encryption.key", "kunci-uji-unit");
        try {
            String first = CryptoUtil.encrypt("sk_test_rahasia");
            String second = CryptoUtil.encrypt("sk_test_rahasia");

            assertNotEquals("sk_test_rahasia", first);
            assertNotEquals(first, second, "IV acak membuat hasil enkripsi selalu berbeda");
            assertEquals("sk_test_rahasia", CryptoUtil.decrypt(first));
            assertEquals("sk_test_rahasia", CryptoUtil.decrypt(second));
        } finally {
            if (previous == null) {
                System.clearProperty("exatuy.encryption.key");
            } else {
                System.setProperty("exatuy.encryption.key", previous);
            }
        }
    }
}
