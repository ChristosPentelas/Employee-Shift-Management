// The session can end while a request is on its way: the chat polls every
// 3 seconds, and any 401 clears the session (F1 step 3b). Screens must not
// re-read the session after an await and assume it is still there (B16).

import 'dart:async';

import 'package:employee_shift_management_ui/models/user_model.dart';
import 'package:employee_shift_management_ui/screens/messages_list_screen.dart';
import 'package:employee_shift_management_ui/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:employee_shift_management_ui/state/auth_session.dart';
import 'helpers/app_scope.dart';

void main() {
  testWidgets('a session that ends during loading still finishes with the same user',
      (WidgetTester tester) async {
    final container = testContainer(
        user: User(id: 7, name: 'Worker', email: 'worker@example.com', role: 'EMPLOYEE'));
    final paths = <String>[];
    final api = ApiService(client: MockClient((request) async {
      paths.add(request.url.path);
      // The session ends while the first reply is on its way.
      container.read(authProvider.notifier).logOut();
      return http.Response('{"content": []}', 200);
    }));

    await tester.pumpWidget(
        withAppState(container, MaterialApp(home: MessagesListScreen(apiService: api))));
    await tester.pumpAndSettle();

    // Before B16's fix the second request re-read the cleared session, threw,
    // and was never sent.
    expect(paths, ['/api/v1/messages/inbox/7', '/api/v1/messages/sent/7']);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('a reply that arrives after the screen closed is ignored (F25)',
      (WidgetTester tester) async {
    final container = testContainer(
        user: User(id: 7, name: 'Worker', email: 'worker@example.com', role: 'EMPLOYEE'));
    // Every reply waits until the test completes this.
    final reply = Completer<http.Response>();
    final api = ApiService(client: MockClient((_) => reply.future));
    final navigator = GlobalKey<NavigatorState>();

    await tester.pumpWidget(withAppState(container,
        MaterialApp(navigatorKey: navigator, home: const Text('Home'))));
    navigator.currentState!.push(
        MaterialPageRoute(builder: (_) => MessagesListScreen(apiService: api)));
    // pump, not pumpAndSettle: the spinner animates forever, so it never
    // settles. A pushed page spends its first frame offstage (being measured
    // for the transition), and finders skip offstage widgets, so move time
    // past the transition before looking.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    navigator.currentState!.pop();
    await tester.pumpAndSettle(); // the screen is gone now

    reply.complete(http.Response('{"content": []}', 200));
    // Without a mounted check the screen now calls setState after dispose,
    // and Flutter fails the test with that error.
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
  });
}
