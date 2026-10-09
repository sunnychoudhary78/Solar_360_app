import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:solar_sales/core/theme/app_design.dart';
import 'package:solar_sales/features/module/presentation/providers/module_provider.dart';
import 'package:solar_sales/features/notifications/data/models/notification_model.dart';
import 'package:solar_sales/features/notifications/presentation/providers/notification_providers.dart';
import 'package:solar_sales/shared/widgets/app_bar.dart';
import 'package:solar_sales/shared/widgets/async_states.dart';
import 'package:solar_sales/shared/widgets/premium_feature_components.dart';

class NotificationsScreen extends ConsumerWidget {
  final bool showAppBar;

  const NotificationsScreen({super.key, this.showAppBar = true});

  Future<void> _markAllRead(WidgetRef ref) async {
    final module = ref.read(moduleProvider).activeModule;
    await ref.read(notificationRepositoryProvider).markAllRead(module: module);
    ref.invalidate(myNotificationsProvider);
    ref.invalidate(unreadNotificationCountProvider);
  }

  /// Maps web redirect paths to Flutter named routes + optional arguments.
  ({String route, Object? arguments})? _navigationFor(
    NotificationModel notification,
  ) {
    final redirect = notification.redirectUrl?.trim();
    if (redirect != null && redirect.isNotEmpty) {
      final uri = _parseAppUri(redirect);
      final mapped = _mapWebPath(uri.path, query: uri.queryParameters);
      if (mapped != null) return mapped;
    }

    // Assignment notifications store task/lead ids in metadata even if redirect
    // parsing fails.
    final taskId = notification.metadataString('task_id');
    final isTaskAssignment = taskId != null ||
        notification.title.trim().toLowerCase() == 'task assigned to you';
    if (isTaskAssignment) {
      final projectId =
          notification.metadataString('lead_id') ?? notification.leadId;
      return (
        route: '/solar/task-management',
        arguments: <String, String>{
          if (projectId != null && projectId.isNotEmpty) 'project': projectId,
          'task': ?taskId,
        },
      );
    }

    final leadId = notification.leadId;
    if (leadId != null && leadId.isNotEmpty) {
      return (route: '/solar/leads/detail', arguments: leadId);
    }
    return null;
  }

  Uri _parseAppUri(String redirect) {
    final raw = redirect.trim();
    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      return Uri.parse(raw);
    }
    final normalized = raw.startsWith('/') ? raw : '/$raw';
    return Uri.parse('app://local$normalized');
  }

  ({String route, Object? arguments})? _mapWebPath(
    String path, {
    Map<String, String> query = const {},
  }) {
    final cleanPath = path.endsWith('/') && path.length > 1
        ? path.substring(0, path.length - 1)
        : path;

    if (cleanPath == '/solar/task-management') {
      final project = (query['project'] ?? '').trim();
      final task = (query['task'] ?? '').trim();
      return (
        route: '/solar/task-management',
        arguments: <String, String>{
          if (project.isNotEmpty) 'project': project,
          if (task.isNotEmpty) 'task': task,
        },
      );
    }

    if (cleanPath == '/items/approvals' ||
        cleanPath == '/quotations/approvals' ||
        cleanPath == '/invoices/approvals' ||
        cleanPath == '/items' ||
        cleanPath == '/quotations' ||
        cleanPath == '/invoices' ||
        cleanPath == '/customers' ||
        cleanPath == '/inventory' ||
        cleanPath == '/inventory/warehouses' ||
        cleanPath == '/solar/leads') {
      return (route: cleanPath, arguments: null);
    }

    final itemMatch = RegExp(r'^/items/([^/]+)$').firstMatch(cleanPath);
    if (itemMatch != null) {
      return (route: '/items/detail', arguments: itemMatch.group(1));
    }
    final quoteMatch = RegExp(r'^/quotations/([^/]+)$').firstMatch(cleanPath);
    if (quoteMatch != null) {
      return (route: '/quotations/detail', arguments: quoteMatch.group(1));
    }
    final invoiceMatch = RegExp(r'^/invoices/([^/]+)$').firstMatch(cleanPath);
    if (invoiceMatch != null) {
      return (route: '/invoices/detail', arguments: invoiceMatch.group(1));
    }
    final leadMatch = RegExp(r'^/solar/leads/([^/]+)$').firstMatch(cleanPath);
    if (leadMatch != null) {
      return (route: '/solar/leads/detail', arguments: leadMatch.group(1));
    }

    // Exact Flutter-style routes already used by the app.
    if (cleanPath.startsWith('/')) {
      return (route: cleanPath, arguments: null);
    }
    return null;
  }

  Future<void> _openNotification(
    BuildContext context,
    WidgetRef ref,
    NotificationModel notification,
  ) async {
    if (!notification.isRead) {
      await ref.read(notificationRepositoryProvider).markRead(notification.id);
      ref.invalidate(myNotificationsProvider);
      ref.invalidate(unreadNotificationCountProvider);
    }

    final target = _navigationFor(notification);
    if (target == null) return;
    if (!context.mounted) return;

    await Navigator.pushNamed(
      context,
      target.route,
      arguments: target.arguments,
    );
  }

  String _createdLabel(String raw) {
    final date = DateTime.tryParse(raw)?.toLocal();
    if (date == null) return '';
    final now = DateTime.now();
    final difference = now.difference(date);
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inHours < 1) return '${difference.inMinutes}m ago';
    if (difference.inDays < 1) return '${difference.inHours}h ago';
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(myNotificationsProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: showAppBar
          ? AppAppBar(
              title: 'Notifications',
              actions: [
                IconButton(
                  tooltip: 'Mark all as read',
                  onPressed: () => _markAllRead(ref),
                  icon: const Icon(Icons.done_all_rounded),
                ),
              ],
            )
          : null,
      body: notificationsAsync.when(
        loading: () => const LoadingState(),
        error: (e, _) => ErrorState(
          message: e.toString(),
          onRetry: () => ref.invalidate(myNotificationsProvider),
        ),
        data: (notifications) {
          if (notifications.isEmpty) {
            return const EmptyState(
              title: 'No notifications',
              subtitle: 'You’re all caught up for now.',
              icon: Icons.notifications_none_rounded,
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(myNotificationsProvider);
              ref.invalidate(unreadNotificationCountProvider);
              await ref.read(myNotificationsProvider.future);
            },
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(
                0,
                AppSpacing.sm,
                0,
                AppSpacing.lg,
              ),
              itemCount: notifications.length + (showAppBar ? 0 : 1),
              itemBuilder: (context, index) {
                if (!showAppBar && index == 0) {
                  return Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                      ),
                      child: TextButton.icon(
                        onPressed: () => _markAllRead(ref),
                        icon: const Icon(Icons.done_all_rounded),
                        label: const Text('Mark all read'),
                      ),
                    ),
                  );
                }

                final notification =
                    notifications[index - (showAppBar ? 0 : 1)];
                final created = _createdLabel(notification.createdAt);
                final title = notification.title.isEmpty
                    ? 'Notification'
                    : notification.title;
                final subtitle = [
                  notification.message,
                  if (created.isNotEmpty) created,
                ].where((value) => value.isNotEmpty).join('\n');

                return EntityTile(
                  index: index,
                  title: title,
                  subtitle: subtitle,
                  leadingIcon: Icons.notifications_outlined,
                  onTap: () => _openNotification(context, ref, notification),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!notification.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(
                            color: scheme.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      if (notification.hasNavigationTarget)
                        Icon(
                          Icons.chevron_right_rounded,
                          color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
                        ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
