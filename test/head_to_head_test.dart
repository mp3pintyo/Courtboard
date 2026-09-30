import 'package:courtboard/data/darts.dart';
import 'package:courtboard/data/espn_schedule.dart';
import 'package:courtboard/data/football_data.dart';
import 'package:courtboard/data/head_to_head.dart';
import 'package:courtboard/data/http_util.dart';
import 'package:courtboard/data/json_file_cache.dart';
import 'package:courtboard/data/sports_api.dart';
import 'package:courtboard/data/upcoming_events.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_http.dart';

UpcomingEvent _event(String sport, String athlete, String opponent) =>
    UpcomingEvent(
      athleteName: athlete,
      sport: sport,
      title: 'x – $opponent',
      opponent: opponent,
      start: DateTime(2026, 10, 23, 3, 30),
      source: 'ESPN',
    );

void main() {
  group('csapatsport (ESPN)', () {
    test('az aktuális és az előző alapszakasz egymás elleni meccsei', () async {
      final http = FakeHttpService({
        '/apis/site/v2/sports/basketball/nba/teams': fixture(
          'espn_nba_teams.json',
        ),
        '/apis/site/v2/sports/basketball/nba/teams/7/schedule': fixture(
          'espn_nba_schedule_den.json',
        ),
        '/apis/site/v2/sports/basketball/nba/teams/7/schedule?season=2026&seasontype=2':
            fixture('espn_nba_schedule_den_2026.json'),
      });
      final record =
          await HeadToHeadRepository(
            http: http,
            cacheStorage: MemoryCacheStorage(),
            clock: () => DateTime(2026, 9, 30),
          ).forEvent(
            _event('NBA', 'Nikola Jokić', 'Oklahoma City Thunder'),
            config: const SportsApiConfig(),
            team: 'Denver Nuggets',
          );
      expect(record.team, isTrue);
      expect(record.source, 'ESPN');
      expect(record.wins, 1);
      expect(record.losses, 4);
      expect(record.balance, '1–4');
      expect(record.meetings, hasLength(5));
      final latest = record.meetings.first;
      expect(latest.date, DateTime.utc(2026, 10, 20, 1).toLocal());
      expect(latest.score, '105–110');
      expect(latest.outcome, 'loss');
      expect(latest.title, '@ Oklahoma City Thunder');
      expect(record.meetings[1].outcome, 'win');
      expect(record.meetings[1].score, '127–107');
    });

    test('csapat nélkül barátságos „nem elérhető” jelzés', () {
      expect(
        HeadToHeadRepository(http: FakeHttpService(const {})).forEvent(
          _event('NFL', 'Saquon Barkley', 'Los Angeles Rams'),
          config: const SportsApiConfig(),
        ),
        throwsA(isA<HeadToHeadUnavailable>()),
      );
    });

    test('becenév és teljes név egyezik, más csapat nem', () {
      final games = [
        EspnCompletedGame(
          id: '1',
          start: DateTime(2026, 1, 1),
          opponent: 'Utah Jazz',
          ownScore: '120',
          opponentScore: '99',
          outcome: 'win',
          homeAway: 'home',
        ),
        EspnCompletedGame(
          id: '2',
          start: DateTime(2026, 1, 3),
          opponent: 'Phoenix Suns',
          ownScore: '100',
          opponentScore: '101',
          outcome: 'loss',
        ),
      ];
      final record = HeadToHeadRepository.teamHeadToHead(
        games,
        opponent: 'Jazz',
        source: 'ESPN',
      );
      expect(record.meetings.single.title, 'vs. Utah Jazz');
      expect(record.wins, 1);
      expect(record.losses, 0);
    });
  });

  group('foci', () {
    test('a csapatmérkőzések közül az ellenfél elleniek, döntetlennel', () {
      final record = HeadToHeadRepository.footballHeadToHead(
        [
          FootballGame(
            date: DateTime(2026, 9, 1),
            opponent: 'Borussia Dortmund',
            score: '2–2',
            result: FootballResult.draw,
            homeAway: 'away',
          ),
          FootballGame(
            date: DateTime(2026, 3, 1),
            opponent: 'BV Borussia 09 Dortmund',
            score: '3–1',
            result: FootballResult.win,
          ),
          FootballGame(
            date: DateTime(2026, 4, 1),
            opponent: 'RB Leipzig',
            score: '0–1',
            result: FootballResult.loss,
          ),
        ],
        opponent: 'Borussia Dortmund',
        source: 'OpenLigaDB',
      );
      expect(record.meetings, hasLength(2));
      expect(record.draws, 1);
      expect(record.wins, 1);
      expect(record.balance, '1–1–0');
      expect(record.meetings.first.title, '@ Borussia Dortmund');
    });
  });

  group('tenisz (Live Tennis API /h2h)', () {
    test('a dokumentált válasz feldolgozása', () {
      final record = HeadToHeadRepository.parseTennisHeadToHead(
        fixture('live_tennis_h2h.json'),
        opponent: 'Aryna Sabalenka',
      );
      expect(record.wins, 8);
      expect(record.losses, 5);
      expect(record.team, isFalse);
      expect(record.meetings, hasLength(4));
      expect(record.meetings.first.title, 'Roland Garros');
      expect(record.meetings.first.outcome, 'win');
      expect(record.meetings.first.competition, 'SF · clay');
      expect(record.meetings[1].outcome, 'loss');
      final walkover = record.meetings.firstWhere(
        (meeting) => meeting.title == 'Australian Open',
      );
      expect(walkover.outcome, isEmpty);
      expect(walkover.score, 'w.o.');
    });

    test('Free kulcsnál (403) „Nem elérhető a Free csomagban”', () async {
      final http = FakeHttpService({
        '/api/public/v1/h2h': CourtboardHttpException(
          provider: 'Live Tennis API',
          statusCode: 403,
        ),
      });
      await expectLater(
        HeadToHeadRepository(
          http: http,
          cacheStorage: MemoryCacheStorage(),
        ).forEvent(
          _event('Tenisz', 'Iga Swiatek', 'Aryna Sabalenka'),
          config: const SportsApiConfig(liveTennisKey: 'free-key'),
        ),
        throwsA(
          isA<HeadToHeadUnavailable>().having(
            (error) => error.message,
            'message',
            contains('Nem elérhető a Free csomagban'),
          ),
        ),
      );
      expect(http.requests.single.queryParameters, {
        'p1': 'Iga Swiatek',
        'p2': 'Aryna Sabalenka',
      });
      expect(http.headers.single['Authorization'], 'Bearer free-key');
    });

    test('kulcs nélkül nem kér', () async {
      final http = FakeHttpService(const {});
      await expectLater(
        HeadToHeadRepository(http: http).forEvent(
          _event('Tenisz', 'Iga Swiatek', 'Aryna Sabalenka'),
          config: const SportsApiConfig(),
        ),
        throwsA(isA<HeadToHeadUnavailable>()),
      );
      expect(http.requests, isEmpty);
    });
  });

  group('darts (TheSportsDB eredménysorok)', () {
    test('csak az ellenfél nevét tartalmazó sorok számítanak', () {
      final record = HeadToHeadRepository.dartsHeadToHead([
        DartsResult(
          date: DateTime(2026, 9, 1),
          event: 'Luke Humphries vs Luke Littler',
          detail: 'L',
        ),
        DartsResult(
          date: DateTime(2026, 8, 1),
          event: 'Luke Humphries vs Michael van Gerwen',
          detail: 'W',
        ),
        DartsResult(
          date: DateTime(2026, 7, 1),
          event: 'Premier League Night 16',
          detail: '—',
        ),
      ], opponent: 'Luke Littler');
      expect(record.meetings, hasLength(1));
      expect(record.losses, 1);
      expect(record.wins, 0);
      expect(record.source, 'TheSportsDB');
    });

    test('egyező sor nélkül üres mérleg', () {
      final record = HeadToHeadRepository.dartsHeadToHead(
        const [],
        opponent: 'Luke Littler',
      );
      expect(record.isEmpty, isTrue);
    });
  });

  test('ellenfél nélküli eseménynél nincs mérleg', () {
    expect(
      HeadToHeadRepository(http: FakeHttpService(const {})).forEvent(
        _event('Darts', 'Luke Humphries', ''),
        config: const SportsApiConfig(),
      ),
      throwsA(isA<HeadToHeadUnavailable>()),
    );
  });
}
