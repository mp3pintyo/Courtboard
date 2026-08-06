part of '../main.dart';

class _WnbaWehoopCard extends StatefulWidget {
  const _WnbaWehoopCard({required this.athleteName, required this.accent});
  final String athleteName;
  final Color accent;

  @override
  State<_WnbaWehoopCard> createState() => _WnbaWehoopCardState();
}

class _WnbaWehoopCardState extends State<_WnbaWehoopCard> {
  late Future<List<WnbaGameLog>> _games;
  int _range = 5;

  @override
  void initState() {
    super.initState();
    _games = WnbaWehoopRepository().recentGames(widget.athleteName);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<WnbaGameLog>>(
    future: _games,
    builder: (context, snapshot) {
      final child = switch (snapshot.connectionState) {
        ConnectionState.waiting => const Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text('WNBA box score-ok letöltése és helyi gyorsítótárazása…'),
          ],
        ),
        _ when snapshot.hasError => const Text(
          'A wehoop WNBA-adat most nem érhető el. A cache vagy a hálózat később újrapróbálható.',
          style: TextStyle(color: _muted),
        ),
        _ when snapshot.data == null || snapshot.data!.isEmpty => const Text(
          'Ehhez a játékoshoz nem érkezett 2026-os wehoop box score rekord.',
          style: TextStyle(color: _muted),
        ),
        _ => _WnbaLiveData(
          games: snapshot.data!,
          range: _range,
          accent: widget.accent,
          onRange: (value) => setState(() => _range = value),
        ),
      };
      return Container(
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
                Icon(Icons.data_usage_rounded, color: widget.accent),
                const SizedBox(width: 9),
                const Expanded(
                  child: Text(
                    'VALÓS WNBA MECCSNAPLÓ',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      letterSpacing: .6,
                    ),
                  ),
                ),
                const _Pill(text: 'WEHOOP · ESPN', color: _olive),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'SportsDataverse / wehoop WNBA player boxscores · CC BY 4.0',
              style: TextStyle(fontSize: 11, color: _muted),
            ),
            const SizedBox(height: 15),
            child,
          ],
        ),
      );
    },
  );
}

class _WnbaBasketballReferenceCard extends StatefulWidget {
  const _WnbaBasketballReferenceCard({
    required this.athleteName,
    required this.accent,
  });

  final String athleteName;
  final Color accent;

  @override
  State<_WnbaBasketballReferenceCard> createState() =>
      _WnbaBasketballReferenceCardState();
}

class _WnbaBasketballReferenceCardState
    extends State<_WnbaBasketballReferenceCard> {
  late Future<List<NbaGameLog>> _games;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _games = BasketballReferenceRepository().recentGames(
      widget.athleteName,
      league: 'wnba',
    );
  }

  @override
  void didUpdateWidget(covariant _WnbaBasketballReferenceCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.athleteName != widget.athleteName) _load();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<NbaGameLog>>(
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
              const Expanded(
                child: Text(
                  'WNBA KIEGÉSZÍTŐ ADATFORRÁS',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: .6,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Újratöltés',
                onPressed: () => setState(_load),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const Text(
            'A wehoop mellett közvetlen Basketball Reference játékos-meccsnapló.',
            style: TextStyle(fontSize: 11, color: _muted),
          ),
          const SizedBox(height: 15),
          if (snapshot.connectionState != ConnectionState.done)
            const Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Text('Basketball Reference WNBA-adatok letöltése…'),
              ],
            )
          else if (snapshot.hasError)
            Text(
              'Basketball Reference WNBA hiba: ${snapshot.error}',
              style: const TextStyle(color: _muted),
            )
          else
            BasketballReferenceGameList(
              games: snapshot.data ?? const [],
              accent: widget.accent,
              league: 'WNBA',
            ),
        ],
      ),
    ),
  );
}

class _WnbaRapidApiCard extends StatefulWidget {
  const _WnbaRapidApiCard({
    required this.athleteName,
    required this.accent,
    required this.config,
  });

  final String athleteName;
  final Color accent;
  final SportsApiConfig config;

  @override
  State<_WnbaRapidApiCard> createState() => _WnbaRapidApiCardState();
}

class _WnbaRapidApiCardState extends State<_WnbaRapidApiCard> {
  late Future<WnbaRapidProfile?> _profile;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _profile = WnbaRapidApiRepository(
      widget.config,
    ).playerProfile(widget.athleteName);
  }

  @override
  void didUpdateWidget(covariant _WnbaRapidApiCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.athleteName != widget.athleteName ||
        oldWidget.config.rapidApiDartsKey != widget.config.rapidApiDartsKey) {
      _load();
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<WnbaRapidProfile?>(
    future: _profile,
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
              Icon(Icons.analytics_outlined, color: widget.accent),
              const SizedBox(width: 9),
              const Expanded(
                child: Text(
                  'WNBA PLAYER BIO ÉS ADVANCED STATISTICS',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: .4,
                  ),
                ),
              ),
              const _Pill(text: 'RAPIDAPI · 7 NAP CACHE', color: _moss),
              IconButton(
                tooltip: 'Újratöltés',
                onPressed: () => setState(_load),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (widget.config.rapidApiDartsKey.isEmpty)
            const Text(
              'A RapidAPI-kulcs nincs beállítva.',
              style: TextStyle(color: _muted),
            )
          else if (snapshot.connectionState != ConnectionState.done)
            const Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Text('WNBA játékosadatok betöltése…'),
              ],
            )
          else if (snapshot.hasError)
            Text(
              'RapidAPI WNBA hiba: ${snapshot.error}',
              style: const TextStyle(color: _muted),
            )
          else if (snapshot.data == null)
            const Text(
              'A játékos ESPN-azonosítója nem található.',
              style: TextStyle(color: _muted),
            )
          else
            WnbaRapidProfileFacts(
              profile: snapshot.data!,
              accent: widget.accent,
            ),
        ],
      ),
    ),
  );
}

class WnbaRapidProfileFacts extends StatelessWidget {
  const WnbaRapidProfileFacts({
    super.key,
    required this.profile,
    required this.accent,
  });

  final WnbaRapidProfile profile;
  final Color accent;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        '${profile.team ?? 'WNBA'} · ${profile.season ?? 'aktuális szezon'} · ESPN ID ${profile.playerId}',
        style: const TextStyle(color: _muted, fontSize: 11),
      ),
      const SizedBox(height: 10),
      Wrap(
        spacing: 9,
        runSpacing: 9,
        children: profile.facts
            .map(
              (fact) => Container(
                width: 92,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: .09),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Column(
                  children: [
                    Text(
                      fact.value,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      fact.label,
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
      if (profile.awards.isNotEmpty) ...[
        const SizedBox(height: 16),
        const Text(
          'ELISMERÉSEK',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 7),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: profile.awards
              .map((award) => Chip(label: Text(award)))
              .toList(),
        ),
      ],
    ],
  );
}

class _WnbaLiveData extends StatelessWidget {
  const _WnbaLiveData({
    required this.games,
    required this.range,
    required this.accent,
    required this.onRange,
  });
  final List<WnbaGameLog> games;
  final int range;
  final Color accent;
  final ValueChanged<int> onRange;

  @override
  Widget build(BuildContext context) {
    final shown = range == 0 ? games : games.take(range).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WnbaSeasonSummaryFacts(games: games),
        const SizedBox(height: 22),
        Row(
          children: [
            const Expanded(
              child: Text(
                'FORMA · PONTSZÁM',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
              ),
            ),
            for (final option in const [(5, '5'), (10, '10'), (0, 'SZEZON')])
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: ChoiceChip(
                  label: Text(option.$2),
                  selected: range == option.$1,
                  onSelected: (_) => onRange(option.$1),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 116,
          child: _WnbaFormBars(games: shown.reversed.toList(), color: accent),
        ),
        const SizedBox(height: 22),
        const Text(
          'UTÓBBI MÉRKŐZÉSEK · VALÓS ADAT',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 5),
        const Text(
          'A SportsDataverse / wehoop meccsszintű box score adataiból.',
          style: TextStyle(fontSize: 11, color: _muted),
        ),
        const SizedBox(height: 8),
        _WnbaGameTable(games: games.take(5).toList(), accent: accent),
      ],
    );
  }
}

class WnbaSeasonSummaryFacts extends StatelessWidget {
  const WnbaSeasonSummaryFacts({super.key, required this.games});

  final List<WnbaGameLog> games;

  @override
  Widget build(BuildContext context) {
    final summary = WnbaSeasonSummary.fromGames(games);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'SZEZON ÖSSZESÍTŐ · VALÓS ADAT',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: _muted,
            letterSpacing: .8,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${games.first.team} · WNBA ${games.first.date.year} · SPORTSDATAVERSE / WEHOOP',
          style: const TextStyle(fontSize: 11, color: _muted),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _WnbaMiniMetric(value: summary.games.toString(), label: 'MECCS'),
            _WnbaMiniMetric(
              value: summary.minutesPerGame.toStringAsFixed(1),
              label: 'PERC / MECCS',
            ),
            _WnbaMiniMetric(
              value: summary.pointsPerGame.toStringAsFixed(1),
              label: 'PONT / MECCS',
            ),
            _WnbaMiniMetric(
              value: summary.reboundsPerGame.toStringAsFixed(1),
              label: 'LEPATTANÓ / MECCS',
            ),
            _WnbaMiniMetric(
              value: summary.assistsPerGame.toStringAsFixed(1),
              label: 'ASSZISZT / MECCS',
            ),
            _WnbaMiniMetric(
              value: summary.stealsPerGame.toStringAsFixed(1),
              label: 'LABDASZERZÉS / MECCS',
            ),
            _WnbaMiniMetric(
              value: summary.turnoversPerGame.toStringAsFixed(1),
              label: 'ELADOTT LABDA / MECCS',
            ),
            _WnbaMiniMetric(
              value: summary.fieldGoalPercentage == null
                  ? '—'
                  : '${summary.fieldGoalPercentage!.toStringAsFixed(1)}%',
              label: 'FG%',
            ),
          ],
        ),
      ],
    );
  }
}

class _WnbaMiniMetric extends StatelessWidget {
  const _WnbaMiniMetric({required this.value, required this.label});
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    width: 138,
    constraints: const BoxConstraints(minHeight: 76),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: _canvas,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 21),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            color: _muted,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}

class _WnbaFormBars extends StatelessWidget {
  const _WnbaFormBars({required this.games, required this.color});
  final List<WnbaGameLog> games;
  final Color color;
  @override
  Widget build(BuildContext context) {
    final max = games.fold<int>(
      1,
      (maxValue, game) => game.points > maxValue ? game.points : maxValue,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: games
          .map(
            (game) => Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Tooltip(
                  message:
                      '${game.date.month}.${game.date.day} · ${game.opponent}: ${game.points} PTS',
                  child: Container(
                    height: 18 + 88 * game.points / max,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(4),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _WnbaGameTable extends StatelessWidget {
  const _WnbaGameTable({required this.games, required this.accent});
  final List<WnbaGameLog> games;
  final Color accent;

  @override
  Widget build(BuildContext context) => Column(
    children: games
        .map(
          (game) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Row(
              children: [
                SizedBox(
                  width: 76,
                  child: Text(
                    '${game.date.month.toString().padLeft(2, '0')}.${game.date.day.toString().padLeft(2, '0')}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                Expanded(
                  child: Text(
                    'vs. ${game.opponent}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                SizedBox(
                  width: 82,
                  child: Text(
                    '${game.score} ${game.result == WnbaResult.win
                        ? 'GY'
                        : game.result == WnbaResult.loss
                        ? 'V'
                        : ''}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: game.result == WnbaResult.win
                          ? _olive
                          : game.result == WnbaResult.loss
                          ? const Color(0xFFB44646)
                          : _muted,
                    ),
                  ),
                ),
                _WnbaStat(value: '${game.points}', label: 'PTS'),
                _WnbaStat(value: '${game.rebounds}', label: 'REB'),
                _WnbaStat(value: '${game.assists}', label: 'AST'),
              ],
            ),
          ),
        )
        .toList(),
  );
}

class _WnbaStat extends StatelessWidget {
  const _WnbaStat({required this.value, required this.label});
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 52,
    child: Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            color: _muted,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}
