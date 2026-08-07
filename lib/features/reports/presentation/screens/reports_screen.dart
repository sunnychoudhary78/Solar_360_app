import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:solar_sales/core/theme/app_design.dart';
import 'package:solar_sales/core/widgets/status_badge.dart';
import 'package:solar_sales/shared/utils/formatters.dart';
import 'package:solar_sales/shared/widgets/app_bar.dart';
import 'package:solar_sales/shared/widgets/async_states.dart';
import 'package:solar_sales/shared/widgets/premium_feature_components.dart';

import '../providers/reports_providers.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(reportsProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: AppAppBar(
        title: 'Reports',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(reportsProvider),
          ),
        ],
      ),
      body: async.when(
        loading: () => const LoadingState(),
        error: (e, _) => ErrorState(
          message: cleanError(e),
          onRetry: () => ref.invalidate(reportsProvider),
        ),
        data: (data) {
          final totalSalesVal = data.sales.fold<double>(
            0,
            (sum, item) => sum + item.totalSales,
          );

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(reportsProvider),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                const PageHeader(
                  icon: Icons.analytics_rounded,
                  title: 'Executive Overview',
                  subtitle:
                      'Real-time financial performance and inventory health',
                  margin: EdgeInsets.zero,
                ),
                const SizedBox(height: AppSpacing.md),

                MetricGrid(
                  crossAxisCount: 3,
                  childAspectRatio: 0.95,
                  spacing: 10,
                  children: [
                    MetricTile(
                      compact: true,
                      label: 'Total Revenue',
                      value: formatInr(totalSalesVal),
                      icon: Icons.payments_outlined,
                    ),
                    MetricTile(
                      compact: true,
                      label: 'Invoices',
                      value: '${data.invoices.length}',
                      icon: Icons.receipt_long_outlined,
                    ),
                    MetricTile(
                      compact: true,
                      label: 'Quotations',
                      value: '${data.quotations.length}',
                      icon: Icons.request_quote_outlined,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),

                // --- 2. Sales Trend & Chart Section ---
                _SectionCard(
                  title: 'Sales Performance',
                  subtitle: 'Monthly revenue overview',
                  trailing: Icon(
                    Icons.trending_up_rounded,
                    color: scheme.primary,
                  ),
                  child: data.sales.isEmpty
                      ? const EmptyState(
                          title: 'No sales data available',
                          icon: Icons.show_chart,
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: AppSpacing.sm),
                            SizedBox(
                              height: 180,
                              child: _SalesBarChart(salesData: data.sales),
                            ),
                            const Divider(height: 32),
                            ...data.sales.asMap().entries.map((entry) {
                              final index = entry.key;
                              final row = entry.value;
                              final label = row.month != null
                                  ? DateFormat.yMMMM().format(row.month!)
                                  : '—';
                              return Column(
                                children: [
                                  if (index > 0)
                                    Divider(
                                      height: 1,
                                      color: scheme.outlineVariant.withValues(alpha: 0.3),
                                    ),
                                  _ReportListRow(
                                    leadingIcon: Icons.calendar_month_outlined,
                                    title: label,
                                    subtitle:
                                        '${row.invoiceCount} approved invoices',
                                    value: formatInr(row.totalSales),
                                  ),
                                ],
                              );
                            }),
                          ],
                        ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // --- 3. Stock Health Section ---
                _SectionCard(
                  title: 'Stock & Inventory',
                  subtitle: 'Current item quantities and stock health',
                  trailing: Icon(
                    Icons.inventory_2_outlined,
                    color: scheme.secondary,
                  ),
                  child: data.stock.isEmpty
                      ? const EmptyState(
                          title: 'No stock items found',
                          icon: Icons.inventory_2_outlined,
                        )
                      : Column(
                          children: data.stock.asMap().entries.map((entry) {
                            final index = entry.key;
                            final s = entry.value;
                            final statusColor = s.isLowStock
                                ? scheme.error
                                : scheme.primary;

                            return Column(
                              children: [
                                if (index > 0)
                                  Divider(
                                    height: 1,
                                    color: scheme.outlineVariant.withValues(alpha: 0.3),
                                  ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: AppSpacing.sm,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        s.isLowStock
                                            ? Icons.warning_amber_rounded
                                            : Icons
                                                  .check_circle_outline_rounded,
                                        color: statusColor,
                                        size: 20,
                                      ),
                                      const SizedBox(width: AppSpacing.sm),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              s.itemName,
                                              style: theme.textTheme.bodyMedium
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                            ),
                                            Text(
                                              s.warehouseName,
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                    color:
                                                        scheme.onSurfaceVariant,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            '${s.currentQuantity} units',
                                            style: theme.textTheme.bodyMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                          const SizedBox(height: 2),
                                          _StockBadge(isLow: s.isLowStock),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // --- 4. Recent Quotations Section ---
                _SectionCard(
                  title: 'Recent Quotations',
                  subtitle: 'Latest generated estimates',
                  child: data.quotations.isEmpty
                      ? const EmptyState(
                          title: 'No recent quotations',
                          icon: Icons.description_outlined,
                        )
                      : Column(
                          children: data.quotations.asMap().entries.map((
                            entry,
                          ) {
                            final index = entry.key;
                            final q = entry.value;
                            return Column(
                              children: [
                                if (index > 0)
                                  Divider(
                                    height: 1,
                                    color: scheme.outlineVariant.withValues(alpha: 0.3),
                                  ),
                                _ReportListRow(
                                  leadingIcon: Icons.description_outlined,
                                  title: q.quotationNumber,
                                  subtitle:
                                      q.customerName ?? 'Unassigned Customer',
                                  value: formatInr(q.totalAmount),
                                  badge: StatusBadge.forStatus(q.status),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // --- 5. Recent Invoices Section ---
                _SectionCard(
                  title: 'Recent Invoices',
                  subtitle: 'Latest billing statements',
                  child: data.invoices.isEmpty
                      ? const EmptyState(
                          title: 'No recent invoices',
                          icon: Icons.receipt_long_outlined,
                        )
                      : Column(
                          children: data.invoices.asMap().entries.map((entry) {
                            final index = entry.key;
                            final inv = entry.value;
                            return Column(
                              children: [
                                if (index > 0)
                                  Divider(
                                    height: 1,
                                    color: scheme.outlineVariant.withValues(alpha: 0.3),
                                  ),
                                _ReportListRow(
                                  leadingIcon: Icons.receipt_outlined,
                                  title: inv.invoiceNumber,
                                  subtitle:
                                      inv.customerName ?? 'Unassigned Customer',
                                  value: formatInr(inv.totalAmount),
                                  badge: StatusBadge.forStatus(inv.status),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// =============================================================================
// CLEAN REFACTORED SUB-COMPONENTS (NO NESTED CONTAINERS)
// =============================================================================

class _SectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;

  const _SectionCard({
    required this.title,
    this.subtitle,
    this.trailing,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PremiumCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            child,
          ],
        ),
      ),
    );
  }
}

class _ReportListRow extends StatelessWidget {
  final IconData leadingIcon;
  final String title;
  final String subtitle;
  final String value;
  final Widget? badge;

  const _ReportListRow({
    required this.leadingIcon,
    required this.title,
    required this.subtitle,
    required this.value,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Icon(leadingIcon, size: 20, color: scheme.onSurfaceVariant),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (badge != null) ...[const SizedBox(height: 2), badge!],
            ],
          ),
        ],
      ),
    );
  }
}

class _StockBadge extends StatelessWidget {
  final bool isLow;

  const _StockBadge({required this.isLow});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = isLow ? scheme.error : const Color(0xFF059669);

    return Text(
      isLow ? 'LOW STOCK' : 'IN STOCK',
      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
    );
  }
}

class _SalesBarChart extends StatelessWidget {
  final List<dynamic> salesData;

  const _SalesBarChart({required this.salesData});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    double maxSales = 1000;
    for (var item in salesData) {
      if (item.totalSales > maxSales) maxSales = item.totalSales.toDouble();
    }

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxSales * 1.15,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => scheme.surfaceContainerHighest,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final item = salesData[groupIndex];
              final dateStr = item.month != null
                  ? DateFormat.MMM().format(item.month!)
                  : '';
              return BarTooltipItem(
                '$dateStr\n',
                TextStyle(color: scheme.onSurface, fontWeight: FontWeight.bold),
                children: [
                  TextSpan(
                    text: formatInr(rod.toY),
                    style: TextStyle(
                      color: scheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (double value, TitleMeta meta) {
                final index = value.toInt();
                if (index < 0 || index >= salesData.length) {
                  return const SizedBox.shrink();
                }
                final item = salesData[index];
                final text = item.month != null
                    ? DateFormat.MMM().format(item.month!)
                    : '';
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    text,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: salesData.asMap().entries.map((entry) {
          final index = entry.key;
          final row = entry.value;
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: (row.totalSales as num).toDouble(),
                gradient: LinearGradient(
                  colors: [
                    scheme.primary,
                    Color.lerp(scheme.primary, scheme.secondary, 0.55)!,
                  ],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
                width: 16,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(6),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}
