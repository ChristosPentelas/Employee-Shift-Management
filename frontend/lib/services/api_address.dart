// Refuses to start a release build that would talk to the backend over plain
// HTTP (B14).
//
// Every request carries the login token, and the login request carries the
// password. Over http:// anyone on the same Wi-Fi can read both. That is
// acceptable between the emulator and your own PC, so debug and profile
// builds may use http://; a release build is meant for real users on real
// networks, so it must use https://.
//
// isRelease is a parameter, not kReleaseMode inside, so a test can check the
// release rule without building a release app.
void checkApiAddress(String url, {required bool isRelease}) {
  if (isRelease && !url.startsWith('https://')) {
    throw StateError(
      'A release build must reach the backend over https://, but '
      'API_BASE_URL is "$url". Pass an https:// address with '
      '--dart-define=API_BASE_URL=..., or build with --debug or --profile '
      'to test against a backend on your own network.',
    );
  }
}
