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
/// answer to "assign a shift", with [problemType] in its body if given (B31).
/// Each body it is sent goes into [posted].
ApiService serverAnsweringAssign(int assignStatus,
        {String? problemType, List<String>? posted}) =>
    ApiService(client: MockClient((request) async {
      if (request.method == 'POST') {
        posted?.add(request.body);
        final type = problemType == null ? '' : '"type":"$problemType",';
        return http.Response('{$type"status":$assignStatus}', assignStatus);
      }
      if (request.url.path == '/api/v1/users') {
        return http.Response(
            '{"content":[{"id":7,"name":"Worker","email":"worker@example.com","role":"EMPLOYEE"}],'
            '"page":0,"size":100,"totalElements":1,"totalPages":1}',
            200);
      }
      return http.Response('[]', 200); // the month's shifts
    }));

/// Opens the assign dialog on the 15th and picks the employee.
Future<void> openAssignDialog(WidgetTester tester, ApiService api) async {
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
}

/// Opens the assign dialog, picks the employee and presses Save.
Future<void> assignAShift(WidgetTester tester, ApiService api) async {
  await openAssignDialog(tester, api);
  await tester.tap(find.text('Αποθήκευση'));
  await tester.pumpAndSettle();
}

/// In an open time picker, types [hour] and [minute] and presses OK.
Future<void> typeInTimePicker(WidgetTester tester, String hour, String minute) async {
  // The picker opens on the clock dial; the keyboard icon switches it to two
  // text fields, which a test can fill without aiming at the dial.
  await tester.tap(find.byIcon(Icons.keyboard_outlined));
  await tester.pumpAndSettle();
  final fields = find.descendant(
      of: find.byType(TimePickerDialog), matching: find.byType(TextField));
  await tester.enterText(fields.at(0), hour);
  await tester.enterText(fields.at(1), minute);
  await tester.tap(find.text('OK'));
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

  // B31: the server refuses a shift on a day of approved leave with a 409 of
  // its own type. The overlap text would send the supervisor looking for a
  // shift that is not there.
  testWidgets('a shift on a leave day keeps the dialog open and says why',
      (WidgetTester tester) async {
    await assignAShift(
        tester,
        serverAnsweringAssign(409,
            problemType: 'urn:shift-manager:problem:employee-on-leave'));

    expect(find.text('Ο υπάλληλος έχει εγκεκριμένη άδεια αυτή την ημέρα.'),
        findsOneWidget);
    expect(find.textContaining('επικαλύπτεται'), findsNothing);
    expect(find.text('Αποθήκευση'), findsOneWidget); // still open
  });

  testWidgets('a saved shift closes the dialog', (WidgetTester tester) async {
    await assignAShift(tester, serverAnsweringAssign(201));

    expect(find.text('Αποθήκευση'), findsNothing);
  });

  // B24: the times used to be free text, and "8.00" reached the server as a
  // time it could not read. A picker cannot produce one.
  testWidgets('the start time is chosen with a time picker',
      (WidgetTester tester) async {
    await openAssignDialog(tester, serverAnsweringAssign(201));

    await tester.tap(find.textContaining('08:00'));
    await tester.pumpAndSettle();

    expect(find.byType(TimePickerDialog), findsOneWidget);
  });

  testWidgets('a picked time is sent as HH:mm, with leading zeros',
      (WidgetTester tester) async {
    final posted = <String>[];
    await openAssignDialog(tester, serverAnsweringAssign(201, posted: posted));

    await tester.tap(find.textContaining('08:00'));
    await tester.pumpAndSettle();
    await typeInTimePicker(tester, '7', '5');
    expect(find.textContaining('07:05'), findsOneWidget); // the row shows it

    await tester.tap(find.text('Αποθήκευση'));
    await tester.pumpAndSettle();

    expect(posted, hasLength(1));
    // "7:5" or "07:05 AM" would be refused, as "8.00" was.
    expect(posted.single, contains('"startTime":"07:05"'));
    expect(posted.single, contains('"endTime":"16:00"'));
  });

  testWidgets('cancelling the picker keeps the time that was there',
      (WidgetTester tester) async {
    final posted = <String>[];
    await openAssignDialog(tester, serverAnsweringAssign(201, posted: posted));

    await tester.tap(find.textContaining('16:00'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.textContaining('16:00'), findsOneWidget);
    await tester.tap(find.text('Αποθήκευση'));
    await tester.pumpAndSettle();
    expect(posted.single, contains('"endTime":"16:00"'));
  });

  // The test locale is English, which on its own would show a 12-hour clock.
  testWidgets('the time picker uses a 24-hour clock',
      (WidgetTester tester) async {
    await openAssignDialog(tester, serverAnsweringAssign(201));

    await tester.tap(find.textContaining('08:00'));
    await tester.pumpAndSettle();

    expect(find.byType(TimePickerDialog), findsOneWidget);
    expect(find.text('AM'), findsNothing);
    expect(find.text('PM'), findsNothing);
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
