// A shell asztali integrációja hamis szolgáltatásokkal: valódi ablak,
// tálcaikon, értesítés vagy rendszerleíró-bejegyzés soha nem jön létre.
import 'dart:io';

import 'package:courtboard/data/athlete_watcher.dart';
import 'package:courtboard/data/local_state.dart';
import 'package:courtboard/data/notification_settings.dart';
import 'package:courtboard/data/notifications.dart';
import 'package:courtboard/data/window_geometry.dart';
import 'package:courtboard/desktop/startup_registration.dart';
import 'package:courtboard/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_desktop.dart';

/// Az állapotot memóriában „menti” (nincs fájlírás a widget-tesztben).
class _RecordingStateStore extends LocalStateStore {
  _RecordingStateStore() : super(file: File('nem-irt-allapot.json'));

  CourtboardLocalState? last;
  int saves = 0;

  @override
  Future<void> save(CourtboardLocalState state) async {
    saves++;
    last = state;
  }
}

Future<void> _tapSetting(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void _desktopView(WidgetTester tester) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(1600, 1000);
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

void main() {
  late FakeNotificationService notifications;
  late FakeDesktopIntegration desktop;
  late MemoryStartupRegistration startup;
  late FakeWatcherSource source;
  late _RecordingStateStore store;

  setUp(() {
    notifications = FakeNotificationService();
    startup = MemoryStartupRegistration();
    desktop = FakeDesktopIntegration(startup: startup);
    source = FakeWatcherSource();
    store = _RecordingStateStore();
  });

  Future<void> pumpApp(
    WidgetTester tester, {
    CourtboardLocalState state = const CourtboardLocalState(),
  }) async {
    _desktopView(tester);
    await tester.pumpWidget(
      CourtboardApp(
        initialState: state,
        stateStore: store,
        desktop: desktop,
        notificationService: notifications,
        startupRegistration: startup,
        watcherSource: source,
        watcherMemoryStore: MemoryWatcherMemoryStore(),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Az app lebontása: a figyelő és a szünet időzítői leállnak.
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  }

  Future<void> openSettingsAt(WidgetTester tester, Key key) async {
    await _tapSetting(tester, find.byKey(const ValueKey('nav-Beállítások')));
    await tester.scrollUntilVisible(
      find.byKey(key),
      200,
      scrollable: find
          .descendant(
            of: find.byType(ListView).last,
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('csak az értesítésre jelölt sportolókat figyeli', (tester) async {
    await pumpApp(
      tester,
      state: const CourtboardLocalState(alerts: {'Nikola Jokić': true}),
    );
    // Az első futás késleltetett (45 mp), hogy ne az indulással versenyezzen.
    expect(source.calls, isEmpty);
    await tester.pump(const Duration(seconds: 46));
    await tester.pump();
    expect(source.calls, isNotEmpty);
    expect(
      source.calls.every((call) => call.endsWith(':Nikola Jokić')),
      isTrue,
    );

    // A profilon bekapcsolt értesítés a következő futásba már bekerül.
    await _tapSetting(
      tester,
      find.byKey(const ValueKey('athlete-Caitlin Clark')),
    );
    await _tapSetting(tester, find.text('Értesítés ki'));
    source.calls.clear();
    desktop.handlers.onRefreshNow!();
    await tester.pumpAndSettle();
    expect(source.calls, contains('results:Caitlin Clark'));
    expect(source.calls, contains('results:Nikola Jokić'));
    await unmount(tester);
  });

  testWidgets('értesítésre kattintva előjön az ablak és a profil nyílik', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(notifications.hasClickHandler, isTrue);
    notifications.click(
      const CourtboardNotification(
        id: 'result:x',
        kind: CourtboardNotificationKind.result,
        title: 'Új eredmény: Nikola Jokić',
        body: 'Győzelem',
        athleteName: 'Nikola Jokić',
      ),
    );
    await tester.pumpAndSettle();
    expect(desktop.log, contains('show'));
    expect(find.byKey(const Key('profile-hero')), findsOneWidget);

    // Több sportolót érintő hírösszesítő: a Hírek oldal nyílik.
    notifications.click(
      const CourtboardNotification(
        id: 'news:batch',
        kind: CourtboardNotificationKind.news,
        title: '3 új hír',
        body: '…',
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const Key('profile-hero')), findsNothing);
    await unmount(tester);
    expect(notifications.hasClickHandler, isFalse);
  });

  testWidgets('az Értesítések kártya ment és tesztértesítést küld', (
    tester,
  ) async {
    await pumpApp(tester);
    await openSettingsAt(tester, const Key('notification-test'));
    expect(find.text('Megjelenítés: Teszt-értesítés'), findsOneWidget);

    await _tapSetting(tester, find.byKey(const Key('notification-test')));
    expect(notifications.shown.single.kind, CourtboardNotificationKind.test);
    expect(find.text('Teszt értesítés elküldve.'), findsOneWidget);

    await _tapSetting(tester, find.text('60 perc'));
    expect(store.last!.notifications.intervalMinutes, 60);

    await _tapSetting(tester, find.byKey(const Key('notify-news-setting')));
    expect(store.last!.notifications.news, isFalse);

    await _tapSetting(tester, find.byKey(const Key('quiet-hours-setting')));
    expect(store.last!.notifications.quietHours, isTrue);
    expect(find.text('Kezdete: 23:00'), findsOneWidget);
    expect(find.text('Vége: 07:00'), findsOneWidget);

    // A fő kapcsoló kikapcsolása letiltja a típusokat.
    await _tapSetting(
      tester,
      find.byKey(const Key('notifications-enabled-setting')),
    );
    expect(store.last!.notifications.enabled, isFalse);
    final matchStart = tester.widget<SwitchListTile>(
      find.byKey(const Key('notify-match-start-setting')),
    );
    expect(matchStart.onChanged, isNull);
    await unmount(tester);
  });

  testWidgets('tálcamenü: szüneteltetés egy órára és folytatás', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(desktop.trayPaused, isFalse);
    desktop.handlers.onTogglePause!();
    await tester.pumpAndSettle();
    expect(desktop.trayPaused, isTrue);
    expect(store.last!.notificationsPausedUntil, isNotNull);

    await openSettingsAt(tester, const Key('notifications-resume'));
    expect(find.byKey(const Key('notifications-paused')), findsOneWidget);
    await _tapSetting(tester, find.byKey(const Key('notifications-resume')));
    expect(desktop.trayPaused, isFalse);
    expect(store.last!.notificationsPausedUntil, isNull);
    expect(find.byKey(const Key('notifications-paused')), findsNothing);
    await unmount(tester);
  });

  testWidgets('bezáráskor a tálcára: egyszeri tipp, majd SnackBar', (
    tester,
  ) async {
    await pumpApp(tester);
    await openSettingsAt(tester, const Key('close-to-tray-setting'));
    await _tapSetting(tester, find.byKey(const Key('close-to-tray-setting')));
    expect(desktop.closeToTray, isTrue);
    expect(store.last!.closeToTray, isTrue);

    await desktop.simulateClose();
    await tester.pump();
    expect(desktop.log, contains('hide'));
    expect(notifications.shown.single.id, 'tray-hint');
    expect(store.last!.closeToTrayHintShown, isTrue);

    await desktop.showWindow();
    await tester.pump();
    expect(find.textContaining('a tálcán futott tovább'), findsOneWidget);
    // Beúszás, a 4 mp-es megjelenítés, majd kiúszás.
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    // A második bezárásnál már nincs tipp.
    await desktop.simulateClose();
    await desktop.showWindow();
    await tester.pump();
    expect(notifications.shown, hasLength(1));
    expect(find.textContaining('a tálcán futott tovább'), findsNothing);
    await unmount(tester);
  });

  testWidgets('Indítás a Windows-zal és tálcára minimalizált indulás', (
    tester,
  ) async {
    await pumpApp(tester);
    await openSettingsAt(tester, const Key('start-minimized-setting'));
    final minimized = find.byKey(const Key('start-minimized-setting'));
    expect(tester.widget<SwitchListTile>(minimized).onChanged, isNull);

    await _tapSetting(
      tester,
      find.byKey(const Key('launch-at-startup-setting')),
    );
    expect(
      startup.command,
      startupCommand(
        MemoryStartupRegistration.executablePath,
        minimized: false,
      ),
    );

    await tester.tap(minimized);
    await tester.pumpAndSettle();
    expect(startup.command, contains(minimizedLaunchArgument));
    expect(store.last!.startMinimized, isTrue);

    await _tapSetting(
      tester,
      find.byKey(const Key('launch-at-startup-setting')),
    );
    expect(startup.command, isNull);
    await unmount(tester);
  });

  testWidgets('MSIX-telepítésnél a Windows-zal indítás letiltott', (
    tester,
  ) async {
    startup = MemoryStartupRegistration(supported: false);
    desktop = FakeDesktopIntegration(startup: startup, trayAvailable: false);
    await pumpApp(tester);
    await openSettingsAt(tester, const Key('start-minimized-setting'));
    for (final key in const [
      Key('launch-at-startup-setting'),
      Key('close-to-tray-setting'),
    ]) {
      expect(tester.widget<SwitchListTile>(find.byKey(key)).onChanged, isNull);
    }
    expect(find.text('Ezen a telepítésen nem érhető el.'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('kilépéskor az ablakhelyzet és az állapot mentődik', (
    tester,
  ) async {
    await pumpApp(
      tester,
      state: const CourtboardLocalState(
        notifications: NotificationSettings(intervalMinutes: 30),
      ),
    );
    const geometry = WindowGeometry(
      left: 120,
      top: 60,
      width: 1300,
      height: 820,
      maximized: true,
    );
    desktop.simulateGeometry(geometry);
    expect(store.last!.windowGeometry, geometry);
    final saves = store.saves;
    await desktop.quit();
    expect(store.saves, saves + 1);
    expect(store.last!.windowGeometry, geometry);
    expect(store.last!.notifications.intervalMinutes, 30);
    await unmount(tester);
  });

  testWidgets('asztali integráció nélkül a kapcsolók letiltottak', (
    tester,
  ) async {
    _desktopView(tester);
    await tester.pumpWidget(const CourtboardApp());
    await tester.pumpAndSettle();
    await openSettingsAt(tester, const Key('notification-test'));
    expect(
      tester
          .widget<ButtonStyleButton>(find.byKey(const Key('notification-test')))
          .onPressed,
      isNull,
    );
    await tester.ensureVisible(
      find.byKey(const Key('start-minimized-setting')),
    );
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Ezek a beállítások csak a telepített Windows-alkalmazásban '
        'érhetők el.',
      ),
      findsOneWidget,
    );
  });
}
