part of '../main.dart';

class _ProfilePage extends StatelessWidget {
  const _ProfilePage({
    super.key,
    required this.athlete,
    required this.backLabel,
    required this.apiConfig,
    required this.videos,
    required this.note,
    required this.alertEnabled,
    required this.onBack,
    required this.onToggleClip,
    required this.onAddVideo,
    required this.onDelete,
    required this.onSaveNote,
    required this.onToggleAlert,
  });
  final Athlete athlete;

  /// A „Vissza” gomb felirata a megnyitás helye szerint.
  final String backLabel;
  final SportsApiConfig apiConfig;
  final List<SavedYouTubeVideo> videos;
  final String note;
  final bool alertEnabled;
  final VoidCallback onBack;
  final ValueChanged<SavedYouTubeVideo> onToggleClip;
  final VoidCallback onAddVideo;
  final VoidCallback onDelete;
  final void Function(Athlete, String) onSaveNote;
  final ValueChanged<Athlete> onToggleAlert;

  @override
  Widget build(BuildContext context) {
    final clips = videos;
    final ligaFProfile =
        athlete.sport == 'Foci' &&
        (athlete.name.toLowerCase().contains('aitana bonmat') ||
            athlete.team.toLowerCase().contains('femen'));
    return Container(
      color: _canvas,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(34, 24, 34, 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                TextButton.icon(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back),
                  label: Text(backLabel),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Sportoló törlése',
                  onPressed: onDelete,
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Color(0xFFB44646),
                  ),
                ),
                _Pill(text: 'JÁTÉKOSPROFIL', color: athlete.accent),
              ],
            ),
            const SizedBox(height: 14),
            _ProfileHero(athlete: athlete),
            const SizedBox(height: 14),
            _PersonalTools(
              note: note,
              alertEnabled: alertEnabled,
              onSaveNote: (value) => onSaveNote(athlete, value),
              onToggleAlert: () => onToggleAlert(athlete),
            ),
            if (athlete.sport == 'NBA' || athlete.sport == 'NFL') ...[
              const SizedBox(height: 18),
              _ApiSportsCard(
                sport: athlete.sport,
                athleteName: athlete.name,
                teamName: athlete.team,
                accent: athlete.accent,
                config: apiConfig,
              ),
            ],
            if (athlete.sport == 'Foci' && !ligaFProfile) ...[
              const SizedBox(height: 18),
              _FootballDataCard(
                teamName: athlete.team,
                accent: athlete.accent,
                config: apiConfig,
              ),
              const SizedBox(height: 18),
              _FootballDataPlayerCard(
                athleteName: athlete.name,
                teamName: athlete.team,
                accent: athlete.accent,
                config: apiConfig,
              ),
            ],
            if (ligaFProfile) ...[
              const SizedBox(height: 18),
              _LigaFCard(accent: athlete.accent),
            ],
            if (athlete.sport == 'WNBA') ...[
              const SizedBox(height: 18),
              _WnbaWehoopCard(
                athleteName: athlete.name,
                accent: athlete.accent,
              ),
              const SizedBox(height: 18),
              _WnbaBasketballReferenceCard(
                athleteName: athlete.name,
                accent: athlete.accent,
              ),
              const SizedBox(height: 18),
              _WnbaRapidApiCard(
                athleteName: athlete.name,
                accent: athlete.accent,
                config: apiConfig,
              ),
            ],
            if (athlete.sport == 'NBA') ...[
              const SizedBox(height: 22),
              _NbaSeasonSummaryCard(
                athleteName: athlete.name,
                accent: athlete.accent,
              ),
            ],
            if (athlete.sport == 'Darts') ...[
              const SizedBox(height: 18),
              _DartsDataCard(
                athleteName: athlete.name,
                accent: athlete.accent,
                config: apiConfig,
              ),
            ],
            if (athlete.sport == 'Tenisz') ...[
              const SizedBox(height: 18),
              _TennisDataCard(
                athleteName: athlete.name,
                accent: athlete.accent,
                config: apiConfig,
              ),
            ],
            if (athlete.sport == 'Foci') ...[
              const SizedBox(height: 22),
              _FootballSeasonSummaryCard(
                athleteName: athlete.name,
                teamName: athlete.team,
                accent: athlete.accent,
                config: apiConfig,
              ),
              const SizedBox(height: 28),
            ] else if (athlete.sport != 'WNBA' &&
                athlete.sport != 'NBA' &&
                athlete.sport != 'Tenisz') ...[
              const SizedBox(height: 22),
              const Text(
                'Szezon összesítő',
                style: TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.2,
                ),
              ),
              const SizedBox(height: 12),
              if (athlete.metrics.isEmpty)
                const _ProfileEmptyNote(
                  'Ehhez a sportolóhoz még nincs valós szezonadat. A számok csak élő adatforrásból jelennek meg.',
                )
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    final w = (constraints.maxWidth - 48) / 4;
                    return Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: athlete.metrics
                          .map(
                            (metric) => SizedBox(
                              width: w,
                              child: _MetricCard(
                                metric: metric,
                                accent: athlete.accent,
                              ),
                            ),
                          )
                          .toList(),
                    );
                  },
                ),
              const SizedBox(height: 28),
              _SportTemplate(athlete: athlete),
              if (athlete.sport != 'NBA' && !ligaFProfile) ...[
                const SizedBox(height: 28),
                const Text(
                  'Utóbbi mérkőzések',
                  style: TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.2,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Egységes mérkőzés-sablon: eredmény, sportág szerinti teljesítmény, értékelés.',
                  style: TextStyle(color: _muted),
                ),
                const SizedBox(height: 12),
                if (athlete.matches.isEmpty)
                  const _ProfileEmptyNote(
                    'Még nincs megjeleníthető mérkőzésadat ehhez a sportolóhoz.',
                  )
                else
                  ...athlete.matches.map(
                    (match) => _MatchRow(match: match, accent: athlete.accent),
                  ),
              ],
              const SizedBox(height: 28),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Videók és saját playlist',
                  style: TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.2,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      '${videos.length} mentett videó',
                      style: const TextStyle(color: _muted),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      onPressed: onAddVideo,
                      icon: const Icon(Icons.add),
                      label: const Text('Videó hozzáadása'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (clips.isEmpty)
              const Text(
                'Még nincs mentett videó. A „Videó hozzáadása” gombbal illessz be egy YouTube-linket vagy videóazonosítót.',
                style: TextStyle(color: _muted),
              )
            else
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: clips
                    .map(
                      (video) => _ClipCard(
                        video: video,
                        onRemove: () => onToggleClip(video),
                      ),
                    )
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }
}

class _ProfileEmptyNote extends StatelessWidget {
  const _ProfileEmptyNote(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: _paper,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFD8D4C8)),
    ),
    child: Text(message, style: const TextStyle(color: _muted)),
  );
}
