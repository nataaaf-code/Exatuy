package com.examora.filter;

import jakarta.servlet.*;
import jakarta.servlet.annotation.WebFilter;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.Arrays;
import java.util.HashSet;
import java.util.Set;
import java.util.logging.Level;
import java.util.logging.Logger;

/**
 * CSRF Protection Filter - Validates CSRF tokens for state-changing requests.
 *
 * Endpoint machine-to-machine (mis. webhook pembayaran) dikecualikan secara
 * eksplisit, bukan sekadar lolos karena tidak membawa cookie session. Endpoint
 * itu wajib diamankan oleh token/signature milik gateway (mis. X-Webhook-Token).
 */
@WebFilter("/*")
public class CSRFProtectionFilter implements Filter {

    private static final Logger logger = Logger.getLogger(CSRFProtectionFilter.class.getName());
    private static final String CSRF_TOKEN_PARAM = "csrfToken";
    private static final String CSRF_TOKEN_HEADER = "X-CSRF-Token";

    private static final Set<String> CSRF_EXEMPT_PATHS = new HashSet<>(Arrays.asList(
            "/LoginServlet",
            "/RegisterServlet",
            "/SumopodWebhookServlet",
            "/api/ai/webhook/messaging"
    ));

    @Override
    public void init(FilterConfig filterConfig) throws ServletException {
        // Initialization
    }

    @Override
    public void doFilter(ServletRequest request, ServletResponse response, FilterChain chain)
            throws IOException, ServletException {

        HttpServletRequest httpRequest = (HttpServletRequest) request;
        HttpServletResponse httpResponse = (HttpServletResponse) response;

        String method = httpRequest.getMethod();

        // Only check CSRF for state-changing methods (POST, PUT, DELETE, PATCH)
        if ("POST".equalsIgnoreCase(method) || "PUT".equalsIgnoreCase(method) ||
            "DELETE".equalsIgnoreCase(method) || "PATCH".equalsIgnoreCase(method)) {

            // Skip CSRF only for explicitly allow-listed machine-to-machine endpoints.
            // They are authenticated by their own gateway token/signature, not CSRF.
            String servletPath = httpRequest.getServletPath();
            if (servletPath != null && CSRF_EXEMPT_PATHS.contains(servletPath)) {
                chain.doFilter(request, response);
                return;
            }

            HttpSession session = httpRequest.getSession(false);

            if (session != null) {
                String sessionToken = (String) session.getAttribute("csrfToken");
                String requestToken = getCSRFToken(httpRequest);

                if (sessionToken == null || requestToken == null
                        || !MessageDigest.isEqual(
                                sessionToken.getBytes(StandardCharsets.UTF_8),
                                requestToken.getBytes(StandardCharsets.UTF_8))) {
                    logger.log(Level.WARNING, "CSRF validation failed - Path: " + servletPath);

                    // Check if this is an AJAX request expecting JSON
                    boolean isAjax = "XMLHttpRequest".equals(httpRequest.getHeader("X-Requested-With")) ||
                                     "true".equals(httpRequest.getParameter("ajax"));
                    if (isAjax) {
                        httpResponse.setContentType("application/json");
                        httpResponse.setCharacterEncoding("UTF-8");
                        httpResponse.setStatus(HttpServletResponse.SC_FORBIDDEN);
                        httpResponse.getWriter().write("{\"success\":false,\"error\":\"Invalid CSRF token. Please refresh the page.\"}");
                    } else {
                        httpResponse.sendError(HttpServletResponse.SC_FORBIDDEN, "Invalid CSRF token");
                    }
                    return;
                }
            }
        }

        chain.doFilter(request, response);
    }

    private String getCSRFToken(HttpServletRequest request) {
        // Check header first (for AJAX requests)
        String token = request.getHeader(CSRF_TOKEN_HEADER);
        if (token != null && !token.isEmpty()) {
            return token;
        }

        // Then check parameter
        token = request.getParameter(CSRF_TOKEN_PARAM);
        return token;
    }

    @Override
    public void destroy() {
        // Cleanup
    }
}
