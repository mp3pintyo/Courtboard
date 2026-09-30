import 'football_names.dart';
import 'friendly_error.dart';
import 'json_util.dart';
import 'match_timeline.dart';
import 'openligadb.dart';
import 'sports_api.dart';

enum FootballResult { win, draw, loss, unknown }

class FootballGame {
  const FootballGame({
    required this.date,
    required this.opponent,
    required this.score,
    required this.result,
    this.competition = '',
    this.homeAway,
    this.timeline,
    this.espnMatch,
    this.source = '',
  });
  final DateTime date;
  final String opponent;
  final String score;
  final FootballResult result;

  /// Bajnokság és forduló, ha a forrás adja.
  final String competition;

  /// `home` / `away`, ha ismert.
  final String? homeAway;

  /// Beépített idővonal (az OpenLigaDB a gólokat a meccslistában adja).
  final MatchTimeline? timeline;

  /// ESPN-mérkőzés, amelynek idővonala lekérhető.
  final EspnMatchRef? espnMatch;

  /// Az adatforrás neve, ha nem az alapértelmezett.
  final String source;
}

/// Csapatmérkőzések adatforrás-állapottal: a lejátszott és a közelgő
/// mérkőzések külön listában, a kihagyott/hibás forrás üzenetével együtt.
class FootballTeamGames {
  const FootballTeamGames({
    this.recent = const [],
    this.upcoming = const [],
    this.warnings = const [],
  });

  /// Lejátszott mérkőzések, legújabb elöl.
  final List<FootballGame> recent;

  /// Közelgő mérkőzések, legközelebbi elöl.
  final List<FootballGame> upcoming;

  /// Felhasználónak szóló, kulcsmentes figyelmeztetések (például
  /// „football-data.org: a kulcs hibás vagy nincs jogosultság (HTTP 403)”).
  final List<String> warnings;
}

class FootballDataRepository {
  FootballDataRepository(this._client, {this._openLiga});
  final SportsApiClient _client;

  /// A német csapatok tartalékforrása (alapból a közös HTTP-réteggel).
  final OpenLigaDbRepository? _openLiga;

  /// Visszafelé kompatibilis: a közös HTTP-klienst nem zárja le.
  void close() => _client.close();

  /// Visszafelé kompatibilis nézet: csak a lejátszott mérkőzések.
  Future<List<FootballGame>> fetchRecentTeamGames(String teamName) async =>
      (await fetchTeamGames(teamName)).recent;

  Future<FootballTeamGames> fetchTeamGames(String teamName) async {
    final warnings = <String>[];
    if (_client.config.footballDataKey.isNotEmpty) {
      try {
        // A Free csapatlista 7 napig közös gyorsítótárból jön.
        final teams = await _client.footballDataTeams();
        final id = parseFootballDataTeamId(teams, teamName);
        if (id == null) {
          throw StateError('A csapat nem található a Free listában.');
        }
        final now = DateTime.now().toUtc();
        final from = DateTime(now.year - 1, now.month, now.day);
        String date(DateTime value) => value.toIso8601String().substring(0, 10);
        final data = await _client.footballData('/v4/teams/$id/matches', {
          'status': 'FINISHED',
          'dateFrom': date(from),
          'dateTo': date(now),
        });
        final games = parseMatches(data, teamName, teamId: id);
        if (games.isNotEmpty) {
          return FootballTeamGames(recent: games, warnings: warnings);
        }
      } on StateError catch (error) {
        warnings.add('football-data.org: ${error.message}');
      } catch (error) {
        // A kulcs nélküli, szélesebb csapatlefedettségű fallback lent fut le,
        // de a kulcs- vagy kvótahibát a felületnek látnia kell.
        final text = '$error';
        warnings.add(
            text.startsWith('football-data.org') ? text : 'football-data.org: $text');
      }
    }

    var recent = <FootballGame>[];
    var upcoming = <FootballGame>[];
    Object? sportsDbError;
    StackTrace? sportsDbStack;
    try {
      final teams = await _client.theSportsDb('/searchteams.php', {
        't': footballTeamSearchTerm(teamName),
      });
      final sportsDbId = parseTheSportsDbTeamId(teams, teamName);
      if (sportsDbId != null) {
        final payloads = await Future.wait([
          _client.theSportsDb('/eventslast.php', {'id': sportsDbId}),
          _client.theSportsDb('/eventsnext.php', {'id': sportsDbId}),
        ]);
        recent = parseTheSportsDbMatches(payloads[0], sportsDbId)
          ..sort((a, b) => b.date.compareTo(a.date));
        upcoming = parseTheSportsDbMatches(payloads[1], sportsDbId)
          ..sort((a, b) => a.date.compareTo(b.date));
      }
    } catch (error, stack) {
      sportsDbError = error;
      sportsDbStack = stack;
    }

    // Német csapatnál (Bundesliga, 2. Bundesliga, Frauen-Bundesliga) az
    // OpenLigaDB pótolja, amit a többi forrás nem adott.
    if (recent.isEmpty || upcoming.isEmpty) {
      try {
        final german = await (_openLiga ?? OpenLigaDbRepository()).teamGames(
          teamName,
        );
        if (german != null) {
          if (recent.isEmpty) recent = german.recentGames();
          if (upcoming.isEmpty) upcoming = german.upcomingGames();
        }
      } catch (error) {
        if (sportsDbError == null) {
          warnings.add('OpenLigaDB: ${friendlyError(error)}');
        }
      }
    }
    if (sportsDbError != null && recent.isEmpty && upcoming.isEmpty) {
      Error.throwWithStackTrace(sportsDbError, sportsDbStack!);
    }
    return FootballTeamGames(
      recent: recent.take(5).toList(growable: false),
      upcoming: upcoming.take(5).toList(growable: false),
      warnings: warnings,
    );
  }

  static int? parseFootballDataTeamId(
    Map<String, dynamic> data,
    String teamName,
  ) {
    final teams = data['teams'];
    if (teams is! List) return null;
    final expected = normalizeFootballTeamName(teamName);
    for (final team in jsonMapList(teams)) {
      final names = [
        '${team['name'] ?? ''}',
        '${team['shortName'] ?? ''}',
        '${team['tla'] ?? ''}',
      ];
      if (names.any((name) => normalizeFootballTeamName(name) == expected)) {
        return int.tryParse('${team['id'] ?? ''}');
      }
    }
    return null;
  }

  static String? parseTheSportsDbTeamId(
    Map<String, dynamic> data,
    String teamName,
  ) {
    final teams = data['teams'];
    if (teams is! List) return null;
    final expected = normalizeFootballTeamName(teamName);
    for (final team in jsonMapList(teams)) {
      if ('${team['strSport'] ?? ''}'.toLowerCase() != 'soccer') continue;
      final names = <String>[
        '${team['strTeam'] ?? ''}',
        ...'${team['strTeamAlternate'] ?? ''}'.split(','),
      ];
      if (names.any((name) => normalizeFootballTeamName(name) == expected)) {
        final id = '${team['idTeam'] ?? ''}'.trim();
        if (id.isNotEmpty) return id;
      }
    }
    return null;
  }

  static List<FootballGame> parseTheSportsDbMatches(
    Map<String, dynamic> data,
    String teamId,
  ) {
    final rawEvents = data['results'] ?? data['events'];
    if (rawEvents is! List) return const [];
    final games = <FootballGame>[];
    for (final raw in jsonMapList(rawEvents)) {
      final date = parseTheSportsDbEventTime(
        '${raw['dateEvent'] ?? ''}',
        '${raw['strTime'] ?? ''}',
      );
      if (date == null) continue;
      final isHome = '${raw['idHomeTeam'] ?? ''}' == teamId;
      final opponent = isHome
          ? '${raw['strAwayTeam'] ?? 'Ismeretlen'}'
          : '${raw['strHomeTeam'] ?? 'Ismeretlen'}';
      final ownScore = isHome ? raw['intHomeScore'] : raw['intAwayScore'];
      final otherScore = isHome ? raw['intAwayScore'] : raw['intHomeScore'];
      final own = int.tryParse('${ownScore ?? ''}');
      final other = int.tryParse('${otherScore ?? ''}');
      final result = own == null || other == null
          ? FootballResult.unknown
          : own == other
          ? FootballResult.draw
          : own > other
          ? FootballResult.win
          : FootballResult.loss;
      games.add(FootballGame(
        date: date,
        opponent: opponent,
        score: own == null || other == null ? '–' : '$own–$other',
        result: result,
      ));
    }
    return games;
  }

  /// A TheSportsDB `dateEvent` + `strTime` mezői UTC-ben értendők; a helyi
  /// időre alakított időpontot adja vissza. Időpont nélkül a napot helyi
  /// dátumként kezeli, értelmezhetetlen adatnál `null`.
  static DateTime? parseTheSportsDbEventTime(String date, String time) {
    final day = date.trim();
    if (day.isEmpty) return null;
    final clock = time.trim();
    if (clock.isEmpty) return DateTime.tryParse(day);
    final hasOffset = RegExp(r'(Z|[+-]\d{2}:?\d{2})$').hasMatch(clock);
    final parsed = DateTime.tryParse('${day}T$clock${hasOffset ? '' : 'Z'}');
    return parsed?.toLocal() ?? DateTime.tryParse(day);
  }

  /// football-data.org mérkőzések a [teamName] csapat szemszögéből.
  ///
  /// Ha a csapat azonosítója ([teamId]) ismert, a hazai/vendég oldalt az
  /// azonosító dönti el; különben normalizált névösszevetés (a `FC`, `CF`,
  /// `AFC` toldalékok és ékezetek figyelmen kívül hagyásával).
  static List<FootballGame> parseMatches(
    Map<String, dynamic> data,
    String teamName, {
    int? teamId,
  }) {
    final matches = data['matches'];
    if (matches is! List) return const [];
    final expected = normalizeFootballTeamName(teamName);
    bool isTeam(Map<String, dynamic> side) {
      if (teamId != null && side['id'] != null) {
        return int.tryParse('${side['id']}') == teamId;
      }
      return [
        '${side['name'] ?? ''}',
        '${side['shortName'] ?? ''}',
        '${side['tla'] ?? ''}',
      ].any((name) =>
          name.isNotEmpty && normalizeFootballTeamName(name) == expected);
    }

    final games = <FootballGame>[];
    for (final raw in jsonMapList(matches)) {
      final home = jsonMap(raw['homeTeam']);
      final away = jsonMap(raw['awayTeam']);
      final date = DateTime.tryParse('${raw['utcDate'] ?? ''}');
      if (date == null) continue;
      final homeName = '${home['name'] ?? ''}';
      final awayName = '${away['name'] ?? ''}';
      final isHome = isTeam(home) || !isTeam(away);
      final score = jsonMap(raw['score']);
      final fullTime = jsonMap(score['fullTime']);
      final homeScore = fullTime['home'] ?? 0;
      final awayScore = fullTime['away'] ?? 0;
      final winner = '${score['winner'] ?? ''}';
      final result = winner == 'DRAW'
          ? FootballResult.draw
          : (isHome && winner == 'HOME_TEAM') ||
                (!isHome && winner == 'AWAY_TEAM')
          ? FootballResult.win
          : winner == 'HOME_TEAM' || winner == 'AWAY_TEAM'
          ? FootballResult.loss
          : FootballResult.unknown;
      games.add(FootballGame(
        date: date.toLocal(),
        opponent: isHome ? awayName : homeName,
        score: isHome ? '$homeScore–$awayScore' : '$awayScore–$homeScore',
        result: result,
      ));
    }
    games.sort((a, b) => b.date.compareTo(a.date));
    return games.take(5).toList();
  }
}
