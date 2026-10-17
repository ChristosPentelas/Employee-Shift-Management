// F7 / F1 step 7c: an employee must not receive other people's leave requests
// at all. Before this, the screen downloaded every request and hid the rest.

import 'package:employee_shift_management_ui/models/user_model.dart';
import 'package:employee_shift_management_ui/screens/leave_requests_screen.dart';
import 'package:employee_shift_management_ui/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'helpers/app_scope.dart';

void main() {
  /// Opens the screen and reports which paths it asked the server for.
  Future<List<String>> requestedPaths(
      WidgetTester tester, ProviderContainer container) async {
    final paths = <String>[];
    final api = ApiService(client: MockClient((request) async {
      paths.add(request.url.path);
      return http.Response('{"content":[]}', 200);
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
        return http.Response('{"content":[]}', 200);
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
}
