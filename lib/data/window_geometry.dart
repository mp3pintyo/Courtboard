/// Az ablak mentett helyzete és mérete fizikai képpontban (a Windows
/// `WINDOWPLACEMENT` „normál” téglalapja, munkaterület-koordinátákban),
/// valamint a teljes méret állapota.
///
/// Fizikai képpontot mentünk, mert több, eltérő nagyítású monitornál a
/// logikai képpont nem egyértelmű; a visszaállítás ugyanazzal az API-val
/// történik, így a koordináták következetesek.
class WindowGeometry {
  const WindowGeometry({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    this.maximized = false,
  });

  final int left;
  final int top;
  final int width;
  final int height;
  final bool maximized;

  int get right => left + width;
  int get bottom => top + height;

  /// A legkisebb elfogadott mentett méret (100%-os nagyításnál a futtató
  /// `kMinWindowWidth` × `kMinWindowHeight` kerete, lásd
  /// `windows/runner/win32_window.cpp`). Ennél kisebb mentett érték sérült.
  static const minWidth = 816;
  static const minHeight = 639;

  /// Irreálisan nagy (sérült) értékek kiszűrésére.
  static const _maxExtent = 32000;

  WindowGeometry copyWith({
    int? left,
    int? top,
    int? width,
    int? height,
    bool? maximized,
  }) => WindowGeometry(
    left: left ?? this.left,
    top: top ?? this.top,
    width: width ?? this.width,
    height: height ?? this.height,
    maximized: maximized ?? this.maximized,
  );

  Map<String, Object?> toJson() => {
    'left': left,
    'top': top,
    'width': width,
    'height': height,
    'maximized': maximized,
  };

  /// `null`, ha a mentés hiányzik vagy nyilvánvalóan hibás.
  static WindowGeometry? fromJson(Object? json) {
    if (json is! Map) return null;
    final left = json['left'];
    final top = json['top'];
    final width = json['width'];
    final height = json['height'];
    if (left is! int || top is! int || width is! int || height is! int) {
      return null;
    }
    if (width < minWidth ||
        height < minHeight ||
        width > _maxExtent ||
        height > _maxExtent ||
        left.abs() > _maxExtent ||
        top.abs() > _maxExtent) {
      return null;
    }
    return WindowGeometry(
      left: left,
      top: top,
      width: width,
      height: height,
      maximized: json['maximized'] == true,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is WindowGeometry &&
      other.left == left &&
      other.top == top &&
      other.width == width &&
      other.height == height &&
      other.maximized == maximized;

  @override
  int get hashCode => Object.hash(left, top, width, height, maximized);

  @override
  String toString() =>
      'WindowGeometry($left, $top, ${width}x$height'
      '${maximized ? ', maximized' : ''})';
}

/// Egész koordinátás téglalap (fizikai képpont).
class PixelRect {
  const PixelRect(this.left, this.top, this.right, this.bottom);

  final int left;
  final int top;
  final int right;
  final int bottom;

  int get width => right - left;
  int get height => bottom - top;

  @override
  bool operator ==(Object other) =>
      other is PixelRect &&
      other.left == left &&
      other.top == top &&
      other.right == right &&
      other.bottom == bottom;

  @override
  int get hashCode => Object.hash(left, top, right, bottom);

  @override
  String toString() => 'PixelRect($left, $top, $right, $bottom)';
}

/// Az adott téglalapot metsző monitor munkaterülete, vagy `null`, ha a
/// téglalap egyetlen csatlakoztatott monitorra sem esik.
typedef WorkAreaLookup = PixelRect? Function(PixelRect rect);

/// A mentett ablakhelyzet ellenőrzése a jelenleg csatlakoztatott
/// monitorokhoz.
///
/// Az ablak címsorának közepe (egy 40 px magas, oldalt 60 px-lel beljebb
/// kezdődő sáv) legyen valamelyik monitoron, különben a felhasználó nem érné
/// el az ablakot (például leválasztott második monitor). Ilyenkor `null` jön
/// vissza: a futtató alapértelmezett, középre igazított ablaka marad.
///
/// Ha a sáv látszik, az ablakot a monitor munkaterületére igazítjuk: a
/// túl nagy méretet levágjuk, a kilógó ablakot beljebb toljuk.
WindowGeometry? fitWindowGeometry(
  WindowGeometry? saved,
  WorkAreaLookup workAreaFor,
) {
  if (saved == null) return null;
  const inset = 60;
  const titleHeight = 40;
  final stripInset = saved.width > inset * 2 + 40 ? inset : 0;
  final strip = PixelRect(
    saved.left + stripInset,
    saved.top,
    saved.right - stripInset,
    saved.top + titleHeight,
  );
  final work = workAreaFor(strip);
  if (work == null || work.width <= 0 || work.height <= 0) return null;
  final width = saved.width.clamp(1, work.width);
  final height = saved.height.clamp(1, work.height);
  final left = saved.left.clamp(work.left, work.right - width);
  final top = saved.top.clamp(work.top, work.bottom - height);
  return saved.copyWith(left: left, top: top, width: width, height: height);
}
