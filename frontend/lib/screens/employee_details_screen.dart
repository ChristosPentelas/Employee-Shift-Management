import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_providers.dart';
import '../models/user_model.dart';
import '../state/auth_session.dart';
import '../screens/chat_screen.dart';

class EmployeeDetailsScreen extends ConsumerWidget {

  final User user;

  EmployeeDetailsScreen({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref){
    return Scaffold(
      appBar: AppBar(title: Text(user.name)),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            ListTile(leading: Icon(Icons.email), title: Text("Emaill"), subtitle: Text(user.email)),
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
                onPressed: () => _showDeleteDialog(context, ref),
                icon: Icon(Icons.delete, color: Colors.red),
                label: Text("Διαγραφή Υπαλλήλου", style: TextStyle(color: Colors.red)),
                style: OutlinedButton.styleFrom(side: BorderSide(color: Colors.red)),
              ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref){
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
                // Close the question first: after the await only this screen
                // matters. Read the service now too; ref may not be used once
                // the screen is gone.
                Navigator.pop(dialogContext);
                final api = ref.read(apiServiceProvider);
                try{
                  await api.deleteUser(user.id);
                  // A ConsumerWidget has no `mounted`; its context has (F25).
                  if (!context.mounted) return;

                  // true tells the employee list to reload and to say the
                  // employee was deleted (it is the screen on display then).
                  Navigator.pop(context,true);
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Σφάλμα: $e")),
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