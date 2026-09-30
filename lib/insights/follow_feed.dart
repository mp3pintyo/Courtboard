/// „Követés” hírfolyam: a követett sportolókhoz kötődő hírek, mentett
/// videók, eredmények és közelgő események egyetlen idővonalon.
///
/// Csak már tárolt adatból dolgozik (hírarchívum, videólista, kiemelések,
/// naptár-gyorsítótár), így megnyitása nem indít hálózati kérést.
library;

import '../components.dart';
import '../data/athlete_highlights.dart';
import '../data/news.dart';
import '../data/upcoming_events.dart';
import '../data/youtube_playlist.dart';
import '../format.dart';

enum FeedItemType {
  upcoming('Következő', 'Következő'),
  result('Eredmény', 'Eredmények'),
  news('Hír', 'Hírek'),
  video('Videó', 'Videók');

  const FeedItemType(this.label, this.pluralLabel);
  final String label;
  final String pluralLabel;
}

class FeedItem {
  const FeedItem({
    required this.id,
    required this.type,
    required this.time,
    required this.title,
    required this.athletes,
    this.detail = '',
    this.url,
    this.outcome = MatchOutcome.unknown,
    this.score = '',
    this.imageUrl = '',
  });

  /// Stabil azonosító (típus + forrásazonosító) a duplikátumok kiszűréséhez.
  final String id;
  final FeedItemType type;
  final DateTime time;
  final String title;

  /// A kapcsolódó követett sportolók (az első a „fő” sportoló).
  final List<String> athletes;
  final String detail;

  /// Hírnél a cikk, videónál a YouTube-oldal címe.
  final String? url;
  final MatchOutcome outcome;
  final String score;
  final String imageUrl;

  String get athlete => athletes.isEmpty ? '' : athletes.first;
}

/// Ennyi napra előre kerülnek a hírfolyamba a közelgő események.
const feedUpcomingHorizon = Duration(days: 7);

/// A követett sportolókat említő hírek (egy cikk egyszer, az összes
/// említett sportolóval).
List<FeedItem> feedFromNews(
  Iterable<NewsArticle> articles,
  List<String> athleteNames,
) => [
  for (final article in articles)
    if (athleteNames.where((name) => newsMatchesAthlete(article, name)).toList()
        case final matched when matched.isNotEmpty)
      FeedItem(
        id: 'news:${article.dedupeKey}',
        type: FeedItemType.news,
        time: article.publishedAt,
        title: article.title,
        athletes: matched,
        detail: article.sourceName,
        url: article.url,
        imageUrl: article.imageUrl,
      ),
];

/// A követett sportolókhoz mentett videók (a mentés ideje szerint).
List<FeedItem> feedFromVideos(
  Iterable<SavedYouTubeVideo> videos,
  List<String> athleteNames,
) {
  final followed = athleteNames.toSet();
  return [
    for (final video in videos)
      if (followed.contains(video.athleteName))
        FeedItem(
          id: 'video:${video.athleteName}:${video.videoId}',
          type: FeedItemType.video,
          time: video.savedAt,
          title: video.title,
          athletes: [video.athleteName],
          detail: 'Mentett YouTube-videó',
          url: video.watchUrl,
          imageUrl: video.thumbnailUrl,
        ),
  ];
}

/// A profilokon már betöltött lejátszott eredmények.
List<FeedItem> feedFromHighlights(
  Map<String, AthleteHighlight> highlights,
  DateTime now,
) => [
  for (final MapEntry(key: name, value: highlight) in highlights.entries)
    for (final event in highlight.recent)
      if (!event.date.isAfter(now) && event.outcome != 'upcoming')
        FeedItem(
          id: 'result:$name:${event.date.toIso8601String()}:${event.title}',
          type: FeedItemType.result,
          time: event.date,
          title: event.title,
          athletes: [name],
          outcome: MatchOutcome.values.firstWhere(
            (value) => value.name == event.outcome,
            orElse: () => MatchOutcome.unknown,
          ),
          score: event.score,
        ),
];

/// A naptár (gyorsítótárból betöltött) eseményei a következő 7 napból.
List<FeedItem> feedFromUpcoming(
  Iterable<UpcomingEvent> events,
  DateTime now, {
  Duration horizon = feedUpcomingHorizon,
}) => [
  for (final event in events)
    if (event.start.isAfter(now) && !event.start.isAfter(now.add(horizon)))
      FeedItem(
        id: 'upcoming:${event.athleteName}:${event.start.toIso8601String()}:${event.title}',
        type: FeedItemType.upcoming,
        time: event.start,
        title: event.matchup,
        athletes: [event.athleteName],
        detail: event.competition,
        url: event.url,
        outcome: MatchOutcome.upcoming,
      ),
];

/// A források összefésülése és szűrése. Elöl a közelgő események (a
/// legközelebbi elöl), utána minden más fordított időrendben (a legfrissebb
/// elöl); az azonos azonosítójú elemek egyszer szerepelnek.
List<FeedItem> mergeFeed(
  Iterable<FeedItem> items, {
  Set<FeedItemType>? types,
  String? athlete,
}) {
  final seen = <String>{};
  final upcoming = <FeedItem>[];
  final past = <FeedItem>[];
  for (final item in items) {
    if (!seen.add(item.id)) continue;
    if (types != null && types.isNotEmpty && !types.contains(item.type)) {
      continue;
    }
    if (athlete != null && !item.athletes.contains(athlete)) continue;
    (item.type == FeedItemType.upcoming ? upcoming : past).add(item);
  }
  upcoming.sort((a, b) => a.time.compareTo(b.time));
  past.sort((a, b) {
    final byTime = b.time.compareTo(a.time);
    return byTime != 0 ? byTime : a.type.index.compareTo(b.type.index);
  });
  return [...upcoming, ...past];
}

/// Magyar relatív időpont: „most”, „5 perce”, „2 órája”, „tegnap”,
/// „3 napja”, régebben dátum („ápr. 12.”); jövőbeli időpontnál „ma 19:30”,
/// „holnap 19:30”, „3 nap múlva”.
String formatRelativeTime(DateTime time, {required DateTime now}) {
  final local = time.toLocal();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(local.year, local.month, local.day);
  // Naptári napok különbsége (a nyári időszámítás órája nem zavarja).
  final days = DateTime.utc(
    day.year,
    day.month,
    day.day,
  ).difference(DateTime.utc(today.year, today.month, today.day)).inDays;
  final diff = now.difference(local);
  if (diff.isNegative) {
    if (-diff.inSeconds < 60) return 'most';
    if (days == 0) return 'ma ${formatTime(local)}';
    if (days == 1) return 'holnap ${formatTime(local)}';
    if (days < 7) return '$days nap múlva';
    return formatMatchDate(local, now: now);
  }
  if (diff.inMinutes < 1) return 'most';
  if (diff.inMinutes < 60) return '${diff.inMinutes} perce';
  if (days == 0 || diff.inHours < 6) return '${diff.inHours} órája';
  if (days == -1) return 'tegnap';
  if (days > -7) return '${-days} napja';
  return formatMatchDate(local, now: now);
}

/// A nyitóoldal előnézete: legfeljebb [maxUpcoming] közelgő esemény (a
/// legközelebbiek), a többi hely a legfrissebb múltbeli elemeké; ha
/// azokból kevés van, további közelgő események töltik ki. A [feed] a
/// [mergeFeed] kimenete (elöl a közelgők).
List<FeedItem> feedPreview(
  List<FeedItem> feed, {
  int count = 6,
  int maxUpcoming = 2,
}) {
  final upcoming = [
    for (final item in feed)
      if (item.type == FeedItemType.upcoming) item,
  ];
  final past = [
    for (final item in feed)
      if (item.type != FeedItemType.upcoming) item,
  ];
  final upcomingSlots = (count - past.length).clamp(maxUpcoming, count);
  return [
    ...upcoming.take(upcomingSlots),
    ...past,
  ].take(count).toList(growable: false);
}
