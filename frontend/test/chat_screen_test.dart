// The chat screen's network traffic (F28).
//
// Marking read (B27): one request for the whole chat, only when something
// new arrived, and never at the cost of showing the messages.
//
// Polling: every 5 seconds, never two loads at once, not at all while the app
// is in the background, and never after the screen is gone.

import 'dart:async';
import 'dart:convert';

import 'package:employee_shift_management_ui/models/user_model.dart';
import 'package:employee_shift_management_ui/screens/chat_screen.dart';
import 'package:employee_shift_management_ui/services/api_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'helpers/app_scope.dart';

final worker = User(id: 7, name: 'Worker', email: 'worker@example.com', role: 'EMPLOYEE');
final boss = User(id: 9, name: 'Boss', email: 'boss@example.com', role: 'SUPERVISOR');

/// One message as the fake server stores it.
class StoredMessage {
  StoredMessage(this.id, this.from, this.to, {this.read = false, String? content})
      : content = content ?? 'm$id';

  final int id;
  final User from;
  final User to;
  final String content;
  bool read;

  Map<String, Object> toJson() => {
        'id': id,
        'content': content,
        // A minute apart, in id order; a whole timestamp, since a long chat
        // has more than 60 messages.
        'timestamp': DateTime(2026, 10, 13, 9).add(Duration(minutes: id)).toIso8601String(),
        'read': read,
        // Both people in full, as the server's UserResponse sends them.
        'sender': from.toJson(),
        'receiver': to.toJson(),
      };
}

/// The chat between the worker and the boss, as the server would answer it.
/// It remembers what was marked read and what was sent, so the next poll sees
/// the change - as the real server would - and logs every request as
/// "METHOD /path".
class FakeChatServer {
  FakeChatServer(this.messages);

  final List<StoredMessage> messages;
  final requests = <String>[];

  /// What the mark-read request answers; set it to fail that request.
  int markReadStatus = 204;

  /// When true, loading the chat fails as if there were no network.
  bool failLoads = false;

  Completer<void>? _heldLoads;

  /// From now on, every chat load waits until [releaseLoads] - a slow network.
  void holdLoads() => _heldLoads = Completer<void>();

  /// Lets every waiting load answer, and stops holding new ones.
  void releaseLoads() {
    _heldLoads?.complete();
    _heldLoads = null;
  }

  Iterable<String> get readRequests => requests.where((r) => r.startsWith('PUT'));
  Iterable<String> get loads => requests.where((r) => r.startsWith('GET'));

  late final client = MockClient((request) async {
    requests.add('${request.method} ${request.url.path}');

    if (request.method == 'GET' && request.url.path == '/api/v1/messages/chat') {
      if (failLoads) throw http.ClientException('no network');
      // The answer is what the chat held when the request arrived, even if
      // it reaches the app later: a message sent meanwhile is not in it.
      // Newest first, 50 a page, like the server (F9); ?page= picks which.
      final number = int.parse(request.url.queryParameters['page'] ?? '0');
      final newestFirst = messages.reversed.map((m) => m.toJson()).toList();
      final page = newestFirst.skip(number * 50).take(50).toList();
      final hold = _heldLoads;
      if (hold != null) await hold.future;
      return http.Response.bytes(
          utf8.encode(jsonEncode({
            'content': page,
            'page': number,
            'size': 50,
            'totalElements': newestFirst.length,
            'totalPages': (newestFirst.length + 49) ~/ 50,
          })),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    }
    if (request.method == 'POST' && request.url.path == '/api/v1/messages') {
      final content = jsonDecode(request.body)['content'] as String;
      messages.add(StoredMessage(messages.length + 1, worker, boss, content: content));
      return http.Response('', 201);
    }
    if (request.method == 'PUT' && request.url.path == '/api/v1/messages/chat/9/read') {
      if (markReadStatus == 204) {
        for (final m in messages.where((m) => m.from == boss && m.to == worker)) {
          m.read = true;
        }
      }
      return http.Response('', markReadStatus);
    }
    return http.Response('unexpected request', 404);
  });
}

Future<void> openChat(WidgetTester tester, FakeChatServer server) async {
  // The binding is shared by every test in this file, so a test that sent
  // the app to the background must not leave the next one starting there.
  if (tester.binding.lifecycleState != AppLifecycleState.resumed) {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  }
  final container = testContainer(
      user: worker,
      overrides: [networkClientProvider.overrideWithValue(server.client)]);
  await tester.pumpWidget(
      withAppState(container, MaterialApp(home: ChatScreen(receiver: boss))));
  await tester.pumpAndSettle();
}

/// Removes the screen, which cancels its poll timer. A timer still running
/// when a test ends fails that test.
Future<void> closeChat(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
}

/// Moves fake time forward and lets every reply that is due arrive.
Future<void> wait(WidgetTester tester, Duration duration) async {
  await tester.pump(duration);
  await tester.pumpAndSettle();
}

/// The home button, one state at a time as a phone reports it:
/// AppLifecycleListener refuses jumps such as resumed straight to paused.
void sendToBackground(WidgetTester tester) {
  for (final state in [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
}

/// Coming back to the app, the same way in reverse.
void bringToForeground(WidgetTester tester) {
  for (final state in [
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
}

void main() {
  group('marking read', () {
    testWidgets('unread messages are marked read with one request, once',
        (WidgetTester tester) async {
      final server = FakeChatServer([
        StoredMessage(1, boss, worker),
        StoredMessage(2, boss, worker),
        StoredMessage(3, worker, boss),
        StoredMessage(4, boss, worker),
      ]);

      await openChat(tester, server);

      // Not one PUT per message, as before B27's fix.
      expect(server.readRequests, ['PUT /api/v1/messages/chat/9/read']);

      // Let the poll run a few times: nothing new arrived, so nothing more is
      // marked. Before the fix this was the same PUTs again on every poll.
      await wait(tester, const Duration(seconds: 20));
      expect(server.loads.length, greaterThan(1), reason: 'the chat kept polling');
      expect(server.readRequests, hasLength(1));

      await closeChat(tester);
    });

    testWidgets('a chat with nothing new to read sends no read request',
        (WidgetTester tester) async {
      final server = FakeChatServer([
        StoredMessage(1, boss, worker, read: true),
        // Unread, but by the boss: only the receiver can mark it.
        StoredMessage(2, worker, boss),
      ]);

      await openChat(tester, server);
      await wait(tester, const Duration(seconds: 20));

      expect(server.loads, isNotEmpty);
      expect(server.readRequests, isEmpty);

      await closeChat(tester);
    });

    testWidgets('the messages are shown even when marking them read fails',
        (WidgetTester tester) async {
      final server = FakeChatServer([
        StoredMessage(1, boss, worker),
        StoredMessage(2, worker, boss),
      ])
        ..markReadStatus = 500;

      await openChat(tester, server);

      // A read receipt is the server's business; the user still sees the chat.
      expect(server.readRequests, isNotEmpty);
      expect(find.text('m1'), findsOneWidget);
      expect(find.text('m2'), findsOneWidget);

      await closeChat(tester);
    });
  });

  group('polling', () {
    testWidgets('the chat reloads every 5 seconds', (WidgetTester tester) async {
      final server = FakeChatServer([StoredMessage(1, boss, worker, read: true)]);

      await openChat(tester, server);
      expect(server.loads, hasLength(1), reason: 'the first load, on opening');

      await wait(tester, const Duration(seconds: 4));
      expect(server.loads, hasLength(1), reason: 'not yet: under 5 seconds');

      await wait(tester, const Duration(seconds: 1));
      expect(server.loads, hasLength(2));

      await wait(tester, const Duration(seconds: 5));
      expect(server.loads, hasLength(3));

      await closeChat(tester);
    });

    testWidgets('a load still on its way is not started again',
        (WidgetTester tester) async {
      final server = FakeChatServer([StoredMessage(1, boss, worker, read: true)])
        ..holdLoads();

      await openChat(tester, server);
      // Several ticks pass while the first reply is still on its way.
      await wait(tester, const Duration(seconds: 20));
      expect(server.loads, hasLength(1),
          reason: 'a second load would only race the first one');

      server.releaseLoads();
      await tester.pumpAndSettle();
      expect(find.text('m1'), findsOneWidget);

      // And the slow load did not stop the polling.
      final afterRelease = server.loads.length;
      await wait(tester, const Duration(seconds: 5));
      expect(server.loads.length, greaterThan(afterRelease));

      await closeChat(tester);
    });

    testWidgets('a failed load does not stop the polling',
        (WidgetTester tester) async {
      final server = FakeChatServer([StoredMessage(1, boss, worker, read: true)])
        ..failLoads = true;

      await openChat(tester, server);
      expect(server.loads, hasLength(1));

      // If the "loading" flag is only cleared when a load succeeds, the first
      // failure leaves it set, and every later tick is skipped for good.
      await wait(tester, const Duration(seconds: 5));
      expect(server.loads, hasLength(2));

      await closeChat(tester);
    });

    testWidgets('a message sent during a slow load still shows without waiting '
        'for the next tick', (WidgetTester tester) async {
      final server = FakeChatServer([StoredMessage(1, boss, worker, read: true)])
        ..holdLoads();

      await openChat(tester, server);
      await tester.enterText(find.byType(TextField), 'Hello');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();

      expect(server.requests, contains('POST /api/v1/messages'));
      expect(server.loads, hasLength(1),
          reason: 'the reload after sending waits for the load on its way');

      // The first reply was taken before "Hello" was sent, so only a second
      // load can show it - and it must come now, not on the next tick.
      server.releaseLoads();
      await tester.pumpAndSettle();
      expect(server.loads, hasLength(2));
      expect(find.text('Hello'), findsOneWidget);

      await closeChat(tester);
    });

    testWidgets('no polling in the background, and a fresh load on return',
        (WidgetTester tester) async {
      final server = FakeChatServer([StoredMessage(1, boss, worker, read: true)]);

      await openChat(tester, server);
      expect(server.loads, hasLength(1));

      sendToBackground(tester);
      await wait(tester, const Duration(seconds: 30));
      expect(server.loads, hasLength(1), reason: 'nobody is looking at the chat');

      // Back in the app: load at once rather than up to 5 seconds later.
      bringToForeground(tester);
      await tester.pumpAndSettle();
      expect(server.loads, hasLength(2));

      await wait(tester, const Duration(seconds: 5));
      expect(server.loads, hasLength(3), reason: 'and the polling is back');

      await closeChat(tester);
    });

    testWidgets('a closed chat neither polls nor reacts to the app coming back',
        (WidgetTester tester) async {
      final server = FakeChatServer([StoredMessage(1, boss, worker, read: true)]);

      await openChat(tester, server);
      await closeChat(tester);
      final loadsWhenClosed = server.loads.length;

      await wait(tester, const Duration(seconds: 20));
      // A lifecycle listener that was never disposed would still fire here,
      // and load a chat whose screen is gone.
      sendToBackground(tester);
      bringToForeground(tester);
      await tester.pumpAndSettle();

      expect(server.loads, hasLength(loadsWhenClosed));
    });
  });

  // B26 step 26d: the chat used to show only its newest 50 messages, and
  // every poll replaced them. Scrolling up now loads older ones above, and a
  // poll only adds what is new at the bottom.
  group('older messages', () {
    /// A chat of [count] messages, the boss and the worker taking turns,
    /// every one already read.
    FakeChatServer longChat(int count) => FakeChatServer([
          for (var id = 1; id <= count; id++)
            StoredMessage(id, id.isOdd ? boss : worker, id.isOdd ? worker : boss,
                read: true),
        ]);

    /// The list is reversed: dragging down moves towards the top, where the
    /// oldest messages are. Twice: the first drag brings the footer into
    /// view, and the older page it loads lands above it - out of sight until
    /// the user scrolls on, as in any chat.
    Future<void> scrollToTheTop(WidgetTester tester) async {
      await tester.drag(find.byType(ListView), const Offset(0, 10000));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, 10000));
      await tester.pumpAndSettle();
    }

    Future<void> scrollToTheBottom(WidgetTester tester) async {
      await tester.drag(find.byType(ListView), const Offset(0, -10000));
      await tester.pumpAndSettle();
    }

    testWidgets('scrolling up loads the older messages above',
        (WidgetTester tester) async {
      // 60: page 0 is 60 down to 11, page 1 is 10 down to 1.
      final server = longChat(60);
      await openChat(tester, server);
      expect(find.text('m60'), findsOneWidget, reason: 'the newest, at the bottom');
      expect(server.loads, hasLength(1));

      await scrollToTheTop(tester);

      expect(server.loads, hasLength(2));
      expect(find.text('m1'), findsOneWidget);
      expect(tester.getTopLeft(find.text('m1')).dy,
          lessThan(tester.getTopLeft(find.text('m2')).dy),
          reason: 'older above newer');

      await closeChat(tester);
    });

    testWidgets('a poll keeps the older messages and adds the new one below',
        (WidgetTester tester) async {
      final server = longChat(60);
      await openChat(tester, server);
      await scrollToTheTop(tester);
      expect(find.text('m1'), findsOneWidget);

      server.messages.add(StoredMessage(61, boss, worker, read: true));
      await wait(tester, const Duration(seconds: 5));

      // Before 26d every poll replaced the list with page 0 again. The new
      // message at the bottom pushes the view up by one bubble, so m1 slides
      // just out of sight at the top - left as it is (decided 2026-10-24) -
      // and scrolling up shows it still there.
      final loadsBefore = server.loads.length;
      await scrollToTheTop(tester);
      expect(find.text('m1'), findsOneWidget);
      expect(server.loads, hasLength(loadsBefore), reason: 'kept, not loaded again');
      await scrollToTheBottom(tester);
      expect(find.text('m61'), findsOneWidget);

      await closeChat(tester);
    });

    testWidgets('an unread message on an older page is not marked read every poll',
        (WidgetTester tester) async {
      final server = longChat(60);
      // Message 1, on page 1, is still unread when its page is loaded.
      server.messages.first.read = false;
      await openChat(tester, server);
      await scrollToTheTop(tester);

      await wait(tester, const Duration(seconds: 20));

      // Only the page each poll fetched again counts: in the list, message 1
      // stays unread for good, and looking there would send a PUT every 5 s.
      expect(server.loads.length, greaterThan(3), reason: 'the chat kept polling');
      expect(server.readRequests, isEmpty);

      await closeChat(tester);
    });

    testWidgets('a failed first load says so, and the next poll shows the chat',
        (WidgetTester tester) async {
      final server = FakeChatServer([StoredMessage(1, boss, worker, read: true)])
        ..failLoads = true;
      await openChat(tester, server);

      // Before 26d this was an empty chat, as if nobody had written (B44).
      expect(find.text('Δεν ήταν δυνατή η φόρτωση των μηνυμάτων.'), findsOneWidget);

      server.failLoads = false;
      await wait(tester, const Duration(seconds: 5));

      expect(find.text('m1'), findsOneWidget);
      expect(find.text('Δεν ήταν δυνατή η φόρτωση των μηνυμάτων.'), findsNothing);

      await closeChat(tester);
    });

    testWidgets('a failed poll keeps the chat on screen',
        (WidgetTester tester) async {
      final server = FakeChatServer([StoredMessage(1, boss, worker, read: true)]);
      await openChat(tester, server);
      expect(find.text('m1'), findsOneWidget);

      server.failLoads = true;
      await wait(tester, const Duration(seconds: 5));

      expect(server.loads, hasLength(2));
      expect(find.text('m1'), findsOneWidget);
      expect(find.text('Δεν ήταν δυνατή η φόρτωση των μηνυμάτων.'), findsNothing);

      await closeChat(tester);
    });
  });
}
