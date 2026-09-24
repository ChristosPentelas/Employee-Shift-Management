import '../models/user_model.dart';
import '../state/app_container.dart';
import '../state/auth_session.dart';

/// A temporary bridge to authProvider for code outside the widget tree, which
/// has no `ref`: ApiService, AuthClient and handleRejectedToken. Screens use
/// `ref` since F24 step 24b; the services follow in 24c. It stores nothing
/// itself; delete it once nothing uses it.
class Session {
  static AuthSession? get _current => appContainer.read(authProvider);

  static User? get currentUser => _current?.user;

  // The login token (JWT). AuthClient sends it with every request.
  // Kept in memory only, so closing the app logs the user out (see F24).
  static String? get token => _current?.token;

  // The user and the token arrive together, so they are set together.
  static void logIn(User user, String token) {
    appContainer.read(authProvider.notifier).logIn(user, token);
  }

  // Forgets the user and the token in one step: logged out means both gone.
  static void clear() {
    appContainer.read(authProvider.notifier).logOut();
  }
}
