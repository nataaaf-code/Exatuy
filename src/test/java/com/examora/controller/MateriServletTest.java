package com.examora.controller;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.*;

class MateriServletTest {
    @Test
    void storedFileNameCannotEscapeMaterialDirectoryOrServeHtml() {
        assertTrue(MateriServlet.isSafeFileName("6f7b35b1-46e9-4568-bd0d-807f2d89109e.pdf"));
        assertTrue(MateriServlet.isSafeFileName("6f7b35b1-46e9-4568-bd0d-807f2d89109e.png"));
        assertFalse(MateriServlet.isSafeFileName("../question.pdf"));
        assertFalse(MateriServlet.isSafeFileName("..\\question.pdf"));
        assertFalse(MateriServlet.isSafeFileName("script.html"));
        assertFalse(MateriServlet.isSafeFileName(null));
    }

    @Test
    void materialUploadOnlyAcceptsSupportedExtensions() {
        assertEquals("png", MateriServlet.fileExtension("diagram.PNG"));
        assertTrue(MateriServlet.isAllowedExtension("png"));
        assertFalse(MateriServlet.isAllowedExtension("php"));
        assertFalse(MateriServlet.isAllowedExtension(""));
    }
}
