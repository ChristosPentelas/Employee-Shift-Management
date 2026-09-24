import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_model.dart';
import 'session_store.dart';

/// Who is logged in, and the token that proves it.
///
/// Both fields are final and required, so a user without a token (or a token
/// without a user) cannot exist. To change the session you replace the whole
/// object through [AuthNotifier]; nobody edits it in place.
class AuthSession {
  final User user;
  final String token;

  const AuthSession({required this.user, required this.token});
}

/// The only code that changes the session. `null` means logged out.
///
/// Every change goes through `state = ...`, which tells whoever is listening,
/// so screens can rebuild when the user logs in or out (F24 step 24b).
class AuthNotifier extends Notifier<AuthSession?> {
  @override
  AuthSession? build() {
    final store = ref.read(sessionStoreProvider);

    // Every change is copied to the phone's storage here, in one place, so a
    // method added later (or a path that skips logIn/logOut) cannot forget
    // to save. The observer pattern: the notifier changes state, the store
    // follows.
    listenSelf((previous, next) {
      if (next == null) {
        store.clear();
      } else {
        store.save(next);
      }
    });

    // What main.dart loaded from storage, or null: log in again.
    return ref.read(restoredSessionProvider);
  }

  void logIn(User user, String token) {
    state = AuthSession(user: user, token: token);
  }

  /// Swaps in the saved profile, keeping the token. The user is replaced, not
  /// edited, so everyone watching authProvider rebuilds with the new values.
  void updateUser(User user) {
    final current = state;
    if (current == null) return; // logged out meanwhile: nothing to update
    state = AuthSession(user: user, token: current.token);
  }

  void logOut() {
    state = null;
  }

  /// Logs out only if [token] is still the session's token, and says whether
  /// it did. A late 401 for a token from an earlier login must not end the
  /// newer session (see handleRejectedToken).
  bool logOutIfCurrent(String token) {
    if (state?.token != token) return false;
    state = null;
    return true;
  }
}

final authProvider =
    NotifierProvider<AuthNotifier, AuthSession?>(AuthNotifier.new);

/// The login main.dart restored from storage before the first screen, or
/// null. Loading is asynchronous and happens once, before runApp, so the
/// session itself can stay a plain value instead of "still loading" that
/// every screen would have to handle.
final restoredSessionProvider = Provider<AuthSession?>((ref) => null);

/// Whether the logged-in user is a supervisor; false when logged out.
///
/// A derived provider: it recomputes whenever authProvider changes, and the
/// screens that watch it rebuild only when the answer itself changes.
final isSupervisorProvider = Provider<bool>((ref) {
  return ref.watch(authProvider)?.user.role.toUpperCase() == 'SUPERVISOR';
});
