import 'dart:convert';
import 'dart:io';

import 'package:courtboard/data/football_data.dart';
import 'package:courtboard/data/json_file_cache.dart';
import 'package:courtboard/data/match_timeline.dart';
import 'package:courtboard/data/openligadb.dart';
import 'package:courtboard/data/sports_api.dart';
import 'package:courtboard/data/upcoming_events.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_http.dart';

/// Lista gyökerű fixture (az OpenLigaDB tömböt ad; a közös HTTP-réteg
/// `{'data': [...]}` alakban adja tovább).
Map<String, dynamic> _listFixture(String name) => {
  'data': jsonDecode(File('test/fixtures/$name').readAsStringSync()),
};

List<Map<String, dynamic>> _matches() => [
  for (final raw in _listFixture('openligadb_bl1_2026.json')['data'] as List)
    raw as Map<String, dynamic>,
];

final _now = DateTime.utc(2026, 9, 30, 12);

void main() {
  group('OpenLigaDB', () {
    test('szezon: júliustól az új év', () {
      expect(OpenLigaDbRepository.seasonOf(DateTime(2026, 9, 30)), 2026);
      expect(OpenLigaDbRepository.seasonOf(DateTime(2027, 3, 1)), 2026);
      expect(OpenLigaDbRepository.seasonOf(DateTime(2026, 7, 1)), 2026);
    });

    test('csapatfeloldás teljes és rövid névvel', () {
      final teams = [
        for (final raw
            in _listFixture('openligadb_teams_bl1_2026.json')['data'] as List)
          raw as Map<String, dynamic>,
      ];
      expect(
        OpenLigaDbRepository.findTeamIn(teams, 'FC Bayern München')?.$2,
        40,
      );
      expect(OpenLigaDbRepository.findTeamIn(teams, 'Bayern München')?.$2, 40);
      expect(OpenLigaDbRepository.findTeamIn(teams, 'Liverpool'), isNull);
    });

    test('lejátszott meccsek végeredménnyel és gólokkal, közelgők külön', () {
      final games = OpenLigaDbRepository.parseTeamGames(
        _matches(),
        league: OpenLigaLeague.bundesliga,
        teamId: 40,
        teamName: 'FC Bayern München',
        now: _now,
      );
      expect(games.recent, hasLength(4));
      expect(games.upcoming, isNotEmpty);
      final latest = games.recent.first;
      expect(latest.home, 'FC Bayern München');
      expect(latest.homeGoals, 7);
      expect(latest.awayGoals, 0);
      expect(latest.round, '4. forduló');
      expect(latest.goals, hasLength(7));
      expect(latest.goals.last.score, '7–0');
      expect(latest.goals.every((goal) => goal.home == true), isTrue);

      final opener = games.recent.last;
      final ownGoal = opener.goals.firstWhere(
        (goal) => goal.type == TimelineEventType.ownGoal,
      );
      expect(ownGoal.player, 'J. Vagnoman');
      expect(ownGoal.minute, "57'");
      // Az öngól a javára írt csapatnál (Bayern, hazai) számít.
      expect(ownGoal.home, isTrue);
      expect(opener.goals.last.minute, startsWith('90+'));

      final recent = games.recentGames();
      expect(recent.first.score, '7–0');
      expect(recent.first.result, FootballResult.win);
      expect(recent.first.homeAway, 'home');
      expect(recent.first.timeline?.events, hasLength(7));
      expect(recent.first.source, 'OpenLigaDB');
      final away = recent.firstWhere(
        (game) => game.opponent == 'SV 07 Elversberg',
      );
      expect(away.homeAway, 'away');
      expect(away.score, '2–1');
      expect(away.result, FootballResult.win);
      final draw = recent.firstWhere(
        (game) => game.opponent == 'FC Schalke 04',
      );
      expect(draw.result, FootballResult.draw);
    });

    test('naptáresemények a közelgő meccsekből', () {
      final games = OpenLigaDbRepository.parseTeamGames(
        _matches(),
        league: OpenLigaLeague.bundesliga,
        teamId: 40,
        teamName: 'FC Bayern München',
        now: _now,
      );
      final events = games.events(athleteName: 'Harry Kane');
      expect(events, isNotEmpty);
      expect(events.first.source, 'OpenLigaDB');
      expect(events.first.competition, startsWith('Bundesliga · '));
      expect(events.first.start.isAfter(_now), isTrue);
      expect(events.first.opponent, isNot('FC Bayern München'));
    });

    test(
      'csapatmeccsek: ha a TheSportsDB nem ismeri, az OpenLigaDB pótol',
      () async {
        final http = FakeHttpService({
          '/api/v1/json/123/searchteams.php': const {'teams': null},
          '/getavailableteams/bl1/2026': _listFixture(
            'openligadb_teams_bl1_2026.json',
          ),
          '/getmatchdata/bl1/2026': _listFixture('openligadb_bl1_2026.json'),
        });
        final storage = MemoryCacheStorage();
        final repository = FootballDataRepository(
          SportsApiClient(
            config: const SportsApiConfig(),
            http: http,
            cacheStorage: storage,
          ),
          openLiga: OpenLigaDbRepository(
            http: http,
            cacheStorage: storage,
            clock: () => _now,
          ),
        );
        final games = await repository.fetchTeamGames('FC Bayern München');
        expect(games.recent, hasLength(4));
        expect(games.upcoming, hasLength(4));
        expect(games.recent.first.timeline, isNotNull);
        expect(games.warnings, isEmpty);
      },
    );

    test('naptár: német csapatnál OpenLigaDB-menetrend', () async {
      final http = FakeHttpService({
        '/api/v1/json/123/searchteams.php': const {'teams': null},
        '/getavailableteams/bl1/2026': _listFixture(
          'openligadb_teams_bl1_2026.json',
        ),
        '/getmatchdata/bl1/2026': _listFixture('openligadb_bl1_2026.json'),
      });
      final repository = UpcomingEventsRepository(
        http: http,
        cacheStorage: MemoryCacheStorage(clock: () => _now),
        clock: () => _now,
      );
      final result = await repository.fetchFor(
        const UpcomingEventsTarget(
          name: 'Harry Kane',
          sport: 'Foci',
          team: 'FC Bayern München',
        ),
        config: const SportsApiConfig(),
      );
      expect(result.error, isNull);
      expect(result.unavailable, isNull);
      expect(result.events, isNotEmpty);
      expect(result.events.first.source, 'OpenLigaDB');
    });

    test('nem német csapatnál nincs OpenLigaDB-adat', () async {
      final http = FakeHttpService({
        '/getavailableteams/bl1/2026': _listFixture(
          'openligadb_teams_bl1_2026.json',
        ),
        '/getavailableteams/bl2/2026': const {'data': <Object>[]},
        '/getavailableteams/ffb1/2026': const {'data': <Object>[]},
        '/getavailableteams/fbl1/2026': const {'data': <Object>[]},
      });
      final repository = OpenLigaDbRepository(
        http: http,
        cacheStorage: MemoryCacheStorage(),
        clock: () => _now,
      );
      expect(await repository.teamGames('Liverpool'), isNull);
    });
  });

  group('ESPN mérkőzés-idővonal', () {
    final timeline = MatchTimelineRepository.parseEspnSummary(
      fixture('espn_soccer_summary_final.json'),
    );

    test('gólok, lapok és cserék perccel, időrendben', () {
      expect(timeline.finished, isTrue);
      expect(timeline.home, 'Athletic Club');
      expect(timeline.homeScore, '3');
      expect(timeline.awayScore, '2');
      final goals = timeline.events
          .where((event) => event.type.isGoal)
          .toList();
      expect(goals, hasLength(5));
      expect(goals.first.minute, "1'");
      expect(goals.first.player, 'Ane Azkona');
      expect(goals.first.home, isTrue);
      expect(goals.first.score, '1–0');
      expect(goals.last.score, '3–2');
      expect(
        timeline.events.where((e) => e.type == TimelineEventType.yellowCard),
        hasLength(5),
      );
      expect(
        timeline.events.where((e) => e.type == TimelineEventType.redCard),
        hasLength(2),
      );
      final sub = timeline.events.firstWhere(
        (e) => e.type == TimelineEventType.substitution,
      );
      expect(sub.player, 'Ane Elexpuru');
      expect(sub.secondaryPlayer, 'Vilariño');
      expect(sub.minute, "58'");
      final keys = [for (final event in timeline.events) event.sortKey];
      expect(keys, orderedEquals([...keys]..sort()));
    });

    test('befejezett meccs végleges cache, zajló 60 mp', () async {
      var now = DateTime(2026, 9, 30, 12);
      final summary = fixture('espn_soccer_summary_final.json');
      final live = jsonDecode(jsonEncode(summary)) as Map<String, dynamic>;
      final competition =
          ((live['header'] as Map)['competitions'] as List).first as Map;
      competition['status'] = {
        'type': {'state': 'in', 'completed': false, 'shortDetail': "63'"},
      };
      final http = FakeHttpService({
        '/apis/site/v2/sports/soccer/esp.w.1/summary': summary,
        '/apis/site/v2/sports/soccer/all/summary': live,
      });
      final repository = MatchTimelineRepository(
        http: http,
        cacheStorage: MemoryCacheStorage(clock: () => now),
        clock: () => now,
      );
      const finished = EspnMatchRef(eventId: '401882508', league: 'esp.w.1');
      const running = EspnMatchRef(eventId: '401882508');
      await repository.timeline(finished);
      await repository.timeline(running);
      expect(http.requests, hasLength(2));
      now = now.add(const Duration(days: 30));
      await repository.timeline(finished);
      expect(http.requests, hasLength(2), reason: 'végleges idővonal');
      await repository.timeline(running);
      expect(http.requests, hasLength(3), reason: 'élő meccs: 60 mp után újra');
    });
  });
}
