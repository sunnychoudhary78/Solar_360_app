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
  final double? centerLat;
  final double? centerLng;
  final int mapZoom;
  final int roofCount;
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
    this.centerLat,
    this.centerLng,
    this.mapZoom = 20,
    this.roofCount = 0,
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
      centerLat: _numOrNull(json['center_lat']),
      centerLng: _numOrNull(json['center_lng']),
      mapZoom: _int(json['map_zoom'], fallback: 20),
      roofCount: _int(json['roof_count']),
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

  bool get hasMapCenter {
    final la = centerLat;
    final ln = centerLng;
    if (la == null || ln == null) return false;
    if (la == 0 && ln == 0) return false;
    return la.abs() <= 85 && ln.abs() <= 180;
  }

  SolarDesignSummary copyWith({
    String? name,
    String? shareCode,
    bool? shareEnabled,
    int? shareViews,
    String? shareLastViewedAt,
    double? centerLat,
    double? centerLng,
    int? mapZoom,
    int? roofCount,
  }) {
    return SolarDesignSummary(
      id: id,
      leadId: leadId,
      name: name ?? this.name,
      panelCount: panelCount,
      capacityKw: capacityKw,
      panelWatts: panelWatts,
      annualKwh: annualKwh,
      centerLat: centerLat ?? this.centerLat,
      centerLng: centerLng ?? this.centerLng,
      mapZoom: mapZoom ?? this.mapZoom,
      roofCount: roofCount ?? this.roofCount,
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

/// Row from `GET /solar-designs/customer/:customerId` (quotation design picker).
class CustomerSolarDesignLead {
  final String id;
  final String leadCode;
  final String fullName;
  final bool hasDesign;

  const CustomerSolarDesignLead({
    this.id = '',
    this.leadCode = '',
    this.fullName = '',
    this.hasDesign = false,
  });

  factory CustomerSolarDesignLead.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const CustomerSolarDesignLead();
    return CustomerSolarDesignLead(
      id: _str(json['id']),
      leadCode: _str(json['lead_code'] ?? json['leadCode']),
      fullName: _str(json['full_name'] ?? json['fullName']),
      hasDesign: json['has_design'] == true || json['hasDesign'] == true,
    );
  }

  String get displayLabel {
    final code = leadCode.trim();
    final name = fullName.trim();
    if (code.isNotEmpty && name.isNotEmpty) return '$code · $name';
    if (name.isNotEmpty) return name;
    if (code.isNotEmpty) return code;
    return id;
  }
}

class CustomerSolarDesignRow {
  final String id;
  final String name;
  final double capacityKw;
  final int panelCount;
  final String leadId;
  final CustomerSolarDesignLead? lead;

  const CustomerSolarDesignRow({
    required this.id,
    this.name = '',
    this.capacityKw = 0,
    this.panelCount = 0,
    this.leadId = '',
    this.lead,
  });

  factory CustomerSolarDesignRow.fromJson(Map<String, dynamic> json) {
    CustomerSolarDesignLead? lead;
    if (json['lead'] is Map) {
      lead = CustomerSolarDesignLead.fromJson(
        Map<String, dynamic>.from(json['lead'] as Map),
      );
    }
    return CustomerSolarDesignRow(
      id: _str(json['id']),
      name: _str(json['name'], fallback: 'Design'),
      capacityKw: _num(json['capacity_kw'] ?? json['capacityKw']),
      panelCount: _int(json['panel_count'] ?? json['panelCount']),
      leadId: _str(json['lead_id'] ?? json['leadId'] ?? lead?.id),
      lead: lead,
    );
  }

  String get pickerLabel {
    final cap = capacityKw <= 0
        ? ''
        : ' · ${capacityKw == capacityKw.roundToDouble() ? capacityKw.toStringAsFixed(0) : capacityKw.toStringAsFixed(2)} kW';
    final panels = panelCount > 0 ? ' · $panelCount panels' : '';
    final leadName = lead?.fullName.trim() ?? '';
    final suffix = leadName.isEmpty ? '' : ' ($leadName)';
    return '$name$cap$panels$suffix';
  }
}

class CustomerSolarDesignsResult {
  final String companyId;
  final List<CustomerSolarDesignRow> designs;
  final List<CustomerSolarDesignLead> leads;

  const CustomerSolarDesignsResult({
    this.companyId = '',
    this.designs = const [],
    this.leads = const [],
  });

  factory CustomerSolarDesignsResult.fromJson(Map<String, dynamic> json) {
    final designsRaw = json['designs'];
    final leadsRaw = json['leads'];
    return CustomerSolarDesignsResult(
      companyId: _str(json['companyId'] ?? json['company_id']),
      designs: designsRaw is List
          ? designsRaw
              .whereType<Map>()
              .map(
                (e) => CustomerSolarDesignRow.fromJson(
                  Map<String, dynamic>.from(e),
                ),
              )
              .toList()
          : const [],
      leads: leadsRaw is List
          ? leadsRaw
              .whereType<Map>()
              .map(
                (e) => CustomerSolarDesignLead.fromJson(
                  Map<String, dynamic>.from(e),
                ),
              )
              .toList()
          : const [],
    );
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

/// Google Solar API height / sunlight grid stored on a design (`surroundings`).
class SolarSurroundings {
  final String source;
  final String? fetchedAt;
  final String? imageryDate;
  final String? imageryQuality;
  final double? groundElevationM;
  final double? cellM;
  final int cols;
  final int rows;
  final double? originLat;
  final double? originLng;
  final bool hasHeights;
  final bool hasFlux;
  final bool hasMask;
  final bool hasVegetation;

  const SolarSurroundings({
    this.source = '',
    this.fetchedAt,
    this.imageryDate,
    this.imageryQuality,
    this.groundElevationM,
    this.cellM,
    this.cols = 0,
    this.rows = 0,
    this.originLat,
    this.originLng,
    this.hasHeights = false,
    this.hasFlux = false,
    this.hasMask = false,
    this.hasVegetation = false,
  });

  factory SolarSurroundings.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const SolarSurroundings();
    final origin = json['origin'];
    double? oLat;
    double? oLng;
    if (origin is Map) {
      oLat = _numOrNull(origin['lat']);
      oLng = _numOrNull(origin['lng']);
    }
    return SolarSurroundings(
      source: _str(json['source']),
      fetchedAt: _nullableStr(json['fetched_at']),
      imageryDate: _nullableStr(json['imagery_date']),
      imageryQuality: _nullableStr(json['imagery_quality']),
      groundElevationM: _numOrNull(json['ground_elevation_m']),
      cellM: _numOrNull(json['cell_m']),
      cols: _int(json['cols']),
      rows: _int(json['rows']),
      originLat: oLat,
      originLng: oLng,
      hasHeights: json['heights_dm'] != null,
      hasFlux: json['flux_10'] != null,
      hasMask: json['mask'] != null,
      hasVegetation: json['veg'] != null,
    );
  }

  bool get isLoaded => hasHeights || hasFlux || hasMask || cols > 0;

  String get statusLabel {
    if (!isLoaded) return 'Not loaded';
    final quality = imageryQuality?.trim();
    final date = imageryDate?.trim();
    if (quality != null && quality.isNotEmpty && date != null && date.isNotEmpty) {
      return 'Loaded · $quality · $date';
    }
    if (date != null && date.isNotEmpty) return 'Loaded · $date';
    if (quality != null && quality.isNotEmpty) return 'Loaded · $quality';
    return 'Loaded';
  }
}

/// Full design from `GET /solar-designs/:id`.
class SolarDesignDetail extends SolarDesignSummary {
  final String? solarPanelId;
  final Map<String, dynamic> design;
  final SolarSurroundings? surroundings;
  final SolarDesignLeadInfo? lead;

  const SolarDesignDetail({
    required super.id,
    super.leadId,
    super.name,
    super.panelCount,
    super.capacityKw,
    super.panelWatts,
    super.annualKwh,
    super.centerLat,
    super.centerLng,
    super.mapZoom,
    super.roofCount,
    super.shareCode,
    super.shareEnabled,
    super.shareViews,
    super.shareLastViewedAt,
    super.creator,
    super.updater,
    super.createdAt,
    super.updatedAt,
    this.solarPanelId,
    this.design = const {},
    this.surroundings,
    this.lead,
  });

  factory SolarDesignDetail.fromJson(Map<String, dynamic> json) {
    final summary = SolarDesignSummary.fromJson(json);
    SolarSurroundings? surroundings;
    if (json['surroundings'] is Map) {
      surroundings = SolarSurroundings.fromJson(
        Map<String, dynamic>.from(json['surroundings'] as Map),
      );
      if (!surroundings.isLoaded) surroundings = null;
    }
    final designMap = json['design'] is Map
        ? Map<String, dynamic>.from(json['design'] as Map)
        : const <String, dynamic>{};
    final roofs = designMap['roofs'];
    final roofsLen = roofs is List ? roofs.length : 0;
    return SolarDesignDetail(
      id: summary.id,
      leadId: summary.leadId,
      name: summary.name,
      panelCount: summary.panelCount,
      capacityKw: summary.capacityKw,
      panelWatts: summary.panelWatts,
      annualKwh: summary.annualKwh,
      centerLat: summary.centerLat,
      centerLng: summary.centerLng,
      mapZoom: summary.mapZoom,
      roofCount: summary.roofCount > 0 ? summary.roofCount : roofsLen,
      shareCode: summary.shareCode,
      shareEnabled: summary.shareEnabled,
      shareViews: summary.shareViews,
      shareLastViewedAt: summary.shareLastViewedAt,
      creator: summary.creator,
      updater: summary.updater,
      createdAt: summary.createdAt,
      updatedAt: summary.updatedAt,
      solarPanelId: _nullableStr(json['solar_panel_id']),
      design: designMap,
      surroundings: surroundings,
      lead: json['lead'] is Map
          ? SolarDesignLeadInfo.fromJson(
              Map<String, dynamic>.from(json['lead'] as Map),
            )
          : null,
    );
  }

  /// `design.analysis.surroundings_at` when shading used surroundings data.
  String? get analysisSurroundingsAt {
    final analysis = design['analysis'];
    if (analysis is! Map) return null;
    return _nullableStr(analysis['surroundings_at']);
  }

  SolarDesignSummary toSummary() => SolarDesignSummary(
        id: id,
        leadId: leadId,
        name: name,
        panelCount: panelCount,
        capacityKw: capacityKw,
        panelWatts: panelWatts,
        annualKwh: annualKwh,
        centerLat: centerLat,
        centerLng: centerLng,
        mapZoom: mapZoom,
        roofCount: roofCount > 0
            ? roofCount
            : (design['roofs'] is List ? (design['roofs'] as List).length : 0),
        shareCode: shareCode,
        shareEnabled: shareEnabled,
        shareViews: shareViews,
        shareLastViewedAt: shareLastViewedAt,
        creator: creator,
        updater: updater,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  /// Soft share warning (same messages as web ShareDialog; signature recompute stays in web).
  String? get shareWarning {
    final analysis = design['analysis'];
    if (analysis is! Map) {
      return 'Run the sun & energy analysis and save, so customers also see generation and savings.';
    }
    final surroundingsAt = analysis['surroundings_at']?.toString();
    final fetched = surroundings?.fetchedAt;
    if (surroundings?.isLoaded == true &&
        (surroundingsAt ?? '') != (fetched ?? '')) {
      return 'The analysis is out of date. Re-run it and save before sharing.';
    }
    final computed = analysis['computed_at']?.toString();
    if (computed != null &&
        computed.isNotEmpty &&
        updatedAt.isNotEmpty) {
      final c = DateTime.tryParse(computed);
      final u = DateTime.tryParse(updatedAt);
      if (c != null && u != null && u.isAfter(c.add(const Duration(seconds: 2)))) {
        return 'The analysis is out of date. Re-run it and save before sharing.';
      }
    }
    return null;
  }
}

/// Place hit from `/solar-designs/geocode` or `/geocode/suggest`.
/// Google autocomplete may return [placeId] with null [lat]/[lng] — resolve via `/geocode/place`.
class SolarGeocodeHit {
  final double? lat;
  final double? lng;
  final String label;
  final String name;
  final String detail;
  final String type;
  final String? placeId;
  final String? provider;

  const SolarGeocodeHit({
    this.lat,
    this.lng,
    this.label = '',
    this.name = '',
    this.detail = '',
    this.type = '',
    this.placeId,
    this.provider,
  });

  factory SolarGeocodeHit.fromJson(Map<String, dynamic> json) {
    return SolarGeocodeHit(
      lat: _numOrNull(json['lat']),
      lng: _numOrNull(json['lng']),
      label: _str(json['label']),
      name: _str(json['name']),
      detail: _str(json['detail']),
      type: _str(json['type']),
      placeId: _nullableStr(json['place_id']),
      provider: _nullableStr(json['provider']),
    );
  }

  bool get hasCoords {
    final la = lat;
    final ln = lng;
    if (la == null || ln == null) return false;
    if (la == 0 && ln == 0) return false;
    return la.abs() <= 85 && ln.abs() <= 180;
  }

  String get displayLabel {
    if (label.isNotEmpty) return label;
    return [name, detail].where((s) => s.trim().isNotEmpty).join(', ');
  }
}

/// Result of `GET /solar-designs/geocode/place`.
class SolarPlaceLocation {
  final double? lat;
  final double? lng;
  final String label;
  final String? provider;

  const SolarPlaceLocation({
    this.lat,
    this.lng,
    this.label = '',
    this.provider,
  });

  factory SolarPlaceLocation.fromJson(Map<String, dynamic> json) {
    return SolarPlaceLocation(
      lat: _numOrNull(json['lat']),
      lng: _numOrNull(json['lng']),
      label: _str(json['label']),
      provider: _nullableStr(json['provider']),
    );
  }

  bool get hasCoords {
    final la = lat;
    final ln = lng;
    if (la == null || ln == null) return false;
    if (la == 0 && ln == 0) return false;
    return la.abs() <= 85 && ln.abs() <= 180;
  }
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
