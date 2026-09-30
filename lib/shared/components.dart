/// Közös, témázott építőelemek: adatforrás-kártya, metrikacsempe,
/// szakaszfejléc, mérkőzéssor, szolgáltató-chip és állapotcímke.
///
/// Minden elem a [CourtboardColors] tokenekből és a témabeli
/// [TextTheme]-ből dolgozik, így világos és sötét módban, zöld és bordó
/// kiemeléssel is egységes.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:courtboard/domain/player_contribution.dart';
import 'package:courtboard/shared/common_ui.dart';
import 'package:courtboard/shared/format.dart';
import 'package:courtboard/shared/theme/courtboard_theme.dart';

export 'package:courtboard/shared/charts.dart';

// ---------------------------------------------------------------------------
// Fejlécek
// ---------------------------------------------------------------------------

/// Oldalcím (a menüpontok oldalain egységesen): nagy címsor, alcím és
/// jobb oldali műveletek.
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.actions = const [],
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget> actions;

  /// Ennél keskenyebb helyen a műveletek a cím alá, sortöréssel kerülnek.
  static const narrowBreakpoint = 720.0;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final titleBlock = Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 16)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.displaySmall,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    subtitle!,
                    style: context.text.bodyMedium?.copyWith(
                      color: context.cb.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      );
      if (actions.isEmpty) return titleBlock;
      if (constraints.maxWidth < narrowBreakpoint) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            titleBlock,
            const SizedBox(height: 14),
            Wrap(spacing: 10, runSpacing: 10, children: actions),
          ],
        );
      }
      return Row(
        children: [
          Expanded(child: titleBlock),
          for (final action in actions) ...[const SizedBox(width: 10), action],
        ],
      );
    },
  );
}

/// Szakaszcím egy oldalon belül (például „Élő adatok”, „Videók”).
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(title, style: context.text.headlineSmall),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: context.text.bodyMedium?.copyWith(
              color: context.cb.textMuted,
            ),
          ),
        ],
      ],
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: trailing == null
          ? SizedBox(width: double.infinity, child: heading)
          : LayoutBuilder(
              // Keskeny helyen a művelet a cím alá kerül (nincs túlcsordulás).
              builder: (context, constraints) => constraints.maxWidth < 560
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        heading,
                        const SizedBox(height: 10),
                        trailing!,
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(child: heading),
                        const SizedBox(width: 12),
                        trailing!,
                      ],
                    ),
            ),
    );
  }
}

/// Kis, nagybetűs alszakasz-címke kártyákon belül
/// (például „LEGUTÓBBI MECCSEK”).
class SubsectionLabel extends StatelessWidget {
  const SubsectionLabel(this.text, {super.key, this.icon, this.color});

  final String text;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final style = context.text.labelMedium?.copyWith(
      color: context.cb.textPrimary,
      fontWeight: FontWeight.w900,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 18,
              color: context.cb.readable(color ?? context.cb.accent),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(child: Text(text, style: style)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Címkék és chipek
// ---------------------------------------------------------------------------

enum StatusTone { neutral, accent, success, warning, error, live }

/// Lekerekített állapotcímke. Tónus szerint a szemantikus tokenekből
/// színeződik, vagy egyedi kitöltéssel ([StatusPill.filled]) — ilyenkor az
/// előtérszín automatikusan olvasható.
class StatusPill extends StatelessWidget {
  const StatusPill(
    this.text, {
    super.key,
    this.tone = StatusTone.neutral,
    this.icon,
  }) : fill = null;

  /// Egyedi kitöltés (például a sportoló saját színe fotó felett).
  const StatusPill.filled(
    this.text, {
    super.key,
    required Color color,
    this.icon,
  }) : fill = color,
       tone = StatusTone.neutral;

  final String text;
  final StatusTone tone;
  final IconData? icon;
  final Color? fill;

  @override
  Widget build(BuildContext context) {
    final cb = context.cb;
    final (Color background, Color foreground) = switch (fill) {
      final Color color => (color, foregroundOn(color)),
      null => switch (tone) {
        StatusTone.neutral => (cb.surfaceMuted, cb.textPrimary),
        StatusTone.accent => (cb.accentSoft, cb.textPrimary),
        StatusTone.success => (cb.tint(cb.win, .16), cb.win),
        StatusTone.warning => (cb.tint(cb.warning, .16), cb.warning),
        StatusTone.error => (cb.tint(cb.error, .14), cb.error),
        StatusTone.live => (cb.tint(cb.live, .14), cb.live),
      },
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
        border: fill == null && tone == StatusTone.neutral
            ? Border.all(color: cb.border)
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: foreground),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.labelSmall?.copyWith(color: foreground),
            ),
          ),
        ],
      ),
    );
  }
}

enum ProviderStatus { ready, failed, missingKey }

/// Egy adatforrás állapota: adatot adott, hibázott, vagy nincs kulcs.
/// A részletes üzenet eszköztippben jelenik meg.
class ProviderChip extends StatelessWidget {
  const ProviderChip({
    super.key,
    required this.name,
    required this.status,
    this.message,
  });

  /// A régi `ready` / `configured` párosból.
  factory ProviderChip.fromFlags({
    Key? key,
    required String name,
    required bool ready,
    bool configured = true,
    String? message,
  }) => ProviderChip(
    key: key,
    name: name,
    message: message,
    status: ready
        ? ProviderStatus.ready
        : configured
        ? ProviderStatus.failed
        : ProviderStatus.missingKey,
  );

  final String name;
  final ProviderStatus status;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final cb = context.cb;
    final (IconData icon, Color color, String fallback) = switch (status) {
      ProviderStatus.ready => (Icons.check_circle, cb.win, 'Adat érkezett'),
      ProviderStatus.failed => (
        Icons.error_outline,
        cb.error,
        'Nem érkezett adat',
      ),
      ProviderStatus.missingKey => (
        Icons.key_off,
        cb.warning,
        'Nincs beállított kulcs',
      ),
    };
    return Tooltip(
      message: message ?? fallback,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
        decoration: BoxDecoration(
          color: cb.tint(color, .10),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cb.tint(color, .45)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              name,
              style: context.text.labelLarge?.copyWith(
                fontSize: 13,
                color: cb.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Metrikák
// ---------------------------------------------------------------------------

/// Egyetlen mérőszám: címke felül, érték alatta, opcionális forrás/megjegyzés.
/// Minden sportágban ugyanazzal a mérettel és ritmussal.
class MetricTile extends StatelessWidget {
  const MetricTile({
    super.key,
    required this.label,
    required this.value,
    this.caption,
    this.captionColor,
    this.highlighted = false,
  });

  final String label;
  final String value;
  final String? caption;
  final Color? captionColor;

  /// Kiemelt csempe (például az összehasonlításban a jobb érték): `win`
  /// színű keret és jelölés; a képernyőolvasó „jobb érték”-et mond.
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final cb = context.cb;
    final hasCaption = caption != null && caption!.isNotEmpty;
    final base = hasCaption ? '$label: $value ($caption)' : '$label: $value';
    // Képernyőolvasónak egyetlen mondat: „Pont / meccs: 26,8 (forrás)”.
    return Semantics(
      container: true,
      label: highlighted ? '$base, jobb érték' : base,
      excludeSemantics: true,
      child: _tile(context, cb),
    );
  }

  Widget _tile(BuildContext context, CourtboardColors cb) {
    return Container(
      constraints: const BoxConstraints(minHeight: 96),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: highlighted ? cb.tint(cb.win, .10) : cb.surfaceMuted,
        borderRadius: BorderRadius.circular(14),
        border: highlighted
            ? Border.all(color: cb.tint(cb.win, .7), width: 1.5)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.labelMedium,
                ),
              ),
              if (highlighted) ...[
                const SizedBox(width: 6),
                Icon(Icons.arrow_upward_rounded, size: 16, color: cb.win),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.text.titleLarge?.copyWith(
              fontSize: 22,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (caption != null && caption!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              caption!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.labelSmall?.copyWith(
                color: cb.readable(captionColor ?? cb.textMuted),
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Metrikacsempék egyenletes rácsban: az oszlopszám a szélességből adódik
/// (legalább [minTileWidth] széles csempék, legfeljebb [maxColumns]).
class MetricGrid extends StatelessWidget {
  const MetricGrid({
    super.key,
    required this.children,
    this.minTileWidth = 150,
    this.maxColumns = 8,
    this.spacing = 10,
  });

  final List<Widget> children;
  final double minTileWidth;
  final int maxColumns;
  final double spacing;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth.isFinite ? constraints.maxWidth : 900;
      final fit = ((width + spacing) / (minTileWidth + spacing)).floor();
      // Kevés csempénél sem nyúlnak szét: az oszlopszám a szélességből jön.
      final columns = fit.clamp(1, maxColumns);
      final tile = (width - spacing * (columns - 1)) / columns;
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: [
          for (final child in children) SizedBox(width: tile, child: child),
        ],
      );
    },
  );
}

/// Szezonösszesítő tartalom (csapat, bajnokság/idény, forrás és a
/// mérőszámok) — az NBA, a WNBA és a foci ugyanezt használja.
class SeasonSummaryPanel extends StatelessWidget {
  const SeasonSummaryPanel({
    super.key,
    required this.title,
    required this.subtitle,
    required this.metrics,
    this.source,
    this.accent,
  });

  final String title;
  final String subtitle;
  final String? source;
  final List<(String, String)> metrics;
  final Color? accent;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.text.titleLarge),
                const SizedBox(height: 2),
                Text(subtitle, style: context.text.bodySmall),
              ],
            ),
          ),
          if (source != null && source!.isNotEmpty)
            StatusPill(source!.toUpperCase(), tone: StatusTone.accent),
        ],
      ),
      const SizedBox(height: 14),
      MetricGrid(
        minTileWidth: 132,
        children: [
          for (final (label, value) in metrics)
            MetricTile(label: label, value: value),
        ],
      ),
    ],
  );
}

// ---------------------------------------------------------------------------
// Mérkőzések
// ---------------------------------------------------------------------------

enum MatchOutcome {
  win('GY', 'Győzelem'),
  loss('V', 'Vereség'),
  draw('D', 'Döntetlen'),
  upcoming('KÖV', 'Következő mérkőzés'),
  unknown('', '');

  const MatchOutcome(this.letter, this.label);
  final String letter;
  final String label;

  /// Szolgáltatói szövegből („WIN”, „GYŐZELEM”, „L”…).
  static MatchOutcome parse(String value) =>
      switch (value.trim().toUpperCase()) {
        'WIN' || 'W' || 'GYŐZELEM' || 'GY' => MatchOutcome.win,
        'LOSS' || 'L' || 'VERESÉG' || 'V' => MatchOutcome.loss,
        'DRAW' || 'D' || 'DÖNTETLEN' => MatchOutcome.draw,
        _ => MatchOutcome.unknown,
      };
}

/// Egységes nagykötőjel az eredményekben („104-72” → „104–72”).
String normalizeScore(String score) => score.replaceAllMapped(
  RegExp(r'(\d)\s*-\s*(\d)'),
  (m) => '${m[1]}–${m[2]}',
);

/// Eredményjelvény (GY / V / D) a win/loss/draw tokenekkel. A [score]
/// csak a képernyőolvasó szövegébe kerül („Győzelem 104–72”).
class ResultBadge extends StatelessWidget {
  const ResultBadge(this.outcome, {super.key, this.score});
  final MatchOutcome outcome;
  final String? score;

  @override
  Widget build(BuildContext context) {
    final cb = context.cb;
    final color = switch (outcome) {
      MatchOutcome.win => cb.win,
      MatchOutcome.loss => cb.loss,
      MatchOutcome.draw => cb.draw,
      _ => cb.textMuted,
    };
    final result = score == null || score!.isEmpty
        ? outcome.label
        : '${outcome.label} ${normalizeScore(score!)}';
    return Semantics(
      label: result,
      excludeSemantics: true,
      child: _badge(context, color),
    );
  }

  Widget _badge(BuildContext context, Color color) {
    final cb = context.cb;
    return Tooltip(
      message: outcome.label,
      child: Container(
        constraints: const BoxConstraints(minWidth: 34),
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: cb.tint(color, .14),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: cb.tint(color, .35)),
        ),
        child: Text(
          outcome.letter,
          style: context.text.labelSmall?.copyWith(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

/// A sportoló saját pontszerzése egy meccssorban: kiemelt címke
/// sportág-ikonnal („2 gól · 1 gólpassz”, „24 pont”, „2 TD · 12 pont”) és
/// halvány megjegyzés („3 passzolt TD”). Semmit sem rajzol, ha nincs mit
/// mutatni; a képernyőolvasó egyetlen mondatot hall.
class PlayerContributionBadge extends StatelessWidget {
  const PlayerContributionBadge(this.contribution, {super.key});

  final PlayerContribution contribution;

  static IconData iconOf(ContributionKind kind) => switch (kind) {
    ContributionKind.football => Icons.sports_soccer,
    ContributionKind.basketball => Icons.sports_basketball,
    ContributionKind.nfl => Icons.sports_football,
  };

  @override
  Widget build(BuildContext context) {
    if (!contribution.isVisible) return const SizedBox.shrink();
    final cb = context.cb;
    final badge = contribution.badgeText;
    final note = contribution.note;
    return Semantics(
      container: true,
      label: contribution.semanticsLabel,
      excludeSemantics: true,
      child: Wrap(
        key: const Key('player-contribution'),
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (badge != null)
            Container(
              padding: const EdgeInsets.fromLTRB(7, 3, 9, 3),
              decoration: BoxDecoration(
                color: cb.accentSoft,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: cb.tint(cb.accent, .45)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    iconOf(contribution.kind),
                    size: 14,
                    color: cb.readable(cb.accent, on: cb.accentSoft),
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      badge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.labelSmall?.copyWith(
                        color: cb.textPrimary,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (note != null)
            Text(
              note,
              style: context.text.labelSmall?.copyWith(
                color: cb.textMuted,
                letterSpacing: 0,
              ),
            ),
        ],
      ),
    );
  }
}

/// Egységes mérkőzéssor minden sportághoz: dátum (és hazai/idegen),
/// ellenfél, részletsor, a sportoló saját pontszerzése, eredmény és GY/V/D
/// jelvény.
class MatchRow extends StatelessWidget {
  const MatchRow({
    super.key,
    required this.opponent,
    this.date,
    this.dateLabel,
    this.venue,
    this.subtitle,
    this.score,
    this.outcome = MatchOutcome.unknown,
    this.grade,
    this.live = false,
    this.footer,
    this.contribution,
  });

  final String opponent;
  final DateTime? date;

  /// A sor alatti kiegészítés (például lenyitható „Idővonal”).
  final Widget? footer;

  /// A dátum helyett megjelenő szöveg (például „Időpont később”).
  final String? dateLabel;

  /// Hazai / idegen (vagy más rövid helyszínjelzés) a dátum alatt.
  final String? venue;
  final String? subtitle;
  final String? score;
  final MatchOutcome outcome;

  /// Teljesítményjegy (A+, B…), ha a forrás ad hozzá alapot.
  final String? grade;
  final bool live;

  /// A sportoló saját pontszerzése ezen a meccsen (gól/gólpassz, pont,
  /// touchdown); csak akkor látszik, ha van mit mutatni (> 0).
  final PlayerContribution? contribution;

  @override
  Widget build(BuildContext context) {
    final cb = context.cb;
    // Egységes dátum: idén „ápr. 12.”, más évben „2025. ápr. 12.”.
    final when = dateLabel ?? (date == null ? '—' : formatMatchDate(date!));
    // A dátumoszlop a szövegmérettel együtt nő, így nagyításnál sem vág.
    final dateColumn = MediaQuery.textScalerOf(context).scale(78);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: live ? cb.tint(cb.live, .08) : cb.surfaceMuted,
        borderRadius: BorderRadius.circular(14),
        border: live ? Border.all(color: cb.tint(cb.live, .4)) : null,
      ),
      child: footer == null
          ? _row(context, when, dateColumn)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [_row(context, when, dateColumn), footer!],
            ),
    );
  }

  Widget _row(BuildContext context, String when, double dateColumn) {
    final cb = context.cb;
    return Row(
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(minWidth: dateColumn),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (live) ...[
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: cb.live,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    live ? 'ÉLŐ' : when,
                    style: context.text.titleSmall?.copyWith(
                      color: live ? cb.live : cb.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              if (venue != null && venue!.isNotEmpty)
                Text(
                  venue!.toUpperCase(),
                  style: context.text.labelSmall?.copyWith(color: cb.textMuted),
                ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                opponent,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.titleMedium,
              ),
              if (subtitle != null && subtitle!.isNotEmpty)
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodySmall,
                ),
              if (contribution case final shown? when shown.isVisible) ...[
                const SizedBox(height: 6),
                PlayerContributionBadge(shown),
              ],
            ],
          ),
        ),
        if (score != null && score!.isNotEmpty) ...[
          const SizedBox(width: 12),
          Text(
            normalizeScore(score!),
            textAlign: TextAlign.right,
            style: context.text.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
        if (outcome != MatchOutcome.unknown) ...[
          const SizedBox(width: 12),
          ResultBadge(outcome, score: score),
        ],
        if (grade != null && grade!.isNotEmpty && grade != '—') ...[
          const SizedBox(width: 8),
          Tooltip(
            message: 'Teljesítményjegy',
            child: Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: cb.surface,
                shape: BoxShape.circle,
                border: Border.all(color: cb.borderStrong),
              ),
              child: Text(
                grade!,
                style: context.text.labelSmall?.copyWith(fontSize: 12),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Állapotok
// ---------------------------------------------------------------------------

/// Üres állapot ikonnal és magyar szöveggel; [compact] esetén kártyán belül.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.message,
    this.title,
    this.icon = Icons.inbox_outlined,
    this.action,
    this.compact = false,
  });

  final String? title;
  final String message;
  final IconData icon;
  final Widget? action;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final cb = context.cb;
    if (compact) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(icon, size: 20, color: cb.textMuted),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: context.text.bodyMedium?.copyWith(color: cb.textMuted),
              ),
            ),
            ?action,
          ],
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 46, color: cb.textMuted),
        const SizedBox(height: 12),
        if (title != null) ...[
          Text(
            title!,
            textAlign: TextAlign.center,
            style: context.text.titleLarge,
          ),
          const SizedBox(height: 6),
        ],
        Text(
          message,
          textAlign: TextAlign.center,
          style: context.text.bodyMedium?.copyWith(color: cb.textMuted),
        ),
        if (action != null) ...[const SizedBox(height: 18), action!],
      ],
    );
  }
}

/// Egyszerű, pulzáló helyőrző doboz betöltés közben.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({super.key, this.width, this.height = 14, this.radius = 7});

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: context.cb.surfaceMuted,
      borderRadius: BorderRadius.circular(radius),
    ),
  );
}

/// Kártyán belüli betöltési helyőrző: felirat, néhány sor és csempe.
class CardSkeleton extends StatefulWidget {
  const CardSkeleton({super.key, this.label = 'Adatok betöltése…'});
  final String label;

  @override
  State<CardSkeleton> createState() => _CardSkeletonState();
}

class _CardSkeletonState extends State<CardSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: widget.label,
    liveRegion: true,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: context.text.bodySmall),
        const SizedBox(height: 12),
        FadeTransition(
          opacity: Tween<double>(begin: .45, end: 1).animate(_pulse),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  for (var i = 0; i < 4; i++) ...[
                    if (i > 0) const SizedBox(width: 10),
                    const Expanded(child: SkeletonBox(height: 64, radius: 14)),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              const FractionallySizedBox(widthFactor: .7, child: SkeletonBox()),
              const SizedBox(height: 8),
              const FractionallySizedBox(
                widthFactor: .45,
                child: SkeletonBox(),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

// ---------------------------------------------------------------------------
// Kártyák
// ---------------------------------------------------------------------------

/// Egységes felület („papír”) kártyákhoz: lekerekítés, keret, belső térköz.
class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.accent,
    this.padding = const EdgeInsets.all(20),
  });

  final Widget child;

  /// A keret színe (például a sportoló kiemelőszíne); alapból a [border].
  final Color? accent;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final cb = context.cb;
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: cb.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: accent == null
              ? cb.border
              : Color.alphaBlend(accent!.withValues(alpha: .55), cb.surface),
        ),
      ),
      child: child,
    );
  }
}

/// Egy adat frissességi adatai a kártyafejléchez.
class DataFreshness {
  const DataFreshness(
    this.fetchedAt, {
    this.fromCache = false,
    this.stale = false,
  });
  final DateTime fetchedAt;
  final bool fromCache;
  final bool stale;
}

/// Adatbetöltő: `force` igaz, ha a felhasználó kifejezetten frissít.
typedef DataLoader<T> = Future<T> Function({required bool force});

/// Élő adatforrás kártyája egy [Future]-t adó betöltővel: a betöltést maga
/// indítja (és a [reloadKey] változásakor újraindítja). A megjelenítés az
/// [AsyncDataSourceCard]-é, így a provideres (AsyncValue-t adó) kártyák
/// ugyanúgy néznek ki.
class DataSourceCard<T> extends StatefulWidget {
  const DataSourceCard({
    super.key,
    required this.title,
    required this.load,
    required this.builder,
    this.subtitle,
    this.provider,
    this.icon,
    this.accent,
    this.reloadKey,
    this.isEmpty,
    this.emptyMessage = 'Nincs megjeleníthető adat.',
    this.emptyIcon = Icons.inbox_outlined,
    this.emptyFooter,
    this.freshness,
    this.loadingLabel = 'Adatok betöltése…',
    this.errorPrefix = '',
    this.headerTrailing,
    this.placeholder,
    this.refreshTooltip = 'Adatok frissítése',
  });

  final String title;
  final String? subtitle;

  /// A szolgáltató neve a fejléc címkéjén.
  final String? provider;
  final IconData? icon;

  /// A sportoló kiemelőszíne (keret, ikon); alapból a téma kiemelőszíne.
  final Color? accent;
  final DataLoader<T> load;
  final Widget Function(BuildContext context, T data) builder;

  /// Ha változik (például más sportoló vagy új API-kulcs), újratöltés.
  final Object? reloadKey;
  final bool Function(T data)? isEmpty;
  final String emptyMessage;
  final IconData emptyIcon;

  /// Üres állapot alatti kiegészítés (például figyelmeztetések).
  final Widget Function(BuildContext context, T data)? emptyFooter;
  final DataFreshness? Function(T data)? freshness;
  final String loadingLabel;

  /// A felhasználóbarát hibaüzenet elé kerülő mondat.
  final String errorPrefix;
  final Widget? headerTrailing;

  /// Ha nem `null`, betöltés helyett ez jelenik meg (például hiányzó kulcs).
  final Widget? placeholder;
  final String refreshTooltip;

  @override
  State<DataSourceCard<T>> createState() => _DataSourceCardState<T>();
}

class _DataSourceCardState<T> extends State<DataSourceCard<T>> {
  Future<T>? _future;

  @override
  void initState() {
    super.initState();
    _start(force: false);
  }

  void _start({required bool force}) {
    _future = widget.placeholder == null ? widget.load(force: force) : null;
  }

  void _refresh() => setState(() => _start(force: true));

  @override
  void didUpdateWidget(covariant DataSourceCard<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reloadKey != widget.reloadKey ||
        (oldWidget.placeholder == null) != (widget.placeholder == null)) {
      _start(force: false);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
    future: _future,
    builder: (context, snapshot) => AsyncDataSourceCard<T>(
      title: widget.title,
      value: _valueOf(snapshot),
      onRefresh: _refresh,
      builder: widget.builder,
      subtitle: widget.subtitle,
      provider: widget.provider,
      icon: widget.icon,
      accent: widget.accent,
      isEmpty: widget.isEmpty,
      emptyMessage: widget.emptyMessage,
      emptyIcon: widget.emptyIcon,
      emptyFooter: widget.emptyFooter,
      freshness: widget.freshness,
      loadingLabel: widget.loadingLabel,
      errorPrefix: widget.errorPrefix,
      headerTrailing: widget.headerTrailing,
      placeholder: widget.placeholder,
      refreshTooltip: widget.refreshTooltip,
    ),
  );

  AsyncValue<T> _valueOf(AsyncSnapshot<T> snapshot) {
    final done =
        _future != null && snapshot.connectionState == ConnectionState.done;
    if (!done) return AsyncLoading<T>();
    if (snapshot.hasError) {
      return AsyncError<T>(
        snapshot.error!,
        snapshot.stackTrace ?? StackTrace.empty,
      );
    }
    return AsyncData<T>(snapshot.data as T);
  }
}

/// Élő adatforrás kártyája egyetlen helyen megvalósítva: fejléc (ikon, cím,
/// szolgáltató, frissítés), frissességi sor, és a betöltés / hiba
/// (újrapróbálással) / üres / adat állapotok egy [AsyncValue]-ből (például
/// egy Riverpod-providerből). Az [onRefresh] a frissítés gomb, a hibánál az
/// „Újra”, és a Ctrl+R / F5.
class AsyncDataSourceCard<T> extends StatelessWidget {
  const AsyncDataSourceCard({
    super.key,
    required this.title,
    required this.value,
    required this.onRefresh,
    required this.builder,
    this.subtitle,
    this.provider,
    this.icon,
    this.accent,
    this.isEmpty,
    this.emptyMessage = 'Nincs megjeleníthető adat.',
    this.emptyIcon = Icons.inbox_outlined,
    this.emptyFooter,
    this.freshness,
    this.loadingLabel = 'Adatok betöltése…',
    this.errorPrefix = '',
    this.headerTrailing,
    this.placeholder,
    this.refreshTooltip = 'Adatok frissítése',
  });

  final String title;

  /// A betöltés állapota; frissítés közben (isLoading) a helyőrző látszik.
  final AsyncValue<T> value;
  final VoidCallback onRefresh;
  final Widget Function(BuildContext context, T data) builder;
  final String? subtitle;

  /// A szolgáltató neve a fejléc címkéjén.
  final String? provider;
  final IconData? icon;

  /// A sportoló kiemelőszíne (keret, ikon); alapból a téma kiemelőszíne.
  final Color? accent;
  final bool Function(T data)? isEmpty;
  final String emptyMessage;
  final IconData emptyIcon;

  /// Üres állapot alatti kiegészítés (például figyelmeztetések).
  final Widget Function(BuildContext context, T data)? emptyFooter;
  final DataFreshness? Function(T data)? freshness;
  final String loadingLabel;

  /// A felhasználóbarát hibaüzenet elé kerülő mondat.
  final String errorPrefix;
  final Widget? headerTrailing;

  /// Ha nem `null`, betöltés helyett ez jelenik meg (például hiányzó kulcs).
  final Widget? placeholder;
  final String refreshTooltip;

  /// Kész (betöltés és hiba nélküli) adat.
  bool get _ready => !value.isLoading && !value.hasError && value.hasValue;

  @override
  Widget build(BuildContext context) {
    final cb = context.cb;
    final accent = this.accent ?? cb.accent;
    final data = placeholder == null && _ready ? value.value : null;
    final freshness = data == null ? null : this.freshness?.call(data);
    // Ctrl+R / F5: az oldal minden adatkártyája újratölt.
    return CommandListener(
      onRefresh: placeholder == null ? onRefresh : null,
      child: SurfaceCard(
        accent: this.accent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(context, accent),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle!, style: context.text.bodySmall),
            ],
            if (freshness != null) ...[
              const SizedBox(height: 6),
              FreshnessNote(
                fetchedAt: freshness.fetchedAt,
                fromCache: freshness.fromCache,
                stale: freshness.stale,
              ),
            ],
            const SizedBox(height: 16),
            _body(context),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context, Color accent) {
    final cb = context.cb;
    final iconColor = cb.readable(accent);
    return Row(
      children: [
        if (icon != null) ...[
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: cb.tint(iconColor, .14),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(child: Text(title, style: context.text.titleLarge)),
        if (provider != null) ...[
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: StatusPill(provider!.toUpperCase()),
          ),
        ],
        if (headerTrailing != null) ...[
          const SizedBox(width: 8),
          headerTrailing!,
        ],
        const SizedBox(width: 4),
        IconButton(
          tooltip: '$refreshTooltip (Ctrl+R)',
          onPressed: placeholder == null ? onRefresh : null,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    );
  }

  Widget _body(BuildContext context) {
    if (placeholder != null) return placeholder!;
    if (value.isLoading) return CardSkeleton(label: loadingLabel);
    if (value.hasError) {
      return CourtboardErrorState(
        message: '$errorPrefix${friendlyError(value.error!)}',
        onRetry: onRefresh,
      );
    }
    final data = value.value;
    if (data == null || (isEmpty?.call(data) ?? false)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EmptyState(compact: true, icon: emptyIcon, message: emptyMessage),
          if (data != null && emptyFooter != null) emptyFooter!(context, data),
        ],
      );
    }
    return builder(context, data);
  }
}

// ---------------------------------------------------------------------------
// Lenyitható részletek
// ---------------------------------------------------------------------------

/// Kompakt, lenyitható részletsáv (például „Idővonal”, „Egymás elleni
/// mérleg”). A tartalom csak az első lenyitáskor töltődik be, így a zárt
/// sáv nem indít hálózati kérést.
class LazyDetailExpander<T> extends StatefulWidget {
  const LazyDetailExpander({
    super.key,
    required this.title,
    required this.load,
    required this.builder,
    this.icon,
    this.errorBuilder,
    this.initiallyExpanded = false,
    this.loadingLabel = 'Betöltés…',
  });

  final String title;
  final IconData? icon;
  final Future<T> Function() load;
  final Widget Function(BuildContext context, T data) builder;

  /// Egyedi hibaüzenet (például csomagkorlátnál); alapból a
  /// [friendlyError] szövege.
  final Widget? Function(BuildContext context, Object error)? errorBuilder;
  final bool initiallyExpanded;
  final String loadingLabel;

  @override
  State<LazyDetailExpander<T>> createState() => _LazyDetailExpanderState<T>();
}

class _LazyDetailExpanderState<T> extends State<LazyDetailExpander<T>> {
  late bool _open = widget.initiallyExpanded;
  Future<T>? _future;

  @override
  void initState() {
    super.initState();
    if (_open) _future = _start();
  }

  /// A betöltés indítása; a hiba a [FutureBuilder]-ben jelenik meg (a
  /// figyelő a következő képkockán csatlakozik, addig ne legyen
  /// „kezeletlen” hiba).
  Future<T> _start() => widget.load()..ignore();

  void _toggle() => setState(() {
    _open = !_open;
    if (_open) _future ??= _start();
  });

  void _retry() => setState(() => _future = _start());

  @override
  Widget build(BuildContext context) {
    final cb = context.cb;
    final color = cb.readable(cb.accent);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Semantics(
            expanded: _open,
            child: TextButton(
              onPressed: _toggle,
              style: TextButton.styleFrom(
                foregroundColor: color,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: const Size(0, 32),
                visualDensity: VisualDensity.compact,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.icon != null) ...[
                    Icon(widget.icon, size: 16),
                    const SizedBox(width: 6),
                  ],
                  Flexible(
                    child: Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.labelLarge?.copyWith(color: color),
                    ),
                  ),
                  const SizedBox(width: 2),
                  AnimatedRotation(
                    turns: _open ? .5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: const Icon(Icons.expand_more_rounded, size: 18),
                  ),
                ],
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          alignment: Alignment.topCenter,
          child: !_open
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                  child: FutureBuilder<T>(
                    future: _future,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return Row(
                          children: [
                            const SizedBox.square(
                              dimension: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              widget.loadingLabel,
                              style: context.text.bodySmall,
                            ),
                          ],
                        );
                      }
                      if (snapshot.hasError) {
                        final custom = widget.errorBuilder?.call(
                          context,
                          snapshot.error!,
                        );
                        if (custom != null) return custom;
                        return Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 18,
                              color: cb.error,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                friendlyError(snapshot.error!),
                                style: context.text.bodySmall,
                              ),
                            ),
                            TextButton(
                              onPressed: _retry,
                              child: const Text('Újra'),
                            ),
                          ],
                        );
                      }
                      return widget.builder(context, snapshot.data as T);
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Fókusz és billentyűparancsok
// ---------------------------------------------------------------------------

/// Látható, 2 px-es fókuszkeret egy kattintható felület köré, amikor a
/// felület (vagy egy leszármazottja) billentyűzettel kap fókuszt. Egérrel
/// kattintva nem jelenik meg (a Flutter fókuszkiemelési módja szerint).
class FocusRing extends StatefulWidget {
  const FocusRing({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.color,
    this.width = 2,
  });

  final Widget child;
  final BorderRadius borderRadius;

  /// Alapból a téma kiemelőszíne.
  final Color? color;
  final double width;

  @override
  State<FocusRing> createState() => _FocusRingState();
}

class _FocusRingState extends State<FocusRing> {
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addHighlightModeListener(_onHighlightMode);
  }

  @override
  void dispose() {
    FocusManager.instance.removeHighlightModeListener(_onHighlightMode);
    super.dispose();
  }

  void _onHighlightMode(FocusHighlightMode _) {
    if (_focused && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final visible =
        _focused &&
        FocusManager.instance.highlightMode == FocusHighlightMode.traditional;
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      includeSemantics: false,
      onFocusChange: (value) {
        if (value != _focused) setState(() => _focused = value);
      },
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: widget.borderRadius,
          border: visible
              ? Border.all(
                  color: widget.color ?? context.cb.accent,
                  width: widget.width,
                )
              : null,
        ),
        child: widget.child,
      ),
    );
  }
}

/// Az alkalmazásszintű billentyűparancsok jelzései az éppen látható oldal
/// felé (Ctrl+R frissítés, Ctrl+F keresés). Az oldalak [CommandListener]
/// segítségével iratkoznak fel; a shell a feliratkozók száma alapján dönti
/// el, hogy az oldal kezeli-e a parancsot.
class CourtboardCommands {
  final ValueNotifier<int> _refresh = ValueNotifier(0);
  final ValueNotifier<int> _focusSearch = ValueNotifier(0);
  int _refreshHandlers = 0;
  int _searchHandlers = 0;

  /// Igaz, ha a látható oldalon van frissíthető tartalom.
  bool get hasRefreshHandler => _refreshHandlers > 0;

  /// Igaz, ha a látható oldalon van keresőmező.
  bool get hasSearchHandler => _searchHandlers > 0;

  void requestRefresh() => _refresh.value++;
  void requestSearchFocus() => _focusSearch.value++;

  void dispose() {
    _refresh.dispose();
    _focusSearch.dispose();
  }
}

/// A [CourtboardCommands] elérhetővé tétele a widgetfában.
class CourtboardCommandScope extends InheritedWidget {
  const CourtboardCommandScope({
    super.key,
    required this.commands,
    required super.child,
  });

  final CourtboardCommands commands;

  static CourtboardCommands? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<CourtboardCommandScope>()
      ?.commands;

  @override
  bool updateShouldNotify(CourtboardCommandScope oldWidget) =>
      !identical(commands, oldWidget.commands);
}

/// Feliratkozás a shell parancsaira: [onRefresh] a Ctrl+R / F5, az
/// [onFocusSearch] a Ctrl+F lenyomásakor fut — csak amíg az oldal látható
/// (a háttérben megtartott ágak nem reagálnak). Parancsfelület nélkül
/// (például különálló widgettesztben) egyszerűen a gyermeket adja vissza.
class CommandListener extends StatefulWidget {
  const CommandListener({
    super.key,
    this.onRefresh,
    this.onFocusSearch,
    required this.child,
  });

  final VoidCallback? onRefresh;
  final VoidCallback? onFocusSearch;
  final Widget child;

  @override
  State<CommandListener> createState() => _CommandListenerState();
}

class _CommandListenerState extends State<CommandListener> {
  CourtboardCommands? _commands;
  bool _refreshRegistered = false;
  bool _searchRegistered = false;

  /// Látható-e az oldal: a háttérben megtartott (például egy másik
  /// menüpont ágában vagy egy profil alatt rejtett) oldal nem kapja meg a
  /// parancsokat ([TickerMode]).
  bool _active = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final commands = CourtboardCommandScope.maybeOf(context);
    final active = TickerMode.valuesOf(context).enabled;
    if (identical(commands, _commands) && active == _active) return;
    _unsubscribe();
    _commands = commands;
    _active = active;
    _subscribe();
  }

  @override
  void didUpdateWidget(covariant CommandListener oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((oldWidget.onRefresh == null) != (widget.onRefresh == null) ||
        (oldWidget.onFocusSearch == null) != (widget.onFocusSearch == null)) {
      _unsubscribe();
      _subscribe();
    }
  }

  @override
  void dispose() {
    _unsubscribe();
    super.dispose();
  }

  void _subscribe() {
    final commands = _commands;
    if (commands == null || !_active) return;
    if (widget.onRefresh != null) {
      commands._refresh.addListener(_handleRefresh);
      commands._refreshHandlers++;
      _refreshRegistered = true;
    }
    if (widget.onFocusSearch != null) {
      commands._focusSearch.addListener(_handleSearch);
      commands._searchHandlers++;
      _searchRegistered = true;
    }
  }

  void _unsubscribe() {
    final commands = _commands;
    if (commands == null) return;
    if (_refreshRegistered) {
      commands._refresh.removeListener(_handleRefresh);
      commands._refreshHandlers--;
      _refreshRegistered = false;
    }
    if (_searchRegistered) {
      commands._focusSearch.removeListener(_handleSearch);
      commands._searchHandlers--;
      _searchRegistered = false;
    }
  }

  void _handleRefresh() {
    if (mounted) widget.onRefresh?.call();
  }

  void _handleSearch() {
    if (mounted) widget.onFocusSearch?.call();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
