import 'user_model.dart';

class Shift {
  final int id;
  final DateTime date;
  final String startTime; // π.χ. "08:00"
  final String endTime;   // π.χ. "16:00"
  final String position;  // π.χ. "Ταμείο", "Αποθήκη"
  final User? assignedUser;

  Shift({
    required this.id,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.position,
    this.assignedUser,
  });

  factory Shift.fromJson(Map<String, dynamic> json) {
    return Shift(
      id: json['id'],
      date: DateTime.parse(json['date']),
      startTime: json['startTime'],
      endTime: json['endTime'],
      position: json['position'],
      assignedUser: json['user'] != null ? User.fromJson(json['user']) : null,
    );
  }
}