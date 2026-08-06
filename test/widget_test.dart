import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:courtboard/data/multi_provider.dart';
import 'package:courtboard/data/basketball_reference.dart';
import 'package:courtboard/data/basketball_season.dart';
import 'package:courtboard/data/darts.dart';
import 'package:courtboard/data/live_tennis.dart';
import 'package:courtboard/data/espn_liga_f.dart';
import 'package:courtboard/data/rapidapi_wnba.dart';
import 'package:courtboard/data/wehoop_wnba.dart';
import 'package:courtboard/main.dart';

void main() {
  setUpAll(() => BasketballReferenceRepository.networkEnabled = false);
  tearDownAll(() => BasketballReferenceRepository.networkEnabled = true);

  test('athlete sorting and team visibility follow the saved preferences', () {
    Athlete athlete(String name, String sport, String team) => Athlete(
          name: name,
          sport: sport,
          team: team,
          country: 'Teszt',
          photoUrl: '',
          accent: Colors.blue,
          seasonLabel: '',
          seasonValue: '',
          primaryLabel: '',
          primaryValue: '',
          metrics: const [],
          matches: const [],
        );

    final darts = athlete('Luke Littler', 'Darts', 'Nincs megadva');
    final nba = athlete('Nikola Jokić', 'NBA', 'Denver Nuggets');
    final football = athlete('Aitana Bonmatí', 'Foci', 'FC Barcelona');
    final tennis = athlete('Iga Świątek', 'Tenisz', 'Nincs megadva');

    expect(darts.showsTeam, isFalse);
    expect(darts.sportAndTeam, 'Darts');
    expect(tennis.sportAndTeam, 'Tenisz');
    expect(nba.sportAndTeam, 'NBA · Denver Nuggets');
    expect(sortAthletes([nba, darts, football], 'name').map((a) => a.name),
        ['Aitana Bonmatí', 'Luke Littler', 'Nikola Jokić']);
    expect(sortAthletes([nba, darts, football], 'sport').map((a) => a.sport),
        ['Darts', 'Foci', 'NBA']);
  });

  testWidgets('overview settings button opens configurable settings',
      (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const CourtboardApp());
    await tester.pumpAndSettle();

    expect(find.text('A te személyes sportközpontod'), findsOneWidget);
    await tester.tap(find.byKey(const Key('overview-settings-button')));
    await tester.pumpAndSettle();

    expect(find.text('Beállítások'), findsNWidgets(2));
    expect(find.text('Zöld téma'), findsOneWidget);
    expect(find.text('Bordó téma'), findsOneWidget);
    expect(find.byKey(const Key('overview-sort-setting')), findsOneWidget);
    expect(find.byKey(const Key('athlete-sort-setting')), findsOneWidget);

    await tester.tap(find.text('Bordó téma'));
    await tester.pumpAndSettle();
    final context = tester.element(find.text('Megjelenés'));
    expect(Theme.of(context).colorScheme.primary, const Color(0xFF7A263A));
  });

  testWidgets('athlete directory supports name search and sport filtering',
      (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const CourtboardApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sportolók'));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const Key('athlete-directory-search')), 'Aitana');
    await tester.pump();
    expect(find.byKey(const ValueKey('directory-athlete-Aitana Bonmatí')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('directory-athlete-Nikola Jokić')),
        findsNothing);

    await tester.enterText(
        find.byKey(const Key('athlete-directory-search')), '');
    await tester.tap(find.byKey(const ValueKey('athlete-sport-Darts')));
    await tester.pump();
    expect(find.byKey(const ValueKey('directory-athlete-Luke Humphries')),
        findsOneWidget);
    expect(find.text('Darts · PDC'), findsNothing);
    expect(find.text('Darts'), findsWidgets);
  });

  testWidgets('athlete card opens a dedicated profile page', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const CourtboardApp());
    await tester.tap(find.byKey(const ValueKey('athlete-Nikola Jokić')));
    await tester.pumpAndSettle();

    expect(find.text('JÁTÉKOSPROFIL'), findsOneWidget);
    expect(find.text('LEGUTÓBBI NBA MECCSEK · BASKETBALL REFERENCE'),
        findsOneWidget);
    expect(find.text('Szezon összesítő'), findsOneWidget);
  });

  testWidgets('data source handbook is searchable', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const CourtboardApp());
    await tester.tap(find.text('Adatforrások'));
    await tester.pumpAndSettle();

    expect(find.text('Adatforrás-kézikönyv'), findsOneWidget);
    await tester.enterText(
        find.byKey(const Key('provider-doc-search')), 'Aitana');
    await tester.pump();

    expect(find.text('1 találat'), findsOneWidget);
    expect(find.text('ESPN · Liga F'), findsOneWidget);
    expect(find.text('TheSportsDB'), findsNothing);

    await tester.enterText(
        find.byKey(const Key('provider-doc-search')), 'beégetett');
    await tester.pump();

    expect(find.text('1 találat'), findsOneWidget);
    expect(find.text('football-data.org'), findsWidgets);
    await tester.tap(find.text('football-data.org').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('nincs beégetett Liverpool-azonosító'),
        findsOneWidget);
  });

  testWidgets('NFL athlete uses the unified NFL performance template',
      (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const CourtboardApp());
    final barkley = find.byKey(const ValueKey('athlete-Saquon Barkley'));
    await tester.scrollUntilVisible(barkley, 300,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(barkley);
    await tester.pumpAndSettle();

    expect(find.text('TELJESÍTMÉNYPROFIL'), findsOneWidget);
  });

  testWidgets('merged NBA facts and every provider status are visible',
      (tester) async {
    final data = UnifiedAthleteData(facts: const [
      AthleteFact(label: 'Poszt', value: 'C', source: 'API-Sports'),
      AthleteFact(
          label: 'Csapat', value: 'Denver Nuggets', source: 'TheSportsDB'),
    ], providers: const [
      DataProviderStatus(name: 'API-Sports', configured: true, hasData: true),
      DataProviderStatus(
          name: 'BALLDONTLIE',
          configured: false,
          hasData: false,
          message: 'Nincs API-kulcs'),
      DataProviderStatus(name: 'TheSportsDB', configured: true, hasData: true),
      DataProviderStatus(
          name: 'Basketball Reference', configured: true, hasData: true),
    ], games: [
      NbaGameLog(
          date: DateTime(2026, 4, 12),
          opponent: 'San Antonio Spurs',
          outcome: 'WIN',
          location: 'AWAY',
          minutes: 18.3,
          points: 23,
          rebounds: 8,
          assists: 1,
          steals: 0,
          blocks: 1,
          gameScore: 22.4)
    ]);

    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: UnifiedAthleteFacts(data: data, accent: Colors.amber))));

    expect(find.text('API-Sports'), findsNWidgets(2));
    expect(find.text('BALLDONTLIE'), findsOneWidget);
    expect(find.text('TheSportsDB'), findsNWidgets(2));
    expect(find.text('C'), findsOneWidget);
    expect(find.text('Denver Nuggets'), findsOneWidget);
    expect(find.text('LEGUTÓBBI NBA MECCSEK · BASKETBALL REFERENCE'),
        findsOneWidget);
    expect(find.text('San Antonio Spurs'), findsOneWidget);
    expect(find.text('23 PTS · 8 REB · 1 AST · 18 MIN'), findsOneWidget);
  });

  testWidgets('NBA season summary shows every requested metric',
      (tester) async {
    const summary = BasketballSeasonStat(
      league: 'NBA',
      season: '2025/2026',
      team: 'Denver Nuggets',
      source: 'Basketball Reference',
      games: 65,
      minutesPerGame: 34.8,
      pointsPerGame: 27.7,
      reboundsPerGame: 12.9,
      assistsPerGame: 10.7,
      stealsPerGame: 1.4,
      turnoversPerGame: 3.7,
      fieldGoalPercentage: 56.9,
    );

    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: BasketballSeasonSummaryFacts(
                summary: summary, accent: Colors.amber))));

    for (final label in const [
      'MÉRKŐZÉS',
      'PERC / MECCS',
      'PONT / MECCS',
      'LEPATTANÓ / MECCS',
      'ASSZISZT / MECCS',
      'LABDASZERZÉS / MECCS',
      'ELADOTT LABDA / MECCS',
      'FG%',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('56.9%'), findsOneWidget);
    expect(find.text('Denver Nuggets'), findsOneWidget);
    expect(find.text('NBA · 2025/2026'), findsOneWidget);
  });

  testWidgets('WNBA season summary shows every requested metric',
      (tester) async {
    final games = [
      WnbaGameLog(
        gameId: '1',
        date: DateTime(2026, 7, 30),
        team: 'Minnesota Lynx',
        opponent: 'Toronto Tempo',
        points: 12,
        rebounds: 5,
        assists: 2,
        steals: 1,
        blocks: 0,
        minutes: 22,
        headshotUrl: '',
        turnovers: 1,
        fieldGoalsMade: 4,
        fieldGoalsAttempted: 8,
        seasonType: '2',
      ),
    ];

    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: WnbaSeasonSummaryFacts(games: games))));

    for (final label in const [
      'MECCS',
      'PERC / MECCS',
      'PONT / MECCS',
      'LEPATTANÓ / MECCS',
      'ASSZISZT / MECCS',
      'LABDASZERZÉS / MECCS',
      'ELADOTT LABDA / MECCS',
      'FG%',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('50.0%'), findsOneWidget);
    expect(find.textContaining('Minnesota Lynx · WNBA 2026'), findsOneWidget);
  });

  testWidgets('Basketball Reference WNBA games show score and box score',
      (tester) async {
    final games = [
      NbaGameLog(
          date: DateTime(2026, 7, 30),
          opponent: 'Toronto Tempo',
          outcome: 'WIN',
          location: 'AWAY',
          minutes: 22,
          points: 12,
          rebounds: 5,
          assists: 2,
          steals: 1,
          blocks: 0,
          score: '104-72',
          gameScore: 11.6),
    ];

    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: BasketballReferenceGameList(
                games: games, accent: Colors.orange, league: 'WNBA'))));

    expect(find.text('LEGUTÓBBI WNBA MECCSEK · BASKETBALL REFERENCE'),
        findsOneWidget);
    expect(find.text('Toronto Tempo'), findsOneWidget);
    expect(find.text('104-72'), findsOneWidget);
    expect(find.text('12 PTS · 5 REB · 2 AST · 22 MIN'), findsOneWidget);
  });

  testWidgets('merged darts profile shows TheSportsDB results and providers',
      (tester) async {
    final data = DartsProfileData(player: const {
      'strPlayer': 'Luke Littler',
      'strTeam': 'PDC Mens',
      'strNationality': 'England',
      'dateBorn': '2007-01-21',
      'strStatus': 'Active',
    }, results: [
      DartsResult(
          date: DateTime(2026, 7, 26),
          event: 'Betfred World Matchplay Day 9',
          detail: 'WIN')
    ], rapidApiConfigured: false);

    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: DartsProfileFacts(data: data, accent: Colors.pink))));

    expect(find.text('TheSportsDB'), findsOneWidget);
    expect(find.text('RapidAPI · Darts API'), findsOneWidget);
    expect(find.text('Luke Littler'), findsOneWidget);
    expect(find.text('Betfred World Matchplay Day 9'), findsOneWidget);
    expect(find.text('GYŐZELEM'), findsOneWidget);
  });

  testWidgets('Liga F list shows Barcelona result and opponent',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: LigaFGameList(games: [
      LigaFGame(
          date: DateTime(2026, 4, 22),
          opponent: 'Espanyol',
          teamScore: 4,
          opponentScore: 1,
          home: false)
    ], accent: Colors.blue))));

    expect(find.text('Espanyol'), findsOneWidget);
    expect(find.text('4–1'), findsOneWidget);
    expect(find.text('IDEGEN · LIGA F'), findsOneWidget);
  });

  testWidgets('RapidAPI WNBA facts show advanced stats and awards',
      (tester) async {
    const profile = WnbaRapidProfile(
        playerId: '4433403',
        team: 'Indiana Fever',
        season: 2026,
        facts: [WnbaAdvancedFact('PTS', '21.5')],
        awards: ['1x Rookie of the Year']);

    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: WnbaRapidProfileFacts(
                profile: profile, accent: Colors.orange))));

    expect(find.text('21.5'), findsOneWidget);
    expect(find.text('PTS'), findsOneWidget);
    expect(find.text('1x Rookie of the Year'), findsOneWidget);
  });

  testWidgets('tennis profile shows ranking live score and next fixture',
      (tester) async {
    final player = TennisPlayer(
        id: 7,
        name: 'Iga Swiatek',
        tour: 'wta',
        country: 'POL',
        ranking: 2,
        rankingPoints: 8000,
        hand: 'R',
        backhand: 2);
    final data = TennisProfileData(
      player: player,
      usage: const TennisUsage(tier: 'FREE', today: 12, dailyLimit: 1000),
      liveMatches: [
        TennisMatch(
            id: 91,
            tournament: 'Montreal',
            status: 'live',
            player1: 'Iga Swiatek',
            player2: 'Coco Gauff',
            player1Id: 7,
            player2Id: 8,
            score: const TennisScore(sets: [
              1,
              0
            ], games: [
              [6, 2],
              [4, 1]
            ], points: [
              '15',
              '0'
            ]))
      ],
      fixtures: [
        TennisFixture(
            id: 100,
            tournament: 'Cincinnati',
            player1: 'Gauff Coco',
            player2: 'Swiatek Iga',
            eventDate: DateTime(2026, 8, 4, 17))
      ],
    );

    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: TennisProfileFacts(data: data, accent: Colors.green)))));

    expect(find.text('#2'), findsOneWidget);
    expect(find.text('vs. Coco Gauff'), findsOneWidget);
    expect(find.text('1–0 szett · 6–4, 2–1 · 15–0 pont'), findsOneWidget);
    expect(find.text('Cincinnati'), findsOneWidget);
    expect(find.textContaining('MA 12/1000 KÉRÉS'), findsOneWidget);
  });
}
