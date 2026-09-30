// A játékos saját pontszerzése a profil lejátszott meccseinek soraiban
// (0.16.0): a közös MatchRow-jelölés, valamint a foci-, NBA-, WNBA- és
// NFL-kártyák sorai valós (megvágott) fixture-ökből, hálózat nélkül.
import 'dart:convert';
import 'dart:io';

import 'package:courtboard/app/providers.dart';
import 'package:courtboard/data/basketball_reference.dart';
import 'package:courtboard/data/espn_athletes.dart';
import 'package:courtboard/data/espn_schedule.dart';
import 'package:courtboard/data/espn_soccer_team.dart';
import 'package:courtboard/data/football_data.dart';
import 'package:courtboard/data/football_season.dart';
import 'package:courtboard/data/football_season_repository.dart';
import 'package:courtboard/data/fotmob_football.dart';
import 'package:courtboard/data/json_file_cache.dart';
import 'package:courtboard/data/match_timeline.dart';
import 'package:courtboard/data/openligadb.dart';
import 'package:courtboard/data/providers.dart';
import 'package:courtboard/data/sports_api.dart';
import 'package:courtboard/data/wehoop_wnba.dart';
import 'package:courtboard/domain/athlete_source_hints.dart';
import 'package:courtboard/domain/player_contribution.dart';
import 'package:courtboard/domain/sport.dart';
import 'package:courtboard/features/profile/sports/profile_football.dart';
import 'package:courtboard/features/profile/sports/profile_nba_facts.dart';
import 'package:courtboard/features/profile/sports/profile_nfl.dart';
import 'package:courtboard/features/profile/sports/profile_wnba.dart';
import 'package:courtboard/shared/components.dart';
import 'package:courtboard/shared/theme/courtboard_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_http.dart';

Widget _host(
  Widget child, {
  List<Override> overrides = const [],
  Brightness brightness = Brightness.light,
}) => ProviderScope(
  overrides: overrides,
  retry: noAutomaticRetry,
  child: MaterialApp(
    theme: buildCourtboardTheme(CourtboardAccent.green, brightness),
    home: Scaffold(
      body: SingleChildScrollView(child: SizedBox(width: 900, child: child)),
    ),
  ),
);

final _contribution = find.byKey(const Key('player-contribution'));

/// Szezonösszesítő a FotMob meccslistájával (a hálózat helyett).
class _FakeSeason extends FootballSeasonRepository {
  _FakeSeason(this.matches) : super(const SportsApiConfig());

  final List<FootballMatchForm> matches;
  int calls = 0;

  @override
  Future<FootballSeasonResult> fetchWithStatus(
    String athleteName,
    String teamName,
  ) async {
    calls++;
    if (matches.isEmpty) return const FootballSeasonResult();
    return FootballSeasonResult(
      stats: [
        FootballSeasonStat(
          season: '2026/2027',
          team: 'Barcelona',
          competition: 'Liga F',
          source: 'FotMob',
          appearances: 1,
          recentMatches: matches,
        ),
      ],
      fetchedAt: DateTime(2026, 9, 30),
    );
  }
}

class _FakeTeamGames extends FootballDataRepository {
  _FakeTeamGames(this.games) : super(SportsApiClient());

  final FootballTeamGames games;

  @override
  Future<FootballTeamGames> fetchTeamGames(
    String teamName, {
    String? competition,
  }) async => games;
}

EspnGameLog _nflLog(String file, String name, String position) =>
    EspnAthleteRepository.parseGameLog(
      fixture(file),
      EspnAthleteRef(
        id: '1',
        displayName: name,
        league: EspnLeague.nfl,
        team: 'Team',
        position: position,
      ),
    );

void main() {
  group('MatchRow pontszerzés-jelölés', () {
    testWidgets('> 0: kiemelt címke ikonnal és képernyőolvasós mondattal', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(
          const MatchRow(
            opponent: 'Chicago Sky',
            score: '84–78',
            outcome: MatchOutcome.win,
            contribution: PlayerContribution.basketball(
              points: 24,
              athlete: 'Juhász Dorka',
            ),
          ),
        ),
      );
      expect(find.text('24 pont'), findsOneWidget);
      expect(find.byIcon(Icons.sports_basketball), findsOneWidget);
      expect(
        find.bySemanticsLabel('Juhász Dorka 24 pontot szerzett'),
        findsOneWidget,
      );
      semantics.dispose();
    });

    testWidgets('0 vagy ismeretlen: semmi (soha nem „0”)', (tester) async {
      await tester.pumpWidget(
        _host(
          const Column(
            children: [
              MatchRow(
                opponent: 'Espanyol',
                contribution: PlayerContribution.football(),
              ),
              MatchRow(opponent: 'Levante'),
              MatchRow(
                opponent: 'Utah Jazz',
                contribution: PlayerContribution.basketball(points: 0),
              ),
            ],
          ),
        ),
      );
      expect(_contribution, findsNothing);
      expect(find.textContaining('0 gól'), findsNothing);
      expect(find.textContaining('0 pont'), findsNothing);
    });

    testWidgets('foci: gól és gólpassz egy címkében, sötét módban is', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const MatchRow(
            opponent: 'Real Madrid',
            contribution: PlayerContribution.football(goals: 1, assists: 1),
          ),
          brightness: Brightness.dark,
        ),
      );
      expect(find.text('1 gól · 1 gólpassz'), findsOneWidget);
      expect(find.byIcon(Icons.sports_soccer), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('csak passzolt TD: halvány megjegyzés, címke nélkül', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const MatchRow(
            opponent: 'Buffalo Bills',
            contribution: PlayerContribution.nfl(passingTouchdowns: 2),
          ),
        ),
      );
      expect(find.text('2 passzolt TD'), findsOneWidget);
      expect(find.byIcon(Icons.sports_football), findsNothing);
    });
  });

  group('kosárlabda', () {
    testWidgets('NBA: „31 pont” kiemelve, a statisztikasorban nincs PTS', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          BasketballReferenceGameList(
            games: [
              NbaGameLog(
                date: DateTime(2026, 4, 12),
                opponent: 'San Antonio Spurs',
                outcome: 'WIN',
                location: 'AWAY',
                minutes: 34.3,
                points: 31,
                rebounds: 14,
                assists: 12,
                steals: 2,
                blocks: 1,
                score: '118-104',
              ),
              NbaGameLog(
                date: DateTime(2026, 4, 10),
                opponent: 'Phoenix Suns',
                outcome: 'LOSS',
                location: 'HOME',
                minutes: 3,
                points: 0,
                rebounds: 1,
                assists: 0,
                steals: 0,
                blocks: 0,
                score: '109-112',
              ),
            ],
            accent: Colors.amber,
            league: Sport.nba,
            athleteName: 'Nikola Jokić',
          ),
        ),
      );
      expect(find.text('31 pont'), findsOneWidget);
      expect(find.text('14 REB · 12 AST · 34 MIN'), findsOneWidget);
      expect(find.textContaining('31 PTS'), findsNothing);
      // Pont nélküli meccs: nincs kiemelés, a sor a valós 0-t mutatja.
      expect(find.text('0 PTS · 1 REB · 0 AST · 3 MIN'), findsOneWidget);
      expect(_contribution, findsOneWidget);
    });

    testWidgets('WNBA: ugyanaz a jelölés és sorforma', (tester) async {
      WnbaGameLog game(int points, String opponent) => WnbaGameLog(
        gameId: opponent,
        athleteId: '1',
        date: DateTime(2026, 7, 30),
        team: 'Indiana Fever',
        opponent: opponent,
        teamScore: 88,
        opponentScore: 80,
        result: WnbaResult.win,
        points: points,
        rebounds: 6,
        assists: 9,
        steals: 1,
        blocks: 0,
        minutes: 33,
        headshotUrl: '',
      );
      await tester.pumpWidget(
        _host(
          WnbaRecentGameList(
            games: [game(24, 'Chicago Sky'), game(0, 'Dallas Wings')],
            athleteName: 'Caitlin Clark',
          ),
        ),
      );
      expect(find.text('24 pont'), findsOneWidget);
      expect(find.text('6 REB · 9 AST · 33 MIN'), findsOneWidget);
      expect(find.text('0 PTS · 6 REB · 9 AST · 33 MIN'), findsOneWidget);
    });
  });

  group('NFL-meccsnapló', () {
    testWidgets('QB: saját TD és pont, a passzolt TD külön, halványan', (
      tester,
    ) async {
      final log = _nflLog('espn_nfl_gamelog_allen.json', 'Josh Allen', 'QB');
      await tester.pumpWidget(
        _host(NflGameLogView(log: log, accent: const Color(0xFF00338D))),
      );
      expect(find.text('2 TD · 12 pont'), findsNWidgets(3));
      expect(find.text('3 passzolt TD'), findsOneWidget);
      expect(find.text('2 passzolt TD'), findsOneWidget);
      // A statisztikasorban nincs duplán a passzolt TD.
      expect(find.textContaining('passz yd · 3 TD'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('RB és K: touchdown, illetve rúgott pont', (tester) async {
      await tester.pumpWidget(
        _host(
          Column(
            children: [
              NflGameLogView(
                log: _nflLog(
                  'espn_nfl_gamelog_barkley.json',
                  'Saquon Barkley',
                  'RB',
                ),
                accent: const Color(0xFF004C54),
              ),
              NflGameLogView(
                log: _nflLog(
                  'espn_nfl_gamelog_elliott.json',
                  'Jake Elliott',
                  'PK',
                ),
                accent: const Color(0xFF004C54),
              ),
            ],
          ),
        ),
      );
      expect(find.text('2 TD · 12 pont'), findsOneWidget);
      expect(find.text('1 TD · 6 pont'), findsNWidgets(2));
      expect(find.text('6 pont'), findsNWidgets(2));
      expect(find.text('1 pont'), findsOneWidget);
    });
  });

  group('foci', () {
    final aitanaTeam = EspnSoccerTeam.fromHints(
      AthleteSourceHints.ligaFBarcelona,
      'FC Barcelona',
    )!;
    final fotMob = FotMobFootballRepository.parseRecentMatches(
      fixture('fotmob_player_aitana.json'),
    );

    testWidgets('Liga F: FotMob elsőként, ESPN-összefoglaló csak a '
        'hiányzó meccshez', (tester) async {
      final semantics = tester.ensureSemantics();
      final http = FakeHttpService({
        '/apis/site/v2/sports/soccer/esp.w.1/summary': fixture(
          'espn_soccer_summary_barcelona.json',
        ),
      });
      final season = _FakeSeason(fotMob);
      await tester.pumpWidget(
        _host(
          EspnSoccerGameList(
            team: aitanaTeam,
            athleteName: 'Aitana Bonmatí',
            accent: Colors.indigo,
            games: [
              // FotMob: 0 gól, 12 perc (más ellenfélnévvel) — nincs jelölés.
              EspnSoccerGame(
                date: DateTime.utc(2026, 9, 26, 14, 30),
                opponent: 'Dux Logroño',
                teamScore: 2,
                opponentScore: 0,
                home: false,
                eventId: '401882506',
              ),
              // FotMob: 1 gól.
              EspnSoccerGame(
                date: DateTime.utc(2026, 5, 27, 17),
                opponent: 'Real Sociedad',
                teamScore: 2,
                opponentScore: 1,
                home: true,
                eventId: '749217',
              ),
              // FotMob nem ismeri: az ESPN-összefoglaló dönt.
              EspnSoccerGame(
                date: DateTime.utc(2025, 3, 2, 12),
                opponent: 'Real Sociedad',
                teamScore: 2,
                opponentScore: 1,
                home: true,
                eventId: '749217',
              ),
            ],
          ),
          overrides: [
            footballSeasonRepositoryProvider.overrideWithValue(season),
            matchTimelineRepositoryProvider.overrideWithValue(
              MatchTimelineRepository(
                http: http,
                cacheStorage: MemoryCacheStorage(),
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('1 gól'), findsNWidgets(2));
      expect(_contribution, findsNWidgets(2));
      expect(
        find.bySemanticsLabel('Aitana Bonmatí 1 gólt szerzett'),
        findsNWidgets(2),
      );
      expect(season.calls, 1, reason: 'egy közös szezonlekérés');
      expect(
        http.requests.map((uri) => uri.queryParameters['event']),
        ['749217'],
        reason: 'csak a FotMobban nem szereplő meccs összefoglalója',
      );
      semantics.dispose();
    });

    testWidgets('csapatmeccsek: OpenLigaDB góllövők, ha a FotMob nem adott '
        'meccslistát', (tester) async {
      final matches = [
        for (final raw
            in jsonDecode(
                  File(
                    'test/fixtures/openligadb_bl1_2026.json',
                  ).readAsStringSync(),
                )
                as List)
          raw as Map<String, dynamic>,
      ];
      final recent = OpenLigaDbRepository.parseTeamGames(
        matches,
        league: OpenLigaLeague.bundesliga,
        teamId: 40,
        teamName: 'FC Bayern München',
        now: DateTime.utc(2026, 9, 30, 12),
      ).recentGames();
      await tester.pumpWidget(
        _host(
          const FootballDataCard(
            athleteName: 'Harry Kane',
            teamName: 'FC Bayern München',
            accent: Colors.red,
          ),
          overrides: [
            footballSeasonRepositoryProvider.overrideWithValue(
              _FakeSeason(const []),
            ),
            footballDataRepositoryProvider.overrideWithValue(
              _FakeTeamGames(
                FootballTeamGames(recent: recent, source: 'OpenLigaDB'),
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('LEJÁTSZOTT MÉRKŐZÉSEK'), findsOneWidget);
      expect(find.text('2 gól'), findsOneWidget);
      expect(find.text('1 gól'), findsOneWidget);
      expect(_contribution, findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('csapatmeccsek: a FotMob-meccs gólpassza', (tester) async {
      await tester.pumpWidget(
        _host(
          const FootballDataCard(
            athleteName: 'Aitana Bonmatí',
            teamName: 'FC Barcelona',
            accent: Colors.indigo,
          ),
          overrides: [
            footballSeasonRepositoryProvider.overrideWithValue(
              _FakeSeason([
                FootballMatchForm(
                  date: DateTime.utc(2026, 4, 26, 16),
                  opponent: 'Real Madrid (W)',
                  teamScore: 3,
                  opponentScore: 1,
                  goals: 0,
                  assists: 1,
                ),
              ]),
            ),
            footballDataRepositoryProvider.overrideWithValue(
              _FakeTeamGames(
                FootballTeamGames(
                  recent: [
                    FootballGame(
                      // A TheSportsDB csak dátumot ad (helyi éjfél).
                      date: DateTime(2026, 4, 26),
                      opponent: 'Real Madrid Femenino',
                      score: '3–1',
                      result: FootballResult.win,
                    ),
                  ],
                  source: 'TheSportsDB',
                ),
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('1 gólpassz'), findsOneWidget);
    });
  });
}
