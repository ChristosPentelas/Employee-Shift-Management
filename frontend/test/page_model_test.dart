// B26: ListPage reads one page of any list endpoint, and says whether the
// server has another one after it.

import 'package:employee_shift_management_ui/models/page_model.dart';
import 'package:flutter_test/flutter_test.dart';

// The server's PageResponse shape (F9).
Map<String, dynamic> pageJson({required int page, required int totalPages}) => {
      'content': [
        {'n': 1},
        {'n': 2},
      ],
      'page': page,
      'size': 2,
      'totalElements': 2 * totalPages,
      'totalPages': totalPages,
    };

ListPage<int> read(Map<String, dynamic> json) =>
    ListPage.fromJson(json, (item) => item['n'] as int);

void main() {
  test('reads each row with the function it is given', () {
    final page = read(pageJson(page: 1, totalPages: 3));

    expect(page.items, [1, 2]);
    expect(page.page, 1);
    expect(page.totalPages, 3);
  });

  test('a page before the last has more after it', () {
    expect(read(pageJson(page: 1, totalPages: 3)).hasMore, isTrue);
  });

  test('the last page has nothing after it', () {
    // Zero-based: of 3 pages, the last is page 2.
    expect(read(pageJson(page: 2, totalPages: 3)).hasMore, isFalse);
  });

  test('an empty list, which has no pages at all, has nothing more', () {
    final json = pageJson(page: 0, totalPages: 0)..['content'] = [];

    expect(read(json).hasMore, isFalse);
  });
}
