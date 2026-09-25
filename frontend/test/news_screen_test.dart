// F29: one news post without an author used to replace the whole news list
// with "Σφάλμα: type 'Null' is not a subtype of ...", for every user.

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
}
