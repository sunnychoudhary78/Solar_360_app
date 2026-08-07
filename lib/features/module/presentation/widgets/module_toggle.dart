import 'package:flutter/material.dart';

import 'package:solar_sales/core/theme/app_design.dart';
import 'package:solar_sales/shared/module/module_access.dart';

/// Premium animated two-up module switcher (Billbook ↔ Green Energy).
class ModuleToggle extends StatelessWidget {
  const ModuleToggle({
    super.key,
    required this.activeModule,
    required this.onChanged,
  });

  final String activeModule;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isSolar = activeModule == AppModules.solar;

    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final half = constraints.maxWidth / 2;
          return Stack(
            children: [
              AnimatedAlign(
                duration: AppMotion.normal,
                curve: AppMotion.easeOut,
                alignment:
                    isSolar ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: half,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    boxShadow: AppShadows.floating(scheme),
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: _Segment(
                      label: 'Billbook',
                      icon: Icons.receipt_long_rounded,
                      selected: !isSolar,
                      onTap: () => onChanged(AppModules.billbook),
                    ),
                  ),
                  Expanded(
                    child: _Segment(
                      label: 'Green Energy',
                      icon: Icons.solar_power_rounded,
                      selected: isSolar,
                      onTap: () => onChanged(AppModules.solar),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = selected ? scheme.onPrimary : scheme.onSurfaceVariant;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration: AppMotion.fast,
            style: TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              color: color,
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 16, color: color),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
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
