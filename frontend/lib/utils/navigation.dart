import 'package:flutter/material.dart';

// Let code outside the widget tree navigate and show messages. AuthClient has
// no BuildContext, so it cannot call Navigator.of(context). Both keys are
// attached to the MaterialApp in main.dart.
//
// They live here, not in main.dart, because main.dart imports the screens,
// which import ApiService, which would import main.dart again (a cycle).
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();
