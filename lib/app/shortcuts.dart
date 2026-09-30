import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:courtboard/app/app_page.dart';

/// Ctrl+F: a látható oldal keresőmezője (vagy az Áttekintésé).
class ShellFocusSearchIntent extends Intent {
  const ShellFocusSearchIntent();
}

/// Esc / Alt+Bal: vissza a profilból.
class ShellBackIntent extends Intent {
  const ShellBackIntent();
}

/// Ctrl+R / F5: a látható oldal frissítése.
class ShellRefreshIntent extends Intent {
  const ShellRefreshIntent();
}

/// Ctrl+1…9: ugrás a menüpontra.
class ShellNavigateIntent extends Intent {
  const ShellNavigateIntent(this.page);
  final AppPage page;
}

/// Ctrl+N: új sportoló.
class ShellAddAthleteIntent extends Intent {
  const ShellAddAthleteIntent();
}

/// A shell billentyűparancsai (a Ctrl+1…9 az [AppPage] sorrendjét követi).
const Map<ShortcutActivator, Intent> shellShortcuts = {
  SingleActivator(LogicalKeyboardKey.keyF, control: true):
      ShellFocusSearchIntent(),
  SingleActivator(LogicalKeyboardKey.escape): ShellBackIntent(),
  SingleActivator(LogicalKeyboardKey.arrowLeft, alt: true): ShellBackIntent(),
  SingleActivator(LogicalKeyboardKey.keyR, control: true): ShellRefreshIntent(),
  SingleActivator(LogicalKeyboardKey.f5): ShellRefreshIntent(),
  SingleActivator(LogicalKeyboardKey.digit1, control: true):
      ShellNavigateIntent(AppPage.overview),
  SingleActivator(LogicalKeyboardKey.digit2, control: true):
      ShellNavigateIntent(AppPage.athletes),
  SingleActivator(LogicalKeyboardKey.digit3, control: true):
      ShellNavigateIntent(AppPage.calendar),
  SingleActivator(LogicalKeyboardKey.digit4, control: true):
      ShellNavigateIntent(AppPage.news),
  SingleActivator(LogicalKeyboardKey.digit5, control: true):
      ShellNavigateIntent(AppPage.videos),
  SingleActivator(LogicalKeyboardKey.digit6, control: true):
      ShellNavigateIntent(AppPage.feed),
  SingleActivator(LogicalKeyboardKey.digit7, control: true):
      ShellNavigateIntent(AppPage.compare),
  SingleActivator(LogicalKeyboardKey.digit8, control: true):
      ShellNavigateIntent(AppPage.dataSources),
  SingleActivator(LogicalKeyboardKey.digit9, control: true):
      ShellNavigateIntent(AppPage.settings),
  SingleActivator(LogicalKeyboardKey.keyN, control: true):
      ShellAddAthleteIntent(),
};

/// A Back intent csak akkor „fogyasztja el” a billentyűt, ha van hova
/// visszalépni; különben az Esc továbbjut (például a párbeszédablakokhoz).
class ShellAction<T extends Intent> extends Action<T> {
  ShellAction({required this.enabled, required this.onInvoke});
  final bool Function() enabled;
  final VoidCallback onInvoke;

  @override
  bool isEnabled(T intent) => enabled();

  @override
  Object? invoke(T intent) {
    onInvoke();
    return null;
  }
}
