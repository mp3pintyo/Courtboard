import 'dart:io';

import 'package:courtboard/data/file_util.dart';
import 'package:courtboard/data/url_safety.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('atomic write replaces an existing file and leaves no temp files',
      () async {
    final directory = await Directory.systemTemp.createTemp('courtboard-fu-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/nested/state.json');

    await writeFileAtomic(file, 'első');
    await writeFileAtomic(file, 'második');

    expect(await file.readAsString(), 'második');
    final names = file.parent
        .listSync()
        .map((entity) => entity.uri.pathSegments.last)
        .toList();
    expect(names, ['state.json']);
  });

  test('cache slug is readable for Latin names and hashed otherwise', () {
    expect(cacheSlug('Nikola Jokić'), 'nikola_jokic');
    final cyrillic = cacheSlug('Даниил Медведев');
    final chinese = cacheSlug('郑钦文');
    expect(cyrillic, isNotEmpty);
    expect(chinese, isNotEmpty);
    expect(cyrillic, isNot(chinese));
    expect(cacheSlug('Даниил Медведев'), cyrillic);
    expect(cyrillic, matches(RegExp(r'^h[0-9a-f]{8}$')));
  });

  test('app data path never falls back to the working directory', () {
    final path = appDataPath();
    expect(path, isNotEmpty);
    if (Platform.environment['APPDATA'] == null &&
        Platform.environment['LOCALAPPDATA'] == null) {
      expect(path, Directory.systemTemp.path);
    }
  });

  test('isSafeWebUrl accepts only http and https web addresses', () {
    expect(isSafeWebUrl('https://www.foxsports.com/nba/story'), isTrue);
    expect(isSafeWebUrl('http://example.com'), isTrue);
    expect(isSafeWebUrl('file:///C:/Windows/system32/calc.exe'), isFalse);
    expect(isSafeWebUrl(r'\\server\share\file'), isFalse);
    expect(isSafeWebUrl('javascript:alert(1)'), isFalse);
    expect(isSafeWebUrl('https://'), isFalse);
    expect(isSafeWebUrl('https://user:pass@example.com'), isFalse);
    expect(isSafeWebUrl(''), isFalse);
  });
}
