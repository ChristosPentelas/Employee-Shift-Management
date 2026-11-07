// B53: each dashboard card used to find its screen by comparing its own Greek
// label with a string (`if (title == "Νέα")`). Now every card is given the
// screen it opens. This pins which card opens which screen, so a card that
// opens the wrong screen, or nothing, fails here.

import 'package:employee_shift_management_ui/models/user_model.dart';
import 'package:employee_shift_management_ui/screens/employee_list_screen.dart';
import 'package:employee_shift_management_ui/screens/home_screen.dart';
import 'package:employee_shift_management_ui/screens/leave_requests_screen.dart';
import 'package:employee_shift_management_ui/screens/messages_list_screen.dart';
import 'package:employee_shift_management_ui/screens/news_screen.dart';
import 'package:employee_shift_management_ui/screens/profile_screen.dart';
import 'package:employee_shift_management_ui/screens/shifts_screen.dart';
import 'package:employee_shift_management_ui/services/api_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'helpers/app_scope.dart';

void main() {
  // Card label -> the screen it must open.
  const cards = {
    'Υπάλληλοι': EmployeeListScreen,
    'Βάρδιες': ShiftsScreen,
    'Μηνύματα': MessagesListScreen,
    'Αιτήματα Αδείας': LeaveRequestsScreen,
    'Νέα': NewsScreen,
    'Προφίλ': ProfileScreen,
  };

  for (final MapEntry(key: label, value: screen) in cards.entries) {
    testWidgets('the "$label" card opens $screen', (WidgetTester tester) async {
      // Every screen loads something when it opens; an empty page is enough,
      // since only which screen opened is checked.
      final network = MockClient((request) async => http.Response(
          '{"content":[],"page":0,"size":20,"totalElements":0,"totalPages":0}',
          200));
      final container = testContainer(
        user: User(id: 9, name: 'Boss', email: 'boss@example.com', role: 'SUPERVISOR'),
        overrides: [networkClientProvider.overrideWithValue(network)],
      );

      // The default 800x600 test window shows only the first row and a half
      // of square cards, and the grid does not build the rest. A tall window
      // shows all six, so every card can be tapped where it is.
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
          withAppState(container, const MaterialApp(home: HomeScreen())));
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();

      expect(find.byType(screen), findsOneWidget);
      expect(find.byType(HomeScreen, skipOffstage: true), findsNothing,
          reason: 'the card must open a screen on top of the dashboard');
    });
  }
}
