part of '../main.dart';

/// Az oldalsáv megjelenése az ablakszélesség szerint.
enum _RailMode {
  /// ≥ 1200 px: teljes, feliratos oldalsáv (236 px).
  full,

  /// 800–1200 px (vagy összecsukva): csak ikonok, eszköztippel (80 px).
  compact,

  /// < 800 px: nincs oldalsáv; hamburger menü nyitja a fiókot.
  drawer,
}

/// Töréspontok és méretek egy helyen.
abstract final class _Layout {
  static const fullRailBreakpoint = 1200.0;
  static const compactRailBreakpoint = 800.0;
  static const fullRailWidth = 236.0;
  static const compactRailWidth = 80.0;

  /// Ultraszéles ablakban a tartalom legfeljebb ilyen széles, középre zárva.
  static const contentMaxWidth = 1440.0;

  static _RailMode modeFor(double width, {required bool collapsed}) =>
      width >= fullRailBreakpoint
      ? (collapsed ? _RailMode.compact : _RailMode.full)
      : width >= compactRailBreakpoint
      ? _RailMode.compact
      : _RailMode.drawer;
}

/// A menüpontok indexei (a Ctrl+1…9 sorrendje is ez).
abstract final class _Nav {
  static const overview = 0;
  static const athletes = 1;
  static const calendar = 2;
  static const news = 3;
  static const videos = 4;
  static const feed = 5;
  static const compare = 6;
  static const dataSources = 7;
  static const settings = 8;
}

const _navItems = [
  (Icons.grid_view_rounded, 'Áttekintés'),
  (Icons.person_add_alt_1_outlined, 'Sportolók'),
  (Icons.calendar_month_outlined, 'Naptár'),
  (Icons.newspaper_outlined, 'Hírek'),
  (Icons.video_library_outlined, 'Videók'),
  (Icons.dynamic_feed_outlined, 'Követés'),
  (Icons.compare_arrows_rounded, 'Összehasonlítás'),
  (Icons.cloud_sync_outlined, 'Adatforrások'),
  (Icons.settings_outlined, 'Beállítások'),
];

class _SideRail extends StatelessWidget {
  const _SideRail({
    required this.active,
    required this.onSelect,
    this.compact = false,
    this.onToggle,
    this.width,
  });
  final int active;
  final ValueChanged<int> onSelect;

  /// Csak ikonok (eszköztippel).
  final bool compact;

  /// Az összecsukás/kinyitás gombja; `null` esetén nincs gomb (például a
  /// közepes szélességnél, ahol a kompakt sáv kötelező).
  final VoidCallback? onToggle;

  /// Alapból a módhoz tartozó szélesség (a fiókban kitölti a fiókot).
  final double? width;

  @override
  Widget build(BuildContext context) {
    final cb = context.cb;
    return Container(
      width:
          width ?? (compact ? _Layout.compactRailWidth : _Layout.fullRailWidth),
      color: cb.ink,
      padding: compact
          ? const EdgeInsets.fromLTRB(12, 26, 12, 20)
          : const EdgeInsets.fromLTRB(22, 30, 22, 24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // A menüpontok magassága a szövegnagyítással nő.
          final scale = MediaQuery.textScalerOf(context).scale(100) / 100;
          return _content(
            context,
            // Alacsony ablakban a promóciós doboz elmarad, hogy a menü
            // férjen; még alacsonyabbnál a menü görgethető (9 menüpont
            // ≈ 590 px 1,0-s nagyításnál).
            showPromo: !compact && constraints.maxHeight >= 740 * scale,
            scroll: constraints.maxHeight < 610 * scale,
          );
        },
      ),
    );
  }

  Widget _logo(BuildContext context) {
    final cb = context.cb;
    final mark = Semantics(
      label: 'Courtboard',
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(color: cb.highlight, shape: BoxShape.circle),
        child: Icon(Icons.bolt, color: cb.onHighlight),
      ),
    );
    if (compact) return Center(child: mark);
    return Row(
      children: [
        mark,
        const SizedBox(width: 10),
        Expanded(
          child: ExcludeSemantics(
            child: Text(
              'COURTBOARD',
              overflow: TextOverflow.ellipsis,
              style: context.text.titleMedium?.copyWith(
                color: cb.onInk,
                fontSize: 17,
                fontWeight: FontWeight.w900,
                letterSpacing: -.8,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _content(
    BuildContext context, {
    required bool showPromo,
    required bool scroll,
  }) {
    final cb = context.cb;
    final items = [
      for (var i = 0; i < _navItems.length; i++)
        _NavItem(
          index: i,
          icon: _navItems[i].$1,
          label: _navItems[i].$2,
          selected: active == i,
          compact: compact,
          onTap: () => onSelect(i),
        ),
    ];
    final expand = compact && onToggle != null
        ? Center(
            child: IconButton(
              key: const Key('rail-expand'),
              tooltip: 'Oldalsáv kinyitása',
              onPressed: onToggle,
              color: cb.onInkMuted,
              icon: const Icon(Icons.keyboard_double_arrow_right_rounded),
            ),
          )
        : null;
    final collapse = !compact && onToggle != null
        ? Align(
            alignment: AlignmentDirectional.centerStart,
            child: Tooltip(
              message: 'Oldalsáv összecsukása',
              child: TextButton.icon(
                key: const Key('rail-collapse'),
                onPressed: onToggle,
                style: TextButton.styleFrom(foregroundColor: cb.onInkMuted),
                icon: const Icon(
                  Icons.keyboard_double_arrow_left_rounded,
                  size: 18,
                ),
                label: const Text('Összecsukás'),
              ),
            ),
          )
        : null;
    if (scroll) {
      // Nagyon alacsony ablak: a menü görgethető, semmi nem csordul túl.
      return ListView(
        padding: EdgeInsets.zero,
        children: [
          _logo(context),
          const SizedBox(height: 24),
          ...items,
          ?expand,
          ?collapse,
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _logo(context),
        SizedBox(height: compact ? 36 : 48),
        ...items,
        const Spacer(),
        ?expand,
        if (collapse != null) ...[collapse, const SizedBox(height: 10)],
        if (showPromo)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cb.inkRaised,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.auto_awesome, color: cb.highlight),
                const SizedBox(height: 12),
                Text(
                  'SZEMÉLYES KÖVETÉS',
                  style: context.text.labelSmall?.copyWith(color: cb.highlight),
                ),
                const SizedBox(height: 6),
                Text(
                  'Minden kedvenced egy helyen.',
                  style: context.text.bodySmall?.copyWith(color: cb.onInkMuted),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.index,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.compact = false,
  });
  final int index;
  final IconData icon;
  final String label;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cb = context.cb;
    final radius = BorderRadius.circular(13);
    final foreground = selected ? cb.onInk : cb.onInkMuted;
    final content = compact
        ? SizedBox(
            height: 46,
            child: Center(
              child: Icon(
                icon,
                color: selected ? cb.highlight : cb.onInkMuted,
                size: 22,
              ),
            ),
          )
        : Padding(
            padding: const EdgeInsets.fromLTRB(6, 12, 13, 12),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 20,
                  decoration: BoxDecoration(
                    color: selected ? cb.highlight : Colors.transparent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  icon,
                  color: selected ? cb.highlight : cb.onInkMuted,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.titleSmall?.copyWith(
                      color: foreground,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          );
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Tooltip(
        message: '$label (Ctrl+${index + 1})',
        // Kompakt sávban azonnal, feliratos sávban csak a gyorsbillentyűért.
        waitDuration: Duration(milliseconds: compact ? 200 : 900),
        excludeFromSemantics: true,
        child: Semantics(
          button: true,
          selected: selected,
          label: label,
          onTap: onTap,
          excludeSemantics: true,
          child: FocusRing(
            borderRadius: radius,
            color: cb.highlight,
            child: Material(
              color: selected ? cb.inkRaised : Colors.transparent,
              borderRadius: radius,
              child: InkWell(
                key: ValueKey('nav-$label'),
                onTap: onTap,
                borderRadius: radius,
                hoverColor: cb.onInk.withValues(alpha: .09),
                focusColor: cb.onInk.withValues(alpha: .12),
                highlightColor: cb.onInk.withValues(alpha: .06),
                splashColor: cb.highlight.withValues(alpha: .18),
                child: content,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Keskeny ablakban (< 800 px) a tartalom fölötti sáv hamburger menüvel.
class _CompactTopBar extends StatelessWidget {
  const _CompactTopBar({required this.title, required this.onMenu});
  final String title;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    final cb = context.cb;
    return Material(
      color: cb.ink,
      child: SizedBox(
        height: 56,
        child: Row(
          children: [
            const SizedBox(width: 6),
            IconButton(
              key: const Key('open-navigation-drawer'),
              tooltip: 'Menü megnyitása',
              color: cb.onInk,
              onPressed: onMenu,
              icon: const Icon(Icons.menu_rounded),
            ),
            const SizedBox(width: 6),
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: cb.highlight,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.bolt, size: 18, color: cb.onHighlight),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.titleMedium?.copyWith(color: cb.onInk),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
