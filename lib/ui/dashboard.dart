part of '../main.dart';

class _Dashboard extends StatefulWidget {
  const _Dashboard({
    required this.athletes,
    required this.search,
    required this.sort,
    required this.filter,
    required this.onFilterChanged,
    required this.onOpenSettings,
    required this.onOpen,
    required this.onAddAthlete,
  });
  final List<Athlete> athletes;
  final TextEditingController search;
  final String sort;

  /// A sportág-szűrő a shellben él, így a profil megnyitása után megmarad.
  final String filter;
  final ValueChanged<String> onFilterChanged;
  final VoidCallback onOpenSettings;
  final ValueChanged<Athlete> onOpen;
  final VoidCallback onAddAthlete;
  @override
  State<_Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<_Dashboard> {
  @override
  Widget build(BuildContext context) {
    final filter = widget.filter;
    final query = normalizeAthleteName(widget.search.text.trim());
    final list = sortAthletes(
      widget.athletes
          .where(
            (a) =>
                (filter == 'Mind' || a.sport == filter) &&
                (query.isEmpty || normalizeAthleteName(a.name).contains(query)),
          )
          .toList(),
      widget.sort,
    );
    final focus = list.isEmpty
        ? null
        : sortAthletes(widget.athletes, widget.sort).first;
    return Container(
      color: _canvas,
      child: SingleChildScrollView(
        key: const PageStorageKey('dashboard-scroll'),
        padding: const EdgeInsets.fromLTRB(34, 28, 34, 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(
              search: widget.search,
              onChanged: (_) => setState(() {}),
              onOpenSettings: widget.onOpenSettings,
            ),
            const SizedBox(height: 26),
            if (focus != null) ...[
              _WelcomeStrip(athlete: focus, onOpen: () => widget.onOpen(focus)),
              const SizedBox(height: 32),
            ],
            Wrap(
              spacing: 28,
              runSpacing: 14,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Követett sportolók',
                      style: TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1.2,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Kattints egy profilra a részletes teljesítményhez.',
                      style: TextStyle(color: _muted),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  children:
                      ['Mind', 'NBA', 'WNBA', 'Foci', 'Darts', 'Tenisz', 'NFL']
                          .map(
                            (item) => ChoiceChip(
                              label: Text(item),
                              selected: filter == item,
                              selectedColor: Theme.of(
                                context,
                              ).colorScheme.secondaryContainer,
                              side: const BorderSide(color: Color(0xFFCAC7BC)),
                              onSelected: (_) => widget.onFilterChanged(item),
                            ),
                          )
                          .toList(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (list.isEmpty)
              _EmptyDashboard(
                hasAthletes: widget.athletes.isNotEmpty,
                onAddAthlete: widget.onAddAthlete,
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth > 1180
                      ? 4
                      : constraints.maxWidth > 820
                      ? 3
                      : 2;
                  final gap = 16.0;
                  final width =
                      (constraints.maxWidth - gap * (columns - 1)) / columns;
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: list
                        .map(
                          (athlete) => SizedBox(
                            width: width,
                            child: _AthleteTile(
                              athlete: athlete,
                              onTap: () => widget.onOpen(athlete),
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

/// Napszakhoz illő köszönés a nyitóoldal fejlécéhez.
String courtboardGreeting(DateTime now) {
  final hour = now.hour;
  if (hour >= 4 && hour < 10) return 'Jó reggelt.';
  if (hour >= 10 && hour < 18) return 'Szép napot.';
  return 'Jó estét.';
}

class _EmptyDashboard extends StatelessWidget {
  const _EmptyDashboard({
    required this.hasAthletes,
    required this.onAddAthlete,
  });
  final bool hasAthletes;
  final VoidCallback onAddAthlete;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('dashboard-empty-state'),
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
    decoration: BoxDecoration(
      color: _paper,
      borderRadius: BorderRadius.circular(24),
    ),
    child: Column(
      children: [
        const Icon(Icons.person_search_outlined, size: 46, color: _muted),
        const SizedBox(height: 12),
        Text(
          hasAthletes
              ? 'Nincs a szűrésnek megfelelő sportoló.'
              : 'Még nem követsz egyetlen sportolót sem.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        Text(
          hasAthletes
              ? 'Módosítsd a keresést vagy a sportág-szűrőt, vagy adj hozzá új sportolót.'
              : 'Adj hozzá egy sportolót, és itt jelenik meg a profilja.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: _muted),
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          key: const Key('dashboard-add-athlete'),
          onPressed: onAddAthlete,
          icon: const Icon(Icons.person_add_alt_1),
          label: const Text('Sportoló hozzáadása'),
        ),
      ],
    ),
  );
}

class _Header extends StatelessWidget {
  const _Header({
    required this.search,
    required this.onChanged,
    required this.onOpenSettings,
  });
  final TextEditingController search;
  final ValueChanged<String> onChanged;
  final VoidCallback onOpenSettings;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              courtboardGreeting(DateTime.now()),
              style: const TextStyle(
                fontSize: 35,
                height: .9,
                fontWeight: FontWeight.w900,
                letterSpacing: -2,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'A te személyes sportközpontod',
              style: TextStyle(color: _muted, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
      SizedBox(
        width: 310,
        child: TextField(
          controller: search,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: 'Sportoló keresése',
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor: _paper,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(22),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ),
      const SizedBox(width: 10),
      _roundIcon(
        Icons.settings_outlined,
        onPressed: onOpenSettings,
        tooltip: 'Beállítások',
        key: const Key('overview-settings-button'),
      ),
    ],
  );
}

Widget _roundIcon(
  IconData icon, {
  VoidCallback? onPressed,
  String? tooltip,
  Key? key,
}) => Container(
  key: key,
  width: 46,
  height: 46,
  decoration: BoxDecoration(
    shape: BoxShape.circle,
    border: Border.all(color: const Color(0xFFC9C6BB)),
  ),
  child: IconButton(
    onPressed: onPressed,
    tooltip: tooltip,
    icon: Icon(icon, size: 21),
  ),
);

class _WelcomeStrip extends StatelessWidget {
  const _WelcomeStrip({required this.athlete, required this.onOpen});
  final Athlete athlete;
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) => Container(
    height: 266,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: _ink,
      borderRadius: BorderRadius.circular(30),
    ),
    child: Stack(
      children: [
        Positioned.fill(
          child: Opacity(
            opacity: .38,
            child: Image.network(
              athlete.photoUrl,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              errorBuilder: (_, __, ___) => const SizedBox(),
            ),
          ),
        ),
        Positioned.fill(
          child: const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_ink, Color(0x00151815)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(28),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'MAI FÓKUSZ · ${athlete.sport.toUpperCase()}',
                      style: const TextStyle(
                        color: _olive,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      athlete.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 39,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      [
                        if (athlete.showsTeam) athlete.team,
                        if (athlete.showsCountry) athlete.country,
                      ].join(' · '),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: onOpen,
                      style: FilledButton.styleFrom(
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.secondary,
                        foregroundColor: Theme.of(
                          context,
                        ).colorScheme.onSecondary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 15,
                        ),
                      ),
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('Profil megnyitása'),
                    ),
                  ],
                ),
              ),
              // Csak valós, kitöltött értéket mutatunk; üres mezőnél nincs doboz.
              if (athlete.seasonValue.isNotEmpty &&
                  athlete.seasonLabel.isNotEmpty) ...[
                _HeroStat(
                  value: athlete.seasonValue,
                  label: athlete.seasonLabel,
                ),
                const SizedBox(width: 14),
              ],
              if (athlete.primaryValue.isNotEmpty &&
                  athlete.primaryLabel.isNotEmpty)
                _HeroStat(
                  value: athlete.primaryValue,
                  label: athlete.primaryLabel,
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.value, required this.label});
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    width: 146,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .13),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white.withValues(alpha: .18)),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 30,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: .7,
          ),
        ),
      ],
    ),
  );
}

class _AthleteTile extends StatelessWidget {
  const _AthleteTile({required this.athlete, required this.onTap});
  final Athlete athlete;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    key: ValueKey('athlete-${athlete.name}'),
    onTap: onTap,
    borderRadius: BorderRadius.circular(24),
    child: Container(
      height: 300,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _paper,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.network(
              athlete.photoUrl,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              errorBuilder: (_, __, ___) => Container(color: athlete.accent),
            ),
          ),
          Positioned.fill(
            child: const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0x00151815), Color(0xD9151815)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          Positioned(
            top: 15,
            left: 15,
            child: _Pill(text: athlete.sport, color: athlete.accent),
          ),
          Positioned(
            left: 18,
            right: 18,
            bottom: 17,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  athlete.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 3),
                if (athlete.showsTeam)
                  Text(
                    athlete.team,
                    style: const TextStyle(color: Colors.white70),
                  ),
                const SizedBox(height: 13),
                Row(
                  children: [
                    if (athlete.seasonValue.isNotEmpty &&
                        athlete.seasonLabel.isNotEmpty) ...[
                      Text(
                        '${athlete.seasonValue}  ',
                        style: TextStyle(
                          color: athlete.accent,
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          athlete.seasonLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ] else
                      const Spacer(),
                    const Icon(
                      Icons.arrow_outward,
                      color: Colors.white,
                      size: 20,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
