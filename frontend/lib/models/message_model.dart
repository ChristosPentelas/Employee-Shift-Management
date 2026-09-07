class Message {
  final int id;
  final String content;
  final DateTime timestamp;
  final bool isRead;
  final int senderId;
  final int receiverId;
  final String senderName;

  Message({
    required this.id,
    required this.content,
    required this.timestamp,
    required this.isRead,
    required this.senderId,
    required this.receiverId,
    this.senderName = "",
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'],
      content: json['content'],
      timestamp: DateTime.parse(json['timestamp']),
      isRead: json['read'] ?? false,
      senderId: json['sender']['id'],
      receiverId: json['receiver']['id'],
      senderName: json['sender']['name'] ?? "",
    );
  }
}
