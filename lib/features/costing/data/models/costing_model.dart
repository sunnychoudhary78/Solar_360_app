import 'package:solar_sales/shared/utils/formatters.dart';

class CostingCustomer {
  final String id;
  final String name;
  final String? email;
  final String? phone;
  final String? city;
  final String? state;

  const CostingCustomer({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.city,
    this.state,
  });

  factory CostingCustomer.fromJson(Map<String, dynamic> json) {
    return CostingCustomer(
      id: asString(json['id']),
      name: asString(json['name'], asString(json['full_name'])),
      email: json['email']?.toString(),
      phone: json['phone']?.toString(),
      city: json['city']?.toString(),
      state: json['state']?.toString(),
    );
  }
}

class CostingLead {
  final String id;
  final String leadCode;
  final String fullName;
  final String? email;
  final String? mobile;
  final String? address;
  final String? city;
  final String? state;

  const CostingLead({
    required this.id,
    required this.fullName,
    this.leadCode = '',
    this.email,
    this.mobile,
    this.address,
    this.city,
    this.state,
  });

  factory CostingLead.fromJson(Map<String, dynamic> json) => CostingLead(
    id: asString(json['id']),
    leadCode: asString(json['lead_code']),
    fullName: asString(json['full_name'], asString(json['name'])),
    email: json['email']?.toString(),
    mobile: (json['mobile'] ?? json['phone'])?.toString(),
    address: json['address']?.toString(),
    city: json['city']?.toString(),
    state: json['state']?.toString(),
  );
}

class CostingVendor {
  final String id;
  final String name;
  final String? address;
  final String? contactNumber;
  final bool isActive;

  const CostingVendor({
    required this.id,
    required this.name,
    this.address,
    this.contactNumber,
    this.isActive = true,
  });

  factory CostingVendor.fromJson(Map<String, dynamic> json) => CostingVendor(
    id: asString(json['id']),
    name: asString(json['name']),
    address: json['address']?.toString(),
    contactNumber: json['contact_number']?.toString(),
    isActive: json['is_active'] != false,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'address': address,
    'contact_number': contactNumber,
  };
}

class CostingLine {
  final String id;
  final String? itemId;
  final String name;
  final String kind;
  final String? unit;
  final double unitPrice;
  final double quantity;
  final double amount;
  final DateTime? createdAt;

  const CostingLine({
    required this.id,
    required this.name,
    required this.kind,
    required this.unitPrice,
    required this.quantity,
    required this.amount,
    this.createdAt,
    this.itemId,
    this.unit,
  });

  factory CostingLine.fromJson(Map<String, dynamic> json) {
    final item = json['item'];
    return CostingLine(
      id: asString(json['id']),
      itemId: json['item_id']?.toString(),
      name: asString(json['name'], item is Map ? asString(item['name']) : ''),
      kind: asString(json['kind'], 'custom'),
      unit:
          json['unit']?.toString() ??
          (item is Map ? item['unit']?.toString() : null),
      unitPrice: asDouble(json['unit_price']),
      quantity: asDouble(json['quantity']),
      amount: asDouble(
        json['amount'],
        asDouble(json['unit_price']) * asDouble(json['quantity']),
      ),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    );
  }

  /// Unsaved line held in the local draft until **Save costing**.
  factory CostingLine.draft({
    required String name,
    required String kind,
    required double unitPrice,
    required double quantity,
    String? itemId,
    String? unit,
  }) {
    return CostingLine(
      id: '',
      name: name,
      kind: kind,
      unitPrice: unitPrice,
      quantity: quantity,
      amount: unitPrice * quantity,
      itemId: itemId,
      unit: unit,
    );
  }

  /// Payload for `POST /costings/customer/:id/save` and `/lead/:id/save`.
  Map<String, dynamic> toPayload() {
    if (kind == 'catalog' && itemId != null && itemId!.isNotEmpty) {
      return {
        'kind': 'catalog',
        'item_id': itemId,
        'unit_price': unitPrice,
        'quantity': quantity,
      };
    }
    return {
      'kind': 'custom',
      'name': name,
      'unit_price': unitPrice,
      'quantity': quantity,
    };
  }
}

class CostingSheet {
  final String id;
  final String? customerId;
  final String? leadId;
  final String? vendorId;
  final double totalAmount;
  final CostingCustomer? customer;
  final CostingLead? lead;
  final CostingVendor? vendor;
  final List<CostingLine> items;

  const CostingSheet({
    required this.id,
    this.customerId,
    this.leadId,
    this.vendorId,
    required this.totalAmount,
    required this.items,
    this.customer,
    this.lead,
    this.vendor,
  });

  String? get partyId => customerId ?? leadId;

  factory CostingSheet.fromJson(dynamic json) {
    if (json is! Map) {
      throw const FormatException('Invalid costing response');
    }
    final source = Map<String, dynamic>.from(json);
    final data = source['data'];
    final map = data is Map ? Map<String, dynamic>.from(data) : source;
    final customer = map['customer'];
    final lead = map['lead'];
    final vendor = map['vendor'];
    final items = map['items'];

    return CostingSheet(
      id: asString(map['id']),
      customerId: map['customer_id']?.toString(),
      leadId: map['lead_id']?.toString(),
      vendorId: map['vendor_id']?.toString(),
      totalAmount: asDouble(map['total_amount']),
      customer: customer is Map
          ? CostingCustomer.fromJson(Map<String, dynamic>.from(customer))
          : null,
      lead: lead is Map
          ? CostingLead.fromJson(Map<String, dynamic>.from(lead))
          : null,
      vendor: vendor is Map
          ? CostingVendor.fromJson(Map<String, dynamic>.from(vendor))
          : null,
      items: items is List
          ? items
                .whereType<Map>()
                .map(
                  (item) =>
                      CostingLine.fromJson(Map<String, dynamic>.from(item)),
                )
                .toList()
          : const [],
    );
  }
}

/// One material line of a BOM sheet (`GET /boms/:id`). BOM lines carry no price.
class BomLine {
  final String id;
  final String? itemId;
  final String name;
  final String kind;
  final String? unit;
  final double quantity;
  final String? spec;
  final String? sku;
  final String? hsnCode;
  final String? category;

  const BomLine({
    required this.id,
    required this.name,
    this.kind = 'custom',
    this.quantity = 0,
    this.itemId,
    this.unit,
    this.spec,
    this.sku,
    this.hsnCode,
    this.category,
  });

  factory BomLine.fromJson(Map<String, dynamic> json) {
    final item = json['item'];
    final itemMap = item is Map ? Map<String, dynamic>.from(item) : null;
    return BomLine(
      id: asString(json['id']),
      itemId: json['item_id']?.toString(),
      name: asString(json['name'], itemMap == null ? '' : asString(itemMap['name'])),
      kind: asString(json['kind'], 'custom'),
      unit: json['unit']?.toString() ?? itemMap?['unit']?.toString(),
      quantity: asDouble(json['quantity']),
      spec: json['spec']?.toString(),
      sku: itemMap?['sku']?.toString(),
      hsnCode: itemMap?['hsn_code']?.toString(),
      category: itemMap?['category']?.toString(),
    );
  }

  factory BomLine.draft({
    required String name,
    required String kind,
    required double quantity,
    String? itemId,
    String? unit,
    String? spec,
  }) {
    return BomLine(
      id: '',
      name: name,
      kind: kind,
      quantity: quantity,
      itemId: itemId,
      unit: unit,
      spec: spec,
    );
  }

  /// Payload for `POST /boms` and `POST /boms/:id/save`.
  Map<String, dynamic> toPayload() {
    if (kind == 'catalog' && itemId != null && itemId!.isNotEmpty) {
      return {
        'kind': 'catalog',
        'item_id': itemId,
        'quantity': quantity,
        if (spec != null && spec!.trim().isNotEmpty) 'spec': spec!.trim(),
      };
    }
    return {
      'kind': 'custom',
      'name': name,
      'quantity': quantity,
      if (unit != null && unit!.trim().isNotEmpty) 'unit': unit!.trim(),
      if (spec != null && spec!.trim().isNotEmpty) 'spec': spec!.trim(),
    };
  }
}

/// Full BOM sheet (`GET /boms/:id`, create / save responses).
class Bom {
  final String id;
  final String? customerId;
  final String projectName;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final CostingCustomer? customer;
  final String creatorName;
  final String? creatorEmail;
  final String updaterName;
  final List<BomLine> items;

  const Bom({
    required this.id,
    required this.projectName,
    this.customerId,
    this.notes,
    this.createdAt,
    this.updatedAt,
    this.customer,
    this.creatorName = '',
    this.creatorEmail,
    this.updaterName = '',
    this.items = const [],
  });

  factory Bom.fromJson(dynamic json) {
    if (json is! Map) {
      throw const FormatException('Invalid BOM response');
    }
    final source = Map<String, dynamic>.from(json);
    final data = source['data'];
    final map = data is Map ? Map<String, dynamic>.from(data) : source;
    final customer = map['customer'];
    final creator = map['creator'];
    final updater = map['updater'];
    final items = map['items'];
    return Bom(
      id: asString(map['id']),
      customerId: map['customer_id']?.toString(),
      projectName: asString(map['project_name'], asString(map['projectName'])),
      notes: map['notes']?.toString(),
      createdAt: parseDate(map['created_at']),
      updatedAt: parseDate(map['updated_at']),
      customer: customer is Map
          ? CostingCustomer.fromJson(Map<String, dynamic>.from(customer))
          : null,
      creatorName: creator is Map ? asString(creator['name']) : '',
      creatorEmail: creator is Map ? creator['email']?.toString() : null,
      updaterName: updater is Map ? asString(updater['name']) : '',
      items: items is List
          ? items
                .whereType<Map>()
                .map((item) => BomLine.fromJson(Map<String, dynamic>.from(item)))
                .toList()
          : const [],
    );
  }
}

/// One row of the BOM project table (`GET /boms`). Rows never include `items`.
class BomListRow {
  final String id;
  final String? customerId;
  final String projectName;
  final int itemCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final CostingCustomer? customer;
  final String creatorName;
  final String? creatorEmail;

  const BomListRow({
    required this.id,
    required this.projectName,
    this.customerId,
    this.itemCount = 0,
    this.createdAt,
    this.updatedAt,
    this.customer,
    this.creatorName = '',
    this.creatorEmail,
  });

  String get customerName {
    final name = (customer?.name ?? '').trim();
    return name.isEmpty ? 'Unknown customer' : name;
  }

  factory BomListRow.fromJson(Map<String, dynamic> json) {
    final customer = json['customer'];
    final creator = json['creator'];
    return BomListRow(
      id: asString(json['id']),
      customerId: json['customer_id']?.toString(),
      projectName: asString(json['project_name'], asString(json['projectName'])),
      itemCount: asInt(json['item_count']),
      createdAt: parseDate(json['created_at']),
      updatedAt: parseDate(json['updated_at']),
      customer: customer is Map
          ? CostingCustomer.fromJson(Map<String, dynamic>.from(customer))
          : null,
      creatorName: creator is Map ? asString(creator['name']) : '',
      creatorEmail: creator is Map ? creator['email']?.toString() : null,
    );
  }
}

/// One row of the All Costings table (`GET /costings`).
///
/// List rows never include `items`; use [itemCount] and [totalAmount].
class CostingListRow {
  final String id;
  final String? customerId;
  final String? leadId;
  final String? vendorId;
  final double totalAmount;
  final int itemCount;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final CostingCustomer? customer;
  final CostingLead? lead;
  final CostingVendor? vendor;
  final String creatorName;
  final String? creatorEmail;
  final bool isActive;

  const CostingListRow({
    required this.id,
    this.customerId,
    this.leadId,
    this.vendorId,
    this.totalAmount = 0,
    this.itemCount = 0,
    this.notes,
    this.createdAt,
    this.updatedAt,
    this.customer,
    this.lead,
    this.vendor,
    this.creatorName = '',
    this.creatorEmail,
    this.isActive = true,
  });

  bool get isLead => customerId == null && leadId != null;

  String? get partyId => customerId ?? leadId;

  String get partyName {
    final name = (customer?.name ?? lead?.fullName ?? '').trim();
    return name.isEmpty ? 'Unknown party' : name;
  }

  String? get partyEmail => customer?.email ?? lead?.email;

  String? get partyPhone => customer?.phone ?? lead?.mobile;

  /// `phone · email` line for the row subtitle.
  String get partyContact {
    final parts = [partyPhone, partyEmail]
        .whereType<String>()
        .where((value) => value.trim().isNotEmpty);
    return parts.join(' · ');
  }

  factory CostingListRow.fromJson(Map<String, dynamic> json) {
    final customer = json['customer'];
    final lead = json['lead'];
    final vendor = json['vendor'];
    final creator = json['creator'];
    return CostingListRow(
      id: asString(json['id']),
      customerId: json['customer_id']?.toString(),
      leadId: json['lead_id']?.toString(),
      vendorId: json['vendor_id']?.toString(),
      totalAmount: asDouble(json['total_amount']),
      itemCount: asInt(json['item_count']),
      notes: json['notes']?.toString(),
      createdAt: parseDate(json['created_at']),
      updatedAt: parseDate(json['updated_at']),
      customer: customer is Map
          ? CostingCustomer.fromJson(Map<String, dynamic>.from(customer))
          : null,
      lead: lead is Map
          ? CostingLead.fromJson(Map<String, dynamic>.from(lead))
          : null,
      vendor: vendor is Map
          ? CostingVendor.fromJson(Map<String, dynamic>.from(vendor))
          : null,
      creatorName: creator is Map ? asString(creator['name']) : '',
      creatorEmail: creator is Map ? creator['email']?.toString() : null,
      isActive: json['is_active'] != false,
    );
  }
}
