import 'dart:convert';
import 'dart:io';

import 'sports_api.dart';
import 'wehoop_wnba.dart';

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
  });

  final String playerId;
  final String? team;
  final int? season;
  final List<WnbaAdvancedFact> facts;
  final List<String> awards;
}

class WnbaRapidApiRepository {
  WnbaRapidApiRepository(this.config,
      {this.cacheLifetime = const Duration(days: 7)});

  final SportsApiConfig config;
  final Duration cacheLifetime;

  Future<WnbaRapidProfile?> playerProfile(String athleteName) async {
    if (config.rapidApiDartsKey.trim().isEmpty) return null;
    final wehoop = WnbaWehoopRepository();
    late List<WnbaGameLog> games;
    try {
      games = await wehoop.recentGames(athleteName);
    } finally {
      wehoop.close();
    }
    final playerId = games.isEmpty ? '' : games.first.athleteId;
    if (playerId.isEmpty) return null;

    final cache = _cacheFile(playerId);
    final cached = await _readCache(cache, freshOnly: true);
    if (cached != null) return parseProfile(playerId, cached);

    final client = SportsApiClient(config: config);
    try {
      // A Basic gateway a két párhuzamos hívás egyikét 429-cel elutasíthatja.
      final bio =
          await client.rapidApiWnba('/player/bio', {'playerId': playerId});
      final advanced = await client.rapidApiWnba(
          '/player-advanced-stats', {'playerId': playerId, 'type': 'wnba'});
      final payload = {'bio': bio, 'advanced': advanced};
      await cache.parent.create(recursive: true);
      await cache.writeAsString(jsonEncode(payload));
      return parseProfile(playerId, payload);
    } catch (_) {
      final stale = await _readCache(cache, freshOnly: false);
      if (stale != null) return parseProfile(playerId, stale);
      rethrow;
    } finally {
      client.close();
    }
  }

  Future<Map<String, dynamic>?> _readCache(File file,
      {required bool freshOnly}) async {
    try {
      if (!await file.exists()) return null;
      if (freshOnly &&
          DateTime.now().difference(await file.lastModified()) >
              cacheLifetime) {
        return null;
      }
      final decoded = jsonDecode(await file.readAsString());
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } catch (_) {
      return null;
    }
  }

  static File _cacheFile(String playerId) {
    final appData = Platform.environment['APPDATA'] ?? Directory.current.path;
    return File(
        '$appData/courtboard_cache/rapidapi_wnba/player_$playerId.json');
  }

  static WnbaRapidProfile parseProfile(
      String playerId, Map<String, dynamic> payload) {
    final bioPayload = payload['bio'];
    final bio = bioPayload is Map && bioPayload['data'] is Map
        ? Map<String, dynamic>.from(bioPayload['data'] as Map)
        : const <String, dynamic>{};
    final histories = bio['teamHistory'];
    Map? currentTeam;
    if (histories is List) {
      final teams = histories.whereType<Map>().toList();
      currentTeam = teams.cast<Map?>().firstWhere(
          (team) => team?['isActive'] == true,
          orElse: () => teams.isEmpty ? null : teams.first);
    }
    final awards = <String>[];
    final rawAwards = bio['awards'];
    if (rawAwards is List) {
      for (final award in rawAwards.whereType<Map>()) {
        if ('${award['league']}' != 'wnba') continue;
        final name = '${award['name'] ?? ''}'.trim();
        if (name.isNotEmpty) {
          awards.add('${award['displayCount'] ?? ''} $name'.trim());
        }
      }
    }

    final advancedPayload = payload['advanced'];
    final playerStats =
        advancedPayload is Map ? advancedPayload['player_stats'] : null;
    final categories = playerStats is Map ? playerStats['categories'] : null;
    Map? averages;
    if (categories is List) {
      averages = categories.whereType<Map>().cast<Map?>().firstWhere(
          (category) => category?['name'] == 'averages',
          orElse: () => null);
    }
    final labels = averages?['labels'];
    final statistics = averages?['statistics'];
    Map? latest;
    if (statistics is List) {
      for (final statistic in statistics.whereType<Map>()) {
        final season = statistic['season'];
        final year = season is Map ? int.tryParse('${season['year']}') ?? 0 : 0;
        final latestSeason = latest?['season'];
        final latestYear = latestSeason is Map
            ? int.tryParse('${latestSeason['year']}') ?? 0
            : 0;
        if (latest == null || year > latestYear) latest = statistic;
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
      '3P%'
    };
    final facts = <WnbaAdvancedFact>[];
    if (labels is List && values is List) {
      for (var index = 0;
          index < labels.length && index < values.length;
          index++) {
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
