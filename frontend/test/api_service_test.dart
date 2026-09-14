// Checks that ApiService really sends its requests through the client it is
// given. If a method went back to calling http.get directly, the token would
// silently be missing from that one request.

import 'package:employee_shift_management_ui/services/api_service.dart';
import 'package:employee_shift_management_ui/services/auth_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('requests go through the auth client and carry the token', () async {
    http.BaseRequest? sent;
    final fakeServer = MockClient((request) async {
      sent = request;
      return http.Response('[]', 200);
    });
    final api = ApiService(
        client: AuthClient(inner: fakeServer, token: () => 'abc'));

    final shifts = await api.getAllShifts();

    expect(shifts, isEmpty);
    expect(sent!.url.path, '/api/v1/shifts');
    expect(sent!.headers['Authorization'], 'Bearer abc');
  });
}
