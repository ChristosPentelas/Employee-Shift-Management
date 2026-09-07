import '../models/user_model.dart';

class Session {
  //here we store the logged in user
  static User? currentUser;

  static bool isSupervisor() {
    return currentUser?.role.toUpperCase() == 'SUPERVISOR';
  }
}