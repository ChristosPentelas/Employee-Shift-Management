import 'package:flutter/material.dart';
import '../utils/session.dart';
import '../services/api_service.dart';
import '../screens/login_screen.dart';

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}


class _ProfileScreenState extends State<ProfileScreen> {
  final ApiService _apiService = ApiService();

  void _showEditDialog() {
    final user = Session.currentUser!;
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
              bool success = await _apiService.updateUser(
                user.id,
                _nameController.text,
                _emailController.text,
                _phoneController.text,
              );

              if (success) {
                setState(() {

                });
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
    final user = Session.currentUser;

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
              Session.currentUser = null; //

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
                  backgroundColor: user.role == 'SUPERVISOR' ? Colors.orange : Colors.blue,
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