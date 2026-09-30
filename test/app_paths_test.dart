import 'dart:io';

import 'package:courtboard/data/app_paths.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'all caches live under one root and legacy caches are migrated',
    () async {
      final previous = AppPaths.root;
      final root = await Directory.systemTemp.createTemp('courtboard-paths-');
      AppPaths.overrideRoot(root.path);
      addTearDown(() async {
        AppPaths.overrideRoot(previous);
        await root.delete(recursive: true);
      });

      expect(AppPaths.cacheDirectory('fotmob'), '${root.path}/cache/fotmob');
      expect(AppPaths.newsDatabase, '${root.path}/courtboard_news.sqlite');

      final csv = File('${root.path}/wnba_cache/player_box_2025.csv');
      await csv.create(recursive: true);
      await csv.writeAsString('game_id');
      final oldJson = File('${root.path}/courtboard_cache/darts/x.json');
      await oldJson.create(recursive: true);

      await AppPaths.migrateLegacyCaches();

      expect(
        await File(
          '${AppPaths.cacheDirectory('wehoop_wnba')}/player_box_2025.csv',
        ).readAsString(),
        'game_id',
      );
      expect(await Directory('${root.path}/wnba_cache').exists(), isFalse);
      expect(
        await Directory('${root.path}/courtboard_cache').exists(),
        isFalse,
      );
    },
  );
}
