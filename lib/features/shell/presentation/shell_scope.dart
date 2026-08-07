import 'package:flutter/material.dart';

/// Exposes the [AppShell] scaffold so nested screens can open the side drawer
/// and optionally switch shell tabs (used by home quick actions).
class ShellScope extends InheritedWidget {
  const ShellScope({
    super.key,
    required this.scaffoldKey,
    required super.child,
    this.selectTab,
    this.selectedTabIndex = 0,
  });

  final GlobalKey<ScaffoldState> scaffoldKey;
  final ValueChanged<int>? selectTab;
  final int selectedTabIndex;

  static ShellScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ShellScope>();
  }

  static void openDrawer(BuildContext context) {
    maybeOf(context)?.scaffoldKey.currentState?.openDrawer();
  }

  static bool hasDrawer(BuildContext context) {
    return maybeOf(context) != null;
  }

  static void goToTab(BuildContext context, int index) {
    maybeOf(context)?.selectTab?.call(index);
  }

  @override
  bool updateShouldNotify(ShellScope oldWidget) {
    return scaffoldKey != oldWidget.scaffoldKey ||
        selectedTabIndex != oldWidget.selectedTabIndex ||
        selectTab != oldWidget.selectTab;
  }
}
