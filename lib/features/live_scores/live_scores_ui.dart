import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:courtboard/shared/common_ui.dart';
import 'package:courtboard/shared/components.dart';
import 'package:courtboard/shared/format.dart';
import 'package:courtboard/shared/theme/courtboard_theme.dart';
import 'package:courtboard/data/live_scores.dart';
import 'package:courtboard/data/match_timeline.dart';
import 'package:courtboard/data/providers.dart';
import 'package:courtboard/data/upcoming_events.dart';
import 'package:courtboard/features/profile/match_details.dart';

/// Élő eredmények lekérdezése látható oldalon: az első betöltés után
/// [liveInterval] (30 mp) időközönként, ha van zajló vagy hamarosan kezdődő
/// meccs, különben [idleInterval] (5 perc) múlva. Szünetel, ha az ablak
/// nem látható (tálca, kis méret), vagy az oldal nincs a képernyőn
/// ([TickerMode]); a [dispose] minden időzítőt leállít.
mixin _LiveScoresPolling<T extends StatefulWidget> on State<T> {
  static const liveInterval = Duration(seconds: 30);
  static const idleInterval = Duration(minutes: 5);

  Timer? _pollTimer;
  AppLifecycleListener? _lifecycle;
  bool _appVisible = true;
  bool _polling = false;
  LiveScoresResult? liveResult;
  DateTime? liveUpdatedAt;

  LiveScoresRepository get liveRepository;
  List<UpcomingEventsTarget> get liveTargets;

  void startLivePolling() {
    _lifecycle = AppLifecycleListener(onStateChange: _lifecycleChanged);
    // Az első lekérés az első képkocka után (az initState-ben még nem
    // olvasható a TickerMode).
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_poll()));
  }

  void restartLivePolling() {
    _pollTimer?.cancel();
    unawaited(_poll());
  }

  void _lifecycleChanged(AppLifecycleState state) {
    final visible =
        state == AppLifecycleState.resumed ||
        state == AppLifecycleState.inactive;
    if (visible == _appVisible) return;
    _appVisible = visible;
    if (visible) {
      unawaited(_poll());
    } else {
      _pollTimer?.cancel();
      _pollTimer = null;
    }
  }

  Future<void> _poll({bool force = false}) async {
    _pollTimer?.cancel();
    _pollTimer = null;
    if (!mounted || !_appVisible) return;
    final targets = liveTargets;
    if (targets.isEmpty) {
      if (liveResult != null) setState(() => liveResult = null);
      return;
    }
    // Rejtett oldal (TickerMode ki): nem kérdezünk, csak újraütemezünk.
    if (!TickerMode.valuesOf(context).enabled) {
      _schedule(idle: liveResult?.hasPending != true);
      return;
    }
    if (_polling) return;
    _polling = true;
    try {
      final result = await liveRepository.forTargets(targets, force: force);
      if (!mounted) return;
      setState(() {
        liveResult = result;
        liveUpdatedAt = DateTime.now();
      });
    } finally {
      _polling = false;
    }
    if (mounted) _schedule(idle: !_needsFastPolling(liveResult));
  }

  bool _needsFastPolling(LiveScoresResult? result) {
    if (result == null) return false;
    if (result.hasLive) return true;
    final now = DateTime.now();
    return result.games.any(
      (game) =>
          game.game.state == LiveGameState.scheduled &&
          game.game.start.difference(now) < const Duration(minutes: 20),
    );
  }

  void _schedule({required bool idle}) {
    _pollTimer?.cancel();
    if (!mounted || !_appVisible) return;
    _pollTimer = Timer(
      idle ? idleInterval : liveInterval,
      () => unawaited(_poll()),
    );
  }

  void stopLivePolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _lifecycle?.dispose();
    _lifecycle = null;
  }
}

/// Egy meccs eredményjelzője: csapatok, pontszám, állapot.
class LiveGameScoreboard extends StatelessWidget {
  const LiveGameScoreboard({
    super.key,
    required this.game,
    this.compact = false,
  });

  final AthleteLiveGame game;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final cb = context.cb;
    final live = game.game.isLive;
    final scoreStyle =
        (compact ? context.text.titleLarge : context.text.headlineMedium)
            ?.copyWith(
              fontWeight: FontWeight.w900,
              fontFeatures: const [FontFeature.tabularFigures()],
            );
    Widget team(LiveTeam team, {required bool own, required TextAlign align}) =>
        Expanded(
          child: Text(
            compact && team.abbreviation.isNotEmpty
                ? team.abbreviation
                : team.name,
            textAlign: align,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.text.titleSmall?.copyWith(
              fontWeight: own ? FontWeight.w900 : FontWeight.w600,
            ),
          ),
        );
    final home = game.game.home;
    final away = game.game.away;
    return Semantics(
      container: true,
      label:
          '${live
              ? 'Élő'
              : game.game.isFinished
              ? 'Befejezett'
              : 'Mai'} mérkőzés: '
          '${home.name} ${home.score}, ${away.name} ${away.score}. '
          '${game.game.status}',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              team(home, own: game.ownIsHome, align: TextAlign.left),
              const SizedBox(width: 10),
              Text(
                home.score.isEmpty
                    ? formatTime(game.game.start)
                    : '${home.score} – ${away.score}',
                style: home.score.isEmpty
                    ? context.text.titleMedium
                    : scoreStyle,
              ),
              const SizedBox(width: 10),
              team(away, own: !game.ownIsHome, align: TextAlign.right),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (live) ...[
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: cb.live,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  game.game.status,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.labelLarge?.copyWith(
                    color: live ? cb.live : cb.textMuted,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A nyitóoldal „Élő” sávja: csak akkor látszik, ha egy követett sportoló
/// csapatának meccse éppen zajlik.
class LiveNowStrip extends ConsumerStatefulWidget {
  const LiveNowStrip({super.key, required this.targets, required this.onOpen});

  final List<UpcomingEventsTarget> targets;
  final ValueChanged<String> onOpen;

  @override
  ConsumerState<LiveNowStrip> createState() => _LiveNowStripState();
}

class _LiveNowStripState extends ConsumerState<LiveNowStrip>
    with _LiveScoresPolling<LiveNowStrip> {
  @override
  LiveScoresRepository get liveRepository =>
      ref.read(liveScoresRepositoryProvider);

  @override
  List<UpcomingEventsTarget> get liveTargets => widget.targets;

  @override
  void initState() {
    super.initState();
    startLivePolling();
  }

  @override
  void didUpdateWidget(covariant LiveNowStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    final before = oldWidget.targets;
    final after = widget.targets;
    final same =
        before.length == after.length &&
        [
          for (var i = 0; i < before.length; i++) before[i] == after[i],
        ].every((equal) => equal);
    if (!same) restartLivePolling();
  }

  @override
  void dispose() {
    stopLivePolling();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final live = liveResult?.live ?? const <AthleteLiveGame>[];
    if (live.isEmpty) return const SizedBox.shrink();
    final cb = context.cb;
    final sources = {for (final game in live) game.game.source}.join(', ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Container(
        key: const Key('dashboard-live-strip'),
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
        decoration: BoxDecoration(
          color: cb.tint(cb.live, .06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cb.tint(cb.live, .45)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const StatusPill(
                  'ÉLŐ',
                  tone: StatusTone.live,
                  icon: Icons.fiber_manual_record,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      live.length == 1
                          ? 'Most zajlik'
                          : '${live.length} mérkőzés zajlik',
                      style: context.text.titleMedium,
                    ),
                  ),
                ),
                Text(
                  '$sources · 30 mp-enként',
                  style: context.text.labelSmall?.copyWith(color: cb.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = (constraints.maxWidth / 340).floor().clamp(
                  1,
                  3,
                );
                final width =
                    (constraints.maxWidth - (columns - 1) * 12) / columns;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final game in live)
                      SizedBox(
                        width: width,
                        child: Material(
                          color: cb.surface,
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            key: ValueKey('live-game-${game.athleteName}'),
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => widget.onOpen(game.athleteName),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                14,
                                10,
                                14,
                                10,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${game.athleteName} · ${game.game.sport}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: context.text.labelMedium?.copyWith(
                                      color: cb.textMuted,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  LiveGameScoreboard(game: game, compact: true),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// A profil „Élő mérkőzés” kártyája: a csapat zajló vagy ma befejezett
/// meccse. Ha nincs ilyen, nem jelenik meg.
class LiveMatchCard extends ConsumerStatefulWidget {
  const LiveMatchCard({super.key, required this.target});

  final UpcomingEventsTarget target;

  static bool supports(UpcomingEventsTarget target) =>
      LiveFeed.forTarget(target) != null && target.team.trim().isNotEmpty;

  @override
  ConsumerState<LiveMatchCard> createState() => _LiveMatchCardState();
}

class _LiveMatchCardState extends ConsumerState<LiveMatchCard>
    with _LiveScoresPolling<LiveMatchCard> {
  @override
  LiveScoresRepository get liveRepository =>
      ref.read(liveScoresRepositoryProvider);

  @override
  List<UpcomingEventsTarget> get liveTargets => [widget.target];

  @override
  void initState() {
    super.initState();
    startLivePolling();
  }

  @override
  void didUpdateWidget(covariant LiveMatchCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.target != widget.target) restartLivePolling();
  }

  @override
  void dispose() {
    stopLivePolling();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final result = liveResult;
    final games = result?.forAthlete(widget.target.name) ?? const [];
    // Zajló meccs, különben a ma befejezett (kezdés előtti nem: az a
    // „Következő mérkőzés” sorban látszik).
    final game =
        games.where((game) => game.game.isLive).firstOrNull ??
        games.where((game) => game.game.isFinished).firstOrNull;
    if (game == null) return const SizedBox.shrink();
    final cb = context.cb;
    final live = game.game.isLive;
    final updated = liveUpdatedAt;
    final soccerMatch = game.game.espnEventId == null
        ? null
        : EspnMatchRef(
            eventId: game.game.espnEventId!,
            league: game.game.espnLeague ?? 'all',
          );
    final feed = LiveFeed.forTarget(widget.target);
    final note = [
      if (feed != null && result?.errors[feed] != null) result!.errors[feed]!,
      ...?result?.notes,
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Container(
        key: const Key('profile-live-match'),
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
        decoration: BoxDecoration(
          color: live ? cb.tint(cb.live, .06) : cb.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: live ? cb.tint(cb.live, .5) : cb.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    live ? 'Élő mérkőzés' : 'Mai mérkőzés · vége',
                    style: context.text.titleLarge,
                  ),
                ),
                StatusPill(
                  live ? 'ÉLŐ' : 'VÉGE',
                  tone: live ? StatusTone.live : StatusTone.neutral,
                  icon: live ? Icons.fiber_manual_record : Icons.flag_outlined,
                ),
                const SizedBox(width: 8),
                StatusPill(game.game.source.toUpperCase()),
                IconButton(
                  tooltip: 'Élő eredmény frissítése',
                  onPressed: () => unawaited(_poll(force: true)),
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LiveGameScoreboard(game: game),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    [
                      if (updated != null) 'Frissítve ${formatTime(updated)}',
                      if (live) 'látható oldalon 30 mp-enként frissül',
                    ].join(' · '),
                    style: context.text.labelSmall?.copyWith(
                      color: cb.textMuted,
                    ),
                  ),
                ),
                if (game.game.url != null)
                  TextButton.icon(
                    onPressed: () =>
                        unawaited(openExternalUrl(context, game.game.url!)),
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: const Text('Részletek'),
                  ),
              ],
            ),
            for (final text in note) CourtboardNote(text),
            if (soccerMatch != null) MatchTimelineExpander(match: soccerMatch),
          ],
        ),
      ),
    );
  }
}
