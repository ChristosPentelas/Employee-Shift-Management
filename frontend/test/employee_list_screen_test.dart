// Account creation lives in the supervisor's employee list (F1 step 5).
// The screens get an ApiService with a fake server, so no backend is needed.

import 'dart:async';

import 'package:employee_shift_management_ui/models/user_model.dart';
import 'package:employee_shift_management_ui/screens/employee_list_screen.dart';
import 'package:employee_shift_management_ui/services/api_providers.dart';
import 'package:employee_shift_management_ui/services/api_service.dart';
import 'package:employee_shift_management_ui/services/auth_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'helpers/app_scope.dart';

User supervisor() =>
    User(id: 9, name: 'Boss', email: 'boss@example.com', role: 'SUPERVISOR');

User employee() =>
    User(id: 7, name: 'Worker', email: 'worker@example.com', role: 'EMPLOYEE');

// An empty page, the server's list shape since F9.
ApiService emptyListServer() => ApiService(
    client: MockClient((_) async => http.Response(
        '{"content":[],"page":0,"size":100,"totalElements":0,"totalPages":0}',
        200)));

Widget appWith(ProviderContainer container, ApiService api) =>
    withAppState(container, MaterialApp(home: EmployeeListScreen(apiService: api)));

void main() {
  testWidgets('a supervisor sees the add-employee button',
      (WidgetTester tester) async {
    final container = testContainer(user: supervisor());

    await tester.pumpWidget(appWith(container, emptyListServer()));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.person_add), findsOneWidget);
  });

  testWidgets('an employee does not see the add-employee button',
      (WidgetTester tester) async {
    final container = testContainer(user: employee());

    await tester.pumpWidget(appWith(container, emptyListServer()));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.person_add), findsNothing);
  });

  testWidgets(
      'a supervisor creates an account with their token, and the list reloads',
      (WidgetTester tester) async {
    final container = testContainer(user: supervisor());

    final requests = <http.BaseRequest>[];
    var listCalls = 0;
    final server = MockClient((request) async {
      requests.add(request);
      if (request.method == 'POST') {
        return http.Response(
            '{"id":8,"name":"New Hire","email":"new@example.com","role":"EMPLOYEE"}',
            201);
      }
      listCalls++;
      // Empty before the account exists, then the new employee.
      return http.Response(
          listCalls == 1
              ? '{"content":[],"page":0,"size":100,"totalElements":0,"totalPages":0}'
              : '{"content":[{"id":8,"name":"New Hire","email":"new@example.com","role":"EMPLOYEE"}],'
                  '"page":0,"size":100,"totalElements":1,"totalPages":1}',
          200);
    });
    final api = ApiService(
        client: AuthClient(
            inner: server, token: () => 'supervisor-token', onTokenRejected: (_) {}));

    await tester.pumpWidget(appWith(container, api));
    await tester.pumpAndSettle();
    expect(find.text('Δεν βρέθηκαν υπάλληλοι.'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.person_add));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Ονομα'), 'New Hire');
    await tester.enterText(
        find.widgetWithText(TextField, 'Email'), 'new@example.com');
    await tester.enterText(
        find.widgetWithText(TextField, 'Κωδικός'), 'secret123');
    await tester.tap(find.text('Δημιουργία Λογαριασμού'));
    await tester.pumpAndSettle();

    final create = requests.singleWhere((r) => r.method == 'POST');
    expect(create.url.path, '/api/v1/users');
    // What F1 step 6 depends on: account creation carries a supervisor token.
    expect(create.headers['Authorization'], 'Bearer supervisor-token');

    // Back on the list, which reloaded and shows the new employee.
    expect(find.text('New Hire'), findsOneWidget);
  });

  // F25: the details screen used to show "deleted" through the context of a
  // dialog it had just closed, after closing itself too. Now it only reports
  // back, and the list - the screen on display - shows the message.
  testWidgets(
      'deleting an employee returns to the list, which reloads and says so',
      (WidgetTester tester) async {
    final requests = <String>[];
    var listCalls = 0;
    final network = MockClient((request) async {
      requests.add('${request.method} ${request.url.path}');
      if (request.method == 'DELETE') return http.Response('', 204);
      listCalls++;
      // The employee before the delete, nobody after it.
      return http.Response(
          listCalls == 1
              ? '{"content":[{"id":7,"name":"Worker","email":"worker@example.com","role":"EMPLOYEE"}],'
                  '"page":0,"size":100,"totalElements":1,"totalPages":1}'
              : '{"content":[],"page":0,"size":100,"totalElements":0,"totalPages":0}',
          200);
    });
    // The details screen takes its ApiService from the providers, so the
    // network is faked there rather than passed to the list.
    final container = testContainer(
        user: supervisor(),
        overrides: [networkClientProvider.overrideWithValue(network)]);

    await tester.pumpWidget(
        withAppState(container, MaterialApp(home: EmployeeListScreen())));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Worker'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Διαγραφή Υπαλλήλου'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Διαγραφή')); // the dialog's confirm button
    await tester.pumpAndSettle();

    expect(requests, contains('DELETE /api/v1/users/7'));
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Δεν βρέθηκαν υπάλληλοι.'), findsOneWidget); // reloaded
    expect(find.text('Ο υπάλληλος διαγράφηκε επιτυχώς'), findsOneWidget);
  });

  // B41: it used to read "Σφάλμα: Exception: Σφάλμα κατά τη διαγραφή:
  // Exception: Αποτυχία διαγραφής: 500".
  testWidgets('a failed delete says so in Greek and stays on the details screen',
      (WidgetTester tester) async {
    final network = MockClient((request) async {
      if (request.method == 'DELETE') return http.Response('', 500);
      return http.Response(
          '{"content":[{"id":7,"name":"Worker","email":"worker@example.com","role":"EMPLOYEE"}],'
          '"page":0,"size":100,"totalElements":1,"totalPages":1}',
          200);
    });
    final container = testContainer(
        user: supervisor(),
        overrides: [networkClientProvider.overrideWithValue(network)]);

    await tester.pumpWidget(
        withAppState(container, MaterialApp(home: EmployeeListScreen())));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Worker'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Διαγραφή Υπαλλήλου'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Διαγραφή')); // the dialog's confirm button
    await tester.pumpAndSettle();

    expect(find.text('Η διαγραφή απέτυχε. Δοκιμάστε ξανά.'), findsOneWidget);
    expect(find.textContaining('Exception'), findsNothing);
    // Still on the details screen: nothing was deleted to go back and show.
    expect(find.text('Διαγραφή Υπαλλήλου'), findsOneWidget);
    expect(find.text('Ο υπάλληλος διαγράφηκε επιτυχώς'), findsNothing);
  });

  // B80: another supervisor deleted them first, so the server answers 404.
  // It used to say "try again" on the details screen of an employee who no
  // longer exists, and every retry was another 404.
  testWidgets('an employee already deleted: back on the list, which reloads and says so',
      (WidgetTester tester) async {
    var deletedElsewhere = false;
    final network = MockClient((request) async {
      if (request.method == 'DELETE') return http.Response('', 404);
      return http.Response(
          deletedElsewhere
              ? '{"content":[],"page":0,"size":100,"totalElements":0,"totalPages":0}'
              : '{"content":[{"id":7,"name":"Worker","email":"worker@example.com","role":"EMPLOYEE"}],'
                  '"page":0,"size":100,"totalElements":1,"totalPages":1}',
          200);
    });
    final container = testContainer(
        user: supervisor(),
        overrides: [networkClientProvider.overrideWithValue(network)]);

    await tester.pumpWidget(
        withAppState(container, MaterialApp(home: EmployeeListScreen())));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Worker'));
    await tester.pumpAndSettle();
    deletedElsewhere = true;
    await tester.tap(find.text('Διαγραφή Υπαλλήλου'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Διαγραφή')); // the dialog's confirm button
    await tester.pumpAndSettle();

    expect(find.text('Ο υπάλληλος είχε ήδη διαγραφεί.'), findsOneWidget);
    expect(find.text('Η διαγραφή απέτυχε. Δοκιμάστε ξανά.'), findsNothing);
    expect(find.text('Διαγραφή Υπαλλήλου'), findsNothing); // details closed
    expect(find.text('Δεν βρέθηκαν υπάλληλοι.'), findsOneWidget); // reloaded
  });

  // No answer at all: the error is thrown, logged, and a retry may work.
  testWidgets('a delete without a network says it failed and stays on the details screen',
      (WidgetTester tester) async {
    final network = MockClient((request) async {
      if (request.method == 'DELETE') throw http.ClientException('no network');
      return http.Response(
          '{"content":[{"id":7,"name":"Worker","email":"worker@example.com","role":"EMPLOYEE"}],'
          '"page":0,"size":100,"totalElements":1,"totalPages":1}',
          200);
    });
    final container = testContainer(
        user: supervisor(),
        overrides: [networkClientProvider.overrideWithValue(network)]);

    await tester.pumpWidget(
        withAppState(container, MaterialApp(home: EmployeeListScreen())));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Worker'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Διαγραφή Υπαλλήλου'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Διαγραφή')); // the dialog's confirm button
    await tester.pumpAndSettle();

    expect(find.text('Η διαγραφή απέτυχε. Δοκιμάστε ξανά.'), findsOneWidget);
    expect(find.text('Διαγραφή Υπαλλήλου'), findsOneWidget);
  });

  // B43: the dialog closes before the DELETE is sent, and nothing stopped the
  // supervisor from deleting the same employee again meanwhile. pump, not
  // pumpAndSettle, while a reply is held: the spinner never settles.
  group('while a delete is on its way', () {
    // bySubtype: OutlinedButton.icon builds a private subclass, which
    // find.byType (an exact type match) would miss.
    final deleteButton = find.ancestor(
        of: find.text('Διαγραφή Υπαλλήλου'),
        matching: find.bySubtype<OutlinedButton>());
    final spinner = find.descendant(
        of: deleteButton, matching: find.byType(CircularProgressIndicator));
    final confirm = find.text('Διαγραφή'); // the dialog's confirm button

    /// Opens Worker's details as a supervisor, each DELETE held in [held],
    /// and opens the delete question.
    Future<void> askToDelete(
        WidgetTester tester, List<Completer<http.Response>> held) async {
      final network = MockClient((request) {
        if (request.method == 'DELETE') {
          final reply = Completer<http.Response>();
          held.add(reply);
          return reply.future;
        }
        return Future.value(http.Response(
            '{"content":[{"id":7,"name":"Worker","email":"worker@example.com","role":"EMPLOYEE"}],'
            '"page":0,"size":100,"totalElements":1,"totalPages":1}',
            200));
      });
      final container = testContainer(
          user: supervisor(),
          overrides: [networkClientProvider.overrideWithValue(network)]);
      await tester.pumpWidget(
          withAppState(container, MaterialApp(home: EmployeeListScreen())));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Worker'));
      await tester.pumpAndSettle();
      await tester.tap(deleteButton);
      await tester.pumpAndSettle();
    }

    VoidCallback? onPressed(WidgetTester tester) =>
        tester.widget<ButtonStyleButton>(deleteButton).onPressed;

    testWidgets('the delete button is off and spins',
        (WidgetTester tester) async {
      final held = <Completer<http.Response>>[];
      await askToDelete(tester, held);

      await tester.tap(confirm);
      await tester.pump();

      expect(spinner, findsOneWidget);
      expect(onPressed(tester), isNull);
      held.single.complete(http.Response('', 204));
      await tester.pumpAndSettle();
    });

    // The bug itself: the question closes at once, so the same employee could
    // be deleted again while the first DELETE was on its way.
    testWidgets('the question cannot be opened again until the reply arrives',
        (WidgetTester tester) async {
      final held = <Completer<http.Response>>[];
      await askToDelete(tester, held);

      await tester.tap(confirm);
      // Long enough for the question to finish closing.
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(deleteButton);
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(AlertDialog), findsNothing);
      expect(held, hasLength(1));
      held.single.complete(http.Response('', 204));
      await tester.pumpAndSettle();
    });

    testWidgets('a failed delete turns the delete button back on',
        (WidgetTester tester) async {
      final held = <Completer<http.Response>>[];
      await askToDelete(tester, held);

      await tester.tap(confirm);
      await tester.pump();
      held.single.complete(http.Response('', 500));
      await tester.pumpAndSettle();

      expect(spinner, findsNothing);
      expect(onPressed(tester), isNotNull);
    });
  });

  // B41: a failed load used to show "Σφάλμα: Exception: Σφάλμα δικτύου: ..."
  // and offer no way to try again but leaving the screen.
  testWidgets('a list that fails to load says so in Greek and can be tried again',
      (WidgetTester tester) async {
    var failing = true;
    final api = ApiService(client: MockClient((_) async => failing
        ? http.Response('', 500)
        : http.Response(
            '{"content":[{"id":7,"name":"Worker","email":"worker@example.com","role":"EMPLOYEE"}],'
            '"page":0,"size":100,"totalElements":1,"totalPages":1}',
            200)));

    await tester.pumpWidget(appWith(testContainer(user: supervisor()), api));
    await tester.pumpAndSettle();

    expect(find.text('Δεν ήταν δυνατή η φόρτωση.'), findsOneWidget);
    expect(find.textContaining('Exception'), findsNothing);

    failing = false;
    await tester.tap(find.text('Δοκιμάστε ξανά'));
    await tester.pumpAndSettle();

    expect(find.text('Worker'), findsOneWidget);
    expect(find.text('Δεν ήταν δυνατή η φόρτωση.'), findsNothing);
  });
}
