import 'dart:convert';
import 'dart:io';

import 'package:courtboard/data/file_util.dart';
import 'package:courtboard/data/youtube_playlist.dart';

/// A [PlaylistStore.load] eredménye.
class PlaylistLoadResult {
  const PlaylistLoadResult({
    this.playlist = const AthleteVideoPlaylist(),
    this.corrupt = false,
    this.backup,
  });

  final AthleteVideoPlaylist playlist;

  /// Igaz, ha a mentett fájl nem volt beolvasható.
  final bool corrupt;

  /// A sérült fájlról készült biztonsági másolat (ha sikerült elkészíteni).
  final File? backup;

  /// A sérült fájlt nem szabad felülírni, ha másolat sem készülhetett róla.
  bool get saveBlocked => corrupt && backup == null;
}

/// A saját videólista (`playlist.json`) betöltése és atomikus mentése.
///
/// Olvashatatlan fájlnál előbb biztonsági másolat készül; ha ez sem sikerül,
/// a mentés tiltott marad, hogy a felhasználó adata ne vesszen el.
class PlaylistStore {
  PlaylistStore(this.file);

  final File file;

  bool _saveBlocked = false;

  /// Igaz, ha a korábbi, olvashatatlan fájl védelme miatt nem mentünk.
  bool get saveBlocked => _saveBlocked;

  Future<PlaylistLoadResult> load() async {
    try {
      if (!await file.exists()) return const PlaylistLoadResult();
      final content = jsonDecode(await file.readAsString());
      return PlaylistLoadResult(
        playlist: AthleteVideoPlaylist.fromJson(content),
      );
    } catch (_) {
      final backup = await _backup();
      _saveBlocked = backup == null;
      return PlaylistLoadResult(corrupt: true, backup: backup);
    }
  }

  Future<File?> _backup() async {
    final stamp = DateTime.now()
        .toUtc()
        .toIso8601String()
        .replaceAll(RegExp(r'[^0-9]'), '')
        .substring(0, 17);
    final path = file.path.endsWith('.json')
        ? file.path.substring(0, file.path.length - 5)
        : file.path;
    try {
      return await file.copy('$path.corrupt-$stamp.json');
    } catch (_) {
      return null;
    }
  }

  /// A videólista mentése. Hibát dob, ha a fájl nem írható, vagy ha a
  /// korábbi, olvashatatlan fájl védelme miatt a mentés tiltott.
  Future<void> save(AthleteVideoPlaylist playlist) async {
    if (_saveBlocked) {
      throw const FileSystemException('A videólista mentése le van tiltva.');
    }
    await writeFileAtomic(file, jsonEncode(playlist.toJson()));
  }
}
