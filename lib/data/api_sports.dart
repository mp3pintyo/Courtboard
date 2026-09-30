import 'dart:convert';

import 'athlete_names.dart';
import 'file_util.dart';
import 'football_names.dart';
import 'football_season.dart';
import 'http_service.dart';
import 'json_file_cache.dart';
import 'json_util.dart';

export 'athlete_names.dart';

class ApiSportsQuota {
  const ApiSportsQuota({required this.used, required this.limit});
  final int used;
  final int limit;
  int get remaining => (limit - used).clamp(0, limit);
  factory ApiSportsQuota.fromStatus(Map<String, dynamic> payload) {
    final requests = jsonMap(jsonMap(payload['response'])['requests']);
    return ApiSportsQuota(
        used: jsonInt(requests['current']),
        limit: jsonInt(requests['limit_day'], fallback: 100));
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

  factory ApiSportsPlayer.fromJson(Map<String, dynamic> raw) {
    final birth = jsonMap(raw['birth']);
    final height = jsonMap(raw['height']);
    final weight = jsonMap(raw['weight']);
    final standard = jsonMap(jsonMap(raw['leagues'])['standard']);
    final firstName = '${raw['firstname'] ?? ''}'.trim();
    final lastName = '${raw['lastname'] ?? ''}'.trim();
    return ApiSportsPlayer(
      id: jsonInt(raw['id']),
      name: '$firstName $lastName'.trim(),
      country: jsonString(birth['country']),
      birthDate: jsonString(birth['date']),
      height: _withUnit(height['meters'], 'm'),
      weight: _withUnit(weight['kilograms'], 'kg'),
      position: jsonString(standard['pos']),
      jersey: jsonString(standard['jersey']),
      college: jsonString(raw['college']),
      active: switch (standard['active']) {
        final bool active => active,
        _ => null,
      },
    );
  }
}

class ApiSportsRepository {
  ApiSportsRepository(
    this.apiKey, {
    HttpService? http,
    CacheStorage? cacheStorage,
    DateTime Function()? clock,
  })  : _http = http ?? HttpService.shared,
        _cache =
            JsonFileCache('api_sports', storage: cacheStorage, clock: clock);

  final String apiKey;
  final HttpService _http;
  final JsonFileCache _cache;

  /// Kvótavédő gyorsítótár-élettartamok (Free csomag: napi 100 kérés).
  static const statusCacheLifetime = Duration(hours: 1);
  static const playerCacheLifetime = Duration(hours: 12);
  static const teamCacheLifetime = Duration(days: 7);
  static const fixtureCacheLifetime = Duration(hours: 6);

  /// Közvetlen (gyorsítótár nélküli) hívás. Az API-Sports hibát 200-as
  /// válaszban, `errors` mezőben is jelezhet: ezt [StateError]-ként dobjuk,
  /// így az ilyen válasz nem kerül gyorsítótárba.
  Future<Map<String, dynamic>> get(String host, String path,
      [Map<String, String> query = const {}]) async {
    if (apiKey.trim().isEmpty) {
      throw StateError('API-Sports kulcs nincs beállítva.');
    }
    final body = await _http.getText(Uri.https(host, path, query),
        provider: 'API-Sports', headers: {'x-apisports-key': apiKey});
    final payload = jsonMap(jsonDecode(body));
    final errors = payload['errors'];
    if (errors is Map && errors.isNotEmpty) {
      throw StateError('API-Sports hiba: ${errors.values.join(', ')}');
    }
    return payload;
  }

  /// Lemezre gyorsítótárazott hívás: friss bejegyzésnél nem fogy a keret,
  /// hibánál a lejárt példány is visszajön. Az egyidejű azonos hívások
  /// ugyanazt a kérést kapják.
  Future<CachedValue<Map<String, dynamic>>> getCached(
    String host,
    String path,
    Map<String, String> query, {
    required Duration ttl,
    bool keyDependent = false,
  }) async {
    if (apiKey.trim().isEmpty) {
      throw StateError('API-Sports kulcs nincs beállítva.');
    }
    final keys = query.keys.toList()..sort();
    final cacheKey = [
      host,
      path,
      for (final name in keys) '$name=${query[name]}',
      // A csomagtól függő válasz (például /status) kulcsonként külön él.
      if (keyDependent) 'key=${fnv1a32Hex(apiKey.trim())}',
    ].join('|').toLowerCase();
    return _cache.getOrFetch<Map<String, dynamic>>(
      cacheKey,
      ttl: ttl,
      fetch: () => get(host, path, query),
      encode: (value) => value,
      decode: jsonMap,
    );
  }

  Future<ApiSportsQuota> status(String host) async =>
      ApiSportsQuota.fromStatus((await getCached(host, '/status', const {},
              ttl: statusCacheLifetime, keyDependent: true))
          .value);

  /// A `/status` 1 órás gyorsítótárból; az egyidejű első hívók a
  /// gyorsítótár közös Future-jét kapják, hiba esetén később újrapróbálható.
  Future<bool> _usesFreePlan(String host) async {
    final payload = (await getCached(host, '/status', const {},
            ttl: statusCacheLifetime, keyDependent: true))
        .value;
    final subscription =
        jsonMap(jsonMap(payload['response'])['subscription']);
    return '${subscription['plan'] ?? ''}'.toLowerCase() == 'free';
  }

  Future<List<ApiSportsGame>> footballRecent(String team) async {
    const host = 'v3.football.api-sports.io';
    final search = footballTeamSearchTerm(team);
    final teams = (await getCached(host, '/teams', {'search': search},
            ttl: teamCacheLifetime))
        .value;
    final items = jsonMapList(teams['response']);
    if (items.isEmpty) return const [];
    final first = findFootballTeamByName(
        items, team, (item) => '${jsonMap(item['team'])['name'] ?? ''}');
    // Nincs névegyezés: inkább üres lista, mint egy másik csapat meccsei.
    if (first == null) return const [];
    final id = jsonInt(jsonMap(first['team'])['id']);
    if (id == 0) return const [];
    final query = footballFixtureQuery(
        teamId: id, now: DateTime.now(), freePlan: await _usesFreePlan(host));
    final fixtures =
        (await getCached(host, '/fixtures', query, ttl: fixtureCacheLifetime))
            .value;
    final games = parseFootballFixtures(fixtures, id, completedOnly: true);
    games.sort((a, b) => b.date.compareTo(a.date));
    return games.take(5).toList();
  }

  Future<List<FootballSeasonStat>> footballSeasonStats(String playerName,
          {DateTime? now}) async =>
      (await footballSeasonStatsCached(playerName, now: now)).value;

  /// Szezonstatisztikák a (gyorsítótárbeli) letöltés idejével.
  Future<CachedValue<List<FootballSeasonStat>>> footballSeasonStatsCached(
      String playerName,
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
    // Az európai szezon júliusban indul: január–június között a naptári év
    // még az előző évben kezdődött szezonhoz tartozik.
    final currentSeason = clock.month >= 7 ? clock.year : clock.year - 1;
    CachedValue<Map<String, dynamic>>? last;
    for (final season in [currentSeason, currentSeason - 1]) {
      final payload = last = await getCached(
          host, '/players', {'search': search, 'season': '$season'},
          ttl: playerCacheLifetime);
      final parsed = parseFootballPlayerStats(payload.value, playerName);
      if (parsed.isNotEmpty) return payload.map((_) => parsed);
    }
    return last!.map((_) => const <FootballSeasonStat>[]);
  }

  static List<FootballSeasonStat> parseFootballPlayerStats(
      Map<String, dynamic> payload, String playerName) {
    final entries = jsonMapList(payload['response']);
    final entry = findAthleteByName(entries, playerName,
        (candidate) => '${jsonMap(candidate['player'])['name'] ?? ''}');
    if (entry == null) return const [];
    return jsonMapList(entry['statistics'])
        .map((raw) {
          final team = jsonMap(raw['team']);
          final league = jsonMap(raw['league']);
          final games = jsonMap(raw['games']);
          final goals = jsonMap(raw['goals']);
          final cards = jsonMap(raw['cards']);
          final rating = double.tryParse('${games['rating'] ?? ''}');
          return FootballSeasonStat(
            season: '${league['season'] ?? ''}',
            team: '${team['name'] ?? ''}',
            competition: '${league['name'] ?? ''}',
            source: 'API-Sports',
            rating: rating,
            appearances: jsonIntOrNull(games['appearences']),
            goals: jsonIntOrNull(goals['total']),
            assists: jsonIntOrNull(goals['assists']),
            yellowCards: jsonIntOrNull(cards['yellow']),
            redCards: jsonIntOrNull(cards['red']),
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
    final payload = (await getCached(
            'v2.nba.api-sports.io', '/players', {'search': search},
            ttl: playerCacheLifetime))
        .value;
    return parseNbaPlayer(payload, name);
  }

  static ApiSportsPlayer? parseNbaPlayer(
      Map<String, dynamic> payload, String name) {
    final players = jsonMapList(payload['response'])
        .map(ApiSportsPlayer.fromJson)
        .where((player) => player.name.isNotEmpty)
        .toList();
    return findAthleteByName(players, name, (player) => player.name);
  }

  Future<Map<String, dynamic>> nflPlayer(String name) async =>
      (await getCached('v1.american-football.api-sports.io', '/players',
              {'search': name},
              ttl: playerCacheLifetime))
          .value;
  static List<ApiSportsGame> parseFootballFixtures(
      Map<String, dynamic> payload, int teamId,
      {bool completedOnly = false}) {
    return jsonMapList(payload['response']).where((raw) {
      if (!completedOnly) return true;
      final status =
          '${jsonMap(jsonMap(raw['fixture'])['status'])['short'] ?? ''}';
      return status.isEmpty || const {'FT', 'AET', 'PEN'}.contains(status);
    }).map((raw) {
      final teams = jsonMap(raw['teams']);
      final home = jsonMap(teams['home']);
      final away = jsonMap(teams['away']);
      final isHome = jsonInt(home['id']) == teamId;
      final own = isHome ? home : away;
      final opponent = isHome ? away : home;
      final goals = jsonMap(raw['goals']);
      final ownGoals = jsonInt(isHome ? goals['home'] : goals['away']);
      final otherGoals = jsonInt(isHome ? goals['away'] : goals['home']);
      final won = own['winner'];
      return ApiSportsGame(
          date: DateTime.tryParse('${jsonMap(raw['fixture'])['date']}') ??
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

String? _withUnit(Object? value, String unit) {
  final text = jsonString(value);
  return text == null ? null : '$text $unit';
}
