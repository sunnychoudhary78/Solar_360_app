import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:solar_sales/core/theme/app_design.dart';
import 'package:solar_sales/features/auth/presentation/providers/auth_provider.dart';
import 'package:solar_sales/shared/widgets/app_bar.dart';
import 'package:solar_sales/shared/widgets/premium_feature_components.dart';

class InventoryHubScreen extends ConsumerWidget {
  const InventoryHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final scheme = Theme.of(context).colorScheme;

    final canRead = auth.hasPermission('inventory.read');
    final canUpdate = auth.hasPermission('inventory.update');
    final canCreate = auth.hasPermission('inventory.create');

    final tiles = <_HubTile>[
      if (canRead)
        _HubTile(
          title: 'Current Stock',
          subtitle: 'Real-time warehouse stock',
          icon: Icons.inventory_2_rounded,
          route: '/inventory/stock',
          accent: _HubAccent.primary,
        ),
      if (canRead)
        _HubTile(
          title: 'Stock Ledger',
          subtitle: 'Audit & movement history',
          icon: Icons.history_rounded,
          route: '/inventory/ledger',
          accent: _HubAccent.secondary,
        ),
      if (canRead)
        _HubTile(
          title: 'Low Stock',
          subtitle: 'Alerts & reorder levels',
          icon: Icons.warning_amber_rounded,
          route: '/inventory/low-stock',
          accent: _HubAccent.error,
          badgeText: 'Alerts',
        ),
      if (canRead || canCreate || canUpdate)
        _HubTile(
          title: 'Warehouses',
          subtitle: 'Locations & sites',
          icon: Icons.warehouse_rounded,
          route: '/inventory/warehouses',
          accent: _HubAccent.tertiary,
        ),
    ];

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: const AppAppBar(title: 'Inventory Hub'),
      body: tiles.isEmpty
          ? const PremiumEmptyState(
              icon: Icons.lock_outline_rounded,
              title: 'No Access Granted',
              subtitle:
                  'Please contact your workspace admin to enable inventory permissions.',
            )
          : CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                const SliverToBoxAdapter(
                  child: PageHeader(
                    icon: Icons.inventory_2_rounded,
                    title: 'Inventory Operations',
                    subtitle:
                        'Manage materials, track ledger history & monitor stock alerts',
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.5,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        return _HubCard(tile: tiles[index]);
                      },
                      childCount: tiles.length,
                    ),
                  ),
                ),
                const SliverToBoxAdapter(
                  child: SizedBox(height: AppSpacing.xl),
                ),
              ],
            ),
    );
  }
}

class _HubCard extends StatelessWidget {
  final _HubTile tile;

  const _HubCard({required this.tile});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final accent = _accentFor(scheme, tile.accent);

    return PremiumCard(
      onTap: () => Navigator.pushNamed(context, tile.route),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(tile.icon, color: accent, size: 22),
              ),
              if (tile.badgeText != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    tile.badgeText!,
                    style: TextStyle(
                      color: accent,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              else
                Icon(
                  Icons.arrow_forward_rounded,
                  size: 18,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tile.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                tile.subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodySmall?.copyWith(
                  height: 1.25,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

enum _HubAccent { primary, secondary, tertiary, error }

Color _accentFor(ColorScheme scheme, _HubAccent accent) {
  return switch (accent) {
    _HubAccent.primary => scheme.primary,
    _HubAccent.secondary => scheme.secondary,
    _HubAccent.tertiary => scheme.tertiary,
    _HubAccent.error => scheme.error,
  };
}

class _HubTile {
  final String title;
  final String subtitle;
  final IconData icon;
  final String route;
  final _HubAccent accent;
  final String? badgeText;

  const _HubTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.route,
    required this.accent,
    this.badgeText,
  });
}
