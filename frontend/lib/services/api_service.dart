import 'dart:convert'; //To convert from JSON to Map
import 'package:employee_shift_management_ui/models/leave_request_model.dart';
import 'package:employee_shift_management_ui/models/news_model.dart';
import 'package:http/http.dart' as http;//Library for internet
import '../models/user_model.dart';
import '../models/shift_model.dart';
import '../models/message_model.dart';
import 'dart:developer' as developer;

/// The outcome of ApiService.assignShift.
enum AssignShiftResult {
  created,
  /// 409: the employee already has a shift at that time (F30).
  overlaps,
  /// 400: the server refused a field, e.g. a time that is not HH:mm.
  invalid,
  /// Anything else, including no network.
  failed,
}

/// The outcome of ApiService.submitLeaveRequest (B19).
enum SubmitLeaveResult {
  /// 201: the request is filed, as PENDING.
  created,
  /// 400: the server refused a field, e.g. a blank or too long reason. The
  /// dialog checks those first, so this means the two rules drifted apart.
  invalid,
  /// Anything else, including no network.
  failed,
}

/// The outcome of ApiService.changePassword (B8).
enum ChangePasswordResult {
  /// 204: the new password is stored. The login token stays valid.
  changed,
  /// 400 saying the current password is wrong.
  wrongCurrentPassword,
  /// Any other 400: the server refused the new password, e.g. too short.
  /// The dialog checks the same rules first, so this means they drifted apart.
  invalid,
  /// 429: too many wrong current passwords, so changing is locked for a while
  /// (B56). Logging in is counted separately and still works.
  tooManyAttempts,
  /// Anything else, including no network.
  failed,
}

class ApiService {
  // Where the backend lives, chosen when the app is built (F27):
  //   flutter run --dart-define=API_BASE_URL=http://192.168.1.50:8080/api/v1
  // Without it, 10.0.2.2 is used: the Android emulator's name for the PC it
  // runs on. The value is compiled in, so changing it needs a full restart,
  // not a hot reload. See frontend/README.md.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8080/api/v1',
  );

  // Every request below goes through this client. In the app it is the
  // AuthClient from authClientProvider, which adds the login token; tests pass
  // a fake. Screens get their ApiService from apiServiceProvider.
  final http.Client _client;

  ApiService({required http.Client client}) : _client = client;

  // Every list endpoint answers one page at a time (F9):
  // {"content": [...], "page": 0, "size": 20, "totalElements": .., "totalPages": ..}
  // Only the first page is read for now; older items need a "load more" (B26).
  static List<dynamic> _pageContent(http.Response response) =>
      jsonDecode(response.body)['content'] as List<dynamic>;

  // YYYY-MM-DD, the date format of ?start= and &end=.
  static String _isoDate(DateTime day) =>
      "${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}";

  // For login
  Future<http.Response> login(String email, String password) async {
    final url = Uri.parse("$baseUrl/users/login");

    return await _client.post(
      url,
      headers: {"Content-Type" : "application/json"},
      body: jsonEncode({
        "email" : email,
        "password" : password,
      }),
    );
  }

  // How long a 429 says to wait (B56), or null if it does not say so in a form
  // the app can use. The server sends whole seconds; RFC 9110 also allows a
  // date, which is treated as "unknown" rather than parsed. The http package
  // lower-cases header names, so 'Retry-After' would never be found.
  static Duration? retryAfter(http.Response response) {
    // tryParse, not parse: parse throws on a date, and the caller's catch
    // would then tell the user the server cannot be reached.
    final seconds = int.tryParse(response.headers['retry-after'] ?? '');
    if (seconds == null || seconds <= 0) return null;
    return Duration(seconds: seconds);
  }

  // The staff list feeds pickers (assign a shift, start a chat), so it asks
  // for the largest page the server allows: 100 people, sorted by name.
  Future<List<User>> getAllEmployees() async {
    try{
      // endpoint for all users
      final response = await _client.get(
        Uri.parse("$baseUrl/users?page=0&size=100"),
        headers: {"Content-Type": "application/json"},
      );

      if (response.statusCode == 200){
        // We convert each element of the page into a User object
        List<User> employees = _pageContent(response).map((dynamic item) => User.fromJson(item)).toList();

        return employees;
      }else{
        throw Exception("Αποτυχία φόρτωσης υπαλλήλων: ${response.statusCode}");
    }
    }catch (e) {
      throw Exception("Σφάλμα δικτύου: $e");
    }
  }

  Future<void> deleteUser(int userId) async {
    try{

      final response = await _client.delete(
        Uri.parse("$baseUrl/users/$userId"),
        headers: {"Content-Type" : "application/json"},
      );

      if(response.statusCode != 200 && response.statusCode != 204) {
        throw Exception("Αποτυχία διαγραφής: ${response.statusCode}");
      }
    }catch (e){
      throw Exception("Σφάλμα κατά τη διαγραφή: $e");
    }
  }

  // The newest page of news.
  Future<List<NewsItem>> getNews({int page = 0, int size = 20}) async {
    try{
      final response = await _client.get(
        Uri.parse("$baseUrl/news?page=$page&size=$size"),
        headers: {"Content-Type" : "application/json"},
      );

      if (response.statusCode == 200) {
        return _pageContent(response).map((item) => NewsItem.fromJson(item)).toList();
      }else{
        throw Exception("Αποτυχία φόρτωσης ειδήσεων");
    }
    } catch (e) {
      throw Exception("Σφάλμα σύνδεσης: $e");
    }
  }

  Future<void> postNews(NewsItem item) async {
    try{
      final response = await _client.post(
        Uri.parse("$baseUrl/news"),
        headers: {"Content-Type" : "application/json"},
        body: jsonEncode({
          "title": item.title,
          "description": item.description,
          "type": item.type,
          // No authorId: the server records the supervisor posting it (F1 step 7b).
          "deadline": item.deadline?.toIso8601String(),
          "targetValue": item.targetValue,
        }
        ),
      );
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception("Αποτυχία δημιουργίας: ${response.statusCode}");
      }
    } catch (e) {
      throw Exception("Σφάλμα: $e");
    }
  }

  Future<void> deleteNews(int id) async {
    try{
      final response = await _client.delete(
        Uri.parse("$baseUrl/news/$id"),
        headers: {"Content-Type" : "application/json"},
      );

      if(response.statusCode != 200 && response.statusCode != 204) {
        throw Exception("Αποτυχία διαγραφής: ${response.statusCode}");
      }
    }catch (e){
      throw Exception("Σφάλμα κατά τη διαγραφή: $e");
    }
  }

  Future<List<LeaveRequest>> getAllLeaveRequests() async {
    // The latest 50, by start date.
    final response = await _client.get(Uri.parse("$baseUrl/leaves?page=0&size=50"));
    if (response.statusCode == 200) {
      return _pageContent(response).map((item) => LeaveRequest.fromJson(item)).toList();
    }
    throw Exception("Σφάλμα φόρτωσης αδειών");
  }

  /// Only the logged-in employee's own requests. Supervisors use
  /// getAllLeaveRequests; from F1 step 7d an employee may not call that.
  /// The caller says who is logged in: a service is handed what it needs
  /// instead of reaching into app state (F24).
  Future<List<LeaveRequest>> getMyLeaveRequests(int userId) async {
    final response = await _client.get(Uri.parse("$baseUrl/users/$userId/leaves?page=0&size=50"));

    if (response.statusCode == 200) {
      return _pageContent(response).map((item) => LeaveRequest.fromJson(item)).toList();
    }
    throw Exception("Σφάλμα φόρτωσης αδειών");
  }

  /// Files a leave request and says whether the server took it. It used to
  /// ignore the reply, so a refused request looked filed (B19).
  Future<SubmitLeaveResult> submitLeaveRequest(LeaveRequest leave) async {
    try {
      final response = await _client.post(
        Uri.parse("$baseUrl/leaves"),
        headers: {"Content-Type" : "application/json"},
        body: jsonEncode({
          // No userId: the server files it for whoever the token says we are.
          "startDate": leave.startDate.toIso8601String(),
          "endDate": leave.endDate.toIso8601String(),
          "reason": leave.reason
        }),
      );
      switch (response.statusCode) {
        case 201:
          return SubmitLeaveResult.created;
        case 400:
          return SubmitLeaveResult.invalid;
        default:
          return SubmitLeaveResult.failed;
      }
    } catch (e) {
      return SubmitLeaveResult.failed;
    }
  }

  Future<void> updateLeaveStatus(int leaveId, String newStatus) async {
    await _client.put(
      Uri.parse("$baseUrl/leaves/$leaveId/status?status=$newStatus"),
    );
  }

  /// Saves your own profile and returns it as the server stored it, or null
  /// if that failed. It does not change the session: the caller decides what
  /// to do with the result, and the service stays free of app state (F24).
  Future<User?> updateUser(int userId,String name,String email,String phone) async {
    try{
      final response = await _client.put(
        Uri.parse("$baseUrl/users/$userId"),
        headers: {"Content-Type" : "application/json"},
        body: jsonEncode({
          "name" : name,
          "email" : email,
          "phoneNumber" : phone,
        }),
      );

      if (response.statusCode == 200) {
        return User.fromJson(jsonDecode(response.body));
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // The server's `detail` for a wrong current password. A 400 carries no
  // machine-readable code (B58), so this English text is the only way to tell
  // it from other 400s; the backend's UserControllerTest pins it. If it ever
  // changes, the app falls back to `invalid`, never to a false "wrong password".
  static const String _wrongCurrentPasswordDetail = "Current password is incorrect";

  // Changes the logged-in user's own password (B8). There is no user id to
  // send: the server takes it from the token.
  //
  // Neither the request nor the response body is ever logged - both
  // passwords are in the request (F26).
  Future<ChangePasswordResult> changePassword(String currentPassword, String newPassword) async {
    try {
      final response = await _client.put(
        Uri.parse("$baseUrl/users/me/password"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "currentPassword": currentPassword,
          "newPassword": newPassword,
        }),
      );
      switch (response.statusCode) {
        case 204:
          return ChangePasswordResult.changed;
        case 400:
          // Decoded only here: a 204 has an empty body, and jsonDecode('')
          // throws.
          final detail = (jsonDecode(response.body) as Map<String, dynamic>)['detail'];
          return detail == _wrongCurrentPasswordDetail
              ? ChangePasswordResult.wrongCurrentPassword
              : ChangePasswordResult.invalid;
        case 429:
          return ChangePasswordResult.tooManyAttempts;
        default:
          return ChangePasswordResult.failed;
      }
    } catch (e) {
      return ChangePasswordResult.failed;
    }
  }

  // Everyone's shifts from start to end, both days included (at most 366
  // days - the server refuses more). Not paged: a calendar needs them all.
  Future<List<Shift>> getAllShifts(DateTime start, DateTime end) async {
    final response = await _client.get(
        Uri.parse("$baseUrl/shifts?start=${_isoDate(start)}&end=${_isoDate(end)}"));

    if (response.statusCode == 200) {
      List body = jsonDecode(response.body);
      return body.map((item) => Shift.fromJson(item)).toList();
    }
    throw Exception("Error loading all shifts");
  }

  // What happened to the shift, not how to say it: the screen picks the
  // wording, because the server's English detail is not for the user (B2).
  Future<AssignShiftResult> assignShift(Shift shift, int userId) async {
    try {
      final response = await _client.post(
        Uri.parse("$baseUrl/users/$userId/shifts"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "date": shift.date.toIso8601String().split('T')[0], // YYYY-MM-DD
          "startTime": shift.startTime,
          "endTime": shift.endTime,
          "position": shift.position,
        }),
      );
      switch (response.statusCode) {
        case 200:
        case 201:
          return AssignShiftResult.created;
        case 409:
          return AssignShiftResult.overlaps;
        case 400:
          return AssignShiftResult.invalid;
        default:
          return AssignShiftResult.failed;
      }
    } catch (e) {
      return AssignShiftResult.failed;
    }
  }

  Future<bool> deleteShift(int shiftId) async {
    try {
      final response = await _client.delete(Uri.parse("$baseUrl/shifts/$shiftId"));

      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      return false;
    }
  }

  Future<List<Shift>> getFilteredShifts(int userId, DateTime start, DateTime end) async {
    final response = await _client.get(
      Uri.parse("$baseUrl/users/$userId/schedule?start=${_isoDate(start)}&end=${_isoDate(end)}")
    );

    if (response.statusCode == 200) {
      List body = jsonDecode(response.body);
      return body.map((item) => Shift.fromJson(item)).toList();
    } else {
      throw Exception("Failed to load filtered shifts");
    }
  }

  // The latest 50 messages of a chat, oldest first. The server sends a page
  // newest-first (page 0 = the latest), so it is turned around here and the
  // chat screen keeps receiving the order it always had.
  Future<List<Message>> getChatHistory(int currentUserId, int otherUserId) async {
    final response = await _client.get(
      Uri.parse("$baseUrl/messages/chat?user1Id=$currentUserId&user2Id=$otherUserId&page=0&size=50")
    );

    if (response.statusCode == 200) {
      return _pageContent(response).map((item) => Message.fromJson(item)).toList().reversed.toList();
    }
    return [];
  }

  Future<bool> sendMessage(int receiverId, String content) async {
    // No senderId: the server takes the sender from the token (F1 step 7a).
    final response = await _client.post(
      Uri.parse("$baseUrl/messages?receiverId=$receiverId"),
      headers: {"Content-Type" : "application/json"},
      body: jsonEncode({"content" : content}),
    );

    return response.statusCode == 201;
  }

  // Everything otherUserId sent us, marked read with one request (B27). No
  // receiver id: the server takes it from the token. Throws on failure, so
  // the caller can tell (not markAsRead's old silence, B44).
  Future<void> markChatAsRead(int otherUserId) async {
    final response = await _client.put(
      Uri.parse("$baseUrl/messages/chat/$otherUserId/read"),
    );

    if (response.statusCode != 204) {
      throw Exception("Marking the chat read failed: ${response.statusCode}");
    }
  }

  Future<List<Message>> getInbox(int userId) async {
    try {
      final response = await _client.get(
        Uri.parse("$baseUrl/messages/inbox/$userId?page=0&size=50"),
      );



      if (response.statusCode == 200) {
        return _pageContent(response).map((item) => Message.fromJson(item)).toList();
      }
    } catch (e) {
      developer.log("getInbox failed", name: "ApiService", error: e);
    }
    return [];
  }

  Future<List<Message>> getSent(int userId) async {
    try {
      // Αντιστοιχεί στο @GetMapping("/sent/{userId}") του Controller σου
      final response = await _client.get(
        Uri.parse("$baseUrl/messages/sent/$userId?page=0&size=50"),
      );

      if (response.statusCode == 200) {
        return _pageContent(response).map((item) => Message.fromJson(item)).toList();
      }
    } catch (e) {
      developer.log("getSent failed", name: "ApiService", error: e);
    }
    return [];
  }

  Future<bool> registerUser(String name,String email,String phone,String password) async{
    try {
      final response = await _client.post(
        Uri.parse("$baseUrl/users"),
        headers: {"Content-Type" : "application/json"},
        body: jsonEncode({
          "name" : name,
          "email" : email,
          "phoneNumber" : phone,
          "password" : password,
        }),
      );

      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
