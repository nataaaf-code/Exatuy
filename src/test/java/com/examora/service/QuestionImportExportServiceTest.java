package com.examora.service;

import com.examora.dao.QuestionDAO;
import com.examora.model.Question;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

import java.io.ByteArrayInputStream;
import java.nio.charset.StandardCharsets;
import java.sql.SQLException;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

class QuestionImportExportServiceTest {
    private final QuizService quizService = mock(QuizService.class);
    private final QuestionDAO questionDAO = mock(QuestionDAO.class);
    private final QuestionImportExportService service =
            new QuestionImportExportService(quizService, questionDAO);

    private ByteArrayInputStream csv(String body) {
        return new ByteArrayInputStream(body.getBytes(StandardCharsets.UTF_8));
    }

    @Test
    void importWithoutQuizStoresBankQuestionAndCategory() throws Exception {
        when(questionDAO.findCategoryIdByName("Matematika")).thenReturn(7);
        String content = "\uFEFFquestion_text,option_a,option_b,option_c,option_d,correct_answer,category,explanation\n"
                + "Berapa 2+2?,3,4,5,6,B,Matematika,Empat\n";

        QuestionImportExportService.ImportResult result = service.importFromCSV(csv(content), null);

        assertEquals(1, result.getSuccessCount());
        assertFalse(result.hasErrors());
        ArgumentCaptor<Question> saved = ArgumentCaptor.forClass(Question.class);
        verify(questionDAO).create(saved.capture());
        assertNull(saved.getValue().getQuizId());
        assertEquals(7, saved.getValue().getCategoryId());
        assertEquals("Empat", saved.getValue().getExplanation());
        verifyNoInteractions(quizService);
    }

    @Test
    void failedInsertIsNotReportedAsSuccess() throws Exception {
        when(questionDAO.create(any(Question.class))).thenThrow(new SQLException("database unavailable"));
        String content = "question_text,option_a,option_b,option_c,option_d,correct_answer\n"
                + "Berapa 2+2?,3,4,5,6,B\n";

        QuestionImportExportService.ImportResult result = service.importFromCSV(csv(content), null);

        assertEquals(0, result.getSuccessCount());
        assertTrue(result.hasErrors());
    }

    @Test
    void missingRequiredHeaderOrUnknownCategoryDoesNotSaveRows() throws Exception {
        String missing = "question_text,option_a,option_b,option_c,correct_answer\n"
                + "Berapa 2+2?,3,4,5,B\n";
        assertEquals(0, service.importFromCSV(csv(missing), null).getSuccessCount());

        String unknown = "question_text,option_a,option_b,option_c,option_d,correct_answer,category\n"
                + "Berapa 2+2?,3,4,5,6,B,Belum Ada\n";
        when(questionDAO.findCategoryIdByName("Belum Ada")).thenReturn(null);
        QuestionImportExportService.ImportResult result = service.importFromCSV(csv(unknown), null);
        assertEquals(0, result.getSuccessCount());
        assertTrue(result.getErrors().get(0).contains("Kategori belum ada"));
        verify(questionDAO, never()).create(any(Question.class));
    }
}
