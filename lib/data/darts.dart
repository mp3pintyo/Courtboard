import 'dart:convert';
import 'dart:io';

import 'sports_api.dart';

class DartsResult {
  const DartsResult({
    required this.date,
    required this.event,
    required this.detail,
    this.position,
    this.country,
  });

  final DateTime date;
  final String event;
  final String detail;
  final int? position;
  final String? country;

  factory DartsResult.fromJson(Map<String, dynamic> json) => DartsResult(
        date: DateTime.parse('${json['dateEvent']}'),
        event: '${json['strEvent'] ?? 'Ismeretlen esemény'}',
        detail: '${json['strDetail'] ?? json['strResult'] ?? '—'}',
        position: int.tryParse('${json['intPosition'] ?? ''}'),
        country: _text(json['strCountry']),
      );
}

class DartsCompetition {
  const DartsCompetition({required this.name, this.id});
  final String name;
  final String? id;
}

class DartsProfileData {
  const DartsProfileData({
    this.player,
    this.results = const [],
    this.competitions = const [],
    this.theSportsDbError,
    this.rapidApiError,
    required this.rapidApiConfigured,
  });

  final Map<String, dynamic>? player;
  final List<DartsResult> results;
  final List<DartsCompetition> competitions;
  final String? theSportsDbError;
  final String? rapidApiError;
  final bool rapidApiConfigured;
}

class DartsRepository {
  DartsRepository(this.config,
      {this.rapidCacheLifetime = const Duration(hours: 6)});

  final SportsApiConfig config;
  final Duration rapidCacheLifetime;

  Future<DartsProfileData> fetch(String athleteName) async {
    final client = SportsApiClient(config: config);
    Map<String, dynamic>? player;
    var results = <DartsResult>[];
    var competitions = <DartsCompetition>[];
    String? theSportsDbError;
    String? rapidApiError;

    final sportsDbFuture = () async {
      try {
        player = await client.findTheSportsDbPlayer(athleteName);
        if (player == null) return;
        final id = _text(player!['idPlayer']);
        if (id == null) return;
        final payload =
            await client.theSportsDb('/playerresults.php', {'id': id});
        results = parseResults(payload);
      } catch (error) {
        theSportsDbError = '$error';
      }
    }();

    final rapidFuture = () async {
      if (config.rapidApiDartsKey.trim().isEmpty) return;
      try {
        final payload = await _rapidCompetitions(client);
        competitions = parseCompetitions(payload);
      } catch (error) {
        rapidApiError = '$error';
      }
    }();

    await Future.wait([sportsDbFuture, rapidFuture]);
    client.close();
    return DartsProfileData(
      player: player,
      results: results,
      competitions: competitions,
      theSportsDbError: theSportsDbError,
      rapidApiError: rapidApiError,
      rapidApiConfigured: config.rapidApiDartsKey.trim().isNotEmpty,
    );
  }

  Future<Map<String, dynamic>> _rapidCompetitions(
      SportsApiClient client) async {
    final cache = _rapidCacheFile();
    try {
      if (await cache.exists() &&
          DateTime.now().difference(await cache.lastModified()) <
              rapidCacheLifetime) {
        final decoded = jsonDecode(await cache.readAsString());
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}

    final payload = await client.rapidApiDarts('/competitions/3503');
    await cache.parent.create(recursive: true);
    await cache.writeAsString(jsonEncode(payload));
    return payload;
  }

  static File _rapidCacheFile() {
    final appData = Platform.environment['APPDATA'] ?? Directory.current.path;
    return File('$appData/courtboard_cache/rapidapi_darts/competitions.json');
  }

  static List<DartsResult> parseResults(Map<String, dynamic> payload) {
    final raw = payload['results'];
    if (raw is! List) return const [];
    final parsed = raw
        .whereType<Map>()
        .map((item) => DartsResult.fromJson(Map<String, dynamic>.from(item)))
        .toList();
    parsed.sort((a, b) => b.date.compareTo(a.date));
    return parsed.take(5).toList();
  }

  static List<DartsCompetition> parseCompetitions(
      Map<String, dynamic> payload) {
    dynamic raw = payload['data'] ??
        payload['competitions'] ??
        payload['response'] ??
        payload['result'];
    if (raw is Map) {
      raw = raw['data'] ?? raw['competitions'] ?? raw['items'];
    }
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) {
          final name = _text(item['competitionName'] ??
                  item['name'] ??
                  item['competition'] ??
                  item['title']) ??
              'Ismeretlen verseny';
          return DartsCompetition(
              name: name,
              id: _text(
                  item['competitionId'] ?? item['id'] ?? item['eventTypeId']));
        })
        .take(8)
        .toList();
  }
}

String? _text(dynamic value) {
  final result = '${value ?? ''}'.trim();
  return result.isEmpty || result == 'null' ? null : result;
}
