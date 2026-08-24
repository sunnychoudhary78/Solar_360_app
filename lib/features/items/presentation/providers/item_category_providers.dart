import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:solar_sales/core/providers/network_providers.dart';
import 'package:solar_sales/shared/constants/item_categories.dart';

import '../../data/item_category_api_service.dart';
import '../../data/models/item_category_model.dart';

final itemCategoryApiServiceProvider = Provider<ItemCategoryApiService>((ref) {
  return ItemCategoryApiService(ref.watch(apiServiceProvider));
});

/// Loads from company-settings API (includes inactive for admin UI).
/// Regular FutureProvider — same pattern as [managedWarehousesProvider].
/// Avoid autoDispose here: invalidating during dialog teardown triggers
/// Flutter's `_dependents.isEmpty` assertion.
final itemCategoriesProvider =
    FutureProvider<List<ItemCategoryModel>>((ref) async {
  return ref.watch(itemCategoryApiServiceProvider).list(includeInactive: true);
});
/// Active categories only — for Item Master / create-item dropdowns.
List<ItemCategoryModel> selectableItemCategories(
  List<ItemCategoryModel> all, {
  String? currentValue,
}) {
  final active = all.where((c) => c.isActive).toList();
  if (currentValue == null || currentValue.isEmpty) return active;

  final hasCurrent = active.any((c) => c.value == currentValue);
  if (hasCurrent) return active;

  // Keep a previously saved (now hidden) category selectable while editing.
  final current = all.where((c) => c.value == currentValue).firstOrNull;
  if (current == null) return active;
  return [...active, current];
}

String itemCategoryLabel(List<ItemCategoryModel>? categories, String? value) {
  if (value == null || value.isEmpty) return '-';
  if (categories != null) {
    for (final category in categories) {
      if (category.value == value) return category.label;
    }
  }
  return ItemCategories.labelFor(value);
}

void invalidateItemCategories(
  WidgetRef ref, {
  bool afterRouteTransition = false,
}) {
  if (afterRouteTransition) {
    // Wait until modal route teardown finishes (see GlobalLoadingNotifier).
    SchedulerBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(itemCategoriesProvider);
    });
    return;
  }
  ref.invalidate(itemCategoriesProvider);
}