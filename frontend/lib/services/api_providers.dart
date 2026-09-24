import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../state/auth_session.dart';
import 'api_service.dart';
import 'auth_client.dart';
import 'session_expiry.dart';

// How the network layer is built, in one place. Each provider creates its
// object once per ProviderScope, so the whole app shares one connection pool
// instead of one per screen. Tests override networkClientProvider with a
// MockClient and keep everything above it real.

/// Does the real network work. Nothing else in the app creates an http.Client.
final networkClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

/// Adds the session's token to every request and ends the session when the
/// server rejects that token.
final authClientProvider = Provider<http.Client>((ref) {
  return AuthClient(
    inner: ref.watch(networkClientProvider),
    // read, not watch: the token is looked up per request, so a new login
    // must not rebuild the client (and with it every ApiService).
    token: () => ref.read(authProvider)?.token,
    onTokenRejected: (sentToken) =>
        handleRejectedToken(ref.read(authProvider.notifier), sentToken),
  );
});

final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService(client: ref.watch(authClientProvider));
});
