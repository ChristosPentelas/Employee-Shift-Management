import '../models/user_model.dart';

class LeaveRequest {
  final int id;
  final User employee;
  final DateTime startDate;
  final DateTime endDate;
  final String status;
  final String? reason;

  LeaveRequest({
    required this.id,
    required this.employee,
    required this.startDate,
    required this.endDate,
    required this.status,
    this.reason,
  });

  factory LeaveRequest.fromJson(Map<String, dynamic> json) {
    return LeaveRequest(
        id: json['id'],
        employee: User.fromJson(json['user']),
        startDate: DateTime.parse(json['startDate']),
        endDate: DateTime.parse(json['endDate']),
        status: json['status'],
        reason : json['reason'],
    );
  }
}