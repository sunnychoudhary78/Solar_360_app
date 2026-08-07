import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:solar_sales/core/providers/global_loading_provider.dart';
import 'package:solar_sales/core/theme/app_design.dart';
import 'package:solar_sales/shared/widgets/offline_banner.dart';

/// Hosts global loading/toast overlays above the navigator without replacing
/// the navigator child when overlay state changes.
class GlobalOverlayHost extends ConsumerWidget {
  final Widget? child;

  const GlobalOverlayHost({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overlay = ref.watch(globalLoadingProvider);
    return Stack(
      fit: StackFit.expand,
      children: [
        if (child != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const OfflineBanner(),
              Expanded(child: child!),
            ],
          ),
        if (overlay.isLoading) GlobalLoader(message: overlay.message),
        if (overlay.isSuccess) GlobalSuccess(message: overlay.message),
        if (overlay.isError) GlobalError(message: overlay.message),
        if (overlay.isMessage) GlobalMessage(message: overlay.message),
      ],
    );
  }
}

class GlobalLoader extends StatelessWidget {
  final String message;
  const GlobalLoader({super.key, this.message = 'Please wait...'});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.black.withValues(alpha: 0.35),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(AppSpacing.lg),
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            decoration: BoxDecoration(
              color: scheme.surface.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.5),
              ),
              boxShadow: AppShadows.floating(scheme),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 36,
                  height: 36,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  message,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: AppMotion.fast).scale(
                begin: const Offset(0.94, 0.94),
                duration: AppMotion.normal,
                curve: AppMotion.easeOut,
              ),
        ),
      ),
    );
  }
}

class GlobalSuccess extends StatelessWidget {
  final String message;
  const GlobalSuccess({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return _ToastBanner(
      icon: Icons.check_circle_rounded,
      color: const Color(0xFF059669),
      message: message,
    );
  }
}

class GlobalError extends StatelessWidget {
  final String message;
  const GlobalError({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return _ToastBanner(
      icon: Icons.error_rounded,
      color: Theme.of(context).colorScheme.error,
      message: message,
    );
  }
}

class GlobalMessage extends StatelessWidget {
  final String message;
  const GlobalMessage({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return _ToastBanner(
      icon: Icons.info_rounded,
      color: Theme.of(context).colorScheme.primary,
      message: message,
    );
  }
}

class _ToastBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String message;

  const _ToastBanner({
    required this.icon,
    required this.color,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Material(
                color: color.withValues(alpha: 0.92),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 420),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: scheme.surface.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, color: Colors.white, size: 22),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          message,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
              .animate()
              .fadeIn(duration: AppMotion.fast)
              .slideY(begin: -0.25, duration: AppMotion.normal, curve: AppMotion.easeOut),
        ),
      ),
    );
  }
}
