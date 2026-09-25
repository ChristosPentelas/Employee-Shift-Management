import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/api_address.dart';
import 'services/api_service.dart';
import 'state/auth_session.dart';
import 'state/session_store.dart';
import 'utils/navigation.dart';

Future<void> main() async {
  // Before anything else: a release build must not send the token over
  // plain HTTP (B14).
  checkApiAddress(ApiService.baseUrl, isRelease: kReleaseMode);

  // Plugins such as secure storage can be used before runApp only after this.
  WidgetsFlutterBinding.ensureInitialized();

  // Read the saved login before the first screen, so a returning user lands
  // on the dashboard instead of seeing the login page flash first.
  final store = SessionStore(const FlutterSecureStorage());
  final restored = await store.load();

  // Holds every provider's state (the session, the network client) for the
  // whole app. Nothing outside the widget tree reads state any more (F24).
  runApp(ProviderScope(
    overrides: [
      sessionStoreProvider.overrideWithValue(store),
      restoredSessionProvider.overrideWithValue(restored),
    ],
    child: MyApp(startLoggedIn: restored != null),
  ));
}

class MyApp extends StatelessWidget {
  /// Whether a saved login was restored; decides only the first screen.
  final bool startLoggedIn;

  const MyApp({super.key, this.startLoggedIn = false});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Employee Management',
      theme: ThemeData(primarySwatch: Colors.blue),
      // Used by handleRejectedToken to return to login from outside any screen.
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: scaffoldMessengerKey,
      home: startLoggedIn ? HomeScreen() : LoginScreen(),
      // A named route, so the network layer can go to login without
      // importing the LoginScreen widget.
      routes: {
        '/login': (context) => LoginScreen(),
      },
    );
  }
}


