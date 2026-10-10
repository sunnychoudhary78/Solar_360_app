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
      if (targetKw case final kw?) 'target_kw': kw,
      if (module case final mod?) 'module': mod,
    });
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

  Future<void> deactivate(String id) async {
    await _api.post(ApiEndpoints.solarDesignDeactivate(id));
  }

  Future<Uint8List> downloadReport(String id) async {
    return _api.postBytes(ApiEndpoints.solarDesignReport(id), {
      'origin': ApiConstants.webAppBaseUrl,
    });
  }

  Map<String, dynamic> _asMap(dynamic res) {
    if (res is Map<String, dynamic>) return res;
    if (res is Map) return Map<String, dynamic>.from(res);
    throw const ApiException('Unexpected solar design response');
  }
}
