class ItemCategories {
  ItemCategories._();

  static const options = <ItemCategoryOption>[
    ItemCategoryOption(value: 'inverter', label: 'Inverter'),
    ItemCategoryOption(value: 'panel', label: 'Panel'),
    ItemCategoryOption(value: 'battery', label: 'Battery'),
    ItemCategoryOption(value: 'gi_structure', label: 'GI Structure'),
    ItemCategoryOption(value: 'solar_accessories', label: 'Solar Accessories'),
    ItemCategoryOption(
      value: 'installation_commissioning',
      label: 'Installation and Commissioning',
    ),
  ];

  static const values = [
    'inverter',
    'panel',
    'battery',
    'gi_structure',
    'solar_accessories',
    'installation_commissioning',
  ];

  static String labelFor(String? value) {
    if (value == null || value.isEmpty) return '-';
    for (final o in options) {
      if (o.value == value) return o.label;
    }
    return value;
  }

  static bool isValid(String? value) {
    if (value == null || value.isEmpty) return false;
    return values.contains(value);
  }
}

class ItemCategoryOption {
  final String value;
  final String label;

  const ItemCategoryOption({required this.value, required this.label});
}
