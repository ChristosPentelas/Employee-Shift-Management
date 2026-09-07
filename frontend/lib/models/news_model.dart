import 'user_model.dart';

class NewsItem{
  final int id;
  final String title;
  final String description;
  final String type;
  final DateTime createdAt;
  final User author;
  final DateTime? deadline;
  final int? targetValue;

  NewsItem({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.createdAt,
    required this.author,
    this.deadline,
    this.targetValue
  });

  factory NewsItem.fromJson(Map<String, dynamic> json) {
    return NewsItem(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      type: json['type'],
      author: User.fromJson(json['author']),
      createdAt: DateTime.parse(json['createdAt']),
      deadline: json['deadline'] != null ? DateTime.parse(json['deadline']) : null,
      targetValue: json['targetValue']?.toInt(),
    );
  }

  Map<String, dynamic> toJson(){
    return{
      'id' : id,
      'title' : title,
      'description' : description,
      'type' : type,
      'author' : author,
      'createdAt' : createdAt,
      'deadline' : deadline,
      'targetValue' : targetValue,
    };
  }
}