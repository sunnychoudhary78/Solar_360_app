import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:solar_sales/core/theme/app_design.dart';
import 'package:solar_sales/core/workflow/lead_workflow.dart';
import 'package:solar_sales/features/leads/presentation/providers/lead_providers.dart';
import 'package:solar_sales/shared/utils/excel_download_action.dart';
import 'package:solar_sales/shared/utils/excel_export.dart';
import 'package:solar_sales/shared/utils/excel_rows.dart';
import 'package:solar_sales/shared/utils/formatters.dart';
import 'package:solar_sales/shared/widgets/app_bar.dart';
import 'package:solar_sales/shared/widgets/async_states.dart';
import 'package:solar_sales/shared/widgets/excel_download_button.dart';
import 'package:solar_sales/shared/widgets/premium_feature_components.dart';

class GreenEnergyReportsScreen extends ConsumerStatefulWidget {
  const GreenEnergyReportsScreen({super.key});

  @override
  ConsumerState<GreenEnergyReportsScreen> createState() =>
      _GreenEnergyReportsScreenState();
}

class _GreenEnergyReportsScreenState
    extends ConsumerState<GreenEnergyReportsScreen> {
  String _exportingKey = '';

  Future<void> _download({
    required String key,
    required String sheetName,
    required String filePrefix,
    required List<Map<String, Object?>> rows,
  }) async {
    if (_exportingKey.isNotEmpty) return;
    setState(() => _exportingKey = key);
    await runExcelDownload(
      context: context,
      sheets: [ExcelSheetData(name: sheetName, rows: rows)],
      filePrefix: filePrefix,
    );
    if (mounted) setState(() => _exportingKey = '');
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(greenEnergyReportsLeadsProvider);
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: AppAppBar(
        title: 'Reports',
        subtitle: 'Green Energy pipeline',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(greenEnergyReportsLeadsProvider),
          ),
        ],
      ),
      body: async.when(
        loading: () => const LoadingState(),
        error: (e, _) => ErrorState(
          message: cleanError(e),
          onRetry: () => ref.invalidate(greenEnergyReportsLeadsProvider),
        ),
        data: (leads) {
          final byStatus = greenEnergyStatusRows(leads);
          final byDepartment = greenEnergyDepartmentRows(leads);
          final byState = greenEnergyStateRows(leads);
          final preview = leads.take(25).toList(growable: false);

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(greenEnergyReportsLeadsProvider),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                const PageHeader(
                  icon: Icons.analytics_rounded,
                  title: 'Lead pipeline summaries',
                  subtitle: 'Download each section as Excel',
                  margin: EdgeInsets.zero,
                ),
                const SizedBox(height: AppSpacing.md),
                MetricGrid(
                  crossAxisCount: 2,
                  childAspectRatio: 1.55,
                  spacing: 10,
                  children: [
                    MetricTile(
                      compact: true,
                      label: 'Total leads',
                      value: '${leads.length}',
                      icon: Icons.handshake_outlined,
                    ),
                    MetricTile(
                      compact: true,
                      label: 'Statuses',
                      value: '${byStatus.length}',
                      icon: Icons.flag_outlined,
                    ),
                    MetricTile(
                      compact: true,
                      label: 'Departments',
                      value: '${byDepartment.length}',
                      icon: Icons.apartment_outlined,
                    ),
                    MetricTile(
                      compact: true,
                      label: 'States',
                      value: '${byState.length}',
                      icon: Icons.map_outlined,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                _SummaryCard(
                  title: 'By status',
                  subtitle: 'Lead count per status',
                  labelHeader: 'Status',
                  rows: byStatus,
                  downloading: _exportingKey == 'status',
                  onDownload: byStatus.isEmpty
                      ? null
                      : () => _download(
                            key: 'status',
                            sheetName: 'By Status',
                            filePrefix: 'GreenEnergy_By_Status',
                            rows: byStatus,
                          ),
                ),
                const SizedBox(height: AppSpacing.md),
                _SummaryCard(
                  title: 'By department',
                  subtitle: 'Lead count per department',
                  labelHeader: 'Department',
                  rows: byDepartment,
                  downloading: _exportingKey == 'department',
                  onDownload: byDepartment.isEmpty
                      ? null
                      : () => _download(
                            key: 'department',
                            sheetName: 'By Department',
                            filePrefix: 'GreenEnergy_By_Department',
                            rows: byDepartment,
                          ),
                ),
                const SizedBox(height: AppSpacing.md),
                _SummaryCard(
                  title: 'By state',
                  subtitle: 'Lead count per state',
                  labelHeader: 'State',
                  rows: byState,
                  downloading: _exportingKey == 'state',
                  onDownload: byState.isEmpty
                      ? null
                      : () => _download(
                            key: 'state',
                            sheetName: 'By State',
                            filePrefix: 'GreenEnergy_By_State',
                            rows: byState,
                          ),
                ),
                const SizedBox(height: AppSpacing.md),
                PremiumCard(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'All leads',
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'Full lead list for Excel export',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ExcelDownloadButton(
                              compact: true,
                              tooltip: 'Download all leads as Excel',
                              enabled: leads.isNotEmpty,
                              busy: _exportingKey == 'leads',
                              onPressed: () => _download(
                                key: 'leads',
                                sheetName: 'All Leads',
                                filePrefix: 'GreenEnergy_All_Leads',
                                rows: greenEnergyLeadRows(leads),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        if (leads.isEmpty)
                          const EmptyState(
                            title: 'No leads found',
                            icon: Icons.handshake_outlined,
                          )
                        else
                          ...preview.asMap().entries.map((entry) {
                            final lead = entry.value;
                            return Column(
                              children: [
                                if (entry.key > 0)
                                  Divider(
                                    height: 1,
                                    color: scheme.outlineVariant.withValues(
                                      alpha: 0.3,
                                    ),
                                  ),
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(
                                    leadExcelName(lead).isEmpty
                                        ? '—'
                                        : leadExcelName(lead),
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: Text(
                                    [
                                      LeadWorkflow.getStatusDisplayLabel(
                                        lead.status,
                                      ),
                                      LeadWorkflow.resolveDepartmentLabel(
                                        lead.currentDepartment,
                                      ),
                                      if (lead.state.isNotEmpty) lead.state,
                                    ].where((p) => p.isNotEmpty).join(' · '),
                                  ),
                                ),
                              ],
                            );
                          }),
                        if (leads.length > 25)
                          Padding(
                            padding: const EdgeInsets.only(top: AppSpacing.sm),
                            child: Text(
                              'Showing 25 of ${leads.length} leads. Use Download for the full dataset.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                      ],
                    ),
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

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.subtitle,
    required this.labelHeader,
    required this.rows,
    required this.downloading,
    this.onDownload,
  });

  final String title;
  final String subtitle;
  final String labelHeader;
  final List<Map<String, Object?>> rows;
  final bool downloading;
  final VoidCallback? onDownload;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final labelKey = rows.isEmpty ? labelHeader : rows.first.keys.first;
    const countKey = 'Count';

    return PremiumCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                ExcelDownloadButton(
                  compact: true,
                  tooltip: 'Download $title as Excel',
                  enabled: onDownload != null,
                  busy: downloading,
                  onPressed: onDownload,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            if (rows.isEmpty)
              const EmptyState(title: 'No data', icon: Icons.bar_chart_outlined)
            else
              ...rows.take(12).map((row) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${row[labelKey] ?? ''}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        '${row[countKey] ?? 0}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
