package org.example.employeeshiftmanagement;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;

@SpringBootTest(properties = {TestProperties.JWT_SECRET_PROPERTY, TestProperties.NO_SUPERVISOR_SEEDING})
@Import(TestcontainersConfiguration.class)
class EmployeeShiftManagementApplicationTests {

    @Test
    void contextLoads() {
    }

}
