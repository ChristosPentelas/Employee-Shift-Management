import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/auth_session.dart';
import '../services/api_service.dart';
import '../screens/login_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  // Tests pass an ApiService with a fake client; the app uses the default.
  final ApiService? apiService;

  const ProfileScreen({this.apiService});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}


class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late final ApiService _apiService = widget.apiService ?? ApiService();

  void _showEditDialog() {
    final me = ref.read(authProvider);
    if (me == null) return;
    final user = me.user;
    final _nameController = TextEditingController(text: user.name);
    final _emailController = TextEditingController(text: user.email);
    final _phoneController = TextEditingController(text: user.phoneNumber);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
            onPressed: () async {
              final saved = await _apiService.updateUser(
                user.id,
                _nameController.text,
                _emailController.text,
                _phoneController.text,
              );

              // The screen may have closed while saving (e.g. the session
              // expired); its ref and context are no longer usable then.
              if (!mounted) return;

              if (saved != null) {
                // A new session with the saved user: build() watches
                // authProvider, so the profile repaints by itself.
                ref.read(authProvider.notifier).updateUser(saved);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Το προφίλ ενημερώθηκε επιτυχώς!")),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Σφάλμα κατά την ενημέρωση")),);
              }
            },
            child: Text("Αποθήκευση"),
          ),
        ],
      ),
    );
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

  Widget _buildStatColumn(String label,String value) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(color: Colors.grey)),
      ],
    );
  }
}