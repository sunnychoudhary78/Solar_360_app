import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:solar_sales/core/theme/app_design.dart';

/// Shared header configuration used by Billbook and Green Energy.
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

/// Shared home layout. Keeps the module-specific image/theme supplied by the
/// caller while giving both dashboards the same premium visual structure.
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
  final Future Function()? onRefresh;
  final String? greeting;

  @override
  Widget build(BuildContext context) {
    final scroll = ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
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
              begin: 10,
              end: 0,
              duration: AppMotion.normal,
              curve: AppMotion.easeOut,
            ),
      ],
    );

    return _AnimatedGradientBackground(
      gradient: header.gradient,
      accentColor: header.accentColor,
      child: onRefresh == null
          ? scroll
          : RefreshIndicator(
              color: header.accentColor,
              backgroundColor:
                  Theme.of(context).colorScheme.surfaceContainerLowest,
              displacement: 22,
              strokeWidth: 2.5,
              onRefresh: onRefresh!,
              child: scroll,
            ),
    );
  }
}

/// Premium shared hero. The existing image asset is never replaced.
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

  static const double _headerHeight = 204;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final width = MediaQuery.sizeOf(context).width;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final radius = BorderRadius.circular(AppRadius.xl);

    final textColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (greeting != null && greeting!.trim().isNotEmpty) ...[
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: accentColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.28),
                      blurRadius: 7,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  greeting!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
        ],
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w900,
            color: scheme.onSurface,
            letterSpacing: -0.6,
            height: 1.08,
          ),
        ),
        if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            subtitle!,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.32,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Container(
              width: 34,
              height: 4,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.20),
                    blurRadius: 7,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Container(
              width: 7,
              height: 4,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
          ],
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
          begin: 9,
          end: 0,
          duration: AppMotion.normal,
          curve: AppMotion.easeOut,
        );

    final maxTextWidth = width < 360
        ? width * 0.53
        : width < 430
            ? width * 0.49
            : width * 0.44;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Container(
        height: _headerHeight,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: [
            ...AppShadows.header(scheme),
            BoxShadow(
              color: accentColor.withValues(alpha: 0.055),
              blurRadius: 24,
              offset: const Offset(0, 9),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: ColoredBox(
            color: scheme.surfaceContainerLowest,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(
                  child: _AnimatedHeroImage(
                    assetPath: heroImage,
                    cacheWidth: (width * dpr).round(),
                    accentColor: accentColor,
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          stops: const [0.0, 0.38, 0.58, 1.0],
                          colors: [
                            scheme.surfaceContainerLowest.withValues(
                              alpha: 0.98,
                            ),
                            scheme.surfaceContainerLowest.withValues(
                              alpha: 0.88,
                            ),
                            scheme.surfaceContainerLowest.withValues(
                              alpha: 0.30,
                            ),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withValues(alpha: 0.07),
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.035),
                          ],
                          stops: const [0.0, 0.45, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxTextWidth),
                        child: textColumn,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 12,
                  top: 12,
                  child: _HeroAccentGlow(color: accentColor),
                ),
              ],
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
    required this.accentColor,
  });

  final LinearGradient gradient;
  final Widget child;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = scheme.surfaceContainerLowest;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) {
        final colors = [
          for (final color in gradient.colors)
            Color.lerp(base, color, t)!,
        ];

        return Stack(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: gradient.begin,
                  end: gradient.end,
                  colors: colors,
                  stops: gradient.stops,
                ),
              ),
              child: child,
            ),
            Positioned(
              top: -120,
              right: -90,
              child: IgnorePointer(
                child: Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.035),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ],
        );
      },
      child: child,
    );
  }
}

class _AnimatedHeroImage extends StatelessWidget {
  const _AnimatedHeroImage({
    required this.assetPath,
    required this.accentColor,
    this.cacheWidth,
  });

  final String assetPath;
  final Color accentColor;
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

    final faded = ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (rect) {
        return const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Colors.transparent,
            Color(0x22000000),
            Color(0x77000000),
            Color(0xDD000000),
            Colors.black,
          ],
          stops: [0.0, 0.28, 0.48, 0.70, 1.0],
        ).createShader(rect);
      },
      child: image,
    );

    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          faded
              .animate(key: ValueKey(assetPath))
              .fadeIn(duration: 600.ms, curve: Curves.easeOutCubic)
              .slideX(
                begin: 0.10,
                end: 0,
                duration: 600.ms,
                curve: Curves.easeOutCubic,
              )
              .scale(
                begin: const Offset(1.035, 1.035),
                end: const Offset(1, 1),
                duration: 600.ms,
                curve: Curves.easeOutCubic,
              ),
          Align(
            alignment: Alignment.centerRight,
            child: FractionallySizedBox(
              widthFactor: 0.52,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.centerRight,
                      radius: 1.0,
                      colors: [
                        accentColor.withValues(alpha: 0.06),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroAccentGlow extends StatelessWidget {
  const _HeroAccentGlow({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.07),
        border: Border.all(
          color: color.withValues(alpha: 0.10),
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.10),
            blurRadius: 18,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Icon(
        Icons.auto_awesome_rounded,
        size: 18,
        color: color.withValues(alpha: 0.75),
      ),
    );
  }
}
