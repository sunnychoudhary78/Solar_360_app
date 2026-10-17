import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:solar_sales/features/solar_design/data/models/solar_design_models.dart';

/// Builds a JPEG data-URL plan view (roofs + panels) when 3D canvas capture fails.
/// Matches the PDF `snapshot` contract: `data:image/jpeg;base64,…`.
Future<String?> buildSolarDesignPlanSnapshot(SolarDesignDetail detail) async {
  final design = detail.design;
  final roofsRaw = design['roofs'];
  final panelsRaw = design['panels'];
  if (roofsRaw is! List || roofsRaw.isEmpty) return null;

  final points = <Offset>[];
  final roofs = <_RoofPoly>[];
  for (final r in roofsRaw.whereType<Map>()) {
    final ptsRaw = r['points'];
    if (ptsRaw is! List || ptsRaw.length < 3) continue;
    final ring = <Offset>[];
    for (final p in ptsRaw) {
      if (p is! List || p.length < 2) continue;
      final lat = _asDouble(p[0]);
      final lng = _asDouble(p[1]);
      if (lat == null || lng == null) continue;
      final o = Offset(lng, lat); // x=east-ish, y=north-ish in lat/lng space
      ring.add(o);
      points.add(o);
    }
    if (ring.length >= 3) {
      roofs.add(_RoofPoly(ring, _str(r['name'], fallback: 'Roof')));
    }
  }
  if (roofs.isEmpty || points.isEmpty) return null;

  final panels = <Offset>[];
  if (panelsRaw is List) {
    for (final p in panelsRaw.whereType<Map>()) {
      final lat = _asDouble(p['lat']);
      final lng = _asDouble(p['lng']);
      if (lat == null || lng == null) continue;
      final o = Offset(lng, lat);
      panels.add(o);
      points.add(o);
    }
  }

  // Bounding box in lng/lat
  var minX = points.first.dx;
  var maxX = points.first.dx;
  var minY = points.first.dy;
  var maxY = points.first.dy;
  for (final p in points) {
    minX = math.min(minX, p.dx);
    maxX = math.max(maxX, p.dx);
    minY = math.min(minY, p.dy);
    maxY = math.max(maxY, p.dy);
  }
  final padX = math.max((maxX - minX) * 0.18, 0.00008);
  final padY = math.max((maxY - minY) * 0.18, 0.00008);
  minX -= padX;
  maxX += padX;
  minY -= padY;
  maxY += padY;

  const width = 1200.0;
  const height = 720.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, width, height));

  // Aerial-style ground (never black — matches readable web report look).
  final bg = Paint()
    ..shader = ui.Gradient.linear(
      Offset.zero,
      const Offset(width, height),
      const [Color(0xFF7A8F6E), Color(0xFF8D9A82), Color(0xFF6E8264)],
    );
  canvas.drawRect(const Rect.fromLTWH(0, 0, width, height), bg);
  final grain = Paint()..color = const Color(0x22000000);
  for (var i = 0; i < 40; i++) {
    final x = (i * 97) % width;
    final y = (i * 53) % height;
    canvas.drawCircle(Offset(x, y), 18 + (i % 5) * 4.0, grain);
  }

  Offset map(Offset lngLat) {
    final nx = (lngLat.dx - minX) / (maxX - minX);
    // Flip Y so north is up
    final ny = 1 - (lngLat.dy - minY) / (maxY - minY);
    return Offset(nx * width, ny * height);
  }

  // Roofs — light concrete like the 3D scene
  final roofFill = Paint()
    ..color = const Color(0xFFD9D6CF)
    ..style = PaintingStyle.fill;
  final roofStroke = Paint()
    ..color = const Color(0xFF9A958A)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3;
  for (final roof in roofs) {
    final path = Path()..addPolygon(roof.ring.map(map).toList(), true);
    canvas.drawPath(path, roofFill);
    canvas.drawPath(path, roofStroke);
  }

  // Panels — uniform solar blue (same language as designer modules)
  final panelPaint = Paint()
    ..color = const Color(0xFF16244A)
    ..style = PaintingStyle.fill;
  final panelEdge = Paint()
    ..color = const Color(0xFF5B78B8)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.2;
  final panelSize = math.max(14.0, math.min(width, height) * 0.032);
  for (final p in panels) {
    final c = map(p);
    final rect = Rect.fromCenter(
      center: c,
      width: panelSize * 1.2,
      height: panelSize * 0.72,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(2)),
      panelPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(2)),
      panelEdge,
    );
  }

  // Caption
  final builder = ui.ParagraphBuilder(
    ui.ParagraphStyle(textAlign: TextAlign.left, fontSize: 22),
  )
    ..pushStyle(ui.TextStyle(
      color: const Color(0xFF0F172A),
      fontWeight: FontWeight.w700,
    ))
    ..addText(detail.name.isEmpty ? 'Rooftop layout' : detail.name);
  final paragraph = builder.build()
    ..layout(const ui.ParagraphConstraints(width: width - 48));
  canvas.drawParagraph(paragraph, const Offset(24, 20));

  final picture = recorder.endRecording();
  final image = await picture.toImage(width.toInt(), height.toInt());
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  if (bytes == null) return null;

  // PDF accepts PNG data URLs via decodeDataUrl on the server.
  final b64 = base64Encode(bytes.buffer.asUint8List());
  return 'data:image/png;base64,$b64';
}

class _RoofPoly {
  _RoofPoly(this.ring, this.name);
  final List<Offset> ring;
  final String name;
}

double? _asDouble(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse(v?.toString() ?? '');
}

String _str(dynamic v, {String fallback = ''}) {
  final t = v?.toString().trim() ?? '';
  return t.isEmpty ? fallback : t;
}
