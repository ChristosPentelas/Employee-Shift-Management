import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'utils/navigation.dart';

void main() {
  runApp(MyApp());
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


