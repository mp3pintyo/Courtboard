import 'package:courtboard/data/darts.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('TheSportsDB darts results are newest first and limited to five', () {
    final results = DartsRepository.parseResults({
      'results': [
        {
          'dateEvent': '2026-07-21',
          'strEvent': 'World Matchplay Day 4',
          'strDetail': 'WIN',
          'intPosition': '3'
        },
        {
          'dateEvent': '2026-07-26',
          'strEvent': 'World Matchplay Day 9',
          'strDetail': 'WIN',
          'intPosition': '1'
        }
      ]
    });

    expect(results.first.event, 'World Matchplay Day 9');
    expect(results.first.detail, 'WIN');
    expect(results.first.position, 1);
  });

  test('RapidAPI competition parser accepts the documented data envelope', () {
    final competitions = DartsRepository.parseCompetitions({
      'data': [
        {'competitionId': 123, 'competitionName': 'PDC World Championship'}
      ]
    });

    expect(competitions.single.name, 'PDC World Championship');
    expect(competitions.single.id, '123');
  });
}
