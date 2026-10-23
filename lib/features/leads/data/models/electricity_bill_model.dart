/// Response model for the AI electricity-bill reader.
///
/// `POST /leads/parse-electricity-bill` (staff) and
/// `POST /customers/leads/parse-electricity-bill` (customer portal).
/// Parse is stateless and does not create a lead — the same file is uploaded
/// again when the lead is saved.
class BillFieldValue {
  final String value;
  final double confidence;

  const BillFieldValue({this.value = '', this.confidence = 0});

  factory BillFieldValue.fromJson(dynamic raw) {
    if (raw is Map) {
      return BillFieldValue(
        value: (raw['value'] ?? '').toString().trim(),
        confidence: _toConfidence(raw['confidence']),
      );
    }
    if (raw == null) return const BillFieldValue();
    return BillFieldValue(value: raw.toString().trim());
  }

  bool get isEmpty => value.trim().isEmpty;

  static double _toConfidence(dynamic raw) {
    final parsed = raw is num
        ? raw.toDouble()
        : double.tryParse('${raw ?? ''}'.trim()) ?? 0;
    return parsed.clamp(0, 1).toDouble();
  }
}

class ElectricityBillParseResult {
  final bool success;
  final String message;
  final Map<String, BillFieldValue> fields;

  /// Field keys skipped because the bill was redacted.
  final List<String> maskedKeys;
  final List<String> warnings;
  final int filledCount;

  /// `image` / `pdf` / `pdf-text` (debug only).
  final String source;
  final String model;

  const ElectricityBillParseResult({
    this.success = true,
    this.message = '',
    this.fields = const {},
    this.maskedKeys = const [],
    this.warnings = const [],
    this.filledCount = 0,
    this.source = '',
    this.model = '',
  });

  factory ElectricityBillParseResult.fromJson(dynamic raw) {
    final root = raw is Map
        ? Map<String, dynamic>.from(raw)
        : <String, dynamic>{};
    final dataRaw = root['data'];
    // Success bodies nest everything under `data`; tolerate flat shapes.
    final data = dataRaw is Map
        ? Map<String, dynamic>.from(dataRaw)
        : root;

    final fields = <String, BillFieldValue>{};
    final rawFields = data['fields'] ?? root['fields'];
    if (rawFields is Map) {
      for (final entry in rawFields.entries) {
        final key = '${entry.key}'.trim();
        if (key.isEmpty) continue;
        fields[key] = BillFieldValue.fromJson(entry.value);
      }
    }

    final declaredCount = _toInt(
      data['filledCount'] ?? data['filled_count'] ?? root['filledCount'],
    );

    return ElectricityBillParseResult(
      success: root['success'] != false,
      message: (root['message'] ?? data['message'] ?? '').toString().trim(),
      fields: fields,
      maskedKeys: _stringList(
        data['maskedKeys'] ?? data['masked_keys'] ?? root['maskedKeys'],
      ),
      warnings: _stringList(data['warnings'] ?? root['warnings']),
      filledCount: declaredCount ?? fields.values.where((f) => !f.isEmpty).length,
      source: (data['source'] ?? '').toString().trim(),
      model: (data['model'] ?? '').toString().trim(),
    );
  }

  /// Missing keys are always treated as `value: "", confidence: 0`.
  BillFieldValue field(String key) =>
      fields[key] ?? const BillFieldValue();

  static List<String> _stringList(dynamic raw) {
    if (raw is List) {
      return raw
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    if (raw is String && raw.trim().isNotEmpty) return [raw.trim()];
    return const [];
  }

  static int? _toInt(dynamic raw) {
    if (raw is num) return raw.toInt();
    return int.tryParse('${raw ?? ''}'.trim());
  }
}

/// Parse failure carrying the API `message` and HTTP status so the form can
/// keep the file, toast the message and hide autofill on `503`.
class ElectricityBillParseException implements Exception {
  final String message;
  final int? statusCode;

  const ElectricityBillParseException(this.message, {this.statusCode});

  @override
  String toString() => message;
}
