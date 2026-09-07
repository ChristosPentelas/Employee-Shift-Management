import 'package:flutter/material.dart';
import '../services/api_service.dart';

class RegisterScreen extends StatefulWidget {
  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _apiService = ApiService();
  bool _isLoading = false;
  String _selectedRole = "EMPLOYEE";
  final List<String> _roles = ["EMPLOYEE", "SUPERVISOR"];

  void _register() async {

    if (_nameController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty) {
      _showError("Παρακαλώ συμπληρώστε όλα τα υποχρεωτικά πεδία.");
      return;
    }

    if (!_emailController.text.contains('@')) {
      _showError("Παρακαλώ εισάγετε ενα έγκυρο email (πρεπει να περιεχεί @).");
      return;
    }

    if (_passwordController.text.length < 4) {
      _showError("Ο κωδικός πρέπει να έχει τουλάχιστον 4 χαρακτήρες.");
      return;
    }

    setState(() {
      _isLoading = true;
    });

    bool success = await _apiService.registerUser(
      _nameController.text,
      _emailController.text,
      _phoneController.text,
      _passwordController.text,
      _selectedRole,
    );

    setState(() {
      _isLoading = false;
    });

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Η εγγραφή ολοκληρώθηκε! Συνδεθείτε.")),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Σφάλμα κατά την εγγραφή. Δοκιμάστε ξανά.")),
      );
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Εγγραφή Νέου Χρήστη")),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(controller: _nameController, decoration: InputDecoration(labelText: "Ονομα")),
            TextField(controller: _emailController, decoration: InputDecoration(labelText: "Email")),
            TextField(controller: _phoneController, decoration: InputDecoration(labelText: "Αριθμός Τηλεφώνου(Προαιρετικό)"),keyboardType: TextInputType.phone,),
            TextField(controller: _passwordController, decoration: InputDecoration(labelText: "Κωδικός")),

            SizedBox(height: 20),

            DropdownButtonFormField<String>(
              value: _selectedRole,
              decoration: InputDecoration(labelText: "Ρόλος Χρήστη"),
              items: _roles.map((role) => DropdownMenuItem(
                value: role,
                child: Text(role),
              )).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedRole = value!;
                });
              },
            ),

            SizedBox(height: 30),
            _isLoading
              ? CircularProgressIndicator()
              : ElevatedButton(onPressed: _register, child: Text("Δημιουργία Λογαριασμού")),
          ],
        ),
      ),
    );
  }
}