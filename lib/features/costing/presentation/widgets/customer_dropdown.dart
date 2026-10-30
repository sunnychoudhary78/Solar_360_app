import 'package:flutter/material.dart';
import 'package:solar_sales/features/customers/data/models/customer_model.dart';

class CustomerDropdown extends StatelessWidget {
  final List<CustomerModel> customers;
  final String? selectedCustomerId;
  final bool isLoading;
  final bool enabled;
  final ValueChanged<String?> onChanged;

  const CustomerDropdown({
    super.key,
    required this.customers,
    required this.selectedCustomerId,
    required this.isLoading,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      key: ValueKey(selectedCustomerId),
      initialValue: selectedCustomerId,
      decoration: InputDecoration(
        labelText: 'Customer *',
        prefixIcon: const Icon(Icons.business_outlined),
        suffixIcon: isLoading
            ? const Padding(
                padding: EdgeInsets.all(14),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : null,
      ),
      isExpanded: true,
      items: customers
          .map(
            (customer) => DropdownMenuItem(
              value: customer.id,
              child: Text(customer.name, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: enabled && !isLoading && customers.isNotEmpty
          ? onChanged
          : null,
      hint: Text(isLoading ? 'Loading customers…' : 'Select a customer'),
    );
  }
}
