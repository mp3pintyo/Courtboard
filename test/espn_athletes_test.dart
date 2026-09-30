import 'package:courtboard/data/basketball_reference.dart';
import 'package:courtboard/data/espn_athletes.dart';
import 'package:courtboard/data/espn_schedule.dart';
import 'package:courtboard/data/http_util.dart';
import 'package:courtboard/data/json_file_cache.dart';
import 'package:courtboard/data/wehoop_wnba.dart';
import 'package:courtboard/insights/compare.dart';
import 'package:courtboard/insights/form_data.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_http.dart';

const _jokicRef = EspnAthleteRef(
  id: '3112335',
  displayName: 'Nikola Jokic',
  league: EspnLeague.nba,
  team: 'Denver Nuggets',
);

const _hurtsRef = EspnAthleteRef(
  id: '4040715',
  displayName: 'Jalen Hurts',
  league: EspnLeague.nfl,
  team: 'Philadelphia Eagles',
  position: 'QB',
);

void main() {
  group('ESPN játékoskeresés', () {
    test('szigorú névegyezés a ligán belül (ékezet nélkül is)', () {
      final ref = EspnAthleteRepository.parseSearch(
        fixture('espn_search_jokic.json'),
        'Nikola Jokić',
        EspnLeague.nba,
      );
      expect(ref?.id, '3112335');
      expect(ref?.team, 'Denver Nuggets');
      expect(ref?.teamAbbreviation, 'DEN');
      // A pozíció objektumként érkezik; a rövidítése kell.
      expect(ref?.position, 'C');
      expect(ref?.jersey, '15');
    });

    test('hasonló, de más nevű játékost és más ligát nem ad vissza', () {
      final payload = fixture('espn_search_jokic.json');
      // A „Nikola Jovic” csali nem egyezik a keresett névvel.
      expect(
        EspnAthleteRepository.parseSearch(
          payload,
          'Nikola Jovicic',
          EspnLeague.nba,
        ),
        isNull,
      );
      expect(
        EspnAthleteRepository.parseSearch(
          payload,
          'Nikola Jokic',
          EspnLeague.wnba,
        ),
        isNull,
      );
      expect(
        EspnAthleteRepository.parseSearch(
          fixture('espn_search_hurts.json'),
          'Jalen Hurts',
          EspnLeague.nfl,
        )?.id,
        '4040715',
      );
      expect(
        EspnAthleteRepository.parseSearch(
          fixture('espn_search_hurts.json'),
          'Jalen Hurts',
          EspnLeague.nfl,
        )?.position,
        'QB',
      );
    });
  });

  group('ESPN meccsnapló – NBA', () {
    final log = EspnAthleteRepository.parseGameLog(
      fixture('espn_nba_gamelog_jokic.json'),
      _jokicRef,
    );

    test('a meccsek a legújabb elöl, oszlopnév szerinti statisztikával', () {
      expect(log.games, isNotEmpty);
      final dates = [for (final game in log.games) game.date];
      expect(
        dates,
        orderedEquals(<DateTime>[...dates]..sort((a, b) => b.compareTo(a))),
      );
      final latest = log.games.first;
      expect(latest.eventId, '401869402');
      expect(latest.phase, EspnSeasonPhase.postseason);
      expect(latest.homeAway, 'away');
      expect(latest.opponent, 'Minnesota Timberwolves');
      expect(latest.result, 'L');
      expect(latest.outcome, 'LOSS');
      expect(latest.score, '98–110');
      expect(latest.stat('points'), 28);
      expect(latest.madeAttempted('fieldGoalsMade-fieldGoalsAttempted'), (
        11,
        19,
      ));
      expect(log.season, '2025-26');
    });

    test('a felkészülési meccsek kimaradnak', () {
      expect(
        log.games.where((game) => game.phase == EspnSeasonPhase.preseason),
        isEmpty,
      );
    });

    test('Basketball Reference-modellre és szezonösszesítőre alakít', () {
      final games = log.toNbaGameLogs(limit: 3);
      expect(games, hasLength(3));
      expect(games.first.points, 28);
      expect(games.first.location, 'AWAY');
      expect(games.first.outcome, 'LOSS');
      expect(games.first.fieldGoalsMade, 11);

      final season = log.toBasketballSeasonStat();
      expect(season, isNotNull);
      expect(season!.source, 'ESPN');
      // Az ESPN „avg” sora: 27,7 pont, 12,9 lepattanó, 10,7 assziszt.
      expect(season.pointsPerGame, 27.7);
      expect(season.reboundsPerGame, 12.9);
      expect(season.assistsPerGame, 10.7);
      expect(season.fieldGoalPercentage, 56.9);
      expect(season.games, log.regularSeason.length);
    });

    test('gyorsítótár: a második hívás nem kér újra', () async {
      final http = FakeHttpService({
        '/apis/common/v3/search': fixture('espn_search_jokic.json'),
        '/apis/common/v3/sports/basketball/nba/athletes/3112335/gamelog':
            fixture('espn_nba_gamelog_jokic.json'),
      });
      final repository = EspnAthleteRepository(
        http: http,
        cacheStorage: MemoryCacheStorage(),
      );
      final first = await repository.gameLog('Nikola Jokić', EspnLeague.nba);
      final second = await repository.gameLog('Nikola Jokić', EspnLeague.nba);
      expect(first?.games.length, second?.games.length);
      expect(http.requests, hasLength(2));
      expect(second!.fromCache, isTrue);
      expect(first!.fromCache, isFalse);
    });

    test(
      'ismeretlen játékosnál null, és a sikertelen keresés is cache-elt',
      () async {
        final http = FakeHttpService({
          '/apis/common/v3/search': fixture('espn_search_jokic.json'),
        });
        final repository = EspnAthleteRepository(
          http: http,
          cacheStorage: MemoryCacheStorage(),
        );
        expect(
          await repository.gameLog('Nemlétező Játékos', EspnLeague.nba),
          isNull,
        );
        expect(
          await repository.gameLog('Nemlétező Játékos', EspnLeague.nba),
          isNull,
        );
        expect(http.requests, hasLength(1));
      },
    );

    test('tartalék: ha a Basketball Reference hibázik, az ESPN adja', () async {
      final http = FakeHttpService({
        '/apis/common/v3/search': fixture('espn_search_jokic.json'),
        '/apis/common/v3/sports/basketball/nba/athletes/3112335/gamelog':
            fixture('espn_nba_gamelog_jokic.json'),
      });
      final cached = await nbaSeasonSummaryWithFallback(
        'Nikola Jokić',
        reference: BasketballReferenceRepository(
          cacheStorage: MemoryCacheStorage(),
          fetchHtml: (_) async => throw CourtboardHttpException(
            provider: 'Basketball Reference',
            statusCode: 429,
          ),
        ),
        espn: EspnAthleteRepository(
          http: http,
          cacheStorage: MemoryCacheStorage(),
        ),
      );
      expect(cached?.value.source, 'ESPN');
      expect(cached?.value.pointsPerGame, 27.7);
    });

    test(
      'ha a tartalék sem ad adatot, az elsődleges hiba jut tovább',
      () async {
        expect(
          nbaSeasonSummaryWithFallback(
            'Nikola Jokić',
            reference: BasketballReferenceRepository(
              cacheStorage: MemoryCacheStorage(),
              fetchHtml: (_) async => throw CourtboardHttpException(
                provider: 'Basketball Reference',
                statusCode: 503,
              ),
            ),
            espn: EspnAthleteRepository(
              http: FakeHttpService(const {}),
              cacheStorage: MemoryCacheStorage(),
            ),
          ),
          throwsA(isA<CourtboardHttpException>()),
        );
      },
    );
  });

  group('ESPN meccsnapló – WNBA tartalék', () {
    test('wehoop hibánál az ESPN-napló wehoop-modellben', () async {
      final http = FakeHttpService({
        '/apis/common/v3/search': fixture('espn_search_clark.json'),
        '/apis/common/v3/sports/basketball/wnba/athletes/4433403/gamelog':
            fixture('espn_wnba_gamelog_clark.json'),
      });
      final result = await wnbaGamesWithFallback(
        'Caitlin Clark',
        wehoop: WnbaWehoopRepository(
          cacheStorage: MemoryCacheStorage(),
          fetchCsv: (_) async => throw CourtboardHttpException(
            provider: 'GitHub',
            statusCode: 503,
          ),
        ),
        espn: EspnAthleteRepository(
          http: http,
          cacheStorage: MemoryCacheStorage(),
        ),
      );
      expect(result.source, 'ESPN');
      expect(result.note, contains('wehoop'));
      expect(result.games, isNotEmpty);
      final game = result.games.first;
      expect(game.points, greaterThanOrEqualTo(0));
      expect(game.result, isNot(WnbaResult.unknown));
      final snapshot = snapshotFromWnbaGames(
        'Caitlin Clark',
        result.games,
        source: result.source,
      );
      expect(snapshot?.source, 'ESPN');
    });
  });

  group('ESPN meccsnapló – NFL', () {
    final log = EspnAthleteRepository.parseGameLog(
      fixture('espn_nfl_gamelog_hurts.json'),
      _hurtsRef,
    );

    test('irányítónál a passzolt yard a fő mutató', () {
      expect(NflFormStat.pick(log), NflFormStat.passingYards);
      expect(log.games, hasLength(3));
      final points = nflFormPoints(log, NflFormStat.passingYards);
      expect(points, hasLength(3));
      expect(points.fold<double>(0, (sum, p) => sum + p.value), 620);
    });

    test('az összesítő sor arány-oszlopai nem oszlanak a meccsszámmal', () {
      expect(log.total('passingYards'), 620);
      expect(log.perGame('completionPct'), 64.4);
      expect(log.perGame('passingYards'), closeTo(620 / 3, .01));
      final lines = {
        for (final (label, value, _) in nflSeasonLines(log)) label: value,
      };
      expect(lines['PASSZOLT YARD'], 620);
      expect(lines['PASSZ TD'], 5);
      expect(lines['INTERCEPTION'], 3);
      expect(lines['FUTOTT YARD'], 87);
      expect(lines.containsKey('ELKAPOTT YARD'), isFalse);
    });

    test('meccsösszegzés és összehasonlítási pillanatkép', () {
      expect(nflGameSummary(log.games.first), contains('passz yd'));
      final snapshot = snapshotFromNflGameLog('Jalen Hurts', log)!;
      expect(snapshot.sport, 'NFL');
      expect(snapshot['passingYards'], closeTo(206.7, .1));
      expect(snapshot['receivingYards'], isNull);
      expect(snapshot['touchdowns'], closeTo(2.0, .01));
      expect(snapshot['games'], 3);
    });

    test('a napló JSON-oda-vissza alakítása veszteségmentes', () {
      final copy = EspnGameLog.fromJson(log.toJson());
      expect(copy.games.length, log.games.length);
      expect(copy.athlete.position, 'QB');
      expect(copy.total('passingYards'), 620);
      expect(copy.games.first.stats, log.games.first.stats);
    });
  });
}
