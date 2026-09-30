/// A követett sportolók „tevékenysége”: a profilokból mentett kiemelések,
/// a hírarchívum sportolókat említő cikkei és a közelgő események — a
/// nyitóoldal és a „Követés” hírfolyam alapadatai.
///
/// Csak már betöltött (helyi) adatból dolgozik; hálózati kérés csak a
/// [refreshFeed] és a [loadUpcoming] hívásakor indul, a meglévő
/// gyorsítótár-szabályok szerint.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:courtboard/app/app_controller.dart';
import 'package:courtboard/data/athlete_highlights.dart';
import 'package:courtboard/data/news.dart';
import 'package:courtboard/data/upcoming_events.dart';
import 'package:courtboard/features/follow_feed/follow_feed_data.dart';

class ActivityController extends ChangeNotifier {
  ActivityController({
    required this.app,
    required this.highlightStore,
    required this.news,
    required this.upcoming,
  }) {
    upcoming.addListener(_upcomingChanged);
  }

  final AppController app;

  /// A profil adatkártyái által mentett kiemelések.
  final AthleteHighlightStore highlightStore;

  /// Hírforrások és a helyi hírarchívum.
  final NewsRepository news;

  /// A naptár eseményei (az oldalváltásokat túléli).
  final UpcomingEventsController upcoming;

  Map<String, AthleteHighlight> _highlights = const {};
  List<NewsArticle> _feedArticles = const [];
  bool _feedLoading = false;
  bool _upcomingWasLoading = false;
  bool _disposed = false;

  /// A profil adatkártyái által legutóbb mentett eredmények és események
  /// sportolónként.
  Map<String, AthleteHighlight> get highlights => _highlights;

  /// A hírarchívum (helyi SQLite) követett sportolókat említő cikkei.
  List<NewsArticle> get feedArticles => _feedArticles;

  bool _started = false;

  /// Indításkor: kiemelések, hírfolyam és (6 órás gyorsítótárral) a
  /// közelgő események, hogy a „Mai fókusz” a naptár megnyitása nélkül is
  /// lássa a következőt. Egyszer indul (a többszöri hívás hatástalan).
  void start() {
    if (_started) return;
    _started = true;
    unawaited(loadHighlights());
    unawaited(loadFeedNews());
    unawaited(loadUpcoming());
  }

  Future<void> loadHighlights() async {
    final highlights = await highlightStore.readAll(app.athleteNames);
    if (_disposed) return;
    _highlights = highlights;
    notifyListeners();
  }

  /// A hírfolyam hírei a helyi hírarchívumból (hálózat nélkül).
  Future<void> loadFeedNews() async {
    if (_feedLoading) return;
    _feedLoading = true;
    try {
      final articles = await news.store.query(limit: 400);
      final names = app.athleteNames;
      final related = [
        for (final article in articles)
          if (names.any((name) => newsMatchesAthlete(article, name))) article,
      ];
      if (!_disposed) {
        _feedArticles = related;
        notifyListeners();
      }
    } catch (_) {
      // A hírarchívum hibája nem akaszthatja meg a hírfolyam többi részét.
    } finally {
      _feedLoading = false;
    }
  }

  Future<void> loadUpcoming() =>
      upcoming.load(app.eventTargets, config: app.apiConfig);

  /// A hírfolyam frissítése a meglévő szabályok szerint: a hírforrások csak
  /// a frissítési időközük lejárta után, a naptár a gyorsítótárból (6 óra),
  /// a kiemelések helyből töltődnek.
  Future<void> refreshFeed() async {
    await Future.wait<void>([
      news.refresh().then<void>((_) {}, onError: (Object _) {}),
      loadUpcoming(),
    ]);
    await loadHighlights();
    await loadFeedNews();
  }

  /// A hírfolyam elemei a már betöltött állapotból.
  List<FeedItem> feedItems() {
    final now = DateTime.now();
    final names = app.athleteNames;
    final followed = names.toSet();
    return mergeFeed([
      ...feedFromUpcoming(
        upcoming.events().where(
          (event) => followed.contains(event.athleteName),
        ),
        now,
      ),
      ...feedFromHighlights(_highlights, now),
      ...feedFromNews(_feedArticles, names),
      ...feedFromVideos(app.playlist.videos, names),
    ]);
  }

  /// Egy betöltési kör végén a kiemelések újraolvasása.
  void _upcomingChanged() {
    final loading = upcoming.isLoading;
    if (_upcomingWasLoading && !loading) unawaited(loadHighlights());
    _upcomingWasLoading = loading;
  }

  @override
  void dispose() {
    _disposed = true;
    upcoming.removeListener(_upcomingChanged);
    super.dispose();
  }
}
