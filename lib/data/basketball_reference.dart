import 'dart:io';
import 'dart:isolate';

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import 'package:courtboard/data/athlete_names.dart';
import 'package:courtboard/data/basketball_season.dart';
import 'package:courtboard/data/file_util.dart';
import 'package:courtboard/data/http_service.dart';
import 'package:courtboard/data/http_util.dart';
import 'package:courtboard/data/json_file_cache.dart';
import 'package:courtboard/data/json_util.dart';

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

  /// A statisztikasor pontok nélkül — amikor a pont a sor kiemelt
  /// pontszerzés-jelölésében látszik.
  String get performanceWithoutPoints =>
      '$rebounds REB · $assists AST · ${minutes.toStringAsFixed(0)} MIN';

  String get grade {
    final score = gameScore;
    if (score == null) return '—';
    if (score >= 25) return 'A+';
    if (score >= 20) return 'A';
    if (score >= 15) return 'B+';
    if (score >= 10) return 'B';
    return 'C';
  }

  /// Értelmezhetetlen dátumú sornál `null` – külső adatnál ezt kell használni.
  static NbaGameLog? tryFromJson(Map<String, dynamic> json) =>
      DateTime.tryParse('${json['date'] ?? ''}') == null
      ? null
      : NbaGameLog.fromJson(json);

  factory NbaGameLog.fromJson(Map<String, dynamic> json) => NbaGameLog(
    date: DateTime.parse('${json['date']}'),
    opponent: '${json['opponent'] ?? 'Ismeretlen'}',
    outcome: '${json['outcome'] ?? ''}'.toUpperCase(),
    location: '${json['location'] ?? ''}'.toUpperCase(),
    minutes: jsonDouble(json['minutes']),
    points: jsonInt(json['points']),
    rebounds: jsonInt(json['rebounds']),
    assists: jsonInt(json['assists']),
    steals: jsonInt(json['steals']),
    blocks: jsonInt(json['blocks']),
    turnovers: jsonInt(json['turnovers']),
    fieldGoalsMade: jsonInt(json['field_goals_made']),
    fieldGoalsAttempted: jsonInt(json['field_goals_attempted']),
    plusMinus: json['plus_minus'] == null ? null : jsonInt(json['plus_minus']),
    gameScore: json['game_score'] == null
        ? null
        : jsonDouble(json['game_score']),
    score: jsonString(json['score']),
  );
}

class BasketballReferenceRepository {
  /// A [cacheDirectory] (tesztekhez) vagy a [cacheStorage] felülírja a közös
  /// gyorsítótárat. [networkEnabled] alapértelmezése a [HttpService]
  /// beállítása; saját [fetchHtml] esetén mindig engedélyezett.
  BasketballReferenceRepository({
    this.cacheLifetime = const Duration(hours: 6),
    BasketballReferenceHtmlFetcher? fetchHtml,
    Directory? cacheDirectory,
    CacheStorage? cacheStorage,
    HttpService? http,
    bool? networkEnabled,
    DateTime Function()? clock,
  }) : _http = http ?? HttpService.shared,
       _fetchOverride = fetchHtml,
       networkEnabled =
           networkEnabled ??
           (fetchHtml != null || (http ?? HttpService.shared).networkEnabled),
       _cache = JsonFileCache(
         'basketball_reference',
         storage: cacheStorage,
         directory: cacheDirectory,
         clock: clock,
       );

  /// `false` esetén a lekérdezések üres eredményt adnak, hálózat és lemez
  /// érintése nélkül (widget-tesztek, offline futtatás).
  final bool networkEnabled;
  final Duration cacheLifetime;
  final HttpService _http;
  final BasketballReferenceHtmlFetcher? _fetchOverride;
  final JsonFileCache _cache;

  static const _host = 'www.basketball-reference.com';

  Future<List<NbaGameLog>> recentGames(
    String athleteName, {
    DateTime? now,
    String league = 'nba',
  }) async =>
      (await recentGamesCached(athleteName, now: now, league: league)).value;

  /// A legutóbbi meccsek a letöltés idejével és gyorsítótár-jelzéssel.
  Future<CachedValue<List<NbaGameLog>>> recentGamesCached(
    String athleteName, {
    DateTime? now,
    String league = 'nba',
    bool forceRefresh = false,
  }) async {
    if (!networkEnabled) {
      return CachedValue(const <NbaGameLog>[], fetchedAt: DateTime.now());
    }
    final normalizedLeague = league.toLowerCase();
    if (normalizedLeague != 'nba' && normalizedLeague != 'wnba') {
      throw ArgumentError.value(league, 'league', 'Csak nba vagy wnba lehet.');
    }
    final effectiveNow = now ?? DateTime.now();
    final season = normalizedLeague == 'wnba'
        ? effectiveNow.year
        : seasonEndYear(effectiveNow);
    final payload = await _cache.getOrFetch<Map<String, dynamic>>(
      '${normalizedLeague}_${cacheSlug(athleteName)}_$season',
      ttl: cacheLifetime,
      forceRefresh: forceRefresh,
      fetch: () => normalizedLeague == 'wnba'
          ? _fetchWnba(athleteName, season)
          : _fetchNba(athleteName, season),
      encode: (value) => value,
      decode: jsonMap,
    );
    return payload.map(parseGames);
  }

  /// Az NBA alapszakasz október második felében indul: szeptemberben még az
  /// előző (júniusban véget ért) szezon a legfrissebb.
  static int seasonEndYear(DateTime now) =>
      now.month >= 10 ? now.year + 1 : now.year;

  Future<BasketballSeasonStat?> seasonSummary(
    String athleteName, {
    DateTime? now,
  }) async => (await seasonSummaryCached(athleteName, now: now))?.value;

  /// NBA szezonösszesítő a letöltés idejével; kikapcsolt hálózatnál `null`.
  Future<CachedValue<BasketballSeasonStat>?> seasonSummaryCached(
    String athleteName, {
    DateTime? now,
    bool forceRefresh = false,
  }) async {
    if (!networkEnabled) return null;
    final effectiveNow = now ?? DateTime.now();
    final season = seasonEndYear(effectiveNow);
    return _cache.getOrFetch<BasketballSeasonStat>(
      'nba_summary_${cacheSlug(athleteName)}_$season',
      ttl: cacheLifetime,
      forceRefresh: forceRefresh,
      fetch: () async {
        final player = await _findPlayer(athleteName, league: 'nba');
        final html = await _fetch(Uri.https(_host, player.$2));
        final summary = await parseNbaSeasonSummaryHtmlAsync(
          html,
          preferredSeasonEndYear: season,
        );
        if (summary == null) {
          throw StateError(
            'A Basketball Reference nem adott NBA szezonösszesítőt: $athleteName',
          );
        }
        return summary;
      },
      encode: (value) => value.toJson(),
      decode: (json) => BasketballSeasonStat.fromJson(jsonMap(json)),
    );
  }

  /// [parseNbaSeasonSummaryHtml] külön isolate-ban (a nagy HTML-oldal
  /// feldolgozása ne akassza meg a felületet).
  static Future<BasketballSeasonStat?> parseNbaSeasonSummaryHtmlAsync(
    String html, {
    int? preferredSeasonEndYear,
  }) => Isolate.run(
    () => parseNbaSeasonSummaryHtml(
      html,
      preferredSeasonEndYear: preferredSeasonEndYear,
    ),
  );

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
      return jsonInt(
        _statText(b.row, 'games'),
      ).compareTo(jsonInt(_statText(a.row, 'games')));
    });
    final selected = candidates.first;
    final row = selected.row;
    double? number(String stat) => jsonDoubleOrNull(_statText(row, stat));
    final fieldGoal = number('fg_pct');
    final team = RegExp(r'^\d+TM$').hasMatch(selected.team)
        ? 'Több csapat'
        : (_nbaTeams[selected.team] ?? selected.team);
    final result = BasketballSeasonStat(
      league: 'NBA',
      season: '${selected.year - 1}/${selected.year}',
      team: team,
      source: 'Basketball Reference',
      games: jsonInt(_statText(row, 'games')),
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
    final parsed = jsonMapList(
      payload['games'],
    ).map(NbaGameLog.tryFromJson).whereType<NbaGameLog>().toList();
    parsed.sort((a, b) => b.date.compareTo(a.date));
    return parsed;
  }

  static List<NbaGameLog> parseNbaGameLogHtml(String html) => parseGames({
    'games': _parseGameTables(html, const {
      'player_game_log_reg',
      'player_game_log_post',
    }, _nbaTeams),
  });

  static List<NbaGameLog> parseWnbaLastFiveHtml(String html) => parseGames({
    'games': _parseGameTables(html, const {'last5'}, _wnbaTeams),
  });

  /// [parseNbaGameLogHtml] külön isolate-ban.
  static Future<List<NbaGameLog>> parseNbaGameLogHtmlAsync(String html) =>
      Isolate.run(() => parseNbaGameLogHtml(html));

  /// [parseWnbaLastFiveHtml] külön isolate-ban.
  static Future<List<NbaGameLog>> parseWnbaLastFiveHtmlAsync(String html) =>
      Isolate.run(() => parseWnbaLastFiveHtml(html));

  /// A keresőoldal játékoslinkjei (`(név, útvonal)`), duplikátumok nélkül.
  static List<(String, String)> parseSearchCandidates(
    String html, {
    required String league,
  }) {
    final document = html_parser.parse(html);
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
    return candidates;
  }

  /// [parseSearchCandidates] külön isolate-ban.
  static Future<List<(String, String)>> parseSearchCandidatesAsync(
    String html, {
    required String league,
  }) => Isolate.run(() => parseSearchCandidates(html, league: league));

  Future<String> _fetch(Uri uri) {
    final override = _fetchOverride;
    if (override != null) return override(uri);
    return _http.getText(
      uri,
      provider: 'Basketball Reference',
      allowMalformed: true,
      timeout: const Duration(seconds: 30),
      headers: {
        HttpHeaders.userAgentHeader:
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
            'AppleWebKit/537.36 Chrome/126.0 Safari/537.36 Courtboard/0.1',
        HttpHeaders.acceptLanguageHeader: 'en-US,en;q=0.9',
        HttpHeaders.acceptHeader: 'text/html,application/xhtml+xml',
      },
    );
  }

  Future<Map<String, dynamic>> _fetchNba(String athleteName, int season) async {
    final player = await _findPlayer(athleteName, league: 'nba');
    final identifier = player.$2.split('/').last.replaceAll('.html', '');
    if (identifier.isEmpty) {
      throw StateError('Érvénytelen Basketball Reference játékosazonosító.');
    }
    // Ha a számolt szezonban még nincs meccs (vagy az oldal 404), az előző
    // szezon naplóját adjuk vissza, hogy a profil ne maradjon üresen.
    for (final candidate in [season, season - 1]) {
      final uri = Uri.https(
        _host,
        '/players/${identifier[0]}/$identifier/gamelog/$candidate',
      );
      final String html;
      try {
        html = await _fetch(uri);
      } on CourtboardHttpException catch (error) {
        if (error.isNotFound && candidate == season) continue;
        rethrow;
      }
      final games = (await parseNbaGameLogHtmlAsync(html)).take(5).toList();
      if (games.isEmpty && candidate == season) continue;
      return _payload(
        provider: 'Basketball Reference',
        player: player.$1,
        identifier: identifier,
        season: candidate,
        games: games,
      );
    }
    throw StateError('Nem található Basketball Reference meccsnapló.');
  }

  Future<Map<String, dynamic>> _fetchWnba(
    String athleteName,
    int season,
  ) async {
    final player = await _findPlayer(athleteName, league: 'wnba');
    final uri = Uri.https(_host, player.$2);
    final html = await _fetch(uri);
    final games = (await parseWnbaLastFiveHtmlAsync(html)).take(5).toList();
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
    final searchUri = Uri.https(_host, '/search/search.fcgi', {
      'search': athleteName,
    });
    final candidates = await parseSearchCandidatesAsync(
      await _fetch(searchUri),
      league: league,
    );
    if (candidates.isEmpty) {
      throw StateError(
        'Nem található Basketball Reference $league játékos: $athleteName',
      );
    }
    final wanted = normalizeAthleteName(athleteName).replaceAll(' ', '');
    for (final candidate in candidates) {
      if (normalizeAthleteName(candidate.$1).replaceAll(' ', '') == wanted) {
        return candidate;
      }
    }
    final match = findAthleteByName(
      candidates,
      athleteName,
      (candidate) => candidate.$1,
    );
    if (match == null) {
      throw StateError(
        'Nem található Basketball Reference $league játékos: $athleteName',
      );
    }
    return match;
  }

  static Map<String, dynamic> _payload({
    required String provider,
    required String player,
    required String identifier,
    required int season,
    required List<NbaGameLog> games,
  }) => {
    'provider': provider,
    'player': player,
    'identifier': identifier,
    'season_end_year': season,
    'fetched_at': DateTime.now().toUtc().toIso8601String(),
    'games': games.map(_gameToJson).toList(),
    'warnings': const <String>[],
  };

  static List<Map<String, dynamic>> _parseGameTables(
    String html,
    Set<String> tableIds,
    Map<String, String> teamNames,
  ) {
    final document = html_parser.parse(html);
    final tables = <dom.Element>[];
    tables.addAll(
      document
          .querySelectorAll('table')
          .where((table) => tableIds.contains(table.id)),
    );

    // Basketball Reference időnként HTML-kommentbe csomagolja a táblákat.
    for (final match in RegExp(r'<!--([\s\S]*?)-->').allMatches(html)) {
      final comment = match.group(1) ?? '';
      if (!comment.contains('<table')) continue;
      final fragment = html_parser.parseFragment(comment);
      tables.addAll(
        fragment
            .querySelectorAll('table')
            .where((table) => tableIds.contains(table.id)),
      );
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
            ? jsonString(result.split(',').skip(1).join(',').trim())
            : null;
        final game = <String, dynamic>{
          'date': date,
          'opponent': teamNames[opponentCode] ?? opponentCode,
          'outcome': result.toUpperCase().startsWith('W') ? 'WIN' : 'LOSS',
          'location': cells['game_location'] == '@' ? 'AWAY' : 'HOME',
          'minutes': _minutes(cells['mp']),
          'points': jsonInt(cells['pts']),
          'rebounds': cells['trb']?.isNotEmpty == true
              ? jsonInt(cells['trb'])
              : jsonInt(cells['orb']) + jsonInt(cells['drb']),
          'assists': jsonInt(cells['ast']),
          'steals': jsonInt(cells['stl']),
          'blocks': jsonInt(cells['blk']),
          'turnovers': jsonInt(cells['tov']),
          'field_goals_made': jsonInt(cells['fg']),
          'field_goals_attempted': jsonInt(cells['fga']),
          'plus_minus': jsonIntOrNull(cells['plus_minus']),
          'game_score': jsonDoubleOrNull(cells['game_score']),
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
  if (!text.contains(':')) return jsonDouble(text);
  final parts = text.split(':');
  if (parts.length != 2) return 0;
  return jsonDouble(parts[0]) + (jsonDouble(parts[1]) / 60);
}
