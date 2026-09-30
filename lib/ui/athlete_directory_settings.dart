part of '../main.dart';

class _AthleteDirectory extends StatefulWidget {
  const _AthleteDirectory({
    required this.athletes,
    required this.sort,
    required this.onOpen,
    required this.onAdd,
    required this.onReorder,
  });
  final List<Athlete> athletes;
  final String sort;
  final ValueChanged<Athlete> onOpen;
  final VoidCallback onAdd;

  /// A „Saját sorrend” módosítása: régi és (a kivétel után már igazított)
  /// új index a teljes listában.
  final void Function(int oldIndex, int newIndex) onReorder;

  @override
  State<_AthleteDirectory> createState() => _AthleteDirectoryState();
}

class _AthleteDirectoryState extends State<_AthleteDirectory> {
  final _search = TextEditingController();
  final _searchFocus = FocusNode(debugLabel: 'directory-search');
  String _sport = 'Mind';

  @override
  void dispose() {
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _focusSearch() {
    _searchFocus.requestFocus();
    _search.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _search.text.length,
    );
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
    final customOrder = widget.sort == 'custom';
    // Húzással csak a teljes, szűretlen listát lehet átrendezni, különben az
    // indexek nem a tényleges sorrendre vonatkoznának.
    final reorderable = customOrder && query.isEmpty && _sport == 'Mind';
    final cb = context.cb;
    final padding = MediaQuery.sizeOf(context).width < 800 ? 20.0 : 34.0;
    return CommandListener(
      onFocusSearch: _focusSearch,
      child: Container(
        color: cb.canvas,
        padding: EdgeInsets.all(padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeader(
              title: 'Sportolók',
              subtitle: 'Névfeloldás, képkeresés és saját követési lista.',
              actions: [
                Tooltip(
                  message: 'Új sportoló (Ctrl+N)',
                  child: FilledButton.icon(
                    onPressed: widget.onAdd,
                    icon: const Icon(Icons.person_add_alt_1),
                    label: const Text('Sportoló hozzáadása'),
                  ),
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
                    focusNode: _searchFocus,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Keresés név alapján… (Ctrl+F)',
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
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  '${athletes.length} sportoló',
                  style: context.text.titleSmall?.copyWith(color: cb.textMuted),
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
                              onSelected: (_) => setState(() => _sport = sport),
                            ),
                          ),
                        )
                        .toList(),
              ),
            ),
            if (customOrder) ...[
              const SizedBox(height: 10),
              Text(
                reorderable
                    ? 'Saját sorrend: a fogantyúval húzva átrendezheted a listát.'
                    : 'Az átrendezéshez töröld a keresést, és válaszd a „Mind” szűrőt.',
                style: context.text.bodySmall,
              ),
            ],
            const SizedBox(height: 18),
            Expanded(
              child: athletes.isEmpty
                  ? const Center(
                      child: EmptyState(
                        icon: Icons.person_search_outlined,
                        message: 'Nincs a keresésnek megfelelő sportoló.',
                      ),
                    )
                  : reorderable
                  ? ReorderableListView.builder(
                      key: const Key('athlete-directory-reorderable'),
                      buildDefaultDragHandles: false,
                      itemCount: athletes.length,
                      onReorderItem: widget.onReorder,
                      itemBuilder: (context, index) => Padding(
                        key: ValueKey('reorder-${athletes[index].name}'),
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _DirectoryTile(
                          athlete: athletes[index],
                          onOpen: widget.onOpen,
                          trailing: ReorderableDragStartListener(
                            index: index,
                            child: Tooltip(
                              message: 'Húzd az átrendezéshez',
                              child: Icon(
                                Icons.drag_handle,
                                color: cb.textMuted,
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: athletes.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) => _DirectoryTile(
                        athlete: athletes[index],
                        onOpen: widget.onOpen,
                        trailing: Icon(
                          Icons.arrow_forward,
                          color: cb.textMuted,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DirectoryTile extends StatelessWidget {
  const _DirectoryTile({
    required this.athlete,
    required this.onOpen,
    required this.trailing,
  });
  final Athlete athlete;
  final ValueChanged<Athlete> onOpen;
  final Widget trailing;

  @override
  Widget build(BuildContext context) => FocusRing(
    borderRadius: BorderRadius.circular(16),
    child: Material(
      color: context.cb.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: context.cb.border),
      ),
      child: ListTile(
        key: ValueKey('directory-athlete-${athlete.name}'),
        onTap: () => onOpen(athlete),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: SizedBox.square(
          dimension: 42,
          child: ClipOval(
            child: CourtboardImage(
              url: athlete.photoUrl,
              alignment: const Alignment(0, -0.5),
              semanticLabel: '${athlete.name} fotója',
              placeholder: InitialsPlaceholder(
                name: athlete.name,
                color: athlete.accent,
              ),
            ),
          ),
        ),
        title: Text(
          athlete.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.text.titleMedium,
        ),
        subtitle: Text(
          athlete.sportAndTeam,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: trailing,
      ),
    ),
  );
}

class _SettingsPage extends StatelessWidget {
  const _SettingsPage({
    required this.theme,
    required this.themeMode,
    required this.onThemeModeChanged,
    required this.overviewSort,
    required this.athleteSort,
    required this.onThemeChanged,
    required this.onOverviewSortChanged,
    required this.onAthleteSortChanged,
  });

  final String theme;
  final String themeMode;
  final ValueChanged<String> onThemeModeChanged;
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
    color: context.cb.canvas,
    padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 800 ? 20 : 34),
    child: ListView(
      children: [
        const PageHeader(
          title: 'Beállítások',
          subtitle: 'A módosításokat a Courtboard automatikusan elmenti.',
        ),
        const SizedBox(height: 28),
        _SettingsCard(
          title: 'Megjelenés',
          description:
              'Válaszd ki a világos vagy sötét módot és az alkalmazás kiemelőszínét.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('MÓD', style: context.text.labelMedium),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                key: const Key('theme-mode-setting'),
                segments: const [
                  ButtonSegment(
                    value: 'system',
                    icon: Icon(Icons.brightness_auto_outlined),
                    label: Text('Rendszer'),
                  ),
                  ButtonSegment(
                    value: 'light',
                    icon: Icon(Icons.light_mode_outlined),
                    label: Text('Világos'),
                  ),
                  ButtonSegment(
                    value: 'dark',
                    icon: Icon(Icons.dark_mode_outlined),
                    label: Text('Sötét'),
                  ),
                ],
                selected: {themeMode},
                onSelectionChanged: (values) =>
                    onThemeModeChanged(values.first),
              ),
              const SizedBox(height: 20),
              Text('KIEMELŐSZÍN', style: context.text.labelMedium),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                key: const Key('accent-setting'),
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
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SettingsCard(
          title: 'Sportolók rendezése',
          description:
              'Az Áttekintés és a Sportolók lista sorrendje külön állítható. A saját sorrendet a Sportolók oldalon, húzással módosíthatod.',
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                style: context.text.bodyLarge,
                key: const Key('overview-sort-setting'),
                initialValue: overviewSort,
                decoration: const InputDecoration(
                  labelText: 'Áttekintés – sportolók sorrendje',
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
                style: context.text.bodyLarge,
                key: const Key('athlete-sort-setting'),
                initialValue: athleteSort,
                decoration: const InputDecoration(
                  labelText: 'Sportolók oldal – lista sorrendje',
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
        const SizedBox(height: 16),
        const _SettingsCard(
          title: 'Billentyűparancsok',
          description:
              'A leggyakoribb műveletek egér nélkül is elérhetők. '
              'A gombok eszköztippje is jelzi a gyorsbillentyűt.',
          child: _ShortcutList(),
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
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 760),
      child: SurfaceCard(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: context.text.titleLarge),
            const SizedBox(height: 5),
            Text(
              description,
              style: context.text.bodyMedium?.copyWith(
                color: context.cb.textMuted,
              ),
            ),
            const SizedBox(height: 20),
            child,
          ],
        ),
      ),
    ),
  );
}

class _CalendarPage extends StatelessWidget {
  const _CalendarPage();
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: context.cb.canvas,
    child: Padding(
      padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 800 ? 20 : 34),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Naptár és mérkőzések',
            subtitle:
                'Követett sportolóid következő eseményei és utolsó eredményei.',
          ),
          SizedBox(height: 28),
          Expanded(
            child: Center(
              key: Key('calendar-empty-state'),
              child: EmptyState(
                icon: Icons.event_available_outlined,
                title: 'Még nincs megjeleníthető esemény.',
                message:
                    'A naptár a követett sportolók közelgő eseményeiből épül fel — hamarosan.',
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
