import 'package:flutter/material.dart';
import '../models/leave_request_model.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../utils/date_limits.dart';

/// Files a leave request for the logged-in employee: a date range and a
/// reason.
///
/// Its own StatefulWidget, like AddNewsDialog, so the reason's controller is
/// released in dispose() when the dialog closes (B35).
///
/// A filed request goes to [onFiled] rather than out through Navigator.pop: a
/// tap outside can close the dialog while the request is on its way, and the
/// screen must still reload its list (F25). A refusal has no callback - it is
/// shown inside the dialog, which stays open so nothing typed is lost (B19).
class AddLeaveDialog extends StatefulWidget {
  // Passed in rather than read from apiServiceProvider, so the screen can
  // hand over the one it has - in tests, one with a fake client.
  final ApiService apiService;
  // The logged-in employee, read by the screen when it opens the dialog.
  final User employee;
  final VoidCallback onFiled;

  const AddLeaveDialog({
    super.key,
    required this.apiService,
    required this.employee,
    required this.onFiled,
  });

  @override
  State<AddLeaveDialog> createState() => _AddLeaveDialogState();
}

class _AddLeaveDialogState extends State<AddLeaveDialog> {
  final _reasonController = TextEditingController();
  DateTimeRange? _selectedRange;
  // Why the server refused, shown under the reason (B19).
  String? _saveError;
  // True while the request is on its way: Submit is off, so a double tap
  // cannot file the same leave twice (B32).
  bool _saving = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: latestPickableDate(DateTime.now()),
    );
    if (!mounted) return;
    if (picked != null) setState(() => _selectedRange = picked);
  }

  Future<void> _submit() async {
    // Before the await: once it starts, a second tap is too late to stop.
    setState(() => _saving = true);

    final newRequest = LeaveRequest(
      id: 0,
      employee: widget.employee,
      startDate: _selectedRange!.start,
      endDate: _selectedRange!.end,
      status: 'PENDING',
      reason: _reasonController.text,
    );

    final result = await widget.apiService.submitLeaveRequest(newRequest);

    if (result == SubmitLeaveResult.created) {
      // Before the mounted check: the screen needs it even when this dialog
      // is already gone.
      widget.onFiled();
      if (mounted) Navigator.pop(context);
    } else if (mounted) {
      setState(() {
        _saving = false;
        _saveError = _submitErrorText(result);
      });
    }
  }

  String _submitErrorText(SubmitLeaveResult result) {
    switch (result) {
      case SubmitLeaveResult.invalid:
        return "Ελέγξτε τις ημερομηνίες και τον λόγο.";
      case SubmitLeaveResult.failed:
      // Never shown - created closes the dialog - but Dart wants every case
      // named, so a value added to the enum later cannot be forgotten here.
      case SubmitLeaveResult.created:
        return "Η αποθήκευση απέτυχε. Δοκιμάστε ξανά.";
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text("Αίτηση Αδείας"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ElevatedButton.icon(
            icon: Icon(Icons.date_range),
            label: Text(_selectedRange == null
                ? "Επιλέξτε Ημερομηνίες"
                : "${_selectedRange!.start.day}/${_selectedRange!.start.month} - ${_selectedRange!.end.day}/${_selectedRange!.end.month}"),
            onPressed: _pickRange,
          ),
          SizedBox(height: 10),
          TextField(
            controller: _reasonController,
            // Required: the server's CreateLeaveRequest.reason is
            // @NotBlank, and the supervisor decides by it (B19).
            decoration: InputDecoration(labelText: "Λόγος"),
            // FieldLimits.TEXT on the server.
            maxLength: 255,
            // Typing does not rebuild the dialog by itself; without this the
            // submit button would not notice the reason.
            onChanged: (_) => setState(() {}),
          ),
          if (_saveError != null)
            Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(_saveError!, style: TextStyle(color: Colors.red)),
            ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text("Ακύρωση")),
        ElevatedButton(
          // trim(): spaces only is not empty, but @NotBlank refuses it.
          onPressed: (_selectedRange == null ||
                  _reasonController.text.trim().isEmpty ||
                  _saving)
              ? null
              : _submit,
          child: _saving
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Text("Υποβολή"),
        ),
      ],
    );
  }
}
