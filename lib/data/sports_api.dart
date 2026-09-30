import 'dart:io';

import 'package:courtboard/data/api_key_id.dart';
import 'package:courtboard/data/athlete_names.dart';
import 'package:courtboard/data/http_service.dart';
import 'package:courtboard/data/json_file_cache.dart';
import 'package:courtboard/data/json_util.dart';

/// A szolgáltatói kulcsok. Forrásuk az appban mentett (biztonságos tárolóban
/// őrzött) kulcs, ennek hiányában a környezeti változó. A desktop appból
/// kikerülő kulcsok ettől még nem teljesen védettek; később egy egyszemélyes
/// backend proxy ajánlott.
class SportsApiConfig {
  const SportsApiConfig({
    this.apiSportsKey = '',
    this.balldontlieKey = '',
    this.footballDataKey = '',
    this.youtubeKey = '',
    this.rapidApiKey = '',
    this.liveTennisKey = '',
  });

  /// Kulcsok a környezeti változókból ([environment] alapértelmezése a
  /// folyamat környezete). A RapidAPI kulcs a `RAPIDAPI_KEY`, visszafelé
  /// kompatibilisen a `RAPIDAPI_DARTS_KEY` változóból is jöhet.
  factory SportsApiConfig.fromEnvironment([Map<String, String>? environment]) {
    final env = environment ?? Platform.environment;
    return SportsApiConfig(
      youtubeKey: env['YOUTUBE_DATA_KEY'] ?? '',
    ).withKeys({for (final id in ApiKeyId.values) id: id.fromEnvironment(env)});
  }

  final String apiSportsKey;
  final String balldontlieKey;
  final String footballDataKey;
  final String youtubeKey;

  /// A Darts és a WNBA RapidAPI közös alkalmazáskulcsa.
  final String rapidApiKey;
  final String liveTennisKey;

  bool get hasAnyKey =>
      youtubeKey.isNotEmpty || ApiKeyId.values.any((id) => key(id).isNotEmpty);

  /// Az [id] szolgáltató kulcsa (üres, ha nincs beállítva).
  String key(ApiKeyId id) => switch (id) {
    ApiKeyId.footballData => footballDataKey,
    ApiKeyId.apiSports => apiSportsKey,
    ApiKeyId.balldontlie => balldontlieKey,
    ApiKeyId.rapidApi => rapidApiKey,
    ApiKeyId.liveTennis => liveTennisKey,
  };

  SportsApiConfig copyWith({
    String? apiSportsKey,
    String? balldontlieKey,
    String? footballDataKey,
    String? youtubeKey,
    String? rapidApiKey,
    String? liveTennisKey,
  }) => SportsApiConfig(
    apiSportsKey: apiSportsKey ?? this.apiSportsKey,
    balldontlieKey: balldontlieKey ?? this.balldontlieKey,
    footballDataKey: footballDataKey ?? this.footballDataKey,
    youtubeKey: youtubeKey ?? this.youtubeKey,
    rapidApiKey: rapidApiKey ?? this.rapidApiKey,
    liveTennisKey: liveTennisKey ?? this.liveTennisKey,
  );

  /// Új konfiguráció, amelyben az [id] kulcsa [value] (levágva).
  SportsApiConfig withKey(ApiKeyId id, String value) {
    final trimmed = value.trim();
    return switch (id) {
      ApiKeyId.footballData => copyWith(footballDataKey: trimmed),
      ApiKeyId.apiSports => copyWith(apiSportsKey: trimmed),
      ApiKeyId.balldontlie => copyWith(balldontlieKey: trimmed),
      ApiKeyId.rapidApi => copyWith(rapidApiKey: trimmed),
      ApiKeyId.liveTennis => copyWith(liveTennisKey: trimmed),
    };
  }

  /// A [keys] nem üres értékei felülírják a meglévőket; az üresek nem
  /// törlik a (például környezeti változóból jövő) kulcsot.
  SportsApiConfig withKeys(Map<ApiKeyId, String> keys) {
    var result = this;
    for (final MapEntry(key: id, :value) in keys.entries) {
      if (value.trim().isNotEmpty) result = result.withKey(id, value);
    }
    return result;
  }
}

class SportsApiClient {
  /// A [http] alapértelmezése a közös [HttpService.shared] (egyetlen
  /// kapcsolatkészlet, kéréskorlát és keretszámláló); a [cacheStorage]
  /// alapértelmezése a közös lemezes gyorsítótár.
  SportsApiClient({
    SportsApiConfig? config,
    HttpService? http,
    this._cacheStorage,
    this._clock,
  }) : config = config ?? SportsApiConfig.fromEnvironment(),
       _http = http ?? HttpService.shared;

  final SportsApiConfig config;
  final HttpService _http;
  final CacheStorage? _cacheStorage;

  /// A gyorsítótár frissességét eldöntő óra (tesztekhez); alapból a
  /// rendszeróra.
  final DateTime Function()? _clock;
  static const theSportsDbFreeKey = '123';

  /// Kvótavédő gyorsítótár-élettartamok.
  static const ballDontLieCacheLifetime = Duration(hours: 12);
  static const theSportsDbSearchCacheLifetime = Duration(hours: 24);
  static const footballDataTeamsCacheLifetime = Duration(days: 7);

  /// Szolgáltatónkénti JSON-gyorsítótár ugyanazon a háttértáron.
  JsonFileCache cache(String namespace) =>
      JsonFileCache(namespace, storage: _cacheStorage, clock: _clock);

  /// Közös GET: 10 mp kapcsolódási és 20 mp teljes időkorláttal, a
  /// szolgáltató kéréskorlátjával és újrapróbálással. A hibák
  /// [CourtboardHttpException]-ként érkeznek, query-paraméterek (és így
  /// URL-ben küldött kulcsok) nélkül.
  Future<Map<String, dynamic>> _get(
    Uri uri, {
    required String provider,
    Map<String, String> headers = const {},
  }) => _http.getJson(uri, provider: provider, headers: headers);

  /// Lemezre gyorsítótárazott JSON-válasz a [namespace] névtérben; a kulcs
  /// az útvonalból és a (rendezett) query-ből képződik.
  Future<Map<String, dynamic>> _cachedGet(
    String namespace,
    String path,
    Map<String, String> query,
    Duration ttl,
    Future<Map<String, dynamic>> Function() fetch,
  ) async {
    final keys = query.keys.toList()..sort();
    final key = [
      path,
      for (final name in keys) '$name=${query[name]}',
    ].join('|').toLowerCase();
    return (await cache(namespace).getOrFetch<Map<String, dynamic>>(
      key,
      ttl: ttl,
      fetch: fetch,
      encode: (value) => value,
      decode: jsonMap,
    )).value;
  }

  /// API-Sports hívó. A domain sportonként eltér: football, basketball/NBA,
  /// american-football/NFL; a konkrét liga-coverage-et az API dokumentációban
  /// kell ellenőrizni.
  Future<Map<String, dynamic>> apiSports(
    String sportDomain,
    String path,
    Map<String, String> query,
  ) {
    if (config.apiSportsKey.trim().isEmpty) {
      throw StateError('API_SPORTS_KEY nincs beállítva.');
    }
    final uri = Uri.https('v3.$sportDomain.api-sports.io', path, query);
    return _get(
      uri,
      provider: 'API-Sports',
      headers: {'x-apisports-key': config.apiSportsKey},
    );
  }

  /// NBA alapadatok a BALLDONTLIE hivatalos API-hostjáról.
  Future<Map<String, dynamic>> ballDontLieNba(
    String path, [
    Map<String, String> query = const {},
  ]) {
    if (config.balldontlieKey.trim().isEmpty) {
      throw StateError('BALLDONTLIE_KEY nincs beállítva.');
    }
    final uri = Uri.https('api.balldontlie.io', path, query);
    return _cachedGet(
      'balldontlie',
      path,
      query,
      ballDontLieCacheLifetime,
      () => _get(
        uri,
        provider: 'BALLDONTLIE',
        headers: {'Authorization': config.balldontlieKey},
      ),
    );
  }

  /// Foci: ingyenes top-versenyek, eredmények és tabellák.
  Future<Map<String, dynamic>> footballData(
    String path, [
    Map<String, String> query = const {},
  ]) {
    if (config.footballDataKey.isEmpty) {
      throw StateError(
        'FOOTBALL_DATA_KEY nincs a futó alkalmazás környezetében.',
      );
    }
    final uri = Uri.https('api.football-data.org', path, query);
    return _get(
      uri,
      provider: 'football-data.org',
      headers: {'X-Auth-Token': config.footballDataKey},
    );
  }

  /// A football-data.org Free csapatlistája (`/v4/teams?limit=500`), 7 napos
  /// közös gyorsítótárral: a csapatmeccs- és a játékoskártya is ezt használja.
  Future<Map<String, dynamic>> footballDataTeams() async {
    if (config.footballDataKey.isEmpty) {
      throw StateError(
        'FOOTBALL_DATA_KEY nincs a futó alkalmazás környezetében.',
      );
    }
    return (await cache('football_data').getOrFetch<Map<String, dynamic>>(
      'teams_limit_500',
      ttl: footballDataTeamsCacheLifetime,
      fetch: () => footballData('/v4/teams', {'limit': '500'}),
      encode: (value) => value,
      decode: jsonMap,
    )).value;
  }

  /// Profilok, csapatok és képek a nyilvános TheSportsDB Free v1 kulccsal.
  ///
  /// A keresések (`/search…`) 24 órás lemezes gyorsítótárba kerülnek.
  Future<Map<String, dynamic>> theSportsDb(
    String path, [
    Map<String, String> query = const {},
  ]) {
    final uri = theSportsDbUri(path, query);
    Future<Map<String, dynamic>> fetch() => _get(uri, provider: 'TheSportsDB');
    if (!path.startsWith('/search')) return fetch();
    return _cachedGet(
      'thesportsdb',
      path,
      query,
      theSportsDbSearchCacheLifetime,
      fetch,
    );
  }

  /// Sportbex Darts API a RapidAPI gatewayen keresztül. A jelenlegi API
  /// versenyeket, eseményeket, piacokat és oddsokat biztosít; játékosprofilt
  /// nem, ezért azt a TheSportsDB egészíti ki.
  Future<Map<String, dynamic>> rapidApiDarts(
    String path, [
    Map<String, String> query = const {},
  ]) {
    if (config.rapidApiKey.trim().isEmpty) {
      throw StateError('RapidAPI kulcs nincs beállítva.');
    }
    final uri = Uri.https('darts-api.p.rapidapi.com', path, query);
    return _get(
      uri,
      provider: 'RapidAPI Darts',
      headers: {
        'X-RapidAPI-Key': config.rapidApiKey,
        'X-RapidAPI-Host': 'darts-api.p.rapidapi.com',
      },
    );
  }

  /// WNBA játékosadatok ugyanazzal a RapidAPI alkalmazáskulccsal. A Free
  /// csomag havi 100 hívása miatt a repository hosszú lemezes cache-t használ.
  Future<Map<String, dynamic>> rapidApiWnba(
    String path, [
    Map<String, String> query = const {},
  ]) {
    if (config.rapidApiKey.trim().isEmpty) {
      throw StateError('RapidAPI kulcs nincs beállítva.');
    }
    final uri = Uri.https('wnba-api.p.rapidapi.com', path, query);
    return _get(
      uri,
      provider: 'RapidAPI WNBA',
      headers: {
        'X-RapidAPI-Key': config.rapidApiKey,
        'X-RapidAPI-Host': 'wnba-api.p.rapidapi.com',
      },
    );
  }

  /// Live Tennis API Free végpontok. A kulcsot fejlécben küldjük, így nem
  /// kerül URL-be, előzményekbe vagy proxy-naplóba.
  Future<Map<String, dynamic>> liveTennis(
    String path, [
    Map<String, String> query = const {},
  ]) {
    if (config.liveTennisKey.trim().isEmpty) {
      throw StateError('LIVE_TENNIS_API_KEY nincs beállítva.');
    }
    final uri = Uri.https(
      'api.livetennisapi.com',
      '/api/public/v1$path',
      query,
    );
    return _get(
      uri,
      provider: 'Live Tennis API',
      headers: {'Authorization': 'Bearer ${config.liveTennisKey.trim()}'},
    );
  }

  /// ESPN liga-paraméteres labdarúgó scoreboard a [from]–[to] napok között
  /// (mindkettő beleértve). A Liga F kódja esp.w.1.
  Future<Map<String, dynamic>> espnSoccerScoreboard(
    String league, {
    required DateTime from,
    required DateTime to,
    int limit = 200,
  }) => _get(
    espnScoreboardUri(league, from: from, to: to, limit: limit),
    provider: 'ESPN',
  );

  /// ESPN nyilvános foci-„site” API (`/apis/site/v2/sports/soccer/…`),
  /// például `usa.1/teams` vagy `all/teams/20232/schedule`. Kulcs nem kell;
  /// a közös „ESPN” korlát (percenként 30 kérés) fogja vissza.
  Future<Map<String, dynamic>> espnSoccerSite(
    String path, [
    Map<String, String>? query,
  ]) => _get(
    Uri.https(
      'site.api.espn.com',
      '/apis/site/v2/sports/soccer/$path',
      query == null || query.isEmpty ? null : query,
    ),
    provider: 'ESPN',
  );

  /// ESPN labdarúgó scoreboard egy teljes naptári évre (`dates=ÉÉÉÉ`). A
  /// jövőbe nyúló napi tartományt az ESPN 400-as hibával utasítja el, az
  /// éves lekérés viszont a még le nem játszott meccseket is tartalmazza.
  Future<Map<String, dynamic>> espnSoccerScoreboardYear(
    String league,
    int year, {
    int limit = 500,
  }) => _get(
    Uri.https(
      'site.api.espn.com',
      '/apis/site/v2/sports/soccer/$league/scoreboard',
      {'dates': '$year', 'limit': '$limit'},
    ),
    provider: 'ESPN',
  );

  static Uri espnScoreboardUri(
    String league, {
    required DateTime from,
    required DateTime to,
    int limit = 200,
  }) => Uri.https(
    'site.api.espn.com',
    '/apis/site/v2/sports/soccer/$league/scoreboard',
    {'dates': '${espnDate(from)}-${espnDate(to)}', 'limit': '$limit'},
  );

  /// ESPN `YYYYMMDD` dátumformátum.
  static String espnDate(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}'
      '${value.month.toString().padLeft(2, '0')}'
      '${value.day.toString().padLeft(2, '0')}';

  static Uri theSportsDbUri(
    String path, [
    Map<String, String> query = const {},
  ]) => Uri.https(
    'www.thesportsdb.com',
    '/api/v1/json/$theSportsDbFreeKey$path',
    query,
  );

  /// Nyilvános TheSportsDB névfeloldás profilképhez. Nincs saját API-kulcs
  /// szükséges; hiba vagy nem találat esetén a hívó monogramos fallbacket mutat.
  Future<String?> resolveProfileImage(String athleteName) async {
    try {
      final result = await theSportsDb('/searchplayers.php', {
        'p': athleteName,
      });
      final players = result['player'];
      if (players is! List) return null;
      for (final entry in jsonMapList(players)) {
        final thumb = entry['strThumb'] ?? entry['strCutout'];
        if (thumb is String && thumb.startsWith('http')) return thumb;
      }
    } catch (_) {
      // Az automatikus képkeresés nem blokkolhatja a sportoló hozzáadását.
    }
    return null;
  }

  Future<Map<String, dynamic>?> findTheSportsDbPlayer(
    String athleteName,
  ) async {
    final result = await theSportsDb('/searchplayers.php', {'p': athleteName});
    return findTheSportsDbPlayerIn(result, athleteName);
  }

  /// A keresőtalálatok közül a névhez illő játékos; egyezés nélkül `null`,
  /// nem az első (esetleg teljesen más) találat.
  static Map<String, dynamic>? findTheSportsDbPlayerIn(
    Map<String, dynamic> result,
    String athleteName,
  ) {
    final players = result['player'];
    if (players is! List) return null;
    final match = findAthleteByName(
      jsonMapList(players),
      athleteName,
      (entry) => '${entry['strPlayer'] ?? ''}',
    );
    return match == null ? null : Map<String, dynamic>.from(match);
  }

  /// YouTube keresés: a playlistünk csak a returned videoId-kat menti el.
  /// A kulcs a query-ben utazik, de a [CourtboardHttpException] üzenete nem
  /// tartalmaz query-paramétert, így a kulcs hibaüzenetbe sem kerülhet.
  Future<List<Map<String, dynamic>>> searchYouTube(String query) async {
    if (config.youtubeKey.isEmpty) return const [];
    final uri = Uri.https('www.googleapis.com', '/youtube/v3/search', {
      'part': 'snippet',
      'type': 'video',
      'maxResults': '12',
      'q': query,
      'key': config.youtubeKey,
    });
    final result = await _get(uri, provider: 'YouTube Data API');
    final items = result['items'];
    return items is List
        ? items.whereType<Map<String, dynamic>>().toList()
        : const [];
  }

  /// Visszafelé kompatibilis no-op: a közös [HttpService] kliensét nem zárjuk
  /// le, mert más repository-k is használják.
  void close() {}
}

/// Egységes sportoló-modell, amelyből a UI később providerfüggetlenül dolgozhat.
class UnifiedAthleteRecord {
  const UnifiedAthleteRecord({
    required this.name,
    required this.sport,
    this.provider,
    this.externalId,
    this.imageUrl,
  });

  final String name;
  final String sport;
  final String? provider;
  final String? externalId;
  final String? imageUrl;
}
