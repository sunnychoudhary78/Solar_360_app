import 'package:flutter/material.dart';

import 'package:solar_sales/core/theme/app_design.dart';
import 'package:solar_sales/shared/models/party_address_model.dart';
import 'package:solar_sales/shared/models/solar_branding_model.dart';

class CompanyLetterheadCard extends StatelessWidget {
  final SolarBrandingModel branding;
  final PartyAddressModel? fromParty;

  const CompanyLetterheadCard({
    super.key,
    required this.branding,
    this.fromParty,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveParty = fromParty;
    final name = effectiveParty?.name.trim().isNotEmpty == true
        ? effectiveParty!.name.trim()
        : branding.companyName.trim();
    final address = effectiveParty?.address.trim().isNotEmpty == true
        ? effectiveParty!.address.trim()
        : branding.companyAddress.trim();
    final gst = effectiveParty?.gstNumber.trim().isNotEmpty == true
        ? effectiveParty!.gstNumber.trim()
        : branding.companyGst.trim();
    final phone = effectiveParty?.phone.trim().isNotEmpty == true
        ? effectiveParty!.phone.trim()
        : branding.companyPhone.trim();
    final email = effectiveParty?.email.trim().isNotEmpty == true
        ? effectiveParty!.email.trim()
        : branding.companyEmail.trim();
    final pan = branding.companyPan.trim();

    if (name.isEmpty &&
        address.isEmpty &&
        gst.isEmpty &&
        phone.isEmpty &&
        email.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name.isEmpty ? 'Company' : name,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            if (address.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(address),
            ],
            if (gst.isNotEmpty ||
                pan.isNotEmpty ||
                phone.isNotEmpty ||
                email.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 6,
                children: [
                  if (gst.isNotEmpty) Text('GSTIN: $gst'),
                  if (pan.isNotEmpty) Text('PAN: $pan'),
                  if (phone.isNotEmpty) Text('Phone: $phone'),
                  if (email.isNotEmpty) Text(email),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
