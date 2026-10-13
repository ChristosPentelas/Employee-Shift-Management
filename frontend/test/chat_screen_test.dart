// How the chat marks messages read (F28, B27): one request for the whole
// chat, only when something new arrived, and never at the cost of showing
// the messages.

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
  StoredMessage(this.id, this.from, this.to, {this.read = false});

  final int id;
  final User from;
  final User to;
  bool read;

  Map<String, Object> toJson() => {
        'id': id,
        'content': 'm$id',
        'timestamp': '2026-10-13T09:${id.toString().padLeft(2, '0')}:00',
        'read': read,
        'sender': {'id': from.id, 'name': from.name},
        'receiver': {'id': to.id, 'name': to.name},
      };
}

/// The chat between the worker and the boss, as the server would answer it.
/// It remembers what was marked read, so the next poll sees the change - as
/// the real server would - and logs every request as "METHOD /path".
class FakeChatServer {
  FakeChatServer(this.messages);

  final List<StoredMessage> messages;
  final requests = <String>[];

  /// What the mark-read request answers; set it to fail that request.
  int markReadStatus = 204;

  Iterable<String> get readRequests => requests.where((r) => r.startsWith('PUT'));
  Iterable<String> get loads => requests.where((r) => r.startsWith('GET'));

  late final client = MockClient((request) async {
    requests.add('${request.method} ${request.url.path}');

    if (request.method == 'GET' && request.url.path == '/api/v1/messages/chat') {
      // Newest first, one page, like the server (F9).
      final page = messages.reversed.map((m) => m.toJson()).toList();
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

void main() {
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
    await tester.pump(const Duration(seconds: 20));
    await tester.pumpAndSettle();
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
    await tester.pump(const Duration(seconds: 20));
    await tester.pumpAndSettle();

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
}
