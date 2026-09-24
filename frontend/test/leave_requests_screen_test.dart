// F7 / F1 step 7c: an employee must not receive other people's leave requests
// at all. Before this, the screen downloaded every request and hid the rest.

import 'package:employee_shift_management_ui/models/user_model.dart';
import 'package:employee_shift_management_ui/screens/leave_requests_screen.dart';
import 'package:employee_shift_management_ui/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'helpers/app_scope.dart';

void main() {
  /// Opens the screen and reports which paths it asked the server for.
  Future<List<String>> requestedPaths(
      WidgetTester tester, ProviderContainer container) async {
    final paths = <String>[];
    final api = ApiService(client: MockClient((request) async {
      paths.add(request.url.path);
      return http.Response('{"content":[]}', 200);
    }));

    await tester.pumpWidget(
        withAppState(container, MaterialApp(home: LeaveRequestsScreen(apiService: api))));
    await tester.pumpAndSettle();
    return paths;
  }

  testWidgets('an employee asks only for their own leave requests',
      (WidgetTester tester) async {
    final container = testContainer(
        user: User(id: 7, name: 'Worker', email: 'worker@example.com', role: 'EMPLOYEE'));

    expect(await requestedPaths(tester, container), ['/api/v1/leaves/users/7/leaves']);
  });

  testWidgets('a supervisor asks for every leave request',
      (WidgetTester tester) async {
    final container = testContainer(
        user: User(id: 9, name: 'Boss', email: 'boss@example.com', role: 'SUPERVISOR'));

    expect(await requestedPaths(tester, container), ['/api/v1/leaves']);
  });
}
