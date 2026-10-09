import 'package:flutter/material.dart';

import 'package:solar_sales/features/solar_tasks/data/models/solar_task_models.dart';

class SolarTaskConstants {
  SolarTaskConstants._();

  static const statuses = <({String value, String label})>[
    (value: 'todo', label: 'To do'),
    (value: 'in_progress', label: 'In progress'),
    (value: 'blocked', label: 'Blocked'),
    (value: 'done', label: 'Done'),
    (value: 'cancelled', label: 'Cancelled'),
  ];

  static const priorities = <({String value, String label})>[
    (value: 'low', label: 'Low'),
    (value: 'medium', label: 'Medium'),
    (value: 'high', label: 'High'),
    (value: 'urgent', label: 'Urgent'),
  ];

  static const fallbackPhases = <SolarTaskPhase>[
    SolarTaskPhase(
      key: 'sales',
      label: 'Sales',
      hint: 'Survey, proposal, and conversion',
    ),
    SolarTaskPhase(
      key: 'sales_manager',
      label: 'Sales Manager',
      hint: 'Review and approval',
    ),
    SolarTaskPhase(
      key: 'finance_manager',
      label: 'Finance Manager',
      hint: 'Handover to documents',
    ),
    SolarTaskPhase(
      key: 'documents',
      label: 'Documents',
      hint: 'KYC, portal, and loan paperwork',
    ),
    SolarTaskPhase(
      key: 'bank',
      label: 'Bank Process',
      hint: 'Bank coordination and sanction',
    ),
    SolarTaskPhase(
      key: 'finance',
      label: 'Finance',
      hint: 'Payment verification',
    ),
    SolarTaskPhase(
      key: 'installation_planning',
      label: 'Installation Planning',
      hint: 'Crew and schedule',
    ),
    SolarTaskPhase(
      key: 'material',
      label: 'Material',
      hint: 'Verification and dispatch',
    ),
    SolarTaskPhase(
      key: 'electrical',
      label: 'Electrical Installation',
      hint: 'On-site installation',
    ),
    SolarTaskPhase(
      key: 'subsidy',
      label: 'Subsidy & Closure',
      hint: 'DCR, discom, and final completion',
    ),
  ];

  static const statusWeights = <String, double>{
    'todo': 0,
    'in_progress': 0.5,
    'blocked': 0.5,
    'done': 1,
    'cancelled': 0,
  };

  static String statusLabel(String value) {
    for (final item in statuses) {
      if (item.value == value) return item.label;
    }
    return value;
  }

  static String priorityLabel(String value) {
    for (final item in priorities) {
      if (item.value == value) return item.label;
    }
    return value;
  }

  static int phasePercent(List<SolarTaskModel> tasks) {
    final active = tasks.where((t) => t.status != 'cancelled').toList();
    if (active.isEmpty) return 0;
    final score = active.fold<double>(
      0,
      (sum, task) => sum + (statusWeights[task.status] ?? 0),
    );
    return (score / active.length * 100).round();
  }

  static String formatDate(String? value) {
    if (value == null || value.isEmpty) return '';
    final parts = value.length >= 10
        ? value.substring(0, 10).split('-')
        : const <String>[];
    if (parts.length != 3) return value;
    final year = parts[0];
    final month = parts[1];
    final day = parts[2];
    if (year.isEmpty || month.isEmpty || day.isEmpty) return value;
    return '$day/$month/$year';
  }

  static String initials(String? name) {
    final parts = (name ?? '')
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .take(2)
        .toList();
    if (parts.isEmpty) return '?';
    return parts.map((p) => p[0].toUpperCase()).join();
  }

  static Color statusDotColor(String status) {
    switch (status) {
      case 'todo':
        return const Color(0xFFCBD5E1);
      case 'in_progress':
        return const Color(0xFF0EA5E9);
      case 'blocked':
        return const Color(0xFFFBBF24);
      case 'done':
        return const Color(0xFF10B981);
      case 'cancelled':
        return const Color(0xFFFDA4AF);
      default:
        return const Color(0xFFCBD5E1);
    }
  }

  static ({Color bg, Color fg, Color border}) statusBadgeColors(String status) {
    switch (status) {
      case 'todo':
        return (
          bg: const Color(0xFFF8FAFC),
          fg: const Color(0xFF334155),
          border: const Color(0xFFE2E8F0),
        );
      case 'in_progress':
        return (
          bg: const Color(0xFFF0F9FF),
          fg: const Color(0xFF0369A1),
          border: const Color(0xFFBAE6FD),
        );
      case 'blocked':
        return (
          bg: const Color(0xFFFFFBEB),
          fg: const Color(0xFF92400E),
          border: const Color(0xFFFDE68A),
        );
      case 'done':
        return (
          bg: const Color(0xFFECFDF5),
          fg: const Color(0xFF047857),
          border: const Color(0xFFA7F3D0),
        );
      case 'cancelled':
        return (
          bg: const Color(0xFFFFF1F2),
          fg: const Color(0xFFBE123C),
          border: const Color(0xFFFECDD3),
        );
      default:
        return (
          bg: const Color(0xFFF8FAFC),
          fg: const Color(0xFF334155),
          border: const Color(0xFFE2E8F0),
        );
    }
  }

  static ({Color bg, Color fg, Color border}) priorityBadgeColors(
    String priority,
  ) {
    switch (priority) {
      case 'low':
        return (
          bg: const Color(0xFFF8FAFC),
          fg: const Color(0xFF475569),
          border: const Color(0xFFE2E8F0),
        );
      case 'medium':
        return (
          bg: const Color(0xFFF0F9FF),
          fg: const Color(0xFF0369A1),
          border: const Color(0xFFBAE6FD),
        );
      case 'high':
        return (
          bg: const Color(0xFFFFFBEB),
          fg: const Color(0xFF92400E),
          border: const Color(0xFFFDE68A),
        );
      case 'urgent':
        return (
          bg: const Color(0xFFFFF1F2),
          fg: const Color(0xFFBE123C),
          border: const Color(0xFFFECDD3),
        );
      default:
        return (
          bg: const Color(0xFFF8FAFC),
          fg: const Color(0xFF475569),
          border: const Color(0xFFE2E8F0),
        );
    }
  }
}
