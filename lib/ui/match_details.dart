part of '../main.dart';

// ---------------------------------------------------------------------------
// Idővonal (foci)
// ---------------------------------------------------------------------------

/// Lenyitható „Idővonal” egy focimeccshez: a beépített (OpenLigaDB)
/// idővonal, vagy lenyitáskor az ESPN-összefoglalóból.
class MatchTimelineExpander extends StatelessWidget {
  const MatchTimelineExpander({
    super.key,
    this.match,
    this.timeline,
    this.repository,
  }) : assert(match != null || timeline != null);

  final EspnMatchRef? match;
  final MatchTimeline? timeline;
  final MatchTimelineRepository? repository;

  /// Van-e megjeleníthető idővonal a sorhoz.
  static bool available({EspnMatchRef? match, MatchTimeline? timeline}) =>
      match != null || (timeline != null && timeline.events.isNotEmpty);

  @override
  Widget build(BuildContext context) => LazyDetailExpander<MatchTimeline>(
    key: ValueKey('timeline-${match?.eventId ?? timeline.hashCode}'),
    title: 'Idővonal',
    icon: Icons.timeline_rounded,
    loadingLabel: 'Idővonal betöltése…',
    load: () async =>
        timeline ??
        await (repository ?? MatchTimelineRepository()).timeline(match!),
    builder: (context, data) => MatchTimelineView(timeline: data),
  );
}

/// Egy mérkőzés eseményei időrendben: perc, ikon, játékos és csapat.
class MatchTimelineView extends StatelessWidget {
  const MatchTimelineView({super.key, required this.timeline});

  final MatchTimeline timeline;

  @override
  Widget build(BuildContext context) {
    final cb = context.cb;
    if (timeline.events.isEmpty) {
      return Text(
        timeline.finished
            ? 'Az összefoglaló nem tartalmaz gólt, lapot vagy cserét.'
            : 'Még nincs rögzített esemény.',
        style: context.text.bodySmall,
      );
    }
    final minuteWidth = MediaQuery.textScalerOf(context).scale(46);
    return Column(
      key: const Key('match-timeline'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final event in timeline.events)
          Semantics(
            label:
                '${event.minute} ${event.type.label}: ${event.player}'
                '${event.secondaryPlayer.isEmpty ? '' : ', le: ${event.secondaryPlayer}'}'
                '${event.team.isEmpty ? '' : ', ${event.team}'}',
            excludeSemantics: true,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: minuteWidth,
                    child: Text(
                      event.minute,
                      style: context.text.labelLarge?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: cb.textMuted,
                      ),
                    ),
                  ),
                  _TimelineIcon(type: event.type),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: event.player.isEmpty
                                    ? event.type.label
                                    : event.player,
                                style: context.text.bodyMedium?.copyWith(
                                  fontWeight: event.type.isGoal
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                ),
                              ),
                              if (event.type == TimelineEventType.penaltyGoal)
                                const TextSpan(text: ' (11-es)'),
                              if (event.type == TimelineEventType.ownGoal)
                                const TextSpan(text: ' (öngól)'),
                              if (event.score.isNotEmpty)
                                TextSpan(
                                  text: '  ${event.score}',
                                  style: context.text.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (event.secondaryPlayer.isNotEmpty ||
                            event.team.isNotEmpty)
                          Text(
                            [
                              if (event.secondaryPlayer.isNotEmpty)
                                'le: ${event.secondaryPlayer}',
                              if (event.team.isNotEmpty) event.team,
                            ].join(' · '),
                            style: context.text.bodySmall,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 2),
        Text(
          'Forrás: ${timeline.source}',
          style: context.text.labelSmall?.copyWith(color: cb.textMuted),
        ),
      ],
    );
  }
}

class _TimelineIcon extends StatelessWidget {
  const _TimelineIcon({required this.type});
  final TimelineEventType type;

  @override
  Widget build(BuildContext context) {
    final cb = context.cb;
    final (IconData icon, Color color, int turns) = switch (type) {
      TimelineEventType.goal ||
      TimelineEventType.penaltyGoal => (Icons.sports_soccer, cb.win, 0),
      TimelineEventType.ownGoal => (Icons.sports_soccer, cb.loss, 0),
      // Álló téglalap: a lap formája.
      TimelineEventType.yellowCard => (Icons.rectangle_rounded, cb.warning, 1),
      TimelineEventType.redCard => (Icons.rectangle_rounded, cb.error, 1),
      TimelineEventType.substitution => (
        Icons.swap_vert_rounded,
        cb.textMuted,
        0,
      ),
      TimelineEventType.other => (Icons.circle_outlined, cb.textMuted, 0),
    };
    return Tooltip(
      message: type.label,
      child: RotatedBox(
        quarterTurns: turns,
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Egymás elleni mérleg
// ---------------------------------------------------------------------------

/// Lenyitható egymás elleni mérleg egy közelgő eseményhez. Csapatsportnál
/// „Legutóbbi egymás elleni meccsek”, egyéni sportnál „Egymás elleni
/// mérleg”.
class HeadToHeadExpander extends StatelessWidget {
  const HeadToHeadExpander({
    super.key,
    required this.event,
    required this.config,
    this.team = '',
    this.repository,
  });

  final UpcomingEvent event;
  final SportsApiConfig config;

  /// A sportoló csapata (csapatsportnál).
  final String team;
  final HeadToHeadRepository? repository;

  static bool isTeamSport(String sport) =>
      const {'NBA', 'WNBA', 'NFL', 'Foci'}.contains(sport);

  /// Van-e értelme a mérlegnek ennél az eseménynél.
  static bool supports(UpcomingEvent event) =>
      event.opponent.trim().isNotEmpty &&
      const {
        'NBA',
        'WNBA',
        'NFL',
        'Foci',
        'Tenisz',
        'Darts',
      }.contains(event.sport);

  @override
  Widget build(BuildContext context) => LazyDetailExpander<HeadToHeadRecord>(
    key: ValueKey('h2h-${event.athleteName}-${event.opponent}'),
    title: isTeamSport(event.sport)
        ? 'Legutóbbi egymás elleni meccsek'
        : 'Egymás elleni mérleg',
    icon: Icons.compare_arrows_rounded,
    loadingLabel: 'Egymás elleni adatok betöltése…',
    load: () => (repository ?? HeadToHeadRepository()).forEvent(
      event,
      config: config,
      team: team,
    ),
    errorBuilder: (context, error) => error is HeadToHeadUnavailable
        ? Row(
            children: [
              Icon(Icons.info_outline, size: 18, color: context.cb.textMuted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(error.message, style: context.text.bodySmall),
              ),
            ],
          )
        : null,
    builder: (context, record) => HeadToHeadView(record: record),
  );
}

/// Az egymás elleni mérleg: összesítő és a legutóbbi meccsek.
class HeadToHeadView extends StatelessWidget {
  const HeadToHeadView({super.key, required this.record});

  final HeadToHeadRecord record;

  @override
  Widget build(BuildContext context) {
    final cb = context.cb;
    if (record.isEmpty) {
      return Text(
        'Nincs korábbi egymás elleni meccs az elérhető adatokban '
        '(${record.source}).',
        style: context.text.bodySmall,
      );
    }
    Widget count(String label, int value, Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: cb.tint(color, .12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$label $value',
        style: context.text.labelLarge?.copyWith(
          color: color,
          fontWeight: FontWeight.w900,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
    return Column(
      key: const Key('head-to-head'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label:
              'Mérleg ${record.opponent} ellen: ${record.wins} győzelem, '
              '${record.losses} vereség'
              '${record.draws > 0 ? ', ${record.draws} döntetlen' : ''}',
          excludeSemantics: true,
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('vs. ${record.opponent}', style: context.text.labelLarge),
              count('GY', record.wins, cb.win),
              if (record.draws > 0) count('D', record.draws, cb.draw),
              count('V', record.losses, cb.loss),
            ],
          ),
        ),
        const SizedBox(height: 8),
        for (final meeting in record.meetings)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                SizedBox(
                  width: MediaQuery.textScalerOf(context).scale(96),
                  child: Text(
                    formatShortDateWithYear(meeting.date),
                    style: context.text.bodySmall,
                  ),
                ),
                Expanded(
                  child: Text(
                    [
                      meeting.title,
                      if (meeting.competition.isNotEmpty) meeting.competition,
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodyMedium,
                  ),
                ),
                if (meeting.score.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text(
                    normalizeScore(meeting.score),
                    style: context.text.labelLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                SizedBox(
                  width: 36,
                  child:
                      MatchOutcome.parse(meeting.outcome) ==
                          MatchOutcome.unknown
                      ? null
                      : ResultBadge(
                          MatchOutcome.parse(meeting.outcome),
                          score: meeting.score,
                        ),
                ),
              ],
            ),
          ),
        if (record.note != null) ...[
          const SizedBox(height: 4),
          Text(
            '${record.note} Forrás: ${record.source}.',
            style: context.text.labelSmall?.copyWith(color: cb.textMuted),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Következő mérkőzés (profil)
// ---------------------------------------------------------------------------

/// A profil „Következő mérkőzés” sora a naptár gyorsítótárából (6 óra), a
/// lenyitható egymás elleni mérleggel. Esemény nélkül nem jelenik meg.
class _NextMatchCard extends StatefulWidget {
  const _NextMatchCard({
    super.key,
    required this.athlete,
    required this.config,
  });

  final Athlete athlete;
  final SportsApiConfig config;

  @override
  State<_NextMatchCard> createState() => _NextMatchCardState();
}

class _NextMatchCardState extends State<_NextMatchCard> {
  Future<AthleteEventsResult>? _future;

  UpcomingEventsTarget get _target => _calendarTargets([widget.athlete]).single;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _NextMatchCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.athlete.name != widget.athlete.name ||
        oldWidget.athlete.team != widget.athlete.team ||
        oldWidget.athlete.sport != widget.athlete.sport) {
      _load();
    }
  }

  void _load() {
    _future = UpcomingEventsRepository().fetchFor(
      _target,
      config: widget.config,
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<AthleteEventsResult>(
    future: _future,
    builder: (context, snapshot) {
      final event = snapshot.data?.events.firstOrNull;
      if (event == null) return const SizedBox.shrink();
      final cb = context.cb;
      final when = event.timeKnown
          ? '${formatMatchDate(event.start)} · ${formatTime(event.start)}'
          : '${formatMatchDate(event.start)} · időpont később';
      return Padding(
        padding: const EdgeInsets.only(top: 16),
        child: SurfaceCard(
          key: const Key('profile-next-match'),
          padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.event_outlined, size: 18, color: cb.textMuted),
                  const SizedBox(width: 8),
                  Text('KÖVETKEZŐ MÉRKŐZÉS', style: context.text.labelMedium),
                  const Spacer(),
                  StatusPill(event.source.toUpperCase()),
                ],
              ),
              const SizedBox(height: 10),
              Text(event.matchup, style: context.text.titleMedium),
              const SizedBox(height: 2),
              Text(
                [
                  when,
                  if (event.competition.isNotEmpty) event.competition,
                  if (event.venue != null && event.venue!.isNotEmpty)
                    event.venue!,
                ].join(' · '),
                style: context.text.bodySmall,
              ),
              if (HeadToHeadExpander.supports(event)) ...[
                const SizedBox(height: 6),
                HeadToHeadExpander(
                  event: event,
                  config: widget.config,
                  team: _target.team,
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}
