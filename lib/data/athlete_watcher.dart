import 'dart:async';
import 'dart:convert';

import 'package:courtboard/data/athlete_highlights.dart';
import 'package:courtboard/data/espn_schedule.dart';
import 'package:courtboard/data/ics_export.dart' show icsUid;
import 'package:courtboard/data/json_file_cache.dart';
import 'package:courtboard/data/live_scores.dart';
import 'package:courtboard/data/news.dart';
import 'package:courtboard/data/notification_settings.dart';
import 'package:courtboard/data/notifications.dart';
import 'package:courtboard/data/sports_api.dart';
import 'package:courtboard/data/upcoming_events.dart';
import 'package:courtboard/domain/sport.dart';

/// Egy befejezett mérkőzés a figyelő számára.
class WatchedResult {
  const WatchedResult({
    required this.key,
    required this.date,
    required this.opponent,
    this.outcome = '',
    this.score = '',
    this.homeAway,
    this.aliases = const [],
  });

  /// Stabil azonosító (például az ESPN-mérkőzés azonosítója).
  final String key;

  /// További azonosítók ugyanarra a meccsre (például „nba:day:2026-10-21”),
  /// hogy a több forrásból (menetrend, élő scoreboard) érkező eredmény csak
  /// egyszer jelezzen.
  final List<String> aliases;

  Iterable<String> get allKeys => [key, ...aliases];
  final DateTime date;
  final String opponent;

  /// `win` / `loss` / `draw` vagy üres.
  final String outcome;

  /// „118–104” (a sportoló csapata elöl) vagy üres.
  final String score;
  final String? homeAway;
}

/// A figyelő adatforrásai. A megvalósítás a meglévő repositorykat és azok
/// gyorsítótárát használja ([RepositoryWatcherSource]); a tesztek hamis
/// forrást adnak.
abstract interface class WatcherDataSource {
  /// A sportoló közelgő eseményei (gyorsítótárból, ha még friss).
  Future<List<UpcomingEvent>> upcomingEvents(UpcomingEventsTarget athlete);

  /// A legutóbbi befejezett mérkőzések, a legújabb elöl; `null`, ha ehhez a
  /// sportolóhoz nincs automatikusan figyelhető eredményforrás.
  Future<List<WatchedResult>?> recentResults(UpcomingEventsTarget athlete);

  /// A sportoló csapatának mai mérkőzései a scoreboardról (élő és
  /// befejezett); üres, ha nincs élő forrás.
  Future<List<AthleteLiveGame>> liveGames(UpcomingEventsTarget athlete);

  /// Hírfrissítés (a [NewsRepository] 20 perces szabályát tartva).
  Future<void> refreshNews();

  /// A sportolóhoz kapcsolódó legfrissebb, már tárolt hírek.
  Future<List<NewsArticle>> recentNews(String athleteName);
}

/// A meglévő repositorykra épülő adatforrás.
///
/// * Közelgő események: [UpcomingEventsRepository] (6 órás gyorsítótár, a
///   naptárral közös).
/// * Eredmények: NBA / WNBA / NFL esetén az ESPN nyilvános csapatmenetrendje
///   ([EspnScheduleRepository.recentResults], 60 perces gyorsítótár); az
///   új eredmény a nyitóoldal kiemelésébe ([AthleteHighlightStore]) is
///   bekerül. Emellett az élő scoreboard ([LiveScoresRepository], 45 mp-es
///   gyorsítótár) mai befejezett meccsei is bekerülnek, így a végeredmény
///   a menetrend frissülése előtt jelez; focinál csak ez az eredményforrás.
/// * Hírek: a közös [NewsRepository] (forrásonként legfeljebb 20 percenként
///   kér), a sportolóhoz tartozást a [newsMatchesAthlete] dönti el.
class RepositoryWatcherSource implements WatcherDataSource {
  RepositoryWatcherSource({
    required this.config,
    required this.news,
    UpcomingEventsRepository? upcoming,
    EspnScheduleRepository? espn,
    LiveScoresRepository? live,
    this._highlights,
  }) : _upcoming = upcoming ?? UpcomingEventsRepository(),
       _espn = espn ?? EspnScheduleRepository(),
       _live = live ?? LiveScoresRepository();

  /// Az aktuális API-kulcsok (a Beállításokban közben változhatnak).
  final SportsApiConfig Function() config;
  final NewsRepository news;
  final UpcomingEventsRepository _upcoming;
  final EspnScheduleRepository _espn;
  final LiveScoresRepository _live;
  final AthleteHighlightStore? _highlights;

  @override
  Future<List<UpcomingEvent>> upcomingEvents(
    UpcomingEventsTarget athlete,
  ) async => (await _upcoming.fetchFor(athlete, config: config())).events;

  @override
  Future<List<WatchedResult>?> recentResults(
    UpcomingEventsTarget athlete,
  ) async {
    final league = EspnLeague.forSport(athlete.sport);
    final teamName = athlete.team.trim();
    if (teamName.isEmpty) return null;
    // A mai, már befejezett meccsek az élő scoreboardról (gyorsabb, mint a
    // menetrend óránkénti frissülése).
    List<WatchedResult> liveFinals;
    try {
      liveFinals = [
        for (final game in await liveGames(athlete))
          if (game.game.isFinished) liveFinalResult(game),
      ];
    } catch (_) {
      liveFinals = const [];
    }
    if (league == null) {
      return athlete.sport == Sport.football ? liveFinals : null;
    }
    final team = await _espn.findTeam(league, teamName);
    if (team == null) return liveFinals.isEmpty ? null : liveFinals;
    final games = await _espn.recentResults(league, team);
    if (games.isNotEmpty) {
      final last = games.first;
      // A nyitóoldal „legutóbbi eredmény” sora is frissül (soha nem dob).
      await (_highlights ?? AthleteHighlightStore.shared).record(athlete.name, [
        HighlightEvent(
          date: last.start,
          title: last.opponent,
          outcome: last.outcome,
          score: last.score,
        ),
      ]);
    }
    return [
      ...liveFinals,
      for (final game in games)
        WatchedResult(
          key: '${league.league}:${game.id}',
          date: game.start,
          opponent: game.opponent,
          outcome: game.outcome,
          score: game.score,
          homeAway: game.homeAway,
          aliases: [resultDayKey(athlete.sport.jsonValue, game.start)],
        ),
    ];
  }

  @override
  Future<List<AthleteLiveGame>> liveGames(UpcomingEventsTarget athlete) async =>
      (await _live.forTargets([athlete])).forAthlete(athlete.name);

  @override
  Future<void> refreshNews() async {
    await news.refresh();
  }

  @override
  Future<List<NewsArticle>> recentNews(String athleteName) async {
    final articles = await news.store.query(
      athleteName: athleteName,
      limit: 30,
    );
    return articles
        .where((article) => newsMatchesAthlete(article, athleteName))
        .toList();
  }
}

/// A figyelő tartós emlékezete: már jelzett események, látott eredmények és
/// hírek. Az első futás csak „megjegyzi” a meglévőt (nincs értesítésözön).
class WatcherMemory {
  WatcherMemory({
    Map<String, DateTime>? notifiedEvents,
    Map<String, List<String>>? seenResults,
    Map<String, List<String>>? seenNews,
    Map<String, String>? liveScores,
  }) : notifiedEvents = notifiedEvents ?? {},
       seenResults = seenResults ?? {},
       seenNews = seenNews ?? {},
       liveScores = liveScores ?? {};

  /// Esemény-UID → kezdés (a már jelzett „Meccs kezdődik” értesítések).
  final Map<String, DateTime> notifiedEvents;

  /// Sportoló → látott mérkőzéskulcsok (a legújabb elöl).
  final Map<String, List<String>> seenResults;

  /// Sportoló → látott hírkulcsok (a legújabb elöl).
  final Map<String, List<String>> seenNews;

  /// Zajló meccs kulcsa → a legutóbb látott állás („84–79”).
  final Map<String, String> liveScores;

  static const maxResultKeys = 60;
  static const maxNewsKeys = 200;

  /// Ennél régebben kezdődött események UID-jai törlődnek.
  static const eventRetention = Duration(days: 2);

  /// A régi esemény-UID-ok és a már nem figyelt sportolók törlése.
  void prune(DateTime now, Set<String> athletes) {
    final cutoff = now.subtract(eventRetention);
    notifiedEvents.removeWhere((_, start) => start.isBefore(cutoff));
    seenResults.removeWhere((name, _) => !athletes.contains(name));
    seenNews.removeWhere((name, _) => !athletes.contains(name));
  }

  Map<String, Object?> toJson() => {
    'v': 1,
    'notifiedEvents': {
      for (final MapEntry(:key, :value) in notifiedEvents.entries)
        key: value.toUtc().toIso8601String(),
    },
    'seenResults': seenResults,
    'seenNews': seenNews,
    'liveScores': liveScores,
  };

  factory WatcherMemory.fromJson(Object? json) {
    if (json is! Map) return WatcherMemory();
    Map<String, List<String>> lists(Object? raw) => {
      if (raw is Map)
        for (final MapEntry(:key, :value) in raw.entries)
          if (value is List) '$key': value.whereType<String>().toList(),
    };
    final events = json['notifiedEvents'];
    return WatcherMemory(
      notifiedEvents: {
        if (events is Map)
          for (final MapEntry(:key, :value) in events.entries)
            if (DateTime.tryParse('$value') case final DateTime start)
              '$key': start.toLocal(),
      },
      seenResults: lists(json['seenResults']),
      seenNews: lists(json['seenNews']),
      liveScores: {
        if (json['liveScores'] case final Map<Object?, Object?> raw)
          for (final MapEntry(:key, :value) in raw.entries)
            if (value is String) '$key': value,
      },
    );
  }
}

/// A [WatcherMemory] mentési helye.
abstract interface class WatcherMemoryStore {
  Future<WatcherMemory> load();
  Future<void> save(WatcherMemory memory);
}

/// A közös gyorsítótár-tárolóban (`cache/watcher/memory.json`) élő
/// emlékezet. Ha a gyorsítótárat törlik, a következő futás újra csak
/// „megjegyzi” a meglévőt, így értesítésözön akkor sem keletkezik.
class CacheWatcherMemoryStore implements WatcherMemoryStore {
  CacheWatcherMemoryStore({this._storage});

  final CacheStorage? _storage;
  static const namespace = 'watcher';
  static const fileName = 'memory.json';

  CacheStorage get _store => _storage ?? CacheStorage.shared;

  @override
  Future<WatcherMemory> load() async {
    try {
      final record = await _store.read(namespace, fileName);
      if (record == null) return WatcherMemory();
      return WatcherMemory.fromJson(jsonDecode(record.contents));
    } catch (_) {
      return WatcherMemory();
    }
  }

  @override
  Future<void> save(WatcherMemory memory) async {
    try {
      await _store.write(namespace, fileName, jsonEncode(memory.toJson()));
    } catch (_) {
      // Kényelmi adat: a mentés hibája legfeljebb ismételt „megjegyzést” okoz.
    }
  }
}

/// Memóriában élő emlékezet (tesztekhez).
class MemoryWatcherMemoryStore implements WatcherMemoryStore {
  WatcherMemory? saved;
  int saves = 0;

  @override
  Future<WatcherMemory> load() async =>
      WatcherMemory.fromJson(saved?.toJson() ?? const <String, Object?>{});

  @override
  Future<void> save(WatcherMemory memory) async {
    saves++;
    saved = WatcherMemory.fromJson(jsonDecode(jsonEncode(memory.toJson())));
  }
}

/// Egy figyelőfutás eredménye (naplózáshoz és tesztekhez).
class WatcherRunReport {
  WatcherRunReport({this.skipReason});

  /// Ha a futás el sem indult: `disabled` / `no-athletes` / `busy`.
  final String? skipReason;

  /// A megjelenített értesítések.
  final List<CourtboardNotification> shown = [];

  /// Csendes óra vagy szünet miatt elnyelt értesítések száma.
  int suppressed = 0;

  /// Első alkalommal csak megjegyzett (értesítés nélküli) listák száma.
  int seeded = 0;

  bool get skipped => skipReason != null;
}

/// Háttérfigyelő: amíg az app fut (a tálcán is), [NotificationSettings.
/// interval] időközönként megnézi, hogy a követett és értesítésre jelölt
/// sportolóknál
///
/// * 15 percen belül kezdődik-e mérkőzés („Meccs kezdődik”; eseményenként
///   egyszer, a jelzett UID-ok megmaradnak újraindítás után is);
/// * van-e új eredmény a legutóbbi mérkőzések között („Új eredmény”);
/// * érkezett-e hozzájuk kapcsolódó új hír („Új hír”, egy értesítésbe
///   összevonva).
///
/// Az első futás sportolónként csak megjegyzi a meglévő eredményeket és
/// híreket. Csendes órában és szüneteltetéskor a futás lefut (az emlékezet
/// friss marad), de értesítés nem jelenik meg. A kvótákat a források
/// gyorsítótára védi: a figyelő soha nem kényszerít frissítést.
class AthleteWatcher {
  AthleteWatcher({
    required this.source,
    required this.notifications,
    WatcherMemoryStore? memoryStore,
    DateTime Function()? clock,
    this.leadTime = const Duration(minutes: 15),
    this.startDelay = const Duration(seconds: 45),
    this.resultMaxAge = const Duration(days: 3),
    this.newsMaxAge = const Duration(days: 2),
  }) : _memoryStore = memoryStore ?? CacheWatcherMemoryStore(),
       _clock = clock ?? DateTime.now;

  final WatcherDataSource source;
  final NotificationService notifications;
  final WatcherMemoryStore _memoryStore;
  final DateTime Function() _clock;

  /// „Meccs kezdődik”: ennyivel a kezdés előtt.
  final Duration leadTime;

  /// Az első futás késleltetése [start] után (ne az indulással versenyezzen).
  final Duration startDelay;

  /// Ennél régebbi „új” eredményről / hírről nem küldünk értesítést.
  final Duration resultMaxAge;
  final Duration newsMaxAge;

  List<UpcomingEventsTarget> _athletes = const [];
  NotificationSettings _settings = const NotificationSettings();
  DateTime? _pausedUntil;

  WatcherMemory? _memory;
  Future<WatcherRunReport>? _running;
  Timer? _startTimer;
  Timer? _periodic;
  final Map<String, Timer> _reminders = {};
  bool _started = false;
  bool _disposed = false;

  /// Az utolsó befejezett futás ideje.
  DateTime? lastRunAt;

  NotificationSettings get settings => _settings;
  List<UpcomingEventsTarget> get athletes => _athletes;
  bool get isRunning => _started;

  /// A tervezett „Meccs kezdődik” emlékeztetők UID-jai (tesztekhez).
  Set<String> get scheduledReminders => Set.unmodifiable(_reminders.keys);

  /// Igaz, ha az értesítések szüneteltetése még tart.
  bool get isPaused {
    final until = _pausedUntil;
    return until != null && _clock().isBefore(until);
  }

  /// A figyelt sportolók (csak akiknél be van kapcsolva az értesítés), a
  /// beállítások és a szüneteltetés frissítése. Gyakoriságváltozáskor az
  /// ütemezés újraindul.
  void update({
    List<UpcomingEventsTarget>? athletes,
    NotificationSettings? settings,
    DateTime? pausedUntil,
    bool clearPause = false,
  }) {
    final intervalChanged =
        settings != null && settings.interval != _settings.interval;
    if (athletes != null) _athletes = List.unmodifiable(athletes);
    if (settings != null) _settings = settings;
    if (clearPause) {
      _pausedUntil = null;
    } else if (pausedUntil != null) {
      _pausedUntil = pausedUntil;
    }
    if (!_settings.enabled || !_settings.matchStart) _cancelReminders();
    if (intervalChanged && _started && _startTimer == null) _schedulePeriodic();
  }

  /// Az ütemezés indítása: első futás [startDelay] múlva, utána
  /// [NotificationSettings.interval] időközönként.
  void start() {
    if (_started || _disposed) return;
    _started = true;
    _startTimer = Timer(startDelay, () {
      _startTimer = null;
      unawaited(run());
      _schedulePeriodic();
    });
  }

  void _schedulePeriodic() {
    _periodic?.cancel();
    _periodic = Timer.periodic(_settings.interval, (_) => unawaited(run()));
  }

  /// Az ütemezés leállítása (a már futó ellenőrzés befejeződik).
  void stop() {
    _started = false;
    _startTimer?.cancel();
    _startTimer = null;
    _periodic?.cancel();
    _periodic = null;
    _cancelReminders();
  }

  void dispose() {
    stop();
    _disposed = true;
  }

  void _cancelReminders() {
    for (final timer in _reminders.values) {
      timer.cancel();
    }
    _reminders.clear();
  }

  /// Egy ellenőrzés azonnal (például a tálcamenü „Frissítés most” pontja).
  /// Ha éppen fut egy, annak az eredményét adja vissza.
  Future<WatcherRunReport> run() {
    final pending = _running;
    if (pending != null) return pending;
    final future = _run();
    _running = future;
    return future.whenComplete(() {
      if (identical(_running, future)) _running = null;
    });
  }

  Future<WatcherMemory> _loadMemory() async =>
      _memory ??= await _memoryStore.load();

  bool _suppressedAt(DateTime now) =>
      (_pausedUntil != null && now.isBefore(_pausedUntil!)) ||
      _settings.isQuietAt(now);

  Future<WatcherRunReport> _run() async {
    if (_disposed) return WatcherRunReport(skipReason: 'disposed');
    final settings = _settings;
    final athletes = _athletes;
    if (!settings.enabled) {
      _cancelReminders();
      return WatcherRunReport(skipReason: 'disabled');
    }
    if (athletes.isEmpty) {
      _cancelReminders();
      return WatcherRunReport(skipReason: 'no-athletes');
    }
    final report = WatcherRunReport();
    final memory = await _loadMemory();
    final now = _clock();
    memory.prune(now, {for (final athlete in athletes) athlete.name});
    final pending = <CourtboardNotification>[];

    if (settings.matchStart) {
      _cancelReminders();
      for (final athlete in athletes) {
        final List<UpcomingEvent> events;
        try {
          events = await source.upcomingEvents(athlete);
        } catch (_) {
          continue;
        }
        for (final event in events) {
          _considerMatchStart(athlete, event, now, memory, pending);
        }
      }
    } else {
      _cancelReminders();
    }

    if (settings.results) {
      for (final athlete in athletes) {
        final List<WatchedResult>? results;
        try {
          results = await source.recentResults(athlete);
        } catch (_) {
          continue;
        }
        if (results == null) continue;
        final notification = _considerResults(
          athlete,
          results,
          now,
          memory,
          report,
        );
        if (notification != null) pending.add(notification);
      }
    } else {
      // Újrabekapcsoláskor ismét csak megjegyzés történik (nincs özön).
      memory.seenResults.clear();
    }

    if (settings.liveScores) {
      final active = <String>{};
      for (final athlete in athletes) {
        final List<AthleteLiveGame> games;
        try {
          games = await source.liveGames(athlete);
        } catch (_) {
          continue;
        }
        for (final game in games) {
          if (!game.game.isLive) continue;
          final key = '${athlete.name}|${game.key}';
          active.add(key);
          final score = game.score;
          final previous = memory.liveScores[key];
          memory.liveScores[key] = score;
          if (previous != null && previous != score && score.isNotEmpty) {
            pending.add(liveScoreNotification(game));
          }
        }
      }
      // A már nem zajló meccsek állása törlődik.
      memory.liveScores.removeWhere((key, _) => !active.contains(key));
    } else {
      memory.liveScores.clear();
    }

    if (settings.news) {
      try {
        await source.refreshNews();
      } catch (_) {
        // A tárolt hírek így is átnézhetők.
      }
      final fresh = <String, List<NewsArticle>>{};
      for (final athlete in athletes) {
        final List<NewsArticle> articles;
        try {
          articles = await source.recentNews(athlete.name);
        } catch (_) {
          continue;
        }
        final found = _considerNews(athlete, articles, now, memory, report);
        if (found.isNotEmpty) fresh[athlete.name] = found;
      }
      final notification = _newsNotification(fresh);
      if (notification != null) pending.add(notification);
    } else {
      memory.seenNews.clear();
    }

    await _memoryStore.save(memory);
    if (_suppressedAt(_clock())) {
      report.suppressed += pending.length;
    } else {
      for (final notification in pending) {
        if (await notifications.show(notification)) {
          report.shown.add(notification);
        }
      }
    }
    lastRunAt = _clock();
    return report;
  }

  void _considerMatchStart(
    UpcomingEventsTarget athlete,
    UpcomingEvent event,
    DateTime now,
    WatcherMemory memory,
    List<CourtboardNotification> pending,
  ) {
    if (!event.timeKnown) return;
    final uid = icsUid(event);
    if (memory.notifiedEvents.containsKey(uid)) return;
    final untilStart = event.start.difference(now);
    // Már elkezdődött (néhány perc türelemmel): nem jelezzük utólag.
    if (untilStart <= const Duration(minutes: -5)) return;
    if (untilStart <= leadTime) {
      memory.notifiedEvents[uid] = event.start;
      pending.add(matchStartNotification(event, uid));
      return;
    }
    // A következő ütemezett futás után esedékes: pontos emlékeztető.
    final fireIn = untilStart - leadTime;
    if (fireIn <= _settings.interval + const Duration(minutes: 1)) {
      _reminders[uid]?.cancel();
      _reminders[uid] = Timer(
        fireIn,
        () => unawaited(_fireReminder(athlete, event, uid)),
      );
    }
  }

  Future<void> _fireReminder(
    UpcomingEventsTarget athlete,
    UpcomingEvent event,
    String uid,
  ) async {
    _reminders.remove(uid);
    if (_disposed) return;
    if (!_settings.enabled || !_settings.matchStart) return;
    if (!_athletes.any((item) => item.name == athlete.name)) return;
    final memory = await _loadMemory();
    if (memory.notifiedEvents.containsKey(uid)) return;
    memory.notifiedEvents[uid] = event.start;
    await _memoryStore.save(memory);
    if (_suppressedAt(_clock())) return;
    await notifications.show(matchStartNotification(event, uid));
  }

  CourtboardNotification? _considerResults(
    UpcomingEventsTarget athlete,
    List<WatchedResult> results,
    DateTime now,
    WatcherMemory memory,
    WatcherRunReport report,
  ) {
    final keys = [for (final result in results) ...result.allKeys];
    final seen = memory.seenResults[athlete.name];
    if (seen == null) {
      memory.seenResults[athlete.name] = {
        ...keys,
      }.take(WatcherMemory.maxResultKeys).toList();
      report.seeded++;
      return null;
    }
    final known = seen.toSet();
    final cutoff = now.subtract(resultMaxAge);
    // Ugyanaz a meccs több forrásból (élő scoreboard + menetrend) egyszer.
    final claimed = <String>{};
    final fresh = <WatchedResult>[];
    for (final result in results) {
      if (result.allKeys.any(known.contains) ||
          !result.date.isAfter(cutoff) ||
          result.allKeys.any(claimed.contains)) {
        continue;
      }
      claimed.addAll(result.allKeys);
      fresh.add(result);
    }
    fresh.sort((a, b) => b.date.compareTo(a.date));
    memory.seenResults[athlete.name] = {
      ...keys,
      ...seen,
    }.take(WatcherMemory.maxResultKeys).toList();
    if (fresh.isEmpty) return null;
    return resultNotification(athlete.name, fresh);
  }

  List<NewsArticle> _considerNews(
    UpcomingEventsTarget athlete,
    List<NewsArticle> articles,
    DateTime now,
    WatcherMemory memory,
    WatcherRunReport report,
  ) {
    final keys = [for (final article in articles) article.dedupeKey];
    final seen = memory.seenNews[athlete.name];
    if (seen == null) {
      memory.seenNews[athlete.name] = keys
          .take(WatcherMemory.maxNewsKeys)
          .toList();
      report.seeded++;
      return const [];
    }
    final known = seen.toSet();
    final cutoff = now.subtract(newsMaxAge);
    final fresh = articles
        .where(
          (article) =>
              !known.contains(article.dedupeKey) &&
              article.publishedAt.isAfter(cutoff),
        )
        .toList();
    memory.seenNews[athlete.name] = {
      ...keys,
      ...seen,
    }.take(WatcherMemory.maxNewsKeys).toList();
    return fresh;
  }

  CourtboardNotification? _newsNotification(
    Map<String, List<NewsArticle>> fresh,
  ) {
    if (fresh.isEmpty) return null;
    // Ugyanaz a cikk több sportolónál is szerepelhet: egyszer számoljuk.
    final unique = <String, NewsArticle>{
      for (final articles in fresh.values)
        for (final article in articles) article.dedupeKey: article,
    };
    final newest = unique.values.toList()
      ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    final headline = newest.first.title;
    if (fresh.length == 1) {
      final name = fresh.keys.single;
      final count = fresh[name]!.length;
      return CourtboardNotification(
        id: 'news:$name:${newest.first.dedupeKey}',
        kind: CourtboardNotificationKind.news,
        title: count == 1 ? 'Új hír: $name' : '$count új hír: $name',
        body: headline,
        athleteName: name,
      );
    }
    final summary = [
      for (final MapEntry(:key, :value) in fresh.entries)
        '$key (${value.length})',
    ].join(', ');
    return CourtboardNotification(
      id: 'news:batch:${newest.first.dedupeKey}',
      kind: CourtboardNotificationKind.news,
      title: '${unique.length} új hír a követett sportolókról',
      body: '$summary · $headline',
    );
  }
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');

/// „Meccs kezdődik” értesítés egy eseményről.
CourtboardNotification matchStartNotification(UpcomingEvent event, String uid) {
  final local = event.start.toLocal();
  final time = '${_twoDigits(local.hour)}:${_twoDigits(local.minute)}';
  final details = [
    event.title,
    'kezdés $time',
    if (event.competition.isNotEmpty) event.competition,
  ].join(' · ');
  return CourtboardNotification(
    id: 'match:$uid',
    kind: CourtboardNotificationKind.matchStart,
    title: 'Hamarosan kezdődik: ${event.athleteName}',
    body: details,
    athleteName: event.athleteName,
  );
}

/// „Új eredmény” értesítés; több új eredménynél a legújabb szerepel.
CourtboardNotification resultNotification(
  String athleteName,
  List<WatchedResult> fresh,
) {
  final latest = fresh.first;
  final label = switch (latest.outcome) {
    'win' => 'Győzelem',
    'loss' => 'Vereség',
    'draw' => 'Döntetlen',
    _ => 'Lejátszott mérkőzés',
  };
  final opponent = latest.opponent.isEmpty
      ? ''
      : ' · ${latest.homeAway == 'away' ? '@' : 'vs.'} ${latest.opponent}';
  final score = latest.score.isEmpty ? '' : ' ${latest.score}';
  final more = fresh.length > 1 ? ' (+${fresh.length - 1} további)' : '';
  return CourtboardNotification(
    id: 'result:$athleteName:${latest.key}',
    kind: CourtboardNotificationKind.result,
    title: 'Új eredmény: $athleteName',
    body: '$label$score$opponent$more',
    athleteName: athleteName,
  );
}

/// Napi kulcs egy csapat eredményéhez („nba:day:2026-10-21”, helyi dátum):
/// egy csapat naponta legfeljebb egy meccset játszik, így a különböző
/// forrásokból érkező azonos meccs összepárosítható.
String resultDayKey(String sport, DateTime start) {
  final local = start.toLocal();
  return '${sport.toLowerCase()}:day:${local.year}-'
      '${_twoDigits(local.month)}-${_twoDigits(local.day)}';
}

/// Egy scoreboardon befejezett meccs figyelő-eredményként.
WatchedResult liveFinalResult(AthleteLiveGame game) {
  final league = EspnLeague.fromSport(game.game.sport);
  return WatchedResult(
    key: game.game.source == LiveScoresRepository.espnProvider && league != null
        ? '${league.league}:${game.game.id}'
        : game.key,
    date: game.game.start,
    opponent: game.opponent.name,
    outcome: game.outcome,
    score: game.score,
    homeAway: game.ownIsHome ? 'home' : 'away',
    aliases: [resultDayKey(game.game.sport, game.game.start)],
  );
}

/// „Élő eredményváltozás” értesítés egy zajló meccsről.
CourtboardNotification liveScoreNotification(AthleteLiveGame game) =>
    CourtboardNotification(
      id: 'live:${game.athleteName}:${game.key}:${game.score}',
      kind: CourtboardNotificationKind.liveScore,
      title: 'Élő: ${game.athleteName}',
      body: [
        '${game.own.name} ${game.score}',
        '${game.ownIsHome ? 'vs.' : '@'} ${game.opponent.name}',
        if (game.game.status.isNotEmpty) game.game.status,
      ].join(' · '),
      athleteName: game.athleteName,
    );
