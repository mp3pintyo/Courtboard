part of '../main.dart';

class _AthleteDirectory extends StatefulWidget {
  const _AthleteDirectory({
    required this.athletes,
    required this.sort,
    required this.onOpen,
    required this.onAdd,
  });
  final List<Athlete> athletes;
  final String sort;
  final ValueChanged<Athlete> onOpen;
  final VoidCallback onAdd;

  @override
  State<_AthleteDirectory> createState() => _AthleteDirectoryState();
}

class _AthleteDirectoryState extends State<_AthleteDirectory> {
  final _search = TextEditingController();
  String _sport = 'Mind';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = normalizeAthleteName(_search.text.trim());
    final athletes = sortAthletes(
      widget.athletes
          .where(
            (athlete) =>
                (_sport == 'Mind' || athlete.sport == _sport) &&
                (query.isEmpty ||
                    normalizeAthleteName(athlete.name).contains(query)),
          )
          .toList(),
      widget.sort,
    );
    return Container(
      color: _canvas,
      padding: const EdgeInsets.all(34),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sportolók',
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Névfeloldás, képkeresés és saját követési lista.',
                      style: TextStyle(color: _muted),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: widget.onAdd,
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Sportoló hozzáadása'),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('athlete-directory-search'),
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Keresés név alapján…',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _search.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Keresés törlése',
                            onPressed: () {
                              _search.clear();
                              setState(() {});
                            },
                            icon: const Icon(Icons.close),
                          ),
                    filled: true,
                    fillColor: _paper,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Text(
                '${athletes.length} sportoló',
                style: const TextStyle(
                  color: _muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children:
                  ['Mind', 'NBA', 'WNBA', 'Foci', 'Darts', 'Tenisz', 'NFL']
                      .map(
                        (sport) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            key: ValueKey('athlete-sport-$sport'),
                            label: Text(sport),
                            selected: _sport == sport,
                            selectedColor: Theme.of(
                              context,
                            ).colorScheme.secondaryContainer,
                            onSelected: (_) => setState(() => _sport = sport),
                          ),
                        ),
                      )
                      .toList(),
            ),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: athletes.isEmpty
                ? const Center(
                    child: Text(
                      'Nincs a keresésnek megfelelő sportoló.',
                      style: TextStyle(color: _muted),
                    ),
                  )
                : ListView.separated(
                    itemCount: athletes.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final athlete = athletes[index];
                      return Material(
                        color: _paper,
                        borderRadius: BorderRadius.circular(16),
                        clipBehavior: Clip.antiAlias,
                        child: ListTile(
                          key: ValueKey('directory-athlete-${athlete.name}'),
                          onTap: () => widget.onOpen(athlete),
                          leading: CircleAvatar(
                            backgroundColor: athlete.accent,
                            child: Text(athlete.name.substring(0, 1)),
                          ),
                          title: Text(
                            athlete.name,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text(athlete.sportAndTeam),
                          trailing: const Icon(Icons.arrow_forward),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _SettingsPage extends StatelessWidget {
  const _SettingsPage({
    required this.theme,
    required this.overviewSort,
    required this.athleteSort,
    required this.onThemeChanged,
    required this.onOverviewSortChanged,
    required this.onAthleteSortChanged,
  });

  final String theme;
  final String overviewSort;
  final String athleteSort;
  final ValueChanged<String> onThemeChanged;
  final ValueChanged<String> onOverviewSortChanged;
  final ValueChanged<String> onAthleteSortChanged;

  static const _sortOptions = {
    'custom': 'Saját sorrend',
    'name': 'Név (A–Z)',
    'sport': 'Sportág, majd név',
    'team': 'Csapat, majd név',
  };

  @override
  Widget build(BuildContext context) => Container(
    color: _canvas,
    padding: const EdgeInsets.all(34),
    child: ListView(
      children: [
        const Text(
          'Beállítások',
          style: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w900,
            letterSpacing: -1.4,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'A módosításokat a Courtboard automatikusan elmenti.',
          style: TextStyle(color: _muted),
        ),
        const SizedBox(height: 28),
        _SettingsCard(
          title: 'Megjelenés',
          description: 'Válaszd ki az alkalmazás kiemelőszínét.',
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'green',
                icon: Icon(Icons.eco_outlined),
                label: Text('Zöld téma'),
              ),
              ButtonSegment(
                value: 'burgundy',
                icon: Icon(Icons.wine_bar_outlined),
                label: Text('Bordó téma'),
              ),
            ],
            selected: {theme},
            onSelectionChanged: (values) => onThemeChanged(values.first),
          ),
        ),
        const SizedBox(height: 16),
        _SettingsCard(
          title: 'Sportolók rendezése',
          description:
              'Az Áttekintés és a Sportolók lista sorrendje külön állítható.',
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                key: const Key('overview-sort-setting'),
                initialValue: overviewSort,
                decoration: const InputDecoration(
                  labelText: 'Áttekintés – sportolók sorrendje',
                  border: OutlineInputBorder(),
                ),
                items: _sortOptions.entries
                    .map(
                      (entry) => DropdownMenuItem(
                        value: entry.key,
                        child: Text(entry.value),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) onOverviewSortChanged(value);
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                key: const Key('athlete-sort-setting'),
                initialValue: athleteSort,
                decoration: const InputDecoration(
                  labelText: 'Sportolók oldal – lista sorrendje',
                  border: OutlineInputBorder(),
                ),
                items: _sortOptions.entries
                    .map(
                      (entry) => DropdownMenuItem(
                        value: entry.key,
                        child: Text(entry.value),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) onAthleteSortChanged(value);
                },
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.title,
    required this.description,
    required this.child,
  });
  final String title;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(maxWidth: 760),
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: _paper,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: const Color(0xFFD8D4C8)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 5),
        Text(description, style: const TextStyle(color: _muted)),
        const SizedBox(height: 20),
        child,
      ],
    ),
  );
}

class _CalendarPage extends StatelessWidget {
  const _CalendarPage();
  @override
  Widget build(BuildContext context) {
    const events = [
      ('JAN 23', 'Denver Nuggets', 'vs. Lakers · NBA'),
      ('JAN 24', 'FC Barcelona', 'vs. Valencia · LaLiga'),
      ('JAN 25', 'Philadelphia Eagles', 'vs. Rams · NFL'),
      ('JAN 30', 'PDC Premier League', 'Luke Humphries · Darts'),
    ];
    return Container(
      color: _canvas,
      child: Padding(
        padding: const EdgeInsets.all(34),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Naptár és mérkőzések',
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w900,
                letterSpacing: -1.5,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Követett sportolóid következő eseményei és utolsó eredményei.',
              style: TextStyle(color: _muted),
            ),
            const SizedBox(height: 28),
            ...events.map(
              (event) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: _paper,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 80,
                      child: Text(
                        event.$1,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: _moss,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            event.$2,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          Text(event.$3, style: const TextStyle(color: _muted)),
                        ],
                      ),
                    ),
                    const Icon(Icons.notifications_none),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
