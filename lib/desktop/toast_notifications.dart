import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

import 'package:courtboard/data/notifications.dart';
import 'package:courtboard/desktop/windows_notifications.dart';

/// Tartalék: a tálcaikon buborékértesítése (`Shell_NotifyIcon`, `NIF_INFO`).
///
/// Akkor él, ha a `flutter_local_notifications` nem inicializálható vagy a
/// toast megjelenítése hibázik (lásd [FlutterLocalNotificationService]).
/// Semmilyen regisztrációt (AUMID, COM, parancsikon) nem igényel.
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
  bool get supportsActions => false;

  @override
  String get description => 'Tálcaértesítés (buborék)';

  @override
  set onActivated(void Function(NotificationActivation activation)? handler) {}

  @override
  Future<void> clearAll() async {}

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
