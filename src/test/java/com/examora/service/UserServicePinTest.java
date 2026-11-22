package com.examora.service;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.*;

class UserServicePinTest {

    @Test
    void pinMustBeFourToSixDigits() {
        assertTrue(UserService.isValidPin("1234"));
        assertTrue(UserService.isValidPin("123456"));
        assertFalse(UserService.isValidPin("123"));
        assertFalse(UserService.isValidPin("1234567"));
        assertFalse(UserService.isValidPin("12a4"));
        assertFalse(UserService.isValidPin(null));
    }
}
