import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:solar_sales/core/network/api_constants.dart';
import 'package:solar_sales/core/providers/network_providers.dart';
import 'package:solar_sales/core/theme/app_design.dart';
import 'package:solar_sales/shared/widgets/app_bar.dart';
import 'package:solar_sales/shared/widgets/async_states.dart';
import 'package:solar_sales/shared/widgets/premium_feature_components.dart';
import 'package:solar_sales/shared/widgets/premium_ui.dart';

import '../../data/models/solar_panel_model.dart';
import '../providers/ar_solar_providers.dart';

class SolarArPanelsScreen extends ConsumerWidget {
  const SolarArPanelsScreen({super.key});

  Future<void> _openDesigner(
    BuildContext context,
    WidgetRef ref,
    SolarPanelModel panel,
  ) async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'The rooftop designer and Google Scene Viewer are Android-only. Install the Google app on an Android device.',
          ),
        ),
      );
      return;
    }

    final token = await ref.read(tokenStorageProvider).getActiveToken();
    if (!context.mounted) return;
    if (token == null || token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in again to open Solar AR.')),
      );
      return;
    }

    try {
      await ref.read(arSolarNativeServiceProvider).openConfigurator(
            panel: panel,
            authToken: token,
            apiBaseUrl: ApiConstants.baseUrl,
          );
    } on PlatformException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.message ?? 'Could not open the rooftop designer.',
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open the rooftop designer: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(enabledSolarPanelsProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: const AppAppBar(title: 'Solar AR'),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PageHeader(
            icon: Icons.view_in_ar_rounded,
            title: 'Solar AR',
            subtitle:
                'Pick a panel, design the rooftop array, then view it in Google AR.',
          ),
          Expanded(
            child: async.when(
              loading: () => const LoadingState(),
              error: (e, _) => ErrorState(
                message: e.toString(),
                onRetry: () => ref.invalidate(enabledSolarPanelsProvider),
              ),
              data: (panels) {
                if (panels.isEmpty) {
                  return const EmptyState(
                    title: 'No solar panels yet',
                    subtitle:
                        'Ask an admin to add panel sizes in Green Energy → AR Panels.',
                    icon: Icons.solar_power_outlined,
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(enabledSolarPanelsProvider);
                    await ref.read(enabledSolarPanelsProvider.future);
                  },
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.xs,
                      AppSpacing.md,
                      32,
                    ),
                    itemCount: panels.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final panel = panels[index];
                      return _PanelDesignCard(
                        panel: panel,
                        onDesign: () => _openDesigner(context, ref, panel),
                      ).appFadeSlide(index: index);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PanelDesignCard extends StatelessWidget {
  const _PanelDesignCard({
    required this.panel,
    required this.onDesign,
  });

  final SolarPanelModel panel;
  final VoidCallback onDesign;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return AppCard(
      variant: AppCardVariant.gradient,
      onTap: onDesign,
      padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  scheme.primary.withValues(alpha: 0.20),
                  scheme.primary.withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color: scheme.primary.withValues(alpha: 0.16),
              ),
            ),
            child: Icon(
              Icons.solar_power_rounded,
              color: scheme.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  panel.companyName,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    StatusPill(
                      label: panel.sizeLabel,
                      color: scheme.primary,
                      icon: Icons.straighten_rounded,
                    ),
                    StatusPill(
                      label: panel.wattsLabel,
                      color: scheme.tertiary,
                      icon: Icons.bolt_rounded,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.primary,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.view_in_ar_rounded,
                    size: 16,
                    color: scheme.onPrimary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Design',
                    style: textTheme.labelLarge?.copyWith(
                      color: scheme.onPrimary,
                      fontWeight: FontWeight.w800,
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
