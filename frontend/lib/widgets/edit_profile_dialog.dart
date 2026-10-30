import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';

/// Edits the logged-in user's name, email and phone.
///
/// Its own StatefulWidget, like ChangePasswordDialog, so the three
/// controllers are released in dispose() when the dialog closes (B35).
///
/// A saved user goes to [onSaved] rather than out through Navigator.pop: a tap
/// outside can close the dialog while the save is on its way, and a closed
/// dialog can no longer pop with anything - but the server stored the change,
/// so the screen must still hear about it (F25).
class EditProfileDialog extends StatefulWidget {
  // Passed in rather than read from apiServiceProvider, so the screen can
  // hand over the one it has - in tests, one with a fake client.
  final ApiService apiService;
  final User user;
  final ValueChanged<User> onSaved;

  const EditProfileDialog({
    super.key,
    required this.apiService,
    required this.user,
    required this.onSaved,
  });

  @override
  State<EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<EditProfileDialog> {
  // `late`: a field's initializer cannot read `widget`; initState can.
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.name);
    _emailController = TextEditingController(text: widget.user.email);
    _phoneController = TextEditingController(text: widget.user.phoneNumber);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final saved = await widget.apiService.updateUser(
      widget.user.id,
      _nameController.text,
      _emailController.text,
      _phoneController.text,
    );

    if (saved != null) {
      // Before the mounted check: the screen needs the saved user even when
      // this dialog is already gone.
      widget.onSaved(saved);
      if (mounted) Navigator.pop(context);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Σφάλμα κατά την ενημέρωση")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text("Επεξεργασία Προφίλ"),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(labelText: "Όνομα"),
            ),
            TextField(
              controller: _emailController,
              decoration: InputDecoration(labelText: "Email"),
            ),
            TextField(
              controller: _phoneController,
              decoration: InputDecoration(labelText: "Τηλέφωνο"),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text("Ακύρωση"),
        ),
        ElevatedButton(
          onPressed: _save,
          child: Text("Αποθήκευση"),
        ),
      ],
    );
  }
}
