class SolarDesignPerson {
  final String id;
  final String name;
  final String email;

  const SolarDesignPerson({
    this.id = '',
    this.name = '',
    this.email = '',
  });

  factory SolarDesignPerson.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const SolarDesignPerson();
    return SolarDesignPerson(
      id: _str(json['id']),
      name: _str(json['name']),
      email: _str(json['email']),
    );
  }
}

class SolarDesignLeadInfo {
  final String id;
  final String leadCode;
  final String fullName;
  final String mobile;
  final String projectType;
  final String loadSectionKw;
  final String address;
  final String city;
  final String state;
  final String pincode;
  final double? latitude;
  final double? longitude;

  const SolarDesignLeadInfo({
    this.id = '',
    this.leadCode = '',
    this.fullName = '',
    this.mobile = '',
    this.projectType = '',
    this.loadSectionKw = '',
    this.address = '',
    this.city = '',
    this.state = '',
    this.pincode = '',
    this.latitude,
    this.longitude,
  });

  factory SolarDesignLeadInfo.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const SolarDesignLeadInfo();
    return SolarDesignLeadInfo(
      id: _str(json['id']),
      leadCode: _str(json['lead_code']),
      fullName: _str(json['full_name']),
      mobile: _str(json['mobile']),
      projectType: _str(json['project_type']),
      loadSectionKw: _str(json['load_section_kw']),
      address: _str(json['address']),
      city: _str(json['city']),
      state: _str(json['state']),
      pincode: _str(json['pincode']),
      latitude: _numOrNull(json['latitude']),
      longitude: _numOrNull(json['longitude']),
    );
  }
}

/// Summary row from `GET /solar-designs/lead/:leadId`.
class SolarDesignSummary {
  final String id;
  final String leadId;
  final String name;
  final int panelCount;
  final double capacityKw;
  final int panelWatts;
  final double? annualKwh;
  final String? shareCode;
  final bool shareEnabled;
  final int shareViews;
  final String? shareLastViewedAt;
  final SolarDesignPerson creator;
  final SolarDesignPerson updater;
  final String createdAt;
  final String updatedAt;

  const SolarDesignSummary({
    required this.id,
    this.leadId = '',
    this.name = '',
    this.panelCount = 0,
    this.capacityKw = 0,
    this.panelWatts = 0,
    this.annualKwh,
    this.shareCode,
    this.shareEnabled = false,
    this.shareViews = 0,
    this.shareLastViewedAt,
    this.creator = const SolarDesignPerson(),
    this.updater = const SolarDesignPerson(),
    this.createdAt = '',
    this.updatedAt = '',
  });

  factory SolarDesignSummary.fromJson(Map<String, dynamic> json) {
    return SolarDesignSummary(
      id: _str(json['id']),
      leadId: _str(json['lead_id']),
      name: _str(json['name'], fallback: 'Design'),
      panelCount: _int(json['panel_count']),
      capacityKw: _num(json['capacity_kw']),
      panelWatts: _int(json['panel_watts']),
      annualKwh: _numOrNull(json['annual_kwh']),
      shareCode: _nullableStr(json['share_code']),
      shareEnabled: json['share_enabled'] == true,
      shareViews: _int(json['share_views']),
      shareLastViewedAt: _nullableStr(json['share_last_viewed_at']),
      creator: SolarDesignPerson.fromJson(
        json['creator'] is Map
            ? Map<String, dynamic>.from(json['creator'] as Map)
            : null,
      ),
      updater: SolarDesignPerson.fromJson(
        json['updater'] is Map
            ? Map<String, dynamic>.from(json['updater'] as Map)
            : null,
      ),
      createdAt: _str(json['created_at']),
      updatedAt: _str(json['updated_at']),
    );
  }

  SolarDesignSummary copyWith({
    String? name,
    String? shareCode,
    bool? shareEnabled,
    int? shareViews,
    String? shareLastViewedAt,
  }) {
    return SolarDesignSummary(
      id: id,
      leadId: leadId,
      name: name ?? this.name,
      panelCount: panelCount,
      capacityKw: capacityKw,
      panelWatts: panelWatts,
      annualKwh: annualKwh,
      shareCode: shareCode ?? this.shareCode,
      shareEnabled: shareEnabled ?? this.shareEnabled,
      shareViews: shareViews ?? this.shareViews,
      shareLastViewedAt: shareLastViewedAt ?? this.shareLastViewedAt,
      creator: creator,
      updater: updater,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  String get capacityLabel {
    if (capacityKw <= 0) return '—';
    final text = capacityKw == capacityKw.roundToDouble()
        ? capacityKw.toStringAsFixed(0)
        : capacityKw.toStringAsFixed(2);
    return '$text kW';
  }

  String get panelsLabel {
    if (panelCount <= 0) return 'No panels yet';
    final watts = panelWatts > 0 ? ' · ${panelWatts}W' : '';
    return '$panelCount panel${panelCount == 1 ? '' : 's'}$watts';
  }

  String get energyLabel {
    if (annualKwh == null) return 'Energy not analysed';
    return '${annualKwh!.round()} kWh/yr';
  }
}

class SolarDesignListResult {
  final SolarDesignLeadInfo lead;
  final List<SolarDesignSummary> designs;

  const SolarDesignListResult({
    this.lead = const SolarDesignLeadInfo(),
    this.designs = const [],
  });

  factory SolarDesignListResult.fromJson(Map<String, dynamic> json) {
    final raw = json['designs'];
    final list = raw is List
        ? raw
            .whereType<Map>()
            .map((e) => SolarDesignSummary.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <SolarDesignSummary>[];
    return SolarDesignListResult(
      lead: SolarDesignLeadInfo.fromJson(
        json['lead'] is Map
            ? Map<String, dynamic>.from(json['lead'] as Map)
            : null,
      ),
      designs: list,
    );
  }
}

/// Full design from `GET /solar-designs/:id`.
class SolarDesignDetail extends SolarDesignSummary {
  final double? centerLat;
  final double? centerLng;
  final int mapZoom;
  final String? solarPanelId;
  final Map<String, dynamic> design;
  final SolarDesignLeadInfo? lead;

  const SolarDesignDetail({
    required super.id,
    super.leadId,
    super.name,
    super.panelCount,
    super.capacityKw,
    super.panelWatts,
    super.annualKwh,
    super.shareCode,
    super.shareEnabled,
    super.shareViews,
    super.shareLastViewedAt,
    super.creator,
    super.updater,
    super.createdAt,
    super.updatedAt,
    this.centerLat,
    this.centerLng,
    this.mapZoom = 20,
    this.solarPanelId,
    this.design = const {},
    this.lead,
  });

  factory SolarDesignDetail.fromJson(Map<String, dynamic> json) {
    final summary = SolarDesignSummary.fromJson(json);
    return SolarDesignDetail(
      id: summary.id,
      leadId: summary.leadId,
      name: summary.name,
      panelCount: summary.panelCount,
      capacityKw: summary.capacityKw,
      panelWatts: summary.panelWatts,
      annualKwh: summary.annualKwh,
      shareCode: summary.shareCode,
      shareEnabled: summary.shareEnabled,
      shareViews: summary.shareViews,
      shareLastViewedAt: summary.shareLastViewedAt,
      creator: summary.creator,
      updater: summary.updater,
      createdAt: summary.createdAt,
      updatedAt: summary.updatedAt,
      centerLat: _numOrNull(json['center_lat']),
      centerLng: _numOrNull(json['center_lng']),
      mapZoom: _int(json['map_zoom'], fallback: 20),
      solarPanelId: _nullableStr(json['solar_panel_id']),
      design: json['design'] is Map
          ? Map<String, dynamic>.from(json['design'] as Map)
          : const {},
      lead: json['lead'] is Map
          ? SolarDesignLeadInfo.fromJson(
              Map<String, dynamic>.from(json['lead'] as Map),
            )
          : null,
    );
  }

  SolarDesignSummary toSummary() => SolarDesignSummary(
        id: id,
        leadId: leadId,
        name: name,
        panelCount: panelCount,
        capacityKw: capacityKw,
        panelWatts: panelWatts,
        annualKwh: annualKwh,
        shareCode: shareCode,
        shareEnabled: shareEnabled,
        shareViews: shareViews,
        shareLastViewedAt: shareLastViewedAt,
        creator: creator,
        updater: updater,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}

String _str(dynamic value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

String? _nullableStr(dynamic value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}

int _int(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

double _num(dynamic value, {double fallback = 0}) {
  return _numOrNull(value) ?? fallback;
}

double? _numOrNull(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString().trim());
}
