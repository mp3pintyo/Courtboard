import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:win32/win32.dart';

import 'package:courtboard/data/notifications.dart';

/// Windows-értesítések (toast) a `local_notifier` csomaggal (WinToast).
///
/// A `flutter_local_notifications` Windows-változata ATL-t igényel, ami ezen
/// a fordítókörnyezeten nem érhető el; a `local_notifier` WRL-alapú, ATL
/// nélkül fordul. Első használatkor a WinToast a Start menüben
/// parancsikont hoz létre az alkalmazásazonosítóval (AUMID) – a nem
/// csomagolt asztali appok értesítéseihez a Windows ezt kéri.
///
/// Ha a beállítás vagy a megjelenítés hibázik, a [fallback] (tálcabuborék)
/// veszi át a további értesítéseket.
class ToastNotificationService implements NotificationService {
  /// A WinToast beállítása (és a Start menü parancsikonja) csak az első
  /// értesítésnél történik meg, nem minden indításkor.
  ToastNotificationService.lazy({this.fallback});

  /// Tartalék megjelenítés, ha a toast nem érhető el.
  final NotificationService? fallback;

  /// `null`: még nincs beállítva; hamis: a toast nem érhető el.
  bool? _toastReady;
  Future<bool>? _setup;
  void Function(CourtboardNotification notification)? _onClick;

  /// A megjelenített toastok figyelői (a régieket elengedjük).
  final List<LocalNotification> _recent = [];
  static const _maxTracked = 30;

  Future<bool> _ensureSetup() => _setup ??= () async {
    try {
      await localNotifier.setup(
        appName: 'Courtboard',
        shortcutPolicy: ShortcutPolicy.requireCreate,
      );
      return _toastReady = true;
    } catch (_) {
      return _toastReady = false;
    }
  }();

  @override
  bool get available => _toastReady != false || (fallback?.available ?? false);

  @override
  bool get supportsClick => _toastReady != false;

  @override
  String get description => _toastReady != false
      ? 'Windows-értesítés'
      : fallback?.description ?? 'Nem elérhető';

  @override
  set onClick(void Function(CourtboardNotification notification)? handler) {
    _onClick = handler;
    fallback?.onClick = handler;
  }

  @override
  Future<bool> show(CourtboardNotification notification) async {
    if (await _ensureSetup() && _toastReady == true) {
      try {
        final toast = LocalNotification(
          identifier: notification.id,
          title: notification.title,
          body: notification.body,
        );
        toast.onClick = () => _onClick?.call(notification);
        _track(toast);
        await toast.show();
        return true;
      } catch (_) {
        // A WinToast nem inicializálódott (például hiányzó parancsikon):
        // a további értesítések a tartalékon mennek.
        _toastReady = false;
      }
    }
    return await fallback?.show(notification) ?? false;
  }

  void _track(LocalNotification toast) {
    _recent.add(toast);
    while (_recent.length > _maxTracked) {
      localNotifier.removeListener(_recent.removeAt(0));
    }
  }
}

/// Tartalék: a tálcaikon buborékértesítése (`Shell_NotifyIcon`, `NIF_INFO`).
///
/// A `tray_manager` a főablakhoz `uID = 1` azonosítóval veszi fel az ikont;
/// ezt módosítjuk. A Windows 10/11 a buborékot is értesítésként mutatja,
/// de a kattintásról az app nem kap jelzést (csak az ablak hozható elő a
/// tálcaikonnal).
class TrayBalloonNotificationService implements NotificationService {
  TrayBalloonNotificationService(int windowHandle, {this.iconId = 1})
    : _hwnd = HWND(Pointer.fromAddress(windowHandle));

  final HWND _hwnd;
  final int iconId;

  @override
  bool get available => true;

  @override
  bool get supportsClick => false;

  @override
  String get description => 'Tálcaértesítés (buborék)';

  @override
  set onClick(void Function(CourtboardNotification notification)? handler) {}

  static String _clip(String value, int max) =>
      value.length < max ? value : '${value.substring(0, max - 2)}…';

  @override
  Future<bool> show(CourtboardNotification notification) async {
    try {
      return using((arena) {
        final data = arena<NOTIFYICONDATA>();
        data.ref
          ..cbSize = sizeOf<NOTIFYICONDATA>()
          ..hWnd = _hwnd
          ..uID = iconId
          ..uFlags = NIF_INFO
          ..szInfoTitle = _clip(notification.title, 64)
          ..szInfo = _clip(notification.body, 256)
          ..dwInfoFlags = NIIF_INFO;
        return Shell_NotifyIcon(NIM_MODIFY, data);
      });
    } catch (_) {
      return false;
    }
  }
}
