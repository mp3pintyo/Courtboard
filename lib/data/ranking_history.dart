import 'dart:convert';

import 'package:flutter/foundation.dart' show visibleForTesting;

import 'package:courtboard/data/file_util.dart';
import 'package:courtboard/data/json_file_cache.dart';
import 'package:courtboard/data/json_util.dart';

/// Egy teniszező ranglista-helyezése és -pontszáma egy adott napon, ahogy a
/// Live Tennis API a profil betöltésekor adta.
class RankingSnapshot {
  const RankingSnapshot({required this.date, this.ranking, this.points});

  final DateTime date;
  final int? ranking;
  final int? points;

  Map<String, Object?> toJson() => {
    'date': date.toUtc().toIso8601String(),
    'ranking': ranking,
    'points': points,
  };

  static RankingSnapshot? fromJson(Object? json) {
    final map = jsonMap(json);
    final date = DateTime.tryParse('${map['date'] ?? ''}');
    if (date == null) return null;
    final ranking = jsonIntOrNull(map['ranking']);
    final points = jsonIntOrNull(map['points']);
    if (ranking == null && points == null) return null;
    return RankingSnapshot(
      date: date.toLocal(),
      ranking: ranking,
      points: points,
    );
  }
}

/// Helyi ranglista-történet teniszezőnként (`cache/ranking_history`).
///
/// A Live Tennis API ingyenes csomagja nem ad ranglista-előzményt, ezért a
/// profil minden sikeres betöltésekor naponta legfeljebb egy mérés kerül ide
/// (az aznapi felülírja az előzőt). Így a formagörbe kizárólag valós, a
/// felhasználó gépén gyűlt adatból rajzolódik; hálózati kérést soha nem indít.
class RankingHistoryStore {
  RankingHistoryStore({this._storage, DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  static RankingHistoryStore? _shared;
  static RankingHistoryStore get shared => _shared ??= RankingHistoryStore();

  @visibleForTesting
  static set shared(RankingHistoryStore? value) => _shared = value;

  static const namespace = 'ranking_history';

  /// Ennyi (napi) mérés marad meg játékosonként.
  static const maxSnapshots = 90;

  final CacheStorage? _storage;
  final DateTime Function() _clock;

  CacheStorage get storage => _storage ?? CacheStorage.shared;

  static String _fileName(String athleteName) =>
      JsonFileCache.fileNameFor(cacheSlug(athleteName));

  /// A mentett mérések időrendben (legrégebbi elöl); hibánál üres lista.
  Future<List<RankingSnapshot>> read(String athleteName) async {
    try {
      final record = await storage.read(namespace, _fileName(athleteName));
      if (record == null) return const [];
      final json = jsonDecode(record.contents);
      if (json is! Map) return const [];
      final raw = json['snapshots'];
      final snapshots = <RankingSnapshot>[
        if (raw is List)
          for (final item in raw)
            if (RankingSnapshot.fromJson(item) case final snapshot?) snapshot,
      ]..sort((a, b) => a.date.compareTo(b.date));
      return snapshots;
    } catch (_) {
      return const [];
    }
  }

  /// Az aktuális helyezés és pontszám mentése (naponta egy mérés), majd a
  /// teljes történet visszaadása. Hiányzó adatnál csak olvas; hibát nem dob.
  Future<List<RankingSnapshot>> record(
    String athleteName, {
    int? ranking,
    int? points,
  }) async {
    final history = await read(athleteName);
    if (ranking == null && points == null) return history;
    final now = _clock();
    final updated = mergeRankingSnapshot(
      history,
      RankingSnapshot(date: now, ranking: ranking, points: points),
    );
    try {
      await storage.write(
        namespace,
        _fileName(athleteName),
        jsonEncode({
          'v': 1,
          'athlete': athleteName,
          'snapshots': [for (final snapshot in updated) snapshot.toJson()],
        }),
      );
    } catch (_) {
      // Kényelmi adat: a mentés hibája nem zavarhatja a profilt.
    }
    return updated;
  }
}

/// Az új mérés beillesztése: ugyanazon a naptári napon csak a legutóbbi
/// marad, időrendben, legfeljebb [max] darab (a legrégebbiek esnek ki).
List<RankingSnapshot> mergeRankingSnapshot(
  List<RankingSnapshot> history,
  RankingSnapshot snapshot, {
  int max = RankingHistoryStore.maxSnapshots,
}) {
  bool sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
  final result = [
    for (final item in history)
      if (!sameDay(item.date.toLocal(), snapshot.date.toLocal())) item,
    snapshot,
  ]..sort((a, b) => a.date.compareTo(b.date));
  return result.length <= max ? result : result.sublist(result.length - max);
}
