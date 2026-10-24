// B26 step 26b2a: the paging the leave screen did itself, as a class any
// screen can hold one or more of. Tested here without widgets; the leave
// screen's own tests check it from the outside.

import 'dart:async';

import 'package:employee_shift_management_ui/models/page_model.dart';
import 'package:employee_shift_management_ui/state/paged_list.dart';
import 'package:flutter_test/flutter_test.dart';

/// A fake server whose pages are answered by the test, one Completer per
/// request, so it can choose when - and in what order - each one arrives.
class FakePages {
  final asked = <int>[];
  final _replies = <Completer<ListPage<int>>>[];

  Future<ListPage<int>> fetch(int page) {
    asked.add(page);
    final reply = Completer<ListPage<int>>();
    _replies.add(reply);
    return reply.future;
  }

  /// Answers the [n]th request with these rows.
  void answer(int n, List<int> items, {required int page, required int totalPages}) =>
      _replies[n].complete(ListPage(items: items, page: page, totalPages: totalPages));

  void fail(int n) => _replies[n].completeError(Exception('no network'));
}

void main() {
  late FakePages server;
  late PagedList<int> list;

  setUp(() {
    server = FakePages();
    list = PagedList<int>(fetch: server.fetch, idOf: (n) => n);
  });

  test('is loading, with nothing to show, until the first page arrives', () async {
    expect(list.loading, isTrue);
    expect(list.items, isEmpty);

    final done = list.reload();
    server.answer(0, [1, 2], page: 0, totalPages: 2);
    await done;

    expect(server.asked, [0]);
    expect(list.loading, isFalse);
    expect(list.items, [1, 2]);
    expect(list.hasMore, isTrue);
    expect(list.error, isNull);
  });

  test('load more asks for the next page and adds it after the rows', () async {
    final first = list.reload();
    server.answer(0, [1], page: 0, totalPages: 2);
    await first;

    final more = list.loadMore();
    expect(list.loadingMore, isTrue);
    server.answer(1, [2], page: 1, totalPages: 2);

    expect(await more, isTrue);
    expect(server.asked, [0, 1]);
    expect(list.items, [1, 2]);
    expect(list.hasMore, isFalse);
    expect(list.loadingMore, isFalse);
  });

  test('a row already shown is not added twice', () async {
    final first = list.reload();
    server.answer(0, [1, 2], page: 0, totalPages: 2);
    await first;

    final more = list.loadMore();
    server.answer(1, [2, 3], page: 1, totalPages: 2); // 2 was pushed down (B69)
    await more;

    expect(list.items, [1, 2, 3]);
  });

  test('a second load more while a page is on its way asks only once', () async {
    final first = list.reload();
    server.answer(0, [1], page: 0, totalPages: 2);
    await first;

    final more = list.loadMore();
    // Not a failure, so the screen must not say one: true.
    expect(await list.loadMore(), isTrue);
    server.answer(1, [2], page: 1, totalPages: 2);
    await more;

    expect(server.asked, [0, 1]);
    expect(list.items, [1, 2]);
  });

  test('a page asked for before a reload is not added after it', () async {
    final first = list.reload();
    server.answer(0, [1], page: 0, totalPages: 2);
    await first;

    final more = list.loadMore(); // request 1
    final again = list.reload(); // request 2
    server.answer(2, [10], page: 0, totalPages: 2);
    await again;
    expect(list.loadingMore, isFalse, reason: 'the reload ended the old load');

    server.answer(1, [2], page: 1, totalPages: 2); // arrives late
    await more;

    expect(list.items, [10]);
  });

  test('a failed first load is an error, and a reload clears it', () async {
    final first = list.reload();
    server.fail(0);
    await first;

    expect(list.loading, isFalse);
    expect(list.error, isNotNull);

    final again = list.reload();
    server.answer(1, [1], page: 0, totalPages: 1);
    await again;

    expect(list.error, isNull);
    expect(list.items, [1]);
  });

  test('a failed later page says so and keeps the rows', () async {
    final first = list.reload();
    server.answer(0, [1], page: 0, totalPages: 2);
    await first;

    final more = list.loadMore();
    server.fail(1);

    expect(await more, isFalse);
    expect(list.items, [1]);
    expect(list.hasMore, isTrue); // so the button stays
    expect(list.loadingMore, isFalse);
    expect(list.error, isNull); // not the first load's error
  });

  // B26 step 26c2: the footer shows "try again" instead of loading by itself
  // while this is set, so a failing server is not asked on every frame.
  test('a failed later page is remembered until the next try', () async {
    final first = list.reload();
    server.answer(0, [1], page: 0, totalPages: 2);
    await first;
    expect(list.loadMoreFailed, isFalse);

    final more = list.loadMore();
    server.fail(1);
    await more;
    expect(list.loadMoreFailed, isTrue);

    final retry = list.loadMore();
    expect(list.loadMoreFailed, isFalse, reason: 'trying again');
    server.answer(2, [2], page: 1, totalPages: 2);
    await retry;

    expect(list.loadMoreFailed, isFalse);
    expect(list.items, [1, 2]);
  });

  test('a reload forgets a failed page', () async {
    final first = list.reload();
    server.answer(0, [1], page: 0, totalPages: 2);
    await first;
    final more = list.loadMore();
    server.fail(1);
    await more;

    final again = list.reload();
    server.answer(2, [1], page: 0, totalPages: 2);
    await again;

    expect(list.loadMoreFailed, isFalse);
  });

  test('load more after dispose asks nothing and does not throw', () async {
    final first = list.reload();
    server.answer(0, [1], page: 0, totalPages: 2);
    await first;
    // The footer's after-frame callback can run once the screen has closed.
    list.dispose();

    expect(await list.loadMore(), isTrue);
    expect(server.asked, [0]);
  });

  test('the rows cannot be changed from outside', () async {
    final first = list.reload();
    server.answer(0, [1], page: 0, totalPages: 1);
    await first;

    // Only reload and loadMore change them, and they tell the listeners.
    expect(() => list.items.add(2), throwsUnsupportedError);
  });

  test('tells its listeners at each change', () async {
    var told = 0;
    list.addListener(() => told++);

    final first = list.reload();
    server.answer(0, [1], page: 0, totalPages: 2);
    await first;
    expect(told, 1);

    final more = list.loadMore();
    expect(told, 2); // loadingMore went on: the button disables
    server.answer(1, [2], page: 1, totalPages: 2);
    await more;
    expect(told, 3);
  });

  test('a page that arrives after dispose is ignored, without an error', () async {
    final first = list.reload();
    list.dispose(); // the screen closed while the page was on its way

    // notifyListeners after dispose would throw a FlutterError here.
    server.answer(0, [1], page: 0, totalPages: 1);
    await first;

    final second = PagedList<int>(fetch: server.fetch, idOf: (n) => n);
    final firstPage = second.reload();
    server.answer(1, [1], page: 0, totalPages: 2);
    await firstPage;
    final more = second.loadMore();
    second.dispose();
    server.fail(2);
    await more; // a failure after dispose must not throw either
  });
}
