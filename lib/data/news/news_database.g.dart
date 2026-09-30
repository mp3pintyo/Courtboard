// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'news_database.dart';

// ignore_for_file: type=lint
class NewsSources extends Table with TableInfo<NewsSources, NewsSourceRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  NewsSources(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _sportMeta = const VerificationMeta('sport');
  late final GeneratedColumn<String> sport = GeneratedColumn<String>(
    'sport',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _urlMeta = const VerificationMeta('url');
  late final GeneratedColumn<String> url = GeneratedColumn<String>(
    'url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _homepageMeta = const VerificationMeta(
    'homepage',
  );
  late final GeneratedColumn<String> homepage = GeneratedColumn<String>(
    'homepage',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  late final GeneratedColumnWithTypeConverter<bool, int> enabled =
      GeneratedColumn<int>(
        'enabled',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
        $customConstraints: 'NOT NULL',
      ).withConverter<bool>(NewsSources.$converterenabled);
  static const VerificationMeta _termsNoteMeta = const VerificationMeta(
    'termsNote',
  );
  late final GeneratedColumn<String> termsNote = GeneratedColumn<String>(
    'terms_note',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'\'',
    defaultValue: const CustomExpression('\'\''),
  );
  late final GeneratedColumnWithTypeConverter<DateTime?, int> lastAttemptAt =
      GeneratedColumn<int>(
        'last_attempt_at',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
        $customConstraints: '',
      ).withConverter<DateTime?>(NewsSources.$converterlastAttemptAtn);
  late final GeneratedColumnWithTypeConverter<DateTime?, int> lastSuccessAt =
      GeneratedColumn<int>(
        'last_success_at',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
        $customConstraints: '',
      ).withConverter<DateTime?>(NewsSources.$converterlastSuccessAtn);
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'\'',
    defaultValue: const CustomExpression('\'\''),
  );
  static const VerificationMeta _etagMeta = const VerificationMeta('etag');
  late final GeneratedColumn<String> etag = GeneratedColumn<String>(
    'etag',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'\'',
    defaultValue: const CustomExpression('\'\''),
  );
  static const VerificationMeta _lastModifiedMeta = const VerificationMeta(
    'lastModified',
  );
  late final GeneratedColumn<String> lastModified = GeneratedColumn<String>(
    'last_modified',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'\'',
    defaultValue: const CustomExpression('\'\''),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    sport,
    url,
    homepage,
    enabled,
    termsNote,
    lastAttemptAt,
    lastSuccessAt,
    lastError,
    etag,
    lastModified,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'news_sources';
  @override
  VerificationContext validateIntegrity(
    Insertable<NewsSourceRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('sport')) {
      context.handle(
        _sportMeta,
        sport.isAcceptableOrUnknown(data['sport']!, _sportMeta),
      );
    } else if (isInserting) {
      context.missing(_sportMeta);
    }
    if (data.containsKey('url')) {
      context.handle(
        _urlMeta,
        url.isAcceptableOrUnknown(data['url']!, _urlMeta),
      );
    } else if (isInserting) {
      context.missing(_urlMeta);
    }
    if (data.containsKey('homepage')) {
      context.handle(
        _homepageMeta,
        homepage.isAcceptableOrUnknown(data['homepage']!, _homepageMeta),
      );
    } else if (isInserting) {
      context.missing(_homepageMeta);
    }
    if (data.containsKey('terms_note')) {
      context.handle(
        _termsNoteMeta,
        termsNote.isAcceptableOrUnknown(data['terms_note']!, _termsNoteMeta),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    if (data.containsKey('etag')) {
      context.handle(
        _etagMeta,
        etag.isAcceptableOrUnknown(data['etag']!, _etagMeta),
      );
    }
    if (data.containsKey('last_modified')) {
      context.handle(
        _lastModifiedMeta,
        lastModified.isAcceptableOrUnknown(
          data['last_modified']!,
          _lastModifiedMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  NewsSourceRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NewsSourceRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      sport: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sport'],
      )!,
      url: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}url'],
      )!,
      homepage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}homepage'],
      )!,
      enabled: NewsSources.$converterenabled.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}enabled'],
        )!,
      ),
      termsNote: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}terms_note'],
      )!,
      lastAttemptAt: NewsSources.$converterlastAttemptAtn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}last_attempt_at'],
        ),
      ),
      lastSuccessAt: NewsSources.$converterlastSuccessAtn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}last_success_at'],
        ),
      ),
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      )!,
      etag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}etag'],
      )!,
      lastModified: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_modified'],
      )!,
    );
  }

  @override
  NewsSources createAlias(String alias) {
    return NewsSources(attachedDatabase, alias);
  }

  static TypeConverter<bool, int> $converterenabled = const IntBoolConverter();
  static TypeConverter<DateTime, int> $converterlastAttemptAt =
      const EpochMillisConverter();
  static TypeConverter<DateTime?, int?> $converterlastAttemptAtn =
      NullAwareTypeConverter.wrap($converterlastAttemptAt);
  static TypeConverter<DateTime, int> $converterlastSuccessAt =
      const EpochMillisConverter();
  static TypeConverter<DateTime?, int?> $converterlastSuccessAtn =
      NullAwareTypeConverter.wrap($converterlastSuccessAt);
  @override
  bool get dontWriteConstraints => true;
}

class NewsSourceRow extends DataClass implements Insertable<NewsSourceRow> {
  final String id;
  final String name;
  final String sport;
  final String url;
  final String homepage;
  final bool enabled;
  final String termsNote;
  final DateTime? lastAttemptAt;
  final DateTime? lastSuccessAt;
  final String lastError;
  final String etag;
  final String lastModified;
  const NewsSourceRow({
    required this.id,
    required this.name,
    required this.sport,
    required this.url,
    required this.homepage,
    required this.enabled,
    required this.termsNote,
    this.lastAttemptAt,
    this.lastSuccessAt,
    required this.lastError,
    required this.etag,
    required this.lastModified,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['sport'] = Variable<String>(sport);
    map['url'] = Variable<String>(url);
    map['homepage'] = Variable<String>(homepage);
    {
      map['enabled'] = Variable<int>(
        NewsSources.$converterenabled.toSql(enabled),
      );
    }
    map['terms_note'] = Variable<String>(termsNote);
    if (!nullToAbsent || lastAttemptAt != null) {
      map['last_attempt_at'] = Variable<int>(
        NewsSources.$converterlastAttemptAtn.toSql(lastAttemptAt),
      );
    }
    if (!nullToAbsent || lastSuccessAt != null) {
      map['last_success_at'] = Variable<int>(
        NewsSources.$converterlastSuccessAtn.toSql(lastSuccessAt),
      );
    }
    map['last_error'] = Variable<String>(lastError);
    map['etag'] = Variable<String>(etag);
    map['last_modified'] = Variable<String>(lastModified);
    return map;
  }

  NewsSourcesCompanion toCompanion(bool nullToAbsent) {
    return NewsSourcesCompanion(
      id: Value(id),
      name: Value(name),
      sport: Value(sport),
      url: Value(url),
      homepage: Value(homepage),
      enabled: Value(enabled),
      termsNote: Value(termsNote),
      lastAttemptAt: lastAttemptAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastAttemptAt),
      lastSuccessAt: lastSuccessAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSuccessAt),
      lastError: Value(lastError),
      etag: Value(etag),
      lastModified: Value(lastModified),
    );
  }

  factory NewsSourceRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NewsSourceRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      sport: serializer.fromJson<String>(json['sport']),
      url: serializer.fromJson<String>(json['url']),
      homepage: serializer.fromJson<String>(json['homepage']),
      enabled: serializer.fromJson<bool>(json['enabled']),
      termsNote: serializer.fromJson<String>(json['terms_note']),
      lastAttemptAt: serializer.fromJson<DateTime?>(json['last_attempt_at']),
      lastSuccessAt: serializer.fromJson<DateTime?>(json['last_success_at']),
      lastError: serializer.fromJson<String>(json['last_error']),
      etag: serializer.fromJson<String>(json['etag']),
      lastModified: serializer.fromJson<String>(json['last_modified']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'sport': serializer.toJson<String>(sport),
      'url': serializer.toJson<String>(url),
      'homepage': serializer.toJson<String>(homepage),
      'enabled': serializer.toJson<bool>(enabled),
      'terms_note': serializer.toJson<String>(termsNote),
      'last_attempt_at': serializer.toJson<DateTime?>(lastAttemptAt),
      'last_success_at': serializer.toJson<DateTime?>(lastSuccessAt),
      'last_error': serializer.toJson<String>(lastError),
      'etag': serializer.toJson<String>(etag),
      'last_modified': serializer.toJson<String>(lastModified),
    };
  }

  NewsSourceRow copyWith({
    String? id,
    String? name,
    String? sport,
    String? url,
    String? homepage,
    bool? enabled,
    String? termsNote,
    Value<DateTime?> lastAttemptAt = const Value.absent(),
    Value<DateTime?> lastSuccessAt = const Value.absent(),
    String? lastError,
    String? etag,
    String? lastModified,
  }) => NewsSourceRow(
    id: id ?? this.id,
    name: name ?? this.name,
    sport: sport ?? this.sport,
    url: url ?? this.url,
    homepage: homepage ?? this.homepage,
    enabled: enabled ?? this.enabled,
    termsNote: termsNote ?? this.termsNote,
    lastAttemptAt: lastAttemptAt.present
        ? lastAttemptAt.value
        : this.lastAttemptAt,
    lastSuccessAt: lastSuccessAt.present
        ? lastSuccessAt.value
        : this.lastSuccessAt,
    lastError: lastError ?? this.lastError,
    etag: etag ?? this.etag,
    lastModified: lastModified ?? this.lastModified,
  );
  NewsSourceRow copyWithCompanion(NewsSourcesCompanion data) {
    return NewsSourceRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      sport: data.sport.present ? data.sport.value : this.sport,
      url: data.url.present ? data.url.value : this.url,
      homepage: data.homepage.present ? data.homepage.value : this.homepage,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
      termsNote: data.termsNote.present ? data.termsNote.value : this.termsNote,
      lastAttemptAt: data.lastAttemptAt.present
          ? data.lastAttemptAt.value
          : this.lastAttemptAt,
      lastSuccessAt: data.lastSuccessAt.present
          ? data.lastSuccessAt.value
          : this.lastSuccessAt,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      etag: data.etag.present ? data.etag.value : this.etag,
      lastModified: data.lastModified.present
          ? data.lastModified.value
          : this.lastModified,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NewsSourceRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('sport: $sport, ')
          ..write('url: $url, ')
          ..write('homepage: $homepage, ')
          ..write('enabled: $enabled, ')
          ..write('termsNote: $termsNote, ')
          ..write('lastAttemptAt: $lastAttemptAt, ')
          ..write('lastSuccessAt: $lastSuccessAt, ')
          ..write('lastError: $lastError, ')
          ..write('etag: $etag, ')
          ..write('lastModified: $lastModified')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    sport,
    url,
    homepage,
    enabled,
    termsNote,
    lastAttemptAt,
    lastSuccessAt,
    lastError,
    etag,
    lastModified,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NewsSourceRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.sport == this.sport &&
          other.url == this.url &&
          other.homepage == this.homepage &&
          other.enabled == this.enabled &&
          other.termsNote == this.termsNote &&
          other.lastAttemptAt == this.lastAttemptAt &&
          other.lastSuccessAt == this.lastSuccessAt &&
          other.lastError == this.lastError &&
          other.etag == this.etag &&
          other.lastModified == this.lastModified);
}

class NewsSourcesCompanion extends UpdateCompanion<NewsSourceRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> sport;
  final Value<String> url;
  final Value<String> homepage;
  final Value<bool> enabled;
  final Value<String> termsNote;
  final Value<DateTime?> lastAttemptAt;
  final Value<DateTime?> lastSuccessAt;
  final Value<String> lastError;
  final Value<String> etag;
  final Value<String> lastModified;
  final Value<int> rowid;
  const NewsSourcesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.sport = const Value.absent(),
    this.url = const Value.absent(),
    this.homepage = const Value.absent(),
    this.enabled = const Value.absent(),
    this.termsNote = const Value.absent(),
    this.lastAttemptAt = const Value.absent(),
    this.lastSuccessAt = const Value.absent(),
    this.lastError = const Value.absent(),
    this.etag = const Value.absent(),
    this.lastModified = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NewsSourcesCompanion.insert({
    required String id,
    required String name,
    required String sport,
    required String url,
    required String homepage,
    required bool enabled,
    this.termsNote = const Value.absent(),
    this.lastAttemptAt = const Value.absent(),
    this.lastSuccessAt = const Value.absent(),
    this.lastError = const Value.absent(),
    this.etag = const Value.absent(),
    this.lastModified = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       sport = Value(sport),
       url = Value(url),
       homepage = Value(homepage),
       enabled = Value(enabled);
  static Insertable<NewsSourceRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? sport,
    Expression<String>? url,
    Expression<String>? homepage,
    Expression<int>? enabled,
    Expression<String>? termsNote,
    Expression<int>? lastAttemptAt,
    Expression<int>? lastSuccessAt,
    Expression<String>? lastError,
    Expression<String>? etag,
    Expression<String>? lastModified,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (sport != null) 'sport': sport,
      if (url != null) 'url': url,
      if (homepage != null) 'homepage': homepage,
      if (enabled != null) 'enabled': enabled,
      if (termsNote != null) 'terms_note': termsNote,
      if (lastAttemptAt != null) 'last_attempt_at': lastAttemptAt,
      if (lastSuccessAt != null) 'last_success_at': lastSuccessAt,
      if (lastError != null) 'last_error': lastError,
      if (etag != null) 'etag': etag,
      if (lastModified != null) 'last_modified': lastModified,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NewsSourcesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? sport,
    Value<String>? url,
    Value<String>? homepage,
    Value<bool>? enabled,
    Value<String>? termsNote,
    Value<DateTime?>? lastAttemptAt,
    Value<DateTime?>? lastSuccessAt,
    Value<String>? lastError,
    Value<String>? etag,
    Value<String>? lastModified,
    Value<int>? rowid,
  }) {
    return NewsSourcesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      sport: sport ?? this.sport,
      url: url ?? this.url,
      homepage: homepage ?? this.homepage,
      enabled: enabled ?? this.enabled,
      termsNote: termsNote ?? this.termsNote,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      lastSuccessAt: lastSuccessAt ?? this.lastSuccessAt,
      lastError: lastError ?? this.lastError,
      etag: etag ?? this.etag,
      lastModified: lastModified ?? this.lastModified,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (sport.present) {
      map['sport'] = Variable<String>(sport.value);
    }
    if (url.present) {
      map['url'] = Variable<String>(url.value);
    }
    if (homepage.present) {
      map['homepage'] = Variable<String>(homepage.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<int>(
        NewsSources.$converterenabled.toSql(enabled.value),
      );
    }
    if (termsNote.present) {
      map['terms_note'] = Variable<String>(termsNote.value);
    }
    if (lastAttemptAt.present) {
      map['last_attempt_at'] = Variable<int>(
        NewsSources.$converterlastAttemptAtn.toSql(lastAttemptAt.value),
      );
    }
    if (lastSuccessAt.present) {
      map['last_success_at'] = Variable<int>(
        NewsSources.$converterlastSuccessAtn.toSql(lastSuccessAt.value),
      );
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (etag.present) {
      map['etag'] = Variable<String>(etag.value);
    }
    if (lastModified.present) {
      map['last_modified'] = Variable<String>(lastModified.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NewsSourcesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('sport: $sport, ')
          ..write('url: $url, ')
          ..write('homepage: $homepage, ')
          ..write('enabled: $enabled, ')
          ..write('termsNote: $termsNote, ')
          ..write('lastAttemptAt: $lastAttemptAt, ')
          ..write('lastSuccessAt: $lastSuccessAt, ')
          ..write('lastError: $lastError, ')
          ..write('etag: $etag, ')
          ..write('lastModified: $lastModified, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class NewsItems extends Table with TableInfo<NewsItems, NewsItemRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  NewsItems(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'PRIMARY KEY AUTOINCREMENT',
  );
  static const VerificationMeta _dedupeKeyMeta = const VerificationMeta(
    'dedupeKey',
  );
  late final GeneratedColumn<String> dedupeKey = GeneratedColumn<String>(
    'dedupe_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL UNIQUE',
  );
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  late final GeneratedColumn<String> sourceId = GeneratedColumn<String>(
    'source_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _sourceNameMeta = const VerificationMeta(
    'sourceName',
  );
  late final GeneratedColumn<String> sourceName = GeneratedColumn<String>(
    'source_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _externalIdMeta = const VerificationMeta(
    'externalId',
  );
  late final GeneratedColumn<String> externalId = GeneratedColumn<String>(
    'external_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'\'',
    defaultValue: const CustomExpression('\'\''),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _summaryMeta = const VerificationMeta(
    'summary',
  );
  late final GeneratedColumn<String> summary = GeneratedColumn<String>(
    'summary',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'\'',
    defaultValue: const CustomExpression('\'\''),
  );
  static const VerificationMeta _urlMeta = const VerificationMeta('url');
  late final GeneratedColumn<String> url = GeneratedColumn<String>(
    'url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _imageUrlMeta = const VerificationMeta(
    'imageUrl',
  );
  late final GeneratedColumn<String> imageUrl = GeneratedColumn<String>(
    'image_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'\'',
    defaultValue: const CustomExpression('\'\''),
  );
  static const VerificationMeta _authorMeta = const VerificationMeta('author');
  late final GeneratedColumn<String> author = GeneratedColumn<String>(
    'author',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'\'',
    defaultValue: const CustomExpression('\'\''),
  );
  static const VerificationMeta _searchTextMeta = const VerificationMeta(
    'searchText',
  );
  late final GeneratedColumn<String> searchText = GeneratedColumn<String>(
    'search_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  late final GeneratedColumnWithTypeConverter<DateTime, int> publishedAt =
      GeneratedColumn<int>(
        'published_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
        $customConstraints: 'NOT NULL',
      ).withConverter<DateTime>(NewsItems.$converterpublishedAt);
  late final GeneratedColumnWithTypeConverter<DateTime, int> fetchedAt =
      GeneratedColumn<int>(
        'fetched_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
        $customConstraints: 'NOT NULL',
      ).withConverter<DateTime>(NewsItems.$converterfetchedAt);
  @override
  List<GeneratedColumn> get $columns => [
    id,
    dedupeKey,
    sourceId,
    sourceName,
    externalId,
    title,
    summary,
    url,
    imageUrl,
    author,
    searchText,
    publishedAt,
    fetchedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'news_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<NewsItemRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('dedupe_key')) {
      context.handle(
        _dedupeKeyMeta,
        dedupeKey.isAcceptableOrUnknown(data['dedupe_key']!, _dedupeKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_dedupeKeyMeta);
    }
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceIdMeta);
    }
    if (data.containsKey('source_name')) {
      context.handle(
        _sourceNameMeta,
        sourceName.isAcceptableOrUnknown(data['source_name']!, _sourceNameMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceNameMeta);
    }
    if (data.containsKey('external_id')) {
      context.handle(
        _externalIdMeta,
        externalId.isAcceptableOrUnknown(data['external_id']!, _externalIdMeta),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('summary')) {
      context.handle(
        _summaryMeta,
        summary.isAcceptableOrUnknown(data['summary']!, _summaryMeta),
      );
    }
    if (data.containsKey('url')) {
      context.handle(
        _urlMeta,
        url.isAcceptableOrUnknown(data['url']!, _urlMeta),
      );
    } else if (isInserting) {
      context.missing(_urlMeta);
    }
    if (data.containsKey('image_url')) {
      context.handle(
        _imageUrlMeta,
        imageUrl.isAcceptableOrUnknown(data['image_url']!, _imageUrlMeta),
      );
    }
    if (data.containsKey('author')) {
      context.handle(
        _authorMeta,
        author.isAcceptableOrUnknown(data['author']!, _authorMeta),
      );
    }
    if (data.containsKey('search_text')) {
      context.handle(
        _searchTextMeta,
        searchText.isAcceptableOrUnknown(data['search_text']!, _searchTextMeta),
      );
    } else if (isInserting) {
      context.missing(_searchTextMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  NewsItemRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NewsItemRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      dedupeKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dedupe_key'],
      )!,
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_id'],
      )!,
      sourceName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_name'],
      )!,
      externalId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}external_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      summary: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}summary'],
      )!,
      url: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}url'],
      )!,
      imageUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_url'],
      )!,
      author: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}author'],
      )!,
      searchText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}search_text'],
      )!,
      publishedAt: NewsItems.$converterpublishedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}published_at'],
        )!,
      ),
      fetchedAt: NewsItems.$converterfetchedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}fetched_at'],
        )!,
      ),
    );
  }

  @override
  NewsItems createAlias(String alias) {
    return NewsItems(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, int> $converterpublishedAt =
      const EpochMillisConverter();
  static TypeConverter<DateTime, int> $converterfetchedAt =
      const EpochMillisConverter();
  @override
  List<String> get customConstraints => const [
    'FOREIGN KEY(source_id)REFERENCES news_sources(id)',
  ];
  @override
  bool get dontWriteConstraints => true;
}

class NewsItemRow extends DataClass implements Insertable<NewsItemRow> {
  final int id;
  final String dedupeKey;
  final String sourceId;
  final String sourceName;
  final String externalId;
  final String title;
  final String summary;
  final String url;
  final String imageUrl;
  final String author;
  final String searchText;
  final DateTime publishedAt;
  final DateTime fetchedAt;
  const NewsItemRow({
    required this.id,
    required this.dedupeKey,
    required this.sourceId,
    required this.sourceName,
    required this.externalId,
    required this.title,
    required this.summary,
    required this.url,
    required this.imageUrl,
    required this.author,
    required this.searchText,
    required this.publishedAt,
    required this.fetchedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['dedupe_key'] = Variable<String>(dedupeKey);
    map['source_id'] = Variable<String>(sourceId);
    map['source_name'] = Variable<String>(sourceName);
    map['external_id'] = Variable<String>(externalId);
    map['title'] = Variable<String>(title);
    map['summary'] = Variable<String>(summary);
    map['url'] = Variable<String>(url);
    map['image_url'] = Variable<String>(imageUrl);
    map['author'] = Variable<String>(author);
    map['search_text'] = Variable<String>(searchText);
    {
      map['published_at'] = Variable<int>(
        NewsItems.$converterpublishedAt.toSql(publishedAt),
      );
    }
    {
      map['fetched_at'] = Variable<int>(
        NewsItems.$converterfetchedAt.toSql(fetchedAt),
      );
    }
    return map;
  }

  NewsItemsCompanion toCompanion(bool nullToAbsent) {
    return NewsItemsCompanion(
      id: Value(id),
      dedupeKey: Value(dedupeKey),
      sourceId: Value(sourceId),
      sourceName: Value(sourceName),
      externalId: Value(externalId),
      title: Value(title),
      summary: Value(summary),
      url: Value(url),
      imageUrl: Value(imageUrl),
      author: Value(author),
      searchText: Value(searchText),
      publishedAt: Value(publishedAt),
      fetchedAt: Value(fetchedAt),
    );
  }

  factory NewsItemRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NewsItemRow(
      id: serializer.fromJson<int>(json['id']),
      dedupeKey: serializer.fromJson<String>(json['dedupe_key']),
      sourceId: serializer.fromJson<String>(json['source_id']),
      sourceName: serializer.fromJson<String>(json['source_name']),
      externalId: serializer.fromJson<String>(json['external_id']),
      title: serializer.fromJson<String>(json['title']),
      summary: serializer.fromJson<String>(json['summary']),
      url: serializer.fromJson<String>(json['url']),
      imageUrl: serializer.fromJson<String>(json['image_url']),
      author: serializer.fromJson<String>(json['author']),
      searchText: serializer.fromJson<String>(json['search_text']),
      publishedAt: serializer.fromJson<DateTime>(json['published_at']),
      fetchedAt: serializer.fromJson<DateTime>(json['fetched_at']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'dedupe_key': serializer.toJson<String>(dedupeKey),
      'source_id': serializer.toJson<String>(sourceId),
      'source_name': serializer.toJson<String>(sourceName),
      'external_id': serializer.toJson<String>(externalId),
      'title': serializer.toJson<String>(title),
      'summary': serializer.toJson<String>(summary),
      'url': serializer.toJson<String>(url),
      'image_url': serializer.toJson<String>(imageUrl),
      'author': serializer.toJson<String>(author),
      'search_text': serializer.toJson<String>(searchText),
      'published_at': serializer.toJson<DateTime>(publishedAt),
      'fetched_at': serializer.toJson<DateTime>(fetchedAt),
    };
  }

  NewsItemRow copyWith({
    int? id,
    String? dedupeKey,
    String? sourceId,
    String? sourceName,
    String? externalId,
    String? title,
    String? summary,
    String? url,
    String? imageUrl,
    String? author,
    String? searchText,
    DateTime? publishedAt,
    DateTime? fetchedAt,
  }) => NewsItemRow(
    id: id ?? this.id,
    dedupeKey: dedupeKey ?? this.dedupeKey,
    sourceId: sourceId ?? this.sourceId,
    sourceName: sourceName ?? this.sourceName,
    externalId: externalId ?? this.externalId,
    title: title ?? this.title,
    summary: summary ?? this.summary,
    url: url ?? this.url,
    imageUrl: imageUrl ?? this.imageUrl,
    author: author ?? this.author,
    searchText: searchText ?? this.searchText,
    publishedAt: publishedAt ?? this.publishedAt,
    fetchedAt: fetchedAt ?? this.fetchedAt,
  );
  NewsItemRow copyWithCompanion(NewsItemsCompanion data) {
    return NewsItemRow(
      id: data.id.present ? data.id.value : this.id,
      dedupeKey: data.dedupeKey.present ? data.dedupeKey.value : this.dedupeKey,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      sourceName: data.sourceName.present
          ? data.sourceName.value
          : this.sourceName,
      externalId: data.externalId.present
          ? data.externalId.value
          : this.externalId,
      title: data.title.present ? data.title.value : this.title,
      summary: data.summary.present ? data.summary.value : this.summary,
      url: data.url.present ? data.url.value : this.url,
      imageUrl: data.imageUrl.present ? data.imageUrl.value : this.imageUrl,
      author: data.author.present ? data.author.value : this.author,
      searchText: data.searchText.present
          ? data.searchText.value
          : this.searchText,
      publishedAt: data.publishedAt.present
          ? data.publishedAt.value
          : this.publishedAt,
      fetchedAt: data.fetchedAt.present ? data.fetchedAt.value : this.fetchedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NewsItemRow(')
          ..write('id: $id, ')
          ..write('dedupeKey: $dedupeKey, ')
          ..write('sourceId: $sourceId, ')
          ..write('sourceName: $sourceName, ')
          ..write('externalId: $externalId, ')
          ..write('title: $title, ')
          ..write('summary: $summary, ')
          ..write('url: $url, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('author: $author, ')
          ..write('searchText: $searchText, ')
          ..write('publishedAt: $publishedAt, ')
          ..write('fetchedAt: $fetchedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    dedupeKey,
    sourceId,
    sourceName,
    externalId,
    title,
    summary,
    url,
    imageUrl,
    author,
    searchText,
    publishedAt,
    fetchedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NewsItemRow &&
          other.id == this.id &&
          other.dedupeKey == this.dedupeKey &&
          other.sourceId == this.sourceId &&
          other.sourceName == this.sourceName &&
          other.externalId == this.externalId &&
          other.title == this.title &&
          other.summary == this.summary &&
          other.url == this.url &&
          other.imageUrl == this.imageUrl &&
          other.author == this.author &&
          other.searchText == this.searchText &&
          other.publishedAt == this.publishedAt &&
          other.fetchedAt == this.fetchedAt);
}

class NewsItemsCompanion extends UpdateCompanion<NewsItemRow> {
  final Value<int> id;
  final Value<String> dedupeKey;
  final Value<String> sourceId;
  final Value<String> sourceName;
  final Value<String> externalId;
  final Value<String> title;
  final Value<String> summary;
  final Value<String> url;
  final Value<String> imageUrl;
  final Value<String> author;
  final Value<String> searchText;
  final Value<DateTime> publishedAt;
  final Value<DateTime> fetchedAt;
  const NewsItemsCompanion({
    this.id = const Value.absent(),
    this.dedupeKey = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.sourceName = const Value.absent(),
    this.externalId = const Value.absent(),
    this.title = const Value.absent(),
    this.summary = const Value.absent(),
    this.url = const Value.absent(),
    this.imageUrl = const Value.absent(),
    this.author = const Value.absent(),
    this.searchText = const Value.absent(),
    this.publishedAt = const Value.absent(),
    this.fetchedAt = const Value.absent(),
  });
  NewsItemsCompanion.insert({
    this.id = const Value.absent(),
    required String dedupeKey,
    required String sourceId,
    required String sourceName,
    this.externalId = const Value.absent(),
    required String title,
    this.summary = const Value.absent(),
    required String url,
    this.imageUrl = const Value.absent(),
    this.author = const Value.absent(),
    required String searchText,
    required DateTime publishedAt,
    required DateTime fetchedAt,
  }) : dedupeKey = Value(dedupeKey),
       sourceId = Value(sourceId),
       sourceName = Value(sourceName),
       title = Value(title),
       url = Value(url),
       searchText = Value(searchText),
       publishedAt = Value(publishedAt),
       fetchedAt = Value(fetchedAt);
  static Insertable<NewsItemRow> custom({
    Expression<int>? id,
    Expression<String>? dedupeKey,
    Expression<String>? sourceId,
    Expression<String>? sourceName,
    Expression<String>? externalId,
    Expression<String>? title,
    Expression<String>? summary,
    Expression<String>? url,
    Expression<String>? imageUrl,
    Expression<String>? author,
    Expression<String>? searchText,
    Expression<int>? publishedAt,
    Expression<int>? fetchedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (dedupeKey != null) 'dedupe_key': dedupeKey,
      if (sourceId != null) 'source_id': sourceId,
      if (sourceName != null) 'source_name': sourceName,
      if (externalId != null) 'external_id': externalId,
      if (title != null) 'title': title,
      if (summary != null) 'summary': summary,
      if (url != null) 'url': url,
      if (imageUrl != null) 'image_url': imageUrl,
      if (author != null) 'author': author,
      if (searchText != null) 'search_text': searchText,
      if (publishedAt != null) 'published_at': publishedAt,
      if (fetchedAt != null) 'fetched_at': fetchedAt,
    });
  }

  NewsItemsCompanion copyWith({
    Value<int>? id,
    Value<String>? dedupeKey,
    Value<String>? sourceId,
    Value<String>? sourceName,
    Value<String>? externalId,
    Value<String>? title,
    Value<String>? summary,
    Value<String>? url,
    Value<String>? imageUrl,
    Value<String>? author,
    Value<String>? searchText,
    Value<DateTime>? publishedAt,
    Value<DateTime>? fetchedAt,
  }) {
    return NewsItemsCompanion(
      id: id ?? this.id,
      dedupeKey: dedupeKey ?? this.dedupeKey,
      sourceId: sourceId ?? this.sourceId,
      sourceName: sourceName ?? this.sourceName,
      externalId: externalId ?? this.externalId,
      title: title ?? this.title,
      summary: summary ?? this.summary,
      url: url ?? this.url,
      imageUrl: imageUrl ?? this.imageUrl,
      author: author ?? this.author,
      searchText: searchText ?? this.searchText,
      publishedAt: publishedAt ?? this.publishedAt,
      fetchedAt: fetchedAt ?? this.fetchedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (dedupeKey.present) {
      map['dedupe_key'] = Variable<String>(dedupeKey.value);
    }
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (sourceName.present) {
      map['source_name'] = Variable<String>(sourceName.value);
    }
    if (externalId.present) {
      map['external_id'] = Variable<String>(externalId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (summary.present) {
      map['summary'] = Variable<String>(summary.value);
    }
    if (url.present) {
      map['url'] = Variable<String>(url.value);
    }
    if (imageUrl.present) {
      map['image_url'] = Variable<String>(imageUrl.value);
    }
    if (author.present) {
      map['author'] = Variable<String>(author.value);
    }
    if (searchText.present) {
      map['search_text'] = Variable<String>(searchText.value);
    }
    if (publishedAt.present) {
      map['published_at'] = Variable<int>(
        NewsItems.$converterpublishedAt.toSql(publishedAt.value),
      );
    }
    if (fetchedAt.present) {
      map['fetched_at'] = Variable<int>(
        NewsItems.$converterfetchedAt.toSql(fetchedAt.value),
      );
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NewsItemsCompanion(')
          ..write('id: $id, ')
          ..write('dedupeKey: $dedupeKey, ')
          ..write('sourceId: $sourceId, ')
          ..write('sourceName: $sourceName, ')
          ..write('externalId: $externalId, ')
          ..write('title: $title, ')
          ..write('summary: $summary, ')
          ..write('url: $url, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('author: $author, ')
          ..write('searchText: $searchText, ')
          ..write('publishedAt: $publishedAt, ')
          ..write('fetchedAt: $fetchedAt')
          ..write(')'))
        .toString();
  }
}

class NewsItemSports extends Table
    with TableInfo<NewsItemSports, NewsItemSportRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  NewsItemSports(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  late final GeneratedColumn<int> itemId = GeneratedColumn<int>(
    'item_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _sportMeta = const VerificationMeta('sport');
  late final GeneratedColumn<String> sport = GeneratedColumn<String>(
    'sport',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [itemId, sport];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'news_item_sports';
  @override
  VerificationContext validateIntegrity(
    Insertable<NewsItemSportRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('item_id')) {
      context.handle(
        _itemIdMeta,
        itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta),
      );
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    if (data.containsKey('sport')) {
      context.handle(
        _sportMeta,
        sport.isAcceptableOrUnknown(data['sport']!, _sportMeta),
      );
    } else if (isInserting) {
      context.missing(_sportMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {itemId, sport};
  @override
  NewsItemSportRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NewsItemSportRow(
      itemId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}item_id'],
      )!,
      sport: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sport'],
      )!,
    );
  }

  @override
  NewsItemSports createAlias(String alias) {
    return NewsItemSports(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const [
    'PRIMARY KEY(item_id, sport)',
    'FOREIGN KEY(item_id)REFERENCES news_items(id)ON DELETE CASCADE',
  ];
  @override
  bool get dontWriteConstraints => true;
}

class NewsItemSportRow extends DataClass
    implements Insertable<NewsItemSportRow> {
  final int itemId;
  final String sport;
  const NewsItemSportRow({required this.itemId, required this.sport});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['item_id'] = Variable<int>(itemId);
    map['sport'] = Variable<String>(sport);
    return map;
  }

  NewsItemSportsCompanion toCompanion(bool nullToAbsent) {
    return NewsItemSportsCompanion(itemId: Value(itemId), sport: Value(sport));
  }

  factory NewsItemSportRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NewsItemSportRow(
      itemId: serializer.fromJson<int>(json['item_id']),
      sport: serializer.fromJson<String>(json['sport']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'item_id': serializer.toJson<int>(itemId),
      'sport': serializer.toJson<String>(sport),
    };
  }

  NewsItemSportRow copyWith({int? itemId, String? sport}) => NewsItemSportRow(
    itemId: itemId ?? this.itemId,
    sport: sport ?? this.sport,
  );
  NewsItemSportRow copyWithCompanion(NewsItemSportsCompanion data) {
    return NewsItemSportRow(
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      sport: data.sport.present ? data.sport.value : this.sport,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NewsItemSportRow(')
          ..write('itemId: $itemId, ')
          ..write('sport: $sport')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(itemId, sport);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NewsItemSportRow &&
          other.itemId == this.itemId &&
          other.sport == this.sport);
}

class NewsItemSportsCompanion extends UpdateCompanion<NewsItemSportRow> {
  final Value<int> itemId;
  final Value<String> sport;
  final Value<int> rowid;
  const NewsItemSportsCompanion({
    this.itemId = const Value.absent(),
    this.sport = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NewsItemSportsCompanion.insert({
    required int itemId,
    required String sport,
    this.rowid = const Value.absent(),
  }) : itemId = Value(itemId),
       sport = Value(sport);
  static Insertable<NewsItemSportRow> custom({
    Expression<int>? itemId,
    Expression<String>? sport,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (itemId != null) 'item_id': itemId,
      if (sport != null) 'sport': sport,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NewsItemSportsCompanion copyWith({
    Value<int>? itemId,
    Value<String>? sport,
    Value<int>? rowid,
  }) {
    return NewsItemSportsCompanion(
      itemId: itemId ?? this.itemId,
      sport: sport ?? this.sport,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (itemId.present) {
      map['item_id'] = Variable<int>(itemId.value);
    }
    if (sport.present) {
      map['sport'] = Variable<String>(sport.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NewsItemSportsCompanion(')
          ..write('itemId: $itemId, ')
          ..write('sport: $sport, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class NewsItemSources extends Table
    with TableInfo<NewsItemSources, NewsItemSourceRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  NewsItemSources(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  late final GeneratedColumn<int> itemId = GeneratedColumn<int>(
    'item_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  late final GeneratedColumn<String> sourceId = GeneratedColumn<String>(
    'source_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [itemId, sourceId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'news_item_sources';
  @override
  VerificationContext validateIntegrity(
    Insertable<NewsItemSourceRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('item_id')) {
      context.handle(
        _itemIdMeta,
        itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta),
      );
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {itemId, sourceId};
  @override
  NewsItemSourceRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NewsItemSourceRow(
      itemId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}item_id'],
      )!,
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_id'],
      )!,
    );
  }

  @override
  NewsItemSources createAlias(String alias) {
    return NewsItemSources(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const [
    'PRIMARY KEY(item_id, source_id)',
    'FOREIGN KEY(item_id)REFERENCES news_items(id)ON DELETE CASCADE',
    'FOREIGN KEY(source_id)REFERENCES news_sources(id)',
  ];
  @override
  bool get dontWriteConstraints => true;
}

class NewsItemSourceRow extends DataClass
    implements Insertable<NewsItemSourceRow> {
  final int itemId;
  final String sourceId;
  const NewsItemSourceRow({required this.itemId, required this.sourceId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['item_id'] = Variable<int>(itemId);
    map['source_id'] = Variable<String>(sourceId);
    return map;
  }

  NewsItemSourcesCompanion toCompanion(bool nullToAbsent) {
    return NewsItemSourcesCompanion(
      itemId: Value(itemId),
      sourceId: Value(sourceId),
    );
  }

  factory NewsItemSourceRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NewsItemSourceRow(
      itemId: serializer.fromJson<int>(json['item_id']),
      sourceId: serializer.fromJson<String>(json['source_id']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'item_id': serializer.toJson<int>(itemId),
      'source_id': serializer.toJson<String>(sourceId),
    };
  }

  NewsItemSourceRow copyWith({int? itemId, String? sourceId}) =>
      NewsItemSourceRow(
        itemId: itemId ?? this.itemId,
        sourceId: sourceId ?? this.sourceId,
      );
  NewsItemSourceRow copyWithCompanion(NewsItemSourcesCompanion data) {
    return NewsItemSourceRow(
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NewsItemSourceRow(')
          ..write('itemId: $itemId, ')
          ..write('sourceId: $sourceId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(itemId, sourceId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NewsItemSourceRow &&
          other.itemId == this.itemId &&
          other.sourceId == this.sourceId);
}

class NewsItemSourcesCompanion extends UpdateCompanion<NewsItemSourceRow> {
  final Value<int> itemId;
  final Value<String> sourceId;
  final Value<int> rowid;
  const NewsItemSourcesCompanion({
    this.itemId = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NewsItemSourcesCompanion.insert({
    required int itemId,
    required String sourceId,
    this.rowid = const Value.absent(),
  }) : itemId = Value(itemId),
       sourceId = Value(sourceId);
  static Insertable<NewsItemSourceRow> custom({
    Expression<int>? itemId,
    Expression<String>? sourceId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (itemId != null) 'item_id': itemId,
      if (sourceId != null) 'source_id': sourceId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NewsItemSourcesCompanion copyWith({
    Value<int>? itemId,
    Value<String>? sourceId,
    Value<int>? rowid,
  }) {
    return NewsItemSourcesCompanion(
      itemId: itemId ?? this.itemId,
      sourceId: sourceId ?? this.sourceId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (itemId.present) {
      map['item_id'] = Variable<int>(itemId.value);
    }
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NewsItemSourcesCompanion(')
          ..write('itemId: $itemId, ')
          ..write('sourceId: $sourceId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$NewsDatabase extends GeneratedDatabase {
  _$NewsDatabase(QueryExecutor e) : super(e);
  late final NewsSources newsSources = NewsSources(this);
  late final NewsItems newsItems = NewsItems(this);
  late final NewsItemSports newsItemSports = NewsItemSports(this);
  late final NewsItemSources newsItemSources = NewsItemSources(this);
  late final Index idxNewsItemsPublished = Index(
    'idx_news_items_published',
    'CREATE INDEX IF NOT EXISTS idx_news_items_published ON news_items (published_at DESC)',
  );
  late final Index idxNewsSportsSport = Index(
    'idx_news_sports_sport',
    'CREATE INDEX IF NOT EXISTS idx_news_sports_sport ON news_item_sports (sport)',
  );
  late final Index idxNewsSourcesSource = Index(
    'idx_news_sources_source',
    'CREATE INDEX IF NOT EXISTS idx_news_sources_source ON news_item_sources (source_id)',
  );
  Future<int> upsertItem({
    required String dedupeKey,
    required String sourceId,
    required String sourceName,
    required String externalId,
    required String title,
    required String summary,
    required String url,
    required String imageUrl,
    required String author,
    required String searchText,
    required DateTime publishedAt,
    required DateTime fetchedAt,
    required bool publishedAtParsed,
  }) {
    return customInsert(
      'INSERT INTO news_items (dedupe_key, source_id, source_name, external_id, title, summary, url, image_url, author, search_text, published_at, fetched_at) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12) ON CONFLICT (dedupe_key) DO UPDATE SET title = excluded.title, summary = CASE WHEN excluded.summary <> \'\' THEN excluded.summary ELSE news_items.summary END, image_url = CASE WHEN excluded.image_url <> \'\' THEN excluded.image_url ELSE news_items.image_url END, author = CASE WHEN excluded.author <> \'\' THEN excluded.author ELSE news_items.author END, search_text = excluded.search_text, published_at = CASE WHEN ?13 THEN excluded.published_at ELSE news_items.published_at END, fetched_at = excluded.fetched_at',
      variables: [
        Variable<String>(dedupeKey),
        Variable<String>(sourceId),
        Variable<String>(sourceName),
        Variable<String>(externalId),
        Variable<String>(title),
        Variable<String>(summary),
        Variable<String>(url),
        Variable<String>(imageUrl),
        Variable<String>(author),
        Variable<String>(searchText),
        Variable<int>(NewsItems.$converterpublishedAt.toSql(publishedAt)),
        Variable<int>(NewsItems.$converterfetchedAt.toSql(fetchedAt)),
        Variable<bool>(publishedAtParsed),
      ],
      updates: {this.newsItems},
    );
  }

  Future<int> linkItemSport({
    required String sport,
    required String dedupeKey,
  }) {
    return customInsert(
      'INSERT OR IGNORE INTO news_item_sports (item_id, sport) SELECT id, ?1 FROM news_items WHERE dedupe_key = ?2',
      variables: [Variable<String>(sport), Variable<String>(dedupeKey)],
      updates: {this.newsItemSports},
    );
  }

  Future<int> linkItemSource({
    required String sourceId,
    required String dedupeKey,
  }) {
    return customInsert(
      'INSERT OR IGNORE INTO news_item_sources (item_id, source_id) SELECT id, ?1 FROM news_items WHERE dedupe_key = ?2',
      variables: [Variable<String>(sourceId), Variable<String>(dedupeKey)],
      updates: {this.newsItemSources},
    );
  }

  Selectable<int> countItems() {
    return customSelect(
      'SELECT COUNT(*) AS _c0 FROM news_items',
      variables: [],
      readsFrom: {this.newsItems},
    ).map((QueryRow row) => row.read<int>('_c0'));
  }

  Future<int> deleteExpiredItems({
    required DateTime cutoff,
    required int keep,
  }) {
    return customUpdate(
      'DELETE FROM news_items WHERE published_at < ?1 AND id NOT IN (SELECT id FROM news_items ORDER BY published_at DESC, id DESC LIMIT ?2)',
      variables: [
        Variable<int>(NewsItems.$converterpublishedAt.toSql(cutoff)),
        Variable<int>(keep),
      ],
      updates: {this.newsItems},
      updateKind: UpdateKind.delete,
    );
  }

  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    newsSources,
    newsItems,
    newsItemSports,
    newsItemSources,
    idxNewsItemsPublished,
    idxNewsSportsSport,
    idxNewsSourcesSource,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'news_items',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('news_item_sports', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'news_items',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('news_item_sources', kind: UpdateKind.delete)],
    ),
  ]);
}
