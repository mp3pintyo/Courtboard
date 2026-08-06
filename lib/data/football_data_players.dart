import 'dart:convert';
import 'dart:io';

import 'api_sports.dart' show athleteNamesMatch, normalizeAthleteName;
import 'fotmob_football.dart';
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
}

class FootballDataPlayerRepository {
  FootballDataPlayerRepository(
    this._client, {
    File? cacheFile,
    this.cacheLifetime = const Duration(days: 7),
    this.rateLimitReset = const Duration(seconds: 61),
  }) : _cacheFile = cacheFile ?? _defaultCacheFile();

  final SportsApiClient _client;
  final File _cacheFile;
  final Duration cacheLifetime;
  final Duration rateLimitReset;

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
  ) async {
    if (_client.config.footballDataKey.trim().isEmpty) {
      throw StateError('FOOTBALL_DATA_KEY nincs beállítva.');
    }

    final fresh = await _readCache(freshOnly: true);
    final cached = findInTeams(fresh, playerName, teamName);
    if (cached != null) return cached;
    final stale = await _readCache(freshOnly: false);

    try {
      final summaries = await _client.footballData('/v4/teams', {
        'limit': '500',
      });
      final teamId = parseTeamId(summaries, teamName);
      if (teamId != null) {
        final team = await _client.footballData('/v4/teams/$teamId');
        final teams = _mergeTeams(stale, [team]);
        await _writeCache(teams);
        return findInTeams(teams, playerName, teamName);
      }

      final hint = await _fotMobCompetitionHint(playerName);
      if (hint.$1) {
        final code = hint.$2;
        if (code == null) return null;
        final payload = await _client.footballData(
          '/v4/competitions/$code/teams',
        );
        final teams = _mergeTeams(stale, parseCompetitionTeams(payload));
        await _writeCache(teams);
        return findInTeams(teams, playerName, teamName);
      }

      final competitions = await _client.footballData('/v4/competitions', {
        'plan': 'TIER_ONE',
      });
      final codes = parseFreeCompetitionCodes(competitions);
      var teams = [...stale];
      for (var start = 0; start < codes.length; start += 8) {
        if (start > 0) await Future<void>.delayed(rateLimitReset);
        final batch = codes.skip(start).take(8);
        final payloads = await Future.wait(
          batch.map(
            (code) => _client.footballData('/v4/competitions/$code/teams'),
          ),
        );
        teams = _mergeTeams(teams, payloads.expand(parseCompetitionTeams));
        await _writeCache(teams);
        final found = findInTeams(teams, playerName, teamName);
        if (found != null) return found;
      }
    } catch (_) {
      final fallback = findInTeams(stale, playerName, teamName);
      if (fallback != null) return fallback;
      rethrow;
    }
    return null;
  }

  static int? parseTeamId(Map<String, dynamic> payload, String teamName) {
    final teams = payload['teams'];
    if (teams is! List) return null;
    final expected = _normalizeTeam(teamName);
    for (final team in teams.whereType<Map>()) {
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
    final available = competitions
        .whereType<Map>()
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
    return teams
        .whereType<Map>()
        .map((team) => Map<String, dynamic>.from(team))
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
      for (final player in squad.whereType<Map>()) {
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
          position: _nonEmpty(player['position']),
          dateOfBirth: _nonEmpty(player['dateOfBirth']),
          nationality: _nonEmpty(player['nationality']),
          shirtNumber: int.tryParse('${player['shirtNumber'] ?? ''}'),
        );
      }
      return null;
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> _readCache({
    required bool freshOnly,
  }) async {
    try {
      if (!await _cacheFile.exists()) return const [];
      if (freshOnly) {
        final age = DateTime.now().difference(await _cacheFile.lastModified());
        if (age.isNegative || age > cacheLifetime) return const [];
      }
      final decoded = jsonDecode(await _cacheFile.readAsString());
      final teams = decoded is Map ? decoded['teams'] : null;
      if (teams is! List) return const [];
      return teams
          .whereType<Map>()
          .map((team) => Map<String, dynamic>.from(team))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _writeCache(List<Map<String, dynamic>> teams) async {
    await _cacheFile.parent.create(recursive: true);
    await _cacheFile.writeAsString(
      jsonEncode({
        'savedAt': DateTime.now().toUtc().toIso8601String(),
        'teams': teams,
      }),
    );
  }

  Future<(bool, String?)> _fotMobCompetitionHint(String playerName) async {
    final repository = FotMobFootballRepository();
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

  static List<Map<String, dynamic>> _mergeTeams(
    Iterable<Map<String, dynamic>> existing,
    Iterable<Map<String, dynamic>> incoming,
  ) {
    final byId = <String, Map<String, dynamic>>{};
    for (final team in [...existing, ...incoming]) {
      final id = '${team['id'] ?? ''}';
      if (id.isNotEmpty) byId[id] = Map<String, dynamic>.from(team);
    }
    return byId.values.toList(growable: false);
  }

  static File _defaultCacheFile() {
    final root = Platform.environment['APPDATA'] ?? Directory.current.path;
    return File('$root/courtboard_cache/football_data/free_players.json');
  }
}

String _normalizeTeam(String value) => normalizeAthleteName(value)
    .split(' ')
    .where((part) => !const {'fc', 'cf', 'afc', 'sc', 'ac'}.contains(part))
    .join('')
    .replaceAll(RegExp(r'[^a-z0-9]'), '');

String? _nonEmpty(dynamic value) {
  final text = '${value ?? ''}'.trim();
  return text.isEmpty ? null : text;
}
