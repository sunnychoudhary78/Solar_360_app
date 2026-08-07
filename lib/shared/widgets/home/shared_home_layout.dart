import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:solar_sales/core/theme/app_design.dart';

/// Lightweight header payload for [SharedHomeLayout]. Not a module framework.
class HomeHeaderData {
  const HomeHeaderData({
    required this.title,
    this.subtitle,
    this.badge,
    required this.heroImage,
    required this.gradient,
    required this.accentColor,
  });

  final String title;
  final String? subtitle;
  final Widget? badge;
  final String heroImage;
  final LinearGradient gradient;
  final Color accentColor;
}

/// Shared home chrome: gradient background, hero, scroll, entrance motion.
/// Caller owns [Scaffold] / app bar; business content stays in [child].
class SharedHomeLayout extends StatelessWidget {
  const SharedHomeLayout({
    super.key,
    required this.header,
    required this.child,
    this.onRefresh,
    this.greeting,
  });

  final HomeHeaderData header;
  final Widget child;
  final Future<void> Function()? onRefresh;
  final String? greeting;

  @override
  Widget build(BuildContext context) {
    final scroll = ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
      children: [
        ModuleHeroHeader(
          greeting: greeting,
          title: header.title,
          subtitle: header.subtitle,
          badge: header.badge,
          heroImage: header.heroImage,
          accentColor: header.accentColor,
        ),
        const SizedBox(height: AppSpacing.xs),
        child
            .animate()
            .fadeIn(duration: AppMotion.normal, curve: AppMotion.easeOut)
            .moveY(
              begin: 8,
              end: 0,
              duration: AppMotion.normal,
              curve: AppMotion.easeOut,
            ),
      ],
    );

    return _AnimatedGradientBackground(
      gradient: header.gradient,
      child: onRefresh == null
          ? scroll
          : RefreshIndicator(onRefresh: onRefresh!, child: scroll),
    );
  }
}

/// Rounded header card: illustration fills the right and feathers into the
/// card surface (left / top / bottom). Left copy sits on the faded zone.
class ModuleHeroHeader extends StatelessWidget {
  const ModuleHeroHeader({
    super.key,
    this.greeting,
    required this.title,
    this.subtitle,
    this.badge,
    required this.heroImage,
    required this.accentColor,
  });

  final String? greeting;
  final String title;
  final String? subtitle;
  final Widget? badge;
  final String heroImage;
  final Color accentColor;

  static const double _headerHeight = 196;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final width = MediaQuery.sizeOf(context).width;
    final cardRadius = BorderRadius.circular(AppRadius.xl);

    final textColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (greeting != null) ...[
          Text(
            greeting!,
            style: textTheme.labelMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
        ],
        Text(
          title,
          style: textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: scheme.onSurface,
            letterSpacing: -0.3,
          ),
        ),
        if (subtitle != null && subtitle!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            subtitle!,
            style: textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        Container(
          width: 28,
          height: 3,
          decoration: BoxDecoration(
            color: accentColor,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
        ),
        if (badge != null) ...[
          const SizedBox(height: AppSpacing.sm),
          badge!,
        ],
      ],
    )
        .animate()
        .fadeIn(duration: AppMotion.normal, curve: AppMotion.easeOut)
        .moveY(
          begin: 8,
          end: 0,
          duration: AppMotion.normal,
          curve: AppMotion.easeOut,
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: cardRadius,
          boxShadow: AppShadows.header(scheme),
        ),
        child: ClipRRect(
          borderRadius: cardRadius,
          child: ColoredBox(
            color: scheme.surfaceContainerLowest,
            child: SizedBox(
              height: _headerHeight,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Positioned.fill(
                    child: _AnimatedHeroImage(
                      assetPath: heroImage,
                      cacheWidth: (width * dpr).round(),
                    ),
                  ),
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: ConstrainedBox(
                          constraints:
                              BoxConstraints(maxWidth: width * 0.43),
                          child: textColumn,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedGradientBackground extends StatelessWidget {
  const _AnimatedGradientBackground({
    required this.gradient,
    required this.child,
  });

  final LinearGradient gradient;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = scheme.surfaceContainerLowest;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) {
        final colors = [
          for (final c in gradient.colors) Color.lerp(base, c, t)!,
        ];
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: gradient.begin,
              end: gradient.end,
              colors: colors,
              stops: gradient.stops,
            ),
          ),
          child: child,
        );
      },
      child: child,
    );
  }
}

class _AnimatedHeroImage extends StatelessWidget {
  const _AnimatedHeroImage({
    required this.assetPath,
    this.cacheWidth,
  });

  final String assetPath;
  final int? cacheWidth;

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      assetPath,
      fit: BoxFit.cover,
      alignment: const Alignment(0.55, 0),
      filterQuality: FilterQuality.medium,
      cacheWidth: cacheWidth,
      errorBuilder: (context, error, stackTrace) =>
          const SizedBox.expand(),
    );

    // Horizontal fade only: left ~half clear for text; full opacity on right.
    final faded = ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (rect) {
        return const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Colors.transparent,
            Color(0x33000000),
            Color(0x99000000),
            Colors.black,
            Colors.black,
          ],
          stops: [0.0, 0.35, 0.50, 0.72, 1.0],
        ).createShader(rect);
      },
      child: image,
    );

    return RepaintBoundary(
      child: faded
          .animate(key: ValueKey(assetPath))
          .fadeIn(duration: 600.ms, curve: Curves.easeOutCubic)
          .slideX(
            begin: 0.12,
            end: 0,
            duration: 600.ms,
            curve: Curves.easeOutCubic,
          )
          .scale(
            begin: const Offset(1.04, 1.04),
            end: const Offset(1, 1),
            duration: 600.ms,
            curve: Curves.easeOutCubic,
          ),
    );
  }
}


