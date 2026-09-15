// Logging in and out must change the session and the screen stack together.
// Before this fix, the dashboard's logout only closed the screen (user and
// token stayed in memory), and "back" from the dashboard reached the login
// page while still logged in.

import 'package:employee_shift_management_ui/models/user_model.dart';
import 'package:employee_shift_management_ui/screens/home_screen.dart';
import 'package:employee_shift_management_ui/screens/login_screen.dart';
import 'package:employee_shift_management_ui/services/api_service.dart';
import 'package:employee_shift_management_ui/utils/session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

// The same named route main.dart registers.
Widget appStartingAt(Widget home) => MaterialApp(
      home: home,
      routes: {'/login': (context) => LoginScreen()},
    );

NavigatorState navigator(WidgetTester tester) =>
    tester.state<NavigatorState>(find.byType(Navigator));

void main() {
  tearDown(Session.clear);

  testWidgets('logging out from the dashboard clears the session and all screens',
      (WidgetTester tester) async {
    Session.currentUser =
        User(id: 9, name: 'Boss', email: 'boss@example.com', role: 'SUPERVISOR');
    Session.token = 'abc';

    await tester.pumpWidget(appStartingAt(HomeScreen()));
    await tester.tap(find.byIcon(Icons.logout));
    await tester.pumpAndSettle();

    expect(Session.currentUser, isNull);
    expect(Session.token, isNull, reason: 'a logged-out app must not keep a working token');
    expect(find.widgetWithText(TextFormField, 'Email'), findsOneWidget);
    expect(navigator(tester).canPop(), isFalse,
        reason: '"back" must not return to the dashboard');
  });

  testWidgets('after logging in, "back" cannot return to the login screen',
      (WidgetTester tester) async {
    final fakeServer = MockClient((request) async => http.Response(
        '{"id":9,"name":"Boss","email":"boss@example.com","role":"SUPERVISOR","token":"abc"}',
        200));

    await tester.pumpWidget(appStartingAt(
        LoginScreen(apiService: ApiService(client: fakeServer))));
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'), 'boss@example.com');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'), 'secret123');
    await tester.tap(find.widgetWithText(ElevatedButton, 'ΣΥΝΔΕΣΗ'));
    await tester.pumpAndSettle();

    expect(find.text('Dashboard'), findsOneWidget);
    expect(Session.token, 'abc');
    expect(navigator(tester).canPop(), isFalse,
        reason: 'the login screen was replaced, not left underneath');
  });
}
