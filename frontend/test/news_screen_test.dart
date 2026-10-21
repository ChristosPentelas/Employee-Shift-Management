// F29: one news post without an author used to replace the whole news list
// with "Σφάλμα: type 'Null' is not a subtype of ...", for every user.

import 'dart:async';
import 'dart:convert';

import 'package:employee_shift_management_ui/models/user_model.dart';
import 'package:employee_shift_management_ui/screens/news_screen.dart';
import 'package:employee_shift_management_ui/services/api_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'helpers/app_scope.dart';

void main() {
  testWidgets('a post without an author is listed as from an unknown author',
      (WidgetTester tester) async {
    final network = MockClient((request) async => http.Response(
          '{"content": [{"id": 1, "title": "Απογραφή", "description": "Την Παρασκευή",'
          ' "type": "ANNOUNCEMENT", "createdAt": "2026-09-25T10:00:00",'
          ' "author": null, "deadline": null, "targetValue": null}],'
          ' "page": 0, "size": 20, "totalElements": 1, "totalPages": 1}',
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ));
    final container = testContainer(
      user: User(id: 7, name: 'Worker', email: 'worker@example.com', role: 'EMPLOYEE'),
      overrides: [networkClientProvider.overrideWithValue(network)],
    );

    await tester.pumpWidget(withAppState(container, MaterialApp(home: NewsScreen())));
    await tester.pumpAndSettle();

    expect(find.text('Απογραφή'), findsOneWidget);
    expect(find.text('Από: Άγνωστος'), findsOneWidget);
    expect(find.textContaining('Σφάλμα'), findsNothing);
  });

  // F25: a dialog can close on its own - a tap outside it - while its request
  // is on its way. Before the fix the reply then popped through the closed
  // dialog's context and threw; and skipping everything instead would leave
  // the saved post off the list.
  testWidgets('a post saved after its dialog was closed still refreshes the list',
      (WidgetTester tester) async {
    final postReply = Completer<http.Response>();
    var listCalls = 0;
    final network = MockClient((request) {
      if (request.method == 'POST') return postReply.future;
      listCalls++;
      return Future.value(http.Response(
          '{"content":[],"page":0,"size":20,"totalElements":0,"totalPages":0}', 200));
    });
    final container = testContainer(
      user: User(id: 9, name: 'Boss', email: 'boss@example.com', role: 'SUPERVISOR'),
      overrides: [networkClientProvider.overrideWithValue(network)],
    );

    await tester.pumpWidget(withAppState(container, MaterialApp(home: NewsScreen())));
    await tester.pumpAndSettle();
    // Four lists since B26 step 26b2b, one per tab, each loaded on opening.
    expect(listCalls, 4);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Τίτλος'), 'Inventory');
    await tester.tap(find.text('Δημοσίευση'));
    await tester.pump();

    // Close the dialog by tapping outside it (the barrier) mid-request.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);

    postReply.complete(http.Response('{}', 201));
    await tester.pumpAndSettle();

    expect(listCalls, 8, reason: 'every tab reloads although the dialog is gone');
  });

  // B26: the tabs used to filter the first 20 posts on the phone, so the
  // Goals tab could say "no entries" while older goals were on page 2. Now
  // each tab pages through its own list from the server.
  group('one list per tab', () {
    final worker =
        User(id: 7, name: 'Worker', email: 'worker@example.com', role: 'EMPLOYEE');
    final boss =
        User(id: 9, name: 'Boss', email: 'boss@example.com', role: 'SUPERVISOR');
    const all = '/api/v1/news';
    const goals = '/api/v1/news/type/GOAL';
    const everyList = [
      '$all 0',
      '/api/v1/news/type/ANNOUNCEMENT 0',
      '$goals 0',
      '/api/v1/news/type/TASK 0',
    ];

    /// One page of posts with these [ids], titled "Post <id>".
    http.Response newsPage(int page, int totalPages, List<int> ids,
            {String type = 'ANNOUNCEMENT'}) =>
        http.Response(
            jsonEncode({
              'content': [
                for (final id in ids)
                  {
                    'id': id,
                    'title': 'Post $id',
                    'description': 'About $id',
                    'type': type,
                    'createdAt': '2026-10-01T09:00:00',
                    'author': null,
                    'deadline': null,
                    'targetValue': null,
                  }
              ],
              'page': page,
              'size': 20,
              'totalElements': ids.length,
              'totalPages': totalPages,
            }),
            200);

    /// Opens the news screen as [user]. [answer] replies to each GET, given
    /// its path and ?page=. Returns every GET as "<path> <page>", in order.
    Future<List<String>> openNews(WidgetTester tester, User user,
        http.Response Function(String path, String? page) answer) async {
      final asked = <String>[];
      final network = MockClient((request) async {
        if (request.method == 'POST') return http.Response('{}', 201);
        if (request.method == 'DELETE') return http.Response('', 204);
        final page = request.url.queryParameters['page'];
        asked.add('${request.url.path} $page');
        return answer(request.url.path, page);
      });
      final container = testContainer(
          user: user, overrides: [networkClientProvider.overrideWithValue(network)]);
      await tester.pumpWidget(withAppState(container, MaterialApp(home: NewsScreen())));
      await tester.pumpAndSettle();
      return asked;
    }

    Finder loadMore() => find.text('Φόρτωση παλαιότερων');

    Future<void> openTab(WidgetTester tester, String label) async {
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }

    testWidgets('opening asks each tab for its own list',
        (WidgetTester tester) async {
      final asked = await openNews(tester, worker, (_, __) => newsPage(0, 0, []));

      expect(asked, unorderedEquals(everyList));
    });

    testWidgets('the Goals tab shows the goals sent for it, not a filter of "all"',
        (WidgetTester tester) async {
      // The newest 20 posts are all announcements; goal 9 is older.
      await openNews(tester, worker, (path, _) => path == goals
          ? newsPage(0, 1, [9], type: 'GOAL')
          : newsPage(0, 2, [1]));

      await openTab(tester, 'Στόχοι');

      expect(find.text('Post 9'), findsOneWidget);
      expect(find.text('Καμία εγγραφή σε αυτή την κατηγορία.'), findsNothing);
    });

    testWidgets('each tab loads more from its own list only',
        (WidgetTester tester) async {
      final asked = await openNews(tester, worker, (path, page) {
        if (path == all) return page == '0' ? newsPage(0, 2, [1]) : newsPage(1, 2, [2]);
        if (path == goals) {
          return page == '0'
              ? newsPage(0, 2, [9], type: 'GOAL')
              : newsPage(1, 2, [8], type: 'GOAL');
        }
        return newsPage(0, 0, []);
      });

      await tester.tap(loadMore());
      await tester.pumpAndSettle();
      expect(asked.last, '$all 1');
      expect(find.text('Post 2'), findsOneWidget);

      await openTab(tester, 'Στόχοι');
      await tester.tap(loadMore());
      await tester.pumpAndSettle();

      expect(asked.last, '$goals 1');
      expect(find.text('Post 8'), findsOneWidget);
      expect(asked.where((a) => a.endsWith(' 1')), hasLength(2));
    });

    testWidgets('a page that fails to load keeps the posts and says so',
        (WidgetTester tester) async {
      await openNews(tester, worker, (path, page) {
        if (path != all) return newsPage(0, 0, []);
        return page == '0' ? newsPage(0, 2, [1]) : http.Response('', 500);
      });

      await tester.tap(loadMore());
      await tester.pumpAndSettle();

      expect(find.text('Post 1'), findsOneWidget);
      expect(find.text('Δεν ήταν δυνατή η φόρτωση. Δοκιμάστε ξανά.'), findsOneWidget);
      expect(loadMore(), findsOneWidget);
    });

    testWidgets('posting reloads every tab from page 0',
        (WidgetTester tester) async {
      final asked = await openNews(tester, boss, (path, page) => path == all
          ? (page == '0' ? newsPage(0, 2, [1]) : newsPage(1, 2, [2]))
          : newsPage(0, 0, []));
      await tester.tap(loadMore());
      await tester.pumpAndSettle();
      asked.clear();

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Τίτλος'), 'Inventory');
      await tester.tap(find.text('Δημοσίευση'));
      await tester.pumpAndSettle();

      // A new post belongs in "all" and in its own type's tab.
      expect(asked, unorderedEquals(everyList));
      expect(find.text('Post 2'), findsNothing); // back to page 0
    });

    testWidgets('deleting reloads every tab from page 0',
        (WidgetTester tester) async {
      final asked = await openNews(tester, boss, (path, _) =>
          path == all ? newsPage(0, 1, [1]) : newsPage(0, 0, []));
      asked.clear();

      await tester.tap(find.byIcon(Icons.delete));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Διαγραφή')); // the dialog's confirm button
      await tester.pumpAndSettle();

      expect(asked, unorderedEquals(everyList));
    });

    testWidgets('a tab keeps its loaded posts and its place after switching away',
        (WidgetTester tester) async {
      await openNews(tester, worker, (path, page) {
        if (path != all) return newsPage(0, 0, []);
        return page == '0'
            ? newsPage(0, 2, [for (var i = 1; i <= 20; i++) i])
            : newsPage(1, 2, [21]);
      });
      // The list itself, not the TabBar or the TabBarView, which scroll too.
      Finder newsScroll() => find.descendant(
          of: find.byType(ListView), matching: find.byType(Scrollable));

      await tester.drag(find.byType(ListView), const Offset(0, -5000));
      await tester.pumpAndSettle();
      await tester.tap(loadMore());
      await tester.pumpAndSettle();
      final place = tester.state<ScrollableState>(newsScroll()).position.pixels;
      expect(place, greaterThan(0));

      await openTab(tester, 'Στόχοι');
      await openTab(tester, 'Ολα');

      // The rows live in the screen's lists, so they survive; the scroll
      // offset only survives through the list's PageStorageKey.
      expect(find.text('Post 21'), findsOneWidget);
      expect(tester.state<ScrollableState>(newsScroll()).position.pixels, place);
    });
  });
}
