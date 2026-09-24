// Account creation lives in the supervisor's employee list (F1 step 5).
// The screens get an ApiService with a fake server, so no backend is needed.

import 'package:employee_shift_management_ui/models/user_model.dart';
import 'package:employee_shift_management_ui/screens/employee_list_screen.dart';
import 'package:employee_shift_management_ui/services/api_service.dart';
import 'package:employee_shift_management_ui/services/auth_client.dart';
import 'package:employee_shift_management_ui/utils/session.dart';
import 'package:flutter/material.dart';
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
    client: MockClient((_) async => http.Response('{"content":[]}', 200)));

Widget appWith(ApiService api) =>
    withAppState(MaterialApp(home: EmployeeListScreen(apiService: api)));

void main() {
  tearDown(Session.clear);

  testWidgets('a supervisor sees the add-employee button',
      (WidgetTester tester) async {
    Session.logIn(supervisor(), 'test-token');

    await tester.pumpWidget(appWith(emptyListServer()));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.person_add), findsOneWidget);
  });

  testWidgets('an employee does not see the add-employee button',
      (WidgetTester tester) async {
    Session.logIn(employee(), 'test-token');

    await tester.pumpWidget(appWith(emptyListServer()));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.person_add), findsNothing);
  });

  testWidgets(
      'a supervisor creates an account with their token, and the list reloads',
      (WidgetTester tester) async {
    Session.logIn(supervisor(), 'test-token');

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
              ? '{"content":[]}'
              : '{"content":[{"id":8,"name":"New Hire","email":"new@example.com","role":"EMPLOYEE"}]}',
          200);
    });
    final api = ApiService(
        client: AuthClient(inner: server, token: () => 'supervisor-token'));

    await tester.pumpWidget(appWith(api));
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
}
