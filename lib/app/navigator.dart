import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Set by [Root] so logout can recreate [ProviderScope].
VoidCallback? appRestartCallback;

/// Recreates [ProviderScope] on the next frame so InheritedWidget dependents
/// are not still attached during dispose (`_dependents.isEmpty` assertion).
void triggerAppRestart() {
  final cb = appRestartCallback;
  if (cb == null) return;
  SchedulerBinding.instance.addPostFrameCallback((_) {
    // One more frame so route teardown from pushNamedAndRemoveUntil finishes.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      cb();
    });
  });
}

/// Closes drawers, dialogs, and bottom sheets on the root navigator.
void closeRootOverlays() {
  final nav = navigatorKey.currentState;
  if (nav == null) return;
  while (nav.canPop()) {
    nav.pop();
  }
}

/// Safely replaces the entire stack after overlays have closed.
///
/// Calling [Navigator.pushNamedAndRemoveUntil] while a drawer/sheet is open
/// (or while providers are still notifying) triggers Flutter framework
/// assertions like `_dependents.isEmpty` / `_elements.contains(element)`.
Future<void> safeResetToRoute(String routeName, {Object? arguments}) async {
  closeRootOverlays();

  // Let the overlay routes finish unmounting before replacing the stack.
  await Future<void>.delayed(Duration.zero);
  await SchedulerBinding.instance.endOfFrame;
  await SchedulerBinding.instance.endOfFrame;

  final nav = navigatorKey.currentState;
  if (nav == null) return;

  nav.pushNamedAndRemoveUntil(
    routeName,
    (route) => false,
    arguments: arguments,
  );
}
