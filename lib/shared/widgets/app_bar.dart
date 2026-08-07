import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:solar_sales/core/theme/app_design.dart';
import 'package:solar_sales/features/shell/presentation/shell_scope.dart';

class AppAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final bool automaticallyImplyLeading;
  final Widget? leading;
  final bool largeTitle;
  final bool centerTitle;

  const AppAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    this.automaticallyImplyLeading = true,
    this.leading,
    this.largeTitle = false,
    this.centerTitle = false,
  });

  @override
  Size get preferredSize => Size.fromHeight(
        largeTitle
            ? (subtitle != null ? 96 : 88)
            : (subtitle != null ? kToolbarHeight + 18 : kToolbarHeight),
      );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    final blurSigma = isIOS ? 10.0 : 12.0;
    final inShell = ShellScope.hasDrawer(context);

    Widget? resolvedLeading = leading;
    if (resolvedLeading == null && inShell) {
      resolvedLeading = IconButton(
        tooltip: 'Menu',
        icon: Icon(isIOS ? Icons.menu_rounded : Icons.menu),
        onPressed: () => ShellScope.openDrawer(context),
      );
    }

    final titleWidget = largeTitle
        ? Column(
            crossAxisAlignment: centerTitle
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  color: scheme.onSurface,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          )
        : subtitle == null
            ? Text(
                title,
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                  Text(
                    subtitle!,
                    style: textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              );

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: AppBar(
          title: titleWidget,
          toolbarHeight: preferredSize.height,
          centerTitle: centerTitle,
          actions: actions,
          leading: resolvedLeading,
          automaticallyImplyLeading:
              resolvedLeading == null && automaticallyImplyLeading,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.transparent,
          backgroundColor: scheme.surface.withValues(alpha: 0.55),
          foregroundColor: scheme.onSurface,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(
              height: 1,
              color: scheme.outline.withValues(alpha: 0.12),
            ),
          ),
        ),
      ),
    );
  }
}

/// Collapsing large-title header for scrollable home screens.
class AppSliverHeader extends StatelessWidget {
  const AppSliverHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    this.expandedHeight = 120,
  });

  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final double expandedHeight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final inShell = ShellScope.hasDrawer(context);

    return SliverAppBar(
      pinned: true,
      floating: false,
      expandedHeight: expandedHeight,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: scheme.surface.withValues(alpha: 0.92),
      surfaceTintColor: Colors.transparent,
      leading: inShell
          ? IconButton(
              tooltip: 'Menu',
              icon: const Icon(Icons.menu_rounded),
              onPressed: () => ShellScope.openDrawer(context),
            )
          : null,
      actions: actions,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: EdgeInsets.only(
          left: inShell ? 56 : AppSpacing.md,
          bottom: 14,
          right: AppSpacing.md,
        ),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: scheme.onSurface,
              ),
            ),
            if (subtitle != null)
              Text(
                subtitle!,
                style: textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
