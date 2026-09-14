import '../models/user_model.dart';

class Session {
  //here we store the logged in user
  static User? currentUser;

  // The login token (JWT). AuthClient sends it with every request.
  // Kept in memory only, so closing the app logs the user out (see F24).
  static String? token;

  static bool isSupervisor() {
    return currentUser?.role.toUpperCase() == 'SUPERVISOR';
  }

  // Forgets everything about the logged-in user in one call. Clearing only the
  // user would leave the app looking logged out while its token still works.
  static void clear() {
    currentUser = null;
    token = null;
  }
}
