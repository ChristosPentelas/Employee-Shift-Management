import 'package:flutter/material.dart';
import '../services/api_service.dart';

/// A supervisor creates an employee account here (F1 step 5). It is opened
/// from the employee list, so the request carries the supervisor's token.
class RegisterScreen extends StatefulWidget {
  // Tests pass an ApiService with a fake client; the app uses the default.
  final ApiService? apiService;

  const RegisterScreen({this.apiService});

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  late final _apiService = widget.apiService ?? ApiService();
  bool _isLoading = false;

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
    );

    // The screen may have closed while waiting (e.g. the token was rejected
    // and the app went back to login). Its context is no longer usable (F25).
    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Ο λογαριασμός δημιουργήθηκε")),
      );
      // true tells the employee list to reload.
      Navigator.pop(context, true);
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
      appBar: AppBar(title: Text("Νέος Υπάλληλος")),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(controller: _nameController, decoration: InputDecoration(labelText: "Ονομα")),
            TextField(controller: _emailController, decoration: InputDecoration(labelText: "Email")),
            TextField(controller: _phoneController, decoration: InputDecoration(labelText: "Αριθμός Τηλεφώνου(Προαιρετικό)"),keyboardType: TextInputType.phone,),
            TextField(controller: _passwordController, decoration: InputDecoration(labelText: "Κωδικός")),

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
