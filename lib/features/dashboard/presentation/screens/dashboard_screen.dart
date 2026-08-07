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
import 'package:solar_sales/shared/widgets/premium_ui.dart';

import '../../data/models/dashboard_model.dart';
import '../providers/dashboard_providers.dart';

String _timeGreeting() {
  final h = DateTime.now().hour;
  if (h < 12) return 'Good morning';
  if (h < 17) return 'Good afternoon';
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

    // Billbook purple-lavender — call-site only, not a design-token class.
    const purple = Color(0xFF7C3AED);
    const lavender = Color(0xFFEDE9FE);

    final header = HomeHeaderData(
      title: firstName,
      subtitle: roleSubtitle.isEmpty
          ? "Here's what's happening with your business today."
          : roleSubtitle,
      badge: StatusPill(label: 'Billbook', color: purple),
      heroImage: 'assets/images/billbook_header.png',
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          lavender.withValues(alpha: 0.9),
          purple.withValues(alpha: 0.12),
          scheme.surfaceContainerLowest,
        ],
      ),
      accentColor: purple,
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
        data: (data) {
          return SharedHomeLayout(
            header: header,
            greeting: _timeGreeting(),
            onRefresh: () async {
              ref.invalidate(dashboardProvider);
            },
            child: _BillBookContent(data: data, auth: auth),
          );
        },
      ),
    );
  }
}

class _BillBookContent extends StatelessWidget {
  const _BillBookContent({required this.data, required this.auth});

  final DashboardModel data;
  final AuthState auth;

  @override
  Widget build(BuildContext context) {
    final tabs = NavDestinations.shellTabs(
      AppModules.billbook,
      auth.hasPermission,
    );
    final quickDests = NavDestinations.quickActions(
      AppModules.billbook,
      auth.hasPermission,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (auth.hasPermission('stats.read')) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: _SalesHeroCard(value: formatInr(data.totalSales)),
          ).appFadeSlide(index: 0),

          const SizedBox(height: AppSpacing.md),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: MetricGrid(
              childAspectRatio: 1.2,
              children: [
                MetricTile(
                  label: 'Customers',
                  value: '${data.customersCount}',
                  icon: Icons.people_alt_rounded,
                  onTap: () => Navigator.pushNamed(context, '/customers'),
                ),
                MetricTile(
                  label: 'Invoices',
                  value: '${data.invoicesCount}',
                  icon: Icons.receipt_long_rounded,
                  onTap: () => Navigator.pushNamed(context, '/invoices'),
                ),
                MetricTile(
                  label: 'Quotations',
                  value: '${data.quotationsCount}',
                  icon: Icons.request_quote_rounded,
                  onTap: () => Navigator.pushNamed(context, '/quotations'),
                ),
                MetricTile(
                  label: 'Pending',
                  value:
                      '${data.pendingQuotations + data.pendingInvoices + data.pendingItemsCount}',
                  icon: Icons.pending_actions_rounded,
                  onTap: () =>
                      Navigator.pushNamed(context, '/quotations/approvals'),
                ),
              ],
            ),
          ).appFadeSlide(index: 1),

          const SizedBox(height: AppSpacing.lg),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: PremiumSectionTitle(title: 'Sales trend'),
          ).appFadeSlide(index: 2),

          const SizedBox(height: AppSpacing.sm),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: SizedBox(
              height: 270,
              child: data.salesTrend.isEmpty
                  ? const _EmptyChart()
                  : _SalesTrendChart(points: data.salesTrend),
            ),
          ).appFadeSlide(index: 3),
        ],

        const SizedBox(height: AppSpacing.lg),

        const Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: PremiumSectionTitle(
            title: 'Explore',
            subtitle: 'Jump to a feature',
          ),
        ).appFadeSlide(index: 4),

        const SizedBox(height: AppSpacing.sm),

        QuickActionGrid(
          destinations: quickDests,
          onDestination: (dest) => navigateDestination(context, dest, tabs),
        ).appFadeSlide(index: 5),

        const SizedBox(height: AppSpacing.lg),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: MetricTile(
                  label: 'Pending approvals',
                  value:
                      '${data.pendingQuotations + data.pendingInvoices + data.pendingItemsCount}',
                  icon: Icons.fact_check_rounded,
                  compact: true,
                  onTap: () =>
                      Navigator.pushNamed(context, '/quotations/approvals'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: MetricTile(
                  label: 'Low stock',
                  value: '${data.lowStockCount}',
                  icon: Icons.warning_amber_rounded,
                  compact: true,
                  onTap: () =>
                      Navigator.pushNamed(context, '/inventory/low-stock'),
                ),
              ),
            ],
          ),
        ).appFadeSlide(index: 6),

        const SizedBox(height: AppSpacing.lg),

        const Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: PremiumSectionTitle(title: 'Create'),
        ),

        const SizedBox(height: AppSpacing.sm),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (auth.hasPermission('customer.create'))
                _CreateChip(
                  label: 'Customer',
                  icon: Icons.person_add_alt_rounded,
                  onTap: () =>
                      Navigator.pushNamed(context, '/customers/form'),
                ),
              if (auth.hasPermission('quotation.create'))
                _CreateChip(
                  label: 'Quotation',
                  icon: Icons.note_add_outlined,
                  onTap: () =>
                      Navigator.pushNamed(context, '/quotations/form'),
                ),
              if (auth.hasPermission('invoice.create'))
                _CreateChip(
                  label: 'Invoice',
                  icon: Icons.receipt_long_outlined,
                  onTap: () => Navigator.pushNamed(context, '/invoices/new'),
                ),
              if (auth.hasPermission('item.create'))
                _CreateChip(
                  label: 'Item',
                  icon: Icons.add_box_outlined,
                  onTap: () => Navigator.pushNamed(context, '/items/form'),
                ),
            ],
          ),
        ).appFadeSlide(index: 7),
      ],
    );
  }
}

class _CreateChip extends StatelessWidget {
  const _CreateChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ActionChip(
      avatar: Icon(icon, size: 18, color: scheme.primary),
      label: Text(label),
      onPressed: onTap,
      backgroundColor: scheme.primaryContainer.withValues(alpha: 0.45),
      side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.4)),
    );
  }
}

// ============================================================================
// SALES HERO CARD
// ============================================================================

class _SalesHeroCard extends StatelessWidget {
  final String value;

  const _SalesHeroCard({required this.value});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primary,
            Color.lerp(scheme.primary, Colors.black, 0.18) ?? scheme.primary,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.35),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Decorative wave in the background.
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(26),
              child: CustomPaint(
                painter: _HeroWavePainter(
                  color: scheme.onPrimary.withValues(alpha: 0.08),
                ),
              ),
            ),
          ),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      'Total Sales',
                      style: TextStyle(
                        color: scheme.onPrimary.withValues(alpha: 0.9),
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: scheme.onPrimary.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.trending_up_rounded,
                      color: scheme.onPrimary,
                      size: 20,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: scheme.onPrimary,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroWavePainter extends CustomPainter {
  final Color color;

  _HeroWavePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;

    final path = Path()
      ..moveTo(0, size.height * 0.55)
      ..quadraticBezierTo(
        size.width * 0.25,
        size.height * 0.35,
        size.width * 0.5,
        size.height * 0.55,
      )
      ..quadraticBezierTo(
        size.width * 0.75,
        size.height * 0.75,
        size.width,
        size.height * 0.5,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _HeroWavePainter oldDelegate) =>
      oldDelegate.color != color;
}

class _SalesTrendChart extends StatelessWidget {
  final List<SalesPoint> points;

  const _SalesTrendChart({required this.points});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final monthFmt = DateFormat('MMM');

    if (points.isEmpty) {
      return const _EmptyChart();
    }

    final values = points.map((e) => e.totalSales.toDouble()).toList();

    final maxValue = values.reduce((a, b) => a > b ? a : b);

    final chartMax = maxValue <= 0 ? 100.0 : maxValue * 1.20;

    return PremiumCard(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Sales Trend',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Sales performance over time',
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.trending_up_rounded,
                  size: 17,
                  color: scheme.primary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          Expanded(
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: chartMax,

                // ----------------------------------------------------------
                // TOUCH
                // ----------------------------------------------------------
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => scheme.inverseSurface,
                    tooltipPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    getTooltipItems: (spots) {
                      return spots.map((spot) {
                        final index = spot.x.toInt();

                        if (index < 0 || index >= points.length) {
                          return null;
                        }

                        final point = points[index];

                        final month = point.month == null
                            ? ''
                            : monthFmt.format(point.month!);

                        return LineTooltipItem(
                          '$month\n${formatInr(point.totalSales)}',
                          TextStyle(
                            color: scheme.onInverseSurface,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),

                // ----------------------------------------------------------
                // GRID
                // ----------------------------------------------------------
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: chartMax / 4,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: scheme.outlineVariant.withValues(alpha: 0.35),
                      strokeWidth: 1,
                    );
                  },
                ),

                borderData: FlBorderData(show: false),

                // ----------------------------------------------------------
                // TITLES
                // ----------------------------------------------------------
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),

                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),

                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      interval: chartMax / 4,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          NumberFormat.compact().format(value),
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: 9,
                          ),
                        );
                      },
                    ),
                  ),

                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 25,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();

                        if (index < 0 || index >= points.length) {
                          return const SizedBox.shrink();
                        }

                        final month = points[index].month;

                        return Padding(
                          padding: const EdgeInsets.only(top: 7),
                          child: Text(
                            month == null ? '' : monthFmt.format(month),
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // ----------------------------------------------------------
                // LINE
                // ----------------------------------------------------------
                lineBarsData: [
                  LineChartBarData(
                    spots: List.generate(points.length, (index) {
                      return FlSpot(
                        index.toDouble(),
                        points[index].totalSales.toDouble(),
                      );
                    }),

                    isCurved: true,

                    curveSmoothness: 0.25,

                    color: scheme.primary,

                    barWidth: 3,

                    isStrokeCapRound: true,

                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 4,
                          color: scheme.surface,
                          strokeWidth: 2.5,
                          strokeColor: scheme.primary,
                        );
                      },
                    ),

                    belowBarData: BarAreaData(
                      show: true,
                      gradient: AppGradients.chartFill(scheme),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// EMPTY CHART
// ============================================================================

class _EmptyChart extends StatelessWidget {
  const _EmptyChart();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return PremiumCard(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.bar_chart_rounded,
                size: 26,
                color: scheme.primary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'No sales data yet',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 3),
            Text(
              'Trend appears after invoices land',
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
