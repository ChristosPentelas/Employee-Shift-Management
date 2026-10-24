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

/// Answers the worker's conversations, page N with [pages][N] - already one
/// row per person, newest first, as the server sends them since B26 step
/// 26c1 - and an empty chat for the chat screen a tap opens. Records the
/// conversation pages asked for in [asked].
http.Client fakeServer(List<List<Map<String, Object?>>> pages, {List<String>? asked}) {
  http.Response page(List<Map<String, Object?>> rows, int number, int total) =>
      http.Response.bytes(
          utf8.encode(jsonEncode({
            'content': rows,
            'page': number,
            'size': 20,
            'totalElements': rows.length,
            'totalPages': total,
          })),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'});

  return MockClient((request) async {
    switch (request.url.path) {
      case '/api/v1/messages/conversations':
        final number = int.parse(request.url.queryParameters['page']!);
        asked?.add('$number');
        // No conversations at all is no pages, as the server says it.
        final total = pages.length == 1 && pages[0].isEmpty ? 0 : pages.length;
        return page(pages[number], number, total);
      case '/api/v1/messages/chat':
        return page([], 0, 0);
      default:
        return http.Response('unexpected request', 404);
    }
  });
}

/// Opens the list as the worker, against [fakeServer] with one page.
Future<void> openList(WidgetTester tester, List<Map<String, Object?>> messages) =>
    openPages(tester, [messages]);

Future<void> openPages(WidgetTester tester, List<List<Map<String, Object?>>> pages,
    {List<String>? asked}) async {
  final container = testContainer(
      user: worker,
      overrides: [networkClientProvider.overrideWithValue(fakeServer(pages, asked: asked))]);
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

    // Picking each conversation's newest message, and one row for a note to
    // yourself, are the server's job since B26 step 26c1 and are tested there
    // (ConversationsIntegrationTest). Here: the rows stay as the server sent
    // them, each with its newest message.
    testWidgets('rows keep the order the server sends: newest conversation first',
        (WidgetTester tester) async {
      await openList(tester, [
        message(4, colleague, worker, 4, content: 'other chat'),
        message(3, boss, worker, 3, content: 'third'),
      ]);

      expect(find.byType(ListTile), findsNWidgets(2));
      expect(find.text('third'), findsOneWidget);
      final titles = tester
          .widgetList<ListTile>(find.byType(ListTile))
          .map((tile) => (tile.title as Text).data);
      expect(titles, ['Colleague', 'Boss']);
    });

    testWidgets('a note to myself is listed under my own name',
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

  // B26 step 26c2: the list used to stop at page 0 of the inbox and of sent,
  // so a conversation older than both was missing. It now scrolls on.
  group('older conversations', () {
    /// Someone the worker wrote to; ids from 100, so no clash with the others.
    User person(int id) =>
        User(id: id, name: 'Person $id', email: 'p$id@example.com', role: 'EMPLOYEE');

    testWidgets('scrolling to the end loads the next page',
        (WidgetTester tester) async {
      final asked = <String>[];
      // 20 rows: more than the test screen holds, so the end is out of sight.
      await openPages(tester, [
        [for (var i = 0; i < 20; i++) message(100 + i, worker, person(100 + i), 59 - i)],
        [message(200, person(200), worker, 1, content: 'an old chat')],
      ], asked: asked);
      expect(asked, ['0']);
      expect(find.text('an old chat'), findsNothing);

      await tester.drag(find.byType(ListView), const Offset(0, -5000));
      await tester.pumpAndSettle();

      expect(asked, ['0', '1']);
      expect(find.text('an old chat'), findsOneWidget);
    });

    testWidgets('someone who moves onto the next page is listed once',
        (WidgetTester tester) async {
      // A new message from someone else between the two pages pushed the boss
      // down from the end of page 0 onto page 1.
      await openPages(tester, [
        [message(3, colleague, worker, 3), message(2, boss, worker, 2)],
        [message(2, boss, worker, 2), message(1, person(100), worker, 1)],
      ]);

      expect(find.widgetWithText(ListTile, 'Boss'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Person 100'), findsOneWidget);
    });

    testWidgets('a failed load says so, not "no messages"',
        (WidgetTester tester) async {
      // getInbox used to turn any failure into an empty list (B44).
      final container = testContainer(
          user: worker,
          overrides: [
            networkClientProvider
                .overrideWithValue(MockClient((_) async => http.Response('', 500)))
          ]);
      await tester.pumpWidget(
          withAppState(container, const MaterialApp(home: MessagesListScreen())));
      await tester.pumpAndSettle();

      expect(find.text('Δεν ήταν δυνατή η φόρτωση των μηνυμάτων.'), findsOneWidget);
    });

    testWidgets('with no conversations it says so', (WidgetTester tester) async {
      await openList(tester, []);

      expect(find.text('Δεν υπάρχουν μηνύματα.'), findsOneWidget);
    });
  });

  testWidgets('a session that ends during loading still finishes with the same user',
      (WidgetTester tester) async {
    final container = testContainer(
        user: User(id: 7, name: 'Worker', email: 'worker@example.com', role: 'EMPLOYEE'));
    final paths = <String>[];
    final api = ApiService(client: MockClient((request) async {
      paths.add(request.url.path);
      // The session ends while the reply is on its way.
      container.read(authProvider.notifier).logOut();
      return http.Response.bytes(
          utf8.encode(jsonEncode({
            'content': [message(1, boss, worker, 1)],
            'page': 0,
            'size': 20,
            'totalElements': 1,
            'totalPages': 1,
          })),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    }));

    await tester.pumpWidget(
        withAppState(container, MaterialApp(home: MessagesListScreen(apiService: api))));
    await tester.pumpAndSettle();

    // Before B16's fix the screen re-read the cleared session after the await
    // and threw. One request since B26 step 26c2 (it was inbox, then sent):
    // turning the reply into rows is what needs the user read beforehand.
    expect(paths, ['/api/v1/messages/conversations']);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.widgetWithText(ListTile, 'Boss'), findsOneWidget);
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

    reply.complete(http.Response(
        '{"content":[],"page":0,"size":20,"totalElements":0,"totalPages":0}', 200));
    // Without a mounted check the screen now calls setState after dispose,
    // and Flutter fails the test with that error.
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
  });
}
