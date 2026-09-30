// Az ESPN-bajnoksági csapatforrás (a korábbi, Barcelonára égetett Liga F
// repository általánosítása) tesztjei.
import 'package:courtboard/data/espn_soccer_team.dart';
import 'package:courtboard/domain/athlete_source_hints.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _event({
  required String date,
  required String home,
  required String away,
  required String homeScore,
  required String awayScore,
  bool completed = true,
  String? id,
}) => {
  'id': ?id,
  'date': date,
  'competitions': [
    {
      'status': {
        'type': {'completed': completed},
      },
      'competitors': [
        {
          'homeAway': 'home',
          'score': homeScore,
          'team': {'displayName': home},
        },
        {
          'homeAway': 'away',
          'score': awayScore,
          'team': {'displayName': away},
        },
      ],
    },
  ],
};

void main() {
  final barcelona = EspnSoccerTeam.fromHints(
    AthleteSourceHints.ligaFBarcelona,
    'FC Barcelona',
  )!;

  test('Liga F parser returns only completed Barcelona matches', () {
    final games = EspnSoccerTeamRepository.parseGames({
      'events': [
        _event(
          date: '2026-04-22T17:00Z',
          home: 'Espanyol',
          away: 'Barcelona',
          homeScore: '1',
          awayScore: '4',
          id: '401',
        ),
        _event(
          date: '2026-04-29T17:00Z',
          home: 'Barcelona',
          away: 'Real Madrid',
          homeScore: '0',
          awayScore: '0',
          completed: false,
        ),
        _event(
          date: '2026-04-20T17:00Z',
          home: 'Levante',
          away: 'Sevilla',
          homeScore: '2',
          awayScore: '1',
        ),
      ],
    }, barcelona);

    expect(games.single.opponent, 'Espanyol');
    expect(games.single.score, '4–1');
    expect(games.single.result, 'GYŐZELEM');
    expect(games.single.home, isFalse);
    expect(games.single.eventId, '401');
  });

  test('Aitana keeps the pre-0.13 Barcelona labels', () {
    expect(barcelona.league, 'esp.w.1');
    expect(barcelona.team, 'Barcelona');
    expect(barcelona.displayName, 'FC Barcelona Femení');
    expect(barcelona.competitionLabel, 'Liga F');
    expect(
      barcelona.description,
      'Valós női Barcelona csapateredmények; nem a férfi FC Barcelona feedje.',
    );
  });

  test('any hinted club works: the team comes from the athlete', () {
    final madrid = EspnSoccerTeam.fromHints(
      AthleteSourceHints.ligaF,
      'Real Madrid Femenino',
    )!;
    expect(madrid.team, 'Real Madrid Femenino');
    expect(madrid.displayName, 'Real Madrid Femenino');
    expect(madrid.matches('Real Madrid'), isTrue);
    expect(madrid.matches('Barcelona'), isFalse);

    final games = EspnSoccerTeamRepository.parseGames({
      'events': [
        _event(
          date: '2026-04-22T17:00Z',
          home: 'Real Madrid',
          away: 'Barcelona',
          homeScore: '2',
          awayScore: '3',
        ),
      ],
    }, madrid);
    expect(games.single.opponent, 'Barcelona');
    expect(games.single.result, 'VERESÉG');
    expect(games.single.home, isTrue);
  });

  test('men\'s leagues work too (club name matching without FC)', () {
    const hints = AthleteSourceHints(espnLeague: 'eng.1', competition: 'PL');
    final arsenal = EspnSoccerTeam.fromHints(hints, 'Arsenal FC')!;
    expect(arsenal.womensTeam, isFalse);
    expect(arsenal.displayName, 'Arsenal FC');
    expect(arsenal.description, 'Valós Arsenal FC csapateredmények.');
    expect(arsenal.matches('Arsenal'), isTrue);
    expect(arsenal.matches('Chelsea'), isFalse);
  });

  test('no league hint or no team: no ESPN team', () {
    expect(
      EspnSoccerTeam.fromHints(AthleteSourceHints.none, 'FC Barcelona'),
      isNull,
    );
    expect(EspnSoccerTeam.fromHints(AthleteSourceHints.ligaF, '  '), isNull);
    // Az ESPN-csapatnév a tippből jön, ha a sportolónál nincs csapat.
    expect(
      EspnSoccerTeam.fromHints(AthleteSourceHints.ligaFBarcelona, '')?.team,
      'Barcelona',
    );
  });

  test('women\'s suffixes are ignored when matching', () {
    expect(EspnSoccerTeam.teamKey('FC Barcelona Femení'), 'fcbarcelona');
    expect(EspnSoccerTeam.teamKey('Chelsea Women'), 'chelsea');
    expect(barcelona.matches('FC Barcelona Femení'), isTrue);
  });
}
