// Checks that ApiService really sends its requests through the client it is
// given. If a method went back to calling http.get directly, the token would
// silently be missing from that one request.

import 'package:employee_shift_management_ui/models/leave_request_model.dart';
import 'package:employee_shift_management_ui/models/user_model.dart';
import 'package:employee_shift_management_ui/services/api_service.dart';
import 'package:employee_shift_management_ui/utils/session.dart';
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

  test('a leave request no longer names the employee it is for', () async {
    Session.currentUser =
        User(id: 7, name: 'Worker', email: 'worker@example.com', role: 'EMPLOYEE');
    http.Request? sent;
    final api = ApiService(client: MockClient((request) async {
      sent = request;
      return http.Response('', 201);
    }));

    await api.submitLeaveRequest(LeaveRequest(
      id: 0,
      employee: Session.currentUser!,
      startDate: DateTime(2026, 10, 1),
      endDate: DateTime(2026, 10, 5),
      status: 'PENDING',
      reason: 'Surgery',
    ));

    // The server files it for whoever the token says we are (F1 step 7b).
    expect(sent!.body, isNot(contains('userId')));
  });

  test('a message no longer names its sender', () async {
    Session.currentUser =
        User(id: 7, name: 'Worker', email: 'worker@example.com', role: 'EMPLOYEE');
    http.BaseRequest? sent;
    final api = ApiService(client: MockClient((request) async {
      sent = request;
      return http.Response('{}', 201);
    }));

    await api.sendMessage(9, 'Hello');

    expect(sent!.url.query, 'receiverId=9');
  });
}
