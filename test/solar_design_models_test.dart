import 'package:flutter_test/flutter_test.dart';
import 'package:solar_sales/features/solar_design/data/models/solar_design_models.dart';
import 'package:solar_sales/features/solar_design/data/solar_design_api_service.dart';

void main() {
  group('SolarDesignApiService.parseLatLngPair', () {
    test('parses comma-separated coordinates', () {
      final hit = SolarDesignApiService.parseLatLngPair('28.6139, 77.2090');
      expect(hit?.lat, closeTo(28.6139, 1e-6));
      expect(hit?.lng, closeTo(77.2090, 1e-6));
    });

    test('rejects invalid or out-of-range values', () {
      expect(SolarDesignApiService.parseLatLngPair('not a place'), isNull);
      expect(SolarDesignApiService.parseLatLngPair('0, 0'), isNull);
      expect(SolarDesignApiService.parseLatLngPair('99, 77'), isNull);
    });
  });

  group('SolarGeocodeHit', () {
    test('accepts place_id without coordinates (Google autocomplete)', () {
      final hit = SolarGeocodeHit.fromJson({
        'place_id': 'ChIJ_example',
        'lat': null,
        'lng': null,
        'label': 'Connaught Place, New Delhi',
        'name': 'Connaught Place',
        'detail': 'New Delhi',
        'provider': 'google',
      });
      expect(hit.placeId, 'ChIJ_example');
      expect(hit.hasCoords, isFalse);
      expect(hit.provider, 'google');
      expect(hit.displayLabel, contains('Connaught Place'));
    });

    test('detects valid coordinates', () {
      final hit = SolarGeocodeHit.fromJson({
        'lat': 28.63,
        'lng': 77.22,
        'label': 'Delhi',
      });
      expect(hit.hasCoords, isTrue);
    });
  });

  group('SolarSurroundings / SolarDesignDetail', () {
    test('parses surroundings payload from GET /:id', () {
      final detail = SolarDesignDetail.fromJson({
        'id': 'd1',
        'name': 'Option A',
        'panel_count': 6,
        'capacity_kw': 3.24,
        'panel_watts': 540,
        'center_lat': 28.67,
        'center_lng': 77.45,
        'map_zoom': 20,
        'design': {
          'analysis': {'surroundings_at': '2026-10-14T10:00:00.000Z'},
        },
        'surroundings': {
          'source': 'Google Solar API',
          'fetched_at': '2026-10-14T10:00:00.000Z',
          'imagery_date': '2024-06-01',
          'imagery_quality': 'HIGH',
          'origin': {'lat': 28.67, 'lng': 77.45},
          'cell_m': 0.5,
          'cols': 100,
          'rows': 100,
          'ground_elevation_m': 210.5,
          'heights_dm': 'AAAA',
          'flux_10': 'BBBB',
          'mask': 'CCCC',
        },
        'share_enabled': false,
        'share_views': 0,
        'created_at': '2026-10-01T00:00:00.000Z',
        'updated_at': '2026-10-01T00:00:00.000Z',
      });

      expect(detail.surroundings, isNotNull);
      expect(detail.surroundings!.isLoaded, isTrue);
      expect(detail.surroundings!.imageryQuality, 'HIGH');
      expect(detail.surroundings!.originLat, closeTo(28.67, 1e-6));
      expect(detail.analysisSurroundingsAt, '2026-10-14T10:00:00.000Z');
      expect(detail.surroundings!.statusLabel, contains('HIGH'));
    });

    test('treats null surroundings as absent', () {
      final detail = SolarDesignDetail.fromJson({
        'id': 'd2',
        'name': 'Option B',
        'design': {},
        'surroundings': null,
      });
      expect(detail.surroundings, isNull);
    });
  });

  group('CustomerSolarDesignsResult', () {
    test('parses GET /solar-designs/customer/:id picker payload', () {
      final result = CustomerSolarDesignsResult.fromJson({
        'companyId': 'co1',
        'designs': [
          {
            'id': 'd1',
            'name': 'Option A 5 kW',
            'capacity_kw': 5,
            'panel_count': 10,
            'lead_id': 'l1',
            'lead': {
              'id': 'l1',
              'lead_code': 'LD-1',
              'full_name': 'Ravi',
            },
          },
        ],
        'leads': [
          {
            'id': 'l1',
            'lead_code': 'LD-1',
            'full_name': 'Ravi',
            'has_design': true,
          },
        ],
      });
      expect(result.companyId, 'co1');
      expect(result.designs, hasLength(1));
      expect(result.designs.first.pickerLabel, contains('5 kW'));
      expect(result.leads.single.hasDesign, isTrue);
    });
  });

  group('SolarPlaceLocation', () {
    test('parses place details response', () {
      final place = SolarPlaceLocation.fromJson({
        'lat': 28.63,
        'lng': 77.22,
        'label': 'Connaught Place, New Delhi, India',
        'provider': 'google',
      });
      expect(place.hasCoords, isTrue);
      expect(place.provider, 'google');
    });
  });
}
