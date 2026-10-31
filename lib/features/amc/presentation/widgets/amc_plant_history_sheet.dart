import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:solar_sales/features/amc/data/models/amc_models.dart';
import 'package:solar_sales/features/amc/presentation/amc_access.dart';
import 'package:solar_sales/features/amc/presentation/providers/amc_providers.dart';
import 'package:solar_sales/features/amc/presentation/widgets/amc_status_chip.dart';
import 'package:solar_sales/features/auth/presentation/providers/auth_provider.dart';
import 'package:solar_sales/shared/utils/formatters.dart';
import 'package:solar_sales/shared/widgets/async_states.dart';

Future<void> showAmcPlantHistorySheet(
  BuildContext context, {
  required AmcPlant plant,
  required bool canCreate,
  required Future<void> Function(AmcPlant plant) onStartAmc,
  required Future<void> Function(AmcPlant plant) onExtraVisit,
  required Future<void> Function(AmcVisit visit) onOpenVisit,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => _AmcPlantHistorySheet(
      initial: plant,
      canCreate: canCreate,
      onStartAmc: onStartAmc,
      onExtraVisit: onExtraVisit,
      onOpenVisit: onOpenVisit,
    ),
  );
}

class _AmcPlantHistorySheet extends ConsumerStatefulWidget {
  const _AmcPlantHistorySheet({
    required this.initial,
    required this.canCreate,
    required this.onStartAmc,
    required this.onExtraVisit,
    required this.onOpenVisit,
  });

  final AmcPlant initial;
  final bool canCreate;
  final Future<void> Function(AmcPlant plant) onStartAmc;
  final Future<void> Function(AmcPlant plant) onExtraVisit;
  final Future<void> Function(AmcVisit visit) onOpenVisit;

  @override
  ConsumerState<_AmcPlantHistorySheet> createState() =>
      _AmcPlantHistorySheetState();
}

class _AmcPlantHistorySheetState extends ConsumerState<_AmcPlantHistorySheet> {
  AmcPlant? _plant;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _plant = widget.initial;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final plant = await ref
          .read(amcHomeProvider.notifier)
          .loadPlant(widget.initial.leadId);
      if (!mounted) return;
      setState(() {
        _plant = plant;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = cleanError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final plant = _plant ?? widget.initial;
    final scheme = Theme.of(context).colorScheme;
    final auth = ref.watch(authProvider);
    final height = MediaQuery.sizeOf(context).height * 0.85;

    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.outlineVariant,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              plant.plantLabel,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              [
                plant.capacity,
                plant.inverterSerialNumber,
                if (plant.city.isNotEmpty) plant.city else plant.district,
              ].where((e) => e.trim().isNotEmpty).join(' · '),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _InfoBox(
                    title: 'Customer',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          plant.fullName.isEmpty ? '—' : plant.fullName,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        if (plant.mobile.isNotEmpty)
                          TextButton(
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () => launchUrl(
                              Uri(scheme: 'tel', path: plant.mobile),
                            ),
                            child: Text(plant.mobile),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _InfoBox(
                    title: 'AMC',
                    child: plant.contract == null
                        ? const Text('Not enrolled')
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${amcVisitStatusLabel(plant.contract!.status)} · ${plant.contract!.visitsPerYear}/year',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                '${formatAmcDate(plant.contract!.startDate)} – ${formatAmcDate(plant.contract!.endDate)}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (AmcAccess.canOpenLead(auth))
                  OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.of(context).pushNamed(
                        '/solar/leads/detail',
                        arguments: plant.leadId,
                      );
                    },
                    child: const Text('Open lead'),
                  ),
                if (plant.contract != null && widget.canCreate)
                  OutlinedButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      await widget.onExtraVisit(plant);
                    },
                    child: const Text('Extra visit'),
                  ),
                if (plant.contract == null && widget.canCreate)
                  FilledButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      await widget.onStartAmc(plant);
                    },
                    child: const Text('Start AMC'),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'VISIT HISTORY',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: scheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const LoadingState(message: 'Loading visits…')
                  : _error != null
                      ? ErrorState(message: _error!, onRetry: _load)
                      : (plant.visits.isEmpty)
                          ? const EmptyState(
                              title: 'No visits yet',
                              subtitle: 'No visits on this plant yet.',
                              icon: Icons.event_available_outlined,
                            )
                          : ListView.separated(
                              itemCount: plant.visits.length,
                              separatorBuilder: (_, _) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final row = plant.visits[index];
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(
                                    row.title.isEmpty
                                        ? 'AMC visit ${row.visitNo}'
                                        : row.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${formatAmcDate(row.scheduledDate)} · ${row.assignee?.name ?? 'Unassigned'}',
                                  ),
                                  trailing: AmcStatusChip(
                                    status: row.status,
                                    isOverdue: row.isOverdue,
                                    forceOverdueLabel: row.isOverdue,
                                  ),
                                  onTap: () async {
                                    Navigator.pop(context);
                                    await widget.onOpenVisit(row);
                                  },
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: .5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}
