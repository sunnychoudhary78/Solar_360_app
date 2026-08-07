import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:solar_sales/shared/constants/payment_modes.dart';
import 'package:solar_sales/shared/utils/validators.dart';

class InvoiceDispatchFields extends StatelessWidget {
  final String? paymentMode;
  final TextEditingController motorVehicleNo;
  final TextEditingController ewayBillNo;
  final ValueChanged<String?> onPaymentModeChanged;
  final bool enabled;

  const InvoiceDispatchFields({
    super.key,
    required this.paymentMode,
    required this.motorVehicleNo,
    required this.ewayBillNo,
    required this.onPaymentModeChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Dispatch', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        DropdownButtonFormField<String?>(
          value: paymentMode != null && paymentMode!.isEmpty ? null : paymentMode,
          decoration: const InputDecoration(labelText: 'Payment mode'),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('— Select —'),
            ),
            ...PaymentModes.values.map(
              (m) => DropdownMenuItem(value: m, child: Text(m)),
            ),
          ],
          onChanged: enabled ? onPaymentModeChanged : null,
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: motorVehicleNo,
          enabled: enabled,
          decoration: const InputDecoration(labelText: 'Motor vehicle no.'),
          inputFormatters: [LengthLimitingTextInputFormatter(50)],
          validator: (v) => AppValidators.maxLength(
            v,
            max: 50,
            field: 'Motor vehicle no.',
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: ewayBillNo,
          enabled: enabled,
          decoration: const InputDecoration(labelText: 'E-way bill no.'),
          inputFormatters: [LengthLimitingTextInputFormatter(50)],
          validator: (v) => AppValidators.maxLength(
            v,
            max: 50,
            field: 'E-way bill no.',
          ),
        ),
      ],
    );
  }
}
