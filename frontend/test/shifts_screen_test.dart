// F30 / B24: when the server refuses a shift, the assign dialog must say why
// and stay open. Before this, it just sat there and the supervisor could not
// tell a saved shift from a refused one.

import 'dart:async';

import 'package:employee_shift_management_ui/models/user_model.dart';
import 'package:employee_shift_management_ui/screens/shifts_screen.dart';
import 'package:employee_shift_management_ui/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'helpers/app_scope.dart';

/// A fake server: an empty calendar, one employee, and [assignStatus] as the
/// answer to "assign a shift".
ApiService serverAnsweringAssign(int assignStatus) =>
    ApiService(client: MockClient((request) async {
      if (request.method == 'POST') {
        return http.Response('{"status":$assignStatus}', assignStatus);
      }
      if (request.url.path == '/api/v1/users') {
        return http.Response(
            '{"content":[{"id":7,"name":"Worker","email":"worker@example.com","role":"EMPLOYEE"}],'
            '"page":0,"size":100,"totalElements":1,"totalPages":1}',
            200);
      }
      return http.Response('[]', 200); // the month's shifts
    }));

/// Opens the assign dialog on the 15th, picks the employee and presses Save.
Future<void> assignAShift(WidgetTester tester, ApiService api) async {
  final boss =
      User(id: 9, name: 'Boss', email: 'boss@example.com', role: 'SUPERVISOR');
  await tester.pumpWidget(withAppState(testContainer(user: boss),
      MaterialApp(home: ShiftsScreen(apiService: api))));
  await tester.pumpAndSettle();

  // The calendar shows the current month; the 15th appears in it exactly once.
  await tester.longPress(find.text('15'));
  await tester.pumpAndSettle();

  await tester.tap(find.byType(DropdownButton<User>));
  await tester.pumpAndSettle();
  // An open dropdown also keeps its closed button in the tree, hence .last.
  await tester.tap(find.text('Worker').last);
  await tester.pumpAndSettle();

  await tester.tap(find.text('Αποθήκευση'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('an overlapping shift keeps the dialog open and says why',
      (WidgetTester tester) async {
    await assignAShift(tester, serverAnsweringAssign(409));

    expect(
        find.text('Ο υπάλληλος έχει ήδη βάρδια που επικαλύπτεται με αυτές τις ώρες.'),
        findsOneWidget);
    expect(find.text('Αποθήκευση'), findsOneWidget); // still open
  });

  testWidgets('a saved shift closes the dialog', (WidgetTester tester) async {
    await assignAShift(tester, serverAnsweringAssign(201));

    expect(find.text('Αποθήκευση'), findsNothing);
  });

  testWidgets('a staff list that fails to load says so (B34)',
      (WidgetTester tester) async {
    final boss =
        User(id: 9, name: 'Boss', email: 'boss@example.com', role: 'SUPERVISOR');
    final api = ApiService(client: MockClient((request) async {
      if (request.url.path == '/api/v1/users') return http.Response('', 500);
      return http.Response('[]', 200); // the month's shifts
    }));
    await tester.pumpWidget(withAppState(testContainer(user: boss),
        MaterialApp(home: ShiftsScreen(apiService: api))));
    await tester.pumpAndSettle();

    await tester.longPress(find.text('15'));
    await tester.pumpAndSettle();

    expect(find.text('Δεν ήταν δυνατή η φόρτωση των υπαλλήλων. Δοκιμάστε ξανά.'),
        findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
  });

  // F25: the error path runs after the await too. A failed reply goes to the
  // catch block, which must not touch a screen that has closed either.
  testWidgets('a failed reply that arrives after the screen closed is ignored',
      (WidgetTester tester) async {
    final boss =
        User(id: 9, name: 'Boss', email: 'boss@example.com', role: 'SUPERVISOR');
    // The month's shifts wait until the test completes this.
    final reply = Completer<http.Response>();
    final api = ApiService(client: MockClient((_) => reply.future));
    final navigator = GlobalKey<NavigatorState>();

    await tester.pumpWidget(withAppState(testContainer(user: boss),
        MaterialApp(navigatorKey: navigator, home: const Text('Home'))));
    navigator.currentState!
        .push(MaterialPageRoute(builder: (_) => ShiftsScreen(apiService: api)));
    // pump, not pumpAndSettle: the spinner animates forever, so it never
    // settles. A pushed page spends its first frame offstage (being measured
    // for the transition), and finders skip offstage widgets, so move time
    // past the transition before looking.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    navigator.currentState!.pop();
    await tester.pumpAndSettle(); // the screen is gone now

    // getAllShifts throws on a 500, so this lands in _loadShifts' catch.
    reply.complete(http.Response('', 500));
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
  });
}
