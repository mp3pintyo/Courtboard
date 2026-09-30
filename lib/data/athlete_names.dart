/// Sportolónevek normalizálása és laza, de nem „első találat” jellegű
/// névegyeztetése külső adatforrások keresőtalálataihoz.
library;

/// Ékezet-, írásjel- és kisbetű-független összehasonlító alak
/// (`Nikola Jokić` → `nikola jokic`).
String normalizeAthleteName(String value) {
  const replacements = {
    'á': 'a',
    'à': 'a',
    'â': 'a',
    'ä': 'a',
    'ã': 'a',
    'å': 'a',
    'č': 'c',
    'ć': 'c',
    'ç': 'c',
    'đ': 'd',
    'ð': 'd',
    'ď': 'd',
    'é': 'e',
    'è': 'e',
    'ê': 'e',
    'ë': 'e',
    'ğ': 'g',
    'í': 'i',
    'ì': 'i',
    'î': 'i',
    'ï': 'i',
    'ı': 'i',
    'ľ': 'l',
    'ĺ': 'l',
    'ł': 'l',
    'ń': 'n',
    'ň': 'n',
    'ñ': 'n',
    'ó': 'o',
    'ò': 'o',
    'ô': 'o',
    'ö': 'o',
    'õ': 'o',
    'ő': 'o',
    'ø': 'o',
    'ř': 'r',
    'š': 's',
    'ś': 's',
    'ş': 's',
    'ș': 's',
    'ť': 't',
    'ț': 't',
    'ú': 'u',
    'ù': 'u',
    'û': 'u',
    'ü': 'u',
    'ű': 'u',
    'ý': 'y',
    'ž': 'z',
    'ź': 'z',
    'ż': 'z',
    'ą': 'a',
    'ā': 'a',
    'ă': 'a',
    'ę': 'e',
    'ė': 'e',
    'ē': 'e',
    'ě': 'e',
    'ī': 'i',
    'į': 'i',
    'ķ': 'k',
    'ļ': 'l',
    'ņ': 'n',
    'ō': 'o',
    'ŕ': 'r',
    'ţ': 't',
    'ū': 'u',
    'ů': 'u',
    'ų': 'u',
    'ÿ': 'y',
    'æ': 'ae',
    'œ': 'oe',
    'ß': 'ss',
  };
  final lower = value.toLowerCase().trim();
  final buffer = StringBuffer();
  for (final rune in lower.runes) {
    final character = String.fromCharCode(rune);
    buffer.write(replacements[character] ?? character);
  }
  return buffer
      .toString()
      .replaceAll(RegExp(r'[^a-z0-9 ]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// Pontos, de sorrendfüggetlen egyezés a normalizált nevek szavain.
bool athleteNamesMatch(String first, String second) {
  final firstName = normalizeAthleteName(first);
  final secondName = normalizeAthleteName(second);
  if (firstName == secondName) return true;
  final firstParts = firstName.split(' ')..sort();
  final secondParts = secondName.split(' ')..sort();
  return firstParts.length == secondParts.length &&
      List.generate(
        firstParts.length,
        (index) => index,
      ).every((index) => firstParts[index] == secondParts[index]);
}

/// Laza, de nem „első találat” jellegű névegyezés külső keresőtalálatokhoz.
///
/// Elfogadja, ha a normalizált nevek egyeznek; ha ugyanazok a szavak más
/// sorrendben szerepelnek (`Juhász Dorka` ~ `Dorka Juhasz`); ha a jelölt a
/// keresett név minden szavát tartalmazza (középső név, második vezetéknév);
/// ha a keresett név tartalmazza a legalább kétszavas jelölt minden szavát;
/// vagy ha a vezetéknév egyezik és az egyik keresztnév csak kezdőbetű
/// (`N. Jokic` ~ `Nikola Jokic`).
bool athleteNameMatches(String query, String candidate) {
  final queryTokens = _nameTokens(query);
  final candidateTokens = _nameTokens(candidate);
  if (queryTokens.isEmpty || candidateTokens.isEmpty) return false;
  final querySet = queryTokens.toSet();
  final candidateSet = candidateTokens.toSet();
  if (candidateSet.containsAll(querySet)) return true;
  if (candidateSet.length >= 2 && querySet.containsAll(candidateSet)) {
    return true;
  }
  if (queryTokens.length >= 2 && candidateTokens.length >= 2) {
    final queryFirst = queryTokens.first;
    final candidateFirst = candidateTokens.first;
    return queryTokens.last == candidateTokens.last &&
        (queryFirst.length == 1 || candidateFirst.length == 1) &&
        queryFirst[0] == candidateFirst[0];
  }
  return false;
}

/// A [query] névhez legjobban illő elem: először pontos (sorrendfüggetlen)
/// egyezést keres, aztán [athleteNameMatches] szerinti lazábbat. Ha egyik
/// sem illik, `null` – soha nem az első találat.
T? findAthleteByName<T>(
  Iterable<T> items,
  String query,
  String Function(T item) nameOf,
) {
  for (final item in items) {
    if (athleteNamesMatch(nameOf(item), query)) return item;
  }
  for (final item in items) {
    if (athleteNameMatches(query, nameOf(item))) return item;
  }
  return null;
}

List<String> _nameTokens(String value) => normalizeAthleteName(
  value,
).split(' ').where((token) => token.isNotEmpty).toList();
