package com.examora.util;

/**
 * Pemetaan role antara aplikasi Java Exatuy dan AI &amp; DS service (FastAPI).
 *
 * PRD P2 #28: role Exatuy (`peserta`, `admin`, `teacher`, `owner`, `orangtua`)
 * dipetakan ke dua role yang dikenal service AI (`student`, `teacher`) agar
 * kontrak API tetap sederhana dan tidak membocorkan struktur role internal.
 */
public final class RoleMapper {

    /** Role yang tersedia di service AI. */
    public static final String AI_STUDENT = "student";
    public static final String AI_TEACHER = "teacher";

    private RoleMapper() {
    }

    /**
     * Exatuy -&gt; AI service.
     *
     * <ul>
     *   <li>peserta, orangtua -&gt; student (orang tua hanya melihat data anak)</li>
     *   <li>admin, teacher, owner -&gt; teacher (boleh akses analitik &amp; rekap)</li>
     *   <li>null / tidak dikenal -&gt; student (hak paling rendah, fail-safe)</li>
     * </ul>
     */
    public static String toAiRole(String exatuyRole) {
        if (exatuyRole == null) {
            return AI_STUDENT;
        }
        switch (exatuyRole.trim().toLowerCase()) {
            case "admin":
            case "teacher":
            case "pengajar":
            case "owner":
                return AI_TEACHER;
            case "peserta":
            case "orangtua":
            case "siswa":
            case "student":
                return AI_STUDENT;
            default:
                return AI_STUDENT;
        }
    }

    /** AI service -&gt; Exatuy (kebalikan pemetaan, untuk audit/log). */
    public static String fromAiRole(String aiRole) {
        if (AI_TEACHER.equalsIgnoreCase(safeTrim(aiRole))) {
            return "admin";
        }
        return "peserta";
    }

    private static String safeTrim(String value) {
        return value == null ? "" : value.trim();
    }
}
