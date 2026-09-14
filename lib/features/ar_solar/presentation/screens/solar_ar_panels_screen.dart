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
      body: async.when(
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
                AppSpacing.md,
                AppSpacing.md,
                32,
              ),
              itemCount: panels.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final panel = panels[index];
                return AppCard(
                  onTap: () => _openDesigner(context, ref, panel),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: scheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.solar_power_outlined,
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
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Panel ${panel.sizeLabel}',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            Text(
                              panel.wattsLabel,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.view_in_ar_outlined,
                        color: scheme.primary,
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
