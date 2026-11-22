package com.examora.util;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;

/**
 * PRD #28 — pemetaan role Exatuy ke role AI &amp; DS service.
 */
class RoleMapperTest {

    @Test
    @DisplayName("role peserta/orangtua dipetakan ke student")
    void pesertaDanOrangTuaMenjadiStudent() {
        assertEquals("student", RoleMapper.toAiRole("peserta"));
        assertEquals("student", RoleMapper.toAiRole("PESERTA"));
        assertEquals("student", RoleMapper.toAiRole("orangtua"));
        assertEquals("student", RoleMapper.toAiRole(" siswa "));
    }

    @Test
    @DisplayName("role admin/teacher/owner dipetakan ke teacher")
    void adminDanPengajarMenjadiTeacher() {
        assertEquals("teacher", RoleMapper.toAiRole("admin"));
        assertEquals("teacher", RoleMapper.toAiRole("Teacher"));
        assertEquals("teacher", RoleMapper.toAiRole("owner"));
        assertEquals("teacher", RoleMapper.toAiRole("pengajar"));
    }

    @Test
    @DisplayName("role tidak dikenal atau null jatuh ke student (fail-safe)")
    void roleTidakDikenalJatuhKeStudent() {
        assertEquals("student", RoleMapper.toAiRole(null));
        assertEquals("student", RoleMapper.toAiRole(""));
        assertEquals("student", RoleMapper.toAiRole("superuser"));
    }

    @Test
    @DisplayName("pemetaan balik AI -> Exatuy")
    void pemetaanBalik() {
        assertEquals("admin", RoleMapper.fromAiRole("teacher"));
        assertEquals("peserta", RoleMapper.fromAiRole("student"));
        assertEquals("peserta", RoleMapper.fromAiRole(null));
    }
}
