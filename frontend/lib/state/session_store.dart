import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/user_model.dart';
import 'auth_session.dart';

/// Keeps the login on the phone between app starts (F24), so closing the app
/// no longer means logging in again.
///
/// Secure storage, not shared_preferences: the token works like a password
/// until it expires, and shared_preferences keeps plain text in the app's
/// settings file. Secure storage encrypts it with a key held by the Android
/// Keystore / iOS Keychain.
class SessionStore {
  static const _key = 'session';

  final FlutterSecureStorage _storage;
  final DateTime Function() _now;

  // The last write asked for; the next one waits for it (see _queue).
  Future<void> _lastWrite = Future.value();

  /// [now] lets tests choose the time; the app uses the clock.
  SessionStore(this._storage, {DateTime Function()? now})
      : _now = now ?? DateTime.now;

  /// The saved login, or null if there is none, it has expired, or it cannot
  /// be read. Never throws: at worst the user logs in again.
  Future<AuthSession?> load() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw == null) return null;

      final json = jsonDecode(raw) as Map<String, dynamic>;
      final session = AuthSession(
        user: User.fromJson(json['user'] as Map<String, dynamic>),
        token: json['token'] as String,
      );

      final expiry = tokenExpiry(session.token);
      if (expiry == null || !_now().isBefore(expiry)) {
        // Certainly over (or no expiry to go by): opening the dashboard would
        // only end in a 401 on the first request.
        await clear();
        return null;
      }
      return session;
    } catch (_) {
      // Unreadable, e.g. an Android backup restored onto a new phone, whose
      // Keystore cannot decrypt it. Forget it rather than crash at startup.
      await clear();
      return null;
    }
  }

  Future<void> save(AuthSession session) => _queue(() => _storage.write(
        key: _key,
        value: jsonEncode({'user': session.user.toJson(), 'token': session.token}),
      ));

  Future<void> clear() => _queue(() => _storage.delete(key: _key));

  // Writes are asynchronous. Logging in and straight out again starts a save
  // and then a delete; if the delete finished first, the save would bring the
  // login back on the next start. Chaining makes them finish in the order
  // they were asked for.
  Future<void> _queue(Future<void> Function() write) {
    // A failed write must not block the ones after it. The session still
    // works in memory; only the next start would not find it.
    return _lastWrite = _lastWrite.then((_) => write()).catchError((Object _) {});
  }
}

/// When [jwt] expires, from its `exp` claim, or null if it cannot be read.
///
/// This reads the token, it does not verify it: only the server can check the
/// signature. It is only used to avoid restoring a login that is surely over.
DateTime? tokenExpiry(String jwt) {
  final parts = jwt.split('.');
  if (parts.length != 3) return null;
  try {
    final payload =
        jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
    final exp = payload['exp'];
    if (exp is! int) return null;
    return DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true);
  } catch (_) {
    return null;
  }
}

final sessionStoreProvider = Provider<SessionStore>((ref) {
  return SessionStore(const FlutterSecureStorage());
});
