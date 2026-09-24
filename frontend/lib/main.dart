import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/login_screen.dart';
import 'utils/navigation.dart';

void main() {
  // Holds every provider's state (the session, the network client) for the
  // whole app. Nothing outside the widget tree reads state any more (F24).
  runApp(ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Employee Management',
      theme: ThemeData(primarySwatch: Colors.blue),
      // Used by handleRejectedToken to return to login from outside any screen.
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: scaffoldMessengerKey,
      home: LoginScreen(),
      // A named route, so the network layer can go to login without
      // importing the LoginScreen widget.
      routes: {
        '/login': (context) => LoginScreen(),
      },
    );
  }
}


