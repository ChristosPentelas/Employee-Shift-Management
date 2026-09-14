// Unit tests for AuthClient. No network: MockClient (shipped inside the http
// package) stands in for the server and records the request it received.

import 'package:employee_shift_management_ui/services/auth_client.dart';
import 'package:employee_shift_management_ui/utils/session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  late http.BaseRequest sent;

  MockClient recordingServer() => MockClient((request) async {
        sent = request;
        return http.Response('', 200);
      });

  final uri = Uri.parse('http://example.test/api/v1/shifts');

  tearDown(Session.clear);

  test('adds a Bearer header when there is a token', () async {
    final client = AuthClient(inner: recordingServer(), token: () => 'abc');

    await client.get(uri);

    expect(sent.headers['Authorization'], 'Bearer abc');
  });

  test('sends no Authorization header when nobody is logged in', () async {
    final client = AuthClient(inner: recordingServer(), token: () => null);

    await client.get(uri);

    expect(sent.headers.containsKey('Authorization'), isFalse);
  });

  test('keeps the headers the caller set', () async {
    final client = AuthClient(inner: recordingServer(), token: () => 'abc');

    await client.post(uri,
        headers: {'Content-Type': 'application/json'}, body: '{}');

    expect(sent.headers['Content-Type'], startsWith('application/json'));
    expect(sent.headers['Authorization'], 'Bearer abc');
  });

  test('by default sends the token stored in Session', () async {
    Session.token = 'from-session';
    final client = AuthClient(inner: recordingServer());

    await client.get(uri);

    expect(sent.headers['Authorization'], 'Bearer from-session');
  });
}
