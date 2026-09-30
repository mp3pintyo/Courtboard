import 'dart:convert';
import 'dart:io';

import 'api_sports.dart' show normalizeAthleteName;

/// A Courtboard által írt fájlok gyökere.
///
/// Windows alatt `%APPDATA%`, ha az hiányzik, `%LOCALAPPDATA%`, végső esetben
/// a rendszer ideiglenes könyvtára. A munkakönyvtárat soha nem használjuk,
/// mert az indítás módjától függően bárhová mutathat.
String appDataPath() {
  final environment = Platform.environment;
  for (final key in const ['APPDATA', 'LOCALAPPDATA']) {
    final value = environment[key]?.trim() ?? '';
    if (value.isNotEmpty) return value;
  }
  return Directory.systemTemp.path;
}

var _tempCounter = 0;

/// Atomikus fájlírás: először egy egyedi `.tmp` fájlba ír, majd átnevezi a
/// célfájlra. Windows alatt a `File.rename` felülírja a meglévő célt; ha a cél
/// épp nyitva van (megosztási hiba), néhányszor újrapróbálja, végül közvetlen
/// írásra vált, hogy a mentés ne vesszen el.
Future<void> writeFileAtomic(File file, String contents) async {
  await file.parent.create(recursive: true);
  final temp = File('${file.path}.${pid}_${_tempCounter++}.tmp');
  try {
    await temp.writeAsString(contents, flush: true);
    for (var attempt = 0;; attempt++) {
      try {
        await temp.rename(file.path);
        return;
      } on FileSystemException {
        if (attempt >= 4) break;
        await Future<void>.delayed(Duration(milliseconds: 50 * (attempt + 1)));
      }
    }
    await file.writeAsString(contents, flush: true);
  } finally {
    try {
      if (await temp.exists()) await temp.delete();
    } catch (_) {
      // Az ideiglenes fájl eltakarítása nem akadályozhatja a mentést.
    }
  }
}

/// Fájlnévbe biztonságosan illeszthető, stabil azonosító egy névből.
///
/// Latin betűs neveknél olvasható slugot ad (`nikola_jokic`); ha a
/// normalizálás után semmi nem marad (például cirill vagy kínai név), a név
/// UTF-8 bájtjainak FNV-1a hash-éből képez azonosítót, így különböző nevek nem
/// osztoznak ugyanazon a cache-fájlon.
String cacheSlug(String name) {
  final slug = normalizeAthleteName(name).replaceAll(' ', '_');
  if (slug.isNotEmpty) {
    return slug.length <= 80 ? slug : slug.substring(0, 80);
  }
  return 'h${fnv1a32Hex(name.trim())}';
}

/// 32 bites FNV-1a hash hexadecimális alakban (UTF-8 bájtokon számolva).
String fnv1a32Hex(String value) {
  var hash = 0x811c9dc5;
  for (final byte in utf8.encode(value)) {
    hash ^= byte;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}
