import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:solar_sales/features/notifications/presentation/providers/notification_providers.dart';

/// Wraps [child] with an unread-count badge from [unreadNotificationCountProvider].
class UnreadBadge extends ConsumerWidget {
  final Widget child;
  final AlignmentGeometry alignment;

  const UnreadBadge({
    super.key,
    required this.child,
    this.alignment = Alignment.topRight,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countAsync = ref.watch(unreadNotificationCountProvider);
    final count = countAsync.maybeWhen(data: (v) => v, orElse: () => 0);
    if (count <= 0) return child;

    final label = count > 99 ? '99+' : '$count';
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      label: '$label unread notifications',
      child: Badge(
        alignment: alignment,
        backgroundColor: scheme.error,
        label: Text(
          label,
          style: TextStyle(
            color: scheme.onError,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
        child: child,
      ),
    );
  }
}
