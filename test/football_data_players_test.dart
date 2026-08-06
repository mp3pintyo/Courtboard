import 'dart:io';

import 'package:courtboard/data/football_data_players.dart';
import 'package:courtboard/data/sports_api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'free competition parser keeps only TIER_ONE and prioritizes leagues',
    () {
      final codes = FootballDataPlayerRepository.parseFreeCompetitionCodes({
        'competitions': [
          {'code': 'WC', 'plan': 'TIER_ONE'},
          {'code': 'CLI', 'plan': 'TIER_FOUR'},
          {'code': 'PD', 'plan': 'TIER_ONE'},
          {'code': 'PL', 'plan': 'TIER_ONE'},
        ],
      });

      expect(codes, ['PL', 'PD', 'WC']);
    },
  );

  test('competition mapping accepts free leagues and rejects MLS', () {
    expect(
      FootballDataPlayerRepository.competitionCode('Premier League'),
      'PL',
    );
    expect(FootballDataPlayerRepository.competitionCode('LaLiga'), 'PD');
    expect(
      FootballDataPlayerRepository.competitionCode('Major League Soccer'),
      isNull,
    );
  });

  test('player lookup accepts club aliases and reversed accented names', () {
    final player = FootballDataPlayerRepository.findInTeams(
      [
        {
          'id': 64,
          'name': 'Liverpool FC',
          'shortName': 'Liverpool',
          'tla': 'LIV',
          'squad': [
            {
              'id': 15378,
              'name': 'Dominik Szoboszlai',
              'position': 'Central Midfield',
              'dateOfBirth': '2000-10-25',
              'nationality': 'Hungary',
              'shirtNumber': 8,
            },
          ],
        },
      ],
      'Szoboszlai Dominik',
      'Liverpool',
    );

    expect(player, isNotNull);
    expect(player!.id, 15378);
    expect(player.teamId, 64);
    expect(player.position, 'Central Midfield');
    expect(player.shirtNumber, 8);
  });

  test(
    'repository resolves the team dynamically instead of a hardcoded id',
    () async {
      final directory = await Directory.systemTemp.createTemp('courtboard_fd_');
      addTearDown(() => directory.delete(recursive: true));
      final client = _FakeSportsApiClient();
      final repository = FootballDataPlayerRepository(
        client,
        cacheFile: File('${directory.path}/players.json'),
        rateLimitReset: Duration.zero,
      );

      final player = await repository.findPlayer(
        'Dominik Szoboszlai',
        'Liverpool',
      );

      expect(player?.name, 'Dominik Szoboszlai');
      expect(client.calls, ['/v4/teams', '/v4/teams/64']);
    },
  );
}

class _FakeSportsApiClient extends SportsApiClient {
  _FakeSportsApiClient()
    : super(config: const SportsApiConfig(footballDataKey: 'test'));

  final calls = <String>[];

  @override
  Future<Map<String, dynamic>> footballData(
    String path, [
    Map<String, String> query = const {},
  ]) async {
    calls.add(path);
    if (path == '/v4/teams') {
      return {
        'teams': [
          {'id': 64, 'name': 'Liverpool FC', 'shortName': 'Liverpool'},
        ],
      };
    }
    if (path == '/v4/teams/64') {
      return {
        'id': 64,
        'name': 'Liverpool FC',
        'shortName': 'Liverpool',
        'squad': [
          {'id': 15378, 'name': 'Dominik Szoboszlai'},
        ],
      };
    }
    throw StateError('Unexpected call: $path');
  }
}
