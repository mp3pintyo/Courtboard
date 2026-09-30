import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

import '../data/window_geometry.dart';

/// Az ablak helyzetének olvasása és visszaállítása közvetlen Win32-hívással
/// (`GetWindowPlacement` / `SetWindowPlacement`).
///
/// A `window_manager` logikai képpontban dolgozik, ami eltérő nagyítású
/// monitoroknál nem egyértelmű; a `WINDOWPLACEMENT` viszont fizikai
/// képpontban, a normál (nem teljes méretű) téglalappal együtt adja vissza a
/// helyzetet, így a teljes méretű ablak „visszaállított” mérete is megmarad.
/// A koordináták munkaterület-koordináták (a fő monitor munkaterületéhez
/// képest); a monitorkereséshez ezeket képernyő-koordinátára váltjuk.
class Win32WindowPlacement {
  Win32WindowPlacement(int handle) : _hwnd = HWND(Pointer.fromAddress(handle));

  final HWND _hwnd;

  bool get isVisible => IsWindowVisible(_hwnd);
  bool get isMaximized => IsZoomed(_hwnd);
  bool get isMinimized => IsIconic(_hwnd);

  /// Az ablak jelenlegi normál téglalapja és teljes méretű állapota.
  WindowGeometry? read() => using((arena) {
    final placement = arena<WINDOWPLACEMENT>();
    placement.ref.length = sizeOf<WINDOWPLACEMENT>();
    if (!GetWindowPlacement(_hwnd, placement).value) return null;
    final ref = placement.ref;
    final rect = ref.rcNormalPosition;
    final maximized =
        ref.showCmd == SW_SHOWMAXIMIZED ||
        (ref.showCmd == SW_SHOWMINIMIZED &&
            (ref.flags & WPF_RESTORETOMAXIMIZED) != 0);
    return WindowGeometry(
      left: rect.left,
      top: rect.top,
      width: rect.right - rect.left,
      height: rect.bottom - rect.top,
      maximized: maximized,
    );
  });

  /// A mentett téglalap beállítása rejtett ablakon (az ablak nem jelenik
  /// meg). Kétszer hívjuk: ha az ablak eltérő nagyítású monitorra kerül, az
  /// első hívás utáni `WM_DPICHANGED` átméretezné; a második már a cél
  /// monitoron, pontos méretet állít be.
  void applyHidden(WindowGeometry geometry) {
    for (var i = 0; i < 2; i++) {
      _set(geometry, SW_HIDE);
    }
  }

  void _set(WindowGeometry geometry, SHOW_WINDOW_CMD command) => using((arena) {
    final placement = arena<WINDOWPLACEMENT>();
    placement.ref.length = sizeOf<WINDOWPLACEMENT>();
    if (!GetWindowPlacement(_hwnd, placement).value) return;
    placement.ref
      ..showCmd = command
      ..rcNormalPosition.left = geometry.left
      ..rcNormalPosition.top = geometry.top
      ..rcNormalPosition.right = geometry.right
      ..rcNormalPosition.bottom = geometry.bottom;
    SetWindowPlacement(_hwnd, placement);
  });

  /// Az ablak megjelenítése (első megjelenéskor a mentett teljes méretű
  /// állapottal) és előtérbe hozása.
  void show({required bool maximized}) {
    ShowWindow(_hwnd, maximized ? SW_SHOWMAXIMIZED : SW_SHOWNORMAL);
    SetForegroundWindow(_hwnd);
  }

  /// A [workspaceRect]-et (munkaterület-koordináták) metsző monitor
  /// munkaterülete ugyanebben a koordináta-rendszerben, vagy `null`, ha a
  /// téglalap egyik csatlakoztatott monitorra sem esik.
  PixelRect? workAreaFor(PixelRect workspaceRect) => using((arena) {
    final offset = _workspaceOffset(arena);
    final rect = arena<RECT>();
    rect.ref
      ..left = workspaceRect.left + offset.$1
      ..top = workspaceRect.top + offset.$2
      ..right = workspaceRect.right + offset.$1
      ..bottom = workspaceRect.bottom + offset.$2;
    final monitor = MonitorFromRect(rect, MONITOR_DEFAULTTONULL);
    if (!monitor.isValid) return null;
    final info = arena<MONITORINFO>();
    info.ref.cbSize = sizeOf<MONITORINFO>();
    if (!GetMonitorInfo(monitor, info)) return null;
    final work = info.ref.rcWork;
    return PixelRect(
      work.left - offset.$1,
      work.top - offset.$2,
      work.right - offset.$1,
      work.bottom - offset.$2,
    );
  });

  /// A munkaterület-koordináták eltolása a képernyő-koordinátákhoz képest
  /// (a fő monitor munkaterületének bal felső sarka; például bal oldali
  /// tálcánál nem nulla).
  (int, int) _workspaceOffset(Arena arena) {
    final point = arena<POINT>();
    final primary = MonitorFromPoint(point.ref, MONITOR_DEFAULTTOPRIMARY);
    final info = arena<MONITORINFO>();
    info.ref.cbSize = sizeOf<MONITORINFO>();
    if (!primary.isValid || !GetMonitorInfo(primary, info)) return (0, 0);
    return (
      info.ref.rcWork.left - info.ref.rcMonitor.left,
      info.ref.rcWork.top - info.ref.rcMonitor.top,
    );
  }
}
