import 'package:flutter/material.dart';

// Let code outside the widget tree navigate and show messages. AuthClient has
// no BuildContext, so it cannot call Navigator.of(context). Both keys are
// attached to the MaterialApp in main.dart.
//
// They live here, not in main.dart, because main.dart imports the screens,
// which import ApiService, which would import main.dart again (a cycle).
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

/// The one way back to the login screen (B38): both logout buttons and an
/// expired token use it. Through the '/login' route main.dart registers, so
/// nothing here imports LoginScreen. Every other screen is removed, so
/// "back" cannot return to a page that needs the session.
///
/// Navigation only: each caller clears the session its own way first (a
/// logout button always, an expired token only if it is still the current
/// one).
extension ReturnToLogin on NavigatorState {
  void returnToLogin() => pushNamedAndRemoveUntil('/login', (route) => false);
}
