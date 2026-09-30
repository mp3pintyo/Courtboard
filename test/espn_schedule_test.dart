import 'package:courtboard/data/espn_schedule.dart';
import 'package:courtboard/data/json_file_cache.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_http.dart';

void main() {
  const nuggets = EspnTeam(id: '7', displayName: 'Denver Nuggets');

  group('ESPN csapatfeloldás', () {
    final teams = fixture('espn_nba_teams.json');

    test('teljes név, rövidítés, becenév és ékezet nélküli alak', () {
      expect(
        EspnScheduleRepository.findTeamIn(teams, 'Denver Nuggets')?.id,
        '7',
      );
      expect(EspnScheduleRepository.findTeamIn(teams, 'den')?.id, '7');
      expect(EspnScheduleRepository.findTeamIn(teams, 'Nuggets')?.id, '7');
      expect(
        EspnScheduleRepository.findTeamIn(
          teams,
          'golden state warriors',
        )?.displayName,
        'Golden State Warriors',
      );
      expect(EspnScheduleRepository.findTeamIn(teams, 'Utah Jazz')?.id, '26');
    });

    test('ismeretlen vagy üres csapatnévre nincs találat', () {
      expect(EspnScheduleRepository.findTeamIn(teams, 'Chicago Bulls'), isNull);
      expect(EspnScheduleRepository.findTeamIn(teams, '  '), isNull);
      expect(EspnScheduleRepository.findTeamIn(const {}, 'Denver'), isNull);
    });
  });

  group('ESPN menetrend-feldolgozás', () {
    test('NBA: befejezett és elhalasztott meccs nélkül, időrendben', () {
      final games = EspnScheduleRepository.parseSchedule(
        fixture('espn_nba_schedule_den.json'),
        league: EspnLeague.nba,
        team: nuggets,
      );

      expect(games.map((game) => game.id), [
        '401909094',
        '401909859',
        '401909876',
      ]);
      final first = games.first;
      expect(first.start, DateTime.utc(2026, 10, 23, 1, 30).toLocal());
      expect(first.start.isUtc, isFalse);
      expect(first.opponent, 'Oklahoma City Thunder');
      expect(first.homeAway, 'away');
      expect(first.home, 'Oklahoma City Thunder');
      expect(first.away, 'Denver Nuggets');
      expect(first.competition, 'NBA · Alapszakasz');
      expect(first.venue, 'Paycom Center, Oklahoma City');
      expect(
        first.url,
        'https://www.espn.com/nba/game/_/gameId/401909094/nuggets-thunder',
      );
      expect(first.timeKnown, isTrue);

      expect(games[1].homeAway, 'home');
      expect(games[1].opponent, 'New Orleans Pelicans');
      // A harmadik meccs időpontja az ESPN szerint még nem végleges.
      expect(games[2].timeKnown, isFalse);
    });

    test('NFL: hét sorszáma a versenyleírásban, idegenbeli meccs', () {
      final games = EspnScheduleRepository.parseSchedule(
        fixture('espn_nfl_schedule_phi.json'),
        league: EspnLeague.nfl,
        team: const EspnTeam(id: '21', displayName: 'Philadelphia Eagles'),
      );

      expect(games, hasLength(2));
      expect(games[0].competition, 'NFL · Alapszakasz · 4. hét');
      expect(games[0].opponent, 'Los Angeles Rams');
      expect(games[0].homeAway, 'home');
      expect(games[1].opponent, 'Jacksonville Jaguars');
      expect(games[1].homeAway, 'away');
      expect(games[1].start, DateTime.utc(2026, 10, 11, 13, 30).toLocal());
    });

    test('hibás vagy hiányos esemény nem dönti el a listát', () {
      final games = EspnScheduleRepository.parseSchedule(
        {
          'events': [
            {'id': '1'},
            {
              'id': '2',
              'competitions': [
                {'date': 'nem dátum', 'competitors': <Object>[]},
              ],
            },
            'szöveg',
            {
              'id': '3',
              'date': '2026-11-01T00:00Z',
              'competitions': [
                {
                  'competitors': [
                    {
                      'homeAway': 'home',
                      'team': {'id': '99', 'displayName': 'Másik csapat'},
                    },
                  ],
                },
              ],
            },
          ],
        },
        league: EspnLeague.nba,
        team: nuggets,
      );
      expect(games, isEmpty);
    });

    test('ligaváltás a sportág-címkéből', () {
      expect(EspnLeague.fromSport('NBA'), EspnLeague.nba);
      expect(EspnLeague.fromSport('WNBA'), EspnLeague.wnba);
      expect(EspnLeague.fromSport('NFL'), EspnLeague.nfl);
      expect(EspnLeague.fromSport('Foci'), isNull);
      expect(
        EspnScheduleRepository.scheduleUri(EspnLeague.wnba, '5').path,
        '/apis/site/v2/sports/basketball/wnba/teams/5/schedule',
      );
    });
  });

  test(
    'felkészülési időszakban az alapszakaszt is lekéri, duplikáció nélkül',
    () async {
      final preseason = fixture('espn_nba_schedule_den.json')
        ..['requestedSeason'] = {'year': 2027, 'type': 1};
      final http = FakeHttpService({
        '/apis/site/v2/sports/basketball/nba/teams/7/schedule': preseason,
        '/apis/site/v2/sports/basketball/nba/teams/7/schedule?seasontype=2':
            fixture('espn_nba_schedule_den.json'),
      });
      final repository = EspnScheduleRepository(
        http: http,
        cacheStorage: MemoryCacheStorage(),
      );

      final games = await repository.upcomingGames(EspnLeague.nba, nuggets);

      expect(http.requests, hasLength(2));
      expect(http.requests.last.queryParameters['seasontype'], '2');
      expect(games, hasLength(3));
    },
  );

  test('a csapatlista 7 napig gyorsítótárból jön', () async {
    final http = FakeHttpService({
      '/apis/site/v2/sports/basketball/nba/teams': fixture(
        'espn_nba_teams.json',
      ),
    });
    final repository = EspnScheduleRepository(
      http: http,
      cacheStorage: MemoryCacheStorage(),
    );

    expect((await repository.findTeam(EspnLeague.nba, 'Nuggets'))?.id, '7');
    expect((await repository.findTeam(EspnLeague.nba, 'Jazz'))?.id, '26');
    expect(http.requests, hasLength(1));
  });
}
