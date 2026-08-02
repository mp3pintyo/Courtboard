import 'dart:convert';
import 'dart:io';

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import 'api_sports.dart';
import 'basketball_season.dart';

typedef BasketballReferenceHtmlFetcher = Future<String> Function(Uri uri);

class NbaGameLog {
  const NbaGameLog({
    required this.date,
    required this.opponent,
    required this.outcome,
    required this.location,
    required this.minutes,
    required this.points,
    required this.rebounds,
    required this.assists,
    required this.steals,
    required this.blocks,
    this.turnovers = 0,
    this.fieldGoalsMade = 0,
    this.fieldGoalsAttempted = 0,
    this.plusMinus,
    this.gameScore,
    this.score,
  });

  final DateTime date;
  final String opponent;
  final String outcome;
  final String location;
  final double minutes;
  final int points;
  final int rebounds;
  final int assists;
  final int steals;
  final int blocks;
  final int turnovers;
  final int fieldGoalsMade;
  final int fieldGoalsAttempted;
  final int? plusMinus;
  final double? gameScore;
  final String? score;

  String get resultLabel => outcome == 'WIN' ? 'GYŐZELEM' : 'VERESÉG';

  String get performance =>
      '$points PTS · $rebounds REB · $assists AST · ${minutes.toStringAsFixed(0)} MIN';

  String get grade {
    final score = gameScore;
    if (score == null) return '—';
    if (score >= 25) return 'A+';
    if (score >= 20) return 'A';
    if (score >= 15) return 'B+';
    if (score >= 10) return 'B';
    return 'C';
  }

  factory NbaGameLog.fromJson(Map<String, dynamic> json) => NbaGameLog(
        date: DateTime.parse('${json['date']}'),
        opponent: '${json['opponent'] ?? 'Ismeretlen'}',
        outcome: '${json['outcome'] ?? ''}'.toUpperCase(),
        location: '${json['location'] ?? ''}'.toUpperCase(),
        minutes: _asDouble(json['minutes']),
        points: _asInt(json['points']),
        rebounds: _asInt(json['rebounds']),
        assists: _asInt(json['assists']),
        steals: _asInt(json['steals']),
        blocks: _asInt(json['blocks']),
        turnovers: _asInt(json['turnovers']),
        fieldGoalsMade: _asInt(json['field_goals_made']),
        fieldGoalsAttempted: _asInt(json['field_goals_attempted']),
        plusMinus:
            json['plus_minus'] == null ? null : _asInt(json['plus_minus']),
        gameScore:
            json['game_score'] == null ? null : _asDouble(json['game_score']),
        score: _nonEmpty(json['score']),
      );
}

class BasketballReferenceRepository {
  BasketballReferenceRepository({
    this.cacheLifetime = const Duration(hours: 6),
    BasketballReferenceHtmlFetcher? fetchHtml,
    Directory? cacheDirectory,
  })  : _fetchHtml = fetchHtml ?? _downloadHtml,
        _cacheDirectory = cacheDirectory;

  static bool networkEnabled = true;
  final Duration cacheLifetime;
  final BasketballReferenceHtmlFetcher _fetchHtml;
  final Directory? _cacheDirectory;

  static const _host = 'www.basketball-reference.com';

  Future<List<NbaGameLog>> recentGames(
    String athleteName, {
    DateTime? now,
    String league = 'nba',
  }) async {
    if (!networkEnabled) return const [];
    final normalizedLeague = league.toLowerCase();
    if (normalizedLeague != 'nba' && normalizedLeague != 'wnba') {
      throw ArgumentError.value(league, 'league', 'Csak nba vagy wnba lehet.');
    }
    final effectiveNow = now ?? DateTime.now();
    final season = normalizedLeague == 'wnba'
        ? effectiveNow.year
        : seasonEndYear(effectiveNow);
    final cache = await _cacheFile(athleteName, season, normalizedLeague);
    final cached = await _readCache(cache, effectiveNow, freshOnly: true);
    if (cached != null) return parseGames(cached);

    try {
      final payload = normalizedLeague == 'wnba'
          ? await _fetchWnba(athleteName, season)
          : await _fetchNba(athleteName, season);
      await cache.parent.create(recursive: true);
      await cache.writeAsString(jsonEncode(payload), flush: true);
      return parseGames(payload);
    } catch (_) {
      final stale = await _readCache(cache, effectiveNow, freshOnly: false);
      if (stale != null) return parseGames(stale);
      rethrow;
    }
  }

  static int seasonEndYear(DateTime now) =>
      now.month >= 9 ? now.year + 1 : now.year;

  Future<BasketballSeasonStat?> seasonSummary(
    String athleteName, {
    DateTime? now,
  }) async {
    if (!networkEnabled) return null;
    final effectiveNow = now ?? DateTime.now();
    final season = seasonEndYear(effectiveNow);
    final cache = await _cacheFile(athleteName, season, 'nba_summary');
    final cached = await _readCache(cache, effectiveNow, freshOnly: true);
    if (cached != null) {
      return BasketballSeasonStat.fromJson(cached);
    }

    try {
      final player = await _findPlayer(athleteName, league: 'nba');
      final html = await _fetchHtml(Uri.https(_host, player.$2));
      final summary = parseNbaSeasonSummaryHtml(
        html,
        preferredSeasonEndYear: season,
      );
      if (summary == null) {
        throw StateError(
          'A Basketball Reference nem adott NBA szezonösszesítőt: $athleteName',
        );
      }
      await cache.parent.create(recursive: true);
      await cache.writeAsString(jsonEncode(summary.toJson()), flush: true);
      return summary;
    } catch (_) {
      final stale = await _readCache(cache, effectiveNow, freshOnly: false);
      if (stale != null) return BasketballSeasonStat.fromJson(stale);
      rethrow;
    }
  }

  static BasketballSeasonStat? parseNbaSeasonSummaryHtml(
    String html, {
    int? preferredSeasonEndYear,
  }) {
    final document = html_parser.parse(html);
    final candidates = <({int year, String team, dom.Element row})>[];
    for (final row in document.querySelectorAll('tr[id]')) {
      final match = RegExp(r'^per_game_stats\.(\d{4})$').firstMatch(row.id);
      if (match == null) continue;
      final year = int.tryParse(match.group(1) ?? '');
      if (year == null ||
          (preferredSeasonEndYear != null && year > preferredSeasonEndYear)) {
        continue;
      }
      candidates.add((
        year: year,
        team: _statText(row, 'team_name_abbr'),
        row: row,
      ));
    }
    if (candidates.isEmpty) return null;
    candidates.sort((a, b) {
      final byYear = b.year.compareTo(a.year);
      if (byYear != 0) return byYear;
      final aTotal = RegExp(r'^\d+TM$').hasMatch(a.team) ? 1 : 0;
      final bTotal = RegExp(r'^\d+TM$').hasMatch(b.team) ? 1 : 0;
      if (aTotal != bTotal) return bTotal.compareTo(aTotal);
      return _asInt(_statText(b.row, 'games'))
          .compareTo(_asInt(_statText(a.row, 'games')));
    });
    final selected = candidates.first;
    final row = selected.row;
    double? number(String stat) => _nullableDouble(_statText(row, stat));
    final fieldGoal = number('fg_pct');
    final team = RegExp(r'^\d+TM$').hasMatch(selected.team)
        ? 'Több csapat'
        : (_nbaTeams[selected.team] ?? selected.team);
    final result = BasketballSeasonStat(
      league: 'NBA',
      season: '${selected.year - 1}/${selected.year}',
      team: team,
      source: 'Basketball Reference',
      games: _asInt(_statText(row, 'games')),
      minutesPerGame: number('mp_per_g'),
      pointsPerGame: number('pts_per_g'),
      reboundsPerGame: number('trb_per_g'),
      assistsPerGame: number('ast_per_g'),
      stealsPerGame: number('stl_per_g'),
      turnoversPerGame: number('tov_per_g'),
      fieldGoalPercentage: fieldGoal == null ? null : fieldGoal * 100,
    );
    return result.hasUsefulData ? result : null;
  }

  static List<NbaGameLog> parseGames(Map<String, dynamic> payload) {
    if (payload['error'] != null) {
      throw StateError('Basketball Reference hiba: ${payload['error']}');
    }
    final games = payload['games'];
    if (games is! List) return const [];
    final parsed = games
        .whereType<Map>()
        .map((game) => NbaGameLog.fromJson(Map<String, dynamic>.from(game)))
        .toList();
    parsed.sort((a, b) => b.date.compareTo(a.date));
    return parsed;
  }

  static List<NbaGameLog> parseNbaGameLogHtml(String html) => parseGames({
        'games': _parseGameTables(
            html,
            const {
              'player_game_log_reg',
              'player_game_log_post',
            },
            _nbaTeams)
      });

  static List<NbaGameLog> parseWnbaLastFiveHtml(String html) => parseGames({
        'games': _parseGameTables(html, const {'last5'}, _wnbaTeams)
      });

  Future<Map<String, dynamic>> _fetchNba(String athleteName, int season) async {
    final player = await _findPlayer(athleteName, league: 'nba');
    final identifier = player.$2.split('/').last.replaceAll('.html', '');
    if (identifier.isEmpty) {
      throw StateError('Érvénytelen Basketball Reference játékosazonosító.');
    }
    final uri = Uri.https(
      _host,
      '/players/${identifier[0]}/$identifier/gamelog/$season',
    );
    final html = await _fetchHtml(uri);
    final games = parseNbaGameLogHtml(html).take(5).toList();
    return _payload(
      provider: 'Basketball Reference',
      player: player.$1,
      identifier: identifier,
      season: season,
      games: games,
    );
  }

  Future<Map<String, dynamic>> _fetchWnba(
    String athleteName,
    int season,
  ) async {
    final player = await _findPlayer(athleteName, league: 'wnba');
    final uri = Uri.https(_host, player.$2);
    final html = await _fetchHtml(uri);
    final games = parseWnbaLastFiveHtml(html).take(5).toList();
    return _payload(
      provider: 'Basketball Reference WNBA',
      player: player.$1,
      identifier: player.$2,
      season: season,
      games: games,
    );
  }

  Future<(String, String)> _findPlayer(
    String athleteName, {
    required String league,
  }) async {
    final searchUri = Uri.https(
      _host,
      '/search/search.fcgi',
      {'search': athleteName},
    );
    final document = html_parser.parse(await _fetchHtml(searchUri));
    final prefix = league == 'wnba' ? '/wnba/players/' : '/players/';
    final candidates = <(String, String)>[];
    for (final anchor in document.querySelectorAll('a[href]')) {
      final href = anchor.attributes['href'] ?? '';
      if (!href.startsWith(prefix) || !href.endsWith('.html')) continue;
      final name = anchor.text.trim().split(' (').first.trim();
      if (name.isEmpty) continue;
      final candidate = (name, href);
      if (!candidates.any((item) => item.$2 == href)) candidates.add(candidate);
    }
    if (candidates.isEmpty) {
      throw StateError(
        'Nem található Basketball Reference $league játékos: $athleteName',
      );
    }
    final wanted = normalizeAthleteName(athleteName).replaceAll(' ', '');
    return candidates.firstWhere(
      (candidate) =>
          normalizeAthleteName(candidate.$1).replaceAll(' ', '') == wanted,
      orElse: () => candidates.first,
    );
  }

  static Map<String, dynamic> _payload({
    required String provider,
    required String player,
    required String identifier,
    required int season,
    required List<NbaGameLog> games,
  }) =>
      {
        'provider': provider,
        'player': player,
        'identifier': identifier,
        'season_end_year': season,
        'fetched_at': DateTime.now().toUtc().toIso8601String(),
        'games': games.map(_gameToJson).toList(),
        'warnings': const [],
      };

  Future<Map<String, dynamic>?> _readCache(
    File file,
    DateTime now, {
    required bool freshOnly,
  }) async {
    try {
      if (!await file.exists()) return null;
      if (freshOnly) {
        final age = now.difference(await file.lastModified());
        if (age > cacheLifetime || age.isNegative) return null;
      }
      final decoded = jsonDecode(await file.readAsString());
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } catch (_) {
      return null;
    }
  }

  Future<File> _cacheFile(String athleteName, int season, String league) async {
    final directory = _cacheDirectory ??
        Directory(
          '${Platform.environment['APPDATA'] ?? Directory.current.path}'
          '/courtboard_cache/basketball_reference',
        );
    final slug = normalizeAthleteName(athleteName).replaceAll(' ', '_');
    return File('${directory.path}/${league}_${slug}_$season.json');
  }

  static Future<String> _downloadHtml(Uri uri) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 20);
    try {
      final request =
          await client.getUrl(uri).timeout(const Duration(seconds: 20));
      request.followRedirects = true;
      request.maxRedirects = 5;
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
        'AppleWebKit/537.36 Chrome/126.0 Safari/537.36 Courtboard/0.1',
      );
      request.headers.set(HttpHeaders.acceptLanguageHeader, 'en-US,en;q=0.9');
      request.headers
          .set(HttpHeaders.acceptHeader, 'text/html,application/xhtml+xml');
      final response =
          await request.close().timeout(const Duration(seconds: 30));
      final body = await response
          .transform(const Utf8Decoder(allowMalformed: true))
          .join()
          .timeout(const Duration(seconds: 30));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'Basketball Reference HTTP ${response.statusCode}',
          uri: uri,
        );
      }
      return body;
    } finally {
      client.close(force: true);
    }
  }

  static List<Map<String, dynamic>> _parseGameTables(
    String html,
    Set<String> tableIds,
    Map<String, String> teamNames,
  ) {
    final document = html_parser.parse(html);
    final tables = <dom.Element>[];
    tables.addAll(document.querySelectorAll('table').where(
          (table) => tableIds.contains(table.id),
        ));

    // Basketball Reference időnként HTML-kommentbe csomagolja a táblákat.
    for (final match in RegExp(r'<!--([\s\S]*?)-->').allMatches(html)) {
      final comment = match.group(1) ?? '';
      if (!comment.contains('<table')) continue;
      final fragment = html_parser.parseFragment(comment);
      tables.addAll(fragment.querySelectorAll('table').where(
            (table) => tableIds.contains(table.id),
          ));
    }

    final games = <Map<String, dynamic>>[];
    final seen = <String>{};
    for (final table in tables) {
      for (final row in table.querySelectorAll('tbody tr')) {
        final cells = <String, String>{};
        for (final cell in row.children) {
          final stat = cell.attributes['data-stat'];
          if (stat != null) cells[stat] = _cleanText(cell.text);
        }
        final date = cells['date'] ?? cells['date_game'] ?? '';
        final minutes = cells['mp'] ?? '';
        if (DateTime.tryParse(date) == null || minutes.isEmpty) continue;
        final opponentCode = cells['opp_name_abbr'] ?? cells['opp_id'] ?? '';
        final result = cells['game_result'] ?? '';
        final score = result.contains(',')
            ? _nonEmpty(result.split(',').skip(1).join(',').trim())
            : null;
        final game = <String, dynamic>{
          'date': date,
          'opponent': teamNames[opponentCode] ?? opponentCode,
          'outcome': result.toUpperCase().startsWith('W') ? 'WIN' : 'LOSS',
          'location': cells['game_location'] == '@' ? 'AWAY' : 'HOME',
          'minutes': _minutes(cells['mp']),
          'points': _asInt(cells['pts']),
          'rebounds': cells['trb']?.isNotEmpty == true
              ? _asInt(cells['trb'])
              : _asInt(cells['orb']) + _asInt(cells['drb']),
          'assists': _asInt(cells['ast']),
          'steals': _asInt(cells['stl']),
          'blocks': _asInt(cells['blk']),
          'turnovers': _asInt(cells['tov']),
          'field_goals_made': _asInt(cells['fg']),
          'field_goals_attempted': _asInt(cells['fga']),
          'plus_minus': _nullableInt(cells['plus_minus']),
          'game_score': _nullableDouble(cells['game_score']),
          'score': score,
        };
        final key = '$date|$opponentCode|${score ?? ''}';
        if (seen.add(key)) games.add(game);
      }
    }
    games.sort((a, b) => '${b['date']}'.compareTo('${a['date']}'));
    return games;
  }
}

Map<String, dynamic> _gameToJson(NbaGameLog game) => {
      'date': game.date.toIso8601String().split('T').first,
      'opponent': game.opponent,
      'outcome': game.outcome,
      'location': game.location,
      'minutes': game.minutes,
      'points': game.points,
      'rebounds': game.rebounds,
      'assists': game.assists,
      'steals': game.steals,
      'blocks': game.blocks,
      'turnovers': game.turnovers,
      'field_goals_made': game.fieldGoalsMade,
      'field_goals_attempted': game.fieldGoalsAttempted,
      'plus_minus': game.plusMinus,
      'game_score': game.gameScore,
      'score': game.score,
    };

String _statText(dom.Element row, String stat) =>
    row.querySelector('[data-stat="$stat"]')?.text.trim() ?? '';

const _nbaTeams = <String, String>{
  'ATL': 'Atlanta Hawks',
  'BOS': 'Boston Celtics',
  'BRK': 'Brooklyn Nets',
  'CHA': 'Charlotte Hornets',
  'CHI': 'Chicago Bulls',
  'CLE': 'Cleveland Cavaliers',
  'DAL': 'Dallas Mavericks',
  'DEN': 'Denver Nuggets',
  'DET': 'Detroit Pistons',
  'GSW': 'Golden State Warriors',
  'HOU': 'Houston Rockets',
  'IND': 'Indiana Pacers',
  'LAC': 'Los Angeles Clippers',
  'LAL': 'Los Angeles Lakers',
  'MEM': 'Memphis Grizzlies',
  'MIA': 'Miami Heat',
  'MIL': 'Milwaukee Bucks',
  'MIN': 'Minnesota Timberwolves',
  'NOP': 'New Orleans Pelicans',
  'NYK': 'New York Knicks',
  'OKC': 'Oklahoma City Thunder',
  'ORL': 'Orlando Magic',
  'PHI': 'Philadelphia 76ers',
  'PHO': 'Phoenix Suns',
  'POR': 'Portland Trail Blazers',
  'SAC': 'Sacramento Kings',
  'SAS': 'San Antonio Spurs',
  'TOR': 'Toronto Raptors',
  'UTA': 'Utah Jazz',
  'WAS': 'Washington Wizards',
  'NJN': 'New Jersey Nets',
  'SEA': 'Seattle SuperSonics',
};

const _wnbaTeams = <String, String>{
  'ATL': 'Atlanta Dream',
  'CHI': 'Chicago Sky',
  'CON': 'Connecticut Sun',
  'DAL': 'Dallas Wings',
  'GSV': 'Golden State Valkyries',
  'IND': 'Indiana Fever',
  'LAS': 'Las Vegas Aces',
  'LVA': 'Las Vegas Aces',
  'MIN': 'Minnesota Lynx',
  'NYL': 'New York Liberty',
  'PHO': 'Phoenix Mercury',
  'POR': 'Portland Fire',
  'SEA': 'Seattle Storm',
  'TOR': 'Toronto Tempo',
  'WAS': 'Washington Mystics',
};

String _cleanText(String value) => value.replaceAll(RegExp(r'\s+'), ' ').trim();

double _minutes(String? value) {
  final text = value?.trim() ?? '';
  if (!text.contains(':')) return _asDouble(text);
  final parts = text.split(':');
  if (parts.length != 2) return 0;
  return _asDouble(parts[0]) + (_asDouble(parts[1]) / 60);
}

int _asInt(dynamic value) => value is int ? value : int.tryParse('$value') ?? 0;

int? _nullableInt(dynamic value) {
  final text = '${value ?? ''}'.trim().replaceFirst('+', '');
  return text.isEmpty ? null : int.tryParse(text);
}

double _asDouble(dynamic value) =>
    value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

double? _nullableDouble(dynamic value) {
  final text = '${value ?? ''}'.trim();
  return text.isEmpty ? null : double.tryParse(text);
}

String? _nonEmpty(dynamic value) {
  final text = '${value ?? ''}'.trim();
  return text.isEmpty || text == 'null' ? null : text;
}
