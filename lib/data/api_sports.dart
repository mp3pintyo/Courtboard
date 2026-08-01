import 'dart:convert';
import 'dart:io';

import 'football_season.dart';

class ApiSportsQuota {
  const ApiSportsQuota({required this.used, required this.limit});
  final int used;
  final int limit;
  int get remaining => (limit - used).clamp(0, limit);
  factory ApiSportsQuota.fromStatus(Map<String, dynamic> payload) {
    final response = payload['response'];
    final requests = response is Map && response['requests'] is Map
        ? response['requests'] as Map
        : const {};
    return ApiSportsQuota(
        used: _asInt(requests['current']),
        limit: _asInt(requests['limit_day'], fallback: 100));
  }
}

class ApiSportsGame {
  const ApiSportsGame(
      {required this.date,
      required this.opponent,
      required this.score,
      required this.result});
  final DateTime date;
  final String opponent;
  final String score;
  final String result;
}

class ApiSportsPlayer {
  const ApiSportsPlayer({
    required this.id,
    required this.name,
    this.country,
    this.birthDate,
    this.height,
    this.weight,
    this.position,
    this.jersey,
    this.college,
    this.active,
  });

  final int id;
  final String name;
  final String? country;
  final String? birthDate;
  final String? height;
  final String? weight;
  final String? position;
  final String? jersey;
  final String? college;
  final bool? active;

  factory ApiSportsPlayer.fromJson(Map<dynamic, dynamic> raw) {
    final birth = raw['birth'] is Map ? raw['birth'] as Map : const {};
    final height = raw['height'] is Map ? raw['height'] as Map : const {};
    final weight = raw['weight'] is Map ? raw['weight'] as Map : const {};
    final leagues = raw['leagues'] is Map ? raw['leagues'] as Map : const {};
    final standard =
        leagues['standard'] is Map ? leagues['standard'] as Map : const {};
    final firstName = '${raw['firstname'] ?? ''}'.trim();
    final lastName = '${raw['lastname'] ?? ''}'.trim();
    return ApiSportsPlayer(
      id: _asInt(raw['id']),
      name: '$firstName $lastName'.trim(),
      country: _nonEmpty(birth['country']),
      birthDate: _nonEmpty(birth['date']),
      height: _withUnit(height['meters'], 'm'),
      weight: _withUnit(weight['kilograms'], 'kg'),
      position: _nonEmpty(standard['pos']),
      jersey: _nonEmpty(standard['jersey']),
      college: _nonEmpty(raw['college']),
      active: standard['active'] is bool ? standard['active'] as bool : null,
    );
  }
}

class ApiSportsRepository {
  ApiSportsRepository(this.apiKey);
  final String apiKey;
  static final Map<String, bool> _freePlanByKey = {};
  Future<Map<String, dynamic>> get(String host, String path,
      [Map<String, String> query = const {}]) async {
    if (apiKey.trim().isEmpty) {
      throw StateError('API-Sports kulcs nincs beállítva.');
    }
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.https(host, path, query));
      request.headers.set('x-apisports-key', apiKey);
      final response = await request.close();
      final body = await utf8.decoder.bind(response).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('API-Sports HTTP ${response.statusCode}');
      }
      final payload = Map<String, dynamic>.from(jsonDecode(body) as Map);
      final errors = payload['errors'];
      if (errors is Map && errors.isNotEmpty) {
        throw StateError('API-Sports hiba: ${errors.values.join(', ')}');
      }
      return payload;
    } finally {
      client.close(force: true);
    }
  }

  Future<ApiSportsQuota> status(String host) async =>
      ApiSportsQuota.fromStatus(await get(host, '/status'));

  Future<bool> _usesFreePlan(String host) async {
    final cached = _freePlanByKey[apiKey];
    if (cached != null) return cached;
    final payload = await get(host, '/status');
    final response = payload['response'];
    final subscription = response is Map && response['subscription'] is Map
        ? response['subscription'] as Map
        : const {};
    final isFree = '${subscription['plan'] ?? ''}'.toLowerCase() == 'free';
    _freePlanByKey[apiKey] = isFree;
    return isFree;
  }

  Future<List<ApiSportsGame>> footballRecent(String team) async {
    const host = 'v3.football.api-sports.io';
    final search = footballTeamSearchTerm(team);
    final teams = await get(host, '/teams', {'search': search});
    final items = teams['response'] as List? ?? const [];
    if (items.isEmpty) return const [];
    final normalizedTeam = normalizeFootballTeamName(team);
    final first = items.whereType<Map>().cast<Map?>().firstWhere((item) {
          final rawTeam = item?['team'];
          final candidate = rawTeam is Map ? '${rawTeam['name'] ?? ''}' : '';
          return normalizeFootballTeamName(candidate) == normalizedTeam;
        }, orElse: () => items.first as Map) ??
        items.first as Map;
    final id =
        _asInt(first['team'] is Map ? (first['team'] as Map)['id'] : null);
    if (id == 0) return const [];
    final query = footballFixtureQuery(
        teamId: id, now: DateTime.now(), freePlan: await _usesFreePlan(host));
    final games = parseFootballFixtures(await get(host, '/fixtures', query), id,
        completedOnly: true);
    games.sort((a, b) => b.date.compareTo(a.date));
    return games.take(5).toList();
  }

  Future<List<FootballSeasonStat>> footballSeasonStats(String playerName,
      {DateTime? now}) async {
    const host = 'v3.football.api-sports.io';
    if (await _usesFreePlan(host)) {
      throw StateError(
          'Az API-Sports Free csomag nem ad aktuális szezonstatisztikát.');
    }
    final clock = now ?? DateTime.now();
    final searchParts = normalizeAthleteName(playerName)
        .split(' ')
        .where((part) => part.isNotEmpty)
        .toList();
    final search = searchParts.isEmpty ? playerName : searchParts.last;
    for (final season in [clock.year, clock.year - 1]) {
      final payload =
          await get(host, '/players', {'search': search, 'season': '$season'});
      final parsed = parseFootballPlayerStats(payload, playerName);
      if (parsed.isNotEmpty) return parsed;
    }
    return const [];
  }

  static List<FootballSeasonStat> parseFootballPlayerStats(
      Map<String, dynamic> payload, String playerName) {
    final response = payload['response'];
    if (response is! List) return const [];
    final normalized = normalizeAthleteName(playerName);
    final entries = response.whereType<Map>().toList();
    if (entries.isEmpty) return const [];
    final entry = entries.cast<Map?>().firstWhere((candidate) {
          final player = candidate?['player'];
          return player is Map &&
              athleteNamesMatch('${player['name'] ?? ''}', normalized);
        }, orElse: () => entries.first) ??
        entries.first;
    final statistics = entry['statistics'];
    if (statistics is! List) return const [];
    return statistics
        .whereType<Map>()
        .map((raw) {
          final team = raw['team'] is Map ? raw['team'] as Map : const {};
          final league = raw['league'] is Map ? raw['league'] as Map : const {};
          final games = raw['games'] is Map ? raw['games'] as Map : const {};
          final goals = raw['goals'] is Map ? raw['goals'] as Map : const {};
          final cards = raw['cards'] is Map ? raw['cards'] as Map : const {};
          final rating = double.tryParse('${games['rating'] ?? ''}');
          return FootballSeasonStat(
            season: '${league['season'] ?? ''}',
            team: '${team['name'] ?? ''}',
            competition: '${league['name'] ?? ''}',
            source: 'API-Sports',
            rating: rating,
            appearances: _asNullableInt(games['appearences']),
            goals: _asNullableInt(goals['total']),
            assists: _asNullableInt(goals['assists']),
            yellowCards: _asNullableInt(cards['yellow']),
            redCards: _asNullableInt(cards['red']),
          );
        })
        .where((item) => item.hasUsefulData())
        .toList(growable: false);
  }

  static Map<String, String> footballFixtureQuery({
    required int teamId,
    required DateTime now,
    required bool freePlan,
  }) {
    final currentSeason = now.month >= 7 ? now.year : now.year - 1;
    return {
      'team': '$teamId',
      // A Free csomag jelenleg 2022–2024 közötti adatot enged. Az aktuális
      // mérkőzéseket a football-data.org adapter egészíti ki a felületen.
      'season': freePlan ? '2024' : '$currentSeason',
    };
  }

  Future<ApiSportsPlayer?> nbaPlayer(String name) async {
    // Az API-NBA keresője a teljes névre gyakran nem ad találatot, és csak
    // ASCII betűket fogad el. A vezetéknévre keresünk, majd a teljes nevet
    // normalizálva egyeztetjük a többértelmű találatok között.
    final normalizedName = normalizeAthleteName(name);
    final parts = normalizedName.split(' ').where((part) => part.isNotEmpty);
    final search = parts.isEmpty ? normalizedName : parts.last;
    final payload =
        await get('v2.nba.api-sports.io', '/players', {'search': search});
    return parseNbaPlayer(payload, name);
  }

  static ApiSportsPlayer? parseNbaPlayer(
      Map<String, dynamic> payload, String name) {
    final normalizedName = normalizeAthleteName(name);
    final response = payload['response'];
    if (response is! List) return null;
    final players = response
        .whereType<Map>()
        .map(ApiSportsPlayer.fromJson)
        .where((player) => player.name.isNotEmpty)
        .toList();
    if (players.isEmpty) return null;
    return players.cast<ApiSportsPlayer?>().firstWhere(
        (player) => athleteNamesMatch(player!.name, normalizedName),
        orElse: () => players.first);
  }

  Future<Map<String, dynamic>> nflPlayer(String name) =>
      get('v1.american-football.api-sports.io', '/players', {'search': name});
  static List<ApiSportsGame> parseFootballFixtures(
      Map<String, dynamic> payload, int teamId,
      {bool completedOnly = false}) {
    final response = payload['response'];
    if (response is! List) return const [];
    return response.whereType<Map>().where((raw) {
      if (!completedOnly) return true;
      final fixture = raw['fixture'];
      final status = fixture is Map && fixture['status'] is Map
          ? '${(fixture['status'] as Map)['short'] ?? ''}'
          : '';
      return status.isEmpty || const {'FT', 'AET', 'PEN'}.contains(status);
    }).map((raw) {
      final teams = raw['teams'] is Map ? raw['teams'] as Map : const {};
      final home = teams['home'] is Map ? teams['home'] as Map : const {};
      final away = teams['away'] is Map ? teams['away'] as Map : const {};
      final isHome = _asInt(home['id']) == teamId;
      final own = isHome ? home : away;
      final opponent = isHome ? away : home;
      final goals = raw['goals'] is Map ? raw['goals'] as Map : const {};
      final ownGoals = _asInt(isHome ? goals['home'] : goals['away']);
      final otherGoals = _asInt(isHome ? goals['away'] : goals['home']);
      final won = own['winner'];
      return ApiSportsGame(
          date: DateTime.tryParse('${(raw['fixture'] as Map?)?['date']}') ??
              DateTime(1970),
          opponent: '${opponent['name'] ?? 'Ismeretlen'}',
          score: '$ownGoals–$otherGoals',
          result: won == true
              ? 'GY'
              : won == false
                  ? 'V'
                  : 'D');
    }).toList();
  }
}

String footballTeamSearchTerm(String value) {
  final words = value.trim().split(RegExp(r'\s+'));
  const clubTokens = {'fc', 'cf', 'afc', 'sc', 'ac'};
  final useful = words
      .where((word) => !clubTokens.contains(word.toLowerCase()))
      .join(' ')
      .trim();
  return useful.isEmpty ? value.trim() : useful;
}

String normalizeFootballTeamName(String value) => footballTeamSearchTerm(value)
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]'), '');

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
    'ď': 'd',
    'é': 'e',
    'è': 'e',
    'ê': 'e',
    'ë': 'e',
    'í': 'i',
    'ì': 'i',
    'î': 'i',
    'ï': 'i',
    'ľ': 'l',
    'ĺ': 'l',
    'ń': 'n',
    'ň': 'n',
    'ñ': 'n',
    'ó': 'o',
    'ò': 'o',
    'ô': 'o',
    'ö': 'o',
    'õ': 'o',
    'ő': 'o',
    'ř': 'r',
    'š': 's',
    'ś': 's',
    'ť': 't',
    'ú': 'u',
    'ù': 'u',
    'û': 'u',
    'ü': 'u',
    'ű': 'u',
    'ý': 'y',
    'ž': 'z',
    'ź': 'z',
    'ż': 'z',
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

bool athleteNamesMatch(String first, String second) {
  final firstName = normalizeAthleteName(first);
  final secondName = normalizeAthleteName(second);
  if (firstName == secondName) return true;
  final firstParts = firstName.split(' ')..sort();
  final secondParts = secondName.split(' ')..sort();
  return firstParts.length == secondParts.length &&
      List.generate(firstParts.length, (index) => index)
          .every((index) => firstParts[index] == secondParts[index]);
}

String? _nonEmpty(dynamic value) {
  final text = '${value ?? ''}'.trim();
  return text.isEmpty || text == 'null' ? null : text;
}

String? _withUnit(dynamic value, String unit) {
  final text = _nonEmpty(value);
  return text == null ? null : '$text $unit';
}

int _asInt(dynamic value, {int fallback = 0}) =>
    value is int ? value : int.tryParse('$value') ?? fallback;

int? _asNullableInt(dynamic value) =>
    value == null ? null : (value is int ? value : int.tryParse('$value'));
