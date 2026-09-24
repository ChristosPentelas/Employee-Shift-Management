import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_model.dart';

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
  AuthSession? build() => null; // the app starts logged out

  void logIn(User user, String token) {
    state = AuthSession(user: user, token: token);
  }

  void logOut() {
    state = null;
  }
}

final authProvider =
    NotifierProvider<AuthNotifier, AuthSession?>(AuthNotifier.new);

/// Whether the logged-in user is a supervisor; false when logged out.
///
/// A derived provider: it recomputes whenever authProvider changes, and the
/// screens that watch it rebuild only when the answer itself changes.
final isSupervisorProvider = Provider<bool>((ref) {
  return ref.watch(authProvider)?.user.role.toUpperCase() == 'SUPERVISOR';
});
