/// Kézzel írt RFC 5545 (iCalendar) kimenet a naptár eseményeihez.
///
/// * `VCALENDAR` → `PRODID:-//Courtboard//HU`, `VERSION:2.0`,
///   `CALSCALE:GREGORIAN`;
/// * eseményenként `VEVENT` stabil `UID`-dal, UTC `DTSTAMP`/`DTSTART`/`DTEND`
///   értékekkel (`YYYYMMDDTHHMMSSZ`), bizonytalan időpontnál egész napos
///   (`VALUE=DATE`) eseménnyel;
/// * szövegértékek escape-elése (`\\`, `\;`, `\,`, `\n`), 75 oktetes
///   sortördelés UTF-8 karakterhatáron, CRLF sorvégek.
library;

import 'dart:convert';
import 'dart:io';

import 'file_util.dart';
import 'upcoming_events.dart';

const icsProductId = '-//Courtboard//HU';

/// Szövegérték escape-elése (RFC 5545 3.3.11): a visszaper, pontosvessző és
/// vessző elé visszaper kerül, a sortörés `\n` lesz.
String icsEscape(String value) => value
    .replaceAll(r'\', r'\\')
    .replaceAll(';', r'\;')
    .replaceAll(',', r'\,')
    .replaceAll('\r\n', r'\n')
    .replaceAll('\r', r'\n')
    .replaceAll('\n', r'\n');

/// Egy tartalomsor tördelése legfeljebb 75 oktetes sorokra (RFC 5545 3.1).
/// A folytatósorok egy szóközzel kezdődnek (ez is beleszámít a 75-be), és
/// többbájtos UTF-8 karakter soha nem kerül két sorra. Az elválasztó CRLF.
String icsFoldLine(String line) {
  const limit = 75;
  final buffer = StringBuffer();
  var lineBytes = 0;
  for (final rune in line.runes) {
    final char = String.fromCharCode(rune);
    final size = utf8.encode(char).length;
    if (lineBytes + size > limit) {
      buffer.write('\r\n ');
      lineBytes = 1;
    }
    buffer.write(char);
    lineBytes += size;
  }
  return buffer.toString();
}

/// UTC időbélyeg `YYYYMMDDTHHMMSSZ` alakban.
String icsDateTime(DateTime value) {
  final utc = value.toUtc();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${utc.year.toString().padLeft(4, '0')}${two(utc.month)}${two(utc.day)}'
      'T${two(utc.hour)}${two(utc.minute)}${two(utc.second)}Z';
}

/// Helyi naptári nap `YYYYMMDD` alakban (egész napos eseményhez).
String icsDate(DateTime value) {
  final local = value.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${local.year.toString().padLeft(4, '0')}${two(local.month)}${two(local.day)}';
}

/// Stabil, ütközésálló azonosító a forrásból, sportolóból, kezdésből és
/// ellenfélből (két független 32 bites FNV-1a hash), `@courtboard` utótaggal.
/// Ugyanaz az esemény újraexportálva ugyanazt az UID-ot kapja, így a
/// naptáralkalmazás frissíti, nem duplikálja.
String icsUid(UpcomingEvent event) {
  final key = [
    event.source,
    event.athleteName,
    event.start.toUtc().toIso8601String(),
    event.opponent.isEmpty ? event.title : event.opponent,
  ].join('|');
  return '${fnv1a32Hex(key)}${fnv1a32Hex('courtboard:$key')}@courtboard';
}

/// Az esemény címe a naptárban: „Nikola Jokić: Denver Nuggets – Utah Jazz”.
String icsSummary(UpcomingEvent event) =>
    '${event.athleteName}: ${event.title}';

/// A leírás sorai (sportoló, sportág, verseny, forrás).
String icsDescription(UpcomingEvent event) => [
  'Sportoló: ${event.athleteName}',
  'Sportág: ${event.sport}',
  if (event.opponent.isNotEmpty) 'Ellenfél: ${event.opponent}',
  if (event.competition.isNotEmpty) 'Verseny: ${event.competition}',
  if (event.homeAway == 'home') 'Hazai pályán',
  if (event.homeAway == 'away') 'Idegenben',
  if (!event.timeKnown) 'Az időpont még nem végleges.',
  'Forrás: ${event.source} (Courtboard)',
].join('\n');

/// Egyetlen `VEVENT` tartalomsorai (tördelés nélkül).
List<String> icsEventLines(UpcomingEvent event, {required DateTime stamp}) {
  final url = event.url;
  final lines = <String>[
    'BEGIN:VEVENT',
    'UID:${icsUid(event)}',
    'DTSTAMP:${icsDateTime(stamp)}',
  ];
  if (event.timeKnown) {
    lines
      ..add('DTSTART:${icsDateTime(event.start)}')
      ..add(
        'DTEND:${icsDateTime(event.start.add(defaultEventDuration(event.sport)))}',
      );
  } else {
    final day = event.start.toLocal();
    lines
      ..add('DTSTART;VALUE=DATE:${icsDate(day)}')
      ..add(
        'DTEND;VALUE=DATE:${icsDate(DateTime(day.year, day.month, day.day + 1))}',
      );
  }
  lines
    ..add('SUMMARY:${icsEscape(icsSummary(event))}')
    ..addAll([
      if (event.venue case final String venue when venue.isNotEmpty)
        'LOCATION:${icsEscape(venue)}',
    ])
    ..add('DESCRIPTION:${icsEscape(icsDescription(event))}')
    ..addAll([
      if (event.sport.isNotEmpty) 'CATEGORIES:${icsEscape(event.sport)}',
      // Az URL értéktípusú mező: nem escape-elünk, csak biztonságos címet írunk.
      if (url != null && url.startsWith('https://')) 'URL:$url',
    ])
    ..add('END:VEVENT');
  return lines;
}

/// Teljes iCalendar-dokumentum az [events] eseményekkel (üres listánál is
/// érvényes, esemény nélküli naptár). A [now] a `DTSTAMP` értéke.
String buildIcsCalendar(Iterable<UpcomingEvent> events, {DateTime? now}) {
  final stamp = now ?? DateTime.now();
  final lines = <String>[
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:$icsProductId',
    'CALSCALE:GREGORIAN',
    'METHOD:PUBLISH',
    'X-WR-CALNAME:Courtboard',
    for (final event in events) ...icsEventLines(event, stamp: stamp),
    'END:VCALENDAR',
  ];
  return '${lines.map(icsFoldLine).join('\r\n')}\r\n';
}

/// Fájlnévbe illő, stabil név egy eseményhez
/// (`courtboard-nikola_jokic-20261004.ics`).
String icsFileName(UpcomingEvent event) =>
    'courtboard-${cacheSlug(event.athleteName)}-${icsDate(event.start)}.ics';

/// Az „Összes exportálása” alapértelmezett fájlneve.
const icsExportFileName = 'courtboard-naptar.ics';

/// A felhasználó Letöltések mappájába mutató útvonal
/// (`%USERPROFILE%\Downloads\courtboard-naptar.ics`); ha a profilmappa nem
/// ismert, a rendszer ideiglenes mappája.
String defaultIcsExportPath([Map<String, String>? environment]) {
  final env = environment ?? Platform.environment;
  final profile = env['USERPROFILE'] ?? env['HOME'];
  final base = profile == null || profile.trim().isEmpty
      ? Directory.systemTemp.path
      : '$profile${Platform.pathSeparator}Downloads';
  return '$base${Platform.pathSeparator}$icsExportFileName';
}

/// Az iCalendar-szöveg atomikus mentése (a mappa szükség esetén létrejön).
Future<File> writeIcsFile(String path, String contents) async {
  final file = File(path);
  await writeFileAtomic(file, contents);
  return file;
}

/// Egyetlen esemény `.ics` fájlja az ideiglenes mappában
/// (`%TEMP%\courtboard\…`), az alapértelmezett naptáralkalmazásnak.
Future<File> writeSingleEventIcs(
  UpcomingEvent event, {
  Directory? directory,
  DateTime? now,
}) {
  final dir =
      directory ??
      Directory(
        '${Directory.systemTemp.path}${Platform.pathSeparator}courtboard',
      );
  return writeIcsFile(
    '${dir.path}${Platform.pathSeparator}${icsFileName(event)}',
    buildIcsCalendar([event], now: now),
  );
}
