import 'user_model.dart';

class NewsItem{
  final int id;
  final String title;
  final String description;
  final String type;
  final DateTime createdAt;
  // Null when the post has no author: the column allows it (author_id is
  // DEFAULT NULL), and the server then sends "author": null (F29).
  final User? author;
  final DateTime? deadline;
  final int? targetValue;

  NewsItem({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.createdAt,
    this.author,
    this.deadline,
    this.targetValue
  });

  factory NewsItem.fromJson(Map<String, dynamic> json) {
    return NewsItem(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      type: json['type'],
      author: json['author'] != null ? User.fromJson(json['author']) : null,
      createdAt: DateTime.parse(json['createdAt']),
      deadline: json['deadline'] != null ? DateTime.parse(json['deadline']) : null,
      targetValue: json['targetValue']?.toInt(),
    );
  }
}