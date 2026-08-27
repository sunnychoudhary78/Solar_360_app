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
        'sub_category': _subCategory.text.trim().isEmpty
            ? null
            : _subCategory.text.trim(),
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
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            DropdownButtonFormField<String>(
              key: ValueKey(_requestType),
              initialValue: _requestType,
              decoration: const InputDecoration(
                labelText: 'Support request type *',
              ),
              items: [
                for (final item in SupportTicketConstants.requestTypes)
                  DropdownMenuItem(value: item.value, child: Text(item.label)),
              ],
              onChanged: _submitting
                  ? null
                  : (value) => setState(() => _requestType = value),
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
            DropdownButtonFormField<String>(
              key: ValueKey(_category),
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Category'),
              hint: const Text('Select category'),
              items: [
                for (final item in SupportTicketConstants.categories)
                  DropdownMenuItem(value: item, child: Text(item)),
              ],
              onChanged: _submitting
                  ? null
                  : (value) => setState(() => _category = value),
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<String>(
              key: ValueKey(_priority),
              initialValue: _priority,
              decoration: const InputDecoration(labelText: 'Priority'),
              items: [
                for (final item in SupportTicketConstants.priorities)
                  DropdownMenuItem(value: item.value, child: Text(item.label)),
              ],
              onChanged: _submitting
                  ? null
                  : (value) => setState(() => _priority = value ?? 'medium'),
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
