import 'package:flutter_test/flutter_test.dart';
import 'package:courtboard/data/football_data.dart';

void main() {
  test('football-data parser derives Liverpool result and opponent', () {
    final games = FootballDataRepository.parseMatches({
      'matches': [
        {
          'utcDate': '2026-01-20T20:00:00Z',
          'homeTeam': {'name': 'Liverpool FC'},
          'awayTeam': {'name': 'Arsenal FC'},
          'score': {
            'winner': 'HOME_TEAM',
            'fullTime': {'home': 2, 'away': 1}
          }
        }
      ]
    }, 'Liverpool');

    expect(games.single.opponent, 'Arsenal FC');
    expect(games.single.score, '2–1');
    expect(games.single.result, FootballResult.win);
  });

  test('parser returns newest matches first and limits the feed to five', () {
    final games = FootballDataRepository.parseMatches({
      'matches': List.generate(
          6,
          (index) => {
                'utcDate': '2026-01-${10 + index}T20:00:00Z',
                'homeTeam': {'name': 'Liverpool FC'},
                'awayTeam': {'name': 'Team $index'},
                'score': {
                  'winner': 'HOME_TEAM',
                  'fullTime': {'home': 1, 'away': 0}
                }
              })
    }, 'Liverpool');
    expect(games, hasLength(5));
    expect(games.first.opponent, 'Team 5');
  });
}
