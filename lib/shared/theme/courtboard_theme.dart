/// A Courtboard vizuális rendszere: szemantikus színtokenek
/// ([CourtboardColors]), kontrasztsegédek, tipográfia és a teljes
/// [ThemeData] a zöld/bordó kiemelőszínhez, világos és sötét módban.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A felhasználó által választható kiemelőszín.
enum CourtboardAccent {
  green,
  burgundy;

  /// A helyi állapotban tárolt érték (`green` / `burgundy`) feloldása;
  /// ismeretlen értéknél a zöld az alapértelmezés.
  static CourtboardAccent fromStorage(String value) =>
      value == 'burgundy' ? CourtboardAccent.burgundy : CourtboardAccent.green;
}

/// A megjelenési mód tárolt értékének (`system` / `light` / `dark`)
/// feloldása; ismeretlen értéknél a rendszerbeállítás érvényes.
ThemeMode themeModeFromStorage(String value) => switch (value) {
  'light' => ThemeMode.light,
  'dark' => ThemeMode.dark,
  _ => ThemeMode.system,
};

// ---------------------------------------------------------------------------
// Kontraszt
// ---------------------------------------------------------------------------

/// WCAG 2.x kontrasztarány két (átlátszatlan) szín között (1–21).
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

/// Az [color] árnyalatát megtartva addig sötétíti vagy világosítja, amíg
/// a [background] háttéren legalább [minRatio] kontrasztot nem ér el.
/// Ha már most megfelel, változatlanul adja vissza.
Color readableOn(Color color, Color background, {double minRatio = 4.5}) {
  final opaque = color.withValues(alpha: 1);
  if (contrastRatio(opaque, background) >= minRatio) return opaque;
  final darken = background.computeLuminance() > 0.35;
  final hsl = HSLColor.fromColor(opaque);
  var lightness = hsl.lightness;
  for (var i = 0; i < 40; i++) {
    lightness = (lightness + (darken ? -0.025 : 0.025)).clamp(0.0, 1.0);
    final candidate = hsl.withLightness(lightness).toColor();
    if (contrastRatio(candidate, background) >= minRatio) return candidate;
  }
  return darken ? Colors.black : Colors.white;
}

/// Fekete-fehér közül az olvashatóbb előtérszín egy kitöltött háttérhez
/// (például a sportoló kiemelőszínével festett címkén).
Color foregroundOn(Color fill, {Color dark = const Color(0xFF151815)}) =>
    contrastRatio(dark, fill) >= contrastRatio(Colors.white, fill)
    ? dark
    : Colors.white;

// ---------------------------------------------------------------------------
// Színtokenek
// ---------------------------------------------------------------------------

/// Szemantikus színtokenek. Minden felület ezekből dolgozik; közvetlen
/// `Color(0x…)` a UI-rétegben csak a sportolók saját azonosító színeinél
/// maradhat.
@immutable
class CourtboardColors extends ThemeExtension<CourtboardColors> {
  const CourtboardColors({
    required this.brightness,
    required this.canvas,
    required this.surface,
    required this.surfaceMuted,
    required this.ink,
    required this.inkRaised,
    required this.onInk,
    required this.onInkMuted,
    required this.textPrimary,
    required this.textMuted,
    required this.border,
    required this.borderStrong,
    required this.accent,
    required this.onAccent,
    required this.accentSoft,
    required this.highlight,
    required this.onHighlight,
    required this.win,
    required this.loss,
    required this.draw,
    required this.warning,
    required this.error,
    required this.live,
  });

  final Brightness brightness;

  /// Az oldalak háttere (meleg bézs / mély szén).
  final Color canvas;

  /// Kártyák, panelek („papír”).
  final Color surface;

  /// Kártyán belüli csempék, sorok háttere.
  final Color surfaceMuted;

  /// Oldalsáv és a sötét „magazin” hero-blokkok.
  final Color ink;

  /// Az [ink] felületen kiemelt doboz.
  final Color inkRaised;
  final Color onInk;
  final Color onInkMuted;

  /// Elsődleges szöveg a [canvas] és [surface] felületen.
  final Color textPrimary;

  /// Másodlagos szöveg; WCAG AA (≥ 4,5:1) a [canvas] és [surface] felületen.
  final Color textMuted;
  final Color border;
  final Color borderStrong;

  /// Kiemelőszín a világos felületeken (gombok, linkek, ikonok).
  final Color accent;
  final Color onAccent;

  /// Halvány kiemelés: kiválasztott chip, címkék háttere.
  final Color accentSoft;

  /// Élénk kiemelés az [ink] felületen (oldalsáv, hero).
  final Color highlight;
  final Color onHighlight;

  /// Eredményszínek szöveghez (≥ 4,5:1 a [surface] felületen).
  final Color win;
  final Color loss;
  final Color draw;
  final Color warning;
  final Color error;
  final Color live;

  bool get isDark => brightness == Brightness.dark;

  /// A [color] olvasható változata szövegnek/ikonnak a [surface] felületen
  /// (például a sportoló saját kiemelőszíne).
  Color readable(Color color, {Color? on}) => readableOn(color, on ?? surface);

  /// Halvány, a felülethez kevert tónus egy szemantikus színből.
  Color tint(Color color, [double amount = .12]) =>
      Color.alphaBlend(color.withValues(alpha: amount), surface);

  // --- Változatok -----------------------------------------------------------

  static const _inkLight = Color(0xFF151815);

  static const lightGreen = CourtboardColors(
    brightness: Brightness.light,
    canvas: Color(0xFFECE9DF),
    surface: Color(0xFFF9F8F3),
    surfaceMuted: Color(0xFFF0EDE4),
    ink: _inkLight,
    inkRaised: Color(0xFF262B24),
    onInk: Color(0xFFFFFFFF),
    onInkMuted: Color(0xFFB5B9AE),
    textPrimary: Color(0xFF191B17),
    textMuted: Color(0xFF585B51),
    border: Color(0xFFD8D4C8),
    borderStrong: Color(0xFFBDB9AC),
    accent: Color(0xFF55672F),
    onAccent: Color(0xFFFFFFFF),
    accentSoft: Color(0xFFE2E8C6),
    highlight: Color(0xFFC5D48B),
    onHighlight: _inkLight,
    win: Color(0xFF2E6B2C),
    loss: Color(0xFFAD3434),
    draw: Color(0xFF7D5A00),
    warning: Color(0xFF8A5200),
    error: Color(0xFFB3261E),
    live: Color(0xFFC62828),
  );

  static const lightBurgundy = CourtboardColors(
    brightness: Brightness.light,
    canvas: Color(0xFFECE9DF),
    surface: Color(0xFFF9F8F3),
    surfaceMuted: Color(0xFFF0EDE4),
    ink: _inkLight,
    inkRaised: Color(0xFF2B2225),
    onInk: Color(0xFFFFFFFF),
    onInkMuted: Color(0xFFBCB4B6),
    textPrimary: Color(0xFF191B17),
    textMuted: Color(0xFF585B51),
    border: Color(0xFFD8D4C8),
    borderStrong: Color(0xFFBDB9AC),
    accent: Color(0xFF7A263A),
    onAccent: Color(0xFFFFFFFF),
    accentSoft: Color(0xFFF0D9DE),
    highlight: Color(0xFFE4B4BD),
    onHighlight: _inkLight,
    win: Color(0xFF2E6B2C),
    loss: Color(0xFFAD3434),
    draw: Color(0xFF7D5A00),
    warning: Color(0xFF8A5200),
    error: Color(0xFFB3261E),
    live: Color(0xFFC62828),
  );

  static const darkGreen = CourtboardColors(
    brightness: Brightness.dark,
    canvas: Color(0xFF121411),
    surface: Color(0xFF1B1E1A),
    surfaceMuted: Color(0xFF242822),
    ink: Color(0xFF0A0C09),
    inkRaised: Color(0xFF1D221B),
    onInk: Color(0xFFF4F3EC),
    onInkMuted: Color(0xFFA9AD9F),
    textPrimary: Color(0xFFECEBE3),
    textMuted: Color(0xFFA7AB9D),
    border: Color(0xFF32372E),
    borderStrong: Color(0xFF4A5044),
    accent: Color(0xFFC5D48B),
    onAccent: Color(0xFF151815),
    accentSoft: Color(0xFF2F3722),
    highlight: Color(0xFFC5D48B),
    onHighlight: Color(0xFF151815),
    win: Color(0xFF8DD08A),
    loss: Color(0xFFF2918A),
    draw: Color(0xFFE3C26A),
    warning: Color(0xFFF0B657),
    error: Color(0xFFF2B8B5),
    live: Color(0xFFFF7A6E),
  );

  static const darkBurgundy = CourtboardColors(
    brightness: Brightness.dark,
    canvas: Color(0xFF141213),
    surface: Color(0xFF1E1B1C),
    surfaceMuted: Color(0xFF282325),
    ink: Color(0xFF0B0A0A),
    inkRaised: Color(0xFF241D1F),
    onInk: Color(0xFFF5F1F2),
    onInkMuted: Color(0xFFB1A8AA),
    textPrimary: Color(0xFFEDE8E9),
    textMuted: Color(0xFFADA4A6),
    border: Color(0xFF3A3234),
    borderStrong: Color(0xFF54494C),
    accent: Color(0xFFE8A9B6),
    onAccent: Color(0xFF2A0E15),
    accentSoft: Color(0xFF40232A),
    highlight: Color(0xFFE4B4BD),
    onHighlight: Color(0xFF2A0E15),
    win: Color(0xFF8DD08A),
    loss: Color(0xFFF2918A),
    draw: Color(0xFFE3C26A),
    warning: Color(0xFFF0B657),
    error: Color(0xFFF2B8B5),
    live: Color(0xFFFF7A6E),
  );

  static CourtboardColors of(CourtboardAccent accent, Brightness brightness) =>
      switch ((accent, brightness)) {
        (CourtboardAccent.green, Brightness.light) => lightGreen,
        (CourtboardAccent.burgundy, Brightness.light) => lightBurgundy,
        (CourtboardAccent.green, Brightness.dark) => darkGreen,
        (CourtboardAccent.burgundy, Brightness.dark) => darkBurgundy,
      };

  /// Mind a négy változat (tesztekhez és dokumentációhoz).
  static const all = [lightGreen, lightBurgundy, darkGreen, darkBurgundy];

  @override
  CourtboardColors copyWith({Color? accent, Color? onAccent}) =>
      CourtboardColors(
        brightness: brightness,
        canvas: canvas,
        surface: surface,
        surfaceMuted: surfaceMuted,
        ink: ink,
        inkRaised: inkRaised,
        onInk: onInk,
        onInkMuted: onInkMuted,
        textPrimary: textPrimary,
        textMuted: textMuted,
        border: border,
        borderStrong: borderStrong,
        accent: accent ?? this.accent,
        onAccent: onAccent ?? this.onAccent,
        accentSoft: accentSoft,
        highlight: highlight,
        onHighlight: onHighlight,
        win: win,
        loss: loss,
        draw: draw,
        warning: warning,
        error: error,
        live: live,
      );

  @override
  CourtboardColors lerp(covariant CourtboardColors? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return CourtboardColors(
      brightness: t < .5 ? brightness : other.brightness,
      canvas: l(canvas, other.canvas),
      surface: l(surface, other.surface),
      surfaceMuted: l(surfaceMuted, other.surfaceMuted),
      ink: l(ink, other.ink),
      inkRaised: l(inkRaised, other.inkRaised),
      onInk: l(onInk, other.onInk),
      onInkMuted: l(onInkMuted, other.onInkMuted),
      textPrimary: l(textPrimary, other.textPrimary),
      textMuted: l(textMuted, other.textMuted),
      border: l(border, other.border),
      borderStrong: l(borderStrong, other.borderStrong),
      accent: l(accent, other.accent),
      onAccent: l(onAccent, other.onAccent),
      accentSoft: l(accentSoft, other.accentSoft),
      highlight: l(highlight, other.highlight),
      onHighlight: l(onHighlight, other.onHighlight),
      win: l(win, other.win),
      loss: l(loss, other.loss),
      draw: l(draw, other.draw),
      warning: l(warning, other.warning),
      error: l(error, other.error),
      live: l(live, other.live),
    );
  }
}

/// Rövid hozzáférés a tokenekhez és a tipográfiához: `context.cb.surface`,
/// `context.text.titleLarge`.
extension CourtboardThemeContext on BuildContext {
  /// A témához tartozó tokenek; téma nélküli környezetben (például egy
  /// csupasz `MaterialApp`-os widgettesztben) a fényerőhöz illő zöld változat.
  CourtboardColors get cb {
    final theme = Theme.of(this);
    return theme.extension<CourtboardColors>() ??
        CourtboardColors.of(CourtboardAccent.green, theme.brightness);
  }

  TextTheme get text => Theme.of(this).textTheme;
}

// ---------------------------------------------------------------------------
// Tipográfia
// ---------------------------------------------------------------------------

const courtboardFontFamily = 'Segoe UI';

/// A Courtboard típusskálája. A címsorok a Segoe UI Black súlyát (w900)
/// használják szűkített betűközzel („sportmagazin”), a címkék legalább
/// 11,5–12 px-esek.
TextTheme courtboardTextTheme(CourtboardColors c) {
  TextStyle s(
    double size,
    FontWeight weight, {
    double spacing = 0,
    double? height,
    Color? color,
  }) => TextStyle(
    fontFamily: courtboardFontFamily,
    fontSize: size,
    fontWeight: weight,
    letterSpacing: spacing,
    height: height,
    color: color ?? c.textPrimary,
  );

  return TextTheme(
    displayLarge: s(42, FontWeight.w900, spacing: -2, height: 1.05),
    displayMedium: s(38, FontWeight.w900, spacing: -1.8, height: 1.05),
    displaySmall: s(34, FontWeight.w900, spacing: -1.4, height: 1.1),
    headlineLarge: s(30, FontWeight.w900, spacing: -1.2, height: 1.1),
    headlineMedium: s(27, FontWeight.w900, spacing: -1, height: 1.15),
    headlineSmall: s(24, FontWeight.w900, spacing: -.8, height: 1.2),
    titleLarge: s(20, FontWeight.w900, spacing: -.3, height: 1.25),
    titleMedium: s(16, FontWeight.w800, height: 1.3),
    titleSmall: s(14, FontWeight.w800, height: 1.3),
    bodyLarge: s(15, FontWeight.w400, height: 1.45),
    bodyMedium: s(14, FontWeight.w400, height: 1.4),
    bodySmall: s(12.5, FontWeight.w400, height: 1.4, color: c.textMuted),
    labelLarge: s(14, FontWeight.w700),
    labelMedium: s(12, FontWeight.w800, spacing: .7, color: c.textMuted),
    labelSmall: s(11.5, FontWeight.w800, spacing: .6),
  );
}

// ---------------------------------------------------------------------------
// ThemeData
// ---------------------------------------------------------------------------

ThemeData buildCourtboardTheme(CourtboardAccent accent, Brightness brightness) {
  final c = CourtboardColors.of(accent, brightness);
  final text = courtboardTextTheme(c);
  final scheme =
      ColorScheme.fromSeed(
        seedColor: c.accent,
        brightness: brightness,
      ).copyWith(
        primary: c.accent,
        onPrimary: c.onAccent,
        primaryContainer: c.accentSoft,
        onPrimaryContainer: c.textPrimary,
        secondary: c.highlight,
        onSecondary: c.onHighlight,
        secondaryContainer: c.accentSoft,
        onSecondaryContainer: c.textPrimary,
        surface: c.surface,
        onSurface: c.textPrimary,
        onSurfaceVariant: c.textMuted,
        surfaceContainerLowest: c.surface,
        surfaceContainerLow: c.surface,
        surfaceContainer: c.surface,
        surfaceContainerHigh: c.surface,
        surfaceContainerHighest: c.surfaceMuted,
        outline: c.borderStrong,
        outlineVariant: c.border,
        error: c.error,
        onError: c.isDark ? const Color(0xFF3B0A08) : Colors.white,
        inverseSurface: c.ink,
        onInverseSurface: c.onInk,
      );
  final radius14 = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(14),
  );
  // Billentyűzetes fókusznál minden gomb és chip 2 px-es kiemelő keretet kap
  // (a Flutter a fókuszállapotot csak billentyűzetes bejárásnál állítja be).
  WidgetStateProperty<BorderSide?> focusSide(Color color, [BorderSide? rest]) =>
      WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.focused)
            ? BorderSide(
                color: color,
                width: 2,
                strokeAlign: BorderSide.strokeAlignOutside,
              )
            : rest,
      );
  OutlineInputBorder inputBorder(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: color, width: width),
      );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    fontFamily: courtboardFontFamily,
    colorScheme: scheme,
    scaffoldBackgroundColor: c.canvas,
    canvasColor: c.surface,
    focusColor: c.accent.withValues(alpha: c.isDark ? .22 : .14),
    hoverColor: c.textPrimary.withValues(alpha: .06),
    textTheme: text,
    iconTheme: IconThemeData(color: c.textPrimary),
    dividerTheme: DividerThemeData(color: c.border, space: 1, thickness: 1),
    extensions: [c],
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: c.accent,
        foregroundColor: c.onAccent,
        disabledBackgroundColor: c.surfaceMuted,
        disabledForegroundColor: c.textMuted,
        textStyle: text.labelLarge,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: radius14,
      ).copyWith(side: focusSide(c.textPrimary)),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: c.textPrimary,
        textStyle: text.labelLarge,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: radius14,
      ).copyWith(side: focusSide(c.accent, BorderSide(color: c.borderStrong))),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: c.accent,
        textStyle: text.labelLarge,
        shape: radius14,
      ).copyWith(side: focusSide(c.accent)),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: c.textPrimary,
      ).copyWith(side: focusSide(c.accent)),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: c.surface,
      selectedColor: c.accentSoft,
      disabledColor: c.surfaceMuted,
      checkmarkColor: c.textPrimary,
      side: WidgetStateBorderSide.resolveWith(
        (states) => states.contains(WidgetState.focused)
            ? BorderSide(color: c.accent, width: 2)
            : BorderSide(color: c.border),
      ),
      labelStyle: text.labelLarge?.copyWith(
        color: c.textPrimary,
        fontWeight: FontWeight.w700,
      ),
      secondaryLabelStyle: text.labelLarge,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        textStyle: WidgetStatePropertyAll(text.labelLarge),
        side: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.focused)
              ? BorderSide(color: c.accent, width: 2)
              : BorderSide(color: c.borderStrong),
        ),
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? c.accentSoft : c.surface,
        ),
        foregroundColor: WidgetStatePropertyAll(c.textPrimary),
        iconColor: WidgetStatePropertyAll(c.textPrimary),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.surface,
      labelStyle: text.bodyMedium?.copyWith(color: c.textMuted),
      floatingLabelStyle: text.bodyMedium?.copyWith(color: c.accent),
      hintStyle: text.bodyMedium?.copyWith(color: c.textMuted),
      prefixIconColor: c.textMuted,
      suffixIconColor: c.textMuted,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: inputBorder(c.border),
      enabledBorder: inputBorder(c.border),
      focusedBorder: inputBorder(c.accent, 1.6),
      errorBorder: inputBorder(c.error),
      focusedErrorBorder: inputBorder(c.error, 1.6),
    ),
    dropdownMenuTheme: DropdownMenuThemeData(
      menuStyle: MenuStyle(backgroundColor: WidgetStatePropertyAll(c.surface)),
    ),
    popupMenuTheme: PopupMenuThemeData(color: c.surface),
    dialogTheme: DialogThemeData(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titleTextStyle: text.titleLarge,
      contentTextStyle: text.bodyMedium,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: c.isDark ? c.surfaceMuted : c.ink,
      contentTextStyle: text.bodyMedium?.copyWith(
        color: c.isDark ? c.textPrimary : c.onInk,
      ),
      actionTextColor: c.highlight,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: c.isDark ? c.surfaceMuted : c.ink,
        borderRadius: BorderRadius.circular(8),
        border: c.isDark ? Border.all(color: c.borderStrong) : null,
      ),
      textStyle: text.bodySmall?.copyWith(
        color: c.isDark ? c.textPrimary : c.onInk,
      ),
    ),
    listTileTheme: ListTileThemeData(
      textColor: c.textPrimary,
      iconColor: c.textMuted,
      subtitleTextStyle: text.bodySmall,
    ),
    expansionTileTheme: ExpansionTileThemeData(
      iconColor: c.textMuted,
      collapsedIconColor: c.textMuted,
      textColor: c.textPrimary,
      collapsedTextColor: c.textPrimary,
      shape: const Border(),
      collapsedShape: const Border(),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: c.accent),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? c.onAccent : c.textMuted,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? c.accent : c.surfaceMuted,
      ),
    ),
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStatePropertyAll(c.borderStrong),
    ),
  );
}
