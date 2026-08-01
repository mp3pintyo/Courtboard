import 'package:courtboard/data/rapidapi_wnba.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('RapidAPI WNBA parser selects latest averages and WNBA awards', () {
    final profile = WnbaRapidApiRepository.parseProfile('4433403', {
      'bio': {
        'data': {
          'teamHistory': [
            {'displayName': 'Indiana Fever', 'isActive': true}
          ],
          'awards': [
            {
              'league': 'wnba',
              'name': 'Rookie of the Year',
              'displayCount': '1x'
            },
            {'league': 'ncaa', 'name': 'College award'}
          ]
        }
      },
      'advanced': {
        'player_stats': {
          'categories': [
            {
              'name': 'averages',
              'labels': ['GP', 'PTS', 'REB', 'AST'],
              'statistics': [
                {
                  'season': {'year': 2024},
                  'stats': ['40', '19.2', '5.7', '8.4']
                },
                {
                  'season': {'year': 2026},
                  'stats': ['20', '21.5', '6.1', '9.0']
                }
              ]
            }
          ]
        }
      }
    });

    expect(profile.team, 'Indiana Fever');
    expect(profile.season, 2026);
    expect(profile.facts.map((fact) => fact.value),
        containsAll(['20', '21.5', '6.1', '9.0']));
    expect(profile.awards.single, '1x Rookie of the Year');
  });
}
