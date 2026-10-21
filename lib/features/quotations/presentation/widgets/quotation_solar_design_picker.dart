import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:solar_sales/core/providers/global_loading_provider.dart';
import 'package:solar_sales/features/auth/presentation/providers/auth_provider.dart';
import 'package:solar_sales/features/leads/presentation/providers/lead_providers.dart';
import 'package:solar_sales/features/quotations/data/models/quotation_model.dart';
import 'package:solar_sales/features/solar_design/data/models/solar_design_models.dart';
import 'package:solar_sales/features/solar_design/presentation/providers/solar_design_providers.dart';
import 'package:solar_sales/features/solar_design/presentation/screens/solar_designs_screen.dart';
import 'package:solar_sales/features/solar_design/presentation/solar_design_access.dart';
import 'package:solar_sales/shared/utils/formatters.dart';

class QuotationSolarDesignPicker extends ConsumerWidget {
  const QuotationSolarDesignPicker({
    super.key,
    required this.customerId,
    required this.selectedDesignId,
    this.attachedDesign,
    required this.onChanged,
  });

  final String? customerId;
  final String? selectedDesignId;
  final QuotationSolarDesign? attachedDesign;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = customerId?.trim() ?? '';
    if (id.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 12),
        child: Text(
          'Select a customer to attach a 3D solar design.',
        ),
      );
    }

    final async = ref.watch(customerSolarDesignsProvider(id));
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.only(top: 12),
        child: LinearProgressIndicator(),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Could not load 3D designs: ${cleanError(e)}',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            TextButton(
              onPressed: () => ref.invalidate(customerSolarDesignsProvider(id)),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (result) => _PickerBody(
        customerId: id,
        result: result,
        selectedDesignId: selectedDesignId,
        attachedDesign: attachedDesign,
        onChanged: onChanged,
      ),
    );
  }
}

class _PickerBody extends ConsumerWidget {
  const _PickerBody({
    required this.customerId,
    required this.result,
    required this.selectedDesignId,
    required this.attachedDesign,
    required this.onChanged,
  });

  final String customerId;
  final CustomerSolarDesignsResult result;
  final String? selectedDesignId;
  final QuotationSolarDesign? attachedDesign;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final canOpenDesigner =
        SolarDesignAccess.canRead(auth) || SolarDesignAccess.canCreate(auth);
    final selected = selectedDesignId?.trim();
    final designs = [...result.designs];
    if (selected != null &&
        selected.isNotEmpty &&
        designs.every((d) => d.id != selected) &&
        attachedDesign != null &&
        attachedDesign!.id == selected) {
      designs.insert(
        0,
        CustomerSolarDesignRow(
          id: attachedDesign!.id,
          name: attachedDesign!.name,
          capacityKw: attachedDesign!.capacityKw,
          panelCount: attachedDesign!.panelCount,
        ),
      );
    }

    final dropdownValue =
        selected != null &&
            selected.isNotEmpty &&
            designs.any((d) => d.id == selected)
        ? selected
        : null;

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String?>(
            value: dropdownValue,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: '3D solar design (optional)',
              prefixIcon: const Icon(Icons.view_in_ar_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 14,
              ),
            ),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('No 3D design'),
              ),
              for (final design in designs)
                DropdownMenuItem<String?>(
                  value: design.id,
                  child: Text(
                    design.pickerLabel,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
            ],
            onChanged: onChanged,
          ),
          if (designs.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                result.leads.isEmpty
                    ? 'This customer has no Green Energy leads yet. '
                          'Create a lead (name + mobile) so a 3D design can be linked.'
                    : 'No 3D designs for this customer yet. Open a lead to create one.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          if (canOpenDesigner && result.leads.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _openDesigner(context, ref),
                icon: const Icon(Icons.add_box_outlined, size: 18),
                label: const Text('Create / open 3D design'),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _openDesigner(BuildContext context, WidgetRef ref) async {
    final leadId = await showModalBottomSheet<String>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'Choose a lead to open the 3D designer',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              for (final lead in result.leads)
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(lead.displayLabel),
                  subtitle: Text(
                    lead.hasDesign ? 'Has a 3D design' : 'No design yet',
                  ),
                  onTap: () => Navigator.pop(context, lead.id),
                ),
            ],
          ),
        );
      },
    );
    if (leadId == null || leadId.isEmpty || !context.mounted) return;

    ref.read(globalLoadingProvider.notifier).showLoading('Opening designer...');
    try {
      final lead = await ref.read(leadRepositoryProvider).getLeadById(leadId);
      ref.read(globalLoadingProvider.notifier).hide();
      if (!context.mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => SolarDesignsScreen(lead: lead)),
      );
      ref.invalidate(customerSolarDesignsProvider(customerId));
    } catch (e) {
      ref.read(globalLoadingProvider.notifier).hide();
      ref.read(globalLoadingProvider.notifier).showApiError(e);
    }
  }
}
