import 'dart:convert';

import 'package:flutter/material.dart';
import '../services/api_service.dart';

// BCrypt's limit, copied from the backend's UserService.MAX_PASSWORD_BYTES.
// Counted in UTF-8 bytes, not characters: a Greek letter takes two.
const maxPasswordBytes = 72;

/// Asks for the current password and a new one, typed twice (B8).
///
/// Pops with `true` once the server has stored the new password, and with
/// nothing when cancelled. The screen that opened it shows the success
/// message: this dialog's context is gone by then.
///
/// Its own StatefulWidget, not a StatefulBuilder inside the screen like the
/// older dialogs (B35): a State has dispose(), so the three controllers are
/// released when the dialog closes, and its own `mounted` and `context`.
class ChangePasswordDialog extends StatefulWidget {
  // Passed in rather than read from apiServiceProvider, so the screen can
  // hand over the one it has - in tests, one with a fake client.
  final ApiService apiService;

  const ChangePasswordDialog({super.key, required this.apiService});

  @override
  State<ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  // True while the request is on its way; the save button is disabled, so the
  // same change cannot be sent twice (B43).
  bool _saving = false;

  // Why the server refused, shown under the fields. The dialog stays open so
  // the user can correct it.
  String? _error;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    // The same rules the server checks, so a mistake is shown next to its
    // field without a round trip.
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    final result = await widget.apiService.changePassword(
      _currentController.text,
      _newController.text,
    );

    // A tap outside, the back button or an expired login can close the
    // dialog while the request is on its way (F25).
    if (!mounted) return;

    if (result == ChangePasswordResult.changed) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _saving = false;
        _error = _errorText(result);
      });
    }
  }

  String _errorText(ChangePasswordResult result) {
    switch (result) {
      case ChangePasswordResult.wrongCurrentPassword:
        return "Ο τρέχων κωδικός είναι λάθος.";
      case ChangePasswordResult.invalid:
        return "Ο νέος κωδικός δεν έγινε δεκτός.";
      case ChangePasswordResult.tooManyAttempts:
        // No wait shown: the user is not locked out of the app, only out of
        // this dialog, and the enum carries no Retry-After.
        return "Πολλές αποτυχημένες προσπάθειες. Δοκιμάστε ξανά αργότερα.";
      case ChangePasswordResult.failed:
      // Never shown - changed closes the dialog - but Dart wants every case
      // named, so a value added to the enum later cannot be forgotten here.
      case ChangePasswordResult.changed:
        return "Η αλλαγή απέτυχε. Δοκιμάστε ξανά.";
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text("Αλλαγή Κωδικού"),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _currentController,
                obscureText: true,
                decoration: InputDecoration(labelText: "Τρέχων κωδικός"),
                // Only required, like the server: a length rule here would
                // stop someone with an older, shorter password from ever
                // changing it.
                validator: (value) =>
                    (value == null || value.isEmpty) ? "Συμπληρώστε τον τρέχοντα κωδικό" : null,
              ),
              TextFormField(
                controller: _newController,
                obscureText: true,
                decoration: InputDecoration(labelText: "Νέος κωδικός"),
                validator: (value) {
                  // String.length counts UTF-16 code units, as Java's @Size
                  // does, so the two sides agree on the minimum.
                  if (value == null || value.length < 4) {
                    return "Ο κωδικός πρέπει να έχει τουλάχιστον 4 χαρακτήρες";
                  }
                  if (utf8.encode(value).length > maxPasswordBytes) {
                    return "Ο κωδικός είναι πολύ μεγάλος";
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _confirmController,
                obscureText: true,
                decoration: InputDecoration(labelText: "Επιβεβαίωση νέου κωδικού"),
                // Typed twice because the fields hide what is typed and there
                // is no "forgot password": a typo would lock the user out.
                validator: (value) =>
                    value != _newController.text ? "Οι κωδικοί δεν ταιριάζουν" : null,
              ),
              if (_error != null)
                Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text(_error!, style: TextStyle(color: Colors.red)),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text("Ακύρωση"),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: Text("Αποθήκευση"),
        ),
      ],
    );
  }
}
