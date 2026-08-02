import 'dart:convert';
import 'dart:io';

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
  final HttpClient _http = HttpClient();
  static const theSportsDbFreeKey = '123';

  Future<Map<String, dynamic>> _get(
    String url, {
    Map<String, String> headers = const {},
  }) async {
    final request = await _http.getUrl(Uri.parse(url));
    headers.forEach(request.headers.set);
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('API hiba: ${response.statusCode}',
          uri: Uri.parse(url));
    }
    final decoded = jsonDecode(body);
    return decoded is Map<String, dynamic>
        ? decoded
        : <String, dynamic>{'data': decoded};
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
    return _get(uri.toString(),
        headers: {'x-apisports-key': config.apiSportsKey});
  }

  /// NBA alapadatok a BALLDONTLIE hivatalos API-hostjáról.
  Future<Map<String, dynamic>> ballDontLieNba(String path,
      [Map<String, String> query = const {}]) {
    if (config.balldontlieKey.trim().isEmpty) {
      throw StateError('BALLDONTLIE_KEY nincs beállítva.');
    }
    final uri = Uri.https('api.balldontlie.io', path, query);
    return _get(uri.toString(),
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
    return _get(uri.toString(),
        headers: {'X-Auth-Token': config.footballDataKey});
  }

  /// Profilok, csapatok és képek a nyilvános TheSportsDB Free v1 kulccsal.
  Future<Map<String, dynamic>> theSportsDb(String path,
      [Map<String, String> query = const {}]) {
    final uri = theSportsDbUri(path, query);
    return _get(uri.toString());
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
    return _get(uri.toString(), headers: {
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
    return _get(uri.toString(), headers: {
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
    return _get(uri.toString(), headers: {
      'Authorization': 'Bearer ${config.liveTennisKey.trim()}',
    });
  }

  /// ESPN liga-paraméteres labdarúgó scoreboard. A Liga F kódja esp.w.1.
  Future<Map<String, dynamic>> espnSoccerScoreboard(String league, int year) {
    final uri = Uri.https(
        'site.api.espn.com',
        '/apis/site/v2/sports/soccer/$league/scoreboard',
        {'dates': '$year', 'limit': '100'});
    return _get(uri.toString());
  }

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
    final players = result['player'];
    if (players is! List || players.isEmpty) return null;
    final normalized = _normalizeName(athleteName);
    final entries = players.whereType<Map>().toList();
    final match = entries.cast<Map?>().firstWhere(
        (entry) => _normalizeName('${entry?['strPlayer'] ?? ''}') == normalized,
        orElse: () => entries.first);
    return match == null ? null : Map<String, dynamic>.from(match);
  }

  /// YouTube keresés: a playlistünk csak a returned videoId-kat menti el.
  Future<List<Map<String, dynamic>>> searchYouTube(String query) async {
    if (config.youtubeKey.isEmpty) return const [];
    final uri = Uri.https('www.googleapis.com', '/youtube/v3/search', {
      'part': 'snippet',
      'type': 'video',
      'maxResults': '12',
      'q': query,
      'key': config.youtubeKey,
    });
    final result = await _get(uri.toString());
    final items = result['items'];
    return items is List
        ? items.whereType<Map<String, dynamic>>().toList()
        : const [];
  }

  void close() => _http.close(force: true);
}

String _normalizeName(String value) => value
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9áéíóöőúüűčćšž ]'), '')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

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
