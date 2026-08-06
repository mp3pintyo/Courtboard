part of '../main.dart';

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({required this.athlete});
  final Athlete athlete;
  @override
  Widget build(BuildContext context) => Container(
    height: 380,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(32),
      color: _ink,
    ),
    child: Stack(
      children: [
        Positioned.fill(
          child: Image.network(
            athlete.photoUrl,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            errorBuilder: (_, __, ___) => Container(color: athlete.accent),
          ),
        ),
        Positioned.fill(
          child: const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0x00151815), Color(0xED151815)],
                stops: [.22, 1],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ),
        Positioned(
          left: 28,
          bottom: 25,
          right: 28,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                width: 68,
                height: 68,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: athlete.accent,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                ),
                child: Text(
                  athlete.name.substring(0, 1),
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      athlete.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 42,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -2,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${athlete.sportAndTeam} · ${athlete.country}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              _Pill(text: 'KÖVETVE', color: _olive),
            ],
          ),
        ),
      ],
    ),
  );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.metric, required this.accent});
  final Metric metric;
  final Color accent;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: _paper,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFD8D4C8)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          metric.label,
          style: const TextStyle(
            fontSize: 10,
            color: _muted,
            fontWeight: FontWeight.w900,
            letterSpacing: .9,
          ),
        ),
        const SizedBox(height: 15),
        Text(
          metric.value,
          style: const TextStyle(
            fontSize: 31,
            fontWeight: FontWeight.w900,
            letterSpacing: -1.3,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          metric.note,
          style: TextStyle(
            color: accent,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ],
    ),
  );
}

class _SportTemplate extends StatelessWidget {
  const _SportTemplate({required this.athlete});
  final Athlete athlete;
  @override
  Widget build(BuildContext context) {
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
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: athlete.accent.withValues(alpha: .4),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            content.$1,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 7),
          Text(content.$2, style: const TextStyle(color: Color(0xFF3F4538))),
          const SizedBox(height: 22),
          Row(
            children: List.generate(
              content.$3.length,
              (index) => Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: index == 2 ? 0 : 14),
                  child: _FormBar(
                    label: content.$3[index],
                    value: [84, 72, 91][index],
                    color: athlete.accent,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FormBar extends StatelessWidget {
  const _FormBar({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final int value;
  final Color color;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
          ),
          Text(
            '$value%',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
          ),
        ],
      ),
      const SizedBox(height: 8),
      ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: LinearProgressIndicator(
          value: value / 100,
          minHeight: 11,
          color: _ink,
          backgroundColor: Colors.white.withValues(alpha: .58),
        ),
      ),
    ],
  );
}

class _MatchRow extends StatelessWidget {
  const _MatchRow({required this.match, required this.accent});
  final MatchLine match;
  final Color accent;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    decoration: BoxDecoration(
      color: _paper,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFD8D4C8)),
    ),
    child: Row(
      children: [
        SizedBox(
          width: 62,
          child: Text(
            match.date,
            style: const TextStyle(
              fontSize: 11,
              color: _muted,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            match.opponent,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        Expanded(
          child: Text(
            match.result,
            style: TextStyle(
              color: accent,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        SizedBox(
          width: 88,
          child: Text(
            match.score,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            match.performance,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _muted, fontSize: 12),
          ),
        ),
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
          child: Text(
            match.grade,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
          ),
        ),
      ],
    ),
  );
}

class _ClipCard extends StatelessWidget {
  const _ClipCard({required this.video, required this.onRemove});
  final SavedYouTubeVideo video;
  final VoidCallback onRemove;
  void _play() => Process.start('cmd', ['/c', 'start', '', video.watchUrl]);
  @override
  Widget build(BuildContext context) => Container(
    width: 305,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: _ink,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.network(
            video.thumbnailUrl,
            height: 106,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const SizedBox(
              height: 106,
              child: Center(
                child: Icon(Icons.broken_image, color: Colors.white),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          video.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Mentve: ${video.savedAt.year}.${video.savedAt.month.toString().padLeft(2, '0')}.${video.savedAt.day.toString().padLeft(2, '0')}',
          style: const TextStyle(color: Colors.white60, fontSize: 12),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            TextButton.icon(
              onPressed: _play,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Lejátszás'),
            ),
            const Spacer(),
            IconButton(
              onPressed: onRemove,
              icon: const Icon(Icons.delete_outline, color: Colors.white),
            ),
          ],
        ),
      ],
    ),
  );
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
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: _paper,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFD8D4C8)),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'SAJÁT JEGYZET',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: _muted,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                note.isEmpty ? 'Még nincs jegyzet ehhez a sportolóhoz.' : note,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        TextButton.icon(
          onPressed: () {
            final controller = TextEditingController(text: note);
            showDialog<void>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Saját jegyzet'),
                content: TextField(
                  controller: controller,
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
                    onPressed: () {
                      onSaveNote(controller.text.trim());
                      Navigator.pop(context);
                    },
                    child: const Text('Mentés'),
                  ),
                ],
              ),
            );
          },
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Szerkesztés'),
        ),
        const SizedBox(width: 8),
        FilterChip(
          label: Text(alertEnabled ? 'Értesítés aktív' : 'Értesítés ki'),
          selected: alertEnabled,
          onSelected: (_) => onToggleAlert(),
          avatar: Icon(
            alertEnabled
                ? Icons.notifications_active
                : Icons.notifications_off_outlined,
            size: 16,
          ),
        ),
      ],
    ),
  );
}
