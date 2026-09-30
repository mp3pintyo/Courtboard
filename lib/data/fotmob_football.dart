import 'dart:convert';
import 'dart:io';

import 'athlete_names.dart';
import 'football_season.dart';
import 'http_service.dart';
import 'json_file_cache.dart';
import 'json_util.dart';

class FotMobFootballRepository {
  FotMobFootballRepository({
    HttpService? http,
    CacheStorage? cacheStorage,
    DateTime Function()? clock,
  })  : _http = http ?? HttpService.shared,
        _cache = JsonFileCache('fotmob', storage: cacheStorage, clock: clock);

  final HttpService _http;
  final JsonFileCache _cache;

  /// Játékosonként ennyi ideig lemezről jön az összesítő (a „nincs adat”
  /// eredmény is), így a nem kulcsos, de nem hivatalos API-t kímélve.
  static const cacheDuration = Duration(hours: 6);

  Future<FootballSeasonStat?> fetchSeasonSummary(String athleteName,
          {DateTime? now}) async =>
      (await fetchSeasonSummaryCached(athleteName, now: now)).value;

  /// Szezonösszesítő a letöltés idejével; a `null` (nincs friss szezon vagy
  /// nincs találat) is gyorsítótárba kerül.
  Future<CachedValue<FootballSeasonStat?>> fetchSeasonSummaryCached(
    String athleteName, {
    DateTime? now,
  }) {
    final key = normalizeAthleteName(athleteName).replaceAll(' ', '_');
    return _cache.getOrFetch<FootballSeasonStat?>(
      key.isEmpty ? 'empty' : key,
      ttl: cacheDuration,
      missTtl: cacheDuration,
      fetch: () async {
        final clock = now ?? DateTime.now();
        final playerId = await _findPlayerId(athleteName);
        if (playerId == null) return null;
        final player = await _get(Uri.https(
            'www.fotmob.com', '/api/data/playerData', {'id': '$playerId'}));
        return parseSeasonSummary(player, now: clock);
      },
      encode: (value) => value?.toJson(),
      decode: (json) =>
          json == null ? null : FootballSeasonStat.fromJson(jsonMap(json)),
    );
  }

  Future<int?> _findPlayerId(String athleteName) async {
    final normalized = normalizeAthleteName(athleteName);
    final parts =
        normalized.split(' ').where((part) => part.isNotEmpty).toList();
    final queries = <String>{
      athleteName,
      if (parts.length > 1) parts.reversed.join(' '),
      if (parts.isNotEmpty)
        parts.reduce(
            (longest, part) => part.length > longest.length ? part : longest),
    };
    for (final query in queries) {
      final search = await _get(Uri.https('apigw.fotmob.com',
          '/searchapi/suggest', {'term': query, 'lang': 'en'}));
      final playerId = parsePlayerId(search, athleteName);
      if (playerId != null) return playerId;
    }
    return null;
  }

  Future<Map<String, dynamic>> _get(Uri uri) async {
    final body = await _http.getText(uri, provider: 'FotMob', headers: {
      HttpHeaders.userAgentHeader: 'Courtboard/1.0',
      HttpHeaders.acceptHeader: 'application/json',
    });
    final decoded = jsonDecode(body);
    return decoded is Map
        ? Map<String, dynamic>.from(decoded)
        : const <String, dynamic>{};
  }

  static int? parsePlayerId(Map<String, dynamic> payload, String athleteName) {
    final suggestions = payload['squadMemberSuggest'];
    if (suggestions is! List) return null;
    final candidates = <Map<String, dynamic>>[];
    for (final group in jsonMapList(suggestions)) {
      final options = group['options'];
      if (options is List) candidates.addAll(jsonMapList(options));
    }
    final exact = findAthleteByName(candidates, athleteName,
        (candidate) => '${candidate['text'] ?? ''}'.split('|').first);
    if (exact == null) return null;
    final payloadMap = exact['payload'];
    return jsonIntOrNull(payloadMap is Map ? payloadMap['id'] : null);
  }

  static FootballSeasonStat? parseSeasonSummary(Map<String, dynamic> payload,
      {required DateTime now}) {
    final mainLeague = payload['mainLeague'];
    final primaryTeam = payload['primaryTeam'];
    if (mainLeague is! Map || primaryTeam is! Map) return null;
    final season = '${mainLeague['season'] ?? ''}'.trim();
    if (!isCurrentOrPreviousFootballSeason(season, now)) return null;
    final values = <String, dynamic>{};
    final stats = mainLeague['stats'];
    if (stats is List) {
      for (final stat in jsonMapList(stats)) {
        final key =
            '${stat['localizedTitleId'] ?? stat['title'] ?? ''}'.toLowerCase();
        values[key] = stat['value'];
      }
    }
    final result = FootballSeasonStat(
      season: season,
      team: '${primaryTeam['teamName'] ?? ''}'.trim(),
      competition: '${mainLeague['leagueName'] ?? ''}'.trim(),
      source: 'FotMob',
      rating: jsonDoubleOrNull(values['rating']),
      appearances:
          jsonIntOrNull(values['matches_uppercase'] ?? values['matches']),
      goals: jsonIntOrNull(values['goals']),
      assists: jsonIntOrNull(values['assists']),
      yellowCards: jsonIntOrNull(values['yellow_cards']),
      redCards: jsonIntOrNull(values['red_cards']),
      recentMatches: parseRecentMatches(payload),
    );
    return result.hasUsefulData() ? result : null;
  }

  /// A játékos legutóbbi mérkőzései (`recentMatches`), legújabb elöl, legfeljebb
  /// [limit] darab. A kispadon maradt (nem játszott) meccsek kimaradnak. A
  /// FotMob a listát közvetlenül vagy sorozatonként csoportosítva is adhatja.
  static List<FootballMatchForm> parseRecentMatches(
    Map<String, dynamic> payload, {
    int limit = 10,
  }) {
    final raw = payload['recentMatches'];
    final entries = <Map<String, dynamic>>[
      if (raw is List) ...jsonMapList(raw),
      if (raw is Map)
        for (final group in raw.values) ...jsonMapList(group),
    ];
    final matches = <FootballMatchForm>[];
    final seen = <String>{};
    for (final entry in entries) {
      if (entry['onBench'] == true) continue;
      final rawDate = entry['matchDate'];
      final date = DateTime.tryParse(
        rawDate is Map ? '${rawDate['utcTime'] ?? ''}' : '${rawDate ?? ''}',
      );
      if (date == null) continue;
      final opponent =
          jsonString(entry['opponentTeamName'] ?? entry['opponentName']) ?? '';
      final home = entry['isHomeTeam'] != false;
      final homeScore = jsonIntOrNull(entry['homeScore']);
      final awayScore = jsonIntOrNull(entry['awayScore']);
      final ratingProps = entry['ratingProps'];
      final rating = jsonDoubleOrNull(ratingProps is Map
          ? ratingProps['num'] ?? ratingProps['rating']
          : entry['rating']);
      final key = '${entry['id'] ?? ''}|${date.toIso8601String()}|$opponent';
      if (!seen.add(key)) continue;
      matches.add(FootballMatchForm(
        date: date.toLocal(),
        opponent: opponent,
        competition: jsonString(entry['leagueName']) ?? '',
        teamScore: home ? homeScore : awayScore,
        opponentScore: home ? awayScore : homeScore,
        rating: rating != null && rating > 0 ? rating : null,
        goals: jsonIntOrNull(entry['goals']) ?? 0,
        assists: jsonIntOrNull(entry['assists']) ?? 0,
        minutes: jsonIntOrNull(entry['minutesPlayed']),
      ));
    }
    matches.sort((a, b) => b.date.compareTo(a.date));
    return matches.take(limit).toList(growable: false);
  }

  /// Visszafelé kompatibilis no-op: a közös [HttpService] kliense nyitva marad.
  void close() {}
}
