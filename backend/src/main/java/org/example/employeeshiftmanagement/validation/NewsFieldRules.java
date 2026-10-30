package org.example.employeeshiftmanagement.validation;

import org.example.employeeshiftmanagement.model.NewsType;

import java.time.LocalDateTime;
import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.Map;

/**
 * Which extra field each news type may have (B74): only a TASK a deadline and
 * only a GOAL a target value. Neither is required - decided 2026-10-31.
 *
 * In one place because two callers need it: ValidNewsFieldsValidator for a
 * new post, where the type is in the request, and NewsItemService for an
 * edit, where it is only in the stored item.
 */
public final class NewsFieldRules {

    private NewsFieldRules() {
        // Only the static method below; nothing to create.
    }

    /**
     * Each extra that does not fit [type], as field name to message, in field
     * order; empty when everything fits. A null type gives an empty map:
     * a missing type is @NotNull's job.
     */
    public static Map<String, String> mismatches(NewsType type, LocalDateTime deadline,
                                                 Integer targetValue) {
        Map<String, String> mismatches = new LinkedHashMap<>();
        if (type == null) {
            return mismatches;
        }
        if (deadline != null && type != NewsType.TASK) {
            mismatches.put("deadline", "Only a task can have a deadline");
        }
        if (targetValue != null && type != NewsType.GOAL) {
            mismatches.put("targetValue", "Only a goal can have a target value");
        }
        return Collections.unmodifiableMap(mismatches);
    }
}
