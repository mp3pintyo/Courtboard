/// A támogatott sportágak egy helyen.
///
/// A 0.13.0 előtt a sportág mindenhol szabad szöveg volt (`'NBA'`, `'Foci'`
/// …); a mentett állapotfájl és a gyorsítótárak továbbra is ezt a magyar
/// szöveget tárolják ([jsonValue]), így a régi mentések változatlanul
/// betölthetők.
library;

import 'package:flutter/material.dart';

enum Sport {
  // A deklaráció sorrendje a felületi sorrend is (szűrőchipek, legördülő
  // lista, naptár csoportosítása).
  nba(
    jsonValue: 'NBA',
    label: 'NBA-kosárlabda',
    shortLabel: 'NBA',
    icon: Icons.sports_basketball,
    hasTeam: true,
    defaultAccent: Color(0xFFE9B86E),
  ),
  wnba(
    jsonValue: 'WNBA',
    label: 'WNBA-kosárlabda',
    shortLabel: 'WNBA',
    icon: Icons.sports_basketball,
    hasTeam: true,
    defaultAccent: Color(0xFF70B7C5),
  ),
  football(
    jsonValue: 'Foci',
    label: 'Labdarúgás',
    shortLabel: 'Foci',
    icon: Icons.sports_soccer,
    hasTeam: true,
    defaultAccent: Color(0xFF9CAAF7),
  ),
  darts(
    jsonValue: 'Darts',
    label: 'Darts',
    shortLabel: 'Darts',
    icon: Icons.adjust_rounded,
    hasTeam: false,
    defaultAccent: Color(0xFFE894A7),
  ),
  tennis(
    jsonValue: 'Tenisz',
    label: 'Tenisz',
    shortLabel: 'Tenisz',
    icon: Icons.sports_tennis_rounded,
    hasTeam: false,
    defaultAccent: Color(0xFFB9D46A),
  ),
  nfl(
    jsonValue: 'NFL',
    label: 'Amerikai futball (NFL)',
    shortLabel: 'NFL',
    icon: Icons.sports_football,
    hasTeam: true,
    defaultAccent: Color(0xFF8ED19C),
  );

  const Sport({
    required this.jsonValue,
    required this.label,
    required this.shortLabel,
    required this.icon,
    required this.hasTeam,
    required this.defaultAccent,
  });

  /// A mentett állapotban és a gyorsítótárakban tárolt (0.13.0 előtti)
  /// szöveges érték: `NBA`, `WNBA`, `Foci`, `Tenisz`, `Darts`, `NFL`.
  final String jsonValue;

  /// Hosszabb magyar megnevezés (leírásokhoz, akadálymentes címkékhez).
  final String label;

  /// A felületen megjelenő rövid felirat (chipek, „NBA · Denver Nuggets”).
  final String shortLabel;

  /// A sportág ikonja.
  final IconData icon;

  /// Csapatsport-e: egyéni sportnál (darts, tenisz) nincs csapat mező.
  final bool hasTeam;

  /// Alapértelmezett azonosító szín egy új sportolóhoz.
  final Color defaultAccent;

  /// A „Mind” szűrő felirata (nincs sportág-megkötés).
  static const allLabel = 'Mind';

  /// A mentett szöveges érték visszaolvasása; a régi (magyar) értékeket, az
  /// enum-neveket és néhány angol változatot is elfogadja, kis- és
  /// nagybetűtől függetlenül. Ismeretlen értéknél `null`.
  static Sport? fromLabel(String? value) {
    final key = value?.trim().toLowerCase();
    if (key == null || key.isEmpty) return null;
    for (final sport in values) {
      if (sport.jsonValue.toLowerCase() == key ||
          sport.name.toLowerCase() == key ||
          sport.shortLabel.toLowerCase() == key) {
        return sport;
      }
    }
    return _aliases[key];
  }

  /// A [fromLabel] szigorú változata JSON-hoz: ismeretlen értéknél hiba.
  static Sport fromJson(Object? json) {
    final sport = json is String ? fromLabel(json) : null;
    if (sport == null) throw FormatException('Ismeretlen sportág: $json');
    return sport;
  }

  static const _aliases = {
    'soccer': Sport.football,
    'labdarúgás': Sport.football,
    'labdarugas': Sport.football,
    'futball': Sport.football,
    'tennis': Sport.tennis,
    'american football': Sport.nfl,
  };

  String toJson() => jsonValue;

  /// Kosárlabda (NBA vagy WNBA).
  bool get isBasketball => this == nba || this == wnba;
}
