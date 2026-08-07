import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:solar_sales/core/theme/app_design.dart';
import 'package:solar_sales/features/shell/presentation/nav_destinations.dart';
import 'package:solar_sales/features/shell/presentation/shell_scope.dart';

// ── Card variants ───────────────────────────────────────────────────────────

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
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final AppCardVariant variant;
  final double? borderRadius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(borderRadius ?? AppRadius.xl);

    final BoxDecoration decoration;
    switch (variant) {
      case AppCardVariant.flat:
        decoration = BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: radius,
        );
      case AppCardVariant.outlined:
        decoration = BoxDecoration(
          color: scheme.surfaceContainerLowest,
          borderRadius: radius,
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: .75),
          ),
        );
      case AppCardVariant.gradient:
        decoration = BoxDecoration(
          gradient: AppGradients.softHeader(scheme),
          borderRadius: radius,
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: .45),
          ),
          boxShadow: AppShadows.header(scheme),
        );
      case AppCardVariant.elevated:
        decoration = BoxDecoration(
          color: scheme.surfaceContainerLowest,
          borderRadius: radius,
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: .55),
          ),
          boxShadow: AppShadows.card(scheme),
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
          child: content,
        ),
      ),
    );
  }
}

/// Backward-compatible alias used across Billbook screens.
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

// ── Page header ─────────────────────────────────────────────────────────────

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
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(AppRadius.md + 4),
                boxShadow: AppShadows.floating(scheme),
              ),
              child: Icon(icon, color: scheme.onPrimary),
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
                    style: textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                ],
                Text(
                  title,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    subtitle!,
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 12), trailing!],
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

// ── Metrics ─────────────────────────────────────────────────────────────────

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

    return AppCard(
      onTap: onTap,
      variant: AppCardVariant.flat,
      borderRadius: AppRadius.lg,
      padding: EdgeInsets.all(compact ? 12 : 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Container(
                  width: compact ? 30 : 34,
                  height: compact ? 30 : 34,
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(
                    icon,
                    size: compact ? 15 : 17,
                    color: scheme.primary,
                  ),
                ),
                const Spacer(),
              ],
              if (trend != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (trendUp == false
                            ? scheme.error
                            : const Color(0xFF059669))
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    trend!,
                    style: textTheme.labelSmall?.copyWith(
                      color: trendUp == false
                          ? scheme.error
                          : const Color(0xFF059669),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: compact ? 8 : 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
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

// ── Entity list tile ────────────────────────────────────────────────────────

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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                    fontWeight: FontWeight.w700,
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
                    fontWeight: FontWeight.w800,
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
        .fadeIn(duration: AppMotion.normal, curve: AppMotion.easeOut)
        .slideY(begin: 0.04, duration: AppMotion.normal, curve: AppMotion.easeOut);
  }
}

class _LeadingAvatar extends StatelessWidget {
  const _LeadingAvatar({this.icon, required this.label});

  final IconData? icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      alignment: Alignment.center,
      child: icon != null
          ? Icon(icon, size: 20, color: scheme.primary)
          : Text(
              label.isNotEmpty ? label[0].toUpperCase() : '?',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: scheme.primary,
              ),
            ),
    );
  }
}

// ── Quick actions ───────────────────────────────────────────────────────────

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
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: destinations.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.45,
        ),
        itemBuilder: (context, i) {
          final dest = destinations[i];
          return _QuickActionTile(
            destination: dest,
            index: i,
            onTap: () {
              if (onDestination != null) {
                onDestination!(dest);
                return;
              }
              _defaultNavigate(context, dest);
            },
          );
        },
      ),
    );
  }

  void _defaultNavigate(BuildContext context, AppDestination dest) {
    if (dest.kind == NavKind.shellTab) {
      // Find tab index via ShellScope — caller should pass onDestination
      // when using shell tabs. Fall through to route if available.
      if (dest.route != null) {
        Navigator.pushNamed(context, dest.route!);
      }
      return;
    }
    if (dest.route != null) {
      Navigator.pushNamed(context, dest.route!);
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return AppCard(
      onTap: onTap,
      variant: AppCardVariant.flat,
      borderRadius: AppRadius.lg,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(destination.icon, size: 17, color: scheme.primary),
          ),
          const Spacer(),
          Text(
            destination.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (destination.quickActionSubtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              destination.quickActionSubtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    )
        .animate(delay: AppMotion.listDelay(index))
        .fadeIn(duration: AppMotion.normal)
        .slideY(begin: 0.05, duration: AppMotion.normal);
  }
}

/// Navigate a destination from a home screen (shell tab or route).
void navigateDestination(
  BuildContext context,
  AppDestination dest,
  List<AppDestination> shellTabs,
) {
  if (dest.kind == NavKind.shellTab) {
    final i = shellTabs.indexWhere((t) => t.id == dest.id);
    if (i >= 0) {
      ShellScope.goToTab(context, i);
      return;
    }
  }
  if (dest.route != null) {
    Navigator.pushNamed(context, dest.route!);
  }
}

// ── Status pill ─────────────────────────────────────────────────────────────

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

  factory StatusPill.forStatus(BuildContext context, String status) {
    return StatusPill(
      label: AppStatusColors.labelFor(status),
      color: AppStatusColors.forStatus(context, status),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: .35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 12,
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

  factory PremiumStatusPill.forStatus(BuildContext context, String status) {
    return PremiumStatusPill(
      label: AppStatusColors.labelFor(status),
      color: AppStatusColors.forStatus(context, status),
    );
  }
}

// ── Search & filters ────────────────────────────────────────────────────────

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
        prefixIcon: Icon(Icons.search_rounded, color: scheme.onSurfaceVariant),
        suffixIcon: controller != null && controller!.text.isNotEmpty
            ? IconButton(
                tooltip: 'Clear search',
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: () {
                  controller!.clear();
                  onClear?.call();
                  onChanged?.call('');
                },
              )
            : null,
        filled: true,
        fillColor: scheme.surfaceContainerLowest,
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
          for (final opt in options) ...[
            FilterChip(
              label: Text(opt),
              selected: selected == opt,
              onSelected: (_) => onSelected(opt),
              selectedColor: scheme.primaryContainer,
              checkmarkColor: scheme.primary,
              labelStyle: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: selected == opt ? scheme.primary : scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

// ── Section title ───────────────────────────────────────────────────────────

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
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle!,
                    style: TextStyle(color: scheme.onSurfaceVariant),
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
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: .10),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 30, color: scheme.primary),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurfaceVariant, height: 1.35),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Skeletons ───────────────────────────────────────────────────────────────

class SkeletonTile extends StatelessWidget {
  const SkeletonTile({super.key, this.height = 72});

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
        .animate(onPlay: (c) => c.repeat())
        .shimmer(
          duration: const Duration(milliseconds: 1200),
          color: scheme.surfaceContainerLowest.withValues(alpha: 0.55),
        );
  }
}

class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.count = 6});

  final int count;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: count,
      padding: const EdgeInsets.only(top: 8),
      itemBuilder: (_, __) => const SkeletonTile(),
    );
  }
}
