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

    await more;
    expect(server.asked, [0, 1]);
    expect(list.items, [1, 2]);
    expect(list.loadMoreFailed, isFalse);
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
    await list.loadMore();
    // Ignored, not failed: the footer must not offer to try again.
    expect(list.loadMoreFailed, isFalse);
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
    await more;

    expect(list.loadMoreFailed, isTrue);
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

    await list.loadMore();
    expect(server.asked, [0]);
  });

  // B26 step 26d: the chat polls page 0 while older pages may be loaded, so
  // the poll must add what is new without dropping them, as reload would.
  group('refresh', () {
    test('puts the new rows in front and keeps the older pages', () async {
      final first = list.reload();
      server.answer(0, [5, 4], page: 0, totalPages: 2);
      await first;
      final more = list.loadMore();
      server.answer(1, [3, 2], page: 1, totalPages: 2);
      await more;

      // Message 6 arrived; 5 is still on page 0, so it is a repeat.
      final refreshed = list.refresh();
      server.answer(2, [6, 5], page: 0, totalPages: 3);
      final fresh = await refreshed;

      expect(server.asked, [0, 1, 0]);
      expect(list.items, [6, 5, 4, 3, 2]);
      expect(list.hasMore, isTrue, reason: 'the total grew to 3 pages');
      expect(fresh!.items, [6, 5], reason: 'the page itself, for the caller');
    });

    test('a fresh copy of a row replaces the one on screen', () async {
      var state = 'unread';
      final rows = PagedList<({int id, String state})>(
        fetch: (page) async =>
            ListPage(items: [(id: 1, state: state)], page: 0, totalPages: 1),
        idOf: (row) => row.id,
      );
      await rows.refresh();

      state = 'read';
      await rows.refresh();

      // Not the old copy kept because its id was already there.
      expect(rows.items, [(id: 1, state: 'read')]);
    });

    test('the first refresh is the first load', () async {
      expect(list.loading, isTrue);

      final refreshed = list.refresh();
      server.answer(0, [1], page: 0, totalPages: 2);
      await refreshed;

      expect(list.loading, isFalse);
      expect(list.items, [1]);
      expect(list.hasMore, isTrue);
    });

    test('a failed refresh with rows on screen changes nothing and says nothing',
        () async {
      final first = list.reload();
      server.answer(0, [1], page: 0, totalPages: 1);
      await first;
      var told = 0;
      list.addListener(() => told++);

      final refreshed = list.refresh();
      server.fail(1);

      expect(await refreshed, isNull);
      expect(list.items, [1]);
      expect(list.error, isNull, reason: 'the next poll tries again');
      expect(told, 0);
    });

    test('a failed refresh with nothing loaded yet is an error', () async {
      final refreshed = list.refresh();
      server.fail(0);
      await refreshed;

      expect(list.loading, isFalse);
      expect(list.error, isNotNull);
    });

    test('does not cancel an older page on its way', () async {
      final first = list.reload();
      server.answer(0, [20, 19], page: 0, totalPages: 2);
      await first;

      final more = list.loadMore(); // request 1
      final refreshed = list.refresh(); // request 2
      server.answer(2, [21, 20], page: 0, totalPages: 2);
      await refreshed;
      expect(list.loadingMore, isTrue, reason: 'unlike reload');
      server.answer(1, [18], page: 1, totalPages: 2);
      await more;

      expect(list.items, [21, 20, 19, 18]);
    });

    test('a refresh that a reload overtook is dropped', () async {
      final refreshed = list.refresh(); // request 0
      final again = list.reload(); // request 1
      server.answer(1, [10], page: 0, totalPages: 1);
      await again;
      server.answer(0, [99], page: 0, totalPages: 1); // arrives late
      await refreshed;

      expect(list.items, [10]);
    });

    test('after dispose it asks nothing', () async {
      list.dispose();

      expect(await list.refresh(), isNull);
      expect(server.asked, isEmpty);
    });
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
