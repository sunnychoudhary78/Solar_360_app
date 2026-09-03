import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:solar_sales/core/providers/global_loading_provider.dart';
import 'package:solar_sales/core/theme/app_design.dart';
import 'package:solar_sales/features/customer_portal/presentation/providers/customer_portal_providers.dart';
import 'package:solar_sales/features/support/data/support_ticket_constants.dart';
import 'package:solar_sales/shared/utils/validators.dart';
import 'package:solar_sales/shared/widgets/app_bar.dart';

class CustomerSupportFormScreen extends ConsumerStatefulWidget {
  const CustomerSupportFormScreen({super.key});

  @override
  ConsumerState<CustomerSupportFormScreen> createState() =>
      _CustomerSupportFormScreenState();
}

class _CustomerSupportFormScreenState
    extends ConsumerState<CustomerSupportFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subject = TextEditingController();
  final _description = TextEditingController();
  final _subCategory = TextEditingController();

  String? _requestType;
  String? _category;
  String _priority = 'medium';
  bool _submitting = false;

  @override
  void dispose() {
    _subject.dispose();
    _description.dispose();
    _subCategory.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    ref
        .read(globalLoadingProvider.notifier)
        .showLoading('Submitting request...');
    try {
      await ref.read(customerPortalApiServiceProvider).createTicket({
        'request_type': _requestType,
        'subject': _subject.text.trim(),
        'description': _description.text.trim(),
        'category': _category,
        'sub_category': SupportTicketConstants.encodeRequestTypeInSubCategory(
          requestType: _requestType,
          subCategory: _subCategory.text.trim(),
        ),
        'priority': _priority,
      });
      ref.read(globalLoadingProvider.notifier).hide();
      ref
          .read(globalLoadingProvider.notifier)
          .showSuccess('Support request submitted');
      await ref.read(customerTicketsProvider.notifier).refresh();
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      ref.read(globalLoadingProvider.notifier).hide();
      ref.read(globalLoadingProvider.notifier).showApiError(e);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppAppBar(title: 'New support request'),
      body: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.disabled,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            _SupportOptionDropdown(
              label: 'Support request type *',
              value: _requestType,
              enabled: !_submitting,
              items: [
                for (final item in SupportTicketConstants.requestTypes)
                  DropdownMenuItem<String>(
                    value: item.value,
                    child: Text(item.label),
                  ),
              ],
              onChanged: (value) => setState(() => _requestType = value),
              validator: (value) => value == null || value.isEmpty
                  ? 'Please select the type of support request.'
                  : null,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _subject,
              decoration: const InputDecoration(
                labelText: 'Subject *',
                hintText: 'Example: Inverter is not working',
              ),
              validator: (v) => AppValidators.required(v, 'Subject'),
            ),
            const SizedBox(height: AppSpacing.md),
            _SupportOptionDropdown(
              label: 'Category',
              value: _category,
              hint: const Text('Select category'),
              enabled: !_submitting,
              items: [
                for (final item in SupportTicketConstants.categories)
                  DropdownMenuItem<String>(value: item, child: Text(item)),
              ],
              onChanged: (value) => setState(() => _category = value),
            ),
            const SizedBox(height: AppSpacing.md),
            _SupportOptionDropdown(
              label: 'Priority',
              value: _priority,
              enabled: !_submitting,
              items: [
                for (final item in SupportTicketConstants.priorities)
                  DropdownMenuItem<String>(
                    value: item.value,
                    child: Text(item.label),
                  ),
              ],
              onChanged: (value) =>
                  setState(() => _priority = value ?? 'medium'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _subCategory,
              decoration: const InputDecoration(
                labelText: 'Sub category',
                hintText: 'Example: Display error',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _description,
              minLines: 4,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: 'Description *',
                hintText: 'Describe your issue...',
              ),
              validator: (v) => AppValidators.required(v, 'Description'),
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: Text(_submitting ? 'Submitting...' : 'Submit request'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Keeps the FormField identity stable so selecting an option does not
/// recreate the dropdown (which crashes with the "exactly one item" assertion).
class _SupportOptionDropdown extends StatefulWidget {
  const _SupportOptionDropdown({
    required this.label,
    required this.items,
    required this.onChanged,
    this.value,
    this.hint,
    this.validator,
    this.enabled = true,
  });

  final String label;
  final String? value;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?> onChanged;
  final Widget? hint;
  final String? Function(String?)? validator;
  final bool enabled;

  @override
  State<_SupportOptionDropdown> createState() => _SupportOptionDropdownState();
}

class _SupportOptionDropdownState extends State<_SupportOptionDropdown> {
  late final String? _initialValue = _safeValue(widget.value, widget.items);

  static String? _safeValue(
    String? value,
    List<DropdownMenuItem<String>> items,
  ) {
    if (value == null) return null;
    var matches = 0;
    for (final item in items) {
      if (item.value == value) matches++;
    }
    return matches == 1 ? value : null;
  }

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: _initialValue,
      isExpanded: true,
      decoration: InputDecoration(labelText: widget.label),
      hint: widget.hint,
      items: widget.items,
      onChanged: widget.enabled ? widget.onChanged : null,
      validator: widget.validator,
    );
  }
}
