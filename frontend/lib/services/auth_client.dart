import 'package:http/http.dart' as http;

import '../utils/session.dart';

/// An http.Client that adds the login token to every request it sends.
///
/// It wraps another client and changes nothing else (the decorator pattern),
/// so ApiService keeps calling get/post/put/delete as before, and a request
/// method added later cannot forget the header.
///
/// Never print headers here: whoever sees the token can act as that user.
class AuthClient extends http.BaseClient {
  final http.Client _inner;
  final String? Function() _token;

  /// [inner] does the real network work; [token] says which token to send.
  /// Both have app defaults, and tests replace them with fakes.
  AuthClient({http.Client? inner, String? Function()? token})
      : _inner = inner ?? http.Client(),
        _token = token ?? (() => Session.token);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    final token = _token();
    // No token before login: send nothing rather than "Bearer null".
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
  }
}
