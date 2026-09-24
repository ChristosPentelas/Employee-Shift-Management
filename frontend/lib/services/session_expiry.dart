import 'package:flutter/material.dart';

import '../state/auth_session.dart';
import '../utils/navigation.dart';

/// Called by AuthClient when the server rejects the token a request carried,
/// usually because it expired (tokens live 8 hours). authClientProvider passes
/// the session's [auth] notifier.
///
/// [sentToken] is the token that request sent. Only the token we still hold
/// counts: the chat polls every 3 seconds, so several requests can fail at
/// once, and a slow reply to an old request can arrive after the user has
/// already logged in again. Without this check that late reply would log the
/// new session out (a race condition).
void handleRejectedToken(AuthNotifier auth, String sentToken) {
  if (!auth.logOutIfCurrent(sentToken)) {
    return;
  }

  // Remove every open screen, so "back" cannot return to a page that needs
  // the session we just cleared.
  navigatorKey.currentState
      ?.pushNamedAndRemoveUntil('/login', (route) => false);

  scaffoldMessengerKey.currentState?.showSnackBar(
    const SnackBar(content: Text("Η σύνδεση έληξε, συνδεθείτε ξανά")),
  );
}
