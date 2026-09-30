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

  Map<String, dynamic> match(
    String home,
    int homeId,
    String away,
    int awayId,
    String winner,
    int homeGoals,
    int awayGoals,
  ) =>
      {
        'utcDate': '2026-03-01T20:00:00Z',
        'homeTeam': {'id': homeId, 'name': home},
        'awayTeam': {'id': awayId, 'name': away},
        'score': {
          'winner': winner,
          'fullTime': {'home': homeGoals, 'away': awayGoals},
        },
      };

  test('FC Barcelona home and away games are detected by team id', () {
    final games = FootballDataRepository.parseMatches({
      'matches': [
        match('FC Barcelona', 81, 'Real Madrid CF', 86, 'HOME_TEAM', 3, 1),
        {
          ...match('Real Madrid CF', 86, 'FC Barcelona', 81, 'AWAY_TEAM', 0, 2),
          'utcDate': '2026-03-08T20:00:00Z',
        },
      ],
    }, 'Barcelona', teamId: 81);

    expect(games.map((game) => game.opponent),
        ['Real Madrid CF', 'Real Madrid CF']);
    expect(games.map((game) => game.score), ['2–0', '3–1']);
    expect(games.every((game) => game.result == FootballResult.win), isTrue);
  });

  test('name fallback handles FC/CF/AFC affixes on either side', () {
    final away = FootballDataRepository.parseMatches({
      'matches': [
        match('Real Madrid CF', 86, 'FC Barcelona', 81, 'HOME_TEAM', 2, 1),
      ],
    }, 'Barcelona');
    expect(away.single.opponent, 'Real Madrid CF');
    expect(away.single.score, '1–2');
    expect(away.single.result, FootballResult.loss);

    final bournemouth = FootballDataRepository.parseMatches({
      'matches': [
        match('Arsenal FC', 57, 'AFC Bournemouth', 1044, 'AWAY_TEAM', 0, 1),
      ],
    }, 'AFC Bournemouth');
    expect(bournemouth.single.opponent, 'Arsenal FC');
    expect(bournemouth.single.result, FootballResult.win);
  });

  test('TheSportsDB strTime is UTC and converted to local time', () {
    final parsed =
        FootballDataRepository.parseTheSportsDbEventTime('2026-08-09', '19:30:00');
    expect(parsed, isNotNull);
    expect(parsed!.isUtc, isFalse);
    expect(parsed.toUtc(), DateTime.utc(2026, 8, 9, 19, 30));
    expect(
      FootballDataRepository.parseTheSportsDbEventTime('2026-08-09', '')
          ?.day,
      9,
    );
    expect(
        FootballDataRepository.parseTheSportsDbEventTime('', '19:30:00'), isNull);
  });

  test('TheSportsDB rows without a date are skipped', () {
    final games = FootballDataRepository.parseTheSportsDbMatches({
      'results': [
        {'dateEvent': '', 'idHomeTeam': '1', 'strAwayTeam': 'X'},
        {
          'dateEvent': '2026-08-05',
          'idHomeTeam': '1',
          'strAwayTeam': 'Y',
          'intHomeScore': '1',
          'intAwayScore': '1',
        },
      ],
    }, '1');
    expect(games.single.opponent, 'Y');
    expect(games.single.result, FootballResult.draw);
  });
}
