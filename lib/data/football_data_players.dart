import 'athlete_names.dart';
import 'file_util.dart';
import 'football_names.dart';
import 'fotmob_football.dart';
import 'json_file_cache.dart';
import 'json_util.dart';
import 'sports_api.dart';

class FootballDataPlayerProfile {
  const FootballDataPlayerProfile({
    required this.id,
    required this.name,
    required this.teamId,
    required this.team,
    this.position,
    this.dateOfBirth,
    this.nationality,
    this.shirtNumber,
  });

  final int id;
  final String name;
  final int teamId;
  final String team;
  final String? position;
  final String? dateOfBirth;
  final String? nationality;
  final int? shirtNumber;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'teamId': teamId,
        'team': team,
        'position': position,
        'dateOfBirth': dateOfBirth,
        'nationality': nationality,
        'shirtNumber': shirtNumber,
      };

  static FootballDataPlayerProfile? tryFromJson(Object? raw) {
    final json = jsonMap(raw);
    final id = jsonIntOrNull(json['id']);
    final teamId = jsonIntOrNull(json['teamId']);
    if (id == null || teamId == null) return null;
    return FootballDataPlayerProfile(
      id: id,
      name: '${json['name'] ?? ''}',
      teamId: teamId,
      team: '${json['team'] ?? ''}',
      position: jsonString(json['position']),
      dateOfBirth: jsonString(json['dateOfBirth']),
      nationality: jsonString(json['nationality']),
      shirtNumber: jsonIntOrNull(json['shirtNumber']),
    );
  }
}

/// football-data.org játékosfeloldás a Free csomag csapatkereteiből.
///
/// Minden hívás lemezre kerül: a csapatlista és a keretek 7 napig, a
/// megtalált játékos 7 napig, a „nem található” eredmény 24 óráig (negatív
/// cache). A percenkénti 10 kéréses korlátot a közös [HttpService] tartja
/// be sorban állással, így egy hideg, teljes versenyszintű keresés is
/// legfeljebb egyszer tart kb. egy percig; utána gyorsítótárból fut.
class FootballDataPlayerRepository {
  FootballDataPlayerRepository(
    this._client, {
    CacheStorage? cacheStorage,
    this.cacheLifetime = const Duration(days: 7),
    this.missLifetime = const Duration(hours: 24),
    DateTime Function()? clock,
  }) : _cache = JsonFileCache(
          'football_data_players',
          storage: cacheStorage,
          clock: clock,
        );

  final SportsApiClient _client;
  final JsonFileCache _cache;
  final Duration cacheLifetime;

  /// A sikertelen keresés ennyi ideig nem ismétlődik.
  final Duration missLifetime;

  static const _competitionPriority = [
    'PL',
    'PD',
    'BL1',
    'SA',
    'FL1',
    'DED',
    'PPL',
    'ELC',
    'BSA',
    'CL',
    'EC',
    'WC',
  ];

  Future<FootballDataPlayerProfile?> findPlayer(
    String playerName,
    String teamName,
  ) async =>
      (await findPlayerCached(playerName, teamName)).value;

  /// A játékos profilja a letöltés idejével; a „nem található” eredmény is
  /// gyorsítótárba kerül [missLifetime] ideig.
  Future<CachedValue<FootballDataPlayerProfile?>> findPlayerCached(
    String playerName,
    String teamName, {
    bool forceRefresh = false,
  }) async {
    if (_client.config.footballDataKey.trim().isEmpty) {
      throw StateError('FOOTBALL_DATA_KEY nincs beállítva.');
    }
    return _cache.getOrFetch<FootballDataPlayerProfile?>(
      'player_${cacheSlug(teamName)}__${cacheSlug(playerName)}',
      ttl: cacheLifetime,
      missTtl: missLifetime,
      forceRefresh: forceRefresh,
      fetch: () => _resolve(playerName, teamName),
      encode: (value) => value?.toJson(),
      decode: FootballDataPlayerProfile.tryFromJson,
    );
  }

  Future<FootballDataPlayerProfile?> _resolve(
    String playerName,
    String teamName,
  ) async {
    final summaries = await _client.footballDataTeams();
    final teamId = parseTeamId(summaries, teamName);
    if (teamId != null) {
      final team = await _cachedJson(
        'team_$teamId',
        () => _client.footballData('/v4/teams/$teamId'),
      );
      return findInTeams([team], playerName, teamName);
    }

    final hint = await _fotMobCompetitionHint(playerName);
    if (hint.$1) {
      final code = hint.$2;
      if (code == null) return null;
      return findInTeams(
          await _competitionTeams(code), playerName, teamName);
    }

    final competitions = await _cachedJson(
      'competitions_tier_one',
      () => _client.footballData('/v4/competitions', {'plan': 'TIER_ONE'}),
    );
    for (final code in parseFreeCompetitionCodes(competitions)) {
      final found = findInTeams(
          await _competitionTeams(code), playerName, teamName);
      if (found != null) return found;
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> _competitionTeams(String code) async =>
      parseCompetitionTeams(await _cachedJson(
        'competition_teams_$code',
        () => _client.footballData('/v4/competitions/$code/teams'),
      ));

  Future<Map<String, dynamic>> _cachedJson(
    String key,
    Future<Map<String, dynamic>> Function() fetch,
  ) async =>
      (await _cache.getOrFetch<Map<String, dynamic>>(
        key,
        ttl: cacheLifetime,
        fetch: fetch,
        encode: (value) => value,
        decode: jsonMap,
      ))
          .value;

  static int? parseTeamId(Map<String, dynamic> payload, String teamName) {
    final teams = payload['teams'];
    if (teams is! List) return null;
    final expected = _normalizeTeam(teamName);
    for (final team in jsonMapList(teams)) {
      final names = [
        '${team['name'] ?? ''}',
        '${team['shortName'] ?? ''}',
        '${team['tla'] ?? ''}',
      ];
      if (names.any((name) => _normalizeTeam(name) == expected)) {
        return int.tryParse('${team['id'] ?? ''}');
      }
    }
    return null;
  }

  static List<String> parseFreeCompetitionCodes(Map<String, dynamic> payload) {
    final competitions = payload['competitions'];
    if (competitions is! List) return const [];
    final available = jsonMapList(competitions)
        .where((item) => '${item['plan'] ?? ''}' == 'TIER_ONE')
        .map((item) => '${item['code'] ?? ''}'.trim())
        .where((code) => code.isNotEmpty)
        .toSet();
    return [
      ..._competitionPriority.where(available.remove),
      ...available.toList()..sort(),
    ];
  }

  static String? competitionCode(String competitionName) {
    final normalized = normalizeAthleteName(
      competitionName,
    ).replaceAll(RegExp(r'[^a-z0-9]'), '');
    return const {
      'premierleague': 'PL',
      'laliga': 'PD',
      'primeradivision': 'PD',
      'bundesliga': 'BL1',
      'seriea': 'SA',
      'ligue1': 'FL1',
      'eredivisie': 'DED',
      'primeiraliga': 'PPL',
      'ligaportugal': 'PPL',
      'championship': 'ELC',
      'brasileiraoseriea': 'BSA',
      'campeonatobrasileiroseriea': 'BSA',
      'uefachampionsleague': 'CL',
      'championsleague': 'CL',
    }[normalized];
  }

  static List<Map<String, dynamic>> parseCompetitionTeams(
    Map<String, dynamic> payload,
  ) {
    final teams = payload['teams'];
    if (teams is! List) return const [];
    return jsonMapList(teams)
        .toList(growable: false);
  }

  static FootballDataPlayerProfile? findInTeams(
    Iterable<Map<String, dynamic>> teams,
    String playerName,
    String teamName,
  ) {
    final expectedTeam = _normalizeTeam(teamName);
    for (final team in teams) {
      final names = [
        '${team['name'] ?? ''}',
        '${team['shortName'] ?? ''}',
        '${team['tla'] ?? ''}',
      ];
      if (!names.any((name) => _normalizeTeam(name) == expectedTeam)) continue;
      final squad = team['squad'];
      if (squad is! List) return null;
      for (final player in jsonMapList(squad)) {
        final name = '${player['name'] ?? ''}'.trim();
        if (!athleteNamesMatch(name, normalizeAthleteName(playerName))) {
          continue;
        }
        final id = int.tryParse('${player['id'] ?? ''}');
        final teamId = int.tryParse('${team['id'] ?? ''}');
        if (id == null || teamId == null) return null;
        return FootballDataPlayerProfile(
          id: id,
          name: name,
          teamId: teamId,
          team: '${team['name'] ?? teamName}',
          position: jsonString(player['position']),
          dateOfBirth: jsonString(player['dateOfBirth']),
          nationality: jsonString(player['nationality']),
          shirtNumber: int.tryParse('${player['shirtNumber'] ?? ''}'),
        );
      }
      return null;
    }
    return null;
  }

  Future<(bool, String?)> _fotMobCompetitionHint(String playerName) async {
    final repository = FotMobFootballRepository(cacheStorage: _cache.storage);
    try {
      final summary = await repository.fetchSeasonSummary(playerName);
      if (summary == null) return (false, null);
      return (true, competitionCode(summary.competition));
    } catch (_) {
      return (false, null);
    } finally {
      repository.close();
    }
  }
}

String _normalizeTeam(String value) => normalizeFootballTeamName(value);
