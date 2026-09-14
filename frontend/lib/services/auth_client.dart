import 'package:http/http.dart' as http;

import '../utils/session.dart';
import 'session_expiry.dart';

/// An http.Client that adds the login token to every request it sends, and
/// reports when the server rejects that token.
///
/// It wraps another client and changes nothing else (the decorator pattern),
/// so ApiService keeps calling get/post/put/delete as before, and a request
/// method added later cannot forget the header.
///
/// Never print headers here: whoever sees the token can act as that user.
class AuthClient extends http.BaseClient {
  final http.Client _inner;
  final String? Function() _token;
  final void Function(String sentToken) _onTokenRejected;

  /// [inner] does the real network work; [token] says which token to send;
  /// [onTokenRejected] runs when the server answers 401 to that token.
  /// All three have app defaults, and tests replace them with fakes.
  AuthClient({
    http.Client? inner,
    String? Function()? token,
    void Function(String sentToken)? onTokenRejected,
  })  : _inner = inner ?? http.Client(),
        _token = token ?? (() => Session.token),
        _onTokenRejected = onTokenRejected ?? handleRejectedToken;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final token = _token();
    // No token before login: send nothing rather than "Bearer null".
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    final response = await _inner.send(request);

    // A 401 can only mean "your token was rejected" if a token was sent. A 401
    // without one is a failed login (wrong password), which the login screen
    // handles itself.
    if (response.statusCode == 401 && token != null) {
      _onTokenRejected(token);
    }

    // The caller still gets exactly what the server said.
    return response;
  }

  @override
  void close() {
    _inner.close();
  }
}
