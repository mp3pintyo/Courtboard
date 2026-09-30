import 'dart:io';

import 'api_sports.dart' show findAthleteByName;
import 'http_util.dart';

/// A kulcsokat környezeti változóból olvassuk, hogy ne kerüljenek bele a Flutter
/// forráskódjába. A desktop appból kikerülő kulcsok ettől még nem teljesen
/// védettek; később egy egyszemélyes backend proxy ajánlott.
class SportsApiConfig {
  const SportsApiConfig({
    this.apiSportsKey = '',
    this.balldontlieKey = '',
    this.footballDataKey = '',
    this.youtubeKey = '',
    this.rapidApiDartsKey = '',
    this.liveTennisKey = '',
  });

  factory SportsApiConfig.fromEnvironment() => SportsApiConfig(
        apiSportsKey: Platform.environment['API_SPORTS_KEY'] ?? '',
        balldontlieKey: Platform.environment['BALLDONTLIE_KEY'] ?? '',
        footballDataKey: Platform.environment['FOOTBALL_DATA_KEY'] ?? '',
        youtubeKey: Platform.environment['YOUTUBE_DATA_KEY'] ?? '',
        rapidApiDartsKey: Platform.environment['RAPIDAPI_DARTS_KEY'] ?? '',
        liveTennisKey: Platform.environment['LIVE_TENNIS_API_KEY'] ?? '',
      );

  final String apiSportsKey;
  final String balldontlieKey;
  final String footballDataKey;
  final String youtubeKey;
  final String rapidApiDartsKey;
  final String liveTennisKey;

  bool get hasAnyKey =>
      apiSportsKey.isNotEmpty ||
      balldontlieKey.isNotEmpty ||
      footballDataKey.isNotEmpty ||
      youtubeKey.isNotEmpty ||
      rapidApiDartsKey.isNotEmpty ||
      liveTennisKey.isNotEmpty;
}

class SportsApiClient {
  SportsApiClient({SportsApiConfig? config})
      : config = config ?? SportsApiConfig.fromEnvironment();

  final SportsApiConfig config;
  final HttpClient _http = createHttpClient();
  static const theSportsDbFreeKey = '123';

  /// Közös GET: 10 mp kapcsolódási és 20 mp teljes időkorláttal. A hibák
  /// [CourtboardHttpException]-ként érkeznek, query-paraméterek (és így
  /// URL-ben küldött kulcsok) nélkül.
  Future<Map<String, dynamic>> _get(
    Uri uri, {
    required String provider,
    Map<String, String> headers = const {},
  }) =>
      httpGetJson(_http, uri, provider: provider, headers: headers);

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
    return _get(uri,
        provider: 'API-Sports',
        headers: {'x-apisports-key': config.apiSportsKey});
  }

  /// NBA alapadatok a BALLDONTLIE hivatalos API-hostjáról.
  Future<Map<String, dynamic>> ballDontLieNba(String path,
      [Map<String, String> query = const {}]) {
    if (config.balldontlieKey.trim().isEmpty) {
      throw StateError('BALLDONTLIE_KEY nincs beállítva.');
    }
    final uri = Uri.https('api.balldontlie.io', path, query);
    return _get(uri,
        provider: 'BALLDONTLIE',
        headers: {'Authorization': config.balldontlieKey});
  }

  /// Foci: ingyenes top-versenyek, eredmények és tabellák.
  Future<Map<String, dynamic>> footballData(String path,
      [Map<String, String> query = const {}]) {
    if (config.footballDataKey.isEmpty) {
      throw StateError(
          'FOOTBALL_DATA_KEY nincs a futó alkalmazás környezetében.');
    }
    final uri = Uri.https('api.football-data.org', path, query);
    return _get(uri,
        provider: 'football-data.org',
        headers: {'X-Auth-Token': config.footballDataKey});
  }

  /// Profilok, csapatok és képek a nyilvános TheSportsDB Free v1 kulccsal.
  Future<Map<String, dynamic>> theSportsDb(String path,
      [Map<String, String> query = const {}]) {
    final uri = theSportsDbUri(path, query);
    return _get(uri, provider: 'TheSportsDB');
  }

  /// Sportbex Darts API a RapidAPI gatewayen keresztül. A jelenlegi API
  /// versenyeket, eseményeket, piacokat és oddsokat biztosít; játékosprofilt
  /// nem, ezért azt a TheSportsDB egészíti ki.
  Future<Map<String, dynamic>> rapidApiDarts(String path,
      [Map<String, String> query = const {}]) {
    if (config.rapidApiDartsKey.trim().isEmpty) {
      throw StateError('RAPIDAPI_DARTS_KEY nincs beállítva.');
    }
    final uri = Uri.https('darts-api.p.rapidapi.com', path, query);
    return _get(uri, provider: 'RapidAPI Darts', headers: {
      'X-RapidAPI-Key': config.rapidApiDartsKey,
      'X-RapidAPI-Host': 'darts-api.p.rapidapi.com',
    });
  }

  /// WNBA játékosadatok ugyanazzal a RapidAPI alkalmazáskulccsal. A Free
  /// csomag havi 100 hívása miatt a repository hosszú lemezes cache-t használ.
  Future<Map<String, dynamic>> rapidApiWnba(String path,
      [Map<String, String> query = const {}]) {
    if (config.rapidApiDartsKey.trim().isEmpty) {
      throw StateError('RapidAPI kulcs nincs beállítva.');
    }
    final uri = Uri.https('wnba-api.p.rapidapi.com', path, query);
    return _get(uri, provider: 'RapidAPI WNBA', headers: {
      'X-RapidAPI-Key': config.rapidApiDartsKey,
      'X-RapidAPI-Host': 'wnba-api.p.rapidapi.com',
    });
  }

  /// Live Tennis API Free végpontok. A kulcsot fejlécben küldjük, így nem
  /// kerül URL-be, előzményekbe vagy proxy-naplóba.
  Future<Map<String, dynamic>> liveTennis(String path,
      [Map<String, String> query = const {}]) {
    if (config.liveTennisKey.trim().isEmpty) {
      throw StateError('LIVE_TENNIS_API_KEY nincs beállítva.');
    }
    final uri =
        Uri.https('api.livetennisapi.com', '/api/public/v1$path', query);
    return _get(uri, provider: 'Live Tennis API', headers: {
      'Authorization': 'Bearer ${config.liveTennisKey.trim()}',
    });
  }

  /// ESPN liga-paraméteres labdarúgó scoreboard a [from]–[to] napok között
  /// (mindkettő beleértve). A Liga F kódja esp.w.1.
  Future<Map<String, dynamic>> espnSoccerScoreboard(
    String league, {
    required DateTime from,
    required DateTime to,
    int limit = 200,
  }) =>
      _get(espnScoreboardUri(league, from: from, to: to, limit: limit),
          provider: 'ESPN');

  static Uri espnScoreboardUri(
    String league, {
    required DateTime from,
    required DateTime to,
    int limit = 200,
  }) =>
      Uri.https(
          'site.api.espn.com', '/apis/site/v2/sports/soccer/$league/scoreboard', {
        'dates': '${espnDate(from)}-${espnDate(to)}',
        'limit': '$limit',
      });

  /// ESPN `YYYYMMDD` dátumformátum.
  static String espnDate(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}'
      '${value.month.toString().padLeft(2, '0')}'
      '${value.day.toString().padLeft(2, '0')}';

  static Uri theSportsDbUri(String path,
          [Map<String, String> query = const {}]) =>
      Uri.https('www.thesportsdb.com', '/api/v1/json/$theSportsDbFreeKey$path',
          query);

  /// Nyilvános TheSportsDB névfeloldás profilképhez. Nincs saját API-kulcs
  /// szükséges; hiba vagy nem találat esetén a hívó monogramos fallbacket mutat.
  Future<String?> resolveProfileImage(String athleteName) async {
    try {
      final result =
          await theSportsDb('/searchplayers.php', {'p': athleteName});
      final players = result['player'];
      if (players is! List) return null;
      for (final entry in players.whereType<Map>()) {
        final thumb = entry['strThumb'] ?? entry['strCutout'];
        if (thumb is String && thumb.startsWith('http')) return thumb;
      }
    } catch (_) {
      // Az automatikus képkeresés nem blokkolhatja a sportoló hozzáadását.
    }
    return null;
  }

  Future<Map<String, dynamic>?> findTheSportsDbPlayer(
      String athleteName) async {
    final result = await theSportsDb('/searchplayers.php', {'p': athleteName});
    return findTheSportsDbPlayerIn(result, athleteName);
  }

  /// A keresőtalálatok közül a névhez illő játékos; egyezés nélkül `null`,
  /// nem az első (esetleg teljesen más) találat.
  static Map<String, dynamic>? findTheSportsDbPlayerIn(
      Map<String, dynamic> result, String athleteName) {
    final players = result['player'];
    if (players is! List) return null;
    final match = findAthleteByName(players.whereType<Map>(), athleteName,
        (entry) => '${entry['strPlayer'] ?? ''}');
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

  void close() => _http.close(force: true);
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
