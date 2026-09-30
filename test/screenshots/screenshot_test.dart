// Vizuális ellenőrzéshez készülő képernyőképek (nem golden-összehasonlítás).
//
// Csak `COURTBOARD_SCREENSHOTS=1` környezeti változóval fut:
//   $env:COURTBOARD_SCREENSHOTS=1; flutter test test/screenshots
// A PNG-k a `test/screenshots/out/` mappába kerülnek (gitignore alatt).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:courtboard/data/athlete_highlights.dart';
import 'package:courtboard/data/basketball_reference.dart';
import 'package:courtboard/data/basketball_season.dart';
import 'package:courtboard/data/darts.dart';
import 'package:courtboard/data/espn_liga_f.dart';
import 'package:courtboard/data/file_util.dart';
import 'package:courtboard/data/json_file_cache.dart';
import 'package:courtboard/data/live_tennis.dart';
import 'package:courtboard/data/local_state.dart';
import 'package:courtboard/data/multi_provider.dart';
import 'package:courtboard/data/news.dart';
import 'package:courtboard/data/rapidapi_wnba.dart';
import 'package:courtboard/data/wehoop_wnba.dart';
import 'package:courtboard/main.dart';
import 'package:courtboard/theme/courtboard_theme.dart';

final bool _enabled = Platform.environment['COURTBOARD_SCREENSHOTS'] == '1';

/// Normál `flutter test` futáskor a képernyőkép-tesztek kimaradnak.
final bool _skip = !_enabled;

const _outDir = 'test/screenshots/out';
const _shotKey = ValueKey('screenshot-root');

Future<void> _loadFonts() async {
  const windowsFonts = r'C:\Windows\Fonts';
  Future<ByteData> read(String path) async {
    final bytes = await File(path).readAsBytes();
    return ByteData.view(Uint8List.fromList(bytes).buffer);
  }

  Future<void> family(String name, List<String> paths) async {
    final loader = FontLoader(name);
    var any = false;
    for (final path in paths) {
      if (File(path).existsSync()) {
        loader.addFont(read(path));
        any = true;
      }
    }
    if (any) await loader.load();
  }

  const segoe = [
    '$windowsFonts\\segoeui.ttf',
    '$windowsFonts\\seguisb.ttf',
    '$windowsFonts\\segoeuib.ttf',
    '$windowsFonts\\seguibl.ttf',
  ];
  await family('Segoe UI', segoe);
  // A ThemeData alapértelmezett és a tesztkörnyezet tartalék családjai.
  await family('Roboto', segoe);
  await family('.SF UI Text', segoe);
  await family('.SF UI Display', segoe);

  final flutterRoot = _flutterRoot();
  if (flutterRoot != null) {
    final icons = [
      '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
      '$flutterRoot/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
    ];
    await family('MaterialIcons', [
      icons.firstWhere(
        (path) => File(path).existsSync(),
        orElse: () => icons.first,
      ),
    ]);
  }
}

String? _flutterRoot() {
  final env = Platform.environment['FLUTTER_ROOT'];
  if (env != null && env.isNotEmpty) return env;
  final result = Process.runSync('where', ['flutter'], runInShell: true);
  final first = '${result.stdout}'.split(RegExp(r'\r?\n')).first.trim();
  if (first.isEmpty) return null;
  return File(first).parent.parent.path;
}

Future<void> _capture(WidgetTester tester, String name) async {
  await tester.pump(const Duration(milliseconds: 50));
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_shotKey),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    final file = File('$_outDir/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(data!.buffer.asUint8List());
  });
}

/// Néhány képkocka valós idővel, hogy a helyi (isolate-os) aszinkron
/// műveletek (SQLite, feldolgozók) is lefussanak; soha nem vár végtelenül.
Future<void> _settle(WidgetTester tester, {int rounds = 4}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 120)),
    );
    await tester.pump(const Duration(milliseconds: 400));
  }
}

Future<void> _seedNews() async {
  final store = NewsStore();
  final now = DateTime.now();
  NewsArticle article(
    int i,
    String sport,
    String source,
    String title,
    String summary,
  ) => NewsArticle(
    dedupeKey: 'shot-$i',
    sourceId: const [
      'fox_nba',
      'espn_wnba',
      'guardian_football',
      'fox_nba',
      'espn_tennis',
      'cbs_nba',
    ][i - 1],
    sourceName: source,
    sport: sport,
    title: title,
    summary: summary,
    url: 'https://example.com/$i',
    publishedAt: now.subtract(Duration(hours: i * 3)),
    fetchedAt: now,
  );
  await store.saveArticles([
    article(
      1,
      'NBA',
      'FOX Sports',
      'Nikola Jokić leads Denver past Phoenix with another triple-double',
      'The three-time MVP finished with 31 points, 14 rebounds and 12 assists.',
    ),
    article(
      2,
      'WNBA',
      'ESPN',
      'Lynx rookie Dorka Juhász sparks second-half comeback',
      'The Hungarian forward added energy off the bench in Minneapolis.',
    ),
    article(
      3,
      'Foci',
      'BBC Sport',
      'Aitana Bonmatí shines as Barcelona Femení cruise in Liga F',
      'Two assists and a goal for the Ballon d\'Or winner.',
    ),
    article(
      4,
      'Darts',
      'PDC',
      'Luke Humphries books his place in the Grand Slam semi-finals',
      '',
    ),
    article(
      5,
      'Tenisz',
      'WTA',
      'Świątek returns to Stuttgart with fresh confidence',
      'The former world No. 1 opens against a qualifier on Tuesday.',
    ),
    article(
      6,
      'NBA',
      'NBA.com',
      'Power rankings: the West is as crowded as ever',
      'Denver, Oklahoma City and Minnesota lead a tight pack.',
    ),
  ]);
  await store.close();
}

CourtboardLocalState _state(String accent, String mode) => CourtboardLocalState(
  theme: accent,
  themeMode: mode,
  customAthletes: const [
    CustomAthlete(
      name: 'Juhász Dorka',
      sport: 'WNBA',
      team: 'Minnesota Lynx',
      country: 'Magyarország',
    ),
  ],
);

/// Magas felület a teljes (görgethető) profil lefényképezéséhez.
Future<void> _captureTall(WidgetTester tester, Size size, String name) async {
  tester.view.physicalSize = Size(size.width, 2400);
  await _settle(tester, rounds: 2);
  for (final state in tester.stateList<ScrollableState>(
    find.byType(Scrollable),
  )) {
    if (state.position.axis == Axis.vertical && state.position.hasPixels) {
      state.position.jumpTo(0);
    }
  }
  await _settle(tester, rounds: 1);
  await _capture(tester, name);
  tester.view.physicalSize = size;
  await _settle(tester, rounds: 1);
}

/// Minta-kiemelések (legutóbbi eredmény / következő esemény), ahogy a
/// profil adatkártyái mentenék őket — a „Mai fókusz” és a kártyák
/// eredménysorának bemutatásához.
Future<void> _seedHighlights() async {
  final store = AthleteHighlightStore.shared;
  final now = DateTime.now();
  await store.record('Nikola Jokić', [
    HighlightEvent(
      date: now.subtract(const Duration(days: 1)),
      title: 'San Antonio Spurs',
      outcome: 'win',
      score: '118–104',
    ),
  ]);
  await store.record('Juhász Dorka', [
    HighlightEvent(
      date: now.subtract(const Duration(days: 3)),
      title: 'Toronto Tempo',
      outcome: 'win',
      score: '84–78',
    ),
  ]);
  await store.record('Caitlin Clark', [
    HighlightEvent(
      date: now.subtract(const Duration(days: 2)),
      title: 'Seattle Storm',
      outcome: 'loss',
      score: '85–90',
    ),
  ]);
  await store.record('Luke Humphries', [
    HighlightEvent(
      date: now.subtract(const Duration(days: 5)),
      title: 'World Matchplay',
      outcome: 'win',
    ),
  ]);
}

Future<void> _clearHighlights() async {
  for (final name in const [
    'Nikola Jokić',
    'Juhász Dorka',
    'Caitlin Clark',
    'Luke Humphries',
  ]) {
    await CacheStorage.shared.delete(
      AthleteHighlightStore.namespace,
      JsonFileCache.fileNameFor(cacheSlug(name)),
    );
  }
}

/// Menüpont megnyitása kulccsal (a kompakt sávban nincs felirat; keskeny
/// ablakban előbb a fiókot nyitjuk ki).
Future<void> _openNav(WidgetTester tester, String label) async {
  final menu = find.byKey(const Key('open-navigation-drawer'));
  if (menu.evaluate().isNotEmpty) {
    await tester.tap(menu);
    await _settle(tester, rounds: 2);
  }
  await tester.tap(find.byKey(ValueKey('nav-$label')).last);
  await _settle(tester);
}

Future<void> _shootApp(
  WidgetTester tester, {
  required String accent,
  required String mode,
  required Size size,
  required String prefix,
  double textScale = 1,
  bool highlights = true,
  bool focusDemo = false,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.platformDispatcher.platformBrightnessTestValue = mode == 'dark'
      ? Brightness.dark
      : Brightness.light;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  // Valódi, elmosott árnyékok (a tesztkörnyezet alapból éles keretet rajzol
  // helyettük, ami a menükön sötét szegélynek látszana).
  debugDisableShadows = false;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.platformDispatcher.clearPlatformBrightnessTestValue();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });
  await tester.runAsync(_seedNews);
  if (highlights) {
    await _seedHighlights();
  } else {
    await _clearHighlights();
  }

  await tester.pumpWidget(
    RepaintBoundary(
      key: _shotKey,
      child: CourtboardApp(initialState: _state(accent, mode)),
    ),
  );
  await _settle(tester);
  await _capture(tester, '${prefix}01_attekintes');
  if (focusDemo) {
    // Billentyűzetes bejárás: a fókuszkeret az első sportolókártyán.
    for (var i = 0; i < 40; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      if (_focusedInkKey() == const ValueKey('athlete-Nikola Jokić')) break;
    }
    await _settle(tester, rounds: 1);
    await _capture(tester, '${prefix}01_attekintes_fokusz');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
  }
  await _captureTall(tester, size, '${prefix}01_attekintes_teljes');

  await _openNav(tester, 'Sportolók');
  await _capture(tester, '${prefix}02_sportolok');

  final dorka = find.byKey(const ValueKey('directory-athlete-Juhász Dorka'));
  await tester.scrollUntilVisible(
    dorka,
    120,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.tap(dorka);
  await _settle(tester, rounds: 6);
  await _capture(tester, '${prefix}03_profil_wnba');
  await _captureTall(tester, size, '${prefix}03_profil_wnba_teljes');

  await _openNav(tester, 'Áttekintés');
  final jokic = find.byKey(const ValueKey('athlete-Nikola Jokić'));
  await tester.scrollUntilVisible(
    jokic,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(jokic);
  await _settle(tester, rounds: 6);
  await _capture(tester, '${prefix}04_profil_nba');
  await _captureTall(tester, size, '${prefix}04_profil_nba_teljes');

  await tester.tap(find.byKey(const Key('profile-more-menu')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  await _settle(tester, rounds: 2);
  await _capture(tester, '${prefix}04_profil_menu');
  await tester.sendKeyEvent(LogicalKeyboardKey.escape);
  await _settle(tester, rounds: 1);

  await _openNav(tester, 'Hírek');
  await _settle(tester, rounds: 4);
  await _capture(tester, '${prefix}05_hirek');

  await _openNav(tester, 'Videók');
  await _capture(tester, '${prefix}05b_videok');

  await _openNav(tester, 'Adatforrások');
  await _capture(tester, '${prefix}06_adatforrasok');

  await _openNav(tester, 'Beállítások');
  await _capture(tester, '${prefix}07_beallitasok');
  await _captureTall(tester, size, '${prefix}07_beallitasok_teljes');

  // Az app lebontása, hogy ne maradjon függő időzítő vagy adatbázis.
  await tester.pumpWidget(const SizedBox());
  await _settle(tester, rounds: 2);
  // A teszt végi invariáns-ellenőrzés előtt vissza kell állítani.
  debugDisableShadows = true;
}

/// A fókuszban lévő InkWell kulcsa (ha van).
Key? _focusedInkKey() {
  final context = FocusManager.instance.primaryFocus?.context;
  if (context == null) return null;
  Key? key;
  context.visitAncestorElements((element) {
    if (element.widget is InkWell) {
      key = element.widget.key;
      return false;
    }
    return true;
  });
  return key;
}

/// Adatállapotú komponensek mintaadatokkal (a tesztben nincs hálózat).
Widget _gallery() {
  final games = [
    for (var i = 0; i < 6; i++)
      WnbaGameLog(
        gameId: '$i',
        date: DateTime(2026, 7, 30 - i * 3),
        team: 'Minnesota Lynx',
        opponent: [
          'Toronto Tempo',
          'Seattle Storm',
          'Indiana Fever',
          'Las Vegas Aces',
          'Chicago Sky',
          'Dallas Wings',
        ][i],
        teamScore: 84 + i,
        opponentScore: i.isEven ? 78 : 90,
        result: i.isEven ? WnbaResult.win : WnbaResult.loss,
        points: 8 + i * 3,
        rebounds: 5 + i,
        assists: 2,
        steals: 1,
        blocks: 0,
        minutes: 22.5,
        headshotUrl: '',
        turnovers: 1,
        fieldGoalsMade: 4,
        fieldGoalsAttempted: 9,
        seasonType: '2',
      ),
  ];
  final nbaGames = [
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
      gameScore: 28.4,
    ),
    NbaGameLog(
      date: DateTime(2026, 4, 10),
      opponent: 'Phoenix Suns',
      outcome: 'LOSS',
      location: 'HOME',
      minutes: 36,
      points: 24,
      rebounds: 11,
      assists: 9,
      steals: 1,
      blocks: 0,
      score: '109-112',
      gameScore: 18.2,
    ),
  ];
  return SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const BasketballSeasonSummaryFacts(
          summary: BasketballSeasonStat(
            league: 'NBA',
            season: '2025/2026',
            team: 'Denver Nuggets',
            source: 'Basketball Reference',
            games: 65,
            minutesPerGame: 34.8,
            pointsPerGame: 26.8,
            reboundsPerGame: 12.9,
            assistsPerGame: 10.7,
            stealsPerGame: 1.4,
            turnoversPerGame: 3.7,
            fieldGoalPercentage: 56.9,
          ),
          accent: Color(0xFFE9B86E),
        ),
        const SizedBox(height: 16),
        WnbaSeasonSummaryFacts(games: games),
        const SizedBox(height: 16),
        UnifiedAthleteFacts(
          data: UnifiedAthleteData(
            facts: const [
              AthleteFact(label: 'Poszt', value: 'C', source: 'API-Sports'),
              AthleteFact(
                label: 'Csapat',
                value: 'Denver Nuggets',
                source: 'TheSportsDB',
              ),
              AthleteFact(label: 'Magasság', value: '211 cm', source: 'NBA'),
            ],
            providers: const [
              DataProviderStatus(
                name: 'API-Sports',
                configured: true,
                hasData: true,
              ),
              DataProviderStatus(
                name: 'BALLDONTLIE',
                configured: false,
                hasData: false,
                message: 'Nincs API-kulcs',
              ),
              DataProviderStatus(
                name: 'TheSportsDB',
                configured: true,
                hasData: false,
              ),
            ],
            games: nbaGames,
          ),
          accent: const Color(0xFFE9B86E),
        ),
        const SizedBox(height: 16),
        LigaFGameList(
          games: [
            LigaFGame(
              date: DateTime(2026, 4, 22),
              opponent: 'Espanyol',
              teamScore: 4,
              opponentScore: 1,
              home: false,
            ),
            LigaFGame(
              date: DateTime(2026, 4, 15),
              opponent: 'Real Madrid',
              teamScore: 1,
              opponentScore: 1,
              home: true,
            ),
          ],
          accent: const Color(0xFF9CAAF7),
        ),
        const SizedBox(height: 16),
        DartsProfileFacts(
          data: DartsProfileData(
            player: const {
              'strPlayer': 'Luke Humphries',
              'strTeam': 'PDC',
              'strNationality': 'England',
              'dateBorn': '1995-02-11',
            },
            results: [
              DartsResult(
                date: DateTime(2026, 7, 26),
                event: 'Betfred World Matchplay Day 9',
                detail: 'WIN',
              ),
              DartsResult(
                date: DateTime(2026, 7, 20),
                event: 'World Cup of Darts',
                detail: 'LOSS',
              ),
            ],
            rapidApiConfigured: false,
          ),
          accent: const Color(0xFFE894A7),
        ),
        const SizedBox(height: 16),
        const WnbaRapidProfileFacts(
          profile: WnbaRapidProfile(
            playerId: '4433403',
            team: 'Indiana Fever',
            season: 2026,
            facts: [
              WnbaAdvancedFact('PTS', '21.5'),
              WnbaAdvancedFact('AST', '8.4'),
              WnbaAdvancedFact('TS%', '55.1'),
            ],
            awards: ['1x Rookie of the Year'],
          ),
          accent: Color(0xFF70B7C5),
        ),
        const SizedBox(height: 16),
        TennisProfileFacts(
          data: TennisProfileData(
            player: const TennisPlayer(
              id: 7,
              name: 'Iga Swiatek',
              tour: 'wta',
              country: 'POL',
              ranking: 2,
              rankingPoints: 8000,
              hand: 'R',
              backhand: 2,
            ),
            usage: const TennisUsage(tier: 'FREE', today: 12, dailyLimit: 1000),
            fixtures: [
              TennisFixture(
                id: 100,
                tournament: 'Cincinnati',
                player1: 'Gauff Coco',
                player2: 'Swiatek Iga',
                eventDate: DateTime(2026, 8, 4, 17),
              ),
            ],
          ),
          accent: const Color(0xFF8ED19C),
        ),
      ],
    ),
  );
}

void main() {
  setUpAll(() async {
    if (_enabled) await _loadFonts();
  });

  const wide = Size(1600, 900);
  const narrow = Size(1100, 800);
  const minimum = Size(800, 600);
  const drawer = Size(720, 900);
  const ultraWide = Size(2400, 1000);

  // (kiemelőszín, mód, méret, szövegnagyítás, kiemelések, fókuszdemó)
  for (final (accent, mode, size, scale, highlights, focus) in const [
    ('green', 'light', wide, 1.0, true, true),
    ('burgundy', 'light', wide, 1.0, true, false),
    ('green', 'dark', wide, 1.0, true, false),
    ('burgundy', 'dark', wide, 1.0, true, false),
    ('green', 'light', narrow, 1.0, false, false),
    ('burgundy', 'dark', narrow, 1.0, true, false),
    ('green', 'light', minimum, 1.0, true, false),
    ('green', 'light', minimum, 1.3, true, false),
    ('green', 'dark', narrow, 1.3, true, false),
    ('green', 'light', drawer, 1.0, true, false),
    ('green', 'light', ultraWide, 1.0, true, false),
  ]) {
    final label =
        '${size.width.toInt()}${scale == 1 ? '' : '_x${scale.toString().replaceAll('.', '')}'}';
    testWidgets('screenshots $accent $mode $label', skip: _skip, (
      tester,
    ) async {
      await _shootApp(
        tester,
        accent: accent,
        mode: mode,
        size: size,
        textScale: scale,
        highlights: highlights,
        focusDemo: focus,
        prefix: '${mode}_${accent}_${label}_',
      );
    });
  }

  for (final (accent, brightness) in const [
    (CourtboardAccent.green, Brightness.light),
    (CourtboardAccent.burgundy, Brightness.dark),
  ]) {
    testWidgets(
      'component gallery ${accent.name} ${brightness.name}',
      skip: _skip,
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(1300, 2400);
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });
        await tester.pumpWidget(
          RepaintBoundary(
            key: _shotKey,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: buildCourtboardTheme(accent, brightness),
              home: Scaffold(body: _gallery()),
            ),
          ),
        );
        await tester.pump();
        await _capture(tester, 'gallery_${brightness.name}_${accent.name}');
      },
    );
  }
}
