// Saving your profile must show the new values at once. Before F24 step 24c
// ApiService edited the user in place and the screen repainted only because
// of an empty setState(() {}); now the session is replaced and the screen,
// which watches it, rebuilds by itself.

import 'dart:convert';

import 'package:employee_shift_management_ui/models/user_model.dart';
import 'package:employee_shift_management_ui/screens/profile_screen.dart';
import 'package:employee_shift_management_ui/services/api_service.dart';
import 'package:employee_shift_management_ui/state/auth_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'helpers/app_scope.dart';

void main() {
  Future<void> saveName(WidgetTester tester, ProviderContainer container,
      ApiService api, String name) async {
    await tester.pumpWidget(
        withAppState(container, MaterialApp(home: ProfileScreen(apiService: api))));
    await tester.tap(find.byIcon(Icons.edit));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Όνομα'), name);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Αποθήκευση'));
    await tester.pumpAndSettle();
  }

  testWidgets('a saved profile shows the name the server stored',
      (WidgetTester tester) async {
    final container = testContainer(
        user: User(id: 7, name: 'Worker', email: 'worker@example.com', role: 'EMPLOYEE'));
    final api = ApiService(client: MockClient((request) async {
      final body = jsonDecode(request.body);
      // The server answers with the user as it stored it.
      return http.Response(
          jsonEncode({...body, 'id': 7, 'role': 'EMPLOYEE'}), 200);
    }));

    await saveName(tester, container, api, 'New Name');

    expect(find.text('New Name'), findsOneWidget);
    expect(container.read(authProvider)!.user.name, 'New Name');
    expect(container.read(authProvider)?.token, 'test-token', reason: 'a profile edit keeps the login');
  });

  testWidgets('a refused save leaves the session as it was',
      (WidgetTester tester) async {
    final container = testContainer(
        user: User(id: 7, name: 'Worker', email: 'worker@example.com', role: 'EMPLOYEE'));
    final api = ApiService(
        client: MockClient((request) async => http.Response('', 400)));

    await saveName(tester, container, api, 'New Name');

    expect(container.read(authProvider)!.user.name, 'Worker');
    expect(find.text('Σφάλμα κατά την ενημέρωση'), findsOneWidget);
  });
}
