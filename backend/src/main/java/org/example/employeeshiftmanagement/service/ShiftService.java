package org.example.employeeshiftmanagement.service;

import org.example.employeeshiftmanagement.exception.ConflictException;
import org.example.employeeshiftmanagement.exception.ResourceNotFoundException;
import org.example.employeeshiftmanagement.model.Shift;
import org.example.employeeshiftmanagement.model.User;
import org.example.employeeshiftmanagement.repository.ShiftRepository;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;

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

    public ShiftService(ShiftRepository shiftRepository, UserService userService) {
        this.shiftRepository = shiftRepository;
        this.userService = userService;
    }

    public Shift createShift(Integer userId,Shift shift){
        User user = userService.findUserById(userId);
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

    public Shift updateShift(Integer shiftId,Shift shiftDetails){
        Shift existingShift = shiftRepository.findById(shiftId)
                .orElseThrow(()-> new ResourceNotFoundException("Shift not found with id "+shiftId));

        // Checked before the fields change, so the query below never sees a
        // half-edited copy of this shift. getId() on the lazy user is free:
        // Hibernate already knows the id without loading the user.
        rejectOverlaps(existingShift.getUser().getId(), shiftId, shiftDetails);

        existingShift.setDate(shiftDetails.getDate());
        existingShift.setStartTime(shiftDetails.getStartTime());
        existingShift.setEndTime(shiftDetails.getEndTime());
        existingShift.setPosition(shiftDetails.getPosition());

        return shiftRepository.save(existingShift);
    }

    public void deleteShift(Integer shiftId){
        if(!shiftRepository.existsById(shiftId)){
            throw new ResourceNotFoundException("Shift not found with id "+shiftId);
        }
        shiftRepository.deleteById(shiftId);
    }

    public List<Shift> getSchedule(Integer userId, LocalDate start, LocalDate end){
        userService.findUserById(userId);
        return shiftRepository.findByUserIdAndDateBetween(userId, start, end, CHRONOLOGICAL);
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
