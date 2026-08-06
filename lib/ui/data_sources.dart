part of '../main.dart';

class _DataStatusPage extends StatefulWidget {
  const _DataStatusPage({
    required this.config,
    required this.onSaveFootballKey,
    required this.onSaveApiSportsKey,
    required this.onSaveBallDontLieKey,
    required this.onSaveRapidApiDartsKey,
    required this.onSaveLiveTennisKey,
  });
  final SportsApiConfig config;
  final ValueChanged<String> onSaveFootballKey;
  final ValueChanged<String> onSaveApiSportsKey;
  final ValueChanged<String> onSaveBallDontLieKey;
  final ValueChanged<String> onSaveRapidApiDartsKey;
  final ValueChanged<String> onSaveLiveTennisKey;

  @override
  State<_DataStatusPage> createState() => _DataStatusPageState();
}

class _DataStatusPageState extends State<_DataStatusPage> {
  final _searchController = TextEditingController();
  String _sport = 'Mind';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _editKey({
    required String title,
    required String value,
    required ValueChanged<String> onSave,
  }) {
    final controller = TextEditingController(text: value);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'API-kulcs'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Mégse'),
          ),
          FilledButton(
            onPressed: () {
              onSave(controller.text.trim());
              Navigator.pop(dialogContext);
            },
            child: const Text('Mentés'),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }

  Future<void> _openDocs(String url) async {
    try {
      await Process.start('cmd', ['/c', 'start', '', url]);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A dokumentáció nem nyitható meg.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const sports = [
      'Mind',
      'NBA',
      'WNBA',
      'Foci',
      'Női foci',
      'Darts',
      'Tenisz',
      'NFL',
      'Hírek',
      'Videó',
    ];
    final rows = filterProviderCatalog(_searchController.text, _sport);
    final activeCount = providerCatalog
        .where(
          (entry) =>
              entry.stage == ProviderStage.active &&
              entry.isConfigured(widget.config),
        )
        .length;
    final noKeyCount = providerCatalog
        .where(
          (entry) =>
              entry.stage == ProviderStage.active &&
              entry.key == ProviderKey.none,
        )
        .length;
    return Container(
      color: _canvas,
      child: ListView(
        key: const Key('provider-documentation-list'),
        padding: const EdgeInsets.all(34),
        children: [
          const Text(
            'Adatforrás-kézikönyv',
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.5,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Keresd ki, melyik szolgáltató mit ad az apphoz, hol jelenik meg, '
            'milyen kulcs és kvóta tartozik hozzá, és mi történik hiba esetén.',
            style: TextStyle(color: _muted),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _SummaryBadge(
                icon: Icons.hub_outlined,
                value: '${providerCatalog.length}',
                label: 'dokumentált forrás',
              ),
              _SummaryBadge(
                icon: Icons.check_circle_outline,
                value: '$activeCount',
                label: 'most használható',
              ),
              _SummaryBadge(
                icon: Icons.key_off_outlined,
                value: '$noKeyCount',
                label: 'saját kulcs nélkül',
              ),
            ],
          ),
          const SizedBox(height: 18),
          const _GettingStartedCard(),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _paper,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'API-kulcsok',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Mind opcionális. A mentett RapidAPI kulcsot a Darts és a WNBA API is használja, de mindkét API-ra külön fel kell iratkozni.',
                  style: TextStyle(color: _muted),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 9,
                  runSpacing: 9,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _editKey(
                        title: 'football-data.org API-kulcs',
                        value: widget.config.footballDataKey,
                        onSave: widget.onSaveFootballKey,
                      ),
                      icon: const Icon(Icons.key_rounded),
                      label: const Text('football-data.org'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _editKey(
                        title: 'API-Sports API-kulcs',
                        value: widget.config.apiSportsKey,
                        onSave: widget.onSaveApiSportsKey,
                      ),
                      icon: const Icon(Icons.key_rounded),
                      label: const Text('API-Sports'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _editKey(
                        title: 'BALLDONTLIE API-kulcs',
                        value: widget.config.balldontlieKey,
                        onSave: widget.onSaveBallDontLieKey,
                      ),
                      icon: const Icon(Icons.key_rounded),
                      label: const Text('BALLDONTLIE'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _editKey(
                        title: 'RapidAPI közös alkalmazáskulcs',
                        value: widget.config.rapidApiDartsKey,
                        onSave: widget.onSaveRapidApiDartsKey,
                      ),
                      icon: const Icon(Icons.key_rounded),
                      label: const Text('RapidAPI · Darts + WNBA'),
                    ),
                    OutlinedButton.icon(
                      key: const Key('live-tennis-key-button'),
                      onPressed: () => _editKey(
                        title: 'Live Tennis API-kulcs',
                        value: widget.config.liveTennisKey,
                        onSave: widget.onSaveLiveTennisKey,
                      ),
                      icon: const Icon(Icons.key_rounded),
                      label: const Text('Live Tennis API'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          TextField(
            key: const Key('provider-doc-search'),
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Keresés: pl. Aitana, 100/hó, profilkép, cache…',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Keresés törlése',
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
              filled: true,
              fillColor: _paper,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: sports
                  .map(
                    (sport) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(sport),
                        selected: _sport == sport,
                        onSelected: (_) => setState(() => _sport = sport),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${rows.length} találat',
            style: const TextStyle(color: _muted, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          if (rows.isEmpty)
            const _EmptyProviderSearch()
          else
            ...rows.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ProviderDocumentationCard(
                  entry: entry,
                  configured: entry.isConfigured(widget.config),
                  onOpenDocs: () => _openDocs(entry.docsUrl),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SummaryBadge extends StatelessWidget {
  const _SummaryBadge({
    required this.icon,
    required this.value,
    required this.label,
  });
  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: _paper,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: _moss),
        const SizedBox(width: 8),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(color: _muted)),
      ],
    ),
  );
}

class _GettingStartedCard extends StatelessWidget {
  const _GettingStartedCard();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: _ink,
      borderRadius: BorderRadius.circular(18),
    ),
    child: const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ELSŐ INDÍTÁS · 3 LÉPÉS',
          style: TextStyle(
            color: _olive,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
        ),
        SizedBox(height: 12),
        _SetupStep(number: '1', text: 'Indítsd a start-courtboard.ps1 fájlt.'),
        _SetupStep(
          number: '2',
          text: 'Az opcionális kulcsokat itt add meg; nélkülük is elindul.',
        ),
        _SetupStep(
          number: '3',
          text:
              'Vegyél fel vagy nyiss meg egy sportolót; az elérhető források együtt töltik ki a kártyáját.',
        ),
      ],
    ),
  );
}

class _SetupStep extends StatelessWidget {
  const _SetupStep({required this.number, required this.text});
  final String number;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 23,
          height: 23,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: _olive,
            shape: BoxShape.circle,
          ),
          child: Text(
            number,
            style: const TextStyle(color: _ink, fontWeight: FontWeight.w900),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: const TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );
}

class _ProviderDocumentationCard extends StatelessWidget {
  const _ProviderDocumentationCard({
    required this.entry,
    required this.configured,
    required this.onOpenDocs,
  });
  final ProviderCatalogEntry entry;
  final bool configured;
  final VoidCallback onOpenDocs;

  @override
  Widget build(BuildContext context) {
    final prepared = entry.stage == ProviderStage.prepared;
    final status = prepared
        ? 'ELŐKÉSZÍTVE'
        : entry.key == ProviderKey.none
        ? 'KULCS NÉLKÜL'
        : configured
        ? 'BEKÖTVE'
        : 'KULCS HIÁNYZIK';
    final statusColor = prepared
        ? _muted
        : configured
        ? _moss
        : Colors.orange.shade800;
    return Material(
      color: _paper,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: Key('provider-${entry.name}'),
        tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        leading: Icon(
          prepared
              ? Icons.construction_rounded
              : configured
              ? Icons.check_circle_rounded
              : Icons.key_off_rounded,
          color: statusColor,
        ),
        title: Text(
          entry.name,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(entry.role),
        ),
        trailing: _StatusLabel(text: status, color: statusColor),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: entry.sports
                  .map(
                    (sport) => Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text(sport),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 12),
          _DocumentationSection(
            title: 'MI JELENIK MEG?',
            items: entry.visibleOutput,
          ),
          _DocumentationSection(
            title: 'MIRE KÉPES?',
            items: entry.capabilities,
          ),
          _DocumentationFact(label: 'Hozzáférés', value: entry.authentication),
          _DocumentationFact(label: 'Limit', value: entry.limit),
          _DocumentationFact(label: 'Cache', value: entry.cache),
          _DocumentationFact(label: 'Beállítás', value: entry.setup),
          _DocumentationFact(label: 'Hiba esetén', value: entry.fallback),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onOpenDocs,
              icon: const Icon(Icons.open_in_new_rounded, size: 17),
              label: const Text('Hivatalos dokumentáció'),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusLabel extends StatelessWidget {
  const _StatusLabel({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900),
    ),
  );
}

class _DocumentationSection extends StatelessWidget {
  const _DocumentationSection({required this.title, required this.items});
  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: .8,
          ),
        ),
        const SizedBox(height: 5),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('•  ', style: TextStyle(color: _moss)),
                Expanded(child: Text(item)),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _DocumentationFact extends StatelessWidget {
  const _DocumentationFact({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: const TextStyle(color: _muted, fontWeight: FontWeight.w800),
          ),
        ),
        Expanded(child: Text(value)),
      ],
    ),
  );
}

class _EmptyProviderSearch extends StatelessWidget {
  const _EmptyProviderSearch();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: _paper,
      borderRadius: BorderRadius.circular(16),
    ),
    child: const Column(
      children: [
        Icon(Icons.search_off_rounded, color: _muted),
        SizedBox(height: 8),
        Text(
          'Nincs ilyen adatforrás vagy funkció.',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        SizedBox(height: 3),
        Text(
          'Próbálj sportágra, megjelenő adatra vagy kvótára keresni.',
          textAlign: TextAlign.center,
          style: TextStyle(color: _muted),
        ),
      ],
    ),
  );
}
