part of '../main.dart';

/// A követett sportolók naptárcélpontjai (név, sportág, csapat).
List<UpcomingEventsTarget> _calendarTargets(List<Athlete> athletes) => [
  for (final athlete in athletes)
    UpcomingEventsTarget(
      name: athlete.name,
      sport: athlete.sport,
      team: athlete.showsTeam ? athlete.team : '',
    ),
];

/// Naptár: a követett sportolók közelgő eseményei napok szerint
/// csoportosítva, sportág- és sportolószűrővel, .ics exporttal.
///
/// A betöltés sportolónként, fokozatosan történik (a [controller] a
/// shellben él, így oldalváltáskor nem vész el); egy forrás hibája csak egy
/// apró megjegyzés a lista alján.
class _CalendarPage extends StatefulWidget {
  const _CalendarPage({
    required this.athletes,
    required this.controller,
    required this.config,
  });

  final List<Athlete> athletes;
  final UpcomingEventsController controller;
  final SportsApiConfig config;

  @override
  State<_CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<_CalendarPage> {
  static const _sportOrder = ['NBA', 'WNBA', 'Foci', 'Darts', 'Tenisz', 'NFL'];

  String _sport = 'Mind';
  String _athlete = 'Mind';
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant _CalendarPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller.removeListener(_changed);
      widget.controller.addListener(_changed);
    }
    unawaited(_load());
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _load({bool force = false}) => widget.controller.load(
    _calendarTargets(widget.athletes),
    config: widget.config,
    force: force,
  );

  void _refresh() => unawaited(_load(force: true));

  void _showSnack(String message, {SnackBarAction? action}) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), action: action));
  }

  /// Egy esemény .ics fájlja az ideiglenes mappába, majd megnyitás az
  /// alapértelmezett naptáralkalmazással.
  Future<void> _addToCalendar(UpcomingEvent event) async {
    final File file;
    try {
      file = await writeSingleEventIcs(event);
    } catch (_) {
      _showSnack('A naptárfájl nem hozható létre.');
      return;
    }
    if (!mounted) return;
    await openLocalFile(context, file.path);
  }

  /// A látható események mentése egyetlen .ics fájlba. Mentési ablak a
  /// `file_selector` csomaggal; ha az nem érhető el, a Letöltések mappába.
  Future<void> _exportAll(List<UpcomingEvent> events) async {
    if (_exporting || events.isEmpty) return;
    setState(() => _exporting = true);
    try {
      final contents = buildIcsCalendar(events);
      String path;
      try {
        final location = await getSaveLocation(
          suggestedName: icsExportFileName,
          confirmButtonText: 'Mentés',
          acceptedTypeGroups: const [
            XTypeGroup(label: 'iCalendar (.ics)', extensions: ['ics']),
          ],
        );
        if (location == null) return; // A felhasználó mégsem mentett.
        path = location.path.toLowerCase().endsWith('.ics')
            ? location.path
            : '${location.path}.ics';
      } catch (_) {
        path = defaultIcsExportPath();
      }
      final File file;
      try {
        file = await writeIcsFile(path, contents);
      } catch (_) {
        _showSnack('A naptár exportálása nem sikerült.');
        return;
      }
      _showSnack(
        '${events.length} esemény exportálva: ${file.path}',
        action: SnackBarAction(
          label: 'Megnyitás',
          onPressed: () {
            if (mounted) unawaited(openLocalFile(context, file.path));
          },
        ),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cb = context.cb;
    final controller = widget.controller;
    final sports = [
      for (final sport in _sportOrder)
        if (widget.athletes.any((athlete) => athlete.sport == sport)) sport,
    ];
    if (_sport != 'Mind' && !sports.contains(_sport)) _sport = 'Mind';
    final athletes = [
      for (final athlete in widget.athletes)
        if (_sport == 'Mind' || athlete.sport == _sport) athlete.name,
    ];
    if (_athlete != 'Mind' && !athletes.contains(_athlete)) _athlete = 'Mind';

    final now = DateTime.now();
    final events = controller.events(sport: _sport, athlete: _athlete);
    final allEvents = controller.events();
    final groups = groupEventsByDay(events, now);
    final accents = {
      for (final athlete in widget.athletes) athlete.name: athlete.accent,
    };
    final teams = {
      for (final target in _calendarTargets(widget.athletes))
        target.name: target.team,
    };
    // Sportolónként a legközelebbi esemény (az események időrendben jönnek).
    final nextByAthlete = <String, UpcomingEvent>{};
    for (final event in events) {
      nextByAthlete.putIfAbsent(event.athleteName, () => event);
    }
    final targetCount = widget.athletes.length;
    final loadingCount = controller.loading.length;
    final notes = _notes(controller.results.values);
    final padding = MediaQuery.sizeOf(context).width < 800 ? 20.0 : 34.0;

    Widget body;
    if (events.isEmpty && controller.isLoading) {
      body = const Center(
        key: Key('calendar-loading'),
        child: CardSkeleton(label: 'Közelgő események betöltése…'),
      );
    } else if (events.isEmpty) {
      body = ListView(
        children: [
          const SizedBox(height: 24),
          Center(
            key: const Key('calendar-empty-state'),
            child: EmptyState(
              icon: Icons.event_available_outlined,
              title: allEvents.isEmpty
                  ? 'Nincs ismert közelgő esemény.'
                  : 'Nincs a szűrésnek megfelelő esemény.',
              message: allEvents.isEmpty
                  ? 'A követett sportolóidhoz a következő hetekben nincs '
                        'időpontos mérkőzés az elérhető forrásokban. A lista '
                        'automatikusan frissül; a megjegyzések lent mutatják, '
                        'melyik forrás mit adott.'
                  : 'Válassz másik sportágat vagy sportolót.',
            ),
          ),
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 28),
            _CalendarNotes(notes: notes),
          ],
        ],
      );
    } else {
      body = ListView(
        key: const Key('calendar-event-list'),
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          for (final group in groups) ...[
            _CalendarDayHeader(group: group),
            for (final event in group.events)
              _CalendarEventRow(
                event: event,
                // Sportolónként csak a következő meccsnél: egymás elleni
                // mérleg / legutóbbi egymás elleni meccsek.
                headToHead:
                    identical(nextByAthlete[event.athleteName], event) &&
                        HeadToHeadExpander.supports(event)
                    ? HeadToHeadExpander(
                        event: event,
                        config: widget.config,
                        team: teams[event.athleteName] ?? '',
                      )
                    : null,
                accent: accents[event.athleteName] ?? cb.accent,
                onAddToCalendar: () => unawaited(_addToCalendar(event)),
                onOpen: event.url == null
                    ? null
                    : () => unawaited(openExternalUrl(context, event.url!)),
              ),
          ],
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 22),
            _CalendarNotes(notes: notes),
          ],
        ],
      );
    }

    return CommandListener(
      onRefresh: _refresh,
      child: ColoredBox(
        color: cb.canvas,
        child: Padding(
          padding: EdgeInsets.fromLTRB(padding, padding, padding, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PageHeader(
                title: 'Naptár',
                subtitle:
                    'Követett sportolóid közelgő mérkőzései és eseményei, '
                    'helyi időben.',
                actions: [
                  Tooltip(
                    message: 'Frissítés a forrásokból (Ctrl+R)',
                    child: OutlinedButton.icon(
                      key: const Key('calendar-refresh'),
                      onPressed: controller.isLoading ? null : _refresh,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Frissítés'),
                    ),
                  ),
                  Tooltip(
                    message:
                        'A listában látható események mentése egy .ics fájlba',
                    child: FilledButton.icon(
                      key: const Key('calendar-export-all'),
                      onPressed: events.isEmpty || _exporting
                          ? null
                          : () => unawaited(_exportAll(events)),
                      icon: const Icon(Icons.ios_share),
                      label: const Text('Összes exportálása'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final sport in ['Mind', ...sports])
                    ChoiceChip(
                      key: ValueKey('calendar-sport-$sport'),
                      label: Text(sport),
                      selected: _sport == sport,
                      onSelected: (_) => setState(() => _sport = sport),
                    ),
                  const SizedBox(width: 4),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 260),
                    child: DropdownButton<String>(
                      key: const Key('calendar-athlete-filter'),
                      value: _athlete,
                      isExpanded: true,
                      isDense: true,
                      underline: const SizedBox.shrink(),
                      borderRadius: BorderRadius.circular(12),
                      style: context.text.bodyMedium,
                      items: [
                        const DropdownMenuItem(
                          value: 'Mind',
                          child: Text('Minden sportoló'),
                        ),
                        for (final name in athletes)
                          DropdownMenuItem(
                            value: name,
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (value) =>
                          setState(() => _athlete = value ?? 'Mind'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 22,
                child: controller.isLoading
                    ? Row(
                        key: const Key('calendar-progress'),
                        children: [
                          const SizedBox.square(
                            dimension: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Betöltés: ${targetCount - loadingCount} / '
                              '$targetCount sportoló kész…',
                              style: context.text.bodySmall,
                            ),
                          ),
                        ],
                      )
                    : Text(
                        events.isEmpty
                            ? ''
                            : '${events.length} esemény · a következő '
                                  '${widget.controller.repository.horizon.inDays} napban',
                        style: context.text.bodySmall,
                      ),
              ),
              const SizedBox(height: 6),
              Expanded(child: body),
            ],
          ),
        ),
      ),
    );
  }

  /// Sportolónkénti megjegyzések (hiányzó forrás, hiba, régi adat) a
  /// szűrőknek megfelelő sportolókhoz.
  List<String> _notes(Iterable<AthleteEventsResult> results) {
    final notes = <String>[];
    for (final result in results) {
      final target = result.target;
      if (_sport != 'Mind' && target.sport != _sport) continue;
      if (_athlete != 'Mind' && target.name != _athlete) continue;
      if (result.unavailable != null) {
        notes.add('${target.name}: ${result.unavailable}');
      }
      if (result.error != null) notes.add('${target.name}: ${result.error}');
      for (final note in result.notes) {
        notes.add('${target.name}: $note');
      }
      if (result.stale && result.fetchedAt != null) {
        notes.add(
          '${target.name}: '
          '${freshnessLabel(result.fetchedAt!, stale: true)} – a frissítés nem sikerült.',
        );
      }
    }
    return notes;
  }
}

class _CalendarDayHeader extends StatelessWidget {
  const _CalendarDayHeader({required this.group});
  final UpcomingDayGroup group;

  @override
  Widget build(BuildContext context) {
    final cb = context.cb;
    final today = group.label == 'Ma';
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Semantics(
        header: true,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Flexible(
              child: Text(
                group.label,
                style: context.text.titleLarge?.copyWith(
                  color: today ? cb.readable(cb.accent) : cb.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '${group.events.length} esemény',
              style: context.text.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _CalendarEventRow extends StatelessWidget {
  const _CalendarEventRow({
    required this.event,
    required this.accent,
    required this.onAddToCalendar,
    this.onOpen,
    this.headToHead,
  });

  /// Lenyitható egymás elleni mérleg (csak a sportoló következő meccsénél).
  final Widget? headToHead;

  final UpcomingEvent event;
  final Color accent;
  final VoidCallback onAddToCalendar;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final cb = context.cb;
    final details = [
      if (event.competition.isNotEmpty) event.competition,
      if (event.venue != null && event.venue!.isNotEmpty) event.venue!,
    ].join(' · ');
    final timeColumn = MediaQuery.textScalerOf(context).scale(64);
    final time = event.timeKnown ? formatTime(event.start) : 'később';
    return Semantics(
      container: true,
      label:
          '${event.athleteName}, ${event.matchup}, '
          '${event.timeKnown ? formatTime(event.start) : 'időpont később'}',
      child: Container(
        key: ValueKey('calendar-event-${icsUid(event)}'),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        decoration: BoxDecoration(
          color: cb.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cb.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _row(context, timeColumn, time, details),
            if (headToHead != null)
              Padding(
                padding: EdgeInsets.only(left: timeColumn + 4, right: 8),
                child: headToHead,
              ),
          ],
        ),
      ),
    );
  }

  Widget _row(
    BuildContext context,
    double timeColumn,
    String time,
    String details,
  ) {
    final cb = context.cb;
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 760;
        return Row(
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(minWidth: timeColumn),
              child: Text(
                time,
                style: context.text.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: event.timeKnown ? cb.textPrimary : cb.textMuted,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          '${event.athleteName} · ${event.sport}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.labelMedium?.copyWith(
                            color: cb.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    event.matchup,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.titleMedium,
                  ),
                  if (details.isNotEmpty)
                    Text(
                      details,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodySmall,
                    ),
                ],
              ),
            ),
            if (onOpen != null)
              IconButton(
                tooltip: 'Megnyitás: ${event.source}',
                onPressed: onOpen,
                icon: const Icon(Icons.open_in_new, size: 20),
              ),
            if (wide)
              TextButton.icon(
                key: const Key('calendar-add-to-calendar'),
                onPressed: onAddToCalendar,
                icon: const Icon(Icons.edit_calendar_outlined, size: 20),
                label: const Text('Hozzáadás a naptárhoz'),
              )
            else
              IconButton(
                key: const Key('calendar-add-to-calendar'),
                tooltip: 'Hozzáadás a naptárhoz',
                onPressed: onAddToCalendar,
                icon: const Icon(Icons.edit_calendar_outlined, size: 20),
              ),
          ],
        );
      },
    );
  }
}

class _CalendarNotes extends StatelessWidget {
  const _CalendarNotes({required this.notes});
  final List<String> notes;

  @override
  Widget build(BuildContext context) => Column(
    key: const Key('calendar-notes'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SubsectionLabel('FORRÁSMEGJEGYZÉSEK', icon: Icons.info_outline),
      for (final note in notes) CourtboardNote(note),
    ],
  );
}
