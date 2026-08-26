import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:solar_sales/core/theme/app_design.dart';
import 'package:solar_sales/features/customer_portal/presentation/screens/customer_account_screen.dart';
import 'package:solar_sales/features/customer_portal/presentation/screens/customer_home_screen.dart';
import 'package:solar_sales/features/customer_portal/presentation/screens/customer_leads_screen.dart';
import 'package:solar_sales/features/customer_portal/presentation/screens/customer_support_screen.dart';
import 'package:solar_sales/features/customer_portal/presentation/widgets/customer_drawer.dart';
import 'package:solar_sales/features/shell/presentation/shell_scope.dart';

class CustomerShell extends ConsumerStatefulWidget {
  const CustomerShell({super.key});

  @override
  ConsumerState<CustomerShell> createState() => _CustomerShellState();
}

class _CustomerShellState extends ConsumerState<CustomerShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  int _index = 0;

  void _selectTab(int index) {
    if (index == _index || index < 0 || index >= customerPortalTabs.length) {
      return;
    }
    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ShellScope(
      scaffoldKey: _scaffoldKey,
      selectTab: _selectTab,
      selectedTabIndex: _index,
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: scheme.surfaceContainerLowest,
        drawer: CustomerDrawer(
          tabs: customerPortalTabs,
          selectedTabIndex: _index,
          onSelectTab: _selectTab,
        ),
        body: IndexedStack(
          index: _index,
          children: [
            CustomerHomeScreen(
              onOpenLeads: () => _selectTab(1),
              onOpenSupport: () => _selectTab(2),
            ),
            const CustomerLeadsScreen(),
            const CustomerSupportScreen(),
            const CustomerAccountScreen(),
          ],
        ),
      ),
    );
  }
}

String customerGreeting() {
  final hour = DateTime.now().hour;
  if (hour < 12) return 'Good morning';
  if (hour < 17) return 'Good afternoon';
  return 'Good evening';
}

class CustomerInfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? tint;

  const CustomerInfoTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.tint,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = tint ?? scheme.primary;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  value.trim().isEmpty ? '—' : value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
