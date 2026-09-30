part of '../main.dart';

class _DataStatusPage extends StatefulWidget {
  const _DataStatusPage({
    required this.config,
    required this.onSaveKey,
    this.secureStorageAvailable = true,
  });
  final SportsApiConfig config;
  final void Function(ApiKeyId id, String value) onSaveKey;

  /// Hamis esetén figyelmeztetés: a kulcsok nem a biztonságos tárolóban vannak.
  final bool secureStorageAvailable;

  @override
  State<_DataStatusPage> createState() => _DataStatusPageState();
}

class _DataStatusPageState extends State<_DataStatusPage> {
  final _searchController = TextEditingController();
  String _sport = 'Mind';

  /// A napi/havi kerettel rendelkező szolgáltatók helyi kérésszámlálója.
  late final Future<List<QuotaUsage>> _quota = HttpService.shared.quota
      .snapshot();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// A kulcsgombok felirata és a szerkesztőablak címe.
  static const _keyButtons = <(ApiKeyId, String, String)>[
    (ApiKeyId.footballData, 'football-data.org', 'football-data.org API-kulcs'),
    (ApiKeyId.apiSports, 'API-Sports', 'API-Sports API-kulcs'),
    (ApiKeyId.balldontlie, 'BALLDONTLIE', 'BALLDONTLIE API-kulcs'),
    (ApiKeyId.rapidApi, 'RapidAPI (Darts + WNBA)', 'RapidAPI közös kulcs'),
    (ApiKeyId.liveTennis, 'Live Tennis API', 'Live Tennis API-kulcs'),
  ];

  /// A kulcs szerkesztése; a dialógus csak mentéskor ad vissza értéket.
  Future<void> _editKey(ApiKeyId id, String title) async {
    final value = await showDialog<String>(
      context: context,
      builder: (_) =>
          _ApiKeyDialog(title: title, initialValue: widget.config.key(id)),
    );
    if (value != null) widget.onSaveKey(id, value);
  }

  Future<void> _openDocs(String url) => openExternalUrl(context, url);

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
      'Naptár',
      'Alkalmazás',
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
    final cb = context.cb;
    return ColoredBox(
      color: cb.canvas,
      child: ListView(
        key: const Key('provider-documentation-list'),
        padding: const EdgeInsets.all(34),
        children: [
          const PageHeader(
            title: 'Adatforrás-kézikönyv',
            subtitle:
                'Keresd ki, melyik szolgáltató mit ad az apphoz, hol jelenik meg, '
                'milyen kulcs és kvóta tartozik hozzá, és mi történik hiba esetén.',
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _SummaryBadge(
                icon: Icons.hub_outlined,
                value: formatInt(providerCatalog.length),
                label: 'dokumentált forrás',
              ),
              _SummaryBadge(
                icon: Icons.check_circle_outline,
                value: formatInt(activeCount),
                label: 'most használható',
              ),
              _SummaryBadge(
                icon: Icons.key_off_outlined,
                value: formatInt(noKeyCount),
                label: 'saját kulcs nélkül',
              ),
            ],
          ),
          const SizedBox(height: 18),
          const _GettingStartedCard(),
          const SizedBox(height: 18),
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('API-kulcsok', style: context.text.titleLarge),
                const SizedBox(height: 5),
                Text(
                  'Mind opcionális. A kulcsok a Windows biztonságos tárolójában '
                  '(Hitelesítőadat-kezelő, titkosítva) kerülnek mentésre. '
                  'A közös RapidAPI kulcsot a Darts és a WNBA API is használja, '
                  'de mindkét API-ra külön fel kell iratkozni.',
                  style: context.text.bodyMedium?.copyWith(color: cb.textMuted),
                ),
                if (!widget.secureStorageAvailable) ...[
                  const SizedBox(height: 12),
                  const _SecureStorageWarning(),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 9,
                  runSpacing: 9,
                  children: [
                    for (final (id, label, title) in _keyButtons)
                      OutlinedButton.icon(
                        key: Key('api-key-button-${id.name}'),
                        onPressed: () => unawaited(_editKey(id, title)),
                        icon: const Icon(Icons.key_rounded),
                        label: Text(label),
                      ),
                  ],
                ),
                _QuotaUsageLines(future: _quota),
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
            style: context.text.titleSmall?.copyWith(color: cb.textMuted),
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

/// API-kulcs szerkesztőablak. A vezérlőt a dialógus saját állapota birtokolja,
/// így a bezáró animáció alatt sem használ felszabadított vezérlőt.
class _ApiKeyDialog extends StatefulWidget {
  const _ApiKeyDialog({required this.title, required this.initialValue});

  final String title;
  final String initialValue;

  @override
  State<_ApiKeyDialog> createState() => _ApiKeyDialogState();
}

class _ApiKeyDialogState extends State<_ApiKeyDialog> {
  late final _controller = TextEditingController(text: widget.initialValue);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() => Navigator.pop(context, _controller.text.trim());

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(
      controller: _controller,
      obscureText: true,
      autofocus: true,
      onSubmitted: (_) => _save(),
      decoration: const InputDecoration(labelText: 'API-kulcs'),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Mégse'),
      ),
      FilledButton(onPressed: _save, child: const Text('Mentés')),
    ],
  );
}

/// Figyelmeztetés, ha a Windows biztonságos tárolója nem érhető el.
class _SecureStorageWarning extends StatelessWidget {
  const _SecureStorageWarning();

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('secure-storage-warning'),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: context.cb.tint(context.cb.warning, .12),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: context.cb.tint(context.cb.warning, .5)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.warning_amber_rounded, color: context.cb.warning),
        const SizedBox(width: 10),
        const Expanded(
          child: Text(
            'A Windows biztonságos kulcstárolója most nem érhető el. '
            'Az API-kulcsok ebben a munkamenetben csak a memóriában élnek: '
            'a korábban mentett kulcsok megmaradnak a helyi állapotfájlban, '
            'az itt most módosított kulcsok viszont az app bezárásakor '
            'elvesznek. Indítsd újra az appot, és próbáld újra.',
          ),
        ),
      ],
    ),
  );
}

/// A helyi kéréskeret-számláló állása szolgáltatónként, egyszerű szövegként
/// (például „API-Sports · Ma: 12 / 100 kérés”).
class _QuotaUsageLines extends StatelessWidget {
  const _QuotaUsageLines({required this.future});

  final Future<List<QuotaUsage>> future;

  @override
  Widget build(BuildContext context) => FutureBuilder<List<QuotaUsage>>(
    future: future,
    builder: (context, snapshot) {
      final usages = snapshot.data ?? const <QuotaUsage>[];
      if (usages.isEmpty) return const SizedBox.shrink();
      return Padding(
        key: const Key('quota-usage'),
        padding: const EdgeInsets.only(top: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('HELYI KÉRÉSKERET', style: context.text.labelMedium),
            const SizedBox(height: 4),
            for (final usage in usages)
              Text(
                '${usage.provider} · ${usage.label}',
                style: context.text.bodySmall,
              ),
          ],
        ),
      );
    },
  );
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
      color: context.cb.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: context.cb.border),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: context.cb.accent),
        const SizedBox(width: 8),
        Text(value, style: context.text.titleMedium),
        const SizedBox(width: 5),
        Text(
          label,
          style: context.text.bodyMedium?.copyWith(color: context.cb.textMuted),
        ),
      ],
    ),
  );
}

class _GettingStartedCard extends StatelessWidget {
  const _GettingStartedCard();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: context.cb.ink,
      borderRadius: BorderRadius.circular(20),
      border: context.cb.isDark ? Border.all(color: context.cb.border) : null,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ELSŐ INDÍTÁS · 3 LÉPÉS',
          style: context.text.labelMedium?.copyWith(
            color: context.cb.highlight,
            fontSize: 13,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 12),
        const _SetupStep(
          number: '1',
          text: 'Indítsd a start-courtboard.ps1 fájlt.',
        ),
        const _SetupStep(
          number: '2',
          text: 'Az opcionális kulcsokat itt add meg; nélkülük is elindul.',
        ),
        const _SetupStep(
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
          decoration: BoxDecoration(
            color: context.cb.highlight,
            shape: BoxShape.circle,
          ),
          child: Text(
            number,
            style: context.text.labelSmall?.copyWith(
              color: context.cb.onHighlight,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: context.text.bodyMedium?.copyWith(color: context.cb.onInk),
          ),
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
    final cb = context.cb;
    final tone = prepared
        ? StatusTone.neutral
        : configured
        ? StatusTone.success
        : StatusTone.warning;
    final statusColor = prepared
        ? cb.textMuted
        : configured
        ? cb.win
        : cb.warning;
    return Material(
      color: cb.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cb.border),
      ),
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
        title: Text(entry.name, style: context.text.titleMedium),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            entry.role,
            style: context.text.bodyMedium?.copyWith(color: cb.textMuted),
          ),
        ),
        trailing: StatusPill(status, tone: tone),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: entry.sports
                  .map((sport) => StatusPill(sport, tone: StatusTone.accent))
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
        Text(title, style: context.text.labelMedium),
        const SizedBox(height: 5),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('•  ', style: TextStyle(color: context.cb.accent)),
                Expanded(child: Text(item, style: context.text.bodyMedium)),
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
          width: 104,
          child: Text(
            label,
            style: context.text.titleSmall?.copyWith(
              color: context.cb.textMuted,
            ),
          ),
        ),
        Expanded(child: Text(value, style: context.text.bodyMedium)),
      ],
    ),
  );
}

class _EmptyProviderSearch extends StatelessWidget {
  const _EmptyProviderSearch();

  @override
  Widget build(BuildContext context) => const SurfaceCard(
    padding: EdgeInsets.all(24),
    child: EmptyState(
      icon: Icons.search_off_rounded,
      title: 'Nincs ilyen adatforrás vagy funkció.',
      message: 'Próbálj sportágra, megjelenő adatra vagy kvótára keresni.',
    ),
  );
}
