import 'package:solar_sales/shared/utils/formatters.dart';

class SolarPanelModel {
  const SolarPanelModel({
    required this.id,
    required this.companyName,
    required this.widthM,
    required this.lengthM,
    required this.minWatts,
    required this.maxWatts,
    required this.defaultWatts,
    this.wattStep = 10,
    this.enabled = true,
  });

  final String id;
  final String companyName;
  final double widthM;
  final double lengthM;
  final int minWatts;
  final int maxWatts;
  final int defaultWatts;
  final int wattStep;
  final bool enabled;

  factory SolarPanelModel.fromJson(Map<String, dynamic> json) {
    return SolarPanelModel(
      id: asString(json['id']),
      companyName: asString(json['company_name']),
      widthM: asDouble(json['width_m']),
      lengthM: asDouble(json['length_m']),
      minWatts: asInt(json['min_watts']),
      maxWatts: asInt(json['max_watts']),
      defaultWatts: asInt(json['default_watts']),
      wattStep: asInt(json['watt_step'], 10),
      enabled: asBool(json['enabled'], true),
    );
  }

  String get sizeLabel {
    return '${widthM.toStringAsFixed(2)} × ${lengthM.toStringAsFixed(2)} m';
  }

  String get wattsLabel => '$minWatts–$maxWatts W';
}
