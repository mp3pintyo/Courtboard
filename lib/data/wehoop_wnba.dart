import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'api_sports.dart';
import 'file_util.dart';
import 'http_util.dart';

/// Tesztelhető letöltő: a CSV szövegét adja vissza, vagy
/// [CourtboardHttpException]-t dob (404 = a szezonfájl még nem létezik).
typedef WnbaCsvFetcher = Future<String> Function(Uri uri);

/// SportsDataverse / wehoop WNBA játékos-boxscore adapter.
///
/// A release-fájlok ESPN-alapú, CC BY 4.0 alatt közzétett CSV-k. A szezonfájl
/// `%APPDATA%/courtboard/wnba_cache` alá kerül: a lezárt szezonok végleg, a
/// folyó szezon [currentSeasonLifetime] ideig érvényes. Hálózati hiba esetén a
/// régebbi, lemezen lévő példányt használjuk. A feldolgozott szezonok
/// memóriában is megmaradnak (példányok között megosztva), így a CSV-t
/// szezononként csak egyszer kell feldolgozni.
class WnbaWehoopRepository {
  WnbaWehoopRepository({
    this._cacheDirectory,
    this._httpClient,
    this._fetchCsv,
  });

  /// Közös példány, hogy a hívók ne töltsék le és dolgozzák fel újra a CSV-t.
  static final WnbaWehoopRepository shared = WnbaWehoopRepository();

  final Directory? _cacheDirectory;
  final HttpClient? _httpClient;
  final WnbaCsvFetcher? _fetchCsv;

  /// A folyó szezon CSV-jének érvényessége; a korábbi szezonoké korlátlan.
  static const currentSeasonLifetime = Duration(hours: 12);
  static const _missingSeasonLifetime = Duration(hours: 1);
  static const _downloadTimeout = Duration(seconds: 60);

  static final Map<String, _WnbaSeasonIndex> _seasons = {};
  static final Map<String, Future<_WnbaSeasonIndex>> _loading = {};

  static const _releaseBase =
      'https://github.com/sportsdataverse/sportsdataverse-data/releases/download/'
      'espn_wnba_player_boxscores';

  /// A játékos meccsei a megadott [season]-ből, legújabb elöl.
  ///
  /// Szezon nélkül a [now] szerinti naptári év az alapértelmezés; ha annak
  /// fájlja még nem létezik (január–május, holtszezon), üres, vagy a játékos
  /// nem szerepel benne, az előző szezon adatait adja.
  Future<List<WnbaGameLog>> recentGames(
    String athleteName, {
    int? season,
    DateTime? now,
  }) async {
    final clock = now ?? DateTime.now();
    final key = _playerNameKey(athleteName);
    if (season != null) {
      return (await _season(season, clock)).games[key] ?? const [];
    }

    Object? currentError;
    StackTrace? currentStack;
    try {
      final current = await _season(clock.year, clock);
      final games = current.games[key];
      if (games != null && games.isNotEmpty) return games;
    } catch (error, stack) {
      currentError = error;
      currentStack = stack;
    }
    try {
      final previous = await _season(clock.year - 1, clock);
      final games = previous.games[key] ?? const <WnbaGameLog>[];
      if (games.isNotEmpty || currentError == null) return games;
    } catch (_) {
      // Az aktuális szezon rendben volt, csak a játékos nem szerepelt benne:
      // az előző szezon hibája nem teszi hibássá a (üres) eredményt.
      if (currentError == null) return const [];
    }
    Error.throwWithStackTrace(currentError, currentStack!);
  }

  Future<_WnbaSeasonIndex> _season(int season, DateTime clock) async {
    final directory = await _cache();
    final memoryKey = '${directory.path}|$season';
    final isCurrent = season >= clock.year;
    final cached = _seasons[memoryKey];
    if (cached != null) {
      final lifetime =
          cached.missing ? _missingSeasonLifetime : currentSeasonLifetime;
      if ((!isCurrent && !cached.missing) ||
          DateTime.now().difference(cached.loadedAt) < lifetime) {
        return cached;
      }
    }
    final pending = _loading[memoryKey];
    if (pending != null) return pending;
    final future = _loadSeason(directory, season, isCurrent).then((index) {
      _seasons[memoryKey] = index;
      return index;
    }).whenComplete(() {
      _loading.remove(memoryKey);
    });
    _loading[memoryKey] = future;
    return future;
  }

  Future<_WnbaSeasonIndex> _loadSeason(
    Directory directory,
    int season,
    bool isCurrent,
  ) async {
    final cacheFile = File('${directory.path}/player_box_$season.csv');
    final hasCache = await cacheFile.exists();
    if (hasCache) {
      final modified = await cacheFile.lastModified();
      final age = DateTime.now().difference(modified);
      if (!isCurrent || (!age.isNegative && age < currentSeasonLifetime)) {
        // A memóriabeli élettartam a lemezes példány korától számít.
        return _index(await cacheFile.readAsString(), loadedAt: modified);
      }
    }

    final String csv;
    try {
      csv = await _download(Uri.parse('$_releaseBase/player_box_$season.csv'));
    } catch (error) {
      // Hálózati vagy szerverhiba: a régebbi lemezes példány is jobb a semminél.
      // Egy óra múlva újrapróbáljuk a letöltést.
      if (hasCache) {
        return _index(await cacheFile.readAsString(),
            loadedAt: DateTime.now()
                .subtract(currentSeasonLifetime - _missingSeasonLifetime));
      }
      if (error is CourtboardHttpException && error.isNotFound) {
        return _WnbaSeasonIndex.missing();
      }
      rethrow;
    }
    await writeFileAtomic(cacheFile, csv);
    return _index(csv);
  }

  static Future<_WnbaSeasonIndex> _index(String csv, {DateTime? loadedAt}) async {
    // A több MB-os CSV feldolgozása ne akassza meg a UI szálat.
    final games = await Isolate.run(() => parseSeasonIndex(csv));
    return _WnbaSeasonIndex(games, loadedAt ?? DateTime.now());
  }

  Future<String> _download(Uri uri) async {
    final fetch = _fetchCsv;
    if (fetch != null) return fetch(uri);
    final client = _httpClient ?? createHttpClient();
    try {
      return await httpGetText(client, uri,
          provider: 'wehoop WNBA', timeout: _downloadTimeout);
    } finally {
      if (_httpClient == null) client.close(force: true);
    }
  }

  Future<Directory> _cache() async {
    final directory = _cacheDirectory ??
        Directory('${appDataPath()}/courtboard/wnba_cache');
    if (!await directory.exists()) await directory.create(recursive: true);
    return directory;
  }

  /// Egy játékos meccsei a CSV-ből, legújabb elöl.
  static List<WnbaGameLog> parsePlayerGames(String csv, String athleteName) =>
      parseSeasonIndex(csv)[_playerNameKey(athleteName)] ?? const [];

  /// A teljes szezon-CSV játékoskulcs szerint csoportosítva, meccsenként
  /// legújabb elöl. Tiszta függvény, így `Isolate.run`-ban is futtatható.
  static Map<String, List<WnbaGameLog>> parseSeasonIndex(String csv) {
    final lines = const LineSplitter()
        .convert(csv)
        .where((line) => line.isNotEmpty)
        .toList();
    if (lines.length < 2) return const {};
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

    final byPlayer = <String, List<WnbaGameLog>>{};
    for (final line in lines.skip(1)) {
      final values = _parseCsvLine(line);
      final playerKey = _playerNameKey(field(values, 'athlete_display_name'));
      if (playerKey.isEmpty) continue;
      if (_asBool(field(values, 'did_not_play'))) continue;
      final date = DateTime.tryParse(field(values, 'game_date'));
      if (date == null) {
        continue;
      }
      (byPlayer[playerKey] ??= <WnbaGameLog>[]).add(WnbaGameLog(
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
    for (final games in byPlayer.values) {
      games.sort((a, b) => b.date.compareTo(a.date));
    }
    return byPlayer;
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

  /// Csak a konstruktorban átadott, hosszú életű klienst zárja le.
  void close() => _httpClient?.close(force: true);
}

class _WnbaSeasonIndex {
  const _WnbaSeasonIndex(this.games, this.loadedAt) : missing = false;
  _WnbaSeasonIndex.missing()
      : games = const {},
        loadedAt = DateTime.now(),
        missing = true;

  final Map<String, List<WnbaGameLog>> games;
  final DateTime loadedAt;

  /// A szezonfájl a forrásnál még nem létezik (404).
  final bool missing;
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
