import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:solar_sales/core/theme/app_design.dart';
import 'package:solar_sales/core/theme/theme_mode_provider.dart';
import 'package:solar_sales/features/auth/presentation/providers/auth_provider.dart';
import 'package:solar_sales/features/module/presentation/providers/module_provider.dart';
import 'package:solar_sales/shared/module/module_access.dart';
import 'package:solar_sales/shared/widgets/app_bar.dart';
import 'package:solar_sales/shared/widgets/dialogs.dart';
import 'package:solar_sales/shared/widgets/premium_feature_components.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final auth = ref.watch(authProvider);
    final module = ref.watch(moduleProvider);
    final profile = auth.profile;
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final switchableRoles = filterRolesForModule(auth.roles, module.activeModule)
        .where((r) =>
            r.toLowerCase() != auth.effectiveRoleName.toLowerCase())
        .toList();

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: const AppAppBar(title: 'Settings'),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          if (profile != null) ...[
            const PremiumSectionTitle(title: 'Account'),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      profile.name.isNotEmpty
                          ? profile.name[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: scheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile.name,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (auth.effectiveRoleName.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            auth.effectiveRoleName,
                            style: textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        if (profile.companyName != null &&
                            profile.companyName!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            profile.companyName!,
                            style: textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                        const SizedBox(height: 2),
                        Text(
                          profile.email,
                          style: textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          if (switchableRoles.isNotEmpty) ...[
            const PremiumSectionTitle(
              title: 'Active role',
              subtitle: 'Switching role updates permissions in this company',
            ),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < switchableRoles.length; i++) ...[
                    if (i > 0)
                      Divider(
                        height: 1,
                        color: scheme.outlineVariant.withValues(alpha: 0.4),
                      ),
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 2,
                      ),
                      leading: Icon(Icons.swap_horiz, color: scheme.primary),
                      title: Text(
                        switchableRoles[i],
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      trailing: Icon(
                        Icons.chevron_right_rounded,
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                      onTap: () async {
                        final role = switchableRoles[i];
                        final ok = await showConfirmDialog(
                          context,
                          title: 'Switch role',
                          message:
                              'Switch to "$role"? The app will refresh with that role\'s permissions.',
                          confirmLabel: 'Switch',
                        );
                        if (!ok) return;
                        await ref.read(authProvider.notifier).switchRole(role);
                      },
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          PremiumSectionTitle(
            title: 'Appearance',
            subtitle: _themeLabel(themeMode),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Theme mode',
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.light,
                      icon: Icon(Icons.light_mode),
                      label: Text('Light'),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      icon: Icon(Icons.dark_mode),
                      label: Text('Dark'),
                    ),
                    ButtonSegment(
                      value: ThemeMode.system,
                      icon: Icon(Icons.settings_suggest),
                      label: Text('System'),
                    ),
                  ],
                  selected: {themeMode},
                  onSelectionChanged: (set) {
                    ref.read(themeModeProvider.notifier).changeMode(set.first);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const PremiumSectionTitle(title: 'Security'),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            padding: EdgeInsets.zero,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 4,
              ),
              leading: Icon(Icons.lock_outline, color: scheme.primary),
              title: const Text(
                'Change password',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              trailing: Icon(
                Icons.chevron_right_rounded,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
              onTap: () => Navigator.pushNamed(context, '/change-password'),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const PremiumSectionTitle(title: 'Session'),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            padding: EdgeInsets.zero,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 4,
              ),
              leading: Icon(Icons.logout_rounded, color: scheme.error),
              title: Text(
                'Logout',
                style: TextStyle(
                  color: scheme.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
              onTap: () async {
                final ok = await showConfirmDialog(
                  context,
                  title: 'Logout',
                  message: 'Are you sure you want to sign out?',
                  confirmLabel: 'Logout',
                  isDestructive: true,
                );
                if (!ok) return;
                await ref.read(authProvider.notifier).logout();
              },
            ),
          ),
        ],
      ),
    );
  }

  String _themeLabel(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.light => 'Light',
      ThemeMode.dark => 'Dark',
      ThemeMode.system => 'System',
    };
  }
}
