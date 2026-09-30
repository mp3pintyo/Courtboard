import 'dart:convert';

import 'package:flutter/foundation.dart' show visibleForTesting;

import 'file_util.dart';
import 'json_file_cache.dart';

/// Egy sportolóhoz kötött mérkőzés vagy esemény rövid összefoglalója
/// (a nyitóoldal kártyáihoz és a „Mai fókusz” blokkhoz).
class HighlightEvent {
  const HighlightEvent({
    required this.date,
    required this.title,
    this.outcome = '',
    this.score = '',
  });

  final DateTime date;

  /// Ellenfél vagy eseménynév („Phoenix Suns”, „World Matchplay”).
  final String title;

  /// `win` / `loss` / `draw` / `upcoming` vagy üres.
  final String outcome;

  /// Eredmény („104–72”) vagy üres.
  final String score;

  Map<String, Object?> toJson() => {
    'date': date.toUtc().toIso8601String(),
    'title': title,
    'outcome': outcome,
    'score': score,
  };

  static HighlightEvent? fromJson(Object? json) {
    if (json is! Map) return null;
    final date = DateTime.tryParse('${json['date'] ?? ''}');
    final title = '${json['title'] ?? ''}'.trim();
    if (date == null || title.isEmpty) return null;
    return HighlightEvent(
      date: date.toLocal(),
      title: title,
      outcome: '${json['outcome'] ?? ''}',
      score: '${json['score'] ?? ''}',
    );
  }
}

/// Egy sportoló legutóbbi eredménye és következő eseménye, ahogy a
/// profiloldal élő adatkártyái legutóbb letöltötték. Csak valós, már
/// betöltött adatból épül; ha nincs ilyen, a mezők üresek.
class AthleteHighlight {
  const AthleteHighlight({this.last, this.next, required this.updatedAt});

  final HighlightEvent? last;
  final HighlightEvent? next;
  final DateTime updatedAt;

  /// A következő esemény, ha még nem múlt el.
  HighlightEvent? upcoming(DateTime now) =>
      next != null && next!.date.isAfter(now) ? next : null;
}

/// A sportolónkénti kiemelések tartós tárolója a közös gyorsítótárban
/// (`cache/highlights`). Hálózati kérést soha nem indít: a profil
/// adatkártyái írják, a nyitóoldal csak olvassa.
class AthleteHighlightStore {
  AthleteHighlightStore({this._storage, DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  static AthleteHighlightStore? _shared;
  static AthleteHighlightStore get shared =>
      _shared ??= AthleteHighlightStore();

  @visibleForTesting
  static set shared(AthleteHighlightStore? value) => _shared = value;

  static const namespace = 'highlights';

  final CacheStorage? _storage;
  final DateTime Function() _clock;

  /// Lustán kiértékelve, hogy a tesztbeli [CacheStorage.shared] érvényesüljön.
  CacheStorage get storage => _storage ?? CacheStorage.shared;

  static String _fileName(String athleteName) =>
      JsonFileCache.fileNameFor(cacheSlug(athleteName));

  Future<AthleteHighlight?> read(String athleteName) async {
    try {
      final record = await storage.read(namespace, _fileName(athleteName));
      if (record == null) return null;
      final json = jsonDecode(record.contents);
      if (json is! Map) return null;
      final updated = DateTime.tryParse('${json['updatedAt'] ?? ''}');
      final last = HighlightEvent.fromJson(json['last']);
      final next = HighlightEvent.fromJson(json['next']);
      if (last == null && next == null) return null;
      return AthleteHighlight(
        last: last,
        next: next,
        updatedAt: (updated ?? record.modified).toLocal(),
      );
    } catch (_) {
      return null;
    }
  }

  /// Több sportoló kiemelése egyszerre; akinél nincs adat, kimarad.
  Future<Map<String, AthleteHighlight>> readAll(Iterable<String> names) async {
    final result = <String, AthleteHighlight>{};
    for (final name in names) {
      final highlight = await read(name);
      if (highlight != null) result[name] = highlight;
    }
    return result;
  }

  /// Az [events] közül a legutóbbi lejátszott és a legközelebbi jövőbeli
  /// eseményt menti. Ha az új listában nincs valamelyik, a korábban mentett
  /// (és még érvényes) érték megmarad. Hibát soha nem dob.
  Future<void> record(
    String athleteName,
    Iterable<HighlightEvent> events,
  ) async {
    try {
      final now = _clock();
      HighlightEvent? last;
      HighlightEvent? next;
      for (final event in events) {
        final upcoming = event.outcome == 'upcoming' || event.date.isAfter(now);
        if (upcoming) {
          if (event.date.isAfter(now) &&
              (next == null || event.date.isBefore(next.date))) {
            next = event;
          }
        } else if (last == null || event.date.isAfter(last.date)) {
          last = event;
        }
      }
      if (last == null && next == null) return;
      final previous = await read(athleteName);
      last ??= previous?.last;
      next ??= previous?.upcoming(now);
      if (previous != null &&
          previous.last != null &&
          last != null &&
          previous.last!.date.isAfter(last.date)) {
        last = previous.last;
      }
      await storage.write(
        namespace,
        _fileName(athleteName),
        jsonEncode({
          'v': 1,
          'athlete': athleteName,
          'updatedAt': now.toUtc().toIso8601String(),
          'last': last?.toJson(),
          'next': next?.toJson(),
        }),
      );
    } catch (_) {
      // A kiemelés csak kényelmi adat: a hibája nem zavarhatja a profilt.
    }
  }
}
