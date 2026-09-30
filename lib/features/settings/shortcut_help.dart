/// A Beállítások „Billentyűparancsok” listája.
library;

import 'package:flutter/material.dart';

import 'package:courtboard/shared/theme/courtboard_theme.dart';

/// A Beállítások „Billentyűparancsok” listája: (billentyűk, leírás).
const courtboardShortcutHelp = <(List<String>, String)>[
  (
    ['Ctrl', 'F'],
    'Keresés az Áttekintésen, a Sportolók, a Hírek és a Videók oldalon',
  ),
  (['Esc'], 'Vissza a profilból; párbeszédablak bezárása'),
  (['Alt', '←'], 'Vissza a profilból'),
  (
    ['Ctrl', 'R'],
    'Az aktuális oldal frissítése (profil adatkártyái, naptár, hírek)',
  ),
  (['F5'], 'Frissítés (ugyanaz, mint a Ctrl+R)'),
  (['Ctrl', '1 … 9'], 'Ugrás a menüpontokra, felülről lefelé'),
  (['Ctrl', 'N'], 'Új sportoló felvétele'),
];

/// Egy billentyű „kupakként” rajzolva (a Beállítások listájához).
class _KeyCap extends StatelessWidget {
  const _KeyCap(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    final cb = context.cb;
    return Container(
      constraints: const BoxConstraints(minWidth: 30),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: cb.surfaceMuted,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: cb.borderStrong),
        boxShadow: [
          BoxShadow(color: cb.borderStrong, offset: const Offset(0, 1.5)),
        ],
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: context.text.labelLarge?.copyWith(
          fontSize: 12.5,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

/// A billentyűparancsok listája a Beállításokban.
class ShortcutList extends StatelessWidget {
  const ShortcutList({super.key});

  @override
  Widget build(BuildContext context) => Column(
    key: const Key('shortcut-list'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final (keys, description) in courtboardShortcutHelp)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Semantics(
            label: '${keys.join(' + ')}: $description',
            excludeSemantics: true,
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 6,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 118),
                  child: Wrap(
                    spacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      for (var i = 0; i < keys.length; i++) ...[
                        if (i > 0) Text('+', style: context.text.bodySmall),
                        _KeyCap(keys[i]),
                      ],
                    ],
                  ),
                ),
                Text(description, style: context.text.bodyMedium),
              ],
            ),
          ),
        ),
    ],
  );
}
