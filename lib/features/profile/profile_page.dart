import 'package:flutter/material.dart';
import 'package:courtboard/shared/components.dart';
import 'package:courtboard/shared/theme/courtboard_theme.dart';
import 'package:courtboard/data/youtube_playlist.dart';
import 'package:courtboard/domain/athlete.dart';
import 'package:courtboard/features/live_scores/live_scores_ui.dart';
import 'package:courtboard/features/profile/match_details.dart';
import 'package:courtboard/features/profile/profile_common.dart';
import 'package:courtboard/features/profile/sport_profile_spec.dart';
import 'package:courtboard/domain/athlete_targets.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({
    super.key,
    required this.athlete,
    required this.backLabel,
    required this.videos,
    required this.note,
    required this.alertEnabled,
    required this.onBack,
    required this.onToggleClip,
    required this.onAddVideo,
    required this.onDelete,
    required this.onSaveNote,
    required this.onToggleAlert,
    this.pinned = false,
    this.onTogglePin,
    this.onCompare,
  });
  final Athlete athlete;

  /// A „Vissza” gomb felirata a megnyitás helye szerint.
  final String backLabel;
  final List<SavedYouTubeVideo> videos;
  final String note;
  final bool alertEnabled;
  final VoidCallback onBack;
  final ValueChanged<SavedYouTubeVideo> onToggleClip;
  final VoidCallback onAddVideo;
  final VoidCallback onDelete;
  final void Function(Athlete, String) onSaveNote;
  final ValueChanged<Athlete> onToggleAlert;

  /// Kitűzött-e a sportoló (a nyitóoldalon elöl jelenik meg).
  final bool pinned;
  final VoidCallback? onTogglePin;

  /// „Összehasonlítás…”: az Összehasonlítás oldal ezzel a sportolóval.
  final VoidCallback? onCompare;

  @override
  Widget build(BuildContext context) {
    final cb = context.cb;
    final spec = SportProfileSpec.of(athlete.sport);
    final liveCards = spec.liveCards(athlete);
    final target = athlete.eventsTarget;
    final horizontal = MediaQuery.sizeOf(context).width < 800 ? 20.0 : 34.0;
    final commands = CourtboardCommandScope.maybeOf(context);
    return ColoredBox(
      color: cb.canvas,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(horizontal, 20, horizontal, 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Tooltip(
                      message: 'Vissza (Esc vagy Alt+←)',
                      child: TextButton.icon(
                        key: const Key('profile-back'),
                        onPressed: onBack,
                        icon: const Icon(Icons.arrow_back),
                        label: Text(
                          backLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                ),
                if (pinned) ...[
                  const StatusPill(
                    'KITŰZVE',
                    key: Key('profile-pinned-badge'),
                    tone: StatusTone.accent,
                    icon: Icons.push_pin,
                  ),
                  const SizedBox(width: 6),
                ],
                _ProfileMoreMenu(
                  onRefresh: () => commands?.requestRefresh(),
                  onAddVideo: onAddVideo,
                  onDelete: onDelete,
                  pinned: pinned,
                  onTogglePin: onTogglePin,
                  onCompare: onCompare,
                ),
              ],
            ),
            const SizedBox(height: 12),
            ProfileHero(athlete: athlete),
            const SizedBox(height: 14),
            PersonalTools(
              note: note,
              alertEnabled: alertEnabled,
              onSaveNote: (value) => onSaveNote(athlete, value),
              onToggleAlert: () => onToggleAlert(athlete),
            ),
            // Zajló (vagy ma befejezett) meccs, és a következő mérkőzés az
            // egymás elleni mérleggel; adat nélkül egyik sem jelenik meg.
            if (LiveMatchCard.supports(target))
              LiveMatchCard(
                key: ValueKey('live-${athlete.name}'),
                target: target,
              ),
            NextMatchCard(
              key: ValueKey('next-${athlete.name}'),
              athlete: athlete,
            ),
            if (liveCards.isNotEmpty) ...[
              const SizedBox(height: 32),
              const SectionHeader(
                title: 'Élő adatok',
                subtitle:
                    'Valós adatforrásokból; minden kártya külön frissíthető.',
              ),
              for (var i = 0; i < liveCards.length; i++) ...[
                if (i > 0) const SizedBox(height: 16),
                liveCards[i],
              ],
            ],
            if (spec.showsGenericSummary) ...[
              const SizedBox(height: 32),
              const SectionHeader(title: 'Szezon összesítő'),
              if (athlete.metrics.isEmpty)
                const _ProfileEmptyNote(
                  'Ehhez a sportolóhoz még nincs valós szezonadat. A számok csak élő adatforrásból jelennek meg.',
                )
              else
                MetricGrid(
                  minTileWidth: 180,
                  maxColumns: 4,
                  children: [
                    for (final metric in athlete.metrics)
                      MetricTile(
                        label: metric.label,
                        value: metric.value,
                        caption: metric.note,
                        captionColor: athlete.accent,
                      ),
                  ],
                ),
              const SizedBox(height: 20),
              SportTemplate(athlete: athlete),
              const SizedBox(height: 32),
              const SectionHeader(
                title: 'Utóbbi mérkőzések',
                subtitle:
                    'Egységes mérkőzés-sablon: eredmény, sportág szerinti teljesítmény, értékelés.',
              ),
              if (athlete.matches.isEmpty)
                const _ProfileEmptyNote(
                  'Még nincs megjeleníthető mérkőzésadat ehhez a sportolóhoz.',
                )
              else
                ...athlete.matches.map(
                  (match) => MatchRow(
                    dateLabel: match.date,
                    opponent: match.opponent,
                    subtitle: match.performance,
                    score: match.score,
                    outcome: MatchOutcome.parse(match.result),
                    grade: match.grade,
                  ),
                ),
            ],
            const SizedBox(height: 32),
            SectionHeader(
              title: 'Videók és saját playlist',
              subtitle: '${videos.length} mentett videó',
              trailing: FilledButton.icon(
                onPressed: onAddVideo,
                icon: const Icon(Icons.add),
                label: const Text('Videó hozzáadása'),
              ),
            ),
            if (videos.isEmpty)
              const _ProfileEmptyNote(
                'Még nincs mentett videó. A „Videó hozzáadása” gombbal illessz be egy YouTube-linket vagy videóazonosítót.',
                icon: Icons.video_library_outlined,
              )
            else
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: videos
                    .map(
                      (video) => ClipCard(
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

/// A profil másodlagos műveletei egy „Továbbiak” menüben (a törlés
/// megerősítő párbeszédablakkal).
class _ProfileMoreMenu extends StatelessWidget {
  const _ProfileMoreMenu({
    required this.onRefresh,
    required this.onAddVideo,
    required this.onDelete,
    this.pinned = false,
    this.onTogglePin,
    this.onCompare,
  });

  final VoidCallback onRefresh;
  final VoidCallback onAddVideo;
  final VoidCallback onDelete;
  final bool pinned;
  final VoidCallback? onTogglePin;
  final VoidCallback? onCompare;

  @override
  Widget build(BuildContext context) {
    final cb = context.cb;
    Widget item(IconData icon, String label, {Color? color}) => Row(
      children: [
        Icon(icon, size: 20, color: color ?? cb.textPrimary),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            label,
            style: context.text.bodyMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
    return PopupMenuButton<String>(
      key: const Key('profile-more-menu'),
      tooltip: 'Továbbiak',
      // A menü az egész ablak fölött nyílik (nem a menüpont ágának
      // navigátorában), így az Esc a menüt zárja be, nem a profilt.
      useRootNavigator: true,
      icon: const Icon(Icons.more_horiz_rounded),
      position: PopupMenuPosition.under,
      onSelected: (value) => switch (value) {
        'refresh' => onRefresh(),
        'video' => onAddVideo(),
        'pin' => onTogglePin?.call(),
        'compare' => onCompare?.call(),
        'delete' => onDelete(),
        _ => null,
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'refresh',
          child: item(Icons.refresh_rounded, 'Adatok frissítése (Ctrl+R)'),
        ),
        PopupMenuItem(
          value: 'video',
          child: item(Icons.video_call_outlined, 'Videó hozzáadása'),
        ),
        if (onTogglePin != null)
          PopupMenuItem(
            key: const Key('profile-pin-athlete'),
            value: 'pin',
            child: item(
              pinned ? Icons.push_pin : Icons.push_pin_outlined,
              pinned ? 'Kitűzés megszüntetése' : 'Kitűzés',
            ),
          ),
        if (onCompare != null)
          PopupMenuItem(
            key: const Key('profile-compare-athlete'),
            value: 'compare',
            child: item(Icons.compare_arrows_rounded, 'Összehasonlítás…'),
          ),
        const PopupMenuDivider(),
        PopupMenuItem(
          key: const Key('profile-delete-athlete'),
          value: 'delete',
          child: item(
            Icons.delete_outline,
            'Sportoló törlése…',
            color: cb.error,
          ),
        ),
      ],
    );
  }
}

class _ProfileEmptyNote extends StatelessWidget {
  const _ProfileEmptyNote(this.message, {this.icon = Icons.inbox_outlined});
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) => SurfaceCard(
    padding: const EdgeInsets.all(18),
    child: EmptyState(compact: true, icon: icon, message: message),
  );
}
