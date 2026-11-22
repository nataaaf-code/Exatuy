<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%@ page import="com.examora.model.User" %>
<%@ page import="com.examora.model.CashInTransaction" %>
<%@ page import="com.examora.dao.CashInTransactionDAO.StatusSummary" %>
<%@ page import="com.examora.util.ValidationUtil" %>
<%@ page import="java.util.List" %>
<%@ page import="java.net.URLEncoder" %>
<%@ page import="java.nio.charset.StandardCharsets" %>
<%!
    private String esc(String s) {
        return ValidationUtil.sanitizeHtml(s != null ? s : "");
    }
    private String urlEnc(String s) {
        if (s == null || s.isEmpty()) return "";
        return URLEncoder.encode(s, StandardCharsets.UTF_8);
    }
%>
<%
    User currentUser = (User) session.getAttribute("user");
    if (currentUser == null || (!currentUser.isAdmin() && !"owner".equals(currentUser.getRole()))) {
        response.sendRedirect("../LoginServlet");
        return;
    }

    StatusSummary summary = (StatusSummary) request.getAttribute("summary");
    if (summary == null) summary = new StatusSummary();
    @SuppressWarnings("unchecked")
    List<CashInTransaction> transactions = (List<CashInTransaction>) request.getAttribute("transactions");
    if (transactions == null) transactions = java.util.Collections.emptyList();

    String selectedStatus = (String) request.getAttribute("selectedStatus");
    String selectedStartDate = (String) request.getAttribute("selectedStartDate");
    String selectedEndDate = (String) request.getAttribute("selectedEndDate");
    String selectedMonth = (String) request.getAttribute("selectedMonth");
    String searchQuery = (String) request.getAttribute("searchQuery");

    if (selectedStatus == null) selectedStatus = "";
    if (selectedStartDate == null) selectedStartDate = "";
    if (selectedEndDate == null) selectedEndDate = "";
    if (selectedMonth == null) selectedMonth = "";
    if (searchQuery == null) searchQuery = "";

    boolean hasFilter = !selectedStatus.isEmpty() || !selectedStartDate.isEmpty()
            || !selectedEndDate.isEmpty() || !selectedMonth.isEmpty() || !searchQuery.isEmpty();

    String exportUrl = request.getContextPath() + "/CashInReportServlet?action=export"
            + "&status=" + urlEnc(selectedStatus)
            + "&startDate=" + urlEnc(selectedStartDate)
            + "&endDate=" + urlEnc(selectedEndDate)
            + "&month=" + urlEnc(selectedMonth)
            + "&search=" + urlEnc(searchQuery);
%>
<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Laporan Kas Masuk - Exatuy</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.2/dist/css/bootstrap.min.css" rel="stylesheet">
    <link href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.1/font/bootstrap-icons.css" rel="stylesheet">
    <link href="<%= request.getContextPath() %>/assets/css/style.css" rel="stylesheet">
    <link href="<%= request.getContextPath() %>/assets/css/handdrawn.css" rel="stylesheet">
    <link rel="icon" type="image/svg+xml" href="<%= request.getContextPath() %>/assets/img/favicon.svg?v=4">
    <style>
        .cashin-stat-card {
            border-radius: 14px;
            transition: transform 0.2s ease, box-shadow 0.2s ease;
            cursor: pointer;
        }
        .cashin-stat-card .stat-amount {
            font-size: 1.55rem;
            font-weight: 800;
            line-height: 1.2;
        }
        .cashin-stat-card.card-completed {
            border-left: 5px solid #2ecc71 !important;
        }
        .cashin-stat-card.card-pending {
            border-left: 5px solid #f59e0b !important;
        }
        .cashin-stat-card.card-failed {
            border-left: 5px solid #e74c3c !important;
        }
        .cashin-icon-box {
            width: 48px;
            height: 48px;
            border-radius: 12px;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 1.4rem;
            flex-shrink: 0;
        }
        .order-code {
            font-family: 'Courier New', monospace;
            font-weight: 700;
            font-size: 0.85rem;
        }
        @media (max-width: 767.98px) {
            .cashin-stat-card .stat-amount { font-size: 1.25rem; }
        }
    </style>
</head>
<body>
    <%@ include file="sidebar.jsp" %>

    <div class="main-content">
        <!-- Page Header -->
        <div class="d-flex justify-content-between align-items-start flex-wrap gap-3 mb-4">
            <div>
                <h1 class="h3 mb-1 fw-bold text-primary">
                    <i class="bi bi-cash-coin me-2"></i>Laporan Kas Masuk
                </h1>
                <nav aria-label="breadcrumb">
                    <ol class="breadcrumb mb-0">
                        <li class="breadcrumb-item"><a href="<%= request.getContextPath() %>/AdminServlet?action=dashboard">Dashboard</a></li>
                        <li class="breadcrumb-item active">Laporan Kas Masuk</li>
                    </ol>
                </nav>
            </div>
            <div class="d-flex flex-wrap gap-2">
                <a href="<%= request.getContextPath() %>/PaymentSettingsServlet" class="btn btn-outline-primary btn-sm">
                    <i class="bi bi-credit-card-2-front me-1"></i>Pengaturan Sumopod
                </a>
                <a href="<%= exportUrl %>" class="btn btn-success btn-sm">
                    <i class="bi bi-filetype-csv me-1"></i>Export CSV
                </a>
            </div>
        </div>

        <!-- 3 Kartu Ringkasan Status Pembayaran (FR-008) -->
        <div class="row g-3 mb-4">
            <!-- Berhasil (completed) -->
            <div class="col-md-4">
                <div class="card cashin-stat-card card-completed h-100" onclick="quickFilterStatus('completed')" title="Klik untuk filter transaksi Berhasil">
                    <div class="card-body d-flex align-items-center justify-content-between gap-3">
                        <div>
                            <div class="text-muted small fw-bold text-uppercase mb-1">
                                <i class="bi bi-check-circle-fill text-success me-1"></i>Kas Masuk Berhasil
                            </div>
                            <div class="stat-amount text-success">
                                Rp <%= String.format("%,.0f", summary.getCompletedAmount()) %>
                            </div>
                            <div class="small text-muted mt-1">
                                <strong><%= summary.getCompletedCount() %></strong> transaksi berhasil
                                <span class="badge bg-success bg-opacity-10 text-success ms-1">completed</span>
                            </div>
                        </div>
                        <div class="cashin-icon-box bg-success bg-opacity-10 text-success">
                            <i class="bi bi-wallet-fill"></i>
                        </div>
                    </div>
                </div>
            </div>

            <!-- Pending (pending) -->
            <div class="col-md-4">
                <div class="card cashin-stat-card card-pending h-100" onclick="quickFilterStatus('pending')" title="Klik untuk filter transaksi Pending">
                    <div class="card-body d-flex align-items-center justify-content-between gap-3">
                        <div>
                            <div class="text-muted small fw-bold text-uppercase mb-1">
                                <i class="bi bi-hourglass-split text-warning me-1"></i>Tagihan Pending
                            </div>
                            <div class="stat-amount text-warning">
                                Rp <%= String.format("%,.0f", summary.getPendingAmount()) %>
                            </div>
                            <div class="small text-muted mt-1">
                                <strong><%= summary.getPendingCount() %></strong> transaksi menunggu
                                <span class="badge bg-warning bg-opacity-10 text-dark ms-1">pending</span>
                            </div>
                        </div>
                        <div class="cashin-icon-box bg-warning bg-opacity-10 text-warning">
                            <i class="bi bi-clock-history"></i>
                        </div>
                    </div>
                </div>
            </div>

            <!-- Gagal (failed) -->
            <div class="col-md-4">
                <div class="card cashin-stat-card card-failed h-100" onclick="quickFilterStatus('failed')" title="Klik untuk filter transaksi Gagal">
                    <div class="card-body d-flex align-items-center justify-content-between gap-3">
                        <div>
                            <div class="text-muted small fw-bold text-uppercase mb-1">
                                <i class="bi bi-x-circle-fill text-danger me-1"></i>Transaksi Gagal
                            </div>
                            <div class="stat-amount text-danger">
                                Rp <%= String.format("%,.0f", summary.getFailedAmount()) %>
                            </div>
                            <div class="small text-muted mt-1">
                                <strong><%= summary.getFailedCount() %></strong> transaksi gagal/kedaluwarsa
                                <span class="badge bg-danger bg-opacity-10 text-danger ms-1">failed</span>
                            </div>
                        </div>
                        <div class="cashin-icon-box bg-danger bg-opacity-10 text-danger">
                            <i class="bi bi-exclamation-octagon-fill"></i>
                        </div>
                    </div>
                </div>
            </div>
        </div>

        <div class="alert alert-info py-2 px-3 mb-4 small d-flex align-items-center gap-2">
            <i class="bi bi-info-circle-fill flex-shrink-0"></i>
            <span>Hanya transaksi berstatus <strong>Berhasil (completed)</strong> yang dihitung sebagai kas masuk riil Bimbel Mentari.</span>
        </div>

        <!-- Filter & Pencarian -->
        <div class="card shadow-sm mb-4">
            <div class="card-header bg-light d-flex justify-content-between align-items-center py-2">
                <span>
                    <i class="bi bi-funnel me-1"></i><strong>Filter Laporan</strong>
                    <% if (hasFilter) { %><span class="badge bg-primary ms-2">Aktif</span><% } %>
                </span>
                <span class="small text-muted">Menampilkan <%= transactions.size() %> transaksi</span>
            </div>
            <div class="card-body">
                <form method="get" action="<%= request.getContextPath() %>/CashInReportServlet" id="cashInFilterForm">
                    <div class="row g-3 align-items-end">
                        <div class="col-12 col-sm-6 col-lg-2">
                            <label class="form-label small fw-semibold mb-1">Status Pembayaran</label>
                            <select name="status" id="statusFilter" class="form-select form-select-sm">
                                <option value="">Semua Status</option>
                                <option value="completed" <%= "completed".equalsIgnoreCase(selectedStatus) ? "selected" : "" %>>Berhasil (Completed)</option>
                                <option value="pending" <%= "pending".equalsIgnoreCase(selectedStatus) ? "selected" : "" %>>Pending</option>
                                <option value="failed" <%= "failed".equalsIgnoreCase(selectedStatus) ? "selected" : "" %>>Gagal (Failed)</option>
                            </select>
                        </div>
                        <div class="col-12 col-sm-6 col-lg-2">
                            <label class="form-label small fw-semibold mb-1">Periode Bulan</label>
                            <input type="month" name="month" id="monthFilter" class="form-control form-control-sm"
                                   value="<%= esc(selectedMonth) %>" onchange="clearDateRangeIfMonth()">
                        </div>
                        <div class="col-6 col-lg-2">
                            <label class="form-label small fw-semibold mb-1">Dari Tanggal</label>
                            <input type="date" name="startDate" id="startDateFilter" class="form-control form-control-sm"
                                   value="<%= esc(selectedStartDate) %>" onchange="clearMonthIfDateRange()">
                        </div>
                        <div class="col-6 col-lg-2">
                            <label class="form-label small fw-semibold mb-1">Sampai Tanggal</label>
                            <input type="date" name="endDate" id="endDateFilter" class="form-control form-control-sm"
                                   value="<%= esc(selectedEndDate) %>" onchange="clearMonthIfDateRange()">
                        </div>
                        <div class="col-12 col-lg-4">
                            <label class="form-label small fw-semibold mb-1">Cari Siswa / No. Invoice</label>
                            <div class="input-group input-group-sm">
                                <span class="input-group-text bg-white"><i class="bi bi-search"></i></span>
                                <input type="text" name="search" class="form-control"
                                       placeholder="Nama siswa, email, atau INV-..."
                                       value="<%= esc(searchQuery) %>">
                                <button type="submit" class="btn btn-primary">
                                    <i class="bi bi-funnel-fill me-1"></i>Filter
                                </button>
                                <% if (hasFilter) { %>
                                <a href="<%= request.getContextPath() %>/CashInReportServlet" class="btn btn-outline-secondary" title="Reset Filter">
                                    <i class="bi bi-arrow-counterclockwise"></i>
                                </a>
                                <% } %>
                            </div>
                        </div>
                    </div>
                </form>
            </div>
        </div>

        <!-- Tabel Riwayat Transaksi -->
        <div class="card shadow-sm">
            <div class="card-header bg-light d-flex justify-content-between align-items-center flex-wrap gap-2">
                <span><i class="bi bi-receipt-cutoff me-2"></i><strong>Riwayat Transaksi Pembayaran Kuota</strong></span>
                <span class="small text-muted">Total dalam periode: <%= summary.getTotalCount() %> transaksi</span>
            </div>
            <div class="card-body p-0">
                <% if (transactions.isEmpty()) { %>
                <div class="text-center py-5 px-3">
                    <i class="bi bi-receipt display-4 text-muted opacity-50 d-block mb-3"></i>
                    <h5 class="text-muted mb-1">Belum ada transaksi pembayaran</h5>
                    <p class="text-muted small mb-3">
                        <% if (hasFilter) { %>
                            Tidak ditemukan transaksi yang cocok dengan filter yang dipilih.
                        <% } else { %>
                            Transaksi pembelian kuota siswa melalui Sumopod akan tercatat otomatis di sini.
                        <% } %>
                    </p>
                    <% if (hasFilter) { %>
                    <a href="<%= request.getContextPath() %>/CashInReportServlet" class="btn btn-outline-primary btn-sm">
                        <i class="bi bi-arrow-counterclockwise me-1"></i>Reset Filter
                    </a>
                    <% } %>
                </div>
                <% } else { %>
                <div class="table-responsive">
                    <table class="table table-hover align-middle mb-0">
                        <thead>
                            <tr>
                                <th>#</th>
                                <th>No. Invoice / Order ID</th>
                                <th>Siswa</th>
                                <th class="text-center">Kuota</th>
                                <th class="text-end">Nominal</th>
                                <th class="text-center">Metode</th>
                                <th class="text-center">Status</th>
                                <th>Tanggal Dibuat</th>
                                <th>Waktu Bayar</th>
                            </tr>
                        </thead>
                        <tbody>
                            <% int rowNo = 1;
                               for (CashInTransaction tx : transactions) { %>
                            <tr>
                                <td class="text-muted small"><%= rowNo++ %></td>
                                <td>
                                    <div class="order-code text-primary"><%= esc(tx.getOrderId()) %></div>
                                    <% if (tx.getSumopodPaymentId() != null && !tx.getSumopodPaymentId().isEmpty()) { %>
                                    <div class="text-muted" style="font-size:0.75rem;">ID: <%= esc(tx.getSumopodPaymentId()) %></div>
                                    <% } %>
                                </td>
                                <td>
                                    <div class="fw-semibold"><%= esc(tx.getStudentName() != null ? tx.getStudentName() : "Siswa #" + tx.getStudentId()) %></div>
                                    <div class="text-muted small"><%= esc(tx.getStudentEmail()) %></div>
                                </td>
                                <td class="text-center">
                                    <span class="badge bg-primary bg-opacity-10 text-primary">
                                        +<%= tx.getPointsPurchased() %> Poin
                                    </span>
                                </td>
                                <td class="text-end fw-bold">
                                    Rp <%= String.format("%,.0f", tx.getAmount()) %>
                                </td>
                                <td class="text-center small">
                                    <%= esc(tx.getPaymentMethod() != null ? tx.getPaymentMethod() : "QRIS") %>
                                </td>
                                <td class="text-center">
                                    <span class="badge <%= tx.getStatusBadgeClass() %>">
                                        <%= tx.getStatusLabel() %>
                                    </span>
                                </td>
                                <td class="small text-muted"><%= tx.getFormattedCreatedAt() %></td>
                                <td class="small text-muted"><%= tx.getFormattedPaidAt() %></td>
                            </tr>
                            <% } %>
                        </tbody>
                    </table>
                </div>
                <% } %>
            </div>
        </div>
    </div>

    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.2/dist/js/bootstrap.bundle.min.js"></script>
    <script>
        function quickFilterStatus(status) {
            const sel = document.getElementById('statusFilter');
            sel.value = (sel.value === status) ? '' : status;
            document.getElementById('cashInFilterForm').submit();
        }
        function clearDateRangeIfMonth() {
            if (document.getElementById('monthFilter').value) {
                document.getElementById('startDateFilter').value = '';
                document.getElementById('endDateFilter').value = '';
            }
        }
        function clearMonthIfDateRange() {
            if (document.getElementById('startDateFilter').value || document.getElementById('endDateFilter').value) {
                document.getElementById('monthFilter').value = '';
            }
        }
    </script>
</body>
</html>
