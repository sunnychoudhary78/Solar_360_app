import 'package:flutter/material.dart';

class ItemUnits {
  ItemUnits._();

  static const groups = <ItemUnitGroup>[
    ItemUnitGroup(
      group: 'Count / Quantity',
      units: [
        ItemUnitOption(value: 'pcs', label: 'Pieces (pcs)'),
        ItemUnitOption(value: 'nos', label: 'Numbers (nos)'),
        ItemUnitOption(value: 'unit', label: 'Unit'),
        ItemUnitOption(value: 'set', label: 'Set'),
        ItemUnitOption(value: 'pair', label: 'Pair'),
        ItemUnitOption(value: 'dozen', label: 'Dozen'),
        ItemUnitOption(value: 'box', label: 'Box'),
        ItemUnitOption(value: 'carton', label: 'Carton'),
        ItemUnitOption(value: 'bundle', label: 'Bundle'),
        ItemUnitOption(value: 'pack', label: 'Pack'),
        ItemUnitOption(value: 'roll', label: 'Roll'),
        ItemUnitOption(value: 'bag', label: 'Bag'),
      ],
    ),
    ItemUnitGroup(
      group: 'Weight',
      units: [
        ItemUnitOption(value: 'mg', label: 'Milligram (mg)'),
        ItemUnitOption(value: 'g', label: 'Gram (g)'),
        ItemUnitOption(value: 'kg', label: 'Kilogram (kg)'),
        ItemUnitOption(value: 'quintal', label: 'Quintal'),
        ItemUnitOption(value: 'ton', label: 'Ton'),
      ],
    ),
    ItemUnitGroup(
      group: 'Length',
      units: [
        ItemUnitOption(value: 'mm', label: 'Millimeter (mm)'),
        ItemUnitOption(value: 'cm', label: 'Centimeter (cm)'),
        ItemUnitOption(value: 'm', label: 'Meter (m)'),
        ItemUnitOption(value: 'km', label: 'Kilometer (km)'),
        ItemUnitOption(value: 'inch', label: 'Inch'),
        ItemUnitOption(value: 'ft', label: 'Feet (ft)'),
        ItemUnitOption(value: 'yard', label: 'Yard'),
      ],
    ),
    ItemUnitGroup(
      group: 'Area',
      units: [
        ItemUnitOption(value: 'sqcm', label: 'Sq. Centimeter'),
        ItemUnitOption(value: 'sqm', label: 'Sq. Meter (sqm)'),
        ItemUnitOption(value: 'sqft', label: 'Sq. Feet (sqft)'),
        ItemUnitOption(value: 'acre', label: 'Acre'),
        ItemUnitOption(value: 'hectare', label: 'Hectare'),
      ],
    ),
    ItemUnitGroup(
      group: 'Volume / Liquid',
      units: [
        ItemUnitOption(value: 'ml', label: 'Milliliter (ml)'),
        ItemUnitOption(value: 'l', label: 'Liter (L)'),
        ItemUnitOption(value: 'kl', label: 'Kiloliter (kL)'),
        ItemUnitOption(value: 'cum', label: 'Cubic Meter (cum)'),
        ItemUnitOption(value: 'cft', label: 'Cubic Feet (cft)'),
      ],
    ),
    ItemUnitGroup(
      group: 'Power / Solar',
      units: [
        ItemUnitOption(value: 'W', label: 'Watt (W)'),
        ItemUnitOption(value: 'kW', label: 'Kilowatt (kW)'),
        ItemUnitOption(value: 'MW', label: 'Megawatt (MW)'),
        ItemUnitOption(value: 'kWh', label: 'Kilowatt-hour (kWh)'),
        ItemUnitOption(value: 'MWh', label: 'Megawatt-hour (MWh)'),
        ItemUnitOption(value: 'Ah', label: 'Ampere-hour (Ah)'),
        ItemUnitOption(value: 'V', label: 'Volt (V)'),
        ItemUnitOption(value: 'A', label: 'Ampere (A)'),
        ItemUnitOption(value: 'kVA', label: 'Kilovolt-ampere (kVA)'),
      ],
    ),
    ItemUnitGroup(
      group: 'Time',
      units: [
        ItemUnitOption(value: 'hr', label: 'Hour (hr)'),
        ItemUnitOption(value: 'day', label: 'Day'),
        ItemUnitOption(value: 'month', label: 'Month'),
        ItemUnitOption(value: 'year', label: 'Year'),
      ],
    ),
  ];

  static final allValues =
      groups.expand((g) => g.units.map((u) => u.value)).toList();

  static String labelFor(String? unit) {
    if (unit == null || unit.isEmpty) return '-';
    for (final g in groups) {
      for (final u in g.units) {
        if (u.value == unit) return u.label;
      }
    }
    return unit.toUpperCase();
  }

  static String normalize(String? unit) {
    if (unit == null || unit.isEmpty) return 'pcs';
    final lower = unit.toLowerCase();
    if (allValues.contains(lower)) return lower;
    const legacy = {
      'nos': 'nos',
      'pcs': 'pcs',
      'kg': 'kg',
      'meter': 'm',
      'set': 'set',
      'box': 'box',
      'litre': 'l',
      'liter': 'l',
    };
    return legacy[lower] ?? lower;
  }

  static List<DropdownMenuItem<String>> dropdownItems() {
    final items = <DropdownMenuItem<String>>[];
    for (final g in groups) {
      items.add(
        DropdownMenuItem<String>(
          enabled: false,
          value: '__group_${g.group}',
          child: Text(
            g.group,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          ),
        ),
      );
      for (final u in g.units) {
        items.add(
          DropdownMenuItem<String>(
            value: u.value,
            child: Text(u.label),
          ),
        );
      }
    }
    return items;
  }
}

class ItemUnitGroup {
  final String group;
  final List<ItemUnitOption> units;

  const ItemUnitGroup({required this.group, required this.units});
}

class ItemUnitOption {
  final String value;
  final String label;

  const ItemUnitOption({required this.value, required this.label});
}
