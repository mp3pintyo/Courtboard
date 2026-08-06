part of '../main.dart';

class VideoLibraryEntry {
  const VideoLibraryEntry({required this.video, this.athlete});

  final SavedYouTubeVideo video;
  final Athlete? athlete;

  String get athleteName =>
      athlete?.name ??
      (video.athleteName.isEmpty
          ? 'Nincs sportolóhoz rendelve'
          : video.athleteName);
  String get sport => athlete?.sport ?? 'Egyéb';
}

List<VideoLibraryEntry> filterVideoLibrary({
  required List<VideoLibraryEntry> entries,
  String titleQuery = '',
  String athleteName = 'Mind',
  String sport = 'Mind',
}) {
  final query = normalizeAthleteName(titleQuery.trim());
  final filtered = entries
      .where(
        (entry) =>
            (athleteName == 'Mind' || entry.athleteName == athleteName) &&
            (sport == 'Mind' || entry.sport == sport) &&
            (query.isEmpty ||
                normalizeAthleteName(entry.video.title).contains(query)),
      )
      .toList();
  filtered.sort((a, b) => b.video.savedAt.compareTo(a.video.savedAt));
  return filtered;
}

class VideoLibraryPage extends StatefulWidget {
  const VideoLibraryPage({
    super.key,
    required this.athletes,
    required this.playlist,
    required this.onOpenAthlete,
    required this.onRemoveVideo,
    required this.onOpenAthletes,
  });

  final List<Athlete> athletes;
  final AthleteVideoPlaylist playlist;
  final ValueChanged<Athlete> onOpenAthlete;
  final ValueChanged<SavedYouTubeVideo> onRemoveVideo;
  final VoidCallback onOpenAthletes;

  @override
  State<VideoLibraryPage> createState() => _VideoLibraryPageState();
}

class _VideoLibraryPageState extends State<VideoLibraryPage> {
  final _titleSearch = TextEditingController();
  String _athlete = 'Mind';
  String _sport = 'Mind';

  @override
  void dispose() {
    _titleSearch.dispose();
    super.dispose();
  }

  List<VideoLibraryEntry> get _entries {
    final athletesByName = {
      for (final athlete in widget.athletes)
        normalizeAthleteName(athlete.name): athlete,
    };
    return [...widget.playlist.videos, ...widget.playlist.unassigned]
        .map(
          (video) => VideoLibraryEntry(
            video: video,
            athlete: athletesByName[normalizeAthleteName(video.athleteName)],
          ),
        )
        .toList();
  }

  void _clearFilters() {
    _titleSearch.clear();
    setState(() {
      _athlete = 'Mind';
      _sport = 'Mind';
    });
  }

  @override
  Widget build(BuildContext context) {
    final entries = _entries;
    final athleteNames =
        entries.map((entry) => entry.athleteName).toSet().toList()..sort(
          (a, b) => normalizeAthleteName(a).compareTo(normalizeAthleteName(b)),
        );
    final sports = entries.map((entry) => entry.sport).toSet().toList()..sort();
    final activeAthlete = athleteNames.contains(_athlete) ? _athlete : 'Mind';
    final activeSport = sports.contains(_sport) ? _sport : 'Mind';
    final filtered = filterVideoLibrary(
      entries: entries,
      titleQuery: _titleSearch.text,
      athleteName: activeAthlete,
      sport: activeSport,
    );
    final athletesWithVideos = entries
        .where((entry) => entry.athlete != null)
        .map((entry) => entry.athleteName)
        .toSet()
        .length;

    return Container(
      color: _canvas,
      padding: const EdgeInsets.fromLTRB(34, 28, 34, 34),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _VideoLibraryHeader(
            videoCount: entries.length,
            athleteCount: athletesWithVideos,
            sportCount: sports.where((sport) => sport != 'Egyéb').length,
          ),
          const SizedBox(height: 22),
          _VideoFilterBar(
            controller: _titleSearch,
            athlete: activeAthlete,
            sport: activeSport,
            athleteNames: athleteNames,
            sports: sports,
            onSearchChanged: (_) => setState(() {}),
            onAthleteChanged: (value) => setState(() => _athlete = value),
            onSportChanged: (value) => setState(() => _sport = value),
            onClear: _clearFilters,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Text(
                '${filtered.length} videó',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              if (entries.isNotEmpty)
                const Text(
                  'Legújabb mentések elöl',
                  style: TextStyle(color: _muted, fontSize: 12),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: entries.isEmpty
                ? _EmptyVideoLibrary(onOpenAthletes: widget.onOpenAthletes)
                : filtered.isEmpty
                ? _EmptyVideoSearch(onClear: _clearFilters)
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth >= 1120
                          ? 3
                          : constraints.maxWidth >= 720
                          ? 2
                          : 1;
                      const gap = 16.0;
                      final width =
                          (constraints.maxWidth - gap * (columns - 1)) /
                          columns;
                      return SingleChildScrollView(
                        child: Wrap(
                          spacing: gap,
                          runSpacing: gap,
                          children: filtered
                              .map(
                                (entry) => SizedBox(
                                  width: width,
                                  child: _VideoLibraryCard(
                                    entry: entry,
                                    onOpenAthlete: entry.athlete == null
                                        ? null
                                        : () => widget.onOpenAthlete(
                                            entry.athlete!,
                                          ),
                                    onRemove: () =>
                                        widget.onRemoveVideo(entry.video),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _VideoLibraryHeader extends StatelessWidget {
  const _VideoLibraryHeader({
    required this.videoCount,
    required this.athleteCount,
    required this.sportCount,
  });
  final int videoCount;
  final int athleteCount;
  final int sportCount;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.secondary,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Icon(Icons.video_library_rounded, size: 29),
      ),
      const SizedBox(width: 16),
      const Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Videók',
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w900,
                letterSpacing: -1.5,
              ),
            ),
            SizedBox(height: 3),
            Text(
              'A sportolóidhoz mentett videók egyetlen médiatárban.',
              style: TextStyle(color: _muted),
            ),
          ],
        ),
      ),
      _VideoLibraryStat(value: '$videoCount', label: 'VIDEÓ'),
      const SizedBox(width: 8),
      _VideoLibraryStat(value: '$athleteCount', label: 'SPORTOLÓ'),
      const SizedBox(width: 8),
      _VideoLibraryStat(value: '$sportCount', label: 'SPORTÁG'),
    ],
  );
}

class _VideoLibraryStat extends StatelessWidget {
  const _VideoLibraryStat({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    width: 86,
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
    decoration: BoxDecoration(
      color: _paper,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFD8D4C8)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
        ),
        Text(
          label,
          style: const TextStyle(
            color: _muted,
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: .6,
          ),
        ),
      ],
    ),
  );
}

class _VideoFilterBar extends StatelessWidget {
  const _VideoFilterBar({
    required this.controller,
    required this.athlete,
    required this.sport,
    required this.athleteNames,
    required this.sports,
    required this.onSearchChanged,
    required this.onAthleteChanged,
    required this.onSportChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final String athlete;
  final String sport;
  final List<String> athleteNames;
  final List<String> sports;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onAthleteChanged;
  final ValueChanged<String> onSportChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: _paper,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFD8D4C8)),
    ),
    child: Row(
      children: [
        Expanded(
          flex: 3,
          child: TextField(
            key: const Key('video-title-search'),
            controller: controller,
            onChanged: onSearchChanged,
            decoration: const InputDecoration(
              labelText: 'Keresés a videók címében',
              prefixIcon: Icon(Icons.search_rounded),
              border: OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          key: const Key('video-athlete-filter'),
          flex: 2,
          child: DropdownButtonFormField<String>(
            key: ValueKey('video-athlete-filter-$athlete'),
            initialValue: athlete,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Sportoló',
              prefixIcon: Icon(Icons.person_outline),
              border: OutlineInputBorder(),
            ),
            items: ['Mind', ...athleteNames]
                .map(
                  (name) => DropdownMenuItem(
                    value: name,
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) onAthleteChanged(value);
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          key: const Key('video-sport-filter'),
          flex: 2,
          child: DropdownButtonFormField<String>(
            key: ValueKey('video-sport-filter-$sport'),
            initialValue: sport,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Sportág',
              prefixIcon: Icon(Icons.sports_basketball_outlined),
              border: OutlineInputBorder(),
            ),
            items: ['Mind', ...sports]
                .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                .toList(),
            onChanged: (value) {
              if (value != null) onSportChanged(value);
            },
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filledTonal(
          key: const Key('video-clear-filters'),
          tooltip: 'Szűrők törlése',
          onPressed: onClear,
          icon: const Icon(Icons.filter_alt_off_outlined),
        ),
      ],
    ),
  );
}

class _VideoLibraryCard extends StatelessWidget {
  const _VideoLibraryCard({
    required this.entry,
    required this.onOpenAthlete,
    required this.onRemove,
  });

  final VideoLibraryEntry entry;
  final VoidCallback? onOpenAthlete;
  final VoidCallback onRemove;

  void _play() =>
      Process.start('cmd', ['/c', 'start', '', entry.video.watchUrl]);

  @override
  Widget build(BuildContext context) {
    final athlete = entry.athlete;
    final accent = athlete?.accent ?? Theme.of(context).colorScheme.secondary;
    return Material(
      key: ValueKey('video-${entry.video.videoId}-${entry.athleteName}'),
      color: _paper,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _play,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    entry.video.thumbnailUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: _ink,
                      child: const Icon(
                        Icons.video_library_outlined,
                        color: Colors.white54,
                        size: 44,
                      ),
                    ),
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.transparent, Color(0x99151815)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: _Pill(
                      text: entry.sport.toUpperCase(),
                      color: accent,
                    ),
                  ),
                  Center(
                    child: Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .92),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: _ink,
                        size: 34,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(17, 16, 12, 13),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.video.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 13),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 17,
                        backgroundColor: accent,
                        child: Text(
                          entry.athleteName.substring(0, 1),
                          style: const TextStyle(
                            color: _ink,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.athleteName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              _savedDate(entry.video.savedAt),
                              style: const TextStyle(
                                color: _muted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (onOpenAthlete != null)
                        IconButton(
                          tooltip: 'Sportoló profilja',
                          onPressed: onOpenAthlete,
                          icon: const Icon(Icons.person_outline),
                        ),
                      IconButton(
                        tooltip: 'Videó eltávolítása',
                        onPressed: onRemove,
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _savedDate(DateTime date) =>
      'Mentve: ${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
}

class _EmptyVideoLibrary extends StatelessWidget {
  const _EmptyVideoLibrary({required this.onOpenAthletes});
  final VoidCallback onOpenAthletes;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 460),
            margin: const EdgeInsets.symmetric(vertical: 12),
            padding: const EdgeInsets.all(34),
            decoration: BoxDecoration(
              color: _paper,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFD8D4C8)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.video_library_outlined,
                  size: 48,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 14),
                const Text(
                  'Még nincs mentett videód',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 7),
                const Text(
                  'Nyiss meg egy sportolói profilt, majd a videók résznél adj hozzá egy YouTube-linket.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _muted, height: 1.4),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: onOpenAthletes,
                  icon: const Icon(Icons.people_outline),
                  label: const Text('Sportolók megnyitása'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _EmptyVideoSearch extends StatelessWidget {
  const _EmptyVideoSearch({required this.onClear});
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.search_off_rounded, size: 42, color: _muted),
        const SizedBox(height: 10),
        const Text(
          'Nincs a szűrésnek megfelelő videó.',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        TextButton.icon(
          onPressed: onClear,
          icon: const Icon(Icons.filter_alt_off_outlined),
          label: const Text('Szűrők törlése'),
        ),
      ],
    ),
  );
}
