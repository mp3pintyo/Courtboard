import 'package:courtboard/domain/sport.dart';
import 'package:courtboard/data/athlete_watcher.dart';
import 'package:courtboard/data/http_util.dart';
import 'package:courtboard/data/json_file_cache.dart';
import 'package:courtboard/data/live_scores.dart';
import 'package:courtboard/data/notification_settings.dart';
import 'package:courtboard/data/notifications.dart';
import 'package:courtboard/data/upcoming_events.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_desktop.dart';
import 'support/fake_http.dart';

const _nbaCdnPath = '/static/json/liveData/scoreboard/todaysScoreboard_00.json';
const _espnNba = '/apis/site/v2/sports/basketball/nba/scoreboard';
const _espnWnba = '/apis/site/v2/sports/basketball/wnba/scoreboard';
const _espnNfl = '/apis/site/v2/sports/football/nfl/scoreboard';
const _espnSoccer = '/apis/site/v2/sports/soccer/all/scoreboard';
const _nbaTeams = '/apis/site/v2/sports/basketball/nba/teams';

LiveScoresRepository _repository(FakeHttpService http, {DateTime? now}) =>
    LiveScoresRepository(
      http: http,
      cacheStorage: MemoryCacheStorage(clock: now == null ? null : () => now),
    );

void main() {
  setUp(LiveScoresRepository.resetNbaCdnBackoff);

  group('NBA CDN scoreboard', () {
    final games = LiveScoresRepository.parseNbaCdnScoreboard(
      fixture('nba_cdn_scoreboard.json'),
    );

    test('élő, befejezett és kezdés előtti meccs', () {
      expect(games, hasLength(3));
      final live = games.firstWhere((game) => game.id == '0022600011');
      expect(live.state, LiveGameState.live);
      expect(live.home.name, 'Denver Nuggets');
      expect(live.home.abbreviation, 'DEN');
      expect(live.home.score, '84');
      expect(live.away.score, '79');
      expect(live.status, '3. negyed · 5:32');
      expect(live.scoreLine, 'DEN 84–79 UTA');
      expect(live.source, 'NBA CDN');

      final finished = games.firstWhere((game) => game.id == '0022600010');
      expect(finished.state, LiveGameState.finished);
      expect(finished.status, 'Vége');

      final pregame = games.firstWhere((game) => game.id == '0022600012');
      expect(pregame.state, LiveGameState.scheduled);
      expect(pregame.home.score, isEmpty);
    });
  });

  group('ESPN scoreboard', () {
    test('élő NBA-meccs negyeddel és órával', () {
      final games = LiveScoresRepository.parseEspnScoreboard(
        fixture('espn_nba_scoreboard_live.json'),
        LiveFeed.nba,
      );
      final game = games.single;
      expect(game.isLive, isTrue);
      expect(game.status, '3. negyed · 5:32');
      expect(game.home.name, 'Toronto Raptors');
      expect(game.home.score, '78');
      expect(game.away.score, '81');
      expect(game.home.id, '28');
    });

    test('befejezett WNBA-meccsek', () {
      final games = LiveScoresRepository.parseEspnScoreboard(
        fixture('espn_wnba_scoreboard_final.json'),
        LiveFeed.wnba,
      );
      expect(games, hasLength(2));
      expect(games.every((game) => game.isFinished), isTrue);
      expect(games.first.status, 'Vége');
    });

    test('kezdés előtti NFL-meccsnek nincs pontszáma', () {
      final games = LiveScoresRepository.parseEspnScoreboard(
        fixture('espn_nfl_scoreboard_pregame.json'),
        LiveFeed.nfl,
      );
      expect(games, hasLength(3));
      expect(
        games.every((game) => game.state == LiveGameState.scheduled),
        isTrue,
      );
      expect(games.first.home.score, isEmpty);
    });

    test('meccs nélküli nap: üres lista', () {
      expect(
        LiveScoresRepository.parseEspnScoreboard(
          fixture('espn_scoreboard_empty.json'),
          LiveFeed.wnba,
        ),
        isEmpty,
      );
    });

    test('élő focimeccs percfelirattal és ESPN-azonosítóval', () {
      final games = LiveScoresRepository.parseEspnScoreboard(
        fixture('espn_soccer_scoreboard_live.json'),
        LiveFeed.soccer,
      );
      final live = games.firstWhere((game) => game.isLive);
      expect(live.status, '63. perc');
      expect(live.espnEventId, '401882508');
      expect(live.espnLeague, 'all');
      expect(live.home.name, 'Athletic Club');
      expect(live.home.score, '2');
    });

    test('magyar állapotfeliratok', () {
      expect(basketballPeriodLabel(5, '2:10'), '1. hosszabbítás · 2:10');
      expect(basketballPeriodLabel(2, ''), '2. negyed');
      expect(soccerMinuteLabel("90'+2'"), '90+2. perc');
    });
  });

  group('LiveScoresRepository', () {
    test('a követett csapat élő meccse (NBA CDN, csapatfeloldással)', () async {
      final http = FakeHttpService({
        _nbaCdnPath: fixture('nba_cdn_scoreboard.json'),
        _nbaTeams: fixture('espn_nba_teams.json'),
      });
      final result = await _repository(http).forTargets(const [
        UpcomingEventsTarget(
          name: 'Nikola Jokić',
          sport: Sport.nba,
          team: 'Denver Nuggets',
        ),
        UpcomingEventsTarget(
          name: 'Luka Dončić',
          sport: Sport.nba,
          team: 'Lakers',
        ),
      ]);
      expect(result.sources[LiveFeed.nba], 'NBA CDN');
      expect(result.hasLive, isTrue);
      final jokic = result.forAthlete('Nikola Jokić').single;
      expect(jokic.ownIsHome, isTrue);
      expect(jokic.score, '84–79');
      expect(jokic.opponent.name, 'Utah Jazz');
      // A Lakers meccse még nem kezdődött el: benne van, de nem élő.
      final luka = result.forAthlete('Luka Dončić').single;
      expect(luka.game.state, LiveGameState.scheduled);
      expect(result.live.map((game) => game.athleteName), ['Nikola Jokić']);
    });

    test(
      'NBA CDN 403 esetén az ESPN a tartalék, a forrás jelölésével',
      () async {
        final http = FakeHttpService({
          _nbaCdnPath: CourtboardHttpException(
            provider: 'NBA CDN',
            statusCode: 403,
          ),
          _espnNba: fixture('espn_nba_scoreboard_live.json'),
          _nbaTeams: fixture('espn_nba_teams.json'),
        });
        final result = await _repository(http).forTargets(const [
          UpcomingEventsTarget(
            name: 'Tyler Herro',
            sport: Sport.nba,
            team: 'Miami Heat',
          ),
        ]);
        expect(result.sources[LiveFeed.nba], 'ESPN');
        expect(result.notes.single, contains('NBA CDN'));
        // A tiltás alatt a CDN-t nem kérdezi újra.
        final again =
            await LiveScoresRepository(
              http: http,
              cacheStorage: MemoryCacheStorage(),
            ).forTargets(const [
              UpcomingEventsTarget(
                name: 'Tyler Herro',
                sport: Sport.nba,
                team: 'Miami Heat',
              ),
            ]);
        expect(again.sources[LiveFeed.nba], 'ESPN');
        expect(
          http.requests.where((uri) => uri.host == 'cdn.nba.com'),
          hasLength(1),
        );
        final game = result.games.single;
        expect(game.ownIsHome, isFalse);
        expect(game.score, '81–78');
        expect(game.game.isLive, isTrue);
      },
    );

    test('a scoreboard 45 mp-ig gyorsítótárból jön', () async {
      final http = FakeHttpService({
        _espnWnba: fixture('espn_wnba_scoreboard_final.json'),
      });
      final repository = _repository(http);
      const target = UpcomingEventsTarget(
        name: 'Caitlin Clark',
        sport: Sport.wnba,
        team: 'Indiana Fever',
      );
      await repository.forTargets(const [target]);
      final second = await repository.forTargets(const [target]);
      expect(http.requests.where((uri) => uri.path == _espnWnba), hasLength(1));
      final game = second.forAthlete('Caitlin Clark').single;
      expect(game.game.isFinished, isTrue);
      expect(game.outcome, 'win');
      expect(game.score, '99–89');
    });

    test('hibás scoreboard: nem dob, a hiba az eredményben jön', () async {
      final http = FakeHttpService({
        _espnNfl: CourtboardHttpException(provider: 'ESPN', statusCode: 500),
      });
      final result = await _repository(http).forTargets(const [
        UpcomingEventsTarget(
          name: 'Saquon Barkley',
          sport: Sport.nfl,
          team: 'Philadelphia Eagles',
        ),
      ]);
      expect(result.games, isEmpty);
      expect(result.errors[LiveFeed.nfl], isNotEmpty);
    });

    test('foci: csapatnév-egyeztetés a napi összesítőben', () async {
      final http = FakeHttpService({
        _espnSoccer: fixture('espn_soccer_scoreboard_live.json'),
      });
      final result = await _repository(http).forTargets(const [
        UpcomingEventsTarget(
          name: 'Ane Azkona',
          sport: Sport.football,
          team: 'Athletic Club',
        ),
        UpcomingEventsTarget(
          name: 'Valaki',
          sport: Sport.football,
          team: 'Liverpool',
        ),
      ]);
      expect(result.games.map((game) => game.athleteName), ['Ane Azkona']);
      expect(result.games.single.game.espnEventId, '401882508');
    });

    test('csapat nélküli vagy nem támogatott sportoló kimarad', () async {
      final http = FakeHttpService(const {});
      final result = await _repository(http).forTargets(const [
        UpcomingEventsTarget(name: 'Iga Świątek', sport: Sport.tennis),
        UpcomingEventsTarget(name: 'Nikola Jokić', sport: Sport.nba),
      ]);
      expect(result.games, isEmpty);
      expect(http.requests, isEmpty);
    });
  });

  group('figyelő: élő eredmények', () {
    const clark = UpcomingEventsTarget(
      name: 'Caitlin Clark',
      sport: Sport.wnba,
      team: 'Indiana Fever',
    );
    final wnba = LiveScoresRepository.parseEspnScoreboard(
      fixture('espn_wnba_scoreboard_final.json'),
      LiveFeed.wnba,
    );
    final finalGame = AthleteLiveGame(
      athleteName: 'Caitlin Clark',
      game: wnba.firstWhere((game) => game.home.name == 'Indiana Fever'),
      ownIsHome: true,
    );

    test('a scoreboard végeredménye és a menetrend ugyanazt a meccset '
        'csak egyszer jelzi', () async {
      final source = FakeWatcherSource();
      final notifications = FakeNotificationService();
      final memory = MemoryWatcherMemoryStore();
      final now = finalGame.game.start.add(const Duration(hours: 3));
      final watcher =
          AthleteWatcher(
            source: source,
            notifications: notifications,
            memoryStore: memory,
            clock: () => now,
          )..update(
            athletes: const [clark],
            settings: const NotificationSettings(
              matchStart: false,
              news: false,
            ),
          );
      // Első futás: csak megjegyzés.
      source.results['Caitlin Clark'] = const [];
      await watcher.run();
      // A scoreboardon véget ért a meccs.
      source.results['Caitlin Clark'] = [liveFinalResult(finalGame)];
      final report = await watcher.run();
      expect(report.shown, hasLength(1));
      expect(report.shown.single.kind, CourtboardNotificationKind.result);
      expect(report.shown.single.body, contains('99–89'));
      // Később a menetrendből is megjön (ugyanaz a napi kulcs): nincs új.
      source.results['Caitlin Clark'] = [
        liveFinalResult(finalGame),
        WatchedResult(
          key: 'wnba:${finalGame.game.id}',
          date: finalGame.game.start,
          opponent: 'Las Vegas Aces',
          outcome: 'win',
          score: '99–89',
          aliases: [resultDayKey('WNBA', finalGame.game.start)],
        ),
      ];
      final again = await watcher.run();
      expect(again.shown, isEmpty);
    });

    test(
      'élő eredményváltozás csak bekapcsolva, és csak változáskor',
      () async {
        final live = LiveScoresRepository.parseNbaCdnScoreboard(
          fixture('nba_cdn_scoreboard.json'),
        ).firstWhere((game) => game.isLive);
        AthleteLiveGame at(String home, String away) => AthleteLiveGame(
          athleteName: 'Nikola Jokić',
          ownIsHome: true,
          game: LiveGame(
            id: live.id,
            sport: 'NBA',
            source: live.source,
            state: LiveGameState.live,
            home: LiveTeam(
              name: live.home.name,
              abbreviation: 'DEN',
              score: home,
            ),
            away: LiveTeam(
              name: live.away.name,
              abbreviation: 'UTA',
              score: away,
            ),
            start: live.start,
            status: live.status,
          ),
        );
        const jokic = UpcomingEventsTarget(
          name: 'Nikola Jokić',
          sport: Sport.nba,
          team: 'Denver Nuggets',
        );
        final source = FakeWatcherSource();
        final notifications = FakeNotificationService();
        final watcher =
            AthleteWatcher(
              source: source,
              notifications: notifications,
              memoryStore: MemoryWatcherMemoryStore(),
              clock: () => live.start.add(const Duration(hours: 1)),
            )..update(
              athletes: const [jokic],
              settings: const NotificationSettings(
                matchStart: false,
                results: false,
                news: false,
              ),
            );
        source.live['Nikola Jokić'] = [at('84', '79')];
        // Kikapcsolt beállításnál le sem kérdezi.
        await watcher.run();
        expect(source.calls.where((call) => call.startsWith('live:')), isEmpty);

        watcher.update(
          settings: const NotificationSettings(
            matchStart: false,
            results: false,
            news: false,
            liveScores: true,
          ),
        );
        expect((await watcher.run()).shown, isEmpty); // első látás: megjegyzés
        expect((await watcher.run()).shown, isEmpty); // nincs változás
        source.live['Nikola Jokić'] = [at('86', '79')];
        final changed = await watcher.run();
        expect(changed.shown, hasLength(1));
        final shown = changed.shown.single;
        expect(shown.kind, CourtboardNotificationKind.liveScore);
        expect(shown.title, 'Élő: Nikola Jokić');
        expect(shown.body, contains('86–79'));
        expect(shown.body, contains('3. negyed'));
      },
    );

    test('a beállítás alapból ki van kapcsolva és mentődik', () {
      expect(const NotificationSettings().liveScores, isFalse);
      final saved = const NotificationSettings(liveScores: true).toJson();
      expect(NotificationSettings.fromJson(saved).liveScores, isTrue);
      expect(NotificationSettings.fromJson(const {}).liveScores, isFalse);
    });
  });
}
