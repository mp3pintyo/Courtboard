/// A hírarchívum drift-oszlopainak típusátalakítói. A sémát a 0.14.0 előtti
/// (sqflite) tárral közösen használjuk, ezért a tárolt formátum változatlan:
/// az időpontok epoch-ezredmásodpercek, a logikai értékek 0/1 egészek.
library;

import 'package:drift/drift.dart';

/// `DateTime` ↔ epoch-ezredmásodperc (helyi idő, ahogy a korábbi tár olvasta).
class EpochMillisConverter extends TypeConverter<DateTime, int> {
  const EpochMillisConverter();

  @override
  DateTime fromSql(int fromDb) =>
      DateTime.fromMillisecondsSinceEpoch(fromDb, isUtc: false);

  @override
  int toSql(DateTime value) => value.millisecondsSinceEpoch;
}

/// `bool` ↔ `INTEGER` 0/1 (a régi séma `enabled INTEGER NOT NULL` oszlopa).
class IntBoolConverter extends TypeConverter<bool, int> {
  const IntBoolConverter();

  @override
  bool fromSql(int fromDb) => fromDb == 1;

  @override
  int toSql(bool value) => value ? 1 : 0;
}
