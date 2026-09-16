import 'dart:convert'; //To convert from JSON to Map
import 'package:employee_shift_management_ui/models/leave_request_model.dart';
import 'package:employee_shift_management_ui/models/news_model.dart';
import 'package:http/http.dart' as http;//Library for internet
import '../models/user_model.dart';
import '../utils/session.dart';
import '../models/shift_model.dart';
import '../models/message_model.dart';
import 'auth_client.dart';

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

  Future<List<User>> getAllEmployees() async {
    try{
      // endpoint for all users
      final response = await _client.get(
        Uri.parse("$baseUrl/users"),
        headers: {"Content-Type": "application/json"},
      );

      if (response.statusCode == 200){
        // From JSON string to List
        List<dynamic> body = jsonDecode(response.body);
        // We convert each element of the list into a User object
        List<User> employees = body.map((dynamic item) => User.fromJson(item)).toList();

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

  Future<List<NewsItem>> getNews() async {
    try{
      final response = await _client.get(
        Uri.parse("$baseUrl/news"),
        headers: {"Content-Type" : "application/json"},
      );

      if (response.statusCode == 200) {
        List<dynamic> body = jsonDecode(response.body);
        return body.map((item) => NewsItem.fromJson(item)).toList();
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
    final response = await _client.get(Uri.parse("$baseUrl/leaves"));
    if (response.statusCode == 200) {
      List body = jsonDecode(response.body);
      return body.map((item) => LeaveRequest.fromJson(item)).toList();
    }
    throw Exception("Σφάλμα φόρτωσης αδειών");
  }

  /// Only the logged-in employee's own requests. Supervisors use
  /// getAllLeaveRequests; from F1 step 7d an employee may not call that.
  Future<List<LeaveRequest>> getMyLeaveRequests() async {
    final userId = Session.currentUser!.id;
    final response = await _client.get(Uri.parse("$baseUrl/leaves/users/$userId/leaves"));

    if (response.statusCode == 200) {
      List body = jsonDecode(response.body);
      return body.map((item) => LeaveRequest.fromJson(item)).toList();
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

  Future<bool> updateUser(int userId,String name,String email,String phone) async {
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
        Session.currentUser!.name = name;
        Session.currentUser!.email = email;
        Session.currentUser!.phoneNumber = phone;
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<List<Shift>> getMyShifts() async {
    final userId = Session.currentUser!.id;
    final response = await _client.get(Uri.parse("$baseUrl/shifts/user/$userId"));

    if(response.statusCode == 200) {
      List body = jsonDecode(response.body);
      return body.map((item) => Shift.fromJson(item)).toList();
    }
    throw Exception("Αποτυχία φόρτωσης βαρδιών");
  }

  Future<List<Shift>> getAllShifts() async {
    final response = await _client.get(Uri.parse("$baseUrl/shifts"));

    if (response.statusCode == 200) {
      List body = jsonDecode(response.body);
      return body.map((item) => Shift.fromJson(item)).toList();
    }
    throw Exception("Error loading all shifts");
  }

  Future<bool> assignShift(Shift shift, int userId) async {
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
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      return false;
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

  Future<List<Shift>> getFilteredShifts(DateTime start, DateTime end) async {
    // YYYY-MM-DD
    String startDate = "${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}";
    String endDate = "${end.year}-${end.month.toString().padLeft(2, '0')}-${end.day.toString().padLeft(2, '0')}";

    final response = await _client.get(
      Uri.parse("$baseUrl/users/${Session.currentUser?.id}/schedule?start=$startDate&end=$endDate")
    );

    if (response.statusCode == 200) {
      List body = jsonDecode(response.body);
      return body.map((item) => Shift.fromJson(item)).toList();
    } else {
      throw Exception("Failed to load filtered shifts");
    }
  }

  Future<List<Message>> getChatHistory(int otherUserId) async {
    final currentUserId = Session.currentUser!.id;

    final response = await _client.get(
      Uri.parse("$baseUrl/messages/chat?user1Id=$currentUserId&user2Id=$otherUserId")
    );

    if (response.statusCode == 200) {
      List body = jsonDecode(response.body);
      return body.map((item) => Message.fromJson(item)).toList();
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
        Uri.parse("$baseUrl/messages/inbox/$userId"),
      );

      print("Response Status: ${response.statusCode}"); // DEBUG
      print("Response Body: ${response.body}"); // DEBUG

      if (response.statusCode == 200) {
        List body = jsonDecode(response.body);
        return body.map((item) => Message.fromJson(item)).toList();
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
        Uri.parse("$baseUrl/messages/sent/$userId"),
      );

      if (response.statusCode == 200) {
        List body = jsonDecode(response.body);
        return body.map((item) => Message.fromJson(item)).toList();
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
