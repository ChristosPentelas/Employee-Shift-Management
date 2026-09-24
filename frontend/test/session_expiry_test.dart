import 'package:employee_shift_management_ui/main.dart';
import 'package:employee_shift_management_ui/models/user_model.dart';
import 'package:employee_shift_management_ui/services/session_expiry.dart';
import 'package:employee_shift_management_ui/utils/navigation.dart';
import 'package:employee_shift_management_ui/utils/session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

User worker() =>
    User(id: 7, name: 'Worker', email: 'worker@example.com', role: 'EMPLOYEE');

void main() {
  tearDown(Session.clear);

  test('a rejected current token logs the user out', () {
    Session.logIn(worker(), 'old');

    handleRejectedToken('old');

    expect(Session.currentUser, isNull);
    expect(Session.token, isNull);
  });

  test('a late rejection of an old token does not log out a newer session', () {
    // The user already logged in again; a slow reply to a request made with
    // the previous token arrives only now.
    Session.logIn(worker(), 'new');

    handleRejectedToken('old');

    expect(Session.token, 'new');
    expect(Session.currentUser, isNotNull);
  });

  testWidgets('returns to the login screen, closes other screens and says why',
      (WidgetTester tester) async {
    await tester.pumpWidget(MyApp());
    navigatorKey.currentState!.push(MaterialPageRoute(
        builder: (_) => const Scaffold(body: Text('Shifts page'))));
    await tester.pumpAndSettle();
    expect(find.text('Shifts page'), findsOneWidget);

    Session.logIn(worker(), 'abc');

    handleRejectedToken('abc');
    await tester.pumpAndSettle();

    expect(find.text('Shifts page'), findsNothing);
    expect(find.widgetWithText(TextFormField, 'Email'), findsOneWidget);
    expect(find.text('Η σύνδεση έληξε, συνδεθείτε ξανά'), findsOneWidget);
    expect(navigatorKey.currentState!.canPop(), isFalse,
        reason: '"back" must not return to a screen that needed the session');
  });
}
