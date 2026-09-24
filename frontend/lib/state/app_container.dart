import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The container that holds the app's providers, such as authProvider.
///
/// main.dart hands this same container to the widget tree, so screens (using
/// `ref`) and code outside any screen (the Session bridge) see one state, not
/// two copies. Only session.dart should read it; screens and services move to
/// `ref` in F24 steps 24b and 24c.
final appContainer = ProviderContainer();
