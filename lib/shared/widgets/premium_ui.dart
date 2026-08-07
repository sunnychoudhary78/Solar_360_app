import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:solar_sales/core/theme/app_design.dart';
import 'package:solar_sales/shared/widgets/premium_feature_components.dart';

/// Fade + slide entrance for list/dashboard items.
extension AppMotionWidgets on Widget {
  Widget appFadeSlide({
    int index = 0,
    Offset begin = const Offset(0, 0.06),
  }) {
    return animate(delay: AppMotion.listDelay(index))
        .fadeIn(duration: AppMotion.normal, curve: AppMotion.easeOut)
        .slideY(
          begin: begin.dy,
          duration: AppMotion.normal,
          curve: AppMotion.easeOut,
        );
  }
}

class DocumentListTile extends StatelessWidget {
  const DocumentListTile({
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return PremiumCard(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs + 2,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
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
                  if (amount != null) const SizedBox(height: 4),
                  PremiumStatusPill.forStatus(context, status!),
                ],
                if (trailing != null) ...[
                  const SizedBox(height: 4),
                  trailing!,
                ],
              ],
            ),
            if (onTap != null) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ],
          ],
        ),
      ),
    );
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
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      alignment: Alignment.center,
      child: icon != null
          ? Icon(icon, color: scheme.primary, size: 22)
          : Text(
              label.isNotEmpty ? label[0].toUpperCase() : '?',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: scheme.primary,
                fontSize: 16,
              ),
            ),
    );
  }
}

class FilterChipItem {
  const FilterChipItem({required this.value, required this.label});
  final String value;
  final String label;
}

class FilterChipBar extends StatelessWidget {
  const FilterChipBar({
    super.key,
    required this.items,
    required this.selected,
    required this.onSelected,
    this.padding,
  });

  final List<FilterChipItem> items;
  /// Empty string means "All" / no filter.
  final String selected;
  final ValueChanged<String> onSelected;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: padding ??
            const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          final item = items[index];
          final isSelected = item.value == selected;
          return AnimatedContainer(
            duration: AppMotion.fast,
            curve: AppMotion.easeOut,
            child: FilterChip(
              selected: isSelected,
              showCheckmark: false,
              label: Text(item.label),
              selectedColor: scheme.primaryContainer,
              backgroundColor: scheme.surfaceContainerLow,
              labelStyle: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: isSelected ? scheme.primary : scheme.onSurfaceVariant,
              ),
              side: BorderSide(
                color: isSelected
                    ? scheme.primary.withValues(alpha: 0.35)
                    : scheme.outlineVariant.withValues(alpha: 0.55),
              ),
              onSelected: (_) => onSelected(item.value),
            ),
          );
        },
      ),
    );
  }
}

class FormSectionCard extends StatelessWidget {
  const FormSectionCard({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
    this.margin,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin ??
          const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.sm,
          ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PremiumSectionTitle(
            title: title,
            subtitle: subtitle,
            trailing: trailing,
          ),
          PremiumCard(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: child,
          ),
        ],
      ),
    );
  }
}

class StickyFormActions extends StatelessWidget {
  const StickyFormActions({
    super.key,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    this.primaryLoading = false,
    this.primaryEnabled = true,
  });

  final String primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final bool primaryLoading;
  final bool primaryEnabled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Material(
      color: scheme.surface.withValues(alpha: 0.96),
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: scheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
        ),
        padding: EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm + 4,
          AppSpacing.md,
          bottom > 0 ? bottom : AppSpacing.md,
        ),
        child: Row(
          children: [
            if (secondaryLabel != null && onSecondary != null) ...[
              Expanded(
                child: OutlinedButton(
                  onPressed: onSecondary,
                  child: Text(secondaryLabel!),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
            Expanded(
              flex: secondaryLabel != null ? 1 : 1,
              child: FilledButton(
                onPressed: primaryEnabled && !primaryLoading ? onPrimary : null,
                child: primaryLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(primaryLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DocumentDetailHeader extends StatelessWidget {
  const DocumentDetailHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.status,
    this.meta,
    this.actions,
    this.icon,
  });

  final String title;
  final String? subtitle;
  final String? status;
  final List<String>? meta;
  final List<Widget>? actions;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primaryContainer,
            scheme.secondaryContainer.withValues(alpha: 0.85),
            scheme.surfaceContainerHighest,
          ],
        ),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: .55)),
        boxShadow: AppShadows.header(scheme),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (icon != null) ...[
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(AppRadius.md + 4),
                  ),
                  child: Icon(icon, color: scheme.onPrimary),
                ),
                const SizedBox(width: 14),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (status != null) PremiumStatusPill.forStatus(context, status!),
            ],
          ),
          if (meta != null && meta!.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: meta!
                  .map(
                    (m) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.surface.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        m,
                        style: textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
          if (actions != null && actions!.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(spacing: 8, runSpacing: 8, children: actions!),
          ],
        ],
      ),
    );
  }
}

class LineItemCard extends StatelessWidget {
  const LineItemCard({
    super.key,
    required this.name,
    this.hsnSac,
    this.quantity,
    this.unit,
    this.rate,
    this.gstRate,
    this.amount,
    this.onTap,
    this.trailing,
  });

  final String name;
  final String? hsnSac;
  final String? quantity;
  final String? unit;
  final String? rate;
  final String? gstRate;
  final String? amount;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final metaParts = <String>[
      if (hsnSac != null && hsnSac!.isNotEmpty) 'HSN $hsnSac',
      if (quantity != null) 'Qty $quantity${unit != null ? ' $unit' : ''}',
      if (rate != null) 'Rate $rate',
      if (gstRate != null) 'GST $gstRate%',
    ];

    return PremiumCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(
                Icons.inventory_2_outlined,
                size: 18,
                color: scheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (metaParts.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      metaParts.join(' · '),
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (amount != null)
              Text(
                amount!,
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
          ],
        ),
      ),
    );
  }
}

class StickyActionBar extends StatelessWidget {
  const StickyActionBar({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Material(
      color: scheme.surface.withValues(alpha: 0.96),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: scheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
        ),
        padding: EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm + 4,
          AppSpacing.md,
          bottom > 0 ? bottom : AppSpacing.md,
        ),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.end,
          children: children,
        ),
      ),
    );
  }
}
