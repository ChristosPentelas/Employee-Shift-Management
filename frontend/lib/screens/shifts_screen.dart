import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/shift_model.dart';
import '../services/api_service.dart';
import '../utils/session.dart';
import '../models/user_model.dart';

class ShiftsScreen extends StatefulWidget {
  @override
  _ShiftsScreenState createState() => _ShiftsScreenState();
}

class _ShiftsScreenState extends State<ShiftsScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  List<Shift> _allShifts = [];
  bool _isLoading = true;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _loadShifts();
  }

  void _loadShifts() async {
    setState(() {
      _isLoading = true;
    });

    try {

      DateTime firstDayOfMonth = DateTime(_focusedDay.year, _focusedDay.month, 1);
      DateTime lastDayOfMonth = DateTime(_focusedDay.year, _focusedDay.month + 1, 0);

      List<Shift> shifts;
      if (Session.isSupervisor()) {
        shifts = await _apiService.getAllShifts();
      } else {
        shifts = await _apiService.getFilteredShifts(firstDayOfMonth, lastDayOfMonth);
      }

      setState(() {

        _allShifts = List.from(shifts);
        _isLoading = false;
        _selectedDay = null;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }

  }

  List<Shift> _getShiftsForDay(DateTime day) {
    return _allShifts.where((shift) {
      return shift.date.year == day.year &&
          shift.date.month == day.month &&
          shift.date.day == day.day;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Πρόγραμμα Βαρδιών"), backgroundColor: Colors.teal),
      body: _isLoading
        ? Center(child: CircularProgressIndicator())
        : Column(
            children: [
              TableCalendar(
                key: ValueKey(_allShifts.length),
                firstDay: DateTime.utc(2024, 1, 1),
                lastDay: DateTime.utc(2030, 12, 31),
                focusedDay: _focusedDay,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                onDaySelected: (selectedDay, focusDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusDay;
                  });
                },
                eventLoader: _getShiftsForDay,
                calendarStyle: CalendarStyle(
                  todayDecoration: BoxDecoration(color: Colors.teal, shape: BoxShape.circle),
                  selectedDecoration: BoxDecoration(color: Colors.teal, shape: BoxShape.circle),
                  markerDecoration: BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
              ),
                onDayLongPressed: (selectedDay, focusedDay) {
                  if (Session.isSupervisor()) {
                    _showAssignShiftDialog(selectedDay);
                  }
                },
                onPageChanged: (focusedDay) {
                  _focusedDay = focusedDay;
                  _loadShifts();
                },
              ),
              const SizedBox(height: 10),
              Expanded(child: _buildShiftList(),),
            ],
      ),
    );
  }

  Widget _buildShiftList() {
    final shifts = _selectedDay != null ? _getShiftsForDay(_selectedDay!) : [];

    if (shifts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 50, color: Colors.grey),
            Text("Καμία βάρδια για αυτη τη μέρα"),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: shifts.length,
      itemBuilder: (context, index) {
        final s = shifts[index];
        return Card(
          margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Padding(
            padding: EdgeInsets.all(10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.position, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      SizedBox(height: 5),
                      Row(
                        children: [
                          Icon(Icons.access_time, size: 16, color: Colors.grey),
                          SizedBox(width: 4),
                          Text("${s.startTime} - ${s.endTime}"),
                        ],
                      ),
                      if (s.assignedUser != null)
                        Text("Υπάλληλος: ${s.assignedUser!.name}", style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),

                if (Session.isSupervisor())
                  IconButton(
                    icon: Icon(Icons.delete_sweep, color: Colors.redAccent),
                    onPressed: () => _confirmDelete(s.id),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAssignShiftDialog(DateTime selectedDate) async {
    List<User> employees = await _apiService.getAllEmployees();
    User? selectedEmployee;
    final _positionController = TextEditingController();
    final _startController = TextEditingController(text: "08:00");
    final _endController = TextEditingController(text: "16:00");

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text("Ανάθεση: ${selectedDate.day}/${selectedDate.month}"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButton<User>(
                  isExpanded: true,
                  hint: Text("Επιλογή Υπαλλήλου"),
                  value: selectedEmployee,
                  items: employees.map((u) => DropdownMenuItem(
                    value: u,
                    child: Text(u.name),
                  )).toList(),
                  onChanged: (val) => setDialogState(() => selectedEmployee = val),
                ),
                TextField(controller: _positionController, decoration: InputDecoration(labelText: "Θέση εργασίας")),
                TextField(controller: _startController, decoration: InputDecoration(labelText: "Έναρξη (HH:mm)")),
                TextField(controller: _endController, decoration: InputDecoration(labelText: "Λήξη (HH:mm)")),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text("Ακύρωση")),
            ElevatedButton(
              onPressed: (selectedEmployee == null) ? null : () async {
                Shift newShift = Shift(
                  id: 0,
                  date: selectedDate,
                  startTime: _startController.text,
                  endTime: _endController.text,
                  position: _positionController.text,
                );

                bool success = await _apiService.assignShift(newShift, selectedEmployee!.id);
                if (success) {
                  Navigator.pop(context);
                  _loadShifts();
                }
              },
              child: Text("Αποθήκευση"),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(int shiftId) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text("Διαγραφή Βάρδιας"),
        content: Text("Είστε σίγουροι ότι θέλετε να διαγράψετε αυτή τη βάρδια;"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("Ακύρωση")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.of(dialogContext, rootNavigator: true).pop();
              bool success = await _apiService.deleteShift(shiftId);
              if (success) {
                _loadShifts();
                setState(() {
                  _selectedDay = null;
                });
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Η βάρδια διαγράφηκε")));
              }
            },
            child: Text("Διαγραφή", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}