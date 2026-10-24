// B26 step 26c2: the last row of a paged list loads the next page by itself
// once it is built - that is, once the user scrolls near the end - and offers
// to try again instead of retrying when a page fails.

import 'package:employee_shift_management_ui/models/page_model.dart';
import 'package:employee_shift_management_ui/state/paged_list.dart';
import 'package:employee_shift_management_ui/widgets/paged_list_footer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A fake server: page N answers with [pages][N], or throws while [failing]
/// holds that page number. Records every page asked for.
class FakePages {
  final List<List<int>> pages;
  final failing = <int>{};
  final asked = <int>[];

  FakePages(this.pages);

  Future<ListPage<int>> fetch(int page) async {
    asked.add(page);
    if (failing.contains(page)) throw Exception('no network');
    return ListPage(items: pages[page], page: page, totalPages: pages.length);
  }
}

/// A list drawn the way the screens draw theirs: the rows, then the footer
/// while the server has more. Each row is 100 px high.
Widget listOf(PagedList<int> list) => MaterialApp(
      home: Scaffold(
        body: ListenableBuilder(
          listenable: list,
          builder: (context, _) => ListView.builder(
            itemCount: list.items.length + (list.hasMore ? 1 : 0),
            itemBuilder: (context, index) => index == list.items.length
                ? PagedListFooter(list: list)
                : SizedBox(height: 100, child: Text('row ${list.items[index]}')),
          ),
        ),
      ),
    );

Future<PagedList<int>> show(WidgetTester tester, FakePages server) async {
  final list = PagedList<int>(fetch: server.fetch, idOf: (n) => n);
  await list.reload();
  await tester.pumpWidget(listOf(list));
  await tester.pumpAndSettle();
  return list;
}

void main() {
  testWidgets('a first page too short to scroll still loads the next one',
      (WidgetTester tester) async {
    // One row: the footer is on screen at once, and there is nothing to
    // scroll, so a scroll listener would never fire.
    final server = FakePages([[1], [2]]);
    await show(tester, server);

    expect(server.asked, [0, 1]);
    expect(find.text('row 2'), findsOneWidget);
    expect(find.byType(PagedListFooter), findsNothing); // that was the last page
  });

  testWidgets('a footer below the screen waits until it is scrolled to',
      (WidgetTester tester) async {
    // 20 rows of 100 px: far more than the 600 px test screen.
    final server = FakePages([
      [for (var i = 1; i <= 20; i++) i],
      [21],
    ]);
    await show(tester, server);
    expect(server.asked, [0], reason: 'nobody has scrolled down yet');

    await tester.drag(find.byType(ListView), const Offset(0, -3000));
    await tester.pumpAndSettle();

    expect(server.asked, [0, 1]);
    expect(find.text('row 21'), findsOneWidget);
  });

  testWidgets('after a failure it offers to try again, and asks nothing by itself',
      (WidgetTester tester) async {
    final server = FakePages([[1], [2]])..failing.add(1);
    await show(tester, server);

    expect(find.text('Δοκιμάστε ξανά'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    // Frames go by - rebuilds, the clock - and no request is retried on its own.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(server.asked, [0, 1]);

    server.failing.clear();
    await tester.tap(find.text('Δοκιμάστε ξανά'));
    await tester.pumpAndSettle();

    expect(server.asked, [0, 1, 1]);
    expect(find.text('row 2'), findsOneWidget);
  });
}
