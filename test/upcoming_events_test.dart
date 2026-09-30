import 'package:courtboard/domain/athlete_source_hints.dart';
import 'package:courtboard/domain/sport.dart';
import 'package:courtboard/data/athlete_highlights.dart';
import 'package:courtboard/data/http_util.dart';
import 'package:courtboard/data/json_file_cache.dart';
import 'package:courtboard/data/live_tennis.dart';
import 'package:courtboard/data/sports_api.dart';
import 'package:courtboard/data/upcoming_events.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_http.dart';

const _jokic = UpcomingEventsTarget(
  name: 'Nikola Jokić',
  sport: Sport.nba,
  team: 'Denver Nuggets',
);

const _teamsPath = '/apis/site/v2/sports/basketball/nba/teams';
const _schedulePath = '/apis/site/v2/sports/basketball/nba/teams/7/schedule';

UpcomingEvent _event(
  String athlete,
  DateTime start, {
  String sport = 'NBA',
  String opponent = 'Utah Jazz',
}) => UpcomingEvent(
  athleteName: athlete,
  sport: sport,
  title: 'Denver Nuggets – $opponent',
  opponent: opponent,
  competition: 'NBA · Alapszakasz',
  start: start,
  source: 'ESPN',
);

void main() {
  // A fixture-meccsek 2026. okt. 23. és 27. közöttiek.
  final now = DateTime.utc(2026, 10, 20, 12).toLocal();
  late DateTime clock;
  setUp(() => clock = now);

  FakeHttpService nbaHttp() => FakeHttpService({
    _teamsPath: fixture('espn_nba_teams.json'),
    _schedulePath: fixture('espn_nba_schedule_den.json'),
  });

  UpcomingEventsRepository repository(
    FakeHttpService http, {
    CacheStorage? storage,
  }) => UpcomingEventsRepository(
    http: http,
    cacheStorage: storage ?? MemoryCacheStorage(clock: () => clock),
    clock: () => clock,
  );

  group('UpcomingEventsRepository', () {
    test(
      'NBA: ESPN-menetrendből események, 6 órás sportolónkénti cache',
      () async {
        final http = nbaHttp();
        final repo = repository(http);

        final result = await repo.fetchFor(
          _jokic,
          config: const SportsApiConfig(),
        );

        expect(result.error, isNull);
        expect(result.unavailable, isNull);
        expect(result.events, hasLength(3));
        final first = result.events.first;
        expect(first.athleteName, 'Nikola Jokić');
        expect(first.title, 'Oklahoma City Thunder – Denver Nuggets');
        expect(first.opponent, 'Oklahoma City Thunder');
        expect(first.matchup, '@ Oklahoma City Thunder');
        expect(first.source, 'ESPN');
        expect(first.url, startsWith('https://www.espn.com/nba/game/'));
        expect(http.requests, hasLength(2));

        // 5 óra múlva gyorsítótárból, hálózati kérés nélkül.
        clock = now.add(const Duration(hours: 5));
        final cached = await repo.fetchFor(
          _jokic,
          config: const SportsApiConfig(),
        );
        expect(cached.fromCache, isTrue);
        expect(cached.events, hasLength(3));
        expect(http.requests, hasLength(2));

        // 7 óra múlva újra letölt (a csapatlista 7 napos, azt nem kéri újra).
        clock = now.add(const Duration(hours: 7));
        await repo.fetchFor(_jokic, config: const SportsApiConfig());
        expect(http.requests, hasLength(3));
        expect(http.requests.last.path, _schedulePath);
      },
    );

    test('a már véget ért és a túl távoli események kimaradnak', () async {
      final repo = repository(nbaHttp());
      await repo.fetchFor(_jokic, config: const SportsApiConfig());

      // Okt. 25. 02:00 UTC: az okt. 23-i meccs lement, a 25-i 01:00-s még
      // tart (2 órás alapértelmezett hossz).
      clock = DateTime.utc(2026, 10, 25, 2).toLocal();
      final later = await repo.fetchFor(
        _jokic,
        config: const SportsApiConfig(),
      );
      expect(later.events.map((e) => e.opponent), [
        'New Orleans Pelicans',
        'Golden State Warriors',
      ]);

      final shortHorizon = UpcomingEventsRepository(
        http: nbaHttp(),
        cacheStorage: MemoryCacheStorage(),
        clock: () => now,
        horizon: const Duration(days: 5),
      );
      final soon = await shortHorizon.fetchFor(
        _jokic,
        config: const SportsApiConfig(),
      );
      expect(soon.events, hasLength(2));
    });

    test('hálózati hibánál a lejárt lista jön, stale jelzéssel', () async {
      final storage = MemoryCacheStorage(clock: () => clock);
      await repository(
        nbaHttp(),
        storage: storage,
      ).fetchFor(_jokic, config: const SportsApiConfig());

      clock = now.add(const Duration(hours: 8));
      final offline = FakeHttpService({
        _schedulePath: CourtboardHttpException(provider: 'ESPN'),
        _teamsPath: fixture('espn_nba_teams.json'),
      });
      final result = await repository(
        offline,
        storage: storage,
      ).fetchFor(_jokic, config: const SportsApiConfig());
      expect(result.stale, isTrue);
      expect(result.events, isNotEmpty);
      expect(result.error, isNull);
    });

    test('hiba cache nélkül: barátságos, sportolónkénti hibaüzenet', () async {
      final result = await repository(
        FakeHttpService({
          _teamsPath: CourtboardHttpException(provider: 'ESPN'),
        }),
      ).fetchFor(_jokic, config: const SportsApiConfig());
      expect(result.events, isEmpty);
      expect(result.error, 'Nincs internetkapcsolat.');
    });

    test(
      'ismeretlen csapat, hiányzó csapat, kulcs nélküli tenisz: megjegyzés',
      () async {
        final http = nbaHttp();
        final repo = repository(http);
        final unknown = await repo.fetchFor(
          const UpcomingEventsTarget(
            name: 'Valaki',
            sport: Sport.nba,
            team: 'Chicago Bulls',
          ),
          config: const SportsApiConfig(),
        );
        expect(unknown.unavailable, contains('Chicago Bulls'));

        final noTeam = await repo.fetchFor(
          const UpcomingEventsTarget(name: 'Valaki', sport: Sport.wnba),
          config: const SportsApiConfig(),
        );
        expect(noTeam.unavailable, contains('csapatot'));

        final requestsBefore = http.requests.length;
        final tennis = await repo.fetchFor(
          const UpcomingEventsTarget(name: 'Iga Swiatek', sport: Sport.tennis),
          config: const SportsApiConfig(),
        );
        expect(tennis.unavailable, contains('Live Tennis API'));
        expect(http.requests.length, requestsBefore);
      },
    );

    test('foci kulcs nélkül: TheSportsDB következő meccsei', () async {
      final http = FakeHttpService({
        '/api/v1/json/123/searchteams.php': {
          'teams': [
            {'idTeam': '133739', 'strTeam': 'Barcelona', 'strSport': 'Soccer'},
          ],
        },
        '/api/v1/json/123/eventsnext.php': {
          'events': [
            {
              'idEvent': '2506239',
              'strEvent': 'Barcelona vs Getafe',
              'strLeague': 'Spanish La Liga',
              'dateEvent': '2026-10-24',
              'strTime': '16:30:00',
              'idHomeTeam': '133739',
              'idAwayTeam': '133731',
              'strHomeTeam': 'Barcelona',
              'strAwayTeam': 'Getafe',
              'strVenue': 'Spotify Camp Nou',
              'intRound': '8',
            },
          ],
        },
      });
      final result = await repository(http).fetchFor(
        const UpcomingEventsTarget(
          name: 'Lamine Yamal',
          sport: Sport.football,
          team: 'FC Barcelona',
        ),
        config: const SportsApiConfig(),
      );
      expect(result.events, hasLength(1));
      final event = result.events.single;
      expect(event.opponent, 'Getafe');
      expect(event.homeAway, 'home');
      expect(event.competition, 'Spanish La Liga · 8. forduló');
      expect(event.venue, 'Spotify Camp Nou');
      expect(event.start, DateTime.utc(2026, 10, 24, 16, 30).toLocal());
      expect(event.url, 'https://www.thesportsdb.com/event/2506239');
      expect(http.requests.first.queryParameters['t'], 'Barcelona');
    });

    test(
      'Liga F-profil: női Barcelona az ESPN esp.w.1 scoreboardjáról',
      () async {
        Map<String, dynamic> team(String id, String name, String side) => {
          'homeAway': side,
          'team': {'id': id, 'displayName': name},
        };
        final http = FakeHttpService({
          '/apis/site/v2/sports/soccer/esp.w.1/scoreboard': {
            'events': [
              {
                'id': '1',
                'date': '2026-10-25T11:00Z',
                'competitions': [
                  {
                    'status': {
                      'type': {'state': 'pre', 'completed': false},
                    },
                    'competitors': [
                      team('1', 'Real Madrid Femenino', 'home'),
                      team('2', 'Barcelona Femení', 'away'),
                    ],
                  },
                ],
              },
              {
                'id': '2',
                'date': '2026-10-26T11:00Z',
                'competitions': [
                  {
                    'competitors': [
                      team('3', 'Sevilla', 'home'),
                      team('4', 'Levante', 'away'),
                    ],
                  },
                ],
              },
            ],
          },
        });
        final result = await repository(http).fetchFor(
          const UpcomingEventsTarget(
            name: 'Aitana Bonmatí',
            sport: Sport.football,
            team: 'FC Barcelona',
            sourceHints: AthleteSourceHints.ligaF,
          ),
          config: const SportsApiConfig(),
        );
        expect(result.events.map((e) => e.opponent), ['Real Madrid Femenino']);
        expect(result.events.single.competition, 'Liga F');
        expect(result.events.single.homeAway, 'away');
      },
    );

    test('football-data.org menetrend feldolgozása', () {
      final events = UpcomingEventsRepository.parseFootballDataFixtures(
        {
          'matches': [
            {
              'utcDate': '2026-10-25T15:00:00Z',
              'status': 'TIMED',
              'matchday': 9,
              'competition': {'name': 'Premier League'},
              'homeTeam': {'id': 57, 'name': 'Arsenal FC'},
              'awayTeam': {'id': 64, 'name': 'Liverpool FC'},
            },
            {
              'utcDate': '2026-10-21T19:00:00Z',
              'status': 'SCHEDULED',
              'competition': {'name': 'UEFA Champions League'},
              'homeTeam': {'id': 64, 'name': 'Liverpool FC'},
              'awayTeam': {'id': 5, 'name': 'FC Bayern München'},
            },
            {
              'utcDate': '2026-10-01T19:00:00Z',
              'status': 'FINISHED',
              'homeTeam': {'id': 64, 'name': 'Liverpool FC'},
              'awayTeam': {'id': 1, 'name': 'Everton FC'},
            },
          ],
        },
        athleteName: 'Mohamed Salah',
        teamId: 64,
        teamName: 'Liverpool FC',
      );
      expect(events.map((e) => e.opponent), [
        'FC Bayern München',
        'Arsenal FC',
      ]);
      expect(events.first.homeAway, 'home');
      expect(events.first.timeKnown, isFalse);
      expect(events.last.homeAway, 'away');
      expect(events.last.competition, 'Premier League · 9. forduló');
    });

    test(
      'tenisz: élő/közelgő meccs és fixture ugyanazzal az ellenféllel egyszer',
      () {
        final data = TennisProfileData(
          player: const TennisPlayer(id: 7, name: 'Iga Swiatek'),
          upcomingMatches: [
            TennisMatch(
              id: 1,
              tournament: 'Wuhan',
              status: 'upcoming',
              player1: 'Iga Swiatek',
              player2: 'Coco Gauff',
              player1Id: 7,
              round: 'QF',
              scheduledTime: DateTime(2026, 10, 22, 12),
            ),
          ],
          fixtures: [
            TennisFixture(
              id: 2,
              tournament: 'Wuhan',
              player1: 'Gauff Coco',
              player2: 'Swiatek Iga',
              eventDate: DateTime(2026, 10, 22),
            ),
            TennisFixture(
              id: 3,
              tournament: 'WTA Finals',
              player1: 'Swiatek Iga',
              player2: 'Sabalenka Aryna',
              eventDate: DateTime(2026, 11, 2),
            ),
          ],
        );
        final events = UpcomingEventsRepository.tennisEvents(
          data,
          athleteName: 'Iga Świątek',
        );
        expect(events.map((e) => e.opponent), [
          'Coco Gauff',
          'Sabalenka Aryna',
        ]);
        expect(events.first.competition, 'Wuhan · QF');
        expect(events.last.timeKnown, isFalse);
      },
    );

    test(
      'darts: csak a dátummal rendelkező versenyek, és a játékos TheSportsDB-eseményei',
      () {
        final competitions =
            UpcomingEventsRepository.parseDartsCompetitionEvents({
              'data': [
                {
                  'competitionName': 'World Grand Prix',
                  'openDate': '2026-10-05T18:00:00Z',
                },
                {'competitionName': 'Premier League'},
                {'name': 'Grand Slam', 'startDate': '2026-11-08'},
              ],
            }, athleteName: 'Luke Humphries');
        expect(competitions.map((e) => e.title), [
          'World Grand Prix',
          'Grand Slam',
        ]);
        expect(competitions.first.timeKnown, isTrue);
        expect(competitions.last.timeKnown, isFalse);
        expect(competitions.first.opponent, isEmpty);

        final events = UpcomingEventsRepository.parseTheSportsDbEvents(
          {
            'events': [
              {
                'idEvent': '9',
                'strEvent': 'Luke Humphries vs Luke Littler',
                'dateEvent': '2026-10-05',
                'strTime': '20:00:00',
                'strLeague': 'World Grand Prix',
              },
              {
                'idEvent': '10',
                'strEvent': 'Gerwyn Price vs Rob Cross',
                'dateEvent': '2026-10-05',
                'strTime': '21:00:00',
              },
            ],
          },
          athleteName: 'Luke Humphries',
          sport: 'Darts',
          teamId: '136716',
          requireAthleteName: true,
        );
        expect(events.map((e) => e.title), ['Luke Humphries vs Luke Littler']);
      },
    );
  });

  group('összesítés és napok', () {
    AthleteEventsResult result(String name, List<UpcomingEvent> events) =>
        AthleteEventsResult(
          target: UpcomingEventsTarget(name: name, sport: Sport.nba),
          events: events,
        );

    test('időrend, azonos kezdésnél név szerint, szűrők és duplikációk', () {
      final start = DateTime(2026, 10, 21, 19);
      final results = [
        result('Zsolt', [_event('Zsolt', start)]),
        result('Anna', [
          _event('Anna', start.add(const Duration(days: 1))),
          _event('Anna', start),
          _event('Anna', start), // duplikátum
        ]),
        result('Béla', [
          _event('Béla', start.subtract(const Duration(days: 2))), // lement
          _event('Béla', start.add(const Duration(hours: 2)), sport: 'NFL'),
        ]),
      ];
      final merged = mergeUpcomingEvents(results, now: now);
      expect(merged.map((e) => '${e.athleteName} ${e.start.day}'), [
        'Anna 21',
        'Zsolt 21',
        'Béla 21',
        'Anna 22',
      ]);
      expect(
        mergeUpcomingEvents(
          results,
          now: now,
          sport: Sport.nfl,
        ).single.athleteName,
        'Béla',
      );
      expect(
        mergeUpcomingEvents(results, now: now, athlete: 'Anna'),
        hasLength(2),
      );
    });

    test('napcímkék: Ma, Holnap, majd „okt. 3., szombat”', () {
      final today = DateTime(2026, 9, 30, 10);
      expect(calendarDayLabel(DateTime(2026, 9, 30), today), 'Ma');
      expect(calendarDayLabel(DateTime(2026, 10, 1), today), 'Holnap');
      expect(
        calendarDayLabel(DateTime(2026, 10, 3), today),
        'okt. 3., szombat',
      );
      expect(
        calendarDayLabel(DateTime(2027, 1, 5), today),
        '2027. jan. 5., kedd',
      );
    });

    test('csoportosítás napok szerint, helyi idő alapján', () {
      final today = DateTime(2026, 9, 30, 10);
      final groups = groupEventsByDay([
        _event('A', DateTime(2026, 9, 30, 20)),
        _event('B', DateTime(2026, 9, 30, 23, 30)),
        _event('C', DateTime(2026, 10, 1, 1)),
        _event('D', DateTime(2026, 10, 3, 18)),
      ], today);
      expect(groups.map((g) => g.label), ['Ma', 'Holnap', 'okt. 3., szombat']);
      expect(groups.first.events, hasLength(2));
    });

    test('UpcomingEvent JSON oda-vissza', () {
      final event = UpcomingEvent(
        athleteName: 'Nikola Jokić',
        sport: 'NBA',
        title: 'Denver Nuggets – Utah Jazz',
        opponent: 'Utah Jazz',
        competition: 'NBA · Alapszakasz',
        start: DateTime.utc(2026, 10, 23, 1, 30).toLocal(),
        venue: 'Ball Arena, Denver',
        homeAway: 'home',
        source: 'ESPN',
        url: 'https://www.espn.com/nba/game/_/gameId/1',
        timeKnown: false,
      );
      final copy = UpcomingEvent.fromJson(event.toJson())!;
      expect(copy.start, event.start);
      expect(copy.venue, event.venue);
      expect(copy.homeAway, 'home');
      expect(copy.timeKnown, isFalse);
      expect(copy.matchup, 'vs. Utah Jazz');
      expect(UpcomingEvent.fromJson({'title': 'x'}), isNull);
    });
  });

  group('UpcomingEventsController', () {
    test(
      'fokozatos betöltés, sportolónkénti hiba, kiemelés a „Mai fókusz”-hoz',
      () async {
        final storage = MemoryCacheStorage(clock: () => clock);
        final highlights = AthleteHighlightStore(
          storage: storage,
          clock: () => clock,
        );
        final controller = UpcomingEventsController(
          repository: repository(nbaHttp(), storage: storage),
          highlightStore: highlights,
          clock: () => clock,
        );
        addTearDown(controller.dispose);
        var notifications = 0;
        controller.addListener(() => notifications++);

        final loading = controller.load([
          _jokic,
          const UpcomingEventsTarget(name: 'Iga Swiatek', sport: Sport.tennis),
          const UpcomingEventsTarget(
            name: 'Valaki',
            sport: Sport.nba,
            team: 'Chicago Bulls',
          ),
        ], config: const SportsApiConfig());
        expect(controller.isLoading, isTrue);
        await loading;

        expect(controller.isLoading, isFalse);
        expect(notifications, greaterThanOrEqualTo(4));
        expect(controller.results['Nikola Jokić']?.events, hasLength(3));
        expect(controller.results['Iga Swiatek']?.unavailable, isNotNull);
        expect(controller.results['Valaki']?.unavailable, isNotNull);
        expect(controller.events(), hasLength(3));
        expect(controller.events(sport: Sport.tennis), isEmpty);

        final highlight = await highlights.read('Nikola Jokić');
        expect(highlight?.upcoming(clock)?.title, '@ Oklahoma City Thunder');
        expect(
          highlight?.next?.date,
          DateTime.utc(2026, 10, 23, 1, 30).toLocal(),
        );

        // Újabb (nem kényszerített) betöltés: a kész sportolót nem kéri újra,
        // az eltávolított sportoló eredménye törlődik.
        await controller.load([_jokic], config: const SportsApiConfig());
        expect(controller.results.keys, ['Nikola Jokić']);
      },
    );
  });
}
