/// Az asztali integráció (tálca, ablak, Windows-indítás), az értesítések és
/// a háttérfigyelő összekötése az [AppController] állapotával.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:courtboard/app/activity_controller.dart';
import 'package:courtboard/app/app_controller.dart';
import 'package:courtboard/data/athlete_watcher.dart';
import 'package:courtboard/data/notifications.dart';
import 'package:courtboard/desktop/desktop_integration.dart';
import 'package:courtboard/desktop/startup_registration.dart';
import 'package:courtboard/domain/athlete_targets.dart';

class DesktopCoordinator extends ChangeNotifier {
  DesktopCoordinator({
    required this.app,
    required this.activity,
    required this.watcherSource,
    this.notifications,
    this.desktop,
    this.startupRegistration,
    this.watcherMemoryStore,
  });

  final AppController app;
  final ActivityController activity;

  /// Asztali értesítések; `null` esetén nincs háttérfigyelő.
  final NotificationService? notifications;

  /// Ablak, tálcaikon és bezárás kezelése; `null` esetén ezek kimaradnak.
  final DesktopIntegration? desktop;

  /// „Indítás a Windows-zal”; `null` esetén a kapcsoló letiltott.
  final StartupRegistration? startupRegistration;

  /// A háttérfigyelő adatforrása.
  final WatcherDataSource watcherSource;

  /// A háttérfigyelő emlékezete; `null` esetén a gyorsítótár.
  final WatcherMemoryStore? watcherMemoryStore;

  final StreamController<String> _messages = StreamController.broadcast();
  final StreamController<CourtboardNotification> _opened =
      StreamController.broadcast();

  /// Rövid üzenetek a felhasználónak (a shell SnackBarként mutatja).
  Stream<String> get messages => _messages.stream;

  /// Egy értesítésre kattintás (az ablak már előkerült): a shell a
  /// sportoló profilját vagy a Hírek oldalt nyitja meg.
  Stream<CourtboardNotification> get notificationOpened => _opened.stream;

  void showMessage(String message) {
    if (!_disposed) _messages.add(message);
  }

  /// A háttérfigyelő (csak ha van értesítési szolgáltatás).
  AthleteWatcher? _watcher;

  /// A Windows „Run” bejegyzésének állapota (induláskor kiolvasva).
  bool _launchAtStartup = false;

  /// Az első tálcára rejtés után a következő megjelenéskor SnackBar-tipp.
  bool _trayHintPending = false;
  bool? _trayMenuPaused;
  bool _disposed = false;

  bool get launchAtStartup => _launchAtStartup;

  /// Elérhető-e a Windows-zal indítás kapcsolója.
  bool get startupSupported {
    final startup = startupRegistration;
    return startup != null && startup.supported;
  }

  bool _started = false;

  /// Egyszer indul (a többszöri hívás hatástalan).
  void start() {
    if (_started) return;
    _started = true;
    final notifications = this.notifications;
    if (notifications != null) {
      notifications.onClick = _onNotificationClick;
      final watcher = AthleteWatcher(
        source: watcherSource,
        notifications: notifications,
        memoryStore: watcherMemoryStore,
      );
      _watcher = watcher;
      _syncWatcher();
      watcher.start();
    }
    final desktop = this.desktop;
    if (desktop != null) {
      desktop
        ..closeToTray = app.closeToTray
        ..attach(
          DesktopHandlers(
            onRefreshNow: () => unawaited(_runWatcherNow()),
            onTogglePause: app.toggleNotificationPause,
            onHiddenToTray: _hiddenToTray,
            onWindowShown: _windowShown,
            onGeometryChanged: app.setWindowGeometry,
            onBeforeQuit: _beforeQuit,
          ),
        );
      _trayMenuPaused = app.notificationsPaused;
      unawaited(
        desktop.updateTrayMenu(notificationsPaused: app.notificationsPaused),
      );
    }
    app.addListener(_appChanged);
    unawaited(_loadStartupState());
  }

  /// Minden állapotváltozás (értesítésjelölés, sportolólista, beállítások)
  /// eljut a háttérfigyelőhöz és a tálcához.
  void _appChanged() {
    _syncWatcher();
    final desktop = this.desktop;
    if (desktop == null) return;
    if (desktop.closeToTray != app.closeToTray) {
      desktop.closeToTray = app.closeToTray;
    }
    final paused = app.notificationsPaused;
    if (paused != _trayMenuPaused) {
      _trayMenuPaused = paused;
      unawaited(desktop.updateTrayMenu(notificationsPaused: paused));
    }
  }

  void _syncWatcher() => _watcher?.update(
    athletes: calendarTargets(app.alertAthletes),
    settings: app.notificationSettings,
    pausedUntil: app.notificationsPausedUntil,
    clearPause: app.notificationsPausedUntil == null,
  );

  /// Tálcamenü „Frissítés most”: azonnali figyelőfutás (a források
  /// gyorsítótára érvényes), utána a kiemelések újraolvasása.
  Future<void> _runWatcherNow() async {
    await _watcher?.run();
    if (!_disposed) await activity.loadHighlights();
  }

  /// Az első tálcára rejtéskor egyszeri tipp (értesítés, és a következő
  /// megjelenéskor SnackBar).
  void _hiddenToTray() {
    if (app.closeToTrayHintShown) return;
    app.markCloseToTrayHintShown();
    _trayHintPending = true;
    unawaited(
      notifications?.show(
        const CourtboardNotification(
          id: 'tray-hint',
          kind: CourtboardNotificationKind.info,
          title: 'A Courtboard a tálcán fut tovább',
          body:
              'Kattints a tálcaikonra a megnyitáshoz; kilépés a tálcaikon '
              'menüjéből.',
        ),
      ),
    );
  }

  void _windowShown() {
    if (!_trayHintPending) return;
    _trayHintPending = false;
    showMessage(
      'A Courtboard a tálcán futott tovább. Kilépés: tálcaikon → Kilépés '
      '(Beállítások → Tálca és indítás).',
    );
  }

  Future<void> _beforeQuit() async {
    _watcher?.stop();
    await app.flush();
  }

  /// Értesítésre kattintva: ablak előhozása, majd a megfelelő oldal.
  void _onNotificationClick(CourtboardNotification notification) {
    unawaited(desktop?.showWindow());
    if (_disposed) return;
    _opened.add(notification);
  }

  Future<void> _loadStartupState() async {
    final startup = startupRegistration;
    if (startup == null || !startup.supported) return;
    final enabled = await startup.isEnabled();
    if (_disposed) return;
    _launchAtStartup = enabled;
    notifyListeners();
  }

  Future<void> setLaunchAtStartup(bool value) async {
    final startup = startupRegistration;
    if (startup == null) return;
    try {
      await startup.setEnabled(value, minimized: app.startMinimized);
    } catch (_) {
      if (!_disposed) {
        showMessage('Az automatikus indítás beállítása nem sikerült.');
      }
    }
    final enabled = await startup.isEnabled();
    if (_disposed) return;
    _launchAtStartup = enabled;
    notifyListeners();
  }

  Future<void> setStartMinimized(bool value) async {
    app.setStartMinimized(value);
    final startup = startupRegistration;
    if (startup == null || !_launchAtStartup) return;
    try {
      await startup.setEnabled(true, minimized: value);
    } catch (_) {
      if (!_disposed) {
        showMessage('Az automatikus indítás beállítása nem sikerült.');
      }
    }
  }

  Future<bool> sendTestNotification() async {
    final service = notifications;
    if (service == null) return false;
    return service.show(
      const CourtboardNotification(
        id: 'test',
        kind: CourtboardNotificationKind.test,
        title: 'Courtboard – teszt értesítés',
        body:
            'Az értesítések működnek. Így jelez a Courtboard meccskezdéskor, '
            'új eredménynél és új hírnél.',
      ),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    app.removeListener(_appChanged);
    _watcher?.dispose();
    notifications?.onClick = null;
    desktop?.attach(const DesktopHandlers());
    unawaited(_messages.close());
    unawaited(_opened.close());
    super.dispose();
  }
}
