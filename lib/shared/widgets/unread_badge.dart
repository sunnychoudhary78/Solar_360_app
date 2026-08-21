import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:solar_sales/features/notifications/presentation/providers/notification_providers.dart';

/// Wraps [child] with an unread-count badge from [unreadNotificationCountProvider].
///
/// Large counts are capped as `99+` so the badge stays compact and does not
/// clip against the screen / AppBar edge.
class UnreadBadge extends ConsumerWidget {
  final Widget child;

  const UnreadBadge({
    super.key,
    required this.child,
  });

  static String formatCount(int count) {
    if (count <= 0) return '';
    if (count > 99) return '99+';
    return '$count';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countAsync = ref.watch(unreadNotificationCountProvider);
    final count = countAsync.maybeWhen(data: (v) => v, orElse: () => 0);
    if (count <= 0) return child;

    final label = formatCount(count);
    final scheme = Theme.of(context).colorScheme;
    final isWide = label.length >= 3;

    return Semantics(
      label: '$label unread notifications',
      child: Padding(
        // Keep badge inside the AppBar / screen (ClipRect + edge safe).
        padding: const EdgeInsets.only(right: 10, top: 2),
        child: Badge(
          alignment: AlignmentDirectional.topEnd,
          // Pull badge slightly inward so it never sits on the screen edge.
          offset: Offset(isWide ? -10 : -4, 2),
          backgroundColor: scheme.error,
          padding: EdgeInsets.symmetric(
            horizontal: isWide ? 5 : 4,
            vertical: 1,
          ),
          label: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: scheme.onError,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
