import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:solar_sales/core/theme/app_design.dart';
import 'package:solar_sales/core/theme/theme_mode_provider.dart';
import 'package:solar_sales/core/widgets/profile_photo_box.dart';
import 'package:solar_sales/features/auth/presentation/providers/auth_provider.dart';
import 'package:solar_sales/features/module/presentation/widgets/module_toggle.dart';
import 'package:solar_sales/features/notifications/presentation/providers/notification_providers.dart';
import 'package:solar_sales/features/shell/presentation/nav_destinations.dart';
import 'package:solar_sales/shared/module/module_access.dart';
import 'package:solar_sales/shared/widgets/dialogs.dart';

class AppDrawer extends ConsumerWidget {
  const AppDrawer({
    super.key,
    required this.tabs,
    required this.selectedTabIndex,
    required this.onSelectDestination,
    this.activeModule = AppModules.billbook,
    this.showModuleToggle = false,
    this.onModuleChanged,
    this.activeRoute,
  });

  final List<AppDestination> tabs;
  final int selectedTabIndex;
  final ValueChanged<AppDestination> onSelectDestination;

  final String activeModule;
  final bool showModuleToggle;
  final ValueChanged<String>? onModuleChanged;

  /// Named route currently pushed above the shell (if any).
  final String? activeRoute;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final scheme = Theme.of(context).colorScheme;
    final themeMode = ref.watch(themeModeProvider);
    final assignedRoles = _assignedRoles(
      auth.assignedRoles.isNotEmpty ? auth.assignedRoles : auth.roles,
    );
    final unreadCount = ref
        .watch(unreadNotificationCountProvider)
        .maybeWhen(data: (value) => value, orElse: () => 0);

    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    final routeName =
        activeRoute ?? ModalRoute.of(context)?.settings.name;

    final drawerRadius = Radius.circular(isIOS ? 16 : 28);

    bool hasPerm(String permission) {
      return auth.hasPermission(permission);
    }

    final sections = <NavSection>[
      NavSection.main,
      NavSection.catalog,
      NavSection.approvals,
      NavSection.solarCrm,
      NavSection.app,
    ];

    var animIndex = 0;
    var switchRoleInserted = false;

    Widget switchRoleTile() {
      return _DrawerTile(
        index: animIndex++,
        icon: Icons.swap_horiz_rounded,
        title: 'Switch Role',
        subtitle: assignedRoles.isEmpty
            ? null
            : '${assignedRoles.length} assigned role${assignedRoles.length == 1 ? '' : 's'}',
        onTap: () async {
          await _showRoleSwitcher(context, ref);
        },
      );
    }

    final navChildren = <Widget>[];
    for (final section in sections) {
      final items = NavDestinations.forSection(
        activeModule,
        section,
        hasPerm,
      );
      if (items.isEmpty) continue;

      navChildren.add(
        _SectionLabel(NavDestinations.sectionLabel(section)),
      );

      for (final dest in items) {
        navChildren.add(
          _DrawerTile(
            index: animIndex++,
            icon: dest.icon,
            selectedIcon: dest.effectiveSelectedIcon,
            title: dest.label,
            isActive: _isActive(dest, routeName),
            badgeCount: dest.id == 'ge_alerts' ||
                    dest.id == 'bb_notifications'
                ? unreadCount
                : 0,
            onTap: () {
              Navigator.pop(context);
              onSelectDestination(dest);
            },
          ),
        );

        // Always keep Switch Role right after Alerts / Notifications so it
        // remains available after every role switch in either module.
        if (!switchRoleInserted &&
            (dest.id == 'ge_alerts' || dest.id == 'bb_notifications')) {
          navChildren.add(switchRoleTile());
          switchRoleInserted = true;
        }
      }

      if (!switchRoleInserted && section == NavSection.main) {
        navChildren.add(switchRoleTile());
        switchRoleInserted = true;
      }
    }

    if (!switchRoleInserted) {
      navChildren.add(const _SectionLabel('Account'));
      navChildren.add(switchRoleTile());
    }

    return Drawer(
      backgroundColor: scheme.surface,
      elevation: isIOS ? 6 : 12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: drawerRadius,
          bottomRight: drawerRadius,
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                physics: isIOS
                    ? const BouncingScrollPhysics()
                    : const ClampingScrollPhysics(),
                children: [
                  // ---------------------------------------------------------
                  // DRAWER HEADER
                  // ---------------------------------------------------------
                  _DrawerHeader(
                    name: auth.profile?.name ?? 'User',
                    email: auth.profile?.email ?? '',
                    role: auth.effectiveRoleName.isNotEmpty
                        ? auth.effectiveRoleName
                        : auth.profile?.roleName,
                    companyName: auth.profile?.companyName,
                    moduleLabel: ModuleLabels.of(activeModule),
                    profilePicture: auth.profile?.photo,
                  ),

                  // ---------------------------------------------------------
                  // MODULE TOGGLE
                  // ---------------------------------------------------------
                  if (showModuleToggle && onModuleChanged != null) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        14,
                        8,
                        14,
                        6,
                      ),
                      child: ModuleToggle(
                        activeModule: activeModule,
                        onChanged: (id) {
                          Navigator.pop(context);
                          onModuleChanged!(id);
                        },
                      ),
                    ),
                  ],

                  const SizedBox(height: AppSpacing.xs),

                  // ---------------------------------------------------------
                  // NAVIGATION SECTIONS (+ Switch Role after Alerts)
                  // ---------------------------------------------------------
                  ...navChildren,

                  const SizedBox(height: AppSpacing.md),
                ],
              ),
            ),

            // ---------------------------------------------------------------
            // FOOTER
            // ---------------------------------------------------------------
            Divider(
              color: scheme.outlineVariant.withValues(
                alpha: 0.5,
              ),
              height: 1,
            ),

            // ---------------------------------------------------------------
            // THEME TOGGLE
            // ---------------------------------------------------------------
            Padding(
              padding: const EdgeInsets.fromLTRB(
                14,
                8,
                14,
                4,
              ),
              child: _ThemeToggleRow(
                themeMode: themeMode,
                onChanged: (mode) {
                  ref
                      .read(themeModeProvider.notifier)
                      .changeMode(mode);
                },
              ),
            ),

            // ---------------------------------------------------------------
            // LOGOUT
            // ---------------------------------------------------------------
            Padding(
              padding: const EdgeInsets.fromLTRB(
                14,
                4,
                14,
                14,
              ),
              child: _DrawerTile(
                index: animIndex++,
                icon: Icons.logout_rounded,
                title: 'Logout',
                isDestructive: true,
                onTap: () async {
                  final ok = await showConfirmDialog(
                    context,
                    title: 'Logout',
                    message:
                        'Are you sure you want to sign out?',
                    confirmLabel: 'Logout',
                    isDestructive: true,
                  );

                  if (!ok || !context.mounted) {
                    return;
                  }

                  Navigator.pop(context);

                  await ref
                      .read(authProvider.notifier)
                      .logout();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // ROLE SWITCHER
  // ===========================================================================

  Future<void> _showRoleSwitcher(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final auth = ref.read(authProvider);

    final currentRole = auth.effectiveRoleName.trim();
    final roles = _assignedRoles(
      auth.assignedRoles.isNotEmpty ? auth.assignedRoles : auth.roles,
    );

    // -------------------------------------------------------------------------
    // NO ROLE AVAILABLE
    // -------------------------------------------------------------------------
    if (roles.isEmpty) {
      if (!context.mounted) {
        return;
      }

      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text(
              'Switch Role',
            ),
            content: const Text(
              'No roles are currently assigned '
              'to this user.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                },
                child: const Text('OK'),
              ),
            ],
          );
        },
      );

      return;
    }

    // -------------------------------------------------------------------------
    // ROLE SELECTION
    // -------------------------------------------------------------------------
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor:
          Theme.of(context).colorScheme.surface,
      builder: (sheetContext) {
        final scheme =
            Theme.of(sheetContext).colorScheme;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              16,
              4,
              16,
              20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment:
                  CrossAxisAlignment.stretch,
              children: [
                // -------------------------------------------------------------
                // TITLE
                // -------------------------------------------------------------
                Text(
                  'Switch Role',
                  style: Theme.of(sheetContext)
                      .textTheme
                      .titleLarge
                      ?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),

                const SizedBox(height: 4),

                // -------------------------------------------------------------
                // CURRENT ROLE
                // -------------------------------------------------------------
                if (currentRole.isNotEmpty)
                  Text(
                    'Current role: $currentRole',
                    style: Theme.of(sheetContext)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(
                          color:
                              scheme.onSurfaceVariant,
                          fontWeight:
                              FontWeight.w600,
                        ),
                  ),

                const SizedBox(height: 14),

                // -------------------------------------------------------------
                // ASSIGNED ROLES
                // -------------------------------------------------------------
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: roles.length,
                    separatorBuilder: (context, index) {
                      return const SizedBox(height: 6);
                    },
                    itemBuilder: (
                      itemContext,
                      index,
                    ) {
                      final role = roles[index];
                      final isCurrent =
                          role.toLowerCase() == currentRole.toLowerCase();

                      return Material(
                        color:
                            scheme.surfaceContainerLow,
                        borderRadius:
                            BorderRadius.circular(
                          AppRadius.lg,
                        ),
                        child: ListTile(
                          shape:
                              RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(
                              AppRadius.lg,
                            ),
                          ),
                          leading: Icon(
                            Icons.badge_outlined,
                            color: scheme.primary,
                          ),
                          title: Text(
                            role,
                            style: const TextStyle(
                              fontWeight:
                                  FontWeight.w700,
                            ),
                          ),
                          subtitle: isCurrent
                              ? Text(
                                  'Active now',
                                  style: TextStyle(
                                    color: scheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                )
                              : null,
                          trailing: isCurrent
                              ? Icon(
                                  Icons.check_circle_rounded,
                                  color: scheme.primary,
                                )
                              : Icon(
                                  Icons.chevron_right_rounded,
                                  color: scheme.onSurfaceVariant,
                                ),
                          onTap: () async {
                            if (isCurrent) {
                              Navigator.pop(sheetContext);
                              return;
                            }

                            // -------------------------------------------------
                            // CONFIRM ROLE SWITCH
                            // -------------------------------------------------
                            final confirmed =
                                await showConfirmDialog(
                              itemContext,
                              title: 'Switch role',
                              message:
                                  'Switch to "$role"? '
                                  'The app will refresh with '
                                  'that role\'s permissions.',
                              confirmLabel: 'Switch',
                            );

                            if (!confirmed ||
                                !itemContext.mounted) {
                              return;
                            }

                            // Close role selector first.
                            Navigator.pop(
                              sheetContext,
                            );

                            // -------------------------------------------------
                            // EXISTING AUTH LOGIC
                            //
                            // DO NOT create another role-switch system.
                            // Existing AuthNotifier.switchRole() handles:
                            // - API role switch
                            // - fresh profile
                            // - permissions
                            // - module sync
                            // - navigation
                            // - provider restart
                            // -------------------------------------------------
                            await ref
                                .read(
                                  authProvider
                                      .notifier,
                                )
                                .switchRole(role);
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<String> _assignedRoles(List<String> roles) {
    final cleaned = roles
        .map((role) => role.trim())
        .where((role) => role.isNotEmpty)
        .toSet()
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return cleaned;
  }

  // ===========================================================================
  // ACTIVE DESTINATION
  // ===========================================================================

  bool _isActive(
    AppDestination dest,
    String? route,
  ) {
    if (dest.kind == NavKind.shellTab) {
      if (activeRoute != null) {
        return false;
      }

      final index = tabs.indexWhere(
        (tab) => tab.id == dest.id,
      );

      return index >= 0 &&
          index == selectedTabIndex;
    }

    return dest.route != null &&
        route == dest.route;
  }
}

// =============================================================================
// DRAWER HEADER
// =============================================================================

class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader({
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
      padding: const EdgeInsets.fromLTRB(
        14,
        10,
        14,
        6,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          16,
          16,
          16,
          14,
        ),
        decoration: BoxDecoration(
          gradient:
              AppGradients.drawerHeader(scheme),
          borderRadius:
              BorderRadius.circular(24),
          boxShadow:
              AppShadows.header(scheme),
          border: Border.all(
            color:
                Colors.white.withValues(alpha: 0.10),
          ),
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            // -----------------------------------------------------------------
            // PROFILE ROW
            // -----------------------------------------------------------------
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  padding:
                      const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(
                      alpha: 0.16,
                    ),
                    borderRadius:
                        BorderRadius.circular(18),
                    border: Border.all(
                      color:
                          Colors.white.withValues(
                        alpha: 0.28,
                      ),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius:
                        BorderRadius.circular(16),
                    child: ProfilePhotoBox(
                      rawProfilePicture:
                          profilePicture,
                      initial: name.isNotEmpty
                          ? name[0].toUpperCase()
                          : 'U',
                      textColor:
                          scheme.primary,
                      fontSize: 20,
                    ),
                  ),
                ),

                const Spacer(),

                if (moduleLabel != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color:
                          Colors.white.withValues(
                        alpha: 0.14,
                      ),
                      borderRadius:
                          BorderRadius.circular(
                        AppRadius.pill,
                      ),
                      border: Border.all(
                        color:
                            Colors.white.withValues(
                          alpha: 0.18,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisSize:
                          MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.layers_rounded,
                          size: 14,
                          color:
                              onHeader.withValues(
                            alpha: 0.85,
                          ),
                        ),
                        const SizedBox(
                          width: 6,
                        ),
                        Text(
                          moduleLabel!,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight:
                                FontWeight.w700,
                            color:
                                onHeader.withValues(
                              alpha: 0.95,
                            ),
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
                fontWeight:
                    FontWeight.w700,
                color:
                    onHeader.withValues(
                  alpha: 0.72,
                ),
                letterSpacing: 0.8,
              ),
            ),

            const SizedBox(height: 4),

            Text(
              name,
              maxLines: 1,
              overflow:
                  TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 18,
                fontWeight:
                    FontWeight.w800,
                color: onHeader,
              ),
            ),

            // -----------------------------------------------------------------
            // CURRENT ROLE
            // -----------------------------------------------------------------
            if (role != null &&
                role!.trim().isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(
                role!,
                maxLines: 1,
                overflow:
                    TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight:
                      FontWeight.w700,
                  color:
                      onHeader.withValues(
                    alpha: 0.88,
                  ),
                ),
              ),
            ],

            // -----------------------------------------------------------------
            // COMPANY + EMAIL
            // -----------------------------------------------------------------
            if ((companyName != null &&
                    companyName!.isNotEmpty) ||
                email.isNotEmpty) ...[
              const SizedBox(height: 8),

              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration:
                    BoxDecoration(
                  color:
                      Colors.white.withValues(
                    alpha: 0.10,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    AppRadius.lg,
                  ),
                  border: Border.all(
                    color:
                        Colors.white.withValues(
                      alpha: 0.12,
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    if (companyName != null &&
                        companyName!.isNotEmpty)
                      Text(
                        companyName!,
                        maxLines: 1,
                        overflow:
                            TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight:
                              FontWeight.w600,
                          color:
                              onHeader.withValues(
                            alpha: 0.80,
                          ),
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
                        overflow:
                            TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          color:
                              onHeader.withValues(
                            alpha: 0.70,
                          ),
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

// =============================================================================
// SECTION LABEL
// =============================================================================

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final scheme =
        Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        22,
        16,
        22,
        4,
      ),
      child: Align(
        alignment:
            Alignment.centerLeft,
        child: Text(
          title.toUpperCase(),
          style: TextStyle(
            color: scheme.onSurfaceVariant
                .withValues(alpha: 0.85),
            fontSize: 11,
            fontWeight:
                FontWeight.w800,
            letterSpacing: 1.0,
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// DRAWER TILE
// =============================================================================

class _DrawerTile extends StatelessWidget {
  const _DrawerTile({
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
    final scheme =
        Theme.of(context).colorScheme;

    final isIOS =
        defaultTargetPlatform ==
            TargetPlatform.iOS;

    final tileRadius =
        BorderRadius.circular(
      isIOS ? 12 : 14,
    );

    final accent =
        isDestructive
            ? scheme.error
            : scheme.primary;

    final muted =
        isDestructive
            ? scheme.error
            : scheme.onSurfaceVariant;

    final label =
        isDestructive
            ? scheme.error
            : scheme.onSurface;

    final displayIcon =
        isActive
            ? (selectedIcon ?? icon)
            : icon;

    final badgeLabel =
        badgeCount > 99
            ? '99+'
            : '$badgeCount';

    return Padding(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 2,
      ),
      child: Semantics(
        button: true,
        selected: isActive,
        label: badgeCount > 0
            ? '$title, $badgeLabel unread'
            : title,
        child: Material(
          color: isActive
              ? scheme.primary.withValues(
                  alpha: 0.10,
                )
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
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 11,
              ),
              decoration:
                  BoxDecoration(
                borderRadius:
                    tileRadius,
                border: isActive
                    ? Border(
                        left: BorderSide(
                          color: accent,
                          width: 3,
                        ),
                      )
                    : null,
              ),
              child: Row(
                children: [
                  Icon(
                    displayIcon,
                    size: 20,
                    color: isActive
                        ? accent
                        : muted,
                  ),

                  const SizedBox(
                    width: AppSpacing.md,
                  ),

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
                      label:
                          '$badgeLabel unread notifications',
                      child: Container(
                        margin:
                            const EdgeInsets.only(
                          right: 6,
                        ),
                        padding:
                            const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration:
                            BoxDecoration(
                          color: scheme.error,
                          borderRadius:
                              BorderRadius.circular(
                            AppRadius.pill,
                          ),
                        ),
                        child: Text(
                          badgeLabel,
                          style: TextStyle(
                            color:
                                scheme.onError,
                            fontSize: 10,
                            fontWeight:
                                FontWeight.w700,
                          ),
                        ),
                      ),
                    )
                  else if (isActive)
                    Container(
                      width: 6,
                      height: 6,
                      decoration:
                          BoxDecoration(
                        color: accent,
                        shape:
                            BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    )
        .animate(
          delay: (index * 35).ms,
        )
        .fade(duration: 260.ms)
        .slideX(
          begin: -0.1,
          end: 0,
          curve:
              Curves.easeOutCubic,
        );
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

// =============================================================================
// THEME TOGGLE
// =============================================================================

class _ThemeToggleRow extends StatelessWidget {
  const _ThemeToggleRow({
    required this.themeMode,
    required this.onChanged,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme =
        Theme.of(context).colorScheme;

    final isDark =
        themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system &&
            MediaQuery.platformBrightnessOf(
                  context,
                ) ==
                Brightness.dark);

    final label =
        isDark ? 'Dark mode' : 'Light mode';

    return Semantics(
      label: label,
      toggled: isDark,
      child: Tooltip(
        message: isDark
            ? 'Switch to light mode'
            : 'Switch to dark mode',
        child: Material(
          color:
              scheme.surfaceContainerLow,
          borderRadius:
              BorderRadius.circular(
            AppRadius.lg,
          ),
          child: InkWell(
            borderRadius:
                BorderRadius.circular(
              AppRadius.lg,
            ),
            onTap: () {
              onChanged(
                isDark
                    ? ThemeMode.light
                    : ThemeMode.dark,
              );
            },
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              child: Row(
                children: [
                  Icon(
                    isDark
                        ? Icons.dark_mode_rounded
                        : Icons.light_mode_rounded,
                    size: 20,
                    color: scheme.primary,
                  ),

                  const SizedBox(
                    width: AppSpacing.md,
                  ),

                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight:
                            FontWeight.w600,
                        color:
                            scheme.onSurface,
                      ),
                    ),
                  ),

                  Switch.adaptive(
                    value: isDark,
                    onChanged: (value) {
                      onChanged(
                        value
                            ? ThemeMode.dark
                            : ThemeMode.light,
                      );
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