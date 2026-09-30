import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../data/window_geometry.dart';
import 'startup_registration.dart';
import 'win32_window_placement.dart';

/// A shell felől érkező műveletek, amelyekre az asztali integráció
/// (tálcamenü, ablakbezárás) támaszkodik.
class DesktopHandlers {
  const DesktopHandlers({
    this.onRefreshNow,
    this.onTogglePause,
    this.onHiddenToTray,
    this.onWindowShown,
    this.onGeometryChanged,
    this.onBeforeQuit,
  });

  /// Tálcamenü: „Frissítés most”.
  final VoidCallback? onRefreshNow;

  /// Tálcamenü: „Értesítések szüneteltetése 1 órára” / „folytatása”.
  final VoidCallback? onTogglePause;

  /// Az ablak bezáráskor a tálcára került.
  final VoidCallback? onHiddenToTray;

  /// Az ablak a tálcáról / kicsinyített állapotból előkerült.
  final VoidCallback? onWindowShown;

  /// Az ablak helyzete / mérete / teljes méretű állapota megváltozott.
  final ValueChanged<WindowGeometry>? onGeometryChanged;

  /// Kilépés előtt: a shell itt menti az állapotát (megvárjuk).
  final Future<void> Function()? onBeforeQuit;
}

/// Az ablak, a tálcaikon és a Windows-zal indítás egységes felülete.
/// A tesztek hamis megvalósítást használnak (`test/support/fake_desktop.dart`);
/// widget-tesztben (`null`) a shell egyszerűen kihagyja ezeket.
abstract class DesktopIntegration {
  /// Igaz, ha a tálcaikon létrejött (a tálcára rejtés csak ekkor lehetséges).
  bool get trayAvailable;

  /// Igaz, ha az app `--minimized` kapcsolóval, ablak nélkül indult.
  bool get startedHidden;

  /// „Indítás a Windows-zal” bejegyzés kezelője.
  StartupRegistration get startup;

  /// A főablak natív azonosítója (HWND), ha ismert.
  int? get windowHandle;

  /// Bezáráskor a tálcára kicsinyítés.
  bool get closeToTray;
  set closeToTray(bool value);

  /// A shell műveleteinek bekötése.
  void attach(DesktopHandlers handlers);

  /// Az első képkocka után: az ablak megjelenítése a mentett helyen
  /// (tálcára indításnál rejtve marad).
  Future<void> revealInitialWindow();

  /// Az ablak előhozása (tálcáról, kicsinyített állapotból is).
  Future<void> showWindow();

  /// Az ablak elrejtése a tálcára.
  Future<void> hideToTray();

  /// A tálcamenü frissítése (a szüneteltetés feliratához).
  Future<void> updateTrayMenu({required bool notificationsPaused});

  /// Kilépés: állapotmentés, tálcaikon törlése, folyamat vége.
  Future<void> quit();

  void dispose();
}

/// Windows-megvalósítás: `window_manager` (bezárás megakadályozása,
/// megjelenítés, események), `tray_manager` (tálcaikon és menü) és
/// közvetlen Win32-hívások (pontos ablakhelyzet, lásd
/// [Win32WindowPlacement]).
///
/// A futtató (`windows/runner/flutter_window.cpp`) az első képkockánál már
/// nem jeleníti meg az ablakot: a Dart oldal előbb a mentett helyre teszi,
/// és csak utána mutatja (nincs villanás). Ha ez 4 mp-en belül nem történik
/// meg (például hiba miatt), a futtató tartalékként maga jeleníti meg –
/// kivéve `--minimized` indításnál.
class WindowsDesktopIntegration extends DesktopIntegration
    with WindowListener, TrayListener {
  WindowsDesktopIntegration._({
    required this.startedHidden,
    required this.startup,
    required int handle,
    required this._restored,
  }) : windowHandle = handle,
       _placement = Win32WindowPlacement(handle);

  /// A tálcaikon (a futtató ikonjának másolata az asset-ek között).
  static const trayIconAsset = 'assets/tray/app_icon.ico';

  @override
  final bool startedHidden;

  @override
  final StartupRegistration startup;

  @override
  final int windowHandle;

  final Win32WindowPlacement _placement;

  /// A visszaállított (monitorhoz igazított) mentett helyzet.
  final WindowGeometry? _restored;

  bool _trayAvailable = false;
  bool _closeToTray = false;
  bool _revealed = false;
  bool _quitting = false;
  bool _paused = false;
  DesktopHandlers _handlers = const DesktopHandlers();
  Timer? _geometryDebounce;
  WindowGeometry? _lastGeometry;

  /// Inicializálás a `runApp` előtt: a mentett helyzet ellenőrzése és
  /// beállítása a még rejtett ablakon, bezárás-megakadályozás, tálcaikon.
  /// Hibánál `null`; ilyenkor a futtató tartalékja jeleníti meg az ablakot.
  static Future<WindowsDesktopIntegration?> initialize({
    required WindowGeometry? savedGeometry,
    required bool startHidden,
    required bool closeToTray,
    StartupRegistration? startup,
  }) async {
    try {
      await windowManager.ensureInitialized();
      final handle = await windowManager.getId();
      final placement = Win32WindowPlacement(handle);
      final fitted = fitWindowGeometry(savedGeometry, placement.workAreaFor);
      if (fitted != null) placement.applyHidden(fitted);
      final integration = WindowsDesktopIntegration._(
        startedHidden: startHidden,
        startup: startup ?? RegistryStartupRegistration(),
        handle: handle,
        restored: fitted,
      );
      integration._closeToTray = closeToTray;
      integration._lastGeometry = fitted;
      await windowManager.setPreventClose(true);
      windowManager.addListener(integration);
      await integration._initTray();
      return integration;
    } catch (error) {
      debugPrint('Courtboard: asztali integráció nem indult: $error');
      return null;
    }
  }

  Future<void> _initTray() async {
    try {
      await trayManager.setIcon(trayIconAsset);
      await trayManager.setToolTip('Courtboard');
      await _setMenu();
      trayManager.addListener(this);
      _trayAvailable = true;
    } catch (error) {
      debugPrint('Courtboard: a tálcaikon nem hozható létre: $error');
      _trayAvailable = false;
    }
  }

  Future<void> _setMenu() => trayManager.setContextMenu(
    Menu(
      items: [
        MenuItem(key: 'open', label: 'Megnyitás'),
        MenuItem(key: 'refresh', label: 'Frissítés most'),
        MenuItem(
          key: 'pause',
          label: _paused
              ? 'Értesítések folytatása'
              : 'Értesítések szüneteltetése 1 órára',
        ),
        MenuItem.separator(),
        MenuItem(key: 'quit', label: 'Kilépés'),
      ],
    ),
  );

  @override
  bool get trayAvailable => _trayAvailable;

  @override
  bool get closeToTray => _closeToTray;

  @override
  set closeToTray(bool value) => _closeToTray = value;

  @override
  void attach(DesktopHandlers handlers) => _handlers = handlers;

  @override
  Future<void> revealInitialWindow() async {
    if (_revealed) return;
    if (startedHidden && _trayAvailable) return;
    _reveal();
  }

  void _reveal() {
    _revealed = true;
    try {
      _placement.show(maximized: _restored?.maximized ?? false);
    } catch (_) {
      unawaited(windowManager.show());
    }
  }

  @override
  Future<void> showWindow() async {
    if (!_revealed) {
      _reveal();
      return;
    }
    try {
      if (await windowManager.isMinimized()) await windowManager.restore();
      await windowManager.show();
      await windowManager.focus();
    } catch (_) {
      // A megjelenítés hibája nem állíthatja le az appot.
    }
    _handlers.onWindowShown?.call();
  }

  @override
  Future<void> hideToTray() async {
    _captureGeometry();
    await windowManager.hide();
  }

  @override
  Future<void> updateTrayMenu({required bool notificationsPaused}) async {
    _paused = notificationsPaused;
    if (!_trayAvailable) return;
    try {
      await _setMenu();
    } catch (_) {
      // A menüfrissítés hibája nem kritikus.
    }
  }

  @override
  Future<void> quit() async {
    if (_quitting) return;
    _quitting = true;
    _captureGeometry();
    try {
      await _handlers.onBeforeQuit?.call();
    } catch (_) {
      // A mentés hibája nem akadályozhatja a kilépést.
    }
    if (_trayAvailable) {
      try {
        await trayManager.destroy();
      } catch (_) {}
    }
    await windowManager.setPreventClose(false);
    await windowManager.destroy();
  }

  @override
  void dispose() {
    _geometryDebounce?.cancel();
    windowManager.removeListener(this);
    trayManager.removeListener(this);
  }

  /// A látható ablak helyzetének kiolvasása és jelzése, ha változott.
  void _captureGeometry() {
    _geometryDebounce?.cancel();
    _geometryDebounce = null;
    if (!_revealed) return;
    try {
      if (!_placement.isVisible) return;
      final geometry = _placement.read();
      if (geometry == null || geometry == _lastGeometry) return;
      if (geometry.width < WindowGeometry.minWidth ~/ 2) return;
      _lastGeometry = geometry;
      _handlers.onGeometryChanged?.call(geometry);
    } catch (_) {
      // Kényelmi adat: hibánál nem mentünk.
    }
  }

  void _scheduleGeometryCapture() {
    _geometryDebounce?.cancel();
    _geometryDebounce = Timer(
      const Duration(milliseconds: 600),
      _captureGeometry,
    );
  }

  // --- WindowListener ---

  @override
  void onWindowClose() => unawaited(_handleClose());

  Future<void> _handleClose() async {
    if (_quitting) return;
    if (_closeToTray && _trayAvailable) {
      await hideToTray();
      _handlers.onHiddenToTray?.call();
    } else {
      await quit();
    }
  }

  @override
  void onWindowResized() => _scheduleGeometryCapture();

  @override
  void onWindowMoved() => _scheduleGeometryCapture();

  @override
  void onWindowMaximize() => _scheduleGeometryCapture();

  @override
  void onWindowUnmaximize() => _scheduleGeometryCapture();

  @override
  void onWindowRestore() => _scheduleGeometryCapture();

  // --- TrayListener ---

  @override
  void onTrayIconMouseDown() => unawaited(showWindow());

  @override
  void onTrayIconRightMouseDown() => unawaited(trayManager.popUpContextMenu());

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'open':
        unawaited(showWindow());
      case 'refresh':
        _handlers.onRefreshNow?.call();
      case 'pause':
        _handlers.onTogglePause?.call();
      case 'quit':
        unawaited(quit());
    }
  }
}

/// Tartalék, ha az asztali integráció nem indult el: az ablak megjelenítése
/// közvetlenül (a futtató is megjeleníti néhány másodperc múlva).
Future<void> showWindowFallback() async {
  try {
    await windowManager.show();
  } catch (_) {
    // A futtató időzítője így is megjeleníti az ablakot.
  }
}
