import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:courtboard/common_ui.dart';
import 'package:courtboard/components.dart';
import 'package:courtboard/data/local_state.dart';
import 'package:courtboard/format.dart';
import 'package:courtboard/main.dart';
import 'package:courtboard/theme/courtboard_theme.dart';

String _name(CourtboardColors c) =>
    '${c.brightness.name}/${c == CourtboardColors.lightGreen || c == CourtboardColors.darkGreen ? 'green' : 'burgundy'}';

Widget _themed(Widget child, {Brightness brightness = Brightness.light}) =>
    MaterialApp(
      theme: buildCourtboardTheme(CourtboardAccent.green, brightness),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

void main() {
  group('színtokenek kontrasztja (WCAG AA)', () {
    for (final c in CourtboardColors.all) {
      test('${_name(c)}: szöveg- és eredményszínek ≥ 4,5:1', () {
        for (final (label, fg) in [
          ('textPrimary', c.textPrimary),
          ('textMuted', c.textMuted),
          ('win', c.win),
          ('loss', c.loss),
          ('draw', c.draw),
          ('warning', c.warning),
          ('error', c.error),
          ('live', c.live),
          ('accent', c.accent),
        ]) {
          for (final (bgLabel, bg) in [
            ('surface', c.surface),
            ('canvas', c.canvas),
            ('surfaceMuted', c.surfaceMuted),
          ]) {
            expect(
              contrastRatio(fg, bg),
              greaterThanOrEqualTo(4.5),
              reason: '$label on $bgLabel',
            );
          }
        }
      });

      test('${_name(c)}: kitöltött felületek előtérszíne ≥ 4,5:1', () {
        expect(contrastRatio(c.onAccent, c.accent), greaterThanOrEqualTo(4.5));
        expect(
          contrastRatio(c.onHighlight, c.highlight),
          greaterThanOrEqualTo(4.5),
        );
        expect(contrastRatio(c.onInk, c.ink), greaterThanOrEqualTo(4.5));
        expect(contrastRatio(c.onInkMuted, c.ink), greaterThanOrEqualTo(4.5));
        expect(contrastRatio(c.highlight, c.ink), greaterThanOrEqualTo(4.5));
        expect(
          contrastRatio(c.textPrimary, c.accentSoft),
          greaterThanOrEqualTo(4.5),
        );
      });

      test('${_name(c)}: eredményjelvény a saját tónusán is olvasható', () {
        for (final color in [c.win, c.loss, c.draw]) {
          final badge = Color.alphaBlend(
            color.withValues(alpha: .14),
            c.surface,
          );
          expect(contrastRatio(color, badge), greaterThanOrEqualTo(4.5));
        }
      });
    }

    test('a bordó téma nem tartalmaz zöld kiemelést', () {
      for (final brightness in Brightness.values) {
        final theme = buildCourtboardTheme(
          CourtboardAccent.burgundy,
          brightness,
        );
        final scheme = theme.colorScheme;
        final c = theme.extension<CourtboardColors>()!;
        for (final color in [
          scheme.primary,
          scheme.secondary,
          c.accent,
          c.highlight,
          c.accentSoft,
        ]) {
          final hue = HSLColor.fromColor(color).hue;
          // A zöld árnyalattartomány (kb. 60–180°) kizárva.
          expect(hue < 60 || hue > 180, isTrue, reason: '$color');
        }
      }
    });

    test('a ColorScheme előtérszínei kifejezetten be vannak állítva', () {
      for (final accent in CourtboardAccent.values) {
        for (final brightness in Brightness.values) {
          final scheme = buildCourtboardTheme(accent, brightness).colorScheme;
          expect(
            contrastRatio(scheme.onPrimary, scheme.primary),
            greaterThanOrEqualTo(4.5),
          );
          expect(
            contrastRatio(scheme.onSecondary, scheme.secondary),
            greaterThanOrEqualTo(4.5),
          );
        }
      }
    });

    test('readableOn a sportolói pasztellszínt olvashatóvá sötétíti', () {
      const pastel = Color(0xFFE9B86E);
      final surface = CourtboardColors.lightGreen.surface;
      expect(contrastRatio(pastel, surface), lessThan(4.5));
      final readable = readableOn(pastel, surface);
      expect(contrastRatio(readable, surface), greaterThanOrEqualTo(4.5));
      // Az árnyalat megmarad.
      expect(
        (HSLColor.fromColor(readable).hue - HSLColor.fromColor(pastel).hue)
            .abs(),
        lessThan(2),
      );
      // Sötét felületen a pasztell már eleve olvasható.
      expect(readableOn(pastel, CourtboardColors.darkGreen.surface), pastel);
    });

    test('foregroundOn az olvashatóbb előtérszínt választja', () {
      expect(foregroundOn(const Color(0xFFE9B86E)), const Color(0xFF151815));
      expect(foregroundOn(const Color(0xFF7A263A)), Colors.white);
    });
  });

  group('magyar formázás', () {
    test('számok', () {
      expect(formatDecimal(26.8), '26,8');
      expect(formatDecimal(3), '3,0');
      expect(formatDecimal(7.456, digits: 2), '7,46');
      expect(formatDecimal(null), '—');
      expect(formatInt(2005), '2 005');
      expect(formatInt(1234567), '1 234 567');
      expect(formatInt(42), '42');
      expect(formatPercent(45.2), '45,2%');
      expect(formatPercent(null), '—');
      expect(localizeNumberText('21.5'), '21,5');
      expect(localizeNumberText('55.1%'), '55,1%');
      expect(localizeNumberText('8000'), '8 000');
      expect(localizeNumberText('6-4'), '6-4');
    });

    test('dátumok', () {
      final date = DateTime(2026, 1, 18, 17, 5);
      expect(formatDate(date), '2026. 01. 18.');
      expect(formatShortDate(date), 'jan. 18.');
      expect(formatShortDate(DateTime(2026, 9, 3)), 'szept. 3.');
      expect(formatTime(date), '17:05');
      expect(formatDateTime(date), '2026. 01. 18. 17:05');
      expect(formatDateText('1995-02-11'), '1995. 02. 11.');
      expect(formatDateText('ismeretlen'), 'ismeretlen');
    });

    test('frissességi felirat', () {
      final now = DateTime(2026, 9, 30, 15);
      expect(
        freshnessLabel(DateTime(2026, 9, 30, 14, 32), now: now),
        'Frissítve: 14:32',
      );
      expect(
        freshnessLabel(
          DateTime(2026, 9, 28, 14, 32),
          fromCache: true,
          now: now,
        ),
        'Frissítve: szept. 28. 14:32 · gyorsítótárból',
      );
    });
  });

  group('megjelenési mód', () {
    test('a themeMode visszafelé kompatibilisen kerül a JSON-ba', () {
      const state = CourtboardLocalState(themeMode: 'dark');
      expect(CourtboardLocalState.fromJson(state.toJson()).themeMode, 'dark');
      // 0.10.0 előtti állapotfájl: nincs themeMode mező.
      expect(
        CourtboardLocalState.fromJson(const {'theme': 'burgundy'}).themeMode,
        'system',
      );
      expect(
        CourtboardLocalState.fromJson(const {'themeMode': 'neon'}).themeMode,
        'system',
      );
      expect(themeModeFromStorage('light'), ThemeMode.light);
      expect(themeModeFromStorage('dark'), ThemeMode.dark);
      expect(themeModeFromStorage('system'), ThemeMode.system);
    });

    testWidgets('a Beállításokban választott sötét mód érvényes és mentődik', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1440, 900);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final directory = Directory.systemTemp.createTempSync('courtboard-tm-');
      addTearDown(() => directory.deleteSync(recursive: true));
      final store = LocalStateStore(
        file: File('${directory.path}/courtboard_state.json'),
      );

      await tester.pumpWidget(CourtboardApp(stateStore: store));
      await tester.pumpAndSettle();
      // Az alapértelmezett 800×600-as tesztfelületen a kompakt (csak
      // ikonos) oldalsáv látszik, ezért a menüpontot kulccsal érjük el.
      await tester.tap(find.byKey(const ValueKey('nav-Beállítások')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('theme-mode-setting')), findsOneWidget);
      expect(find.text('Rendszer'), findsOneWidget);
      expect(find.text('Világos'), findsOneWidget);
      await tester.tap(find.text('Sötét'));
      await tester.pumpAndSettle();

      final context = tester.element(find.text('Megjelenés'));
      expect(Theme.of(context).brightness, Brightness.dark);
      expect(
        Theme.of(context).scaffoldBackgroundColor,
        CourtboardColors.darkGreen.canvas,
      );
      // A mentés valódi fájlművelet: rövid valós várakozás, majd a fájl
      // közvetlen visszaolvasása.
      final file = File('${directory.path}/courtboard_state.json');
      for (var i = 0; i < 20 && !file.existsSync(); i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
      }
      final saved = CourtboardLocalState.fromJson(
        jsonDecode(file.readAsStringSync()) as Map<String, dynamic>,
      );
      expect(saved.themeMode, 'dark');
    });

    testWidgets('a mentett világos mód a sötét rendszertémát felülírja', (
      tester,
    ) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await tester.pumpWidget(
        const CourtboardApp(
          initialState: CourtboardLocalState(themeMode: 'light'),
        ),
      );
      await tester.pumpAndSettle();
      final context = tester.element(
        find.byKey(const ValueKey('nav-Áttekintés')),
      );
      expect(Theme.of(context).brightness, Brightness.light);
    });

    testWidgets('rendszer módban a sötét rendszertéma érvényes', (
      tester,
    ) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await tester.pumpWidget(const CourtboardApp());
      await tester.pumpAndSettle();
      final context = tester.element(
        find.byKey(const ValueKey('nav-Áttekintés')),
      );
      expect(Theme.of(context).brightness, Brightness.dark);
      // A Material feliratok magyarul jelennek meg.
      expect(Localizations.localeOf(context), const Locale('hu'));
    });
  });

  group('DataSourceCard', () {
    testWidgets('betöltés közben helyőrzőt mutat', (tester) async {
      final completer = Completer<String>();
      await tester.pumpWidget(
        _themed(
          DataSourceCard<String>(
            title: 'Teszt kártya',
            provider: 'Teszt API',
            loadingLabel: 'Tesztadat betöltése…',
            load: ({required force}) => completer.future,
            builder: (context, data) => Text(data),
          ),
        ),
      );
      expect(find.text('Teszt kártya'), findsOneWidget);
      expect(find.text('TESZT API'), findsOneWidget);
      expect(find.text('Tesztadat betöltése…'), findsOneWidget);
      expect(find.byType(CardSkeleton), findsOneWidget);
      expect(find.byTooltip('Adatok frissítése (Ctrl+R)'), findsOneWidget);

      completer.complete('kész');
      await tester.pump();
      expect(find.byType(CardSkeleton), findsNothing);
      expect(find.text('kész'), findsOneWidget);
    });

    testWidgets('hibánál barátságos üzenet és működő újrapróbálás', (
      tester,
    ) async {
      var calls = 0;
      final forces = <bool>[];
      await tester.pumpWidget(
        _themed(
          DataSourceCard<String>(
            title: 'Teszt kártya',
            errorPrefix: 'A teszt most nem érhető el. ',
            load: ({required force}) async {
              forces.add(force);
              calls++;
              if (calls == 1) throw const SocketException('offline');
              return 'második próbálkozás';
            },
            builder: (context, data) => Text(data),
          ),
        ),
      );
      await tester.pump();
      expect(
        find.text('A teszt most nem érhető el. Nincs internetkapcsolat.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Újrapróbálás'));
      await tester.pump();
      await tester.pump();
      expect(find.text('második próbálkozás'), findsOneWidget);
      expect(forces, [false, true]);
    });

    testWidgets('üres adatnál ikonos magyar üres állapot', (tester) async {
      await tester.pumpWidget(
        _themed(
          DataSourceCard<List<int>>(
            title: 'Teszt kártya',
            emptyMessage: 'Nincs még mérkőzés.',
            emptyIcon: Icons.event_busy_outlined,
            isEmpty: (data) => data.isEmpty,
            load: ({required force}) async => const [],
            builder: (context, data) => Text('${data.length} elem'),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Nincs még mérkőzés.'), findsOneWidget);
      expect(find.byIcon(Icons.event_busy_outlined), findsOneWidget);
      expect(find.textContaining('elem'), findsNothing);
    });

    testWidgets('adatnál tartalom és frissességi sor', (tester) async {
      final fetched = DateTime.now().subtract(const Duration(minutes: 5));
      await tester.pumpWidget(
        _themed(
          DataSourceCard<List<int>>(
            title: 'Teszt kártya',
            isEmpty: (data) => data.isEmpty,
            freshness: (_) => DataFreshness(fetched, fromCache: true),
            load: ({required force}) async => const [1, 2, 3],
            builder: (context, data) => Text('${data.length} elem'),
          ),
          brightness: Brightness.dark,
        ),
      );
      await tester.pump();
      expect(find.text('3 elem'), findsOneWidget);
      expect(
        find.text('Frissítve: ${formatTime(fetched)} · gyorsítótárból'),
        findsOneWidget,
      );
    });

    testWidgets('helyőrző esetén nem tölt és a frissítés tiltott', (
      tester,
    ) async {
      var called = false;
      await tester.pumpWidget(
        _themed(
          DataSourceCard<String>(
            title: 'Teszt kártya',
            placeholder: const Text('Nincs kulcs'),
            load: ({required force}) async {
              called = true;
              return 'x';
            },
            builder: (context, data) => Text(data),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Nincs kulcs'), findsOneWidget);
      expect(called, isFalse);
      final refresh = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.refresh_rounded),
      );
      expect(refresh.onPressed, isNull);
    });
  });

  group('közös komponensek', () {
    testWidgets('MatchRow egységes eredményjelvénnyel', (tester) async {
      await tester.pumpWidget(
        _themed(
          Column(
            children: [
              MatchRow(
                date: DateTime(DateTime.now().year, 1, 18),
                venue: 'Hazai',
                opponent: 'Denver Nuggets',
                score: '110-102',
                outcome: MatchOutcome.win,
              ),
              MatchRow(
                date: DateTime(DateTime.now().year, 1, 20),
                opponent: 'Phoenix Suns',
                outcome: MatchOutcome.parse('LOSS'),
              ),
              const MatchRow(
                opponent: 'Real Madrid',
                dateLabel: 'Időpont később',
                outcome: MatchOutcome.draw,
              ),
            ],
          ),
        ),
      );
      expect(find.text('jan. 18.'), findsOneWidget);
      expect(find.text('HAZAI'), findsOneWidget);
      expect(find.text('110–102'), findsOneWidget);
      expect(find.text('GY'), findsOneWidget);
      expect(find.text('V'), findsOneWidget);
      expect(find.text('D'), findsOneWidget);
      expect(find.text('Időpont később'), findsOneWidget);
      expect(find.byTooltip('Vereség'), findsOneWidget);
    });

    testWidgets('MetricTile: címke felül, érték alatta', (tester) async {
      await tester.pumpWidget(
        _themed(
          const SizedBox(
            width: 200,
            child: MetricTile(label: 'Pont / meccs', value: '26,8'),
          ),
        ),
      );
      final label = tester.getTopLeft(find.text('PONT / MECCS'));
      final value = tester.getTopLeft(find.text('26,8'));
      expect(label.dy, lessThan(value.dy));
      final style = tester.widget<Text>(find.text('PONT / MECCS')).style!;
      expect(style.fontSize, greaterThanOrEqualTo(11));
    });

    testWidgets('ProviderChip állapot szerint színeződik', (tester) async {
      await tester.pumpWidget(
        _themed(
          const Wrap(
            children: [
              ProviderChip(name: 'A', status: ProviderStatus.ready),
              ProviderChip(name: 'B', status: ProviderStatus.failed),
              ProviderChip(name: 'C', status: ProviderStatus.missingKey),
            ],
          ),
        ),
      );
      const c = CourtboardColors.lightGreen;
      Icon icon(IconData data) => tester.widget<Icon>(find.byIcon(data));
      expect(icon(Icons.check_circle).color, c.win);
      expect(icon(Icons.error_outline).color, c.error);
      expect(icon(Icons.key_off).color, c.warning);
    });
  });
}
