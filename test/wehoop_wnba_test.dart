import 'dart:io';

import 'package:courtboard/data/http_util.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:courtboard/data/wehoop_wnba.dart';

const _header =
    'game_id,game_date,athlete_display_name,athlete_id,team_name,opponent_team_name,team_score,opponent_team_score,team_result,points,rebounds,assists,steals,blocks,minutes,athlete_headshot_href';

String _csv(String date, int points) =>
    '$_header\n'
    '1,$date,Caitlin Clark,4433403,Fever,Liberty,88,81,WIN,$points,5,9,2,1,34.0,\n';

void main() {
  test('wehoop parser returns normalized player game logs newest first', () {
    const csv =
        '''game_id,game_date,athlete_display_name,team_name,opponent_team_name,opponent_team_display_name,team_location,team_score,opponent_team_score,team_result,points,rebounds,assists,steals,blocks,minutes,turnovers,field_goals_made,field_goals_attempted,season_type,athlete_headshot_href
1,2026-06-01,Caitlin Clark,Fever,Liberty,New York Liberty,Indiana,88,81,WIN,21,5,9,2,1,34.0,4,7,14,2,https://cdn.example/clark.png
2,2026-06-03,Caitlin Clark,Fever,Mystics,Washington Mystics,Indiana,72,80,LOSS,17,8,11,1,0,36.0,2,6,16,2,https://cdn.example/clark.png
3,2026-06-02,Another Player,Storm,Fever,Indiana Fever,Seattle,90,74,WIN,12,3,4,0,2,20.0,1,5,10,2,https://cdn.example/other.png
''';

    final logs = WnbaWehoopRepository.parsePlayerGames(csv, 'Caitlin Clark');

    expect(logs, hasLength(2));
    expect(logs.first.opponent, 'Washington Mystics');
    expect(logs.first.score, '72–80');
    expect(logs.first.result, WnbaResult.loss);
    expect(logs.first.points, 17);
    expect(logs.first.assists, 11);
    expect(logs.first.turnovers, 2);
    expect(logs.first.fieldGoalsMade, 6);
    expect(logs.first.fieldGoalsAttempted, 16);
    expect(logs.first.headshotUrl, 'https://cdn.example/clark.png');
  });
  test('season summary calculates per-game averages from actual logs', () {
    final games = [
      _game(
          points: 20,
          rebounds: 4,
          assists: 8,
          minutes: 32,
          steals: 2,
          turnovers: 4,
          fieldGoalsMade: 8,
          fieldGoalsAttempted: 16),
      _game(
          points: 10,
          rebounds: 8,
          assists: 4,
          minutes: 28,
          steals: 0,
          turnovers: 2,
          fieldGoalsMade: 4,
          fieldGoalsAttempted: 14),
    ];

    final summary = WnbaSeasonSummary.fromGames(games);

    expect(summary.games, 2);
    expect(summary.pointsPerGame, 15);
    expect(summary.reboundsPerGame, 6);
    expect(summary.assistsPerGame, 6);
    expect(summary.minutesPerGame, 30);
    expect(summary.stealsPerGame, 1);
    expect(summary.turnoversPerGame, 3);
    expect(summary.fieldGoalPercentage, 40);
  });

  test('Hungarian accents and reversed name order resolve the ESPN ID', () {
    const csv =
        '''game_id,game_date,athlete_display_name,athlete_id,team_name,opponent_team_name,team_score,opponent_team_score,team_result,points,rebounds,assists,steals,blocks,minutes,athlete_headshot_href
1,2026-07-30,Dorka Juhasz,4398938,Lynx,Tempo,104,72,WIN,12,5,2,1,1,22.0,https://cdn.example/juhasz.png
2,2026-07-30,Dorka Juhasz-Smith,999,Lynx,Tempo,104,72,WIN,9,3,1,0,0,18.0,https://cdn.example/other.png
''';

    final logs = WnbaWehoopRepository.parsePlayerGames(csv, 'Juhász Dorka');

    expect(logs, hasLength(1));
    expect(logs.single.athleteId, '4398938');
    expect(logs.single.points, 12);
  });

  group('season cache and fallback', () {
    late Directory cache;
    setUp(() async {
      cache = await Directory.systemTemp.createTemp('courtboard-wehoop-');
    });
    tearDown(() => cache.delete(recursive: true));

    test('off-season 404 falls back to the previous season', () async {
      final requested = <String>[];
      final repository = WnbaWehoopRepository(
        cacheDirectory: cache,
        fetchCsv: (uri) async {
          requested.add(uri.pathSegments.last);
          if (uri.path.endsWith('player_box_2026.csv')) {
            throw CourtboardHttpException(
                provider: 'wehoop WNBA', statusCode: 404, uri: uri);
          }
          return _csv('2025-09-10', 30);
        },
      );

      final games = await repository.recentGames('Caitlin Clark',
          now: DateTime(2026, 3, 1));

      expect(games.single.points, 30);
      expect(requested, ['player_box_2026.csv', 'player_box_2025.csv']);
      expect(File('${cache.path}/player_box_2025.csv').existsSync(), isTrue);
    });

    test('past seasons are served from disk without a download', () async {
      await File('${cache.path}/player_box_2024.csv')
          .writeAsString(_csv('2024-08-01', 12));
      await File('${cache.path}/player_box_2024.csv')
          .setLastModified(DateTime.now().subtract(const Duration(days: 400)));
      final repository = WnbaWehoopRepository(
        cacheDirectory: cache,
        fetchCsv: (uri) async => throw StateError('no network expected'),
      );

      final games = await repository.recentGames('Caitlin Clark',
          season: 2024, now: DateTime(2026, 8, 1));

      expect(games.single.points, 12);
    });

    test('expired current season is refreshed, stale copy used offline',
        () async {
      final file = File('${cache.path}/player_box_2026.csv');
      await file.writeAsString(_csv('2026-06-01', 10));
      await file.setLastModified(
          DateTime.now().subtract(const Duration(hours: 13)));

      final offline = WnbaWehoopRepository(
        cacheDirectory: cache,
        fetchCsv: (uri) async => throw CourtboardHttpException(
            provider: 'wehoop WNBA', uri: uri, timedOut: true),
      );
      final stale = await offline.recentGames('Caitlin Clark',
          season: 2026, now: DateTime(2026, 8, 1));
      expect(stale.single.points, 10);

      final refreshCache =
          await Directory.systemTemp.createTemp('courtboard-wehoop-');
      addTearDown(() => refreshCache.delete(recursive: true));
      final refreshed = File('${refreshCache.path}/player_box_2026.csv');
      await refreshed.writeAsString(_csv('2026-06-01', 10));
      await refreshed.setLastModified(
          DateTime.now().subtract(const Duration(hours: 13)));
      var downloads = 0;
      final online = WnbaWehoopRepository(
        cacheDirectory: refreshCache,
        fetchCsv: (uri) async {
          downloads++;
          return _csv('2026-07-01', 25);
        },
      );
      final fresh = await online.recentGames('Caitlin Clark',
          season: 2026, now: DateTime(2026, 8, 1));
      final again = await online.recentGames('Caitlin Clark',
          season: 2026, now: DateTime(2026, 8, 1));

      expect(fresh.single.points, 25);
      expect(again.single.points, 25);
      expect(downloads, 1);
      expect(await refreshed.readAsString(), contains('2026-07-01'));
    });
  });
}

WnbaGameLog _game({
  required int points,
  required int rebounds,
  required int assists,
  double minutes = 30,
  int steals = 0,
  int turnovers = 0,
  int fieldGoalsMade = 0,
  int fieldGoalsAttempted = 0,
}) =>
    WnbaGameLog(
      gameId: 'test',
      date: DateTime(2026, 1, 1),
      team: 'Fever',
      opponent: 'Storm',
      points: points,
      rebounds: rebounds,
      assists: assists,
      steals: steals,
      blocks: 0,
      minutes: minutes,
      turnovers: turnovers,
      fieldGoalsMade: fieldGoalsMade,
      fieldGoalsAttempted: fieldGoalsAttempted,
      headshotUrl: '',
    );
