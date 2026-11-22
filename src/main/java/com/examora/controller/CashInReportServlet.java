package com.examora.controller;

import com.examora.dao.CashInTransactionDAO;
import com.examora.dao.CashInTransactionDAO.StatusSummary;
import com.examora.model.CashInTransaction;
import com.examora.model.User;

import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;

import java.io.IOException;
import java.io.PrintWriter;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.List;

/**
 * CashInReportServlet - Laporan Kas Masuk (FR-008 / Gap Analysis P1 #16)
 * Displays 3 summary cards (Berhasil / Pending / Gagal), filtered transaction table,
 * and CSV export respecting active filters.
 */
@WebServlet("/CashInReportServlet")
public class CashInReportServlet extends HttpServlet {
    private CashInTransactionDAO transactionDAO;

    @Override
    public void init() throws ServletException {
        transactionDAO = new CashInTransactionDAO();
    }

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        HttpSession session = request.getSession(false);
        User currentUser = session != null ? (User) session.getAttribute("user") : null;

        if (currentUser == null || (!currentUser.isAdmin() && !"owner".equals(currentUser.getRole()))) {
            response.sendRedirect(request.getContextPath() + "/LoginServlet");
            return;
        }

        String action = request.getParameter("action");
        String status = trimParam(request.getParameter("status"));
        String startDate = trimParam(request.getParameter("startDate"));
        String endDate = trimParam(request.getParameter("endDate"));
        String month = trimParam(request.getParameter("month"));
        String search = trimParam(request.getParameter("search"));

        // If month is set, clear custom date range to avoid conflicting filters
        if (!month.isEmpty()) {
            startDate = "";
            endDate = "";
        }

        if ("export".equalsIgnoreCase(action)) {
            List<CashInTransaction> transactions = transactionDAO.findFiltered(status, startDate, endDate, month, search);
            exportToCSV(response, transactions);
            return;
        }

        StatusSummary summary = transactionDAO.getSummary(startDate, endDate, month, search);
        List<CashInTransaction> transactions = transactionDAO.findFiltered(status, startDate, endDate, month, search);

        request.setAttribute("summary", summary);
        request.setAttribute("transactions", transactions);
        request.setAttribute("selectedStatus", status);
        request.setAttribute("selectedStartDate", startDate);
        request.setAttribute("selectedEndDate", endDate);
        request.setAttribute("selectedMonth", month);
        request.setAttribute("searchQuery", search);

        request.getRequestDispatcher("/admin/cash-in-report.jsp").forward(request, response);
    }

    private void exportToCSV(HttpServletResponse response, List<CashInTransaction> transactions) throws IOException {
        String dateStamp = new SimpleDateFormat("yyyyMMdd_HHmm").format(new Date());
        response.setContentType("text/csv; charset=UTF-8");
        response.setHeader("Content-Disposition", "attachment; filename=\"laporan_kas_masuk_" + dateStamp + ".csv\"");

        PrintWriter writer = response.getWriter();
        writer.write('\ufeff'); // UTF-8 BOM for Excel

        writer.println("No,Order ID,Nama Siswa,Email,Kelas/Tag,Poin Dibeli,Nominal (IDR),Status,Metode,Sumopod Payment ID,Tanggal Dibuat,Tanggal Dibayar");

        int no = 1;
        for (CashInTransaction tx : transactions) {
            StringBuilder line = new StringBuilder();
            line.append(no++).append(",");
            line.append(escapeCSV(tx.getOrderId())).append(",");
            line.append(escapeCSV(tx.getStudentName())).append(",");
            line.append(escapeCSV(tx.getStudentEmail())).append(",");
            line.append(escapeCSV(tx.getStudentTag())).append(",");
            line.append(tx.getPointsPurchased()).append(",");
            line.append(tx.getAmount().toPlainString()).append(",");
            line.append(escapeCSV(tx.getStatusLabel())).append(",");
            line.append(escapeCSV(tx.getPaymentMethod())).append(",");
            line.append(escapeCSV(tx.getSumopodPaymentId())).append(",");
            line.append(escapeCSV(tx.getFormattedCreatedAt())).append(",");
            line.append(escapeCSV(tx.getFormattedPaidAt()));
            writer.println(line.toString());
        }

        writer.flush();
        writer.close();
    }

    private String trimParam(String val) {
        return val == null ? "" : val.trim();
    }

    private String escapeCSV(String value) {
        if (value == null) return "";
        if (value.contains(",") || value.contains("\"") || value.contains("\n") || value.contains("\r")) {
            return "\"" + value.replace("\"", "\"\"") + "\"";
        }
        return value;
    }
}
