import 'package:employee_shift_management_ui/screens/employee_details_screen.dart';
import 'package:employee_shift_management_ui/screens/register_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/auth_session.dart';
import '../services/api_service.dart';
import '../services/api_providers.dart';
import '../models/user_model.dart';

class EmployeeListScreen extends ConsumerStatefulWidget {
  // Tests pass an ApiService with a fake client; the app uses the default.
  final ApiService? apiService;

  const EmployeeListScreen({this.apiService});

  @override
  _EmployeeListScreenState createState() => _EmployeeListScreenState();
}

class _EmployeeListScreenState extends ConsumerState<EmployeeListScreen> {
  late final ApiService _apiService = widget.apiService ?? ref.read(apiServiceProvider);
  late Future<List<User>> _employeesFuture;

  @override
  void initState() {
    super.initState();
    _employeesFuture = _apiService.getAllEmployees();
  }

  Future<void> _addEmployee() async {
    final created = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RegisterScreen(apiService: _apiService),
      ),
    );

    if (created == true && mounted) {
      setState(() {
        _employeesFuture = _apiService.getAllEmployees();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text("Λίστα Υπαλλήλων"), backgroundColor: Colors.blue[800]),
      // Only supervisors create accounts (F1 step 5). Hiding the button is a
      // convenience, not security: the server enforces the rule (step 6).
      floatingActionButton: ref.watch(isSupervisorProvider)
          ? FloatingActionButton(
              tooltip: "Νέος Υπάλληλος",
              backgroundColor: Colors.blue[800],
              onPressed: _addEmployee,
              child: Icon(Icons.person_add),
            )
          : null,
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
