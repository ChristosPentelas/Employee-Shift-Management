import 'dart:convert'; //To convert from JSON to Map
import 'package:employee_shift_management_ui/models/leave_request_model.dart';
import 'package:employee_shift_management_ui/models/news_model.dart';
import 'package:http/http.dart' as http;//Library for internet
import '../models/user_model.dart';
import '../models/shift_model.dart';
import '../models/message_model.dart';
import 'auth_client.dart';

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

class ApiService {
  //IP 10.0.2.2 is the localhost to my PC
  static const String baseUrl = "http://10.0.2.2:8080/api/v1";

  // One client for the whole app. Every screen creates its own ApiService, and
  // a new http.Client per screen would open a separate connection pool each time.
  static final http.Client _sharedClient = AuthClient();

  // Every request below goes through this client, which adds the login token.
  final http.Client _client;

  // Tests pass a fake client; the app uses the shared one.
  ApiService({http.Client? client}) : _client = client ?? _sharedClient;

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
      print("Full Delete URL: ${baseUrl}/users/$userId");
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

  Future<User?> findUserByEmail(String email) async {
    try{
      final response = await _client.get(
        Uri.parse("$baseUrl/users/search?email=$email"),
        headers: {"Content-Type" : "application/json"},
      );

      if(response.statusCode == 200){
        return User.fromJson(jsonDecode(response.body));
      }else {
        return null;
      }
    } catch (e) {
      throw Exception("Σφάλμα αναζήτησης: $e");
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
      print("DEBUG ERROR: $e"); // Αυτό θα το δεις στο Terminal του VS Code/Android Studio
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
    final response = await _client.get(Uri.parse("$baseUrl/leaves/users/$userId/leaves?page=0&size=50"));

    if (response.statusCode == 200) {
      return _pageContent(response).map((item) => LeaveRequest.fromJson(item)).toList();
    }
    throw Exception("Σφάλμα φόρτωσης αδειών");
  }

  Future<void> submitLeaveRequest(LeaveRequest leave) async {
    await _client.post(
      Uri.parse("$baseUrl/leaves"),
      headers: {"Content-Type" : "application/json"},
      body: jsonEncode({
        // No userId: the server files it for whoever the token says we are.
        "startDate": leave.startDate.toIso8601String(),
        "endDate": leave.endDate.toIso8601String(),
        "reason": leave.reason
      }),
    );
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

  Future<void> markAsRead(int messageId) async {
    try {
      final response = await _client.put(
        Uri.parse("$baseUrl/messages/$messageId/read"),
      );
      print("Marking message $messageId as read. Status: ${response.statusCode}");
    } catch (e) {
      print("Error marking as read: $e");
    }
  }

  Future<List<Message>> getInbox(int userId) async {
    try {
      print("Fetching inbox for user: $userId"); // DEBUG
      final response = await _client.get(
        Uri.parse("$baseUrl/messages/inbox/$userId?page=0&size=50"),
      );

      print("Response Status: ${response.statusCode}"); // DEBUG
      print("Response Body: ${response.body}"); // DEBUG

      if (response.statusCode == 200) {
        return _pageContent(response).map((item) => Message.fromJson(item)).toList();
      }
    } catch (e) {
      print("Error in getInbox: $e");
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
      print("Error in getSent: $e");
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
