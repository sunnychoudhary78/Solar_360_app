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
  });

  final String status;
  final bool isOverdue;

  @override
  Widget build(BuildContext context) {
    if (isOverdue && (status == 'scheduled' || status == 'in_progress')) {
      return _chip('Overdue', _amcOverdueRose, Colors.white);
    }
    switch (status) {
      case 'in_progress':
        return _chip(
          amcVisitStatusLabel(status),
          Colors.amber.shade700,
          Colors.white,
        );
      case 'completed':
        return _chip(amcVisitStatusLabel(status), _amcEmerald, Colors.white);
      case 'skipped':
      case 'cancelled':
        return _chip(
          amcVisitStatusLabel(status),
          Colors.blueGrey.shade600,
          Colors.white,
        );
      case 'scheduled':
      default:
        return _chip(amcVisitStatusLabel(status), _amcSky, Colors.white);
    }
  }

  Widget _chip(String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
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
