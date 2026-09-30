import 'api_sports.dart';
import 'basketball_reference.dart';
import 'basketball_season.dart';
import 'espn_athletes.dart';
import 'espn_schedule.dart';
import 'friendly_error.dart';
import 'http_service.dart';
import 'json_file_cache.dart';
import 'json_util.dart';
import 'sports_api.dart';

class AthleteFact {
  const AthleteFact(
      {required this.label, required this.value, required this.source});

  final String label;
  final String value;
  final String source;
}

class DataProviderStatus {
  const DataProviderStatus({
    required this.name,
    required this.configured,
    required this.hasData,
    this.message,
  });

  final String name;
  final bool configured;
  final bool hasData;
  final String? message;
}

class UnifiedAthleteData {
  const UnifiedAthleteData({
    required this.facts,
    required this.providers,
    this.games = const [],
    this.gamesSource = 'Basketball Reference',
    this.espnSeason,
  });

  final List<AthleteFact> facts;
  final List<DataProviderStatus> providers;
  final List<NbaGameLog> games;

  /// A meccsnapló forrása (`Basketball Reference`, vagy tartalékként `ESPN`).
  final String gamesSource;

  /// Az ESPN meccsnaplójából számolt alapszakasz-összesítő (tartalék a
  /// Basketball Reference szezonösszesítője mellé).
  final BasketballSeasonStat? espnSeason;

  int get activeProviderCount =>
      providers.where((provider) => provider.hasData).length;
}

class MultiProviderAthleteRepository {
  MultiProviderAthleteRepository(this.config, {this._http, this._cacheStorage});

  final SportsApiConfig config;
  final HttpService? _http;
  final CacheStorage? _cacheStorage;

  Future<UnifiedAthleteData> fetchNbaPlayer(String athleteName) async {
    final client = SportsApiClient(
        config: config, http: _http, cacheStorage: _cacheStorage);
    final apiSports = _capture(
      'API-Sports',
      config.apiSportsKey.trim().isNotEmpty,
      () => ApiSportsRepository(config.apiSportsKey,
              http: _http, cacheStorage: _cacheStorage)
          .nbaPlayer(athleteName),
    );
    // A BALLDONTLIE-keresés 12, a TheSportsDB-keresés 24 órás gyorsítótárból
    // jön, így a profil újranyitása nem fogyasztja a percenkénti keretet.
    final ballDontLie = _capture(
      'BALLDONTLIE',
      config.balldontlieKey.trim().isNotEmpty,
      () async {
        final payload = await client.ballDontLieNba(
            '/v1/players', {'search': athleteName, 'per_page': '25'});
        return _findBallDontLiePlayer(payload, athleteName);
      },
    );
    final sportsDb = _capture(
      'TheSportsDB',
      true,
      () => client.findTheSportsDbPlayer(athleteName),
    );
    final basketballReference = _capture(
      'Basketball Reference',
      true,
      () => BasketballReferenceRepository(
              http: _http, cacheStorage: _cacheStorage)
          .recentGames(athleteName),
    );

    // Kulcs nélküli kiegészítő és tartalékforrás: ha a Basketball Reference
    // nem ad meccsnaplót, az ESPN-é látszik (6 órás gyorsítótár).
    final espn = _capture(
      'ESPN',
      true,
      () => EspnAthleteRepository(http: _http, cacheStorage: _cacheStorage)
          .gameLog(athleteName, EspnLeague.nba),
    );

    final results = await Future.wait(
        [apiSports, ballDontLie, sportsDb, basketballReference, espn]);
    final facts = <AthleteFact>[];
    final seenLabels = <String>{};

    void add(String label, dynamic value, String source) {
      final text = '${value ?? ''}'.trim();
      if (text.isEmpty || text == 'null' || seenLabels.contains(label)) return;
      seenLabels.add(label);
      facts.add(AthleteFact(label: label, value: text, source: source));
    }

    final apiPlayer = results[0].data;
    if (apiPlayer is ApiSportsPlayer) {
      add('Név', apiPlayer.name, 'API-Sports');
      add('Poszt', apiPlayer.position, 'API-Sports');
      add('Mezszám', apiPlayer.jersey, 'API-Sports');
      add('Magasság', apiPlayer.height, 'API-Sports');
      add('Súly', apiPlayer.weight, 'API-Sports');
      add('Születési dátum', apiPlayer.birthDate, 'API-Sports');
      add('Ország', apiPlayer.country, 'API-Sports');
      add('Egyetem', apiPlayer.college, 'API-Sports');
      if (apiPlayer.active != null) {
        add('Státusz', apiPlayer.active! ? 'Aktív' : 'Inaktív', 'API-Sports');
      }
    }

    final bdlPlayer = results[1].data;
    if (bdlPlayer is Map<String, dynamic>) {
      final team = jsonMap(bdlPlayer['team']);
      add(
          'Név',
          '${bdlPlayer['first_name'] ?? ''} ${bdlPlayer['last_name'] ?? ''}',
          'BALLDONTLIE');
      add('Csapat', team['full_name'], 'BALLDONTLIE');
      add('Poszt', bdlPlayer['position'], 'BALLDONTLIE');
      add('Mezszám', bdlPlayer['jersey_number'], 'BALLDONTLIE');
      add('Magasság', bdlPlayer['height'], 'BALLDONTLIE');
      add(
          'Súly',
          bdlPlayer['weight'] == null ? null : '${bdlPlayer['weight']} lb',
          'BALLDONTLIE');
      add('Ország', bdlPlayer['country'], 'BALLDONTLIE');
      add('Egyetem', bdlPlayer['college'], 'BALLDONTLIE');
      add('Draft', _draftLabel(bdlPlayer), 'BALLDONTLIE');
    }

    final sportsDbPlayer = results[2].data;
    if (sportsDbPlayer is Map<String, dynamic>) {
      add('Név', sportsDbPlayer['strPlayer'], 'TheSportsDB');
      add('Csapat', sportsDbPlayer['strTeam'], 'TheSportsDB');
      add('Poszt', sportsDbPlayer['strPosition'], 'TheSportsDB');
      add('Születési dátum', sportsDbPlayer['dateBorn'], 'TheSportsDB');
      add('Ország', sportsDbPlayer['strNationality'], 'TheSportsDB');
    }

    final espnLog = results[4].data;
    if (espnLog is EspnGameLog) {
      add('Név', espnLog.athlete.displayName, 'ESPN');
      add('Csapat', espnLog.athlete.team, 'ESPN');
      add('Poszt', espnLog.athlete.position, 'ESPN');
      add('Mezszám', espnLog.athlete.jersey, 'ESPN');
    }

    final referenceGames = results[3].data is List<NbaGameLog>
        ? results[3].data as List<NbaGameLog>
        : const <NbaGameLog>[];
    final espnGames = espnLog is EspnGameLog
        ? espnLog.toNbaGameLogs(limit: 10)
        : const <NbaGameLog>[];
    final useEspn = referenceGames.isEmpty && espnGames.isNotEmpty;
    final providers = [
      for (final (index, result) in results.indexed)
        if (index == 4 && result.status.hasData)
          DataProviderStatus(
            name: 'ESPN',
            configured: true,
            hasData: true,
            message: useEspn
                ? 'Tartalék: az ESPN meccsnaplója látszik'
                : 'Kiegészítő profiladat és szezonátlag',
          )
        else
          result.status,
    ];
    return UnifiedAthleteData(
      facts: facts,
      providers: providers,
      games: useEspn ? espnGames : referenceGames,
      gamesSource: useEspn ? 'ESPN' : 'Basketball Reference',
      espnSeason: espnLog is EspnGameLog
          ? espnLog.toBasketballSeasonStat()
          : null,
    );
  }

  static Map<String, dynamic>? _findBallDontLiePlayer(
      Map<String, dynamic> payload, String athleteName) {
    final data = payload['data'];
    if (data is! List) return null;
    final players = jsonMapList(data)
        .toList();
    return findAthleteByName(
        players,
        athleteName,
        (player) => '${player['first_name'] ?? ''} '
            '${player['last_name'] ?? ''}');
  }

  static String? _draftLabel(Map<String, dynamic> player) {
    final year = player['draft_year'];
    if (year == null) return null;
    final round = player['draft_round'];
    final number = player['draft_number'];
    return [
      '$year',
      if (round != null) '$round. kör',
      if (number != null) '$number. választás',
    ].join(' · ');
  }

  Future<_CapturedResult> _capture(
    String provider,
    bool configured,
    Future<dynamic> Function() load,
  ) async {
    if (!configured) {
      return _CapturedResult(
        status: DataProviderStatus(
          name: provider,
          configured: false,
          hasData: false,
          message: 'Nincs API-kulcs',
        ),
      );
    }
    try {
      final data = await load();
      final hasData = data != null && (data is! List || data.isNotEmpty);
      return _CapturedResult(
        data: data,
        status: DataProviderStatus(
          name: provider,
          configured: true,
          hasData: hasData,
          message: hasData ? null : 'Nincs találat',
        ),
      );
    } catch (error) {
      return _CapturedResult(
        status: DataProviderStatus(
          name: provider,
          configured: true,
          hasData: false,
          message: friendlyError(error),
        ),
      );
    }
  }
}

class _CapturedResult {
  const _CapturedResult({required this.status, this.data});

  final DataProviderStatus status;
  final dynamic data;
}
