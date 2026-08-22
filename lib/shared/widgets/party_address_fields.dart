import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

import 'package:solar_sales/shared/utils/validators.dart';
import 'package:solar_sales/shared/models/solar_branding_model.dart';
import 'package:solar_sales/shared/models/party_address_model.dart';

class PartyAddressEditor extends StatefulWidget {
  final String title;
  final PartyAddressModel party;
  final ValueChanged<PartyAddressModel> onChanged;
  final bool readOnly;

  const PartyAddressEditor({
    super.key,
    required this.title,
    required this.party,
    required this.onChanged,
    this.readOnly = false,
  });

  @override
  State<PartyAddressEditor> createState() => _PartyAddressEditorState();
}

class _PartyAddressEditorState extends State<PartyAddressEditor> {
  late final TextEditingController _name;
  late final TextEditingController _address;
  late final TextEditingController _city;
  late final TextEditingController _state;
  late final TextEditingController _pincode;
  late final TextEditingController _gst;
  late final TextEditingController _aadhar;
  late final TextEditingController _phone;
  late final TextEditingController _email;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.party.name);
    _address = TextEditingController(text: widget.party.address);
    _city = TextEditingController(text: widget.party.city);
    _state = TextEditingController(text: widget.party.state);
    _pincode = TextEditingController(text: widget.party.pincode);
    _gst = TextEditingController(text: widget.party.gstNumber);
    _aadhar = TextEditingController(text: widget.party.aadharNumber);
    _phone = TextEditingController(text: widget.party.phone);
    _email = TextEditingController(text: widget.party.email);
  }

  @override
  void didUpdateWidget(covariant PartyAddressEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.party == widget.party) return;
    _syncController(_name, widget.party.name);
    _syncController(_address, widget.party.address);
    _syncController(_city, widget.party.city);
    _syncController(_state, widget.party.state);
    _syncController(_pincode, widget.party.pincode);
    _syncController(_gst, widget.party.gstNumber);
    _syncController(_aadhar, widget.party.aadharNumber);
    _syncController(_phone, widget.party.phone);
    _syncController(_email, widget.party.email);
  }

  void _syncController(TextEditingController controller, String value) {
    if (controller.text == value) return;
    final offset = controller.selection.baseOffset;
    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(
        offset: offset.clamp(0, value.length),
      ),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _city.dispose();
    _state.dispose();
    _pincode.dispose();
    _gst.dispose();
    _aadhar.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  void _emit() {
    widget.onChanged(
      PartyAddressModel(
        name: _name.text,
        address: _address.text,
        city: _city.text,
        state: _state.text,
        pincode: _pincode.text,
        gstNumber: _gst.text,
        aadharNumber: _aadhar.text.replaceAll(RegExp(r'\D'), ''),
        phone: _phone.text,
        email: _email.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        TextFormField(
          controller: _name,
          enabled: !widget.readOnly,
          decoration: const InputDecoration(labelText: 'Name'),
          onChanged: (_) => _emit(),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _address,
          enabled: !widget.readOnly,
          decoration: const InputDecoration(labelText: 'Address'),
          maxLines: 2,
          onChanged: (_) => _emit(),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _city,
                enabled: !widget.readOnly,
                decoration: const InputDecoration(labelText: 'City'),
                onChanged: (_) => _emit(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: _state,
                enabled: !widget.readOnly,
                decoration: const InputDecoration(labelText: 'State'),
                onChanged: (_) => _emit(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _pincode,
                enabled: !widget.readOnly,
                decoration: const InputDecoration(labelText: 'Pincode'),
                keyboardType: TextInputType.number,
                onChanged: (_) => _emit(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: _gst,
                enabled: !widget.readOnly,
                decoration: const InputDecoration(labelText: 'GSTIN'),
                textCapitalization: TextCapitalization.characters,
                onChanged: (_) => _emit(),
                validator: AppValidators.gstNumber,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _aadhar,
          enabled: !widget.readOnly,
          decoration: const InputDecoration(labelText: 'Aadhar No.'),
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(12),
          ],
          onChanged: (_) => _emit(),
          validator: AppValidators.aadharNumber,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _phone,
                enabled: !widget.readOnly,
                decoration: const InputDecoration(labelText: 'Phone'),
                keyboardType: TextInputType.phone,
                onChanged: (_) => _emit(),
                validator: AppValidators.optionalPhone,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: _email,
                enabled: !widget.readOnly,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                onChanged: (_) => _emit(),
                validator: AppValidators.optionalEmail,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class FromAddressSelector extends StatelessWidget {
  final String? branchId;
  final ValueChanged<String?> onChanged;
  final String companyAddress;
  final List<BranchAddressModel> branches;
  final bool readOnly;

  const FromAddressSelector({
    super.key,
    required this.branchId,
    required this.onChanged,
    required this.companyAddress,
    required this.branches,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    final selectedAddress = branchId == null || branchId!.isEmpty
        ? companyAddress
        : _branchAddress(branchId!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('From address', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(
          'Branch address shown on the PDF (company name, GST, and contact stay the same).',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String?>(
          value: branchId ?? '',
          isExpanded: true, // <-- fix: dropdown ko available width use karne do
          decoration: const InputDecoration(labelText: 'Select address'),
          items: [
            if (companyAddress.isNotEmpty)
              DropdownMenuItem<String?>(
                value: '',
                child: Text(
                  'Head office - $companyAddress',
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ...branches.map(
              (b) => DropdownMenuItem<String?>(
                value: b.id ?? '',
                child: Text(
                  '${b.label}${b.isDefault ? ' (default)' : ''}',
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ),
          ],
          onChanged: readOnly
              ? null
              : (v) => onChanged(v == null || v.isEmpty ? '' : v),
        ),
        if (selectedAddress.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(selectedAddress),
          ),
        ],
      ],
    );
  }

  String _branchAddress(String id) {
    for (final b in branches) {
      if (b.id == id) return b.address;
    }
    return companyAddress;
  }
}
