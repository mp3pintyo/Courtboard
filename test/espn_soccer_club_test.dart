// Az ESPN-klubforrás (csapatfeloldás a bajnoki csapatlistákból, lejátszott
// és közelgő mérkőzések a csapatmenetrendből) és a csapatmérkőzések
// forrássorrendjének tesztjei. A fixture-ök valós ESPN / TheSportsDB
// válaszokból (2026-09-30) rövidítve készültek: az Inter Miami 2026. 09. 27-i
// idegenbeli vereségét (Columbus Crew 2–1) a TheSportsDB ingyenes
// `eventslast.php` feedje nem adja, csak a szept. 20-i hazai meccset.
import 'package:courtboard/data/athlete_highlights.dart';
import 'package:courtboard/data/athlete_watcher.dart';
import 'package:courtboard/data/espn_soccer_team.dart';
import 'package:courtboard/data/football_data.dart';
import 'package:courtboard/data/http_util.dart';
import 'package:courtboard/data/json_file_cache.dart';
import 'package:courtboard/data/live_scores.dart';
import 'package:courtboard/data/news.dart';
import 'package:courtboard/data/sports_api.dart';
import 'package:courtboard/data/upcoming_events.dart';
import 'package:courtboard/domain/sport.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_http.dart';

const _espn = '/apis/site/v2/sports/soccer';
const _usaTeams = '$_espn/usa.1/teams';
const _miaSchedule = '$_espn/all/teams/20232/schedule';
const _miaFixtures = '$_miaSchedule?fixture=true';
const _tsdb = '/api/v1/json/123';

Map<String, Object> _espnRoutes() => {
  _usaTeams: fixture('espn_soccer_teams_usa1.json'),
  _miaSchedule: fixture('espn_soccer_schedule_mia.json'),
  _miaFixtures: fixture('espn_soccer_fixtures_mia.json'),
};

Map<String, Object> _theSportsDbRoutes() => {
  '$_tsdb/searchteams.php': fixture('thesportsdb_searchteams_mia.json'),
  '$_tsdb/eventslast.php': fixture('thesportsdb_eventslast_mia.json'),
  '$_tsdb/eventsnext.php': fixture('thesportsdb_eventsnext_mia.json'),
};

const _miami = EspnSoccerClub(
  league: 'usa.1',
  leagueLabel: 'MLS',
  id: '20232',
  displayName: 'Inter Miami CF',
  abbreviation: 'MIA',
);

void main() {
  final now = DateTime.utc(2026, 9, 30, 10).toLocal();
  late DateTime clock;
  late MemoryCacheStorage storage;

  setUp(() {
    clock = now;
    storage = MemoryCacheStorage(clock: () => clock);
  });

  SportsApiClient client(FakeHttpService http) => SportsApiClient(
    config: const SportsApiConfig(),
    http: http,
    cacheStorage: storage,
    clock: () => clock,
  );

  EspnSoccerTeamRepository espn(FakeHttpService http) =>
      EspnSoccerTeamRepository(client(http));

  FootballDataRepository football(FakeHttpService http) =>
      FootballDataRepository(client(http));

  group('csapatfeloldás', () {
    final teams = fixture('espn_soccer_teams_usa1.json');
    const mls = EspnSoccerLeague('usa.1', 'MLS');

    test('szigorú névegyezés: teljes név, rövid név, rövidítés', () {
      for (final name in ['Inter Miami', 'Inter Miami CF', 'MIA', 'Miami']) {
        final club = EspnSoccerTeamRepository.findClubIn(teams, mls, name);
        expect(club?.id, '20232', reason: name);
        expect(club?.league, 'usa.1');
        expect(club?.displayName, 'Inter Miami CF');
      }
      expect(
        EspnSoccerTeamRepository.findClubIn(teams, mls, 'Columbus Crew')?.id,
        '183',
      );
    });

    test('részleges név nem egyezik (nincs laza találat)', () {
      for (final name in ['Inter', 'Crew', 'United', 'FC', '']) {
        expect(
          EspnSoccerTeamRepository.findClubIn(teams, mls, name),
          isNull,
          reason: name,
        );
      }
    });

    test('keresési sorrend: tipp szerinti liga elöl, női csapatnál a női '
        'bajnokságok', () {
      final order = EspnSoccerTeamRepository.leagueSearchOrder();
      expect(order.first.slug, 'usa.1');
      expect(
        order.map((league) => league.slug),
        containsAll([
          'usa.1',
          'eng.1',
          'esp.1',
          'ger.1',
          'ita.1',
          'fra.1',
          'por.1',
          'ned.1',
          'mex.1',
          'bra.1',
          'arg.1',
          'ksa.1',
          'tur.1',
          'sco.1',
          'bel.1',
          'usa.nwsl',
          'eng.w.1',
          'esp.w.1',
        ]),
      );
      // A férfi bajnokságok a női bajnokságok előtt.
      expect(order.last.womens, isTrue);
      expect(
        EspnSoccerTeamRepository.leagueSearchOrder(
          competition: 'Premier League',
        ).first.slug,
        'eng.1',
      );
      final womens = EspnSoccerTeamRepository.leagueSearchOrder(
        womensTeam: true,
      );
      expect(womens.every((league) => league.womens), isTrue);
      expect(
        EspnSoccerTeamRepository.leagueSearchOrder(
          competition: 'Liga F',
        ).first.slug,
        'esp.w.1',
      );
    });

    test('az első találatnál megáll, és 7 napig gyorsítótárból jön', () async {
      final http = FakeHttpService(_espnRoutes());
      final club = await espn(http).resolveClub('Inter Miami');
      expect(club, isNotNull);
      expect(club!.league, 'usa.1');
      expect(club.id, '20232');
      expect(club.leagueLabel, 'MLS');
      expect(http.requests.map((uri) => uri.path), [_usaTeams]);

      http.requests.clear();
      clock = now.add(const Duration(days: 6));
      expect((await espn(http).resolveClub('Inter Miami'))?.id, '20232');
      expect(http.requests, isEmpty);
    });

    test('a sikertelen keresés 24 óráig nem ismétlődik', () async {
      // Csak az MLS-lista létezik; a többi liga 404 (kihagyja).
      final http = FakeHttpService(_espnRoutes());
      expect(await espn(http).resolveClub('Ferencvárosi TC'), isNull);
      final scanned = http.requests.length;
      expect(scanned, EspnSoccerTeamRepository.leagueSearchOrder().length);

      http.requests.clear();
      clock = now.add(const Duration(hours: 23));
      expect(await espn(http).resolveClub('Ferencvárosi TC'), isNull);
      expect(http.requests, isEmpty);

      // 24 óra után újra keres (a csapatlisták 7 napig gyorsítótárban).
      clock = now.add(const Duration(hours: 25));
      expect(await espn(http).resolveClub('Ferencvárosi TC'), isNull);
      expect(http.requests, hasLength(scanned - 1));
      expect(http.requests.map((uri) => uri.path), isNot(contains(_usaTeams)));
    });

    test('hálózati hibánál nem ment „nincs találat” bejegyzést', () async {
      final routes = _espnRoutes()
        ..[_usaTeams] = CourtboardHttpException(
          provider: 'ESPN',
          statusCode: 503,
        );
      final http = FakeHttpService(routes);
      await expectLater(
        espn(http).resolveClub('Inter Miami'),
        throwsA(isA<CourtboardHttpException>()),
      );
      // Az első nem-404 hibánál abbahagyja a keresést.
      expect(http.requests, hasLength(1));

      routes[_usaTeams] = fixture('espn_soccer_teams_usa1.json');
      expect((await espn(http).resolveClub('Inter Miami'))?.id, '20232');
    });
  });

  group('menetrend-feldolgozás', () {
    test('lejátszott meccsek: csak befejezett, legújabb elöl, hazai/idegen, '
        'sorozat', () {
      final games = EspnSoccerTeamRepository.parseClubResults(
        fixture('espn_soccer_schedule_mia.json'),
        _miami,
      );
      expect(games, hasLength(7));
      final last = games.first;
      expect(last.date, DateTime.utc(2026, 9, 27, 23));
      expect(last.opponent, 'Columbus Crew');
      expect(last.home, isFalse);
      expect(last.score, '1–2');
      expect(last.result, 'VERESÉG');
      expect(last.competition, 'MLS');
      expect(last.league, 'usa.1');
      expect(last.eventId, isNotNull);
      final previous = games[1];
      expect(previous.date, DateTime.utc(2026, 9, 20, 23));
      expect(previous.opponent, 'San Diego FC');
      expect(previous.home, isTrue);
      expect(previous.result, 'DÖNTETLEN');
      // A kupameccs is látszik, a saját sorozatnevével.
      final cup = games[2];
      expect(cup.opponent, 'Cruz Azul');
      expect(cup.competition, 'Campeones Cup');
      expect(cup.result, 'GYŐZELEM');
      for (var i = 1; i < games.length; i++) {
        expect(games[i - 1].date.isAfter(games[i].date), isTrue);
      }
    });

    test('tizenegyespárbaj: döntetlen rendes játékidő, a párbaj dönt', () {
      final games = EspnSoccerTeamRepository.parseClubResults(
        fixture('espn_soccer_schedule_rsl_pen.json'),
        const EspnSoccerClub(
          league: 'usa.1',
          leagueLabel: 'MLS',
          id: '4771',
          displayName: 'Real Salt Lake',
        ),
      );
      final game = games.single;
      expect(game.opponent, 'Tigres UANL');
      expect(game.teamScore, 1);
      expect(game.opponentScore, 1);
      expect(game.result, 'VERESÉG');
      expect(game.score, '1–1 (11-esek: 5–6)');
      expect(game.competition, 'Leagues Cup');
    });

    test('hosszabbítás és a nem befejezett / elhalasztott meccsek', () {
      Map<String, dynamic> event(
        String id,
        String date,
        String status, {
        bool completed = true,
        String state = 'post',
      }) => {
        'id': id,
        'date': date,
        'league': {'name': 'U.S. Open Cup', 'slug': 'usa.open'},
        'competitions': [
          {
            'status': {
              'type': {'name': status, 'state': state, 'completed': completed},
            },
            'competitors': [
              {
                'id': '20232',
                'homeAway': 'home',
                'winner': true,
                'team': {'id': '20232', 'displayName': 'Inter Miami CF'},
                'score': {'value': 2.0, 'displayValue': '2'},
              },
              {
                'id': '9',
                'homeAway': 'away',
                'winner': false,
                'team': {'id': '9', 'displayName': 'Orlando City SC'},
                'score': {'value': 1.0, 'displayValue': '1'},
              },
            ],
          },
        ],
      };
      final games = EspnSoccerTeamRepository.parseClubResults({
        'events': [
          event('1', '2026-06-01T23:00Z', 'STATUS_FINAL_AET'),
          event(
            '2',
            '2026-06-05T23:00Z',
            'STATUS_POSTPONED',
            completed: false,
            state: 'pre',
          ),
          event(
            '3',
            '2026-06-08T23:00Z',
            'STATUS_SCHEDULED',
            completed: false,
            state: 'pre',
          ),
          event('4', '2026-06-09T23:00Z', 'STATUS_CANCELED'),
        ],
      }, _miami);
      expect(games.map((game) => game.eventId), ['1']);
      expect(games.single.score, '2–1 (h.u.)');
      expect(games.single.result, 'GYŐZELEM');
    });

    test('közelgő meccsek: időrendben, sorozattal és hazai/idegen '
        'jelöléssel', () {
      final games = EspnSoccerTeamRepository.parseClubFixtures(
        fixture('espn_soccer_fixtures_mia.json'),
        _miami,
      );
      expect(games, hasLength(7));
      expect(games.first.start, DateTime.utc(2026, 10, 10, 23, 30).toLocal());
      expect(games.first.opponent, 'D.C. United');
      expect(games.first.homeAway, 'home');
      expect(games.first.competition, 'MLS');
      expect(games[2].opponent, 'Atlanta United FC');
      expect(games[2].homeAway, 'away');
      for (var i = 1; i < games.length; i++) {
        expect(games[i - 1].start.isBefore(games[i].start), isTrue);
      }
    });

    test('a lejátszott meccsek 1 óráig, a menetrend 6 óráig gyorsítótárból '
        'jön, hibánál a régi lista marad', () async {
      final routes = _espnRoutes();
      final http = FakeHttpService(routes);
      final repository = espn(http);
      expect(await repository.clubResults(_miami), hasLength(7));
      expect(await repository.clubFixtures(_miami), hasLength(7));
      http.requests.clear();

      clock = now.add(const Duration(minutes: 50));
      await repository.clubResults(_miami);
      await repository.clubFixtures(_miami);
      expect(http.requests, isEmpty);

      clock = now.add(const Duration(hours: 2));
      await repository.clubResults(_miami);
      await repository.clubFixtures(_miami);
      expect(http.requests.map((uri) => uri.path), [_miaSchedule]);

      http.requests.clear();
      clock = now.add(const Duration(hours: 7));
      routes[_miaSchedule] = CourtboardHttpException(
        provider: 'ESPN',
        statusCode: 500,
      );
      routes[_miaFixtures] = CourtboardHttpException(
        provider: 'ESPN',
        statusCode: 500,
      );
      expect(await repository.clubResults(_miami), hasLength(7));
      expect(await repository.clubFixtures(_miami), hasLength(7));
      expect(http.requests, hasLength(2));
    });
  });

  group('csapatmérkőzések forrássorrendje', () {
    test('Inter Miami: az ESPN adja a szept. 27-i idegenbeli vereséget '
        'és az 5 legutóbbi meccset', () async {
      final http = FakeHttpService({..._espnRoutes(), ..._theSportsDbRoutes()});
      final games = await football(http).fetchTeamGames('Inter Miami');
      expect(games.source, 'ESPN · MLS');
      expect(games.warnings, isEmpty);
      expect(games.recent, hasLength(5));
      final last = games.recent.first;
      expect(last.date, DateTime.utc(2026, 9, 27, 23).toLocal());
      expect(last.opponent, 'Columbus Crew');
      expect(last.homeAway, 'away');
      expect(last.score, '1–2');
      expect(last.result, FootballResult.loss);
      expect(last.competition, 'MLS');
      expect(last.espnMatch?.league, 'usa.1');
      expect(games.recent[1].opponent, 'San Diego FC');
      expect(games.recent[1].result, FootballResult.draw);
      expect(games.upcoming, hasLength(5));
      expect(games.upcoming.first.opponent, 'D.C. United');
      expect(games.upcoming.first.homeAway, 'home');
      expect(games.upcoming.first.result, FootballResult.unknown);
      // A TheSportsDB-t már nem kérdezi.
      expect(http.requests.where((uri) => uri.path.startsWith(_tsdb)), isEmpty);
    });

    test('ESPN-hiba esetén TheSportsDB-tartalék figyelmeztetéssel', () async {
      final routes = {..._espnRoutes(), ..._theSportsDbRoutes()}
        ..[_miaSchedule] = CourtboardHttpException(
          provider: 'ESPN',
          statusCode: 500,
        )
        ..[_miaFixtures] = CourtboardHttpException(
          provider: 'ESPN',
          statusCode: 500,
        );
      final http = FakeHttpService(routes);
      final games = await football(http).fetchTeamGames('Inter Miami');
      expect(games.source, 'TheSportsDB');
      expect(games.recent, hasLength(1));
      expect(games.recent.single.opponent, 'San Diego FC');
      expect(games.recent.single.date, DateTime.utc(2026, 9, 20, 23).toLocal());
      expect(games.upcoming.single.opponent, 'DC United');
      expect(games.warnings, hasLength(2));
      expect(games.warnings.first, startsWith('ESPN: '));
      expect(games.warnings.last, contains('TheSportsDB'));
      expect(games.warnings.last, contains('hiányos'));
    });

    test('ha az ESPN nem ismeri a csapatot, figyelmeztetés csak a '
        'TheSportsDB hiányosságáról szól', () async {
      final http = FakeHttpService(_theSportsDbRoutes());
      final games = await football(http).fetchTeamGames('Inter Miami');
      expect(games.source, 'TheSportsDB');
      expect(games.recent.single.opponent, 'San Diego FC');
      expect(games.warnings, hasLength(1));
      expect(games.warnings.single, contains('csak a legutóbbi hazai'));
    });
  });

  group('naptár', () {
    test('ESPN-menetrend a TheSportsDB előtt', () async {
      final http = FakeHttpService({..._espnRoutes(), ..._theSportsDbRoutes()});
      final repository = UpcomingEventsRepository(
        http: http,
        cacheStorage: storage,
        clock: () => clock,
      );
      final result = await repository.fetchFor(
        const UpcomingEventsTarget(
          name: 'Lionel Messi',
          sport: Sport.football,
          team: 'Inter Miami',
        ),
        config: const SportsApiConfig(),
      );
      expect(result.error, isNull);
      expect(result.unavailable, isNull);
      expect(result.events, hasLength(7));
      final first = result.events.first;
      expect(first.source, 'ESPN');
      expect(first.opponent, 'D.C. United');
      expect(first.homeAway, 'home');
      expect(first.competition, 'MLS');
      expect(first.title, 'Inter Miami CF – D.C. United');
      expect(first.start, DateTime.utc(2026, 10, 10, 23, 30).toLocal());
      expect(http.requests.where((uri) => uri.path.startsWith(_tsdb)), isEmpty);
    });

    test('ESPN-hibánál a TheSportsDB következő meccse jön', () async {
      final routes = {..._espnRoutes(), ..._theSportsDbRoutes()}
        ..[_miaFixtures] = CourtboardHttpException(
          provider: 'ESPN',
          statusCode: 500,
        );
      final http = FakeHttpService(routes);
      final repository = UpcomingEventsRepository(
        http: http,
        cacheStorage: storage,
        clock: () => clock,
      );
      final result = await repository.fetchFor(
        const UpcomingEventsTarget(
          name: 'Lionel Messi',
          sport: Sport.football,
          team: 'Inter Miami',
        ),
        config: const SportsApiConfig(),
      );
      expect(result.events.single.opponent, 'DC United');
      expect(result.notes.single, startsWith('ESPN: '));
    });
  });

  group('háttérfigyelő', () {
    test('focicsapatnál az ESPN-eredmények és a nyitólap kiemelése', () async {
      final http = FakeHttpService(_espnRoutes());
      final highlights = AthleteHighlightStore(
        storage: MemoryCacheStorage(),
        clock: () => clock,
      );
      final source = RepositoryWatcherSource(
        config: () => const SportsApiConfig(),
        news: NewsRepository(),
        live: LiveScoresRepository(http: http, cacheStorage: storage),
        espnSoccer: espn(http),
        highlights: highlights,
      );
      final results = await source.recentResults(
        const UpcomingEventsTarget(
          name: 'Lionel Messi',
          sport: Sport.football,
          team: 'Inter Miami',
        ),
      );
      expect(results, isNotNull);
      final last = results!.first;
      expect(last.opponent, 'Columbus Crew');
      expect(last.outcome, 'loss');
      expect(last.score, '1–2');
      expect(last.homeAway, 'away');
      expect(last.date, DateTime.utc(2026, 9, 27, 23).toLocal());

      final highlight = await highlights.read('Lionel Messi');
      expect(highlight?.last?.title, 'vs. Columbus Crew');
      expect(highlight?.last?.outcome, 'loss');
      expect(highlight?.last?.score, '1–2');
      expect(highlight?.last?.date, DateTime.utc(2026, 9, 27, 23).toLocal());
    });
  });
}
