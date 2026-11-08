// The supervisor's "new employee" screen (F1 step 5). Its first tests, added
// with B84 step 84g.

import 'package:employee_shift_management_ui/models/user_model.dart';
import 'package:employee_shift_management_ui/screens/register_screen.dart';
import 'package:employee_shift_management_ui/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'helpers/app_scope.dart';

void main() {
  final boss =
      User(id: 9, name: 'Boss', email: 'boss@example.com', role: 'SUPERVISOR');
  final create = find.widgetWithText(ElevatedButton, 'Δημιουργία Λογαριασμού');

  /// Opens the screen against [api] and fills in every field.
  Future<void> openAndFillIn(WidgetTester tester, ApiService api) async {
    await tester.pumpWidget(withAppState(testContainer(user: boss),
        MaterialApp(home: RegisterScreen(apiService: api))));
    await tester.enterText(find.widgetWithText(TextField, 'Ονομα'), 'New Worker');
    await tester.enterText(find.widgetWithText(TextField, 'Email'), 'new@example.com');
    await tester.enterText(find.widgetWithText(TextField, 'Κωδικός'), 'secret');
  }

  // B84 step 84g: registerUser now throws a lost network for the screen to
  // log. Passes on the old code too, which returned false; it guards the
  // screen's catch - without it the error escapes the `void` _register
  // uncaught, and the spinner never turns back into the button.
  testWidgets('an account that never reached the server says it failed and keeps the form',
      (WidgetTester tester) async {
    final api = ApiService(client: MockClient((_) async {
      throw http.ClientException('no network');
    }));
    await openAndFillIn(tester, api);

    await tester.tap(create);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Σφάλμα κατά την εγγραφή. Δοκιμάστε ξανά.'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(create, findsOneWidget, reason: 'it can be tried again');
    expect(find.text('New Worker'), findsOneWidget, reason: 'nothing typed is lost');
  });
}
