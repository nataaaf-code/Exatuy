<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%@ page import="com.examora.model.User" %>
<%@ page import="com.examora.model.Quiz" %>
<%@ page import="com.examora.model.Submission" %>
<%@ page import="com.examora.util.ValidationUtil" %>
<%@ page import="java.util.List" %>
<%@ page import="java.util.Map" %>
<%
    User currentUser = (User) session.getAttribute("user");
    if (currentUser == null) {
        response.sendRedirect("../LoginServlet");
        return;
    }
    Quiz quiz = (Quiz) request.getAttribute("quiz");
    Submission submission = (Submission) request.getAttribute("submission");
    Integer totalQuestionsAttr = (Integer) request.getAttribute("totalQuestions");
    Integer remainingTimeSeconds = (Integer) request.getAttribute("remainingTimeSeconds");

    if (quiz == null || submission == null) {
        response.sendRedirect("../ExamServlet?action=list");
        return;
    }

    int totalQuestions = totalQuestionsAttr != null ? totalQuestionsAttr : 0;

    // Use server-calculated remaining time, fallback to full duration
    int timeRemaining = (remainingTimeSeconds != null && remainingTimeSeconds > 0)
        ? remainingTimeSeconds
        : quiz.getDuration() * 60;
%>
<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Ujian - Exatuy</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
    <link href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.10.0/font/bootstrap-icons.css" rel="stylesheet">
    <link href="../assets/css/style.css" rel="stylesheet">
    <link rel="icon" type="image/svg+xml" type="image/svg+xml" href="../assets/img/favicon.svg?v=3">
    <style>
        @import url('https://fonts.googleapis.com/css2?family=DM+Sans:ital,opsz,wght@0,9..40,200;0,9..40,400;0,9..40,500;0,9..40,600;0,9..40,700;0,9..40,900;1,9..40,400&family=JetBrains+Mono:wght@400;600;700&display=swap');

        :root {
            --primary: #4361ee;
            --primary-soft: #eef1ff;
            --primary-glow: rgba(67, 97, 238, 0.25);
            --success: #06d6a0;
            --success-soft: #ecfdf5;
            --warning: #f59e0b;
            --danger: #ef476f;
            --bg: #f0f2f8;
            --surface: #ffffff;
            --surface-raised: #fafbfe;
            --border: #e0e4ed;
            --border-light: #eef0f5;
            --ink: #1a1d2e;
            --ink-muted: #6b7194;
            --ink-faint: #9ca3bf;
            --mono: 'JetBrains Mono', monospace;
            --sans: 'DM Sans', system-ui, sans-serif;
            --radius: 14px;
            --radius-sm: 10px;
            --shadow-sm: 0 1px 2px rgba(26,29,46,0.04);
            --shadow-md: 0 4px 16px rgba(26,29,46,0.07);
            --shadow-lg: 0 8px 32px rgba(26,29,46,0.10);
        }

        *, *::before, *::after { margin: 0; padding: 0; box-sizing: border-box; }

        body {
            background: var(--bg);
            font-family: var(--sans);
            color: var(--ink);
            line-height: 1.6;
            -webkit-font-smoothing: antialiased;
            -moz-osx-font-smoothing: grayscale;
            -webkit-user-select: none;
            -moz-user-select: none;
            -ms-user-select: none;
            user-select: none;
        }

        /* Print protection - show watermark only when printing */
        @media print {
            body * { display: none !important; }
            body::after {
                content: 'EXATUY - Cetak tidak diizinkan selama ujian';
                display: block !important;
                font-size: 48px;
                text-align: center;
                padding: 200px 50px;
                color: #dc3545;
            }
        }

        /* ==================== HEADER ==================== */
        .exam-header {
            position: fixed;
            top: 0; left: 0; right: 0;
            z-index: 1000;
            background: var(--surface);
            border-bottom: 1px solid var(--border);
            box-shadow: var(--shadow-sm);
        }

        .header-main { padding: 0.65rem 0; }

        .header-main .container {
            display: flex;
            align-items: center;
            justify-content: space-between;
            gap: 0.75rem;
        }

        .quiz-title {
            font-size: 0.95rem;
            font-weight: 700;
            color: var(--ink);
            margin: 0;
            display: flex;
            align-items: center;
            gap: 0.6rem;
            letter-spacing: -0.01em;
        }

        .quiz-title i {
            color: var(--primary);
            font-size: 1.15rem;
        }

        /* Timer */
        .exam-timer {
            font-family: var(--mono);
            font-size: 1.05rem;
            font-weight: 700;
            letter-spacing: 0.04em;
            background: var(--surface-raised);
            border: 1.5px solid var(--border);
            padding: 0.4rem 1rem;
            border-radius: 50px;
            display: flex;
            align-items: center;
            gap: 0.45rem;
            color: var(--ink);
            transition: all 0.4s ease;
        }

        .exam-timer i { font-size: 0.95rem; color: var(--primary); }

        .exam-timer.warning {
            background: #fef3c7;
            border-color: #fbbf24;
            color: #92400e;
            animation: timerPulse 1.5s ease-in-out infinite;
        }

        .exam-timer.warning i { color: #d97706; }

        @keyframes timerPulse {
            0%, 100% { box-shadow: 0 0 0 0 rgba(245, 158, 11, 0); }
            50% { box-shadow: 0 0 0 6px rgba(245, 158, 11, 0.15); }
        }

        .header-actions {
            display: flex;
            align-items: center;
            gap: 0.6rem;
        }

        .question-count-badge {
            background: var(--primary-soft);
            color: var(--primary);
            padding: 0.3rem 0.7rem;
            border-radius: 50px;
            font-size: 0.8rem;
            font-weight: 600;
            letter-spacing: -0.01em;
        }

        .submit-btn {
            background: var(--ink);
            color: white;
            border: none;
            padding: 0.45rem 1.1rem;
            border-radius: 50px;
            font-family: var(--sans);
            font-weight: 600;
            font-size: 0.85rem;
            display: flex;
            align-items: center;
            gap: 0.4rem;
            cursor: pointer;
            transition: all 0.25s ease;
            letter-spacing: -0.01em;
        }

        .submit-btn:hover {
            background: var(--primary);
            transform: translateY(-1px);
            box-shadow: 0 4px 12px var(--primary-glow);
        }

        /* Progress Bar */
        .header-progress {
            background: var(--surface);
            padding: 0.55rem 0;
            border-top: 1px solid var(--border-light);
        }

        .header-progress .container {
            display: flex;
            align-items: center;
            gap: 0.85rem;
        }

        .progress-container { flex: 1; }

        .progress {
            height: 5px;
            background: var(--border-light);
            border-radius: 50px;
            overflow: hidden;
        }

        .progress-bar {
            height: 100%;
            background: var(--primary);
            border-radius: 50px;
            transition: width 0.5s cubic-bezier(0.4, 0, 0.2, 1);
        }

        .progress-text {
            color: var(--ink-muted);
            font-size: 0.8rem;
            font-weight: 600;
            white-space: nowrap;
            letter-spacing: -0.01em;
        }

        /* ==================== MAIN CONTENT ==================== */
        .exam-content {
            margin-top: 120px;
            margin-bottom: 96px;
            padding: 1.5rem;
            max-width: 780px;
            margin-left: auto;
            margin-right: auto;
        }

        /* ==================== QUESTION CARD ==================== */
        .question-card {
            background: var(--surface);
            border: 1px solid var(--border);
            border-radius: var(--radius);
            overflow: hidden;
            box-shadow: var(--shadow-md);
            animation: cardIn 0.35s cubic-bezier(0.16, 1, 0.3, 1) both;
        }

        @keyframes cardIn {
            from { opacity: 0; transform: translateY(12px) scale(0.98); }
            to { opacity: 1; transform: translateY(0) scale(1); }
        }

        .question-card .card-header {
            background: var(--surface-raised);
            padding: 0.85rem 1.25rem;
            border-bottom: 1px solid var(--border-light);
        }

        .question-card .card-header h5 {
            font-size: 0.9rem;
            font-weight: 600;
            color: var(--ink-muted);
            display: flex;
            align-items: center;
            gap: 0.65rem;
            text-transform: uppercase;
            letter-spacing: 0.04em;
            margin: 0;
        }

        .question-number {
            background: var(--primary);
            color: white;
            width: 30px; height: 30px;
            border-radius: 8px;
            display: inline-flex;
            align-items: center;
            justify-content: center;
            font-family: var(--mono);
            font-size: 0.8rem;
            font-weight: 700;
            letter-spacing: 0;
        }

        .question-card .card-body { padding: 1.5rem 1.5rem 1.75rem; }

        .question-text {
            font-size: 1.08rem;
            color: var(--ink);
            margin-bottom: 1.75rem;
            line-height: 1.75;
            font-weight: 500;
            letter-spacing: -0.01em;
        }

        /* ==================== OPTIONS ==================== */
        .options { display: grid; gap: 0.6rem; }

        .option-item {
            background: var(--surface);
            border: 1.5px solid var(--border);
            border-radius: var(--radius-sm);
            padding: 0.9rem 1.1rem;
            cursor: pointer;
            transition: all 0.2s ease;
            display: flex;
            align-items: center;
            gap: 0.85rem;
            position: relative;
        }

        .option-item:hover {
            border-color: var(--primary);
            background: var(--primary-soft);
            transform: translateX(4px);
        }

        .option-item:active { transform: scale(0.99); }

        .option-item.selected {
            border-color: var(--primary);
            background: var(--primary-soft);
            box-shadow: inset 0 0 0 1px var(--primary), 0 2px 8px var(--primary-glow);
        }

        .option-letter {
            width: 34px; height: 34px;
            border-radius: 8px;
            background: var(--bg);
            display: flex;
            align-items: center;
            justify-content: center;
            font-family: var(--mono);
            font-weight: 700;
            font-size: 0.85rem;
            color: var(--ink-muted);
            flex-shrink: 0;
            transition: all 0.2s ease;
            border: 1.5px solid var(--border);
        }

        .option-item.selected .option-letter {
            background: var(--primary);
            color: white;
            border-color: var(--primary);
        }

        .option-text {
            flex: 1;
            font-size: 0.98rem;
            color: var(--ink);
            line-height: 1.5;
            letter-spacing: -0.01em;
        }

        /* ==================== BOTTOM NAV ==================== */
        .nav-arrows {
            position: fixed;
            bottom: 0; left: 0; right: 0;
            z-index: 1001;
            background: var(--surface);
            border-top: 1px solid var(--border);
            box-shadow: 0 -2px 12px rgba(26,29,46,0.05);
            padding: 0.55rem 1rem;
        }

        .nav-arrows .container {
            display: flex;
            align-items: center;
            justify-content: space-between;
            max-width: 780px;
        }

        .nav-arrow-btn {
            display: flex;
            align-items: center;
            gap: 0.4rem;
            padding: 0.5rem 1rem;
            border-radius: 50px;
            font-family: var(--sans);
            font-weight: 600;
            font-size: 0.88rem;
            border: 1.5px solid var(--border);
            background: var(--surface);
            color: var(--ink);
            cursor: pointer;
            transition: all 0.2s ease;
            letter-spacing: -0.01em;
        }

        .nav-arrow-btn:hover:not(:disabled) {
            border-color: var(--primary);
            color: var(--primary);
            background: var(--primary-soft);
        }

        .nav-arrow-btn:disabled { opacity: 0.3; cursor: not-allowed; }
        .nav-arrow-btn i { font-size: 1rem; }

        .nav-arrow-indicator {
            display: flex;
            align-items: center;
            gap: 0.4rem;
            color: var(--ink-muted);
            font-size: 0.85rem;
            font-weight: 500;
        }

        .nav-arrow-indicator span.current-num {
            color: var(--primary);
            font-family: var(--mono);
            font-weight: 700;
            font-size: 1rem;
        }

        .nav-grid-toggle {
            background: var(--surface-raised);
            border: 1.5px solid var(--border);
            border-radius: 50px;
            padding: 0.4rem 0.65rem;
            cursor: pointer;
            color: var(--ink-muted);
            transition: all 0.2s;
            display: flex;
            align-items: center;
            gap: 0.3rem;
            font-size: 0.82rem;
            font-weight: 600;
        }

        .nav-grid-toggle:hover {
            border-color: var(--primary);
            color: var(--primary);
            background: var(--primary-soft);
        }

        .nav-grid-toggle i { font-size: 1rem; }

        /* ==================== QUESTION GRID ==================== */
        .question-nav {
            position: fixed;
            bottom: 56px; left: 0; right: 0;
            background: var(--surface);
            border-top: 1px solid var(--border);
            padding: 0.85rem 1rem;
            z-index: 1000;
            box-shadow: 0 -4px 16px rgba(26,29,46,0.06);
            transform: translateY(100%);
            transition: transform 0.35s cubic-bezier(0.16, 1, 0.3, 1);
        }

        .question-nav.show { transform: translateY(0); }

        .question-nav .container {
            display: flex;
            align-items: center;
            justify-content: center;
            gap: 1rem;
            flex-wrap: wrap;
        }

        .nav-buttons {
            display: flex;
            gap: 0.35rem;
            flex-wrap: wrap;
            justify-content: center;
        }

        .question-btn {
            width: 36px; height: 36px;
            border-radius: 8px;
            border: 1.5px solid var(--border);
            background: var(--surface);
            color: var(--ink-muted);
            font-family: var(--mono);
            font-weight: 600;
            font-size: 0.78rem;
            cursor: pointer;
            transition: all 0.2s ease;
        }

        .question-btn:hover {
            border-color: var(--primary);
            color: var(--primary);
            background: var(--primary-soft);
        }

        .question-btn.answered {
            background: var(--success);
            border-color: var(--success);
            color: white;
            box-shadow: 0 2px 6px rgba(6, 214, 160, 0.3);
        }

        .question-btn.current {
            border-color: var(--primary);
            border-width: 2px;
            background: var(--primary-soft);
            color: var(--primary);
        }

        .nav-legend {
            display: flex;
            gap: 1rem;
            align-items: center;
        }

        .nav-legend span {
            font-size: 0.78rem;
            color: var(--ink-muted);
            display: flex;
            align-items: center;
            gap: 0.4rem;
            font-weight: 500;
        }

        .nav-legend .dot {
            width: 10px; height: 10px;
            border-radius: 3px;
            border: 1.5px solid var(--border);
            display: inline-block;
        }

        .nav-legend .dot.answered {
            background: var(--success);
            border-color: var(--success);
        }

        /* ==================== SAVE INDICATOR ==================== */
        .save-indicator {
            position: fixed;
            top: 130px;
            right: 20px;
            z-index: 1001;
            background: var(--surface);
            padding: 0.4rem 0.85rem;
            border-radius: 50px;
            box-shadow: var(--shadow-md);
            font-size: 0.8rem;
            font-weight: 600;
            display: none;
            border: 1px solid var(--border-light);
            letter-spacing: -0.01em;
        }

        .save-indicator.saving {
            display: flex; align-items: center; gap: 0.45rem;
            color: var(--warning);
        }

        .save-indicator.saved {
            display: flex; align-items: center; gap: 0.45rem;
            color: var(--success);
        }

        .save-indicator.error {
            display: flex; align-items: center; gap: 0.45rem;
            color: var(--danger);
        }

        /* ==================== LOADING ==================== */
        .question-loading {
            display: flex;
            justify-content: center;
            align-items: center;
            min-height: 300px;
        }

        .question-loading .spinner-border {
            width: 2.5rem; height: 2.5rem;
            border-width: 3px;
            color: var(--primary);
        }

        .mobile-nav-close { display: none; }

        /* ==================== QUESTION IMAGE & ZOOM (P2 #24) ==================== */
        .question-image-wrap {
            position: relative;
            display: inline-block;
            max-width: 100%;
            margin-bottom: 1.25rem;
            cursor: zoom-in;
        }
        .question-image {
            max-width: 100%;
            max-height: 400px;
            border-radius: var(--radius-sm);
            border: 1px solid var(--border-light);
            transition: transform 0.2s ease, box-shadow 0.2s ease;
            display: block;
        }
        .question-image-wrap:hover .question-image {
            box-shadow: var(--shadow-md);
            transform: scale(1.01);
        }
        .question-image-hint {
            display: inline-flex;
            align-items: center;
            gap: 0.35rem;
            margin-top: 0.45rem;
            font-size: 0.78rem;
            color: var(--ink-muted);
            background: var(--surface-raised);
            border: 1px solid var(--border);
            padding: 0.2rem 0.65rem;
            border-radius: 50px;
        }
        .img-zoom-backdrop {
            display: none;
            position: fixed;
            inset: 0;
            z-index: 10050;
            background: rgba(15, 23, 42, 0.88);
            flex-direction: column;
            align-items: center;
            justify-content: center;
            padding: 1rem;
        }
        .img-zoom-backdrop.open {
            display: flex;
        }
        .img-zoom-toolbar {
            display: flex;
            align-items: center;
            gap: 0.5rem;
            margin-bottom: 0.75rem;
            background: rgba(255, 255, 255, 0.14);
            padding: 0.4rem 0.75rem;
            border-radius: 50px;
            backdrop-filter: blur(6px);
        }
        .img-zoom-toolbar button {
            background: #ffffff;
            color: #1a1d2e;
            border: none;
            border-radius: 50px;
            padding: 0.3rem 0.75rem;
            font-size: 0.82rem;
            font-weight: 600;
            cursor: pointer;
        }
        .img-zoom-toolbar button:hover {
            background: #eef1ff;
            color: #4361ee;
        }
        .img-zoom-stage {
            max-width: 94vw;
            max-height: 80vh;
            overflow: auto;
            display: flex;
            align-items: center;
            justify-content: center;
            border-radius: 10px;
        }
        .img-zoom-stage img {
            max-width: 100%;
            max-height: 78vh;
            border-radius: 8px;
            transition: transform 0.2s ease;
            transform-origin: center center;
        }

        /* ==================== OFFLINE SYNC BANNER (P2 #25) ==================== */
        .offline-sync-banner {
            display: none;
            position: fixed;
            top: 118px;
            left: 50%;
            transform: translateX(-50%);
            z-index: 1002;
            padding: 0.45rem 1rem;
            border-radius: 50px;
            font-size: 0.82rem;
            font-weight: 600;
            box-shadow: var(--shadow-md);
            white-space: nowrap;
            max-width: 92vw;
            overflow: hidden;
            text-overflow: ellipsis;
        }
        .offline-sync-banner.offline {
            display: inline-flex;
            align-items: center;
            gap: 0.45rem;
            background: #fef3c7;
            color: #92400e;
            border: 1.5px solid #f59e0b;
        }
        .offline-sync-banner.syncing {
            display: inline-flex;
            align-items: center;
            gap: 0.45rem;
            background: #eef1ff;
            color: #4361ee;
            border: 1.5px solid #4361ee;
        }
        .offline-sync-banner.synced {
            display: inline-flex;
            align-items: center;
            gap: 0.45rem;
            background: #ecfdf5;
            color: #065f46;
            border: 1.5px solid #06d6a0;
        }

        /* ==================== RESPONSIVE ==================== */
        @media (max-width: 768px) {
            .header-main .container { flex-wrap: wrap; gap: 0.4rem; }
            .quiz-title { font-size: 0.82rem; max-width: 160px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
            .exam-timer { padding: 0.3rem 0.7rem; font-size: 0.92rem; }
            .question-count-badge { padding: 0.2rem 0.5rem; font-size: 0.72rem; }
            .submit-btn { padding: 0.35rem 0.7rem; font-size: 0.8rem; }
            .submit-btn span { display: none; }
            .header-progress { padding: 0.4rem 0; }
            .header-progress .container { gap: 0.5rem; }
            .progress-text { font-size: 0.72rem; }
            .progress { height: 4px; }
            .exam-content { margin-top: 115px; margin-bottom: 88px; padding: 0.85rem; }
            .question-card .card-header { padding: 0.65rem 1rem; }
            .question-card .card-header h5 { font-size: 0.8rem; }
            .question-number { width: 26px; height: 26px; font-size: 0.72rem; }
            .question-card .card-body { padding: 1.1rem; }
            .question-text { font-size: 0.98rem; margin-bottom: 1.25rem; line-height: 1.65; }
            .option-item { padding: 0.7rem 0.85rem; gap: 0.65rem; }
            .option-letter { width: 30px; height: 30px; font-size: 0.78rem; }
            .option-text { font-size: 0.9rem; }
            .nav-arrows { padding: 0.45rem 0.65rem; }
            .nav-arrow-btn { padding: 0.45rem 0.7rem; font-size: 0.82rem; }
            .nav-arrow-btn span.btn-label { display: none; }
            .nav-arrow-btn i { font-size: 1.1rem; }
            .nav-arrow-indicator { font-size: 0.78rem; }
            .nav-arrow-indicator span.current-num { font-size: 0.92rem; }
            .nav-grid-toggle { padding: 0.35rem 0.55rem; font-size: 0.78rem; }
            .question-nav { bottom: 50px; padding: 0.5rem; }
            .question-btn { width: 32px; height: 32px; font-size: 0.72rem; }
            .mobile-nav-close { display: block !important; }
            .question-nav .container { flex-direction: column; align-items: stretch; }
            .nav-buttons { justify-content: center; }
            .nav-legend { justify-content: center; }
            .save-indicator { top: 125px; right: 10px; padding: 0.3rem 0.65rem; font-size: 0.72rem; }
            .question-loading { min-height: 200px; }
        }

        @media (max-width: 480px) {
            .quiz-title { max-width: 110px; font-size: 0.78rem; }
            .exam-timer { padding: 0.25rem 0.55rem; font-size: 0.85rem; }
            .submit-btn { padding: 0.3rem 0.55rem; }
            .exam-content { margin-top: 115px; margin-bottom: 82px; padding: 0.65rem; }
            .question-card .card-header { padding: 0.55rem 0.75rem; }
            .question-card .card-body { padding: 0.85rem; }
            .question-text { font-size: 0.92rem; }
            .option-item { padding: 0.55rem 0.75rem; }
            .option-text { font-size: 0.85rem; }
            .nav-arrow-btn { padding: 0.4rem 0.55rem; }
        }

        /* ==================== ANTI-CHEAT ==================== */
        body, .question-card, .card-body, p, .option-item, label {
            -webkit-user-select: none; -moz-user-select: none; -ms-user-select: none; user-select: none;
        }
        img, a, * { -webkit-user-drag: none; user-drag: none; }
        @media print { body { display: none !important; } }
        @keyframes spin { from { transform: rotate(0deg); } to { transform: rotate(360deg); } }
        .spin { animation: spin 1s linear infinite; }
    </style>
<link href="../assets/css/handdrawn.css" rel="stylesheet">
</head>
<body oncontextmenu="return false;" onselectstart="return false;" ondragstart="return false;" ondrop="return false;">
    <!-- Save Indicator -->
    <div class="save-indicator" id="saveIndicator">
        <span id="saveStatus"></span>
    </div>

    <!-- Offline / LocalStorage Sync Banner (P2 #25) -->
    <div class="offline-sync-banner" id="offlineSyncBanner" role="status" aria-live="polite"></div>

    <!-- Exam Header -->
    <div class="exam-header">
        <!-- Main Header -->
        <div class="header-main">
            <div class="container">
                <h5 class="quiz-title">
                    <i class="bi bi-journal-text"></i>
                    <%= ValidationUtil.sanitizeHtml(quiz.getTitle()) %>
                </h5>
                <div class="exam-timer" id="timer">
                    <i class="bi bi-stopwatch-fill"></i>
                    <span id="timeDisplay"><%= quiz.getDuration() %>:00</span>
                </div>
                <div class="header-actions">
                    <span class="question-count-badge" id="questionCountBadge">
                        <%= totalQuestions %> Soal
                    </span>
                    <button class="submit-btn" id="submitBtn" data-bs-toggle="modal" data-bs-target="#submitModal">
                        <i class="bi bi-send-fill"></i>
                        <span>Submit</span>
                    </button>
                </div>
            </div>
        </div>
        <!-- Progress Bar -->
        <div class="header-progress">
            <div class="container">
                <div class="progress-container">
                    <div class="progress">
                        <div class="progress-bar" id="progressBar" role="progressbar" style="width: 0%"></div>
                    </div>
                </div>
                <div class="progress-text">
                    <span id="answeredCount">0</span> / <%= totalQuestions %> dijawab
                </div>
            </div>
        </div>
    </div>

    <!-- Exam Content - Questions loaded dynamically via AJAX -->
    <div class="container exam-content">
        <form id="examForm">
            <input type="hidden" name="submissionId" value="<%= submission.getId() %>">
            <input type="hidden" name="timeSpent" id="timeSpent" value="0">
            <input type="hidden" name="isTimeout" id="isTimeout" value="false">
            <input type="hidden" name="csrfToken" id="csrfToken" value="<%= session.getAttribute("csrfToken") %>">

            <!-- Single question container - populated via AJAX -->
            <div id="questionContainer">
                <div class="question-loading">
                    <div class="spinner-border text-primary" role="status">
                        <span class="visually-hidden">Memuat soal...</span>
                    </div>
                </div>
            </div>
        </form>
    </div>

    <!-- Navigation Arrows (prev/next) - always visible -->
    <div class="nav-arrows" id="navArrows">
        <div class="container">
            <button type="button" class="nav-arrow-btn" id="prevBtn" onclick="prevQuestion()">
                <i class="bi bi-chevron-left"></i>
                <span class="btn-label">Sebelumnya</span>
            </button>
            <div style="display:flex;align-items:center;gap:0.5rem;">
                <div class="nav-arrow-indicator">
                    <span class="current-num" id="currentQNum">1</span> / <span id="totalQNum"><%= totalQuestions %></span>
                </div>
                <button type="button" class="nav-grid-toggle" id="gridToggleBtn" onclick="toggleQuestionNav()">
                    <i class="bi bi-grid-3x3-gap-fill"></i>
                </button>
            </div>
            <button type="button" class="nav-arrow-btn" id="nextBtn" onclick="nextQuestion()">
                <span class="btn-label">Selanjutnya</span>
                <i class="bi bi-chevron-right"></i>
            </button>
        </div>
    </div>

    <!-- Question Number Grid - toggled -->
    <div class="question-nav" id="questionNav">
        <div class="container">
            <button type="button" class="btn btn-outline-secondary btn-sm mobile-nav-close mb-2 float-end" onclick="hideQuestionNav()">
                <i class="bi bi-x-lg"></i> Tutup
            </button>
            <div class="nav-buttons" id="navButtons">
                <!-- Navigation buttons generated by JS -->
            </div>
            <div class="nav-legend">
                <span><i class="dot"></i> Belum</span>
                <span><i class="dot answered"></i> Dijawab</span>
            </div>
        </div>
    </div>

    <!-- Submit Modal -->
    <div class="modal fade" id="submitModal" tabindex="-1">
        <div class="modal-dialog modal-dialog-centered">
            <div class="modal-content">
                <div class="modal-header">
                    <h5 class="modal-title"><i class="bi bi-question-circle me-2"></i>Konfirmasi Submit</h5>
                    <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
                </div>
                <div class="modal-body">
                    <p>Apakah Anda yakin ingin menyelesaikan ujian ini?</p>
                    <p class="mb-0 text-muted">
                        Anda telah menjawab <strong id="modalAnsweredCount">0</strong> dari
                        <strong><%= totalQuestions %></strong> soal.
                    </p>
                    <div id="unansweredWarning" class="alert alert-warning mt-3" style="display: none;">
                        <i class="bi bi-exclamation-triangle me-2"></i>
                        Masih ada soal yang belum dijawab!
                    </div>
                    <div id="pendingSavesWarning" class="alert alert-danger mt-3" style="display: none;">
                        <i class="bi bi-exclamation-circle me-2"></i>
                        Masih ada jawaban yang sedang disimpan. Mohon tunggu...
                    </div>
                </div>
                <div class="modal-footer">
                    <button type="button" class="btn btn-outline-secondary" data-bs-dismiss="modal">
                        <i class="bi bi-x-lg me-1"></i>Batal
                    </button>
                    <button type="button" class="btn btn-success" id="confirmSubmitBtn" onclick="submitExam()">
                        <i class="bi bi-send me-1"></i>Ya, Submit
                    </button>
                </div>
            </div>
        </div>
    </div>

    <!-- Unanswered Questions Warning Modal -->
    <div class="modal fade" id="unansweredWarningModal" tabindex="-1" data-bs-backdrop="static">
        <div class="modal-dialog modal-dialog-centered">
            <div class="modal-content border-0">
                <div class="modal-header bg-danger text-white border-0">
                    <h5 class="modal-title">
                        <i class="bi bi-exclamation-triangle-fill me-2"></i>Peringatan!
                    </h5>
                </div>
                <div class="modal-body text-center py-4">
                    <div class="mb-3">
                        <i class="bi bi-exclamation-circle text-danger" style="font-size: 4rem;"></i>
                    </div>
                    <h5 class="mb-3">Masih ada <span id="unansweredCount" class="text-danger fw-bold">0</span> soal yang belum dijawab.</h5>
                    <p class="text-muted mb-0">
                        <i class="bi bi-info-circle me-1"></i>
                        Soal yang tidak dijawab akan dianggap <strong class="text-danger">SALAH</strong>.
                    </p>
                </div>
                <div class="modal-footer border-0 justify-content-center">
                    <button type="button" class="btn btn-secondary px-4" data-bs-dismiss="modal">
                        <i class="bi bi-arrow-left me-1"></i>Kembali ke Quiz
                    </button>
                    <button type="button" class="btn btn-danger px-4" id="forceSubmitBtn" onclick="forceSubmit()">
                        <i class="bi bi-send me-1"></i>Ya, Submit Sekarang
                    </button>
                </div>
            </div>
        </div>
    </div>

    <!-- Image Zoom Lightbox Modal (P2 #24) -->
    <div class="img-zoom-backdrop" id="imageZoomModal" onclick="if (event.target === this) closeImageZoom();">
        <div class="img-zoom-toolbar">
            <button type="button" onclick="adjustImageZoom(-0.25)" title="Perkecil"><i class="bi bi-zoom-out"></i></button>
            <button type="button" onclick="resetImageZoom()" title="Reset 100%"><span id="zoomLevelLabel">100%</span></button>
            <button type="button" onclick="adjustImageZoom(0.25)" title="Perbesar"><i class="bi bi-zoom-in"></i></button>
            <button type="button" onclick="closeImageZoom()" title="Tutup"><i class="bi bi-x-lg"></i> Tutup</button>
        </div>
        <div class="img-zoom-stage">
            <img id="zoomedImageEl" src="" alt="Preview Gambar Soal" oncontextmenu="return false;" ondragstart="return false;">
        </div>
    </div>

    <!-- Submit Overlay -->
    <div id="submitOverlay" style="display:none; position:fixed; top:0; left:0; width:100vw; height:100vh; z-index:99999; background:rgba(0,0,0,0.75); align-items:center; justify-content:center; flex-direction:column; color:#fff; font-family:var(--sans);">
        <div class="spinner-border text-light mb-3" style="width:3rem; height:3rem;" role="status">
            <span class="visually-hidden">Loading...</span>
        </div>
        <h4 style="margin:0 0 0.5rem 0;">Mengumpulkan jawaban...</h4>
        <p style="margin:0; opacity:0.7; font-size:0.95rem;">Mohon tunggu, jangan tutup halaman ini</p>
    </div>

    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/js/bootstrap.bundle.min.js"></script>
    <script>
        // ============================================
        // CONFIGURATION
        // ============================================
        const totalQuestions = <%= totalQuestions %>;
        const quizId = <%= quiz.getId() %>;
        let timeRemaining = <%= timeRemaining %>;
        const submissionId = <%= submission.getId() %>;

        // ============================================
        // STATE MANAGEMENT - single source of truth
        // ============================================
        let currentQuestionIndex = 0;
        let answeredQuestions = {};   // { questionId: 'A' } - local answer state
        let questionIdMap = {};       // { index: questionId } - index to ID mapping
        let questionCache = {};       // { questionId: {data} } - cached question data
        let startTime = Date.now();
        let isLoadingQuestion = false;
        let timerInitialized = false;

        // Save queue & LocalStorage keys (P2 #25)
        let pendingSaves = {};
        let failedSaves = {};
        let saveInProgress = 0;
        const MAX_RETRIES = 3;
        const RETRY_DELAY = 1000;
        const LS_ANSWERS_KEY = 'exatuy_exam_answers_' + submissionId;
        const LS_PENDING_KEY = 'exatuy_exam_pending_' + submissionId;
        let currentImageZoom = 1;

        function persistAnswersToLocalStorage() {
            try {
                localStorage.setItem(LS_ANSWERS_KEY, JSON.stringify(answeredQuestions));
                localStorage.setItem(LS_PENDING_KEY, JSON.stringify(failedSaves));
            } catch (e) {
                console.warn('LocalStorage unavailable:', e);
            }
        }

        function restoreAnswersFromLocalStorage() {
            try {
                const rawAnswers = localStorage.getItem(LS_ANSWERS_KEY);
                if (rawAnswers) {
                    const parsed = JSON.parse(rawAnswers);
                    if (parsed && typeof parsed === 'object') {
                        Object.assign(answeredQuestions, parsed);
                    }
                }
                const rawPending = localStorage.getItem(LS_PENDING_KEY);
                if (rawPending) {
                    const parsedPending = JSON.parse(rawPending);
                    if (parsedPending && typeof parsedPending === 'object') {
                        Object.assign(failedSaves, parsedPending);
                    }
                }
            } catch (e) {
                console.warn('Failed to restore localStorage answers:', e);
            }
        }

        function clearExamLocalStorage() {
            try {
                localStorage.removeItem(LS_ANSWERS_KEY);
                localStorage.removeItem(LS_PENDING_KEY);
            } catch (e) {}
        }

        function setOfflineBanner(state, text) {
            const banner = document.getElementById('offlineSyncBanner');
            if (!banner) return;
            if (!state) {
                banner.className = 'offline-sync-banner';
                banner.innerHTML = '';
                return;
            }
            banner.className = 'offline-sync-banner ' + state;
            banner.innerHTML = text;
        }

        // Image Zoom Lightbox helpers (P2 #24)
        function openImageZoom(imgSrc) {
            const modal = document.getElementById('imageZoomModal');
            const img = document.getElementById('zoomedImageEl');
            if (!modal || !img) return;
            img.src = imgSrc;
            currentImageZoom = 1;
            applyImageZoom();
            modal.classList.add('open');
        }

        function adjustImageZoom(delta) {
            currentImageZoom = Math.min(3, Math.max(0.5, currentImageZoom + delta));
            applyImageZoom();
        }

        function resetImageZoom() {
            currentImageZoom = 1;
            applyImageZoom();
        }

        function applyImageZoom() {
            const img = document.getElementById('zoomedImageEl');
            const label = document.getElementById('zoomLevelLabel');
            if (img) img.style.transform = 'scale(' + currentImageZoom + ')';
            if (label) label.textContent = Math.round(currentImageZoom * 100) + '%';
        }

        function closeImageZoom() {
            const modal = document.getElementById('imageZoomModal');
            if (modal) modal.classList.remove('open');
        }

        // ============================================
        // NAVIGATION
        // ============================================
        function buildNavigation() {
            const navButtons = document.getElementById('navButtons');
            navButtons.innerHTML = '';
            for (let i = 0; i < totalQuestions; i++) {
                const btn = document.createElement('button');
                btn.type = 'button';
                btn.className = 'question-btn' + (i === 0 ? ' current' : '');
                btn.id = 'nav-' + (i + 1);
                btn.textContent = i + 1;
                const idx = i;
                btn.onclick = function() { loadQuestion(idx); };
                navButtons.appendChild(btn);
            }
            updateArrowButtons();
        }

        function updateAllNavButtons() {
            // Rebuild all nav button states based on current answeredQuestions
            for (let i = 0; i < totalQuestions; i++) {
                const btn = document.getElementById('nav-' + (i + 1));
                if (!btn) continue;
                const qId = questionIdMap[i];
                if (qId && answeredQuestions[qId]) {
                    btn.classList.add('answered');
                }
                if (i === currentQuestionIndex) {
                    btn.classList.add('current');
                } else {
                    btn.classList.remove('current');
                }
            }
            updateArrowButtons();
            const numEl = document.getElementById('currentQNum');
            if (numEl) numEl.textContent = currentQuestionIndex + 1;
        }

        function updateArrowButtons() {
            const prevBtn = document.getElementById('prevBtn');
            const nextBtn = document.getElementById('nextBtn');
            if (prevBtn) prevBtn.disabled = (currentQuestionIndex <= 0);
            if (nextBtn) nextBtn.disabled = (currentQuestionIndex >= totalQuestions - 1);
        }

        function prevQuestion() {
            if (currentQuestionIndex > 0 && !isLoadingQuestion) {
                loadQuestion(currentQuestionIndex - 1);
                window.scrollTo({ top: 0, behavior: 'smooth' });
            }
        }

        function nextQuestion() {
            if (currentQuestionIndex < totalQuestions - 1 && !isLoadingQuestion) {
                loadQuestion(currentQuestionIndex + 1);
                window.scrollTo({ top: 0, behavior: 'smooth' });
            }
        }

        function toggleQuestionNav() {
            document.getElementById('questionNav').classList.toggle('show');
        }

        function hideQuestionNav() {
            document.getElementById('questionNav').classList.remove('show');
        }

        // ============================================
        // QUESTION LOADING - with local cache
        // ============================================
        function loadQuestion(index) {
            if (index < 0 || index >= totalQuestions) return;
            if (isLoadingQuestion && index === currentQuestionIndex) return;

            currentQuestionIndex = index;

            // If question is already cached, render from cache immediately
            const cachedQId = questionIdMap[index];
            if (cachedQId && questionCache[cachedQId]) {
                updateAllNavButtons();
                renderCachedQuestion(cachedQId);
                if (window.innerWidth <= 768) {
                    setTimeout(hideQuestionNav, 300);
                }
                return;
            }

            isLoadingQuestion = true;
            updateAllNavButtons();

            document.getElementById('questionContainer').innerHTML =
                '<div class="question-loading"><div class="spinner-border text-primary" role="status"><span class="visually-hidden">Memuat soal...</span></div></div>';

            fetch('../ExamServlet?action=getQuestionData&quizId=' + quizId + '&index=' + index + '&submissionId=' + submissionId)
                .then(response => response.json())
                .then(data => {
                    if (!data.success) {
                        if (data.message === 'TIME_EXPIRED') {
                            alert('Waktu quiz telah habis! Jawaban Anda telah otomatis dikumpulkan.');
                            window.location.href = '../ExamServlet?action=' + (data.redirect || ('result?submissionId=' + submissionId + '&timeout=true'));
                            return;
                        }
                        document.getElementById('questionContainer').innerHTML =
                            '<div class="alert alert-danger">Gagal memuat soal. <button class="btn btn-sm btn-outline-danger" onclick="loadQuestion(' + index + ')">Coba Lagi</button></div>';
                        return;
                    }

                    // Store mapping and cache
                    questionIdMap[index] = data.questionId;
                    questionCache[data.questionId] = data;

                    // Sync server answer only if local doesn't have it
                    if (data.savedAnswer && !answeredQuestions[data.questionId]) {
                        answeredQuestions[data.questionId] = data.savedAnswer;
                    }

                    // Only sync remaining time on first load
                    // After that, only sync when unfreezing (handled by syncTimeFromServer)
                    if (typeof data.remainingTime === 'number' && !timerInitialized) {
                        timeRemaining = data.remainingTime;
                        timerInitialized = true;
                    }

                    // Only render if still on this question
                    if (currentQuestionIndex === index) {
                        renderCachedQuestion(data.questionId);
                    }

                    updateAllNavButtons();
                    updateProgress();
                })
                .catch(error => {
                    console.error('Error loading question:', error);
                    if (currentQuestionIndex === index) {
                        document.getElementById('questionContainer').innerHTML =
                            '<div class="alert alert-danger">Gagal memuat soal. <button class="btn btn-sm btn-outline-danger" onclick="loadQuestion(' + index + ')">Coba Lagi</button></div>';
                    }
                })
                .finally(() => {
                    isLoadingQuestion = false;
                    if (window.innerWidth <= 768) {
                        setTimeout(hideQuestionNav, 300);
                    }
                });
        }

        // ============================================
        // RENDER QUESTION - always from cache + local state
        // ============================================
        function renderCachedQuestion(questionId) {
            const data = questionCache[questionId];
            if (!data) return;

            const container = document.getElementById('questionContainer');
            const questionNum = currentQuestionIndex + 1;
            // ALWAYS use local answeredQuestions as source of truth
            const selectedAnswer = answeredQuestions[questionId] || null;

            let html = '<div class="question-card">';
            html += '<div class="card-header"><h5 class="mb-0">';
            html += '<span class="question-number">' + questionNum + '</span>';
            html += 'Soal #' + questionNum;
            html += '</h5></div>';
            html += '<div class="card-body">';
            html += '<p class="question-text">' + escapeHtml(data.questionText) + '</p>';

            if (data.imagePath) {
                var imgSrc = '../' + escapeHtml(data.imagePath);
                html += '<div class="mb-3 text-center">';
                html += '<div class="question-image-wrap" onclick="openImageZoom(\'' + imgSrc.replace(/'/g, "\\'") + '\')" title="Klik untuk memperbesar gambar soal">';
                html += '<img src="' + imgSrc + '" alt="Question Image" class="question-image" oncontextmenu="return false;" ondragstart="return false;">';
                html += '<div class="question-image-hint"><i class="bi bi-zoom-in"></i> Klik gambar untuk perbesar</div>';
                html += '</div></div>';
            }

            html += '<div class="options">';

            var options = [
                { letter: 'A', text: data.optionA },
                { letter: 'B', text: data.optionB },
                { letter: 'C', text: data.optionC },
                { letter: 'D', text: data.optionD }
            ];

            for (var i = 0; i < options.length; i++) {
                var opt = options[i];
                var isSelected = selectedAnswer === opt.letter;
                html += '<div class="option-item' + (isSelected ? ' selected' : '') + '"';
                html += ' data-question="' + questionId + '" data-option="' + opt.letter + '"';
                html += ' onclick="selectOption(' + questionId + ', \'' + opt.letter + '\', this)">';
                html += '<span class="option-letter">' + opt.letter + '</span>';
                html += '<span class="option-text">' + escapeHtml(opt.text) + '</span>';
                html += '</div>';
            }

            html += '</div></div></div>';
            container.innerHTML = html;
        }

        function escapeHtml(text) {
            if (!text) return '';
            var div = document.createElement('div');
            div.textContent = text;
            return div.innerHTML;
        }

        // ============================================
        // OPTION SELECTION
        // ============================================
        function selectOption(questionId, option, element) {
            // Visual update
            var options = document.querySelectorAll('[data-question="' + questionId + '"]');
            for (var i = 0; i < options.length; i++) {
                options[i].classList.remove('selected');
            }
            element.classList.add('selected');

            // Save to local state & localStorage (P2 #25)
            answeredQuestions[questionId] = option;
            persistAnswersToLocalStorage();

            // Update UI
            updateProgress();
            updateAllNavButtons();

            // If offline, queue locally for sync when back online
            if (!navigator.onLine) {
                failedSaves[questionId] = { answer: option, error: 'offline' };
                persistAnswersToLocalStorage();
                updateSaveIndicator('offline');
                setOfflineBanner('offline', '<i class="bi bi-wifi-off"></i> Koneksi terputus &mdash; jawaban tersimpan lokal');
                return;
            }

            // Save to server
            saveAnswerToServer(questionId, option, 0);
        }

        // ============================================
        // SAVE ANSWER TO SERVER
        // ============================================
        function saveAnswerToServer(questionId, selectedAnswer, retryCount) {
            var csrfToken = document.getElementById('csrfToken').value;

            pendingSaves[questionId] = { answer: selectedAnswer, retryCount: retryCount };
            saveInProgress++;
            updateSaveIndicator('saving');

            fetch('../ExamServlet?action=saveAnswer', {
                method: 'POST',
                headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
                body: 'submissionId=' + submissionId + '&questionId=' + questionId + '&selectedAnswer=' + selectedAnswer + '&csrfToken=' + encodeURIComponent(csrfToken)
            })
            .then(function(response) {
                if (!response.ok) throw new Error('HTTP error ' + response.status);
                return response.json();
            })
            .then(function(data) {
                if (data.success) {
                    delete pendingSaves[questionId];
                    delete failedSaves[questionId];
                    persistAnswersToLocalStorage();
                } else if (data.message === 'TIME_EXPIRED') {
                    clearExamLocalStorage();
                    alert('Waktu quiz telah habis! Jawaban Anda telah otomatis dikumpulkan.');
                    window.location.href = '../ExamServlet?action=' + data.redirect;
                } else {
                    throw new Error(data.message || 'Unknown error');
                }
            })
            .catch(function(error) {
                console.error('Error saving answer:', error);
                if (navigator.onLine && retryCount < MAX_RETRIES) {
                    setTimeout(function() { saveAnswerToServer(questionId, selectedAnswer, retryCount + 1); }, RETRY_DELAY);
                    return;
                }
                failedSaves[questionId] = { answer: selectedAnswer, error: error.message };
                delete pendingSaves[questionId];
                persistAnswersToLocalStorage();
                if (!navigator.onLine) {
                    setOfflineBanner('offline', '<i class="bi bi-wifi-off"></i> Koneksi terputus &mdash; jawaban tersimpan lokal');
                }
            })
            .finally(function() {
                saveInProgress--;
                if (saveInProgress === 0) {
                    if (Object.keys(failedSaves).length > 0) {
                        updateSaveIndicator(navigator.onLine ? 'error' : 'offline');
                    } else if (Object.keys(pendingSaves).length === 0) {
                        updateSaveIndicator('saved');
                    }
                }
            });
        }

        // ============================================
        // UPDATE UI
        // ============================================
        function updateProgress() {
            var answered = Object.keys(answeredQuestions).length;
            document.getElementById('answeredCount').textContent = answered;
            document.getElementById('modalAnsweredCount').textContent = answered;

            var percentage = (answered / totalQuestions) * 100;
            document.getElementById('progressBar').style.width = percentage + '%';

            document.getElementById('unansweredWarning').style.display =
                answered < totalQuestions ? 'block' : 'none';
        }

        function updateSaveIndicator(status) {
            var indicator = document.getElementById('saveIndicator');
            var statusEl = document.getElementById('saveStatus');
            indicator.className = 'save-indicator ' + status;

            if (status === 'saving') {
                statusEl.innerHTML = '<i class="bi bi-arrow-repeat spin"></i> Menyimpan...';
            } else if (status === 'saved') {
                statusEl.innerHTML = '<i class="bi bi-check-circle-fill"></i> Tersimpan';
            } else if (status === 'offline') {
                indicator.className = 'save-indicator saving';
                statusEl.innerHTML = '<i class="bi bi-hdd-fill"></i> Tersimpan lokal';
            } else if (status === 'error') {
                statusEl.innerHTML = '<i class="bi bi-exclamation-circle-fill"></i> Menunggu sinkronisasi';
            } else {
                statusEl.innerHTML = '';
            }
        }

        // ============================================
        // TIMER - freeze on disconnect/tab switch, sync on return
        // ============================================
        let timerFrozen = false;
        let timerInterval = null;
        let frozenAt = null; // timestamp when timer was frozen

        function updateTimer() {
            if (timerFrozen) return;

            var minutes = Math.floor(timeRemaining / 60);
            var seconds = timeRemaining % 60;
            document.getElementById('timeDisplay').textContent =
                String(minutes).padStart(2, '0') + ':' + String(seconds).padStart(2, '0');

            if (timeRemaining <= 300) {
                document.getElementById('timer').classList.add('warning');
            }

            if (timeRemaining <= 0) {
                clearInterval(timerInterval);
                document.getElementById('isTimeout').value = 'true';
                // Force submit directly on timeout - skip unanswered check
                proceedWithSubmit();
                return;
            }

            timeRemaining--;
        }

        function freezeTimer() {
            if (timerFrozen) return;
            timerFrozen = true;
            frozenAt = Date.now();
            // Show frozen indicator
            document.getElementById('timeDisplay').textContent =
                document.getElementById('timeDisplay').textContent + ' (Dijeda)';
        }

        function unfreezeTimer() {
            if (!timerFrozen) return;
            // Resume the local timer from where it was frozen. We intentionally
            // do NOT sync from the server here: the previous implementation called
            // getQuestionData on every tab return, which triggered updateActivity
            // and corrupted the pause calculation, making the displayed time jump
            // to a random value. The server-side time check at submit/expire is
            // the authoritative validation; the local timer is just for display.
            timerFrozen = false;
            frozenAt = null;
            // Remove "(Dijeda)" suffix if present
            var td = document.getElementById('timeDisplay');
            if (td && td.textContent.indexOf(' (Dijeda)') !== -1) {
                td.textContent = td.textContent.replace(' (Dijeda)', '');
            }
        }

        // Detect tab visibility change - freeze when hidden
        document.addEventListener('visibilitychange', function() {
            if (document.hidden) {
                freezeTimer();
            } else {
                unfreezeTimer();
            }
        });

        // Detect internet disconnect - freeze & save locally (P2 #25)
        window.addEventListener('offline', function() {
            freezeTimer();
            persistAnswersToLocalStorage();
            setOfflineBanner('offline', '<i class="bi bi-wifi-off"></i> Koneksi terputus &mdash; jawaban disimpan lokal di perangkat');
        });

        window.addEventListener('online', async function() {
            unfreezeTimer();
            const pendingCount = Object.keys(failedSaves).length;
            if (pendingCount > 0) {
                setOfflineBanner('syncing', '<i class="bi bi-arrow-repeat spin"></i> Menyinkronkan ' + pendingCount + ' jawaban lokal ke server...');
                await retryFailedSaves();
                persistAnswersToLocalStorage();
                if (Object.keys(failedSaves).length === 0) {
                    updateSaveIndicator('saved');
                    setOfflineBanner('synced', '<i class="bi bi-cloud-check-fill"></i> Semua jawaban berhasil disinkronkan!');
                    setTimeout(function() { setOfflineBanner(null, ''); }, 3500);
                } else {
                    setOfflineBanner('offline', '<i class="bi bi-exclamation-triangle"></i> Sebagian jawaban belum tersinkron, akan dicoba saat submit');
                }
            } else {
                setOfflineBanner('synced', '<i class="bi bi-wifi"></i> Koneksi kembali tersambung');
                setTimeout(function() { setOfflineBanner(null, ''); }, 2500);
            }
        });

        // ============================================
        // SUBMIT EXAM
        // ============================================
        async function submitExam() {
            var answered = Object.keys(answeredQuestions).length;
            var unanswered = totalQuestions - answered;

            if (unanswered > 0) {
                document.getElementById('unansweredCount').textContent = unanswered;
                var warningModal = new bootstrap.Modal(document.getElementById('unansweredWarningModal'));
                warningModal.show();
                return;
            }

            await proceedWithSubmit();
        }

        async function forceSubmit() {
            var warningModal = bootstrap.Modal.getInstance(document.getElementById('unansweredWarningModal'));
            warningModal.hide();
            await proceedWithSubmit();
        }

        async function proceedWithSubmit() {
            // Show submit overlay
            var overlay = document.getElementById('submitOverlay');
            if (overlay) overlay.style.display = 'flex';

            var submitBtn = document.getElementById('confirmSubmitBtn');
            var forceSubmitBtn = document.getElementById('forceSubmitBtn');
            if (submitBtn) {
                submitBtn.disabled = true;
                submitBtn.innerHTML = '<span class="spinner-border spinner-border-sm me-2"></span>Mengirim...';
            }
            if (forceSubmitBtn) forceSubmitBtn.disabled = true;

            // Wait for any pending saves to complete
            if (saveInProgress > 0) {
                document.getElementById('pendingSavesWarning').style.display = 'block';
                var waited = 0;
                while (saveInProgress > 0 && waited < 10000) {
                    await new Promise(function(resolve) { setTimeout(resolve, 500); });
                    waited += 500;
                }
                document.getElementById('pendingSavesWarning').style.display = 'none';
            }

            // Only retry failed saves (don't re-send all answers)
            await retryFailedSaves();

            isSubmitting = true;

            var timeSpent = Math.floor((Date.now() - startTime) / 1000);
            var isTimeout = document.getElementById('isTimeout').value;
            var csrfToken = document.getElementById('csrfToken').value;

            // Submit via AJAX with retry
            var maxRetries = 3;
            var lastError = null;

            for (var attempt = 0; attempt < maxRetries; attempt++) {
                try {
                    var resp = await fetch('../ExamServlet?action=submit', {
                        method: 'POST',
                        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
                        body: 'submissionId=' + submissionId + '&timeSpent=' + timeSpent + '&isTimeout=' + isTimeout + '&csrfToken=' + encodeURIComponent(csrfToken) + '&ajax=true'
                    });

                    var data = await resp.json();

                    if (data.success) {
                        clearExamLocalStorage();
                        window.location.href = '../ExamServlet?action=result&submissionId=' + submissionId;
                        return;
                    } else {
                        throw new Error(data.message || 'Submit gagal');
                    }
                } catch (error) {
                    lastError = error;
                    console.error('Submit attempt ' + (attempt + 1) + ' failed:', error);
                    if (attempt < maxRetries - 1) {
                        // Update overlay to show retry
                        if (overlay) {
                            overlay.querySelector('h4').textContent = 'Mencoba lagi... (' + (attempt + 2) + '/' + maxRetries + ')';
                        }
                        await new Promise(function(resolve) { setTimeout(resolve, 2000); });
                    }
                }
            }

            // All retries failed
            isSubmitting = false;
            if (overlay) overlay.style.display = 'none';
            alert('Submit gagal setelah ' + maxRetries + ' percobaan.\n\nHalaman akan di-refresh untuk mencoba lagi.');
            window.location.reload();
        }

        async function retryFailedSaves() {
            var csrfToken = document.getElementById('csrfToken').value;
            var promises = [];

            for (var qId in failedSaves) {
                var selAnswer = failedSaves[qId].answer;
                promises.push(
                    fetch('../ExamServlet?action=saveAnswer', {
                        method: 'POST',
                        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
                        body: 'submissionId=' + submissionId + '&questionId=' + qId + '&selectedAnswer=' + selAnswer + '&csrfToken=' + encodeURIComponent(csrfToken)
                    })
                    .then(function(response) { return response.json(); })
                    .then(function(data) {
                        if (data.success) delete failedSaves[qId];
                        return data;
                    })
                    .catch(function(error) { return { success: false }; })
                );
            }

            if (promises.length > 0) {
                await Promise.all(promises);
            }
        }

        var isSubmitting = false;

        window.addEventListener('beforeunload', function(e) {
            if (isSubmitting) return;
            e.preventDefault();
            e.returnValue = '';
        });

        // ============================================
        // INITIALIZATION
        // ============================================
        document.addEventListener('DOMContentLoaded', function() {
            restoreAnswersFromLocalStorage();
            buildNavigation();
            updateProgress();
            loadQuestion(0);
            timerInterval = setInterval(updateTimer, 1000);
            if (navigator.onLine && Object.keys(failedSaves).length > 0) {
                retryFailedSaves().then(function() { persistAnswersToLocalStorage(); });
            }
        });

        document.addEventListener('keydown', function(e) {
            if (e.key === 'Escape') {
                closeImageZoom();
            }
        });

        // ============================================
        // ANTI-COPY & ANTI-INSPECT PROTECTION
        // ============================================

        document.addEventListener('copy', e => { e.preventDefault(); return false; });
        document.addEventListener('cut', e => { e.preventDefault(); return false; });
        document.addEventListener('paste', e => { e.preventDefault(); return false; });

        document.addEventListener('keydown', function(e) {
            if (e.key === 'F12') { e.preventDefault(); return false; }
            if (e.ctrlKey && e.shiftKey && e.key === 'I') { e.preventDefault(); return false; }
            if (e.ctrlKey && e.shiftKey && e.key === 'J') { e.preventDefault(); return false; }
            if (e.ctrlKey && e.shiftKey && e.key === 'C') { e.preventDefault(); return false; }
            if (e.ctrlKey && e.key === 'u') { e.preventDefault(); return false; }
            if (e.ctrlKey && e.key === 's') { e.preventDefault(); return false; }
            if (e.ctrlKey && e.key === 'p') { e.preventDefault(); return false; }
            if (e.ctrlKey && e.key === 'a') { e.preventDefault(); return false; }
            if (e.ctrlKey && e.key === 'c') { e.preventDefault(); return false; }
            if (e.ctrlKey && e.key === 'x') { e.preventDefault(); return false; }
            // Block PrintScreen key
            if (e.key === 'PrintScreen') { e.preventDefault(); showScreenshotWarning(); return false; }
        });

        // Block PrintScreen via keyup (keydown sometimes doesn't catch it)
        document.addEventListener('keyup', function(e) {
            if (e.key === 'PrintScreen') {
                showScreenshotWarning();
                // Clear clipboard to prevent paste of screenshot
                navigator.clipboard.writeText('').catch(() => {});
            }
        });

        // ============================================
        // WATERMARK OVERLAY - visible on screenshot
        // ============================================
        (function() {
            const userName = '<%= ValidationUtil.sanitizeHtml(currentUser.getName()) %>';
            const userId = '<%= currentUser.getId() %>';
            <%
                String realIp = request.getHeader("X-Forwarded-For");
                if (realIp == null || realIp.isEmpty()) {
                    realIp = request.getHeader("X-Real-IP");
                }
                if (realIp == null || realIp.isEmpty()) {
                    realIp = request.getRemoteAddr();
                }
                // X-Forwarded-For can contain multiple IPs, take the first (client)
                if (realIp != null && realIp.contains(",")) {
                    realIp = realIp.split(",")[0].trim();
                }
            %>
            const userIp = '<%= realIp %>';
            const userInfo = userName + ' | ID:' + userId + ' | ' + userIp;

            // Use canvas for a clean, lightweight watermark
            const canvas = document.createElement('canvas');
            const ctx = canvas.getContext('2d');

            function generateWatermark() {
                // Tile size for each watermark block
                const tileW = 320;
                const tileH = 150;
                canvas.width = tileW;
                canvas.height = tileH;

                ctx.clearRect(0, 0, tileW, tileH);
                ctx.save();
                ctx.translate(tileW / 2, tileH / 2);
                ctx.rotate(-20 * Math.PI / 180);

                // Main text
                ctx.font = '600 14px -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif';
                ctx.fillStyle = 'rgba(0, 0, 0, 0.06)';
                ctx.textAlign = 'center';
                ctx.textBaseline = 'middle';
                ctx.fillText('EXATUY', 0, -8);

                // User info line
                ctx.font = '400 9px -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif';
                ctx.fillStyle = 'rgba(0, 0, 0, 0.04)';
                ctx.fillText(userInfo, 0, 8);

                ctx.restore();

                // Create repeating pattern
                const overlay = document.getElementById('watermarkOverlay');
                if (!overlay) return;
                overlay.style.backgroundImage = 'url(' + canvas.toDataURL() + ')';
                overlay.style.backgroundRepeat = 'repeat';
            }

            const watermarkLayer = document.createElement('div');
            watermarkLayer.id = 'watermarkOverlay';
            watermarkLayer.style.cssText = 'position:fixed;top:0;left:0;width:100vw;height:100vh;z-index:9999;pointer-events:none;overflow:hidden;';
            document.body.appendChild(watermarkLayer);

            generateWatermark();

            window.addEventListener('resize', function() {
                // No need to regenerate - background-repeat handles it
            });
        })();

        // ============================================
        // SCREENSHOT DETECTION & WARNING
        // ============================================
        function showScreenshotWarning() {
            const overlay = document.createElement('div');
            overlay.id = 'screenshotBlocker';
            overlay.style.cssText = 'position:fixed;top:0;left:0;width:100vw;height:100vh;z-index:99999;background:rgba(0,0,0,0.95);display:flex;align-items:center;justify-content:center;flex-direction:column;color:#fff;font-family:sans-serif;';
            overlay.innerHTML = '<div style="text-align:center;"><div style="font-size:80px;margin-bottom:20px;">🚫</div><h1 style="font-size:28px;margin-bottom:10px;color:#dc3545;">Screenshot Diblokir!</h1><p style="font-size:16px;opacity:0.8;">Menangkap layar selama ujian tidak diizinkan.<br>Aktivitas ini tercatat.</p></div>';
            document.body.appendChild(overlay);

            // Log the attempt
            try {
                fetch('../ExamServlet?action=saveAnswer', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
                    body: 'action=logCheatAttempt&type=screenshot&submissionId=' + submissionId + '&csrfToken=' + document.getElementById('csrfToken').value
                });
            } catch(e) {}

            setTimeout(function() {
                overlay.remove();
            }, 3000);
        }

        // Detect Win+Shift+S (Windows Snip & Sketch)
        document.addEventListener('keydown', function(e) {
            if (e.shiftKey && e.metaKey) {
                showScreenshotWarning();
            }
        });

        // Detect visibility change (potential screenshot tool activation)
        document.addEventListener('visibilitychange', function() {
            if (document.hidden) {
                // When tab loses focus, show blank overlay so screenshot captures nothing useful
                const blurOverlay = document.createElement('div');
                blurOverlay.id = 'blurOverlay';
                blurOverlay.style.cssText = 'position:fixed;top:0;left:0;width:100vw;height:100vh;z-index:99998;background:#fff;display:flex;align-items:center;justify-content:center;color:#999;font-size:20px;font-family:sans-serif;';
                blurOverlay.innerHTML = '<div style="text-align:center;"><div style="font-size:48px;margin-bottom:15px;">🔒</div><p>Ujian terkunci saat tab tidak aktif</p></div>';
                document.body.appendChild(blurOverlay);
            } else {
                const existing = document.getElementById('blurOverlay');
                if (existing) existing.remove();
            }
        });

        // Detect DevTools opening via debugger
        (function() {
            function checkDevTools() {
                const devtools = /./;
                devtools.toString = function() {
                    this.opened = true;
                };
                const start = performance.now();
                debugger;
                const end = performance.now();
                if (end - start > 100 || devtools.opened) {
                    document.body.innerHTML = '<div style="display:flex;justify-content:center;align-items:center;height:100vh;flex-direction:column;background:#f8f9fa;"><h1 style="color:#dc3545;">Akses Ditolak</h1><p>DevTools terdeteksi. Halaman ini akan ditutup.</p></div>';
                    setTimeout(() => { window.close(); }, 1000);
                }
            }
            setInterval(checkDevTools, 1000);
        })();

        // Disable right-click on images
        document.addEventListener('contextmenu', function(e) {
            if (e.target.tagName === 'IMG') e.preventDefault();
        });

        // Clear console periodically
        setInterval(function() { try { console.clear(); } catch(e) {} }, 500);
    </script>
</body>
</html>
