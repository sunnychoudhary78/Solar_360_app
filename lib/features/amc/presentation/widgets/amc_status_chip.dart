import 'package:flutter/material.dart';

import 'package:solar_sales/core/theme/app_design.dart';
import 'package:solar_sales/features/amc/data/models/amc_models.dart';

const _amcOverdueRose = Color(0xFFE11D48);
const _amcEmerald = Color(0xFF059669);
const _amcSky = Color(0xFF0284C7);

class AmcStatusChip extends StatelessWidget {
  const AmcStatusChip({
    super.key,
    required this.status,
    this.isOverdue = false,
    this.forceOverdueLabel = false,
  });

  final String status;
  final bool isOverdue;
  final bool forceOverdueLabel;

  @override
  Widget build(BuildContext context) {
    if (forceOverdueLabel ||
        (isOverdue && (status == 'scheduled' || status == 'in_progress'))) {
      return _chip(
        'Overdue',
        _amcOverdueRose.withValues(alpha: .08),
        _amcOverdueRose,
      );
    }
    final label = amcVisitStatusLabel(status);
    switch (status) {
      case 'in_progress':
        return _chip(label, Colors.amber.shade50, Colors.amber.shade800);
      case 'completed':
      case 'active':
        return _chip(label, _amcEmerald.withValues(alpha: .08), _amcEmerald);
      case 'skipped':
      case 'draft':
        return _chip(label, Colors.blueGrey.shade50, Colors.blueGrey.shade600);
      case 'cancelled':
        return _chip(
          label,
          _amcOverdueRose.withValues(alpha: .08),
          _amcOverdueRose,
        );
      case 'expired':
        return _chip(label, Colors.amber.shade50, Colors.amber.shade800);
      case 'scheduled':
      default:
        return _chip(label, _amcSky.withValues(alpha: .08), _amcSky);
    }
  }

  Widget _chip(String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: fg.withValues(alpha: .25)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
