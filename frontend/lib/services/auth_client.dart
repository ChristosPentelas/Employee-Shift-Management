import 'package:http/http.dart' as http;


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
  ///
  /// All three are required: AuthClient knows nothing about the app's state,
  /// it is told. authClientProvider (api_providers.dart) connects it to the
  /// session; tests hand it fakes.
  AuthClient({
    required http.Client inner,
    required String? Function() token,
    required void Function(String sentToken) onTokenRejected,
  })  : _inner = inner,
        _token = token,
        _onTokenRejected = onTokenRejected;

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
