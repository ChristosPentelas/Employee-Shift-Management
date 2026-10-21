// F7 / F1 step 7c: an employee must not receive other people's leave requests
// at all. Before this, the screen downloaded every request and hid the rest.

import 'dart:async';
import 'dart:convert';

import 'package:employee_shift_management_ui/models/user_model.dart';
import 'package:employee_shift_management_ui/screens/leave_requests_screen.dart';
import 'package:employee_shift_management_ui/services/api_service.dart';
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
    Future<List<String>> openDialogWithDates(
        WidgetTester tester, int postStatus) async {
      final listLoads = <String>[];
      final api = ApiService(client: MockClient((request) async {
        if (request.method == 'POST') return http.Response('{}', postStatus);
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
    /// with [putStatus], and taps approve. Returns how many times the list
    /// was loaded.
    Future<List<String>> approveAnswered(WidgetTester tester, int putStatus) async {
      final listLoads = <String>[];
      final api = ApiService(client: MockClient((request) async {
        if (request.method == 'PUT') return http.Response('{}', putStatus);
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

    Finder loadMore() => find.text('Φόρτωση παλαιότερων');
    Finder shown(int id) => find.text('Λόγος: Reason $id');

    /// Opens the screen as [user]; [pages] answers each ?page= with a reply.
    /// Returns the pages asked for, in order.
    Future<List<String?>> openAs(WidgetTester tester, User user,
        Future<http.Response> Function(String? page) pages,
        {int putStatus = 200}) async {
      final asked = <String?>[];
      final api = ApiService(client: MockClient((request) async {
        if (request.method == 'PUT') return http.Response('{}', putStatus);
        final page = request.url.queryParameters['page'];
        asked.add(page);
        return pages(page);
      }));
      await tester.pumpWidget(withAppState(testContainer(user: user),
          MaterialApp(home: LeaveRequestsScreen(apiService: api))));
      await tester.pumpAndSettle();
      return asked;
    }

    testWidgets('a list that fits on one page has no load-more button',
        (WidgetTester tester) async {
      await openAs(tester, worker, (_) async => http.Response(leavePage(0, 1, [1]), 200));

      expect(shown(1), findsOneWidget);
      expect(loadMore(), findsNothing);
    });

    testWidgets('load more asks for the next page and adds it below',
        (WidgetTester tester) async {
      final asked = await openAs(tester, worker, (page) async => http.Response(
          page == '0' ? leavePage(0, 2, [1]) : leavePage(1, 2, [2]), 200));

      await tester.tap(loadMore());
      await tester.pumpAndSettle();

      expect(asked, ['0', '1']);
      expect(shown(1), findsOneWidget);
      expect(shown(2), findsOneWidget);
      expect(tester.getTopLeft(shown(1)).dy, lessThan(tester.getTopLeft(shown(2)).dy));
      expect(loadMore(), findsNothing); // that was the last page
    });

    testWidgets('a second tap while the page is on its way asks only once',
        (WidgetTester tester) async {
      final secondPage = Completer<http.Response>();
      final asked = await openAs(tester, worker, (page) => page == '0'
          ? Future.value(http.Response(leavePage(0, 2, [1]), 200))
          : secondPage.future);

      // No pump in between: the second tap reaches the same, still enabled
      // button, as a quick double tap does on a phone.
      await tester.tap(loadMore());
      await tester.tap(loadMore());
      await tester.pump();
      secondPage.complete(http.Response(leavePage(1, 2, [2]), 200));
      await tester.pumpAndSettle();

      expect(asked, ['0', '1']);
      expect(shown(2), findsOneWidget);
    });

    testWidgets('a page that fails to load keeps the list and says so',
        (WidgetTester tester) async {
      await openAs(tester, worker, (page) async => page == '0'
          ? http.Response(leavePage(0, 2, [1]), 200)
          : http.Response('', 500));

      await tester.tap(loadMore());
      await tester.pumpAndSettle();

      expect(shown(1), findsOneWidget);
      expect(find.text('Δεν ήταν δυνατή η φόρτωση. Δοκιμάστε ξανά.'), findsOneWidget);
      // Still there and enabled, so the supervisor can try again.
      expect(tester.widget<TextButton>(find.widgetWithText(TextButton, 'Φόρτωση παλαιότερων'))
          .onPressed, isNotNull);
    });

    testWidgets('a request already shown is not shown twice',
        (WidgetTester tester) async {
      // Request 2 was last on page 0; a newer one filed in between pushed it
      // onto page 1 as well (B69).
      await openAs(tester, worker, (page) async => http.Response(
          page == '0' ? leavePage(0, 2, [1, 2]) : leavePage(1, 2, [2, 3]), 200));

      await tester.tap(loadMore());
      await tester.pumpAndSettle();

      expect(shown(2), findsOneWidget);
      expect(shown(3), findsOneWidget);
    });

    testWidgets('answering a request starts the list again from page 0',
        (WidgetTester tester) async {
      final asked = await openAs(tester, boss, (page) async => http.Response(
          page == '0'
              ? leavePage(0, 2, [1], status: 'PENDING')
              : leavePage(1, 2, [2], status: 'PENDING'),
          200));
      await tester.tap(loadMore());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.check_circle).last); // request 2
      await tester.pumpAndSettle();

      expect(asked, ['0', '1', '0']);
      expect(shown(1), findsOneWidget);
      expect(shown(2), findsNothing); // page 1 is not loaded any more
      expect(loadMore(), findsOneWidget);
    });

    testWidgets('a page asked for before a reload is not added after it',
        (WidgetTester tester) async {
      final secondPage = Completer<http.Response>();
      await openAs(tester, boss, (page) => page == '0'
          ? Future.value(http.Response(leavePage(0, 2, [1], status: 'PENDING'), 200))
          : secondPage.future);

      await tester.tap(loadMore());
      await tester.pump();
      // While page 1 is on its way, approving reloads the list from page 0.
      await tester.tap(find.byIcon(Icons.check_circle));
      await tester.pumpAndSettle();
      // Page 1 belongs to the list from before the reload.
      secondPage.complete(http.Response(leavePage(1, 2, [2], status: 'PENDING'), 200));
      await tester.pumpAndSettle();

      expect(shown(1), findsOneWidget);
      expect(shown(2), findsNothing);
      // The reload ended the old load, so the button works again.
      expect(tester.widget<TextButton>(find.widgetWithText(TextButton, 'Φόρτωση παλαιότερων'))
          .onPressed, isNotNull);
    });
  });
}