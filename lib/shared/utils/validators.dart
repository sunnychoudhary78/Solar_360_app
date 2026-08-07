class AppValidators {
  static final _gstinRe = RegExp(
    r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$',
  );

  static String? required(String? value, [String field = 'This field']) {
    if (value == null || value.trim().isEmpty) {
      return '$field is required';
    }
    return null;
  }

  static String? personName(String? value, [String field = 'Name']) {
    final requiredError = required(value, field);
    if (requiredError != null) return requiredError;
    final trimmed = value!.trim();
    if (trimmed.length < 2) return '$field must be at least 2 characters';
    if (trimmed.length > 100) return '$field must be at most 100 characters';
    if (!RegExp(r"^[a-zA-Z][a-zA-Z .'-]*$").hasMatch(trimmed)) {
      return 'Enter a valid $field';
    }
    return null;
  }

  /// Company / product / warehouse names — allows digits and `&`.
  static String? entityName(String? value, [String field = 'Name']) {
    final requiredError = required(value, field);
    if (requiredError != null) return requiredError;
    final trimmed = value!.trim();
    if (trimmed.length < 2) return '$field must be at least 2 characters';
    if (trimmed.length > 100) return '$field must be at most 100 characters';
    if (!RegExp(r"^[a-zA-Z0-9][a-zA-Z0-9 .,'&\-/]*$").hasMatch(trimmed)) {
      return 'Enter a valid $field';
    }
    return null;
  }

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email is required';
    final regex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!regex.hasMatch(value.trim())) return 'Enter a valid email';
    return null;
  }

  static String? optionalEmail(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return email(value);
  }

  /// Normalize phone input to digit string (strips +91 / leading 0).
  static String normalizePhoneDigits(String value) {
    var digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 12 && digits.startsWith('91')) {
      digits = digits.substring(2);
    }
    if (digits.length == 11 && digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    return digits;
  }

  /// 10-digit Indian mobile starting with 6–9.
  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) return 'Phone is required';
    final digits = normalizePhoneDigits(value);
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(digits)) {
      return 'Enter a valid 10-digit mobile number';
    }
    return null;
  }

  /// Optional phone: blank ok; Indian 10-digit or 10–15 digit international.
  static String? optionalPhone(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final digits = normalizePhoneDigits(value);
    if (RegExp(r'^[6-9]\d{9}$').hasMatch(digits)) return null;
    if (digits.length >= 10 && digits.length <= 15) return null;
    return 'Enter a valid 10-digit phone number';
  }

  /// Optional 12-digit Aadhar number (digits only).
  static String? aadharNumber(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 12) {
      return 'Enter a valid 12-digit Aadhar number';
    }
    return null;
  }

  /// GSTIN: allow 1–15 alphanumeric; strict validation at 15 chars.
  static String? gstNumber(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final v = value.trim().toUpperCase();
    if (v.length < 1 || v.length > 15) {
      return 'GSTIN can be 1 to 15 characters';
    }
    if (v.length == 15) {
      if (!_gstinRe.hasMatch(v)) {
        return 'Enter a valid 15-character GSTIN';
      }
      return null;
    }
    if (!RegExp(r'^[0-9A-Z]+$').hasMatch(v)) {
      return 'GSTIN can be 1 to 15 characters';
    }
    return null;
  }

  /// Returns error message if duplicate item IDs found on a document.
  static String? duplicateLineItems(Iterable<String?> itemIds) {
    final seen = <String>{};
    for (final id in itemIds) {
      if (id == null || id.isEmpty) continue;
      if (seen.contains(id)) {
        return 'Duplicate items on the same document are not allowed';
      }
      seen.add(id);
    }
    return null;
  }

  static String? pincode(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    if (!RegExp(r'^\d{6}$').hasMatch(value.trim())) {
      return 'Pincode must be 6 digits';
    }
    return null;
  }

  static String? hsnCode(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final digits = value.trim();
    if (!RegExp(r'^\d{4,8}$').hasMatch(digits)) {
      return 'HSN must be 4–8 digits';
    }
    return null;
  }

  static String? sku(String? value, [String field = 'SKU']) {
    final requiredError = required(value, field);
    if (requiredError != null) return requiredError;
    return _skuFormat(value!.trim(), field);
  }

  /// Empty SKU is allowed (sent as null); format checked when filled.
  static String? optionalSku(String? value, [String field = 'SKU']) {
    if (value == null || value.trim().isEmpty) return null;
    return _skuFormat(value.trim(), field);
  }

  static String? _skuFormat(String trimmed, String field) {
    if (trimmed.length < 2) return '$field must be at least 2 characters';
    if (trimmed.length > 40) return '$field must be at most 40 characters';
    if (!RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9\-_]*$').hasMatch(trimmed)) {
      return 'Enter a valid $field (letters, numbers, - or _)';
    }
    return null;
  }

  static String? maxLength(
    String? value, {
    required int max,
    String field = 'This field',
    bool required = false,
    int? min,
  }) {
    if (value == null || value.trim().isEmpty) {
      return required ? '$field is required' : null;
    }
    final trimmed = value.trim();
    if (min != null && trimmed.length < min) {
      return '$field must be at least $min characters';
    }
    if (trimmed.length > max) {
      return '$field must be at most $max characters';
    }
    return null;
  }

  static String? positiveNumber(String? value, [String field = 'Value']) {
    if (value == null || value.trim().isEmpty) return '$field is required';
    final n = num.tryParse(value);
    if (n == null || n <= 0) return '$field must be greater than 0';
    return null;
  }

  static String? nonNegativeNumber(String? value, [String field = 'Value']) {
    if (value == null || value.trim().isEmpty) return '$field is required';
    final n = num.tryParse(value);
    if (n == null || n < 0) return '$field must be 0 or more';
    return null;
  }

  static String? gstPercent(String? value) {
    final base = nonNegativeNumber(value, 'GST');
    if (base != null) return base;
    final n = num.parse(value!.trim());
    if (n > 100) return 'GST must be between 0 and 100';
    return null;
  }

  static String? loginIdentifier(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email or payroll code is required';
    }
    final trimmed = value.trim();
    if (trimmed.contains('@')) return email(trimmed);
    if (trimmed.length < 3) {
      return 'Payroll code must be at least 3 characters';
    }
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.length < 8) {
      return 'Password must be at least 8 characters';
    }
    return null;
  }

  static String? strongPassword(String? value) {
    if (value == null || value.length < 8) {
      return 'Password must be at least 8 characters';
    }
    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return 'Include at least one uppercase letter';
    }
    if (!RegExp(r'[0-9]').hasMatch(value)) {
      return 'Include at least one digit';
    }
    if (!RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(value)) {
      return 'Include at least one special character';
    }
    return null;
  }

  static String? confirmPassword(String? value, String original) {
    if (value != original) return 'Passwords do not match';
    return null;
  }
}
