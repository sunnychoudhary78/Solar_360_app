import 'package:flutter/material.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Set by [Root] so logout can recreate [ProviderScope].
VoidCallback? appRestartCallback;

void triggerAppRestart() {
  appRestartCallback?.call();
}
