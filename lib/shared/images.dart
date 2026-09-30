/// Hálózati képek lemezes gyorsítótárral, méretezett dekódolással,
/// beúszó megjelenéssel és egységes helyőrzővel.
///
/// A `cached_network_image` csomag a `flutter_cache_manager`-en át az
/// `sqflite`-ra épül, amelynek nincs Windows-implementációja; ezért egy
/// kicsi, saját [ImageProvider] tölti a képeket a közös HTTP-rétegen át, és
/// menti őket a `%APPDATA%\Courtboard\cache\images` alá (30 napos élettartam,
/// hiba esetén a lejárt példány is használható).
///
/// A tár Riverpod-szolgáltatás ([imageDiskCacheProvider]); a
/// [CourtboardImage] a legközelebbi `ProviderScope`-ból kéri. Az
/// [ImageDiskCache.shared] a provider alapértéke és híd a `ProviderScope`
/// nélküli helyekre (indítás előtti takarítás, scope nélküli widgetek).
library;

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:courtboard/data/app_paths.dart';
import 'package:courtboard/data/file_util.dart' show fnv1a32Hex;
import 'package:courtboard/data/http_service.dart';
import 'package:courtboard/data/http_util.dart';
import 'package:courtboard/data/url_safety.dart';
import 'package:courtboard/shared/theme/courtboard_theme.dart';

/// A képletöltések szolgáltatóneve a közös HTTP-rétegben.
const imageProviderName = 'Képek';

/// Letöltött képek lemezes tárolója.
class ImageDiskCache {
  ImageDiskCache({
    this._directory,
    this.ttl = const Duration(days: 30),
    this._http,
    DateTime Function()? clock,
    this._loader,
  }) : _clock = clock ?? DateTime.now;

  static ImageDiskCache? _shared;

  /// Az alkalmazás közös példánya: az [imageDiskCacheProvider] alapértéke,
  /// és híd a `ProviderScope`-on kívüli helyekre (például a `main` indítás
  /// előtti takarítása).
  static ImageDiskCache get shared => _shared ??= ImageDiskCache();

  @visibleForTesting
  static set shared(ImageDiskCache? value) => _shared = value;

  final String? _directory;
  final HttpService? _http;
  final DateTime Function() _clock;

  /// Tesztekhez: a teljes betöltés helyettesítése (például soha be nem
  /// fejeződő Future-rel, hogy a widgettesztek ne próbáljanak letölteni).
  final Future<Uint8List> Function(String url)? _loader;

  /// Ennyi ideig friss egy mentett kép; utána újra letöltjük, de hiba esetén
  /// a régi példány marad.
  final Duration ttl;

  final Map<String, Future<Uint8List>> _pending = {};

  String get directory => _directory ?? AppPaths.cacheDirectory('images');
  HttpService get http => _http ?? HttpService.shared;

  /// A kép fájlja: két független hash, hogy ütközés gyakorlatilag ne legyen.
  File fileFor(String url) =>
      File('$directory/${fnv1a32Hex(url)}${fnv1a32Hex('$url#cb')}.img');

  /// A kép bájtjai lemezről vagy hálózatról; az egyidejű kérések osztoznak.
  Future<Uint8List> load(String url) {
    final pending = _pending[url];
    if (pending != null) return pending;
    final future = _loader?.call(url) ?? _load(url);
    _pending[url] = future;
    void cleanup() {
      // A kivett Future hibáját a hívó kezeli; itt csak a nyilvántartás fogy.
      _pending.remove(url)?.ignore();
    }

    unawaited(
      future.then<void>((_) => cleanup(), onError: (Object _) => cleanup()),
    );
    return future;
  }

  Future<Uint8List> _load(String url) async {
    final file = fileFor(url);
    Uint8List? cached;
    DateTime? modified;
    try {
      if (await file.exists()) {
        modified = await file.lastModified();
        cached = await file.readAsBytes();
      }
    } on FileSystemException {
      cached = null;
    }
    if (cached != null &&
        cached.isNotEmpty &&
        modified != null &&
        _clock().difference(modified) < ttl) {
      return cached;
    }
    try {
      final bytes = await http.send(
        imageProviderName,
        () => httpGetBytes(
          http.client,
          Uri.parse(url),
          provider: imageProviderName,
          headers: const {
            // A Wikimedia Commons kéri az azonosítható User-Agentet.
            'User-Agent':
                'Courtboard/0.10 (Windows desktop; github.com/mp3pintyo/Courtboard)',
          },
        ),
      );
      if (bytes.isEmpty) throw const FormatException('üres kép');
      unawaited(_write(file, bytes));
      return bytes;
    } catch (_) {
      // Lejárt, de meglévő példány: offline is látszik a kép.
      if (cached != null && cached.isNotEmpty) return cached;
      rethrow;
    }
  }

  Future<void> _write(File file, Uint8List bytes) async {
    final temp = File(
      '${file.path}.${DateTime.now().microsecondsSinceEpoch}.tmp',
    );
    try {
      await file.parent.create(recursive: true);
      await temp.writeAsBytes(bytes, flush: true);
      await temp.rename(file.path);
    } catch (_) {
      // A mentés hibája csak annyit jelent, hogy legközelebb újra letöltjük.
      try {
        if (await temp.exists()) await temp.delete();
      } catch (_) {
        // Nem kritikus.
      }
    }
  }

  /// A nagyon régi (az élettartam háromszorosánál idősebb) képek törlése.
  Future<void> pruneExpired() async {
    try {
      final dir = Directory(directory);
      if (!await dir.exists()) return;
      final limit = _clock().subtract(ttl * 3);
      await for (final entity in dir.list()) {
        if (entity is! File) continue;
        try {
          if ((await entity.lastModified()).isBefore(limit)) {
            await entity.delete();
          }
        } on FileSystemException {
          // Zárolt fájl: a következő indításkor újra próbáljuk.
        }
      }
    } catch (_) {
      // Csak takarítás.
    }
  }
}

/// A képek lemezes tára. Alapból az [ImageDiskCache.shared]; a
/// `ProviderScope` `overrides` listájával cserélhető (például egy
/// widgettesztben).
final imageDiskCacheProvider = Provider<ImageDiskCache>(
  (ref) => ImageDiskCache.shared,
  name: 'imageDiskCacheProvider',
);

/// A [context] feletti `ProviderScope` képtára; scope nélkül (például egy
/// önálló widgettesztben) az [ImageDiskCache.shared].
ImageDiskCache imageDiskCacheOf(BuildContext context) {
  final ProviderContainer container;
  try {
    container = ProviderScope.containerOf(context, listen: false);
  } on StateError {
    return ImageDiskCache.shared;
  }
  return container.read(imageDiskCacheProvider);
}

/// Lemezes gyorsítótárat használó hálózati kép.
@immutable
class CourtboardNetworkImage extends ImageProvider<CourtboardNetworkImage> {
  const CourtboardNetworkImage(this.url, {this.scale = 1.0, this.cache});

  final String url;
  final double scale;

  /// A képtár; alapból az [ImageDiskCache.shared]. Az [ImageProvider]
  /// nem éri el a Riverpodot, ezért a widget adja át
  /// ([imageDiskCacheOf]).
  final ImageDiskCache? cache;

  @override
  Future<CourtboardNetworkImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<CourtboardNetworkImage>(this);

  @override
  ImageStreamCompleter loadImage(
    CourtboardNetworkImage key,
    ImageDecoderCallback decode,
  ) => MultiFrameImageStreamCompleter(
    codec: _loadCodec(key, decode),
    scale: key.scale,
    debugLabel: key.url,
    informationCollector: () => [
      DiagnosticsProperty<ImageProvider>('Image provider', this),
    ],
  );

  Future<ui.Codec> _loadCodec(
    CourtboardNetworkImage key,
    ImageDecoderCallback decode,
  ) async {
    final bytes = await (key.cache ?? ImageDiskCache.shared).load(key.url);
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    return decode(buffer);
  }

  @override
  bool operator ==(Object other) =>
      other is CourtboardNetworkImage &&
      other.url == url &&
      other.scale == scale;

  @override
  int get hashCode => Object.hash(url, scale);

  @override
  String toString() =>
      '${objectRuntimeType(this, 'CourtboardNetworkImage')}("$url", scale: $scale)';
}

/// Monogram egy névből: „Nikola Jokić” → „NJ”, „Aitana” → „A”.
String initialsOf(String name) {
  final words = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .toList();
  if (words.isEmpty) return '?';
  String first(String word) => String.fromCharCode(word.runes.first);
  final initials = words.length == 1
      ? first(words.first)
      : '${first(words.first)}${first(words.last)}';
  return initials.toUpperCase();
}

/// Egységes képhelyőrző: a sportoló színéből képzett átmenet, opcionálisan
/// monogrammal. Betöltés közben és hibánál is ez látszik.
class InitialsPlaceholder extends StatelessWidget {
  const InitialsPlaceholder({
    super.key,
    required this.name,
    required this.color,
    this.showInitials = true,
  });

  final String name;
  final Color color;
  final bool showInitials;

  @override
  Widget build(BuildContext context) {
    final deep = Color.lerp(color, Colors.black, .38)!;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, deep],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: showInitials
          ? LayoutBuilder(
              builder: (context, constraints) {
                final side = math.min(
                  constraints.maxWidth.isFinite ? constraints.maxWidth : 120,
                  constraints.maxHeight.isFinite ? constraints.maxHeight : 120,
                );
                return Center(
                  child: ExcludeSemantics(
                    child: Text(
                      initialsOf(name),
                      maxLines: 1,
                      textScaler: TextScaler.noScaling,
                      style: TextStyle(
                        fontFamily: courtboardFontFamily,
                        fontSize: math.max(12, side * .36),
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1,
                        color: foregroundOn(color).withValues(alpha: .62),
                      ),
                    ),
                  ),
                );
              },
            )
          : null,
    );
  }
}

/// Hálózati kép lemezes gyorsítótárral, a megjelenített mérethez igazított
/// dekódolással (`cacheWidth` = elrendezési szélesség × képpontsűrűség),
/// beúszással, helyőrzővel és hibakezeléssel. Üres vagy nem http(s) címnél
/// csak a helyőrző jelenik meg.
class CourtboardImage extends StatelessWidget {
  const CourtboardImage({
    super.key,
    required this.url,
    required this.placeholder,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.semanticLabel,
    this.opacity = 1,
  });

  final String url;
  final Widget placeholder;
  final BoxFit fit;
  final AlignmentGeometry alignment;

  /// Képernyőolvasónak szóló leírás (például „Nikola Jokić fotója”);
  /// `null` esetén a kép dekoratív, kimarad a szemantikából.
  final String? semanticLabel;

  /// Átlátszatlanság `Opacity` réteg nélkül (a kép saját festésében).
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final fallback = semanticLabel == null
        ? placeholder
        : Semantics(image: true, label: semanticLabel, child: placeholder);
    if (!isSafeWebUrl(url)) return fallback;
    return LayoutBuilder(
      builder: (context, constraints) {
        final ratio = MediaQuery.devicePixelRatioOf(context);
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 0.0;
        final height = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : 0.0;
        // Kitöltésnél a hosszabb oldal a mérvadó (álló kép széles dobozban).
        final logical = math.max(width, height);
        final cacheWidth = logical <= 0
            ? null
            : (logical * ratio).round().clamp(32, 2400);
        final provider = ResizeImage.resizeIfNeeded(
          cacheWidth,
          null,
          CourtboardNetworkImage(url.trim(), cache: imageDiskCacheOf(context)),
        );
        return Image(
          image: provider,
          fit: fit,
          alignment: alignment,
          width: width > 0 ? width : null,
          height: height > 0 ? height : null,
          gaplessPlayback: true,
          semanticLabel: semanticLabel,
          excludeFromSemantics: semanticLabel == null,
          opacity: opacity < 1 ? AlwaysStoppedAnimation(opacity) : null,
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (wasSynchronouslyLoaded) return child;
            return Stack(
              fit: StackFit.passthrough,
              children: [
                Positioned.fill(child: placeholder),
                AnimatedOpacity(
                  opacity: frame == null ? 0 : 1,
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOut,
                  child: child,
                ),
              ],
            );
          },
          errorBuilder: (context, error, stackTrace) => fallback,
        );
      },
    );
  }
}
