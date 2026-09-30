/// Az értesítések (Beállítások → Értesítések) mentett beállításai.
///
/// A háttérfigyelő ([AthleteWatcher]) csak azokról a sportolókról küld
/// értesítést, akiknél a profilon be van kapcsolva az „Értesítés”; ez a
/// beállítás a típusokat, a gyakoriságot és a csendes órákat szabályozza.
class NotificationSettings {
  const NotificationSettings({
    this.enabled = true,
    this.matchStart = true,
    this.results = true,
    this.news = true,
    this.intervalMinutes = defaultIntervalMinutes,
    this.quietHours = false,
    this.quietStartMinutes = 23 * 60,
    this.quietEndMinutes = 7 * 60,
  });

  /// Az összes értesítés fő kapcsolója.
  final bool enabled;

  /// „Meccs kezdődik”: 15 perccel a kezdés előtt.
  final bool matchStart;

  /// „Új eredmény” a legutóbbi mérkőzésekben.
  final bool results;

  /// „Új hír” a követett sportolóról.
  final bool news;

  /// Az ellenőrzések gyakorisága percben ([intervalOptions] egyike).
  final int intervalMinutes;

  /// Csendes órák: ilyenkor nem jelenik meg értesítés.
  final bool quietHours;

  /// A csendes órák kezdete és vége éjfél óta eltelt percekben (helyi idő);
  /// ha a kezdet a vég után van, az időszak átnyúlik éjfélen.
  final int quietStartMinutes;
  final int quietEndMinutes;

  static const defaultIntervalMinutes = 15;
  static const intervalOptions = [5, 15, 30, 60];

  Duration get interval => Duration(minutes: intervalMinutes);

  /// Igaz, ha [local] (helyi idő) a csendes órákba esik.
  bool isQuietAt(DateTime local) {
    if (!quietHours || quietStartMinutes == quietEndMinutes) return false;
    final minute = local.hour * 60 + local.minute;
    return quietStartMinutes < quietEndMinutes
        ? minute >= quietStartMinutes && minute < quietEndMinutes
        : minute >= quietStartMinutes || minute < quietEndMinutes;
  }

  NotificationSettings copyWith({
    bool? enabled,
    bool? matchStart,
    bool? results,
    bool? news,
    int? intervalMinutes,
    bool? quietHours,
    int? quietStartMinutes,
    int? quietEndMinutes,
  }) => NotificationSettings(
    enabled: enabled ?? this.enabled,
    matchStart: matchStart ?? this.matchStart,
    results: results ?? this.results,
    news: news ?? this.news,
    intervalMinutes: _validInterval(intervalMinutes ?? this.intervalMinutes),
    quietHours: quietHours ?? this.quietHours,
    quietStartMinutes: _validMinute(
      quietStartMinutes ?? this.quietStartMinutes,
      23 * 60,
    ),
    quietEndMinutes: _validMinute(
      quietEndMinutes ?? this.quietEndMinutes,
      7 * 60,
    ),
  );

  Map<String, Object?> toJson() => {
    'enabled': enabled,
    'matchStart': matchStart,
    'results': results,
    'news': news,
    'intervalMinutes': intervalMinutes,
    'quietHours': quietHours,
    'quietStart': quietStartMinutes,
    'quietEnd': quietEndMinutes,
  };

  /// Hiányzó vagy hibás mezőknél az alapértékek élnek.
  factory NotificationSettings.fromJson(Object? json) {
    if (json is! Map) return const NotificationSettings();
    return NotificationSettings(
      enabled: json['enabled'] != false,
      matchStart: json['matchStart'] != false,
      results: json['results'] != false,
      news: json['news'] != false,
      intervalMinutes: _validInterval(json['intervalMinutes']),
      quietHours: json['quietHours'] == true,
      quietStartMinutes: _validMinute(json['quietStart'], 23 * 60),
      quietEndMinutes: _validMinute(json['quietEnd'], 7 * 60),
    );
  }

  static int _validInterval(Object? value) =>
      value is int && intervalOptions.contains(value)
      ? value
      : defaultIntervalMinutes;

  static int _validMinute(Object? value, int fallback) =>
      value is int && value >= 0 && value < 24 * 60 ? value : fallback;

  @override
  bool operator ==(Object other) =>
      other is NotificationSettings &&
      other.enabled == enabled &&
      other.matchStart == matchStart &&
      other.results == results &&
      other.news == news &&
      other.intervalMinutes == intervalMinutes &&
      other.quietHours == quietHours &&
      other.quietStartMinutes == quietStartMinutes &&
      other.quietEndMinutes == quietEndMinutes;

  @override
  int get hashCode => Object.hash(
    enabled,
    matchStart,
    results,
    news,
    intervalMinutes,
    quietHours,
    quietStartMinutes,
    quietEndMinutes,
  );
}

/// „23:00” alakú felirat az éjfél óta eltelt percekből.
String formatMinuteOfDay(int minutes) {
  final value = minutes.clamp(0, 24 * 60 - 1);
  final hour = (value ~/ 60).toString().padLeft(2, '0');
  final minute = (value % 60).toString().padLeft(2, '0');
  return '$hour:$minute';
}
