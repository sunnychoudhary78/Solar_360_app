// FULL REWRITE: Billbook Dashboard
// Keeps existing Riverpod provider, DashboardModel, permissions and routes.

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:solar_sales/core/theme/app_design.dart';
import 'package:solar_sales/features/auth/presentation/providers/auth_provider.dart';
import 'package:solar_sales/features/auth/presentation/providers/auth_state.dart';
import 'package:solar_sales/features/shell/presentation/nav_destinations.dart';
import 'package:solar_sales/shared/constants/role_taglines.dart';
import 'package:solar_sales/shared/module/module_access.dart';
import 'package:solar_sales/shared/utils/formatters.dart';
import 'package:solar_sales/shared/widgets/app_bar.dart';
import 'package:solar_sales/shared/widgets/async_states.dart';
import 'package:solar_sales/shared/widgets/home/shared_home_layout.dart';
import 'package:solar_sales/shared/widgets/premium_feature_components.dart';

import '../../data/models/dashboard_model.dart';
import '../providers/dashboard_providers.dart';

String _timeGreeting() {
  final hour = DateTime.now().hour;
  if (hour < 12) return 'Good morning';
  if (hour < 17) return 'Good afternoon';
  return 'Good evening';
}

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(dashboardProvider);
    final auth = ref.watch(authProvider);
    final scheme = Theme.of(context).colorScheme;
    final firstName = auth.profile?.name.split(' ').first ?? 'there';
    final roleSubtitle = RoleTaglines.forRole(auth.profile?.roleName);

    const green = Color(0xFF0E9F6E);
    const greenDark = Color(0xFF087F5B);

    final header = HomeHeaderData(
      title: firstName,
      subtitle: roleSubtitle.isEmpty
          ? "Here's what's happening with your business today."
          : roleSubtitle,
      badge: const StatusPill(
        label: 'Billbook',
        color: green,
        icon: Icons.auto_graph_rounded,
      ),
      // DO NOT CHANGE: existing Billbook header image.
      heroImage: 'assets/images/billbook_header.png',
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFF3FBF7),
          Color(0xFFE8F7F0),
          Color(0xFFF8FCFA),
        ],
      ),
      accentColor: green,
    );

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: AppAppBar(
        title: 'Billbook',
        subtitle: '${_timeGreeting()}, $firstName',
        largeTitle: true,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(dashboardProvider),
          ),
        ],
      ),
      body: async.when(
        loading: () => const LoadingState(),
        error: (e, _) => ErrorState(
          message: cleanError(e),
          onRetry: () => ref.invalidate(dashboardProvider),
        ),
        data: (data) => SharedHomeLayout(
          header: header,
          greeting: _timeGreeting(),
          onRefresh: () async => ref.invalidate(dashboardProvider),
          child: _BillBookContent(
            data: data,
            auth: auth,
            accentColor: green,
            accentDark: greenDark,
          ),
        ),
      ),
    );
  }
}

class _BillBookContent extends StatelessWidget {
  const _BillBookContent({
    required this.data,
    required this.auth,
    required this.accentColor,
    required this.accentDark,
  });

  final DashboardModel data;
  final AuthState auth;
  final Color accentColor;
  final Color accentDark;

  @override
  Widget build(BuildContext context) {
    final tabs = NavDestinations.shellTabs(AppModules.billbook, auth.hasPermission);
    final quickDests = NavDestinations.quickActions(AppModules.billbook, auth.hasPermission);
    final pending = data.pendingQuotations + data.pendingInvoices + data.pendingItemsCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (auth.hasPermission('stats.read')) ...[
          _Section(child: _SalesHeroCard(value: formatInr(data.totalSales), accentColor: accentColor, accentDark: accentDark)),
          const SizedBox(height: 14),
          _Section(child: _KpiRow(
            customers: data.customersCount,
            invoices: data.invoicesCount,
            quotations: data.quotationsCount,
            pending: pending,
            accentColor: accentColor,
            onCustomers: () => Navigator.pushNamed(context, '/customers'),
            onInvoices: () => Navigator.pushNamed(context, '/invoices'),
            onQuotations: () => Navigator.pushNamed(context, '/quotations'),
            onPending: () => Navigator.pushNamed(context, '/quotations/approvals'),
          )),
          const SizedBox(height: 22),
          const _SectionTitle(title: 'Today at a glance', subtitle: 'Your Billbook activity in one view'),
          const SizedBox(height: 8),
          _Section(child: _OverviewGrid(
            pending: pending,
            lowStock: data.lowStockCount,
            invoices: data.invoicesCount,
            quotations: data.quotationsCount,
            accentColor: accentColor,
            onPending: () => Navigator.pushNamed(context, '/quotations/approvals'),
            onLowStock: () => Navigator.pushNamed(context, '/inventory/low-stock'),
            onInvoices: () => Navigator.pushNamed(context, '/invoices'),
            onQuotations: () => Navigator.pushNamed(context, '/quotations'),
          )),
          const SizedBox(height: 22),
          const _SectionTitle(title: 'Sales analytics', subtitle: 'Track your sales performance over time'),
          const SizedBox(height: 8),
          _Section(child: SizedBox(
            height: 330,
            child: data.salesTrend.isEmpty ? const _EmptyChart() : _SalesTrendChart(points: data.salesTrend, accentColor: accentColor),
          )),
        ],
        const SizedBox(height: 22),
        const _SectionTitle(title: 'Quick actions', subtitle: 'Jump directly into your most-used features'),
        const SizedBox(height: 8),
        QuickActionGrid(
          destinations: quickDests,
          onDestination: (dest) => navigateDestination(context, dest, tabs),
        ),
        const SizedBox(height: 22),
        const _SectionTitle(title: 'Needs attention', subtitle: 'Items that may need your action'),
        const SizedBox(height: 8),
        _Section(child: _AttentionPanel(
          pending: pending,
          lowStock: data.lowStockCount,
          accentColor: accentColor,
          onPending: () => Navigator.pushNamed(context, '/quotations/approvals'),
          onLowStock: () => Navigator.pushNamed(context, '/inventory/low-stock'),
        )),
        const SizedBox(height: 22),
        const _SectionTitle(title: 'Create new', subtitle: 'Start a new Billbook record'),
        const SizedBox(height: 8),
        _Section(child: _CreateActions(
          auth: auth,
          accentColor: accentColor,
          onCustomer: () => Navigator.pushNamed(context, '/customers/form'),
          onQuotation: () => Navigator.pushNamed(context, '/quotations/form'),
          onInvoice: () => Navigator.pushNamed(context, '/invoices/new'),
          onItem: () => Navigator.pushNamed(context, '/items/form'),
          onWarehouse: () => Navigator.pushNamed(context, '/inventory/warehouses'),
        )),
        const SizedBox(height: 18),
        _Section(child: _FooterHint(accentColor: accentColor)),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: child,
      );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 3),
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _SalesHeroCard extends StatelessWidget {
  const _SalesHeroCard({required this.value, required this.accentColor, required this.accentDark});
  final String value;
  final Color accentColor;
  final Color accentDark;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 16, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [accentDark, accentColor, const Color(0xFF35B985)]),
        boxShadow: [BoxShadow(color: accentColor.withValues(alpha: .25), blurRadius: 26, offset: const Offset(0, 12))],
      ),
      child: Stack(children: [
        Positioned(right: -25, top: -50, child: _Circle(size: 150, color: Colors.white.withValues(alpha: .08))),
        Positioned(right: 45, bottom: -70, child: _Circle(size: 140, color: Colors.white.withValues(alpha: .06))),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 38, height: 38, decoration: BoxDecoration(color: Colors.white.withValues(alpha: .16), borderRadius: BorderRadius.circular(13)), child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 20)),
              const SizedBox(width: 10),
              const Text('Total sales', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 18),
            Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 31, fontWeight: FontWeight.w900, letterSpacing: -.8)),
            const SizedBox(height: 6),
            Text('Business performance', style: TextStyle(color: Colors.white.withValues(alpha: .78), fontSize: 12, fontWeight: FontWeight.w600)),
          ])),
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7), decoration: BoxDecoration(color: Colors.white.withValues(alpha: .14), borderRadius: BorderRadius.circular(14)), child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.trending_up_rounded, size: 16, color: Colors.white), SizedBox(width: 4), Text('Overview', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800))])),
        ]),
      ]),
    );
  }
}

class _Circle extends StatelessWidget {
  const _Circle({required this.size, required this.color});
  final double size;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, color: color));
}

class _KpiRow extends StatelessWidget {
  const _KpiRow({required this.customers, required this.invoices, required this.quotations, required this.pending, required this.accentColor, required this.onCustomers, required this.onInvoices, required this.onQuotations, required this.onPending});
  final int customers, invoices, quotations, pending;
  final Color accentColor;
  final VoidCallback onCustomers, onInvoices, onQuotations, onPending;
  @override
  Widget build(BuildContext context) => SizedBox(
        height: 118,
        child: ListView(scrollDirection: Axis.horizontal, physics: const BouncingScrollPhysics(), children: [
          _KpiCard(label: 'Customers', value: '$customers', icon: Icons.people_alt_rounded, accent: accentColor, onTap: onCustomers),
          const SizedBox(width: 10),
          _KpiCard(label: 'Invoices', value: '$invoices', icon: Icons.receipt_long_rounded, accent: const Color(0xFF2563EB), onTap: onInvoices),
          const SizedBox(width: 10),
          _KpiCard(label: 'Quotations', value: '$quotations', icon: Icons.request_quote_rounded, accent: const Color(0xFF8B5CF6), onTap: onQuotations),
          const SizedBox(width: 10),
          _KpiCard(label: 'Pending', value: '$pending', icon: Icons.pending_actions_rounded, accent: const Color(0xFFF59E0B), onTap: onPending),
        ]),
      );
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.label, required this.value, required this.icon, required this.accent, required this.onTap});
  final String label, value;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 150,
      child: Material(color: Colors.transparent, child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: scheme.surfaceContainerLowest, borderRadius: BorderRadius.circular(20), border: Border.all(color: scheme.outlineVariant.withValues(alpha: .45)), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .035), blurRadius: 16, offset: const Offset(0, 6))]),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(width: 34, height: 34, decoration: BoxDecoration(color: accent.withValues(alpha: .11), borderRadius: BorderRadius.circular(11)), child: Icon(icon, color: accent, size: 18)),
            const Spacer(),
            Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
            Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
          ]),
        ),
      )),
    );
  }
}

class _OverviewGrid extends StatelessWidget {
  const _OverviewGrid({required this.pending, required this.lowStock, required this.invoices, required this.quotations, required this.accentColor, required this.onPending, required this.onLowStock, required this.onInvoices, required this.onQuotations});
  final int pending, lowStock, invoices, quotations;
  final Color accentColor;
  final VoidCallback onPending, onLowStock, onInvoices, onQuotations;
  @override
  Widget build(BuildContext context) => GridView.count(
        crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.55, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        children: [
          _OverviewCard(title: 'Pending approvals', value: '$pending', subtitle: 'Needs review', icon: Icons.fact_check_rounded, accent: const Color(0xFFF59E0B), onTap: onPending),
          _OverviewCard(title: 'Low stock', value: '$lowStock', subtitle: 'Check inventory', icon: Icons.inventory_2_rounded, accent: const Color(0xFFEF4444), onTap: onLowStock),
          _OverviewCard(title: 'Invoices', value: '$invoices', subtitle: 'Documents', icon: Icons.receipt_long_rounded, accent: const Color(0xFF2563EB), onTap: onInvoices),
          _OverviewCard(title: 'Quotations', value: '$quotations', subtitle: 'Quotes created', icon: Icons.description_rounded, accent: accentColor, onTap: onQuotations),
        ],
      );
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({required this.title, required this.value, required this.subtitle, required this.icon, required this.accent, required this.onTap});
  final String title, value, subtitle;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(color: Colors.transparent, child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: scheme.surfaceContainerLowest, borderRadius: BorderRadius.circular(20), border: Border.all(color: scheme.outlineVariant.withValues(alpha: .45))),
        child: Row(children: [
          Container(width: 40, height: 40, decoration: BoxDecoration(color: accent.withValues(alpha: .11), borderRadius: BorderRadius.circular(13)), child: Icon(icon, color: accent, size: 19)),
          const SizedBox(width: 11),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 3),
            Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
            Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
          ])),
          Icon(Icons.chevron_right_rounded, size: 20, color: scheme.onSurfaceVariant.withValues(alpha: .6)),
        ]),
      ),
    ));
  }
}

class _AttentionPanel extends StatelessWidget {
  const _AttentionPanel({required this.pending, required this.lowStock, required this.accentColor, required this.onPending, required this.onLowStock});
  final int pending, lowStock;
  final Color accentColor;
  final VoidCallback onPending, onLowStock;
  @override
  Widget build(BuildContext context) {
    if (pending == 0 && lowStock == 0) {
      return Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: accentColor.withValues(alpha: .07), borderRadius: BorderRadius.circular(20), border: Border.all(color: accentColor.withValues(alpha: .16))), child: Row(children: [
        Container(width: 42, height: 42, decoration: BoxDecoration(color: accentColor.withValues(alpha: .12), shape: BoxShape.circle), child: Icon(Icons.check_rounded, color: accentColor)),
        const SizedBox(width: 12),
        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Everything looks good', style: TextStyle(fontWeight: FontWeight.w800)), SizedBox(height: 3), Text('There are no pending items requiring attention.', style: TextStyle(fontSize: 12))])),
      ]));
    }
    return Column(children: [
      if (pending > 0) _AttentionTile(title: 'Pending approvals', subtitle: '$pending item${pending == 1 ? '' : 's'} waiting for review', icon: Icons.pending_actions_rounded, color: const Color(0xFFF59E0B), onTap: onPending),
      if (pending > 0 && lowStock > 0) const SizedBox(height: 10),
      if (lowStock > 0) _AttentionTile(title: 'Low stock', subtitle: '$lowStock item${lowStock == 1 ? '' : 's'} need attention', icon: Icons.warning_amber_rounded, color: const Color(0xFFEF4444), onTap: onLowStock),
    ]);
  }
}

class _AttentionTile extends StatelessWidget {
  const _AttentionTile({required this.title, required this.subtitle, required this.icon, required this.color, required this.onTap});
  final String title, subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(color: Colors.transparent, child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(18), child: Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: scheme.surfaceContainerLowest, borderRadius: BorderRadius.circular(18), border: Border.all(color: color.withValues(alpha: .18))), child: Row(children: [
      Container(width: 42, height: 42, decoration: BoxDecoration(color: color.withValues(alpha: .11), borderRadius: BorderRadius.circular(13)), child: Icon(icon, color: color, size: 20)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)), const SizedBox(height: 3), Text(subtitle, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11.5))])),
      Icon(Icons.arrow_forward_ios_rounded, size: 14, color: scheme.onSurfaceVariant),
    ]))));
  }
}

class _CreateActions extends StatelessWidget {
  const _CreateActions({
    required this.auth,
    required this.accentColor,
    required this.onCustomer,
    required this.onQuotation,
    required this.onInvoice,
    required this.onItem,
    required this.onWarehouse,
  });
  final AuthState auth;
  final Color accentColor;
  final VoidCallback onCustomer, onQuotation, onInvoice, onItem, onWarehouse;
  @override
  Widget build(BuildContext context) {
    final actions = <Widget>[
      if (auth.hasPermission('customer.create')) _CreateAction(label: 'Customer', subtitle: 'Add customer', icon: Icons.person_add_alt_rounded, color: accentColor, onTap: onCustomer),
      if (auth.hasPermission('quotation.create')) _CreateAction(label: 'Quotation', subtitle: 'Create quote', icon: Icons.note_add_outlined, color: const Color(0xFF8B5CF6), onTap: onQuotation),
      if (auth.hasPermission('invoice.create')) _CreateAction(label: 'Invoice', subtitle: 'Create invoice', icon: Icons.receipt_long_outlined, color: const Color(0xFF2563EB), onTap: onInvoice),
      if (auth.hasPermission('item.create')) _CreateAction(label: 'Item', subtitle: 'Add product', icon: Icons.add_box_outlined, color: const Color(0xFFF59E0B), onTap: onItem),
      if (auth.hasPermission('inventory.create') ||
          auth.hasPermission('inventory.read'))
        _CreateAction(
          label: 'Warehouse',
          subtitle: 'Add warehouse',
          icon: Icons.warehouse_outlined,
          color: const Color(0xFF0E9F6E),
          onTap: onWarehouse,
        ),
    ];
    return Wrap(spacing: 10, runSpacing: 10, children: actions);
  }
}

class _CreateAction extends StatelessWidget {
  const _CreateAction({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final width = (MediaQuery.sizeOf(context).width - 48) / 2;

    return SizedBox(
      width: width,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: .45),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .11),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 19),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FooterHint extends StatelessWidget {
  const _FooterHint({required this.accentColor});
  final Color accentColor;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12), decoration: BoxDecoration(color: scheme.surfaceContainerLow, borderRadius: BorderRadius.circular(16), border: Border.all(color: scheme.outlineVariant.withValues(alpha: .35))), child: Row(children: [
      Icon(Icons.auto_awesome_rounded, color: accentColor, size: 17),
      const SizedBox(width: 8),
      Expanded(child: Text('Billbook dashboard • Keep your sales and documents organized.', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600))),
    ]));
  }
}

class _SalesTrendChart extends StatelessWidget {
  const _SalesTrendChart({required this.points, required this.accentColor});
  final List<SalesPoint> points;
  final Color accentColor;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fmt = DateFormat('MMM');
    if (points.isEmpty) return const _EmptyChart();
    final values = points.map((p) => p.totalSales.toDouble()).toList();
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final maxY = maxValue <= 0 ? 100.0 : maxValue * 1.2;
    final interval = maxY / 4;
    return Container(padding: const EdgeInsets.fromLTRB(15, 16, 15, 10), decoration: BoxDecoration(color: scheme.surfaceContainerLowest, borderRadius: BorderRadius.circular(22), border: Border.all(color: scheme.outlineVariant.withValues(alpha: .45)), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .035), blurRadius: 18, offset: const Offset(0, 7))]), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Sales trend', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)), const SizedBox(height: 3), Text('Sales performance over time', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant))])), Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: accentColor.withValues(alpha: .09), borderRadius: BorderRadius.circular(11)), child: Icon(Icons.trending_up_rounded, size: 17, color: accentColor))]),
      const SizedBox(height: 18),
      Expanded(child: LineChart(LineChartData(
        minY: 0, maxY: maxY, clipData: const FlClipData.none(),
        lineTouchData: LineTouchData(enabled: true, touchTooltipData: LineTouchTooltipData(getTooltipColor: (_) => scheme.inverseSurface, getTooltipItems: (spots) => spots.map((spot) { final i = spot.x.toInt(); if (i < 0 || i >= points.length) return null; final p = points[i]; final month = p.month == null ? '' : fmt.format(p.month!); return LineTooltipItem('$month\n${formatInr(p.totalSales)}', TextStyle(color: scheme.onInverseSurface, fontSize: 11, fontWeight: FontWeight.w700)); }).toList())),
        gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: interval, getDrawingHorizontalLine: (_) => FlLine(color: scheme.outlineVariant.withValues(alpha: .28), strokeWidth: 1)),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 42, interval: interval, getTitlesWidget: (value, meta) => Text(NumberFormat.compact().format(value), style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant, fontSize: 9)))),
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 25, getTitlesWidget: (value, meta) { final i = value.toInt(); if (i < 0 || i >= points.length) return const SizedBox.shrink(); final m = points[i].month; return Padding(padding: const EdgeInsets.only(top: 7), child: Text(m == null ? '' : fmt.format(m), style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant, fontSize: 9.5, fontWeight: FontWeight.w600))); })),
        ),
        lineBarsData: [LineChartBarData(
          spots: List.generate(points.length, (i) => FlSpot(i.toDouble(), points[i].totalSales.toDouble())), isCurved: true, curveSmoothness: .25, color: accentColor, barWidth: 3, isStrokeCapRound: true,
          dotData: FlDotData(show: true, getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(radius: 3.7, color: scheme.surface, strokeWidth: 2.3, strokeColor: accentColor)),
          belowBarData: BarAreaData(show: true, gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [accentColor.withValues(alpha: .22), accentColor.withValues(alpha: .015)])),
        )],
      ))),
    ]));
  }
}

class _EmptyChart extends StatelessWidget {
  const _EmptyChart();
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(width: double.infinity, decoration: BoxDecoration(color: scheme.surfaceContainerLowest, borderRadius: BorderRadius.circular(22), border: Border.all(color: scheme.outlineVariant.withValues(alpha: .45))), child: Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 56, height: 56, decoration: BoxDecoration(color: scheme.primary.withValues(alpha: .10), borderRadius: BorderRadius.circular(18)), child: Icon(Icons.show_chart_rounded, size: 28, color: scheme.primary)),
      const SizedBox(height: 12),
      Text('No sales data yet', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
      const SizedBox(height: 4),
      Text('The sales trend will appear after invoice data is available.', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
    ]))));
  }
}
