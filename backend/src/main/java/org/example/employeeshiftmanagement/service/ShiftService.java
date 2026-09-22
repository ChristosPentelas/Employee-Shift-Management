package org.example.employeeshiftmanagement.service;

import org.example.employeeshiftmanagement.exception.ResourceNotFoundException;
import org.example.employeeshiftmanagement.model.Shift;
import org.example.employeeshiftmanagement.model.User;
import org.example.employeeshiftmanagement.repository.ShiftRepository;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;

import java.time.LocalDate;
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
}
