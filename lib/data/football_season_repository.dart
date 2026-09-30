import 'api_sports.dart';
import 'football_season.dart';
import 'fotmob_football.dart';
import 'http_service.dart';
import 'json_file_cache.dart';
import 'sports_api.dart';

/// Szezonstatisztikák a forrásonkénti hibaüzenetekkel együtt.
class FootballSeasonResult {
  const FootballSeasonResult({
    this.stats = const [],
    this.errors = const [],
    this.fetchedAt,
    this.fromCache = false,
  });

  final List<FootballSeasonStat> stats;

  /// Kulcsmentes, forrás-előtaggal ellátott hibaüzenetek (például
  /// „API-Sports: kvóta vagy kéréslimit túllépve (HTTP 429)”).
  final List<String> errors;

  /// Az adatot adó források közül a legrégebbi letöltés ideje.
  final DateTime? fetchedAt;

  /// Igaz, ha minden adatot adó forrás gyorsítótárból jött.
  final bool fromCache;
}

class FootballSeasonRepository {
  FootballSeasonRepository(this.config, {this._http, this._cacheStorage});
  final SportsApiConfig config;
  final HttpService? _http;
  final CacheStorage? _cacheStorage;

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
        ? Future.value(const _Captured())
        : _capture(
            'API-Sports',
            errors,
            () => ApiSportsRepository(config.apiSportsKey,
                    http: _http, cacheStorage: _cacheStorage)
                .footballSeasonStatsCached(athleteName));
    final fotMob = _capture(
        'FotMob',
        errors,
        () => FotMobFootballRepository(
                http: _http, cacheStorage: _cacheStorage)
            .fetchSeasonSummaryCached(athleteName));
    final results = await Future.wait([apiSports, fotMob]);
    final items = results.expand((result) => result.stats).toList();
    if (items.isEmpty) return FootballSeasonResult(errors: errors);
    final sources = results.where((result) => result.stats.isNotEmpty);
    final fetchedAt = sources
        .map((result) => result.fetchedAt!)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    final fromCache = sources.every((result) => result.fromCache);

    final newestSeason =
        items.map((item) => item.seasonStart).reduce((a, b) => a > b ? a : b);
    final newest = items.where((item) => item.seasonStart == newestSeason);
    final merged = <String, FootballSeasonStat>{};
    for (final item in newest) {
      final key = '${_normalize(item.team)}|${_normalize(item.competition)}';
      merged[key] = merged[key]?.merge(item) ?? item;
    }
    final output = merged.values.toList()..sort(compareForTeam(teamName));
    return FootballSeasonResult(
      stats: output,
      errors: errors,
      fetchedAt: fetchedAt,
      fromCache: fromCache,
    );
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

  Future<_Captured> _capture(
    String provider,
    List<String> errors,
    Future<CachedValue<Object?>> Function() operation,
  ) async {
    try {
      final result = await operation();
      final value = result.value;
      final stats = value is FootballSeasonStat
          ? [value]
          : value is List<FootballSeasonStat>
              ? value
              : const <FootballSeasonStat>[];
      return _Captured(
        stats: stats,
        fetchedAt: result.fetchedAt,
        fromCache: result.fromCache,
      );
    } catch (error) {
      // A két forrás egymástól független: egyik hibája nem rejti el a másikat,
      // de az üzenetet (kulcs nélkül) továbbadjuk a felületnek.
      final text = '$error'
          .replaceFirst(RegExp(r'^(Bad state|Exception): '), '')
          .trim();
      errors.add(text.startsWith(provider) ? text : '$provider: $text');
    }
    return const _Captured();
  }
}

class _Captured {
  const _Captured({
    this.stats = const [],
    this.fetchedAt,
    this.fromCache = false,
  });

  final List<FootballSeasonStat> stats;
  final DateTime? fetchedAt;
  final bool fromCache;
}

String _normalize(String value) => normalizeAthleteName(value);
