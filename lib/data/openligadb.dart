import 'package:courtboard/data/football_data.dart';
import 'package:courtboard/data/football_names.dart';
import 'package:courtboard/data/http_service.dart';
import 'package:courtboard/data/json_file_cache.dart';
import 'package:courtboard/data/json_util.dart';
import 'package:courtboard/data/match_timeline.dart';
import 'package:courtboard/data/upcoming_events.dart';

/// Egy OpenLigaDB-bajnokság.
enum OpenLigaLeague {
  bundesliga('bl1', 'Bundesliga'),
  bundesliga2('bl2', '2. Bundesliga'),
  frauenBundesliga('ffb1', 'Frauen-Bundesliga', fallbackShortcut: 'fbl1');

  const OpenLigaLeague(this.shortcut, this.label, {this.fallbackShortcut});

  /// Az OpenLigaDB ligakódja (`bl1`, `bl2`, `ffb1`).
  final String shortcut;
  final String label;

  /// Régebbi szezonok ligakódja (a női liga 2026 előtt `fbl1` volt).
  final String? fallbackShortcut;
}

/// Egy OpenLigaDB-mérkőzés a követett csapat szemszögéből.
class OpenLigaMatch {
  const OpenLigaMatch({
    required this.id,
    required this.start,
    required this.home,
    required this.away,
    required this.league,
    required this.finished,
    this.homeGoals,
    this.awayGoals,
    this.round = '',
    this.goals = const [],
    this.homeTeamId,
    this.awayTeamId,
  });

  final String id;
  final DateTime start;
  final String home;
  final String away;
  final OpenLigaLeague league;
  final bool finished;
  final int? homeGoals;
  final int? awayGoals;

  /// „4. Spieltag” → „4. forduló”.
  final String round;
  final List<TimelineEvent> goals;
  final int? homeTeamId;
  final int? awayTeamId;

  MatchTimeline get timeline => MatchTimeline(
    events: goals,
    home: home,
    away: away,
    homeScore: homeGoals?.toString() ?? '',
    awayScore: awayGoals?.toString() ?? '',
    finished: finished,
    source: 'OpenLigaDB',
  );
}

/// Egy német csapat mérkőzései az OpenLigaDB-ből.
class OpenLigaTeamGames {
  const OpenLigaTeamGames({
    required this.team,
    required this.league,
    this.recent = const [],
    this.upcoming = const [],
  });

  final String team;
  final OpenLigaLeague league;

  /// Lejátszott mérkőzések, a legújabb elöl.
  final List<OpenLigaMatch> recent;

  /// Közelgő mérkőzések, a legközelebbi elöl.
  final List<OpenLigaMatch> upcoming;
}

/// OpenLigaDB (api.openligadb.de): nyílt, kulcs nélküli, közösségi német
/// labdarúgó-adatbázis. A Bundesliga, a 2. Bundesliga és a Frauen-Bundesliga
/// csapataihoz ad eredményt és menetrendet, ha a többi forrás nem ad.
///
/// * Csapatlista (`getavailableteams/{liga}/{szezon}`): 7 napos cache.
/// * Szezon-meccslista (`getmatchdata/{liga}/{szezon}`): 1 órás cache,
///   hibánál a régebbi lista.
class OpenLigaDbRepository {
  OpenLigaDbRepository({
    HttpService? http,
    this._cacheStorage,
    DateTime Function()? clock,
  }) : _http = http ?? HttpService.shared,
       _clock = clock ?? DateTime.now;

  final HttpService _http;
  final CacheStorage? _cacheStorage;
  final DateTime Function() _clock;

  static const provider = 'OpenLigaDB';
  static const teamsCacheLifetime = Duration(days: 7);
  static const matchesCacheLifetime = Duration(hours: 1);

  JsonFileCache get _cache =>
      JsonFileCache('openligadb', storage: _cacheStorage);

  /// Az OpenLigaDB szezonja: július 1-től az új év (2026/27 → 2026).
  static int seasonOf(DateTime date) =>
      date.month >= 7 ? date.year : date.year - 1;

  static Uri teamsUri(String shortcut, int season) =>
      Uri.https('api.openligadb.de', '/getavailableteams/$shortcut/$season');

  static Uri matchesUri(String shortcut, int season) =>
      Uri.https('api.openligadb.de', '/getmatchdata/$shortcut/$season');

  Future<List<Map<String, dynamic>>> _list(
    Uri uri,
    String key,
    Duration ttl,
  ) async => (await _cache.getOrFetch<List<Map<String, dynamic>>>(
    key,
    ttl: ttl,
    fetch: () async =>
        jsonMapList((await _http.getJson(uri, provider: provider))['data']),
    encode: (value) => value,
    decode: jsonMapList,
  )).value;

  /// A csapat bajnoksága és pontos neve, vagy `null`, ha egyik figyelt
  /// német bajnokságban sem szerepel.
  Future<(OpenLigaLeague, String, int)?> findTeam(String teamName) async {
    final season = seasonOf(_clock());
    for (final league in OpenLigaLeague.values) {
      for (final shortcut in [league.shortcut, ?league.fallbackShortcut]) {
        final List<Map<String, dynamic>> teams;
        try {
          teams = await _list(
            teamsUri(shortcut, season),
            'teams_${shortcut}_$season',
            teamsCacheLifetime,
          );
        } catch (_) {
          continue;
        }
        if (teams.isEmpty) continue;
        final match = findTeamIn(teams, teamName);
        if (match != null) return (league, match.$1, match.$2);
        break;
      }
    }
    return null;
  }

  /// A csapatlista közül a névhez illő (`teamName` vagy `shortName`).
  static (String, int)? findTeamIn(
    List<Map<String, dynamic>> teams,
    String teamName,
  ) {
    final team =
        findFootballTeamByName(
          teams,
          teamName,
          (team) => jsonString(team['teamName']) ?? '',
        ) ??
        findFootballTeamByName(
          teams,
          teamName,
          (team) => jsonString(team['shortName']) ?? '',
        );
    final id = jsonIntOrNull(team?['teamId']);
    if (team == null || id == null) return null;
    return (jsonString(team['teamName']) ?? teamName, id);
  }

  /// A csapat idei lejátszott és közelgő mérkőzései, vagy `null`, ha a
  /// csapat nem német (figyelt) bajnokságbeli.
  Future<OpenLigaTeamGames?> teamGames(String teamName) async {
    final found = await findTeam(teamName);
    if (found == null) return null;
    final (league, name, teamId) = found;
    final season = seasonOf(_clock());
    var matches = <Map<String, dynamic>>[];
    for (final shortcut in [league.shortcut, ?league.fallbackShortcut]) {
      matches = await _list(
        matchesUri(shortcut, season),
        'matches_${shortcut}_$season',
        matchesCacheLifetime,
      );
      if (matches.isNotEmpty) break;
    }
    return parseTeamGames(
      matches,
      league: league,
      teamId: teamId,
      teamName: name,
      now: _clock(),
    );
  }

  /// A szezon meccslistája a [teamId] csapatra szűrve.
  static OpenLigaTeamGames parseTeamGames(
    List<Map<String, dynamic>> matches, {
    required OpenLigaLeague league,
    required int teamId,
    required String teamName,
    required DateTime now,
  }) {
    final recent = <OpenLigaMatch>[];
    final upcoming = <OpenLigaMatch>[];
    for (final raw in matches) {
      final match = parseMatch(raw, league);
      if (match == null) continue;
      if (match.homeTeamId != teamId && match.awayTeamId != teamId) continue;
      if (match.finished) {
        recent.add(match);
      } else if (match.start.isAfter(now.subtract(const Duration(hours: 3)))) {
        upcoming.add(match);
      }
    }
    recent.sort((a, b) => b.start.compareTo(a.start));
    upcoming.sort((a, b) => a.start.compareTo(b.start));
    return OpenLigaTeamGames(
      team: teamName,
      league: league,
      recent: recent,
      upcoming: upcoming,
    );
  }

  /// Egy `getmatchdata` sor. Az 1970-es (ismeretlen) dátumú meccsek
  /// kimaradnak.
  static OpenLigaMatch? parseMatch(
    Map<String, dynamic> raw,
    OpenLigaLeague league,
  ) {
    final id = jsonString(raw['matchID']);
    final start = DateTime.tryParse(jsonString(raw['matchDateTimeUTC']) ?? '');
    if (id == null || start == null || start.year < 2000) return null;
    final team1 = jsonMap(raw['team1']);
    final team2 = jsonMap(raw['team2']);
    final homeId = jsonIntOrNull(team1['teamId']);
    final awayId = jsonIntOrNull(team2['teamId']);
    final finished = raw['matchIsFinished'] == true;
    // A végeredmény a legnagyobb `resultOrderID`-jú sor („Endergebnis”).
    final results = jsonMapList(raw['matchResults'])
      ..sort(
        (a, b) => (jsonIntOrNull(a['resultOrderID']) ?? 0).compareTo(
          jsonIntOrNull(b['resultOrderID']) ?? 0,
        ),
      );
    final result = results.lastOrNull;
    final goals = <TimelineEvent>[];
    for (final goal in jsonMapList(raw['goals'])) {
      final minute = jsonIntOrNull(goal['matchMinute']);
      final scorer = jsonString(goal['goalGetterName']) ?? '';
      final scoringTeam = jsonIntOrNull(goal['scoringTeamId']);
      final own = goal['isOwnGoal'] == true;
      final penalty = goal['isPenalty'] == true;
      final score1 = jsonIntOrNull(goal['scoreTeam1']);
      final score2 = jsonIntOrNull(goal['scoreTeam2']);
      // Ha nincs `scoringTeamId`, az állás változásából következtetünk.
      bool? home = scoringTeam == null
          ? null
          : scoringTeam == homeId
          ? true
          : scoringTeam == awayId
          ? false
          : null;
      if (home == null && score1 != null && score2 != null) {
        final previous = goals.lastOrNull?.score.split('–');
        final before1 = int.tryParse(previous?.first ?? '') ?? 0;
        home = score1 > before1;
      }
      goals.add(
        TimelineEvent(
          type: own
              ? TimelineEventType.ownGoal
              : penalty
              ? TimelineEventType.penaltyGoal
              : TimelineEventType.goal,
          minute: minute == null
              ? ''
              : minute > 90
              ? "90+${minute - 90}'"
              : "$minute'",
          sortKey: (minute ?? 0).toDouble() + goals.length / 1000,
          player: scorer,
          team: home == null
              ? ''
              : home
              ? jsonString(team1['teamName']) ?? ''
              : jsonString(team2['teamName']) ?? '',
          home: home,
          score: score1 == null || score2 == null ? '' : '$score1–$score2',
        ),
      );
    }
    final round = jsonString(jsonMap(raw['group'])['groupName']) ?? '';
    return OpenLigaMatch(
      id: id,
      start: start.toLocal(),
      home: jsonString(team1['teamName']) ?? 'Ismeretlen',
      away: jsonString(team2['teamName']) ?? 'Ismeretlen',
      league: league,
      finished: finished,
      homeGoals: finished ? jsonIntOrNull(result?['pointsTeam1']) : null,
      awayGoals: finished ? jsonIntOrNull(result?['pointsTeam2']) : null,
      round: round.replaceAll('Spieltag', 'forduló').trim(),
      goals: goals,
      homeTeamId: homeId,
      awayTeamId: awayId,
    );
  }
}

/// Átalakítás a meglévő modellekre.
extension OpenLigaTeamGamesViews on OpenLigaTeamGames {
  bool _isHome(OpenLigaMatch match) =>
      footballTeamNamesMatch(team, match.home) ||
      !footballTeamNamesMatch(team, match.away);

  /// Lejátszott meccsek a „Csapatmérkőzések” kártyához.
  List<FootballGame> recentGames({int limit = 5}) => [
    for (final match in recent.take(limit))
      () {
        final home = _isHome(match);
        final own = home ? match.homeGoals : match.awayGoals;
        final other = home ? match.awayGoals : match.homeGoals;
        return FootballGame(
          date: match.start,
          opponent: home ? match.away : match.home,
          score: own == null || other == null ? '–' : '$own–$other',
          result: own == null || other == null
              ? FootballResult.unknown
              : own == other
              ? FootballResult.draw
              : own > other
              ? FootballResult.win
              : FootballResult.loss,
          competition: [
            league.label,
            if (match.round.isNotEmpty) match.round,
          ].join(' · '),
          homeAway: home ? 'home' : 'away',
          timeline: match.goals.isEmpty ? null : match.timeline,
          source: OpenLigaDbRepository.provider,
        );
      }(),
  ];

  /// Közelgő meccsek a „Csapatmérkőzések” kártyához.
  List<FootballGame> upcomingGames({int limit = 5}) => [
    for (final match in upcoming.take(limit))
      FootballGame(
        date: match.start,
        opponent: _isHome(match) ? match.away : match.home,
        score: '–',
        result: FootballResult.unknown,
        competition: [
          league.label,
          if (match.round.isNotEmpty) match.round,
        ].join(' · '),
        homeAway: _isHome(match) ? 'home' : 'away',
        source: OpenLigaDbRepository.provider,
      ),
  ];

  /// Naptáresemények.
  List<UpcomingEvent> events({
    required String athleteName,
    String sport = 'Foci',
  }) => [
    for (final match in upcoming)
      UpcomingEvent(
        athleteName: athleteName,
        sport: sport,
        title: '${match.home} – ${match.away}',
        opponent: _isHome(match) ? match.away : match.home,
        competition: [
          league.label,
          if (match.round.isNotEmpty) match.round,
        ].join(' · '),
        start: match.start,
        homeAway: _isHome(match) ? 'home' : 'away',
        source: OpenLigaDbRepository.provider,
        url: 'https://www.openligadb.de/',
        // Az OpenLigaDB 00:00-s időpontja jellemzően még nem végleges.
        timeKnown:
            match.start.toUtc().hour != 0 || match.start.toUtc().minute != 0,
      ),
  ];
}
