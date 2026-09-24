// Checks that ApiService really sends its requests through the client it is
// given. If a method went back to calling http.get directly, the token would
// silently be missing from that one request.

import 'package:employee_shift_management_ui/models/leave_request_model.dart';
import 'package:employee_shift_management_ui/models/shift_model.dart';
import 'package:employee_shift_management_ui/models/user_model.dart';
import 'package:employee_shift_management_ui/services/api_service.dart';
import 'package:employee_shift_management_ui/services/auth_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Shift aShift() => Shift(
      id: 0,
      date: DateTime(2026, 9, 29),
      startTime: '08:00',
      endTime: '16:00',
      position: 'Ταμείο',
    );

void main() {
  test('requests go through the auth client and carry the token', () async {
    http.BaseRequest? sent;
    final fakeServer = MockClient((request) async {
      sent = request;
      return http.Response('[]', 200);
    });
    final api = ApiService(
        client: AuthClient(
            inner: fakeServer, token: () => 'abc', onTokenRejected: (_) {}));

    final shifts =
        await api.getAllShifts(DateTime(2026, 9, 1), DateTime(2026, 9, 30));

    expect(shifts, isEmpty);
    expect(sent!.url.path, '/api/v1/shifts');
    expect(sent!.headers['Authorization'], 'Bearer abc');
  });

  test('a leave request no longer names the employee it is for', () async {
    http.Request? sent;
    final api = ApiService(client: MockClient((request) async {
      sent = request;
      return http.Response('', 201);
    }));

    await api.submitLeaveRequest(LeaveRequest(
      id: 0,
      employee: User(id: 7, name: 'Worker', email: 'worker@example.com', role: 'EMPLOYEE'),
      startDate: DateTime(2026, 10, 1),
      endDate: DateTime(2026, 10, 5),
      status: 'PENDING',
      reason: 'Surgery',
    ));

    // The server files it for whoever the token says we are (F1 step 7b).
    expect(sent!.body, isNot(contains('userId')));
  });

  test('a message no longer names its sender', () async {
    http.BaseRequest? sent;
    final api = ApiService(client: MockClient((request) async {
      sent = request;
      return http.Response('{}', 201);
    }));

    await api.sendMessage(9, 'Hello');

    expect(sent!.url.query, 'receiverId=9');
  });

  test('news is read from one page, and the first page is asked for', () async {
    http.BaseRequest? sent;
    final api = ApiService(client: MockClient((request) async {
      sent = request;
      // The server's page shape (F9): the items sit under "content".
      return http.Response(
          '{"content":[{"id":1,"title":"Staff meeting","description":"Monday",'
          '"type":"ANNOUNCEMENT","createdAt":"2026-09-19T09:00:00",'
          '"author":{"id":9,"name":"Boss","email":"boss@example.com","role":"SUPERVISOR"}}],'
          '"page":0,"size":20,"totalElements":1,"totalPages":1}',
          200);
    }));

    final news = await api.getNews();

    expect(news.single.title, 'Staff meeting');
    expect(sent!.url.queryParameters, {'page': '0', 'size': '20'});
  });

  test("the supervisor's calendar asks for the month it shows", () async {
    http.BaseRequest? sent;
    final api = ApiService(client: MockClient((request) async {
      sent = request;
      return http.Response('[]', 200);
    }));

    await api.getAllShifts(DateTime(2026, 2, 1), DateTime(2026, 2, 28));

    // Zero-padded YYYY-MM-DD: the server rejects anything else (F9).
    expect(sent!.url.queryParameters, {'start': '2026-02-01', 'end': '2026-02-28'});
  });

  test('a chat page arrives newest first and is shown oldest first', () async {
    http.BaseRequest? sent;
    String message(int id, String time) =>
        '{"id":$id,"content":"m$id","timestamp":"2026-09-19T$time",'
        '"read":true,"sender":{"id":9,"name":"Boss"},"receiver":{"id":7,"name":"Worker"}}';
    final api = ApiService(client: MockClient((request) async {
      sent = request;
      return http.Response(
          '{"content":[${message(2, "10:00:00")},${message(1, "09:00:00")}],'
          '"page":0,"size":50,"totalElements":2,"totalPages":1}',
          200);
    }));

    final chat = await api.getChatHistory(7, 9);

    expect(chat.map((m) => m.id), [1, 2]);
    expect(sent!.url.queryParameters['page'], '0');
    expect(sent!.url.queryParameters['size'], '50');
    expect(sent!.url.queryParameters['user1Id'], '7',
        reason: 'the caller says who is asking; the service no longer looks it up');
  });

  test('own leave requests and own schedule are asked for the id passed in',
      () async {
    final paths = <String>[];
    final api = ApiService(client: MockClient((request) async {
      paths.add(request.url.path);
      return http.Response(
          request.url.path.contains('leaves') ? '{"content":[]}' : '[]', 200);
    }));

    await api.getMyLeaveRequests(7);
    await api.getFilteredShifts(7, DateTime(2026, 2, 1), DateTime(2026, 2, 28));

    expect(paths, ['/api/v1/leaves/users/7/leaves', '/api/v1/users/7/schedule']);
  });

  test('the staff list asks for the largest page the server allows', () async {
    http.BaseRequest? sent;
    final api = ApiService(client: MockClient((request) async {
      sent = request;
      return http.Response(
          '{"content":[{"id":7,"name":"Worker","email":"worker@example.com","role":"EMPLOYEE"}],'
          '"page":0,"size":100,"totalElements":1,"totalPages":1}',
          200);
    }));

    final staff = await api.getAllEmployees();

    expect(staff.single.name, 'Worker');
    expect(sent!.url.queryParameters, {'page': '0', 'size': '100'});
  });

  test('assigning a shift reports why the server refused it', () async {
    Future<AssignShiftResult> assignAnswered(int status) {
      final api = ApiService(
          client: MockClient((_) async => http.Response('{}', status)));
      return api.assignShift(aShift(), 7);
    }

    expect(await assignAnswered(201), AssignShiftResult.created);
    // 409: the employee already has a shift then (F30).
    expect(await assignAnswered(409), AssignShiftResult.overlaps);
    expect(await assignAnswered(400), AssignShiftResult.invalid);
    expect(await assignAnswered(500), AssignShiftResult.failed);
  });

  test('assigning a shift without a network is a failure, not a crash', () async {
    final api = ApiService(client: MockClient((_) async {
      throw http.ClientException('no network');
    }));

    final result = await api.assignShift(aShift(), 7);

    expect(result, AssignShiftResult.failed);
  });
}
