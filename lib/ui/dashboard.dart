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
    this.highlights = const {},
    this.onOpenNews,
    this.onOpenVideos,
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

  /// A profilokon már betöltött legutóbbi eredmények / következő események.
  final Map<String, AthleteHighlight> highlights;
  final VoidCallback? onOpenNews;
  final VoidCallback? onOpenVideos;
  @override
  State<_Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<_Dashboard> {
  final _searchFocus = FocusNode(debugLabel: 'dashboard-search');

  @override
  void dispose() {
    _searchFocus.dispose();
    super.dispose();
  }

  void _focusSearch() {
    _searchFocus.requestFocus();
    widget.search.selection = TextSelection(
      baseOffset: 0,
      extentOffset: widget.search.text.length,
    );
  }

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
    final focus = pickDashboardFocus(
      sortAthletes(widget.athletes, widget.sort),
      widget.highlights,
      DateTime.now(),
    );
    return CommandListener(
      onFocusSearch: _focusSearch,
      child: ColoredBox(
        color: context.cb.canvas,
        child: LayoutBuilder(
          builder: (context, viewport) {
            final horizontal = viewport.maxWidth < 700 ? 20.0 : 34.0;
            return SingleChildScrollView(
              key: const PageStorageKey('dashboard-scroll'),
              padding: EdgeInsets.fromLTRB(horizontal, 28, horizontal, 48),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Header(
                    search: widget.search,
                    focusNode: _searchFocus,
                    onChanged: (_) => setState(() {}),
                    onOpenSettings: widget.onOpenSettings,
                  ),
                  const SizedBox(height: 24),
                  if (widget.athletes.isNotEmpty) ...[
                    if (focus != null)
                      _FocusHero(
                        focus: focus,
                        onOpen: () => widget.onOpen(focus.athlete),
                      )
                    else
                      _SummaryHero(
                        athletes: widget.athletes,
                        onAddAthlete: widget.onAddAthlete,
                        onOpenNews: widget.onOpenNews,
                        onOpenVideos: widget.onOpenVideos,
                      ),
                    const SizedBox(height: 30),
                  ],
                  Wrap(
                    spacing: 28,
                    runSpacing: 14,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Semantics(
                            header: true,
                            child: Text(
                              'Követett sportolók',
                              style: context.text.headlineSmall,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Kattints egy profilra a részletes teljesítményhez.',
                            style: context.text.bodyMedium?.copyWith(
                              color: context.cb.textMuted,
                            ),
                          ),
                        ],
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children:
                            [
                                  'Mind',
                                  'NBA',
                                  'WNBA',
                                  'Foci',
                                  'Darts',
                                  'Tenisz',
                                  'NFL',
                                ]
                                .map(
                                  (item) => ChoiceChip(
                                    label: Text(item),
                                    selected: filter == item,
                                    onSelected: (_) =>
                                        widget.onFilterChanged(item),
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
                            : constraints.maxWidth > 480
                            ? 2
                            : 1;
                        const gap = 16.0;
                        final width =
                            (constraints.maxWidth - gap * (columns - 1)) /
                            columns;
                        return Wrap(
                          spacing: gap,
                          runSpacing: gap,
                          children: list
                              .map(
                                (athlete) => SizedBox(
                                  width: width,
                                  child: _AthleteTile(
                                    athlete: athlete,
                                    highlight: widget.highlights[athlete.name],
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
            );
          },
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

/// A „Mai fókusz” kiválasztott sportolója és a hozzá tartozó esemény.
class DashboardFocus {
  const DashboardFocus({
    required this.athlete,
    required this.event,
    required this.upcoming,
  });
  final Athlete athlete;
  final HighlightEvent event;

  /// Igaz: közelgő esemény; hamis: legutóbbi eredmény.
  final bool upcoming;
}

/// A fókusz kiválasztása a már betöltött kiemelésekből: elsőként a
/// legközelebbi közelgő esemény, különben a legfrissebb eredmény. Ha egyik
/// követett sportolóhoz sincs ilyen adat, `null` (összefoglaló hero).
DashboardFocus? pickDashboardFocus(
  List<Athlete> athletes,
  Map<String, AthleteHighlight> highlights,
  DateTime now,
) {
  DashboardFocus? upcoming;
  DashboardFocus? recent;
  for (final athlete in athletes) {
    final highlight = highlights[athlete.name];
    if (highlight == null) continue;
    final next = highlight.upcoming(now);
    if (next != null &&
        (upcoming == null || next.date.isBefore(upcoming.event.date))) {
      upcoming = DashboardFocus(athlete: athlete, event: next, upcoming: true);
    }
    final last = highlight.last;
    if (last != null &&
        (recent == null || last.date.isAfter(recent.event.date))) {
      recent = DashboardFocus(athlete: athlete, event: last, upcoming: false);
    }
  }
  return upcoming ?? recent;
}

class _EmptyDashboard extends StatelessWidget {
  const _EmptyDashboard({
    required this.hasAthletes,
    required this.onAddAthlete,
  });
  final bool hasAthletes;
  final VoidCallback onAddAthlete;

  @override
  Widget build(BuildContext context) => SurfaceCard(
    key: const Key('dashboard-empty-state'),
    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
    child: EmptyState(
      icon: Icons.person_search_outlined,
      title: hasAthletes
          ? 'Nincs a szűrésnek megfelelő sportoló.'
          : 'Még nem követsz egyetlen sportolót sem.',
      message: hasAthletes
          ? 'Módosítsd a keresést vagy a sportág-szűrőt, vagy adj hozzá új sportolót.'
          : 'Adj hozzá egy sportolót, és itt jelenik meg a profilja.',
      action: FilledButton.icon(
        key: const Key('dashboard-add-athlete'),
        onPressed: onAddAthlete,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Sportoló hozzáadása'),
      ),
    ),
  );
}

class _Header extends StatelessWidget {
  const _Header({
    required this.search,
    required this.focusNode,
    required this.onChanged,
    required this.onOpenSettings,
  });
  final TextEditingController search;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final cb = context.cb;
    OutlineInputBorder pill(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide(color: color, width: width),
        );
    final greeting = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            courtboardGreeting(DateTime.now()),
            style: context.text.displaySmall?.copyWith(
              fontSize: 36,
              height: 1,
              letterSpacing: -1.8,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'A te személyes sportközpontod',
          style: context.text.bodyMedium?.copyWith(
            color: cb.textMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
    final field = TextField(
      controller: search,
      focusNode: focusNode,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: 'Sportoló keresése (Ctrl+F)',
        prefixIcon: const Icon(Icons.search),
        border: pill(cb.border),
        enabledBorder: pill(cb.border),
        focusedBorder: pill(cb.accent, 2),
      ),
    );
    final settings = _RoundIcon(
      key: const Key('overview-settings-button'),
      icon: Icons.settings_outlined,
      onPressed: onOpenSettings,
      tooltip: 'Beállítások (Ctrl+7)',
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 640) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: greeting),
                  settings,
                ],
              ),
              const SizedBox(height: 16),
              field,
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: greeting),
            const SizedBox(width: 16),
            SizedBox(
              width: constraints.maxWidth < 900 ? 260 : 320,
              child: field,
            ),
            const SizedBox(width: 10),
            settings,
          ],
        );
      },
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
  });
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) => IconButton(
    onPressed: onPressed,
    tooltip: tooltip,
    style: IconButton.styleFrom(
      backgroundColor: context.cb.surface,
      fixedSize: const Size(46, 46),
      shape: CircleBorder(side: BorderSide(color: context.cb.border)),
    ),
    icon: Icon(icon, size: 21),
  );
}

/// Sötét, lapos „magazin” blokk a nyitóoldal tetején (≤ ~220 px).
class _HeroShell extends StatelessWidget {
  const _HeroShell({required this.child, this.background});
  final Widget child;
  final Widget? background;

  @override
  Widget build(BuildContext context) {
    final cb = context.cb;
    return Container(
      key: const Key('dashboard-hero'),
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 150),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: cb.ink,
        borderRadius: BorderRadius.circular(26),
        // Sötét módban a hero finom kerettel válik el a vászontól.
        border: cb.isDark ? Border.all(color: cb.border) : null,
      ),
      child: Stack(
        children: [
          if (background != null) Positioned.fill(child: background!),
          Padding(
            padding: const EdgeInsets.fromLTRB(26, 22, 26, 22),
            child: child,
          ),
        ],
      ),
    );
  }
}

/// Adatvezérelt „Mai fókusz”: a legközelebbi esemény vagy a legfrissebb
/// eredmény egy követett sportolótól — csak valós, már betöltött adatból.
class _FocusHero extends StatelessWidget {
  const _FocusHero({required this.focus, required this.onOpen});
  final DashboardFocus focus;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final cb = context.cb;
    final athlete = focus.athlete;
    final event = focus.event;
    final outcome = focus.upcoming
        ? MatchOutcome.upcoming
        : MatchOutcome.values.firstWhere(
            (value) => value.name == event.outcome,
            orElse: () => MatchOutcome.unknown,
          );
    final label = focus.upcoming ? 'KÖVETKEZŐ ESEMÉNY' : 'LEGUTÓBBI EREDMÉNY';
    final when = focus.upcoming
        ? '${formatMatchDate(event.date)} ${formatTime(event.date)}'
        : formatMatchDate(event.date);
    return LayoutBuilder(
      builder: (context, constraints) {
        final photoWidth = constraints.maxWidth < 620
            ? 0.0
            : (constraints.maxWidth * .38).clamp(220.0, 460.0);
        return _HeroShell(
          background: photoWidth == 0
              ? null
              : Stack(
                  children: [
                    Positioned(
                      top: 0,
                      right: 0,
                      bottom: 0,
                      width: photoWidth,
                      child: CourtboardImage(
                        url: athlete.photoUrl,
                        alignment: const Alignment(0, -0.3),
                        opacity: .72,
                        semanticLabel: '${athlete.name} fotója',
                        placeholder: InitialsPlaceholder(
                          name: athlete.name,
                          color: athlete.accent,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 0,
                      bottom: 0,
                      right: photoWidth - 160,
                      width: 160,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [cb.ink, cb.ink.withValues(alpha: 0)],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
          child: Padding(
            padding: EdgeInsets.only(right: photoWidth * .8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'MAI FÓKUSZ · $label · ${athlete.sport.toUpperCase()}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.labelMedium?.copyWith(
                    color: cb.highlight,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  athlete.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.headlineLarge?.copyWith(color: cb.onInk),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (outcome != MatchOutcome.unknown)
                      _InkResultBadge(outcome: outcome, score: event.score),
                    if (event.score.isNotEmpty)
                      Text(
                        normalizeScore(event.score),
                        style: context.text.titleLarge?.copyWith(
                          color: cb.onInk,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    Text(
                      '${event.title} · $when',
                      style: context.text.bodyLarge?.copyWith(
                        color: cb.onInkMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  key: const Key('dashboard-hero-open'),
                  onPressed: onOpen,
                  style: FilledButton.styleFrom(
                    backgroundColor: cb.highlight,
                    foregroundColor: cb.onHighlight,
                    side: BorderSide.none,
                  ).copyWith(side: _onInkFocusSide(cb)),
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Profil megnyitása'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Fókuszkeret sötét (ink) felületen lévő gombokhoz.
WidgetStateProperty<BorderSide?> _onInkFocusSide(CourtboardColors cb) =>
    WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.focused)
          ? BorderSide(
              color: cb.onInk,
              width: 2,
              strokeAlign: BorderSide.strokeAlignOutside,
            )
          : null,
    );

/// Eredményjelvény sötét felületen (a hero-ban).
class _InkResultBadge extends StatelessWidget {
  const _InkResultBadge({required this.outcome, required this.score});
  final MatchOutcome outcome;
  final String score;

  @override
  Widget build(BuildContext context) {
    final cb = context.cb;
    // Az ink felületen a sötét mód élénk eredményszínei olvashatók.
    final dark = CourtboardColors.darkGreen;
    final color = switch (outcome) {
      MatchOutcome.win => dark.win,
      MatchOutcome.loss => dark.loss,
      MatchOutcome.draw => dark.draw,
      _ => cb.highlight,
    };
    return Semantics(
      label: score.isEmpty
          ? outcome.label
          : '${outcome.label} ${normalizeScore(score)}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .16),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: .6)),
        ),
        child: Text(
          outcome.letter,
          style: context.text.labelLarge?.copyWith(
            color: color,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

/// Összefoglaló hero, ha még nincs betöltött eredmény vagy esemény:
/// követettek száma sportáganként és gyors műveletek.
class _SummaryHero extends StatelessWidget {
  const _SummaryHero({
    required this.athletes,
    required this.onAddAthlete,
    this.onOpenNews,
    this.onOpenVideos,
  });
  final List<Athlete> athletes;
  final VoidCallback onAddAthlete;
  final VoidCallback? onOpenNews;
  final VoidCallback? onOpenVideos;

  @override
  Widget build(BuildContext context) {
    final cb = context.cb;
    final counts = <String, int>{};
    for (final athlete in athletes) {
      counts[athlete.sport] = (counts[athlete.sport] ?? 0) + 1;
    }
    final secondary =
        OutlinedButton.styleFrom(
          foregroundColor: cb.onInk,
          side: BorderSide(color: cb.onInk.withValues(alpha: .28)),
        ).copyWith(
          side: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.focused)
                ? BorderSide(color: cb.onInk, width: 2)
                : BorderSide(color: cb.onInk.withValues(alpha: .28)),
          ),
        );
    return _HeroShell(
      child: Wrap(
        spacing: 24,
        runSpacing: 18,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'MAI FÓKUSZ',
                  style: context.text.labelMedium?.copyWith(
                    color: cb.highlight,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${athletes.length} követett sportoló',
                  style: context.text.headlineMedium?.copyWith(color: cb.onInk),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final entry in counts.entries)
                      Semantics(
                        label: '${entry.key}: ${entry.value} sportoló',
                        excludeSemantics: true,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: cb.inkRaised,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${entry.key} · ${entry.value}',
                            style: context.text.labelLarge?.copyWith(
                              color: cb.onInk,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Nyiss meg egy profilt: a betöltött eredmények és a következő '
                  'események itt jelennek meg.',
                  style: context.text.bodyMedium?.copyWith(
                    color: cb.onInkMuted,
                  ),
                ),
              ],
            ),
          ),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                key: const Key('hero-add-athlete'),
                onPressed: onAddAthlete,
                style: FilledButton.styleFrom(
                  backgroundColor: cb.highlight,
                  foregroundColor: cb.onHighlight,
                ).copyWith(side: _onInkFocusSide(cb)),
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Sportoló hozzáadása'),
              ),
              if (onOpenNews != null)
                OutlinedButton.icon(
                  onPressed: onOpenNews,
                  style: secondary,
                  icon: const Icon(Icons.newspaper_outlined),
                  label: const Text('Hírek'),
                ),
              if (onOpenVideos != null)
                OutlinedButton.icon(
                  onPressed: onOpenVideos,
                  style: secondary,
                  icon: const Icon(Icons.video_library_outlined),
                  label: const Text('Videók'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Sportolókártya: fotó (vagy monogramos átmenet), sportág, név, csapat és
/// — ha a profilon már betöltődött — a legutóbbi eredmény. Egérrel
/// kiemelkedik, billentyűzettel fókuszkeretet kap.
class _AthleteTile extends StatefulWidget {
  const _AthleteTile({
    required this.athlete,
    required this.onTap,
    this.highlight,
  });
  final Athlete athlete;
  final VoidCallback onTap;
  final AthleteHighlight? highlight;

  @override
  State<_AthleteTile> createState() => _AthleteTileState();
}

class _AthleteTileState extends State<_AthleteTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final cb = context.cb;
    final athlete = widget.athlete;
    final radius = BorderRadius.circular(22);
    final subtitle = athlete.showsTeam
        ? athlete.team
        : athlete.showsCountry
        ? athlete.country
        : '';
    final semantic = [
      athlete.name,
      athlete.sport,
      if (subtitle.isNotEmpty) subtitle,
    ].join(', ');
    return Semantics(
      button: true,
      label: '$semantic – profil megnyitása',
      onTap: widget.onTap,
      excludeSemantics: true,
      child: AnimatedScale(
        scale: _hover ? 1.015 : 1,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: _hover ? cb.borderStrong : cb.border),
            boxShadow: [
              if (_hover)
                BoxShadow(
                  color: Colors.black.withValues(alpha: cb.isDark ? .45 : .14),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
            ],
          ),
          child: FocusRing(
            borderRadius: radius,
            width: 2.5,
            child: ClipRRect(
              borderRadius: radius,
              child: Material(
                color: cb.surface,
                child: Stack(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          height: 142,
                          child: _TilePhoto(athlete: athlete),
                        ),
                        _TileInfo(
                          subtitle: subtitle,
                          highlight: widget.highlight,
                        ),
                      ],
                    ),
                    // Az InkWell a kép fölött van, így a hover/ripple látszik.
                    Positioned.fill(
                      child: Material(
                        type: MaterialType.transparency,
                        child: InkWell(
                          key: ValueKey('athlete-${athlete.name}'),
                          onTap: widget.onTap,
                          onHover: (value) => setState(() => _hover = value),
                          hoverColor: cb.onInk.withValues(alpha: .04),
                          focusColor: cb.accent.withValues(alpha: .10),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TilePhoto extends StatelessWidget {
  const _TilePhoto({required this.athlete});
  final Athlete athlete;

  @override
  Widget build(BuildContext context) {
    final cb = context.cb;
    return Stack(
      fit: StackFit.expand,
      children: [
        CourtboardImage(
          url: athlete.photoUrl,
          alignment: const Alignment(0, -0.35),
          semanticLabel: '${athlete.name} fotója',
          placeholder: InitialsPlaceholder(
            name: athlete.name,
            color: athlete.accent,
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                cb.ink.withValues(alpha: 0),
                cb.ink.withValues(alpha: .86),
              ],
              stops: const [.35, 1],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        Positioned(
          top: 12,
          left: 12,
          child: StatusPill.filled(
            athlete.sport.toUpperCase(),
            color: athlete.accent,
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 10,
          child: Text(
            athlete.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.headlineSmall?.copyWith(color: cb.onInk),
          ),
        ),
      ],
    );
  }
}

/// A kártya alsó, kompakt információs sora: csapat (vagy ország) és a
/// legutóbbi eredmény / következő esemény, ha van valós adat.
class _TileInfo extends StatelessWidget {
  const _TileInfo({required this.subtitle, required this.highlight});
  final String subtitle;
  final AthleteHighlight? highlight;

  @override
  Widget build(BuildContext context) {
    final cb = context.cb;
    final now = DateTime.now();
    final next = highlight?.upcoming(now);
    final last = highlight?.last;
    Widget? result;
    if (last != null) {
      final outcome = MatchOutcome.values.firstWhere(
        (value) => value.name == last.outcome,
        orElse: () => MatchOutcome.unknown,
      );
      result = Tooltip(
        message: '${last.title} · ${formatMatchDate(last.date)}',
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (outcome != MatchOutcome.unknown)
              ResultBadge(outcome, score: last.score),
            if (last.score.isNotEmpty) ...[
              const SizedBox(width: 6),
              Text(
                normalizeScore(last.score),
                style: context.text.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ],
        ),
      );
    } else if (next != null) {
      result = StatusPill(
        'KÖV. ${formatMatchDate(next.date)}',
        tone: StatusTone.accent,
        icon: Icons.event_outlined,
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 34),
        child: Row(
          children: [
            Expanded(
              child: Text(
                subtitle.isEmpty ? 'Profil megnyitása' : subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.bodyMedium?.copyWith(
                  color: cb.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (result != null) ...[
              const SizedBox(width: 8),
              result,
            ] else
              Icon(Icons.arrow_outward, color: cb.textMuted, size: 18),
          ],
        ),
      ),
    );
  }
}
