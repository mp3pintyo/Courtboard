part of '../main.dart';

/// Ctrl+F: a látható oldal keresőmezője (vagy az Áttekintésé).
class _FocusSearchIntent extends Intent {
  const _FocusSearchIntent();
}

/// Esc / Alt+Bal: vissza a profilból.
class _BackIntent extends Intent {
  const _BackIntent();
}

/// Ctrl+R / F5: a látható oldal frissítése.
class _RefreshIntent extends Intent {
  const _RefreshIntent();
}

/// Ctrl+1…7: ugrás a menüpontra.
class _NavigateIntent extends Intent {
  const _NavigateIntent(this.index);
  final int index;
}

/// Ctrl+N: új sportoló.
class _AddAthleteIntent extends Intent {
  const _AddAthleteIntent();
}

/// A shell billentyűparancsai.
const Map<ShortcutActivator, Intent> _shellShortcuts = {
  SingleActivator(LogicalKeyboardKey.keyF, control: true): _FocusSearchIntent(),
  SingleActivator(LogicalKeyboardKey.escape): _BackIntent(),
  SingleActivator(LogicalKeyboardKey.arrowLeft, alt: true): _BackIntent(),
  SingleActivator(LogicalKeyboardKey.keyR, control: true): _RefreshIntent(),
  SingleActivator(LogicalKeyboardKey.f5): _RefreshIntent(),
  SingleActivator(LogicalKeyboardKey.digit1, control: true): _NavigateIntent(0),
  SingleActivator(LogicalKeyboardKey.digit2, control: true): _NavigateIntent(1),
  SingleActivator(LogicalKeyboardKey.digit3, control: true): _NavigateIntent(2),
  SingleActivator(LogicalKeyboardKey.digit4, control: true): _NavigateIntent(3),
  SingleActivator(LogicalKeyboardKey.digit5, control: true): _NavigateIntent(4),
  SingleActivator(LogicalKeyboardKey.digit6, control: true): _NavigateIntent(5),
  SingleActivator(LogicalKeyboardKey.digit7, control: true): _NavigateIntent(6),
  SingleActivator(LogicalKeyboardKey.keyN, control: true): _AddAthleteIntent(),
};

/// A Beállítások „Billentyűparancsok” listája: (billentyűk, leírás).
const courtboardShortcutHelp = <(List<String>, String)>[
  (
    ['Ctrl', 'F'],
    'Keresés az Áttekintésen, a Sportolók, a Hírek és a Videók oldalon',
  ),
  (['Esc'], 'Vissza a profilból; párbeszédablak bezárása'),
  (['Alt', '←'], 'Vissza a profilból'),
  (['Ctrl', 'R'], 'Az aktuális oldal frissítése (profil adatkártyái, hírek)'),
  (['F5'], 'Frissítés (ugyanaz, mint a Ctrl+R)'),
  (['Ctrl', '1 … 7'], 'Ugrás a menüpontokra, felülről lefelé'),
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
class _ShortcutList extends StatelessWidget {
  const _ShortcutList();

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
