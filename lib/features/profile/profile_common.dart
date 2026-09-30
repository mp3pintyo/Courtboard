import 'dart:async';
import 'package:flutter/material.dart';
import 'package:courtboard/shared/common_ui.dart';
import 'package:courtboard/shared/components.dart';
import 'package:courtboard/shared/format.dart';
import 'package:courtboard/shared/images.dart';
import 'package:courtboard/shared/theme/courtboard_theme.dart';
import 'package:courtboard/data/athlete_highlights.dart';
import 'package:courtboard/data/youtube_playlist.dart';
import 'package:courtboard/domain/athlete.dart';
import 'package:courtboard/features/profile/sport_profile_spec.dart';

/// A profil fejléce (~220–240 px): bal oldalon név és sportág/csapat/ország,
/// jobb oldalon az arcra igazított fotó (vagy a sportoló színéből képzett
/// átmenet), sötét átmenettel a szöveg felé.
class ProfileHero extends StatelessWidget {
  const ProfileHero({super.key, required this.athlete});
  final Athlete athlete;

  @override
  Widget build(BuildContext context) {
    final cb = context.cb;
    final details = athlete.showsCountry
        ? '${athlete.sportAndTeam} · ${athlete.country}'
        : athlete.sportAndTeam;
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 620;
        final photoWidth = narrow
            ? constraints.maxWidth * .5
            : (constraints.maxWidth * .44).clamp(260.0, 560.0);
        return Container(
          key: const Key('profile-hero'),
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 220),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            color: cb.ink,
            // Sötét módban a hero finom kerettel válik el a vászontól.
            border: cb.isDark ? Border.all(color: cb.border) : null,
          ),
          child: Stack(
            alignment: Alignment.bottomLeft,
            children: [
              Positioned(
                top: 0,
                right: 0,
                bottom: 0,
                width: photoWidth,
                child: CourtboardImage(
                  url: athlete.photoUrl,
                  // Az álló portrékon az arc a kép felső harmadában van.
                  alignment: const Alignment(0, -0.3),
                  semanticLabel: '${athlete.name} fotója',
                  placeholder: InitialsPlaceholder(
                    name: athlete.name,
                    color: athlete.accent,
                    showInitials: false,
                  ),
                ),
              ),
              // A fotó bal széle beleolvad a sötét felületbe.
              Positioned(
                top: 0,
                bottom: 0,
                right: photoWidth - 200,
                width: 200,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [cb.ink, cb.ink.withValues(alpha: 0)],
                    ),
                  ),
                ),
              ),
              // Keskeny helyen a fotóra is kerülhet szöveg: alul sötétítünk.
              if (narrow)
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          cb.ink.withValues(alpha: 0),
                          cb.ink.withValues(alpha: .85),
                        ],
                        stops: const [.3, 1],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  28,
                  28,
                  narrow ? 28 : photoWidth * .7,
                  26,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: athlete.accent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Semantics(
                      header: true,
                      child: Text(
                        athlete.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.displayLarge?.copyWith(
                          color: cb.onInk,
                          fontSize: narrow ? 34 : 42,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      details,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodyLarge?.copyWith(
                        color: cb.onInkMuted,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// A profil adatkártyái a betöltött mérkőzésekből kiemelést mentenek a
/// nyitóoldal számára (legutóbbi eredmény, következő esemény). A mentés
/// háttérben fut, és a hibája soha nem érinti a kártyát.
///
/// A [store] alapból a közös tároló (a kártyák a `highlightStoreProvider`
/// példányát adják át).
Future<T> withHighlights<T>(
  String athleteName,
  Future<T> future,
  Iterable<HighlightEvent> Function(T value) events, {
  AthleteHighlightStore? store,
}) async {
  final value = await future;
  try {
    unawaited(
      (store ?? AthleteHighlightStore.shared).record(
        athleteName,
        events(value).toList(),
      ),
    );
  } catch (_) {
    // Kényelmi adat: hibánál egyszerűen nem mentünk.
  }
  return value;
}

HighlightEvent highlightEvent(
  DateTime date,
  String title,
  MatchOutcome outcome, [
  String? score,
]) => HighlightEvent(
  date: date,
  title: title,
  outcome: outcome == MatchOutcome.unknown ? '' : outcome.name,
  score: score == null ? '' : normalizeScore(score),
);

class SportTemplate extends StatelessWidget {
  const SportTemplate({super.key, required this.athlete});
  final Athlete athlete;

  @override
  Widget build(BuildContext context) {
    final cb = context.cb;
    final content = SportProfileSpec.of(athlete.sport).template;
    // A sportoló színe halványan a felülethez keverve: a szöveg mindkét
    // módban a normál szövegtokenekkel olvasható.
    final background = Color.alphaBlend(
      athlete.accent.withValues(alpha: cb.isDark ? .16 : .32),
      cb.surface,
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            content.title,
            style: context.text.labelMedium?.copyWith(
              color: cb.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 7),
          Text(content.description, style: context.text.bodyMedium),
          // Formamutatót csak valós adatból rajzolunk; amíg nincs ilyen
          // forrás, a jelzők neve szerepel, kitalált százalék nélkül.
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: content.indicators
                .map((label) => StatusPill(label.toUpperCase()))
                .toList(),
          ),
          const SizedBox(height: 10),
          Text(
            'A formagörbe az élő adatkártyán jelenik meg, amint legalább két '
            'valós mérkőzés adata elérhető.',
            style: context.text.bodySmall?.copyWith(color: cb.textPrimary),
          ),
        ],
      ),
    );
  }
}

class ClipCard extends StatelessWidget {
  const ClipCard({super.key, required this.video, required this.onRemove});
  final SavedYouTubeVideo video;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final cb = context.cb;
    return Container(
      width: 305,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cb.ink,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: CourtboardImage(
                url: video.thumbnailUrl,
                semanticLabel: 'Videó bélyegképe: ${video.title}',
                placeholder: ColoredBox(
                  color: cb.inkRaised,
                  child: Center(
                    child: Icon(
                      Icons.video_library_outlined,
                      color: cb.onInkMuted,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            video.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.text.titleSmall?.copyWith(color: cb.onInk),
          ),
          const SizedBox(height: 4),
          Text(
            'Mentve: ${formatDate(video.savedAt)}',
            style: context.text.bodySmall?.copyWith(color: cb.onInkMuted),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: cb.highlight),
                onPressed: () => openExternalUrl(context, video.watchUrl),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Lejátszás'),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Videó eltávolítása',
                onPressed: onRemove,
                icon: Icon(Icons.delete_outline, color: cb.onInk),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class PersonalTools extends StatelessWidget {
  const PersonalTools({
    super.key,
    required this.note,
    required this.alertEnabled,
    required this.onSaveNote,
    required this.onToggleAlert,
  });
  final String note;
  final bool alertEnabled;
  final ValueChanged<String> onSaveNote;
  final VoidCallback onToggleAlert;

  @override
  Widget build(BuildContext context) {
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('SAJÁT JEGYZET', style: context.text.labelMedium),
        const SizedBox(height: 5),
        Text(
          note.isEmpty ? 'Még nincs jegyzet ehhez a sportolóhoz.' : note,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: context.text.bodyMedium?.copyWith(
            color: note.isEmpty ? context.cb.textMuted : null,
          ),
        ),
      ],
    );
    final actions = _actions(context);
    return SurfaceCard(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        // Keskeny helyen a gombok a jegyzet alá kerülnek.
        builder: (context, constraints) => constraints.maxWidth < 560
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  text,
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: actions,
                  ),
                ],
              )
            : Row(
                children: [
                  Expanded(child: text),
                  const SizedBox(width: 8),
                  ...actions,
                ],
              ),
      ),
    );
  }

  List<Widget> _actions(BuildContext context) => [
    TextButton.icon(
      onPressed: () async {
        final value = await showDialog<String>(
          context: context,
          builder: (_) => _NoteDialog(initialValue: note),
        );
        if (value != null) onSaveNote(value);
      },
      icon: const Icon(Icons.edit_outlined),
      label: const Text('Szerkesztés'),
    ),
    FilterChip(
      label: Text(alertEnabled ? 'Értesítés aktív' : 'Értesítés ki'),
      selected: alertEnabled,
      showCheckmark: false,
      onSelected: (_) => onToggleAlert(),
      avatar: Icon(
        alertEnabled
            ? Icons.notifications_active
            : Icons.notifications_off_outlined,
        size: 16,
      ),
    ),
  ];
}

/// Jegyzetszerkesztő párbeszédablak; a vezérlőt a saját állapota birtokolja
/// és szabadítja fel, így az a bezárási animáció alatt is érvényes marad.
class _NoteDialog extends StatefulWidget {
  const _NoteDialog({required this.initialValue});
  final String initialValue;

  @override
  State<_NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<_NoteDialog> {
  late final _controller = TextEditingController(text: widget.initialValue);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Saját jegyzet'),
    content: TextField(
      controller: _controller,
      autofocus: true,
      maxLines: 4,
      decoration: const InputDecoration(
        hintText: 'Mit szeretnél észben tartani?',
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Mégse'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _controller.text.trim()),
        child: const Text('Mentés'),
      ),
    ],
  );
}
