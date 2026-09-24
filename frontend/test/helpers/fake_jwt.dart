import 'dart:convert';

/// A token shaped like the server's (header.payload.signature) that expires
/// at [expiresAt]. The signature is fake: the app never checks it, only the
/// server can.
String fakeJwt(DateTime expiresAt) {
  String part(Map<String, Object> json) =>
      base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  final exp = expiresAt.millisecondsSinceEpoch ~/ 1000;
  return '${part({'alg': 'none'})}.${part({'sub': '7', 'exp': exp})}.signature';
}
