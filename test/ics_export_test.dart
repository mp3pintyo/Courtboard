import 'dart:convert';
import 'dart:io';

import 'package:courtboard/data/ics_export.dart';
import 'package:courtboard/data/upcoming_events.dart';
import 'package:flutter_test/flutter_test.dart';

UpcomingEvent _event({
  String athlete = 'Nikola Jokić',
  String sport = 'NBA',
  String opponent = 'Utah Jazz',
  DateTime? start,
  bool timeKnown = true,
  String? venue = 'Ball Arena, Denver',
  String? url = 'https://www.espn.com/nba/game/_/gameId/401914127',
}) => UpcomingEvent(
  athleteName: athlete,
  sport: sport,
  title: 'Denver Nuggets – $opponent',
  opponent: opponent,
  competition: 'NBA · Alapszakasz',
  start: start ?? DateTime.utc(2026, 10, 4, 23),
  venue: venue,
  homeAway: 'home',
  source: 'ESPN',
  url: url,
  timeKnown: timeKnown,
);

/// RFC 5545 visszatördelés: CRLF + szóköz/tab törlése.
String _unfold(String text) => text.replaceAll(RegExp('\r\n[ \t]'), '');

void main() {
  group('escape', () {
    test('visszaper, pontosvessző, vessző és sortörés', () {
      expect(icsEscape(r'a\b'), r'a\\b');
      expect(icsEscape('Ball Arena, Denver; CO'), r'Ball Arena\, Denver\; CO');
      expect(
        icsEscape('első\nmásodik\r\nharmadik'),
        r'első\nmásodik\nharmadik',
      );
      expect(icsEscape('Időpont: 19:00'), 'Időpont: 19:00');
      // Az escape sorrendje: a beszúrt visszaperek nem duplázódnak.
      expect(icsEscape(r'\,'), r'\\\,');
    });
  });

  group('75 oktetes tördelés', () {
    test('rövid sor változatlan', () {
      expect(icsFoldLine('SUMMARY:Rövid'), 'SUMMARY:Rövid');
    });

    test('ASCII: 75 oktet az első, 74 + szóköz a folytatósorokban', () {
      final line = 'DESCRIPTION:${'x' * 200}';
      final folded = icsFoldLine(line);
      final parts = folded.split('\r\n');
      expect(parts.first.length, 75);
      for (final part in parts.skip(1)) {
        expect(part.startsWith(' '), isTrue);
        expect(utf8.encode(part).length, lessThanOrEqualTo(75));
      }
      expect(_unfold(folded), line);
    });

    test('UTF-8: többbájtos karakter nem kerül két sorra', () {
      final line = 'SUMMARY:${'Jokić – Świątek ő ű 🏀 ' * 12}';
      final folded = icsFoldLine(line);
      for (final part in folded.split('\r\n')) {
        final bytes = utf8.encode(part);
        expect(bytes.length, lessThanOrEqualTo(75));
        // Érvényes UTF-8 minden sor önmagában is.
        expect(() => utf8.decode(bytes), returnsNormally);
      }
      expect(_unfold(folded), line);
    });
  });

  group('UID', () {
    test('stabil ugyanarra az eseményre, @courtboard utótaggal', () {
      final a = icsUid(_event());
      final b = icsUid(_event(venue: null, url: null));
      expect(a, b);
      expect(a, matches(RegExp(r'^[0-9a-f]{16}@courtboard$')));
    });

    test('eltér más sportolónál, kezdésnél, ellenfélnél vagy forrásnál', () {
      final base = icsUid(_event());
      expect(icsUid(_event(athlete: 'Jamal Murray')), isNot(base));
      expect(icsUid(_event(start: DateTime.utc(2026, 10, 5, 23))), isNot(base));
      expect(icsUid(_event(opponent: 'Phoenix Suns')), isNot(base));
    });

    test('a helyi és az UTC időpont ugyanazt adja', () {
      final utc = DateTime.utc(2026, 10, 4, 23);
      expect(icsUid(_event(start: utc)), icsUid(_event(start: utc.toLocal())));
    });
  });

  test('időformátumok', () {
    expect(icsDateTime(DateTime.utc(2026, 1, 2, 3, 4, 5)), '20260102T030405Z');
    expect(
      icsDateTime(DateTime.utc(2026, 10, 4, 23).toLocal()),
      '20261004T230000Z',
    );
    expect(icsDate(DateTime(2026, 3, 9, 22)), '20260309');
  });

  test('alapértelmezett hossz sportáganként', () {
    expect(defaultEventDuration('NBA'), const Duration(hours: 2));
    expect(defaultEventDuration('Foci'), const Duration(hours: 2));
    expect(defaultEventDuration('Tenisz'), const Duration(hours: 2));
    expect(defaultEventDuration('NFL'), const Duration(hours: 3, minutes: 30));
    expect(defaultEventDuration('Darts'), const Duration(hours: 3));
  });

  group('teljes dokumentum', () {
    final stamp = DateTime.utc(2026, 9, 30, 8, 15);

    test('VCALENDAR fejléc, VEVENT mezők, CRLF sorvégek', () {
      final ics = buildIcsCalendar([
        _event(),
        _event(
          athlete: 'Saquon Barkley',
          sport: 'NFL',
          opponent: 'Los Angeles Rams',
          start: DateTime.utc(2026, 10, 4, 17),
          url: null,
        ),
      ], now: stamp);

      expect(ics.endsWith('\r\n'), isTrue);
      expect(ics.replaceAll('\r\n', '').contains('\n'), isFalse);
      final lines = _unfold(ics).split('\r\n')..removeLast();
      expect(lines.take(4), [
        'BEGIN:VCALENDAR',
        'VERSION:2.0',
        'PRODID:-//Courtboard//HU',
        'CALSCALE:GREGORIAN',
      ]);
      expect(lines.last, 'END:VCALENDAR');
      expect(lines.where((l) => l == 'BEGIN:VEVENT'), hasLength(2));
      expect(lines.where((l) => l == 'END:VEVENT'), hasLength(2));
      expect(lines, contains('DTSTAMP:20260930T081500Z'));
      // NBA: 2 óra.
      expect(lines, contains('DTSTART:20261004T230000Z'));
      expect(lines, contains('DTEND:20261005T010000Z'));
      // NFL: 3,5 óra.
      expect(lines, contains('DTSTART:20261004T170000Z'));
      expect(lines, contains('DTEND:20261004T203000Z'));
      expect(
        lines,
        contains(r'SUMMARY:Nikola Jokić: Denver Nuggets – Utah Jazz'),
      );
      expect(lines, contains(r'LOCATION:Ball Arena\, Denver'));
      expect(
        lines,
        contains('URL:https://www.espn.com/nba/game/_/gameId/401914127'),
      );
      expect(lines.where((l) => l.startsWith('URL:')), hasLength(1));
      expect(lines, contains('UID:${icsUid(_event())}'));
      final description = lines.firstWhere((l) => l.startsWith('DESCRIPTION:'));
      expect(description, contains(r'Sportoló: Nikola Jokić\nSportág: NBA'));
      expect(description, contains(r'Verseny: NBA · Alapszakasz'));
      for (final line in ics.split('\r\n')) {
        expect(utf8.encode(line).length, lessThanOrEqualTo(75));
      }
    });

    test('bizonytalan időpont: egész napos esemény a helyi napra', () {
      final ics = _unfold(
        buildIcsCalendar([
          _event(start: DateTime(2026, 10, 12, 0, 0), timeKnown: false),
        ], now: stamp),
      );
      expect(ics, contains('DTSTART;VALUE=DATE:20261012\r\n'));
      expect(ics, contains('DTEND;VALUE=DATE:20261013\r\n'));
      expect(ics, contains(r'Az időpont még nem végleges.'));
    });

    test('esemény nélkül is érvényes naptár', () {
      final ics = buildIcsCalendar(const [], now: stamp);
      expect(ics, startsWith('BEGIN:VCALENDAR\r\n'));
      expect(ics, endsWith('END:VCALENDAR\r\n'));
      expect(ics, isNot(contains('BEGIN:VEVENT')));
    });
  });

  group('fájlok', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('courtboard-ics-'));
    tearDown(() => dir.delete(recursive: true));

    test('egy esemény .ics fájlja a megadott mappába', () async {
      final file = await writeSingleEventIcs(
        _event(),
        directory: dir,
        now: DateTime.utc(2026, 9, 30),
      );
      expect(
        file.path,
        endsWith('courtboard-nikola_jokic-${icsDate(_event().start)}.ics'),
      );
      final text = await file.readAsString();
      expect(text, contains('BEGIN:VEVENT'));
      expect(text, contains('Nikola Jokić'));
    });

    test('export: mappa létrehozása és UTF-8 tartalom', () async {
      final path = '${dir.path}/al/courtboard-naptar.ics';
      final file = await writeIcsFile(path, buildIcsCalendar([_event()]));
      expect(await file.exists(), isTrue);
      expect(await file.readAsString(), contains('Jokić'));
    });

    test('alapértelmezett exporthely: a profil Letöltések mappája', () {
      final path = defaultIcsExportPath({'USERPROFILE': r'C:\Users\teszt'});
      expect(path, endsWith('courtboard-naptar.ics'));
      expect(path, startsWith(r'C:\Users\teszt'));
      expect(path, contains('Downloads'));
      expect(defaultIcsExportPath(const {}), endsWith(icsExportFileName));
    });
  });
}
