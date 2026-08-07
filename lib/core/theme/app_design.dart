import 'package:flutter/material.dart';

class AppSpacing {
  static const xxs = 2.0;
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 48.0;
}

class AppRadius {
  static const xs = 6.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 28.0;
  static const pill = 50.0;
}

class AppElevation {
  static const card = 2.0;
  static const floating = 6.0;
  static const modal = 12.0;
}

class AppShadows {
  /// Soft card lift — default for list rows and content cards.
  static List<BoxShadow> card(ColorScheme scheme) => [
        BoxShadow(
          color: Colors.black.withValues(alpha: scheme.brightness == Brightness.dark ? .28 : .04),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: scheme.primary.withValues(alpha: .04),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];

  /// Stronger lift for headers / hero blocks.
  static List<BoxShadow> header(ColorScheme scheme) => [
        BoxShadow(
          color: scheme.primary.withValues(alpha: .12),
          blurRadius: 28,
          offset: const Offset(0, 14),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: scheme.brightness == Brightness.dark ? .35 : .05),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ];

  /// Floating actions / FABs.
  static List<BoxShadow> floating(ColorScheme scheme) => [
        BoxShadow(
          color: scheme.primary.withValues(alpha: .22),
          blurRadius: 22,
          offset: const Offset(0, 10),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: .06),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ];
}

class AppGradients {
  static LinearGradient brand(ColorScheme scheme) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          scheme.primary,
          Color.lerp(scheme.primary, scheme.secondary, 0.55)!,
        ],
      );

  static LinearGradient softHeader(ColorScheme scheme) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          scheme.primaryContainer,
          scheme.secondaryContainer,
          scheme.surfaceContainerHighest,
        ],
      );

  static LinearGradient drawerHeader(ColorScheme scheme) {
    final isDark = scheme.brightness == Brightness.dark;
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isDark
          ? [const Color(0xFF1A2332), const Color(0xFF0F766E)]
          : [scheme.primary, Color.lerp(scheme.primary, scheme.tertiary, 0.35)!],
    );
  }

  static LinearGradient chartFill(ColorScheme scheme) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          scheme.primary.withValues(alpha: .35),
          scheme.primary.withValues(alpha: .02),
        ],
      );
}

class AppMotion {
  static const Duration fast = Duration(milliseconds: 180);
  static const Duration normal = Duration(milliseconds: 280);
  static const Duration slow = Duration(milliseconds: 420);
  static const Duration stagger = Duration(milliseconds: 45);

  static const Curve easeOut = Curves.easeOutCubic;
  static const Curve easeInOut = Curves.easeInOutCubic;
  static const Curve emphasized = Curves.easeOutBack;

  /// Cap list stagger so long lists stay snappy.
  static Duration listDelay(int index, {int maxItems = 8}) {
    final i = index.clamp(0, maxItems);
    return stagger * i;
  }
}

/// Semantic status colors for documents and lead workflow.
class AppStatusColors {
  static Color forStatus(BuildContext context, String status) {
    final scheme = Theme.of(context).colorScheme;
    switch (status.toLowerCase().trim()) {
      case 'draft':
        return scheme.outline;
      case 'pending':
      case 'pending_approval':
      case 'in progress':
      case 'in_progress':
        return const Color(0xFFD97706); // amber-600
      case 'approved':
      case 'active':
      case 'final complete':
      case 'lead completed':
      case 'completed':
        return const Color(0xFF059669); // emerald-600
      case 'sent':
      case 'dispatched':
        return scheme.primary;
      case 'rejected':
      case 'cancelled':
      case 'canceled':
        return scheme.error;
      case 'inactive':
        return scheme.outline;
      // Lead workflow departments / stages
      case 'support':
      case 'document administrator':
      case 'documents':
        return const Color(0xFF6366F1); // indigo
      case 'bank process':
      case 'bank':
        return const Color(0xFF0EA5E9); // sky
      case 'finance':
      case 'finance manager':
      case 'finance user':
        return const Color(0xFF8B5CF6); // violet
      case 'installation':
      case 'installation manager':
      case 'material engineer':
      case 'electrical engineer':
        return const Color(0xFF14B8A6); // teal
      case 'sales':
      case 'sales manager':
        return const Color(0xFF0F766E);
      default:
        return scheme.onSurfaceVariant;
    }
  }

  static String labelFor(String status) {
    switch (status.toLowerCase().trim()) {
      case 'draft':
        return 'Draft';
      case 'pending':
        return 'Pending';
      case 'pending_approval':
        return 'Pending Approval';
      case 'approved':
        return 'Approved';
      case 'sent':
        return 'Sent';
      case 'rejected':
        return 'Rejected';
      case 'active':
        return 'Active';
      case 'inactive':
        return 'Inactive';
      case 'final complete':
      case 'lead completed':
        return 'Completed';
      case 'in progress':
      case 'in_progress':
        return 'In Progress';
      default:
        if (status.isEmpty) return status;
        // Title-case unknown statuses for display.
        return status
            .split(RegExp(r'[_\s]+'))
            .where((w) => w.isNotEmpty)
            .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
            .join(' ');
    }
  }
}
