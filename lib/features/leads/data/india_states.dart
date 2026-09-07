/// Canonical Indian states/UTs used by the web Green Energy dashboard map.
const indiaStateNames = <String>[
  'Andhra Pradesh',
  'Arunachal Pradesh',
  'Assam',
  'Bihar',
  'Chhattisgarh',
  'Goa',
  'Gujarat',
  'Haryana',
  'Himachal Pradesh',
  'Jharkhand',
  'Karnataka',
  'Kerala',
  'Madhya Pradesh',
  'Maharashtra',
  'Manipur',
  'Meghalaya',
  'Mizoram',
  'Nagaland',
  'Odisha',
  'Punjab',
  'Rajasthan',
  'Sikkim',
  'Tamil Nadu',
  'Telangana',
  'Tripura',
  'Uttar Pradesh',
  'Uttarakhand',
  'West Bengal',
  'Andaman and Nicobar Islands',
  'Chandigarh',
  'Dadra and Nagar Haveli and Daman and Diu',
  'Delhi',
  'Jammu and Kashmir',
  'Ladakh',
  'Lakshadweep',
  'Puducherry',
];

const _stateAliases = <String, String>{
  'up': 'Uttar Pradesh',
  'u p': 'Uttar Pradesh',
  'uttar pradesh': 'Uttar Pradesh',
  'uk': 'Uttarakhand',
  'u k': 'Uttarakhand',
  'uttaranchal': 'Uttarakhand',
  'tamilnadu': 'Tamil Nadu',
  'west bengal': 'West Bengal',
  'orissa': 'Odisha',
  'pondicherry': 'Puducherry',
  'jammu & kashmir': 'Jammu and Kashmir',
  'jammu and kashmir': 'Jammu and Kashmir',
  'andaman & nicobar islands': 'Andaman and Nicobar Islands',
  'andaman and nicobar': 'Andaman and Nicobar Islands',
  'dadra and nagar haveli': 'Dadra and Nagar Haveli and Daman and Diu',
  'daman and diu': 'Dadra and Nagar Haveli and Daman and Diu',
  'nct of delhi': 'Delhi',
  'dl': 'Delhi',
  'nct delhi': 'Delhi',
};

String normalizeStateName(String? value) {
  final raw = (value ?? '').trim();
  if (raw.isEmpty) return '';

  final key = raw
      .toLowerCase()
      .replaceAll(RegExp(r'[._-]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  if (_stateAliases.containsKey(key)) return _stateAliases[key]!;

  for (final name in indiaStateNames) {
    if (name.toLowerCase() == key) return name;
  }
  return raw;
}

bool sameState(String? a, String? b) {
  final left = normalizeStateName(a);
  final right = normalizeStateName(b);
  if (left.isEmpty || right.isEmpty) return false;
  return left.toLowerCase() == right.toLowerCase();
}
