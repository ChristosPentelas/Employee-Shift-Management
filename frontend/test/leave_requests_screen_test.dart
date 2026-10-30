// F7 / F1 step 7c: an employee must not receive other people's leave requests
// at all. Before this, the screen downloaded every request and hid the rest.

import 'dart:async';
import 'dart:convert';

import 'package:employee_shift_management_ui/models/user_model.dart';
import 'package:employee_shift_management_ui/screens/leave_requests_screen.dart';
import 'package:employee_shift_management_ui/services/api_service.dart';
import 'package:employee_shift_management_ui/widgets/paged_list_footer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'helpers/app_scope.dart';

// What the server sends for no requests: the PageResponse shape (F9), with no
// pages at all.
const emptyPage =
    '{"content":[],"page":0,"size":50,"totalElements":0,"totalPages":0}';

void main() {
  /// Opens the screen and reports which paths it asked the server for.
  Future<List<String>> requestedPaths(
      WidgetTester tester, ProviderContainer container) async {
    final paths = <String>[];
    final api = ApiService(client: MockClient((request) async {
      paths.add(request.url.path);
      return http.Response(emptyPage, 200);
    }));

    await tester.pumpWidget(
        withAppState(container, MaterialApp(home: LeaveRequestsScreen(apiService: api))));
    await tester.pumpAndSettle();
    return paths;
  }

  testWidgets('an employee asks only for their own leave requests',
      (WidgetTester tester) async {
    final container = testContainer(
        user: User(id: 7, name: 'Worker', email: 'worker@example.com', role: 'EMPLOYEE'));

    expect(await requestedPaths(tester, container), ['/api/v1/users/7/leaves']);
  });

  testWidgets('a supervisor asks for every leave request',
      (WidgetTester tester) async {
    final container = testContainer(
        user: User(id: 9, name: 'Boss', email: 'boss@example.com', role: 'SUPERVISOR'));

    expect(await requestedPaths(tester, container), ['/api/v1/leaves']);
  });

  // B19: the label said the reason was optional, the server requires it, and
  // the dialog closed whatever the server answered - so a refused request
  // looked filed.
  group('filing a leave request', () {
    final worker =
        User(id: 7, name: 'Worker', email: 'worker@example.com', role: 'EMPLOYEE');

    /// Opens the screen as [worker] against a fake server that answers a new
    /// request with [postStatus], opens the dialog and picks tomorrow to the
    /// day after. Returns how many times the list was loaded.
    ///
    /// With [held], each new request instead waits for the test to complete
    /// the [Completer] it adds there, and [postStatus] is not used (B32).
    Future<List<String>> openDialogWithDates(WidgetTester tester, int postStatus,
        {List<Completer<http.Response>>? held}) async {
      final listLoads = <String>[];
      final api = ApiService(client: MockClient((request) async {
        if (request.method == 'POST') {
          if (held == null) return http.Response('{}', postStatus);
          final reply = Completer<http.Response>();
          held.add(reply);
          return reply.future;
        }
        listLoads.add(request.url.path);
        return http.Response(emptyPage, 200);
      }));
      await tester.pumpWidget(withAppState(testContainer(user: worker),
          MaterialApp(home: LeaveRequestsScreen(apiService: api))));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Επιλέξτε Ημερομηνίες'));
      await tester.pumpAndSettle();

      // Typing the dates is steadier than tapping days on a calendar whose
      // month depends on when the test runs. The test app is en_US: MM/dd/yyyy.
      await tester.tap(find.byTooltip('Switch to input'));
      await tester.pumpAndSettle();
      String typed(DateTime d) => '${d.month}/${d.day}/${d.year}';
      final now = DateTime.now();
      // Only the picker's fields: the dialog's reason field is a TextField too.
      final fields = find.descendant(
          of: find.byType(DateRangePickerDialog), matching: find.byType(TextField));
      await tester.enterText(fields.at(0), typed(now.add(Duration(days: 1))));
      await tester.enterText(fields.at(1), typed(now.add(Duration(days: 2))));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      return listLoads;
    }

    Finder submitButton() => find.widgetWithText(ElevatedButton, 'Υποβολή');

    bool submitEnabled(WidgetTester tester) =>
        tester.widget<ElevatedButton>(submitButton()).onPressed != null;

    testWidgets('cannot be submitted with a blank reason',
        (WidgetTester tester) async {
      await openDialogWithDates(tester, 201);

      expect(submitEnabled(tester), isFalse);

      // Spaces only: not empty, but the server's @NotBlank still refuses it.
      await tester.enterText(find.byType(TextField), '   ');
      await tester.pump();
      expect(submitEnabled(tester), isFalse);

      await tester.enterText(find.byType(TextField), 'Surgery');
      await tester.pump();
      expect(submitEnabled(tester), isTrue);
    });

    testWidgets('a refused request keeps the dialog open and says why',
        (WidgetTester tester) async {
      final listLoads = await openDialogWithDates(tester, 500);
      await tester.enterText(find.byType(TextField), 'Surgery');
      await tester.pump();

      await tester.tap(submitButton());
      await tester.pumpAndSettle();

      expect(find.text('Η αποθήκευση απέτυχε. Δοκιμάστε ξανά.'), findsOneWidget);
      expect(submitButton(), findsOneWidget); // still open
      expect(listLoads, hasLength(1)); // nothing was filed, so no reload
    });

    testWidgets('a filed request closes the dialog and reloads the list',
        (WidgetTester tester) async {
      final listLoads = await openDialogWithDates(tester, 201);
      await tester.enterText(find.byType(TextField), 'Surgery');
      await tester.pump();

      await tester.tap(submitButton());
      await tester.pumpAndSettle();

      expect(submitButton(), findsNothing);
      expect(listLoads, hasLength(2));
    });

    // B32: Submit stayed enabled while the request was on its way, so a
    // double tap filed the same leave twice - leave has no overlap check to
    // refuse the second. pump, not pumpAndSettle, while a reply is held: the
    // spinner animates forever, so it never settles.
    group('while it is being sent', () {
      final spinner = find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(CircularProgressIndicator));

      testWidgets('a double tap files it once', (WidgetTester tester) async {
        final held = <Completer<http.Response>>[];
        await openDialogWithDates(tester, 0, held: held);
        await tester.enterText(find.byType(TextField), 'Surgery');
        await tester.pump();

        // Where the finger is: the button's text is gone once it spins.
        final submit = tester.getCenter(submitButton());
        await tester.tapAt(submit);
        await tester.pump();
        await tester.tapAt(submit);
        await tester.pump();

        expect(held, hasLength(1));
        held.single.complete(http.Response('{}', 201));
        await tester.pumpAndSettle();
      });

      testWidgets('Submit is off and shows a spinner',
          (WidgetTester tester) async {
        final held = <Completer<http.Response>>[];
        await openDialogWithDates(tester, 0, held: held);
        await tester.enterText(find.byType(TextField), 'Surgery');
        await tester.pump();

        await tester.tap(submitButton());
        await tester.pump();

        expect(spinner, findsOneWidget);
        final submit = tester.widget<ElevatedButton>(
            find.ancestor(of: spinner, matching: find.byType(ElevatedButton)));
        expect(submit.onPressed, isNull);
        held.single.complete(http.Response('{}', 201));
        await tester.pumpAndSettle();
      });

      testWidgets('a refused request turns Submit back on',
          (WidgetTester tester) async {
        final held = <Completer<http.Response>>[];
        await openDialogWithDates(tester, 0, held: held);
        await tester.enterText(find.byType(TextField), 'Surgery');
        await tester.pump();

        await tester.tap(submitButton());
        await tester.pump();
        held.single.complete(http.Response('{}', 500));
        await tester.pumpAndSettle();

        expect(spinner, findsNothing);
        expect(submitEnabled(tester), isTrue);
        await tester.tap(submitButton());
        await tester.pump();
        expect(held, hasLength(2));
        held.last.complete(http.Response('{}', 201));
        await tester.pumpAndSettle();
      });

      // B35: the dialog moved into its own State. A tap outside can close it
      // while the request is on its way; the two tests below pin what
      // happens to each answer then.
      Future<void> submitAndCloseTheDialog(WidgetTester tester) async {
        await tester.enterText(find.byType(TextField), 'Surgery');
        await tester.pump();
        await tester.tap(submitButton());
        await tester.pump();
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
      }

      testWidgets('a request filed after its dialog was closed still reloads the list',
          (WidgetTester tester) async {
        final held = <Completer<http.Response>>[];
        final listLoads = await openDialogWithDates(tester, 0, held: held);
        await submitAndCloseTheDialog(tester);

        held.single.complete(http.Response('{}', 201));
        await tester.pumpAndSettle();

        expect(listLoads, hasLength(2));
      });

      // The refusal is shown inside the dialog, which is gone. What matters
      // is that nothing touches the closed dialog: a setState on a State
      // that was disposed throws.
      testWidgets('a request refused after its dialog was closed breaks nothing',
          (WidgetTester tester) async {
        final held = <Completer<http.Response>>[];
        final listLoads = await openDialogWithDates(tester, 0, held: held);
        await submitAndCloseTheDialog(tester);

        held.single.complete(http.Response('{}', 500));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(listLoads, hasLength(1));
      });
    });
  });

  // B42: the reply to approve or reject used to be ignored, so a refused
  // answer looked like it worked; B63 added the 409.
  group('a supervisor answering a request', () {
    final boss =
        User(id: 9, name: 'Boss', email: 'boss@example.com', role: 'SUPERVISOR');
    const pendingList = '{"content":[{"id":5,"startDate":"2026-10-01",'
        '"endDate":"2026-10-05","status":"PENDING","reason":"Surgery",'
        '"user":{"id":7,"name":"Worker","email":"worker@example.com",'
        '"role":"EMPLOYEE"}}],'
        '"page":0,"size":50,"totalElements":1,"totalPages":1}';

    /// Opens the screen as [boss] against a fake server that answers the PUT
    /// with [putStatus] and [putBody], and taps approve. Returns how many
    /// times the list was loaded.
    Future<List<String>> approveAnswered(WidgetTester tester, int putStatus,
        {String putBody = '{}'}) async {
      final listLoads = <String>[];
      final api = ApiService(client: MockClient((request) async {
        if (request.method == 'PUT') return http.Response(putBody, putStatus);
        listLoads.add(request.url.path);
        return http.Response(pendingList, 200);
      }));
      await tester.pumpWidget(withAppState(testContainer(user: boss),
          MaterialApp(home: LeaveRequestsScreen(apiService: api))));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.check_circle));
      await tester.pumpAndSettle();
      return listLoads;
    }

    testWidgets('an answer that worked reloads the list',
        (WidgetTester tester) async {
      final listLoads = await approveAnswered(tester, 200);

      expect(listLoads, hasLength(2));
      expect(find.byType(SnackBar), findsNothing);
    });

    // B31: approving removes the employee's shifts on the leave days, and the
    // server says how many. The supervisor should know their rota changed.
    testWidgets('an approval that removed shifts says how many',
        (WidgetTester tester) async {
      final listLoads = await approveAnswered(tester, 200,
          putBody: '{"id":5,"status":"APPROVED","removedShifts":2}');

      expect(find.text('Εγκρίθηκε. Αφαιρέθηκαν 2 βάρδιες.'), findsOneWidget);
      expect(listLoads, hasLength(2));
    });

    testWidgets('an approval that removed one shift says so in the singular',
        (WidgetTester tester) async {
      await approveAnswered(tester, 200,
          putBody: '{"id":5,"status":"APPROVED","removedShifts":1}');

      expect(find.text('Εγκρίθηκε. Αφαιρέθηκε 1 βάρδια.'), findsOneWidget);
    });

    testWidgets('an approval that removed no shifts says nothing extra',
        (WidgetTester tester) async {
      await approveAnswered(tester, 200,
          putBody: '{"id":5,"status":"APPROVED","removedShifts":0}');

      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('an answer the server refused says so and keeps the list',
        (WidgetTester tester) async {
      final listLoads = await approveAnswered(tester, 500);

      expect(find.text('Η αλλαγή απέτυχε. Δοκιμάστε ξανά.'), findsOneWidget);
      expect(listLoads, hasLength(1)); // nothing changed, so no reload
    });

    testWidgets('a request someone else answered first says so and reloads',
        (WidgetTester tester) async {
      final listLoads = await approveAnswered(tester, 409);

      expect(find.text('Η αίτηση έχει ήδη απαντηθεί.'), findsOneWidget);
      // The list is out of date: reloading shows the other supervisor's answer.
      expect(listLoads, hasLength(2));
    });

    testWidgets('a request that no longer exists says so and reloads',
        (WidgetTester tester) async {
      final listLoads = await approveAnswered(tester, 404);

      expect(find.text('Η αίτηση δεν υπάρχει πια.'), findsOneWidget);
      expect(listLoads, hasLength(2));
    });
  });

  // B26: the list used to stop at the server's first page, so a request on
  // page 2 - perhaps still PENDING - could not be seen or answered.
  group('older requests', () {
    final worker =
        User(id: 7, name: 'Worker', email: 'worker@example.com', role: 'EMPLOYEE');
    final boss =
        User(id: 9, name: 'Boss', email: 'boss@example.com', role: 'SUPERVISOR');

    /// One page of requests with these [ids], each with the reason "Reason <id>".
    String leavePage(int page, int totalPages, List<int> ids,
            {String status = 'APPROVED'}) =>
        jsonEncode({
          'content': [
            for (final id in ids)
              {
                'id': id,
                'startDate': '2026-10-01',
                'endDate': '2026-10-05',
                'status': status,
                'reason': 'Reason $id',
                'user': {
                  'id': 7,
                  'name': 'Worker',
                  'email': 'worker@example.com',
                  'role': 'EMPLOYEE'
                },
              }
          ],
          'page': page,
          'size': 50,
          'totalElements': ids.length,
          'totalPages': totalPages,
        });

    Finder footer() => find.byType(PagedListFooter);
    Finder shown(int id) => find.text('Λόγος: Reason $id');
    // More rows than the 600 px test screen holds. Since B26 step 26c3 the
    // list loads its next page once its last row comes into view, so a short
    // first page would load page 1 at once, before a test could look.
    final aScreenful = [for (var id = 1; id <= 20; id++) id];

    /// Opens the screen as [user]; [pages] answers each ?page= with a reply.
    /// Returns the pages asked for, in order. [settle] false only pumps: a
    /// page held back keeps the footer's spinner turning, which never settles.
    Future<List<String?>> openAs(WidgetTester tester, User user,
        Future<http.Response> Function(String? page) pages,
        {int putStatus = 200, bool settle = true}) async {
      final asked = <String?>[];
      final api = ApiService(client: MockClient((request) async {
        if (request.method == 'PUT') return http.Response('{}', putStatus);
        final page = request.url.queryParameters['page'];
        asked.add(page);
        return pages(page);
      }));
      await tester.pumpWidget(withAppState(testContainer(user: user),
          MaterialApp(home: LeaveRequestsScreen(apiService: api))));
      if (settle) {
        await tester.pumpAndSettle();
      } else {
        await tester.pump(); // page 0 arrives
        await tester.pump(); // the footer asks for page 1 after that frame
      }
      return asked;
    }

    Future<void> scrollToTheEnd(WidgetTester tester) async {
      await tester.drag(find.byType(ListView), const Offset(0, -5000));
      await tester.pumpAndSettle();
    }

    testWidgets('a list that fits on one page has no footer',
        (WidgetTester tester) async {
      final asked = await openAs(
          tester, worker, (_) async => http.Response(leavePage(0, 1, [1]), 200));

      expect(shown(1), findsOneWidget);
      expect(footer(), findsNothing);
      expect(asked, ['0']);
    });

    testWidgets('scrolling to the end loads the next page below',
        (WidgetTester tester) async {
      final asked = await openAs(tester, worker, (page) async => http.Response(
          page == '0' ? leavePage(0, 2, aScreenful) : leavePage(1, 2, [21]), 200));
      expect(asked, ['0'], reason: 'nobody has scrolled down yet');

      await scrollToTheEnd(tester);

      expect(asked, ['0', '1']);
      expect(shown(21), findsOneWidget);
      expect(tester.getTopLeft(shown(20)).dy, lessThan(tester.getTopLeft(shown(21)).dy));
      expect(footer(), findsNothing); // that was the last page
    });

    // A second load while one is on its way is ignored by PagedList itself
    // ("a second load more while a page is on its way asks only once" in
    // paged_list_test.dart); with no button there is nothing to tap twice here.

    testWidgets('a page that fails to load keeps the list and offers to try again',
        (WidgetTester tester) async {
      var failing = true;
      await openAs(tester, worker, (page) async {
        if (page == '0') return http.Response(leavePage(0, 2, [1]), 200);
        return failing ? http.Response('', 500) : http.Response(leavePage(1, 2, [2]), 200);
      });

      expect(shown(1), findsOneWidget);
      expect(find.text('Δοκιμάστε ξανά'), findsOneWidget);
      // Said once, in the list: no SnackBar on top of it since 26c3.
      expect(find.byType(SnackBar), findsNothing);

      failing = false;
      await tester.tap(find.text('Δοκιμάστε ξανά'));
      await tester.pumpAndSettle();

      expect(shown(2), findsOneWidget);
    });

    testWidgets('a request already shown is not shown twice',
        (WidgetTester tester) async {
      // Request 2 was last on page 0; a newer one filed in between pushed it
      // onto page 1 as well (B69). Short page: page 1 loads by itself.
      await openAs(tester, worker, (page) async => http.Response(
          page == '0' ? leavePage(0, 2, [1, 2]) : leavePage(1, 2, [2, 3]), 200));

      expect(shown(2), findsOneWidget);
      expect(shown(3), findsOneWidget);
    });

    testWidgets('answering a request starts the list again from page 0',
        (WidgetTester tester) async {
      final asked = await openAs(tester, boss, (page) async => http.Response(
          page == '0'
              ? leavePage(0, 2, aScreenful, status: 'PENDING')
              : leavePage(1, 2, [21], status: 'PENDING'),
          200));
      await scrollToTheEnd(tester);
      expect(shown(21), findsOneWidget);

      await tester.tap(find.byIcon(Icons.check_circle).last); // request 21
      await tester.pumpAndSettle();

      // Page 0 again, not page 1 again: the pages after it are dropped. The
      // list is still scrolled to its end, so the footer is in view and then
      // fetches page 1 anew - which is what infinite scroll should do.
      expect(asked.take(3), ['0', '1', '0']);
    });

    testWidgets('a page asked for before a reload is not added after it',
        (WidgetTester tester) async {
      final stale = Completer<http.Response>();
      var page1Requests = 0;
      await openAs(tester, boss, (page) {
        if (page == '0') {
          return Future.value(http.Response(leavePage(0, 2, [1], status: 'PENDING'), 200));
        }
        // The first page 1 is held back; the one asked for after the reload
        // answers at once, with a different request.
        page1Requests++;
        return page1Requests == 1
            ? stale.future
            : Future.value(http.Response(leavePage(1, 2, [3], status: 'PENDING'), 200));
      }, settle: false);
      expect(page1Requests, 1);

      // While page 1 is on its way, approving reloads the list from page 0.
      await tester.tap(find.byIcon(Icons.check_circle));
      await tester.pumpAndSettle();
      expect(shown(3), findsOneWidget);

      // The held page 1 belongs to the list from before the reload.
      stale.complete(http.Response(leavePage(1, 2, [2], status: 'PENDING'), 200));
      await tester.pumpAndSettle();

      expect(shown(1), findsOneWidget);
      expect(shown(2), findsNothing);
    });
  });
}