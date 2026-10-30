import 'package:flutter/material.dart';
import '../models/news_model.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../utils/date_limits.dart';

/// Writes a new announcement, goal or task.
///
/// Its own StatefulWidget, like EditProfileDialog, so the three controllers
/// are released in dispose() when the dialog closes (B35).
///
/// The outcome goes to [onPosted] or [onFailed] rather than out through
/// Navigator.pop: a tap outside can close the dialog while the post is on its
/// way, and a closed dialog can no longer pop with anything or show a message
/// - but the screen is still there and must still hear about it (F25).
class AddNewsDialog extends StatefulWidget {
  // Passed in rather than read from apiServiceProvider, so the screen can
  // hand over the one it has.
  final ApiService apiService;
  // The logged-in supervisor, read by the screen when it opens the dialog.
  final User author;
  final VoidCallback onPosted;
  final ValueChanged<Object> onFailed;

  const AddNewsDialog({
    super.key,
    required this.apiService,
    required this.author,
    required this.onPosted,
    required this.onFailed,
  });

  @override
  State<AddNewsDialog> createState() => _AddNewsDialogState();
}

class _AddNewsDialogState extends State<AddNewsDialog> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _targetController = TextEditingController();

  // Fields of the State, so they survive every setState. Inside a
  // StatefulBuilder they had to live outside the builder for the same reason.
  String _selectedType = 'ANNOUNCEMENT';
  DateTime? _selectedDeadline;
  // True while the post is on its way: Post is off, so a double tap cannot
  // publish the same announcement twice (B73).
  bool _saving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  Future<void> _pickDeadline() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: latestPickableDate(DateTime.now()),
    );
    if (!mounted) return;
    if (picked != null) setState(() => _selectedDeadline = picked);
  }

  Future<void> _post() async {
    // Before the await: once it starts, a second tap is too late to stop.
    setState(() => _saving = true);
    final newItem = NewsItem(
      id: 0,
      title: _titleController.text,
      description: _descController.text,
      type: _selectedType,
      createdAt: DateTime.now(),
      author: widget.author,
      // Only the type's own extra: switching the type hides the other one
      // but keeps what was in it, in case the user switches back (B74).
      deadline: _selectedType == 'TASK' ? _selectedDeadline : null,
      targetValue: _selectedType == 'GOAL' ? int.tryParse(_targetController.text) : null,
    );

    // Both outcomes are reported before any mounted check: the screen needs
    // them even when this dialog is already gone.
    try {
      await widget.apiService.postNews(newItem);
    } catch (e) {
      // The dialog stays open, so what was typed can be corrected.
      widget.onFailed(e);
      if (mounted) setState(() => _saving = false);
      return;
    }
    widget.onPosted();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text("Νέα Ανάρτηση"),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButton<String>(
              value: _selectedType,
              isExpanded: true,
              items: ['ANNOUNCEMENT', 'GOAL', 'TASK'].map((String val) {
                return DropdownMenuItem(value: val, child: Text(val));
              }).toList(),
              onChanged: (val) => setState(() => _selectedType = val!),
            ),
            TextField(controller: _titleController, decoration: InputDecoration(labelText: "Τίτλος")),
            TextField(controller: _descController, decoration: InputDecoration(labelText: "Περιγραφή"), maxLines: 3),

            if (_selectedType == 'GOAL')
              TextField(
                controller: _targetController,
                decoration: InputDecoration(labelText: "Τιμή Στόχου (Target Value)"),
                keyboardType: TextInputType.number,
              ),

            if (_selectedType == 'TASK')
              ListTile(
                title: Text(_selectedDeadline == null
                    ? "Επιλογή Deadline"
                    : "Deadline: ${_selectedDeadline!.day}/${_selectedDeadline!.month}"),
                trailing: Icon(Icons.calendar_today),
                onTap: _pickDeadline,
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text("Ακύρωση")),
        ElevatedButton(
          onPressed: _saving ? null : _post,
          // Small enough to sit inside the button in place of its text.
          child: _saving
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Text("Δημοσίευση"),
        ),
      ],
    );
  }
}
