import 'package:flutter/material.dart';
import '../models/shift_model.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';

/// Assigns a shift on [date]: an employee, a position and two times.
///
/// Its own StatefulWidget, like AddLeaveDialog, so the position's controller
/// is released in dispose() when the dialog closes (B35).
///
/// A saved shift goes to [onSaved] rather than out through Navigator.pop: a
/// tap outside can close the dialog while the shift is on its way, and the
/// screen must still reload its calendar (F25). A refusal has no callback -
/// it is shown inside the dialog, which stays open so the supervisor can fix
/// the times and save again.
class AssignShiftDialog extends StatefulWidget {
  // Passed in rather than read from apiServiceProvider, so the screen can
  // hand over the one it has - in tests, one with a fake client.
  final ApiService apiService;
  final DateTime date;
  // Loaded by the screen before it opens the dialog, so a list that fails to
  // load is reported without an empty dialog first (B34).
  final List<User> employees;
  final VoidCallback onSaved;

  const AssignShiftDialog({
    super.key,
    required this.apiService,
    required this.date,
    required this.employees,
    required this.onSaved,
  });

  @override
  State<AssignShiftDialog> createState() => _AssignShiftDialogState();
}

class _AssignShiftDialogState extends State<AssignShiftDialog> {
  final _positionController = TextEditingController();
  User? _selectedEmployee;
  // Picked, not typed, so a time the server cannot read cannot be entered
  // (B24).
  TimeOfDay _startTime = TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _endTime = TimeOfDay(hour: 16, minute: 0);
  // Shown in the dialog when the server refuses the shift.
  String? _saveError;
  // True while the shift is on its way: Save is off, so a double tap cannot
  // send it twice (B32).
  bool _saving = false;

  @override
  void dispose() {
    _positionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    // Before the await: once it starts, a second tap is too late to stop.
    setState(() => _saving = true);
    final newShift = Shift(
      id: 0,
      date: widget.date,
      startTime: _hhmm(_startTime),
      endTime: _hhmm(_endTime),
      position: _positionController.text,
    );

    final result = await widget.apiService.assignShift(newShift, _selectedEmployee!.id);

    if (result == AssignShiftResult.created) {
      // Before the mounted check: the screen needs it even when this dialog
      // is already gone.
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } else if (mounted) {
      // The dialog stays open, so the supervisor can fix the times and save
      // again.
      setState(() {
        _saving = false;
        _saveError = _assignErrorText(result);
      });
    }
  }

  /// Opens a 24-hour time picker on [initial]; null if it was cancelled.
  Future<TimeOfDay?> _pickTime(TimeOfDay initial) {
    return showTimePicker(
      context: context,
      initialTime: initial,
      // On its own the picker follows the device locale, and an English phone
      // would show AM/PM. Shift times here are written 08:00 - 16:00.
      builder: (pickerContext, child) => MediaQuery(
        data: MediaQuery.of(pickerContext).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
  }

  /// The "HH:mm" the server reads as a LocalTime, e.g. 07:05. Not
  /// TimeOfDay.format(), which follows the locale ("7:05 AM") and would
  /// bring back the very 400 that B24 was about.
  String _hhmm(TimeOfDay time) =>
      "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";

  String _assignErrorText(AssignShiftResult result) {
    switch (result) {
      case AssignShiftResult.overlaps:
        return "Ο υπάλληλος έχει ήδη βάρδια που επικαλύπτεται με αυτές τις ώρες.";
      case AssignShiftResult.onLeave:
        // The server checks the date the shift is filed under (B31).
        return "Ο υπάλληλος έχει εγκεκριμένη άδεια αυτή την ημέρα.";
      case AssignShiftResult.invalid:
        // The picker rules out a malformed time (B24), so a 400 now means
        // equal times or a missing / too long position (B68).
        return "Ελέγξτε τα στοιχεία: η λήξη δεν μπορεί να είναι ίδια με την έναρξη και η θέση εργασίας είναι υποχρεωτική.";
      case AssignShiftResult.failed:
      // Never shown - created closes the dialog - but Dart wants every case
      // named, so a value added to the enum later cannot be forgotten here.
      case AssignShiftResult.created:
        return "Η αποθήκευση απέτυχε. Δοκιμάστε ξανά.";
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text("Ανάθεση: ${widget.date.day}/${widget.date.month}"),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButton<User>(
              isExpanded: true,
              hint: Text("Επιλογή Υπαλλήλου"),
              value: _selectedEmployee,
              items: widget.employees.map((u) => DropdownMenuItem(
                value: u,
                child: Text(u.name),
              )).toList(),
              onChanged: (val) => setState(() => _selectedEmployee = val),
            ),
            TextField(controller: _positionController, decoration: InputDecoration(labelText: "Θέση εργασίας")),
            ListTile(
              title: Text("Έναρξη: ${_hhmm(_startTime)}"),
              trailing: Icon(Icons.access_time),
              onTap: () async {
                final picked = await _pickTime(_startTime);
                if (!mounted) return;
                // null: the picker was cancelled, so the old time stays.
                if (picked != null) setState(() => _startTime = picked);
              },
            ),
            ListTile(
              title: Text("Λήξη: ${_hhmm(_endTime)}"),
              trailing: Icon(Icons.access_time),
              onTap: () async {
                final picked = await _pickTime(_endTime);
                if (!mounted) return;
                if (picked != null) setState(() => _endTime = picked);
              },
            ),
            if (_saveError != null)
              Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(_saveError!, style: TextStyle(color: Colors.red)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text("Ακύρωση")),
        ElevatedButton(
          onPressed: (_selectedEmployee == null || _saving) ? null : _save,
          // Small enough to sit inside the button in place of its text.
          child: _saving
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Text("Αποθήκευση"),
        ),
      ],
    );
  }
}
