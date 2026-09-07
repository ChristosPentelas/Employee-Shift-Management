import 'package:employee_shift_management_ui/screens/employee_details_screen.dart';
import 'package:employee_shift_management_ui/utils/session.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/user_model.dart';

class EmployeeListScreen extends StatefulWidget {
  @override
  _EmployeeListScreenState createState() => _EmployeeListScreenState();
}

class _EmployeeListScreenState extends State<EmployeeListScreen> {
  final ApiService _apiService = ApiService();
  late Future<List<User>> _employeesFuture;

  @override
  void initState() {
    super.initState();
    _employeesFuture = _apiService.getAllEmployees();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text("Λίστα Υπαλλήλων"), backgroundColor: Colors.blue[800]),
      body: FutureBuilder<List<User>>(
        future: _employeesFuture,
        builder: (context, snapshot) {
          // Waiting for data
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) { //if error corrupt
            return Center(child: Text("Σφάλμα: ${snapshot.error}"));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text("Δεν βρέθηκαν υπάλληλοι."));
          }

          List<User> employees = snapshot.data!;
          return ListView.builder(
            itemCount: employees.length,
            itemBuilder: (context, index) {
              User emp = employees[index];
              return Card(
                margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                elevation: 3,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue[100],
                    child: Text(emp.name[0].toUpperCase()),
                  ),
                  title: Text(
                      emp.name, style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("${emp.role} • ${emp.email}"),
                  trailing: Icon(Icons.chevron_right),
                  onTap: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EmployeeDetailsScreen(user: emp),
                      ),
                    );

                    if (result == true) {
                      setState(() {
                        _employeesFuture = _apiService.getAllEmployees();
                      });
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}