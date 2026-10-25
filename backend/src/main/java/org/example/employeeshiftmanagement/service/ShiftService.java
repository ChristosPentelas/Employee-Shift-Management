package org.example.employeeshiftmanagement.service;

import org.example.employeeshiftmanagement.exception.ConflictException;
import org.example.employeeshiftmanagement.exception.ProblemTypes;
import org.example.employeeshiftmanagement.exception.ResourceNotFoundException;
import org.example.employeeshiftmanagement.model.LeaveStatus;
import org.example.employeeshiftmanagement.model.Shift;
import org.example.employeeshiftmanagement.model.User;
import org.example.employeeshiftmanagement.repository.LeaveRequestRepository;
import org.example.employeeshiftmanagement.repository.ShiftRepository;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Isolation;
import org.springframework.transaction.annotation.Transactional;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;

@Service
public class ShiftService {

    /** Calendar order: by day, then by start time. */
    private static final Sort CHRONOLOGICAL =
            Sort.by(Sort.Order.asc("date"), Sort.Order.asc("startTime"), Sort.Order.asc("id"));

    /** One employee's shift history: the latest first. */
    private static final Sort LATEST_FIRST =
            Sort.by(Sort.Order.desc("date"), Sort.Order.desc("startTime"), Sort.Order.desc("id"));

    private final ShiftRepository shiftRepository;
    private final UserService userService;
    // The repository, not LeaveRequestService: approving leave will remove
    // shifts (B31 step 31c), so that service will need this one, and two
    // services that each need the other cannot be built.
    private final LeaveRequestRepository leaveRequestRepository;

    public ShiftService(ShiftRepository shiftRepository, UserService userService,
                        LeaveRequestRepository leaveRequestRepository) {
        this.shiftRepository = shiftRepository;
        this.userService = userService;
        this.leaveRequestRepository = leaveRequestRepository;
    }

    /*
     * createShift and updateShift both check for overlaps, then save. Two
     * requests for the same employee at the same moment could both check
     * before either saves, and both pass (B30). So each first locks the
     * employee's row: the second request waits at that lock until the first
     * commits, and only then runs its own check.
     *
     * READ_COMMITTED makes the check after the wait see what the first
     * request saved. Under MySQL's default, REPEATABLE READ, every plain
     * SELECT in a transaction reads one snapshot, taken at the first one - in
     * updateShift that is loading the shift, before the wait - so the check
     * would still miss it.
     */
    @Transactional(isolation = Isolation.READ_COMMITTED)
    public Shift createShift(Integer userId,Shift shift){
        // First, before any read the overlap check depends on.
        User user = userService.findLockedUserById(userId);
        rejectLeaveDays(userId, shift);
        rejectOverlaps(userId, null, shift);
        shift.setUser(user);
        return shiftRepository.save(shift);
    }

    /** Everyone's shifts from start to end, both days included. The controller has checked the range. */
    public List<Shift> getAllShifts(LocalDate start, LocalDate end){
        return shiftRepository.findByDateBetween(start, end, CHRONOLOGICAL);
    }

    public Page<Shift> getShiftsByEmployee(Integer userId, Pageable pageable){
        return shiftRepository.findByUserId(userId, Paging.withSort(pageable, LATEST_FIRST));
    }

    @Transactional(isolation = Isolation.READ_COMMITTED)
    public Shift updateShift(Integer shiftId,Shift shiftDetails){
        Shift existingShift = shiftRepository.findById(shiftId)
                .orElseThrow(()-> new ResourceNotFoundException("Shift", shiftId));

        Integer existingUserId = existingShift.getUser().getId();
        // Also loads the user the response shows: Hibernate fills the shift's
        // lazy user with this one, the same row in the same session, so
        // findById needs no @EntityGraph (B28).
        userService.findLockedUserById(existingUserId);

        // Checked before the fields change, so the queries below never see a
        // half-edited copy of this shift. getId() on the lazy user is free:
        // Hibernate already knows the id without loading the user.
        rejectLeaveDays(existingUserId, shiftDetails);
        rejectOverlaps(existingUserId, shiftId, shiftDetails);

        existingShift.setDate(shiftDetails.getDate());
        existingShift.setStartTime(shiftDetails.getStartTime());
        existingShift.setEndTime(shiftDetails.getEndTime());
        existingShift.setPosition(shiftDetails.getPosition());

        return shiftRepository.save(existingShift);
    }

    @Transactional
    public void deleteShift(Integer shiftId){
        if(!shiftRepository.existsById(shiftId)){
            throw new ResourceNotFoundException("Shift", shiftId);
        }
        shiftRepository.deleteById(shiftId);
    }

    /**
     * Removes the employee's shifts from start to end, both days included,
     * and answers how many there were. Called when their leave is approved
     * (B31): a shift belongs to its date, as in rejectLeaveDays, so a night
     * shift the evening before the leave stays.
     *
     * The caller must hold the employee's lock (UserService.findLockedUserById),
     * as createShift does, so no shift can be added between this and the commit.
     */
    @Transactional
    public int removeShiftsDuring(Integer userId, LocalDate start, LocalDate end) {
        return shiftRepository.deleteByUserIdAndDateBetween(userId, start, end);
    }

    public List<Shift> getSchedule(Integer userId, LocalDate start, LocalDate end){
        userService.findUserById(userId);
        return shiftRepository.findByUserIdAndDateBetween(userId, start, end, CHRONOLOGICAL);
    }

    /**
     * No shift on a day the employee has approved leave (B31): throws
     * ConflictException, with a problem type so the app can say why.
     *
     * Rules decided 2026-10-25: only APPROVED leave counts - a PENDING request
     * is still only a request. And a shift belongs to its date: a Mon
     * 22:00-06:00 shift is refused by leave on Monday, not by leave starting
     * on Tuesday, even though it ends then.
     *
     * The caller holds the employee's lock, as for rejectOverlaps.
     */
    private void rejectLeaveDays(Integer userId, Shift shift) {
        if (leaveRequestRepository.existsCovering(userId, LeaveStatus.APPROVED, shift.getDate())) {
            throw new ConflictException(ProblemTypes.EMPLOYEE_ON_LEAVE,
                    "On approved leave on " + shift.getDate());
        }
    }

    /**
     * The employee may not be in two places at once (F30): throws
     * ConflictException if one of their shifts overlaps this one.
     *
     * ignoredShiftId is the shift being edited (null on create), so an update
     * never clashes with its own old times.
     *
     * Only the day before and the day after can reach this shift: a shift is
     * shorter than 24 hours, so the furthest one can spill over is into the
     * next morning. Yesterday's night shift can run into today, and today's
     * night shift into tomorrow's early one.
     *
     * Existing shifts are not re-checked: two that overlapped before this rule
     * stay, but editing either one is refused until the clash is removed.
     *
     * The caller must already hold the employee's lock
     * (UserService.findLockedUserById); otherwise two requests can both pass
     * this check at the same moment (B30).
     */
    private void rejectOverlaps(Integer userId, Integer ignoredShiftId, Shift shift) {
        LocalDateTime start = startOf(shift);
        LocalDateTime end = endOf(shift);

        List<Shift> nearby = shiftRepository.findByUserIdAndDateBetween(
                userId, shift.getDate().minusDays(1), shift.getDate().plusDays(1), CHRONOLOGICAL);

        for (Shift other : nearby) {
            if (other.getId().equals(ignoredShiftId)) {
                continue;
            }
            // Each shift is [start, end): the end moment is not part of it, so
            // one shift ending at 13:00 and the next starting at 13:00 is a
            // handover, not an overlap.
            if (start.isBefore(endOf(other)) && startOf(other).isBefore(end)) {
                throw new ConflictException("Overlaps shift " + other.getId() + " on " + other.getDate()
                        + ", " + other.getStartTime() + "-" + other.getEndTime());
            }
        }
    }

    private static LocalDateTime startOf(Shift shift) {
        return shift.getDate().atTime(shift.getStartTime());
    }

    /** An end before the start is the next morning - an overnight shift (F15). */
    private static LocalDateTime endOf(Shift shift) {
        LocalDate endDate = shift.getEndTime().isBefore(shift.getStartTime())
                ? shift.getDate().plusDays(1)
                : shift.getDate();
        return endDate.atTime(shift.getEndTime());
    }
}
