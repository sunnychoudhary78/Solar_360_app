class ItemCategoryModel {
  final String id;
  final String value;
  final String label;
  final bool isActive;
  final int sortOrder;

  const ItemCategoryModel({
    required this.id,
    required this.value,
    required this.label,
    this.isActive = true,
    this.sortOrder = 0,
  });

  factory ItemCategoryModel.fromJson(Map<String, dynamic> json) {
    return ItemCategoryModel(
      id: json['id']?.toString() ?? '',
      value: json['value']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      isActive: json['is_active'] != false,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    );
  }
}
