// F29: NewsItem.fromJson must accept every shape the server can send. The
// author_id column is nullable, and NewsItemResponse then sends "author": null.

import 'package:employee_shift_management_ui/models/news_model.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> newsJson({Map<String, dynamic>? author}) => {
      'id': 1,
      'title': 'Απογραφή',
      'description': 'Την Παρασκευή',
      'type': 'ANNOUNCEMENT',
      'createdAt': '2026-09-25T10:00:00',
      'author': author,
      'deadline': null,
      'targetValue': null,
    };

void main() {
  test('reads the author when there is one', () {
    final item = NewsItem.fromJson(newsJson(author: {
      'id': 9,
      'name': 'Boss',
      'email': 'boss@example.com',
      'phoneNumber': null,
      'role': 'SUPERVISOR',
    }));

    expect(item.author?.name, 'Boss');
  });

  test('a post without an author is read, not rejected', () {
    // Before F29 this threw: User.fromJson(null).
    final item = NewsItem.fromJson(newsJson(author: null));

    expect(item.author, isNull);
    expect(item.title, 'Απογραφή');
  });
}
