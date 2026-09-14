// Widget tests for the app's entry point.
//
// These pump the real root widget from main.dart, so they also cover the
// MaterialApp wiring and `home: LoginScreen()`. No backend is involved:
// LoginScreen only builds a form, and _handleLogin returns early when
// validation fails, so nothing here reaches ApiService.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:employee_shift_management_ui/main.dart';

void main() {
  testWidgets('app starts on the login screen with email and password fields',
      (WidgetTester tester) async {
    await tester.pumpWidget(MyApp());

    expect(find.widgetWithText(TextFormField, 'Email'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Password'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'ΣΥΝΔΕΣΗ'), findsOneWidget);
  });

  testWidgets('submitting an empty form shows validation errors, not a request',
      (WidgetTester tester) async {
    await tester.pumpWidget(MyApp());

    await tester.tap(find.widgetWithText(ElevatedButton, 'ΣΥΝΔΕΣΗ'));
    await tester.pump();

    expect(find.text('Παρακαλώ βάλτε email'), findsOneWidget);
    expect(find.text('Ο κωδικός πρέπει να έχει τουλάχιστον 4 χαρακτήρες'),
        findsOneWidget);
  });

  testWidgets('the login screen offers no self-registration',
      (WidgetTester tester) async {
    await tester.pumpWidget(MyApp());

    // Accounts are created by a supervisor from the employee list (F1 step 5).
    expect(find.textContaining('Εγγραφείτε'), findsNothing);
  });
}
