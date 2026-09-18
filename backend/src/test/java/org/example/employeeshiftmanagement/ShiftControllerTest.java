package org.example.employeeshiftmanagement;

import org.example.employeeshiftmanagement.config.JwtConfig;
import org.example.employeeshiftmanagement.config.SecurityConfig;
import org.example.employeeshiftmanagement.controller.ShiftController;
import org.example.employeeshiftmanagement.model.Shift;
import org.example.employeeshiftmanagement.service.ShiftService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import java.time.LocalDate;
import java.time.LocalTime;
import java.util.List;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * The real SecurityConfig and JwtConfig are loaded, so these requests pass
 * through the same security rules as in production. TestTokens stands in for
 * a logged-in supervisor or employee without creating a signed token;
 * SecurityIntegrationTest covers real tokens over HTTP.
 */
@WebMvcTest(value = ShiftController.class, properties = TestProperties.JWT_SECRET_PROPERTY)
@Import({SecurityConfig.class, JwtConfig.class})
class ShiftControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockitoBean
    private ShiftService shiftService;

    private static Shift shift() {
        Shift shift = new Shift();
        shift.setId(1);
        shift.setDate(LocalDate.of(2026, 9, 14));
        shift.setStartTime(LocalTime.of(8, 0));
        shift.setEndTime(LocalTime.of(16, 0));
        shift.setPosition("Ταμείο");
        shift.setUser(TestUsers.employee());
        return shift;
    }

    @Test
    void theShiftListDoesNotLeakPasswordsAndKeepsItsWireFormat() throws Exception {
        when(shiftService.getAllShifts()).thenReturn(List.of(shift()));

        mockMvc.perform(get("/api/v1/shifts").with(TestTokens.supervisor()))
                .andExpect(status().isOk())
                // Shift.fromJson on the Flutter side reads these exact keys
                .andExpect(jsonPath("$[0].date").value("2026-09-14"))
                .andExpect(jsonPath("$[0].startTime").value("08:00:00"))
                .andExpect(jsonPath("$[0].position").value("Ταμείο"))
                .andExpect(jsonPath("$[0].user.name").value("Worker"))
                .andExpect(jsonPath("$[0].user.password").doesNotExist());
    }

    @Test
    void creatingAShiftTakesTheEmployeeFromThePathNotTheBody() throws Exception {
        when(shiftService.createShift(eq(7), any(Shift.class))).thenReturn(shift());

        mockMvc.perform(post("/api/v1/users/7/shifts")
                        .with(TestTokens.supervisor())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"date":"2026-09-14","startTime":"08:00","endTime":"16:00",
                                 "position":"Ταμείο","user":{"id":99}}
                                """))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.user.id").value(7))
                .andExpect(jsonPath("$.user.password").doesNotExist());
    }

    @Test
    void creatingAShiftRejectsAMissingDate() throws Exception {
        mockMvc.perform(post("/api/v1/users/7/shifts")
                        .with(TestTokens.supervisor())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"startTime":"08:00","endTime":"16:00","position":"Ταμείο"}
                                """))
                .andExpect(status().isBadRequest());
    }

    @Test
    void creatingAShiftRejectsEqualStartAndEndTimes() throws Exception {
        mockMvc.perform(post("/api/v1/users/7/shifts")
                        .with(TestTokens.supervisor())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"date":"2026-09-14","startTime":"08:00","endTime":"08:00",
                                 "position":"Ταμείο"}
                                """))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errors.endTime")
                        .value("End time must differ from start time"));

        verify(shiftService, never()).createShift(anyInt(), any());
    }

    @Test
    void creatingAShiftAcceptsAnOvernightShift() throws Exception {
        // End before start means the next day - decided 2026-09-18 (F15).
        when(shiftService.createShift(eq(7), any(Shift.class))).thenReturn(shift());

        mockMvc.perform(post("/api/v1/users/7/shifts")
                        .with(TestTokens.supervisor())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"date":"2026-09-14","startTime":"22:00","endTime":"06:00",
                                 "position":"Ταμείο"}
                                """))
                .andExpect(status().isCreated());
    }

    @Test
    void creatingAShiftRejectsAPositionLongerThanTheColumn() throws Exception {
        mockMvc.perform(post("/api/v1/users/7/shifts")
                        .with(TestTokens.supervisor())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"date":"2026-09-14","startTime":"08:00","endTime":"16:00",
                                 "position":"%s"}
                                """.formatted("a".repeat(256))))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errors.position")
                        .value("Position must be at most 255 characters"));

        verify(shiftService, never()).createShift(anyInt(), any());
    }

    @Test
    void updatingAShiftRejectsEqualStartAndEndTimes() throws Exception {
        // Create and update share ShiftRequest, so both get the rule.
        mockMvc.perform(put("/api/v1/shifts/1")
                        .with(TestTokens.supervisor())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"date":"2026-09-14","startTime":"08:00","endTime":"08:00",
                                 "position":"Ταμείο"}
                                """))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errors.endTime").exists());

        verify(shiftService, never()).updateShift(anyInt(), any());
    }

    @Test
    void theShiftListWithoutATokenIsUnauthorized() throws Exception {
        mockMvc.perform(get("/api/v1/shifts"))
                .andExpect(status().isUnauthorized());

        verify(shiftService, never()).getAllShifts();
    }

    @Test
    void anEmployeeCannotSeeEveryonesShifts() throws Exception {
        mockMvc.perform(get("/api/v1/shifts").with(TestTokens.employee()))
                .andExpect(status().isForbidden());

        verify(shiftService, never()).getAllShifts();
    }

    @Test
    void anEmployeeCannotAssignShifts() throws Exception {
        mockMvc.perform(post("/api/v1/users/7/shifts")
                        .with(TestTokens.employee())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"date":"2026-09-14","startTime":"08:00","endTime":"16:00","position":"Ταμείο"}
                                """))
                .andExpect(status().isForbidden());

        verify(shiftService, never()).createShift(anyInt(), any());
    }

    @Test
    void anEmployeeCanReadTheirOwnShifts() throws Exception {
        when(shiftService.getShiftsByEmployee(7)).thenReturn(List.of(shift()));

        mockMvc.perform(get("/api/v1/shifts/users/7").with(TestTokens.employee()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].position").value("Ταμείο"));
    }

    @Test
    void anEmployeeCannotReadSomeoneElsesShifts() throws Exception {
        mockMvc.perform(get("/api/v1/shifts/users/9").with(TestTokens.employee()))
                .andExpect(status().isForbidden());

        verify(shiftService, never()).getShiftsByEmployee(anyInt());
    }

    @Test
    void anEmployeeCanReadTheirOwnSchedule() throws Exception {
        when(shiftService.getSchedule(eq(7), any(LocalDate.class), any(LocalDate.class)))
                .thenReturn(List.of(shift()));

        mockMvc.perform(get("/api/v1/users/7/schedule")
                        .param("start", "2026-09-01")
                        .param("end", "2026-09-30")
                        .with(TestTokens.employee()))
                .andExpect(status().isOk());
    }

    @Test
    void anEmployeeCannotReadSomeoneElsesSchedule() throws Exception {
        mockMvc.perform(get("/api/v1/users/9/schedule")
                        .param("start", "2026-09-01")
                        .param("end", "2026-09-30")
                        .with(TestTokens.employee()))
                .andExpect(status().isForbidden());

        verify(shiftService, never()).getSchedule(anyInt(), any(), any());
    }

    @Test
    void aSupervisorCanReadAnEmployeesSchedule() throws Exception {
        when(shiftService.getSchedule(eq(7), any(LocalDate.class), any(LocalDate.class)))
                .thenReturn(List.of(shift()));

        mockMvc.perform(get("/api/v1/users/7/schedule")
                        .param("start", "2026-09-01")
                        .param("end", "2026-09-30")
                        .with(TestTokens.supervisor()))
                .andExpect(status().isOk());
    }
}
