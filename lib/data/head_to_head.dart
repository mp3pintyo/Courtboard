import 'athlete_names.dart';
import 'darts.dart';
import 'espn_liga_f.dart';
import 'espn_schedule.dart';
import 'file_util.dart';
import 'football_data.dart';
import 'football_names.dart';
import 'http_service.dart';
import 'http_util.dart';
import 'json_file_cache.dart';
import 'json_util.dart';
import 'openligadb.dart';
import 'sports_api.dart';
import 'upcoming_events.dart';

/// Egy korábbi egymás elleni mérkőzés a követett sportoló (csapat)
/// szemszögéből.
class HeadToHeadMeeting {
  const HeadToHeadMeeting({
    required this.date,
    required this.title,
    this.score = '',
    this.outcome = '',
    this.competition = '',
  });

  final DateTime date;

  /// „vs. Utah Jazz”, „@ Utah Jazz” vagy versenynév.
  final String title;

  /// Eredmény (saját elöl), ha ismert.
  final String score;

  /// `win` / `loss` / `draw` vagy üres (például feladás, walkover).
  final String outcome;
  final String competition;
}

/// Egymás elleni mérleg.
class HeadToHeadRecord {
  const HeadToHeadRecord({
    required this.opponent,
    required this.source,
    this.meetings = const [],
    this._wins,
    this._losses,
    this._draws,
    this.note,
    this.team = false,
  });

  final String opponent;
  final String source;

  /// A legutóbbi egymás elleni meccsek, a legújabb elöl.
  final List<HeadToHeadMeeting> meetings;
  final int? _wins;
  final int? _losses;
  final int? _draws;

  /// Megjegyzés a lefedettségről („az aktuális és az előző szezonból”).
  final String? note;

  /// Csapatsport (a felület „Legutóbbi egymás elleni meccsek” címet ad).
  final bool team;

  int _count(String outcome) =>
      meetings.where((meeting) => meeting.outcome == outcome).length;

  /// A forrás összesítője, különben a [meetings]-ből számolva.
  int get wins => _wins ?? _count('win');
  int get losses => _losses ?? _count('loss');
  int get draws => _draws ?? _count('draw');

  bool get isEmpty => meetings.isEmpty && wins + losses + draws == 0;

  /// „3–1” vagy döntetlennel „3–1–2”.
  String get balance => draws > 0 ? '$wins–$draws–$losses' : '$wins–$losses';
}

/// Az egymás elleni adat ehhez a párosításhoz nem érhető el (például
/// csomagkorlát). Nem hiba: a felület rövid megjegyzésként mutatja.
class HeadToHeadUnavailable implements Exception {
  const HeadToHeadUnavailable(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Egymás elleni mérleg a már meglévő forrásokból:
///
/// * NBA / WNBA / NFL – az ESPN csapatmenetrend befejezett meccsei (az
///   aktuális és az előző alapszakasz), ugyanabból a gyorsítótárból, mint a
///   háttérfigyelő;
/// * foci – az ESPN Liga F-eredmények, az OpenLigaDB szezonlistája vagy a
///   csapatmérkőzések kártya adatai;
/// * tenisz – a Live Tennis API `/h2h` végpontja (BASIC csomag; a Free
///   kulcs 403-at kaphat, ilyenkor „Nem elérhető a Free csomagban”);
/// * darts – a TheSportsDB eredménysoraiból, ha az ellenfél neve szerepel.
class HeadToHeadRepository {
  HeadToHeadRepository({
    HttpService? http,
    this._cacheStorage,
    DateTime Function()? clock,
  }) : _http = http ?? HttpService.shared,
       _clock = clock ?? DateTime.now;

  final HttpService _http;
  final CacheStorage? _cacheStorage;
  final DateTime Function() _clock;

  static const tennisCacheLifetime = Duration(days: 7);

  /// A mérleg a naptár / profil [event] eseményéhez; [team] a sportoló
  /// csapata (csapatsportnál kötelező).
  Future<HeadToHeadRecord> forEvent(
    UpcomingEvent event, {
    required SportsApiConfig config,
    String team = '',
  }) async {
    final opponent = event.opponent.trim();
    if (opponent.isEmpty) {
      throw const HeadToHeadUnavailable(
        'Ennél az eseménynél nincs megnevezett ellenfél.',
      );
    }
    final league = EspnLeague.fromSport(event.sport);
    if (league != null) return _espnTeams(league, team, opponent);
    return switch (event.sport) {
      'Foci' => _football(event, team, opponent, config),
      'Tenisz' => _tennis(event.athleteName, opponent, config),
      'Darts' => _darts(event.athleteName, opponent, config),
      _ => throw const HeadToHeadUnavailable(
        'Ehhez a sportághoz nincs egymás elleni adatforrás.',
      ),
    };
  }

  Future<HeadToHeadRecord> _espnTeams(
    EspnLeague league,
    String teamName,
    String opponent,
  ) async {
    if (teamName.trim().isEmpty) {
      throw const HeadToHeadUnavailable(
        'Add meg a sportoló csapatát az egymás elleni meccsekhez.',
      );
    }
    final espn = EspnScheduleRepository(
      http: _http,
      cacheStorage: _cacheStorage,
    );
    final team = await espn.findTeam(league, teamName);
    if (team == null) {
      throw HeadToHeadUnavailable(
        'Az ESPN ${league.label}-csapatlistájában nincs „$teamName”.',
      );
    }
    final current = await espn.seasonResults(league, team);
    var previous = const <EspnCompletedGame>[];
    try {
      previous = await espn.seasonResults(
        league,
        team,
        season: EspnScheduleRepository.currentSeasonYear(league, _clock()) - 1,
      );
    } catch (_) {
      // Az előző szezon csak kiegészítés.
    }
    return teamHeadToHead(
      [...current, ...previous],
      opponent: opponent,
      source: 'ESPN',
      note: 'Az aktuális és az előző alapszakasz befejezett meccseiből.',
    );
  }

  Future<HeadToHeadRecord> _football(
    UpcomingEvent event,
    String teamName,
    String opponent,
    SportsApiConfig config,
  ) async {
    final target = UpcomingEventsTarget(
      name: event.athleteName,
      sport: event.sport,
      team: teamName,
    );
    if (target.isLigaF) {
      final games = await LigaFRepository(
        SportsApiClient(
          config: config,
          http: _http,
          cacheStorage: _cacheStorage,
        ),
      ).recentBarcelonaGames(window: const Duration(days: 365));
      return HeadToHeadRecord(
        opponent: opponent,
        source: 'ESPN · Liga F',
        team: true,
        note: 'Az elmúlt egy év Liga F-meccseiből.',
        meetings: [
          for (final game in games)
            if (footballTeamNamesMatch(opponent, game.opponent) ||
                footballTeamNamesMatch(game.opponent, opponent))
              HeadToHeadMeeting(
                date: game.date,
                title: '${game.home ? 'vs.' : '@'} ${game.opponent}',
                score: game.score,
                outcome: switch (game.result) {
                  'GYŐZELEM' => 'win',
                  'VERESÉG' => 'loss',
                  _ => 'draw',
                },
                competition: 'Liga F',
              ),
        ],
      );
    }
    if (teamName.trim().isEmpty) {
      throw const HeadToHeadUnavailable(
        'Add meg a sportoló csapatát az egymás elleni meccsekhez.',
      );
    }
    final german = await OpenLigaDbRepository(
      http: _http,
      cacheStorage: _cacheStorage,
      clock: _clock,
    ).teamGames(teamName);
    if (german != null) {
      return footballHeadToHead(
        german.recentGames(limit: 60),
        opponent: opponent,
        source: 'OpenLigaDB',
        note: 'Az idei ${german.league.label}-szezon meccseiből.',
      );
    }
    final data = await FootballDataRepository(
      SportsApiClient(config: config, http: _http, cacheStorage: _cacheStorage),
    ).fetchTeamGames(teamName);
    return footballHeadToHead(
      data.recent,
      opponent: opponent,
      source: 'Csapatmérkőzések',
      note: 'Csak a csapatmérkőzések kártya legutóbbi meccseiből.',
    );
  }

  Future<HeadToHeadRecord> _tennis(
    String athleteName,
    String opponent,
    SportsApiConfig config,
  ) async {
    if (config.liveTennisKey.trim().isEmpty) {
      throw const HeadToHeadUnavailable(
        'A tenisz egymás elleni mérlegéhez Live Tennis API-kulcs kell.',
      );
    }
    final client = SportsApiClient(
      config: config,
      http: _http,
      cacheStorage: _cacheStorage,
    );
    try {
      final payload = await client
          .cache('live_tennis')
          .getOrFetch<Map<String, dynamic>>(
            'h2h_${cacheSlug('$athleteName $opponent')}',
            ttl: tennisCacheLifetime,
            fetch: () =>
                client.liveTennis('/h2h', {'p1': athleteName, 'p2': opponent}),
            encode: (value) => value,
            decode: jsonMap,
          );
      return parseTennisHeadToHead(payload.value, opponent: opponent);
    } on CourtboardHttpException catch (error) {
      if (error.statusCode == 403) {
        throw const HeadToHeadUnavailable(
          'Nem elérhető a Free csomagban: a Live Tennis API egymás elleni '
          'mérlege (/h2h) BASIC előfizetést igényel.',
        );
      }
      if (error.statusCode == 400) {
        throw const HeadToHeadUnavailable(
          'A Live Tennis API nem tudta egyértelműen azonosítani a két játékost.',
        );
      }
      rethrow;
    }
  }

  Future<HeadToHeadRecord> _darts(
    String athleteName,
    String opponent,
    SportsApiConfig config,
  ) async {
    final data = await DartsRepository(
      config,
      http: _http,
      cacheStorage: _cacheStorage,
    ).fetch(athleteName);
    if (data.theSportsDbError != null && data.results.isEmpty) {
      throw StateError(data.theSportsDbError!);
    }
    return dartsHeadToHead(data.results, opponent: opponent);
  }

  // -------------------------------------------------------------------------
  // Tiszta számítások
  // -------------------------------------------------------------------------

  /// Csapatsport: a befejezett meccsek közül az [opponent] elleniek.
  static HeadToHeadRecord teamHeadToHead(
    List<EspnCompletedGame> games, {
    required String opponent,
    required String source,
    String? note,
    int limit = 5,
  }) {
    final seen = <String>{};
    final meetings = [
      for (final game in [...games]..sort((a, b) => b.start.compareTo(a.start)))
        if (_sameTeam(game.opponent, opponent) && seen.add(game.id))
          HeadToHeadMeeting(
            date: game.start,
            title: '${game.homeAway == 'away' ? '@' : 'vs.'} ${game.opponent}',
            score: game.score,
            outcome: game.outcome,
          ),
    ];
    return HeadToHeadRecord(
      opponent: opponent,
      source: source,
      team: true,
      note: note,
      wins: meetings.where((m) => m.outcome == 'win').length,
      losses: meetings.where((m) => m.outcome == 'loss').length,
      draws: meetings.where((m) => m.outcome == 'draw').length,
      meetings: meetings.take(limit).toList(growable: false),
    );
  }

  /// Foci: a csapatmérkőzések közül az [opponent] elleniek.
  static HeadToHeadRecord footballHeadToHead(
    List<FootballGame> games, {
    required String opponent,
    required String source,
    String? note,
    int limit = 5,
  }) {
    final meetings = [
      for (final game in [...games]..sort((a, b) => b.date.compareTo(a.date)))
        if (footballTeamNamesMatch(opponent, game.opponent) ||
            footballTeamNamesMatch(game.opponent, opponent))
          HeadToHeadMeeting(
            date: game.date,
            title: '${game.homeAway == 'away' ? '@' : 'vs.'} ${game.opponent}',
            score: game.score == '–' ? '' : game.score,
            outcome: switch (game.result) {
              FootballResult.win => 'win',
              FootballResult.loss => 'loss',
              FootballResult.draw => 'draw',
              FootballResult.unknown => '',
            },
            competition: game.competition,
          ),
    ];
    return HeadToHeadRecord(
      opponent: opponent,
      source: source,
      team: true,
      note: note,
      wins: meetings.where((m) => m.outcome == 'win').length,
      losses: meetings.where((m) => m.outcome == 'loss').length,
      draws: meetings.where((m) => m.outcome == 'draw').length,
      meetings: meetings.take(limit).toList(growable: false),
    );
  }

  /// Darts: az eredménysorok közül azok, amelyek az ellenfél nevét
  /// tartalmazzák (a TheSportsDB eseményneve „A vs B” alakú).
  static HeadToHeadRecord dartsHeadToHead(
    List<DartsResult> results, {
    required String opponent,
  }) {
    final key = normalizeAthleteName(opponent);
    final surname = key.split(' ').last;
    final meetings = [
      for (final result in results)
        if (key.isNotEmpty &&
            (normalizeAthleteName(result.event).contains(key) ||
                (surname.length > 3 &&
                    normalizeAthleteName(result.event).contains(surname))))
          HeadToHeadMeeting(
            date: result.date,
            title: result.event,
            score:
                RegExp(r'\d+\s*[-–]\s*\d+').firstMatch(result.detail)?[0] ?? '',
            outcome: switch (result.detail.trim().toUpperCase()) {
              'W' || 'WIN' || 'WON' => 'win',
              'L' || 'LOSS' || 'LOST' => 'loss',
              _ => '',
            },
          ),
    ];
    return HeadToHeadRecord(
      opponent: opponent,
      source: 'TheSportsDB',
      meetings: meetings,
      note:
          'A TheSportsDB legutóbbi eredménysoraiból; a régebbi meccsek '
          'nem szerepelnek.',
    );
  }

  /// A Live Tennis API `/h2h` válasza (`players`, `totals`, `meetings[]`),
  /// a kérésben a sportoló a `p1`.
  static HeadToHeadRecord parseTennisHeadToHead(
    Map<String, dynamic> payload, {
    required String opponent,
  }) {
    final players = payload['players'];
    if (players == null) {
      throw const HeadToHeadUnavailable(
        'A Live Tennis API nem ismeri fel a két játékost.',
      );
    }
    final totals = jsonMap(payload['totals']);
    int? pick(List<String> keys) {
      for (final key in keys) {
        final value = totals[key];
        if (value is Map) {
          final wins = jsonIntOrNull(value['wins']);
          if (wins != null) return wins;
        }
        final number = jsonIntOrNull(value);
        if (number != null) return number;
      }
      return null;
    }

    final meetings = <HeadToHeadMeeting>[];
    for (final raw in jsonMapList(payload['meetings'])) {
      final date = DateTime.tryParse(
        jsonString(raw['date']) ??
            jsonString(raw['event_date']) ??
            jsonString(raw['scheduled_time']) ??
            '',
      );
      if (date == null) continue;
      final winner = jsonIntOrNull(raw['winner']);
      final outcomeText = (jsonString(raw['outcome']) ?? '').toLowerCase();
      final walkover = outcomeText.contains('walkover');
      meetings.add(
        HeadToHeadMeeting(
          date: date.toLocal(),
          title:
              jsonString(raw['tournament']) ??
              jsonString(raw['tournament_name']) ??
              'Mérkőzés',
          score: walkover ? 'w.o.' : jsonString(raw['score']) ?? '',
          outcome: winner == 1
              ? 'win'
              : winner == 2
              ? 'loss'
              : '',
          competition: [
            ?jsonString(raw['round_code']) ?? jsonString(raw['round']),
            ?jsonString(raw['surface']),
          ].join(' · '),
        ),
      );
    }
    meetings.sort((a, b) => b.date.compareTo(a.date));
    return HeadToHeadRecord(
      opponent: opponent,
      source: 'Live Tennis API',
      wins: pick(const ['p1', 'p1_wins', 'wins_p1']),
      losses: pick(const ['p2', 'p2_wins', 'wins_p2']),
      draws: 0,
      meetings: meetings.take(5).toList(growable: false),
    );
  }
}

bool _sameTeam(String a, String b) {
  final left = normalizeAthleteName(a);
  final right = normalizeAthleteName(b);
  if (left.isEmpty || right.isEmpty) return false;
  return left == right || left.endsWith(' $right') || right.endsWith(' $left');
}
