import 'package:courtboard/domain/sport.dart';
import 'package:courtboard/data/athlete_highlights.dart';
import 'package:courtboard/data/json_file_cache.dart';
import 'package:courtboard/data/local_state.dart';
import 'package:courtboard/data/upcoming_events.dart';
import 'package:courtboard/data/update_checker.dart';
import 'package:courtboard/app/courtboard_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_http.dart';

void _desktopView(WidgetTester tester) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(1440, 900);
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

const _jokic = UpcomingEventsTarget(
  name: 'Nikola Jokić',
  sport: Sport.nba,
  team: 'Denver Nuggets',
);
const _barkley = UpcomingEventsTarget(
  name: 'Saquon Barkley',
  sport: Sport.nfl,
  team: 'Philadelphia Eagles',
);

UpcomingEvent _event(
  UpcomingEventsTarget target,
  DateTime start,
  String opponent, {
  String homeAway = 'home',
}) => UpcomingEvent(
  athleteName: target.name,
  sport: target.sport.jsonValue,
  title: '${target.team} – $opponent',
  opponent: opponent,
  competition: '${target.sport} · Alapszakasz',
  start: start,
  venue: 'Aréna',
  homeAway: homeAway,
  source: 'ESPN',
  url: 'https://www.espn.com/game/1',
);

Future<void> _openCalendar(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('nav-Naptár')));
  await tester.pumpAndSettle();
}

void main() {
  // Minden teszt tiszta, memóriabeli gyorsítótárral indul (a naptár és a
  // kiemelések bejegyzései nem szivárognak át).
  setUp(() => CacheStorage.shared = MemoryCacheStorage());

  testWidgets('a naptár napok szerint csoportosít, szűr és exportálhat', (
    tester,
  ) async {
    _desktopView(tester);
    final now = DateTime.now();
    final soon = now.add(const Duration(hours: 1));
    final later = DateTime(now.year, now.month, now.day + 3, 19, 30);
    final repository = UpcomingEventsRepository();
    await repository.seed(_jokic, [
      _event(_jokic, soon, 'Utah Jazz'),
      _event(_jokic, later, 'Phoenix Suns', homeAway: 'away'),
    ]);
    await repository.seed(_barkley, [
      _event(_barkley, later.add(const Duration(hours: 1)), 'Dallas Cowboys'),
    ]);

    await tester.pumpWidget(const CourtboardApp());
    await tester.pumpAndSettle();
    await _openCalendar(tester);

    expect(find.byKey(const Key('calendar-event-list')), findsOneWidget);
    expect(find.text(calendarDayLabel(soon, now)), findsOneWidget);
    expect(find.text(calendarDayLabel(later, now)), findsOneWidget);
    expect(find.text('vs. Utah Jazz'), findsOneWidget);
    expect(find.text('@ Phoenix Suns'), findsOneWidget);
    expect(find.text('vs. Dallas Cowboys'), findsOneWidget);
    expect(find.text('Nikola Jokić · NBA'), findsNWidgets(2));
    expect(find.byKey(const Key('calendar-add-to-calendar')), findsNWidgets(3));
    expect(find.text('Hozzáadás a naptárhoz'), findsNWidgets(3));
    final export = tester.widget<ButtonStyleButton>(
      find.byKey(const Key('calendar-export-all')),
    );
    expect(export.onPressed, isNotNull);
    // A többi (nem előre betöltött) sportoló hibája apró megjegyzés.
    expect(find.byKey(const Key('calendar-notes')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('calendar-sport-NFL')));
    await tester.pumpAndSettle();
    expect(find.text('vs. Dallas Cowboys'), findsOneWidget);
    expect(find.text('vs. Utah Jazz'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('calendar-sport-Darts')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('calendar-empty-state')), findsOneWidget);
    expect(find.text('Nincs a szűrésnek megfelelő esemény.'), findsOneWidget);
    expect(find.textContaining('Luke Humphries:'), findsWidgets);

    // A legközelebbi esemény a „Mai fókusz” kiemelésébe is bekerült.
    final highlight = await AthleteHighlightStore.shared.read('Nikola Jokić');
    expect(highlight?.upcoming(now)?.title, 'vs. Utah Jazz');
  });

  testWidgets('sportolószűrő a legördülő listából', (tester) async {
    _desktopView(tester);
    final start = DateTime.now().add(const Duration(days: 1));
    final repository = UpcomingEventsRepository();
    await repository.seed(_jokic, [_event(_jokic, start, 'Utah Jazz')]);
    await repository.seed(_barkley, [
      _event(_barkley, start, 'Dallas Cowboys'),
    ]);

    await tester.pumpWidget(const CourtboardApp());
    await tester.pumpAndSettle();
    await _openCalendar(tester);
    expect(find.text('vs. Dallas Cowboys'), findsOneWidget);

    await tester.tap(find.byKey(const Key('calendar-athlete-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nikola Jokić').last);
    await tester.pumpAndSettle();
    expect(find.text('vs. Utah Jazz'), findsOneWidget);
    expect(find.text('vs. Dallas Cowboys'), findsNothing);
  });

  for (final (size, scale) in const [
    (Size(800, 600), 1.3),
    (Size(720, 800), 1.0),
  ]) {
    testWidgets('a naptár sorai nem csordulnak túl: ${size.width.toInt()}×'
        '${size.height.toInt()}, ${scale}x', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });
      final start = DateTime.now().add(const Duration(days: 2));
      await UpcomingEventsRepository().seed(_jokic, [
        _event(
          _jokic,
          start,
          'Nagyon hosszú nevű ellenfél csapat a nyugati főcsoportból',
        ),
        UpcomingEvent(
          athleteName: _jokic.name,
          sport: 'NBA',
          title: 'Denver Nuggets – Utah Jazz',
          opponent: 'Utah Jazz',
          start: start.add(const Duration(hours: 3)),
          source: 'ESPN',
          timeKnown: false,
        ),
      ]);

      await tester.pumpWidget(const CourtboardApp());
      await tester.pumpAndSettle();
      final menu = find.byKey(const Key('open-navigation-drawer'));
      if (menu.evaluate().isNotEmpty) {
        await tester.tap(menu);
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byKey(const ValueKey('nav-Naptár')).last);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('calendar-event-list')), findsOneWidget);
      expect(find.text('később'), findsOneWidget);
      // Keskeny helyen a „Hozzáadás a naptárhoz” ikongomb, eszköztippel.
      expect(find.byTooltip('Hozzáadás a naptárhoz'), findsNWidgets(2));
    });
  }

  group('frissítés-ellenőrzés a felületen', () {
    const path = '/repos/mp3pintyo/Courtboard/releases/latest';

    UpdateChecker checker(FakeHttpService http) => UpdateChecker(
      currentVersion: '0.11.0',
      http: http,
      cacheStorage: MemoryCacheStorage(),
    );

    testWidgets('újabb kiadásnál sáv jelenik meg, elrejthető', (tester) async {
      _desktopView(tester);
      final http = FakeHttpService({
        path: fixture('github_release_latest.json'),
      });
      await tester.pumpWidget(
        CourtboardApp(appVersion: '0.11.0', updateChecker: checker(http)),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('update-banner')), findsOneWidget);
      expect(find.text('Új verzió érhető el: 0.12.0'), findsOneWidget);
      expect(find.text('Letöltés'), findsOneWidget);

      await tester.tap(find.byKey(const Key('update-banner-dismiss')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('update-banner')), findsNothing);
    });

    testWidgets('a Beállítások „Keresés most” gombja eredményt mutat', (
      tester,
    ) async {
      _desktopView(tester);
      final http = FakeHttpService({
        path: fixture('github_release_latest.json')..['tag_name'] = 'v0.11.0',
      });
      await tester.pumpWidget(
        CourtboardApp(
          appVersion: '0.11.0',
          updateChecker: checker(http),
          initialState: const CourtboardLocalState(autoUpdateCheck: false),
        ),
      );
      await tester.pumpAndSettle();
      // Kikapcsolt automatikus ellenőrzésnél indításkor nincs kérés.
      expect(http.requests, isEmpty);
      expect(find.byKey(const Key('update-banner')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('nav-Beállítások')));
      await tester.pumpAndSettle();
      final button = find.byKey(const Key('update-check-now'));
      await tester.scrollUntilVisible(
        button,
        200,
        scrollable: find
            .descendant(
              of: find.byType(ListView).last,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      expect(find.text('Jelenlegi verzió: 0.11.0'), findsOneWidget);
      final toggle = tester.widget<SwitchListTile>(
        find.byKey(const Key('auto-update-check-setting')),
      );
      expect(toggle.value, isFalse);

      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(http.requests, hasLength(1));
      expect(find.byKey(const Key('update-result')), findsOneWidget);
      expect(find.textContaining('naprakész'), findsOneWidget);
    });

    testWidgets('verzió nélkül a Frissítések kártya jelzi, hogy nem elérhető', (
      tester,
    ) async {
      _desktopView(tester);
      await tester.pumpWidget(const CourtboardApp());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('nav-Beállítások')));
      await tester.pumpAndSettle();
      final button = find.byKey(const Key('update-check-now'));
      await tester.scrollUntilVisible(
        button,
        200,
        scrollable: find
            .descendant(
              of: find.byType(ListView).last,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      expect(find.text('Jelenlegi verzió: ismeretlen'), findsOneWidget);
      expect(tester.widget<ButtonStyleButton>(button).onPressed, isNull);
    });
  });
}
