// Checks that ApiService really sends its requests through the client it is
// given. If a method went back to calling http.get directly, the token would
// silently be missing from that one request.

import 'dart:async';
import 'dart:convert';

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

LeaveRequest aLeave() => LeaveRequest(
      id: 0,
      employee: User(id: 7, name: 'Worker', email: 'worker@example.com', role: 'EMPLOYEE'),
      startDate: DateTime(2026, 10, 1),
      endDate: DateTime(2026, 10, 5),
      status: 'PENDING',
      reason: 'Surgery',
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

    expect(news.items.single.title, 'Staff meeting');
    expect(sent!.url.path, '/api/v1/news');
    expect(sent!.url.queryParameters, {'page': '0', 'size': '20'});
  });

  // B26 step 26c2: one row per conversation, from the server, a page at a time.
  test('conversations are asked for by page, with no user id in the URL', () async {
    http.BaseRequest? sent;
    final api = ApiService(client: MockClient((request) async {
      sent = request;
      return http.Response(
          '{"content":[],"page":1,"size":20,"totalElements":21,"totalPages":2}',
          200);
    }));

    final page = await api.getConversations(page: 1);

    // The server takes the user from the token (26c1).
    expect(sent!.url.path, '/api/v1/messages/conversations');
    expect(sent!.url.queryParameters, {'page': '1', 'size': '20'});
    expect(page.page, 1);
    expect(page.hasMore, isFalse);
  });

  test('a failed conversation list throws, not an empty list (B44)', () async {
    final api = ApiService(client: MockClient((_) async => http.Response('', 500)));

    // getInbox and getSent returned [] for any failure, so the screen showed
    // "no messages" instead of an error.
    await expectLater(api.getConversations(), throwsException);
  });

  // B26 step 26b2b: each news tab pages through its own type on the server.
  test('news of one type is asked for by type, at the page given', () async {
    http.BaseRequest? sent;
    final api = ApiService(client: MockClient((request) async {
      sent = request;
      return http.Response(
          '{"content":[],"page":1,"size":20,"totalElements":21,"totalPages":2}',
          200);
    }));

    final goals = await api.getNews(type: 'GOAL', page: 1);

    expect(sent!.url.path, '/api/v1/news/type/GOAL');
    expect(sent!.url.queryParameters, {'page': '1', 'size': '20'});
    expect(goals.page, 1);
    expect(goals.hasMore, isFalse);
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

  // Newest first since B26 step 26d, as the server sends it: the chat list is
  // reversed, so the newest sits at the bottom and older pages load above.
  test('a chat page stays newest first, and older pages are asked for by number',
      () async {
    http.BaseRequest? sent;
    String message(int id, String time) =>
        '{"id":$id,"content":"m$id","timestamp":"2026-09-19T$time",'
        '"read":true,'
        '"sender":{"id":9,"name":"Boss","email":"boss@example.com","phoneNumber":null,"role":"SUPERVISOR"},'
        '"receiver":{"id":7,"name":"Worker","email":"worker@example.com","phoneNumber":null,"role":"EMPLOYEE"}}';
    final api = ApiService(client: MockClient((request) async {
      sent = request;
      return http.Response(
          '{"content":[${message(2, "10:00:00")},${message(1, "09:00:00")}],'
          '"page":1,"size":50,"totalElements":52,"totalPages":2}',
          200);
    }));

    final chat = await api.getChatHistory(7, 9, page: 1);

    expect(chat.items.map((m) => m.id), [2, 1]);
    expect(chat.page, 1);
    // user1Id: the caller says who is asking; the service no longer looks it up.
    expect(sent!.url.queryParameters,
        {'user1Id': '7', 'user2Id': '9', 'page': '1', 'size': '50'});
  });

  test('a failed chat load throws, not an empty chat (B44)', () async {
    final api = ApiService(client: MockClient((_) async => http.Response('', 500)));

    await expectLater(api.getChatHistory(7, 9), throwsException);
  });

  test('a chat is marked read with one request naming only the other person',
      () async {
    final sent = <http.BaseRequest>[];
    final api = ApiService(client: MockClient((request) async {
      sent.add(request);
      return http.Response('', 204);
    }));

    await api.markChatAsRead(9);

    // One PUT for the whole chat (B27). The server takes the receiver from
    // the token, so the caller's own id is not in the URL.
    expect(sent.map((r) => '${r.method} ${r.url.path}'),
        ['PUT /api/v1/messages/chat/9/read']);
  });

  test('marking a chat read reports a refusal instead of hiding it', () async {
    final api = ApiService(client: MockClient((_) async {
      return http.Response('', 500);
    }));

    // Not markAsRead's old catch-everything shape (B44): the caller decides.
    await expectLater(api.markChatAsRead(9), throwsException);
  });

  test('own leave requests and own schedule are asked for the id passed in',
      () async {
    final paths = <String>[];
    final api = ApiService(client: MockClient((request) async {
      paths.add(request.url.path);
      return http.Response(
          request.url.path.contains('leaves')
              ? '{"content":[],"page":0,"size":50,"totalElements":0,"totalPages":0}'
              : '[]',
          200);
    }));

    await api.getMyLeaveRequests(7);
    await api.getFilteredShifts(7, DateTime(2026, 2, 1), DateTime(2026, 2, 28));

    // /users/{id}/leaves since F16 step 16d2; the old
    // /leaves/users/{id}/leaves was removed from the server in 16d3.
    expect(paths, ['/api/v1/users/7/leaves', '/api/v1/users/7/schedule']);
  });

  // B26: the leave screen loads older requests a page at a time.
  test('both leave lists ask for the page they are given', () async {
    final asked = <Map<String, String>>[];
    final api = ApiService(client: MockClient((request) async {
      asked.add(request.url.queryParameters);
      return http.Response(
          '{"content":[],"page":2,"size":50,"totalElements":100,"totalPages":3}',
          200);
    }));

    final everyone = await api.getAllLeaveRequests(page: 2);
    await api.getMyLeaveRequests(7, page: 2);

    expect(asked, [
      {'page': '2', 'size': '50'},
      {'page': '2', 'size': '50'},
    ]);
    // The page's place in the list reaches the screen, not only its rows.
    expect(everyone.page, 2);
    expect(everyone.hasMore, isFalse);
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

  // B26: the staff list feeds pickers, so it reads every page, not only the
  // first. Each fake answers ?page=N with the users given for page N.
  group('the staff list across pages', () {
    String staffPage(int page, int totalPages, List<int> ids) => jsonEncode({
          'content': [
            for (final id in ids)
              {'id': id, 'name': 'User $id', 'email': 'u$id@example.com', 'role': 'EMPLOYEE'}
          ],
          'page': page,
          'size': 100,
          'totalElements': ids.length,
          'totalPages': totalPages,
        });

    test('reads every page, in order, into one list', () async {
      final asked = <String?>[];
      final api = ApiService(client: MockClient((request) async {
        final page = request.url.queryParameters['page'];
        asked.add(page);
        if (asked.length > 5) return http.Response('', 500); // fail, not hang
        return http.Response(
            staffPage(int.parse(page!), 3, [int.parse(page) + 1]), 200);
      }));

      final staff = await api.getAllEmployees();

      expect(asked, ['0', '1', '2']);
      expect(staff.map((u) => u.id), [1, 2, 3]);
    });

    test('an empty staff list is one request', () async {
      var requests = 0;
      final api = ApiService(client: MockClient((request) async {
        requests++;
        if (requests > 5) return http.Response('', 500); // fail, not hang
        // What the server sends for no users: no pages at all, not one empty one.
        return http.Response(staffPage(0, 0, []), 200);
      }));

      final staff = await api.getAllEmployees();

      expect(staff, isEmpty);
      expect(requests, 1);
    });

    test('a failed later page fails the whole list', () async {
      final api = ApiService(client: MockClient((request) async {
        final page = request.url.queryParameters['page'];
        return page == '0'
            ? http.Response(staffPage(0, 2, [1]), 200)
            : http.Response('', 500);
      }));

      // Not page 0 alone: a picker missing people is the bug B26 is about.
      await expectLater(api.getAllEmployees(), throwsException);
    });

    test('someone who moves onto the next page is listed once', () async {
      // User 2 is last on page 0; someone added before it in the name order
      // between the two requests pushes it onto page 1 as well.
      final api = ApiService(client: MockClient((request) async {
        final page = request.url.queryParameters['page'];
        return http.Response(
            page == '0' ? staffPage(0, 2, [1, 2]) : staffPage(1, 2, [2, 3]),
            200);
      }));

      final staff = await api.getAllEmployees();

      expect(staff.map((u) => u.id), [1, 2, 3]);
    });
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

  // B31: two different 409s. The server tells them apart by the body's
  // "type" (RFC 9457), never by its English "detail" text.
  group('a refused shift', () {
    Future<AssignShiftResult> assignAnswered409(String body) {
      final api =
          ApiService(client: MockClient((_) async => http.Response(body, 409)));
      return api.assignShift(aShift(), 7);
    }

    test('is "on leave" when the server says so', () async {
      expect(
          await assignAnswered409(
              '{"type":"urn:shift-manager:problem:employee-on-leave",'
              '"status":409,"detail":"On approved leave on 2026-09-29"}'),
          AssignShiftResult.onLeave);
    });

    test('is an overlap when the 409 has another type or none', () async {
      expect(await assignAnswered409('{"type":"urn:something-else"}'),
          AssignShiftResult.overlaps);
      expect(await assignAnswered409('{"status":409}'), AssignShiftResult.overlaps);
    });

    test('is still an overlap when the body is not JSON', () async {
      // E.g. a proxy's HTML page. Reading the type must not turn a real
      // refusal into "save failed, try again".
      expect(await assignAnswered409('<html>Conflict</html>'),
          AssignShiftResult.overlaps);
      expect(await assignAnswered409(''), AssignShiftResult.overlaps);
      expect(await assignAnswered409('["not", "an", "object"]'),
          AssignShiftResult.overlaps);
    });
  });

  test('assigning a shift without a network is a failure, not a crash', () async {
    final api = ApiService(client: MockClient((_) async {
      throw http.ClientException('no network');
    }));

    final result = await api.assignShift(aShift(), 7);

    expect(result, AssignShiftResult.failed);
  });

  // B19: the reply used to be ignored, so a refused request looked filed.
  test('filing leave reports whether the server took it', () async {
    Future<SubmitLeaveResult> submitAnswered(int status) {
      final api = ApiService(
          client: MockClient((_) async => http.Response('{}', status)));
      return api.submitLeaveRequest(aLeave());
    }

    expect(await submitAnswered(201), SubmitLeaveResult.created);
    expect(await submitAnswered(400), SubmitLeaveResult.invalid);
    expect(await submitAnswered(500), SubmitLeaveResult.failed);
  });

  test('filing leave without a network is a failure, not a crash', () async {
    final api = ApiService(client: MockClient((_) async {
      throw http.ClientException('no network');
    }));

    final result = await api.submitLeaveRequest(aLeave());

    expect(result, SubmitLeaveResult.failed);
  });

  // B42: the reply used to be ignored, so a refused answer looked like it worked.
  test('answering leave reports whether the server took it', () async {
    Future<UpdateLeaveStatusResult> answerAnswered(int status) async {
      final api = ApiService(
          client: MockClient((_) async => http.Response('{}', status)));
      return (await api.updateLeaveStatus(5, 'APPROVED')).result;
    }

    expect(await answerAnswered(200), UpdateLeaveStatusResult.updated);
    // 409: someone answered it first (B63).
    expect(await answerAnswered(409), UpdateLeaveStatusResult.alreadyAnswered);
    expect(await answerAnswered(404), UpdateLeaveStatusResult.notFound);
    expect(await answerAnswered(403), UpdateLeaveStatusResult.failed);
    expect(await answerAnswered(500), UpdateLeaveStatusResult.failed);
  });

  test('answering leave sends the answer to that request', () async {
    http.Request? sent;
    final api = ApiService(client: MockClient((request) async {
      sent = request;
      return http.Response('{}', 200);
    }));

    await api.updateLeaveStatus(5, 'REJECTED');

    expect(sent!.method, 'PUT');
    expect(sent!.url.path, '/api/v1/leaves/5/status');
    expect(sent!.url.queryParameters, {'status': 'REJECTED'});
  });

  test('answering leave without a network is a failure, not a crash', () async {
    final api = ApiService(client: MockClient((_) async {
      throw http.ClientException('no network');
    }));

    final answer = await api.updateLeaveStatus(5, 'APPROVED');

    expect(answer, (result: UpdateLeaveStatusResult.failed, removedShifts: 0));
  });

  // B31: approving removes the employee's shifts on the leave days, and the
  // 200 says how many.
  group('an answered leave request', () {
    Future<({UpdateLeaveStatusResult result, int removedShifts})> approvedWith(
        String body) {
      final api =
          ApiService(client: MockClient((_) async => http.Response(body, 200)));
      return api.updateLeaveStatus(5, 'APPROVED');
    }

    test('says how many shifts the approval removed', () async {
      expect(await approvedWith('{"id":5,"status":"APPROVED","removedShifts":2}'),
          (result: UpdateLeaveStatusResult.updated, removedShifts: 2));
    });

    test('still worked when the body does not say', () async {
      // The answer is already stored, so a body the app cannot read must not
      // turn it into "failed": the supervisor would try again, and be told
      // it was already answered.
      const worked = (result: UpdateLeaveStatusResult.updated, removedShifts: 0);
      expect(await approvedWith('{}'), worked);
      expect(await approvedWith('not json'), worked);
      expect(await approvedWith('{"removedShifts":"two"}'), worked);
      expect(await approvedWith('[2]'), worked);
    });
  });

  test('a password change names no user: the server takes it from the token (B8)',
      () async {
    late http.Request sent;
    final api = ApiService(client: MockClient((request) async {
      sent = request;
      return http.Response('', 204);
    }));

    await api.changePassword('old-secret', 'new-secret');

    expect(sent.method, 'PUT');
    expect(sent.url.path, endsWith('/users/me/password'));
    expect(jsonDecode(sent.body),
        {'currentPassword': 'old-secret', 'newPassword': 'new-secret'});
  });

  test('a password change reports why the server refused it', () async {
    Future<ChangePasswordResult> changeAnswered(int status, [String body = '']) {
      final api = ApiService(
          client: MockClient((_) async => http.Response(body, status)));
      return api.changePassword('old-secret', 'new-secret');
    }

    // 204 has an empty body: reading it as JSON would throw.
    expect(await changeAnswered(204), ChangePasswordResult.changed);
    expect(
        await changeAnswered(400,
            '{"status":400,"detail":"Current password is incorrect"}'),
        ChangePasswordResult.wrongCurrentPassword);
    // Any other 400 - a broken field rule, or the 72-byte limit - must not be
    // reported as a wrong current password.
    expect(
        await changeAnswered(400,
            '{"status":400,"detail":"Validation failed","errors":{"newPassword":"..."}}'),
        ChangePasswordResult.invalid);
    // The 72-byte limit, as the server sends it since B20 step 20b.
    expect(
        await changeAnswered(400,
            '{"status":400,"detail":"Validation failed",'
            '"errors":{"newPassword":"New password must be at most 72 bytes"}}'),
        ChangePasswordResult.invalid);
    // Five wrong current passwords lock the change for 15 minutes (B56).
    expect(
        await changeAnswered(429,
            '{"status":429,"detail":"Too many failed attempts, try again later"}'),
        ChangePasswordResult.tooManyAttempts);
    expect(await changeAnswered(500), ChangePasswordResult.failed);
  });

  test('a 429 says how long to wait in its Retry-After header (B56)', () {
    // Lower-case, as in a real response: the http package's client
    // lower-cases header names, and a fake response keeps what it is given.
    http.Response locked(Map<String, String> headers) =>
        http.Response('', 429, headers: headers);

    expect(ApiService.retryAfter(locked({'retry-after': '120'})),
        const Duration(seconds: 120));
    expect(ApiService.retryAfter(locked({})), isNull);
    // "Wait 0 seconds" while locked makes no sense; the server sends at least 1.
    expect(ApiService.retryAfter(locked({'retry-after': '0'})), isNull);
    expect(ApiService.retryAfter(locked({'retry-after': '-5'})), isNull);
    // RFC 9110 also allows a date here. Our server never sends one, but the
    // app must not crash if a proxy in between does.
    expect(
        ApiService.retryAfter(
            locked({'retry-after': 'Wed, 21 Oct 2026 07:28:00 GMT'})),
        isNull);
  });

  test('a password change without a network is a failure, not a crash', () async {
    final api = ApiService(client: MockClient((_) async {
      throw http.ClientException('no network');
    }));

    expect(await api.changePassword('old-secret', 'new-secret'),
        ChangePasswordResult.failed);
  });

  // F26: print() goes to the device log in release builds too, so nothing the
  // service does may reach it, whether the call works or fails.
  group('nothing is printed to the device log', () {
    test('when the server answers', () async {
      final api = ApiService(client: MockClient((request) async {
        // A PUT answers 204 with no body, like the server's mark-chat-read.
        if (request.method == 'PUT') return http.Response('', 204);
        return http.Response(
            '{"content":[],"page":0,"size":20,"totalElements":0,"totalPages":0}',
            200);
      }));

      final printed = await printedBy(() async {
        await api.getConversations();
        await api.markChatAsRead(9);
        await api.deleteUser(7);
        await api.getNews();
        // Its request carries both passwords (B8).
        await api.changePassword('old-secret', 'new-secret');
      });

      expect(printed, isEmpty);
    });

    test('when there is no network', () async {
      final api = ApiService(client: MockClient((_) async {
        throw http.ClientException('no network');
      }));

      final printed = await printedBy(() async {
        await expectLater(api.getConversations(), throwsException);
        await expectLater(api.markChatAsRead(9), throwsException);
        await expectLater(api.getNews(), throwsException);
        await api.changePassword('old-secret', 'new-secret');
      });

      expect(printed, isEmpty);
    });
  });
}

/// Runs [body] and returns every line it sent to print().
Future<List<String>> printedBy(Future<void> Function() body) async {
  final lines = <String>[];
  await runZoned(
    body,
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) => lines.add(line),
    ),
  );
  return lines;
}
