import 'package:employee_shift_management_ui/main.dart';
import 'package:employee_shift_management_ui/models/user_model.dart';
import 'package:employee_shift_management_ui/services/session_expiry.dart';
import 'package:employee_shift_management_ui/utils/navigation.dart';
import 'package:employee_shift_management_ui/state/auth_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers/app_scope.dart';

User worker() =>
    User(id: 7, name: 'Worker', email: 'worker@example.com', role: 'EMPLOYEE');

void main() {
  test('a rejected current token logs the user out', () {
    final container = testContainer(user: worker(), token: 'old');

    handleRejectedToken(container.read(authProvider.notifier), 'old');

    expect(container.read(authProvider)?.user, isNull);
    expect(container.read(authProvider)?.token, isNull);
  });

  test('a late rejection of an old token does not log out a newer session', () {
    // The user already logged in again; a slow reply to a request made with
    // the previous token arrives only now.
    final container = testContainer(user: worker(), token: 'new');

    handleRejectedToken(container.read(authProvider.notifier), 'old');

    expect(container.read(authProvider)?.token, 'new');
    expect(container.read(authProvider)?.user, isNotNull);
  });

  testWidgets('returns to the login screen, closes other screens and says why',
      (WidgetTester tester) async {
    final container = testContainer();
    await tester.pumpWidget(withAppState(container, MyApp()));
    navigatorKey.currentState!.push(MaterialPageRoute(
        builder: (_) => const Scaffold(body: Text('Shifts page'))));
    await tester.pumpAndSettle();
    expect(find.text('Shifts page'), findsOneWidget);

    container.read(authProvider.notifier).logIn(worker(), 'abc');

    handleRejectedToken(container.read(authProvider.notifier), 'abc');
    await tester.pumpAndSettle();

    expect(find.text('Shifts page'), findsNothing);
    expect(find.widgetWithText(TextFormField, 'Email'), findsOneWidget);
    expect(find.text('Η σύνδεση έληξε, συνδεθείτε ξανά'), findsOneWidget);
    expect(navigatorKey.currentState!.canPop(), isFalse,
        reason: '"back" must not return to a screen that needed the session');
  });
}
