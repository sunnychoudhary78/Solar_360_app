import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_drawing/path_drawing.dart';

import 'package:solar_sales/features/leads/data/india_states.dart';

class IndiaMapLocation {
  const IndiaMapLocation({
    required this.id,
    required this.name,
    required this.path,
  });

  final String id;
  final String name;
  final Path path;
}

class IndiaMapData {
  const IndiaMapData({
    required this.viewBox,
    required this.locations,
  });

  final Rect viewBox;
  final List<IndiaMapLocation> locations;
}

IndiaMapData? _cachedMap;

Future<IndiaMapData> loadIndiaMapData() async {
  if (_cachedMap != null) return _cachedMap!;

  final raw = await rootBundle.loadString('assets/maps/india.json');
  final json = jsonDecode(raw) as Map<String, dynamic>;
  final viewTokens = json['viewBox']
      .toString()
      .trim()
      .split(RegExp(r'\s+'))
      .map(double.parse)
      .toList();
  final viewBox = Rect.fromLTWH(
    viewTokens[0],
    viewTokens[1],
    viewTokens[2],
    viewTokens[3],
  );

  final locations = <IndiaMapLocation>[];
  for (final item in (json['locations'] as List? ?? const [])) {
    if (item is! Map) continue;
    final map = Map<String, dynamic>.from(item);
    final d = (map['path'] ?? '').toString();
    if (d.isEmpty) continue;
    locations.add(
      IndiaMapLocation(
        id: (map['id'] ?? '').toString(),
        name: normalizeStateName((map['name'] ?? '').toString()),
        path: parseSvgPathData(d),
      ),
    );
  }

  _cachedMap = IndiaMapData(viewBox: viewBox, locations: locations);
  return _cachedMap!;
}

final indiaMapDataProvider = FutureProvider<IndiaMapData>((ref) {
  return loadIndiaMapData();
});
