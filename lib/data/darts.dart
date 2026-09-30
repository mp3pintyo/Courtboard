import 'package:courtboard/data/friendly_error.dart';
import 'package:courtboard/data/http_service.dart';
import 'package:courtboard/data/json_file_cache.dart';
import 'package:courtboard/data/json_util.dart';
import 'package:courtboard/data/sports_api.dart';

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

  /// Értelmezhetetlen dátumú sornál `null`; a külső adat így nem dönti el a
  /// teljes listát.
  static DartsResult? tryFromJson(Map<String, dynamic> json) =>
      DateTime.tryParse('${json['dateEvent'] ?? ''}') == null
      ? null
      : DartsResult.fromJson(json);

  factory DartsResult.fromJson(Map<String, dynamic> json) => DartsResult(
    date: DateTime.parse('${json['dateEvent']}'),
    event: '${json['strEvent'] ?? 'Ismeretlen esemény'}',
    detail: '${json['strDetail'] ?? json['strResult'] ?? '—'}',
    position: int.tryParse('${json['intPosition'] ?? ''}'),
    country: jsonString(json['strCountry']),
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
    this.fetchedAt,
    this.rapidApiFetchedAt,
    this.rapidApiFromCache = false,
  });

  final Map<String, dynamic>? player;
  final List<DartsResult> results;
  final List<DartsCompetition> competitions;
  final String? theSportsDbError;
  final String? rapidApiError;
  final bool rapidApiConfigured;

  /// A TheSportsDB-adatok lekérésének ideje.
  final DateTime? fetchedAt;

  /// A RapidAPI versenylista letöltési ideje (gyorsítótárból érkezve az
  /// eredeti letöltésé).
  final DateTime? rapidApiFetchedAt;
  final bool rapidApiFromCache;
}

class DartsRepository {
  DartsRepository(
    this.config, {
    this.rapidCacheLifetime = const Duration(hours: 6),
    this._http,
    this._cacheStorage,
  });

  final SportsApiConfig config;
  final Duration rapidCacheLifetime;
  final HttpService? _http;
  final CacheStorage? _cacheStorage;

  Future<DartsProfileData> fetch(String athleteName) async {
    final client = SportsApiClient(
      config: config,
      http: _http,
      cacheStorage: _cacheStorage,
    );
    final fetchedAt = DateTime.now();
    Map<String, dynamic>? player;
    var results = <DartsResult>[];
    var competitions = <DartsCompetition>[];
    String? theSportsDbError;
    String? rapidApiError;
    DateTime? rapidFetchedAt;
    var rapidFromCache = false;

    final sportsDbFuture = () async {
      try {
        player = await client.findTheSportsDbPlayer(athleteName);
        if (player == null) return;
        final id = jsonString(player!['idPlayer']);
        if (id == null) return;
        final payload = await client.theSportsDb('/playerresults.php', {
          'id': id,
        });
        results = parseResults(payload);
      } catch (error) {
        theSportsDbError = friendlyError(error);
      }
    }();

    final rapidFuture = () async {
      if (config.rapidApiKey.trim().isEmpty) return;
      try {
        final payload = await _rapidCompetitions(client);
        competitions = parseCompetitions(payload.value);
        rapidFetchedAt = payload.fetchedAt;
        rapidFromCache = payload.fromCache;
      } catch (error) {
        rapidApiError = friendlyError(error);
      }
    }();

    try {
      await Future.wait([sportsDbFuture, rapidFuture]);
    } finally {
      client.close();
    }
    return DartsProfileData(
      player: player,
      results: results,
      competitions: competitions,
      theSportsDbError: theSportsDbError,
      rapidApiError: rapidApiError,
      rapidApiConfigured: config.rapidApiKey.trim().isNotEmpty,
      fetchedAt: fetchedAt,
      rapidApiFetchedAt: rapidFetchedAt,
      rapidApiFromCache: rapidFromCache,
    );
  }

  /// A RapidAPI versenylista a havi 1000 kérés védelmében
  /// [rapidCacheLifetime] ideig lemezről jön; hibánál a lejárt példány is.
  Future<CachedValue<Map<String, dynamic>>> _rapidCompetitions(
    SportsApiClient client,
  ) => client
      .cache('rapidapi_darts')
      .getOrFetch<Map<String, dynamic>>(
        'competitions_3503',
        ttl: rapidCacheLifetime,
        fetch: () => client.rapidApiDarts('/competitions/3503'),
        encode: (value) => value,
        decode: jsonMap,
      );

  static List<DartsResult> parseResults(Map<String, dynamic> payload) {
    final parsed = jsonMapList(
      payload['results'],
    ).map(DartsResult.tryFromJson).whereType<DartsResult>().toList();
    parsed.sort((a, b) => b.date.compareTo(a.date));
    return parsed.take(5).toList();
  }

  static List<DartsCompetition> parseCompetitions(
    Map<String, dynamic> payload,
  ) {
    Object? raw =
        payload['data'] ??
        payload['competitions'] ??
        payload['response'] ??
        payload['result'];
    if (raw is Map) {
      raw = raw['data'] ?? raw['competitions'] ?? raw['items'];
    }
    return jsonMapList(raw)
        .map((item) {
          final name =
              jsonString(
                item['competitionName'] ??
                    item['name'] ??
                    item['competition'] ??
                    item['title'],
              ) ??
              'Ismeretlen verseny';
          return DartsCompetition(
            name: name,
            id: jsonString(
              item['competitionId'] ?? item['id'] ?? item['eventTypeId'],
            ),
          );
        })
        .take(8)
        .toList();
  }
}
