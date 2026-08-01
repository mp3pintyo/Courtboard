import 'api_sports.dart';
import 'football_season.dart';
import 'fotmob_football.dart';
import 'sports_api.dart';

class FootballSeasonRepository {
  FootballSeasonRepository(this.config);
  final SportsApiConfig config;

  Future<List<FootballSeasonStat>> fetch(
      String athleteName, String teamName) async {
    final apiSports = _capture(() => ApiSportsRepository(config.apiSportsKey)
        .footballSeasonStats(athleteName));
    final fotMob = _capture(() async {
      final repository = FotMobFootballRepository();
      try {
        return await repository.fetchSeasonSummary(athleteName);
      } finally {
        repository.close();
      }
    });
    final results = await Future.wait([apiSports, fotMob]);
    final items = results.expand((result) => result).toList();
    if (items.isEmpty) {
      throw StateError(
          'Az aktuális vagy előző szezonhoz egyik adatforrás sem adott játékosstatisztikát.');
    }

    final newestSeason =
        items.map((item) => item.seasonStart).reduce((a, b) => a > b ? a : b);
    final newest = items.where((item) => item.seasonStart == newestSeason);
    final merged = <String, FootballSeasonStat>{};
    for (final item in newest) {
      final key = '${_normalize(item.team)}|${_normalize(item.competition)}';
      merged[key] = merged[key]?.merge(item) ?? item;
    }
    final output = merged.values.toList()
      ..sort((a, b) {
        final aTeam = _normalize(a.team) == _normalize(teamName) ? 0 : 1;
        final bTeam = _normalize(b.team) == _normalize(teamName) ? 0 : 1;
        if (aTeam != bTeam) return aTeam.compareTo(bTeam);
        return b.appearances?.compareTo(a.appearances ?? 0) ?? -1;
      });
    return output;
  }

  Future<List<FootballSeasonStat>> _capture(
      Future<dynamic> Function() operation) async {
    try {
      final value = await operation();
      if (value is FootballSeasonStat) return [value];
      if (value is List<FootballSeasonStat>) return value;
    } catch (_) {
      // A két forrás egymástól független: egyik hibája nem rejti el a másikat.
    }
    return const [];
  }
}

String _normalize(String value) => normalizeAthleteName(value);
