import 'package:flutter/material.dart';

import 'package:solar_sales/features/leads/data/green_energy_dashboard_logic.dart';
import 'package:solar_sales/features/leads/data/india_map_data.dart';
import 'package:solar_sales/features/leads/data/india_states.dart';

const _heatColors = <Color>[
  Color(0xFFE2E8F0),
  Color(0xFFBAE6FD),
  Color(0xFF5EEAD4),
  Color(0xFF34D399),
  Color(0xFFFBBF24),
  Color(0xFFEA580C),
];

int heatLevelFor(int leads, int maxLeads) {
  if (leads <= 0) return 0;
  final ratio = maxLeads <= 0 ? 0.0 : leads / maxLeads;
  return (ratio * 5).ceil().clamp(1, 5);
}

class IndiaHeatMap extends StatelessWidget {
  const IndiaHeatMap({
    super.key,
    required this.map,
    required this.analytics,
    required this.maxLeads,
    this.selectedState,
    this.onStateTap,
    this.height = 320,
  });

  final IndiaMapData map;
  final Map<String, StateAnalytics> analytics;
  final int maxLeads;
  final String? selectedState;
  final ValueChanged<StateAnalytics>? onStateTap;
  final double height;

  StateAnalytics _dataFor(String name) {
    return analytics[name] ?? StateAnalytics(name: name);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final fitted = _fittedMap(
            size: Size(constraints.maxWidth, constraints.maxHeight),
            viewBox: map.viewBox,
          );
          return GestureDetector(
            onTapDown: (details) {
              final state = _hitTest(details.localPosition, fitted);
              if (state == null) return;
              onStateTap?.call(_dataFor(state.name));
            },
            child: CustomPaint(
              size: Size(constraints.maxWidth, constraints.maxHeight),
              painter: _IndiaMapPainter(
                map: map,
                analytics: analytics,
                maxLeads: maxLeads,
                selectedState: normalizeStateName(selectedState ?? ''),
                transform: fitted,
              ),
            ),
          );
        },
      ),
    );
  }

  IndiaMapLocation? _hitTest(Offset local, Matrix4 transform) {
    final inverted = Matrix4.tryInvert(transform);
    if (inverted == null) return null;
    final scene = MatrixUtils.transformPoint(inverted, local);
    for (final location in map.locations.reversed) {
      if (location.path.contains(scene)) return location;
    }
    return null;
  }
}

Matrix4 _fittedMap({required Size size, required Rect viewBox}) {
  final scaleX = size.width / viewBox.width;
  final scaleY = size.height / viewBox.height;
  final scale = scaleX < scaleY ? scaleX : scaleY;
  final dx = (size.width - viewBox.width * scale) / 2 - viewBox.left * scale;
  final dy = (size.height - viewBox.height * scale) / 2 - viewBox.top * scale;
  return Matrix4.identity()
    ..translateByDouble(dx, dy, 0, 1)
    ..scaleByDouble(scale, scale, 1, 1);
}

class _IndiaMapPainter extends CustomPainter {
  _IndiaMapPainter({
    required this.map,
    required this.analytics,
    required this.maxLeads,
    required this.selectedState,
    required this.transform,
  });

  final IndiaMapData map;
  final Map<String, StateAnalytics> analytics;
  final int maxLeads;
  final String selectedState;
  final Matrix4 transform;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.transform(transform.storage);

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;

    for (final location in map.locations) {
      final data = analytics[location.name] ?? StateAnalytics(name: location.name);
      final selected =
          selectedState.isNotEmpty && selectedState == location.name;
      final fill = Paint()
        ..style = PaintingStyle.fill
        ..color = selected
            ? const Color(0xFF0F766E)
            : _heatColors[heatLevelFor(data.leads, maxLeads)];
      canvas.drawPath(location.path, fill);
      stroke
        ..color = selected ? const Color(0xFF022C22) : Colors.white
        ..strokeWidth = selected ? 2.2 : 1.05;
      canvas.drawPath(location.path, stroke);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _IndiaMapPainter oldDelegate) {
    return oldDelegate.analytics != analytics ||
        oldDelegate.selectedState != selectedState ||
        oldDelegate.maxLeads != maxLeads;
  }
}

class IndiaMapLegend extends StatelessWidget {
  const IndiaMapLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Low',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(width: 4),
          for (final color in const [Color(0xFFBAE6FD), Color(0xFF5EEAD4)])
            Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          const SizedBox(width: 4),
          Text(
            'Medium',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(width: 4),
          for (final color in const [Color(0xFF34D399), Color(0xFFFBBF24), Color(0xFFEA580C)])
            Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          const SizedBox(width: 4),
          Text(
            'High',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}
