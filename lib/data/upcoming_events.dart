import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import 'package:courtboard/domain/athlete_source_hints.dart';
import 'package:courtboard/domain/sport.dart';
import 'package:courtboard/shared/format.dart'
    show ensureHungarianDateFormatting, courtboardLocale;
import 'package:courtboard/data/athlete_highlights.dart';
import 'package:courtboard/data/athlete_names.dart';
import 'package:courtboard/data/darts.dart';
import 'package:courtboard/data/espn_schedule.dart';
import 'package:courtboard/data/espn_soccer_team.dart';
import 'package:courtboard/data/file_util.dart';
import 'package:courtboard/data/football_data.dart';
import 'package:courtboard/data/football_names.dart';
import 'package:courtboard/data/friendly_error.dart';
import 'package:courtboard/data/http_service.dart';
import 'package:courtboard/data/json_file_cache.dart';
import 'package:courtboard/data/json_util.dart';
import 'package:courtboard/data/live_tennis.dart';
import 'package:courtboard/data/openligadb.dart';
import 'package:courtboard/data/sports_api.dart';

/// Egy követett sportoló közelgő eseménye (mérkőzés vagy verseny).
class UpcomingEvent {
  const UpcomingEvent({
    required this.athleteName,
    required this.sport,
    required this.title,
    required this.start,
    required this.source,
    this.opponent = '',
    this.competition = '',
    this.venue,
    this.homeAway,
    this.url,
    this.timeKnown = true,
  });

  final String athleteName;

  /// Courtboard sportág-címke (`NBA`, `WNBA`, `NFL`, `Foci`, `Tenisz`, `Darts`).
  final String sport;

  /// Párosítás („Denver Nuggets – Utah Jazz”) vagy versenynév.
  final String title;

  /// Ellenfél; versenyeseménynél üres.
  final String opponent;

  /// Bajnokság / sorozat és szakasz („NBA · Alapszakasz”).
  final String competition;

  /// Kezdés helyi időben (a források UTC-ben küldik).
  final DateTime start;
  final String? venue;

  /// `home` / `away`, ha ismert.
  final String? homeAway;

  /// Az adatforrás neve (például `ESPN`).
  final String source;

  /// A mérkőzés nyilvános oldala, ha van.
  final String? url;

  /// Hamis, ha a forrás szerint csak a nap biztos, az időpont nem.
  final bool timeKnown;

  /// Rövid felirat a listához és a „Mai fókusz”-hoz („vs. Utah Jazz”,
  /// „@ Utah Jazz”, versenynél a cím).
  String get matchup => opponent.isEmpty
      ? title
      : homeAway == 'away'
      ? '@ $opponent'
      : 'vs. $opponent';

  Map<String, Object?> toJson() => {
    'athlete': athleteName,
    'sport': sport,
    'title': title,
    'opponent': opponent,
    'competition': competition,
    'start': start.toUtc().toIso8601String(),
    'venue': venue,
    'homeAway': homeAway,
    'source': source,
    'url': url,
    'timeKnown': timeKnown,
  };

  static UpcomingEvent? fromJson(Object? json) {
    final map = jsonMap(json);
    final start = DateTime.tryParse(jsonString(map['start']) ?? '');
    final athlete = jsonString(map['athlete']);
    final title = jsonString(map['title']);
    if (start == null || athlete == null || title == null) return null;
    return UpcomingEvent(
      athleteName: athlete,
      sport: jsonString(map['sport']) ?? '',
      title: title,
      opponent: jsonString(map['opponent']) ?? '',
      competition: jsonString(map['competition']) ?? '',
      start: start.toLocal(),
      venue: jsonString(map['venue']),
      homeAway: jsonString(map['homeAway']),
      source: jsonString(map['source']) ?? '',
      url: jsonString(map['url']),
      timeKnown: map['timeKnown'] != false,
    );
  }
}

/// Egy követett sportoló, amelyhez eseményeket keresünk.
class UpcomingEventsTarget {
  const UpcomingEventsTarget({
    required this.name,
    required this.sport,
    this.team = '',
    this.sourceHints = AthleteSourceHints.none,
  });

  final String name;
  final Sport sport;
  final String team;

  /// A sportolóval mentett adatforrás-tippek (például Liga F).
  final AthleteSourceHints sourceHints;

  /// A Liga F-tippel (ESPN `esp.w.1`) rendelkező focista.
  bool get isLigaF => sport == Sport.football && sourceHints.isLigaF;

  /// ESPN-bajnokságkóddal rendelkező focista: menetrendje, élő meccsei és
  /// eredményei az adott ESPN-bajnokságból jönnek (a csapatot a [team],
  /// illetve a tippek adják); más focistánál a klubcsapat-források élnek.
  bool get hasEspnSoccerLeague =>
      sport == Sport.football && sourceHints.hasEspnLeague;

  /// A csapat az ESPN-bajnokságban (lásd [hasEspnSoccerLeague]); `null`,
  /// ha nincs ilyen tipp vagy csapat.
  EspnSoccerTeam? get espnSoccerTeam => sport == Sport.football
      ? EspnSoccerTeam.fromHints(sourceHints, team)
      : null;

  /// Stabil gyorsítótár-kulcs; csapat- vagy sportágváltáskor új bejegyzés.
  /// (A sportág a 0.13.0 előtti szöveges alakjában szerepel, így a régi
  /// gyorsítótár-bejegyzések érvényesek maradnak.)
  String get cacheKey => cacheSlug('${sport.jsonValue} $team $name');

  @override
  bool operator ==(Object other) =>
      other is UpcomingEventsTarget &&
      other.name == name &&
      other.sport == sport &&
      other.team == team &&
      other.sourceHints == sourceHints;

  @override
  int get hashCode => Object.hash(name, sport, team, sourceHints);
}

/// Egy sportoló eseménylistája és a betöltés állapota.
class AthleteEventsResult {
  const AthleteEventsResult({
    required this.target,
    this.events = const [],
    this.notes = const [],
    this.error,
    this.unavailable,
    this.fetchedAt,
    this.fromCache = false,
    this.stale = false,
  });

  final UpcomingEventsTarget target;

  /// Közelgő események időrendben.
  final List<UpcomingEvent> events;

  /// Nem végzetes figyelmeztetések (például egy kiegészítő forrás hibája).
  final List<String> notes;

  /// Felhasználóbarát hibaüzenet, ha a betöltés sikertelen volt.
  final String? error;

  /// Ha ehhez a sportolóhoz nincs (vagy kulcs nélkül nincs) eseményforrás.
  final String? unavailable;
  final DateTime? fetchedAt;
  final bool fromCache;
  final bool stale;
}

/// A sportolóhoz nincs használható eseményforrás (hiányzó kulcs, csapat
/// vagy támogatás). Nem hiba: a naptár apró megjegyzésként jelzi.
class UpcomingEventsUnavailable implements Exception {
  const UpcomingEventsUnavailable(this.message);
  final String message;

  @override
  String toString() => message;
}

/// A közelgő események forrása egy sportolóhoz (lásd
/// [UpcomingEventsRepository]).
enum UpcomingSource {
  /// NBA / WNBA / NFL: az ESPN nyilvános csapatmenetrendje.
  espnTeamSchedule('ESPN csapatmenetrend'),

  /// ESPN-bajnokságkóddal rendelkező focista (például Liga F): az ESPN
  /// bajnoki scoreboardja a csapat meccseivel.
  espnSoccerLeague('ESPN · bajnoki scoreboard'),

  /// Focista: football-data.org, ESPN-csapatmenetrend, TheSportsDB, végül
  /// OpenLigaDB.
  footballClub('football-data.org / ESPN / TheSportsDB / OpenLigaDB'),

  /// Teniszező: Live Tennis API.
  tennis('Live Tennis API'),

  /// Dartsjátékos: RapidAPI Darts versenynaptár.
  darts('RapidAPI Darts');

  const UpcomingSource(this.label);

  /// Felhasználónak szóló rövid név.
  final String label;

  static UpcomingSource forTarget(UpcomingEventsTarget target) =>
      switch (target.sport) {
        Sport.nba || Sport.wnba || Sport.nfl => espnTeamSchedule,
        Sport.football when target.hasEspnSoccerLeague => espnSoccerLeague,
        Sport.football => footballClub,
        Sport.tennis => tennis,
        Sport.darts => darts,
      };
}

/// Alapértelmezett eseményhossz sportáganként (az .ics exporthoz és annak
/// eldöntéséhez, hogy egy elkezdett esemény még „folyamatban” van-e).
Duration defaultEventDuration(String sport) => switch (Sport.fromLabel(sport)) {
  Sport.nfl => const Duration(hours: 3, minutes: 30),
  Sport.darts => const Duration(hours: 3),
  _ => const Duration(hours: 2),
};

/// A követett sportolók közelgő eseményei a már meglévő forrásokból:
///
/// * NBA / WNBA / NFL – ESPN nyilvános csapatmenetrend (kulcs nélkül);
/// * foci – football-data.org (kulccsal), különben az ESPN
///   csapatmenetrendje (a klub az ESPN-bajnokságok csapatlistáiból), végül
///   TheSportsDB; Liga F-nél az ESPN női bajnoksági scoreboardja; német csapatnál, ha a többi
///   forrás nem ad menetrendet, az OpenLigaDB;
/// * tenisz – Live Tennis API (kulccsal);
/// * darts – TheSportsDB következő eseményei és (kulccsal) a RapidAPI
///   versenylistája, ha dátumot is ad.
///
/// Az eredmény sportolónként [cacheLifetime] ideig (alapból 6 óra) lemezes
/// gyorsítótárból jön; hálózati hibánál a lejárt lista is visszajön.
class UpcomingEventsRepository {
  UpcomingEventsRepository({
    this._http,
    this._cacheStorage,
    DateTime Function()? clock,
    this.cacheLifetime = const Duration(hours: 6),
    this.horizon = const Duration(days: 45),
    this.maxEventsPerAthlete = 20,
  }) : _clock = clock ?? DateTime.now;

  final HttpService? _http;
  final CacheStorage? _cacheStorage;
  final DateTime Function() _clock;
  final Duration cacheLifetime;

  /// Ennél távolabbi eseményeket nem mutatunk.
  final Duration horizon;
  final int maxEventsPerAthlete;

  static const namespace = 'upcoming_events';

  JsonFileCache get _cache =>
      JsonFileCache(namespace, storage: _cacheStorage, clock: _clock);

  /// Egy sportoló eseményei; soha nem dob kivételt, a hiba az eredményben
  /// ([AthleteEventsResult.error] / [AthleteEventsResult.unavailable]) jön.
  Future<AthleteEventsResult> fetchFor(
    UpcomingEventsTarget target, {
    required SportsApiConfig config,
    bool forceRefresh = false,
  }) async {
    try {
      final cached = await _cache.getOrFetch<_Payload>(
        target.cacheKey,
        ttl: cacheLifetime,
        forceRefresh: forceRefresh,
        fetch: () => _download(target, config),
        encode: (value) => value.toJson(),
        decode: _Payload.fromJson,
      );
      return AthleteEventsResult(
        target: target,
        events: _window(cached.value.events),
        notes: cached.value.notes,
        fetchedAt: cached.fetchedAt,
        fromCache: cached.fromCache,
        stale: cached.stale,
      );
    } on UpcomingEventsUnavailable catch (error) {
      return AthleteEventsResult(target: target, unavailable: error.message);
    } catch (error) {
      return AthleteEventsResult(target: target, error: friendlyError(error));
    }
  }

  /// Előre elkészített eseménylista mentése a gyorsítótárba (tesztek,
  /// képernyőképek és offline bemutató számára).
  @visibleForTesting
  Future<void> seed(
    UpcomingEventsTarget target,
    List<UpcomingEvent> events, {
    List<String> notes = const [],
  }) async {
    await _cache.getOrFetch<_Payload>(
      target.cacheKey,
      ttl: Duration.zero,
      forceRefresh: true,
      fetch: () async => _Payload(events, notes),
      encode: (value) => value.toJson(),
      decode: _Payload.fromJson,
    );
  }

  /// Az éppen zajló vagy [horizon]-on belüli események, időrendben.
  List<UpcomingEvent> _window(List<UpcomingEvent> events) {
    final now = _clock();
    final until = now.add(horizon);
    final result =
        events
            .where(
              (event) =>
                  event.start
                      .add(defaultEventDuration(event.sport))
                      .isAfter(now) &&
                  event.start.isBefore(until),
            )
            .toList()
          ..sort((a, b) => a.start.compareTo(b.start));
    return result.take(maxEventsPerAthlete).toList(growable: false);
  }

  Future<_Payload> _download(
    UpcomingEventsTarget target,
    SportsApiConfig config,
  ) async {
    final client = SportsApiClient(
      config: config,
      http: _http,
      cacheStorage: _cacheStorage,
      clock: _clock,
    );
    return switch (UpcomingSource.forTarget(target)) {
      UpcomingSource.espnTeamSchedule => _espnTeam(
        target,
        EspnLeague.forSport(target.sport)!,
      ),
      UpcomingSource.espnSoccerLeague => _espnSoccerLeague(target, client),
      UpcomingSource.footballClub => _football(target, client),
      UpcomingSource.tennis => _tennis(target, config),
      UpcomingSource.darts => _darts(target, client),
    };
  }

  String _requireTeam(UpcomingEventsTarget target) {
    final team = target.team.trim();
    if (team.isEmpty || team.toLowerCase() == 'nincs megadva') {
      throw const UpcomingEventsUnavailable(
        'Add meg a csapatot, hogy a menetrend betöltődjön.',
      );
    }
    return team;
  }

  Future<_Payload> _espnTeam(
    UpcomingEventsTarget target,
    EspnLeague league,
  ) async {
    final teamName = _requireTeam(target);
    final espn = EspnScheduleRepository(
      http: _http,
      cacheStorage: _cacheStorage,
    );
    final team = await espn.findTeam(league, teamName);
    if (team == null) {
      throw UpcomingEventsUnavailable(
        'Az ESPN ${league.label}-csapatlistájában nincs „$teamName”.',
      );
    }
    final games = await espn.upcomingGames(league, team);
    return _Payload([
      for (final game in games)
        UpcomingEvent(
          athleteName: target.name,
          sport: target.sport.jsonValue,
          title: '${game.home} – ${game.away}',
          opponent: game.opponent,
          competition: game.competition,
          start: game.start,
          venue: game.venue,
          homeAway: game.homeAway,
          source: 'ESPN',
          url: game.url,
          timeKnown: game.timeKnown,
        ),
    ], const []);
  }

  /// Egy ESPN-bajnokság (például Liga F) teljes szezonjának scoreboardja,
  /// a csapat meccseire szűrve.
  Future<_Payload> _espnSoccerLeague(
    UpcomingEventsTarget target,
    SportsApiClient client,
  ) async {
    final team = target.espnSoccerTeam;
    if (team == null) {
      throw const UpcomingEventsUnavailable(
        'Add meg a sportoló csapatát a menetrendhez.',
      );
    }
    final today = _clock();
    final years = {today.year, today.add(horizon).year};
    final events = <Map<String, dynamic>>[];
    for (final year in years) {
      final season = await client.espnSoccerScoreboardYear(team.league, year);
      events.addAll(jsonMapList(season['events']));
    }
    final payload = {'events': events};
    final games = EspnScheduleRepository.parseEvents(
      payload,
      competitionLabel: (_) => team.competitionLabel,
      isOwnTeam: (competitor) {
        final raw = jsonMap(competitor['team']);
        return team.matches('${raw['displayName'] ?? raw['name'] ?? ''}');
      },
    );
    return _Payload([
      for (final game in games)
        UpcomingEvent(
          athleteName: target.name,
          sport: target.sport.jsonValue,
          title: '${game.home} – ${game.away}',
          opponent: game.opponent,
          competition: game.competition,
          start: game.start,
          venue: game.venue,
          homeAway: game.homeAway,
          source: 'ESPN',
          url: game.url,
          timeKnown: game.timeKnown,
        ),
    ], const []);
  }

  Future<_Payload> _football(
    UpcomingEventsTarget target,
    SportsApiClient client,
  ) async {
    final teamName = _requireTeam(target);
    final notes = <String>[];
    if (client.config.footballDataKey.isNotEmpty) {
      try {
        final teams = await client.footballDataTeams();
        final id = FootballDataRepository.parseFootballDataTeamId(
          teams,
          teamName,
        );
        if (id != null) {
          final now = _clock().toUtc();
          String date(DateTime value) =>
              value.toIso8601String().substring(0, 10);
          final data = await client.footballData('/v4/teams/$id/matches', {
            'status': 'SCHEDULED,TIMED,IN_PLAY,PAUSED',
            'dateFrom': date(now),
            'dateTo': date(now.add(horizon)),
          });
          final events = parseFootballDataFixtures(
            data,
            athleteName: target.name,
            teamId: id,
            teamName: teamName,
          );
          if (events.isNotEmpty) return _Payload(events, notes);
        }
      } catch (error) {
        notes.add('football-data.org: ${friendlyError(error)}');
      }
    }
    // ESPN (kulcs nélkül): a csapat teljes menetrendje minden sorozatból; a
    // TheSportsDB ingyenes feedje csak a következő egy meccset adja.
    try {
      final espn = EspnSoccerTeamRepository(client);
      final club = await espn.resolveClub(
        teamName,
        competition: target.sourceHints.competition,
        womensTeam: target.sourceHints.womensTeam ? true : null,
      );
      if (club != null) {
        final games = await espn.clubFixtures(club);
        if (games.isNotEmpty) {
          return _Payload([
            for (final game in games)
              UpcomingEvent(
                athleteName: target.name,
                sport: target.sport.jsonValue,
                title: '${game.home} – ${game.away}',
                opponent: game.opponent,
                competition: game.competition,
                start: game.start,
                venue: game.venue,
                homeAway: game.homeAway,
                source: 'ESPN',
                url: game.url,
                timeKnown: game.timeKnown,
              ),
          ], notes);
        }
      }
    } catch (error) {
      notes.add('ESPN: ${friendlyError(error)}');
    }
    final Map<String, dynamic> teams;
    try {
      teams = await client.theSportsDb('/searchteams.php', {
        't': footballTeamSearchTerm(teamName),
      });
    } catch (error) {
      // A TheSportsDB hibájakor a német csapatok az OpenLigaDB-ből jönnek.
      final german = await _openLiga(target, teamName, notes);
      if (german != null && german.events.isNotEmpty) return german;
      rethrow;
    }
    final teamId = FootballDataRepository.parseTheSportsDbTeamId(
      teams,
      teamName,
    );
    if (teamId == null) {
      final german = await _openLiga(target, teamName, notes);
      if (german != null) return german;
      if (notes.isNotEmpty) return _Payload(const [], notes);
      throw UpcomingEventsUnavailable(
        'A TheSportsDB nem ismeri a(z) „$teamName” csapatot.',
      );
    }
    final next = await client.theSportsDb('/eventsnext.php', {'id': teamId});
    final events = parseTheSportsDbEvents(
      next,
      athleteName: target.name,
      sport: target.sport.jsonValue,
      teamId: teamId,
    );
    if (events.isEmpty) {
      final german = await _openLiga(target, teamName, notes);
      if (german != null && german.events.isNotEmpty) return german;
    }
    return _Payload(events, notes);
  }

  /// Német csapat (Bundesliga, 2. Bundesliga, Frauen-Bundesliga) közelgő
  /// mérkőzései az OpenLigaDB-ből; `null`, ha a csapat nem német.
  Future<_Payload?> _openLiga(
    UpcomingEventsTarget target,
    String teamName,
    List<String> notes,
  ) async {
    try {
      final german = await OpenLigaDbRepository(
        http: _http,
        cacheStorage: _cacheStorage,
        clock: _clock,
      ).teamGames(teamName);
      if (german == null) return null;
      return _Payload(german.events(athleteName: target.name), notes);
    } catch (error) {
      notes.add('OpenLigaDB: ${friendlyError(error)}');
      return null;
    }
  }

  Future<_Payload> _tennis(
    UpcomingEventsTarget target,
    SportsApiConfig config,
  ) async {
    if (config.liveTennisKey.trim().isEmpty) {
      throw const UpcomingEventsUnavailable(
        'A teniszmenetrendhez Live Tennis API-kulcs kell (Adatforrások).',
      );
    }
    final data = await TennisRepository(
      config,
      http: _http,
      cacheStorage: _cacheStorage,
    ).fetch(target.name);
    return _Payload(tennisEvents(data, athleteName: target.name), const []);
  }

  Future<_Payload> _darts(
    UpcomingEventsTarget target,
    SportsApiClient client,
  ) async {
    final events = <UpcomingEvent>[];
    final notes = <String>[];
    final failures = <Object>[];
    var attempted = 1;
    try {
      final player = await client.findTheSportsDbPlayer(target.name);
      final teamId = jsonString(player?['idTeam']);
      if (teamId != null) {
        final next = await client.theSportsDb('/eventsnext.php', {
          'id': teamId,
        });
        events.addAll(
          parseTheSportsDbEvents(
            next,
            athleteName: target.name,
            sport: target.sport.jsonValue,
            teamId: teamId,
            requireAthleteName: true,
          ),
        );
      }
    } catch (error) {
      failures.add(error);
      notes.add('TheSportsDB: ${friendlyError(error)}');
    }
    if (client.config.rapidApiKey.trim().isNotEmpty) {
      attempted++;
      try {
        // Ugyanaz a 6 órás bejegyzés, mint a profil darts kártyájáé: a havi
        // 1000 kérés nem fogy kétszer.
        final payload = await client
            .cache('rapidapi_darts')
            .getOrFetch<Map<String, dynamic>>(
              'competitions_3503',
              ttl: const Duration(hours: 6),
              fetch: () => client.rapidApiDarts('/competitions/3503'),
              encode: (value) => value,
              decode: jsonMap,
            );
        events.addAll(
          parseDartsCompetitionEvents(payload.value, athleteName: target.name),
        );
      } catch (error) {
        failures.add(error);
        notes.add('RapidAPI Darts: ${friendlyError(error)}');
      }
    }
    // Ha minden forrás hibázott, ne kerüljön üres lista 6 órára a
    // gyorsítótárba: a hiba (és a régebbi mentett lista) jusson tovább.
    if (events.isEmpty && failures.length == attempted) throw failures.first;
    if (events.isEmpty && notes.isEmpty) {
      notes.add(
        'A darts ingyenes forrásai most nem adnak játékosszintű menetrendet.',
      );
    }
    return _Payload(events, notes);
  }

  // -------------------------------------------------------------------------
  // Feldolgozók (tesztelhető, tiszta függvények)
  // -------------------------------------------------------------------------

  /// football-data.org `/v4/teams/{id}/matches` még le nem játszott meccsei.
  static List<UpcomingEvent> parseFootballDataFixtures(
    Map<String, dynamic> data, {
    required String athleteName,
    required int teamId,
    required String teamName,
  }) {
    final events = <UpcomingEvent>[];
    for (final raw in jsonMapList(data['matches'])) {
      final status = jsonString(raw['status']) ?? '';
      if (const {
        'FINISHED',
        'CANCELLED',
        'POSTPONED',
        'SUSPENDED',
        'AWARDED',
      }.contains(status)) {
        continue;
      }
      final start = DateTime.tryParse(jsonString(raw['utcDate']) ?? '');
      if (start == null) continue;
      final home = jsonMap(raw['homeTeam']);
      final away = jsonMap(raw['awayTeam']);
      final isHome =
          jsonIntOrNull(home['id']) == teamId ||
          (jsonIntOrNull(away['id']) != teamId &&
              footballTeamNamesMatch(teamName, '${home['name'] ?? ''}'));
      final homeName = jsonString(home['name']) ?? 'Ismeretlen';
      final awayName = jsonString(away['name']) ?? 'Ismeretlen';
      final competition = jsonString(jsonMap(raw['competition'])['name']);
      final matchday = jsonIntOrNull(raw['matchday']);
      events.add(
        UpcomingEvent(
          athleteName: athleteName,
          sport: Sport.football.jsonValue,
          title: '$homeName – $awayName',
          opponent: isHome ? awayName : homeName,
          competition: [
            ?competition,
            if (matchday != null) '$matchday. forduló',
          ].join(' · '),
          start: start.toLocal(),
          venue: jsonString(raw['venue']),
          homeAway: isHome ? 'home' : 'away',
          source: 'football-data.org',
          // A SCHEDULED státuszú meccs időpontja még nem végleges.
          timeKnown: status != 'SCHEDULED',
        ),
      );
    }
    events.sort((a, b) => a.start.compareTo(b.start));
    return events;
  }

  /// TheSportsDB `eventsnext.php` válasza. [requireAthleteName] esetén csak
  /// azok az események maradnak, amelyekben a sportoló neve szerepel
  /// (egyéni sportágaknál a „csapat” egy egész sorozat lehet).
  static List<UpcomingEvent> parseTheSportsDbEvents(
    Map<String, dynamic> data, {
    required String athleteName,
    required String sport,
    required String teamId,
    bool requireAthleteName = false,
  }) {
    final events = <UpcomingEvent>[];
    for (final raw in jsonMapList(data['events'] ?? data['results'])) {
      final homeName = jsonString(raw['strHomeTeam']);
      final awayName = jsonString(raw['strAwayTeam']);
      final eventName = jsonString(raw['strEvent']) ?? '';
      if (requireAthleteName &&
          !normalizeAthleteName(
            eventName,
          ).contains(normalizeAthleteName(athleteName)) &&
          ![homeName, awayName].whereType<String>().any(
            (name) => athleteNamesMatch(name, athleteName),
          )) {
        continue;
      }
      final time = jsonString(raw['strTime']) ?? '';
      final start = FootballDataRepository.parseTheSportsDbEventTime(
        jsonString(raw['dateEvent']) ?? '',
        time,
      );
      if (start == null) continue;
      final isHome = jsonString(raw['idHomeTeam']) == teamId;
      final isAway = jsonString(raw['idAwayTeam']) == teamId;
      final opponent = isHome
          ? awayName
          : isAway
          ? homeName
          : null;
      final round = jsonIntOrNull(raw['intRound']);
      final id = jsonString(raw['idEvent']);
      events.add(
        UpcomingEvent(
          athleteName: athleteName,
          sport: sport,
          title: homeName != null && awayName != null
              ? '$homeName – $awayName'
              : eventName.isEmpty
              ? 'Esemény'
              : eventName,
          opponent: opponent ?? '',
          competition: [
            ?jsonString(raw['strLeague']),
            if (round != null && round > 0) '$round. forduló',
          ].join(' · '),
          start: start,
          venue: jsonString(raw['strVenue']),
          homeAway: isHome
              ? 'home'
              : isAway
              ? 'away'
              : null,
          source: 'TheSportsDB',
          url: id == null ? null : 'https://www.thesportsdb.com/event/$id',
          timeKnown: time.isNotEmpty,
        ),
      );
    }
    events.sort((a, b) => a.start.compareTo(b.start));
    return events;
  }

  /// A Live Tennis API közelgő mérkőzései és név szerinti fixture-jei
  /// (ugyanaz az ellenfél ugyanazon a napon csak egyszer).
  static List<UpcomingEvent> tennisEvents(
    TennisProfileData data, {
    required String athleteName,
  }) {
    final player = data.player;
    final events = <UpcomingEvent>[];
    final seen = <String>{};
    void add({
      required DateTime start,
      required String player1,
      required String player2,
      required String opponent,
      required String tournament,
      String? round,
      bool timeKnown = true,
    }) {
      // Névsorrend-független kulcs („Gauff Coco” = „Coco Gauff”).
      final name = (normalizeAthleteName(
        opponent,
      ).split(' ')..sort()).join(' ');
      final key = '$name|${start.year}-${start.month}-${start.day}';
      if (!seen.add(key)) return;
      events.add(
        UpcomingEvent(
          athleteName: athleteName,
          sport: Sport.tennis.jsonValue,
          title: '$player1 – $player2',
          opponent: opponent,
          competition: [tournament, ?round].join(' · '),
          start: start,
          source: 'Live Tennis API',
          timeKnown: timeKnown,
        ),
      );
    }

    for (final match in [...data.liveMatches, ...data.upcomingMatches]) {
      final start = match.scheduledTime;
      if (start == null) continue;
      add(
        start: start,
        player1: match.player1,
        player2: match.player2,
        opponent: match.opponentOf(player),
        tournament: match.tournament,
        round: match.round,
      );
    }
    for (final fixture in data.fixtures) {
      final start = fixture.eventDate;
      if (start == null) continue;
      add(
        start: start,
        player1: fixture.player1,
        player2: fixture.player2,
        opponent: fixture.opponentOf(player),
        tournament: fixture.tournament,
        round: fixture.round,
        timeKnown: start.hour != 0 || start.minute != 0,
      );
    }
    events.sort((a, b) => a.start.compareTo(b.start));
    return events;
  }

  /// A RapidAPI darts versenylistájából csak a kezdési dátummal rendelkező
  /// tételek lesznek események (a lista maga nem játékosszintű).
  static List<UpcomingEvent> parseDartsCompetitionEvents(
    Map<String, dynamic> payload, {
    required String athleteName,
  }) {
    Object? raw =
        payload['data'] ??
        payload['competitions'] ??
        payload['response'] ??
        payload['result'];
    if (raw is Map) raw = raw['data'] ?? raw['competitions'] ?? raw['items'];
    final events = <UpcomingEvent>[];
    final names = DartsRepository.parseCompetitions({'data': raw});
    final items = jsonMapList(raw);
    for (var i = 0; i < items.length && i < names.length; i++) {
      final item = items[i];
      final dateText = [
        'openDate',
        'startDate',
        'marketStartTime',
        'start',
        'date',
      ].map((key) => jsonString(item[key])).whereType<String>().firstOrNull;
      final start = DateTime.tryParse(dateText ?? '');
      if (start == null) continue;
      events.add(
        UpcomingEvent(
          athleteName: athleteName,
          sport: Sport.darts.jsonValue,
          title: names[i].name,
          competition: 'Versenynaptár · a részvétel nem megerősített',
          start: start.toLocal(),
          source: 'RapidAPI Darts',
          timeKnown: dateText!.contains('T'),
        ),
      );
    }
    return events;
  }
}

class _Payload {
  const _Payload(this.events, this.notes);
  final List<UpcomingEvent> events;
  final List<String> notes;

  Map<String, Object?> toJson() => {
    'events': [for (final event in events) event.toJson()],
    'notes': notes,
  };

  static _Payload fromJson(Object? json) {
    final map = jsonMap(json);
    if (map['events'] is! List) throw const FormatException('events');
    return _Payload(
      jsonList(
        map['events'],
      ).map(UpcomingEvent.fromJson).whereType<UpcomingEvent>().toList(),
      jsonList(map['notes']).map((note) => '$note').toList(),
    );
  }
}

// ---------------------------------------------------------------------------
// Összesítés, szűrés és napi csoportosítás
// ---------------------------------------------------------------------------

/// Az összes sportoló eseménye egy listában: időrendben (azonos kezdésnél
/// sportolónév szerint), a [sport] (`null` = minden sportág) és [athlete]
/// szűrővel („Mind” = nincs szűrés), a már véget ért események nélkül.
List<UpcomingEvent> mergeUpcomingEvents(
  Iterable<AthleteEventsResult> results, {
  required DateTime now,
  Sport? sport,
  String athlete = 'Mind',
}) {
  final seen = <String>{};
  final events = [
    for (final result in results)
      for (final event in result.events)
        if ((sport == null || event.sport == sport.jsonValue) &&
            (athlete == 'Mind' || event.athleteName == athlete) &&
            event.start.add(defaultEventDuration(event.sport)).isAfter(now) &&
            seen.add(
              '${event.athleteName}|${event.start.toUtc().toIso8601String()}|${event.title}',
            ))
          event,
  ];
  events.sort((a, b) {
    final byTime = a.start.compareTo(b.start);
    return byTime != 0
        ? byTime
        : normalizeAthleteName(
            a.athleteName,
          ).compareTo(normalizeAthleteName(b.athleteName));
  });
  return events;
}

/// Egy nap eseményei a naptár listájához.
class UpcomingDayGroup {
  const UpcomingDayGroup({
    required this.day,
    required this.label,
    required this.events,
  });

  /// A nap (helyi idő, éjfél).
  final DateTime day;

  /// „Ma”, „Holnap” vagy „okt. 3., péntek”.
  final String label;
  final List<UpcomingEvent> events;
}

/// Napcímke: „Ma”, „Holnap”, különben „okt. 3., péntek” (más évben
/// évszámmal: „2027. jan. 5., kedd”). A már elkezdett, tegnapi esemény
/// „Tegnap” címkét kap.
String calendarDayLabel(DateTime day, DateTime now) {
  ensureHungarianDateFormatting();
  final date = DateTime(day.year, day.month, day.day);
  final today = DateTime(now.year, now.month, now.day);
  final diff = DateTime.utc(
    date.year,
    date.month,
    date.day,
  ).difference(DateTime.utc(today.year, today.month, today.day)).inDays;
  if (diff == 0) return 'Ma';
  if (diff == 1) return 'Holnap';
  if (diff == -1) return 'Tegnap';
  final dayPart = date.year == today.year
      ? DateFormat.MMMd(courtboardLocale).format(date)
      : DateFormat.yMMMd(courtboardLocale).format(date);
  return '$dayPart, ${DateFormat.EEEE(courtboardLocale).format(date)}';
}

/// Az (időrendbe rendezett) események napok szerint csoportosítva.
List<UpcomingDayGroup> groupEventsByDay(
  List<UpcomingEvent> events,
  DateTime now,
) {
  final groups = <UpcomingDayGroup>[];
  for (final event in events) {
    final local = event.start.toLocal();
    final day = DateTime(local.year, local.month, local.day);
    if (groups.isEmpty || groups.last.day != day) {
      groups.add(
        UpcomingDayGroup(
          day: day,
          label: calendarDayLabel(day, now),
          events: [event],
        ),
      );
    } else {
      groups.last.events.add(event);
    }
  }
  return groups;
}

// ---------------------------------------------------------------------------
// Vezérlő: fokozatos betöltés a felület számára
// ---------------------------------------------------------------------------

/// A naptár állapota: sportolónként külön, fokozatosan érkező eredmények.
/// Egy sportoló hibája nem akasztja meg a többit. Minden sikeres betöltés
/// után a legközelebbi esemény a [AthleteHighlightStore]-ba kerül, így a
/// nyitóoldal „Mai fókusz” blokkja is látja.
class UpcomingEventsController extends ChangeNotifier {
  UpcomingEventsController({
    UpcomingEventsRepository? repository,
    this._highlightStore,
    this.concurrency = 3,
    DateTime Function()? clock,
  }) : repository = repository ?? UpcomingEventsRepository(),
       _clock = clock ?? DateTime.now;

  final UpcomingEventsRepository repository;
  final AthleteHighlightStore? _highlightStore;
  final int concurrency;
  final DateTime Function() _clock;

  final Map<String, AthleteEventsResult> _results = {};

  /// Betöltés alatt álló sportoló → a betöltést indító [load] sorszáma.
  final Map<String, int> _loading = {};
  bool _disposed = false;

  /// A kérés sorszáma: egy újabb [load] után a régi válaszok nem írnak.
  int _generation = 0;

  AthleteHighlightStore get _highlights =>
      _highlightStore ?? AthleteHighlightStore.shared;

  /// Sportolónév → legutóbbi eredmény.
  Map<String, AthleteEventsResult> get results => Map.unmodifiable(_results);

  /// Az éppen betöltés alatt álló sportolók.
  Set<String> get loading => Set.unmodifiable(_loading.keys);
  bool get isLoading => _loading.isNotEmpty;

  /// Az összes közelgő esemény a szűrőkkel.
  List<UpcomingEvent> events({Sport? sport, String athlete = 'Mind'}) =>
      mergeUpcomingEvents(
        _results.values,
        now: _clock(),
        sport: sport,
        athlete: athlete,
      );

  /// A [targets] eseményeinek betöltése legfeljebb [concurrency] párhuzamos
  /// sportolóval. Már betöltött (és nem változott) sportolót csak [force]
  /// esetén kér újra; a listából kikerült sportolók eredménye törlődik.
  Future<void> load(
    List<UpcomingEventsTarget> targets, {
    required SportsApiConfig config,
    bool force = false,
  }) async {
    final generation = force ? ++_generation : _generation;
    final names = {for (final target in targets) target.name};
    final removed = _results.keys.where((name) => !names.contains(name));
    var changed = false;
    for (final name in removed.toList()) {
      _results.remove(name);
      changed = true;
    }
    final queue = [
      for (final target in targets)
        if (force ||
            (!_loading.containsKey(target.name) &&
                (_results[target.name]?.target != target ||
                    // Hiányzó kulcs vagy csapat: olcsó újraellenőrizni
                    // (például ha közben megadták a kulcsot).
                    _results[target.name]?.unavailable != null)))
          target,
    ];
    for (final target in queue) {
      changed |= _loading[target.name] != generation;
      _loading[target.name] = generation;
    }
    if (changed) _notify();
    if (queue.isEmpty) return;

    var next = 0;
    Future<void> worker() async {
      while (next < queue.length) {
        final target = queue[next++];
        final result = await repository.fetchFor(
          target,
          config: config,
          forceRefresh: force,
        );
        if (_disposed) return;
        // Egy közben indított kényszerített frissítés felülírja ezt a kérést.
        if (_loading[target.name] != generation) continue;
        _loading.remove(target.name);
        if (generation != _generation) {
          _notify();
          continue;
        }
        _results[target.name] = result;
        if (result.events.isNotEmpty) {
          // A mentés előbb lezárul, így a jelzésre olvasó nyitóoldal már
          // az új „következő eseményt” látja. A `record` soha nem dob.
          final soonest = result.events.first;
          await _highlights.record(target.name, [
            HighlightEvent(
              date: soonest.start,
              title: soonest.matchup,
              outcome: 'upcoming',
            ),
          ]);
          if (_disposed) return;
        }
        _notify();
      }
    }

    await Future.wait([
      for (var i = 0; i < concurrency.clamp(1, queue.length); i++) worker(),
    ]);
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
