// Saving your profile must show the new values at once. Before F24 step 24c
// ApiService edited the user in place and the screen repainted only because
// of an empty setState(() {}); now the session is replaced and the screen,
// which watches it, rebuilds by itself.
//
// Changing the password (B8) goes through the real screen and dialog, with
// only the network faked: the button, the phone-side checks, what the dialog
// shows for each answer, and the screen's message afterwards.

import 'dart:async';
import 'dart:convert';

import 'package:employee_shift_management_ui/models/user_model.dart';
import 'package:employee_shift_management_ui/screens/profile_screen.dart';
import 'package:employee_shift_management_ui/services/api_service.dart';
import 'package:employee_shift_management_ui/state/auth_session.dart';
import 'package:employee_shift_management_ui/widgets/change_password_dialog.dart';
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

  // B35: the edit dialog moved into its own StatefulWidget, so its three
  // controllers are released when it closes. These pin what it did before.
  group('the edit dialog', () {
    String fieldText(WidgetTester tester, String label) =>
        tester.widget<TextField>(find.widgetWithText(TextField, label)).controller!.text;

    testWidgets('opens with the current name, email and phone',
        (WidgetTester tester) async {
      final container = testContainer(
          user: User(id: 7, name: 'Worker', email: 'worker@example.com',
              phoneNumber: '6900000000', role: 'EMPLOYEE'));
      final api = ApiService(
          client: MockClient((_) async => http.Response('', 500)));

      await tester.pumpWidget(
          withAppState(container, MaterialApp(home: ProfileScreen(apiService: api))));
      await tester.tap(find.byIcon(Icons.edit));
      await tester.pumpAndSettle();

      expect(fieldText(tester, 'Όνομα'), 'Worker');
      expect(fieldText(tester, 'Email'), 'worker@example.com');
      expect(fieldText(tester, 'Τηλέφωνο'), '6900000000');
    });

    testWidgets('cancelling sends nothing and keeps the profile',
        (WidgetTester tester) async {
      var requests = 0;
      final container = testContainer(
          user: User(id: 7, name: 'Worker', email: 'worker@example.com', role: 'EMPLOYEE'));
      final api = ApiService(client: MockClient((_) async {
        requests++;
        return http.Response('', 500);
      }));

      await tester.pumpWidget(
          withAppState(container, MaterialApp(home: ProfileScreen(apiService: api))));
      await tester.tap(find.byIcon(Icons.edit));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Όνομα'), 'New Name');
      await tester.tap(find.widgetWithText(TextButton, 'Ακύρωση'));
      await tester.pumpAndSettle();

      expect(requests, 0);
      expect(find.byType(AlertDialog), findsNothing);
      expect(container.read(authProvider)!.user.name, 'Worker');
    });

    // F25: a tap outside closes the dialog while the save is on its way. The
    // server stored the new name anyway, so the session must get it too -
    // the reason the dialog reports through onSaved instead of popping with
    // the user, which a closed dialog can no longer do.
    testWidgets('a save that finishes after the dialog was closed still updates the session',
        (WidgetTester tester) async {
      final saveReply = Completer<http.Response>();
      final container = testContainer(
          user: User(id: 7, name: 'Worker', email: 'worker@example.com', role: 'EMPLOYEE'));
      final api = ApiService(client: MockClient((_) => saveReply.future));

      await tester.pumpWidget(
          withAppState(container, MaterialApp(home: ProfileScreen(apiService: api))));
      await tester.tap(find.byIcon(Icons.edit));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Όνομα'), 'New Name');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Αποθήκευση'));
      await tester.pump();

      // Close the dialog by tapping outside it (the barrier) mid-request.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);

      saveReply.complete(http.Response(
          jsonEncode({'id': 7, 'name': 'New Name', 'email': 'worker@example.com',
              'role': 'EMPLOYEE'}),
          200));
      await tester.pumpAndSettle();

      expect(container.read(authProvider)!.user.name, 'New Name');
      expect(find.text('New Name'), findsOneWidget);
    });

    // The same tap outside, but the save fails. The screen is still there, so
    // it must still say so - the dialog that would have is gone.
    testWidgets('a save that fails after the dialog was closed still says so',
        (WidgetTester tester) async {
      final saveReply = Completer<http.Response>();
      final container = testContainer(
          user: User(id: 7, name: 'Worker', email: 'worker@example.com', role: 'EMPLOYEE'));
      final api = ApiService(client: MockClient((_) => saveReply.future));

      await tester.pumpWidget(
          withAppState(container, MaterialApp(home: ProfileScreen(apiService: api))));
      await tester.tap(find.byIcon(Icons.edit));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Αποθήκευση'));
      await tester.pump();

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);

      saveReply.complete(http.Response('', 400));
      await tester.pumpAndSettle();

      expect(find.text('Σφάλμα κατά την ενημέρωση'), findsOneWidget);
      expect(container.read(authProvider)!.user.name, 'Worker');
    });

    // B73: Save stayed enabled while the request was on its way, so a double
    // tap sent the profile twice and said so twice. pump, not pumpAndSettle,
    // while a reply is held: the spinner animates forever, so it never
    // settles.
    group('while it is being saved', () {
      final spinner = find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(CircularProgressIndicator));
      final savedReply = http.Response(
          jsonEncode({'id': 7, 'name': 'Worker', 'email': 'worker@example.com',
              'role': 'EMPLOYEE'}),
          200);

      /// Opens the edit dialog with each save waiting for the test to
      /// complete the Completer it adds to [held].
      Future<void> openHeld(
          WidgetTester tester, List<Completer<http.Response>> held) async {
        final container = testContainer(
            user: User(id: 7, name: 'Worker', email: 'worker@example.com', role: 'EMPLOYEE'));
        final api = ApiService(client: MockClient((_) {
          final reply = Completer<http.Response>();
          held.add(reply);
          return reply.future;
        }));
        await tester.pumpWidget(
            withAppState(container, MaterialApp(home: ProfileScreen(apiService: api))));
        await tester.tap(find.byIcon(Icons.edit));
        await tester.pumpAndSettle();
      }

      testWidgets('a double tap saves once', (WidgetTester tester) async {
        final held = <Completer<http.Response>>[];
        await openHeld(tester, held);

        // Where the finger is: the button's text is gone once it spins.
        final save = tester.getCenter(find.widgetWithText(ElevatedButton, 'Αποθήκευση'));
        await tester.tapAt(save);
        await tester.pump();
        await tester.tapAt(save);
        await tester.pump();

        expect(held, hasLength(1));
        held.single.complete(savedReply);
        await tester.pumpAndSettle();
      });

      testWidgets('Save is off and shows a spinner', (WidgetTester tester) async {
        final held = <Completer<http.Response>>[];
        await openHeld(tester, held);

        await tester.tap(find.widgetWithText(ElevatedButton, 'Αποθήκευση'));
        await tester.pump();

        expect(spinner, findsOneWidget);
        final save = tester.widget<ElevatedButton>(
            find.ancestor(of: spinner, matching: find.byType(ElevatedButton)));
        expect(save.onPressed, isNull);
        held.single.complete(savedReply);
        await tester.pumpAndSettle();
      });

      // The dialog stays open after a failure; Save must work again.
      testWidgets('a failed save turns Save back on', (WidgetTester tester) async {
        final held = <Completer<http.Response>>[];
        await openHeld(tester, held);

        await tester.tap(find.widgetWithText(ElevatedButton, 'Αποθήκευση'));
        await tester.pump();
        held.single.complete(http.Response('', 400));
        await tester.pumpAndSettle();

        expect(spinner, findsNothing);
        await tester.tap(find.widgetWithText(ElevatedButton, 'Αποθήκευση'));
        await tester.pump();
        expect(held, hasLength(2));
        held.last.complete(savedReply);
        await tester.pumpAndSettle();
      });
    });
  });

  group('changing the password (B8)', () {
    User worker() =>
        User(id: 7, name: 'Worker', email: 'worker@example.com', role: 'EMPLOYEE');

    Future<void> openDialog(
        WidgetTester tester, ProviderContainer container, ApiService api) async {
      await tester.pumpWidget(
          withAppState(container, MaterialApp(home: ProfileScreen(apiService: api))));
      final button = find.widgetWithText(OutlinedButton, 'Αλλαγή κωδικού');
      // The button is at the bottom of the profile; on the test's small
      // screen it may be below the fold, where a tap would miss it.
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
    }

    Future<void> fillIn(WidgetTester tester,
        {String current = 'old-secret',
        String newPassword = 'new-secret',
        String? confirm}) async {
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Τρέχων κωδικός'), current);
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Νέος κωδικός'), newPassword);
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Επιβεβαίωση νέου κωδικού'),
          confirm ?? newPassword);
    }

    final save = find.widgetWithText(ElevatedButton, 'Αποθήκευση');

    testWidgets('a changed password closes the dialog and keeps the login',
        (WidgetTester tester) async {
      final container = testContainer(user: worker());
      final api = ApiService(client: MockClient((_) async => http.Response('', 204)));

      await openDialog(tester, container, api);
      await fillIn(tester);
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(find.byType(ChangePasswordDialog), findsNothing);
      expect(find.text('Ο κωδικός άλλαξε επιτυχώς!'), findsOneWidget);
      // The token stays valid after a password change, so nothing about the
      // session may change - least of all a logout.
      expect(container.read(authProvider)?.token, 'test-token');
    });

    testWidgets('a wrong current password keeps the dialog open and says so',
        (WidgetTester tester) async {
      final container = testContainer(user: worker());
      final api = ApiService(client: MockClient((_) async => http.Response(
          '{"status":400,"detail":"Current password is incorrect"}', 400)));

      await openDialog(tester, container, api);
      await fillIn(tester);
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(find.byType(ChangePasswordDialog), findsOneWidget);
      expect(find.text('Ο τρέχων κωδικός είναι λάθος.'), findsOneWidget);
      expect(find.text('Ο κωδικός άλλαξε επιτυχώς!'), findsNothing);
      expect(container.read(authProvider)?.token, 'test-token');
      // Enabled again, so the user can correct it and retry.
      expect(tester.widget<ElevatedButton>(save).onPressed, isNotNull);
    });

    testWidgets('a locked password change keeps the dialog open and the login (B56)',
        (WidgetTester tester) async {
      final container = testContainer(user: worker());
      final api = ApiService(client: MockClient((_) async => http.Response(
          '{"status":429,"detail":"Too many failed attempts, try again later"}',
          429,
          headers: {'retry-after': '900'})));

      await openDialog(tester, container, api);
      await fillIn(tester);
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(find.byType(ChangePasswordDialog), findsOneWidget);
      expect(find.textContaining('Πολλές αποτυχημένες προσπάθειες'), findsOneWidget);
      // Not the general message: "try again" now would only be refused.
      expect(find.text('Η αλλαγή απέτυχε. Δοκιμάστε ξανά.'), findsNothing);
      // A 429 is not a rejected token: the user stays logged in.
      expect(container.read(authProvider)?.token, 'test-token');
    });

    // Each mistake the phone can see is shown at its field, and no request
    // is sent for it.
    final mistakes = {
      'a blank current password': (
        fields: (current: '', newPassword: 'new-secret', confirm: null),
        message: 'Συμπληρώστε τον τρέχοντα κωδικό',
      ),
      'a new password typed differently twice': (
        fields: (current: 'old-secret', newPassword: 'new-secret', confirm: 'new-secreT'),
        message: 'Οι κωδικοί δεν ταιριάζουν',
      ),
      'a new password under 4 characters': (
        fields: (current: 'old-secret', newPassword: 'abc', confirm: null),
        message: 'Ο κωδικός πρέπει να έχει τουλάχιστον 4 χαρακτήρες',
      ),
      // 37 characters, but 74 bytes: a character count would let it through.
      'a new password over 72 bytes': (
        fields: (current: 'old-secret', newPassword: 'κ' * 37, confirm: null),
        message: 'Ο κωδικός είναι πολύ μεγάλος',
      ),
    };

    mistakes.forEach((name, mistake) {
      testWidgets('$name is refused without asking the server',
          (WidgetTester tester) async {
        var requests = 0;
        final container = testContainer(user: worker());
        final api = ApiService(client: MockClient((_) async {
          requests++;
          return http.Response('', 204);
        }));

        await openDialog(tester, container, api);
        await fillIn(tester,
            current: mistake.fields.current,
            newPassword: mistake.fields.newPassword,
            confirm: mistake.fields.confirm);
        await tester.tap(save);
        await tester.pumpAndSettle();

        expect(requests, 0);
        expect(find.text(mistake.message), findsOneWidget);
        expect(find.byType(ChangePasswordDialog), findsOneWidget);
      });
    });

    testWidgets('a 72-byte new password is accepted', (WidgetTester tester) async {
      var requests = 0;
      final container = testContainer(user: worker());
      final api = ApiService(client: MockClient((_) async {
        requests++;
        return http.Response('', 204);
      }));

      await openDialog(tester, container, api);
      // "At most 72", as on the server: 36 Greek letters are exactly 72 bytes.
      await fillIn(tester, newPassword: 'κ' * 36);
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(requests, 1);
    });

    testWidgets('save cannot be tapped twice while the change is on its way',
        (WidgetTester tester) async {
      var requests = 0;
      final answer = Completer<http.Response>();
      final container = testContainer(user: worker());
      final api = ApiService(client: MockClient((_) {
        requests++;
        return answer.future;
      }));

      await openDialog(tester, container, api);
      await fillIn(tester);
      await tester.tap(save);
      await tester.pump(); // the request is sent, the answer has not come

      expect(tester.widget<ElevatedButton>(save).onPressed, isNull);
      await tester.tap(save, warnIfMissed: false);
      expect(requests, 1);

      answer.complete(http.Response('', 204));
      await tester.pumpAndSettle();
      expect(find.byType(ChangePasswordDialog), findsNothing);
    });

    testWidgets('cancelling sends nothing and says nothing',
        (WidgetTester tester) async {
      var requests = 0;
      final container = testContainer(user: worker());
      final api = ApiService(client: MockClient((_) async {
        requests++;
        return http.Response('', 204);
      }));

      await openDialog(tester, container, api);
      await fillIn(tester);
      await tester.tap(find.widgetWithText(TextButton, 'Ακύρωση'));
      await tester.pumpAndSettle();

      expect(requests, 0);
      expect(find.byType(ChangePasswordDialog), findsNothing);
      expect(find.text('Ο κωδικός άλλαξε επιτυχώς!'), findsNothing);
    });
  });
}
