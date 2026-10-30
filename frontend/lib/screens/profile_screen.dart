import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/auth_session.dart';
import '../services/api_service.dart';
import '../services/api_providers.dart';
import '../screens/login_screen.dart';
import '../widgets/change_password_dialog.dart';
import '../widgets/edit_profile_dialog.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  // Tests pass an ApiService with a fake client; the app uses the default.
  final ApiService? apiService;

  const ProfileScreen({this.apiService});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}


class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late final ApiService _apiService = widget.apiService ?? ref.read(apiServiceProvider);

  void _showEditDialog() {
    final me = ref.read(authProvider);
    if (me == null) return;

    showDialog(
      context: context,
      builder: (_) => EditProfileDialog(
        apiService: _apiService,
        user: me.user,
        // Runs even if the dialog was closed while saving; only the screen
        // needs to be there.
        onSaved: (saved) {
          // The screen may have closed while saving (e.g. the session
          // expired); its ref and context are no longer usable then.
          if (!mounted) return;
          // A new session with the saved user: build() watches
          // authProvider, so the profile repaints by itself.
          ref.read(authProvider.notifier).updateUser(saved);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Το προφίλ ενημερώθηκε επιτυχώς!")),
          );
        },
      ),
    );
  }

  Future<void> _showChangePasswordDialog() async {
    // null when the dialog was cancelled, tapped away or closed with back.
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => ChangePasswordDialog(apiService: _apiService),
    );

    // The session needs no change: the token stays valid and the user is the
    // same. Only the message is the screen's job, since the dialog is gone.
    if (changed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Ο κωδικός άλλαξε επιτυχώς!")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider)?.user;
    final isSupervisor = ref.watch(isSupervisorProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text("Το Προφίλ μου"),
        backgroundColor: Colors.grey,
        actions: [
          IconButton(
            icon: Icon(Icons.edit, color: Colors.white),
            onPressed: _showEditDialog,
          ),
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () {
              ref.read(authProvider.notifier).logOut(); // the user and the token together

              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => LoginScreen()),
                    (Route<dynamic> route) => false,
              );
            },
          )
        ],
      ),
      body: user == null
        ? Center(child: Text("Δεν βρέθηκαν στοιχεία χρήστη"))
        : SingleChildScrollView(
            padding: EdgeInsets.all(20),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor:  Colors.grey,
                  child: Text(
                    user.name[0].toUpperCase(),
                    style: TextStyle(fontSize: 40,color: Colors.white),
                  ),
                ),
                SizedBox(height: 20),
                Text(user.name, style: TextStyle(fontSize: 24,fontWeight: FontWeight.bold)),
                Chip(
                  label: Text(user.role),
                  backgroundColor: isSupervisor ? Colors.orange : Colors.blue,
                ),
                Divider(height: 40),

                _buildInfoTile(Icons.email, "Email", user.email),
                _buildInfoTile(Icons.phone, "Τηλέφωνο", user.phoneNumber ?? "Δεν έχει καταχωρηθεί"),
                _buildInfoTile(Icons.badge, "ID Υπαλλήλου", "#${user.id}"),
                SizedBox(height: 20),
                OutlinedButton.icon(
                  icon: Icon(Icons.lock_outline),
                  label: Text("Αλλαγή κωδικού"),
                  onPressed: _showChangePasswordDialog,
                ),


              ],
            ),
      ),
    );
  }

  Widget _buildInfoTile(IconData icon,String label, String value) {
    return ListTile(
      leading: Icon(icon,color: Colors.blueGrey),
      title: Text(label, style: TextStyle(fontSize: 14,color: Colors.grey)),
      subtitle: Text(value,style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
    );
  }
}