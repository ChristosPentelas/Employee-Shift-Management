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
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Επιβεβαίωση Διαγραφής"),
          content: Text("Είστε σίγουροι ότι θέλετε να διαγράψετε τον υπάλληλο ${user.name};"),
          actions: [
            TextButton(
              child: Text("Ακύρωση"),
              onPressed: () => Navigator.pop(context),
            ),
            TextButton(
              child: Text("Διαγραφή", style: TextStyle(color:Colors.red)),
              onPressed: () async {
                try{
                  await ref.read(apiServiceProvider).deleteUser(user.id);

                  Navigator.pop(context);
                  Navigator.pop(context,true);

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Ο υπάλληλος διαγράφηκε επιτυχώς"), backgroundColor: Colors.red),
                  );
                } catch (e) {
                  Navigator.pop(context);
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