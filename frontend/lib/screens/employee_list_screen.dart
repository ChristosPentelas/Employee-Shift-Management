import 'dart:developer' as developer;

import 'package:employee_shift_management_ui/screens/employee_details_screen.dart';
import 'package:employee_shift_management_ui/screens/register_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/auth_session.dart';
import '../services/api_service.dart';
import '../services/api_providers.dart';
import '../models/user_model.dart';
import '../widgets/load_error_view.dart';

class EmployeeListScreen extends ConsumerStatefulWidget {
  // Tests pass an ApiService with a fake client; the app uses the default.
  final ApiService? apiService;

  const EmployeeListScreen({super.key, this.apiService});

  @override
  ConsumerState<EmployeeListScreen> createState() => _EmployeeListScreenState();
}

class _EmployeeListScreenState extends ConsumerState<EmployeeListScreen> {
  late final ApiService _apiService = widget.apiService ?? ref.read(apiServiceProvider);
  late Future<List<User>> _employeesFuture;

  @override
  void initState() {
    super.initState();
    _employeesFuture = _loadEmployees();
  }

  // Logs a failure here, once, then passes it on to the FutureBuilder, which
  // shows only that it failed (B41). Not in the builder: that runs on every
  // rebuild and would log the same error again each time.
  Future<List<User>> _loadEmployees() async {
    try {
      return await _apiService.getAllEmployees();
    } catch (e, stackTrace) {
      developer.log("Loading the employees failed",
          name: "EmployeeListScreen", error: e, stackTrace: stackTrace);
      // rethrow, not `throw e`: it keeps the original stack trace.
      rethrow;
    }
  }

  // A new future starts the FutureBuilder over, spinner first.
  void _reload() {
    setState(() {
      _employeesFuture = _loadEmployees();
    });
  }

  Future<void> _addEmployee() async {
    final created = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RegisterScreen(apiService: _apiService),
      ),
    );

    if (created == true && mounted) {
      _reload();
    }
  }

  // A method, not code inside the row's onTap: in a State method `context` is
  // this screen's, which is the one `mounted` checks. Inside the list's
  // builders `context` would be the row's, and the analyzer rightly calls
  // `mounted` unrelated to it (F25).
  Future<void> _openEmployee(User emp) async {
    final deleted = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EmployeeDetailsScreen(user: emp),
      ),
    );

    // true means the details screen deleted this employee. That screen is
    // closed by now, so this one, the screen on display, says so.
    if (deleted == true && mounted) {
      _reload();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Ο υπάλληλος διαγράφηκε επιτυχώς"),
            backgroundColor: Colors.red),
      );
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
          } else if (snapshot.hasError) {
            return LoadErrorView(onRetry: _reload);
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
                  onTap: () => _openEmployee(emp),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
