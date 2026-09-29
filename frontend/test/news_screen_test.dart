// F29: one news post without an author used to replace the whole news list
// with "Σφάλμα: type 'Null' is not a subtype of ...", for every user.

import 'dart:async';

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
          ' "author": null, "deadline": null, "targetValue": null}]}',
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
      return Future.value(http.Response('{"content": []}', 200));
    });
    final container = testContainer(
      user: User(id: 9, name: 'Boss', email: 'boss@example.com', role: 'SUPERVISOR'),
      overrides: [networkClientProvider.overrideWithValue(network)],
    );

    await tester.pumpWidget(withAppState(container, MaterialApp(home: NewsScreen())));
    await tester.pumpAndSettle();
    expect(listCalls, 1);

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

    expect(listCalls, 2, reason: 'the list reloads although the dialog is gone');
  });
}
