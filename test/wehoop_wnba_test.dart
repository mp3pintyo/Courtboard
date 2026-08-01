import 'package:flutter_test/flutter_test.dart';
import 'package:courtboard/data/wehoop_wnba.dart';

void main() {
  test('wehoop parser returns normalized player game logs newest first', () {
    const csv =
        '''game_id,game_date,athlete_display_name,team_name,opponent_team_name,opponent_team_display_name,team_location,team_score,opponent_team_score,team_result,points,rebounds,assists,steals,blocks,minutes,athlete_headshot_href
1,2026-06-01,Caitlin Clark,Fever,Liberty,New York Liberty,Indiana,88,81,WIN,21,5,9,2,1,34.0,https://cdn.example/clark.png
2,2026-06-03,Caitlin Clark,Fever,Mystics,Washington Mystics,Indiana,72,80,LOSS,17,8,11,1,0,36.0,https://cdn.example/clark.png
3,2026-06-02,Another Player,Storm,Fever,Indiana Fever,Seattle,90,74,WIN,12,3,4,0,2,20.0,https://cdn.example/other.png
''';

    final logs = WnbaWehoopRepository.parsePlayerGames(csv, 'Caitlin Clark');

    expect(logs, hasLength(2));
    expect(logs.first.opponent, 'Washington Mystics');
    expect(logs.first.score, '72–80');
    expect(logs.first.result, WnbaResult.loss);
    expect(logs.first.points, 17);
    expect(logs.first.assists, 11);
    expect(logs.first.headshotUrl, 'https://cdn.example/clark.png');
  });
  test('season summary calculates per-game averages from actual logs', () {
    final games = [
      _game(points: 20, rebounds: 4, assists: 8),
      _game(points: 10, rebounds: 8, assists: 4),
    ];

    final summary = WnbaSeasonSummary.fromGames(games);

    expect(summary.games, 2);
    expect(summary.pointsPerGame, 15);
    expect(summary.reboundsPerGame, 6);
    expect(summary.assistsPerGame, 6);
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
}

WnbaGameLog _game(
        {required int points, required int rebounds, required int assists}) =>
    WnbaGameLog(
      gameId: 'test',
      date: DateTime(2026, 1, 1),
      team: 'Fever',
      opponent: 'Storm',
      points: points,
      rebounds: rebounds,
      assists: assists,
      steals: 0,
      blocks: 0,
      minutes: 30,
      headshotUrl: '',
    );
