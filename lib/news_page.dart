import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import 'data/api_sports.dart' show normalizeAthleteName;
import 'data/news.dart';

const _newsCanvas = Color(0xFFECE9DF);
const _newsPaper = Color(0xFFF9F8F3);
const _newsMuted = Color(0xFF73766C);

class NewsAthleteRef {
  const NewsAthleteRef({required this.name, required this.sport});
  final String name;
  final String sport;
}

class NewsPage extends StatefulWidget {
  const NewsPage({
    super.key,
    required this.athletes,
    this.repository,
    this.autoRefresh = true,
  });

  final List<NewsAthleteRef> athletes;
  final NewsRepository? repository;
  final bool autoRefresh;

  @override
  State<NewsPage> createState() => _NewsPageState();
}

class _NewsPageState extends State<NewsPage> {
  late final NewsRepository _repository;
  final _search = TextEditingController();
  Timer? _debounce;
  List<NewsArticle> _articles = const [];
  List<NewsSourceState> _sources = const [];
  String _sport = 'Mind';
  String _source = 'Mind';
  String _athlete = 'Mind';
  bool _loading = true;
  bool _refreshing = false;
  int _storedCount = 0;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? NewsRepository();
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    await _reload();
    if (widget.autoRefresh) unawaited(_refresh());
  }

  Future<void> _reload() async {
    final articles = await _repository.store.query(
      text: _search.text,
      sport: _sport,
      sourceId: _source,
      athleteName: _athlete,
    );
    final sources = await _repository.store.sourceStates();
    final count = await _repository.store.count();
    if (!mounted) return;
    setState(() {
      _articles = articles;
      _sources = sources;
      _storedCount = count;
      _loading = false;
    });
  }

  Future<void> _refresh({bool force = false}) async {
    if (_refreshing) return;
    setState(() {
      _refreshing = true;
      _status = '';
    });
    final report = await _repository.refresh(force: force);
    if (!mounted) return;
    if (report.skipped) {
      _status = 'A feedek 20 percen belül már frissültek.';
    } else if (report.errors.isEmpty) {
      _status = report.newArticles == 0
          ? '${report.updatedSources} forrás frissítve, nem érkezett új hír.'
          : '${report.newArticles} új hír tartósan elmentve.';
    } else {
      _status =
          '${report.updatedSources} forrás frissült, ${report.errors.length} átmenetileg hibázott. A korábban mentett hírek elérhetők maradnak.';
    }
    setState(() => _refreshing = false);
    await _reload();
  }

  void _scheduleReload() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 220), _reload);
  }

  Future<void> _openSources() async {
    var states = List<NewsSourceState>.from(_sources);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Hírforrások kezelése'),
          content: SizedBox(
            width: 660,
            height: 560,
            child: ListView.separated(
              itemCount: states.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final state = states[index];
                final source = state.source;
                return SwitchListTile(
                  key: ValueKey('news-source-${source.id}'),
                  value: state.enabled,
                  title: Text(
                    '${source.name} · ${source.sport}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (source.termsNote.isNotEmpty) Text(source.termsNote),
                      if (state.lastError.isNotEmpty)
                        Text(
                          'Utolsó hiba: ${state.lastError}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.red),
                        ),
                    ],
                  ),
                  onChanged: (enabled) async {
                    await _repository.store.setSourceEnabled(
                      source.id,
                      enabled,
                    );
                    final refreshed = await _repository.store.sourceStates();
                    if (dialogContext.mounted) {
                      setDialogState(() => states = refreshed);
                    }
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Kész'),
            ),
          ],
        ),
      ),
    );
    await _reload();
    if (widget.autoRefresh) unawaited(_refresh());
  }

  void _clearFilters() {
    _search.clear();
    setState(() {
      _sport = 'Mind';
      _source = 'Mind';
      _athlete = 'Mind';
    });
    unawaited(_reload());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    if (widget.repository == null) unawaited(_repository.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sports = _sources.map((state) => state.source.sport).toSet().toList()
      ..sort();
    final enabledSources = _sources.where((state) => state.enabled).toList();
    final athleteNames =
        widget.athletes
            .where((athlete) => _sport == 'Mind' || athlete.sport == _sport)
            .map((athlete) => athlete.name)
            .toSet()
            .toList()
          ..sort(
            (a, b) =>
                normalizeAthleteName(a).compareTo(normalizeAthleteName(b)),
          );
    final activeAthlete = athleteNames.contains(_athlete) ? _athlete : 'Mind';

    return Container(
      color: _newsCanvas,
      padding: const EdgeInsets.fromLTRB(34, 28, 34, 34),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hírek',
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1.5,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Tartós hírarchívum: a már letöltött hírek később és hálózat nélkül is kereshetők.',
                      style: TextStyle(color: _newsMuted),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                key: const Key('news-source-settings'),
                onPressed: _openSources,
                icon: const Icon(Icons.tune_rounded),
                label: const Text('Források'),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                key: const Key('news-refresh-button'),
                onPressed: _refreshing ? null : () => _refresh(force: true),
                icon: _refreshing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync_rounded),
                label: Text(_refreshing ? 'Frissítés…' : 'Frissítés'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _NewsStat(value: '$_storedCount', label: 'tartósan tárolt hír'),
              _NewsStat(
                value: '${enabledSources.length}',
                label: 'aktív hírforrás',
              ),
              _NewsStat(
                value: '${_articles.length}',
                label: 'jelenlegi találat',
              ),
            ],
          ),
          if (_status.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              _status,
              key: const Key('news-refresh-status'),
              style: const TextStyle(color: _newsMuted),
            ),
          ],
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _newsPaper,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: [
                TextField(
                  key: const Key('news-search'),
                  controller: _search,
                  onChanged: (_) => _scheduleReload(),
                  decoration: InputDecoration(
                    hintText: 'Keresés a címekben és összefoglalókban…',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _search.text.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _search.clear();
                              _scheduleReload();
                              setState(() {});
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
                    border: InputBorder.none,
                  ),
                ),
                const Divider(),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        key: const Key('news-sport-filter'),
                        initialValue: _sport,
                        decoration: const InputDecoration(labelText: 'Sportág'),
                        items: ['Mind', ...sports]
                            .map(
                              (value) => DropdownMenuItem(
                                value: value,
                                child: Text(value),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            _sport = value ?? 'Mind';
                            _athlete = 'Mind';
                          });
                          unawaited(_reload());
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        key: const Key('news-athlete-filter'),
                        initialValue: activeAthlete,
                        decoration: const InputDecoration(
                          labelText: 'Sportoló',
                        ),
                        items: ['Mind', ...athleteNames]
                            .map(
                              (value) => DropdownMenuItem(
                                value: value,
                                child: Text(
                                  value,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setState(() => _athlete = value ?? 'Mind');
                          unawaited(_reload());
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        key: const Key('news-source-filter'),
                        initialValue: _source,
                        decoration: const InputDecoration(labelText: 'Forrás'),
                        items: [
                          const DropdownMenuItem(
                            value: 'Mind',
                            child: Text('Mind'),
                          ),
                          ..._sources.map(
                            (state) => DropdownMenuItem(
                              value: state.source.id,
                              child: Text(
                                '${state.source.name} · ${state.source.sport}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() => _source = value ?? 'Mind');
                          unawaited(_reload());
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Szűrők törlése',
                      onPressed: _clearFilters,
                      icon: const Icon(Icons.filter_alt_off_outlined),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _articles.isEmpty
                ? const _EmptyNews()
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
                          children: _articles
                              .map(
                                (article) => SizedBox(
                                  width: width,
                                  child: NewsArticleCard(
                                    article: article,
                                    athletes: widget.athletes,
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

class _NewsStat extends StatelessWidget {
  const _NewsStat({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: _newsPaper,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: _newsMuted)),
      ],
    ),
  );
}

class NewsArticleCard extends StatelessWidget {
  const NewsArticleCard({
    super.key,
    required this.article,
    required this.athletes,
  });
  final NewsArticle article;
  final List<NewsAthleteRef> athletes;

  @override
  Widget build(BuildContext context) {
    final related = athletes
        .where((athlete) => newsMatchesAthlete(article, athlete.name))
        .map((athlete) => athlete.name)
        .take(3)
        .toList();
    return Material(
      color: _newsPaper,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('news-${article.dedupeKey}'),
        onTap: () => _openArticle(article.url),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (article.imageUrl.isNotEmpty)
              AspectRatio(
                aspectRatio: 16 / 8,
                child: Image.network(
                  article.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: const Color(0xFFDDE1D0),
                    child: const Icon(
                      Icons.newspaper_rounded,
                      size: 44,
                      color: _newsMuted,
                    ),
                  ),
                ),
              )
            else
              Container(
                height: 82,
                color: const Color(0xFFDDE1D0),
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: const Icon(
                  Icons.newspaper_rounded,
                  size: 38,
                  color: _newsMuted,
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      _NewsChip(article.sourceName),
                      _NewsChip(article.sport),
                      if (related.isNotEmpty) _NewsChip(related.join(' · ')),
                    ],
                  ),
                  const SizedBox(height: 11),
                  Text(
                    article.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      height: 1.2,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (article.summary.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      article.summary,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _newsMuted,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                  const SizedBox(height: 13),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _newsDate(article.publishedAt),
                          style: const TextStyle(
                            color: _newsMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const Text(
                        'Eredeti cikk',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.open_in_new_rounded, size: 15),
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
}

class _NewsChip extends StatelessWidget {
  const _NewsChip(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.secondaryContainer,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900),
    ),
  );
}

class _EmptyNews extends StatelessWidget {
  const _EmptyNews();

  @override
  Widget build(BuildContext context) => const Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.newspaper_outlined, size: 46, color: _newsMuted),
        SizedBox(height: 12),
        Text(
          'Még nincs a szűrésnek megfelelő mentett hír.',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
        SizedBox(height: 6),
        Text(
          'Frissítsd az aktív feedeket, vagy módosítsd a szűrőket.',
          style: TextStyle(color: _newsMuted),
        ),
      ],
    ),
  );
}

Future<void> _openArticle(String url) async {
  if (!Platform.isWindows) return;
  await Process.start('rundll32.exe', [
    'url.dll,FileProtocolHandler',
    url,
  ], mode: ProcessStartMode.detached);
}

String _newsDate(DateTime date) =>
    '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')} '
    '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
