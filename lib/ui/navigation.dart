part of '../main.dart';

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.color});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: const TextStyle(
        color: _ink,
        fontSize: 10,
        fontWeight: FontWeight.w900,
        letterSpacing: .8,
      ),
    ),
  );
}

class _SideRail extends StatelessWidget {
  const _SideRail({required this.active, required this.onSelect});
  final int active;
  final ValueChanged<int> onSelect;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: 236,
      color: _ink,
      padding: const EdgeInsets.fromLTRB(22, 30, 22, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: colors.secondary,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.bolt, color: colors.onSecondary),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'COURTBOARD',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 48),
          _NavItem(
            icon: Icons.grid_view_rounded,
            label: 'Áttekintés',
            selected: active == 0,
            onTap: () => onSelect(0),
          ),
          _NavItem(
            icon: Icons.person_add_alt_1_outlined,
            label: 'Sportolók',
            selected: active == 1,
            onTap: () => onSelect(1),
          ),
          _NavItem(
            icon: Icons.calendar_month_outlined,
            label: 'Naptár',
            selected: active == 2,
            onTap: () => onSelect(2),
          ),
          _NavItem(
            icon: Icons.newspaper_outlined,
            label: 'Hírek',
            selected: active == 3,
            onTap: () => onSelect(3),
          ),
          _NavItem(
            icon: Icons.video_library_outlined,
            label: 'Videók',
            selected: active == 4,
            onTap: () => onSelect(4),
          ),
          _NavItem(
            icon: Icons.cloud_sync_outlined,
            label: 'Adatforrások',
            selected: active == 5,
            onTap: () => onSelect(5),
          ),
          _NavItem(
            icon: Icons.settings_outlined,
            label: 'Beállítások',
            selected: active == 6,
            onTap: () => onSelect(6),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF2A3027),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.auto_awesome, color: colors.secondary),
                const SizedBox(height: 12),
                Text(
                  'SZEMÉLYES KÖVETÉS',
                  style: TextStyle(
                    color: colors.secondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Minden kedvenced egy helyen.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
          decoration: BoxDecoration(
            color: selected
                ? colors.primary.withValues(alpha: .55)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: selected ? colors.secondary : Colors.white54,
                size: 19,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? Colors.white : Colors.white60,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
