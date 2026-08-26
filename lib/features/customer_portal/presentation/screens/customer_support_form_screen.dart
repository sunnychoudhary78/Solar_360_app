import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:solar_sales/core/providers/global_loading_provider.dart';
import 'package:solar_sales/core/theme/app_design.dart';
import 'package:solar_sales/features/auth/presentation/providers/auth_provider.dart';
import 'package:solar_sales/features/customer_portal/presentation/providers/customer_portal_providers.dart';
import 'package:solar_sales/shared/utils/validators.dart';
import 'package:solar_sales/shared/widgets/app_bar.dart';

const _requestTypes = <String, String>{
  'complaint': 'Complaint',
  'service_request': 'Service Request',
  'technical_support': 'Technical Support',
  'installation_support': 'Installation Support',
  'maintenance': 'Maintenance',
  'billing_payment': 'Billing & Payment',
  'warranty': 'Warranty',
  'other': 'Other',
};

const _categories = <String, String>{
  'solar_panel': 'Solar Panel',
  'inverter': 'Inverter',
  'battery': 'Battery',
  'installation': 'Installation',
  'maintenance': 'Maintenance',
  'subsidy': 'Subsidy',
  'billing': 'Billing',
  'documentation': 'Documentation',
  'other': 'Other',
};

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
  late final TextEditingController _phone;
  late final TextEditingController _email;

  String? _requestType;
  String? _category;
  String _priority = 'medium';
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final customer = ref.read(authProvider).customer;
    _phone = TextEditingController(text: customer?.phone ?? '');
    _email = TextEditingController(text: customer?.email ?? '');
  }

  @override
  void dispose() {
    _subject.dispose();
    _description.dispose();
    _subCategory.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    ref.read(globalLoadingProvider.notifier).showLoading('Submitting request...');
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
        'source': 'customer_portal',
        'contact_method': 'phone',
        'phone': _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        'email': _email.text.trim().isEmpty ? null : _email.text.trim(),
      });
      ref.read(globalLoadingProvider.notifier).hide();
      ref.read(globalLoadingProvider.notifier).showSuccess(
            'Support request submitted',
          );
      ref.invalidate(customerTicketsProvider);
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
              value: _requestType,
              decoration: const InputDecoration(labelText: 'Request type *'),
              items: [
                for (final entry in _requestTypes.entries)
                  DropdownMenuItem(value: entry.key, child: Text(entry.value)),
              ],
              onChanged: _submitting
                  ? null
                  : (value) => setState(() => _requestType = value),
              validator: (value) =>
                  value == null || value.isEmpty ? 'Select a request type' : null,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _subject,
              decoration: const InputDecoration(labelText: 'Subject *'),
              validator: (v) => AppValidators.required(v, 'Subject'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _description,
              minLines: 4,
              maxLines: 8,
              decoration: const InputDecoration(labelText: 'Description *'),
              validator: (v) => AppValidators.required(v, 'Description'),
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<String>(
              value: _category,
              decoration: const InputDecoration(labelText: 'Category'),
              hint: const Text('Select category'),
              items: [
                for (final entry in _categories.entries)
                  DropdownMenuItem(value: entry.key, child: Text(entry.value)),
              ],
              onChanged: _submitting
                  ? null
                  : (value) => setState(() => _category = value),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _subCategory,
              decoration: const InputDecoration(labelText: 'Sub category'),
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<String>(
              value: _priority,
              decoration: const InputDecoration(labelText: 'Priority'),
              items: const [
                DropdownMenuItem(value: 'low', child: Text('Low')),
                DropdownMenuItem(value: 'medium', child: Text('Medium')),
                DropdownMenuItem(value: 'high', child: Text('High')),
                DropdownMenuItem(value: 'urgent', child: Text('Urgent')),
              ],
              onChanged: _submitting
                  ? null
                  : (value) => setState(() => _priority = value ?? 'medium'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
              validator: AppValidators.optionalEmail,
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: const Text('Submit request'),
            ),
          ],
        ),
      ),
    );
  }
}
