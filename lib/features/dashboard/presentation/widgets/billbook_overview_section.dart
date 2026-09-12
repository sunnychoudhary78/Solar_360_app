import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:solar_sales/features/dashboard/data/models/dashboard_model.dart';
import 'package:solar_sales/shared/utils/formatters.dart';
import 'package:solar_sales/shared/widgets/persistent_chart_touch.dart';

const _emerald = Color(0xFF0D7A5F);
const _sky = Color(0xFF0EA5E9);
const _amber = Color(0xFFF59E0B);
const _violet = Color(0xFF8B5CF6);
const _rose = Color(0xFFF43F5E);
const _teal = Color(0xFF10B981);
const _slate = Color(0xFF94A3B8);

const _statusKeys = [
  'draft',
  'pending_approval',
  'approved',
  'rejected',
  'sent',
];

const _statusMeta = <String, ({String label, Color color})>{
  'draft': (label: 'Draft', color: _slate),
  'pending_approval': (label: 'Pending', color: _amber),
  'approved': (label: 'Approved', color: _teal),
  'rejected': (label: 'Rejected', color: _rose),
  'sent': (label: 'Sent', color: _sky),
};

const _barColors = [
  Color(0xFF0D7A5F),
  Color(0xFF0EA5E9),
  Color(0xFFF59E0B),
  Color(0xFF8B5CF6),
  Color(0xFF06B6D4),
  Color(0xFFF43F5E),
  Color(0xFF84CC16),
];

/// Web-parity Billbook overview shown below the unchanged greeting card.
class BillbookOverviewSection extends StatelessWidget {
  const BillbookOverviewSection({
    super.key,
    required this.data,
    required this.accentColor,
    required this.onOpen,
    this.canOpenReports = false,
  });

  final DashboardModel data;
  final Color accentColor;
  final bool canOpenReports;
  final void Function(String route) onOpen;

  @override
  Widget build(BuildContext context) {
    final mom = data.salesMomPercent;
    final momHint = mom != 0
        ? '${mom >= 0 ? '↑' : '↓'} ${mom.abs()}% vs last month'
        : 'All-time billed';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _OverviewHeader(
          canOpenReports: canOpenReports,
          onReports: () => onOpen('/reports'),
        ),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.42,
          children: [
            _TintedMetric(
              label: 'Total sales',
              value: formatCompactInr(data.totalSales),
              hint: momHint,
              tone: _MetricTone.emerald,
              onTap: canOpenReports ? () => onOpen('/reports') : null,
            ),
            _TintedMetric(
              label: 'This month',
              value: formatCompactInr(data.thisMonthSales),
              hint: '${data.thisMonthInvoices} invoices',
              tone: _MetricTone.sky,
              onTap: () => onOpen('/invoices'),
            ),
            _TintedMetric(
              label: 'GST collected',
              value: formatCompactInr(data.gstCollected),
              hint: 'On billed invoices',
              tone: _MetricTone.violet,
              onTap: () => onOpen('/invoices'),
            ),
            _TintedMetric(
              label: 'Quote pipeline',
              value: formatCompactInr(data.quotationPipelineValue),
              hint: 'Approved + sent quotes',
              tone: _MetricTone.amber,
              onTap: () => onOpen('/quotations'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _PanelCard(
          title: 'Invoice volume',
          subtitle: 'Monthly invoice count trend',
          child: SizedBox(
            height: 200,
            child: data.salesTrend.isEmpty
                ? const _ChartEmpty(message: 'No invoice trend yet')
                : _InvoiceVolumeChart(points: data.salesTrend),
          ),
        ),
        const SizedBox(height: 12),
        _PanelCard(
          title: 'Quotes vs invoices',
          subtitle: 'Status comparison',
          child: SizedBox(
            height: 210,
            child: _QuotesVsInvoicesChart(
              quotes: data.quotationStatus,
              invoices: data.invoiceStatus,
            ),
          ),
        ),
        const SizedBox(height: 12),
        _PanelCard(
          title: 'Win & stock health',
          subtitle: 'Radial scorecards',
          child: Row(
            children: [
              Expanded(
                child: _RadialScore(
                  label: 'Win rate',
                  percent: data.conversionPercent,
                  color: _violet,
                ),
              ),
              Expanded(
                child: _RadialScore(
                  label: 'Stock',
                  percent: data.inventoryHealthPercent ?? 0,
                  color: _teal,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _PanelCard(
          title: 'Monthly revenue',
          subtitle: 'Last 12 months sales trend',
          child: SizedBox(
            height: 220,
            child: data.salesTrend.isEmpty
                ? const _ChartEmpty(message: 'No revenue data yet')
                : _MonthlyRevenueChart(points: data.salesTrend),
          ),
        ),
        const SizedBox(height: 12),
        _PanelCard(
          title: 'This month vs last month',
          subtitle: 'Sales and invoice count',
          child: SizedBox(
            height: 220,
            child: _MonthCompareChart(
              lastSales: data.lastMonthSales,
              thisSales: data.thisMonthSales,
              lastInvoices: data.lastMonthInvoices,
              thisInvoices: data.thisMonthInvoices,
            ),
          ),
        ),
        const SizedBox(height: 12),
        _PanelCard(
          title: 'Sales & billing',
          subtitle:
              '${data.invoicesCount} invoices · avg ${formatCompactInr(data.avgInvoiceValue)}',
          actionLabel: 'Open',
          onAction: () => onOpen('/invoices'),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _TintedMetric(
                      label: 'Customers',
                      value: '${data.customersCount}',
                      tone: _MetricTone.sky,
                      compact: true,
                      onTap: () => onOpen('/customers'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _TintedMetric(
                      label: 'Invoices',
                      value: '${data.invoicesCount}',
                      tone: _MetricTone.emerald,
                      compact: true,
                      onTap: () => onOpen('/invoices'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _TintedMetric(
                      label: 'Win rate',
                      value: '${data.conversionPercent}%',
                      tone: _MetricTone.violet,
                      compact: true,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _TintedMetric(
                      label: 'Pending',
                      value: '${data.pendingTotal}',
                      tone: data.pendingTotal > 0
                          ? _MetricTone.orange
                          : _MetricTone.slate,
                      compact: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 200,
                child: data.salesTrend.isEmpty
                    ? const _ChartEmpty(message: 'No sales trend yet')
                    : _SalesBillingChart(points: data.salesTrend),
              ),
              const SizedBox(height: 12),
              _StatusPills(counts: data.invoiceStatus),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _PanelCard(
          title: 'Quotation pipeline',
          subtitle:
              '${data.quotationsCount} total · ${data.pendingQuotations} awaiting approval',
          actionLabel: 'Open',
          onAction: () => onOpen('/quotations'),
          child: Column(
            children: [
              _DonutWithLegend(
                counts: data.quotationStatus,
                centerLabel: 'Quotes',
                centerValue: '${data.quotationsCount}',
                emptyLabel: 'No quotations yet',
              ),
              const SizedBox(height: 12),
              _PipelineList(counts: data.quotationStatus),
              const SizedBox(height: 14),
              _LabeledProgress(
                label: 'Quote → invoice conversion',
                percent: data.conversionPercent,
                color: _violet,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _TintedMetric(
                      label: 'Sent quotes',
                      value: '${data.sentQuotations}',
                      tone: _MetricTone.sky,
                      compact: true,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _TintedMetric(
                      label: 'Invoiced',
                      value: '${data.invoicesFromQuotes}',
                      tone: _MetricTone.emerald,
                      compact: true,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _PanelCard(
          title: 'Inventory',
          subtitle:
              '${data.approvedItemsCount} approved products · health ${data.inventoryHealthPercent ?? '—'}%',
          actionLabel: 'Open',
          onAction: () => onOpen('/inventory'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _TintedMetric(
                      label: 'Products',
                      value: '${data.itemsCount}',
                      tone: _MetricTone.slate,
                      compact: true,
                      onTap: () => onOpen('/items'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _TintedMetric(
                      label: 'Approved',
                      value: '${data.approvedItemsCount}',
                      tone: _MetricTone.emerald,
                      compact: true,
                      onTap: () => onOpen('/items'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _TintedMetric(
                      label: 'Healthy',
                      value: '${data.healthyStock}',
                      tone: _MetricTone.teal,
                      compact: true,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _TintedMetric(
                      label: 'Low / out',
                      value: '${data.lowStockCount}',
                      tone: data.lowStockCount > 0
                          ? _MetricTone.rose
                          : _MetricTone.slate,
                      compact: true,
                      onTap: () => onOpen('/inventory/low-stock'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _LabeledProgress(
                label: 'Inventory health',
                percent: data.inventoryHealthPercent ?? 0,
                color: (data.inventoryHealthPercent ?? 0) >= 80
                    ? _teal
                    : _amber,
              ),
              const SizedBox(height: 14),
              Text(
                'LOW STOCK WATCHLIST',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              if (data.lowStock.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: _teal.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _teal.withValues(alpha: 0.18)),
                  ),
                  child: const Text(
                    'All stock levels look healthy',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF065F46),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                )
              else
                _HorizontalValueBars(
                  rows: [
                    for (var i = 0; i < data.lowStock.take(6).length; i++)
                      _BarRow(
                        label: data.lowStock[i].itemName,
                        value: data.lowStock[i].currentQuantity.toDouble(),
                        display:
                            '${data.lowStock[i].currentQuantity}/${data.lowStock[i].minStock}',
                        color: _barColors[i % _barColors.length],
                      ),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _PanelCard(
          title: 'Document status',
          subtitle: 'Quotations + invoices workflow',
          actionLabel: 'Open',
          onAction: canOpenReports ? () => onOpen('/reports') : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _StatusBlock(
                      label: 'Open',
                      value: '${data.openDocs}',
                      background: const Color(0xFFFFFBEB),
                      border: const Color(0xFFFDE68A),
                      foreground: const Color(0xFF78350F),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _StatusBlock(
                      label: 'Completed',
                      value: '${data.completedDocs}',
                      background: const Color(0xFFECFDF5),
                      border: const Color(0xFFA7F3D0),
                      foreground: const Color(0xFF064E3B),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _StatusBlock(
                      label: 'Rejected',
                      value: '${data.rejectedDocs}',
                      background: const Color(0xFFFFF1F2),
                      border: const Color(0xFFFECDD3),
                      foreground: const Color(0xFF9F1239),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _LabeledProgress(
                label: 'Completion',
                percent: data.completionPercent,
                color: _emerald,
              ),
              const SizedBox(height: 14),
              _DonutWithLegend(
                counts: data.invoiceStatus,
                centerLabel: 'Invoices',
                centerValue: '${data.invoicesCount}',
                emptyLabel: 'No invoices yet',
              ),
              const SizedBox(height: 12),
              Text(
                'INVOICE STAGES',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              _StatusPills(counts: data.invoiceStatus),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _PanelCard(
          title: 'Top customers',
          subtitle: 'By billed sales',
          actionLabel: 'Open',
          onAction: () => onOpen('/customers'),
          child: data.topCustomers.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 28),
                  child: Center(
                    child: Text(
                      'No billed customers yet',
                      style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                    ),
                  ),
                )
              : _HorizontalValueBars(
                  rows: [
                    for (var i = 0; i < data.topCustomers.length; i++)
                      _BarRow(
                        label: data.topCustomers[i].name,
                        value: data.topCustomers[i].totalSales,
                        display: formatCompactInr(
                          data.topCustomers[i].totalSales,
                        ),
                        color: _barColors[i % _barColors.length],
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 12),
        _PanelCard(
          title: 'Alerts & shortcuts',
          subtitle: 'Things that need attention',
          child: Column(
            children: [
              _AlertRow(
                label: 'Low stock',
                value: '${data.lowStockCount}',
                icon: Icons.warning_amber_rounded,
                background: data.lowStockCount > 0
                    ? const Color(0xFFFFF1F2)
                    : const Color(0xFFF8FAFC),
                border: data.lowStockCount > 0
                    ? const Color(0xFFFECDD3)
                    : const Color(0xFFE2E8F0),
                foreground: data.lowStockCount > 0
                    ? const Color(0xFF9F1239)
                    : const Color(0xFF334155),
                onTap: () => onOpen('/inventory/low-stock'),
              ),
              const SizedBox(height: 8),
              _AlertRow(
                label: 'Quote approvals',
                value: '${data.pendingQuotations}',
                icon: Icons.description_outlined,
                background: const Color(0xFFFFFBEB),
                border: const Color(0xFFFDE68A),
                foreground: const Color(0xFF78350F),
                onTap: () => onOpen('/quotations/approvals'),
              ),
              const SizedBox(height: 8),
              _AlertRow(
                label: 'Invoice approvals',
                value: '${data.pendingInvoices}',
                icon: Icons.receipt_long_outlined,
                background: const Color(0xFFFFF7ED),
                border: const Color(0xFFFED7AA),
                foreground: const Color(0xFF7C2D12),
                onTap: () => onOpen('/invoices/approvals'),
              ),
              const SizedBox(height: 8),
              _AlertRow(
                label: 'Customers',
                value: '${data.customersCount}',
                icon: Icons.people_alt_outlined,
                background: const Color(0xFFF0F9FF),
                border: const Color(0xFFBAE6FD),
                foreground: const Color(0xFF0C4A6E),
                onTap: () => onOpen('/customers'),
              ),
              const SizedBox(height: 8),
              _AlertRow(
                label: 'Item master',
                value: '${data.itemsCount}',
                icon: Icons.inventory_2_outlined,
                background: const Color(0xFFECFDF5),
                border: const Color(0xFFA7F3D0),
                foreground: const Color(0xFF064E3B),
                onTap: () => onOpen('/items'),
              ),
              if (data.lowStock.isNotEmpty) ...[
                const SizedBox(height: 8),
                for (final stock in data.lowStock.take(4))
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            stock.itemName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          '${stock.currentQuantity}/${stock.minStock}',
                          style: const TextStyle(
                            color: _rose,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
              ] else
                const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Text(
                    'No stock alerts right now',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _MoneyStrip(
          accentColor: accentColor,
          revenue: formatCompactInr(data.totalSales),
          pipeline: formatCompactInr(data.quotationPipelineValue),
          gst: formatCompactInr(data.gstCollected),
          docsSent: '${data.docsSent}',
        ),
      ],
    );
  }
}

class _OverviewHeader extends StatelessWidget {
  const _OverviewHeader({
    required this.canOpenReports,
    required this.onReports,
  });

  final bool canOpenReports;
  final VoidCallback onReports;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Business overview',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 3),
              Text(
                'Sales, billing, stock and pipeline at a glance',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        if (canOpenReports)
          TextButton(
            onPressed: onReports,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFEA580C),
              visualDensity: VisualDensity.compact,
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Full reports',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                ),
                SizedBox(width: 2),
                Icon(Icons.arrow_forward_rounded, size: 14),
              ],
            ),
          ),
      ],
    );
  }
}

class _PanelCard extends StatelessWidget {
  const _PanelCard({
    required this.title,
    required this.subtitle,
    required this.child,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: .45)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .035),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (onAction != null)
                TextButton(
                  onPressed: onAction,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFEA580C),
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        actionLabel ?? 'Open',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(Icons.arrow_forward_rounded, size: 13),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

enum _MetricTone { emerald, sky, amber, rose, violet, orange, slate, teal }

class _TintedMetric extends StatelessWidget {
  const _TintedMetric({
    required this.label,
    required this.value,
    required this.tone,
    this.hint,
    this.onTap,
    this.compact = false,
  });

  final String label;
  final String value;
  final String? hint;
  final _MetricTone tone;
  final VoidCallback? onTap;
  final bool compact;

  ({Color bg, Color border, Color fg}) get _colors {
    switch (tone) {
      case _MetricTone.emerald:
        return (
          bg: const Color(0xFFECFDF5),
          border: const Color(0xFFA7F3D0),
          fg: const Color(0xFF064E3B),
        );
      case _MetricTone.sky:
        return (
          bg: const Color(0xFFF0F9FF),
          border: const Color(0xFFBAE6FD),
          fg: const Color(0xFF0C4A6E),
        );
      case _MetricTone.amber:
        return (
          bg: const Color(0xFFFFFBEB),
          border: const Color(0xFFFDE68A),
          fg: const Color(0xFF78350F),
        );
      case _MetricTone.rose:
        return (
          bg: const Color(0xFFFFF1F2),
          border: const Color(0xFFFECDD3),
          fg: const Color(0xFF9F1239),
        );
      case _MetricTone.violet:
        return (
          bg: const Color(0xFFF5F3FF),
          border: const Color(0xFFDDD6FE),
          fg: const Color(0xFF4C1D95),
        );
      case _MetricTone.orange:
        return (
          bg: const Color(0xFFFFF7ED),
          border: const Color(0xFFFED7AA),
          fg: const Color(0xFF7C2D12),
        );
      case _MetricTone.teal:
        return (
          bg: const Color(0xFFF0FDFA),
          border: const Color(0xFF99F6E4),
          fg: const Color(0xFF134E4A),
        );
      case _MetricTone.slate:
        return (
          bg: const Color(0xFFF8FAFC),
          border: const Color(0xFFE2E8F0),
          fg: const Color(0xFF0F172A),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _colors;
    final body = Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        12,
        compact ? 10 : 12,
        12,
        compact ? 10 : 12,
      ),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: c.fg.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                fontSize: compact ? 18 : 20,
                fontWeight: FontWeight.w900,
                color: c.fg,
                height: 1.1,
              ),
            ),
          ),
          if (hint != null) ...[
            const SizedBox(height: 4),
            Text(
              hint!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: c.fg.withValues(alpha: 0.7),
              ),
            ),
          ],
        ],
      ),
    );

    if (onTap == null) return body;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: body,
      ),
    );
  }
}

class _StatusBlock extends StatelessWidget {
  const _StatusBlock({
    required this.label,
    required this.value,
    required this.background,
    required this.border,
    required this.foreground,
  });

  final String label;
  final String value;
  final Color background;
  final Color border;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
              color: foreground.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }
}

class _LabeledProgress extends StatelessWidget {
  const _LabeledProgress({
    required this.label,
    required this.percent,
    required this.color,
  });

  final String label;
  final int percent;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final pct = percent.clamp(0, 100);
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            Text(
              '$pct%',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: pct / 100,
            minHeight: 8,
            color: color,
            backgroundColor: scheme.surfaceContainerHighest,
          ),
        ),
      ],
    );
  }
}

class _StatusPills extends StatelessWidget {
  const _StatusPills({required this.counts});
  final DocumentStatusCounts counts;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final key in _statusKeys)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _statusMeta[key]!.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(99),
              border: Border.all(
                color: _statusMeta[key]!.color.withValues(alpha: 0.18),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: _statusMeta[key]!.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${_statusMeta[key]!.label} ${counts.valueFor(key)}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _statusMeta[key]!.color,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _DonutWithLegend extends StatelessWidget {
  const _DonutWithLegend({
    required this.counts,
    required this.centerLabel,
    required this.centerValue,
    required this.emptyLabel,
  });

  final DocumentStatusCounts counts;
  final String centerLabel;
  final String centerValue;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    final sections = [
      for (final key in _statusKeys)
        if (counts.valueFor(key) > 0)
          PieChartSectionData(
            value: counts.valueFor(key).toDouble(),
            color: _statusMeta[key]!.color,
            radius: 18,
            showTitle: false,
          ),
    ];
    final total = _statusKeys.fold<int>(0, (s, k) => s + counts.valueFor(k));

    return Row(
      children: [
        SizedBox(
          width: 128,
          height: 128,
          child: total == 0
              ? Center(
                  child: Text(
                    emptyLabel,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                )
              : Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        sectionsSpace: 3,
                        centerSpaceRadius: 38,
                        startDegreeOffset: -90,
                        sections: sections,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          centerLabel,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        Text(
                          centerValue,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            children: [
              for (final key in _statusKeys)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _statusMeta[key]!.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _statusMeta[key]!.label,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ),
                      Text(
                        '${counts.valueFor(key)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PipelineList extends StatelessWidget {
  const _PipelineList({required this.counts});
  final DocumentStatusCounts counts;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: .4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 4, 6, 6),
            child: Text(
              'BY STATUS',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          for (final key in _statusKeys)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _statusMeta[key]!.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _statusMeta[key]!.label,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 28),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDFA),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: const Color(0xFFCCFBF1)),
                      ),
                      child: Text(
                        '${counts.valueFor(key)}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF115E59),
                        ),
                      ),
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

class _BarRow {
  const _BarRow({
    required this.label,
    required this.value,
    required this.display,
    required this.color,
  });
  final String label;
  final double value;
  final String display;
  final Color color;
}

class _HorizontalValueBars extends StatelessWidget {
  const _HorizontalValueBars({required this.rows});
  final List<_BarRow> rows;

  @override
  Widget build(BuildContext context) {
    final maxVal = rows.fold<double>(0, (m, r) => math.max(m, r.value));
    final denom = maxVal <= 0 ? 1.0 : maxVal;
    return Column(
      children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        row.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      row.display,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: row.color,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: math.max(0.06, row.value / denom),
                    minHeight: 8,
                    color: row.color,
                    backgroundColor: const Color(0xFFF1F5F9),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _AlertRow extends StatelessWidget {
  const _AlertRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.background,
    required this.border,
    required this.foreground,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color background;
  final Color border;
  final Color foreground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: foreground),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: foreground,
                  ),
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  color: foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoneyStrip extends StatelessWidget {
  const _MoneyStrip({
    required this.accentColor,
    required this.revenue,
    required this.pipeline,
    required this.gst,
    required this.docsSent,
  });

  final Color accentColor;
  final String revenue;
  final String pipeline;
  final String gst;
  final String docsSent;

  @override
  Widget build(BuildContext context) {
    Widget cell(String label, String value, {IconData? icon}) {
      return Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 12, color: Colors.white70),
                  const SizedBox(width: 3),
                ],
                Flexible(
                  child: Text(
                    label.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                maxLines: 1,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF059669), Color(0xFF0D9488), Color(0xFF0284C7)],
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          cell('Revenue', revenue, icon: Icons.currency_rupee_rounded),
          cell('Pipeline', pipeline),
          cell('GST', gst),
          cell('Docs sent', docsSent),
        ],
      ),
    );
  }
}

class _RadialScore extends StatelessWidget {
  const _RadialScore({
    required this.label,
    required this.percent,
    required this.color,
  });

  final String label;
  final int percent;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final pct = percent.clamp(0, 100);
    return SizedBox(
      height: 160,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 112,
            height: 112,
            child: CircularProgressIndicator(
              value: pct / 100,
              strokeWidth: 11,
              strokeCap: StrokeCap.round,
              color: color,
              backgroundColor: const Color(0xFFF1F5F9),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelSmall),
              Text(
                '$pct%',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChartEmpty extends StatelessWidget {
  const _ChartEmpty({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

String _monthLabel(DateTime? month) {
  if (month == null) return '';
  return DateFormat('MMM yy').format(month);
}

FlTitlesData _chartTitles({
  required BuildContext context,
  required List<String> bottom,
  String Function(double)? leftFormat,
  String Function(double)? rightFormat,
  double? leftInterval,
  double? rightInterval,
}) {
  final scheme = Theme.of(context).colorScheme;
  final style = Theme.of(
    context,
  ).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant, fontSize: 9);
  return FlTitlesData(
    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    rightTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: rightFormat != null,
        reservedSize: 28,
        interval: rightInterval,
        getTitlesWidget: (value, meta) {
          if (rightFormat == null) return const SizedBox.shrink();
          return Text(rightFormat(value), style: style);
        },
      ),
    ),
    leftTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 42,
        interval: leftInterval,
        getTitlesWidget: (value, meta) {
          final text =
              leftFormat?.call(value) ?? NumberFormat.compact().format(value);
          return Text(text, style: style);
        },
      ),
    ),
    bottomTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 22,
        getTitlesWidget: (value, meta) {
          final i = value.toInt();
          if (i < 0 || i >= bottom.length || value != i.toDouble()) {
            return const SizedBox.shrink();
          }
          return Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(bottom[i], style: style),
          );
        },
      ),
    ),
  );
}

class _InvoiceVolumeChart extends StatefulWidget {
  const _InvoiceVolumeChart({required this.points});
  final List<SalesPoint> points;

  @override
  State<_InvoiceVolumeChart> createState() => _InvoiceVolumeChartState();
}

class _InvoiceVolumeChartState extends State<_InvoiceVolumeChart>
    with TimedChartTooltip {

  @override
  Widget build(BuildContext context) {
    final points = widget.points;
    final scheme = Theme.of(context).colorScheme;
    final maxY = math.max(
      1.0,
      points.fold<int>(0, (m, p) => math.max(m, p.invoiceCount)).toDouble(),
    );
    final bars = [
      LineChartBarData(
        spots: [
          for (var i = 0; i < points.length; i++)
            FlSpot(i.toDouble(), points[i].invoiceCount.toDouble()),
        ],
        isCurved: true,
        color: _sky,
        barWidth: 3,
        dotData: const FlDotData(show: true),
      ),
    ];
    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY * 1.2,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(
            color: scheme.outlineVariant.withValues(alpha: .28),
            strokeWidth: 1,
            dashArray: [3, 3],
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: _chartTitles(
          context: context,
          bottom: [for (final p in points) _monthLabel(p.month)],
          leftFormat: (v) => v.round().toString(),
        ),
        showingTooltipIndicators: lineTooltipsAtIndex(
          bars: bars,
          index: selectedTooltipIndex,
        ),
        lineTouchData: LineTouchData(
          handleBuiltInTouches: false,
          touchCallback: (event, response) {
            if (!persistChartTap(event)) return;
            final index = selectedLineSpotIndex(response);
            if (index == null) return;
            showChartTooltip(index);
          },
          touchTooltipData: LineTouchTooltipData(
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipColor: (_) => scheme.inverseSurface,
            getTooltipItems: (spots) => spots.map((spot) {
              final i = spot.x.toInt();
              if (i < 0 || i >= points.length) return null;
              return LineTooltipItem(
                '${_monthLabel(points[i].month)}\n${points[i].invoiceCount} invoices',
                TextStyle(
                  color: scheme.onInverseSurface,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              );
            }).toList(),
          ),
        ),
        lineBarsData: bars,
      ),
    );
  }
}

class _MonthlyRevenueChart extends StatefulWidget {
  const _MonthlyRevenueChart({required this.points});
  final List<SalesPoint> points;

  @override
  State<_MonthlyRevenueChart> createState() => _MonthlyRevenueChartState();
}

class _MonthlyRevenueChartState extends State<_MonthlyRevenueChart>
    with TimedChartTooltip {

  @override
  Widget build(BuildContext context) {
    final points = widget.points;
    final scheme = Theme.of(context).colorScheme;
    final maxY = math.max(
      1.0,
      points.fold<double>(0, (m, p) => math.max(m, p.totalSales)),
    );
    final bars = [
      LineChartBarData(
        spots: [
          for (var i = 0; i < points.length; i++)
            FlSpot(i.toDouble(), points[i].totalSales),
        ],
        isCurved: true,
        color: _emerald,
        barWidth: 3,
        dotData: const FlDotData(show: true),
      ),
    ];
    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY * 1.2,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(
            color: scheme.outlineVariant.withValues(alpha: .28),
            strokeWidth: 1,
            dashArray: [3, 3],
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: _chartTitles(
          context: context,
          bottom: [for (final p in points) _monthLabel(p.month)],
          leftFormat: formatAxisInr,
        ),
        showingTooltipIndicators: lineTooltipsAtIndex(
          bars: bars,
          index: selectedTooltipIndex,
        ),
        lineTouchData: LineTouchData(
          handleBuiltInTouches: false,
          touchCallback: (event, response) {
            if (!persistChartTap(event)) return;
            final index = selectedLineSpotIndex(response);
            if (index == null) return;
            showChartTooltip(index);
          },
          touchTooltipData: LineTouchTooltipData(
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipColor: (_) => scheme.inverseSurface,
            getTooltipItems: (spots) => spots.map((spot) {
              final i = spot.x.toInt();
              if (i < 0 || i >= points.length) return null;
              return LineTooltipItem(
                '${_monthLabel(points[i].month)}\n${formatInr(points[i].totalSales)}',
                TextStyle(
                  color: scheme.onInverseSurface,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              );
            }).toList(),
          ),
        ),
        lineBarsData: bars,
      ),
    );
  }
}

class _QuotesVsInvoicesChart extends StatefulWidget {
  const _QuotesVsInvoicesChart({required this.quotes, required this.invoices});

  final DocumentStatusCounts quotes;
  final DocumentStatusCounts invoices;

  @override
  State<_QuotesVsInvoicesChart> createState() => _QuotesVsInvoicesChartState();
}

class _QuotesVsInvoicesChartState extends State<_QuotesVsInvoicesChart>
    with TimedChartTooltip {

  @override
  Widget build(BuildContext context) {
    final quotes = widget.quotes;
    final invoices = widget.invoices;
    final scheme = Theme.of(context).colorScheme;
    final maxY = math.max(
      1,
      _statusKeys.fold<int>(
        0,
        (m, k) =>
            math.max(m, math.max(quotes.valueFor(k), invoices.valueFor(k))),
      ),
    );
    return Column(
      children: [
        Expanded(
          child: BarChart(
            BarChartData(
              maxY: maxY * 1.2,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: scheme.outlineVariant.withValues(alpha: .28),
                  strokeWidth: 1,
                  dashArray: [3, 3],
                ),
              ),
              borderData: FlBorderData(show: false),
              titlesData: _chartTitles(
                context: context,
                bottom: [for (final k in _statusKeys) _statusMeta[k]!.label],
                leftFormat: (v) => v.round().toString(),
              ),
              barTouchData: BarTouchData(
                handleBuiltInTouches: false,
                touchCallback: (event, response) {
                  if (!persistChartTap(event)) return;
                  final index = selectedBarGroupIndex(response);
                  if (index == null) return;
                  showChartTooltip(index);
                },
                touchTooltipData: BarTouchTooltipData(
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  getTooltipColor: (_) => scheme.inverseSurface,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    if (groupIndex < 0 || groupIndex >= _statusKeys.length) {
                      return null;
                    }
                    final key = _statusKeys[groupIndex];
                    final isQuotes = rodIndex == 0;
                    return BarTooltipItem(
                      '${_statusMeta[key]!.label}\n${isQuotes ? 'Quotes' : 'Invoices'}  ${rod.toY.round()}',
                      TextStyle(
                        color: scheme.onInverseSurface,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    );
                  },
                ),
              ),
              barGroups: [
                for (var i = 0; i < _statusKeys.length; i++)
                  BarChartGroupData(
                    x: i,
                    barsSpace: 3,
                    showingTooltipIndicators: barRodTooltipIndexes(
                      2,
                      selected: selectedTooltipIndex == i,
                    ),
                    barRods: [
                      BarChartRodData(
                        toY: quotes.valueFor(_statusKeys[i]).toDouble(),
                        color: _amber,
                        width: 8,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                      ),
                      BarChartRodData(
                        toY: invoices.valueFor(_statusKeys[i]).toDouble(),
                        color: _emerald,
                        width: 8,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _LegendDot(color: _amber, label: 'Quotes'),
            SizedBox(width: 14),
            _LegendDot(color: _emerald, label: 'Invoices'),
          ],
        ),
      ],
    );
  }
}

class _MonthCompareChart extends StatefulWidget {
  const _MonthCompareChart({
    required this.lastSales,
    required this.thisSales,
    required this.lastInvoices,
    required this.thisInvoices,
  });

  final double lastSales;
  final double thisSales;
  final int lastInvoices;
  final int thisInvoices;

  @override
  State<_MonthCompareChart> createState() => _MonthCompareChartState();
}

class _MonthCompareChartState extends State<_MonthCompareChart>
    with TimedChartTooltip {

  @override
  Widget build(BuildContext context) {
    final lastSales = widget.lastSales;
    final thisSales = widget.thisSales;
    final lastInvoices = widget.lastInvoices;
    final thisInvoices = widget.thisInvoices;
    final scheme = Theme.of(context).colorScheme;
    final maxSales = math.max(1.0, math.max(lastSales, thisSales));
    final maxInv = math.max(1, math.max(lastInvoices, thisInvoices));
    final sales = [lastSales, thisSales];
    final invoices = [lastInvoices, thisInvoices];
    final labels = ['Last month', 'This month'];

    double scaledInv(int count) => (count / maxInv) * maxSales;
    final bars = [
      LineChartBarData(
        spots: [FlSpot(0, lastSales), FlSpot(1, thisSales)],
        color: _sky,
        barWidth: 3,
        dotData: const FlDotData(show: true),
      ),
      LineChartBarData(
        spots: [
          FlSpot(0, scaledInv(lastInvoices)),
          FlSpot(1, scaledInv(thisInvoices)),
        ],
        color: _amber,
        barWidth: 3,
        dashArray: [5, 4],
        dotData: const FlDotData(show: true),
      ),
    ];

    return Column(
      children: [
        Expanded(
          child: LineChart(
            LineChartData(
              minY: 0,
              maxY: maxSales * 1.2,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: scheme.outlineVariant.withValues(alpha: .28),
                  strokeWidth: 1,
                  dashArray: [3, 3],
                ),
              ),
              borderData: FlBorderData(show: false),
              titlesData: _chartTitles(
                context: context,
                bottom: labels,
                leftFormat: formatAxisInr,
                rightFormat: (v) {
                  final inv = ((v / maxSales) * maxInv).round();
                  return '$inv';
                },
              ),
              showingTooltipIndicators: lineTooltipsAtIndex(
                bars: bars,
                index: selectedTooltipIndex,
              ),
              lineTouchData: LineTouchData(
                handleBuiltInTouches: false,
                touchCallback: (event, response) {
                  if (!persistChartTap(event)) return;
                  final index = selectedLineSpotIndex(response);
                  if (index == null) return;
                  showChartTooltip(index);
                },
                touchTooltipData: LineTouchTooltipData(
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  getTooltipColor: (_) => scheme.inverseSurface,
                  getTooltipItems: (spots) => spots.map((spot) {
                    final i = spot.x.toInt();
                    if (i < 0 || i > 1) return null;
                    final isSales = spot.barIndex == 0;
                    final text = isSales
                        ? 'Sales  ${formatInr(sales[i])}'
                        : 'Invoices  ${invoices[i]}';
                    return LineTooltipItem(
                      '${labels[i]}\n$text',
                      TextStyle(
                        color: scheme.onInverseSurface,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    );
                  }).toList(),
                ),
              ),
              lineBarsData: bars,
            ),
          ),
        ),
        const SizedBox(height: 6),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _LegendDot(color: _sky, label: 'Sales'),
            SizedBox(width: 14),
            _LegendDot(color: _amber, label: 'Invoices'),
          ],
        ),
      ],
    );
  }
}

class _SalesBillingChart extends StatefulWidget {
  const _SalesBillingChart({required this.points});
  final List<SalesPoint> points;

  @override
  State<_SalesBillingChart> createState() => _SalesBillingChartState();
}

class _SalesBillingChartState extends State<_SalesBillingChart>
    with TimedChartTooltip {

  @override
  Widget build(BuildContext context) {
    final points = widget.points;
    final scheme = Theme.of(context).colorScheme;
    final maxSales = math.max(
      1.0,
      points.fold<double>(0, (m, p) => math.max(m, p.totalSales)),
    );
    final maxInv = math.max(
      1,
      points.fold<int>(0, (m, p) => math.max(m, p.invoiceCount)),
    );

    return BarChart(
      BarChartData(
        maxY: maxSales * 1.2,
        alignment: BarChartAlignment.spaceAround,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(
            color: const Color(0xFFD1FAE5),
            strokeWidth: 1,
            dashArray: [3, 3],
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: _chartTitles(
          context: context,
          bottom: [for (final p in points) _monthLabel(p.month)],
          leftFormat: formatAxisInr,
          rightFormat: (v) {
            final inv = ((v / maxSales) * maxInv).round();
            return '$inv';
          },
        ),
        barTouchData: BarTouchData(
          handleBuiltInTouches: false,
          touchCallback: (event, response) {
            if (!persistChartTap(event)) return;
            final index = selectedBarGroupIndex(response);
            if (index == null) return;
            showChartTooltip(index);
          },
          touchTooltipData: BarTouchTooltipData(
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipColor: (_) => scheme.inverseSurface,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              if (groupIndex < 0 || groupIndex >= points.length) return null;
              final p = points[groupIndex];
              return BarTooltipItem(
                '${_monthLabel(p.month)}\n${formatInr(p.totalSales)}\n${p.invoiceCount} invoices',
                TextStyle(
                  color: scheme.onInverseSurface,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              );
            },
          ),
        ),
        barGroups: [
          for (var i = 0; i < points.length; i++)
            BarChartGroupData(
              x: i,
              showingTooltipIndicators: barRodTooltipIndexes(
                1,
                selected: selectedTooltipIndex == i,
              ),
              barRods: [
                BarChartRodData(
                  toY: points[i].totalSales,
                  color: _sky,
                  width: 12,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}
