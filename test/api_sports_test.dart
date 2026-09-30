import 'package:flutter_test/flutter_test.dart';
import 'package:courtboard/data/api_sports.dart';
import 'package:courtboard/data/football_names.dart';
import 'package:courtboard/data/json_file_cache.dart';

void main() {
  test('status parser reports the remaining daily quota', () {
    expect(
      ApiSportsQuota.fromStatus({
        'response': {
          'requests': {'current': 12, 'limit_day': 100},
        },
      }).remaining,
      88,
    );
  });
  test('football fixture parser returns a team-view result and date', () {
    final games = ApiSportsRepository.parseFootballFixtures({
      'response': [
        {
          'fixture': {'date': '2026-05-25T14:00:00Z'},
          'teams': {
            'home': {'name': 'Liverpool', 'id': 40, 'winner': true},
            'away': {'name': 'Arsenal', 'id': 42, 'winner': false},
          },
          'goals': {'home': 2, 'away': 1},
        },
      ],
    }, 40);
    expect(games.single.opponent, 'Arsenal');
    expect(games.single.score, '2–1');
    expect(games.single.result, 'GY');
  });

  test('NBA parser matches an API-Sports ASCII name to an accented name', () {
    final player = ApiSportsRepository.parseNbaPlayer({
      'response': [
        {
          'id': 279,
          'firstname': 'Nikola',
          'lastname': 'Jokic',
          'birth': {'date': '1995-02-19', 'country': 'Serbia'},
          'height': {'meters': '2.11'},
          'weight': {'kilograms': '128.8'},
          'college': null,
          'leagues': {
            'standard': {'jersey': 15, 'active': true, 'pos': 'C'},
          },
        },
      ],
    }, 'Nikola Jokić');

    expect(player, isNotNull);
    expect(player!.name, 'Nikola Jokic');
    expect(player.position, 'C');
    expect(player.height, '2.11 m');
    expect(player.jersey, '15');
  });

  test('athlete name normalization removes accents and punctuation', () {
    expect(normalizeAthleteName(' Nikola Jokić '), 'nikola jokic');
    expect(normalizeAthleteName("De'Aaron Fox"), 'deaaron fox');
  });

  test('free football query uses an accessible season without last', () {
    final query = ApiSportsRepository.footballFixtureQuery(
      teamId: 529,
      now: DateTime(2026, 8, 1),
      freePlan: true,
    );

    expect(query, {'team': '529', 'season': '2024'});
    expect(query, isNot(contains('last')));
  });

  test('football team search removes common club prefixes', () {
    expect(footballTeamSearchTerm('FC Barcelona'), 'Barcelona');
    expect(normalizeFootballTeamName('Liverpool FC'), 'liverpool');
  });

  test('football player parser reads every requested season field', () {
    final stats = ApiSportsRepository.parseFootballPlayerStats({
      'response': [
        {
          'player': {'id': 1, 'name': 'Dominik Szoboszlai'},
          'statistics': [
            {
              'team': {'name': 'Liverpool'},
              'league': {'name': 'Premier League', 'season': 2025},
              'games': {'appearences': 36, 'rating': '7.50'},
              'goals': {'total': 6, 'assists': 7},
              'cards': {'yellow': 8, 'red': 1},
            },
          ],
        },
      ],
    }, 'Szoboszlai Dominik');

    expect(stats.single.team, 'Liverpool');
    expect(stats.single.competition, 'Premier League');
    expect(stats.single.rating, 7.5);
    expect(stats.single.appearances, 36);
    expect(stats.single.goals, 6);
    expect(stats.single.assists, 7);
    expect(stats.single.yellowCards, 8);
    expect(stats.single.redCards, 1);
  });

  test('athlete name matching accepts real variants only', () {
    expect(athleteNameMatches('Nikola Jokić', 'Nikola Jokic'), isTrue);
    expect(athleteNameMatches('Juhász Dorka', 'Dorka Juhasz'), isTrue);
    expect(
      athleteNameMatches(
        'Vinicius Junior',
        'Vinicius Jose Paixao de Oliveira Junior',
      ),
      isTrue,
    );
    expect(
      athleteNameMatches('Aitana Bonmatí Conca', 'Aitana Bonmati'),
      isTrue,
    );
    expect(athleteNameMatches('N. Jokic', 'Nikola Jokic'), isTrue);
    expect(athleteNameMatches('Iga Świątek', 'Swiatek Iga'), isTrue);
    expect(athleteNameMatches('Nikola Jokic', 'Nikola Jovic'), isFalse);
    expect(athleteNameMatches('Caitlin Clark', 'Caitlin Brown'), isFalse);
    expect(athleteNameMatches('', 'Anyone'), isFalse);
  });

  test('NBA parser returns null instead of the first unrelated hit', () {
    final player = ApiSportsRepository.parseNbaPlayer({
      'response': [
        {'id': 1, 'firstname': 'Nikola', 'lastname': 'Jovic'},
        {'id': 2, 'firstname': 'Nikola', 'lastname': 'Vucevic'},
      ],
    }, 'Nikola Jokić');
    expect(player, isNull);
  });

  test('football player parser ignores unrelated search results', () {
    final stats = ApiSportsRepository.parseFootballPlayerStats({
      'response': [
        {
          'player': {'id': 9, 'name': 'Dominik Livakovic'},
          'statistics': [
            {
              'team': {'name': 'Fenerbahce'},
              'league': {'name': 'Super Lig', 'season': 2025},
              'games': {'appearences': 30},
            },
          ],
        },
      ],
    }, 'Szoboszlai Dominik');
    expect(stats, isEmpty);
  });

  test('team matching tolerates club affixes and accents', () {
    expect(footballTeamNamesMatch('FC Barcelona', 'Barcelona'), isTrue);
    expect(
      footballTeamNamesMatch('Bayern Munchen', 'FC Bayern München'),
      isTrue,
    );
    expect(footballTeamNamesMatch('Liverpool', 'Everton'), isFalse);
    expect(
      findFootballTeamByName(
        ['Espanyol', 'FC Barcelona'],
        'Barcelona',
        (name) => name,
      ),
      'FC Barcelona',
    );
    expect(
      findFootballTeamByName(['Everton'], 'Liverpool', (name) => name),
      isNull,
    );
  });

  test(
    'API-Sports responses are disk-cached and share one status call',
    () async {
      final repository = _CountingApiSports();

      final first = await repository.nbaPlayer('Nikola Jokić');
      final second = await repository.nbaPlayer('Nikola Jokic');
      final plans = await Future.wait([
        repository.status('v3.football.api-sports.io'),
        repository.status('v3.football.api-sports.io'),
      ]);

      expect(first?.name, 'Nikola Jokic');
      expect(second?.name, 'Nikola Jokic');
      expect(plans.first.remaining, 88);
      expect(repository.calls, ['/players', '/status']);
    },
  );
}

class _CountingApiSports extends ApiSportsRepository {
  _CountingApiSports() : super('key', cacheStorage: MemoryCacheStorage());

  final calls = <String>[];

  @override
  Future<Map<String, dynamic>> get(
    String host,
    String path, [
    Map<String, String> query = const {},
  ]) async {
    calls.add(path);
    if (path == '/status') {
      return {
        'response': {
          'requests': {'current': 12, 'limit_day': 100},
        },
      };
    }
    return {
      'response': [
        {'id': 279, 'firstname': 'Nikola', 'lastname': 'Jokic'},
      ],
    };
  }
}
