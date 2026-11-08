import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/shift_model.dart';
import '../services/api_service.dart';
import '../services/api_providers.dart';
import '../state/auth_session.dart';
import '../models/user_model.dart';
import '../widgets/assign_shift_dialog.dart';

class ShiftsScreen extends ConsumerStatefulWidget {
  // Tests pass an ApiService with a fake client; the app uses the default.
  final ApiService? apiService;

  const ShiftsScreen({super.key, this.apiService});

  @override
  ConsumerState<ShiftsScreen> createState() => _ShiftsScreenState();
}

class _ShiftsScreenState extends ConsumerState<ShiftsScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  List<Shift> _allShifts = [];
  bool _isLoading = true;
  // The shift being deleted, or null when no delete is on its way. While set,
  // every delete button is off, so the same shift cannot be deleted twice
  // (B43); that shift's button spins.
  int? _deletingId;
  late final ApiService _apiService = widget.apiService ?? ref.read(apiServiceProvider);

  @override
  void initState() {
    super.initState();
    _loadShifts();
  }

  void _loadShifts() async {
    // Read before the await: the session can end while the request is on
    // its way (B16).
    final me = ref.read(authProvider);
    if (me == null) return;

    setState(() {
      _isLoading = true;
    });

    try {

      DateTime firstDayOfMonth = DateTime(_focusedDay.year, _focusedDay.month, 1);
      DateTime lastDayOfMonth = DateTime(_focusedDay.year, _focusedDay.month + 1, 0);

      List<Shift> shifts;
      if (ref.read(isSupervisorProvider)) {
        shifts = await _apiService.getAllShifts(firstDayOfMonth, lastDayOfMonth);
      } else {
        shifts = await _apiService.getFilteredShifts(me.user.id, firstDayOfMonth, lastDayOfMonth);
      }

      if (!mounted) return;

      setState(() {

        _allShifts = List.from(shifts);
        _isLoading = false;
        _selectedDay = null;
      });
    } catch (e) {
      if (!mounted) return;
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
                  if (ref.read(isSupervisorProvider)) {
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
    // Called from build, so watch (not read): a role change rebuilds the list.
    final isSupervisor = ref.watch(isSupervisorProvider);
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

                if (isSupervisor)
                  IconButton(
                    icon: _deletingId == s.id
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Icon(Icons.delete_sweep, color: Colors.redAccent),
                    onPressed: _deletingId == null ? () => _confirmDelete(s.id) : null,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAssignShiftDialog(DateTime selectedDate) async {
    // Assigned in try; the catch returns, so after it Dart knows it is set.
    final List<User> employees;
    try {
      employees = await _apiService.getAllEmployees();
    } catch (e) {
      // Without this the long-press did nothing and the error reached only
      // the debug log (B34).
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Δεν ήταν δυνατή η φόρτωση των υπαλλήλων. Δοκιμάστε ξανά.")));
      return;
    }
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (_) => AssignShiftDialog(
        apiService: _apiService,
        date: selectedDate,
        employees: employees,
        // Runs even if the dialog was closed while saving; only the screen
        // needs to be there.
        onSaved: () {
          if (mounted) _loadShifts();
        },
        // Only called once the dialog is gone, so the message must say what
        // was refused (B75).
        onFailed: (message) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Η βάρδια δεν αποθηκεύτηκε. $message")));
        },
      ),
    );
  }

  // A switch with no default: a value added to the enum later will not
  // compile until it is given its text here.
  String _deleteResultText(DeleteResult result) {
    switch (result) {
      case DeleteResult.deleted:
        return "Η βάρδια διαγράφηκε";
      case DeleteResult.notFound:
        return "Η βάρδια είχε ήδη διαγραφεί.";
      case DeleteResult.failed:
        return "Η διαγραφή απέτυχε. Δοκιμάστε ξανά.";
    }
  }

  void _confirmDelete(int shiftId) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text("Διαγραφή Βάρδιας"),
        content: Text("Είστε σίγουροι ότι θέλετε να διαγράψετε αυτή τη βάρδια;"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text("Ακύρωση")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              // Before the await: from the next frame on, every delete button
              // is off until the reply arrives (B43).
              setState(() => _deletingId = shiftId);
              Navigator.pop(dialogContext);
              try {
                final result = await _apiService.deleteShift(shiftId);
                if (!mounted) return;
                // Reload unless nothing changed: after a 404 the calendar on
                // screen is out of date, and the reload shows what is stored.
                if (result != DeleteResult.failed) {
                  setState(() => _selectedDay = null);
                  _loadShifts();
                }
                // Every outcome says something: a failure used to say nothing
                // at all (B33).
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(_deleteResultText(result))));
              } catch (e, stackTrace) {
                // No network: deleteShift throws it so that it is logged here
                // (B84). Logged before the mounted check: it failed either way.
                developer.log("Deleting the shift failed",
                    name: "ShiftsScreen", error: e, stackTrace: stackTrace);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(_deleteResultText(DeleteResult.failed))));
              } finally {
                // On success and failure alike, or the delete buttons stay
                // off for good (B43); the guard is for a screen closed
                // meanwhile, whose setState would throw.
                if (mounted) setState(() => _deletingId = null);
              }
            },
            child: Text("Διαγραφή", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}