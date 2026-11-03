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
/// Each body it is sent goes into [posted], and each load of the month's
/// shifts adds its path to [shiftLoads].
///
/// With [held], each "assign a shift" instead waits for the test to complete
/// the [Completer] it adds there, and [assignStatus] is not used (B32).
ApiService serverAnsweringAssign(int assignStatus,
        {String? problemType,
        List<String>? posted,
        List<String>? shiftLoads,
        List<Completer<http.Response>>? held}) =>
    ApiService(client: MockClient((request) async {
      if (request.method == 'POST') {
        posted?.add(request.body);
        if (held != null) {
          final reply = Completer<http.Response>();
          held.add(reply);
          return reply.future;
        }
        final type = problemType == null ? '' : '"type":"$problemType",';
        return http.Response('{$type"status":$assignStatus}', assignStatus);
      }
      if (request.url.path == '/api/v1/users') {
        return http.Response(
            '{"content":[{"id":7,"name":"Worker","email":"worker@example.com","role":"EMPLOYEE"}],'
            '"page":0,"size":100,"totalElements":1,"totalPages":1}',
            200);
      }
      shiftLoads?.add(request.url.path);
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
    // B75: the screen reports a refusal only once the dialog is gone; an
    // open dialog says it already.
    expect(find.byType(SnackBar), findsNothing);
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

  // B32: Save stayed enabled while the request was on its way, so a double
  // tap sent the shift twice.
  group('while a shift is being saved', () {
    // pump, not pumpAndSettle, while a reply is held: the spinner animates
    // forever, so it never settles.
    final spinner = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(CircularProgressIndicator));

    testWidgets('a double tap sends it once', (WidgetTester tester) async {
      final held = <Completer<http.Response>>[];
      await openAssignDialog(tester, serverAnsweringAssign(0, held: held));

      // Where the finger is: the button's text is gone once it spins.
      final save = tester.getCenter(find.text('Αποθήκευση'));
      await tester.tapAt(save);
      await tester.pump();
      await tester.tapAt(save);
      await tester.pump();

      expect(held, hasLength(1));
      held.single.complete(http.Response('{}', 201));
      await tester.pumpAndSettle();
    });

    testWidgets('Save is off and shows a spinner', (WidgetTester tester) async {
      final held = <Completer<http.Response>>[];
      await openAssignDialog(tester, serverAnsweringAssign(0, held: held));

      await tester.tap(find.text('Αποθήκευση'));
      await tester.pump();

      expect(spinner, findsOneWidget);
      final save = tester.widget<ElevatedButton>(
          find.ancestor(of: spinner, matching: find.byType(ElevatedButton)));
      expect(save.onPressed, isNull);
      held.single.complete(http.Response('{}', 201));
      await tester.pumpAndSettle();
    });

    // The supervisor fixes the times after a refusal; Save must work again.
    testWidgets('a refused shift turns Save back on',
        (WidgetTester tester) async {
      final held = <Completer<http.Response>>[];
      await openAssignDialog(tester, serverAnsweringAssign(0, held: held));

      await tester.tap(find.text('Αποθήκευση'));
      await tester.pump();
      held.single.complete(http.Response('{"status":409}', 409));
      await tester.pumpAndSettle();

      expect(spinner, findsNothing);
      await tester.tap(find.text('Αποθήκευση'));
      await tester.pump();
      expect(held, hasLength(2));
      held.last.complete(http.Response('{}', 201));
      await tester.pumpAndSettle();
    });

    // B35: the dialog moved into its own State. A tap outside can close it
    // while the shift is on its way; the two tests below pin what happens to
    // each answer then.
    Future<void> saveAndCloseTheDialog(WidgetTester tester) async {
      await tester.tap(find.text('Αποθήκευση'));
      await tester.pump();
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    }

    testWidgets('a shift saved after its dialog was closed still reloads the calendar',
        (WidgetTester tester) async {
      final held = <Completer<http.Response>>[];
      final shiftLoads = <String>[];
      await openAssignDialog(
          tester, serverAnsweringAssign(0, held: held, shiftLoads: shiftLoads));
      await saveAndCloseTheDialog(tester);
      final loadsBefore = shiftLoads.length;

      held.single.complete(http.Response('{}', 201));
      await tester.pumpAndSettle();

      expect(shiftLoads, hasLength(loadsBefore + 1));
    });

    // B75: this used to pin silence - the refusal went to the dialog, which
    // was gone, so the supervisor was left thinking the shift was in. The
    // screen says it now, with the dialog's reason. A setState on the
    // disposed State would throw, hence takeException.
    testWidgets('a shift refused after its dialog was closed still says so',
        (WidgetTester tester) async {
      final held = <Completer<http.Response>>[];
      final shiftLoads = <String>[];
      await openAssignDialog(
          tester, serverAnsweringAssign(0, held: held, shiftLoads: shiftLoads));
      await saveAndCloseTheDialog(tester);
      final loadsBefore = shiftLoads.length;

      held.single.complete(http.Response('{"status":409}', 409));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
          find.text('Η βάρδια δεν αποθηκεύτηκε. '
              'Ο υπάλληλος έχει ήδη βάρδια που επικαλύπτεται με αυτές τις ώρες.'),
          findsOneWidget);
      expect(shiftLoads, hasLength(loadsBefore));
    });
  });

  testWidgets('the typed position is sent',
      (WidgetTester tester) async {
    final posted = <String>[];
    await openAssignDialog(tester, serverAnsweringAssign(201, posted: posted));

    await tester.enterText(find.widgetWithText(TextField, 'Θέση εργασίας'), 'Cashier');
    await tester.tap(find.text('Αποθήκευση'));
    await tester.pumpAndSettle();

    expect(posted.single, contains('"position":"Cashier"'));
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

  // B33: a delete the server refused left the shift on the calendar and said
  // nothing, so the supervisor could not tell it apart from a slow one.
  group('deleting a shift', () {
    /// Opens the calendar as a supervisor against a fake server with one shift
    /// on the 15th, which answers the delete with [deleteStatus]; selects the
    /// 15th and confirms the delete. Returns how often the month was loaded.
    Future<List<String>> deleteAnswered(
        WidgetTester tester, int deleteStatus) async {
      final now = DateTime.now();
      final month = now.month.toString().padLeft(2, '0');
      final monthLoads = <String>[];
      final api = ApiService(client: MockClient((request) async {
        if (request.method == 'DELETE') return http.Response('', deleteStatus);
        monthLoads.add(request.url.path);
        return http.Response(
            '[{"id":3,"date":"${now.year}-$month-15","startTime":"08:00",'
            '"endTime":"16:00","position":"Cashier"}]',
            200);
      }));
      final boss = User(
          id: 9, name: 'Boss', email: 'boss@example.com', role: 'SUPERVISOR');
      await tester.pumpWidget(withAppState(testContainer(user: boss),
          MaterialApp(home: ShiftsScreen(apiService: api))));
      await tester.pumpAndSettle();

      await tester.tap(find.text('15'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.delete_sweep));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Διαγραφή')); // the dialog's confirm button
      await tester.pumpAndSettle();
      return monthLoads;
    }

    testWidgets('a deleted shift says so and reloads the calendar',
        (WidgetTester tester) async {
      final monthLoads = await deleteAnswered(tester, 204);

      expect(find.text('Η βάρδια διαγράφηκε'), findsOneWidget);
      expect(monthLoads, hasLength(2));
    });

    // Someone else got there first: the calendar on screen is out of date.
    testWidgets('a shift that was already gone says so and reloads',
        (WidgetTester tester) async {
      final monthLoads = await deleteAnswered(tester, 404);

      expect(find.text('Η βάρδια είχε ήδη διαγραφεί.'), findsOneWidget);
      expect(monthLoads, hasLength(2));
    });

    testWidgets('a failed delete says so and leaves the calendar alone',
        (WidgetTester tester) async {
      final monthLoads = await deleteAnswered(tester, 500);

      expect(find.text('Η διαγραφή απέτυχε. Δοκιμάστε ξανά.'), findsOneWidget);
      expect(monthLoads, hasLength(1)); // nothing changed, so no reload
      expect(find.text('Cashier'), findsOneWidget); // still listed
    });

    // B43: the dialog closes before the DELETE is sent, and nothing stopped
    // the supervisor from deleting the same shift again meanwhile. pump, not
    // pumpAndSettle, while a reply is held: the spinner never settles.
    group('while it is on its way', () {
      final spinner = find.descendant(
          of: find.byType(IconButton),
          matching: find.byType(CircularProgressIndicator));
      final confirm = find.text('Διαγραφή'); // the dialog's confirm button

      /// Opens the calendar as a supervisor with two shifts on the 15th, each
      /// DELETE held in [held]; selects the 15th and asks to delete the first.
      Future<void> askToDeleteFirst(
          WidgetTester tester, List<Completer<http.Response>> held) async {
        final now = DateTime.now();
        final day = '${now.year}-${now.month.toString().padLeft(2, '0')}-15';
        final api = ApiService(client: MockClient((request) {
          if (request.method == 'DELETE') {
            final reply = Completer<http.Response>();
            held.add(reply);
            return reply.future;
          }
          return Future.value(http.Response(
              '[{"id":3,"date":"$day","startTime":"08:00","endTime":"12:00","position":"Cashier"},'
              '{"id":4,"date":"$day","startTime":"13:00","endTime":"17:00","position":"Stock"}]',
              200));
        }));
        final boss = User(
            id: 9, name: 'Boss', email: 'boss@example.com', role: 'SUPERVISOR');
        await tester.pumpWidget(withAppState(testContainer(user: boss),
            MaterialApp(home: ShiftsScreen(apiService: api))));
        await tester.pumpAndSettle();

        await tester.tap(find.text('15'));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.delete_sweep).first);
        await tester.pumpAndSettle();
      }

      // Each shift is a Card; the calendar's own buttons are outside them.
      List<IconButton> deleteButtons(WidgetTester tester) => tester
          .widgetList<IconButton>(find.descendant(
              of: find.byType(Card), matching: find.byType(IconButton)))
          .toList();

      testWidgets('every delete button is off and the shift deleted spins',
          (WidgetTester tester) async {
        final held = <Completer<http.Response>>[];
        await askToDeleteFirst(tester, held);

        await tester.tap(confirm);
        await tester.pump();

        expect(spinner, findsOneWidget);
        expect(deleteButtons(tester), hasLength(2));
        // The other shift's too: one delete at a time.
        expect(deleteButtons(tester).map((b) => b.onPressed), everyElement(isNull));
        held.single.complete(http.Response('', 204));
        await tester.pumpAndSettle();
      });

      // The bug itself: the question closes at once, so the same shift could
      // be deleted again while the first DELETE was on its way.
      testWidgets('the question cannot be opened again until the reply arrives',
          (WidgetTester tester) async {
        final held = <Completer<http.Response>>[];
        await askToDeleteFirst(tester, held);

        await tester.tap(confirm);
        // Long enough for the question to finish closing.
        await tester.pump(const Duration(seconds: 1));
        await tester.tap(find
            .descendant(of: find.byType(Card), matching: find.byType(IconButton))
            .first);
        await tester.pump(const Duration(seconds: 1));

        expect(find.byType(AlertDialog), findsNothing);
        expect(held, hasLength(1));
        held.single.complete(http.Response('', 204));
        await tester.pumpAndSettle();
      });

      testWidgets('a failed delete turns the delete buttons back on',
          (WidgetTester tester) async {
        final held = <Completer<http.Response>>[];
        await askToDeleteFirst(tester, held);

        await tester.tap(confirm);
        await tester.pump();
        held.single.complete(http.Response('', 500));
        await tester.pumpAndSettle();

        expect(spinner, findsNothing);
        expect(deleteButtons(tester), hasLength(2));
        expect(deleteButtons(tester).map((b) => b.onPressed), everyElement(isNotNull));
      });
    });
  });
}
