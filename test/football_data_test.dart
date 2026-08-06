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
            'fullTime': {'home': 2, 'away': 1},
          },
        },
      ],
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
            'fullTime': {'home': 1, 'away': 0},
          },
        },
      ),
    }, 'Liverpool');
    expect(games, hasLength(5));
    expect(games.first.opponent, 'Team 5');
  });

  test('football-data resolves any supported team dynamically', () {
    final id = FootballDataRepository.parseFootballDataTeamId({
      'teams': [
        {
          'id': 5,
          'name': 'FC Bayern München',
          'shortName': 'Bayern München',
          'tla': 'FCB',
        },
      ],
    }, 'Bayern München');

    expect(id, 5);
  });

  test('TheSportsDB resolves Inter Miami CF aliases', () {
    final id = FootballDataRepository.parseTheSportsDbTeamId({
      'teams': [
        {
          'idTeam': '137699',
          'strTeam': 'Inter Miami',
          'strTeamAlternate':
              'Inter Miami CF, Club Internacional de Fútbol Miami',
          'strSport': 'Soccer',
        },
      ],
    }, 'Inter Miami CF');

    expect(id, '137699');
  });

  test(
    'TheSportsDB parser handles completed and upcoming Inter Miami games',
    () {
      final completed = FootballDataRepository.parseTheSportsDbMatches({
        'results': [
          {
            'dateEvent': '2026-08-05',
            'idHomeTeam': '137699',
            'idAwayTeam': '136856',
            'strHomeTeam': 'Inter Miami',
            'strAwayTeam': 'Atlético de San Luis',
            'intHomeScore': '4',
            'intAwayScore': '2',
          },
        ],
      }, '137699');
      final upcoming = FootballDataRepository.parseTheSportsDbMatches({
        'events': [
          {
            'dateEvent': '2026-08-09',
            'strTime': '00:00:00',
            'idHomeTeam': '137699',
            'idAwayTeam': '134198',
            'strHomeTeam': 'Inter Miami',
            'strAwayTeam': 'Monterrey',
            'intHomeScore': null,
            'intAwayScore': null,
          },
        ],
      }, '137699');

      expect(completed.single.opponent, 'Atlético de San Luis');
      expect(completed.single.score, '4–2');
      expect(completed.single.result, FootballResult.win);
      expect(upcoming.single.opponent, 'Monterrey');
      expect(upcoming.single.score, '–');
      expect(upcoming.single.result, FootballResult.unknown);
    },
  );
}
