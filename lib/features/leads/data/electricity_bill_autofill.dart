import 'models/electricity_bill_model.dart';

/// Device-side rules for the AI electricity-bill autofill.
///
/// The server already strips most masks, but the same rules are re-applied on
/// device so a redacted value can never reach the form.
const double kBillReviewThreshold = 0.75;

/// Bill file rules for the parse call (5 MB, photo or PDF).
const int kBillMaxBytes = 5 * 1024 * 1024;
const List<String> kBillUploadExtensions = [
  'jpg',
  'jpeg',
  'png',
  'webp',
  'gif',
  'jfif',
  'pdf',
];

/// Canonical DISCOM options (same list as web).
const List<String> kBillDiscomOptions = [
  'BSES Rajdhani',
  'BSES Yamuna',
  'TPDDL',
  'NPCL',
  'UPPCL',
  'DHBVN',
  'UHBVN',
  'PSPCL',
  'JVVNL',
  'MSEDCL',
  'BESCOM',
  'TANGEDCO',
  'Other',
];

const List<String> kBillProjectTypes = [
  'Residential',
  'Commercial',
  'Industrial',
  'Agriculture',
];

/// Keys the reader can return, in the order the web form fills them.
const List<String> kBillFieldOrder = [
  'full_name',
  'mobile',
  'email',
  'ca_number',
  'k_number',
  'reference_number',
  'discom',
  'load_section_kw',
  'address',
  'city',
  'state',
  'pincode',
  'project_type',
];

const Map<String, String> _billFieldLabels = {
  'full_name': 'Full name',
  'mobile': 'Mobile',
  'email': 'Email',
  'ca_number': 'Consumer number',
  'k_number': 'K number',
  'reference_number': 'Reference number',
  'discom': 'DISCOM',
  'load_section_kw': 'Load (KW)',
  'address': 'Address',
  'city': 'City',
  'state': 'State',
  'pincode': 'Pincode',
  'project_type': 'Project type',
  'bank_account_name': 'Account holder',
  'bank_name': 'Bank name',
  'account_number': 'Account number',
  'account_type': 'Account type',
  'ifsc_code': 'IFSC',
  'electricity_bill': 'Electricity bill',
  'aadhaar_front': 'Aadhaar front',
  'aadhaar_back': 'Aadhaar back',
  'pan_card': 'PAN card',
  'cheque_passbook': 'Cheque / passbook',
  'available_shadow_free_area': 'Shadow-free area',
  'quotation_amount': 'Quotation amount',
  'visited_employee_name': 'Visited employee',
  'visited_employee_contact': 'Visited employee contact',
};

/// Form section a field lives in, used by the "Still needed" chips.
const Map<String, String> _billFieldSections = {
  'full_name': 'basic',
  'mobile': 'basic',
  'email': 'basic',
  'address': 'basic',
  'city': 'basic',
  'state': 'basic',
  'pincode': 'basic',
  'load_section_kw': 'basic',
  'ca_number': 'electricity',
  'k_number': 'electricity',
  'reference_number': 'electricity',
  'discom': 'electricity',
  'project_type': 'source',
  'bank_account_name': 'bank',
  'bank_name': 'bank',
  'account_number': 'bank',
  'account_type': 'bank',
  'ifsc_code': 'bank',
  'electricity_bill': 'documents',
  'aadhaar_front': 'documents',
  'aadhaar_back': 'documents',
  'pan_card': 'documents',
  'cheque_passbook': 'documents',
  'available_shadow_free_area': 'site',
  'quotation_amount': 'site',
  'visited_employee_name': 'site',
  'visited_employee_contact': 'site',
};

/// Fields required on create; anything still empty is listed as "Still needed".
/// Bank, KYC and site fields are never on the bill, so they are always asked.
const List<String> _billRequiredKeys = [
  'full_name',
  'mobile',
  'ca_number',
  'discom',
  'load_section_kw',
  'address',
  'city',
  'state',
  'pincode',
  'electricity_bill',
  'aadhaar_front',
  'aadhaar_back',
  'pan_card',
  'cheque_passbook',
  'bank_account_name',
  'bank_name',
  'account_number',
  'account_type',
  'ifsc_code',
  'available_shadow_free_area',
  'quotation_amount',
  'visited_employee_name',
  'visited_employee_contact',
];

/// The basic create step only sends the basic tab, so only those are needed.
const List<String> _billRequiredKeysBasic = [
  'full_name',
  'mobile',
  'electricity_bill',
];

String billFieldLabel(String key) => _billFieldLabels[key] ?? key;

String billFieldSection(String key) =>
    _billFieldSections[key] ?? 'basic';

/// Client-side check for the bill file before it is uploaded.
String? billUploadRejection({
  required int sizeBytes,
  required String filename,
}) {
  if (sizeBytes > kBillMaxBytes) {
    return 'Bill file must be 5MB or smaller';
  }
  final name = filename.toLowerCase().split(RegExp(r'[?#]')).first;
  final dot = name.lastIndexOf('.');
  final ext = dot == -1 ? '' : name.substring(dot + 1);
  if (!kBillUploadExtensions.contains(ext)) {
    return 'Upload a photo or PDF of the electricity bill';
  }
  return null;
}

/// `*`, `*****`, `R*mesh`, `98****3210`, `XXXXX6789`, `●●●` … are treats as
/// redacted and must stay empty.
bool isMaskedBillValue(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return false;
  if (RegExp(r'[*＊✱⁎]').hasMatch(text)) return true;
  if (RegExp(r'[•●◉]{2,}').hasMatch(text)) return true;
  final compact = text.replaceAll(RegExp(r'[\s.\-_/]'), '');
  if (RegExp(r'X{3,}', caseSensitive: false).hasMatch(compact)) return true;
  if (RegExp(r'#{2,}').hasMatch(compact)) return true;
  return false;
}

/// DISCOM is a dropdown on web; the app dropdown keeps unknown values verbatim
/// (its own free-text "Other" slot), so the raw name is never lost.
String billDiscomValue(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return '';
  for (final option in kBillDiscomOptions) {
    if (option.toLowerCase() == value.toLowerCase()) return option;
  }
  return value;
}

/// Normalises a read value to what the form can accept. Returns `null` when the
/// value does not look usable, in which case the field stays empty.
String? normalizeBillValue(String key, String raw) {
  final value = raw.trim();
  if (value.isEmpty) return null;

  if (key == 'mobile') {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 10) return digits.substring(digits.length - 10);
    return digits.length == 10 ? digits : null;
  }
  if (key == 'pincode') {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    return digits.length == 6 ? digits : null;
  }
  if (key == 'load_section_kw') {
    final number = double.tryParse(
      value.replaceAll(RegExp(r'[^0-9.]'), ''),
    );
    if (number == null || number <= 0) return null;
    return number == number.roundToDouble()
        ? number.toInt().toString()
        : number.toString();
  }
  if (key == 'email') {
    final valid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
    return valid ? value : null;
  }
  if (key == 'project_type') {
    for (final option in kBillProjectTypes) {
      if (option.toLowerCase() == value.toLowerCase()) return option;
    }
    return null;
  }
  if (key == 'discom') return billDiscomValue(value);
  if (key == 'state') return value;
  if (key == 'address') {
    final words = value.split(RegExp(r'\s+'));
    return words.length <= 30 ? value : words.take(30).join(' ');
  }
  return value;
}

/// What the parse result should do to the form.
class BillAutofillOutcome {
  /// Only the empty, readable, unmasked values — never an overwrite.
  final Map<String, String> values;
  final List<String> filledKeys;
  final List<String> reviewKeys;
  final List<String> maskedKeys;
  final List<String> skippedTypedKeys;

  const BillAutofillOutcome({
    this.values = const {},
    this.filledKeys = const [],
    this.reviewKeys = const [],
    this.maskedKeys = const [],
    this.skippedTypedKeys = const [],
  });
}

/// Builds the fill plan: empty fields only, masked values skipped, review flag
/// for `confidence < 0.75`, name copied to the account holder when it is empty.
BillAutofillOutcome planBillAutofill({
  required ElectricityBillParseResult result,
  required String? Function(String key) typedValue,
}) {
  final values = <String, String>{};
  final filled = <String>[];
  final review = <String>[];
  final masked = <String>[];
  final skippedTyped = <String>[];
  final maskedFromServer = result.maskedKeys
      .map((key) => key.trim())
      .where((key) => key.isNotEmpty)
      .toSet();

  for (final key in kBillFieldOrder) {
    final field = result.fields[key];
    if (field == null) continue;

    final raw = field.value.trim();
    if (raw.isEmpty) {
      if (maskedFromServer.contains(key) && !masked.contains(key)) {
        masked.add(key);
      }
      continue;
    }
    if (isMaskedBillValue(raw)) {
      if (!masked.contains(key)) masked.add(key);
      continue;
    }

    final normalized = normalizeBillValue(key, raw);
    if (normalized == null || normalized.isEmpty) continue;

    if ((typedValue(key) ?? '').trim().isNotEmpty) {
      skippedTyped.add(key);
      continue;
    }

    values[key] = normalized;
    filled.add(key);
    if (field.confidence < kBillReviewThreshold) review.add(key);
  }

  // Copy the name onto the account holder only when that is still empty.
  final nameFromBill = values['full_name'];
  if (nameFromBill != null &&
      !values.containsKey('bank_account_name') &&
      (typedValue('bank_account_name') ?? '').trim().isEmpty) {
    values['bank_account_name'] = nameFromBill;
    filled.add('bank_account_name');
  }

  return BillAutofillOutcome(
    values: values,
    filledKeys: filled,
    reviewKeys: review,
    maskedKeys: masked,
    skippedTypedKeys: skippedTyped,
  );
}

/// Required-on-create fields that are still empty.
List<String> stillNeededBillKeys({
  required bool fullForm,
  required String? Function(String key) typedValue,
}) {
  final keys = fullForm ? _billRequiredKeys : _billRequiredKeysBasic;
  return [
    for (final key in keys)
      if ((typedValue(key) ?? '').trim().isEmpty) key,
  ];
}
