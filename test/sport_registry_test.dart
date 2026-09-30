// A Sport enum (JSON, régi szöveges értékek), az adatforrás-tippek, a Liga F
// migráció és a SportProfileSpec regiszter tesztjei.
import 'dart:convert';

import 'package:courtboard/app/app_controller.dart';
import 'package:courtboard/app/seed_data.dart';
import 'package:courtboard/data/api_key_store.dart';
import 'package:courtboard/data/file_util.dart';
import 'package:courtboard/data/live_scores.dart';
import 'package:courtboard/data/local_state.dart';
import 'package:courtboard/data/secret_store.dart';
import 'package:courtboard/data/sports_api.dart';
import 'package:courtboard/data/upcoming_events.dart';
import 'package:courtboard/domain/athlete.dart';
import 'package:courtboard/domain/athlete_targets.dart';
import 'package:courtboard/features/profile/sport_profile_spec.dart';
import 'package:courtboard/features/profile/sports/profile_football.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Athlete _athlete(
  String name,
  Sport sport, {
  String team = 'Teszt FC',
  AthleteSourceHints hints = AthleteSourceHints.none,
}) => Athlete(
  name: name,
  sport: sport,
  team: team,
  country: '',
  photoUrl: '',
  accent: Colors.blue,
  sourceHints: hints,
);

void main() {
  group('Sport', () {
    test('JSON values are the pre-0.13 Hungarian strings', () {
      expect(
        {for (final s in Sport.values) s: s.jsonValue},
        {
          Sport.nba: 'NBA',
          Sport.wnba: 'WNBA',
          Sport.football: 'Foci',
          Sport.darts: 'Darts',
          Sport.tennis: 'Tenisz',
          Sport.nfl: 'NFL',
        },
      );
    });

    test('round-trips through JSON', () {
      for (final sport in Sport.values) {
        final encoded = jsonEncode({'sport': sport});
        final decoded = jsonDecode(encoded) as Map<String, dynamic>;
        expect(Sport.fromJson(decoded['sport']), sport);
        expect(Sport.fromLabel(sport.toJson()), sport);
      }
    });

    test('accepts legacy and alternative spellings', () {
      expect(Sport.fromLabel('Foci'), Sport.football);
      expect(Sport.fromLabel(' foci '), Sport.football);
      expect(Sport.fromLabel('football'), Sport.football);
      expect(Sport.fromLabel('soccer'), Sport.football);
      expect(Sport.fromLabel('TENISZ'), Sport.tennis);
      expect(Sport.fromLabel('tennis'), Sport.tennis);
      expect(Sport.fromLabel('nba'), Sport.nba);
      expect(Sport.fromLabel('Darts'), Sport.darts);
      expect(Sport.fromLabel('wnba'), Sport.wnba);
      expect(Sport.fromLabel('NFL'), Sport.nfl);
    });

    test('unknown values', () {
      expect(Sport.fromLabel(null), isNull);
      expect(Sport.fromLabel(''), isNull);
      expect(Sport.fromLabel('Curling'), isNull);
      expect(() => Sport.fromJson('Curling'), throwsFormatException);
      expect(() => Sport.fromJson(42), throwsFormatException);
    });

    test('metadata: team sports, labels and UI order', () {
      expect(Sport.values.where((s) => !s.hasTeam), [
        Sport.darts,
        Sport.tennis,
      ]);
      expect(Sport.values.map((s) => s.shortLabel), [
        'NBA',
        'WNBA',
        'Foci',
        'Darts',
        'Tenisz',
        'NFL',
      ]);
      for (final sport in Sport.values) {
        expect(sport.label, isNotEmpty);
        expect(sport.icon, isA<IconData>());
      }
      expect(Sport.nba.isBasketball && Sport.wnba.isBasketball, isTrue);
      expect(Sport.nfl.isBasketball, isFalse);
    });

    test('custom athletes keep the legacy sport string on disk', () {
      final json = const CustomAthlete(
        name: 'Iga Świątek',
        sport: 'Tenisz',
        team: '',
      ).toJson();
      expect(json['sport'], 'Tenisz');
      final athlete = AppController.customToAthlete(
        CustomAthlete.fromJson(json),
      )!;
      expect(athlete.sport, Sport.tennis);
      expect(AppController.athleteToCustom(athlete).sport, 'Tenisz');
    });
  });

  group('source hints and the Liga F migration', () {
    test('hints round-trip through JSON', () {
      expect(
        AthleteSourceHints.fromJson(AthleteSourceHints.ligaF.toJson()),
        AthleteSourceHints.ligaF,
      );
      expect(AthleteSourceHints.none.toJson(), isEmpty);
      expect(AthleteSourceHints.fromJson(const {}), AthleteSourceHints.none);
      expect(AthleteSourceHints.fromJson('hibás'), AthleteSourceHints.none);
      expect(AthleteSourceHints.ligaF.isLigaF, isTrue);
      expect(AthleteSourceHints.ligaF.womensTeam, isTrue);
    });

    test('legacy saved Aitana entry is migrated to Liga F', () {
      // 0.12.0-s mentés: nincs `sourceHints` mező.
      final legacy = CustomAthlete.fromJson(const {
        'name': 'Aitana Bonmatí',
        'sport': 'Foci',
        'team': 'FC Barcelona',
      });
      // Aitana régi mentése a korábbi (barcelonai) adatokat kapja.
      expect(legacy.sourceHints, AthleteSourceHints.ligaFBarcelona);

      final femeni = CustomAthlete.fromJson(const {
        'name': 'Alexia Putellas',
        'sport': 'Foci',
        'team': 'FC Barcelona Femení',
      });
      expect(femeni.sourceHints.isLigaF, isTrue);

      final other = CustomAthlete.fromJson(const {
        'name': 'Lamine Yamal',
        'sport': 'Foci',
        'team': 'FC Barcelona',
      });
      expect(other.sourceHints, AthleteSourceHints.none);

      // Nem foci: a régi szabály sem adott Liga F-et.
      final notFootball = CustomAthlete.fromJson(const {
        'name': 'Aitana Bonmatí',
        'sport': 'Tenisz',
        'team': '',
      });
      expect(notFootball.sourceHints, AthleteSourceHints.none);
    });

    test('migration runs once: saved hints are data afterwards', () {
      final state = CourtboardLocalState.fromJson(const {
        'customAthletes': [
          {'name': 'Aitana Bonmatí', 'sport': 'Foci', 'team': 'FC Barcelona'},
        ],
      });
      final saved = jsonDecode(jsonEncode(state.toJson()));
      final entry = ((saved as Map)['customAthletes'] as List).single as Map;
      expect(entry['sourceHints'], {
        'womensTeam': true,
        'espnLeague': 'esp.w.1',
        'competition': 'Liga F',
        'espnTeam': 'Barcelona',
        'teamLabel': 'FC Barcelona Femení',
      });
      // Az azonosító is adatként rögzül (útvonalakhoz).
      expect(entry['id'], 'aitana-bonmati');

      // Egy már 0.13-as, kifejezetten tipp nélküli bejegyzésre a név
      // alapján sem fut le újra a régi szabály.
      final explicit = CustomAthlete.fromJson(const {
        'name': 'Aitana Bonmatí',
        'sport': 'Foci',
        'team': 'FC Barcelona',
        'sourceHints': <String, dynamic>{},
      });
      expect(explicit.sourceHints, AthleteSourceHints.none);
    });

    test('migrated custom Aitana reaches the controller and targets', () {
      final app = AppController(
        initialState: CourtboardLocalState.fromJson(const {
          'removedAthleteNames': ['Aitana Bonmatí'],
          'customAthletes': [
            {'name': 'Aitana Bonmatí', 'sport': 'Foci', 'team': 'FC Barcelona'},
          ],
        }),
        apiKeyStore: ApiKeyStore(secrets: MemorySecretStore()),
        baseConfig: const SportsApiConfig(),
      );
      final aitana = app.athleteNamed('Aitana Bonmatí')!;
      expect(aitana.isCustom, isTrue);
      expect(aitana.sourceHints, AthleteSourceHints.ligaFBarcelona);
      expect(aitana.eventsTarget.isLigaF, isTrue);
      expect(
        app.currentState.customAthletes.single.sourceHints,
        AthleteSourceHints.ligaFBarcelona,
      );
      app.dispose();
    });

    test('seed data carries the Liga F hint for Aitana only', () {
      final withHints = seedAthletes.where((a) => !a.sourceHints.isEmpty);
      expect(withHints.map((a) => a.name), ['Aitana Bonmatí']);
      expect(withHints.single.sourceHints, AthleteSourceHints.ligaFBarcelona);
      expect(withHints.single.sourceHints.isLigaF, isTrue);
    });

    test('Liga F is decided by the hints, not by the name', () {
      final hinted = _athlete(
        'Bárki',
        Sport.football,
        team: 'FC Barcelona',
        hints: AthleteSourceHints.ligaF,
      ).eventsTarget;
      expect(hinted.isLigaF, isTrue);
      expect(LiveFeed.forTarget(hinted), LiveFeed.ligaF);
      expect(UpcomingSource.forTarget(hinted), UpcomingSource.espnSoccerLeague);

      final byName = _athlete(
        'Aitana Bonmatí',
        Sport.football,
        team: 'FC Barcelona',
      ).eventsTarget;
      expect(byName.isLigaF, isFalse);
      expect(LiveFeed.forTarget(byName), LiveFeed.soccer);
      expect(UpcomingSource.forTarget(byName), UpcomingSource.footballClub);
    });

    test('new athletes infer Liga F only from a women\'s club name', () {
      expect(
        AthleteSourceHints.inferFromTeam(Sport.football, 'Barcelona Femení'),
        AthleteSourceHints.ligaF,
      );
      expect(
        AthleteSourceHints.inferFromTeam(Sport.football, 'FC Barcelona'),
        AthleteSourceHints.none,
      );
      expect(
        AthleteSourceHints.inferFromTeam(Sport.nba, 'Femení'),
        AthleteSourceHints.none,
      );
    });

    test('target cache keys stay compatible with 0.12 caches', () {
      const target = UpcomingEventsTarget(
        name: 'Nikola Jokić',
        sport: Sport.nba,
        team: 'Denver Nuggets',
      );
      // A 0.12-es kulcs: cacheSlug('\$sport \$team \$name') a szöveges sportággal.
      expect(target.cacheKey, cacheSlug('NBA Denver Nuggets Nikola Jokić'));
      expect(
        target.cacheKey,
        const UpcomingEventsTarget(
          name: 'Nikola Jokić',
          sport: Sport.nba,
          team: 'Denver Nuggets',
          sourceHints: AthleteSourceHints.ligaF,
        ).cacheKey,
      );
    });
  });

  group('SportProfileSpec registry', () {
    test('covers every sport', () {
      expect(SportProfileSpec.registry.keys.toSet(), Sport.values.toSet());
      for (final sport in Sport.values) {
        expect(SportProfileSpec.of(sport).sport, sport);
        expect(SportProfileSpec.of(sport).template.indicators, hasLength(3));
      }
    });

    test('only darts falls back to the generic season summary', () {
      expect(
        Sport.values.where((s) => SportProfileSpec.of(s).showsGenericSummary),
        [Sport.darts],
      );
    });

    test('compare support and head-to-head kind follow the sport', () {
      expect(
        Sport.values.where((s) => SportProfileSpec.of(s).supportsCompare),
        [Sport.nba, Sport.wnba, Sport.football, Sport.tennis, Sport.nfl],
      );
      expect(
        Sport.values.where(
          (s) => SportProfileSpec.of(s).headToHead == HeadToHeadKind.team,
        ),
        [Sport.nba, Sport.wnba, Sport.football, Sport.nfl],
      );
    });

    test('live cards: Liga F replaces the club cards for hinted players', () {
      final spec = SportProfileSpec.of(Sport.football);
      final club = spec.liveCards(_athlete('Játékos', Sport.football));
      expect(club.map((w) => w.runtimeType), [
        FootballDataCard,
        FootballDataPlayerCard,
        FootballSeasonSummaryCard,
      ]);
      final ligaF = spec.liveCards(
        _athlete('Játékos', Sport.football, hints: AthleteSourceHints.ligaF),
      );
      expect(ligaF.map((w) => w.runtimeType), [
        EspnSoccerTeamCard,
        FootballSeasonSummaryCard,
      ]);
    });

    test('every sport has at least one live card', () {
      for (final sport in Sport.values) {
        final cards = SportProfileSpec.of(
          sport,
        ).liveCards(_athlete('Teszt', sport));
        expect(cards, isNotEmpty, reason: sport.name);
      }
    });

    test('upcoming source and live feed per sport', () {
      final spec = SportProfileSpec.of(Sport.nba);
      final jokic = _athlete('Nikola Jokić', Sport.nba, team: 'Nuggets');
      expect(spec.upcomingSourceFor(jokic), UpcomingSource.espnTeamSchedule);
      expect(spec.liveFeedFor(jokic), LiveFeed.nba);
      final darts = _athlete('Luke Humphries', Sport.darts);
      expect(
        SportProfileSpec.of(Sport.darts).upcomingSourceFor(darts),
        UpcomingSource.darts,
      );
      expect(SportProfileSpec.of(Sport.darts).liveFeedFor(darts), isNull);
    });
  });
}
