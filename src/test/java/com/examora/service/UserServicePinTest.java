package com.examora.service;

import org.junit.jupiter.api.Test;

import java.time.LocalDateTime;

import static org.junit.jupiter.api.Assertions.*;

class UserServicePinTest {

    private static final LocalDateTime NOW = LocalDateTime.of(2026, 11, 23, 8, 0, 0);

    @Test
    void pinMustBeFourToSixDigits() {
        assertTrue(UserService.isValidPin("1234"));
        assertTrue(UserService.isValidPin("123456"));
        assertFalse(UserService.isValidPin("123"));
        assertFalse(UserService.isValidPin("1234567"));
        assertFalse(UserService.isValidPin("12a4"));
        assertFalse(UserService.isValidPin(null));
    }

    @Test
    void newPinMustBeExactlySixDigits() {
        assertTrue(UserService.isValidNewPin("123456"));
        assertFalse(UserService.isValidNewPin("1234"));
        assertFalse(UserService.isValidNewPin("12345"));
        assertFalse(UserService.isValidNewPin("1234567"));
        assertFalse(UserService.isValidNewPin("12345a"));
        assertFalse(UserService.isValidNewPin(null));
    }

    @Test
    void pinLocksAfterFiveRecentFailures() {
        assertFalse(UserService.isPinLocked(4, NOW.minusMinutes(1), NOW));
        assertTrue(UserService.isPinLocked(5, NOW.minusMinutes(1), NOW));
        assertTrue(UserService.isPinLocked(5, NOW.minusMinutes(14), NOW));
    }

    @Test
    void pinLockEndsFifteenMinutesAfterLastFailure() {
        assertFalse(UserService.isPinLocked(5, NOW.minusMinutes(15), NOW));
        assertFalse(UserService.isPinLocked(5, null, NOW));
        assertFalse(UserService.isPinLocked(0, null, NOW));
    }
}
