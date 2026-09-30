part of '../main.dart';

/// Egy hírfolyam-elem ikonja és kiemelőszíne típus (és eredmény) szerint.
(IconData, Color) _feedVisual(CourtboardColors cb, FeedItem item) =>
    switch (item.type) {
      FeedItemType.news => (Icons.newspaper_outlined, cb.accent),
      FeedItemType.video => (Icons.play_circle_outline, cb.live),
      FeedItemType.upcoming => (Icons.event_outlined, cb.warning),
      FeedItemType.result => (
        Icons.sports_score_rounded,
        switch (item.outcome) {
          MatchOutcome.win => cb.win,
          MatchOutcome.loss => cb.loss,
          MatchOutcome.draw => cb.draw,
          _ => cb.textMuted,
        },
      ),
    };

/// A „Követés” oldal: a követettek hírei, mentett videói, eredményei és a
/// következő 7 nap eseményei egy idővonalon, típus- és sportolószűrővel,
/// fokozatosan (lapozva) megjelenítve.
class _FollowFeedPage extends StatefulWidget {
  const _FollowFeedPage({
    required this.items,
    required this.athletes,
    required this.onOpenAthlete,
    required this.onRefresh,
  });

  final List<FeedItem> items;
  final List<Athlete> athletes;
  final ValueChanged<Athlete> onOpenAthlete;
  final Future<void> Function() onRefresh;

  @override
  State<_FollowFeedPage> createState() => _FollowFeedPageState();
}

class _FollowFeedPageState extends State<_FollowFeedPage> {
  static const _pageSize = 20;

  final Set<FeedItemType> _types = {};
  String? _athlete;
  int _visible = _pageSize;
  bool _refreshing = false;

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      await widget.onRefresh();
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  void _loadMore() {
    if (!mounted) return;
    setState(() => _visible += _pageSize);
  }

  void _setTypes(void Function() change) => setState(() {
    change();
    _visible = _pageSize;
  });

  @override
  Widget build(BuildContext context) {
    final cb = context.cb;
    final filtered = mergeFeed(widget.items, types: _types, athlete: _athlete);
    final shown = filtered.take(_visible).toList();
    final hasMore = filtered.length > shown.length;
    final athleteNames = <String>{
      for (final item in widget.items) ...item.athletes,
    };
    final now = DateTime.now();
    final horizontal = MediaQuery.sizeOf(context).width < 800 ? 20.0 : 34.0;
    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageHeader(
          title: 'Követés',
          subtitle:
              'Legfrissebb a követettektől: hírek, mentett videók, eredmények '
              'és a következő 7 nap eseményei — a már letöltött adatokból.',
          actions: [
            FilledButton.tonalIcon(
              key: const Key('feed-refresh'),
              onPressed: _refreshing ? null : () => unawaited(_refresh()),
              icon: _refreshing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded),
              label: const Text('Frissítés (Ctrl+R)'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              key: const Key('feed-type-all'),
              label: const Text('Mind'),
              selected: _types.isEmpty,
              onSelected: (_) => _setTypes(_types.clear),
            ),
            for (final type in FeedItemType.values)
              FilterChip(
                key: ValueKey('feed-type-${type.name}'),
                label: Text(type.pluralLabel),
                avatar: Icon(
                  _feedVisual(
                    cb,
                    FeedItem(
                      id: '',
                      type: type,
                      time: now,
                      title: '',
                      athletes: const [],
                    ),
                  ).$1,
                  size: 16,
                ),
                selected: _types.contains(type),
                onSelected: (value) => _setTypes(
                  () => value ? _types.add(type) : _types.remove(type),
                ),
              ),
          ],
        ),
        if (athleteNames.length > 1) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Minden sportoló'),
                selected: _athlete == null,
                onSelected: (_) => setState(() {
                  _athlete = null;
                  _visible = _pageSize;
                }),
              ),
              for (final athlete in widget.athletes)
                if (athleteNames.contains(athlete.name))
                  ChoiceChip(
                    key: ValueKey('feed-athlete-${athlete.name}'),
                    label: Text(athlete.name),
                    avatar: CircleAvatar(
                      backgroundColor: athlete.accent,
                      radius: 6,
                    ),
                    selected: _athlete == athlete.name,
                    onSelected: (_) => setState(() {
                      _athlete = _athlete == athlete.name ? null : athlete.name;
                      _visible = _pageSize;
                    }),
                  ),
            ],
          ),
        ],
        const SizedBox(height: 8),
        Text(
          filtered.isEmpty
              ? ''
              : '${formatInt(filtered.length)} elem · '
                    '${formatInt(shown.length)} látható',
          style: context.text.bodySmall,
        ),
        const SizedBox(height: 12),
      ],
    );
    return CommandListener(
      onRefresh: () => unawaited(_refresh()),
      child: ColoredBox(
        color: cb.canvas,
        child: ListView.builder(
          key: const PageStorageKey('feed-scroll'),
          padding: EdgeInsets.fromLTRB(horizontal, 28, horizontal, 48),
          itemCount:
              1 + (filtered.isEmpty ? 1 : shown.length) + (hasMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == 0) return header;
            if (filtered.isEmpty) {
              return SurfaceCard(
                key: const Key('feed-empty'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 36,
                ),
                child: EmptyState(
                  icon: Icons.dynamic_feed_outlined,
                  title: widget.items.isEmpty
                      ? 'Még nincs friss tartalom a követettektől.'
                      : 'Nincs a szűrésnek megfelelő elem.',
                  message: widget.items.isEmpty
                      ? 'A hírfolyam a Hírek oldal cikkeiből, a mentett '
                            'videókból, a profilokon betöltött eredményekből '
                            'és a Naptár eseményeiből épül.'
                      : 'Módosítsd a típus- vagy sportolószűrőt.',
                ),
              );
            }
            final i = index - 1;
            if (i >= shown.length) {
              // Az utolsó elem láthatóvá válásakor töltjük a következő
              // oldalt (a ListView csak a látható elemeket építi meg).
              WidgetsBinding.instance.addPostFrameCallback((_) => _loadMore());
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: TextButton.icon(
                    key: const Key('feed-load-more'),
                    onPressed: _loadMore,
                    icon: const Icon(Icons.expand_more),
                    label: const Text('Továbbiak betöltése'),
                  ),
                ),
              );
            }
            final item = shown[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _FeedTile(
                item: item,
                now: now,
                athletes: widget.athletes,
                onOpenAthlete: widget.onOpenAthlete,
              ),
            );
          },
        ),
      ),
    );
  }
}

/// „Legfrissebb a követettektől” a nyitóoldalon: a hírfolyam első öt eleme.
class _DashboardFeedSection extends StatelessWidget {
  const _DashboardFeedSection({
    required this.items,
    required this.athletes,
    required this.onOpenAll,
    required this.onOpenAthlete,
  });

  final List<FeedItem> items;
  final List<Athlete> athletes;
  final VoidCallback onOpenAll;
  final ValueChanged<Athlete> onOpenAthlete;

  static const previewCount = 6;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final preview = feedPreview(items, count: previewCount);
    return Column(
      key: const Key('dashboard-feed'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Legfrissebb a követettektől',
          subtitle: 'Hírek, videók, eredmények és a következő 7 nap eseményei.',
          trailing: TextButton.icon(
            key: const Key('dashboard-feed-all'),
            onPressed: onOpenAll,
            icon: const Icon(Icons.dynamic_feed_outlined),
            label: Text(
              items.length > previewCount
                  ? 'Mind a ${formatInt(items.length)} (Ctrl+6)'
                  : 'Követés oldal (Ctrl+6)',
            ),
          ),
        ),
        if (preview.isEmpty)
          const SurfaceCard(
            padding: EdgeInsets.all(18),
            child: EmptyState(
              compact: true,
              icon: Icons.dynamic_feed_outlined,
              message:
                  'Még nincs friss tartalom. Nyiss meg egy profilt, mentsd el '
                  'egy videót, vagy frissítsd a Híreket.',
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              const gap = 10.0;
              final columns = constraints.maxWidth >= 900 ? 2 : 1;
              final width =
                  (constraints.maxWidth - gap * (columns - 1)) / columns;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final item in preview)
                    SizedBox(
                      width: width,
                      child: _FeedTile(
                        item: item,
                        now: now,
                        athletes: athletes,
                        onOpenAthlete: onOpenAthlete,
                        compact: true,
                      ),
                    ),
                ],
              );
            },
          ),
      ],
    );
  }
}

/// Egy hírfolyam-elem: típusikon, cím, sportoló-chip, relatív idő; a
/// kattintás a cikket / videót nyitja meg, eredménynél és eseménynél a
/// sportoló profilját.
class _FeedTile extends StatelessWidget {
  const _FeedTile({
    required this.item,
    required this.now,
    required this.athletes,
    required this.onOpenAthlete,
    this.compact = false,
  });

  final FeedItem item;
  final DateTime now;
  final List<Athlete> athletes;
  final ValueChanged<Athlete> onOpenAthlete;
  final bool compact;

  Athlete? _athlete(String name) =>
      athletes.where((athlete) => athlete.name == name).firstOrNull;

  void _open(BuildContext context) {
    final url = item.url;
    if ((item.type == FeedItemType.news || item.type == FeedItemType.video) &&
        url != null) {
      unawaited(openExternalUrl(context, url));
      return;
    }
    final athlete = _athlete(item.athlete);
    if (athlete != null) onOpenAthlete(athlete);
  }

  @override
  Widget build(BuildContext context) {
    final cb = context.cb;
    final (icon, color) = _feedVisual(cb, item);
    final iconColor = cb.readable(color);
    final when = formatRelativeTime(item.time, now: now);
    final opens = switch (item.type) {
      FeedItemType.news => 'cikk megnyitása',
      FeedItemType.video => 'videó megnyitása',
      _ => 'profil megnyitása',
    };
    final radius = BorderRadius.circular(16);
    return Semantics(
      button: true,
      label:
          '${item.type.label}, $when: ${item.title}. '
          '${item.athletes.join(', ')}. ${item.detail} – $opens',
      excludeSemantics: true,
      onTap: () => _open(context),
      child: FocusRing(
        borderRadius: radius,
        child: Material(
          color: cb.surface,
          borderRadius: radius,
          child: InkWell(
            key: ValueKey('feed-item-${item.id}'),
            borderRadius: radius,
            onTap: () => _open(context),
            child: Container(
              padding: EdgeInsets.all(compact ? 12 : 16),
              decoration: BoxDecoration(
                borderRadius: radius,
                border: Border.all(color: cb.border),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: cb.tint(iconColor, .14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, size: 22, color: iconColor),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: _body(context, cb, when)),
                  if (item.type == FeedItemType.result &&
                      item.outcome != MatchOutcome.unknown) ...[
                    const SizedBox(width: 10),
                    ResultBadge(item.outcome, score: item.score),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, CourtboardColors cb, String when) {
    final detail = [
      if (item.type == FeedItemType.result && item.score.isNotEmpty)
        normalizeScore(item.score),
      if (item.detail.isNotEmpty) item.detail,
    ].join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              item.type.label.toUpperCase(),
              style: context.text.labelSmall?.copyWith(
                color: cb.textMuted,
                fontWeight: FontWeight.w900,
              ),
            ),
            Tooltip(
              message: formatDateTime(item.time),
              child: Text(
                when,
                style: context.text.labelSmall?.copyWith(
                  color: item.type == FeedItemType.upcoming
                      ? cb.readable(cb.warning)
                      : cb.textMuted,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          item.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: context.text.titleMedium,
        ),
        if (detail.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            detail,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.bodySmall,
          ),
        ],
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final name in item.athletes.take(3))
              _AthleteChip(
                name: name,
                athlete: _athlete(name),
                onOpen: onOpenAthlete,
              ),
          ],
        ),
      ],
    );
  }
}

/// Kis sportoló-chip (a sportoló színével); kattintásra a profil nyílik.
class _AthleteChip extends StatelessWidget {
  const _AthleteChip({
    required this.name,
    required this.athlete,
    required this.onOpen,
  });

  final String name;
  final Athlete? athlete;
  final ValueChanged<Athlete> onOpen;

  @override
  Widget build(BuildContext context) {
    final cb = context.cb;
    final color = athlete?.accent ?? cb.accent;
    final radius = BorderRadius.circular(20);
    return Material(
      color: cb.surfaceMuted,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: athlete == null ? null : () => onOpen(athlete!),
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: cb.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(
                name,
                style: context.text.labelMedium?.copyWith(
                  color: cb.textPrimary,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
