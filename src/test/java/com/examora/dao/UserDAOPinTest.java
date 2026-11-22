package com.examora.dao;

import org.junit.jupiter.api.Test;

import java.time.LocalDateTime;

import static org.junit.jupiter.api.Assertions.*;

class UserDAOPinTest {

    private static final LocalDateTime NOW = LocalDateTime.of(2026, 11, 23, 8, 0, 0);

    @Test
    void failuresWithinWindowAreCountedOneByOne() {
        assertEquals(1, UserDAO.nextPinFailureCount(0, null, NOW, 15));
        assertEquals(5, UserDAO.nextPinFailureCount(4, NOW.minusMinutes(2), NOW, 15));
    }

    @Test
    void countingRestartsWhenLastFailureIsOutsideWindow() {
        assertEquals(1, UserDAO.nextPinFailureCount(4, NOW.minusMinutes(15), NOW, 15));
        assertEquals(1, UserDAO.nextPinFailureCount(5, NOW.minusHours(3), NOW, 15));
    }
}
