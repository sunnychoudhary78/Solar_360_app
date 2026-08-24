import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:solar_sales/core/providers/global_loading_provider.dart';
import 'package:solar_sales/core/theme/app_design.dart';
import 'package:solar_sales/features/auth/presentation/providers/auth_provider.dart';
import 'package:solar_sales/shared/utils/formatters.dart';
import 'package:solar_sales/shared/utils/validators.dart';
import 'package:solar_sales/shared/widgets/app_bar.dart';
import 'package:solar_sales/shared/widgets/async_states.dart';
import 'package:solar_sales/shared/widgets/premium_feature_components.dart';

import '../../data/models/item_category_model.dart';
import '../providers/item_category_providers.dart';

/// Mobile counterpart of web Settings → Item Categories.
class ItemCategoriesScreen extends ConsumerStatefulWidget {
  const ItemCategoriesScreen({super.key});

  @override
  ConsumerState<ItemCategoriesScreen> createState() =>
      _ItemCategoriesScreenState();
}

class _ItemCategoriesScreenState extends ConsumerState<ItemCategoriesScreen> {
  @override
  Widget build(BuildContext context) {
    final async = ref.watch(itemCategoriesProvider);
    final canManage =
        ref.watch(authProvider).hasPermission('companySettings.update');
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: const AppAppBar(title: 'Item Categories'),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              heroTag: 'item_categories_fab',
              onPressed: _showAddForm,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Category'),
            )
          : null,
      body: async.when(
        loading: () => const LoadingState(),
        error: (e, _) => ErrorState(
          message: cleanError(e),
          onRetry: () => invalidateItemCategories(ref),
        ),
        data: (categories) {
          return RefreshIndicator(
            onRefresh: () async => invalidateItemCategories(ref),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                canManage ? 96 : AppSpacing.xl,
              ),
              children: [
                Text(
                  'Item Categories',
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Manage categories shown in Inventory → Item Master. '
                  'Disabled categories are hidden when creating items but '
                  'existing items keep their category.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                if (categories.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 48),
                    child: EmptyState(
                      title: 'No categories yet',
                      subtitle: 'Add a category to use in Item Master.',
                      icon: Icons.category_outlined,
                    ),
                  )
                else
                  AppCard(
                    variant: AppCardVariant.outlined,
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (var i = 0; i < categories.length; i++) ...[
                          if (i > 0)
                            Divider(
                              height: 1,
                              color: scheme.outlineVariant
                                  .withValues(alpha: 0.55),
                            ),
                          _CategoryRow(
                            category: categories[i],
                            canManage: canManage,
                            onEdit: () => _showForm(category: categories[i]),
                            onToggleVisible: (visible) => _setVisible(
                              categories[i],
                              visible,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _setVisible(
    ItemCategoryModel category,
    bool visible,
  ) async {
    ref.read(globalLoadingProvider.notifier).showLoading(
          visible ? 'Showing…' : 'Hiding…',
        );
    try {
      await ref.read(itemCategoryApiServiceProvider).update(
            category.id,
            isActive: visible,
          );
      if (!mounted) return;
      ref.read(globalLoadingProvider.notifier).hide();
      ref.read(globalLoadingProvider.notifier).showSuccess(
            visible ? 'Category visible in Item Master' : 'Category hidden',
          );
      invalidateItemCategories(ref);
    } catch (e) {
      if (!mounted) return;
      ref.read(globalLoadingProvider.notifier).hide();
      ref.read(globalLoadingProvider.notifier).showError(cleanError(e));
    }
  }

  Future<void> _showAddForm() => _showForm();

  Future<void> _showForm({ItemCategoryModel? category}) async {
    final isEdit = category != null;
    final result = await showDialog<_CategoryFormResult>(
      context: context,
      builder: (dialogContext) => _CategoryFormDialog(
        category: category,
        isEdit: isEdit,
      ),
    );

    if (!mounted || result == null) return;

    ref.read(globalLoadingProvider.notifier).showLoading(
          isEdit ? 'Saving…' : 'Adding…',
        );
    try {
      final api = ref.read(itemCategoryApiServiceProvider);
      if (isEdit) {
        await api.update(
          category.id,
          label: result.label,
          isActive: result.isActive,
        );
      } else {
        await api.create(label: result.label, isActive: result.isActive);
      }
      if (!mounted) return;
      ref.read(globalLoadingProvider.notifier).hide();
      ref.read(globalLoadingProvider.notifier).showSuccess(
            isEdit ? 'Category updated' : 'Category added',
          );
      invalidateItemCategories(ref, afterRouteTransition: true);
    } catch (e) {
      if (!mounted) return;
      ref.read(globalLoadingProvider.notifier).hide();
      ref.read(globalLoadingProvider.notifier).showError(cleanError(e));
    }
  }
}

class _CategoryFormResult {
  const _CategoryFormResult({
    required this.label,
    required this.isActive,
  });

  final String label;
  final bool isActive;
}

class _CategoryFormDialog extends StatefulWidget {
  const _CategoryFormDialog({
    required this.isEdit,
    this.category,
  });

  final bool isEdit;
  final ItemCategoryModel? category;

  @override
  State<_CategoryFormDialog> createState() => _CategoryFormDialogState();
}

class _CategoryFormDialogState extends State<_CategoryFormDialog> {
  late final TextEditingController _controller;
  late final GlobalKey<FormState> _formKey;
  late bool _isActive;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.category?.label ?? '');
    _formKey = GlobalKey<FormState>();
    _isActive = widget.category?.isActive ?? true;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() != true) return;
    Navigator.pop(
      context,
      _CategoryFormResult(
        label: _controller.text.trim(),
        isActive: _isActive,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final category = widget.category;

    return AlertDialog(
      title: Text(widget.isEdit ? 'Edit Category' : 'Add Category'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _controller,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Category name *',
                hintText: 'e.g. Solar Accessories',
              ),
              inputFormatters: [
                LengthLimitingTextInputFormatter(80),
              ],
              validator: (v) => AppValidators.required(v, 'Category name'),
            ),
            if (widget.isEdit && category != null) ...[
              const SizedBox(height: 8),
              Text(
                'Code: ${category.value}',
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
            ],
            const SizedBox(height: 12),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Show in Item Master'),
              subtitle: Text(
                _isActive
                    ? 'Visible in create/edit item dropdowns'
                    : 'Hidden from create/edit item dropdowns',
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
              value: _isActive,
              onChanged: (v) => setState(() => _isActive = v),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(widget.isEdit ? 'Save' : 'Add'),
        ),
      ],
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.category,
    required this.canManage,
    required this.onEdit,
    required this.onToggleVisible,
  });

  final ItemCategoryModel category;
  final bool canManage;
  final VoidCallback onEdit;
  final ValueChanged<bool> onToggleVisible;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.label,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  category.value,
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      category.isActive
                          ? Icons.check_box_rounded
                          : Icons.check_box_outline_blank_rounded,
                      size: 18,
                      color: category.isActive
                          ? scheme.primary
                          : scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      category.isActive ? 'Visible' : 'Hidden',
                      style: textTheme.labelMedium?.copyWith(
                        color: category.isActive
                            ? scheme.primary
                            : scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (canManage) ...[
            Switch.adaptive(
              value: category.isActive,
              onChanged: onToggleVisible,
            ),
            IconButton(
              tooltip: 'Edit',
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
            ),
          ],
        ],
      ),
    );
  }
}
