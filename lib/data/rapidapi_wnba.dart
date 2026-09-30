import 'package:courtboard/data/file_util.dart';
import 'package:courtboard/data/http_service.dart';
import 'package:courtboard/data/json_file_cache.dart';
import 'package:courtboard/data/json_util.dart';
import 'package:courtboard/data/sports_api.dart';
import 'package:courtboard/data/wehoop_wnba.dart';

class WnbaAdvancedFact {
  const WnbaAdvancedFact(this.label, this.value);
  final String label;
  final String value;
}

class WnbaRapidProfile {
  const WnbaRapidProfile({
    required this.playerId,
    this.team,
    this.season,
    this.facts = const [],
    this.awards = const [],
    this.fetchedAt,
    this.fromCache = false,
  });

  final String playerId;
  final String? team;
  final int? season;
  final List<WnbaAdvancedFact> facts;
  final List<String> awards;

  /// A RapidAPI-válasz letöltési ideje (gyorsítótárból az eredetié).
  final DateTime? fetchedAt;
  final bool fromCache;

  WnbaRapidProfile withFreshness(
    DateTime fetchedAt, {
    required bool fromCache,
  }) => WnbaRapidProfile(
    playerId: playerId,
    team: team,
    season: season,
    facts: facts,
    awards: awards,
    fetchedAt: fetchedAt,
    fromCache: fromCache,
  );
}

class WnbaRapidApiRepository {
  /// A [wehoop] alapértelmezése a közös [WnbaWehoopRepository.shared]
  /// példány, így a szezon-CSV nem töltődik le és dolgozódik fel minden
  /// profilmegnyitáskor újra.
  WnbaRapidApiRepository(
    this.config, {
    this.cacheLifetime = const Duration(days: 7),
    WnbaWehoopRepository? wehoop,
    this._http,
    this._cacheStorage,
  }) : _wehoop = wehoop ?? WnbaWehoopRepository.shared;

  final SportsApiConfig config;
  final Duration cacheLifetime;
  final WnbaWehoopRepository _wehoop;
  final HttpService? _http;
  final CacheStorage? _cacheStorage;

  Future<WnbaRapidProfile?> playerProfile(String athleteName) async {
    if (config.rapidApiKey.trim().isEmpty) return null;
    final games = await _wehoop.recentGames(athleteName);
    final playerId = games.isEmpty ? '' : games.first.athleteId;
    if (playerId.isEmpty) return null;

    final client = SportsApiClient(
      config: config,
      http: _http,
      cacheStorage: _cacheStorage,
    );
    // A Free csomag havi 100 hívása miatt hosszú lemezes gyorsítótár, hibánál
    // a lejárt példány is visszajön.
    final payload = await client
        .cache('rapidapi_wnba')
        .getOrFetch<Map<String, dynamic>>(
          'player_${cacheSlug(playerId)}',
          ttl: cacheLifetime,
          fetch: () async {
            // A Basic gateway a két párhuzamos hívás egyikét 429-cel elutasíthatja.
            final bio = await client.rapidApiWnba('/player/bio', {
              'playerId': playerId,
            });
            final advanced = await client.rapidApiWnba(
              '/player-advanced-stats',
              {'playerId': playerId, 'type': 'wnba'},
            );
            return {'bio': bio, 'advanced': advanced};
          },
          encode: (value) => value,
          decode: jsonMap,
        );
    return parseProfile(
      playerId,
      payload.value,
    ).withFreshness(payload.fetchedAt, fromCache: payload.fromCache);
  }

  static WnbaRapidProfile parseProfile(
    String playerId,
    Map<String, dynamic> payload,
  ) {
    final bio = jsonMap(jsonMap(payload['bio'])['data']);
    final teams = jsonMapList(bio['teamHistory']);
    final currentTeam = teams.isEmpty
        ? null
        : teams.firstWhere(
            (team) => team['isActive'] == true,
            orElse: () => teams.first,
          );
    final awards = <String>[];
    for (final award in jsonMapList(bio['awards'])) {
      if ('${award['league']}' != 'wnba') continue;
      final name = '${award['name'] ?? ''}'.trim();
      if (name.isNotEmpty) {
        awards.add('${award['displayCount'] ?? ''} $name'.trim());
      }
    }

    final playerStats = jsonMap(jsonMap(payload['advanced'])['player_stats']);
    final averages = jsonMapList(
      playerStats['categories'],
    ).where((category) => category['name'] == 'averages').firstOrNull;
    final labels = averages?['labels'];
    Map<String, dynamic>? latest;
    var latestYear = 0;
    for (final statistic in jsonMapList(averages?['statistics'])) {
      final year = jsonInt(jsonMap(statistic['season'])['year']);
      if (latest == null || year > latestYear) {
        latest = statistic;
        latestYear = year;
      }
    }
    final values = latest?['stats'];
    const wanted = {
      'GP',
      'MIN',
      'PTS',
      'REB',
      'AST',
      'STL',
      'TO',
      'TOV',
      'BLK',
      'FG%',
      '3P%',
    };
    final facts = <WnbaAdvancedFact>[];
    if (labels is List && values is List) {
      for (
        var index = 0;
        index < labels.length && index < values.length;
        index++
      ) {
        final label = '${labels[index]}';
        if (wanted.contains(label)) {
          facts.add(WnbaAdvancedFact(label, '${values[index]}'));
        }
      }
    }
    final latestSeason = latest?['season'];
    return WnbaRapidProfile(
      playerId: playerId,
      team: currentTeam == null ? null : '${currentTeam['displayName']}',
      season: latestSeason is Map
          ? int.tryParse('${latestSeason['year'] ?? ''}')
          : null,
      facts: facts,
      awards: awards.take(4).toList(),
    );
  }
}
