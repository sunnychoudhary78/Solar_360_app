import 'package:flutter/material.dart';

import 'package:solar_sales/core/theme/app_design.dart';
import 'package:solar_sales/shared/widgets/premium_feature_components.dart';

class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const StatusBadge({super.key, required this.label, required this.color});

  factory StatusBadge.forStatus(String status) {
    late Color color;
    final normalized = status.toLowerCase();
    switch (normalized) {
      case 'draft':
        color = Colors.blueGrey;
      case 'pending':
      case 'pending_approval':
        color = const Color(0xFFD97706);
      case 'approved':
        color = const Color(0xFF059669);
      case 'sent':
        color = const Color(0xFF0F766E);
      case 'rejected':
        color = Colors.red;
      default:
        color = Colors.grey;
    }
    return StatusBadge(
      label: AppStatusColors.labelFor(status),
      color: color,
    );
  }

  @override
  Widget build(BuildContext context) {
    return StatusPill(label: label, color: color);
  }
}
