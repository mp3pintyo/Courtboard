import 'package:courtboard/data/espn_liga_f.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Liga F parser returns only completed Barcelona matches', () {
    final games = LigaFRepository.parseGames({
      'events': [
        {
          'date': '2026-04-22T17:00Z',
          'competitions': [
            {
              'status': {
                'type': {'completed': true}
              },
              'competitors': [
                {
                  'homeAway': 'away',
                  'score': '4',
                  'team': {'displayName': 'Barcelona'}
                },
                {
                  'homeAway': 'home',
                  'score': '1',
                  'team': {'displayName': 'Espanyol'}
                }
              ]
            }
          ]
        }
      ]
    }, 'Barcelona');

    expect(games.single.opponent, 'Espanyol');
    expect(games.single.score, '4–1');
    expect(games.single.result, 'GYŐZELEM');
    expect(games.single.home, isFalse);
  });
}
