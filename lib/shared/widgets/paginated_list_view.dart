import 'package:flutter/material.dart';

/// Simple infinite-scroll list helper with pull-to-refresh.
class PaginatedListView<T> extends StatelessWidget {
  final List<T> items;
  final bool isLoadingMore;
  final bool hasMore;
  final Future<void> Function() onRefresh;
  final VoidCallback onLoadMore;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final Widget? empty;
  final EdgeInsetsGeometry padding;
  final Widget? separator;

  const PaginatedListView({
    super.key,
    required this.items,
    required this.isLoadingMore,
    required this.hasMore,
    required this.onRefresh,
    required this.onLoadMore,
    required this.itemBuilder,
    this.empty,
    this.padding = const EdgeInsets.all(16),
    this.separator,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.6,
              child: empty ?? const Center(child: Text('No items')),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.metrics.pixels >=
                  notification.metrics.maxScrollExtent - 200 &&
              hasMore &&
              !isLoadingMore) {
            onLoadMore();
          }
          return false;
        },
        child: ListView.separated(
          padding: padding,
          itemCount: items.length + (isLoadingMore ? 1 : 0),
          separatorBuilder: (_, __) =>
              separator ?? const SizedBox(height: 8),
          itemBuilder: (context, index) {
            if (index >= items.length) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            return itemBuilder(context, items[index], index);
          },
        ),
      ),
    );
  }
}
