import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'http_util.dart';
import 'json_file_cache.dart';

/// Egy szolgáltató dokumentált ingyenes kerete. A percenkénti limitet
/// várakoztatással ([RateLimiter]), a napi/havi keretet tartós számlálóval
/// ([QuotaTracker]) tartjuk be.
class ProviderLimits {
  const ProviderLimits({this.perMinute, this.perDay, this.perMonth});

  final int? perMinute;
  final int? perDay;
  final int? perMonth;

  bool get hasQuota => perDay != null || perMonth != null;
}

/// A szolgáltatók ingyenes kerete a [CourtboardHttpException.provider]
/// nevével azonos kulccsal.
///
/// Az API-Sports napi 100 kérése valójában sportágankénti API-ra vonatkozik;
/// itt szándékosan egy közös, óvatosabb keretként számoljuk.
const providerLimits = <String, ProviderLimits>{
  'API-Sports': ProviderLimits(perMinute: 10, perDay: 100),
  'BALLDONTLIE': ProviderLimits(perMinute: 5),
  'football-data.org': ProviderLimits(perMinute: 10),
  'TheSportsDB': ProviderLimits(perMinute: 30),
  // A dokumentáció (2026. szeptember) szerint a Free csomag napi 100 kérés.
  'Live Tennis API': ProviderLimits(perMinute: 30, perDay: 100),
  'RapidAPI Darts': ProviderLimits(perMonth: 1000),
  'RapidAPI WNBA': ProviderLimits(perMonth: 100),
  // Nem kulcsos API, de percenként 20-nál több kérésnél ideiglenesen tilt.
  'Basketball Reference': ProviderLimits(perMinute: 20),
  // Nem dokumentált, kulcs nélküli nyilvános API: kímélő, percenként 30.
  // A sportolói végpontok (keresés, meccsnapló), a scoreboardok és a
  // mérkőzés-összefoglalók is ebből a közös keretből fogynak.
  'ESPN': ProviderLimits(perMinute: 30),
  // Az NBA nyilvános élő scoreboardja (CDN, kb. 10 mp-es szervercache).
  'NBA CDN': ProviderLimits(perMinute: 20),
  // Nyílt, közösségi német focis adatbázis: kímélő, percenként 30.
  'OpenLigaDB': ProviderLimits(perMinute: 30),
  // Hitelesítés nélkül óránként 60 kérés; a frissítés-ellenőrzés 12 órás
  // gyorsítótárral ennek töredékét használja.
  'GitHub': ProviderLimits(perMinute: 10),
};

/// Csúszóablakos kéréskorlátozó: egy [window] időablakban legfeljebb
/// `limit` kérés indulhat, a többi sorban (FIFO) vár.
///
/// Az órát és a várakozást be lehet injektálni, így a tesztek determinisztikusak.
class RateLimiter {
  RateLimiter({
    DateTime Function()? clock,
    Future<void> Function(Duration duration)? delay,
    this.window = const Duration(minutes: 1),
  }) : _clock = clock ?? DateTime.now,
       _delay = delay ?? _realDelay;

  final DateTime Function() _clock;
  final Future<void> Function(Duration duration) _delay;
  final Duration window;

  final Map<String, ListQueue<DateTime>> _sent = {};
  final Map<String, Future<void>> _queues = {};

  static Future<void> _realDelay(Duration duration) =>
      Future<void>.delayed(duration);

  /// Megvárja, amíg a [bucket] ablakában szabad hely lesz, majd lefoglalja.
  ///
  /// A várakozók szigorúan érkezési sorrendben kapnak helyet: a következő
  /// csak az előző engedélyének kiadása után kezd számolni.
  Future<void> acquire(String bucket, int limit) {
    if (limit <= 0) return Future<void>.value();
    final previous = _queues[bucket];
    final granted = Completer<void>();
    _queues[bucket] = granted.future;
    Future<void> run() async {
      try {
        await _take(bucket, limit);
        granted.complete();
      } catch (error, stack) {
        granted.completeError(error, stack);
      }
    }

    if (previous == null) {
      unawaited(run());
    } else {
      unawaited(previous.then((_) => run(), onError: (Object _) => run()));
    }
    return granted.future;
  }

  Future<void> _take(String bucket, int limit) async {
    final sent = _sent.putIfAbsent(bucket, ListQueue<DateTime>.new);
    while (true) {
      final now = _clock();
      while (sent.isNotEmpty && now.difference(sent.first) >= window) {
        sent.removeFirst();
      }
      if (sent.length < limit) {
        sent.addLast(now);
        return;
      }
      final wait = sent.first.add(window).difference(now);
      await _delay(wait.isNegative ? Duration.zero : wait);
    }
  }

  /// Az ablakban lévő kérések száma (tesztekhez és diagnosztikához).
  int pending(String bucket) {
    final now = _clock();
    return _sent[bucket]
            ?.where((sent) => now.difference(sent) < window)
            .length ??
        0;
  }
}

enum QuotaPeriod { day, month }

/// Egy szolgáltató napi vagy havi keretének helyi állása.
class QuotaUsage {
  const QuotaUsage({
    required this.provider,
    required this.used,
    required this.limit,
    required this.period,
  });

  final String provider;
  final int used;
  final int limit;
  final QuotaPeriod period;

  int get remaining => (limit - used).clamp(0, limit);

  /// Rövid magyar felirat, például „Ma: 12 / 100 kérés”.
  String get label => period == QuotaPeriod.day
      ? 'Ma: $used / $limit kérés'
      : 'E hónapban: $used / $limit kérés';
}

/// A helyi napi/havi keret elfogyott: a kérés el sem indul.
class QuotaExhaustedException extends CourtboardHttpException {
  QuotaExhaustedException({
    required super.provider,
    required this.used,
    required this.limit,
    required this.period,
  }) : super(detail: 'helyi keret');

  final int used;
  final int limit;
  final QuotaPeriod period;

  @override
  String get message => period == QuotaPeriod.day
      ? 'a napi keret elfogyott ($used/$limit), holnap újra elérhető'
      : 'a havi keret elfogyott ($used/$limit), jövő hónapban újra elérhető';
}

/// Tartós napi/havi kérésszámláló szolgáltatónként.
///
/// A napok és hónapok UTC szerint fordulnak (az API-Sports is UTC éjfélkor
/// nulláz). A számláló a kérés elküldése előtt nő, így a sikertelen kérések
/// is beleszámítanak – ez a biztonságosabb irány.
class QuotaTracker {
  QuotaTracker({
    this._storage,
    DateTime Function()? clock,
    this._limits = providerLimits,
  }) : _clock = clock ?? DateTime.now;

  final CacheStorage? _storage;
  final DateTime Function() _clock;
  final Map<String, ProviderLimits> _limits;

  CacheStorage get storage => _storage ?? CacheStorage.shared;

  static const _namespace = 'quota';
  static const _fileName = 'usage.json';

  Map<String, _Counter>? _counters;
  Future<void> _lock = Future<void>.value();

  /// Egy kérés helyének lefoglalása; elfogyott keretnél
  /// [QuotaExhaustedException]. Keret nélküli szolgáltatónál nem csinál semmit.
  Future<void> reserve(String provider) {
    final limits = _limits[provider];
    if (limits == null || !limits.hasQuota) return Future<void>.value();
    return _synchronized(() async {
      final counters = await _load();
      final now = _clock().toUtc();
      final checks = [
        if (limits.perDay != null) (QuotaPeriod.day, limits.perDay!),
        if (limits.perMonth != null) (QuotaPeriod.month, limits.perMonth!),
      ];
      for (final (period, limit) in checks) {
        final used = _used(counters, provider, period, now);
        if (used >= limit) {
          throw QuotaExhaustedException(
            provider: provider,
            used: used,
            limit: limit,
            period: period,
          );
        }
      }
      for (final (period, _) in checks) {
        final id = _periodId(period, now);
        final key = _key(provider, period);
        final current = counters[key];
        counters[key] = _Counter(
          id,
          current != null && current.period == id ? current.count + 1 : 1,
        );
      }
      await _save(counters);
    });
  }

  /// A napi/havi kerettel rendelkező szolgáltatók aktuális állása.
  Future<List<QuotaUsage>> snapshot() => _synchronized(() async {
    final counters = await _load();
    final now = _clock().toUtc();
    return [
      for (final entry in _limits.entries) ...[
        if (entry.value.perDay != null)
          QuotaUsage(
            provider: entry.key,
            used: _used(counters, entry.key, QuotaPeriod.day, now),
            limit: entry.value.perDay!,
            period: QuotaPeriod.day,
          ),
        if (entry.value.perMonth != null)
          QuotaUsage(
            provider: entry.key,
            used: _used(counters, entry.key, QuotaPeriod.month, now),
            limit: entry.value.perMonth!,
            period: QuotaPeriod.month,
          ),
      ],
    ];
  });

  Future<R> _synchronized<R>(Future<R> Function() action) {
    final result = _lock.then((_) => action());
    _lock = result.then((_) {}, onError: (Object _) {});
    return result;
  }

  int _used(
    Map<String, _Counter> counters,
    String provider,
    QuotaPeriod period,
    DateTime now,
  ) {
    final counter = counters[_key(provider, period)];
    return counter != null && counter.period == _periodId(period, now)
        ? counter.count
        : 0;
  }

  static String _key(String provider, QuotaPeriod period) =>
      '$provider|${period.name}';

  static String _periodId(QuotaPeriod period, DateTime utc) {
    final month =
        '${utc.year.toString().padLeft(4, '0')}-${utc.month.toString().padLeft(2, '0')}';
    return period == QuotaPeriod.month
        ? month
        : '$month-${utc.day.toString().padLeft(2, '0')}';
  }

  Future<Map<String, _Counter>> _load() async {
    final existing = _counters;
    if (existing != null) return existing;
    final counters = <String, _Counter>{};
    try {
      final record = await storage.read(_namespace, _fileName);
      if (record != null) {
        final decoded = jsonDecode(record.contents);
        final raw = decoded is Map ? decoded['counters'] : null;
        if (raw is Map) {
          raw.forEach((key, value) {
            if (value is Map && value['count'] is int) {
              counters['$key'] = _Counter(
                '${value['period'] ?? ''}',
                value['count'] as int,
              );
            }
          });
        }
      }
    } catch (_) {
      // Sérült számlálófájl: nulláról indulunk.
    }
    return _counters = counters;
  }

  Future<void> _save(Map<String, _Counter> counters) async {
    try {
      await storage.write(
        _namespace,
        _fileName,
        jsonEncode({
          'v': 1,
          'counters': {
            for (final entry in counters.entries)
              entry.key: {
                'period': entry.value.period,
                'count': entry.value.count,
              },
          },
        }),
      );
    } catch (_) {
      // A számláló mentésének hibája nem akaszthatja meg a kérést.
    }
  }
}

class _Counter {
  const _Counter(this.period, this.count);
  final String period;
  final int count;
}
