// Unit tests for AuthClient. No network: MockClient (shipped inside the http
// package) stands in for the server and records the request it received.

import 'package:employee_shift_management_ui/models/user_model.dart';
import 'package:employee_shift_management_ui/services/auth_client.dart';
import 'package:employee_shift_management_ui/utils/session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  late http.BaseRequest sent;

  MockClient server({int status = 200}) => MockClient((request) async {
        sent = request;
        return http.Response('', status);
      });

  final uri = Uri.parse('http://example.test/api/v1/shifts');

  tearDown(Session.clear);

  test('adds a Bearer header when there is a token', () async {
    final client = AuthClient(inner: server(), token: () => 'abc');

    await client.get(uri);

    expect(sent.headers['Authorization'], 'Bearer abc');
  });

  test('sends no Authorization header when nobody is logged in', () async {
    final client = AuthClient(inner: server(), token: () => null);

    await client.get(uri);

    expect(sent.headers.containsKey('Authorization'), isFalse);
  });

  test('keeps the headers the caller set', () async {
    final client = AuthClient(inner: server(), token: () => 'abc');

    await client.post(uri,
        headers: {'Content-Type': 'application/json'}, body: '{}');

    expect(sent.headers['Content-Type'], startsWith('application/json'));
    expect(sent.headers['Authorization'], 'Bearer abc');
  });

  test('by default sends the token stored in Session', () async {
    Session.logIn(
        User(id: 7, name: 'Worker', email: 'worker@example.com', role: 'EMPLOYEE'),
        'from-session');
    final client = AuthClient(inner: server());

    await client.get(uri);

    expect(sent.headers['Authorization'], 'Bearer from-session');
  });

  test('a 401 on a request with a token reports that token as rejected',
      () async {
    String? rejected;
    final client = AuthClient(
        inner: server(status: 401),
        token: () => 'abc',
        onTokenRejected: (token) => rejected = token);

    final response = await client.get(uri);

    expect(rejected, 'abc');
    expect(response.statusCode, 401,
        reason: 'the caller must still see what the server said');
  });

  test('a 401 without a token (wrong password at login) is not a rejected token',
      () async {
    String? rejected;
    final client = AuthClient(
        inner: server(status: 401),
        token: () => null,
        onTokenRejected: (token) => rejected = token);

    await client.post(uri, body: '{}');

    expect(rejected, isNull);
  });

  test('a successful response reports nothing', () async {
    String? rejected;
    final client = AuthClient(
        inner: server(status: 200),
        token: () => 'abc',
        onTokenRejected: (token) => rejected = token);

    await client.get(uri);

    expect(rejected, isNull);
  });
}
