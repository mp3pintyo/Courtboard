import 'package:courtboard/data/http_service.dart';
import 'package:courtboard/data/http_util.dart';
import 'package:courtboard/data/json_file_cache.dart';
import 'package:courtboard/data/json_util.dart';
import 'package:courtboard/data/rate_limit.dart';

/// Szemantikus verzió (`MAJOR.MINOR.PATCH[-előzetes][+build]`), a
/// SemVer 2.0 elsőbbségi szabályaival. A build-metaadat nem számít.
class SemanticVersion implements Comparable<SemanticVersion> {
  const SemanticVersion(
    this.major,
    this.minor,
    this.patch, [
    this.preRelease = const [],
  ]);

  final int major;
  final int minor;
  final int patch;

  /// Az előzetes kiadás azonosítói (`beta.2` → `['beta', '2']`).
  final List<String> preRelease;

  bool get isPreRelease => preRelease.isNotEmpty;

  static final _pattern = RegExp(
    r'^[vV]?(\d+)\.(\d+)(?:\.(\d+))?(?:-([0-9A-Za-z.-]+))?(?:\+[0-9A-Za-z.-]+)?$',
  );

  /// `v0.12.0`, `0.12.0-beta.1`, `0.11.0+12`, `1.2` → verzió; minden más
  /// `null`.
  static SemanticVersion? tryParse(String? value) {
    final match = _pattern.firstMatch((value ?? '').trim());
    if (match == null) return null;
    final pre = match.group(4);
    return SemanticVersion(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3) ?? '0'),
      pre == null ? const [] : pre.split('.'),
    );
  }

  @override
  int compareTo(SemanticVersion other) {
    for (final (a, b) in [
      (major, other.major),
      (minor, other.minor),
      (patch, other.patch),
    ]) {
      if (a != b) return a.compareTo(b);
    }
    // Előzetes kiadás < végleges kiadás.
    if (preRelease.isEmpty || other.preRelease.isEmpty) {
      return other.preRelease.length.sign - preRelease.length.sign;
    }
    for (var i = 0; i < preRelease.length && i < other.preRelease.length; i++) {
      final a = preRelease[i];
      final b = other.preRelease[i];
      final an = int.tryParse(a);
      final bn = int.tryParse(b);
      final result = an != null && bn != null
          ? an.compareTo(bn)
          : an != null
          ? -1
          : bn != null
          ? 1
          : a.compareTo(b);
      if (result != 0) return result;
    }
    return preRelease.length.compareTo(other.preRelease.length);
  }

  bool operator >(SemanticVersion other) => compareTo(other) > 0;

  @override
  bool operator ==(Object other) =>
      other is SemanticVersion && compareTo(other) == 0;

  @override
  int get hashCode => Object.hash(major, minor, patch, preRelease.join('.'));

  @override
  String toString() =>
      '$major.$minor.$patch${preRelease.isEmpty ? '' : '-${preRelease.join('.')}'}';
}

/// A GitHubon közzétett legfrissebb kiadás lényeges adatai.
class ReleaseInfo {
  const ReleaseInfo({
    required this.tagName,
    required this.version,
    required this.htmlUrl,
    this.name = '',
    this.publishedAt,
    this.prerelease = false,
    this.draft = false,
  });

  final String tagName;
  final SemanticVersion version;

  /// A kiadás oldala (letöltésekkel és kiadási jegyzettel).
  final String htmlUrl;
  final String name;
  final DateTime? publishedAt;
  final bool prerelease;
  final bool draft;

  /// A GitHub `releases/latest` válaszából; értelmezhetetlen (hiányzó vagy
  /// nem szemantikus tag, nem https-es oldal) adatnál `null`.
  static ReleaseInfo? fromJson(Object? json) {
    final map = jsonMap(json);
    final tag = jsonString(map['tag_name']);
    final version = SemanticVersion.tryParse(tag);
    final url = jsonString(map['html_url']);
    if (tag == null ||
        version == null ||
        url == null ||
        !url.startsWith('https://github.com/')) {
      return null;
    }
    return ReleaseInfo(
      tagName: tag,
      version: version,
      htmlUrl: url,
      name: jsonString(map['name']) ?? tag,
      publishedAt: DateTime.tryParse(jsonString(map['published_at']) ?? ''),
      prerelease: map['prerelease'] == true || version.isPreRelease,
      draft: map['draft'] == true,
    );
  }

  Map<String, Object?> toJson() => {
    'tag_name': tagName,
    'html_url': htmlUrl,
    'name': name,
    'published_at': publishedAt?.toUtc().toIso8601String(),
    'prerelease': prerelease,
    'draft': draft,
  };
}

enum UpdateStatus {
  /// Van a futónál újabb, végleges kiadás.
  updateAvailable,

  /// A futó verzió a legfrissebb (vagy annál újabb, például fejlesztői build).
  upToDate,

  /// Az ellenőrzés nem sikerült (hálózat, kéréskorlát, hibás válasz).
  failed,
}

/// Egy frissítés-ellenőrzés eredménye.
class UpdateCheckResult {
  const UpdateCheckResult({
    required this.status,
    required this.currentVersion,
    this.latest,
    this.message,
    this.checkedAt,
    this.fromCache = false,
  });

  final UpdateStatus status;
  final String currentVersion;
  final ReleaseInfo? latest;

  /// Felhasználónak szóló magyar magyarázat hibánál (vagy ha nincs kiadás).
  final String? message;
  final DateTime? checkedAt;
  final bool fromCache;

  bool get updateAvailable => status == UpdateStatus.updateAvailable;

  /// Rövid összefoglaló a Beállítások oldalra.
  String get summary => switch (status) {
    UpdateStatus.updateAvailable =>
      'Új verzió érhető el: ${latest!.version} (jelenlegi: $currentVersion).',
    UpdateStatus.upToDate => 'A Courtboard naprakész ($currentVersion).',
    UpdateStatus.failed => message ?? 'A frissítések most nem ellenőrizhetők.',
  };
}

/// Frissítés-ellenőrzés a GitHub Releases API-val
/// (`/repos/mp3pintyo/Courtboard/releases/latest`).
///
/// * A válasz 12 órán át gyorsítótárból jön ([cacheLifetime]); a „Keresés
///   most” gomb ([check] `force: true`) kikerüli.
/// * A kérés `User-Agent` fejlécet küld (a GitHub API megköveteli).
/// * 403/429 kéréskorlátnál barátságos üzenet; hálózati hibánál a régebbi
///   mentett válasz is felhasználható.
/// * Előzetes (prerelease) és vázlat kiadásról nem szól.
class UpdateChecker {
  UpdateChecker({
    required this.currentVersion,
    HttpService? http,
    this._cacheStorage,
    DateTime Function()? clock,
    this.cacheLifetime = const Duration(hours: 12),
    this.repository = 'mp3pintyo/Courtboard',
  }) : _http = http ?? HttpService.shared,
       _clock = clock ?? DateTime.now;

  /// A futó alkalmazás verziója (`0.11.0` vagy `0.11.0+12`).
  final String currentVersion;
  final HttpService _http;
  final CacheStorage? _cacheStorage;
  final DateTime Function() _clock;
  final Duration cacheLifetime;
  final String repository;

  static const provider = 'GitHub';

  Uri get latestReleaseUri =>
      Uri.https('api.github.com', '/repos/$repository/releases/latest');

  /// A kiadások oldala (ha a konkrét kiadás linkje nem ismert).
  String get releasesPage => 'https://github.com/$repository/releases';

  JsonFileCache get _cache =>
      JsonFileCache('update_check', storage: _cacheStorage, clock: _clock);

  /// Az ellenőrzés; soha nem dob kivételt.
  Future<UpdateCheckResult> check({bool force = false}) async {
    final current = SemanticVersion.tryParse(currentVersion);
    if (current == null) {
      return UpdateCheckResult(
        status: UpdateStatus.failed,
        currentVersion: currentVersion,
        message: 'A futó verzió nem állapítható meg.',
      );
    }
    try {
      final cached = await _cache.getOrFetch<ReleaseInfo>(
        'latest_release',
        ttl: cacheLifetime,
        forceRefresh: force,
        fetch: _fetchLatest,
        encode: (value) => value.toJson(),
        decode: (json) =>
            ReleaseInfo.fromJson(json) ??
            (throw const FormatException('release')),
      );
      return evaluate(
        current: currentVersion,
        latest: cached.value,
        checkedAt: cached.fetchedAt,
        fromCache: cached.fromCache,
      );
    } catch (error) {
      return UpdateCheckResult(
        status: UpdateStatus.failed,
        currentVersion: currentVersion,
        message: describeError(error),
        checkedAt: _clock(),
      );
    }
  }

  Future<ReleaseInfo> _fetchLatest() async {
    final json = await _http.getJson(
      latestReleaseUri,
      provider: provider,
      headers: {
        'User-Agent':
            'Courtboard/$currentVersion (+https://github.com/$repository)',
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
      },
    );
    return ReleaseInfo.fromJson(json) ??
        (throw const FormatException('A kiadás adatai hiányosak.'));
  }

  /// A futó és a legfrissebb verzió összevetése. Előzetes vagy vázlat
  /// kiadás soha nem számít frissítésnek.
  static UpdateCheckResult evaluate({
    required String current,
    required ReleaseInfo latest,
    DateTime? checkedAt,
    bool fromCache = false,
  }) {
    final running = SemanticVersion.tryParse(current);
    final newer =
        running != null &&
        !latest.prerelease &&
        !latest.draft &&
        latest.version > running;
    return UpdateCheckResult(
      status: newer ? UpdateStatus.updateAvailable : UpdateStatus.upToDate,
      currentVersion: running?.toString() ?? current,
      latest: latest,
      checkedAt: checkedAt,
      fromCache: fromCache,
    );
  }

  /// Magyar hibaüzenet a GitHub-specifikus esetekre.
  static String describeError(Object error) {
    if (error is QuotaExhaustedException) {
      return 'A frissítés-ellenőrzés kerete most elfogyott, próbáld később.';
    }
    if (error is CourtboardHttpException) {
      if (error.statusCode == 403 || error.statusCode == 429) {
        return 'A GitHub kéréskorlátja átmenetileg elfogyott, próbáld később.';
      }
      if (error.statusCode == 404) return 'Még nincs közzétett kiadás.';
      if (error.timedOut) return 'A GitHub nem válaszolt időben.';
      if (error.statusCode == null) return 'Nincs internetkapcsolat.';
      return 'A GitHub most nem érhető el, próbáld később.';
    }
    if (error is FormatException) {
      return 'A kiadási adatok nem értelmezhetők.';
    }
    return 'A frissítések most nem ellenőrizhetők.';
  }
}
