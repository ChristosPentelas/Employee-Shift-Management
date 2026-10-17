// After 5 wrong passwords the server locks the login for 15 minutes and
// answers 429 with a Retry-After header in seconds (B56). The login screen
// must say so in its own Greek words, with the wait in whole minutes rounded
// up, instead of "Σφάλμα συστήματος: 429".

import 'package:employee_shift_management_ui/screens/login_screen.dart';
import 'package:employee_shift_management_ui/services/api_service.dart';
import 'package:employee_shift_management_ui/state/auth_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'helpers/app_scope.dart';

// The start of the message, the same on the login screen and in the password
// change dialog. Not "your account is locked": an email nobody has is locked
// too, so that a 429 does not reveal who is registered.
const tooManyAttempts = 'Πολλές αποτυχημένες προσπάθειες';

// A locked server's answer. Header names are lower-case, as in a real
// response (see api_service_test.dart).
http.Response locked({String? retryAfter}) => http.Response(
      '{"status":429,"detail":"Too many failed attempts, try again later"}',
      429,
      headers: {if (retryAfter != null) 'retry-after': retryAfter},
    );

Future<void> logIn(
    WidgetTester tester, ProviderContainer container, http.Response answer) async {
  await tester.pumpWidget(withAppState(container, MaterialApp(
    home: LoginScreen(
        apiService: ApiService(client: MockClient((_) async => answer))),
  )));
  await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'), 'worker@example.com');
  await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'), 'secret123');
  await tester.tap(find.widgetWithText(ElevatedButton, 'ΣΥΝΔΕΣΗ'));
  await tester.pumpAndSettle();
}

void main() {
  // Seconds from the server -> what the user reads. Rounded up: 59 s rounded
  // down is "0 minutes", while the lock is still on.
  final waits = {
    '1': '1 λεπτό',
    '59': '1 λεπτό',
    '60': '1 λεπτό',
    '61': '2 λεπτά',
    '900': '15 λεπτά',
  };

  waits.forEach((seconds, shown) {
    testWidgets('a lock with Retry-After: $seconds says "$shown"',
        (WidgetTester tester) async {
      final container = testContainer();

      await logIn(tester, container, locked(retryAfter: seconds));

      expect(find.textContaining(tooManyAttempts), findsOneWidget);
      expect(find.textContaining(shown), findsOneWidget);
      expect(find.textContaining('Σφάλμα συστήματος'), findsNothing);
      // Still logged out, still on the login form.
      expect(container.read(authProvider)?.user, isNull);
      expect(find.widgetWithText(TextFormField, 'Email'), findsOneWidget);
    });
  });

  // Without a usable number the lock is still explained, just without the
  // wait. A date that int.parse throws on would otherwise end in the catch,
  // and the user would read "cannot reach the server".
  final unusable = {
    'no Retry-After': null,
    'a date in Retry-After': 'Wed, 21 Oct 2026 07:28:00 GMT',
  };

  unusable.forEach((name, retryAfter) {
    testWidgets('a lock with $name is explained without a wait',
        (WidgetTester tester) async {
      final container = testContainer();

      await logIn(tester, container, locked(retryAfter: retryAfter));

      expect(find.textContaining(tooManyAttempts), findsOneWidget);
      expect(find.textContaining('λεπτ'), findsNothing);
      expect(find.textContaining('Αδυναμία σύνδεσης'), findsNothing);
      expect(container.read(authProvider)?.user, isNull);
    });
  });
}
