import 'package:employee_shift_management_ui/models/user_model.dart';
import 'package:employee_shift_management_ui/state/auth_session.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

/// A fresh set of providers for one test, disposed when the test ends, so no
/// login leaks from one test into the next. Pass [user] to start logged in,
/// and [overrides] to replace a provider (e.g. the network) with a fake.
ProviderContainer testContainer({
  User? user,
  String token = 'test-token',
  List<Override> overrides = const [],
}) {
  final container = ProviderContainer.test(overrides: overrides);
  if (user != null) {
    container.read(authProvider.notifier).logIn(user, token);
  }
  return container;
}

/// Gives [child] the providers in [container], as ProviderScope does in
/// main.dart. The test keeps [container] to set up and check the session.
Widget withAppState(ProviderContainer container, Widget child) =>
    UncontrolledProviderScope(container: container, child: child);
