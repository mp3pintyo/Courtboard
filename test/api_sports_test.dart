import 'package:flutter_test/flutter_test.dart';
import 'package:courtboard/data/api_sports.dart';

void main() {
  test('status parser reports the remaining daily quota', () {
    expect(
        ApiSportsQuota.fromStatus({
          'response': {
            'requests': {'current': 12, 'limit_day': 100}
          }
        }).remaining,
        88);
  });
  test('football fixture parser returns a team-view result and date', () {
    final games = ApiSportsRepository.parseFootballFixtures({
      'response': [
        {
          'fixture': {'date': '2026-05-25T14:00:00Z'},
          'teams': {
            'home': {'name': 'Liverpool', 'id': 40, 'winner': true},
            'away': {'name': 'Arsenal', 'id': 42, 'winner': false}
          },
          'goals': {'home': 2, 'away': 1}
        }
      ]
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
            'standard': {'jersey': 15, 'active': true, 'pos': 'C'}
          }
        }
      ]
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
        teamId: 529, now: DateTime(2026, 8, 1), freePlan: true);

    expect(query, {'team': '529', 'season': '2024'});
    expect(query, isNot(contains('last')));
  });

  test('football team search removes common club prefixes', () {
    expect(footballTeamSearchTerm('FC Barcelona'), 'Barcelona');
    expect(normalizeFootballTeamName('Liverpool FC'), 'liverpool');
  });
}
