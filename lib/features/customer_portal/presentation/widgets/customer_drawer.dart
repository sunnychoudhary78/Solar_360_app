import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:solar_sales/core/theme/app_design.dart';
import 'package:solar_sales/core/theme/theme_mode_provider.dart';
import 'package:solar_sales/features/auth/presentation/providers/auth_provider.dart';
import 'package:solar_sales/features/shell/presentation/widgets/drawer_chrome.dart';
import 'package:solar_sales/shared/widgets/dialogs.dart';

class CustomerPortalTab {
  final String label;
  final IconData icon;
  final IconData selectedIcon;

  const CustomerPortalTab({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });
}

const customerPortalTabs = [
  CustomerPortalTab(
    label: 'Home',
    icon: Icons.home_outlined,
    selectedIcon: Icons.home_rounded,
  ),
  CustomerPortalTab(
    label: 'Leads',
    icon: Icons.assignment_outlined,
    selectedIcon: Icons.assignment_rounded,
  ),
  CustomerPortalTab(
    label: 'Support',
    icon: Icons.headset_mic_outlined,
    selectedIcon: Icons.headset_mic_rounded,
  ),
  CustomerPortalTab(
    label: 'Account',
    icon: Icons.person_outline_rounded,
    selectedIcon: Icons.person_rounded,
  ),
];

class CustomerDrawer extends ConsumerWidget {
  const CustomerDrawer({
    super.key,
    required this.tabs,
    required this.selectedTabIndex,
    required this.onSelectTab,
  });

  final List<CustomerPortalTab> tabs;
  final int selectedTabIndex;
  final ValueChanged<int> onSelectTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customer = ref.watch(authProvider).customer;
    final scheme = Theme.of(context).colorScheme;
    final themeMode = ref.watch(themeModeProvider);
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    final drawerRadius = Radius.circular(isIOS ? 16 : 28);

    var animIndex = 0;

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
                  AppDrawerHeader(
                    name: customer?.name ?? 'Customer',
                    email: customer?.email ?? '',
                    role: customer?.roleName ?? 'Customer',
                    companyName: customer?.companyName,
                    moduleLabel: 'Customer',
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  const AppDrawerSectionLabel('Main'),
                  for (var i = 0; i < tabs.length; i++)
                    AppDrawerTile(
                      index: animIndex++,
                      icon: tabs[i].icon,
                      selectedIcon: tabs[i].selectedIcon,
                      title: tabs[i].label,
                      isActive: selectedTabIndex == i,
                      onTap: () {
                        Navigator.pop(context);
                        onSelectTab(i);
                      },
                    ),
                  const SizedBox(height: AppSpacing.md),
                ],
              ),
            ),
            Divider(
              color: scheme.outlineVariant.withValues(alpha: 0.5),
              height: 1,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
              child: AppDrawerThemeToggle(
                themeMode: themeMode,
                onChanged: (mode) {
                  ref.read(themeModeProvider.notifier).changeMode(mode);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
              child: AppDrawerTile(
                index: animIndex++,
                icon: Icons.logout_rounded,
                title: 'Logout',
                isDestructive: true,
                onTap: () async {
                  final ok = await showConfirmDialog(
                    context,
                    title: 'Logout',
                    message: 'Sign out of your customer account?',
                    confirmLabel: 'Logout',
                    isDestructive: true,
                  );
                  if (!ok || !context.mounted) return;
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  }
                  await Future<void>.delayed(Duration.zero);
                  await ref.read(authProvider.notifier).logout();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
