import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solar_sales/shared/widgets/persistent_chart_touch.dart';

void main() {
  test('lineTooltipsAtIndex keeps both series at the tapped x', () {
    final bars = [
      LineChartBarData(spots: const [FlSpot(0, 1), FlSpot(1, 2)]),
      LineChartBarData(spots: const [FlSpot(0, 3), FlSpot(1, 4)]),
    ];

    expect(lineTooltipsAtIndex(bars: bars, index: null), isEmpty);

    final shown = lineTooltipsAtIndex(bars: bars, index: 1);
    expect(shown, hasLength(1));
    expect(shown.first.showingSpots, hasLength(2));
    expect(shown.first.showingSpots.map((spot) => spot.x), [1, 1]);
  });

  test('barRodTooltipIndexes only for the selected group', () {
    expect(barRodTooltipIndexes(2, selected: false), isEmpty);
    expect(barRodTooltipIndexes(0, selected: true), isEmpty);
    expect(barRodTooltipIndexes(2, selected: true), [0, 1]);
  });

  test('TimedChartSelection hides after the hold duration', () async {
    var notified = 0;
    final selection = TimedChartSelection(
      () => notified++,
      holdDuration: Duration.zero,
    );

    selection.select(2);
    expect(selection.index, 2);
    expect(notified, 1);

    await Future<void>.delayed(Duration.zero);
    expect(selection.index, isNull);
    expect(notified, 2);
  });

  test('TimedChartSelection replaces the previous point immediately', () async {
    final selection = TimedChartSelection(
      () {},
      holdDuration: const Duration(milliseconds: 40),
    );

    selection.select(0);
    selection.select(1);
    expect(selection.index, 1);

    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(selection.index, 1);

    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(selection.index, isNull);
  });
}
