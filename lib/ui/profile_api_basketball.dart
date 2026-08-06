part of '../main.dart';

class _ApiSportsCard extends StatefulWidget {
  const _ApiSportsCard({
    required this.sport,
    required this.athleteName,
    required this.teamName,
    required this.accent,
    required this.config,
  });
  final String sport;
  final String athleteName;
  final String teamName;
  final Color accent;
  final SportsApiConfig config;
  @override
  State<_ApiSportsCard> createState() => _ApiSportsCardState();
}

class _ApiSportsCardState extends State<_ApiSportsCard> {
  late Future<Object> _data;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final repo = ApiSportsRepository(widget.config.apiSportsKey);
    _data = switch (widget.sport) {
      'Foci' => repo.footballRecent(widget.teamName),
      'NBA' => MultiProviderAthleteRepository(
        widget.config,
      ).fetchNbaPlayer(widget.athleteName),
      _ => repo.nflPlayer(widget.athleteName),
    };
  }

  @override
  void didUpdateWidget(covariant _ApiSportsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.athleteName != widget.athleteName ||
        oldWidget.teamName != widget.teamName ||
        oldWidget.config.apiSportsKey != widget.config.apiSportsKey ||
        oldWidget.config.balldontlieKey != widget.config.balldontlieKey) {
      _load();
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Object>(
    future: _data,
    builder: (context, snapshot) => Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _paper,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: widget.accent.withValues(alpha: .35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                widget.sport == 'NBA'
                    ? 'VALÓS NBA ADAT · EGYESÍTETT FORRÁSOK'
                    : 'VALÓS ${widget.sport.toUpperCase()} ADAT · API-SPORTS',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: widget.accent,
                ),
              ),
              const Spacer(),
              IconButton(
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
            Text('${snapshot.error}', style: const TextStyle(color: Colors.red))
          else if (snapshot.data is List<ApiSportsGame>)
            ...((snapshot.data as List<ApiSportsGame>).map(
              (game) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Text(
                  '${game.date.year}.${game.date.month.toString().padLeft(2, '0')}.${game.date.day.toString().padLeft(2, '0')} · ${game.opponent} · ${game.score} · ${game.result}',
                ),
              ),
            ))
          else if (snapshot.data is UnifiedAthleteData)
            UnifiedAthleteFacts(
              data: snapshot.data as UnifiedAthleteData,
              accent: widget.accent,
            )
          else
            Text(
              '${widget.athleteName}: a szolgáltató nem adott megjeleníthető adatot.',
            ),
        ],
      ),
    ),
  );
}

class _NbaSeasonSummaryCard extends StatefulWidget {
  const _NbaSeasonSummaryCard({
    required this.athleteName,
    required this.accent,
  });

  final String athleteName;
  final Color accent;

  @override
  State<_NbaSeasonSummaryCard> createState() => _NbaSeasonSummaryCardState();
}

class _NbaSeasonSummaryCardState extends State<_NbaSeasonSummaryCard> {
  late Future<BasketballSeasonStat?> _summary;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _summary = BasketballReferenceRepository().seasonSummary(
      widget.athleteName,
    );
  }

  @override
  void didUpdateWidget(covariant _NbaSeasonSummaryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.athleteName != widget.athleteName) _load();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          const Expanded(
            child: Text(
              'Szezon összesítő',
              style: TextStyle(
                fontSize: 27,
                fontWeight: FontWeight.w900,
                letterSpacing: -1.2,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Szezonadatok frissítése',
            onPressed: () => setState(_load),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      const SizedBox(height: 12),
      FutureBuilder<BasketballSeasonStat?>(
        future: _summary,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return _BasketballSeasonMessage(
              message: 'NBA szezonadatok betöltése…',
              accent: widget.accent,
              loading: true,
            );
          }
          if (snapshot.hasError) {
            return _BasketballSeasonMessage(
              message:
                  'A friss NBA szezonösszesítő most nem érhető el: ${snapshot.error}',
              accent: widget.accent,
            );
          }
          final summary = snapshot.data;
          if (summary == null) {
            return _BasketballSeasonMessage(
              message: 'Ehhez a játékoshoz nincs friss NBA szezonadat.',
              accent: widget.accent,
            );
          }
          return BasketballSeasonSummaryFacts(
            summary: summary,
            accent: widget.accent,
          );
        },
      ),
      const SizedBox(height: 28),
    ],
  );
}

class _BasketballSeasonMessage extends StatelessWidget {
  const _BasketballSeasonMessage({
    required this.message,
    required this.accent,
    this.loading = false,
  });

  final String message;
  final Color accent;
  final bool loading;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: _paper,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: accent.withValues(alpha: .35)),
    ),
    child: Row(
      children: [
        if (loading) ...[
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Text(message, style: const TextStyle(color: _muted)),
        ),
      ],
    ),
  );
}

class BasketballSeasonSummaryFacts extends StatelessWidget {
  const BasketballSeasonSummaryFacts({
    super.key,
    required this.summary,
    required this.accent,
  });

  final BasketballSeasonStat summary;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      ('MÉRKŐZÉS', '${summary.games}'),
      ('PERC / MECCS', _decimal(summary.minutesPerGame)),
      ('PONT / MECCS', _decimal(summary.pointsPerGame)),
      ('LEPATTANÓ / MECCS', _decimal(summary.reboundsPerGame)),
      ('ASSZISZT / MECCS', _decimal(summary.assistsPerGame)),
      ('LABDASZERZÉS / MECCS', _decimal(summary.stealsPerGame)),
      ('ELADOTT LABDA / MECCS', _decimal(summary.turnoversPerGame)),
      ('FG%', _percentage(summary.fieldGoalPercentage)),
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: _paper,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: accent.withValues(alpha: .45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      summary.team.isEmpty ? summary.league : summary.team,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${summary.league} · ${summary.season}',
                      style: const TextStyle(color: _muted),
                    ),
                  ],
                ),
              ),
              _Pill(text: summary.source.toUpperCase(), color: accent),
            ],
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 1000 ? 8 : 4;
              final width =
                  (constraints.maxWidth - (columns - 1) * 10) / columns;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: metrics
                    .map(
                      (metric) => SizedBox(
                        width: width,
                        child: _BasketballSeasonMetric(
                          label: metric.$1,
                          value: metric.$2,
                          accent: accent,
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

  static String _decimal(double? value) =>
      value == null ? '—' : value.toStringAsFixed(1);
  static String _percentage(double? value) =>
      value == null ? '—' : '${value.toStringAsFixed(1)}%';
}

class _BasketballSeasonMetric extends StatelessWidget {
  const _BasketballSeasonMetric({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 90),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: accent.withValues(alpha: .09),
      borderRadius: BorderRadius.circular(13),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: _muted,
            fontSize: 9,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          value,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
        ),
      ],
    ),
  );
}
