import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:solar_sales/core/providers/global_loading_provider.dart';
import 'package:solar_sales/core/theme/app_design.dart';
import 'package:solar_sales/features/auth/presentation/providers/auth_provider.dart';
import 'package:solar_sales/shared/utils/validators.dart';
import 'package:solar_sales/shared/widgets/app_bar.dart';
import 'package:solar_sales/shared/widgets/async_states.dart';
import 'package:solar_sales/shared/widgets/dialogs.dart';

import '../../data/models/customer_model.dart';
import '../providers/customer_providers.dart';
import '../widgets/customer_credentials_dialog.dart';

class CustomerFormScreen extends ConsumerStatefulWidget {
  final String? customerId;

  const CustomerFormScreen({super.key, this.customerId});

  @override
  ConsumerState<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends ConsumerState<CustomerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController();
  final _pincode = TextEditingController();
  final _gst = TextEditingController();
  final _aadhar = TextEditingController();

  bool _loading = false;
  bool _initialized = false;

  bool get isEdit => widget.customerId != null;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _address.dispose();
    _city.dispose();
    _state.dispose();
    _pincode.dispose();
    _gst.dispose();
    _aadhar.dispose();
    super.dispose();
  }

  void _fill(CustomerModel c) {
    _name.text = c.name;
    _email.text = c.email ?? '';
    _phone.text = c.phone ?? '';
    _address.text = c.address ?? '';
    _city.text = c.city ?? '';
    _state.text = c.state ?? '';
    _pincode.text = c.pincode ?? '';
    _gst.text = c.gstNumber ?? '';
    _aadhar.text = c.aadharNumber ?? '';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final canCreate = ref.read(authProvider).hasPermission('customer.create');
    final canUpdate = ref.read(authProvider).hasPermission('customer.update');
    if (isEdit && !canUpdate) return;
    if (!isEdit && !canCreate) return;

    final model = CustomerModel(
      id: widget.customerId ?? '',
      name: _name.text.trim(),
      email: _email.text.trim().isEmpty ? null : _email.text.trim(),
      phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
      address: _address.text.trim().isEmpty ? null : _address.text.trim(),
      city: _city.text.trim().isEmpty ? null : _city.text.trim(),
      state: _state.text.trim().isEmpty ? null : _state.text.trim(),
      pincode: _pincode.text.trim().isEmpty ? null : _pincode.text.trim(),
      gstNumber:
          _gst.text.trim().isEmpty ? null : _gst.text.trim().toUpperCase(),
      aadharNumber: _aadhar.text.trim().isEmpty
          ? null
          : _aadhar.text.replaceAll(RegExp(r'\D'), ''),
    );

    setState(() => _loading = true);
    ref.read(globalLoadingProvider.notifier).showLoading(
          isEdit ? 'Updating customer...' : 'Creating customer...',
        );

    try {
      final repo = ref.read(customerRepositoryProvider);
      Object? popResult = true;
      LoginCredentials? credentials;
      if (isEdit) {
        await repo.update(widget.customerId!, model);
      } else {
        final created = await repo.create(model);
        popResult = created.customer.id.isNotEmpty
            ? created.customer.id
            : true;
        credentials = created.credentials;
      }
      ref.read(customerListProvider.notifier).refresh();
      if (isEdit) {
        ref.invalidate(customerDetailProvider(widget.customerId!));
      }
      ref.read(globalLoadingProvider.notifier).hide();
      ref.read(globalLoadingProvider.notifier).showSuccess(
            isEdit ? 'Customer updated' : 'Customer created',
          );
      if (!mounted) return;
      if (credentials != null) {
        await showCustomerCredentialsDialog(
          context,
          credentials: credentials,
        );
      }
      if (mounted) Navigator.pop(context, popResult);
    } catch (e) {
      ref.read(globalLoadingProvider.notifier).hide();
      ref.read(globalLoadingProvider.notifier).showApiError(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resetPassword() async {
    if (!isEdit || widget.customerId == null) return;
    final confirmed = await showConfirmDialog(
      context,
      title: 'Reset login pass',
      message:
          'Generate a new temporary password for this customer? Share it only with them.',
      confirmLabel: 'Reset',
    );
    if (!confirmed || !mounted) return;

    setState(() => _loading = true);
    ref
        .read(globalLoadingProvider.notifier)
        .showLoading('Resetting password...');
    try {
      final credentials = await ref
          .read(customerRepositoryProvider)
          .resetDefaultPassword(widget.customerId!);
      ref.read(globalLoadingProvider.notifier).hide();
      if (!mounted) return;
      await showCustomerCredentialsDialog(
        context,
        credentials: credentials,
        title: 'Login pass reset',
      );
    } catch (e) {
      ref.read(globalLoadingProvider.notifier).hide();
      ref.read(globalLoadingProvider.notifier).showApiError(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isEdit && !_initialized) {
      final async = ref.watch(customerDetailProvider(widget.customerId!));
      return async.when(
        loading: () => const Scaffold(body: LoadingState()),
        error: (e, _) => Scaffold(
          appBar: AppAppBar(title: isEdit ? 'Edit Customer' : 'New Customer'),
          body: ErrorState(
            message: e.toString(),
            onRetry: () =>
                ref.invalidate(customerDetailProvider(widget.customerId!)),
          ),
        ),
        data: (customer) {
          if (!_initialized) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted || _initialized) return;
              _fill(customer);
              setState(() => _initialized = true);
            });
          }
          return _buildForm();
        },
      );
    }

    return _buildForm();
  }

  Widget _buildForm() {
    final scheme = Theme.of(context).colorScheme;
    final canSave = isEdit
        ? ref.watch(authProvider).hasPermission('customer.update')
        : ref.watch(authProvider).hasPermission('customer.create');

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppAppBar(
        title: isEdit ? 'Edit Customer' : 'New Customer',
        actions: [
          if (isEdit &&
              ref.watch(authProvider).hasPermission('customer.update'))
            IconButton(
              tooltip: 'Reset login pass',
              onPressed: _loading ? null : _resetPassword,
              icon: const Icon(Icons.lock_reset_outlined),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Basic Section
              _buildSectionHeader('Basic Info', 'Customer identity details'),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'Name *',
                  hintText: 'Enter full name',
                ),
                textCapitalization: TextCapitalization.words,
                inputFormatters: [LengthLimitingTextInputFormatter(100)],
                validator: (v) => AppValidators.entityName(v, 'Name'),
              ),

              const SizedBox(height: AppSpacing.xl),

              // Contact Section
              _buildSectionHeader('Contact Info', 'Phone and email details'),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _phone,
                decoration: const InputDecoration(
                  labelText: 'Phone',
                  hintText: '10-digit mobile number',
                ),
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                validator: AppValidators.optionalPhone,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _email,
                decoration: InputDecoration(
                  labelText: isEdit ? 'Email' : 'Email *',
                  hintText: 'Used for customer login',
                ),
                keyboardType: TextInputType.emailAddress,
                inputFormatters: [LengthLimitingTextInputFormatter(100)],
                validator: isEdit
                    ? AppValidators.optionalEmail
                    : AppValidators.email,
              ),

              const SizedBox(height: AppSpacing.xl),

              // Address Section
              _buildSectionHeader('Address Details', 'Primary location'),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _address,
                decoration: const InputDecoration(labelText: 'Street Address'),
                maxLines: 2,
                inputFormatters: [LengthLimitingTextInputFormatter(250)],
                validator: (v) => AppValidators.maxLength(
                  v,
                  max: 250,
                  field: 'Address',
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _city,
                      decoration: const InputDecoration(labelText: 'City'),
                      textCapitalization: TextCapitalization.words,
                      inputFormatters: [LengthLimitingTextInputFormatter(50)],
                      validator: (v) => AppValidators.maxLength(
                        v,
                        max: 50,
                        field: 'City',
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: TextFormField(
                      controller: _state,
                      decoration: const InputDecoration(labelText: 'State'),
                      textCapitalization: TextCapitalization.words,
                      inputFormatters: [LengthLimitingTextInputFormatter(50)],
                      validator: (v) => AppValidators.maxLength(
                        v,
                        max: 50,
                        field: 'State',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _pincode,
                decoration: const InputDecoration(labelText: 'Pincode'),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                validator: AppValidators.pincode,
              ),

              const SizedBox(height: AppSpacing.xl),

              // Tax Section
              _buildSectionHeader('Tax & Identification', 'GST and Aadhar verification'),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _gst,
                decoration: const InputDecoration(
                  labelText: 'GST Number',
                  hintText: '15-character GSTIN',
                ),
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                  LengthLimitingTextInputFormatter(15),
                  _UpperCaseTextFormatter(),
                ],
                validator: AppValidators.gstNumber,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _aadhar,
                decoration: const InputDecoration(
                  labelText: 'Aadhar Number',
                  hintText: '12-digit Aadhar',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(12),
                ],
                validator: AppValidators.aadharNumber,
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: canSave
          ? SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                decoration: BoxDecoration(
                  color: scheme.surface,
                  border: Border(
                    top: BorderSide(
                      color: scheme.outlineVariant.withAlpha(80),
                      width: 1,
                    ),
                  ),
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: _loading ? null : _save,
                    child: Text(
                      isEdit ? 'Update Customer' : 'Create Customer',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}