import 'package:flutter_test/flutter_test.dart';
import 'package:solar_sales/features/leads/data/india_cities.dart';
import 'package:solar_sales/features/leads/data/india_states.dart';

void main() {
  test('cities appear only after a canonical Indian state is selected', () {
    expect(citiesForIndiaState(''), isEmpty);
    expect(citiesForIndiaState('Rajasthan'), containsAll(['Jaipur', 'Udaipur', 'Kota']));
    expect(citiesForIndiaState('UP'), contains('Lucknow'));
    expect(citiesForIndiaState('Maharashtra'), contains('Mumbai'));
    expect(cityBelongsToState('Jaipur', 'Rajasthan'), isTrue);
    expect(cityBelongsToState('Jaipur', 'Kerala'), isFalse);
  });

  test('keeps a custom city when it is not in the selected state list', () {
    expect(resolveIndiaCityName('Unknown Town', 'Rajasthan'), 'Unknown Town');
    expect(resolveIndiaCityName('jaipur', 'Rajasthan'), 'Jaipur');
    expect(
      indiaCityOptionsIncluding('Rajasthan', 'Custom Place').first,
      'Custom Place',
    );
    expect(indiaStateOptionsIncluding('orissa'), contains('Odisha'));
    expect(normalizeStateName('RJ'), 'Rajasthan');
  });
}
