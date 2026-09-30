part of '../main.dart';

/// A profil fejléce (~220–240 px): bal oldalon név és sportág/csapat/ország,
/// jobb oldalon az arcra igazított fotó (vagy a sportoló színéből képzett
/// átmenet), sötét átmenettel a szöveg felé.
class _ProfileHero extends StatelessWidget {
  const _ProfileHero({required this.athlete});
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
Future<T> _withHighlights<T>(
  String athleteName,
  Future<T> future,
  Iterable<HighlightEvent> Function(T value) events,
) async {
  final value = await future;
  try {
    unawaited(
      AthleteHighlightStore.shared.record(athleteName, events(value).toList()),
    );
  } catch (_) {
    // Kényelmi adat: hibánál egyszerűen nem mentünk.
  }
  return value;
}

HighlightEvent _highlight(
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

class _SportTemplate extends StatelessWidget {
  const _SportTemplate({required this.athlete});
  final Athlete athlete;

  @override
  Widget build(BuildContext context) {
    final cb = context.cb;
    final content = switch (athlete.sport) {
      'NBA' || 'WNBA' => (
        'JÁTÉKINTELLIGENCIA',
        'A pontszerzés, játékirányítás és lepattanózás formagörbéje.',
        ['Dobóforma', 'Játékszervezés', 'Védekezés'],
      ),
      'Foci' => (
        'TÁMADÓ HATÁS',
        'Gólveszély, kulcspasszok és labdabiztosság az utóbbi meccseken.',
        ['Gólveszély', 'Kreativitás', 'Passzjáték'],
      ),
      'Darts' => (
        'DOBÓFORMA',
        '3-dart átlag, kiszállózás és maximumok alakulása.',
        ['Átlag', 'Checkout', '180-asok'],
      ),
      'Tenisz' => (
        'TENISZPROFIL',
        'Ranglista, játékosprofil, élő állás és következő mérkőzések.',
        ['Ranglista', 'Borítás', 'Mérkőzésritmus'],
      ),
      'NFL' => (
        'TELJESÍTMÉNYPROFIL',
        'A szerepkörhöz igazított, egységes heti teljesítmény.',
        ['Hatékonyság', 'Explozivitás', 'Kulcsjátékok'],
      ),
      _ => (
        'TELJESÍTMÉNYPROFIL',
        'Sportág-specifikus formajelzők.',
        ['Forma', 'Hatékonyság', 'Hatás'],
      ),
    };
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
            content.$1,
            style: context.text.labelMedium?.copyWith(
              color: cb.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 7),
          Text(content.$2, style: context.text.bodyMedium),
          // Formamutatót csak valós adatból rajzolunk; amíg nincs ilyen
          // forrás, a jelzők neve szerepel, kitalált százalék nélkül.
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: content.$3
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

class _ClipCard extends StatelessWidget {
  const _ClipCard({required this.video, required this.onRemove});
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

class _PersonalTools extends StatelessWidget {
  const _PersonalTools({
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
