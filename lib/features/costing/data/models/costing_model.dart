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
      name: asString(json['name']),
      email: json['email']?.toString(),
      phone: json['phone']?.toString(),
      city: json['city']?.toString(),
      state: json['state']?.toString(),
    );
  }
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

  const CostingLine({
    required this.id,
    required this.name,
    required this.kind,
    required this.unitPrice,
    required this.quantity,
    required this.amount,
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
    );
  }
}

class CostingSheet {
  final String id;
  final String customerId;
  final double totalAmount;
  final CostingCustomer? customer;
  final List<CostingLine> items;

  const CostingSheet({
    required this.id,
    required this.customerId,
    required this.totalAmount,
    required this.items,
    this.customer,
  });

  factory CostingSheet.fromJson(dynamic json) {
    if (json is! Map) {
      throw const FormatException('Invalid costing response');
    }
    final source = Map<String, dynamic>.from(json);
    final data = source['data'];
    final map = data is Map ? Map<String, dynamic>.from(data) : source;
    final customer = map['customer'];
    final items = map['items'];

    return CostingSheet(
      id: asString(map['id']),
      customerId: asString(map['customer_id']),
      totalAmount: asDouble(map['total_amount']),
      customer: customer is Map
          ? CostingCustomer.fromJson(Map<String, dynamic>.from(customer))
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
