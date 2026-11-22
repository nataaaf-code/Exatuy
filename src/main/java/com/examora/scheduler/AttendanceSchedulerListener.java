package com.examora.scheduler;

import com.examora.dao.AttendanceDAO;
import com.examora.dao.QuizDAO;
import com.examora.service.PaymentGatewayService;
import com.examora.service.QuotaService;

import jakarta.servlet.ServletContextEvent;
import jakarta.servlet.ServletContextListener;
import jakarta.servlet.annotation.WebListener;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;
import java.util.logging.Level;
import java.util.logging.Logger;

@WebListener
public class AttendanceSchedulerListener implements ServletContextListener {

    private static final Logger LOGGER = Logger.getLogger(AttendanceSchedulerListener.class.getName());
    private ScheduledExecutorService scheduler;

    /** Waktu tick terakhir — dipakai HealthServlet (#21) untuk memantau penjadwal. */
    private static volatile java.time.Instant lastRunAt;
    private static volatile boolean started;

    public static java.time.Instant getLastRunAt() {
        return lastRunAt;
    }

    public static boolean isStarted() {
        return started;
    }

    @Override
    public void contextInitialized(ServletContextEvent sce) {
        scheduler = Executors.newSingleThreadScheduledExecutor();
        scheduler.scheduleAtFixedRate(() -> {
            try {
                AttendanceDAO dao = new AttendanceDAO();
                int activated = dao.autoActivateScheduledSessions();
                int closed = dao.autoCloseActiveSessions();
                if (activated > 0 || closed > 0) {
                    LOGGER.info("Auto attendance status update: activated=" + activated + ", closed=" + closed);
                }
            } catch (Exception e) {
                LOGGER.log(Level.WARNING, "Attendance auto-status update failed", e);
            }

            try {
                QuizDAO quizDAO = new QuizDAO();
                int published = quizDAO.autoPublishScheduledQuizzes();
                if (published > 0) {
                    LOGGER.info("Auto quiz publish: " + published + " quiz(es) published");
                }
            } catch (Exception e) {
                LOGGER.log(Level.WARNING, "Quiz auto-publish failed", e);
            }

            try {
                // Idempoten: hanya mereset siswa yang periode saldonya belum bulan berjalan (WIB)
                int reset = new QuotaService().resetForCurrentMonth();
                if (reset > 0) {
                    LOGGER.info("Monthly quota reset: " + reset + " student(s)");
                }
            } catch (Exception e) {
                LOGGER.log(Level.WARNING, "Monthly quota reset failed", e);
            }

            try {
                // Tagihan kuota yang lewat batas waktu bayar ditandai gagal
                int expired = new PaymentGatewayService().expireStaleOrders();
                if (expired > 0) {
                    LOGGER.info("Expired quota orders: " + expired);
                }
            } catch (Exception e) {
                LOGGER.log(Level.WARNING, "Quota order expiry failed", e);
            }

            lastRunAt = java.time.Instant.now();
        }, 0, 1, TimeUnit.MINUTES);

        started = true;
        LOGGER.info("AttendanceSchedulerListener started — checking every 1 minute");
    }

    @Override
    public void contextDestroyed(ServletContextEvent sce) {
        if (scheduler != null) {
            scheduler.shutdownNow();
            LOGGER.info("AttendanceSchedulerListener stopped");
        }
    }
}
