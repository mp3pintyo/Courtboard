part of '../main.dart';

class _FootballSeasonSummaryCard extends StatefulWidget {
  const _FootballSeasonSummaryCard({
    required this.athleteName,
    required this.teamName,
    required this.accent,
    required this.config,
  });

  final String athleteName;
  final String teamName;
  final Color accent;
  final SportsApiConfig config;

  @override
  State<_FootballSeasonSummaryCard> createState() =>
      _FootballSeasonSummaryCardState();
}

class _FootballSeasonSummaryCardState
    extends State<_FootballSeasonSummaryCard> {
  late Future<List<FootballSeasonStat>> _stats;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _stats = FootballSeasonRepository(
      widget.config,
    ).fetch(widget.athleteName, widget.teamName);
  }

  @override
  void didUpdateWidget(covariant _FootballSeasonSummaryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.athleteName != widget.athleteName ||
        oldWidget.teamName != widget.teamName ||
        oldWidget.config.apiSportsKey != widget.config.apiSportsKey) {
      _load();
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          const Text(
            'Szezon összesítő',
            style: TextStyle(
              fontSize: 27,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.2,
            ),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Szezonadatok frissítése',
            onPressed: () => setState(_load),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      const SizedBox(height: 12),
      FutureBuilder<List<FootballSeasonStat>>(
        future: _stats,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Padding(
              padding: EdgeInsets.all(18),
              child: CircularProgressIndicator(),
            );
          }
          if (snapshot.hasError) {
            return _FootballSeasonMessage(
              message: 'Nem érkezett friss szezonadat: ${snapshot.error}',
              accent: widget.accent,
            );
          }
          final stats = snapshot.data ?? const [];
          if (stats.isEmpty) {
            return _FootballSeasonMessage(
              message: 'Az aktuális vagy előző szezonhoz nincs elérhető adat.',
              accent: widget.accent,
            );
          }
          return Column(
            children: stats
                .map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _FootballSeasonStatCard(
                      stat: item,
                      accent: widget.accent,
                    ),
                  ),
                )
                .toList(),
          );
        },
      ),
    ],
  );
}

class _FootballSeasonMessage extends StatelessWidget {
  const _FootballSeasonMessage({required this.message, required this.accent});
  final String message;
  final Color accent;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: _paper,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: accent.withValues(alpha: .35)),
    ),
    child: Text(message, style: const TextStyle(color: _muted)),
  );
}

class _FootballSeasonStatCard extends StatelessWidget {
  const _FootballSeasonStatCard({required this.stat, required this.accent});
  final FootballSeasonStat stat;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      ('ÉRTÉKELÉS ÁTLAG', stat.rating?.toStringAsFixed(2) ?? '—'),
      ('MÉRKŐZÉS', _format(stat.appearances)),
      ('GÓL', _format(stat.goals)),
      ('GÓLPASSZ', _format(stat.assists)),
      ('SÁRGA LAP', _format(stat.yellowCards)),
      ('PIROS LAP', _format(stat.redCards)),
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _paper,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: accent.withValues(alpha: .42)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stat.team,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${stat.competition} · ${stat.season}',
                      style: const TextStyle(color: _muted),
                    ),
                  ],
                ),
              ),
              _Pill(text: stat.source.toUpperCase(), color: accent),
            ],
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 900 ? 6 : 3;
              final width =
                  (constraints.maxWidth - (columns - 1) * 10) / columns;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: metrics
                    .map(
                      (metric) => Container(
                        width: width,
                        padding: const EdgeInsets.all(13),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: .16),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              metric.$1,
                              style: const TextStyle(
                                color: _muted,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 7),
                            Text(
                              metric.$2,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
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
  }

  static String _format(int? value) => value?.toString() ?? '—';
}

class _FootballDataCard extends StatefulWidget {
  const _FootballDataCard({
    required this.teamName,
    required this.accent,
    required this.config,
  });
  final String teamName;
  final Color accent;
  final SportsApiConfig config;
  @override
  State<_FootballDataCard> createState() => _FootballDataCardState();
}

class _FootballDataCardState extends State<_FootballDataCard> {
  late Future<List<FootballGame>> _games;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _games = FootballDataRepository(
      SportsApiClient(config: widget.config),
    ).fetchRecentTeamGames(widget.teamName);
  }

  @override
  void didUpdateWidget(covariant _FootballDataCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.teamName != widget.teamName ||
        oldWidget.config.footballDataKey != widget.config.footballDataKey) {
      _load();
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<FootballGame>>(
    future: _games,
    builder: (context, snapshot) => Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _paper,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: widget.accent.withValues(alpha: .7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CSAPATMÉRKŐZÉSEK · ÉLŐ ADATFORRÁS',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
          ),
          const SizedBox(height: 5),
          Text(
            '${widget.teamName} · valódi eredmények',
            style: const TextStyle(color: _muted, fontSize: 11),
          ),
          const SizedBox(height: 12),
          if (snapshot.connectionState == ConnectionState.waiting)
            const Text('Mérkőzések lekérése…')
          else if (snapshot.hasError)
            Text(
              'A mérkőzések lekérése sikertelen: ${snapshot.error}',
              style: const TextStyle(color: _muted),
            )
          else if (!snapshot.hasData || snapshot.data!.isEmpty)
            const Text(
              'Nem található friss vagy közelgő csapatmérkőzés.',
              style: TextStyle(color: _muted),
            )
          else
            ...snapshot.data!.map(
              (game) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${game.date.year}.${game.date.month.toString().padLeft(2, '0')}.${game.date.day.toString().padLeft(2, '0')} · vs. ${game.opponent}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text(
                      game.score,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      game.result == FootballResult.win
                          ? 'GY'
                          : game.result == FootballResult.loss
                          ? 'V'
                          : game.result == FootballResult.draw
                          ? 'D'
                          : 'KÖV.',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: game.result == FootballResult.win
                            ? _olive
                            : game.result == FootballResult.loss
                            ? const Color(0xFFB44646)
                            : _muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class _FootballDataPlayerCard extends StatefulWidget {
  const _FootballDataPlayerCard({
    required this.athleteName,
    required this.teamName,
    required this.accent,
    required this.config,
  });

  final String athleteName;
  final String teamName;
  final Color accent;
  final SportsApiConfig config;

  @override
  State<_FootballDataPlayerCard> createState() =>
      _FootballDataPlayerCardState();
}

class _FootballDataPlayerCardState extends State<_FootballDataPlayerCard> {
  late Future<FootballDataPlayerProfile?> _profile;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _profile = FootballDataPlayerRepository(
      SportsApiClient(config: widget.config),
    ).findPlayer(widget.athleteName, widget.teamName);
  }

  @override
  void didUpdateWidget(covariant _FootballDataPlayerCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.athleteName != widget.athleteName ||
        oldWidget.teamName != widget.teamName ||
        oldWidget.config.footballDataKey != widget.config.footballDataKey) {
      _load();
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) => FutureBuilder<FootballDataPlayerProfile?>(
    future: _profile,
    builder: (context, snapshot) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _paper,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: widget.accent.withValues(alpha: .45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'JÁTÉKOSPROFIL · FOOTBALL-DATA.ORG FREE',
                style: TextStyle(
                  color: widget.accent,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Játékosadat frissítése',
                onPressed: () => setState(_load),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          if (snapshot.connectionState != ConnectionState.done)
            const Padding(
              padding: EdgeInsets.all(12),
              child: CircularProgressIndicator(),
            )
          else if (snapshot.hasError)
            Text(
              'Football-data.org játékoskeresési hiba: ${snapshot.error}',
              style: const TextStyle(color: _muted),
            )
          else if (snapshot.data == null)
            const Text(
              'A játékos nem található az ingyenes versenysorozatok aktuális kereteiben.',
              style: TextStyle(color: _muted),
            )
          else
            _FootballDataPlayerFacts(
              profile: snapshot.data!,
              accent: widget.accent,
            ),
        ],
      ),
    ),
  );
}

class _FootballDataPlayerFacts extends StatelessWidget {
  const _FootballDataPlayerFacts({required this.profile, required this.accent});

  final FootballDataPlayerProfile profile;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final facts = [
      ('CSAPAT', profile.team),
      ('POSZT', profile.position ?? '—'),
      ('NEMZETISÉG', profile.nationality ?? '—'),
      ('SZÜLETÉSI DÁTUM', profile.dateOfBirth ?? '—'),
      ('MEZSZÁM', profile.shirtNumber?.toString() ?? '—'),
      ('PLAYER ID', profile.id.toString()),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          profile.name,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: facts
              .map(
                (fact) => Container(
                  width: 180,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fact.$1,
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        fact.$2,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _LigaFCard extends StatefulWidget {
  const _LigaFCard({required this.accent});
  final Color accent;

  @override
  State<_LigaFCard> createState() => _LigaFCardState();
}

class _LigaFCardState extends State<_LigaFCard> {
  late Future<List<LigaFGame>> _games;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _games = LigaFRepository().recentBarcelonaGames();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<LigaFGame>>(
    future: _games,
    builder: (context, snapshot) => Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _paper,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: widget.accent.withValues(alpha: .7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.sports_soccer, color: widget.accent),
              const SizedBox(width: 9),
              const Expanded(
                child: Text(
                  'FC BARCELONA FEMENÍ · LIGA F',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: .5,
                  ),
                ),
              ),
              const _Pill(text: 'ESPN · esp.w.1', color: _moss),
              IconButton(
                tooltip: 'Újratöltés',
                onPressed: () => setState(_load),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 5),
          const Text(
            'Valós női Barcelona csapateredmények; nem a férfi FC Barcelona feedje.',
            style: TextStyle(fontSize: 11, color: _muted),
          ),
          const SizedBox(height: 14),
          if (snapshot.connectionState != ConnectionState.done)
            const CircularProgressIndicator()
          else if (snapshot.hasError)
            Text(
              'ESPN Liga F hiba: ${snapshot.error}',
              style: const TextStyle(color: _muted),
            )
          else if (snapshot.data == null || snapshot.data!.isEmpty)
            const Text(
              'Nincs befejezett Barcelona-meccs ebben az évben.',
              style: TextStyle(color: _muted),
            )
          else
            LigaFGameList(games: snapshot.data!, accent: widget.accent),
        ],
      ),
    ),
  );
}

class LigaFGameList extends StatelessWidget {
  const LigaFGameList({super.key, required this.games, required this.accent});
  final List<LigaFGame> games;
  final Color accent;

  @override
  Widget build(BuildContext context) => Column(
    children: games
        .map(
          (game) => _MatchRow(
            accent: accent,
            match: MatchLine(
              '${game.date.year}.${game.date.month.toString().padLeft(2, '0')}.${game.date.day.toString().padLeft(2, '0')}',
              game.opponent,
              game.result,
              game.score,
              game.home ? 'HAZAI · LIGA F' : 'IDEGEN · LIGA F',
              '—',
            ),
          ),
        )
        .toList(),
  );
}
