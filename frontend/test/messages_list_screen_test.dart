// The session can end while a request is on its way: the chat polls every
// 3 seconds, and any 401 clears the session (F1 step 3b). Screens must not
// re-read the session after an await and assume it is still there (B16).

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
}
