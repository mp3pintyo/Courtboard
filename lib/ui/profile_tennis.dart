part of '../main.dart';

class _TennisDataCard extends StatefulWidget {
  const _TennisDataCard({
    required this.athleteName,
    required this.accent,
    required this.config,
  });

  final String athleteName;
  final Color accent;
  final SportsApiConfig config;

  @override
  State<_TennisDataCard> createState() => _TennisDataCardState();
}

class _TennisDataCardState extends State<_TennisDataCard> {
  Future<TennisProfileData>? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load({bool force = false}) {
    _data = widget.config.liveTennisKey.trim().isEmpty
        ? null
        : TennisRepository(
            widget.config,
          ).fetch(widget.athleteName, forceRefresh: force);
  }

  @override
  void didUpdateWidget(covariant _TennisDataCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.athleteName != widget.athleteName ||
        oldWidget.config.liveTennisKey != widget.config.liveTennisKey) {
      _load();
    }
  }

  @override
  Widget build(BuildContext context) => Container(
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
            Icon(Icons.sports_tennis_rounded, color: widget.accent),
            const SizedBox(width: 9),
            const Expanded(
              child: Text(
                'ÉLŐ TENISZADAT · LIVE TENNIS API',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  letterSpacing: .5,
                ),
              ),
            ),
            _DartsProviderChip(
              name: 'Live Tennis API',
              ready: _data != null,
              configured: _data != null,
              message: _data == null
                  ? 'A kulcs az Adatforrások oldalon adható meg'
                  : 'Free: játékos, ranglista, élő és közelgő meccsek',
            ),
            IconButton(
              tooltip: 'Frissítés az API-ból',
              onPressed: _data == null
                  ? null
                  : () => setState(() => _load(force: true)),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_data == null)
          const Text(
            'Add meg a Live Tennis API ingyenes kulcsát az Adatforrások oldalon. Ezután a profil automatikusan megkapja a ranglistát, az élő állást és a következő mérkőzéseket.',
            style: TextStyle(color: _muted),
          )
        else
          FutureBuilder<TennisProfileData>(
            future: _data,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.all(12),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 19,
                        height: 19,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 12),
                      Text('Teniszprofil és aktuális meccsek betöltése…'),
                    ],
                  ),
                );
              }
              if (snapshot.hasError) {
                return Text(
                  'Live Tennis API hiba: ${snapshot.error}',
                  style: const TextStyle(color: Colors.red),
                );
              }
              return TennisProfileFacts(
                data: snapshot.data!,
                accent: widget.accent,
              );
            },
          ),
      ],
    ),
  );
}

class TennisProfileFacts extends StatelessWidget {
  const TennisProfileFacts({
    super.key,
    required this.data,
    required this.accent,
  });

  final TennisProfileData data;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final player = data.player;
    final facts = <(String, String)>[
      if (player.ranking != null) ('RANGLISTA', '#${player.ranking}'),
      if (player.rankingPoints != null)
        ('RANGLISTAPONT', '${player.rankingPoints}'),
      if (player.tour != null) ('SOROZAT', player.tour!.toUpperCase()),
      if (player.country != null) ('ORSZÁG', player.country!),
      if (player.hand != null)
        ('ÜTŐKÉZ', player.hand == 'L' ? 'Balkezes' : 'Jobbkezes'),
      if (player.backhand != null)
        ('FONÁK', player.backhand == 1 ? 'Egykezes' : 'Kétkezes'),
      if (player.birthday != null) ('SZÜLETETT', _tennisDate(player.birthday)),
    ];
    final usage = data.usage;
    final usageText = usage == null
        ? null
        : usage.today != null && usage.dailyLimit != null
        ? '${usage.tier} · ma ${usage.today}/${usage.dailyLimit} kérés'
        : '${usage.tier} csomag';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                player.name,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            if (usageText != null)
              _Pill(text: usageText.toUpperCase(), color: accent),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: facts
              .map(
                (fact) => Container(
                  width: 170,
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: .08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fact.$1,
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        fact.$2,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 20),
        const Text(
          'ÉLŐ MÉRKŐZÉS',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: .4),
        ),
        const SizedBox(height: 8),
        if (data.liveMatches.isEmpty)
          const Text(
            'A játékosnak most nincs élő mérkőzése.',
            style: TextStyle(color: _muted),
          )
        else
          ...data.liveMatches.map(
            (match) => _TennisMatchTile(
              opponent: match.opponentOf(player),
              tournament: match.tournament,
              detail: match.score?.summary ?? 'Élő mérkőzés',
              date: match.scheduledTime,
              surface: match.surface,
              accent: accent,
              live: true,
            ),
          ),
        const SizedBox(height: 18),
        const Text(
          'KÖVETKEZŐ MÉRKŐZÉSEK',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: .4),
        ),
        const SizedBox(height: 8),
        if (data.upcomingMatches.isEmpty && data.fixtures.isEmpty)
          const Text(
            'Most nincs a játékoshoz kapcsolható közelgő mérkőzés.',
            style: TextStyle(color: _muted),
          )
        else ...[
          ...data.upcomingMatches
              .take(5)
              .map(
                (match) => _TennisMatchTile(
                  opponent: match.opponentOf(player),
                  tournament: match.tournament,
                  detail: match.round ?? 'Közelgő mérkőzés',
                  date: match.scheduledTime,
                  surface: match.surface,
                  accent: accent,
                ),
              ),
          if (data.upcomingMatches.length < 5)
            ...data.fixtures
                .take(5 - data.upcomingMatches.length)
                .map(
                  (fixture) => _TennisMatchTile(
                    opponent: fixture.opponentOf(player),
                    tournament: fixture.tournament,
                    detail: fixture.round ?? 'Közelgő mérkőzés',
                    date: fixture.eventDate,
                    surface: fixture.surface,
                    accent: accent,
                  ),
                ),
        ],
        const SizedBox(height: 14),
        const Text(
          'A Free csomag élő és közelgő adatokat biztosít. A befejezett meccselőzmények és a pontonkénti történet fizetős History hozzáférést igényelnek.',
          style: TextStyle(fontSize: 11, color: _muted),
        ),
      ],
    );
  }
}

class _TennisMatchTile extends StatelessWidget {
  const _TennisMatchTile({
    required this.opponent,
    required this.tournament,
    required this.detail,
    required this.accent,
    this.date,
    this.surface,
    this.live = false,
  });

  final String opponent;
  final String tournament;
  final String detail;
  final Color accent;
  final DateTime? date;
  final String? surface;
  final bool live;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
    decoration: BoxDecoration(
      color: live ? accent.withValues(alpha: .13) : const Color(0xFFF1EFE8),
      borderRadius: BorderRadius.circular(13),
    ),
    child: Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: live ? Colors.red : accent,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 11),
        SizedBox(
          width: 105,
          child: Text(
            live ? 'ÉLŐ' : _tennisDate(date),
            style: TextStyle(
              color: live ? Colors.red : _muted,
              fontWeight: FontWeight.w900,
              fontSize: 11,
            ),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'vs. $opponent',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              Text(
                [
                  tournament,
                  if (surface != null) surface!.toUpperCase(),
                ].join(' · '),
                style: const TextStyle(fontSize: 11, color: _muted),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            detail,
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    ),
  );
}

String _tennisDate(DateTime? date) => date == null
    ? 'Időpont később'
    : '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')} '
          '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
