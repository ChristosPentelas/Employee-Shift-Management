import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_providers.dart';
import '../models/user_model.dart';
import '../state/auth_session.dart';
import '../screens/chat_screen.dart';

// Stateful since B43: it has to remember that a delete is on its way.
class EmployeeDetailsScreen extends ConsumerStatefulWidget {

  final User user;

  const EmployeeDetailsScreen({super.key, required this.user});

  @override
  ConsumerState<EmployeeDetailsScreen> createState() => _EmployeeDetailsScreenState();
}

class _EmployeeDetailsScreenState extends ConsumerState<EmployeeDetailsScreen> {
  // True while the delete is on its way; the delete button is off and spins,
  // so the same employee cannot be deleted twice (B43).
  bool _deleting = false;

  @override
  Widget build(BuildContext context){
    // The State reaches its widget's fields through `widget`.
    final user = widget.user;
    return Scaffold(
      appBar: AppBar(title: Text(user.name)),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            ListTile(leading: Icon(Icons.email), title: Text("Email"), subtitle: Text(user.email)),
            ListTile(leading: Icon(Icons.work), title: Text("Ρόλος"), subtitle: Text(user.role)),


            ListTile(
                leading: Icon(Icons.phone),
                title: Text("Τηλέφωνο"),
                subtitle: Text(user.phoneNumber ?? "Δεν έχει καταχωρηθεί")
            ),

            ElevatedButton.icon(
              onPressed: (){
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatScreen(receiver: user),
                    )
                  );
              },
              icon: Icon(Icons.send),
              label: Text("Αποστολή Μηνύματος"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[600],foregroundColor: Colors.white),
            ),

            SizedBox(height: 10),

            if (ref.watch(isSupervisorProvider))
              OutlinedButton.icon(
                onPressed: _deleting ? null : _showDeleteDialog,
                icon: _deleting
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(Icons.delete, color: Colors.red),
                label: Text("Διαγραφή Υπαλλήλου", style: TextStyle(color: Colors.red)),
                style: OutlinedButton.styleFrom(side: BorderSide(color: Colors.red)),
              ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(){
    final user = widget.user;
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text("Επιβεβαίωση Διαγραφής"),
          content: Text("Είστε σίγουροι ότι θέλετε να διαγράψετε τον υπάλληλο ${user.name};"),
          actions: [
            TextButton(
              child: Text("Ακύρωση"),
              onPressed: () => Navigator.pop(dialogContext),
            ),
            TextButton(
              child: Text("Διαγραφή", style: TextStyle(color:Colors.red)),
              onPressed: () async {
                // Before the await: from the next frame on, the delete button
                // is off until the reply arrives (B43).
                setState(() => _deleting = true);
                // Close the question first: after the await only this screen
                // matters. Read the service now too; ref may not be used once
                // the screen is gone.
                Navigator.pop(dialogContext);
                final api = ref.read(apiServiceProvider);
                try{
                  await api.deleteUser(user.id);
                  if (!mounted) return;

                  // true tells the employee list to reload and to say the
                  // employee was deleted (it is the screen on display then).
                  // _deleting stays true: the screen is on its way out.
                  Navigator.pop(context,true);
                } catch (e, stackTrace) {
                  // The detail is for whoever debugs it, not the supervisor
                  // (B41). Logged before the mounted check: it failed either way.
                  developer.log("Deleting the employee failed",
                      name: "EmployeeDetailsScreen", error: e, stackTrace: stackTrace);
                  if (!mounted) return;
                  setState(() => _deleting = false);
                  // The shifts screen's words for the same failure (B33).
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Η διαγραφή απέτυχε. Δοκιμάστε ξανά.")),
                  );
                }

              },
            ),
          ],
        );
      },
    );
  }
}
