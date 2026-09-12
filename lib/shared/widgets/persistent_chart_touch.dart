import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/widgets.dart';

/// How long a tapped chart tooltip stays visible before it hides.
const chartTooltipHold = Duration(seconds: 5);

/// Keep a chart tooltip after tap instead of hiding it when the pointer lifts.
bool persistChartTap(FlTouchEvent event) {
  return event is FlTapUpEvent ||
      event is FlTapDownEvent ||
      event is FlLongPressStart;
}

int? selectedLineSpotIndex(LineTouchResponse? response) {
  final spots = response?.lineBarSpots;
  if (spots == null || spots.isEmpty) return null;
  return spots.first.spotIndex;
}

int? selectedBarGroupIndex(BarTouchResponse? response) {
  return response?.spot?.touchedBarGroupIndex;
}

int? selectedPieSectionIndex(PieTouchResponse? response) {
  final index = response?.touchedSection?.touchedSectionIndex;
  if (index == null || index < 0) return null;
  return index;
}

List<ShowingTooltipIndicators> lineTooltipsAtIndex({
  required List<LineChartBarData> bars,
  required int? index,
}) {
  if (index == null) return const [];
  final spots = <LineBarSpot>[];
  for (var i = 0; i < bars.length; i++) {
    final bar = bars[i];
    if (index < 0 || index >= bar.spots.length) continue;
    spots.add(LineBarSpot(bar, i, bar.spots[index]));
  }
  if (spots.isEmpty) return const [];
  return [ShowingTooltipIndicators(spots)];
}

List<int> barRodTooltipIndexes(int rodCount, {required bool selected}) {
  if (!selected || rodCount <= 0) return const [];
  return [for (var i = 0; i < rodCount; i++) i];
}

/// Holds a tapped chart index and auto-clears it after [holdDuration].
///
/// A new [select] call cancels the previous hide timer so the old tooltip
/// is replaced immediately.
class TimedChartSelection {
  TimedChartSelection(
    this.onChanged, {
    this.holdDuration = chartTooltipHold,
  });

  final VoidCallback onChanged;
  final Duration holdDuration;

  Timer? _timer;
  int? index;

  void select(int next) {
    _timer?.cancel();
    index = next;
    _timer = Timer(holdDuration, clear);
    onChanged();
  }

  void clear() {
    _timer?.cancel();
    _timer = null;
    if (index == null) return;
    index = null;
    onChanged();
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}

/// Mix into a chart [State] so tap tooltips hide after [chartTooltipHold].
mixin TimedChartTooltip<T extends StatefulWidget> on State<T> {
  late final TimedChartSelection _chartTooltip = TimedChartSelection(() {
    if (mounted) setState(() {});
  });

  int? get selectedTooltipIndex => _chartTooltip.index;

  void showChartTooltip(int index) => _chartTooltip.select(index);

  @override
  void dispose() {
    _chartTooltip.dispose();
    super.dispose();
  }
}
