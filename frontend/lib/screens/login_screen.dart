import 'package:employee_shift_management_ui/screens/home_screen.dart';
import 'package:employee_shift_management_ui/services/api_service.dart';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../utils/session.dart';
import 'dart:convert';
import '../screens/register_screen.dart';

class LoginScreen extends StatefulWidget{
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // key for the form(validation)
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;

  final ApiService _apiService = ApiService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
           key: _formKey,
           child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                  Icons.lock_person_rounded, size: 80, color: Colors.blue[800]),
              SizedBox(height: 20),
              Text(
                "Shift Management",
                style: TextStyle(fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[900]),
              ),
              SizedBox(height: 40),
              //field for email
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: "Email",
                  prefixIcon : Icon(Icons.email_outlined),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (value) {
                  if(value == null || value.isEmpty) return "Παρακαλώ βάλτε email";
                  if(!value.contains("@")) return "Το email δεν είναι έγκυρο";
                  return null;
                },
              ),
              SizedBox(height: 16),
              //field for password
              TextFormField(
                controller: _passwordController,
                obscureText: true, //hides the characters
                decoration: InputDecoration(
                  labelText: "Password",
                  prefixIcon: Icon(Icons.lock_outline),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (value) {
                  if(value == null || value.length<4) return "Ο κωδικός πρέπει να έχει τουλάχιστον 4 χαρακτήρες";
                  return null;

                },
              ),
              SizedBox(height: 24),

              //login button
              _isLoading
                ? CircularProgressIndicator()
                :ElevatedButton(
                  onPressed: _handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[800],
                  // Button Color
                    foregroundColor: Colors.white,
                  // Color Text
                    minimumSize: Size(double.infinity, 55),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 5,
                ),
                child: Text("ΣΥΝΔΕΣΗ", style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              SizedBox(height: 20),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => RegisterScreen()),
                  );
                },
                child: Text("Δεν έχετε λογαριασμό; Εγγραφείτε εδώ",
                    style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }

  // Login logic
  void _handleLogin() async {
    //if form is not valid,stop here
    if(!_formKey.currentState!.validate()) return;

    //Start loading
    setState(() {
      _isLoading = true;
    });

    try{
      final response = await _apiService.login(
          _emailController.text, _passwordController.text);

      if (response.statusCode == 200) {
        var userData = jsonDecode(response.body);
        Session.currentUser = User.fromJson(userData);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Επιτυχής σύνδεση!"), backgroundColor: Colors.green),
        );

        Navigator.push(
          context, MaterialPageRoute(builder: (context) => HomeScreen()),
        );
      }else if (response.statusCode == 401){
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Λάθος email ή κωδικός"), backgroundColor: Colors.red),
        );

      }else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Σφάλμα συστήματος: ${response.statusCode}")),
        );
      }
    }catch (e) {
      //if the server is closed or incorrect IP
      print("Connection Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Αδυναμία σύνδεσης με τον διακοσμιτή.")),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }

  }
}