part of '../main.dart';

class _DartsDataCard extends StatefulWidget {
  const _DartsDataCard({
    required this.athleteName,
    required this.accent,
    required this.config,
  });

  final String athleteName;
  final Color accent;
  final SportsApiConfig config;

  @override
  State<_DartsDataCard> createState() => _DartsDataCardState();
}

class _DartsDataCardState extends State<_DartsDataCard> {
  late Future<DartsProfileData> _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _data = DartsRepository(widget.config).fetch(widget.athleteName);
  }

  @override
  void didUpdateWidget(covariant _DartsDataCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.athleteName != widget.athleteName ||
        oldWidget.config.rapidApiDartsKey != widget.config.rapidApiDartsKey) {
      _load();
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<DartsProfileData>(
    future: _data,
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
              Icon(Icons.adjust_rounded, color: widget.accent),
              const SizedBox(width: 9),
              const Expanded(
                child: Text(
                  'VALÓS DARTS ADAT · EGYESÍTETT FORRÁSOK',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: .5,
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
          if (snapshot.connectionState != ConnectionState.done)
            const Padding(
              padding: EdgeInsets.all(12),
              child: CircularProgressIndicator(),
            )
          else if (snapshot.hasError)
            Text(
              'Darts adatforrás hiba: ${snapshot.error}',
              style: const TextStyle(color: Colors.red),
            )
          else
            DartsProfileFacts(data: snapshot.data!, accent: widget.accent),
        ],
      ),
    ),
  );
}

class DartsProfileFacts extends StatelessWidget {
  const DartsProfileFacts({
    super.key,
    required this.data,
    required this.accent,
  });

  final DartsProfileData data;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final player = data.player;
    final facts = <(String, String)>[
      if (player?['strPlayer'] != null) ('NÉV', '${player!['strPlayer']}'),
      if (player?['strTeam'] != null) ('SOROZAT', '${player!['strTeam']}'),
      if (player?['strNationality'] != null)
        ('NEMZETISÉG', '${player!['strNationality']}'),
      if (player?['dateBorn'] != null) ('SZÜLETETT', '${player!['dateBorn']}'),
      if (player?['strStatus'] != null) ('STÁTUSZ', '${player!['strStatus']}'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _DartsProviderChip(
              name: 'TheSportsDB',
              ready: player != null,
              message:
                  data.theSportsDbError ??
                  (player == null ? 'Nincs találat' : 'Profil és eredmények'),
            ),
            _DartsProviderChip(
              name: 'RapidAPI · Darts API',
              ready: data.competitions.isNotEmpty,
              configured: data.rapidApiConfigured,
              message:
                  data.rapidApiError ??
                  (data.rapidApiConfigured
                      ? 'Verseny- és eseményfeed'
                      : 'RAPIDAPI_DARTS_KEY nincs beállítva'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (facts.isEmpty)
          const Text(
            'A TheSportsDB nem talált ilyen dartsjátékost.',
            style: TextStyle(color: _muted),
          )
        else
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: facts
                .map(
                  (fact) => Container(
                    width: 175,
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
          'LEGUTÓBBI DARTS EREDMÉNYEK · THESPORTSDB',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        if (data.results.isEmpty)
          const Text(
            'Nem érkezett játékoshoz kötött eredmény.',
            style: TextStyle(color: _muted),
          )
        else
          ...data.results.map(
            (result) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                children: [
                  SizedBox(
                    width: 92,
                    child: Text(
                      '${result.date.year}.${result.date.month.toString().padLeft(2, '0')}.${result.date.day.toString().padLeft(2, '0')}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      result.event,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  Text(
                    result.detail == 'WIN' ? 'GYŐZELEM' : result.detail,
                    style: TextStyle(
                      color: result.detail == 'WIN' ? _moss : _muted,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 18),
        const Text(
          'RAPIDAPI VERSENYFEED',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 5),
        const Text(
          'A Sportbex API ezen csomagja versenyeket, eseményeket, piacokat és oddsokat ad; játékosstatisztikát nem.',
          style: TextStyle(fontSize: 11, color: _muted),
        ),
        const SizedBox(height: 8),
        if (!data.rapidApiConfigured)
          const Text(
            'A RapidAPI darts kulcs az Adatforrások oldalon adható meg.',
            style: TextStyle(color: _muted),
          )
        else if (data.competitions.isEmpty)
          Text(
            data.rapidApiError ?? 'Most nincs elérhető verseny.',
            style: const TextStyle(color: _muted),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: data.competitions
                .map((competition) => Chip(label: Text(competition.name)))
                .toList(),
          ),
      ],
    );
  }
}

class _DartsProviderChip extends StatelessWidget {
  const _DartsProviderChip({
    required this.name,
    required this.ready,
    required this.message,
    this.configured = true,
  });

  final String name;
  final bool ready;
  final bool configured;
  final String message;

  @override
  Widget build(BuildContext context) {
    final color = ready
        ? _moss
        : configured
        ? Colors.red.shade400
        : Colors.orange.shade600;
    return Tooltip(
      message: message,
      child: Chip(
        avatar: Icon(
          ready
              ? Icons.check_circle
              : configured
              ? Icons.error_outline
              : Icons.key_off,
          size: 17,
          color: color,
        ),
        label: Text(name),
        side: BorderSide(color: color.withValues(alpha: .45)),
        backgroundColor: color.withValues(alpha: .08),
      ),
    );
  }
}
