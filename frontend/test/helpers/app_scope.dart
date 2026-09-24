import 'package:employee_shift_management_ui/state/app_container.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Gives [child] the app's providers, as main.dart does.
///
/// It uses the app's own container on purpose: until F24 step 24c the services
/// still read the session through `Session`, which reads that container, so a
/// screen and the service it calls must share it. Tests set it up with
/// `Session.logIn` and reset it with `Session.clear`.
Widget withAppState(Widget child) =>
    UncontrolledProviderScope(container: appContainer, child: child);
