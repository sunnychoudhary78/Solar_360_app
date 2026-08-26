import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:solar_sales/core/theme/app_design.dart';
import 'package:solar_sales/core/widgets/profile_photo_box.dart';

class AppDrawerHeader extends StatelessWidget {
  const AppDrawerHeader({
    super.key,
    required this.name,
    required this.email,
    this.role,
    this.companyName,
    this.moduleLabel,
    this.profilePicture,
  });

  final String name;
  final String email;
  final String? role;
  final String? companyName;
  final String? moduleLabel;
  final String? profilePicture;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    const onHeader = Colors.white;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        decoration: BoxDecoration(
          gradient: AppGradients.drawerHeader(scheme),
          borderRadius: BorderRadius.circular(24),
          boxShadow: AppShadows.header(scheme),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.28),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: ProfilePhotoBox(
                      rawProfilePicture: profilePicture,
                      initial: name.isNotEmpty ? name[0].toUpperCase() : 'U',
                      textColor: scheme.primary,
                      fontSize: 20,
                    ),
                  ),
                ),
                const Spacer(),
                if (moduleLabel != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.18),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.layers_rounded,
                          size: 14,
                          color: onHeader.withValues(alpha: 0.85),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          moduleLabel!,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: onHeader.withValues(alpha: 0.95),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Solar 360',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: onHeader.withValues(alpha: 0.72),
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: onHeader,
              ),
            ),
            if (role != null && role!.trim().isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(
                role!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: onHeader.withValues(alpha: 0.88),
                ),
              ),
            ],
            if ((companyName != null && companyName!.isNotEmpty) ||
                email.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (companyName != null && companyName!.isNotEmpty)
                      Text(
                        companyName!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: onHeader.withValues(alpha: 0.80),
                        ),
                      ),
                    if (companyName != null &&
                        companyName!.isNotEmpty &&
                        email.isNotEmpty)
                      const SizedBox(height: 4),
                    if (email.isNotEmpty)
                      Text(
                        email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: onHeader.withValues(alpha: 0.70),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class AppDrawerSectionLabel extends StatelessWidget {
  const AppDrawerSectionLabel(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title.toUpperCase(),
          style: TextStyle(
            color: scheme.onSurfaceVariant.withValues(alpha: 0.85),
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
          ),
        ),
      ),
    );
  }
}

class AppDrawerTile extends StatelessWidget {
  const AppDrawerTile({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    required this.index,
    this.selectedIcon,
    this.subtitle,
    this.isActive = false,
    this.isDestructive = false,
    this.badgeCount = 0,
  });

  final IconData icon;
  final IconData? selectedIcon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final int index;

  final bool isActive;
  final bool isDestructive;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    final tileRadius = BorderRadius.circular(isIOS ? 12 : 14);
    final accent = isDestructive ? scheme.error : scheme.primary;
    final muted = isDestructive ? scheme.error : scheme.onSurfaceVariant;
    final label = isDestructive ? scheme.error : scheme.onSurface;
    final displayIcon = isActive ? (selectedIcon ?? icon) : icon;
    final badgeLabel = badgeCount > 99 ? '99+' : '$badgeCount';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      child: Semantics(
        button: true,
        selected: isActive,
        label: badgeCount > 0 ? '$title, $badgeLabel unread' : title,
        child: Material(
          color: isActive
              ? scheme.primary.withValues(alpha: 0.10)
              : Colors.transparent,
          borderRadius: tileRadius,
          child: InkWell(
            borderRadius: tileRadius,
            splashFactory: isIOS
                ? NoSplash.splashFactory
                : InkSplash.splashFactory,
            onTap: onTap,
            child: AnimatedContainer(
              duration: AppMotion.fast,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                borderRadius: tileRadius,
                border: isActive
                    ? Border(left: BorderSide(color: accent, width: 3))
                    : null,
              ),
              child: Row(
                children: [
                  Icon(
                    displayIcon,
                    size: 20,
                    color: isActive ? accent : muted,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: _DrawerTileText(
                      title: title,
                      subtitle: subtitle,
                      isActive: isActive,
                      accent: accent,
                      label: label,
                      scheme: scheme,
                    ),
                  ),
                  if (badgeCount > 0)
                    Semantics(
                      label: '$badgeLabel unread notifications',
                      child: Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.error,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Text(
                          badgeLabel,
                          style: TextStyle(
                            color: scheme.onError,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    )
                  else if (isActive)
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    )
        .animate(delay: (index * 35).ms)
        .fade(duration: 260.ms)
        .slideX(begin: -0.1, end: 0, curve: Curves.easeOutCubic);
  }
}

class _DrawerTileText extends StatelessWidget {
  const _DrawerTileText({
    required this.title,
    required this.subtitle,
    required this.isActive,
    required this.accent,
    required this.label,
    required this.scheme,
  });

  final String title;
  final String? subtitle;
  final bool isActive;
  final Color accent;
  final Color label;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            color: isActive ? accent : label,
          ),
        ),
        if (subtitle != null && subtitle!.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              subtitle!,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}

class AppDrawerThemeToggle extends StatelessWidget {
  const AppDrawerThemeToggle({
    super.key,
    required this.themeMode,
    required this.onChanged,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);
    final label = isDark ? 'Dark mode' : 'Light mode';

    return Semantics(
      label: label,
      toggled: isDark,
      child: Tooltip(
        message: isDark ? 'Switch to light mode' : 'Switch to dark mode',
        child: Material(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            onTap: () {
              onChanged(isDark ? ThemeMode.light : ThemeMode.dark);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    isDark
                        ? Icons.dark_mode_rounded
                        : Icons.light_mode_rounded,
                    size: 20,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                  Switch.adaptive(
                    value: isDark,
                    onChanged: (value) {
                      onChanged(value ? ThemeMode.dark : ThemeMode.light);
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
