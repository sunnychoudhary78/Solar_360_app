import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:solar_sales/core/theme/app_design.dart';
import 'package:solar_sales/features/shell/presentation/nav_destinations.dart';
import 'package:solar_sales/features/shell/presentation/shell_scope.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Premium Feature Components
//
// This file keeps the existing public APIs used by Billbook and Green Energy,
// while upgrading the visual system: softer surfaces, stronger hierarchy,
// premium quick-action cards, responsive metric cards, and cleaner sections.
//
// Navigation, routes, permissions and providers are intentionally untouched.
// ─────────────────────────────────────────────────────────────────────────────

// ── Card variants ─────────────────────────────────────────────────────────────

enum AppCardVariant { flat, elevated, gradient, outlined }

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.margin,
    this.onTap,
    this.variant = AppCardVariant.elevated,
    this.borderRadius,
    this.accentColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final AppCardVariant variant;
  final double? borderRadius;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(borderRadius ?? AppRadius.xl);
    final accent = accentColor ?? scheme.primary;

    final BoxDecoration decoration;

    switch (variant) {
      case AppCardVariant.flat:
        decoration = BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: radius,
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.38),
          ),
        );

      case AppCardVariant.outlined:
        decoration = BoxDecoration(
          color: scheme.surfaceContainerLowest,
          borderRadius: radius,
          border: Border.all(
            color: accent.withValues(alpha: 0.20),
            width: 1.1,
          ),
        );

      case AppCardVariant.gradient:
        decoration = BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              scheme.surfaceContainerLowest,
              accent.withValues(alpha: 0.045),
              scheme.surfaceContainerLowest,
            ],
          ),
          borderRadius: radius,
          border: Border.all(
            color: accent.withValues(alpha: 0.14),
          ),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.07),
              blurRadius: 24,
              offset: const Offset(0, 9),
            ),
          ],
        );

      case AppCardVariant.elevated:
        decoration = BoxDecoration(
          color: scheme.surfaceContainerLowest,
          borderRadius: radius,
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.42),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.035),
              blurRadius: 18,
              offset: const Offset(0, 7),
            ),
          ],
        );
    }

    final content = Container(
      margin: onTap == null ? margin : null,
      padding: padding,
      decoration: decoration,
      child: child,
    );

    if (onTap == null) return content;

    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          splashColor: accent.withValues(alpha: 0.06),
          highlightColor: accent.withValues(alpha: 0.025),
          child: content,
        ),
      ),
    );
  }
}

// ── Premium card ─────────────────────────────────────────────────────────────

class PremiumCard extends StatelessWidget {
  const PremiumCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.margin,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: padding,
      margin: margin,
      onTap: onTap,
      child: child,
    );
  }
}

// ── Page header ──────────────────────────────────────────────────────────────

class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.greeting,
    this.icon,
    this.trailing,
    this.margin,
  });

  final String title;
  final String? subtitle;
  final String? greeting;
  final IconData? icon;
  final Widget? trailing;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return AppCard(
      variant: AppCardVariant.gradient,
      accentColor: scheme.primary,
      margin: margin ??
          const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm + 4,
            AppSpacing.md,
            AppSpacing.sm,
          ),
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            _PremiumIconBox(
              icon: icon!,
              color: scheme.primary,
              size: 48,
              iconSize: 22,
            ),
            const SizedBox(width: 14),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (greeting != null) ...[
                  Text(
                    greeting!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                ],
                // Keep full role titles (e.g. "Document Administrator") on one
                // line by scaling down instead of mid-word wrapping.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title,
                    maxLines: 1,
                    softWrap: false,
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    subtitle!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                ],
                // Badge below text so long titles keep full horizontal width.
                if (trailing != null) ...[
                  const SizedBox(height: 10),
                  trailing!,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PremiumFeatureHeader extends StatelessWidget {
  const PremiumFeatureHeader({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.margin,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    return PageHeader(
      icon: icon,
      title: title,
      subtitle: subtitle,
      trailing: trailing,
      margin: margin,
    );
  }
}

// ── Metrics ──────────────────────────────────────────────────────────────────

class MetricTile extends StatelessWidget {
  const MetricTile({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.trend,
    this.trendUp,
    this.onTap,
    this.compact = false,
  });

  final String label;
  final String value;
  final IconData? icon;
  final String? trend;
  final bool? trendUp;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final positive = trendUp != false;
    final trendColor = positive ? const Color(0xFF059669) : scheme.error;

    return AppCard(
      onTap: onTap,
      variant: AppCardVariant.elevated,
      borderRadius: AppRadius.lg,
      padding: EdgeInsets.all(compact ? 12 : 14),
      child: Stack(
        children: [
          Positioned(
            right: -24,
            top: -28,
            child: _SoftCircle(
              size: compact ? 78 : 92,
              color: scheme.primary.withValues(alpha: 0.035),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  if (icon != null)
                    _PremiumIconBox(
                      icon: icon!,
                      color: scheme.primary,
                      size: compact ? 32 : 36,
                      iconSize: compact ? 16 : 18,
                    ),
                  if (icon != null) const Spacer(),
                  if (trend != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: trendColor.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        border: Border.all(
                          color: trendColor.withValues(alpha: 0.16),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            positive
                                ? Icons.arrow_upward_rounded
                                : Icons.arrow_downward_rounded,
                            size: 11,
                            color: trendColor,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            trend!,
                            style: textTheme.labelSmall?.copyWith(
                              color: trendColor,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              SizedBox(height: compact ? 10 : 14),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  maxLines: 1,
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class MetricGrid extends StatelessWidget {
  const MetricGrid({
    super.key,
    required this.children,
    this.crossAxisCount = 2,
    this.spacing = 12,
    this.childAspectRatio = 1.2,
  });

  final List<Widget> children;
  final int crossAxisCount;
  final double spacing;
  final double childAspectRatio;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: crossAxisCount,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: spacing,
      crossAxisSpacing: spacing,
      childAspectRatio: childAspectRatio,
      children: children,
    );
  }
}

// ── Entity list tile ─────────────────────────────────────────────────────────

class EntityTile extends StatelessWidget {
  const EntityTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.leadingIcon,
    this.leadingLabel,
    this.amount,
    this.status,
    this.onTap,
    this.trailing,
    this.index = 0,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final IconData? leadingIcon;
  final String? leadingLabel;
  final String? amount;
  final String? status;
  final VoidCallback? onTap;
  final Widget? trailing;
  final int index;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return AppCard(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs + 2,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 13,
        vertical: 11,
      ),
      onTap: onTap,
      child: Row(
        children: [
          leading ??
              _LeadingAvatar(
                icon: leadingIcon,
                label: leadingLabel ?? title,
              ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.25,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (amount != null)
                Text(
                  amount!,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: scheme.primary,
                  ),
                ),
              if (status != null) ...[
                const SizedBox(height: 4),
                StatusPill.forStatus(context, status!),
              ],
              if (trailing != null) trailing!,
            ],
          ),
        ],
      ),
    )
        .animate(delay: AppMotion.listDelay(index))
        .fadeIn(
          duration: AppMotion.normal,
          curve: AppMotion.easeOut,
        )
        .slideY(
          begin: 0.04,
          end: 0,
          duration: AppMotion.normal,
          curve: AppMotion.easeOut,
        );
  }
}

class _LeadingAvatar extends StatelessWidget {
  const _LeadingAvatar({
    this.icon,
    required this.label,
  });

  final IconData? icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primary.withValues(alpha: 0.15),
            scheme.primary.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadius.md + 2),
      ),
      alignment: Alignment.center,
      child: icon != null
          ? Icon(
              icon,
              size: 20,
              color: scheme.primary,
            )
          : Text(
              label.isNotEmpty ? label[0].toUpperCase() : '?',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: scheme.primary,
              ),
            ),
    );
  }
}

// ── Quick actions ────────────────────────────────────────────────────────────

class QuickActionGrid extends StatelessWidget {
  const QuickActionGrid({
    super.key,
    required this.destinations,
    this.onDestination,
    this.crossAxisCount = 2,
  });

  final List<AppDestination> destinations;
  final ValueChanged<AppDestination>? onDestination;
  final int crossAxisCount;

  @override
  Widget build(BuildContext context) {
    if (destinations.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final count = constraints.maxWidth < 420
              ? 2
              : crossAxisCount.clamp(2, 3);

          final ratio = count == 2 ? 1.43 : 1.55;

          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: destinations.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: count,
              mainAxisSpacing: 11,
              crossAxisSpacing: 11,
              childAspectRatio: ratio,
            ),
            itemBuilder: (context, index) {
              final destination = destinations[index];

              return _QuickActionTile(
                destination: destination,
                index: index,
                onTap: () {
                  if (onDestination != null) {
                    onDestination!(destination);
                    return;
                  }

                  _defaultNavigate(context, destination);
                },
              );
            },
          );
        },
      ),
    );
  }

  void _defaultNavigate(
    BuildContext context,
    AppDestination destination,
  ) {
    if (destination.kind == NavKind.shellTab) {
      if (destination.route != null) {
        Navigator.pushNamed(context, destination.route!);
      }
      return;
    }

    if (destination.route != null) {
      Navigator.pushNamed(context, destination.route!);
    }
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({
    required this.destination,
    required this.onTap,
    required this.index,
  });

  final AppDestination destination;
  final VoidCallback onTap;
  final int index;

  static const _actionAccents = <Color>[
    Color(0xFF0E9F6E),
    Color(0xFF2563EB),
    Color(0xFF8B5CF6),
    Color(0xFFF59E0B),
    Color(0xFFEF4444),
    Color(0xFF0891B2),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final accent =
        _actionAccents[index % _actionAccents.length];

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(21),
        child: Ink(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(21),
            border: Border.all(
              color: accent.withValues(alpha: 0.16),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.035),
                blurRadius: 15,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                right: -32,
                top: -38,
                child: _SoftCircle(
                  size: 105,
                  color: accent.withValues(alpha: 0.055),
                ),
              ),
              Positioned(
                left: 0,
                top: 16,
                bottom: 16,
                child: Container(
                  width: 3,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  15,
                  14,
                  13,
                  13,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _PremiumIconBox(
                          icon: destination.icon,
                          color: accent,
                          size: 42,
                          iconSize: 20,
                        ),
                        const Spacer(),
                        Container(
                          width: 29,
                          height: 29,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.07),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.arrow_forward_rounded,
                            size: 15,
                            color: accent,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      destination.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.1,
                      ),
                    ),
                    if (destination.quickActionSubtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        destination.quickActionSubtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    )
        .animate(
          delay: AppMotion.listDelay(index),
        )
        .fadeIn(
          duration: AppMotion.normal,
          curve: AppMotion.easeOut,
        )
        .slideY(
          begin: 0.06,
          end: 0,
          duration: AppMotion.normal,
          curve: AppMotion.easeOut,
        );
  }
}

// ── Navigation ───────────────────────────────────────────────────────────────

void navigateDestination(
  BuildContext context,
  AppDestination dest,
  List<AppDestination> shellTabs,
) {
  if (dest.kind == NavKind.shellTab) {
    final index = shellTabs.indexWhere(
      (tab) => tab.id == dest.id,
    );

    if (index >= 0) {
      ShellScope.goToTab(context, index);
      return;
    }
  }

  if (dest.route != null) {
    Navigator.pushNamed(context, dest.route!);
  }
}

// ── Status pill ──────────────────────────────────────────────────────────────

class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  final String label;
  final Color color;
  final IconData? icon;

  factory StatusPill.forStatus(
    BuildContext context,
    String status,
  ) {
    return StatusPill(
      label: AppStatusColors.labelFor(status),
      color: AppStatusColors.forStatus(context, status),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(
          color: color.withValues(alpha: 0.28),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 13,
              color: color,
            ),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 11.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PremiumStatusPill extends StatusPill {
  const PremiumStatusPill({
    super.key,
    required super.label,
    required super.color,
    super.icon,
  });

  factory PremiumStatusPill.forStatus(
    BuildContext context,
    String status,
  ) {
    return PremiumStatusPill(
      label: AppStatusColors.labelFor(status),
      color: AppStatusColors.forStatus(context, status),
    );
  }
}

// ── Search & filters ─────────────────────────────────────────────────────────

class AppSearchField extends StatelessWidget {
  const AppSearchField({
    super.key,
    this.controller,
    this.hintText = 'Search…',
    this.onChanged,
    this.onClear,
  });

  final TextEditingController? controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: Icon(
          Icons.search_rounded,
          color: scheme.onSurfaceVariant,
        ),
        suffixIcon: controller != null && controller!.text.isNotEmpty
            ? IconButton(
                tooltip: 'Clear search',
                icon: const Icon(
                  Icons.close_rounded,
                  size: 18,
                ),
                onPressed: () {
                  controller!.clear();
                  onClear?.call();
                  onChanged?.call('');
                },
              )
            : null,
        filled: true,
        fillColor: scheme.surfaceContainerLowest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.45),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.45),
          ),
        ),
      ),
    );
  }
}

class AppFilterBar extends StatelessWidget {
  const AppFilterBar({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.padding,
  });

  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelected;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding ??
          const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
      child: Row(
        children: [
          for (final option in options) ...[
            FilterChip(
              label: Text(option),
              selected: selected == option,
              onSelected: (_) => onSelected(option),
              selectedColor: scheme.primaryContainer,
              checkmarkColor: scheme.primary,
              labelStyle: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: selected == option
                    ? scheme.primary
                    : scheme.onSurfaceVariant,
              ),
              side: BorderSide(
                color: selected == option
                    ? scheme.primary.withValues(alpha: 0.20)
                    : scheme.outlineVariant.withValues(alpha: 0.50),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

// ── Section title ────────────────────────────────────────────────────────────

class PremiumSectionTitle extends StatelessWidget {
  const PremiumSectionTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        12,
        8,
        12,
        8,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 4,
            height: subtitle == null ? 20 : 32,
            margin: const EdgeInsets.only(
              right: 9,
              bottom: 1,
            ),
            decoration: BoxDecoration(
              color: scheme.primary,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.1,
                      ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

// ── Empty state ──────────────────────────────────────────────────────────────

class PremiumEmptyState extends StatelessWidget {
  const PremiumEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: AppCard(
          variant: AppCardVariant.outlined,
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PremiumIconBox(
                icon: icon,
                color: scheme.primary,
                size: 60,
                iconSize: 28,
                circular: true,
              ),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Skeletons ────────────────────────────────────────────────────────────────

class SkeletonTile extends StatelessWidget {
  const SkeletonTile({
    super.key,
    this.height = 72,
  });

  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      height: height,
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs + 2,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
    )
        .animate(onPlay: (controller) => controller.repeat())
        .shimmer(
          duration: const Duration(milliseconds: 1200),
          color: scheme.surfaceContainerLowest.withValues(alpha: 0.55),
        );
  }
}

class SkeletonList extends StatelessWidget {
  const SkeletonList({
    super.key,
    this.count = 6,
  });

  final int count;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final unbounded = !constraints.hasBoundedHeight;
        if (unbounded) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < count; i++) const SkeletonTile(),
            ],
          );
        }
        return ListView.builder(
          itemCount: count,
          padding: const EdgeInsets.only(top: 8),
          itemBuilder: (_, __) => const SkeletonTile(),
        );
      },
    );
  }
}

// ── Private visual helpers ───────────────────────────────────────────────────

class _PremiumIconBox extends StatelessWidget {
  const _PremiumIconBox({
    required this.icon,
    required this.color,
    required this.size,
    required this.iconSize,
    this.circular = false,
  });

  final IconData icon;
  final Color color;
  final double size;
  final double iconSize;
  final bool circular;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.17),
            color.withValues(alpha: 0.07),
          ],
        ),
        shape: circular ? BoxShape.circle : BoxShape.rectangle,
        borderRadius:
            circular ? null : BorderRadius.circular(AppRadius.md + 2),
        border: Border.all(
          color: color.withValues(alpha: 0.12),
        ),
      ),
      alignment: Alignment.center,
      child: Icon(
        icon,
        size: iconSize,
        color: color,
      ),
    );
  }
}

class _SoftCircle extends StatelessWidget {
  const _SoftCircle({
    required this.size,
    required this.color,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
