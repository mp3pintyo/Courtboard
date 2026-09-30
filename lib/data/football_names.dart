import 'api_sports.dart' show athleteNameMatches, normalizeAthleteName;

const _clubTokens = {'fc', 'cf', 'afc', 'sc', 'ac'};

/// Keresőkifejezés csapatnévből: a gyakori klubelőtagok/-utótagok (FC, CF,
/// AFC, SC, AC) nélkül, például `FC Barcelona` → `Barcelona`.
String footballTeamSearchTerm(String value) {
  final words = value.trim().split(RegExp(r'\s+'));
  final useful = words
      .where((word) => !_clubTokens.contains(word.toLowerCase()))
      .join(' ')
      .trim();
  return useful.isEmpty ? value.trim() : useful;
}

/// Összehasonlító kulcs csapatnevekhez: klubtoldalék, ékezet, szóköz és
/// írásjel nélkül (`FC Bayern München` → `bayernmunchen`).
String normalizeFootballTeamName(String value) =>
    normalizeAthleteName(footballTeamSearchTerm(value)).replaceAll(' ', '');

/// Két csapatnév ugyanarra a klubra utal-e. Pontos kulcsegyezést vagy
/// szóhalmaz-egyezést fogad el (a keresett név minden szava szerepel).
bool footballTeamNamesMatch(String query, String candidate) {
  final expected = normalizeFootballTeamName(query);
  if (expected.isEmpty) return false;
  if (normalizeFootballTeamName(candidate) == expected) return true;
  return athleteNameMatches(
      footballTeamSearchTerm(query), footballTeamSearchTerm(candidate));
}

/// A [query] csapathoz illő elem: először pontos kulcsegyezés, aztán
/// [footballTeamNamesMatch]. Ha egyik sem illik, `null`.
T? findFootballTeamByName<T>(
  Iterable<T> items,
  String query,
  String Function(T item) nameOf,
) {
  final expected = normalizeFootballTeamName(query);
  for (final item in items) {
    if (normalizeFootballTeamName(nameOf(item)) == expected) return item;
  }
  for (final item in items) {
    if (footballTeamNamesMatch(query, nameOf(item))) return item;
  }
  return null;
}
