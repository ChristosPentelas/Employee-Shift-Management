import 'package:employee_shift_management_ui/models/user_model.dart';
import 'package:employee_shift_management_ui/utils/session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('clear forgets both the user and the token', () {
    Session.currentUser =
        User(id: 1, name: 'Worker', email: 'worker@example.com', role: 'EMPLOYEE');
    Session.token = 'abc';

    Session.clear();

    expect(Session.currentUser, isNull);
    expect(Session.token, isNull);
  });
}
