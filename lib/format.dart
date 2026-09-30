/// Magyar szám- és dátumformázás egy helyen (intl, `hu` területi beállítás).
///
/// - `formatDecimal(26.8)` → `26,8`
/// - `formatInt(2005)` → `2 005` (nem törhető szóközzel)
/// - `formatPercent(45.2)` → `45,2%`
/// - `formatDate(d)` → `2026. 04. 12.`
/// - `formatShortDate(d)` → `ápr. 12.`
/// - `formatMatchDate(d)` → `ápr. 12.` (idén) / `2025. ápr. 12.` (más évben)
/// - `formatDateTime(d)` → `2026. 04. 12. 17:05`
library;

import 'dart:async';

import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

const courtboardLocale = 'hu';

var _dateSymbolsReady = false;

/// A `hu` dátumszimbólumok betöltése. Az intl helyi adatai szinkron
/// töltődnek be, így a formázók a `main()`-beli várakozás nélkül (például
/// widgettesztben) is azonnal használhatók.
void ensureHungarianDateFormatting() {
  if (_dateSymbolsReady) return;
  unawaited(initializeDateFormatting(courtboardLocale));
  _dateSymbolsReady = true;
}

final Map<int, NumberFormat> _decimalFormats = {};

NumberFormat _decimalFormat(int digits) => _decimalFormats.putIfAbsent(
  digits,
  () => NumberFormat(
    digits == 0 ? '#,##0' : '#,##0.${'0' * digits}',
    courtboardLocale,
  ),
);

/// Tizedes tört magyar írásmóddal (`26,8`); `null` esetén gondolatjel.
String formatDecimal(num? value, {int digits = 1}) =>
    value == null ? '—' : _decimalFormat(digits).format(value);

/// Egész szám ezres tagolással (`2 005`); `null` esetén gondolatjel.
String formatInt(num? value) =>
    value == null ? '—' : _decimalFormat(0).format(value);

/// Százalék egy tizedessel (`45,2%`); `null` esetén gondolatjel.
String formatPercent(num? value, {int digits = 1}) =>
    value == null ? '—' : '${formatDecimal(value, digits: digits)}%';

/// Szolgáltatótól szövegként érkező szám („21.5”, „1234”) magyar alakja;
/// ha nem tisztán szám, változatlanul adja vissza.
String localizeNumberText(String value) {
  final trimmed = value.trim();
  final match = RegExp(r'^(-?\d+)(?:\.(\d+))?(%?)$').firstMatch(trimmed);
  if (match == null) return value;
  final fraction = match.group(2);
  final number = num.parse(
    fraction == null ? match.group(1)! : '${match.group(1)}.$fraction',
  );
  final text = fraction == null
      ? formatInt(number)
      : formatDecimal(number, digits: fraction.length);
  return '$text${match.group(3)}';
}

DateFormat _pattern(DateFormat Function(String locale) create) {
  ensureHungarianDateFormatting();
  return create(courtboardLocale);
}

/// Teljes dátum: `2026. 04. 12.`
String formatDate(DateTime date) =>
    _pattern((locale) => DateFormat.yMd(locale)).format(date);

/// Rövid dátum évszám nélkül: `ápr. 12.`
String formatShortDate(DateTime date) =>
    _pattern((locale) => DateFormat.MMMd(locale)).format(date);

/// Rövid dátum évszámmal: `2025. ápr. 12.`
String formatShortDateWithYear(DateTime date) =>
    _pattern((locale) => DateFormat.yMMMd(locale)).format(date);

/// Mérkőzésdátum egységesen minden sportágban: az idei évben évszám nélkül
/// (`ápr. 12.`), más évben évszámmal (`2025. ápr. 12.`).
String formatMatchDate(DateTime date, {DateTime? now}) =>
    date.year == (now ?? DateTime.now()).year
    ? formatShortDate(date)
    : formatShortDateWithYear(date);

/// Óra és perc: `17:05`
String formatTime(DateTime date) =>
    _pattern((locale) => DateFormat.Hm(locale)).format(date);

/// Dátum és idő: `2026. 04. 12. 17:05`
String formatDateTime(DateTime date) =>
    '${formatDate(date)} ${formatTime(date)}';

/// ISO-szerű dátumszöveg („1995-02-11”) magyar alakja; értelmezhetetlen
/// értéknél az eredeti szöveg.
String formatDateText(String value) {
  final parsed = DateTime.tryParse(value.trim());
  return parsed == null ? value : formatDate(parsed);
}
