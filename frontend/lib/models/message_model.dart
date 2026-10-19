import 'user_model.dart';

class Message {
  final int id;
  final String content;
  final DateTime timestamp;
  final bool isRead;
  // Both people in full, as the server sends them: the receiver's name and
  // either person's role are needed too, not only the sender's name (B18).
  final User sender;
  final User receiver;

  Message({
    required this.id,
    required this.content,
    required this.timestamp,
    required this.isRead,
    required this.sender,
    required this.receiver,
  });

  int get senderId => sender.id;
  int get receiverId => receiver.id;

  /// The person this message is with, seen from [myId]: the receiver of a
  /// message I sent, the sender of one I received.
  User otherPerson(int myId) => senderId == myId ? receiver : sender;

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'],
      content: json['content'],
      timestamp: DateTime.parse(json['timestamp']),
      isRead: json['read'] ?? false,
      sender: User.fromJson(json['sender']),
      receiver: User.fromJson(json['receiver']),
    );
  }
}
