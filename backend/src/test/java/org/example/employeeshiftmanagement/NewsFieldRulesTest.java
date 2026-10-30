package org.example.employeeshiftmanagement;

import org.example.employeeshiftmanagement.model.NewsType;
import org.example.employeeshiftmanagement.validation.NewsFieldRules;
import org.junit.jupiter.api.Test;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * B74: which extra field each news type may have. Plain JUnit - the rule is
 * a function of three values, so no Spring context is needed. Both POST
 * (through ValidNewsFields) and PUT (through NewsItemService) use it.
 */
class NewsFieldRulesTest {

    private static final LocalDateTime DEADLINE = LocalDateTime.of(2026, 11, 30, 0, 0);

    @Test
    void eachTypeMayHaveItsOwnExtra() {
        assertTrue(NewsFieldRules.mismatches(NewsType.TASK, DEADLINE, null).isEmpty());
        assertTrue(NewsFieldRules.mismatches(NewsType.GOAL, null, 50).isEmpty());
    }

    // Decided 2026-10-31: the extras are allowed, not required.
    @Test
    void everyTypeMayHaveNoExtra() {
        for (NewsType type : NewsType.values()) {
            assertTrue(NewsFieldRules.mismatches(type, null, null).isEmpty(), type.name());
        }
    }

    @Test
    void aTaskWithATargetValueIsToldAboutTheTarget() {
        assertEquals(Map.of("targetValue", "Only a goal can have a target value"),
                NewsFieldRules.mismatches(NewsType.TASK, DEADLINE, 50));
    }

    @Test
    void aGoalWithADeadlineIsToldAboutTheDeadline() {
        assertEquals(Map.of("deadline", "Only a task can have a deadline"),
                NewsFieldRules.mismatches(NewsType.GOAL, DEADLINE, 50));
    }

    @Test
    void anAnnouncementWithBothIsToldAboutBothInFieldOrder() {
        Map<String, String> mismatches =
                NewsFieldRules.mismatches(NewsType.ANNOUNCEMENT, DEADLINE, 50);

        assertEquals(List.of("deadline", "targetValue"), List.copyOf(mismatches.keySet()));
    }

    // A missing type is @NotNull's job; answering here too would give the
    // client two errors for one mistake.
    @Test
    void aMissingTypeIsLeftToNotNull() {
        assertTrue(NewsFieldRules.mismatches(null, DEADLINE, 50).isEmpty());
    }
}
