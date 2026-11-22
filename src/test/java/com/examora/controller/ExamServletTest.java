package com.examora.controller;

import com.examora.model.Question;
import com.google.gson.JsonObject;
import com.google.gson.JsonParser;
import org.junit.jupiter.api.Test;

import java.time.LocalDateTime;

import static org.junit.jupiter.api.Assertions.*;

class ExamServletTest {

    private static final LocalDateTime START = LocalDateTime.of(2026, 11, 23, 8, 0, 0);

    @Test
    void newSessionCostsOnePointForStudents() {
        assertTrue(ExamServlet.shouldChargeQuota(true, false, false, false));
    }

    @Test
    void resumeRetakeAndAdminAreNotCharged() {
        assertFalse(ExamServlet.shouldChargeQuota(true, true, false, false), "melanjutkan sesi berjalan");
        assertFalse(ExamServlet.shouldChargeQuota(true, false, true, false), "kode retake");
        assertFalse(ExamServlet.shouldChargeQuota(true, false, false, true), "retake izin manual");
        assertFalse(ExamServlet.shouldChargeQuota(false, false, false, false), "admin");
    }

    @Test
    void remainingSecondsCountsPauseAndGoesNegativeAfterDeadline() {
        // 30 menit, mulai 08:00, jeda 60 detik -> batas 08:31:00
        assertEquals(60, ExamServlet.remainingSeconds(START, 60, 30, START.plusMinutes(30)));
        assertEquals(0, ExamServlet.remainingSeconds(START, 60, 30, START.plusMinutes(31)));
        assertEquals(-7, ExamServlet.remainingSeconds(START, 60, 30, START.plusMinutes(31).plusSeconds(7)));
        assertEquals(1800, ExamServlet.remainingSeconds(null, null, 30, START));
    }

    @Test
    void lateRequestsAreAcceptedUpToFiveSeconds() {
        assertFalse(ExamServlet.isPastGrace(0));
        assertFalse(ExamServlet.isPastGrace(-5));
        assertTrue(ExamServlet.isPastGrace(-6));
    }

    @Test
    void questionJsonWithImageIsValidAndHidesAnswerKey() {
        Question q = new Question();
        q.setId(7);
        q.setQuestionText("Luas \"persegi\"?\nSisi 4 cm");
        q.setImagePath("uploads/questions/a b.png");
        q.setOptionA("8");
        q.setOptionB("16");
        q.setOptionC("12");
        q.setOptionD("4");
        q.setCorrectAnswer("B");

        JsonObject json = JsonParser.parseString(ExamServlet.buildQuestionJson(q, 2, 5, "A", 90)).getAsJsonObject();

        assertTrue(json.get("success").getAsBoolean());
        assertEquals(7, json.get("questionId").getAsInt());
        assertEquals(2, json.get("questionNumber").getAsInt());
        assertEquals(5, json.get("totalQuestions").getAsInt());
        assertEquals("Luas \"persegi\"?\nSisi 4 cm", json.get("questionText").getAsString());
        assertEquals("uploads/questions/a b.png", json.get("imagePath").getAsString());
        assertEquals("A", json.get("savedAnswer").getAsString());
        assertEquals(90, json.get("remainingTime").getAsInt());
        assertFalse(json.has("correctAnswer"));
        assertFalse(json.toString().contains("\"B\""));
    }

    @Test
    void questionJsonOmitsImageAndSavedAnswerWhenAbsent() {
        Question q = new Question();
        q.setId(1);
        q.setQuestionText("1 + 1 = ?");
        q.setOptionA("1");
        q.setOptionB("2");
        q.setOptionC("3");
        q.setOptionD("4");

        JsonObject json = JsonParser.parseString(ExamServlet.buildQuestionJson(q, 1, 1, null, 10)).getAsJsonObject();

        assertFalse(json.has("imagePath"));
        assertFalse(json.has("savedAnswer"));
    }
}
