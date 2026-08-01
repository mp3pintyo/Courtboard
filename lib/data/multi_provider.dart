import 'api_sports.dart';
import 'basketball_reference.dart';
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
  });

  final List<AthleteFact> facts;
  final List<DataProviderStatus> providers;
  final List<NbaGameLog> games;

  int get activeProviderCount =>
      providers.where((provider) => provider.hasData).length;
}

class MultiProviderAthleteRepository {
  MultiProviderAthleteRepository(this.config);

  final SportsApiConfig config;

  Future<UnifiedAthleteData> fetchNbaPlayer(String athleteName) async {
    final apiSports = _capture(
      'API-Sports',
      config.apiSportsKey.trim().isNotEmpty,
      () => ApiSportsRepository(config.apiSportsKey).nbaPlayer(athleteName),
    );
    final ballDontLie = _capture(
      'BALLDONTLIE',
      config.balldontlieKey.trim().isNotEmpty,
      () async {
        final client = SportsApiClient(config: config);
        try {
          final payload = await client.ballDontLieNba(
              '/v1/players', {'search': athleteName, 'per_page': '25'});
          return _findBallDontLiePlayer(payload, athleteName);
        } finally {
          client.close();
        }
      },
    );
    final sportsDb = _capture(
      'TheSportsDB',
      true,
      () async {
        final client = SportsApiClient(config: config);
        try {
          return await client.findTheSportsDbPlayer(athleteName);
        } finally {
          client.close();
        }
      },
    );
    final basketballReference = _capture(
      'Basketball Reference',
      true,
      () => BasketballReferenceRepository().recentGames(athleteName),
    );

    final results = await Future.wait(
        [apiSports, ballDontLie, sportsDb, basketballReference]);
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
      final team = bdlPlayer['team'] is Map
          ? Map<String, dynamic>.from(bdlPlayer['team'] as Map)
          : const <String, dynamic>{};
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

    return UnifiedAthleteData(
      facts: facts,
      providers: results.map((result) => result.status).toList(),
      games: results[3].data is List<NbaGameLog>
          ? results[3].data as List<NbaGameLog>
          : const [],
    );
  }

  static Map<String, dynamic>? _findBallDontLiePlayer(
      Map<String, dynamic> payload, String athleteName) {
    final data = payload['data'];
    if (data is! List) return null;
    final players = data
        .whereType<Map>()
        .map((player) => Map<String, dynamic>.from(player))
        .toList();
    if (players.isEmpty) return null;
    final wanted = normalizeAthleteName(athleteName);
    return players.cast<Map<String, dynamic>?>().firstWhere((player) {
      final name = '${player?['first_name'] ?? ''} '
          '${player?['last_name'] ?? ''}';
      return normalizeAthleteName(name) == wanted;
    }, orElse: () => players.first);
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
          message: '$error',
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
