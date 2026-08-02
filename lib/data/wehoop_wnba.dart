import 'dart:convert';
import 'dart:io';

import 'api_sports.dart';

/// SportsDataverse / wehoop WNBA játékos-boxscore adapter.
///
/// A release-fájlok ESPN-alapú, CC BY 4.0 alatt közzétett CSV-k. A kiválasztott
/// szezon egyszer töltődik le, majd `%APPDATA%/courtboard/wnba_cache` alatt
/// marad, így a profil megnyitása később offline is működik.
class WnbaWehoopRepository {
  WnbaWehoopRepository({Directory? cacheDirectory, HttpClient? httpClient})
      : _cacheDirectory = cacheDirectory,
        _httpClient = httpClient ?? HttpClient();

  final Directory? _cacheDirectory;
  final HttpClient _httpClient;
  final Map<String, List<WnbaGameLog>> _memory = <String, List<WnbaGameLog>>{};

  static const _releaseBase =
      'https://github.com/sportsdataverse/sportsdataverse-data/releases/download/'
      'espn_wnba_player_boxscores';

  Future<List<WnbaGameLog>> recentGames(
    String athleteName, {
    int? season,
  }) async {
    final selectedSeason = season ?? DateTime.now().year;
    final key = '$selectedSeason:${_playerNameKey(athleteName)}';
    final inMemory = _memory[key];
    if (inMemory != null) return inMemory;

    final csv = await _readSeason(selectedSeason);
    final logs = parsePlayerGames(csv, athleteName);
    _memory[key] = logs;
    return logs;
  }

  Future<String> _readSeason(int season) async {
    final cacheFile = File('${(await _cache()).path}/player_box_$season.csv');
    if (await cacheFile.exists()) return cacheFile.readAsString();

    final url = '$_releaseBase/player_box_$season.csv';
    final request = await _httpClient.getUrl(Uri.parse(url));
    final response = await request.close();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('wehoop WNBA letöltési hiba: ${response.statusCode}',
          uri: Uri.parse(url));
    }
    final csv = await response.transform(utf8.decoder).join();
    await cacheFile.writeAsString(csv, flush: true);
    return csv;
  }

  Future<Directory> _cache() async {
    final directory = _cacheDirectory ??
        Directory(
            '${Platform.environment['APPDATA'] ?? Directory.current.path}/courtboard/wnba_cache');
    if (!await directory.exists()) await directory.create(recursive: true);
    return directory;
  }

  static List<WnbaGameLog> parsePlayerGames(String csv, String athleteName) {
    final lines = const LineSplitter()
        .convert(csv)
        .where((line) => line.isNotEmpty)
        .toList();
    if (lines.length < 2) return const [];
    final headers = _parseCsvLine(lines.first);
    final index = <String, int>{
      for (var i = 0; i < headers.length; i++) headers[i]: i
    };
    String field(List<String> values, String name) {
      final position = index[name];
      return position == null || position >= values.length
          ? ''
          : values[position];
    }

    final normalized = _playerNameKey(athleteName);
    final games = <WnbaGameLog>[];
    for (final line in lines.skip(1)) {
      final values = _parseCsvLine(line);
      if (_playerNameKey(field(values, 'athlete_display_name')) != normalized) {
        continue;
      }
      if (_asBool(field(values, 'did_not_play'))) continue;
      final date = DateTime.tryParse(field(values, 'game_date'));
      if (date == null) {
        continue;
      }
      games.add(WnbaGameLog(
        gameId: field(values, 'game_id'),
        athleteId: field(values, 'athlete_id'),
        date: date,
        team: field(values, 'team_display_name').isNotEmpty
            ? field(values, 'team_display_name')
            : field(values, 'team_name'),
        opponent: field(values, 'opponent_team_display_name').isNotEmpty
            ? field(values, 'opponent_team_display_name')
            : field(values, 'opponent_team_name'),
        teamScore: _asInt(field(values, 'team_score')),
        opponentScore: _asInt(field(values, 'opponent_team_score')),
        result: WnbaResult.fromProvider(field(values, 'team_winner').isNotEmpty
            ? field(values, 'team_winner')
            : field(values, 'team_result')),
        points: _asInt(field(values, 'points')),
        rebounds: _asInt(field(values, 'rebounds')),
        assists: _asInt(field(values, 'assists')),
        steals: _asInt(field(values, 'steals')),
        blocks: _asInt(field(values, 'blocks')),
        turnovers: _asInt(field(values, 'turnovers')),
        fieldGoalsMade: _asInt(field(values, 'field_goals_made')),
        fieldGoalsAttempted: _asInt(field(values, 'field_goals_attempted')),
        minutes: _asDouble(field(values, 'minutes')),
        headshotUrl: field(values, 'athlete_headshot_href'),
        seasonType: field(values, 'season_type'),
      ));
    }
    games.sort((a, b) => b.date.compareTo(a.date));
    return games;
  }

  static int _asInt(String value) => int.tryParse(value) ?? 0;
  static double _asDouble(String value) => double.tryParse(value) ?? 0;
  static bool _asBool(String value) =>
      const {'true', '1', 'yes'}.contains(value.trim().toLowerCase());

  static List<String> _parseCsvLine(String line) {
    final fields = <String>[];
    final current = StringBuffer();
    var quoted = false;
    for (var i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        if (quoted && i + 1 < line.length && line[i + 1] == '"') {
          current.write('"');
          i++;
        } else {
          quoted = !quoted;
        }
      } else if (char == ',' && !quoted) {
        fields.add(current.toString());
        current.clear();
      } else {
        current.write(char);
      }
    }
    fields.add(current.toString());
    return fields;
  }

  void close() => _httpClient.close(force: true);
}

/// Ékezet-, írásjel- és névsorrend-független kulcs ESPN/wehoop nevekhez.
/// A teljes tokenhalmaznak egyeznie kell, így résznév nem találhat más játékost.
String _playerNameKey(String value) {
  final tokens = normalizeAthleteName(value)
      .split(' ')
      .where((token) => token.isNotEmpty)
      .toList()
    ..sort();
  return tokens.join('|');
}

class WnbaSeasonSummary {
  const WnbaSeasonSummary({
    required this.games,
    required this.pointsPerGame,
    required this.reboundsPerGame,
    required this.assistsPerGame,
    required this.minutesPerGame,
    required this.stealsPerGame,
    required this.turnoversPerGame,
    this.fieldGoalPercentage,
  });

  final int games;
  final double pointsPerGame;
  final double reboundsPerGame;
  final double assistsPerGame;
  final double minutesPerGame;
  final double stealsPerGame;
  final double turnoversPerGame;
  final double? fieldGoalPercentage;

  factory WnbaSeasonSummary.fromGames(List<WnbaGameLog> games) {
    if (games.isEmpty) {
      return const WnbaSeasonSummary(
        games: 0,
        pointsPerGame: 0,
        reboundsPerGame: 0,
        assistsPerGame: 0,
        minutesPerGame: 0,
        stealsPerGame: 0,
        turnoversPerGame: 0,
      );
    }
    final regularSeason = games
        .where((game) => game.seasonType.isEmpty || game.seasonType == '2')
        .toList();
    final selected = regularSeason.isEmpty ? games : regularSeason;
    double average(num Function(WnbaGameLog game) selector) =>
        selected.map(selector).reduce((a, b) => a + b) / selected.length;
    final made =
        selected.fold<int>(0, (total, game) => total + game.fieldGoalsMade);
    final attempted = selected.fold<int>(
        0, (total, game) => total + game.fieldGoalsAttempted);
    return WnbaSeasonSummary(
      games: selected.length,
      pointsPerGame: average((game) => game.points),
      reboundsPerGame: average((game) => game.rebounds),
      assistsPerGame: average((game) => game.assists),
      minutesPerGame: average((game) => game.minutes),
      stealsPerGame: average((game) => game.steals),
      turnoversPerGame: average((game) => game.turnovers),
      fieldGoalPercentage: attempted == 0 ? null : made / attempted * 100,
    );
  }
}

enum WnbaResult {
  win,
  loss,
  unknown;

  static WnbaResult fromProvider(String value) =>
      switch (value.trim().toUpperCase()) {
        'WIN' || 'W' || 'TRUE' => WnbaResult.win,
        'LOSS' || 'L' || 'FALSE' => WnbaResult.loss,
        _ => WnbaResult.unknown,
      };
}

class WnbaGameLog {
  const WnbaGameLog({
    required this.gameId,
    this.athleteId = '',
    required this.date,
    required this.team,
    required this.opponent,
    this.teamScore = 0,
    this.opponentScore = 0,
    this.result = WnbaResult.unknown,
    required this.points,
    required this.rebounds,
    required this.assists,
    required this.steals,
    required this.blocks,
    required this.minutes,
    required this.headshotUrl,
    this.turnovers = 0,
    this.fieldGoalsMade = 0,
    this.fieldGoalsAttempted = 0,
    this.seasonType = '',
  });

  final String gameId;
  final String athleteId;
  final DateTime date;
  final String team;
  final String opponent;
  final int teamScore;
  final int opponentScore;
  final WnbaResult result;
  String get score => '$teamScore–$opponentScore';
  final int points;
  final int rebounds;
  final int assists;
  final int steals;
  final int blocks;
  final double minutes;
  final String headshotUrl;
  final int turnovers;
  final int fieldGoalsMade;
  final int fieldGoalsAttempted;
  final String seasonType;
}
