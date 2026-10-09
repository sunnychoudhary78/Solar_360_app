import 'package:flutter/material.dart';

import 'package:solar_sales/features/solar_tasks/data/solar_task_constants.dart';

class SolarTaskBadge extends StatelessWidget {
  const SolarTaskBadge({
    super.key,
    required this.label,
    required this.bg,
    required this.fg,
    required this.border,
  });

  final String label;
  final Color bg;
  final Color fg;
  final Color border;

  factory SolarTaskBadge.status(String status) {
    final colors = SolarTaskConstants.statusBadgeColors(status);
    return SolarTaskBadge(
      label: SolarTaskConstants.statusLabel(status),
      bg: colors.bg,
      fg: colors.fg,
      border: colors.border,
    );
  }

  factory SolarTaskBadge.priority(String priority) {
    final colors = SolarTaskConstants.priorityBadgeColors(priority);
    return SolarTaskBadge(
      label: SolarTaskConstants.priorityLabel(priority),
      bg: colors.bg,
      fg: colors.fg,
      border: colors.border,
    );
  }

  factory SolarTaskBadge.waiting() {
    final colors = SolarTaskConstants.statusBadgeColors('blocked');
    return SolarTaskBadge(
      label: 'Waiting',
      bg: colors.bg,
      fg: colors.fg,
      border: colors.border,
    );
  }

  factory SolarTaskBadge.overdue() {
    return const SolarTaskBadge(
      label: 'Overdue',
      bg: Color(0xFFFFF1F2),
      fg: Color(0xFFBE123C),
      border: Color(0xFFFECDD3),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          height: 1.1,
        ),
      ),
    );
  }
}
