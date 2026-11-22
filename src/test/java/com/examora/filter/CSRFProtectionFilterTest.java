package com.examora.filter;

import jakarta.servlet.FilterChain;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.*;

class CSRFProtectionFilterTest {

    private final CSRFProtectionFilter filter = new CSRFProtectionFilter();
    private HttpServletRequest request;
    private HttpServletResponse response;
    private FilterChain chain;
    private HttpSession session;

    @BeforeEach
    void setUp() {
        request = mock(HttpServletRequest.class);
        response = mock(HttpServletResponse.class);
        chain = mock(FilterChain.class);
        session = mock(HttpSession.class);
    }

    private void stubStateChanging(String method, String servletPath) {
        when(request.getMethod()).thenReturn(method);
        when(request.getServletPath()).thenReturn(servletPath);
    }

    @Test
    void allowsReadOnlyMethodsWithoutSession() throws Exception {
        when(request.getMethod()).thenReturn("GET");

        filter.doFilter(request, response, chain);

        verify(chain).doFilter(request, response);
        verifyNoInteractions(session);
    }

    @Test
    void allowsExplicitExemptEndpointEvenWithCookieSession() throws Exception {
        stubStateChanging("POST", "/SumopodWebhookServlet");
        when(request.getSession(false)).thenReturn(session);

        filter.doFilter(request, response, chain);

        verify(chain).doFilter(request, response);
        verifyNoInteractions(session);
    }

    @Test
    void allowsMatchingToken() throws Exception {
        stubStateChanging("POST", "/ExamServlet");
        when(request.getSession(false)).thenReturn(session);
        when(session.getAttribute("csrfToken")).thenReturn("token-123");
        when(request.getHeader("X-CSRF-Token")).thenReturn("token-123");

        filter.doFilter(request, response, chain);

        verify(chain).doFilter(request, response);
    }

    @Test
    void rejectsMismatchedToken() throws Exception {
        stubStateChanging("POST", "/ExamServlet");
        when(request.getSession(false)).thenReturn(session);
        when(session.getAttribute("csrfToken")).thenReturn("token-abc");
        when(request.getParameter("csrfToken")).thenReturn("token-xyz");

        filter.doFilter(request, response, chain);

        verify(chain, never()).doFilter(any(), any());
        verify(response).sendError(HttpServletResponse.SC_FORBIDDEN, "Invalid CSRF token");
    }

    @Test
    void rejectsWhenSessionHasNoToken() throws Exception {
        stubStateChanging("PUT", "/ExamServlet");
        when(request.getSession(false)).thenReturn(session);
        when(session.getAttribute("csrfToken")).thenReturn(null);
        when(request.getHeader("X-CSRF-Token")).thenReturn("anything");

        filter.doFilter(request, response, chain);

        verify(chain, never()).doFilter(any(), any());
        verify(response).sendError(HttpServletResponse.SC_FORBIDDEN, "Invalid CSRF token");
    }
}