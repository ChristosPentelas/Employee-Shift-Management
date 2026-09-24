// Unit tests for authProvider. Each test gets its own ProviderContainer, so
// no state leaks from one test into the next (unlike a static field).

import 'package:employee_shift_management_ui/models/user_model.dart';
import 'package:employee_shift_management_ui/state/auth_session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers/app_scope.dart';

User worker() =>
    User(id: 7, name: 'Worker', email: 'worker@example.com', role: 'EMPLOYEE');

void main() {
  late ProviderContainer container;

  setUp(() => container = testContainer());

  test('the app starts logged out', () {
    expect(container.read(authProvider), isNull);
  });

  test('logIn keeps the user and the token together; logOut forgets both', () {
    final user = worker();

    container.read(authProvider.notifier).logIn(user, 'abc');
    final session = container.read(authProvider)!;
    expect(session.user, same(user));
    expect(session.token, 'abc');

    container.read(authProvider.notifier).logOut();
    expect(container.read(authProvider), isNull);
  });

  test('listeners hear about every login and logout', () {
    // This is what the static Session could not do: nothing was told when it
    // changed, so screens had to be repainted by hand.
    final heard = <String?>[];
    container.listen(authProvider, (_, next) => heard.add(next?.token));

    container.read(authProvider.notifier).logIn(worker(), 'abc');
    container.read(authProvider.notifier).logOut();

    expect(heard, ['abc', null]);
  });

  test('updateUser replaces the user, keeps the token and tells listeners', () {
    container.read(authProvider.notifier).logIn(worker(), 'abc');
    final heard = <String?>[];
    container.listen(authProvider, (_, next) => heard.add(next?.user.name));

    container.read(authProvider.notifier).updateUser(User(
        id: 7, name: 'Renamed', email: 'worker@example.com', role: 'EMPLOYEE'));

    expect(container.read(authProvider)!.token, 'abc');
    expect(heard, ['Renamed']);
  });

  test('updateUser after a logout does not log anyone back in', () {
    // A save can finish after the session expired.
    container.read(authProvider.notifier).updateUser(worker());

    expect(container.read(authProvider), isNull);
  });

  test('isSupervisorProvider follows whoever is logged in', () {
    expect(container.read(isSupervisorProvider), isFalse,
        reason: 'nobody is logged in');

    container.read(authProvider.notifier).logIn(
        User(id: 9, name: 'Boss', email: 'boss@example.com', role: 'supervisor'),
        'abc');
    expect(container.read(isSupervisorProvider), isTrue,
        reason: 'the role is compared without regard to case');

    container.read(authProvider.notifier).logIn(worker(), 'def');
    expect(container.read(isSupervisorProvider), isFalse);

    container.read(authProvider.notifier).logOut();
    expect(container.read(isSupervisorProvider), isFalse);
  });
}
