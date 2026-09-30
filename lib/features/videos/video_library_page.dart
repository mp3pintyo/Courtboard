import 'package:flutter/material.dart';
import 'package:courtboard/shared/common_ui.dart';
import 'package:courtboard/shared/components.dart';
import 'package:courtboard/shared/format.dart';
import 'package:courtboard/shared/images.dart';
import 'package:courtboard/shared/theme/courtboard_theme.dart';
import 'package:courtboard/data/api_sports.dart';
import 'package:courtboard/data/youtube_playlist.dart';
import 'package:courtboard/domain/athlete.dart';

class VideoLibraryEntry {
  const VideoLibraryEntry({required this.video, this.athlete});

  final SavedYouTubeVideo video;
  final Athlete? athlete;

  String get athleteName =>
      athlete?.name ??
      (video.athleteName.isEmpty
          ? 'Nincs sportolóhoz rendelve'
          : video.athleteName);
  String get sport => athlete?.sport.shortLabel ?? 'Egyéb';
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
  final _searchFocus = FocusNode(debugLabel: 'video-search');
  String _athlete = 'Mind';
  String _sport = 'Mind';

  @override
  void dispose() {
    _titleSearch.dispose();
    _searchFocus.dispose();
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

    final horizontal = MediaQuery.sizeOf(context).width < 800 ? 20.0 : 34.0;
    return CommandListener(
      onFocusSearch: () {
        _searchFocus.requestFocus();
        _titleSearch.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _titleSearch.text.length,
        );
      },
      child: Container(
        color: context.cb.canvas,
        padding: EdgeInsets.fromLTRB(horizontal, 28, horizontal, 34),
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
              focusNode: _searchFocus,
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
                  style: context.text.titleLarge,
                ),
                const Spacer(),
                if (entries.isNotEmpty)
                  Text('Legújabb mentések elöl', style: context.text.bodySmall),
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
  Widget build(BuildContext context) => PageHeader(
    title: 'Videók',
    subtitle: 'A sportolóidhoz mentett videók egyetlen médiatárban.',
    leading: Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: context.cb.accentSoft,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Icon(
        Icons.video_library_rounded,
        size: 29,
        color: context.cb.accent,
      ),
    ),
    actions: [
      _VideoLibraryStat(value: formatInt(videoCount), label: 'VIDEÓ'),
      _VideoLibraryStat(value: formatInt(athleteCount), label: 'SPORTOLÓ'),
      _VideoLibraryStat(value: formatInt(sportCount), label: 'SPORTÁG'),
    ],
  );
}

class _VideoLibraryStat extends StatelessWidget {
  const _VideoLibraryStat({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minWidth: 92),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: context.cb.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: context.cb.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: context.text.titleLarge),
        Text(label, style: context.text.labelMedium),
      ],
    ),
  );
}

class _VideoFilterBar extends StatelessWidget {
  const _VideoFilterBar({
    required this.controller,
    required this.focusNode,
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
  final FocusNode focusNode;
  final String athlete;
  final String sport;
  final List<String> athleteNames;
  final List<String> sports;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onAthleteChanged;
  final ValueChanged<String> onSportChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => SurfaceCard(
    padding: const EdgeInsets.all(16),
    child: Row(
      children: [
        Expanded(
          flex: 3,
          child: TextField(
            key: const Key('video-title-search'),
            controller: controller,
            focusNode: focusNode,
            onChanged: onSearchChanged,
            decoration: const InputDecoration(
              labelText: 'Keresés a videók címében',
              hintText: 'Ctrl+F',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          key: const Key('video-athlete-filter'),
          flex: 2,
          child: DropdownButtonFormField<String>(
            style: context.text.bodyLarge,
            key: ValueKey('video-athlete-filter-$athlete'),
            initialValue: athlete,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Sportoló',
              prefixIcon: Icon(Icons.person_outline),
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
            style: context.text.bodyLarge,
            key: ValueKey('video-sport-filter-$sport'),
            initialValue: sport,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Sportág',
              prefixIcon: Icon(Icons.sports_basketball_outlined),
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

  @override
  Widget build(BuildContext context) {
    final cb = context.cb;
    final athlete = entry.athlete;
    final accent = athlete?.accent ?? cb.highlight;
    return FocusRing(
      borderRadius: BorderRadius.circular(22),
      child: Material(
        key: ValueKey('video-${entry.video.videoId}-${entry.athleteName}'),
        color: cb.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: cb.border),
        ),
        child: InkWell(
          onTap: () => openExternalUrl(context, entry.video.watchUrl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CourtboardImage(
                      url: entry.video.thumbnailUrl,
                      semanticLabel: 'Videó bélyegképe: ${entry.video.title}',
                      placeholder: Container(
                        color: cb.ink,
                        child: Icon(
                          Icons.video_library_outlined,
                          color: cb.onInkMuted,
                          size: 44,
                        ),
                      ),
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            cb.ink.withValues(alpha: 0),
                            cb.ink.withValues(alpha: .6),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 12,
                      left: 12,
                      child: StatusPill.filled(
                        entry.sport.toUpperCase(),
                        color: accent,
                      ),
                    ),
                    Center(
                      child: Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: cb.onInk.withValues(alpha: .92),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.play_arrow_rounded,
                          color: cb.ink,
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
                      style: context.text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 13),
                    Row(
                      children: [
                        SizedBox.square(
                          dimension: 34,
                          child: ClipOval(
                            child: CourtboardImage(
                              url: athlete?.photoUrl ?? '',
                              alignment: const Alignment(0, -0.5),
                              placeholder: InitialsPlaceholder(
                                name: entry.athleteName,
                                color: accent,
                              ),
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
                                style: context.text.titleSmall,
                              ),
                              Text(
                                _savedDate(entry.video.savedAt),
                                style: context.text.bodySmall,
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
      ),
    );
  }

  static String _savedDate(DateTime date) => 'Mentve: ${formatDate(date)}';
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
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: SurfaceCard(
                padding: const EdgeInsets.all(34),
                child: EmptyState(
                  icon: Icons.video_library_outlined,
                  title: 'Még nincs mentett videód',
                  message:
                      'Nyiss meg egy sportolói profilt, majd a videók résznél adj hozzá egy YouTube-linket.',
                  action: FilledButton.icon(
                    onPressed: onOpenAthletes,
                    icon: const Icon(Icons.people_outline),
                    label: const Text('Sportolók megnyitása'),
                  ),
                ),
              ),
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
    child: EmptyState(
      icon: Icons.search_off_rounded,
      title: 'Nincs a szűrésnek megfelelő videó.',
      message: 'Próbálj más címet, sportolót vagy sportágat.',
      action: TextButton.icon(
        onPressed: onClear,
        icon: const Icon(Icons.filter_alt_off_outlined),
        label: const Text('Szűrők törlése'),
      ),
    ),
  );
}
