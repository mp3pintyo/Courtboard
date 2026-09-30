import 'package:courtboard/data/football_data_players.dart';
import 'package:courtboard/data/json_file_cache.dart';
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
      final storage = MemoryCacheStorage();
      final client = _FakeSportsApiClient(storage);
      final repository = FootballDataPlayerRepository(
        client,
        cacheStorage: storage,
      );

      final player = await repository.findPlayer(
        'Dominik Szoboszlai',
        'Liverpool',
      );

      expect(player?.name, 'Dominik Szoboszlai');
      expect(client.calls, ['/v4/teams', '/v4/teams/64']);
    },
  );

  test('a player that is not found is negatively cached for a day', () async {
    var now = DateTime(2026, 9, 30, 12);
    final storage = MemoryCacheStorage(clock: () => now);
    final client = _FakeSportsApiClient(storage);
    final repository = FootballDataPlayerRepository(
      client,
      cacheStorage: storage,
      clock: () => now,
    );

    final first = await repository.findPlayerCached(
      'Nobody Here',
      'Unknown FC',
    );
    final calls = [...client.calls];
    final second = await repository.findPlayerCached(
      'Nobody Here',
      'Unknown FC',
    );

    expect(first.value, isNull);
    expect(calls, [
      '/v4/teams',
      '/v4/competitions',
      '/v4/competitions/PL/teams',
    ]);
    expect(second.value, isNull);
    expect(second.fromCache, isTrue);
    expect(client.calls, calls, reason: 'a negatív cache nem kérdez újra');

    now = now.add(const Duration(hours: 25));
    await repository.findPlayerCached('Nobody Here', 'Unknown FC');
    // A csapatlista és a keretek 7 napig gyorsítótárból jönnek, így a lejárt
    // negatív bejegyzés után sem indul újabb hálózati kérés.
    expect(client.calls, calls);
  });

  test('found players are cached with their freshness', () async {
    final storage = MemoryCacheStorage();
    final client = _FakeSportsApiClient(storage);
    final repository = FootballDataPlayerRepository(
      client,
      cacheStorage: storage,
    );

    await repository.findPlayer('Dominik Szoboszlai', 'Liverpool');
    final cached = await repository.findPlayerCached(
      'Szoboszlai Dominik',
      'Liverpool',
    );

    // Más névsorrend új kulcs, de a csapatlista és a keret már gyorsítótárból
    // jön, így nem indul újabb kérés.
    expect(cached.value?.id, 15378);
    expect(client.calls, ['/v4/teams', '/v4/teams/64']);
    final again = await repository.findPlayerCached(
      'Dominik Szoboszlai',
      'Liverpool',
    );
    expect(again.fromCache, isTrue);
    expect(again.value?.name, 'Dominik Szoboszlai');
    expect(client.calls, hasLength(2));
  });
}

class _FakeSportsApiClient extends SportsApiClient {
  _FakeSportsApiClient([CacheStorage? storage])
    : super(
        config: const SportsApiConfig(footballDataKey: 'test'),
        cacheStorage: storage,
      );

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
    if (path == '/v4/competitions') {
      return {
        'competitions': [
          {'code': 'PL', 'plan': 'TIER_ONE'},
        ],
      };
    }
    if (path == '/v4/competitions/PL/teams') {
      return {
        'teams': [
          {'id': 64, 'name': 'Liverpool FC', 'squad': <Object?>[]},
        ],
      };
    }
    throw StateError('Unexpected call: $path');
  }
}
