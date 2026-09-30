import 'api_sports.dart';
import 'football_season.dart';
import 'fotmob_football.dart';
import 'sports_api.dart';

/// Szezonstatisztikák a forrásonkénti hibaüzenetekkel együtt.
class FootballSeasonResult {
  const FootballSeasonResult({this.stats = const [], this.errors = const []});

  final List<FootballSeasonStat> stats;

  /// Kulcsmentes, forrás-előtaggal ellátott hibaüzenetek (például
  /// „API-Sports: kvóta vagy kéréslimit túllépve (HTTP 429)”).
  final List<String> errors;
}

class FootballSeasonRepository {
  FootballSeasonRepository(this.config);
  final SportsApiConfig config;

  /// Visszafelé kompatibilis nézet: ha egyik forrás sem adott adatot, a
  /// forrásonkénti hibákat tartalmazó [StateError]-t dob.
  Future<List<FootballSeasonStat>> fetch(
      String athleteName, String teamName) async {
    final result = await fetchWithStatus(athleteName, teamName);
    if (result.stats.isEmpty) {
      final details =
          result.errors.isEmpty ? '' : ' (${result.errors.join('; ')})';
      throw StateError(
          'Az aktuális vagy előző szezonhoz egyik adatforrás sem adott játékosstatisztikát.$details');
    }
    return result.stats;
  }

  Future<FootballSeasonResult> fetchWithStatus(
      String athleteName, String teamName) async {
    final errors = <String>[];
    final apiSports = config.apiSportsKey.trim().isEmpty
        ? Future.value(const <FootballSeasonStat>[])
        : _capture(
            'API-Sports',
            errors,
            () => ApiSportsRepository(config.apiSportsKey)
                .footballSeasonStats(athleteName));
    final fotMob = _capture('FotMob', errors, () async {
      final repository = FotMobFootballRepository();
      try {
        return await repository.fetchSeasonSummary(athleteName);
      } finally {
        repository.close();
      }
    });
    final results = await Future.wait([apiSports, fotMob]);
    final items = results.expand((result) => result).toList();
    if (items.isEmpty) return FootballSeasonResult(errors: errors);

    final newestSeason =
        items.map((item) => item.seasonStart).reduce((a, b) => a > b ? a : b);
    final newest = items.where((item) => item.seasonStart == newestSeason);
    final merged = <String, FootballSeasonStat>{};
    for (final item in newest) {
      final key = '${_normalize(item.team)}|${_normalize(item.competition)}';
      merged[key] = merged[key]?.merge(item) ?? item;
    }
    final output = merged.values.toList()..sort(compareForTeam(teamName));
    return FootballSeasonResult(stats: output, errors: errors);
  }

  /// Teljes rendezés: előbb a megadott csapat sorai, aztán a több
  /// mérkőzéses sorok; ismeretlen meccsszám a végére kerül.
  static int Function(FootballSeasonStat, FootballSeasonStat) compareForTeam(
      String teamName) {
    final team = _normalize(teamName);
    return (a, b) {
      final aTeam = _normalize(a.team) == team ? 0 : 1;
      final bTeam = _normalize(b.team) == team ? 0 : 1;
      if (aTeam != bTeam) return aTeam.compareTo(bTeam);
      return (b.appearances ?? -1).compareTo(a.appearances ?? -1);
    };
  }

  Future<List<FootballSeasonStat>> _capture(
    String provider,
    List<String> errors,
    Future<dynamic> Function() operation,
  ) async {
    try {
      final value = await operation();
      if (value is FootballSeasonStat) return [value];
      if (value is List<FootballSeasonStat>) return value;
    } catch (error) {
      // A két forrás egymástól független: egyik hibája nem rejti el a másikat,
      // de az üzenetet (kulcs nélkül) továbbadjuk a felületnek.
      final text = '$error'
          .replaceFirst(RegExp(r'^(Bad state|Exception): '), '')
          .trim();
      errors.add(text.startsWith(provider) ? text : '$provider: $text');
    }
    return const [];
  }
}

String _normalize(String value) => normalizeAthleteName(value);
