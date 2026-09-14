/**
 * Builds Flutter city data from the same country-state-city@3.2.1
 * dataset used by Imt_Billbook_frontend customer/lead forms.
 */
const fs = require('fs');
const path = require('path');

const root = path.resolve(__dirname, '..', '..');
const pkg = path.join(
  root,
  'Imt_Billbook_frontend',
  'node_modules',
  'country-state-city',
  'lib',
  'cjs',
  'assets',
);

const states = require(path.join(pkg, 'state.json'));
const citiesRaw = require(path.join(pkg, 'city.json'));

function compareName(a, b) {
  if (a < b) return -1;
  if (a > b) return 1;
  return 0;
}

function dartString(value) {
  return `'${String(value)
    .replace(/\\/g, '\\\\')
    .replace(/'/g, "\\'")
    .replace(/\$/g, '\\$')}'`;
}

const indianStates = states
  .filter((state) => state.countryCode === 'IN')
  .slice()
  .sort((a, b) => compareName(a.name, b.name));

const nameByIso = Object.fromEntries(
  indianStates.map((state) => [state.isoCode, state.name]),
);

const byState = Object.fromEntries(indianStates.map((state) => [state.name, []]));

for (const row of citiesRaw) {
  const name = row[0];
  const countryCode = row[1];
  const stateCode = row[2];
  if (countryCode !== 'IN') continue;
  const stateName = nameByIso[stateCode];
  if (!stateName) continue;
  byState[stateName].push(name);
}

for (const stateName of Object.keys(byState)) {
  byState[stateName].sort(compareName);
}

const lines = [];
lines.push("import 'package:solar_sales/features/leads/data/india_states.dart';");
lines.push('');
lines.push('/// City names grouped by canonical Indian state, copied from');
lines.push('/// `country-state-city@3.2.1` (`City.getCitiesOfState("IN", iso)`)');
lines.push('/// so the app matches the web customer / lead forms.');
lines.push('const Map<String, List<String>> indiaCitiesByState = {');

for (const state of indianStates) {
  const cities = byState[state.name];
  lines.push(`  ${dartString(state.name)}: [`);
  for (const city of cities) {
    lines.push(`    ${dartString(city)},`);
  }
  lines.push('  ],');
}

lines.push('};');
lines.push('');
lines.push('List<String> citiesForIndiaState(String? state) {');
lines.push('  final name = normalizeStateName(state);');
lines.push('  if (name.isEmpty) return const [];');
lines.push(
  '  return List<String>.from(indiaCitiesByState[name] ?? const <String>[]);',
);
lines.push('}');
lines.push('');
lines.push('String resolveIndiaCityName(String? city, String? state) {');
lines.push("  final raw = (city ?? '').trim();");
lines.push("  if (raw.isEmpty) return '';");
lines.push('  final cities = citiesForIndiaState(state);');
lines.push('  for (final item in cities) {');
lines.push('    if (item.toLowerCase() == raw.toLowerCase()) return item;');
lines.push('  }');
lines.push('  return raw;');
lines.push('}');
lines.push('');
lines.push('List<String> indiaStateOptionsIncluding(String? current) {');
lines.push('  final options = List<String>.from(indiaStateNames);');
lines.push('  final value = normalizeStateName(current);');
lines.push('  if (value.isNotEmpty &&');
lines.push(
  '      !options.any((item) => item.toLowerCase() == value.toLowerCase())) {',
);
lines.push('    options.insert(0, value);');
lines.push('  }');
lines.push('  return options;');
lines.push('}');
lines.push('');
lines.push('List<String> indiaCityOptionsIncluding(String? state, String? current) {');
lines.push('  final options = citiesForIndiaState(state);');
lines.push("  final value = (current ?? '').trim();");
lines.push('  if (value.isNotEmpty &&');
lines.push(
  '      !options.any((item) => item.toLowerCase() == value.toLowerCase())) {',
);
lines.push('    options.insert(0, value);');
lines.push('  }');
lines.push('  return options;');
lines.push('}');
lines.push('');
lines.push('bool cityBelongsToState(String? city, String? state) {');
lines.push("  final raw = (city ?? '').trim();");
lines.push('  if (raw.isEmpty) return true;');
lines.push('  return citiesForIndiaState(state)');
lines.push(
  '      .any((item) => item.toLowerCase() == raw.toLowerCase());',
);
lines.push('}');
lines.push('');

const outPath = path.join(
  root,
  'Solar_360_app',
  'lib',
  'features',
  'leads',
  'data',
  'india_cities.dart',
);
fs.writeFileSync(outPath, lines.join('\n'));

const total = Object.values(byState).reduce((sum, list) => sum + list.length, 0);
console.log(`Wrote ${outPath}`);
console.log(`States: ${indianStates.length}, cities: ${total}`);
console.log(
  indianStates
    .map((state) => `${state.name}: ${byState[state.name].length}`)
    .join('\n'),
);
