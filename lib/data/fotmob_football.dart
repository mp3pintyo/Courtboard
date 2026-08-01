import 'dart:convert';
import 'dart:io';

import 'api_sports.dart' show athleteNamesMatch, normalizeAthleteName;
import 'football_season.dart';

class FotMobFootballRepository {
  FotMobFootballRepository({HttpClient? client})
      : _client = client ?? HttpClient();

  final HttpClient _client;
  static final Map<String, _CachedFootballStat> _cache = {};
  static const _cacheDuration = Duration(hours: 6);

  Future<FootballSeasonStat?> fetchSeasonSummary(String athleteName,
      {DateTime? now}) async {
    final clock = now ?? DateTime.now();
    final cacheKey = normalizeAthleteName(athleteName);
    final cached = _cache[cacheKey];
    if (cached != null && clock.difference(cached.savedAt) < _cacheDuration) {
      return cached.value;
    }

    final playerId = await _findPlayerId(athleteName);
    if (playerId == null) return null;

    final player = await _get(Uri.https(
        'www.fotmob.com', '/api/data/playerData', {'id': '$playerId'}));
    final value = parseSeasonSummary(player, now: clock);
    if (value != null) {
      _cache[cacheKey] = _CachedFootballStat(clock, value);
    }
    return value;
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
    final request = await _client.getUrl(uri);
    request.headers
      ..set(HttpHeaders.userAgentHeader, 'Courtboard/1.0')
      ..set(HttpHeaders.acceptHeader, 'application/json');
    final response = await request.close();
    final body = await utf8.decoder.bind(response).join();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('FotMob HTTP ${response.statusCode}', uri: uri);
    }
    final decoded = jsonDecode(body);
    return decoded is Map
        ? Map<String, dynamic>.from(decoded)
        : const <String, dynamic>{};
  }

  static int? parsePlayerId(Map<String, dynamic> payload, String athleteName) {
    final suggestions = payload['squadMemberSuggest'];
    if (suggestions is! List) return null;
    final normalized = normalizeAthleteName(athleteName);
    final candidates = <Map>[];
    for (final group in suggestions.whereType<Map>()) {
      final options = group['options'];
      if (options is List) candidates.addAll(options.whereType<Map>());
    }
    if (candidates.isEmpty) return null;
    final exact = candidates.cast<Map?>().firstWhere((candidate) {
      final text = '${candidate?['text'] ?? ''}'.split('|').first;
      return athleteNamesMatch(text, normalized);
    }, orElse: () => candidates.first);
    final payloadMap = exact?['payload'];
    return _asInt(payloadMap is Map ? payloadMap['id'] : null);
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
      for (final stat in stats.whereType<Map>()) {
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
      rating: _asDouble(values['rating']),
      appearances: _asInt(values['matches_uppercase'] ?? values['matches']),
      goals: _asInt(values['goals']),
      assists: _asInt(values['assists']),
      yellowCards: _asInt(values['yellow_cards']),
      redCards: _asInt(values['red_cards']),
    );
    return result.hasUsefulData() ? result : null;
  }

  void close() => _client.close(force: true);
}

class _CachedFootballStat {
  const _CachedFootballStat(this.savedAt, this.value);
  final DateTime savedAt;
  final FootballSeasonStat value;
}

int? _asInt(dynamic value) =>
    value == null ? null : (value is int ? value : int.tryParse('$value'));

double? _asDouble(dynamic value) => value == null
    ? null
    : (value is num ? value.toDouble() : double.tryParse('$value'));
