// Vizuális ellenőrzéshez készülő képernyőképek (nem golden-összehasonlítás).
//
// Csak `COURTBOARD_SCREENSHOTS=1` környezeti változóval fut:
//   $env:COURTBOARD_SCREENSHOTS=1; flutter test test/screenshots
// A PNG-k a `test/screenshots/out/` mappába kerülnek (gitignore alatt).
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart' show kSecondaryButton;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:courtboard/domain/athlete_source_hints.dart';
import 'package:courtboard/domain/sport.dart';
import 'package:courtboard/shared/components.dart';
import 'package:courtboard/data/athlete_highlights.dart';
import 'package:courtboard/data/athlete_watcher.dart';
import 'package:courtboard/data/basketball_reference.dart';
import 'package:courtboard/data/basketball_season.dart';
import 'package:courtboard/data/darts.dart';
import 'package:courtboard/data/espn_athletes.dart';
import 'package:courtboard/data/espn_schedule.dart';
import 'package:courtboard/data/espn_soccer_team.dart';
import 'package:courtboard/data/football_data.dart';
import 'package:courtboard/data/football_season_repository.dart';
import 'package:courtboard/data/fotmob_football.dart';
import 'package:courtboard/data/match_timeline.dart';
import 'package:courtboard/data/openligadb.dart';
import 'package:courtboard/data/providers.dart';
import 'package:courtboard/data/file_util.dart';
import 'package:courtboard/data/http_service.dart';
import 'package:courtboard/data/football_season.dart';
import 'package:courtboard/data/json_file_cache.dart';
import 'package:courtboard/data/live_scores.dart';
import 'package:courtboard/data/live_tennis.dart';
import 'package:courtboard/data/local_state.dart';
import 'package:courtboard/data/multi_provider.dart';
import 'package:courtboard/data/notification_settings.dart';
import 'package:courtboard/data/news.dart';
import 'package:courtboard/data/ranking_history.dart';
import 'package:courtboard/data/rapidapi_wnba.dart';
import 'package:courtboard/data/sports_api.dart';
import 'package:courtboard/data/upcoming_events.dart';
import 'package:courtboard/data/wehoop_wnba.dart';
import 'package:courtboard/data/youtube_playlist.dart';
import 'package:courtboard/desktop/startup_registration.dart';
import 'package:courtboard/features/compare/compare_data.dart';
import 'package:courtboard/features/profile/form_data.dart';
import 'package:courtboard/app/courtboard_app.dart';
import 'package:courtboard/app/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:courtboard/features/profile/profile_form.dart';
import 'package:courtboard/features/profile/sports/profile_api_basketball.dart';
import 'package:courtboard/features/profile/sports/profile_darts.dart';
import 'package:courtboard/features/profile/sports/profile_football.dart';
import 'package:courtboard/features/profile/sports/profile_nfl.dart';
import 'package:courtboard/features/profile/sports/profile_nba_facts.dart';
import 'package:courtboard/features/profile/sports/profile_tennis.dart';
import 'package:courtboard/features/profile/sports/profile_wnba.dart';
import 'package:courtboard/shared/theme/courtboard_theme.dart';

import '../support/fake_desktop.dart';
import '../support/fake_http.dart';

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

/// Legfeljebb [maxRounds] további [_settle] kör, amíg a [ready] igaz nem
/// lesz (valós idejű, aszinkron betöltésekhez).
Future<void> _settleUntil(
  WidgetTester tester,
  bool Function() ready, {
  int maxRounds = 20,
}) async {
  for (var i = 0; i < maxRounds && !ready(); i++) {
    await _settle(tester, rounds: 1);
  }
  await _settle(tester, rounds: 1);
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
  // A hírarchívum (drift, háttér-isolate) megnyitása néhány oda-vissza
  // üzenet; a „Legfrissebb a követettektől” hírei csak utána töltődnek be.
  await _settleUntil(
    tester,
    () => tester
        .container()
        .read(activityControllerProvider)
        .feedArticles
        .isNotEmpty,
  );
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

/// Minta-naptáresemények a követett sportolókhoz (a tesztben nincs hálózat,
/// ezért a naptár a gyorsítótárba előre betöltött listákat mutatja).
Future<void> _seedCalendar() async {
  final repository = UpcomingEventsRepository();
  final now = DateTime.now();
  DateTime day(int offset, int hour, [int minute = 0]) =>
      DateTime(now.year, now.month, now.day + offset, hour, minute);
  UpcomingEvent event(
    UpcomingEventsTarget target,
    DateTime start,
    String home,
    String away, {
    required String competition,
    String? venue,
    String source = 'ESPN',
    bool timeKnown = true,
  }) {
    final isHome = home == target.team || home == target.name;
    return UpcomingEvent(
      athleteName: target.name,
      sport: target.sport.jsonValue,
      title: '$home – $away',
      opponent: isHome ? away : home,
      homeAway: isHome ? 'home' : 'away',
      competition: competition,
      start: start,
      venue: venue,
      source: source,
      url: 'https://www.espn.com/',
      timeKnown: timeKnown,
    );
  }

  const jokic = UpcomingEventsTarget(
    name: 'Nikola Jokić',
    sport: Sport.nba,
    team: 'Denver Nuggets',
  );
  const clark = UpcomingEventsTarget(
    name: 'Caitlin Clark',
    sport: Sport.wnba,
    team: 'Indiana Fever',
  );
  const dorka = UpcomingEventsTarget(
    name: 'Juhász Dorka',
    sport: Sport.wnba,
    team: 'Minnesota Lynx',
  );
  const barkley = UpcomingEventsTarget(
    name: 'Saquon Barkley',
    sport: Sport.nfl,
    team: 'Philadelphia Eagles',
  );
  const aitana = UpcomingEventsTarget(
    name: 'Aitana Bonmatí',
    sport: Sport.football,
    team: 'FC Barcelona',
    sourceHints: AthleteSourceHints.ligaF,
  );
  const humphries = UpcomingEventsTarget(
    name: 'Luke Humphries',
    sport: Sport.darts,
  );

  final later = now.add(const Duration(hours: 2));
  await repository.seed(jokic, [
    event(
      jokic,
      DateTime(later.year, later.month, later.day, later.hour),
      'Denver Nuggets',
      'Utah Jazz',
      competition: 'NBA · Felkészülési mérkőzés',
      venue: 'Ball Arena, Denver',
    ),
    event(
      jokic,
      day(3, 4),
      'Golden State Warriors',
      'Denver Nuggets',
      competition: 'NBA · Alapszakasz',
      venue: 'Chase Center, San Francisco',
    ),
    event(
      jokic,
      day(5, 3, 30),
      'Denver Nuggets',
      'Los Angeles Lakers',
      competition: 'NBA · Alapszakasz',
      venue: 'Ball Arena, Denver',
    ),
  ]);
  await repository.seed(clark, [
    event(
      clark,
      day(1, 1, 30),
      'Las Vegas Aces',
      'Indiana Fever',
      competition: 'WNBA · Rájátszás',
      venue: 'Michelob ULTRA Arena, Las Vegas',
    ),
  ]);
  await repository.seed(dorka, [
    event(
      dorka,
      day(1, 3),
      'Minnesota Lynx',
      'Phoenix Mercury',
      competition: 'WNBA · Rájátszás',
      venue: 'Target Center, Minneapolis',
    ),
    event(
      dorka,
      day(6, 2),
      'Phoenix Mercury',
      'Minnesota Lynx',
      competition: 'WNBA · Rájátszás',
      venue: 'PHX Arena, Phoenix',
      timeKnown: false,
    ),
  ]);
  await repository.seed(aitana, [
    event(
      aitana,
      day(1, 12),
      'Real Madrid Femenino',
      'Barcelona Femení',
      competition: 'Liga F',
      venue: 'Estadio Alfredo Di Stéfano, Madrid',
    ),
  ]);
  await repository.seed(barkley, [
    event(
      barkley,
      day(4, 19),
      'Philadelphia Eagles',
      'Los Angeles Rams',
      competition: 'NFL · Alapszakasz · 5. hét',
      venue: 'Lincoln Financial Field, Philadelphia',
    ),
  ]);
  await repository.seed(
    humphries,
    [
      event(
        humphries,
        day(2, 20),
        'Luke Humphries',
        'Luke Littler',
        competition: 'World Grand Prix · 2. forduló',
        venue: 'Mattioli Arena, Leicester',
        source: 'TheSportsDB',
      ),
    ],
    notes: const ['RapidAPI Darts: a versenylista nem ad időpontot.'],
  );
}

Future<void> _shootCalendar(
  WidgetTester tester, {
  required String mode,
  required Size size,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.platformDispatcher.platformBrightnessTestValue = mode == 'dark'
      ? Brightness.dark
      : Brightness.light;
  debugDisableShadows = false;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.platformDispatcher.clearPlatformBrightnessTestValue();
  });
  // Tiszta gyorsítótár: csak a mintaesemények és -kiemelések látszanak.
  CacheStorage.shared = MemoryCacheStorage();
  await tester.runAsync(_seedNews);
  await _seedHighlights();
  await _seedCalendar();

  await tester.pumpWidget(
    RepaintBoundary(
      key: _shotKey,
      child: CourtboardApp(initialState: _state('green', mode)),
    ),
  );
  await _settle(tester);
  final prefix = '${mode}_green_${size.width.toInt()}_';
  // A naptár háttérbetöltése a „Mai fókusz”-t is frissíti.
  await _capture(tester, '${prefix}08a_attekintes_naptarbol');
  await _openNav(tester, 'Naptár');
  await _capture(tester, '${prefix}08_naptar');
  await _captureTall(tester, size, '${prefix}08_naptar_teljes');

  await tester.pumpWidget(const SizedBox());
  await _settle(tester, rounds: 2);
  CacheStorage.shared = MemoryCacheStorage();
  debugDisableShadows = true;
}

/// A Beállítások új kártyái (Értesítések, Tálca és indítás) hamis asztali
/// szolgáltatásokkal, hogy a kapcsolók engedélyezett állapotban látsszanak.
Future<void> _shootDesktopSettings(
  WidgetTester tester, {
  required String mode,
  required Size size,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.platformDispatcher.platformBrightnessTestValue = mode == 'dark'
      ? Brightness.dark
      : Brightness.light;
  debugDisableShadows = false;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.platformDispatcher.clearPlatformBrightnessTestValue();
  });
  final startup = MemoryStartupRegistration(
    command: startupCommand(
      MemoryStartupRegistration.executablePath,
      minimized: true,
    ),
  );
  final base = _state('green', mode);
  await tester.pumpWidget(
    RepaintBoundary(
      key: _shotKey,
      child: CourtboardApp(
        initialState: CourtboardLocalState(
          theme: base.theme,
          themeMode: base.themeMode,
          customAthletes: base.customAthletes,
          alerts: const {'Nikola Jokić': true, 'Caitlin Clark': true},
          closeToTray: true,
          startMinimized: true,
          notifications: const NotificationSettings(quietHours: true),
          notificationsPausedUntil: DateTime.now().add(
            const Duration(minutes: 40),
          ),
        ),
        desktop: FakeDesktopIntegration(startup: startup),
        notificationService: FakeNotificationService(),
        startupRegistration: startup,
        watcherSource: FakeWatcherSource(),
        watcherMemoryStore: MemoryWatcherMemoryStore(),
      ),
    ),
  );
  await _settle(tester);
  await _openNav(tester, 'Beállítások');
  final prefix = '${mode}_green_${size.width.toInt()}_';
  final settingsList = find
      .descendant(
        of: find.byType(ListView).last,
        matching: find.byType(Scrollable),
      )
      .first;
  await tester.scrollUntilVisible(
    find.byKey(const Key('notifications-enabled-setting')),
    200,
    scrollable: settingsList,
  );
  await _settle(tester, rounds: 2);
  await _capture(tester, '${prefix}09_beallitasok_ertesitesek');
  await tester.scrollUntilVisible(
    find.byKey(const Key('start-minimized-setting')),
    200,
    scrollable: settingsList,
  );
  // A kártya címe kerüljön a nézet tetejére.
  await tester.ensureVisible(find.text('Tálca és indítás'));
  await _settle(tester, rounds: 2);
  await _capture(tester, '${prefix}09_beallitasok_talca');
  await _captureTall(tester, size, '${prefix}09_beallitasok_teljes');

  await tester.pumpWidget(const SizedBox());
  await _settle(tester, rounds: 2);
  debugDisableShadows = true;
}

/// Mintaadatos szezonösszesítő az Összehasonlítás oldalhoz (a tesztben
/// nincs hálózat). Csak a képernyőképekhez; nem valós statisztika.
class _FixtureCompareSource implements CompareDataSource {
  const _FixtureCompareSource();

  @override
  Future<AthleteSeasonSnapshot?> load({
    required String name,
    required Sport sport,
    required String team,
    required SportsApiConfig config,
    bool force = false,
  }) async => switch (name) {
    'Nikola Jokić' => snapshotFromBasketball(
      name,
      const BasketballSeasonStat(
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
    ),
    'Luka Dončić' => snapshotFromBasketball(
      name,
      const BasketballSeasonStat(
        league: 'NBA',
        season: '2025/2026',
        team: 'Los Angeles Lakers',
        source: 'Basketball Reference',
        games: 70,
        minutesPerGame: 36.2,
        pointsPerGame: 28.4,
        reboundsPerGame: 8.1,
        assistsPerGame: 7.9,
        stealsPerGame: 1.6,
        turnoversPerGame: 3.9,
        fieldGoalPercentage: 47.1,
      ),
    ),
    _ => null,
  };
}

/// Több lejátszott eredmény sportolónként (a hírfolyam „Eredmény” elemei).
Future<void> _seedFeedHighlights() async {
  final store = AthleteHighlightStore.shared;
  final now = DateTime.now();
  HighlightEvent played(
    int hoursAgo,
    String title,
    String outcome,
    String score,
  ) => HighlightEvent(
    date: now.subtract(Duration(hours: hoursAgo)),
    title: title,
    outcome: outcome,
    score: score,
  );
  await store.record('Nikola Jokić', [
    played(20, 'San Antonio Spurs', 'win', '118–104'),
    played(70, 'Phoenix Suns', 'loss', '109–112'),
  ]);
  await store.record('Juhász Dorka', [
    played(5, 'Toronto Tempo', 'win', '84–78'),
    played(52, 'Seattle Storm', 'win', '90–81'),
  ]);
  await store.record('Caitlin Clark', [
    played(44, 'Seattle Storm', 'loss', '85–90'),
  ]);
  await store.record('Luke Humphries', [
    HighlightEvent(
      date: now.subtract(const Duration(days: 5)),
      title: 'World Matchplay',
      outcome: 'win',
    ),
  ]);
}

Future<File> _seedPlaylist() async {
  final now = DateTime.now();
  final file = File(
    '${Directory.systemTemp.path}/courtboard-shot-playlist-${now.microsecondsSinceEpoch}.json',
  );
  final playlist = AthleteVideoPlaylist(
    videos: [
      SavedYouTubeVideo(
        videoId: 'dQw4w9WgXcQ',
        athleteName: 'Nikola Jokić',
        title: 'Nikola Jokić – szezon legjobb passzai',
        thumbnailUrl: SavedYouTubeVideo.defaultThumbnailUrl('dQw4w9WgXcQ'),
        savedAt: now.subtract(const Duration(minutes: 35)),
      ),
      SavedYouTubeVideo(
        videoId: 'aqz-KE-bpKQ',
        athleteName: 'Juhász Dorka',
        title: 'Juhász Dorka – 18 pont a Lynx győzelméhez',
        thumbnailUrl: SavedYouTubeVideo.defaultThumbnailUrl('aqz-KE-bpKQ'),
        savedAt: now.subtract(const Duration(days: 3, hours: 2)),
      ),
    ],
  );
  await file.writeAsString(jsonEncode(playlist.toJson()));
  return file;
}

/// Az 0.12.0 új nézetei: kitűzött sportolók és hírfolyam a nyitóoldalon,
/// a kártya helyi menüje, a „Követés” oldal és az „Összehasonlítás”.
Future<void> _shootInsights(
  WidgetTester tester, {
  required String accent,
  required String mode,
  required Size size,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.platformDispatcher.platformBrightnessTestValue = mode == 'dark'
      ? Brightness.dark
      : Brightness.light;
  debugDisableShadows = false;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.platformDispatcher.clearPlatformBrightnessTestValue();
  });
  CacheStorage.shared = MemoryCacheStorage();
  await tester.runAsync(_seedNews);
  await _seedFeedHighlights();
  await _seedCalendar();
  final playlist = (await tester.runAsync(_seedPlaylist))!;
  final base = _state(accent, mode);

  await tester.pumpWidget(
    RepaintBoundary(
      key: _shotKey,
      child: CourtboardApp(
        initialState: CourtboardLocalState(
          theme: base.theme,
          themeMode: base.themeMode,
          customAthletes: [
            ...base.customAthletes,
            const CustomAthlete(
              name: 'Luka Dončić',
              sport: 'NBA',
              team: 'Los Angeles Lakers',
              country: 'Szlovénia',
            ),
          ],
          pinnedAthletes: const ['Caitlin Clark', 'Juhász Dorka'],
        ),
        playlistFile: playlist,
        compareSource: const _FixtureCompareSource(),
      ),
    ),
  );
  await _settle(tester, rounds: 6);
  final prefix = '${mode}_${accent}_${size.width.toInt()}_';
  await _capture(tester, '${prefix}10_attekintes_kituzve');
  await _captureTall(tester, size, '${prefix}10_attekintes_hirfolyam');

  // A kártya helyi menüje (jobb kattintás).
  final tile = find.byKey(const ValueKey('athlete-Nikola Jokić'));
  await tester.scrollUntilVisible(
    tile,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(tile, buttons: kSecondaryButton);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  await _settle(tester, rounds: 2);
  await _capture(tester, '${prefix}11_kartya_menu');
  await tester.sendKeyEvent(LogicalKeyboardKey.escape);
  await _settle(tester, rounds: 1);

  await _openNav(tester, 'Követés');
  await _capture(tester, '${prefix}12_kovetes');
  await _captureTall(tester, size, '${prefix}12_kovetes_teljes');

  await _openNav(tester, 'Összehasonlítás');
  await _settle(tester, rounds: 4);
  await _capture(tester, '${prefix}13_osszehasonlitas');
  await _captureTall(tester, size, '${prefix}13_osszehasonlitas_teljes');

  await tester.pumpWidget(const SizedBox());
  await _settle(tester, rounds: 2);
  await tester.runAsync(() async {
    try {
      await playlist.delete();
    } catch (_) {}
  });
  CacheStorage.shared = MemoryCacheStorage();
  debugDisableShadows = true;
}

/// Élő eredmények, egymás elleni mérleg, foci-idővonal és NFL-meccsnapló.
/// A hálózatot a tesztfixture-ökre épülő hamis HTTP-réteg helyettesíti
/// (NBA CDN élő meccs, ESPN soccer/all élő meccs, ESPN-meccsnaplók).
Map<String, Object> _liveRoutes() {
  final summary = fixture('espn_soccer_summary_final.json');
  // Az összefoglaló a 63. percig (a scoreboard élő állapotához igazítva).
  final live = jsonDecode(jsonEncode(summary)) as Map<String, dynamic>;
  final header = live['header'] as Map<String, dynamic>;
  final competition =
      (header['competitions'] as List).first as Map<String, dynamic>;
  competition['status'] = {
    'type': {'state': 'in', 'completed': false, 'shortDetail': "63'"},
  };
  for (final competitor in competition['competitors'] as List) {
    final side = competitor as Map<String, dynamic>;
    side['score'] = side['homeAway'] == 'home' ? '2' : '1';
  }
  live['keyEvents'] = [
    for (final event in live['keyEvents'] as List)
      if (((event as Map)['clock'] as Map)['value'] as num <= 3780) event,
  ];
  return {
    '/static/json/liveData/scoreboard/todaysScoreboard_00.json': fixture(
      'nba_cdn_scoreboard.json',
    ),
    '/apis/site/v2/sports/basketball/nba/teams': fixture('espn_nba_teams.json'),
    '/apis/site/v2/sports/basketball/wnba/scoreboard': fixture(
      'espn_wnba_scoreboard_final.json',
    ),
    '/apis/site/v2/sports/football/nfl/scoreboard': fixture(
      'espn_nfl_scoreboard_pregame.json',
    ),
    '/apis/site/v2/sports/soccer/all/scoreboard': fixture(
      'espn_soccer_scoreboard_live.json',
    ),
    '/apis/site/v2/sports/soccer/esp.w.1/scoreboard': fixture(
      'espn_scoreboard_empty.json',
    ),
    '/apis/site/v2/sports/soccer/all/summary': live,
    '/apis/common/v3/search': (Uri uri) =>
        switch (uri.queryParameters['query']) {
          'Jalen Hurts' => fixture('espn_search_hurts.json'),
          'Nikola Jokić' => fixture('espn_search_jokic.json'),
          _ => <String, dynamic>{'items': <Object>[]},
        },
    '/apis/common/v3/sports/basketball/nba/athletes/3112335/gamelog': fixture(
      'espn_nba_gamelog_jokic.json',
    ),
    '/apis/common/v3/sports/football/nfl/athletes/4040715/gamelog': fixture(
      'espn_nfl_gamelog_hurts.json',
    ),
    '/apis/site/v2/sports/basketball/nba/teams/7/schedule': fixture(
      'espn_nba_schedule_den.json',
    ),
    '/apis/site/v2/sports/basketball/nba/teams/7/schedule?season=2026&seasontype=2':
        fixture('espn_nba_schedule_den_2026.json'),
  };
}

Future<void> _shootLive(
  WidgetTester tester, {
  required String accent,
  required String mode,
  required Size size,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.platformDispatcher.platformBrightnessTestValue = mode == 'dark'
      ? Brightness.dark
      : Brightness.light;
  debugDisableShadows = false;
  final previousHttp = HttpService.shared;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.platformDispatcher.clearPlatformBrightnessTestValue();
    HttpService.shared = previousHttp;
  });
  CacheStorage.shared = MemoryCacheStorage();
  HttpService.shared = FakeHttpService(_liveRoutes());
  // A korábbi (hálózat nélküli) jelenetek NBA CDN-tiltása ne hasson ide.
  LiveScoresRepository.resetNbaCdnBackoff();
  await tester.runAsync(_seedNews);
  await _seedHighlights();
  await _seedCalendar();
  // Jokić következő meccse az Oklahoma City ellen (a mérleghez).
  final now = DateTime.now();
  await UpcomingEventsRepository().seed(
    const UpcomingEventsTarget(
      name: 'Nikola Jokić',
      sport: Sport.nba,
      team: 'Denver Nuggets',
    ),
    [
      UpcomingEvent(
        athleteName: 'Nikola Jokić',
        sport: 'NBA',
        title: 'Oklahoma City Thunder – Denver Nuggets',
        opponent: 'Oklahoma City Thunder',
        homeAway: 'away',
        competition: 'NBA · Alapszakasz',
        venue: 'Paycom Center, Oklahoma City',
        start: DateTime(now.year, now.month, now.day + 2, 1, 30),
        source: 'ESPN',
        url: 'https://www.espn.com/',
      ),
    ],
  );
  final base = _state(accent, mode);
  await tester.pumpWidget(
    RepaintBoundary(
      key: _shotKey,
      child: CourtboardApp(
        initialState: CourtboardLocalState(
          theme: base.theme,
          themeMode: base.themeMode,
          customAthletes: const [
            CustomAthlete(
              name: 'Jalen Hurts',
              sport: 'NFL',
              team: 'Philadelphia Eagles',
              country: 'USA',
            ),
            CustomAthlete(
              name: 'Ane Azkona',
              sport: 'Foci',
              team: 'Athletic Club',
              country: 'Spanyolország',
            ),
          ],
        ),
      ),
    ),
  );
  await _settle(tester, rounds: 6);
  final prefix = '${mode}_${accent}_${size.width.toInt()}_';
  await _capture(tester, '${prefix}14_elo_attekintes');

  // Jokić profilja: élő mérkőzés és a következő meccs egymás elleni mérlege.
  await tester.tap(find.byKey(const ValueKey('live-game-Nikola Jokić')));
  await _settle(tester, rounds: 6);
  final h2h = find.text('Legutóbbi egymás elleni meccsek').first;
  await tester.ensureVisible(h2h);
  await tester.tap(h2h);
  await _settle(tester, rounds: 4);
  await _capture(tester, '${prefix}15_profil_elo_h2h');
  await _captureTall(tester, size, '${prefix}15_profil_elo_h2h_teljes');

  // Foci: élő meccs lenyitott idővonallal.
  await _openNav(tester, 'Áttekintés');
  await tester.tap(find.byKey(const ValueKey('live-game-Ane Azkona')));
  await _settle(tester, rounds: 6);
  final timeline = find.text('Idővonal').first;
  await tester.ensureVisible(timeline);
  await tester.tap(timeline);
  await _settle(tester, rounds: 4);
  await _capture(tester, '${prefix}16_profil_foci_idovonal');

  // NFL: játékos-meccsnapló az ESPN-ből.
  await _openNav(tester, 'Sportolók');
  final hurts = find.byKey(const ValueKey('directory-athlete-Jalen Hurts'));
  await tester.scrollUntilVisible(
    hurts,
    120,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.tap(hurts);
  await _settle(tester, rounds: 6);
  await _captureTall(tester, size, '${prefix}17_profil_nfl_teljes');

  // Naptár: a következő meccsnél lenyitott egymás elleni mérleg.
  await _openNav(tester, 'Naptár');
  final calendarH2h = find.descendant(
    of: find.byKey(const ValueKey('h2h-Nikola Jokić-Oklahoma City Thunder')),
    matching: find.text('Legutóbbi egymás elleni meccsek'),
  );
  await tester.scrollUntilVisible(
    calendarH2h,
    200,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.ensureVisible(calendarH2h);
  await tester.tap(calendarH2h);
  await _settle(tester, rounds: 4);
  await _capture(tester, '${prefix}18_naptar_h2h');

  await tester.pumpWidget(const SizedBox());
  await _settle(tester, rounds: 2);
  CacheStorage.shared = MemoryCacheStorage();
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
    NbaGameLog(
      date: DateTime(2026, 4, 8),
      opponent: 'Utah Jazz',
      outcome: 'WIN',
      location: 'HOME',
      minutes: 32,
      points: 22,
      rebounds: 16,
      assists: 13,
      steals: 3,
      blocks: 1,
      score: '127-110',
      gameScore: 24.0,
    ),
    NbaGameLog(
      date: DateTime(2026, 4, 6),
      opponent: 'Los Angeles Lakers',
      outcome: 'LOSS',
      location: 'AWAY',
      minutes: 38,
      points: 35,
      rebounds: 10,
      assists: 8,
      steals: 1,
      blocks: 2,
      score: '114-119',
      gameScore: 26.1,
    ),
    NbaGameLog(
      date: DateTime(2026, 4, 3),
      opponent: 'Golden State Warriors',
      outcome: 'WIN',
      location: 'HOME',
      minutes: 35,
      points: 27,
      rebounds: 12,
      assists: 11,
      steals: 2,
      blocks: 0,
      score: '121-108',
      gameScore: 23.5,
    ),
  ];
  const nbaSeason = BasketballSeasonStat(
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
  );
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
          season: nbaSeason,
        ),
        const SizedBox(height: 16),
        FootballFormPanel(
          matches: [
            for (var i = 0; i < 7; i++)
              FootballMatchForm(
                date: DateTime(2026, 4, 26 - i * 4),
                opponent: const [
                  'Real Madrid',
                  'Atlético Madrid',
                  'Sevilla',
                  'Levante',
                  'Real Sociedad',
                  'Espanyol',
                  'Athletic Club',
                ][i],
                teamScore: const [3, 1, 2, 4, 0, 2, 1][i],
                opponentScore: const [1, 1, 0, 0, 1, 2, 0][i],
                rating: const [8.4, 7.1, 7.6, 8.9, 6.6, 7.3, 7.8][i],
                goals: const [1, 0, 0, 2, 0, 1, 0][i],
                assists: const [1, 0, 1, 1, 0, 0, 1][i],
              ),
          ],
          seasonRating: 7.62,
          accent: const Color(0xFF9CAAF7),
        ),
        const SizedBox(height: 16),
        TennisRankingForm(
          history: [
            for (var i = 0; i < 6; i++)
              RankingSnapshot(
                date: DateTime(2026, 7, 1 + i * 6),
                ranking: const [4, 4, 3, 3, 2, 2][i],
                points: const [6120, 6340, 6890, 7010, 7780, 8000][i],
              ),
          ],
          accent: const Color(0xFF8ED19C),
        ),
        const SizedBox(height: 16),
        ResultStrip(
          results: dartsResultMarks([
            for (var i = 0; i < 6; i++)
              DartsResult(
                date: DateTime(2026, 7, 26 - i * 3),
                event: 'World Matchplay · ${i + 1}. nap',
                detail: const ['WIN', 'WIN', 'LOSS', 'WIN', 'LOSS', 'WIN'][i],
              ),
          ]),
        ),
        const SizedBox(height: 16),
        EspnSoccerGameList(
          team: _aitanaTeam,
          games: [
            EspnSoccerGame(
              date: DateTime(2026, 4, 22),
              opponent: 'Espanyol',
              teamScore: 4,
              opponentScore: 1,
              home: false,
            ),
            EspnSoccerGame(
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

  for (final (mode, size) in const [
    ('light', wide),
    ('dark', wide),
    ('light', minimum),
  ]) {
    testWidgets(
      'calendar screenshots $mode ${size.width.toInt()}',
      skip: _skip,
      (tester) => _shootCalendar(tester, mode: mode, size: size),
    );
  }

  for (final (mode, size) in const [
    ('light', wide),
    ('dark', wide),
    ('light', minimum),
  ]) {
    testWidgets(
      'desktop settings screenshots $mode ${size.width.toInt()}',
      skip: _skip,
      (tester) => _shootDesktopSettings(tester, mode: mode, size: size),
    );
  }

  for (final (accent, mode, size) in const [
    ('green', 'light', wide),
    ('burgundy', 'dark', wide),
    ('green', 'light', minimum),
  ]) {
    testWidgets(
      'live and match detail screenshots $accent $mode ${size.width.toInt()}',
      skip: _skip,
      (tester) => _shootLive(tester, accent: accent, mode: mode, size: size),
    );
  }

  for (final (accent, mode, size) in const [
    ('green', 'light', wide),
    ('burgundy', 'dark', wide),
    ('green', 'light', narrow),
    ('green', 'light', drawer),
  ]) {
    testWidgets(
      'insights screenshots $accent $mode ${size.width.toInt()}',
      skip: _skip,
      (tester) =>
          _shootInsights(tester, accent: accent, mode: mode, size: size),
    );
  }

  for (final (accent, brightness) in const [
    (CourtboardAccent.green, Brightness.light),
    (CourtboardAccent.burgundy, Brightness.dark),
    (CourtboardAccent.green, Brightness.dark),
  ]) {
    testWidgets(
      'player contribution screenshots ${accent.name} ${brightness.name}',
      skip: _skip,
      (tester) => _shootContributions(tester, accent, brightness),
    );
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
        tester.view.physicalSize = const Size(1300, 4200);
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

/// Aitana Bonmatí csapata a Liga F-ben (a galériához).
final _aitanaTeam = EspnSoccerTeam.fromHints(
  AthleteSourceHints.ligaFBarcelona,
  'FC Barcelona',
)!;

// ---------------------------------------------------------------------------
// Pontszerzés a lejátszott meccsek soraiban (0.16.0)
// ---------------------------------------------------------------------------

/// Szezonösszesítő a FotMob meccslistájával (a hálózat helyett).
class _ShotSeason extends FootballSeasonRepository {
  _ShotSeason(this.matches) : super(const SportsApiConfig());
  final List<FootballMatchForm> matches;

  @override
  Future<FootballSeasonResult> fetchWithStatus(
    String athleteName,
    String teamName,
  ) async => matches.isEmpty
      ? const FootballSeasonResult()
      : FootballSeasonResult(
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

class _ShotTeamGames extends FootballDataRepository {
  _ShotTeamGames(this.games) : super(SportsApiClient());
  final FootballTeamGames games;

  @override
  Future<FootballTeamGames> fetchTeamGames(
    String teamName, {
    String? competition,
  }) async => games;
}

EspnGameLog _shotNflLog(String file, String name, String position) =>
    EspnAthleteRepository.parseGameLog(
      fixture(file),
      EspnAthleteRef(
        id: '1',
        displayName: name,
        league: EspnLeague.nfl,
        team: position == 'QB' ? 'Buffalo Bills' : 'Philadelphia Eagles',
        position: position,
      ),
    );

Future<void> _shootContributions(
  WidgetTester tester,
  CourtboardAccent accent,
  Brightness brightness,
) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1000, 3400);
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  final openLiga = [
    for (final raw
        in jsonDecode(
              File('test/fixtures/openligadb_bl1_2026.json').readAsStringSync(),
            )
            as List)
      raw as Map<String, dynamic>,
  ];
  final bayern = OpenLigaDbRepository.parseTeamGames(
    openLiga,
    league: OpenLigaLeague.bundesliga,
    teamId: 40,
    teamName: 'FC Bayern München',
    now: DateTime.utc(2026, 9, 30, 12),
  ).recentGames();
  final http = FakeHttpService({
    '/apis/site/v2/sports/soccer/esp.w.1/summary': fixture(
      'espn_soccer_summary_barcelona.json',
    ),
  });
  final aitana = EspnSoccerTeam.fromHints(
    AthleteSourceHints.ligaFBarcelona,
    'FC Barcelona',
  )!;
  await tester.pumpWidget(
    RepaintBoundary(
      key: _shotKey,
      child: ProviderScope(
        retry: noAutomaticRetry,
        overrides: [
          footballSeasonRepositoryProvider.overrideWithValue(
            _ShotSeason(
              FotMobFootballRepository.parseRecentMatches(
                fixture('fotmob_player_aitana.json'),
              ),
            ),
          ),
          matchTimelineRepositoryProvider.overrideWithValue(
            MatchTimelineRepository(
              http: http,
              cacheStorage: MemoryCacheStorage(),
            ),
          ),
          footballDataRepositoryProvider.overrideWithValue(
            _ShotTeamGames(
              FootballTeamGames(recent: bayern, source: 'OpenLigaDB'),
            ),
          ),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildCourtboardTheme(accent, brightness),
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SurfaceCard(
                    child: EspnSoccerGameList(
                      team: aitana,
                      athleteName: 'Aitana Bonmatí',
                      accent: const Color(0xFF9CAAF7),
                      games: [
                        EspnSoccerGame(
                          date: DateTime.utc(2026, 9, 26, 14, 30),
                          opponent: 'Dux Logroño',
                          teamScore: 2,
                          opponentScore: 0,
                          home: false,
                          eventId: '401882506',
                        ),
                        EspnSoccerGame(
                          date: DateTime.utc(2026, 5, 27, 17),
                          opponent: 'Real Sociedad',
                          teamScore: 2,
                          opponentScore: 1,
                          home: true,
                          eventId: '749217',
                        ),
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
                  ),
                  const SizedBox(height: 16),
                  const FootballDataCard(
                    athleteName: 'Harry Kane',
                    teamName: 'FC Bayern München',
                    accent: Color(0xFFE894A7),
                  ),
                  const SizedBox(height: 16),
                  SurfaceCard(
                    child: BasketballReferenceGameList(
                      athleteName: 'Nikola Jokić',
                      accent: const Color(0xFFE9B86E),
                      league: Sport.nba,
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
                          gameScore: 28.4,
                        ),
                        NbaGameLog(
                          date: DateTime(2026, 4, 10),
                          opponent: 'Phoenix Suns',
                          outcome: 'LOSS',
                          location: 'HOME',
                          minutes: 4,
                          points: 0,
                          rebounds: 1,
                          assists: 0,
                          steals: 0,
                          blocks: 0,
                          score: '109-112',
                          gameScore: 0.4,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SurfaceCard(
                    child: WnbaRecentGameList(
                      athleteName: 'Caitlin Clark',
                      games: [
                        WnbaGameLog(
                          gameId: '1',
                          athleteId: '1',
                          date: DateTime(2026, 7, 30),
                          team: 'Indiana Fever',
                          opponent: 'Chicago Sky',
                          teamScore: 88,
                          opponentScore: 80,
                          result: WnbaResult.win,
                          points: 24,
                          rebounds: 6,
                          assists: 9,
                          steals: 1,
                          blocks: 0,
                          minutes: 33,
                          headshotUrl: '',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SurfaceCard(
                    child: NflGameLogView(
                      log: _shotNflLog(
                        'espn_nfl_gamelog_allen.json',
                        'Josh Allen',
                        'QB',
                      ),
                      accent: const Color(0xFF8ED19C),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SurfaceCard(
                    child: NflGameLogView(
                      log: _shotNflLog(
                        'espn_nfl_gamelog_elliott.json',
                        'Jake Elliott',
                        'PK',
                      ),
                      accent: const Color(0xFF8ED19C),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await _settleUntil(tester, () => find.text('1 gól').evaluate().length >= 3);
  await _capture(tester, 'contributions_${brightness.name}_${accent.name}');
}
