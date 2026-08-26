import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:solar_sales/core/providers/global_loading_provider.dart';
import 'package:solar_sales/core/theme/app_design.dart';
import 'package:solar_sales/features/customers/data/models/customer_model.dart';
import 'package:solar_sales/features/customers/presentation/providers/customer_providers.dart';
import 'package:solar_sales/features/support/presentation/providers/support_providers.dart';
import 'package:solar_sales/shared/utils/formatters.dart';
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

class SupportTicketFormScreen extends ConsumerStatefulWidget {
  const SupportTicketFormScreen({super.key});

  @override
  ConsumerState<SupportTicketFormScreen> createState() =>
      _SupportTicketFormScreenState();
}

class _SupportTicketFormScreenState
    extends ConsumerState<SupportTicketFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subject = TextEditingController();
  final _description = TextEditingController();
  CustomerModel? _customer;
  String? _requestType;
  String? _category;
  String _priority = 'medium';
  bool _submitting = false;

  @override
  void dispose() {
    _subject.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickCustomer() async {
    final selected = await showModalBottomSheet<CustomerModel>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => const _CustomerPickerSheet(),
    );
    if (selected == null) return;
    setState(() => _customer = selected);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_customer == null) return;
    setState(() => _submitting = true);
    ref.read(globalLoadingProvider.notifier).showLoading('Creating request...');
    try {
      await ref.read(supportApiServiceProvider).create({
        'customer_id': _customer!.id,
        'request_type': _requestType,
        'subject': _subject.text.trim(),
        'description': _description.text.trim(),
        'category': _category,
        'priority': _priority,
        'source': 'admin',
      });
      ref.read(globalLoadingProvider.notifier).hide();
      ref.read(globalLoadingProvider.notifier).showSuccess(
            'Support request created',
          );
      ref.invalidate(supportTicketListProvider);
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
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Customer *'),
              subtitle: Text(
                _customer == null
                    ? 'Select the related customer / lead account'
                    : [
                        _customer!.name,
                        if ((_customer!.email ?? '').isNotEmpty) _customer!.email,
                      ].join(' · '),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: _pickCustomer,
            ),
            if (_customer == null)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  'A customer is required so the conversation is visible in their portal.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            DropdownButtonFormField<String>(
              value: _requestType,
              decoration: const InputDecoration(labelText: 'Request type *'),
              items: [
                for (final entry in _requestTypes.entries)
                  DropdownMenuItem(value: entry.key, child: Text(entry.value)),
              ],
              onChanged: (value) => setState(() => _requestType = value),
              validator: (value) =>
                  value == null || value.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _subject,
              decoration: const InputDecoration(labelText: 'Subject *'),
              validator: (v) => AppValidators.required(v, 'Subject'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              minLines: 4,
              maxLines: 8,
              decoration: const InputDecoration(labelText: 'Description *'),
              validator: (v) => AppValidators.required(v, 'Description'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: [
                for (final entry in _categories.entries)
                  DropdownMenuItem(value: entry.key, child: Text(entry.value)),
              ],
              onChanged: (value) => setState(() => _category = value),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _priority,
              decoration: const InputDecoration(labelText: 'Priority'),
              items: const [
                DropdownMenuItem(value: 'low', child: Text('Low')),
                DropdownMenuItem(value: 'medium', child: Text('Medium')),
                DropdownMenuItem(value: 'high', child: Text('High')),
                DropdownMenuItem(value: 'urgent', child: Text('Urgent')),
              ],
              onChanged: (value) =>
                  setState(() => _priority = value ?? 'medium'),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _submitting || _customer == null ? null : _submit,
              child: const Text('Create request'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomerPickerSheet extends ConsumerStatefulWidget {
  const _CustomerPickerSheet();

  @override
  ConsumerState<_CustomerPickerSheet> createState() =>
      _CustomerPickerSheetState();
}

class _CustomerPickerSheetState extends ConsumerState<_CustomerPickerSheet> {
  final _search = TextEditingController();
  List<CustomerModel> _items = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load([String search = '']) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ref.read(customerRepositoryProvider).list(
            search: search,
            page: 1,
            limit: 50,
          );
      if (!mounted) return;
      setState(() {
        _items = result.data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = cleanError(e);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.7,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: TextField(
                controller: _search,
                decoration: const InputDecoration(
                  hintText: 'Search customer name, phone, email…',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
                onSubmitted: _load,
                onChanged: (value) {
                  if (value.trim().isEmpty) _load();
                },
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(child: Text(_error!))
                      : ListView.builder(
                          itemCount: _items.length,
                          itemBuilder: (context, index) {
                            final customer = _items[index];
                            return ListTile(
                              title: Text(customer.name),
                              subtitle: Text(
                                [
                                  if ((customer.email ?? '').isNotEmpty)
                                    customer.email,
                                  if ((customer.phone ?? '').isNotEmpty)
                                    customer.phone,
                                ].join(' · '),
                              ),
                              onTap: () => Navigator.pop(context, customer),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
