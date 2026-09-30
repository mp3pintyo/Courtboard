import 'package:courtboard/data/football_season.dart';
import 'package:courtboard/data/football_season_repository.dart';
import 'package:flutter_test/flutter_test.dart';

FootballSeasonStat _stat(String team, int? appearances) => FootballSeasonStat(
  season: '2025/2026',
  team: team,
  competition: 'Liga $team ${appearances ?? 'x'}',
  source: 'Teszt',
  appearances: appearances,
);

void main() {
  test(
    'season rows use a total order: own team, then appearances, nulls last',
    () {
      final compare = FootballSeasonRepository.compareForTeam('Liverpool');
      final rows = [
        _stat('Hungary', null),
        _stat('Liverpool', null),
        _stat('Hungary', 8),
        _stat('Liverpool', 30),
        _stat('Other', null),
      ]..sort(compare);

      expect(rows.map((row) => '${row.team}:${row.appearances}'), [
        'Liverpool:30',
        'Liverpool:null',
        'Hungary:8',
        'Hungary:null',
        'Other:null',
      ]);
      expect(compare(_stat('A', null), _stat('B', null)), 0);
      expect(compare(_stat('A', 3), _stat('B', null)), lessThan(0));
      expect(compare(_stat('A', null), _stat('B', 3)), greaterThan(0));
    },
  );
}
