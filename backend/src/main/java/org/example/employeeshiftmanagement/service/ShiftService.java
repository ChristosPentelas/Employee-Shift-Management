package org.example.employeeshiftmanagement.service;

import org.example.employeeshiftmanagement.model.Shift;
import org.example.employeeshiftmanagement.model.User;
import org.example.employeeshiftmanagement.repository.ShiftRepository;
import org.springframework.stereotype.Service;

import java.time.LocalDate;
import java.util.List;

@Service
public class ShiftService {

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

    public List<Shift> getAllShifts(){
        return shiftRepository.findAll();
    }

    public List<Shift> getShiftsByEmployee(Integer userId){
        return shiftRepository.findByUserId(userId);
    }

    public Shift updateShift(Integer shiftId,Shift shiftDetails){
        Shift existingShift = shiftRepository.findById(shiftId)
                .orElseThrow(()-> new RuntimeException("Shift not found with id "+shiftId));

        existingShift.setDate(shiftDetails.getDate());
        existingShift.setStartTime(shiftDetails.getStartTime());
        existingShift.setEndTime(shiftDetails.getEndTime());
        existingShift.setPosition(shiftDetails.getPosition());

        return shiftRepository.save(existingShift);
    }

    public void deleteShift(Integer shiftId){
        if(!shiftRepository.existsById(shiftId)){
            throw new RuntimeException("Shift not found with id "+shiftId);
        }
        shiftRepository.deleteById(shiftId);
    }

    public List<Shift> getSchedule(Integer userId, LocalDate start, LocalDate end){
        userService.findUserById(userId);
        return shiftRepository.findByUserIdAndDateBetweenOrderByDateAsc(userId, start, end);
    }
}
