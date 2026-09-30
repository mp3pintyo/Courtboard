/// Az alkalmazás fő oldalai (menüpontjai).
library;

import 'package:flutter/material.dart';

/// A menüpontok a megjelenés sorrendjében; a Ctrl+1…9 billentyűparancs és
/// a router ágai (`StatefulShellBranch`) is ezt a sorrendet követik
/// ([shortcutDigit], [index]).
enum AppPage {
  overview(Icons.grid_view_rounded, 'Áttekintés', 'attekintes'),
  athletes(Icons.person_add_alt_1_outlined, 'Sportolók', 'sportolok'),
  calendar(Icons.calendar_month_outlined, 'Naptár', 'naptar'),
  news(Icons.newspaper_outlined, 'Hírek', 'hirek'),
  videos(Icons.video_library_outlined, 'Videók', 'videok'),
  feed(Icons.dynamic_feed_outlined, 'Követés', 'kovetes'),
  compare(Icons.compare_arrows_rounded, 'Összehasonlítás', 'osszehasonlitas'),
  dataSources(Icons.cloud_sync_outlined, 'Adatforrások', 'adatforrasok'),
  settings(Icons.settings_outlined, 'Beállítások', 'beallitasok');

  const AppPage(this.icon, this.label, this.slug);

  final IconData icon;

  /// A menüpont felirata (és a keskeny ablak felső sávjának címe).
  final String label;

  /// Az útvonal szegmense és a profil `from=` paraméterének értéke.
  final String slug;

  /// Az oldal útvonala (az Áttekintésé `/`).
  String get path => this == overview ? '/' : '/$slug';

  /// Az oldal a `from=` paraméter értékéből; ismeretlennél `null`.
  static AppPage? fromSlug(String? slug) =>
      values.where((page) => page.slug == slug).firstOrNull;

  /// A Ctrl+számjegy billentyűparancs számjegye (1–9).
  int get shortcutDigit => index + 1;

  /// Van-e az oldalon keresőmező (Ctrl+F).
  bool get hasSearch => switch (this) {
    overview || athletes || news || videos => true,
    _ => false,
  };

  /// A profil „Vissza” gombjának felirata, ha a profilt erről az oldalról
  /// nyitották meg.
  String get backLabel => switch (this) {
    athletes => 'Vissza: Sportolók',
    videos => 'Vissza: Videók',
    feed => 'Vissza: Követés',
    compare => 'Vissza: Összehasonlítás',
    _ => 'Vissza: Áttekintés',
  };
}
