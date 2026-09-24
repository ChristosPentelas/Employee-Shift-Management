// Saving the login so it survives a restart (F24 step 24d). The store runs
// for real against flutter_secure_storage's in-memory test double.

import 'package:employee_shift_management_ui/main.dart';
import 'package:employee_shift_management_ui/models/user_model.dart';
import 'package:employee_shift_management_ui/state/auth_session.dart';
import 'package:employee_shift_management_ui/state/session_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers/app_scope.dart';
import 'helpers/fake_jwt.dart';

User worker({String name = 'Worker'}) =>
    User(id: 7, name: name, email: 'worker@example.com', role: 'EMPLOYEE');

final now = DateTime.utc(2026, 9, 24, 12);
final validToken = fakeJwt(now.add(const Duration(hours: 8)));

SessionStore storeAt(DateTime time) =>
    SessionStore(const FlutterSecureStorage(), now: () => time);

/// Answers every write late, as a slow Keystore might.
class SlowWriteStorage extends FlutterSecureStorage {
  const SlowWriteStorage();

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    return super.write(key: key, value: value);
  }
}

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  group('SessionStore', () {
    test('a saved login loads back after a restart', () async {
      await storeAt(now).save(AuthSession(user: worker(), token: validToken));

      // A new store, as after closing and reopening the app.
      final loaded = await storeAt(now).load();

      expect(loaded!.token, validToken);
      expect(loaded.user.id, 7);
      expect(loaded.user.name, 'Worker');
    });

    test('nothing saved means nothing to restore', () async {
      expect(await storeAt(now).load(), isNull);
    });

    test('an expired login is not restored, and is forgotten', () async {
      final expired = fakeJwt(now.subtract(const Duration(minutes: 1)));
      await storeAt(now).save(AuthSession(user: worker(), token: expired));

      expect(await storeAt(now).load(), isNull);
      expect(await const FlutterSecureStorage().read(key: 'session'), isNull);
    });

    test('a token whose expiry cannot be read is not restored', () async {
      await storeAt(now).save(AuthSession(user: worker(), token: 'not-a-jwt'));

      expect(await storeAt(now).load(), isNull);
    });

    test('unreadable saved data is forgotten instead of crashing startup',
        () async {
      FlutterSecureStorage.setMockInitialValues({'session': '{broken'});

      expect(await storeAt(now).load(), isNull);
      expect(await const FlutterSecureStorage().read(key: 'session'), isNull);
    });

    test('a logout right after a login is not overtaken by the slower save',
        () async {
      final store = SessionStore(const SlowWriteStorage(), now: () => now);

      // Without the queue the delete finishes first and the late save puts
      // the login back: the next start would be logged in.
      await Future.wait([
        store.save(AuthSession(user: worker(), token: validToken)),
        store.clear(),
      ]);

      expect(await const FlutterSecureStorage().read(key: 'session'), isNull);
    });
  });

  group('the session follows the store', () {
    test('logIn, updateUser and logOut are all saved', () async {
      final container = testContainer();
      final auth = container.read(authProvider.notifier);

      auth.logIn(worker(), validToken);
      await pumpEventQueue();
      expect((await storeAt(now).load())!.user.name, 'Worker');

      auth.updateUser(worker(name: 'Renamed'));
      await pumpEventQueue();
      expect((await storeAt(now).load())!.user.name, 'Renamed');

      auth.logOut();
      await pumpEventQueue();
      expect(await storeAt(now).load(), isNull);
    });

    test('a restored login is the session the app starts with', () {
      final restored = AuthSession(user: worker(), token: validToken);
      final container = testContainer(
          overrides: [restoredSessionProvider.overrideWithValue(restored)]);

      expect(container.read(authProvider), same(restored));
    });
  });

  testWidgets('a restored login opens on the dashboard',
      (WidgetTester tester) async {
    final container = testContainer(user: worker(), token: validToken);

    await tester.pumpWidget(withAppState(container, const MyApp(startLoggedIn: true)));

    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Email'), findsNothing);
  });
}
