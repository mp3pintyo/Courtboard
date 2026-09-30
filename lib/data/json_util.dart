/// Közös, hibatűrő olvasók külső JSON- (és HTML-/CSV-) mezőkhöz.
///
/// A szolgáltatók ugyanazt a mezőt hol számként, hol szövegként, hol `null`
/// értékkel küldik; ezek a függvények soha nem dobnak kivételt.
library;

/// Egész szám; értelmezhetetlen értéknél [fallback].
///
/// Elfogad `int`, `num` (csonkolva) és szöveges alakot (szóközökkel,
/// előjellel, például `+14`).
int jsonInt(Object? value, {int fallback = 0}) =>
    jsonIntOrNull(value) ?? fallback;

/// Egész szám vagy `null`, ha az érték hiányzik vagy nem értelmezhető.
int? jsonIntOrNull(Object? value) {
  if (value is int) return value;
  if (value is num) return value.isFinite ? value.toInt() : null;
  final text = '${value ?? ''}'.trim();
  return text.isEmpty ? null : int.tryParse(text);
}

/// Lebegőpontos szám; értelmezhetetlen értéknél [fallback].
double jsonDouble(Object? value, {double fallback = 0}) =>
    jsonDoubleOrNull(value) ?? fallback;

/// Lebegőpontos szám vagy `null`, ha az érték hiányzik vagy nem értelmezhető.
double? jsonDoubleOrNull(Object? value) {
  if (value is num) return value.toDouble();
  final text = '${value ?? ''}'.trim();
  return text.isEmpty ? null : double.tryParse(text);
}

/// Levágott, nem üres szöveg; üres érték vagy a `"null"` szöveg esetén `null`.
String? jsonString(Object? value) {
  final text = '${value ?? ''}'.trim();
  return text.isEmpty || text == 'null' ? null : text;
}

/// Objektum `Map<String, dynamic>` alakban (sekély másolat); nem objektumnál
/// üres (const) map. Nem szöveges kulcsokat szöveggé alakít.
Map<String, dynamic> jsonMap(Object? value) => switch (value) {
  Map<String, dynamic>() => Map<String, dynamic>.of(value),
  Map() => {for (final MapEntry(:key, :value) in value.entries) '$key': value},
  _ => const <String, dynamic>{},
};

/// A lista objektum elemei `Map<String, dynamic>` alakban; a nem objektum
/// elemeket (és nem listánál az egészet) kihagyja.
List<Map<String, dynamic>> jsonMapList(Object? value) => [
  for (final item in jsonList(value))
    if (item is Map) jsonMap(item),
];

/// Lista; nem listánál üres (const) lista.
List<Object?> jsonList(Object? value) =>
    value is List ? value : const <Object?>[];
