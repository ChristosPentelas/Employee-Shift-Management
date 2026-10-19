// The session can end while a request is on its way: the chat polls every
// 5 seconds, and any 401 clears the session (F1 step 3b). Screens must not
// re-read the session after an await and assume it is still there (B16).

import 'dart:async';
import 'dart:convert';

import 'package:employee_shift_management_ui/models/user_model.dart';
import 'package:employee_shift_management_ui/screens/chat_screen.dart';
import 'package:employee_shift_management_ui/screens/messages_list_screen.dart';
import 'package:employee_shift_management_ui/services/api_providers.dart';
import 'package:employee_shift_management_ui/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:employee_shift_management_ui/state/auth_session.dart';
import 'helpers/app_scope.dart';

final worker = User(id: 7, name: 'Worker', email: 'worker@example.com', role: 'EMPLOYEE');
final boss = User(id: 9, name: 'Boss', email: 'boss@example.com', role: 'SUPERVISOR');
final colleague = User(id: 8, name: 'Colleague', email: 'colleague@example.com', role: 'EMPLOYEE');

/// One message as the server sends it: both people in full (UserResponse).
/// [minute] orders them; a higher minute is newer.
Map<String, Object?> message(int id, User from, User to, int minute,
        {String? content, bool read = false}) =>
    {
      'id': id,
      'content': content ?? 'm$id',
      'timestamp': '2026-10-19T09:${minute.toString().padLeft(2, '0')}:00',
      'read': read,
      'sender': from.toJson(),
      'receiver': to.toJson(),
    };

/// Answers the worker's inbox and sent lists from [messages], newest first
/// like the server, and an empty chat for the chat screen a tap opens.
http.Client fakeServer(List<Map<String, Object?>> messages) {
  List<Map<String, Object?>> where(bool Function(Map<String, Object?>) test) =>
      messages.where(test).toList()
        ..sort((a, b) => (b['timestamp'] as String).compareTo(a['timestamp'] as String));
  int idOf(Object? user) => (user as Map<String, dynamic>)['id'] as int;

  return MockClient((request) async {
    final page = switch (request.url.path) {
      '/api/v1/messages/inbox/7' => where((m) => idOf(m['receiver']) == 7),
      '/api/v1/messages/sent/7' => where((m) => idOf(m['sender']) == 7),
      '/api/v1/messages/chat' => <Map<String, Object?>>[],
      _ => null,
    };
    if (page == null) return http.Response('unexpected request', 404);
    return http.Response.bytes(
        utf8.encode(jsonEncode({
          'content': page,
          'page': 0,
          'size': 50,
          'totalElements': page.length,
          'totalPages': 1,
        })),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'});
  });
}

/// Opens the list as the worker, against [fakeServer].
Future<void> openList(WidgetTester tester, List<Map<String, Object?>> messages) async {
  final container = testContainer(
      user: worker,
      overrides: [networkClientProvider.overrideWithValue(fakeServer(messages))]);
  await tester.pumpWidget(
      withAppState(container, const MaterialApp(home: MessagesListScreen())));
  await tester.pumpAndSettle();
}

ListTile rowFor(WidgetTester tester, String name) =>
    tester.widget<ListTile>(find.widgetWithText(ListTile, name));

void main() {
  group('one row per conversation, named after the other person (B18)', () {
    testWidgets('a message I sent is listed under the person I sent it to',
        (WidgetTester tester) async {
      await openList(tester, [message(1, worker, boss, 1, content: 'Hello')]);

      expect(find.widgetWithText(ListTile, 'Boss'), findsOneWidget);
      // Before B18's fix the row showed the sender - me.
      expect(find.widgetWithText(ListTile, 'Worker'), findsNothing);
    });

    testWidgets('a conversation is one row, showing its newest message',
        (WidgetTester tester) async {
      await openList(tester, [
        message(1, boss, worker, 1, content: 'first'),
        message(2, worker, boss, 2, content: 'second'),
        message(3, boss, worker, 3, content: 'third'),
        message(4, colleague, worker, 4, content: 'other chat'),
      ]);

      expect(find.byType(ListTile), findsNWidgets(2));
      expect(find.text('third'), findsOneWidget);
      expect(find.text('first'), findsNothing);
      expect(find.text('second'), findsNothing);
      // Newest conversation on top.
      final titles = tester
          .widgetList<ListTile>(find.byType(ListTile))
          .map((tile) => (tile.title as Text).data);
      expect(titles, ['Colleague', 'Boss']);
    });

    testWidgets('a message to myself is one row, not one from inbox and one from sent',
        (WidgetTester tester) async {
      await openList(tester, [message(1, worker, worker, 1, content: 'note to self')]);

      expect(find.widgetWithText(ListTile, 'Worker'), findsOneWidget);
    });

    testWidgets('tapping a row opens the chat with that person, role included',
        (WidgetTester tester) async {
      await openList(tester, [message(1, worker, boss, 1)]);

      await tester.tap(find.widgetWithText(ListTile, 'Boss'));
      await tester.pumpAndSettle();

      final partner = tester.widget<ChatScreen>(find.byType(ChatScreen)).receiver;
      expect(partner.id, 9);
      expect(partner.name, 'Boss');
      // Was hard-coded to EMPLOYEE.
      expect(partner.role, 'SUPERVISOR');

      // The chat polls on a timer; removing it cancels the timer, and a timer
      // still running when a test ends fails the test.
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('the unread dot is for messages to me, not ones I sent',
        (WidgetTester tester) async {
      await openList(tester, [
        message(1, boss, worker, 1),
        message(2, worker, colleague, 2), // unread by the colleague, not by me
      ]);

      expect(rowFor(tester, 'Boss').trailing, isNotNull);
      expect(rowFor(tester, 'Colleague').trailing, isNull);
    });
  });

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
