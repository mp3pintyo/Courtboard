import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:courtboard/data/multi_provider.dart';
import 'package:courtboard/data/basketball_reference.dart';
import 'package:courtboard/data/darts.dart';
import 'package:courtboard/data/espn_liga_f.dart';
import 'package:courtboard/data/rapidapi_wnba.dart';
import 'package:courtboard/main.dart';

void main() {
  setUpAll(() => BasketballReferenceRepository.networkEnabled = false);
  tearDownAll(() => BasketballReferenceRepository.networkEnabled = true);

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
}
