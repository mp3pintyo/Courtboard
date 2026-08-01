import 'package:courtboard/data/fotmob_football.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('FotMob search matches reversed accented player names', () {
    final id = FotMobFootballRepository.parsePlayerId({
      'squadMemberSuggest': [
        {
          'options': [
            {
              'text': 'Aitana Martínez|123',
              'payload': {'id': '123'}
            },
            {
              'text': 'Aitana Bonmati|887411',
              'payload': {'id': '887411'}
            }
          ]
        }
      ]
    }, 'Bonmatí Aitana');

    expect(id, 887411);
  });

  test('FotMob parser accepts previous season and reads all summary fields',
      () {
    final stat = FotMobFootballRepository.parseSeasonSummary({
      'primaryTeam': {'teamName': 'Barcelona'},
      'mainLeague': {
        'leagueName': 'Liga F',
        'season': '2025/2026',
        'stats': [
          {'localizedTitleId': 'goals', 'value': 7},
          {'localizedTitleId': 'assists', 'value': 3},
          {'localizedTitleId': 'matches_uppercase', 'value': 15},
          {'localizedTitleId': 'rating', 'value': 7.61},
          {'localizedTitleId': 'yellow_cards', 'value': 0},
          {'localizedTitleId': 'red_cards', 'value': 0},
        ]
      }
    }, now: DateTime(2026, 8, 1));

    expect(stat, isNotNull);
    expect(stat!.team, 'Barcelona');
    expect(stat.competition, 'Liga F');
    expect(stat.rating, 7.61);
    expect(stat.appearances, 15);
    expect(stat.goals, 7);
    expect(stat.assists, 3);
    expect(stat.yellowCards, 0);
    expect(stat.redCards, 0);
  });

  test('FotMob parser rejects stale seasons', () {
    final stat = FotMobFootballRepository.parseSeasonSummary({
      'primaryTeam': {'teamName': 'Liverpool'},
      'mainLeague': {
        'leagueName': 'Premier League',
        'season': '2023/2024',
        'stats': [
          {'localizedTitleId': 'goals', 'value': 3}
        ]
      }
    }, now: DateTime(2026, 8, 1));

    expect(stat, isNull);
  });
}
