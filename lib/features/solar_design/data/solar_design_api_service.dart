import 'dart:math' as math;
import 'dart:typed_data';

import 'package:solar_sales/core/network/api_constants.dart';
import 'package:solar_sales/core/network/api_endpoints.dart';
import 'package:solar_sales/core/network/api_service.dart';
import 'package:solar_sales/features/solar_design/data/models/solar_design_models.dart';

class SolarDesignApiService {
  SolarDesignApiService(this._api);

  final ApiService _api;

  Future<SolarDesignListResult> listForLead(String leadId) async {
    final res = await _api.get(ApiEndpoints.solarDesignsForLead(leadId));
    return SolarDesignListResult.fromJson(_asMap(res));
  }

  /// Designs + leads for a Billbook customer (quotation form picker).
  Future<CustomerSolarDesignsResult> listForCustomer(String customerId) async {
    final res = await _api.get(ApiEndpoints.solarDesignsForCustomer(customerId));
    return CustomerSolarDesignsResult.fromJson(_asMap(res));
  }

  Future<SolarDesignDetail> getById(String id) async {
    final res = await _api.get(ApiEndpoints.solarDesign(id));
    return SolarDesignDetail.fromJson(_asMap(res));
  }

  Future<SolarDesignDetail> create({
    required String leadId,
    required double centerLat,
    required double centerLng,
    String? name,
    double? targetKw,
    int mapZoom = 20,
    Map<String, dynamic>? module,
  }) async {
    final trimmedName = name?.trim();
    final res = await _api.post(ApiEndpoints.solarDesignsForLead(leadId), {
      'center_lat': centerLat,
      'center_lng': centerLng,
      'map_zoom': mapZoom,
      if (trimmedName != null && trimmedName.isNotEmpty) 'name': trimmedName,
      'target_kw': ?targetKw,
      'module': ?module,
    });
    return SolarDesignDetail.fromJson(_asMap(res));
  }

  Future<SolarDesignDetail> save({
    required String id,
    required Map<String, dynamic> body,
  }) async {
    final res = await _api.put(ApiEndpoints.solarDesign(id), body);
    return SolarDesignDetail.fromJson(_asMap(res));
  }

  Future<SolarDesignDetail> setSharing({
    required String id,
    required bool enabled,
  }) async {
    final res = await _api.post(ApiEndpoints.solarDesignShare(id), {
      'enabled': enabled,
    });
    return SolarDesignDetail.fromJson(_asMap(res));
  }

  /// Fetch Google Solar height / sunlight grid and store it on the design.
  Future<SolarDesignDetail> loadSurroundings({
    required String id,
    double? lat,
    double? lng,
    double? radius,
  }) async {
    final res = await _api.post(ApiEndpoints.solarDesignSurroundings(id), {
      'lat': ?lat,
      'lng': ?lng,
      'radius': ?radius,
    });
    return SolarDesignDetail.fromJson(_asMap(res));
  }

  Future<SolarDesignDetail> clearSurroundings(String id) async {
    final res = await _api.delete(ApiEndpoints.solarDesignSurroundings(id));
    return SolarDesignDetail.fromJson(_asMap(res));
  }

  Future<void> deactivate(String id) async {
    await _api.post(ApiEndpoints.solarDesignDeactivate(id));
  }

  /// PDF report. Prefer `imagery: google` when Google maps are in use (backend credits).
  Future<Uint8List> downloadReport(
    String id, {
    String? snapshot,
    String imagery = 'google',
  }) async {
    return _api.postBytes(ApiEndpoints.solarDesignReport(id), {
      'origin': ApiConstants.webAppBaseUrl,
      'imagery': imagery,
      if (snapshot != null && snapshot.isNotEmpty) 'snapshot': snapshot,
    });
  }

  Future<List<SolarGeocodeHit>> geocode(String query) async {
    final res = await _api.get(
      ApiEndpoints.solarDesignGeocode,
      queryParams: {'q': query},
    );
    return _parseGeocode(res);
  }

  /// Type-ahead suggestions. Pass [session] with Google Places autocomplete;
  /// resolve picks via [geocodePlace] using the same session.
  Future<List<SolarGeocodeHit>> geocodeSuggest(
    String query, {
    double? lat,
    double? lng,
    String? session,
  }) async {
    final res = await _api.get(
      ApiEndpoints.solarDesignGeocodeSuggest,
      queryParams: {
        'q': query,
        'lat': ?lat,
        'lng': ?lng,
        if (session != null && session.isNotEmpty) 'session': session,
      },
    );
    return _parseGeocode(res);
  }

  /// Resolve a Google `place_id` (from autocomplete) to lat/lng.
  Future<SolarPlaceLocation> geocodePlace(
    String placeId, {
    String? session,
  }) async {
    final res = await _api.get(
      ApiEndpoints.solarDesignGeocodePlace,
      queryParams: {
        'id': placeId,
        if (session != null && session.isNotEmpty) 'session': session,
      },
    );
    return SolarPlaceLocation.fromJson(_asMap(res));
  }

  /// Resolve a geocode/suggest hit to coordinates (handles place_id-only hits).
  Future<({double lat, double lng, String label})?> resolveGeocodeHit(
    SolarGeocodeHit hit, {
    String? session,
  }) async {
    if (hit.hasCoords) {
      return (lat: hit.lat!, lng: hit.lng!, label: hit.displayLabel);
    }
    final placeId = hit.placeId?.trim();
    if (placeId == null || placeId.isEmpty) return null;
    final place = await geocodePlace(placeId, session: session);
    if (!place.hasCoords) return null;
    return (
      lat: place.lat!,
      lng: place.lng!,
      label: place.label.isNotEmpty ? place.label : hit.displayLabel,
    );
  }

  /// Unshaded energy estimate (PVGIS) — same body shape as the web designer.
  Future<Map<String, dynamic>> energyEstimate({
    required double lat,
    required double lng,
    required List<Map<String, dynamic>> arrays,
  }) async {
    final res = await _api.post(ApiEndpoints.solarDesignEnergyEstimate, {
      'lat': lat,
      'lng': lng,
      'arrays': arrays,
    });
    return _asMap(res);
  }

  /// Session token for Google Places autocomplete → place details billing.
  static String newPlacesSessionToken() {
    const alphabet =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-';
    final rnd = math.Random.secure();
    final buf = StringBuffer();
    for (var i = 0; i < 24; i++) {
      buf.write(alphabet[rnd.nextInt(alphabet.length)]);
    }
    return buf.toString();
  }

  /// Parse pasted `"lat, lng"` / `"lat lng"` (doc §4.8 / web PlaceSearch).
  static ({double lat, double lng})? parseLatLngPair(String? text) {
    final raw = text?.trim() ?? '';
    if (raw.isEmpty) return null;
    final match = RegExp(
      r'^(-?\d+(?:\.\d+)?)\s*[,;\s]\s*(-?\d+(?:\.\d+)?)$',
    ).firstMatch(raw);
    if (match == null) return null;
    final lat = double.tryParse(match.group(1)!);
    final lng = double.tryParse(match.group(2)!);
    if (lat == null || lng == null) return null;
    if (lat.abs() > 85 || lng.abs() > 180) return null;
    if (lat == 0 && lng == 0) return null;
    return (lat: lat, lng: lng);
  }

  /// Same as web `BUILDING_ZOOM` — below this the map is an area, not a building.
  static const buildingZoom = 17;

  /// Same as web `placeZoom(type)` — zoom for geocode result precision.
  static int placeZoom(String? type) {
    final t = (type ?? '').toLowerCase();
    if (t.isEmpty) return 19;
    if (RegExp(r'^country$').hasMatch(t)) return 5;
    if (RegExp(
      r'administrative_area_level_1|^state$|^region$|^province$',
    ).hasMatch(t)) {
      return 7;
    }
    if (RegExp(
      r'administrative_area_level_[2-4]|^county$|^district$|^state_district$',
    ).hasMatch(t)) {
      return 10;
    }
    if (RegExp(
      r'locality|^city$|^town$|^municipality$|postal_code|^postcode$|^administrative$',
    ).hasMatch(t)) {
      return 13;
    }
    if (RegExp(
      r'^village$|sublocality|neighbou?rhood|^suburb$|^quarter$|^hamlet$|^route$|^road$|^street$|^residential$',
    ).hasMatch(t)) {
      return 16;
    }
    return 19;
  }

  /// Rough ground distance in metres (web `distanceM`).
  static double distanceM({
    required double lat1,
    required double lng1,
    required double lat2,
    required double lng2,
  }) {
    const rad = 3.141592653589793 / 180;
    final x = (lng2 - lng1) * rad * math.cos(((lat1 + lat2) / 2) * rad);
    final y = (lat2 - lat1) * rad;
    return math.sqrt(x * x + y * y) * 6371000;
  }

  /// Roof reach in metres from design center (web surroundings `reach + 22`).
  static double roofReachMeters({
    required Map<String, dynamic> design,
    required double centerLat,
    required double centerLng,
  }) {
    final roofs = design['roofs'];
    if (roofs is! List) return 0;
    final cosLat = math.cos(centerLat * math.pi / 180);
    var reach = 0.0;
    for (final roof in roofs.whereType<Map>()) {
      final pts = roof['points'];
      if (pts is! List) continue;
      for (final p in pts) {
        if (p is! List || p.length < 2) continue;
        final lat = p[0] is num
            ? (p[0] as num).toDouble()
            : double.tryParse('${p[0]}');
        final lng = p[1] is num
            ? (p[1] as num).toDouble()
            : double.tryParse('${p[1]}');
        if (lat == null || lng == null) continue;
        final dx = ((lng - centerLng) * 111320 * cosLat).abs();
        final dy = ((lat - centerLat) * 111320).abs();
        reach = math.max(reach, math.max(dx, dy));
      }
    }
    return reach;
  }

  /// Clamp radius like backend Google Solar layers (25–60 m).
  static double surroundingsRadiusM(double roofReach) {
    final r = roofReach + 22;
    if (r < 25) return 25;
    if (r > 60) return 60;
    return r;
  }

  List<SolarGeocodeHit> _parseGeocode(dynamic res) {
    final map = _asMap(res);
    final raw = map['results'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => SolarGeocodeHit.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Map<String, dynamic> _asMap(dynamic res) {
    if (res is Map<String, dynamic>) return res;
    if (res is Map) return Map<String, dynamic>.from(res);
    throw const ApiException('Unexpected solar design response');
  }
}
