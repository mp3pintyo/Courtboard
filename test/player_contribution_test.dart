// A játékos saját pontszerzése a lejátszott meccsek soraiban (0.16.0):
// a közös modell, a FotMob-meccsek párosítása, az ESPN-összefoglaló és az
// OpenLigaDB góllövői, valamint az NFL-meccsnapló touchdownjai — valós
// (megvágott) válaszokból, hálózat nélkül.
import 'dart:convert';
import 'dart:io';

import 'package:courtboard/data/espn_athletes.dart';
import 'package:courtboard/data/espn_schedule.dart';
import 'package:courtboard/data/fotmob_football.dart';
import 'package:courtboard/data/json_file_cache.dart';
import 'package:courtboard/data/match_timeline.dart';
import 'package:courtboard/data/openligadb.dart';
import 'package:courtboard/data/player_contributions.dart';
import 'package:courtboard/domain/player_contribution.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_http.dart';

MatchTimeline _summary(String name) =>
    MatchTimelineRepository.parseEspnSummary(fixture(name));

/// A timeline játékosstatisztikák (ESPN `rosters`) nélkül: csak az
/// eseményekből számolható hozzájárulás.
MatchTimeline _eventsOnly(MatchTimeline timeline) => MatchTimeline(
  events: timeline.events,
  home: timeline.home,
  away: timeline.away,
  homeScore: timeline.homeScore,
  awayScore: timeline.awayScore,
  finished: timeline.finished,
);

EspnGameLog _nflLog(String file, String name, String position) =>
    EspnAthleteRepository.parseGameLog(
      fixture(file),
      EspnAthleteRef(
        id: '1',
        displayName: name,
        league: EspnLeague.nfl,
        team: 'Team',
        position: position,
      ),
    );

EspnGameLogEntry _gameOn(EspnGameLog log, String utcDay) =>
    log.games.firstWhere(
      (game) => game.date.toUtc().toIso8601String().startsWith(utcDay),
    );

void main() {
  group('PlayerContribution modell', () {
    test('foci: gól és gólpassz, csak ami > 0', () {
      const both = PlayerContribution.football(goals: 2, assists: 1);
      expect(both.badgeText, '2 gól · 1 gólpassz');
      expect(both.hasBadge, isTrue);
      expect(
        both.withAthlete('Aitana Bonmatí').semanticsLabel,
        'Aitana Bonmatí 2 gólt szerzett és 1 gólpasszt adott',
      );
      const assist = PlayerContribution.football(assists: 1);
      expect(assist.badgeText, '1 gólpassz');
      expect(assist.semanticsLabel, 'A játékos 1 gólpasszt adott');
      const none = PlayerContribution.football();
      expect(none.hasBadge, isFalse);
      expect(none.isVisible, isFalse);
      expect(none.badgeText, isNull);
    });

    test('kosárlabda: pont, nullánál nincs kiemelés', () {
      const points = PlayerContribution.basketball(
        points: 24,
        athlete: 'Juhász Dorka',
      );
      expect(points.badgeText, '24 pont');
      expect(points.semanticsLabel, 'Juhász Dorka 24 pontot szerzett');
      expect(const PlayerContribution.basketball(points: 0).isVisible, isFalse);
    });

    test('NFL: TD és pont, rúgónál csak pont, passzolt TD külön', () {
      const runner = PlayerContribution.nfl(touchdowns: 2, points: 12);
      expect(runner.badgeText, '2 TD · 12 pont');
      expect(runner.note, isNull);
      const kicker = PlayerContribution.nfl(points: 9);
      expect(kicker.badgeText, '9 pont');
      const passer = PlayerContribution.nfl(passingTouchdowns: 3);
      expect(passer.hasBadge, isFalse);
      expect(passer.isVisible, isTrue);
      expect(passer.badgeText, isNull);
      expect(passer.note, '3 passzolt TD');
      expect(
        const PlayerContribution.nfl(
          touchdowns: 1,
          points: 6,
          passingTouchdowns: 2,
          athlete: 'Josh Allen',
        ).semanticsLabel,
        'Josh Allen 1 touchdownt szerzett, összesen 6 pontot, '
        '2 touchdownpasszt adott',
      );
    });
  });

  group('ESPN foci-összefoglaló', () {
    final city = _summary('espn_soccer_summary_assists.json');

    test('a gólpasszadó és a játékosstatisztika is bekerül', () {
      final goals = city.events.where((event) => event.type.isGoal).toList();
      expect(goals, hasLength(8));
      final cherki = goals.firstWhere((goal) => goal.player == 'Rayan Cherki');
      expect(cherki.assist, 'Antoine Semenyo');
      expect(
        goals.firstWhere((goal) => goal.player == 'Enzo Fernández').assist,
        isEmpty,
      );
      expect(city.hasPlayerStats, isTrue);
      final semenyo = city.players.firstWhere(
        (player) => player.name == 'Antoine Semenyo',
      );
      expect(semenyo.goals, 2);
      expect(semenyo.assists, 1);
      expect(semenyo.home, isTrue);
    });

    test('JSON oda-vissza: gólpassz és játékosstatisztika megmarad', () {
      final decoded = MatchTimeline.fromJson(
        jsonDecode(jsonEncode(city.toJson())),
      );
      expect(decoded.hasPlayerStats, isTrue);
      expect(decoded.players, hasLength(city.players.length));
      expect(
        decoded.events.firstWhere((e) => e.player == 'Rayan Cherki').assist,
        'Antoine Semenyo',
      );
    });

    test('hozzájárulás a játékosstatisztikából', () {
      expect(
        footballContributionFromTimeline(city, 'Antoine Semenyo'),
        const PlayerContribution.football(goals: 2, assists: 1, source: 'ESPN'),
      );
      expect(
        footballContributionFromTimeline(city, 'Erling Haaland')?.badgeText,
        '1 gól',
      );
      expect(
        footballContributionFromTimeline(city, 'Marc Guehi')?.badgeText,
        '1 gólpassz',
      );
      expect(footballContributionFromTimeline(city, 'Brian Brobbey')?.goals, 3);
      // Pályán volt, de nem szerzett pontot: nincs mit mutatni.
      expect(footballContributionFromTimeline(city, 'Rodri'), isNull);
    });

    test('csak az eseményekből is számol (gól és gólpassz)', () {
      final events = _eventsOnly(city);
      expect(events.hasPlayerStats, isFalse);
      expect(
        footballContributionFromTimeline(events, 'Antoine Semenyo'),
        const PlayerContribution.football(goals: 2, assists: 1, source: 'ESPN'),
      );
      expect(
        footballContributionFromTimeline(events, 'Josko Gvardiol')?.badgeText,
        '1 gólpassz',
      );
    });

    test('a saját csapat oldala szűr: az ellenfél névrokona nem számít', () {
      // Brobbey a vendég (Sunderland) játékosa.
      expect(
        footballContributionFromTimeline(city, 'Brian Brobbey', teamHome: true),
        isNull,
      );
      expect(
        footballContributionFromTimeline(
          _eventsOnly(city),
          'Brian Brobbey',
          teamHome: false,
        )?.goals,
        3,
      );
    });

    test('öngól: nem a szerző gólja, a gólpassz viszont számít', () {
      final fulham = _summary('espn_soccer_summary_own_goal.json');
      final own = fulham.events.firstWhere(
        (event) => event.type == TimelineEventType.ownGoal,
      );
      expect(own.player, 'Lisandro Martínez');
      expect(own.assist, isEmpty);
      for (final timeline in [fulham, _eventsOnly(fulham)]) {
        expect(
          footballContributionFromTimeline(timeline, 'Lisandro Martinez'),
          isNull,
        );
        expect(
          footballContributionFromTimeline(timeline, 'Matheus Cunha')?.goals,
          1,
        );
        expect(
          footballContributionFromTimeline(
            timeline,
            'Patrick Dorgu',
          )?.badgeText,
          '1 gólpassz',
        );
      }
    });

    test('Liga F: a gólpassz csak a játékosstatisztikában szerepel', () {
      final barca = _summary('espn_soccer_summary_barcelona.json');
      expect(
        footballContributionFromTimeline(
          barca,
          'Aitana Bonmatí',
          teamHome: true,
        ),
        const PlayerContribution.football(goals: 1, source: 'ESPN'),
      );
      expect(
        footballContributionFromTimeline(barca, 'Alexia Putellas')?.badgeText,
        '1 gólpassz',
      );
      expect(
        footballContributionFromTimeline(_eventsOnly(barca), 'Alexia Putellas'),
        isNull,
      );
    });

    test('az összefoglaló cache-kulcsa új (a régi idővonalban nincs '
        'játékosstatisztika)', () async {
      final http = FakeHttpService({
        '/apis/site/v2/sports/soccer/esp.w.1/summary': fixture(
          'espn_soccer_summary_barcelona.json',
        ),
      });
      final repository = MatchTimelineRepository(
        http: http,
        cacheStorage: MemoryCacheStorage(),
      );
      const match = EspnMatchRef(eventId: '749217', league: 'esp.w.1');
      final timeline = await repository.timeline(match);
      expect(timeline.hasPlayerStats, isTrue);
      await repository.timeline(match);
      expect(http.requests, hasLength(1));
    });
  });

  group('OpenLigaDB góllövők', () {
    final matches = [
      for (final raw
          in jsonDecode(
                File(
                  'test/fixtures/openligadb_bl1_2026.json',
                ).readAsStringSync(),
              )
              as List)
        raw as Map<String, dynamic>,
    ];
    final bayern = OpenLigaDbRepository.parseTeamGames(
      matches,
      league: OpenLigaLeague.bundesliga,
      teamId: 40,
      teamName: 'FC Bayern München',
      now: DateTime.utc(2026, 9, 30, 12),
    ).recentGames();

    test('rövidített név („H. Kane”) és mesterhármas', () {
      final union = bayern.firstWhere((game) => game.score == '7–0');
      expect(
        footballContributionFromTimeline(
          union.timeline!,
          'Harry Kane',
          teamHome: true,
        )?.badgeText,
        '2 gól',
      );
      expect(
        footballContributionFromTimeline(
          union.timeline!,
          'Michael Olise',
          teamHome: true,
        )?.goals,
        3,
      );
    });

    test('az öngól nem a szerzőé', () {
      final stuttgart = OpenLigaDbRepository.parseTeamGames(
        matches,
        league: OpenLigaLeague.bundesliga,
        teamId: 16,
        teamName: 'VfB Stuttgart',
        now: DateTime.utc(2026, 9, 30, 12),
      ).recentGames();
      final opener = stuttgart.firstWhere(
        (game) => game.opponent == 'FC Bayern München',
      );
      // J. Vagnoman: egy gól a Stuttgartnak, egy öngól a Bayernnek.
      expect(
        footballContributionFromTimeline(
          opener.timeline!,
          'Josha Vagnoman',
          teamHome: false,
        ),
        const PlayerContribution.football(goals: 1, source: 'OpenLigaDB'),
      );
    });
  });

  group('FotMob-meccsek párosítása', () {
    final forms = FotMobFootballRepository.parseRecentMatches(
      fixture('fotmob_player_aitana.json'),
    );

    test('azonos ellenfél, ±1 nap (időzóna-biztos)', () {
      final match = findFootballMatchForm(
        forms,
        date: DateTime.utc(2026, 5, 27, 17),
        opponent: 'Real Sociedad',
      );
      expect(match, isNotNull);
      expect(match!.goals, 1);
      // Csak dátum (helyi éjfél, TheSportsDB) és a „(W)” utótag nélkül.
      expect(
        findFootballMatchForm(
          forms,
          date: DateTime(2026, 5, 28),
          opponent: 'Real Sociedad Femenino',
        )?.goals,
        1,
      );
      expect(
        footballContributionFromForm(match, athlete: 'Aitana Bonmatí'),
        const PlayerContribution.football(
          goals: 1,
          athlete: 'Aitana Bonmatí',
          source: 'FotMob',
        ),
      );
    });

    test('más névvel: pontosan egyező kezdés és eredmény', () {
      // ESPN: „Dux Logroño”, FotMob: „Logroño United (W)”.
      final match = findFootballMatchForm(
        forms,
        date: DateTime.utc(2026, 9, 26, 14, 30),
        opponent: 'Dux Logroño',
        teamScore: 2,
        opponentScore: 0,
      );
      expect(match?.minutes, 12);
      expect(
        findFootballMatchForm(
          forms,
          date: DateTime.utc(2026, 9, 26, 14, 30),
          opponent: 'Dux Logroño',
          teamScore: 1,
          opponentScore: 0,
        ),
        isNull,
        reason: 'eltérő eredménynél nincs párosítás',
      );
    });

    test('nem párosít más napra vagy más ellenfélre', () {
      expect(
        findFootballMatchForm(
          forms,
          date: DateTime.utc(2026, 5, 30, 17),
          opponent: 'Real Sociedad',
        ),
        isNull,
      );
      expect(
        findFootballMatchForm(
          forms,
          date: DateTime.utc(2026, 5, 27, 17),
          opponent: 'Levante',
        ),
        isNull,
      );
      // A kispadon töltött meccs nem szerepel.
      expect(
        findFootballMatchForm(
          forms,
          date: DateTime.utc(2026, 5, 16, 19),
          opponent: 'Atlético Madrid',
        ),
        isNull,
      );
    });

    test('a „0 gól, 0 gólpassz” meccs is ismert, de nincs kiemelés', () {
      final match = findFootballMatchForm(
        forms,
        date: DateTime.utc(2026, 5, 10, 17),
        opponent: 'UD Tenerife',
      );
      expect(match, isNotNull);
      expect(footballContributionFromForm(match!).hasBadge, isFalse);
    });

    test('eredménypár a sor szövegéből', () {
      expect(parseScorePair('2–1'), (2, 1));
      expect(parseScorePair('1–1 (11-esek: 5–6)'), (1, 1));
      expect(parseScorePair('–'), isNull);
    });
  });

  group('NFL touchdownok és pontok (ESPN meccsnapló)', () {
    test('RB: futó + elkapó TD (Saquon Barkley)', () {
      final log = _nflLog(
        'espn_nfl_gamelog_barkley.json',
        'Saquon Barkley',
        'RB',
      );
      expect(
        nflContribution(_gameOn(log, '2025-10-26')),
        const PlayerContribution.nfl(touchdowns: 2, points: 12, source: 'ESPN'),
      );
      expect(
        nflContribution(_gameOn(log, '2025-10-05'))?.badgeText,
        '1 TD · 6 pont',
      );
      expect(nflContribution(_gameOn(log, '2025-12-20'))?.touchdowns, 1);
    });

    test('K: 3 × mezőnygól + extra pont (a hibás PTS-oszlop helyett)', () {
      final log = _nflLog(
        'espn_nfl_gamelog_elliott.json',
        'Jake Elliott',
        'PK',
      );
      // Az ESPN „totalKickingPoints” itt 5, de 1 FG + 3 XP = 6.
      expect(nflContribution(_gameOn(log, '2026-09-13'))?.badgeText, '6 pont');
      expect(nflContribution(_gameOn(log, '2026-09-20'))?.points, 6);
      expect(nflContribution(_gameOn(log, '2026-09-29'))?.badgeText, '1 pont');
    });

    test('QB: a passzolt TD külön, nem a saját pontja', () {
      final log = _nflLog('espn_nfl_gamelog_allen.json', 'Josh Allen', 'QB');
      final detroit = nflContribution(_gameOn(log, '2026-09-18'))!;
      expect(detroit.badgeText, '2 TD · 12 pont');
      expect(detroit.note, '3 passzolt TD');
      final chargers = nflContribution(_gameOn(log, '2026-09-27'))!;
      expect(chargers.touchdowns, 2);
      expect(chargers.note, isNull);
    });

    test('hiányzó oszlopoknál nincs kitalált érték', () {
      final game = EspnGameLogEntry(
        eventId: '1',
        date: DateTime(2026, 9, 1),
        opponent: 'X',
        stats: const {'totalTackles': '7'},
      );
      expect(nflContribution(game), isNull);
      final zero = EspnGameLogEntry(
        eventId: '2',
        date: DateTime(2026, 9, 1),
        opponent: 'X',
        stats: const {'rushingTouchdowns': '0', 'receivingTouchdowns': '0'},
      );
      expect(nflContribution(zero)?.isVisible, isFalse);
      final defender = EspnGameLogEntry(
        eventId: '3',
        date: DateTime(2026, 9, 1),
        opponent: 'X',
        stats: const {'interceptionTouchdowns': '1', 'totalTackles': '5'},
      );
      expect(nflContribution(defender)?.badgeText, '1 TD · 6 pont');
    });

    test('a meccsösszegzésből kimarad a passzolt TD, ha külön látszik', () {
      final log = _nflLog('espn_nfl_gamelog_allen.json', 'Josh Allen', 'QB');
      final game = _gameOn(log, '2026-09-18');
      expect(nflGameSummary(game), contains('3 TD'));
      expect(
        nflGameSummary(game, includePassingTouchdowns: false),
        isNot(contains('TD')),
      );
    });
  });
}
