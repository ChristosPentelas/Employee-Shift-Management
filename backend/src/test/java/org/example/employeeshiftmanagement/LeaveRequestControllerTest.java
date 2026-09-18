package org.example.employeeshiftmanagement;

import org.example.employeeshiftmanagement.config.JwtConfig;
import org.example.employeeshiftmanagement.config.SecurityConfig;
import org.example.employeeshiftmanagement.controller.LeaveRequestController;
import org.example.employeeshiftmanagement.model.LeaveRequest;
import org.example.employeeshiftmanagement.model.LeaveStatus;
import org.example.employeeshiftmanagement.service.LeaveRequestService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import java.time.LocalDate;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.mockito.ArgumentCaptor.forClass;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(value = LeaveRequestController.class, properties = TestProperties.JWT_SECRET_PROPERTY)
@Import({SecurityConfig.class, JwtConfig.class})
class LeaveRequestControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockitoBean
    private LeaveRequestService leaveRequestService;

    private static LeaveRequest leaveRequest() {
        LeaveRequest leave = new LeaveRequest();
        leave.setId(1);
        leave.setStartDate(LocalDate.of(2026, 10, 1));
        leave.setEndDate(LocalDate.of(2026, 10, 5));
        leave.setReason("Surgery");
        leave.setStatus(LeaveStatus.PENDING);
        leave.setUser(TestUsers.employee());
        return leave;
    }

    @Test
    void theLeaveListDoesNotLeakPasswords() throws Exception {
        when(leaveRequestService.getAllLeaveRequests()).thenReturn(List.of(leaveRequest()));

        mockMvc.perform(get("/api/v1/leaves").with(TestTokens.supervisor()))
                .andExpect(status().isOk())
                // LeaveRequest.fromJson on the Flutter side reads json['user']
                .andExpect(jsonPath("$[0].status").value("PENDING"))
                .andExpect(jsonPath("$[0].user.name").value("Worker"))
                .andExpect(jsonPath("$[0].user.password").doesNotExist());
    }

    @Test
    void creatingALeaveIsFiledForTheCallerNotTheUserIdSent() throws Exception {
        when(leaveRequestService.createLeaveRequest(eq(7), any(LeaveRequest.class)))
                .thenReturn(leaveRequest());

        mockMvc.perform(post("/api/v1/leaves")
                        .with(TestTokens.employee())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"userId":99,"startDate":"2026-10-01","endDate":"2026-10-05",
                                 "reason":"Surgery","status":"APPROVED","id":99}
                                """))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.user.password").doesNotExist());

        // Filed for the caller (7), although the body named user 99 (F1 step 7b).
        var captor = forClass(LeaveRequest.class);
        verify(leaveRequestService).createLeaveRequest(eq(7), captor.capture());

        assertNull(captor.getValue().getId(),
                "A client must not be able to choose the row id");
        // Not null: LeaveRequest initialises status to PENDING at the field.
        // The point is that the APPROVED the client sent never got near it.
        assertEquals(LeaveStatus.PENDING, captor.getValue().getStatus(),
                "A client must not be able to file an already-APPROVED request");
    }

    @Test
    void creatingALeaveRejectsAMissingStartDate() throws Exception {
        mockMvc.perform(post("/api/v1/leaves")
                        .with(TestTokens.employee())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"endDate":"2026-10-05","reason":"Surgery"}
                                """))
                .andExpect(status().isBadRequest());
    }

    @Test
    void creatingALeaveRejectsAnEndDateBeforeTheStartDate() throws Exception {
        mockMvc.perform(post("/api/v1/leaves")
                        .with(TestTokens.employee())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"startDate":"2026-10-10","endDate":"2026-10-01","reason":"Surgery"}
                                """))
                .andExpect(status().isBadRequest())
                // Reported on the field, not as a nameless "Validation failed"
                .andExpect(jsonPath("$.errors.endDate")
                        .value("End date must not be before start date"));

        verify(leaveRequestService, never()).createLeaveRequest(anyInt(), any());
    }

    @Test
    void creatingALeaveAcceptsASingleDay() throws Exception {
        when(leaveRequestService.createLeaveRequest(eq(7), any(LeaveRequest.class)))
                .thenReturn(leaveRequest());

        mockMvc.perform(post("/api/v1/leaves")
                        .with(TestTokens.employee())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"startDate":"2026-10-01","endDate":"2026-10-01","reason":"Surgery"}
                                """))
                .andExpect(status().isCreated());
    }

    @Test
    void creatingALeaveRejectsAReasonLongerThanTheColumn() throws Exception {
        // 256 characters do not fit VARCHAR(255): a 400, not a 500 from MySQL.
        mockMvc.perform(post("/api/v1/leaves")
                        .with(TestTokens.employee())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"startDate":"2026-10-01","endDate":"2026-10-05","reason":"%s"}
                                """.formatted("a".repeat(256))))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errors.reason")
                        .value("Reason must be at most 255 characters"));

        verify(leaveRequestService, never()).createLeaveRequest(anyInt(), any());
    }

    @Test
    void theLeaveListWithoutATokenIsUnauthorized() throws Exception {
        // Leave reasons are medical and family information (see F7).
        mockMvc.perform(get("/api/v1/leaves"))
                .andExpect(status().isUnauthorized());

        verify(leaveRequestService, never()).getAllLeaveRequests();
    }

    @Test
    void aSupervisorCanApproveALeave() throws Exception {
        LeaveRequest approved = leaveRequest();
        approved.setStatus(LeaveStatus.APPROVED);
        when(leaveRequestService.updateLeaveRequest(1, LeaveStatus.APPROVED)).thenReturn(approved);

        mockMvc.perform(put("/api/v1/leaves/1/status")
                        .param("status", "APPROVED")
                        .with(TestTokens.supervisor()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("APPROVED"));
    }

    @Test
    void anEmployeeCannotApproveALeave() throws Exception {
        mockMvc.perform(put("/api/v1/leaves/1/status")
                        .param("status", "APPROVED")
                        .with(TestTokens.employee()))
                .andExpect(status().isForbidden());

        verify(leaveRequestService, never()).updateLeaveRequest(anyInt(), any());
    }

    @Test
    void anEmployeeCanReadTheirOwnLeaveList() throws Exception {
        when(leaveRequestService.getLeavesByUser(7)).thenReturn(List.of(leaveRequest()));

        mockMvc.perform(get("/api/v1/leaves/users/7/leaves").with(TestTokens.employee()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].status").value("PENDING"));
    }

    @Test
    void anEmployeeCannotReadSomeoneElsesLeaveList() throws Exception {
        // Leave reasons are medical and family information (F7).
        mockMvc.perform(get("/api/v1/leaves/users/9/leaves").with(TestTokens.employee()))
                .andExpect(status().isForbidden());

        verify(leaveRequestService, never()).getLeavesByUser(anyInt());
    }

    @Test
    void aSupervisorCanReadAnEmployeesLeaveList() throws Exception {
        when(leaveRequestService.getLeavesByUser(7)).thenReturn(List.of(leaveRequest()));

        mockMvc.perform(get("/api/v1/leaves/users/7/leaves").with(TestTokens.supervisor()))
                .andExpect(status().isOk());
    }

    @Test
    void anEmployeeCannotReadEveryonesLeave() throws Exception {
        // The F7 fix: leave reasons are health and family information, and an
        // employee has no business receiving colleagues' requests at all.
        mockMvc.perform(get("/api/v1/leaves").with(TestTokens.employee()))
                .andExpect(status().isForbidden());

        verify(leaveRequestService, never()).getAllLeaveRequests();
    }
}
