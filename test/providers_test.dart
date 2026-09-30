// Riverpod-providerek: az AppController a providerből (kulcsmentés → új
// API-konfiguráció), és néhány adatkártya felülírt repositoryval
// (`ProviderScope(overrides: …)`), hálózat nélkül.
import 'package:courtboard/app/app_services.dart';
import 'package:courtboard/app/providers.dart';
import 'package:courtboard/data/api_key_id.dart';
import 'package:courtboard/data/api_key_store.dart';
import 'package:courtboard/data/espn_athletes.dart';
import 'package:courtboard/data/espn_schedule.dart';
import 'package:courtboard/data/espn_soccer_team.dart';
import 'package:courtboard/data/local_state.dart';
import 'package:courtboard/data/providers.dart';
import 'package:courtboard/data/secret_store.dart';
import 'package:courtboard/data/sports_api.dart';
import 'package:courtboard/data/upcoming_events.dart';
import 'package:courtboard/domain/athlete.dart';
import 'package:courtboard/features/profile/match_details.dart';
import 'package:courtboard/features/profile/sports/profile_football.dart';
import 'package:courtboard/features/profile/sports/profile_nfl.dart';
import 'package:courtboard/shared/theme/courtboard_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_http.dart';

Widget _host(Widget child, {List<Override> overrides = const []}) =>
    ProviderScope(
      overrides: overrides,
      retry: noAutomaticRetry,
      child: MaterialApp(
        theme: buildCourtboardTheme(CourtboardAccent.green, Brightness.light),
        home: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(width: 900, child: child),
          ),
        ),
      ),
    );

class _FakeUpcoming extends UpcomingEventsRepository {
  final List<UpcomingEventsTarget> requested = [];

  @override
  Future<AthleteEventsResult> fetchFor(
    UpcomingEventsTarget target, {
    required SportsApiConfig config,
    bool forceRefresh = false,
  }) async {
    requested.add(target);
    return AthleteEventsResult(
      target: target,
      events: [
        UpcomingEvent(
          athleteName: target.name,
          sport: target.sport.jsonValue,
          title: 'Denver Nuggets – Phoenix Suns',
          opponent: 'Phoenix Suns',
          start: DateTime(2026, 10, 24, 3),
          source: 'ESPN',
        ),
      ],
    );
  }
}

class _FakeEspnAthletes extends EspnAthleteRepository {
  _FakeEspnAthletes(this.log);

  final EspnGameLog log;
  final List<bool> forced = [];

  @override
  Future<EspnGameLog?> gameLog(
    String name,
    EspnLeague league, {
    bool forceRefresh = false,
  }) async {
    forced.add(forceRefresh);
    return log;
  }
}

class _FakeSoccerTeams extends EspnSoccerTeamRepository {
  int calls = 0;
  bool fail = true;
  final List<EspnSoccerTeam> teams = [];

  @override
  Future<List<EspnSoccerGame>> recentGames(
    EspnSoccerTeam team, {
    DateTime? now,
    Duration window = const Duration(days: 60),
  }) async {
    calls++;
    teams.add(team);
    if (fail) throw StateError('ESPN nem érhető el');
    return [
      EspnSoccerGame(
        date: DateTime(2026, 4, 22),
        opponent: 'Espanyol',
        teamScore: 4,
        opponentScore: 1,
        home: false,
      ),
    ];
  }
}

const _jokic = Athlete(
  name: 'Nikola Jokić',
  sport: Sport.nba,
  team: 'Denver Nuggets',
  country: '',
  photoUrl: '',
  accent: Colors.orange,
);

void main() {
  group('AppController a providerből', () {
    test('az indítási állapot, az azonosítók és a kulcsmentés', () async {
      final container = ProviderContainer(
        overrides: courtboardOverrides(
          services: AppServices(
            apiKeyStore: ApiKeyStore(secrets: MemorySecretStore()),
          ),
          launch: const AppLaunchState(
            initialState: CourtboardLocalState(
              customAthletes: [
                CustomAthlete(name: 'LeBron James', sport: 'NBA', team: 'LAL'),
              ],
            ),
          ),
        ),
      );
      addTearDown(container.dispose);

      final app = container.read(appControllerProvider);
      expect(app.athleteById('lebron-james')?.name, 'LeBron James');
      expect(app.athleteById('nikola-jokic')?.name, 'Nikola Jokić');
      // Ugyanaz a példány, amíg a konténer él.
      expect(identical(container.read(appControllerProvider), app), isTrue);

      // A kulcsos repositoryk a controller konfigurációját kapják.
      final configs = <SportsApiConfig>[];
      container.listen(
        apiConfigProvider,
        (_, next) => configs.add(next),
        fireImmediately: true,
      );
      expect(configs.single.footballDataKey, isNot('kulcs-123'));
      await app.saveApiKey(ApiKeyId.footballData, 'kulcs-123');
      // A provider-frissítések a következő eseményciklusban futnak le.
      await Future<void>.delayed(Duration.zero);
      expect(configs.last.footballDataKey, 'kulcs-123');
      expect(
        container.read(footballSeasonRepositoryProvider).config.footballDataKey,
        'kulcs-123',
      );

      // A vezérlők ugyanarra a controllerre épülnek.
      expect(
        identical(container.read(activityControllerProvider).app, app),
        isTrue,
      );
      expect(
        identical(container.read(desktopCoordinatorProvider).app, app),
        isTrue,
      );
    });

    test('a figyelők értesülnek a változásról', () {
      final container = ProviderContainer(
        overrides: courtboardOverrides(
          services: AppServices(
            apiKeyStore: ApiKeyStore(secrets: MemorySecretStore()),
          ),
        ),
      );
      addTearDown(container.dispose);
      var notified = 0;
      container.listen(
        appControllerProvider.select((app) => app.isPinned(_jokic)),
        (_, _) => notified++,
      );
      container.read(appControllerProvider).togglePin(_jokic);
      expect(notified, 1);
      expect(container.read(appControllerProvider).pinned, ['Nikola Jokić']);
    });
  });

  testWidgets('Következő mérkőzés: a repository providerből', (tester) async {
    final upcoming = _FakeUpcoming();
    await tester.pumpWidget(
      _host(
        const NextMatchCard(athlete: _jokic),
        overrides: [
          upcomingEventsRepositoryProvider.overrideWithValue(upcoming),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profile-next-match')), findsOneWidget);
    expect(find.textContaining('Phoenix Suns'), findsWidgets);
    expect(upcoming.requested.single.name, 'Nikola Jokić');
    expect(upcoming.requested.single.team, 'Denver Nuggets');
  });

  testWidgets('NFL-meccsnapló: felülírt repository, kényszerített frissítés', (
    tester,
  ) async {
    const ref = EspnAthleteRef(
      id: '4040715',
      displayName: 'Jalen Hurts',
      league: EspnLeague.nfl,
      team: 'Philadelphia Eagles',
      position: 'QB',
    );
    final espn = _FakeEspnAthletes(
      EspnAthleteRepository.parseGameLog(
        fixture('espn_nfl_gamelog_hurts.json'),
        ref,
      ),
    );
    await tester.pumpWidget(
      _host(
        const NflPlayerCard(athleteName: 'Jalen Hurts', accent: Colors.green),
        overrides: [espnAthleteRepositoryProvider.overrideWithValue(espn)],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('nfl-player-log')), findsOneWidget);
    expect(espn.forced, [false]);

    await tester.tap(find.byTooltip('Meccsnapló frissítése (Ctrl+R)'));
    await tester.pumpAndSettle();
    expect(espn.forced, [false, true]);
    expect(find.byKey(const Key('nfl-player-log')), findsOneWidget);
  });

  testWidgets('ESPN-csapatkártya: Aitana felirata, hiba és újrapróbálás', (
    tester,
  ) async {
    final teams = _FakeSoccerTeams();
    final team = EspnSoccerTeam.fromHints(
      AthleteSourceHints.ligaFBarcelona,
      'FC Barcelona',
    )!;
    await tester.pumpWidget(
      _host(
        EspnSoccerTeamCard(
          athleteName: 'Aitana Bonmatí',
          team: team,
          accent: Colors.indigo,
        ),
        overrides: [espnSoccerTeamRepositoryProvider.overrideWithValue(teams)],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('FC Barcelona Femení · Liga F'), findsOneWidget);
    expect(find.text('ESPN · ESP.W.1'), findsOneWidget);
    expect(
      find.text(
        'Valós női Barcelona csapateredmények; nem a férfi FC Barcelona feedje.',
      ),
      findsOneWidget,
    );
    expect(find.text('Újrapróbálás'), findsOneWidget);
    expect(teams.teams.single.team, 'Barcelona');

    teams.fail = false;
    await tester.tap(find.text('Újrapróbálás'));
    await tester.pumpAndSettle();
    expect(teams.calls, 2);
    expect(find.text('Espanyol'), findsOneWidget);
    expect(find.text('4–1'), findsOneWidget);
    expect(find.text('Liga F'), findsOneWidget);
  });
}
