import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:courtboard/shared/components.dart';
import 'package:courtboard/shared/format.dart';
import 'package:courtboard/data/espn_athletes.dart';
import 'package:courtboard/features/profile/profile_form.dart';
import 'package:courtboard/features/profile/profile_providers.dart';
import 'package:courtboard/domain/sport.dart';
import 'package:courtboard/features/profile/sport_profile_spec.dart';

/// NFL-játékos meccsnaplója (ESPN, kulcs nélkül, 6 órás gyorsítótár):
/// szezonösszesítő, szerepkör szerinti formagörbe és legutóbbi meccsek. Az
/// adat a [nflGameLogProvider]-ből jön.
class NflPlayerCard extends ConsumerWidget {
  const NflPlayerCard({
    super.key,
    required this.athleteName,
    required this.accent,
  });

  final String athleteName;
  final Color accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      AsyncDataSourceCard<EspnGameLog?>(
        title: 'Játékos-meccsnapló',
        provider: 'ESPN',
        subtitle: 'Szezonösszesítő, formagörbe és a legutóbbi meccsek.',
        icon: Icons.sports_football,
        accent: accent,
        value: ref.watch(nflGameLogProvider(athleteName)),
        onRefresh: () => unawaited(
          ref.read(nflGameLogProvider(athleteName).notifier).refresh(),
        ),
        refreshTooltip: 'Meccsnapló frissítése',
        loadingLabel: 'NFL-meccsnapló betöltése…',
        errorPrefix: 'Az ESPN NFL-meccsnaplója most nem érhető el. ',
        emptyMessage:
            'Az ESPN nem talált ilyen nevű NFL-játékost, vagy még nincs '
            'lejátszott meccse ebben a szezonban.',
        emptyIcon: Icons.person_search_outlined,
        isEmpty: (log) => log == null || log.games.isEmpty,
        freshness: (log) => log?.fetchedAt == null
            ? null
            : DataFreshness(
                log!.fetchedAt!,
                fromCache: log.fromCache,
                stale: log.stale,
              ),
        builder: (context, log) => NflGameLogView(log: log!, accent: accent),
      );
}

/// Az NFL-meccsnapló nézete (külön osztály, hogy tesztelhető legyen).
class NflGameLogView extends StatelessWidget {
  const NflGameLogView({super.key, required this.log, required this.accent});

  final EspnGameLog log;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final athlete = log.athlete;
    final identity = [
      if (athlete.team.isNotEmpty) athlete.team,
      if (athlete.position.isNotEmpty) athlete.position,
      if (athlete.jersey.isNotEmpty) '#${athlete.jersey}',
    ].join(' · ');
    return Column(
      key: const Key('nfl-player-log'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SeasonSummaryPanel(
          title: identity.isEmpty ? athlete.displayName : identity,
          subtitle:
              'NFL ${log.season} · alapszakasz'
              '${log.regularSeason.isEmpty ? '' : ' · ${log.regularSeason.length} meccs'}',
          source: 'ESPN',
          metrics: [
            for (final (label, value, digits) in nflSeasonLines(log))
              (
                label,
                digits == 0
                    ? formatInt(value)
                    : formatDecimal(value, digits: digits),
              ),
          ],
        ),
        SportFormChart(
          kind: SportProfileSpec.formChartOf(Sport.nfl),
          data: NflFormData(log),
          accent: accent,
        ),
        const SizedBox(height: 22),
        SubsectionLabel(
          'LEGUTÓBBI MECCSEK · ESPN',
          icon: Icons.sports_football,
          color: accent,
        ),
        for (final game in log.games.take(5))
          MatchRow(
            date: game.date,
            venue: game.homeAway == 'away' ? 'Idegen' : 'Hazai',
            opponent: game.opponent,
            subtitle: [
              nflGameSummary(game),
              if (game.phase == EspnSeasonPhase.postseason)
                game.note.isEmpty ? 'Rájátszás' : game.note,
            ].where((part) => part.isNotEmpty).join(' · '),
            score: game.score.isEmpty ? null : game.score,
            outcome: MatchOutcome.parse(game.outcome),
          ),
      ],
    );
  }
}
