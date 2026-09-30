import 'dart:async';

import 'package:flutter/material.dart';

import 'common_ui.dart';
import 'components.dart';
import 'data/athlete_names.dart' show normalizeAthleteName;
import 'data/news.dart';
import 'format.dart';
import 'images.dart';
import 'theme/courtboard_theme.dart';

class NewsAthleteRef {
  const NewsAthleteRef({required this.name, required this.sport});
  final String name;
  final String sport;
}

/// A cikkben említett követett sportolók nevei (legfeljebb [max]).
List<String> newsRelatedAthletes(
  NewsArticle article,
  List<NewsAthleteRef> athletes, {
  int max = 3,
}) => athletes
    .where((athlete) => newsMatchesAthlete(article, athlete.name))
    .map((athlete) => athlete.name)
    .take(max)
    .toList();

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
  final _searchFocus = FocusNode(debugLabel: 'news-search');
  Timer? _debounce;
  static const _pageSize = 60;

  List<NewsArticle> _articles = const [];

  /// Cikkenként (dedupeKey) a kapcsolódó sportolók, betöltéskor egyszer
  /// számolva, hogy a kártyák építése ne ismételje az egyeztetést.
  Map<String, List<String>> _related = const {};
  bool _hasMore = false;
  bool _loadingMore = false;
  String? _loadError;
  bool _refreshFailed = false;
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

  Future<List<NewsArticle>> _queryPage(int offset) => _repository.store.query(
    text: _search.text,
    sport: _sport,
    sourceId: _source,
    athleteName: _athlete,
    limit: _pageSize + 1,
    offset: offset,
  );

  Map<String, List<String>> _relatedFor(Iterable<NewsArticle> articles) => {
    for (final article in articles)
      article.dedupeKey: newsRelatedAthletes(article, widget.athletes),
  };

  Future<void> _reload() async {
    try {
      final page = await _queryPage(0);
      final sources = await _repository.store.sourceStates();
      final count = await _repository.store.count();
      if (!mounted) return;
      final articles = page.take(_pageSize).toList();
      setState(() {
        _articles = articles;
        _related = _relatedFor(articles);
        _hasMore = page.length > _pageSize;
        _sources = sources;
        _storedCount = count;
        _loadError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _loadError =
            'A mentett hírek nem tölthetők be. ${friendlyError(error)}',
      );
    } finally {
      if (mounted && _loading) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final page = await _queryPage(_articles.length);
      if (!mounted) return;
      final more = page.take(_pageSize).toList();
      setState(() {
        _articles = [..._articles, ...more];
        _related = {..._related, ..._relatedFor(more)};
        _hasMore = page.length > _pageSize;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            'További hírek nem tölthetők be. ${friendlyError(error)}',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _refresh({bool force = false}) async {
    if (_refreshing) return;
    setState(() {
      _refreshing = true;
      _refreshFailed = false;
      _status = '';
    });
    try {
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
    } catch (error) {
      if (!mounted) return;
      _refreshFailed = true;
      _status =
          'A hírek frissítése nem sikerült. ${friendlyError(error)} A korábban mentett hírek elérhetők maradnak.';
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
    if (mounted) await _reload();
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
                    style: context.text.titleSmall,
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
                          style: TextStyle(color: context.cb.error),
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
    _searchFocus.dispose();
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

    final cb = context.cb;
    final horizontal = MediaQuery.sizeOf(context).width < 800 ? 20.0 : 34.0;
    return CommandListener(
      onRefresh: () {
        if (!_refreshing) unawaited(_refresh(force: true));
      },
      onFocusSearch: () {
        _searchFocus.requestFocus();
        _search.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _search.text.length,
        );
      },
      child: ColoredBox(
        color: cb.canvas,
        child: LayoutBuilder(
          builder: (context, viewport) {
            // A fejléc és a szűrők a hírekkel együtt görgetnek, így alacsony
            // ablakban (vagy nagy szövegméretnél) sem csordul túl semmi.
            final contentWidth = viewport.maxWidth - 2 * horizontal;
            final columns = contentWidth >= 1120
                ? 3
                : contentWidth >= 720
                ? 2
                : 1;
            const gap = 16.0;
            final rows = (_articles.length + columns - 1) ~/ columns;
            final showList =
                !_loading &&
                !(_loadError != null && _articles.isEmpty) &&
                _articles.isNotEmpty;
            return CustomScrollView(
              key: const PageStorageKey('news-list'),
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(horizontal, 28, horizontal, 18),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        PageHeader(
                          title: 'Hírek',
                          subtitle:
                              'Tartós hírarchívum: a már letöltött hírek később és hálózat nélkül is kereshetők.',
                          actions: [
                            OutlinedButton.icon(
                              key: const Key('news-source-settings'),
                              onPressed: _openSources,
                              icon: const Icon(Icons.tune_rounded),
                              label: const Text('Források'),
                            ),
                            Tooltip(
                              message: 'Hírek frissítése (Ctrl+R)',
                              child: FilledButton.icon(
                                key: const Key('news-refresh-button'),
                                onPressed: _refreshing
                                    ? null
                                    : () => _refresh(force: true),
                                icon: _refreshing
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.sync_rounded),
                                label: Text(
                                  _refreshing ? 'Frissítés…' : 'Frissítés',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _NewsStat(
                              value: formatInt(_storedCount),
                              label: 'tartósan tárolt hír',
                            ),
                            _NewsStat(
                              value: formatInt(enabledSources.length),
                              label: 'aktív hírforrás',
                            ),
                            _NewsStat(
                              value:
                                  '${formatInt(_articles.length)}${_hasMore ? '+' : ''}',
                              label: 'jelenlegi találat',
                            ),
                          ],
                        ),
                        if (_status.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            children: [
                              Icon(
                                _refreshFailed
                                    ? Icons.cloud_off_outlined
                                    : Icons.info_outline_rounded,
                                size: 17,
                                color: _refreshFailed
                                    ? cb.warning
                                    : cb.textMuted,
                              ),
                              Text(
                                _status,
                                key: const Key('news-refresh-status'),
                                style: context.text.bodyMedium?.copyWith(
                                  color: cb.textMuted,
                                ),
                              ),
                              if (_refreshFailed)
                                TextButton.icon(
                                  key: const Key('news-refresh-retry'),
                                  onPressed: _refreshing
                                      ? null
                                      : () => _refresh(force: true),
                                  icon: const Icon(Icons.refresh, size: 18),
                                  label: const Text('Újrapróbálás'),
                                ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 18),
                        SurfaceCard(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            children: [
                              TextField(
                                key: const Key('news-search'),
                                controller: _search,
                                focusNode: _searchFocus,
                                onChanged: (_) => _scheduleReload(),
                                decoration: InputDecoration(
                                  hintText:
                                      'Keresés a címekben és összefoglalókban… (Ctrl+F)',
                                  prefixIcon: const Icon(Icons.search_rounded),
                                  suffixIcon: _search.text.isEmpty
                                      ? null
                                      : IconButton(
                                          tooltip: 'Keresés törlése',
                                          onPressed: () {
                                            _search.clear();
                                            _scheduleReload();
                                            setState(() {});
                                          },
                                          icon: const Icon(Icons.close_rounded),
                                        ),
                                  filled: false,
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                ),
                              ),
                              const Divider(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      isExpanded: true,
                                      style: context.text.bodyLarge,
                                      key: const Key('news-sport-filter'),
                                      initialValue: _sport,
                                      decoration: const InputDecoration(
                                        labelText: 'Sportág',
                                      ),
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
                                      isExpanded: true,
                                      style: context.text.bodyLarge,
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
                                        setState(
                                          () => _athlete = value ?? 'Mind',
                                        );
                                        unawaited(_reload());
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      isExpanded: true,
                                      style: context.text.bodyLarge,
                                      key: const Key('news-source-filter'),
                                      initialValue: _source,
                                      decoration: const InputDecoration(
                                        labelText: 'Forrás',
                                      ),
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
                                        setState(
                                          () => _source = value ?? 'Mind',
                                        );
                                        unawaited(_reload());
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    tooltip: 'Szűrők törlése',
                                    onPressed: _clearFilters,
                                    icon: const Icon(
                                      Icons.filter_alt_off_outlined,
                                    ),
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
                if (showList)
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(horizontal, 0, horizontal, 34),
                    // Soronként, lustán épített lista: csak a látható
                    // kártyák készülnek el, a teljes archívum soha.
                    sliver: SliverList.builder(
                      itemCount: rows + (_hasMore ? 1 : 0),
                      itemBuilder: (context, row) {
                        if (row == rows) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Center(
                              child: OutlinedButton.icon(
                                key: const Key('news-load-more'),
                                onPressed: _loadingMore ? null : _loadMore,
                                icon: _loadingMore
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.expand_more_rounded),
                                label: const Text('Továbbiak betöltése'),
                              ),
                            ),
                          );
                        }
                        final start = row * columns;
                        return Padding(
                          padding: EdgeInsets.only(
                            bottom: row == rows - 1 ? 0 : gap,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (
                                var column = 0;
                                column < columns;
                                column++
                              ) ...[
                                if (column > 0) const SizedBox(width: gap),
                                Expanded(
                                  child: start + column < _articles.length
                                      ? NewsArticleCard(
                                          article: _articles[start + column],
                                          relatedAthletes:
                                              _related[_articles[start + column]
                                                  .dedupeKey] ??
                                              const [],
                                        )
                                      : const SizedBox.shrink(),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  )
                else
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        horizontal,
                        0,
                        horizontal,
                        34,
                      ),
                      child: _loading
                          ? const Align(
                              alignment: Alignment.topCenter,
                              child: CardSkeleton(
                                label: 'Mentett hírek betöltése…',
                              ),
                            )
                          : _loadError != null && _articles.isEmpty
                          ? Center(
                              key: const Key('news-load-error'),
                              child: CourtboardErrorState(
                                message: _loadError!,
                                onRetry: () {
                                  setState(() => _loading = true);
                                  unawaited(_reload());
                                },
                              ),
                            )
                          : const _EmptyNews(),
                    ),
                  ),
              ],
            );
          },
        ),
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
      color: context.cb.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: context.cb.border),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: context.text.titleMedium),
        const SizedBox(width: 6),
        Text(
          label,
          style: context.text.bodyMedium?.copyWith(color: context.cb.textMuted),
        ),
      ],
    ),
  );
}

class NewsArticleCard extends StatelessWidget {
  const NewsArticleCard({
    super.key,
    required this.article,
    this.relatedAthletes = const [],
  });
  final NewsArticle article;

  /// Előre kiszámolt kapcsolódó sportolók ([newsRelatedAthletes]).
  final List<String> relatedAthletes;

  @override
  Widget build(BuildContext context) {
    final cb = context.cb;
    final related = relatedAthletes;
    final placeholder = ColoredBox(
      color: cb.surfaceMuted,
      child: Center(
        child: Icon(Icons.newspaper_rounded, size: 40, color: cb.textMuted),
      ),
    );
    return FocusRing(
      borderRadius: BorderRadius.circular(20),
      child: Material(
        color: cb.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: cb.border),
        ),
        child: InkWell(
          key: ValueKey('news-${article.dedupeKey}'),
          onTap: () => openExternalUrl(context, article.url),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (article.imageUrl.isNotEmpty)
                AspectRatio(
                  aspectRatio: 16 / 8,
                  child: CourtboardImage(
                    url: article.imageUrl,
                    placeholder: placeholder,
                  ),
                )
              else
                Container(
                  height: 64,
                  color: cb.surfaceMuted,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Row(
                    children: [
                      Icon(
                        Icons.newspaper_rounded,
                        size: 24,
                        color: cb.textMuted,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          article.sourceName.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.labelMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        StatusPill(article.sourceName),
                        StatusPill(article.sport, tone: StatusTone.accent),
                        if (related.isNotEmpty)
                          StatusPill(
                            related.join(' · '),
                            tone: StatusTone.accent,
                            icon: Icons.person_outline,
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      article.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.titleMedium?.copyWith(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        height: 1.25,
                      ),
                    ),
                    if (article.summary.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        article.summary,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodyMedium?.copyWith(
                          color: cb.textMuted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            formatDateTime(article.publishedAt),
                            style: context.text.bodySmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          'Eredeti cikk',
                          style: context.text.labelLarge?.copyWith(
                            color: cb.accent,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.open_in_new_rounded,
                          size: 15,
                          color: cb.accent,
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
}

class _EmptyNews extends StatelessWidget {
  const _EmptyNews();

  @override
  Widget build(BuildContext context) => const Center(
    child: EmptyState(
      icon: Icons.newspaper_outlined,
      title: 'Még nincs a szűrésnek megfelelő mentett hír.',
      message: 'Frissítsd az aktív feedeket, vagy módosítsd a szűrőket.',
    ),
  );
}
