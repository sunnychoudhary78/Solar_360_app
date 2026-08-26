import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:solar_sales/core/theme/app_design.dart';
import 'package:solar_sales/core/theme/theme_mode_provider.dart';
import 'package:solar_sales/core/workflow/lead_workflow.dart';
import 'package:solar_sales/features/auth/presentation/providers/auth_provider.dart';
import 'package:solar_sales/features/module/presentation/widgets/module_toggle.dart';
import 'package:solar_sales/features/notifications/presentation/providers/notification_providers.dart';
import 'package:solar_sales/features/shell/presentation/nav_destinations.dart';
import 'package:solar_sales/features/shell/presentation/widgets/drawer_chrome.dart';
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

    final isSolarSalesUser =
        activeModule == AppModules.solar &&
        LeadWorkflow.resolveRoleKey(auth.effectiveRoleName) == 'Sales';

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
      return AppDrawerTile(
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

    Widget customersTile() {
      final dest = NavDestinations.solarCustomers;
      return AppDrawerTile(
        index: animIndex++,
        icon: dest.icon,
        selectedIcon: dest.effectiveSelectedIcon,
        title: dest.label,
        isActive: _isActive(dest, routeName),
        onTap: () {
          Navigator.pop(context);
          onSelectDestination(dest);
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
        AppDrawerSectionLabel(NavDestinations.sectionLabel(section)),
      );

      for (final dest in items) {
        navChildren.add(
          AppDrawerTile(
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

        // Sales User only: Customers sits above Switch Role (after Alerts).
        if (!switchRoleInserted &&
            (dest.id == 'ge_alerts' || dest.id == 'bb_notifications')) {
          if (isSolarSalesUser) {
            navChildren.add(customersTile());
          }
          navChildren.add(switchRoleTile());
          switchRoleInserted = true;
        }
      }

      if (!switchRoleInserted && section == NavSection.main) {
        if (isSolarSalesUser) {
          navChildren.add(customersTile());
        }
        navChildren.add(switchRoleTile());
        switchRoleInserted = true;
      }
    }

    if (!switchRoleInserted) {
      navChildren.add(const AppDrawerSectionLabel('Account'));
      if (isSolarSalesUser) {
        navChildren.add(customersTile());
      }
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
                  AppDrawerHeader(
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
              child: AppDrawerThemeToggle(
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
              child: AppDrawerTile(
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

                  // Close drawer before logout navigates / restarts providers.
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  }
                  await Future<void>.delayed(Duration.zero);

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

                            // Close role sheet + drawer before auth navigates.
                            // Leaving them open caused `_dependents.isEmpty`
                            // red screens after a successful switch.
                            Navigator.of(
                              sheetContext,
                              rootNavigator: false,
                            ).pop();
                            if (context.mounted &&
                                Navigator.of(context).canPop()) {
                              Navigator.of(context).pop();
                            }

                            await Future<void>.delayed(Duration.zero);

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
