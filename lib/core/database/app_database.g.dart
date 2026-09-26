// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $VaultBindersTable extends VaultBinders
    with TableInfo<$VaultBindersTable, VaultBinder> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $VaultBindersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _collectionTypeMeta = const VerificationMeta(
    'collectionType',
  );
  @override
  late final GeneratedColumn<String> collectionType = GeneratedColumn<String>(
    'collection_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    collectionType,
    createdAt,
    isDeleted,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'vault_binders';
  @override
  VerificationContext validateIntegrity(
    Insertable<VaultBinder> instance, {
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
    if (data.containsKey('collection_type')) {
      context.handle(
        _collectionTypeMeta,
        collectionType.isAcceptableOrUnknown(
          data['collection_type']!,
          _collectionTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_collectionTypeMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  VaultBinder map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return VaultBinder(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      collectionType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}collection_type'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      ),
    );
  }

  @override
  $VaultBindersTable createAlias(String alias) {
    return $VaultBindersTable(attachedDatabase, alias);
  }
}

class VaultBinder extends DataClass implements Insertable<VaultBinder> {
  final String id;
  final String name;
  final String collectionType;
  final DateTime createdAt;
  final bool isDeleted;
  final DateTime? updatedAt;
  const VaultBinder({
    required this.id,
    required this.name,
    required this.collectionType,
    required this.createdAt,
    required this.isDeleted,
    this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['collection_type'] = Variable<String>(collectionType);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['is_deleted'] = Variable<bool>(isDeleted);
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    return map;
  }

  VaultBindersCompanion toCompanion(bool nullToAbsent) {
    return VaultBindersCompanion(
      id: Value(id),
      name: Value(name),
      collectionType: Value(collectionType),
      createdAt: Value(createdAt),
      isDeleted: Value(isDeleted),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
    );
  }

  factory VaultBinder.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return VaultBinder(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      collectionType: serializer.fromJson<String>(json['collectionType']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'collectionType': serializer.toJson<String>(collectionType),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
    };
  }

  VaultBinder copyWith({
    String? id,
    String? name,
    String? collectionType,
    DateTime? createdAt,
    bool? isDeleted,
    Value<DateTime?> updatedAt = const Value.absent(),
  }) => VaultBinder(
    id: id ?? this.id,
    name: name ?? this.name,
    collectionType: collectionType ?? this.collectionType,
    createdAt: createdAt ?? this.createdAt,
    isDeleted: isDeleted ?? this.isDeleted,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
  );
  VaultBinder copyWithCompanion(VaultBindersCompanion data) {
    return VaultBinder(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      collectionType: data.collectionType.present
          ? data.collectionType.value
          : this.collectionType,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('VaultBinder(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('collectionType: $collectionType, ')
          ..write('createdAt: $createdAt, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, collectionType, createdAt, isDeleted, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VaultBinder &&
          other.id == this.id &&
          other.name == this.name &&
          other.collectionType == this.collectionType &&
          other.createdAt == this.createdAt &&
          other.isDeleted == this.isDeleted &&
          other.updatedAt == this.updatedAt);
}

class VaultBindersCompanion extends UpdateCompanion<VaultBinder> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> collectionType;
  final Value<DateTime> createdAt;
  final Value<bool> isDeleted;
  final Value<DateTime?> updatedAt;
  final Value<int> rowid;
  const VaultBindersCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.collectionType = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  VaultBindersCompanion.insert({
    required String id,
    required String name,
    required String collectionType,
    required DateTime createdAt,
    this.isDeleted = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       collectionType = Value(collectionType),
       createdAt = Value(createdAt);
  static Insertable<VaultBinder> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? collectionType,
    Expression<DateTime>? createdAt,
    Expression<bool>? isDeleted,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (collectionType != null) 'collection_type': collectionType,
      if (createdAt != null) 'created_at': createdAt,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  VaultBindersCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? collectionType,
    Value<DateTime>? createdAt,
    Value<bool>? isDeleted,
    Value<DateTime?>? updatedAt,
    Value<int>? rowid,
  }) {
    return VaultBindersCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      collectionType: collectionType ?? this.collectionType,
      createdAt: createdAt ?? this.createdAt,
      isDeleted: isDeleted ?? this.isDeleted,
      updatedAt: updatedAt ?? this.updatedAt,
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
    if (collectionType.present) {
      map['collection_type'] = Variable<String>(collectionType.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('VaultBindersCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('collectionType: $collectionType, ')
          ..write('createdAt: $createdAt, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $VaultItemsTable extends VaultItems
    with TableInfo<$VaultItemsTable, VaultItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $VaultItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _collectionTypeMeta = const VerificationMeta(
    'collectionType',
  );
  @override
  late final GeneratedColumn<String> collectionType = GeneratedColumn<String>(
    'collection_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _setOrSeriesMeta = const VerificationMeta(
    'setOrSeries',
  );
  @override
  late final GeneratedColumn<String> setOrSeries = GeneratedColumn<String>(
    'set_or_series',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _imageUrlMeta = const VerificationMeta(
    'imageUrl',
  );
  @override
  late final GeneratedColumn<String> imageUrl = GeneratedColumn<String>(
    'image_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _flavorNameMeta = const VerificationMeta(
    'flavorName',
  );
  @override
  late final GeneratedColumn<String> flavorName = GeneratedColumn<String>(
    'flavor_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _acquiredPriceMeta = const VerificationMeta(
    'acquiredPrice',
  );
  @override
  late final GeneratedColumn<double> acquiredPrice = GeneratedColumn<double>(
    'acquired_price',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _acquiredDateMeta = const VerificationMeta(
    'acquiredDate',
  );
  @override
  late final GeneratedColumn<DateTime> acquiredDate = GeneratedColumn<DateTime>(
    'acquired_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _quantityMeta = const VerificationMeta(
    'quantity',
  );
  @override
  late final GeneratedColumn<int> quantity = GeneratedColumn<int>(
    'quantity',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _conditionMeta = const VerificationMeta(
    'condition',
  );
  @override
  late final GeneratedColumn<String> condition = GeneratedColumn<String>(
    'condition',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isGradedMeta = const VerificationMeta(
    'isGraded',
  );
  @override
  late final GeneratedColumn<bool> isGraded = GeneratedColumn<bool>(
    'is_graded',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_graded" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isAlteredMeta = const VerificationMeta(
    'isAltered',
  );
  @override
  late final GeneratedColumn<bool> isAltered = GeneratedColumn<bool>(
    'is_altered',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_altered" IN (0, 1))',
    ),
    clientDefault: () => false,
  );
  static const VerificationMeta _isMisprintMeta = const VerificationMeta(
    'isMisprint',
  );
  @override
  late final GeneratedColumn<bool> isMisprint = GeneratedColumn<bool>(
    'is_misprint',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_misprint" IN (0, 1))',
    ),
    clientDefault: () => false,
  );
  static const VerificationMeta _isSignedMeta = const VerificationMeta(
    'isSigned',
  );
  @override
  late final GeneratedColumn<bool> isSigned = GeneratedColumn<bool>(
    'is_signed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_signed" IN (0, 1))',
    ),
    clientDefault: () => false,
  );
  static const VerificationMeta _personalNotesMeta = const VerificationMeta(
    'personalNotes',
  );
  @override
  late final GeneratedColumn<String> personalNotes = GeneratedColumn<String>(
    'personal_notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dateObtainedMeta = const VerificationMeta(
    'dateObtained',
  );
  @override
  late final GeneratedColumn<DateTime> dateObtained = GeneratedColumn<DateTime>(
    'date_obtained',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _purchasePriceMeta = const VerificationMeta(
    'purchasePrice',
  );
  @override
  late final GeneratedColumn<double> purchasePrice = GeneratedColumn<double>(
    'purchase_price',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _binderPageMeta = const VerificationMeta(
    'binderPage',
  );
  @override
  late final GeneratedColumn<int> binderPage = GeneratedColumn<int>(
    'binder_page',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _binderSlotMeta = const VerificationMeta(
    'binderSlot',
  );
  @override
  late final GeneratedColumn<String> binderSlot = GeneratedColumn<String>(
    'binder_slot',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _protectionStatusMeta = const VerificationMeta(
    'protectionStatus',
  );
  @override
  late final GeneratedColumn<String> protectionStatus = GeneratedColumn<String>(
    'protection_status',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('Sleeved'),
  );
  static const VerificationMeta _primaryBinderIdMeta = const VerificationMeta(
    'primaryBinderId',
  );
  @override
  late final GeneratedColumn<String> primaryBinderId = GeneratedColumn<String>(
    'primary_binder_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES vault_binders (id)',
    ),
  );
  static const VerificationMeta _currentMarketPriceMeta =
      const VerificationMeta('currentMarketPrice');
  @override
  late final GeneratedColumn<double> currentMarketPrice =
      GeneratedColumn<double>(
        'current_market_price',
        aliasedName,
        false,
        type: DriftSqlType.double,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _lastPriceUpdateMeta = const VerificationMeta(
    'lastPriceUpdate',
  );
  @override
  late final GeneratedColumn<DateTime> lastPriceUpdate =
      GeneratedColumn<DateTime>(
        'last_price_update',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _dynamicDataMeta = const VerificationMeta(
    'dynamicData',
  );
  @override
  late final GeneratedColumn<String> dynamicData = GeneratedColumn<String>(
    'dynamic_data',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    collectionType,
    name,
    setOrSeries,
    imageUrl,
    flavorName,
    acquiredPrice,
    acquiredDate,
    quantity,
    condition,
    isGraded,
    isAltered,
    isMisprint,
    isSigned,
    personalNotes,
    dateObtained,
    purchasePrice,
    binderPage,
    binderSlot,
    notes,
    protectionStatus,
    primaryBinderId,
    currentMarketPrice,
    lastPriceUpdate,
    dynamicData,
    isDeleted,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'vault_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<VaultItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('collection_type')) {
      context.handle(
        _collectionTypeMeta,
        collectionType.isAcceptableOrUnknown(
          data['collection_type']!,
          _collectionTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_collectionTypeMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('set_or_series')) {
      context.handle(
        _setOrSeriesMeta,
        setOrSeries.isAcceptableOrUnknown(
          data['set_or_series']!,
          _setOrSeriesMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_setOrSeriesMeta);
    }
    if (data.containsKey('image_url')) {
      context.handle(
        _imageUrlMeta,
        imageUrl.isAcceptableOrUnknown(data['image_url']!, _imageUrlMeta),
      );
    } else if (isInserting) {
      context.missing(_imageUrlMeta);
    }
    if (data.containsKey('flavor_name')) {
      context.handle(
        _flavorNameMeta,
        flavorName.isAcceptableOrUnknown(data['flavor_name']!, _flavorNameMeta),
      );
    }
    if (data.containsKey('acquired_price')) {
      context.handle(
        _acquiredPriceMeta,
        acquiredPrice.isAcceptableOrUnknown(
          data['acquired_price']!,
          _acquiredPriceMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_acquiredPriceMeta);
    }
    if (data.containsKey('acquired_date')) {
      context.handle(
        _acquiredDateMeta,
        acquiredDate.isAcceptableOrUnknown(
          data['acquired_date']!,
          _acquiredDateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_acquiredDateMeta);
    }
    if (data.containsKey('quantity')) {
      context.handle(
        _quantityMeta,
        quantity.isAcceptableOrUnknown(data['quantity']!, _quantityMeta),
      );
    }
    if (data.containsKey('condition')) {
      context.handle(
        _conditionMeta,
        condition.isAcceptableOrUnknown(data['condition']!, _conditionMeta),
      );
    } else if (isInserting) {
      context.missing(_conditionMeta);
    }
    if (data.containsKey('is_graded')) {
      context.handle(
        _isGradedMeta,
        isGraded.isAcceptableOrUnknown(data['is_graded']!, _isGradedMeta),
      );
    }
    if (data.containsKey('is_altered')) {
      context.handle(
        _isAlteredMeta,
        isAltered.isAcceptableOrUnknown(data['is_altered']!, _isAlteredMeta),
      );
    }
    if (data.containsKey('is_misprint')) {
      context.handle(
        _isMisprintMeta,
        isMisprint.isAcceptableOrUnknown(data['is_misprint']!, _isMisprintMeta),
      );
    }
    if (data.containsKey('is_signed')) {
      context.handle(
        _isSignedMeta,
        isSigned.isAcceptableOrUnknown(data['is_signed']!, _isSignedMeta),
      );
    }
    if (data.containsKey('personal_notes')) {
      context.handle(
        _personalNotesMeta,
        personalNotes.isAcceptableOrUnknown(
          data['personal_notes']!,
          _personalNotesMeta,
        ),
      );
    }
    if (data.containsKey('date_obtained')) {
      context.handle(
        _dateObtainedMeta,
        dateObtained.isAcceptableOrUnknown(
          data['date_obtained']!,
          _dateObtainedMeta,
        ),
      );
    }
    if (data.containsKey('purchase_price')) {
      context.handle(
        _purchasePriceMeta,
        purchasePrice.isAcceptableOrUnknown(
          data['purchase_price']!,
          _purchasePriceMeta,
        ),
      );
    }
    if (data.containsKey('binder_page')) {
      context.handle(
        _binderPageMeta,
        binderPage.isAcceptableOrUnknown(data['binder_page']!, _binderPageMeta),
      );
    }
    if (data.containsKey('binder_slot')) {
      context.handle(
        _binderSlotMeta,
        binderSlot.isAcceptableOrUnknown(data['binder_slot']!, _binderSlotMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('protection_status')) {
      context.handle(
        _protectionStatusMeta,
        protectionStatus.isAcceptableOrUnknown(
          data['protection_status']!,
          _protectionStatusMeta,
        ),
      );
    }
    if (data.containsKey('primary_binder_id')) {
      context.handle(
        _primaryBinderIdMeta,
        primaryBinderId.isAcceptableOrUnknown(
          data['primary_binder_id']!,
          _primaryBinderIdMeta,
        ),
      );
    }
    if (data.containsKey('current_market_price')) {
      context.handle(
        _currentMarketPriceMeta,
        currentMarketPrice.isAcceptableOrUnknown(
          data['current_market_price']!,
          _currentMarketPriceMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_currentMarketPriceMeta);
    }
    if (data.containsKey('last_price_update')) {
      context.handle(
        _lastPriceUpdateMeta,
        lastPriceUpdate.isAcceptableOrUnknown(
          data['last_price_update']!,
          _lastPriceUpdateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastPriceUpdateMeta);
    }
    if (data.containsKey('dynamic_data')) {
      context.handle(
        _dynamicDataMeta,
        dynamicData.isAcceptableOrUnknown(
          data['dynamic_data']!,
          _dynamicDataMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_dynamicDataMeta);
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  VaultItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return VaultItem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      collectionType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}collection_type'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      setOrSeries: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}set_or_series'],
      )!,
      imageUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_url'],
      )!,
      flavorName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}flavor_name'],
      ),
      acquiredPrice: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}acquired_price'],
      )!,
      acquiredDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}acquired_date'],
      )!,
      quantity: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}quantity'],
      )!,
      condition: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}condition'],
      )!,
      isGraded: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_graded'],
      )!,
      isAltered: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_altered'],
      )!,
      isMisprint: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_misprint'],
      )!,
      isSigned: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_signed'],
      )!,
      personalNotes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}personal_notes'],
      ),
      dateObtained: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date_obtained'],
      ),
      purchasePrice: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}purchase_price'],
      ),
      binderPage: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}binder_page'],
      ),
      binderSlot: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}binder_slot'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      protectionStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}protection_status'],
      ),
      primaryBinderId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}primary_binder_id'],
      ),
      currentMarketPrice: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}current_market_price'],
      )!,
      lastPriceUpdate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_price_update'],
      )!,
      dynamicData: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dynamic_data'],
      )!,
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      ),
    );
  }

  @override
  $VaultItemsTable createAlias(String alias) {
    return $VaultItemsTable(attachedDatabase, alias);
  }
}

class VaultItem extends DataClass implements Insertable<VaultItem> {
  final String id;
  final String collectionType;
  final String name;
  final String setOrSeries;
  final String imageUrl;
  final String? flavorName;
  final double acquiredPrice;
  final DateTime acquiredDate;
  final int quantity;
  final String condition;
  final bool isGraded;
  final bool isAltered;
  final bool isMisprint;
  final bool isSigned;
  final String? personalNotes;
  final DateTime? dateObtained;
  final double? purchasePrice;
  final int? binderPage;
  final String? binderSlot;
  final String? notes;
  final String? protectionStatus;
  final String? primaryBinderId;
  final double currentMarketPrice;
  final DateTime lastPriceUpdate;
  final String dynamicData;
  final bool isDeleted;
  final DateTime? updatedAt;
  const VaultItem({
    required this.id,
    required this.collectionType,
    required this.name,
    required this.setOrSeries,
    required this.imageUrl,
    this.flavorName,
    required this.acquiredPrice,
    required this.acquiredDate,
    required this.quantity,
    required this.condition,
    required this.isGraded,
    required this.isAltered,
    required this.isMisprint,
    required this.isSigned,
    this.personalNotes,
    this.dateObtained,
    this.purchasePrice,
    this.binderPage,
    this.binderSlot,
    this.notes,
    this.protectionStatus,
    this.primaryBinderId,
    required this.currentMarketPrice,
    required this.lastPriceUpdate,
    required this.dynamicData,
    required this.isDeleted,
    this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['collection_type'] = Variable<String>(collectionType);
    map['name'] = Variable<String>(name);
    map['set_or_series'] = Variable<String>(setOrSeries);
    map['image_url'] = Variable<String>(imageUrl);
    if (!nullToAbsent || flavorName != null) {
      map['flavor_name'] = Variable<String>(flavorName);
    }
    map['acquired_price'] = Variable<double>(acquiredPrice);
    map['acquired_date'] = Variable<DateTime>(acquiredDate);
    map['quantity'] = Variable<int>(quantity);
    map['condition'] = Variable<String>(condition);
    map['is_graded'] = Variable<bool>(isGraded);
    map['is_altered'] = Variable<bool>(isAltered);
    map['is_misprint'] = Variable<bool>(isMisprint);
    map['is_signed'] = Variable<bool>(isSigned);
    if (!nullToAbsent || personalNotes != null) {
      map['personal_notes'] = Variable<String>(personalNotes);
    }
    if (!nullToAbsent || dateObtained != null) {
      map['date_obtained'] = Variable<DateTime>(dateObtained);
    }
    if (!nullToAbsent || purchasePrice != null) {
      map['purchase_price'] = Variable<double>(purchasePrice);
    }
    if (!nullToAbsent || binderPage != null) {
      map['binder_page'] = Variable<int>(binderPage);
    }
    if (!nullToAbsent || binderSlot != null) {
      map['binder_slot'] = Variable<String>(binderSlot);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    if (!nullToAbsent || protectionStatus != null) {
      map['protection_status'] = Variable<String>(protectionStatus);
    }
    if (!nullToAbsent || primaryBinderId != null) {
      map['primary_binder_id'] = Variable<String>(primaryBinderId);
    }
    map['current_market_price'] = Variable<double>(currentMarketPrice);
    map['last_price_update'] = Variable<DateTime>(lastPriceUpdate);
    map['dynamic_data'] = Variable<String>(dynamicData);
    map['is_deleted'] = Variable<bool>(isDeleted);
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    return map;
  }

  VaultItemsCompanion toCompanion(bool nullToAbsent) {
    return VaultItemsCompanion(
      id: Value(id),
      collectionType: Value(collectionType),
      name: Value(name),
      setOrSeries: Value(setOrSeries),
      imageUrl: Value(imageUrl),
      flavorName: flavorName == null && nullToAbsent
          ? const Value.absent()
          : Value(flavorName),
      acquiredPrice: Value(acquiredPrice),
      acquiredDate: Value(acquiredDate),
      quantity: Value(quantity),
      condition: Value(condition),
      isGraded: Value(isGraded),
      isAltered: Value(isAltered),
      isMisprint: Value(isMisprint),
      isSigned: Value(isSigned),
      personalNotes: personalNotes == null && nullToAbsent
          ? const Value.absent()
          : Value(personalNotes),
      dateObtained: dateObtained == null && nullToAbsent
          ? const Value.absent()
          : Value(dateObtained),
      purchasePrice: purchasePrice == null && nullToAbsent
          ? const Value.absent()
          : Value(purchasePrice),
      binderPage: binderPage == null && nullToAbsent
          ? const Value.absent()
          : Value(binderPage),
      binderSlot: binderSlot == null && nullToAbsent
          ? const Value.absent()
          : Value(binderSlot),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      protectionStatus: protectionStatus == null && nullToAbsent
          ? const Value.absent()
          : Value(protectionStatus),
      primaryBinderId: primaryBinderId == null && nullToAbsent
          ? const Value.absent()
          : Value(primaryBinderId),
      currentMarketPrice: Value(currentMarketPrice),
      lastPriceUpdate: Value(lastPriceUpdate),
      dynamicData: Value(dynamicData),
      isDeleted: Value(isDeleted),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
    );
  }

  factory VaultItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return VaultItem(
      id: serializer.fromJson<String>(json['id']),
      collectionType: serializer.fromJson<String>(json['collectionType']),
      name: serializer.fromJson<String>(json['name']),
      setOrSeries: serializer.fromJson<String>(json['setOrSeries']),
      imageUrl: serializer.fromJson<String>(json['imageUrl']),
      flavorName: serializer.fromJson<String?>(json['flavorName']),
      acquiredPrice: serializer.fromJson<double>(json['acquiredPrice']),
      acquiredDate: serializer.fromJson<DateTime>(json['acquiredDate']),
      quantity: serializer.fromJson<int>(json['quantity']),
      condition: serializer.fromJson<String>(json['condition']),
      isGraded: serializer.fromJson<bool>(json['isGraded']),
      isAltered: serializer.fromJson<bool>(json['isAltered']),
      isMisprint: serializer.fromJson<bool>(json['isMisprint']),
      isSigned: serializer.fromJson<bool>(json['isSigned']),
      personalNotes: serializer.fromJson<String?>(json['personalNotes']),
      dateObtained: serializer.fromJson<DateTime?>(json['dateObtained']),
      purchasePrice: serializer.fromJson<double?>(json['purchasePrice']),
      binderPage: serializer.fromJson<int?>(json['binderPage']),
      binderSlot: serializer.fromJson<String?>(json['binderSlot']),
      notes: serializer.fromJson<String?>(json['notes']),
      protectionStatus: serializer.fromJson<String?>(json['protectionStatus']),
      primaryBinderId: serializer.fromJson<String?>(json['primaryBinderId']),
      currentMarketPrice: serializer.fromJson<double>(
        json['currentMarketPrice'],
      ),
      lastPriceUpdate: serializer.fromJson<DateTime>(json['lastPriceUpdate']),
      dynamicData: serializer.fromJson<String>(json['dynamicData']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'collectionType': serializer.toJson<String>(collectionType),
      'name': serializer.toJson<String>(name),
      'setOrSeries': serializer.toJson<String>(setOrSeries),
      'imageUrl': serializer.toJson<String>(imageUrl),
      'flavorName': serializer.toJson<String?>(flavorName),
      'acquiredPrice': serializer.toJson<double>(acquiredPrice),
      'acquiredDate': serializer.toJson<DateTime>(acquiredDate),
      'quantity': serializer.toJson<int>(quantity),
      'condition': serializer.toJson<String>(condition),
      'isGraded': serializer.toJson<bool>(isGraded),
      'isAltered': serializer.toJson<bool>(isAltered),
      'isMisprint': serializer.toJson<bool>(isMisprint),
      'isSigned': serializer.toJson<bool>(isSigned),
      'personalNotes': serializer.toJson<String?>(personalNotes),
      'dateObtained': serializer.toJson<DateTime?>(dateObtained),
      'purchasePrice': serializer.toJson<double?>(purchasePrice),
      'binderPage': serializer.toJson<int?>(binderPage),
      'binderSlot': serializer.toJson<String?>(binderSlot),
      'notes': serializer.toJson<String?>(notes),
      'protectionStatus': serializer.toJson<String?>(protectionStatus),
      'primaryBinderId': serializer.toJson<String?>(primaryBinderId),
      'currentMarketPrice': serializer.toJson<double>(currentMarketPrice),
      'lastPriceUpdate': serializer.toJson<DateTime>(lastPriceUpdate),
      'dynamicData': serializer.toJson<String>(dynamicData),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
    };
  }

  VaultItem copyWith({
    String? id,
    String? collectionType,
    String? name,
    String? setOrSeries,
    String? imageUrl,
    Value<String?> flavorName = const Value.absent(),
    double? acquiredPrice,
    DateTime? acquiredDate,
    int? quantity,
    String? condition,
    bool? isGraded,
    bool? isAltered,
    bool? isMisprint,
    bool? isSigned,
    Value<String?> personalNotes = const Value.absent(),
    Value<DateTime?> dateObtained = const Value.absent(),
    Value<double?> purchasePrice = const Value.absent(),
    Value<int?> binderPage = const Value.absent(),
    Value<String?> binderSlot = const Value.absent(),
    Value<String?> notes = const Value.absent(),
    Value<String?> protectionStatus = const Value.absent(),
    Value<String?> primaryBinderId = const Value.absent(),
    double? currentMarketPrice,
    DateTime? lastPriceUpdate,
    String? dynamicData,
    bool? isDeleted,
    Value<DateTime?> updatedAt = const Value.absent(),
  }) => VaultItem(
    id: id ?? this.id,
    collectionType: collectionType ?? this.collectionType,
    name: name ?? this.name,
    setOrSeries: setOrSeries ?? this.setOrSeries,
    imageUrl: imageUrl ?? this.imageUrl,
    flavorName: flavorName.present ? flavorName.value : this.flavorName,
    acquiredPrice: acquiredPrice ?? this.acquiredPrice,
    acquiredDate: acquiredDate ?? this.acquiredDate,
    quantity: quantity ?? this.quantity,
    condition: condition ?? this.condition,
    isGraded: isGraded ?? this.isGraded,
    isAltered: isAltered ?? this.isAltered,
    isMisprint: isMisprint ?? this.isMisprint,
    isSigned: isSigned ?? this.isSigned,
    personalNotes: personalNotes.present
        ? personalNotes.value
        : this.personalNotes,
    dateObtained: dateObtained.present ? dateObtained.value : this.dateObtained,
    purchasePrice: purchasePrice.present
        ? purchasePrice.value
        : this.purchasePrice,
    binderPage: binderPage.present ? binderPage.value : this.binderPage,
    binderSlot: binderSlot.present ? binderSlot.value : this.binderSlot,
    notes: notes.present ? notes.value : this.notes,
    protectionStatus: protectionStatus.present
        ? protectionStatus.value
        : this.protectionStatus,
    primaryBinderId: primaryBinderId.present
        ? primaryBinderId.value
        : this.primaryBinderId,
    currentMarketPrice: currentMarketPrice ?? this.currentMarketPrice,
    lastPriceUpdate: lastPriceUpdate ?? this.lastPriceUpdate,
    dynamicData: dynamicData ?? this.dynamicData,
    isDeleted: isDeleted ?? this.isDeleted,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
  );
  VaultItem copyWithCompanion(VaultItemsCompanion data) {
    return VaultItem(
      id: data.id.present ? data.id.value : this.id,
      collectionType: data.collectionType.present
          ? data.collectionType.value
          : this.collectionType,
      name: data.name.present ? data.name.value : this.name,
      setOrSeries: data.setOrSeries.present
          ? data.setOrSeries.value
          : this.setOrSeries,
      imageUrl: data.imageUrl.present ? data.imageUrl.value : this.imageUrl,
      flavorName: data.flavorName.present
          ? data.flavorName.value
          : this.flavorName,
      acquiredPrice: data.acquiredPrice.present
          ? data.acquiredPrice.value
          : this.acquiredPrice,
      acquiredDate: data.acquiredDate.present
          ? data.acquiredDate.value
          : this.acquiredDate,
      quantity: data.quantity.present ? data.quantity.value : this.quantity,
      condition: data.condition.present ? data.condition.value : this.condition,
      isGraded: data.isGraded.present ? data.isGraded.value : this.isGraded,
      isAltered: data.isAltered.present ? data.isAltered.value : this.isAltered,
      isMisprint: data.isMisprint.present
          ? data.isMisprint.value
          : this.isMisprint,
      isSigned: data.isSigned.present ? data.isSigned.value : this.isSigned,
      personalNotes: data.personalNotes.present
          ? data.personalNotes.value
          : this.personalNotes,
      dateObtained: data.dateObtained.present
          ? data.dateObtained.value
          : this.dateObtained,
      purchasePrice: data.purchasePrice.present
          ? data.purchasePrice.value
          : this.purchasePrice,
      binderPage: data.binderPage.present
          ? data.binderPage.value
          : this.binderPage,
      binderSlot: data.binderSlot.present
          ? data.binderSlot.value
          : this.binderSlot,
      notes: data.notes.present ? data.notes.value : this.notes,
      protectionStatus: data.protectionStatus.present
          ? data.protectionStatus.value
          : this.protectionStatus,
      primaryBinderId: data.primaryBinderId.present
          ? data.primaryBinderId.value
          : this.primaryBinderId,
      currentMarketPrice: data.currentMarketPrice.present
          ? data.currentMarketPrice.value
          : this.currentMarketPrice,
      lastPriceUpdate: data.lastPriceUpdate.present
          ? data.lastPriceUpdate.value
          : this.lastPriceUpdate,
      dynamicData: data.dynamicData.present
          ? data.dynamicData.value
          : this.dynamicData,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('VaultItem(')
          ..write('id: $id, ')
          ..write('collectionType: $collectionType, ')
          ..write('name: $name, ')
          ..write('setOrSeries: $setOrSeries, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('flavorName: $flavorName, ')
          ..write('acquiredPrice: $acquiredPrice, ')
          ..write('acquiredDate: $acquiredDate, ')
          ..write('quantity: $quantity, ')
          ..write('condition: $condition, ')
          ..write('isGraded: $isGraded, ')
          ..write('isAltered: $isAltered, ')
          ..write('isMisprint: $isMisprint, ')
          ..write('isSigned: $isSigned, ')
          ..write('personalNotes: $personalNotes, ')
          ..write('dateObtained: $dateObtained, ')
          ..write('purchasePrice: $purchasePrice, ')
          ..write('binderPage: $binderPage, ')
          ..write('binderSlot: $binderSlot, ')
          ..write('notes: $notes, ')
          ..write('protectionStatus: $protectionStatus, ')
          ..write('primaryBinderId: $primaryBinderId, ')
          ..write('currentMarketPrice: $currentMarketPrice, ')
          ..write('lastPriceUpdate: $lastPriceUpdate, ')
          ..write('dynamicData: $dynamicData, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    collectionType,
    name,
    setOrSeries,
    imageUrl,
    flavorName,
    acquiredPrice,
    acquiredDate,
    quantity,
    condition,
    isGraded,
    isAltered,
    isMisprint,
    isSigned,
    personalNotes,
    dateObtained,
    purchasePrice,
    binderPage,
    binderSlot,
    notes,
    protectionStatus,
    primaryBinderId,
    currentMarketPrice,
    lastPriceUpdate,
    dynamicData,
    isDeleted,
    updatedAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VaultItem &&
          other.id == this.id &&
          other.collectionType == this.collectionType &&
          other.name == this.name &&
          other.setOrSeries == this.setOrSeries &&
          other.imageUrl == this.imageUrl &&
          other.flavorName == this.flavorName &&
          other.acquiredPrice == this.acquiredPrice &&
          other.acquiredDate == this.acquiredDate &&
          other.quantity == this.quantity &&
          other.condition == this.condition &&
          other.isGraded == this.isGraded &&
          other.isAltered == this.isAltered &&
          other.isMisprint == this.isMisprint &&
          other.isSigned == this.isSigned &&
          other.personalNotes == this.personalNotes &&
          other.dateObtained == this.dateObtained &&
          other.purchasePrice == this.purchasePrice &&
          other.binderPage == this.binderPage &&
          other.binderSlot == this.binderSlot &&
          other.notes == this.notes &&
          other.protectionStatus == this.protectionStatus &&
          other.primaryBinderId == this.primaryBinderId &&
          other.currentMarketPrice == this.currentMarketPrice &&
          other.lastPriceUpdate == this.lastPriceUpdate &&
          other.dynamicData == this.dynamicData &&
          other.isDeleted == this.isDeleted &&
          other.updatedAt == this.updatedAt);
}

class VaultItemsCompanion extends UpdateCompanion<VaultItem> {
  final Value<String> id;
  final Value<String> collectionType;
  final Value<String> name;
  final Value<String> setOrSeries;
  final Value<String> imageUrl;
  final Value<String?> flavorName;
  final Value<double> acquiredPrice;
  final Value<DateTime> acquiredDate;
  final Value<int> quantity;
  final Value<String> condition;
  final Value<bool> isGraded;
  final Value<bool> isAltered;
  final Value<bool> isMisprint;
  final Value<bool> isSigned;
  final Value<String?> personalNotes;
  final Value<DateTime?> dateObtained;
  final Value<double?> purchasePrice;
  final Value<int?> binderPage;
  final Value<String?> binderSlot;
  final Value<String?> notes;
  final Value<String?> protectionStatus;
  final Value<String?> primaryBinderId;
  final Value<double> currentMarketPrice;
  final Value<DateTime> lastPriceUpdate;
  final Value<String> dynamicData;
  final Value<bool> isDeleted;
  final Value<DateTime?> updatedAt;
  final Value<int> rowid;
  const VaultItemsCompanion({
    this.id = const Value.absent(),
    this.collectionType = const Value.absent(),
    this.name = const Value.absent(),
    this.setOrSeries = const Value.absent(),
    this.imageUrl = const Value.absent(),
    this.flavorName = const Value.absent(),
    this.acquiredPrice = const Value.absent(),
    this.acquiredDate = const Value.absent(),
    this.quantity = const Value.absent(),
    this.condition = const Value.absent(),
    this.isGraded = const Value.absent(),
    this.isAltered = const Value.absent(),
    this.isMisprint = const Value.absent(),
    this.isSigned = const Value.absent(),
    this.personalNotes = const Value.absent(),
    this.dateObtained = const Value.absent(),
    this.purchasePrice = const Value.absent(),
    this.binderPage = const Value.absent(),
    this.binderSlot = const Value.absent(),
    this.notes = const Value.absent(),
    this.protectionStatus = const Value.absent(),
    this.primaryBinderId = const Value.absent(),
    this.currentMarketPrice = const Value.absent(),
    this.lastPriceUpdate = const Value.absent(),
    this.dynamicData = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  VaultItemsCompanion.insert({
    required String id,
    required String collectionType,
    required String name,
    required String setOrSeries,
    required String imageUrl,
    this.flavorName = const Value.absent(),
    required double acquiredPrice,
    required DateTime acquiredDate,
    this.quantity = const Value.absent(),
    required String condition,
    this.isGraded = const Value.absent(),
    this.isAltered = const Value.absent(),
    this.isMisprint = const Value.absent(),
    this.isSigned = const Value.absent(),
    this.personalNotes = const Value.absent(),
    this.dateObtained = const Value.absent(),
    this.purchasePrice = const Value.absent(),
    this.binderPage = const Value.absent(),
    this.binderSlot = const Value.absent(),
    this.notes = const Value.absent(),
    this.protectionStatus = const Value.absent(),
    this.primaryBinderId = const Value.absent(),
    required double currentMarketPrice,
    required DateTime lastPriceUpdate,
    required String dynamicData,
    this.isDeleted = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       collectionType = Value(collectionType),
       name = Value(name),
       setOrSeries = Value(setOrSeries),
       imageUrl = Value(imageUrl),
       acquiredPrice = Value(acquiredPrice),
       acquiredDate = Value(acquiredDate),
       condition = Value(condition),
       currentMarketPrice = Value(currentMarketPrice),
       lastPriceUpdate = Value(lastPriceUpdate),
       dynamicData = Value(dynamicData);
  static Insertable<VaultItem> custom({
    Expression<String>? id,
    Expression<String>? collectionType,
    Expression<String>? name,
    Expression<String>? setOrSeries,
    Expression<String>? imageUrl,
    Expression<String>? flavorName,
    Expression<double>? acquiredPrice,
    Expression<DateTime>? acquiredDate,
    Expression<int>? quantity,
    Expression<String>? condition,
    Expression<bool>? isGraded,
    Expression<bool>? isAltered,
    Expression<bool>? isMisprint,
    Expression<bool>? isSigned,
    Expression<String>? personalNotes,
    Expression<DateTime>? dateObtained,
    Expression<double>? purchasePrice,
    Expression<int>? binderPage,
    Expression<String>? binderSlot,
    Expression<String>? notes,
    Expression<String>? protectionStatus,
    Expression<String>? primaryBinderId,
    Expression<double>? currentMarketPrice,
    Expression<DateTime>? lastPriceUpdate,
    Expression<String>? dynamicData,
    Expression<bool>? isDeleted,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (collectionType != null) 'collection_type': collectionType,
      if (name != null) 'name': name,
      if (setOrSeries != null) 'set_or_series': setOrSeries,
      if (imageUrl != null) 'image_url': imageUrl,
      if (flavorName != null) 'flavor_name': flavorName,
      if (acquiredPrice != null) 'acquired_price': acquiredPrice,
      if (acquiredDate != null) 'acquired_date': acquiredDate,
      if (quantity != null) 'quantity': quantity,
      if (condition != null) 'condition': condition,
      if (isGraded != null) 'is_graded': isGraded,
      if (isAltered != null) 'is_altered': isAltered,
      if (isMisprint != null) 'is_misprint': isMisprint,
      if (isSigned != null) 'is_signed': isSigned,
      if (personalNotes != null) 'personal_notes': personalNotes,
      if (dateObtained != null) 'date_obtained': dateObtained,
      if (purchasePrice != null) 'purchase_price': purchasePrice,
      if (binderPage != null) 'binder_page': binderPage,
      if (binderSlot != null) 'binder_slot': binderSlot,
      if (notes != null) 'notes': notes,
      if (protectionStatus != null) 'protection_status': protectionStatus,
      if (primaryBinderId != null) 'primary_binder_id': primaryBinderId,
      if (currentMarketPrice != null)
        'current_market_price': currentMarketPrice,
      if (lastPriceUpdate != null) 'last_price_update': lastPriceUpdate,
      if (dynamicData != null) 'dynamic_data': dynamicData,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  VaultItemsCompanion copyWith({
    Value<String>? id,
    Value<String>? collectionType,
    Value<String>? name,
    Value<String>? setOrSeries,
    Value<String>? imageUrl,
    Value<String?>? flavorName,
    Value<double>? acquiredPrice,
    Value<DateTime>? acquiredDate,
    Value<int>? quantity,
    Value<String>? condition,
    Value<bool>? isGraded,
    Value<bool>? isAltered,
    Value<bool>? isMisprint,
    Value<bool>? isSigned,
    Value<String?>? personalNotes,
    Value<DateTime?>? dateObtained,
    Value<double?>? purchasePrice,
    Value<int?>? binderPage,
    Value<String?>? binderSlot,
    Value<String?>? notes,
    Value<String?>? protectionStatus,
    Value<String?>? primaryBinderId,
    Value<double>? currentMarketPrice,
    Value<DateTime>? lastPriceUpdate,
    Value<String>? dynamicData,
    Value<bool>? isDeleted,
    Value<DateTime?>? updatedAt,
    Value<int>? rowid,
  }) {
    return VaultItemsCompanion(
      id: id ?? this.id,
      collectionType: collectionType ?? this.collectionType,
      name: name ?? this.name,
      setOrSeries: setOrSeries ?? this.setOrSeries,
      imageUrl: imageUrl ?? this.imageUrl,
      flavorName: flavorName ?? this.flavorName,
      acquiredPrice: acquiredPrice ?? this.acquiredPrice,
      acquiredDate: acquiredDate ?? this.acquiredDate,
      quantity: quantity ?? this.quantity,
      condition: condition ?? this.condition,
      isGraded: isGraded ?? this.isGraded,
      isAltered: isAltered ?? this.isAltered,
      isMisprint: isMisprint ?? this.isMisprint,
      isSigned: isSigned ?? this.isSigned,
      personalNotes: personalNotes ?? this.personalNotes,
      dateObtained: dateObtained ?? this.dateObtained,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      binderPage: binderPage ?? this.binderPage,
      binderSlot: binderSlot ?? this.binderSlot,
      notes: notes ?? this.notes,
      protectionStatus: protectionStatus ?? this.protectionStatus,
      primaryBinderId: primaryBinderId ?? this.primaryBinderId,
      currentMarketPrice: currentMarketPrice ?? this.currentMarketPrice,
      lastPriceUpdate: lastPriceUpdate ?? this.lastPriceUpdate,
      dynamicData: dynamicData ?? this.dynamicData,
      isDeleted: isDeleted ?? this.isDeleted,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (collectionType.present) {
      map['collection_type'] = Variable<String>(collectionType.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (setOrSeries.present) {
      map['set_or_series'] = Variable<String>(setOrSeries.value);
    }
    if (imageUrl.present) {
      map['image_url'] = Variable<String>(imageUrl.value);
    }
    if (flavorName.present) {
      map['flavor_name'] = Variable<String>(flavorName.value);
    }
    if (acquiredPrice.present) {
      map['acquired_price'] = Variable<double>(acquiredPrice.value);
    }
    if (acquiredDate.present) {
      map['acquired_date'] = Variable<DateTime>(acquiredDate.value);
    }
    if (quantity.present) {
      map['quantity'] = Variable<int>(quantity.value);
    }
    if (condition.present) {
      map['condition'] = Variable<String>(condition.value);
    }
    if (isGraded.present) {
      map['is_graded'] = Variable<bool>(isGraded.value);
    }
    if (isAltered.present) {
      map['is_altered'] = Variable<bool>(isAltered.value);
    }
    if (isMisprint.present) {
      map['is_misprint'] = Variable<bool>(isMisprint.value);
    }
    if (isSigned.present) {
      map['is_signed'] = Variable<bool>(isSigned.value);
    }
    if (personalNotes.present) {
      map['personal_notes'] = Variable<String>(personalNotes.value);
    }
    if (dateObtained.present) {
      map['date_obtained'] = Variable<DateTime>(dateObtained.value);
    }
    if (purchasePrice.present) {
      map['purchase_price'] = Variable<double>(purchasePrice.value);
    }
    if (binderPage.present) {
      map['binder_page'] = Variable<int>(binderPage.value);
    }
    if (binderSlot.present) {
      map['binder_slot'] = Variable<String>(binderSlot.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (protectionStatus.present) {
      map['protection_status'] = Variable<String>(protectionStatus.value);
    }
    if (primaryBinderId.present) {
      map['primary_binder_id'] = Variable<String>(primaryBinderId.value);
    }
    if (currentMarketPrice.present) {
      map['current_market_price'] = Variable<double>(currentMarketPrice.value);
    }
    if (lastPriceUpdate.present) {
      map['last_price_update'] = Variable<DateTime>(lastPriceUpdate.value);
    }
    if (dynamicData.present) {
      map['dynamic_data'] = Variable<String>(dynamicData.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('VaultItemsCompanion(')
          ..write('id: $id, ')
          ..write('collectionType: $collectionType, ')
          ..write('name: $name, ')
          ..write('setOrSeries: $setOrSeries, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('flavorName: $flavorName, ')
          ..write('acquiredPrice: $acquiredPrice, ')
          ..write('acquiredDate: $acquiredDate, ')
          ..write('quantity: $quantity, ')
          ..write('condition: $condition, ')
          ..write('isGraded: $isGraded, ')
          ..write('isAltered: $isAltered, ')
          ..write('isMisprint: $isMisprint, ')
          ..write('isSigned: $isSigned, ')
          ..write('personalNotes: $personalNotes, ')
          ..write('dateObtained: $dateObtained, ')
          ..write('purchasePrice: $purchasePrice, ')
          ..write('binderPage: $binderPage, ')
          ..write('binderSlot: $binderSlot, ')
          ..write('notes: $notes, ')
          ..write('protectionStatus: $protectionStatus, ')
          ..write('primaryBinderId: $primaryBinderId, ')
          ..write('currentMarketPrice: $currentMarketPrice, ')
          ..write('lastPriceUpdate: $lastPriceUpdate, ')
          ..write('dynamicData: $dynamicData, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DecksTable extends Decks with TableInfo<$DecksTable, Deck> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DecksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _formatMeta = const VerificationMeta('format');
  @override
  late final GeneratedColumn<String> format = GeneratedColumn<String>(
    'format',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _winsMeta = const VerificationMeta('wins');
  @override
  late final GeneratedColumn<int> wins = GeneratedColumn<int>(
    'wins',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lossesMeta = const VerificationMeta('losses');
  @override
  late final GeneratedColumn<int> losses = GeneratedColumn<int>(
    'losses',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _drawsMeta = const VerificationMeta('draws');
  @override
  late final GeneratedColumn<int> draws = GeneratedColumn<int>(
    'draws',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _coverItemIdMeta = const VerificationMeta(
    'coverItemId',
  );
  @override
  late final GeneratedColumn<String> coverItemId = GeneratedColumn<String>(
    'cover_item_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _coverCropRectMeta = const VerificationMeta(
    'coverCropRect',
  );
  @override
  late final GeneratedColumn<String> coverCropRect = GeneratedColumn<String>(
    'cover_crop_rect',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tcgDomainMeta = const VerificationMeta(
    'tcgDomain',
  );
  @override
  late final GeneratedColumn<String> tcgDomain = GeneratedColumn<String>(
    'tcg_domain',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('mtg'),
  );
  static const VerificationMeta _isRegisteredMeta = const VerificationMeta(
    'isRegistered',
  );
  @override
  late final GeneratedColumn<bool> isRegistered = GeneratedColumn<bool>(
    'is_registered',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_registered" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isCompetitiveMeta = const VerificationMeta(
    'isCompetitive',
  );
  @override
  late final GeneratedColumn<bool> isCompetitive = GeneratedColumn<bool>(
    'is_competitive',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_competitive" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isAssembledMeta = const VerificationMeta(
    'isAssembled',
  );
  @override
  late final GeneratedColumn<bool> isAssembled = GeneratedColumn<bool>(
    'is_assembled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_assembled" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    format,
    description,
    wins,
    losses,
    draws,
    coverItemId,
    coverCropRect,
    createdAt,
    tcgDomain,
    isRegistered,
    isCompetitive,
    isAssembled,
    isDeleted,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'decks';
  @override
  VerificationContext validateIntegrity(
    Insertable<Deck> instance, {
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
    if (data.containsKey('format')) {
      context.handle(
        _formatMeta,
        format.isAcceptableOrUnknown(data['format']!, _formatMeta),
      );
    } else if (isInserting) {
      context.missing(_formatMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('wins')) {
      context.handle(
        _winsMeta,
        wins.isAcceptableOrUnknown(data['wins']!, _winsMeta),
      );
    }
    if (data.containsKey('losses')) {
      context.handle(
        _lossesMeta,
        losses.isAcceptableOrUnknown(data['losses']!, _lossesMeta),
      );
    }
    if (data.containsKey('draws')) {
      context.handle(
        _drawsMeta,
        draws.isAcceptableOrUnknown(data['draws']!, _drawsMeta),
      );
    }
    if (data.containsKey('cover_item_id')) {
      context.handle(
        _coverItemIdMeta,
        coverItemId.isAcceptableOrUnknown(
          data['cover_item_id']!,
          _coverItemIdMeta,
        ),
      );
    }
    if (data.containsKey('cover_crop_rect')) {
      context.handle(
        _coverCropRectMeta,
        coverCropRect.isAcceptableOrUnknown(
          data['cover_crop_rect']!,
          _coverCropRectMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('tcg_domain')) {
      context.handle(
        _tcgDomainMeta,
        tcgDomain.isAcceptableOrUnknown(data['tcg_domain']!, _tcgDomainMeta),
      );
    }
    if (data.containsKey('is_registered')) {
      context.handle(
        _isRegisteredMeta,
        isRegistered.isAcceptableOrUnknown(
          data['is_registered']!,
          _isRegisteredMeta,
        ),
      );
    }
    if (data.containsKey('is_competitive')) {
      context.handle(
        _isCompetitiveMeta,
        isCompetitive.isAcceptableOrUnknown(
          data['is_competitive']!,
          _isCompetitiveMeta,
        ),
      );
    }
    if (data.containsKey('is_assembled')) {
      context.handle(
        _isAssembledMeta,
        isAssembled.isAcceptableOrUnknown(
          data['is_assembled']!,
          _isAssembledMeta,
        ),
      );
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Deck map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Deck(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      format: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}format'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      wins: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}wins'],
      )!,
      losses: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}losses'],
      )!,
      draws: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}draws'],
      )!,
      coverItemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_item_id'],
      ),
      coverCropRect: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_crop_rect'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      tcgDomain: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tcg_domain'],
      )!,
      isRegistered: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_registered'],
      )!,
      isCompetitive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_competitive'],
      )!,
      isAssembled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_assembled'],
      )!,
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      ),
    );
  }

  @override
  $DecksTable createAlias(String alias) {
    return $DecksTable(attachedDatabase, alias);
  }
}

class Deck extends DataClass implements Insertable<Deck> {
  final String id;
  final String name;
  final String format;
  final String? description;
  final int wins;
  final int losses;
  final int draws;
  final String? coverItemId;
  final String? coverCropRect;
  final DateTime createdAt;
  final String tcgDomain;
  final bool isRegistered;
  final bool isCompetitive;
  final bool isAssembled;
  final bool isDeleted;
  final DateTime? updatedAt;
  const Deck({
    required this.id,
    required this.name,
    required this.format,
    this.description,
    required this.wins,
    required this.losses,
    required this.draws,
    this.coverItemId,
    this.coverCropRect,
    required this.createdAt,
    required this.tcgDomain,
    required this.isRegistered,
    required this.isCompetitive,
    required this.isAssembled,
    required this.isDeleted,
    this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['format'] = Variable<String>(format);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['wins'] = Variable<int>(wins);
    map['losses'] = Variable<int>(losses);
    map['draws'] = Variable<int>(draws);
    if (!nullToAbsent || coverItemId != null) {
      map['cover_item_id'] = Variable<String>(coverItemId);
    }
    if (!nullToAbsent || coverCropRect != null) {
      map['cover_crop_rect'] = Variable<String>(coverCropRect);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['tcg_domain'] = Variable<String>(tcgDomain);
    map['is_registered'] = Variable<bool>(isRegistered);
    map['is_competitive'] = Variable<bool>(isCompetitive);
    map['is_assembled'] = Variable<bool>(isAssembled);
    map['is_deleted'] = Variable<bool>(isDeleted);
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    return map;
  }

  DecksCompanion toCompanion(bool nullToAbsent) {
    return DecksCompanion(
      id: Value(id),
      name: Value(name),
      format: Value(format),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      wins: Value(wins),
      losses: Value(losses),
      draws: Value(draws),
      coverItemId: coverItemId == null && nullToAbsent
          ? const Value.absent()
          : Value(coverItemId),
      coverCropRect: coverCropRect == null && nullToAbsent
          ? const Value.absent()
          : Value(coverCropRect),
      createdAt: Value(createdAt),
      tcgDomain: Value(tcgDomain),
      isRegistered: Value(isRegistered),
      isCompetitive: Value(isCompetitive),
      isAssembled: Value(isAssembled),
      isDeleted: Value(isDeleted),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
    );
  }

  factory Deck.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Deck(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      format: serializer.fromJson<String>(json['format']),
      description: serializer.fromJson<String?>(json['description']),
      wins: serializer.fromJson<int>(json['wins']),
      losses: serializer.fromJson<int>(json['losses']),
      draws: serializer.fromJson<int>(json['draws']),
      coverItemId: serializer.fromJson<String?>(json['coverItemId']),
      coverCropRect: serializer.fromJson<String?>(json['coverCropRect']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      tcgDomain: serializer.fromJson<String>(json['tcgDomain']),
      isRegistered: serializer.fromJson<bool>(json['isRegistered']),
      isCompetitive: serializer.fromJson<bool>(json['isCompetitive']),
      isAssembled: serializer.fromJson<bool>(json['isAssembled']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'format': serializer.toJson<String>(format),
      'description': serializer.toJson<String?>(description),
      'wins': serializer.toJson<int>(wins),
      'losses': serializer.toJson<int>(losses),
      'draws': serializer.toJson<int>(draws),
      'coverItemId': serializer.toJson<String?>(coverItemId),
      'coverCropRect': serializer.toJson<String?>(coverCropRect),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'tcgDomain': serializer.toJson<String>(tcgDomain),
      'isRegistered': serializer.toJson<bool>(isRegistered),
      'isCompetitive': serializer.toJson<bool>(isCompetitive),
      'isAssembled': serializer.toJson<bool>(isAssembled),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
    };
  }

  Deck copyWith({
    String? id,
    String? name,
    String? format,
    Value<String?> description = const Value.absent(),
    int? wins,
    int? losses,
    int? draws,
    Value<String?> coverItemId = const Value.absent(),
    Value<String?> coverCropRect = const Value.absent(),
    DateTime? createdAt,
    String? tcgDomain,
    bool? isRegistered,
    bool? isCompetitive,
    bool? isAssembled,
    bool? isDeleted,
    Value<DateTime?> updatedAt = const Value.absent(),
  }) => Deck(
    id: id ?? this.id,
    name: name ?? this.name,
    format: format ?? this.format,
    description: description.present ? description.value : this.description,
    wins: wins ?? this.wins,
    losses: losses ?? this.losses,
    draws: draws ?? this.draws,
    coverItemId: coverItemId.present ? coverItemId.value : this.coverItemId,
    coverCropRect: coverCropRect.present
        ? coverCropRect.value
        : this.coverCropRect,
    createdAt: createdAt ?? this.createdAt,
    tcgDomain: tcgDomain ?? this.tcgDomain,
    isRegistered: isRegistered ?? this.isRegistered,
    isCompetitive: isCompetitive ?? this.isCompetitive,
    isAssembled: isAssembled ?? this.isAssembled,
    isDeleted: isDeleted ?? this.isDeleted,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
  );
  Deck copyWithCompanion(DecksCompanion data) {
    return Deck(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      format: data.format.present ? data.format.value : this.format,
      description: data.description.present
          ? data.description.value
          : this.description,
      wins: data.wins.present ? data.wins.value : this.wins,
      losses: data.losses.present ? data.losses.value : this.losses,
      draws: data.draws.present ? data.draws.value : this.draws,
      coverItemId: data.coverItemId.present
          ? data.coverItemId.value
          : this.coverItemId,
      coverCropRect: data.coverCropRect.present
          ? data.coverCropRect.value
          : this.coverCropRect,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      tcgDomain: data.tcgDomain.present ? data.tcgDomain.value : this.tcgDomain,
      isRegistered: data.isRegistered.present
          ? data.isRegistered.value
          : this.isRegistered,
      isCompetitive: data.isCompetitive.present
          ? data.isCompetitive.value
          : this.isCompetitive,
      isAssembled: data.isAssembled.present
          ? data.isAssembled.value
          : this.isAssembled,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Deck(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('format: $format, ')
          ..write('description: $description, ')
          ..write('wins: $wins, ')
          ..write('losses: $losses, ')
          ..write('draws: $draws, ')
          ..write('coverItemId: $coverItemId, ')
          ..write('coverCropRect: $coverCropRect, ')
          ..write('createdAt: $createdAt, ')
          ..write('tcgDomain: $tcgDomain, ')
          ..write('isRegistered: $isRegistered, ')
          ..write('isCompetitive: $isCompetitive, ')
          ..write('isAssembled: $isAssembled, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    format,
    description,
    wins,
    losses,
    draws,
    coverItemId,
    coverCropRect,
    createdAt,
    tcgDomain,
    isRegistered,
    isCompetitive,
    isAssembled,
    isDeleted,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Deck &&
          other.id == this.id &&
          other.name == this.name &&
          other.format == this.format &&
          other.description == this.description &&
          other.wins == this.wins &&
          other.losses == this.losses &&
          other.draws == this.draws &&
          other.coverItemId == this.coverItemId &&
          other.coverCropRect == this.coverCropRect &&
          other.createdAt == this.createdAt &&
          other.tcgDomain == this.tcgDomain &&
          other.isRegistered == this.isRegistered &&
          other.isCompetitive == this.isCompetitive &&
          other.isAssembled == this.isAssembled &&
          other.isDeleted == this.isDeleted &&
          other.updatedAt == this.updatedAt);
}

class DecksCompanion extends UpdateCompanion<Deck> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> format;
  final Value<String?> description;
  final Value<int> wins;
  final Value<int> losses;
  final Value<int> draws;
  final Value<String?> coverItemId;
  final Value<String?> coverCropRect;
  final Value<DateTime> createdAt;
  final Value<String> tcgDomain;
  final Value<bool> isRegistered;
  final Value<bool> isCompetitive;
  final Value<bool> isAssembled;
  final Value<bool> isDeleted;
  final Value<DateTime?> updatedAt;
  final Value<int> rowid;
  const DecksCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.format = const Value.absent(),
    this.description = const Value.absent(),
    this.wins = const Value.absent(),
    this.losses = const Value.absent(),
    this.draws = const Value.absent(),
    this.coverItemId = const Value.absent(),
    this.coverCropRect = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.tcgDomain = const Value.absent(),
    this.isRegistered = const Value.absent(),
    this.isCompetitive = const Value.absent(),
    this.isAssembled = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DecksCompanion.insert({
    required String id,
    required String name,
    required String format,
    this.description = const Value.absent(),
    this.wins = const Value.absent(),
    this.losses = const Value.absent(),
    this.draws = const Value.absent(),
    this.coverItemId = const Value.absent(),
    this.coverCropRect = const Value.absent(),
    required DateTime createdAt,
    this.tcgDomain = const Value.absent(),
    this.isRegistered = const Value.absent(),
    this.isCompetitive = const Value.absent(),
    this.isAssembled = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       format = Value(format),
       createdAt = Value(createdAt);
  static Insertable<Deck> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? format,
    Expression<String>? description,
    Expression<int>? wins,
    Expression<int>? losses,
    Expression<int>? draws,
    Expression<String>? coverItemId,
    Expression<String>? coverCropRect,
    Expression<DateTime>? createdAt,
    Expression<String>? tcgDomain,
    Expression<bool>? isRegistered,
    Expression<bool>? isCompetitive,
    Expression<bool>? isAssembled,
    Expression<bool>? isDeleted,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (format != null) 'format': format,
      if (description != null) 'description': description,
      if (wins != null) 'wins': wins,
      if (losses != null) 'losses': losses,
      if (draws != null) 'draws': draws,
      if (coverItemId != null) 'cover_item_id': coverItemId,
      if (coverCropRect != null) 'cover_crop_rect': coverCropRect,
      if (createdAt != null) 'created_at': createdAt,
      if (tcgDomain != null) 'tcg_domain': tcgDomain,
      if (isRegistered != null) 'is_registered': isRegistered,
      if (isCompetitive != null) 'is_competitive': isCompetitive,
      if (isAssembled != null) 'is_assembled': isAssembled,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DecksCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? format,
    Value<String?>? description,
    Value<int>? wins,
    Value<int>? losses,
    Value<int>? draws,
    Value<String?>? coverItemId,
    Value<String?>? coverCropRect,
    Value<DateTime>? createdAt,
    Value<String>? tcgDomain,
    Value<bool>? isRegistered,
    Value<bool>? isCompetitive,
    Value<bool>? isAssembled,
    Value<bool>? isDeleted,
    Value<DateTime?>? updatedAt,
    Value<int>? rowid,
  }) {
    return DecksCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      format: format ?? this.format,
      description: description ?? this.description,
      wins: wins ?? this.wins,
      losses: losses ?? this.losses,
      draws: draws ?? this.draws,
      coverItemId: coverItemId ?? this.coverItemId,
      coverCropRect: coverCropRect ?? this.coverCropRect,
      createdAt: createdAt ?? this.createdAt,
      tcgDomain: tcgDomain ?? this.tcgDomain,
      isRegistered: isRegistered ?? this.isRegistered,
      isCompetitive: isCompetitive ?? this.isCompetitive,
      isAssembled: isAssembled ?? this.isAssembled,
      isDeleted: isDeleted ?? this.isDeleted,
      updatedAt: updatedAt ?? this.updatedAt,
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
    if (format.present) {
      map['format'] = Variable<String>(format.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (wins.present) {
      map['wins'] = Variable<int>(wins.value);
    }
    if (losses.present) {
      map['losses'] = Variable<int>(losses.value);
    }
    if (draws.present) {
      map['draws'] = Variable<int>(draws.value);
    }
    if (coverItemId.present) {
      map['cover_item_id'] = Variable<String>(coverItemId.value);
    }
    if (coverCropRect.present) {
      map['cover_crop_rect'] = Variable<String>(coverCropRect.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (tcgDomain.present) {
      map['tcg_domain'] = Variable<String>(tcgDomain.value);
    }
    if (isRegistered.present) {
      map['is_registered'] = Variable<bool>(isRegistered.value);
    }
    if (isCompetitive.present) {
      map['is_competitive'] = Variable<bool>(isCompetitive.value);
    }
    if (isAssembled.present) {
      map['is_assembled'] = Variable<bool>(isAssembled.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DecksCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('format: $format, ')
          ..write('description: $description, ')
          ..write('wins: $wins, ')
          ..write('losses: $losses, ')
          ..write('draws: $draws, ')
          ..write('coverItemId: $coverItemId, ')
          ..write('coverCropRect: $coverCropRect, ')
          ..write('createdAt: $createdAt, ')
          ..write('tcgDomain: $tcgDomain, ')
          ..write('isRegistered: $isRegistered, ')
          ..write('isCompetitive: $isCompetitive, ')
          ..write('isAssembled: $isAssembled, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DeckVersionsTable extends DeckVersions
    with TableInfo<$DeckVersionsTable, DeckVersion> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DeckVersionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deckIdMeta = const VerificationMeta('deckId');
  @override
  late final GeneratedColumn<String> deckId = GeneratedColumn<String>(
    'deck_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES decks (id)',
    ),
  );
  static const VerificationMeta _versionNumberMeta = const VerificationMeta(
    'versionNumber',
  );
  @override
  late final GeneratedColumn<int> versionNumber = GeneratedColumn<int>(
    'version_number',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionNoteMeta = const VerificationMeta(
    'versionNote',
  );
  @override
  late final GeneratedColumn<String> versionNote = GeneratedColumn<String>(
    'version_note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    deckId,
    versionNumber,
    versionNote,
    isActive,
    createdAt,
    isDeleted,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'deck_versions';
  @override
  VerificationContext validateIntegrity(
    Insertable<DeckVersion> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('deck_id')) {
      context.handle(
        _deckIdMeta,
        deckId.isAcceptableOrUnknown(data['deck_id']!, _deckIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deckIdMeta);
    }
    if (data.containsKey('version_number')) {
      context.handle(
        _versionNumberMeta,
        versionNumber.isAcceptableOrUnknown(
          data['version_number']!,
          _versionNumberMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_versionNumberMeta);
    }
    if (data.containsKey('version_note')) {
      context.handle(
        _versionNoteMeta,
        versionNote.isAcceptableOrUnknown(
          data['version_note']!,
          _versionNoteMeta,
        ),
      );
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DeckVersion map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DeckVersion(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      deckId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}deck_id'],
      )!,
      versionNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version_number'],
      )!,
      versionNote: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}version_note'],
      ),
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      ),
    );
  }

  @override
  $DeckVersionsTable createAlias(String alias) {
    return $DeckVersionsTable(attachedDatabase, alias);
  }
}

class DeckVersion extends DataClass implements Insertable<DeckVersion> {
  final String id;
  final String deckId;
  final int versionNumber;
  final String? versionNote;
  final bool isActive;
  final DateTime createdAt;
  final bool isDeleted;
  final DateTime? updatedAt;
  const DeckVersion({
    required this.id,
    required this.deckId,
    required this.versionNumber,
    this.versionNote,
    required this.isActive,
    required this.createdAt,
    required this.isDeleted,
    this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['deck_id'] = Variable<String>(deckId);
    map['version_number'] = Variable<int>(versionNumber);
    if (!nullToAbsent || versionNote != null) {
      map['version_note'] = Variable<String>(versionNote);
    }
    map['is_active'] = Variable<bool>(isActive);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['is_deleted'] = Variable<bool>(isDeleted);
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    return map;
  }

  DeckVersionsCompanion toCompanion(bool nullToAbsent) {
    return DeckVersionsCompanion(
      id: Value(id),
      deckId: Value(deckId),
      versionNumber: Value(versionNumber),
      versionNote: versionNote == null && nullToAbsent
          ? const Value.absent()
          : Value(versionNote),
      isActive: Value(isActive),
      createdAt: Value(createdAt),
      isDeleted: Value(isDeleted),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
    );
  }

  factory DeckVersion.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DeckVersion(
      id: serializer.fromJson<String>(json['id']),
      deckId: serializer.fromJson<String>(json['deckId']),
      versionNumber: serializer.fromJson<int>(json['versionNumber']),
      versionNote: serializer.fromJson<String?>(json['versionNote']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'deckId': serializer.toJson<String>(deckId),
      'versionNumber': serializer.toJson<int>(versionNumber),
      'versionNote': serializer.toJson<String?>(versionNote),
      'isActive': serializer.toJson<bool>(isActive),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
    };
  }

  DeckVersion copyWith({
    String? id,
    String? deckId,
    int? versionNumber,
    Value<String?> versionNote = const Value.absent(),
    bool? isActive,
    DateTime? createdAt,
    bool? isDeleted,
    Value<DateTime?> updatedAt = const Value.absent(),
  }) => DeckVersion(
    id: id ?? this.id,
    deckId: deckId ?? this.deckId,
    versionNumber: versionNumber ?? this.versionNumber,
    versionNote: versionNote.present ? versionNote.value : this.versionNote,
    isActive: isActive ?? this.isActive,
    createdAt: createdAt ?? this.createdAt,
    isDeleted: isDeleted ?? this.isDeleted,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
  );
  DeckVersion copyWithCompanion(DeckVersionsCompanion data) {
    return DeckVersion(
      id: data.id.present ? data.id.value : this.id,
      deckId: data.deckId.present ? data.deckId.value : this.deckId,
      versionNumber: data.versionNumber.present
          ? data.versionNumber.value
          : this.versionNumber,
      versionNote: data.versionNote.present
          ? data.versionNote.value
          : this.versionNote,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DeckVersion(')
          ..write('id: $id, ')
          ..write('deckId: $deckId, ')
          ..write('versionNumber: $versionNumber, ')
          ..write('versionNote: $versionNote, ')
          ..write('isActive: $isActive, ')
          ..write('createdAt: $createdAt, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    deckId,
    versionNumber,
    versionNote,
    isActive,
    createdAt,
    isDeleted,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DeckVersion &&
          other.id == this.id &&
          other.deckId == this.deckId &&
          other.versionNumber == this.versionNumber &&
          other.versionNote == this.versionNote &&
          other.isActive == this.isActive &&
          other.createdAt == this.createdAt &&
          other.isDeleted == this.isDeleted &&
          other.updatedAt == this.updatedAt);
}

class DeckVersionsCompanion extends UpdateCompanion<DeckVersion> {
  final Value<String> id;
  final Value<String> deckId;
  final Value<int> versionNumber;
  final Value<String?> versionNote;
  final Value<bool> isActive;
  final Value<DateTime> createdAt;
  final Value<bool> isDeleted;
  final Value<DateTime?> updatedAt;
  final Value<int> rowid;
  const DeckVersionsCompanion({
    this.id = const Value.absent(),
    this.deckId = const Value.absent(),
    this.versionNumber = const Value.absent(),
    this.versionNote = const Value.absent(),
    this.isActive = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DeckVersionsCompanion.insert({
    required String id,
    required String deckId,
    required int versionNumber,
    this.versionNote = const Value.absent(),
    this.isActive = const Value.absent(),
    required DateTime createdAt,
    this.isDeleted = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       deckId = Value(deckId),
       versionNumber = Value(versionNumber),
       createdAt = Value(createdAt);
  static Insertable<DeckVersion> custom({
    Expression<String>? id,
    Expression<String>? deckId,
    Expression<int>? versionNumber,
    Expression<String>? versionNote,
    Expression<bool>? isActive,
    Expression<DateTime>? createdAt,
    Expression<bool>? isDeleted,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (deckId != null) 'deck_id': deckId,
      if (versionNumber != null) 'version_number': versionNumber,
      if (versionNote != null) 'version_note': versionNote,
      if (isActive != null) 'is_active': isActive,
      if (createdAt != null) 'created_at': createdAt,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DeckVersionsCompanion copyWith({
    Value<String>? id,
    Value<String>? deckId,
    Value<int>? versionNumber,
    Value<String?>? versionNote,
    Value<bool>? isActive,
    Value<DateTime>? createdAt,
    Value<bool>? isDeleted,
    Value<DateTime?>? updatedAt,
    Value<int>? rowid,
  }) {
    return DeckVersionsCompanion(
      id: id ?? this.id,
      deckId: deckId ?? this.deckId,
      versionNumber: versionNumber ?? this.versionNumber,
      versionNote: versionNote ?? this.versionNote,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      isDeleted: isDeleted ?? this.isDeleted,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (deckId.present) {
      map['deck_id'] = Variable<String>(deckId.value);
    }
    if (versionNumber.present) {
      map['version_number'] = Variable<int>(versionNumber.value);
    }
    if (versionNote.present) {
      map['version_note'] = Variable<String>(versionNote.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DeckVersionsCompanion(')
          ..write('id: $id, ')
          ..write('deckId: $deckId, ')
          ..write('versionNumber: $versionNumber, ')
          ..write('versionNote: $versionNote, ')
          ..write('isActive: $isActive, ')
          ..write('createdAt: $createdAt, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DeckVersionItemsTable extends DeckVersionItems
    with TableInfo<$DeckVersionItemsTable, DeckVersionItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DeckVersionItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionIdMeta = const VerificationMeta(
    'versionId',
  );
  @override
  late final GeneratedColumn<String> versionId = GeneratedColumn<String>(
    'version_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES deck_versions (id)',
    ),
  );
  static const VerificationMeta _vaultItemIdMeta = const VerificationMeta(
    'vaultItemId',
  );
  @override
  late final GeneratedColumn<String> vaultItemId = GeneratedColumn<String>(
    'vault_item_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES vault_items (id)',
    ),
  );
  static const VerificationMeta _quantityMeta = const VerificationMeta(
    'quantity',
  );
  @override
  late final GeneratedColumn<int> quantity = GeneratedColumn<int>(
    'quantity',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _boardZoneMeta = const VerificationMeta(
    'boardZone',
  );
  @override
  late final GeneratedColumn<String> boardZone = GeneratedColumn<String>(
    'board_zone',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isProxyMeta = const VerificationMeta(
    'isProxy',
  );
  @override
  late final GeneratedColumn<bool> isProxy = GeneratedColumn<bool>(
    'is_proxy',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_proxy" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    versionId,
    vaultItemId,
    quantity,
    boardZone,
    isProxy,
    isDeleted,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'deck_version_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<DeckVersionItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('version_id')) {
      context.handle(
        _versionIdMeta,
        versionId.isAcceptableOrUnknown(data['version_id']!, _versionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_versionIdMeta);
    }
    if (data.containsKey('vault_item_id')) {
      context.handle(
        _vaultItemIdMeta,
        vaultItemId.isAcceptableOrUnknown(
          data['vault_item_id']!,
          _vaultItemIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_vaultItemIdMeta);
    }
    if (data.containsKey('quantity')) {
      context.handle(
        _quantityMeta,
        quantity.isAcceptableOrUnknown(data['quantity']!, _quantityMeta),
      );
    }
    if (data.containsKey('board_zone')) {
      context.handle(
        _boardZoneMeta,
        boardZone.isAcceptableOrUnknown(data['board_zone']!, _boardZoneMeta),
      );
    } else if (isInserting) {
      context.missing(_boardZoneMeta);
    }
    if (data.containsKey('is_proxy')) {
      context.handle(
        _isProxyMeta,
        isProxy.isAcceptableOrUnknown(data['is_proxy']!, _isProxyMeta),
      );
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DeckVersionItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DeckVersionItem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      versionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}version_id'],
      )!,
      vaultItemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}vault_item_id'],
      )!,
      quantity: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}quantity'],
      )!,
      boardZone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}board_zone'],
      )!,
      isProxy: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_proxy'],
      )!,
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      ),
    );
  }

  @override
  $DeckVersionItemsTable createAlias(String alias) {
    return $DeckVersionItemsTable(attachedDatabase, alias);
  }
}

class DeckVersionItem extends DataClass implements Insertable<DeckVersionItem> {
  final String id;
  final String versionId;
  final String vaultItemId;
  final int quantity;
  final String boardZone;
  final bool isProxy;
  final bool isDeleted;
  final DateTime? updatedAt;
  const DeckVersionItem({
    required this.id,
    required this.versionId,
    required this.vaultItemId,
    required this.quantity,
    required this.boardZone,
    required this.isProxy,
    required this.isDeleted,
    this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['version_id'] = Variable<String>(versionId);
    map['vault_item_id'] = Variable<String>(vaultItemId);
    map['quantity'] = Variable<int>(quantity);
    map['board_zone'] = Variable<String>(boardZone);
    map['is_proxy'] = Variable<bool>(isProxy);
    map['is_deleted'] = Variable<bool>(isDeleted);
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    return map;
  }

  DeckVersionItemsCompanion toCompanion(bool nullToAbsent) {
    return DeckVersionItemsCompanion(
      id: Value(id),
      versionId: Value(versionId),
      vaultItemId: Value(vaultItemId),
      quantity: Value(quantity),
      boardZone: Value(boardZone),
      isProxy: Value(isProxy),
      isDeleted: Value(isDeleted),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
    );
  }

  factory DeckVersionItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DeckVersionItem(
      id: serializer.fromJson<String>(json['id']),
      versionId: serializer.fromJson<String>(json['versionId']),
      vaultItemId: serializer.fromJson<String>(json['vaultItemId']),
      quantity: serializer.fromJson<int>(json['quantity']),
      boardZone: serializer.fromJson<String>(json['boardZone']),
      isProxy: serializer.fromJson<bool>(json['isProxy']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'versionId': serializer.toJson<String>(versionId),
      'vaultItemId': serializer.toJson<String>(vaultItemId),
      'quantity': serializer.toJson<int>(quantity),
      'boardZone': serializer.toJson<String>(boardZone),
      'isProxy': serializer.toJson<bool>(isProxy),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
    };
  }

  DeckVersionItem copyWith({
    String? id,
    String? versionId,
    String? vaultItemId,
    int? quantity,
    String? boardZone,
    bool? isProxy,
    bool? isDeleted,
    Value<DateTime?> updatedAt = const Value.absent(),
  }) => DeckVersionItem(
    id: id ?? this.id,
    versionId: versionId ?? this.versionId,
    vaultItemId: vaultItemId ?? this.vaultItemId,
    quantity: quantity ?? this.quantity,
    boardZone: boardZone ?? this.boardZone,
    isProxy: isProxy ?? this.isProxy,
    isDeleted: isDeleted ?? this.isDeleted,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
  );
  DeckVersionItem copyWithCompanion(DeckVersionItemsCompanion data) {
    return DeckVersionItem(
      id: data.id.present ? data.id.value : this.id,
      versionId: data.versionId.present ? data.versionId.value : this.versionId,
      vaultItemId: data.vaultItemId.present
          ? data.vaultItemId.value
          : this.vaultItemId,
      quantity: data.quantity.present ? data.quantity.value : this.quantity,
      boardZone: data.boardZone.present ? data.boardZone.value : this.boardZone,
      isProxy: data.isProxy.present ? data.isProxy.value : this.isProxy,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DeckVersionItem(')
          ..write('id: $id, ')
          ..write('versionId: $versionId, ')
          ..write('vaultItemId: $vaultItemId, ')
          ..write('quantity: $quantity, ')
          ..write('boardZone: $boardZone, ')
          ..write('isProxy: $isProxy, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    versionId,
    vaultItemId,
    quantity,
    boardZone,
    isProxy,
    isDeleted,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DeckVersionItem &&
          other.id == this.id &&
          other.versionId == this.versionId &&
          other.vaultItemId == this.vaultItemId &&
          other.quantity == this.quantity &&
          other.boardZone == this.boardZone &&
          other.isProxy == this.isProxy &&
          other.isDeleted == this.isDeleted &&
          other.updatedAt == this.updatedAt);
}

class DeckVersionItemsCompanion extends UpdateCompanion<DeckVersionItem> {
  final Value<String> id;
  final Value<String> versionId;
  final Value<String> vaultItemId;
  final Value<int> quantity;
  final Value<String> boardZone;
  final Value<bool> isProxy;
  final Value<bool> isDeleted;
  final Value<DateTime?> updatedAt;
  final Value<int> rowid;
  const DeckVersionItemsCompanion({
    this.id = const Value.absent(),
    this.versionId = const Value.absent(),
    this.vaultItemId = const Value.absent(),
    this.quantity = const Value.absent(),
    this.boardZone = const Value.absent(),
    this.isProxy = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DeckVersionItemsCompanion.insert({
    required String id,
    required String versionId,
    required String vaultItemId,
    this.quantity = const Value.absent(),
    required String boardZone,
    this.isProxy = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       versionId = Value(versionId),
       vaultItemId = Value(vaultItemId),
       boardZone = Value(boardZone);
  static Insertable<DeckVersionItem> custom({
    Expression<String>? id,
    Expression<String>? versionId,
    Expression<String>? vaultItemId,
    Expression<int>? quantity,
    Expression<String>? boardZone,
    Expression<bool>? isProxy,
    Expression<bool>? isDeleted,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (versionId != null) 'version_id': versionId,
      if (vaultItemId != null) 'vault_item_id': vaultItemId,
      if (quantity != null) 'quantity': quantity,
      if (boardZone != null) 'board_zone': boardZone,
      if (isProxy != null) 'is_proxy': isProxy,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DeckVersionItemsCompanion copyWith({
    Value<String>? id,
    Value<String>? versionId,
    Value<String>? vaultItemId,
    Value<int>? quantity,
    Value<String>? boardZone,
    Value<bool>? isProxy,
    Value<bool>? isDeleted,
    Value<DateTime?>? updatedAt,
    Value<int>? rowid,
  }) {
    return DeckVersionItemsCompanion(
      id: id ?? this.id,
      versionId: versionId ?? this.versionId,
      vaultItemId: vaultItemId ?? this.vaultItemId,
      quantity: quantity ?? this.quantity,
      boardZone: boardZone ?? this.boardZone,
      isProxy: isProxy ?? this.isProxy,
      isDeleted: isDeleted ?? this.isDeleted,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (versionId.present) {
      map['version_id'] = Variable<String>(versionId.value);
    }
    if (vaultItemId.present) {
      map['vault_item_id'] = Variable<String>(vaultItemId.value);
    }
    if (quantity.present) {
      map['quantity'] = Variable<int>(quantity.value);
    }
    if (boardZone.present) {
      map['board_zone'] = Variable<String>(boardZone.value);
    }
    if (isProxy.present) {
      map['is_proxy'] = Variable<bool>(isProxy.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DeckVersionItemsCompanion(')
          ..write('id: $id, ')
          ..write('versionId: $versionId, ')
          ..write('vaultItemId: $vaultItemId, ')
          ..write('quantity: $quantity, ')
          ..write('boardZone: $boardZone, ')
          ..write('isProxy: $isProxy, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DeckMatchupsTable extends DeckMatchups
    with TableInfo<$DeckMatchupsTable, DeckMatchup> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DeckMatchupsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deckIdMeta = const VerificationMeta('deckId');
  @override
  late final GeneratedColumn<String> deckId = GeneratedColumn<String>(
    'deck_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES decks (id)',
    ),
  );
  static const VerificationMeta _opponentArchetypeMeta = const VerificationMeta(
    'opponentArchetype',
  );
  @override
  late final GeneratedColumn<String> opponentArchetype =
      GeneratedColumn<String>(
        'opponent_archetype',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _swapInItemIdsMeta = const VerificationMeta(
    'swapInItemIds',
  );
  @override
  late final GeneratedColumn<String> swapInItemIds = GeneratedColumn<String>(
    'swap_in_item_ids',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _swapOutItemIdsMeta = const VerificationMeta(
    'swapOutItemIds',
  );
  @override
  late final GeneratedColumn<String> swapOutItemIds = GeneratedColumn<String>(
    'swap_out_item_ids',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    deckId,
    opponentArchetype,
    notes,
    swapInItemIds,
    swapOutItemIds,
    isDeleted,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'deck_matchups';
  @override
  VerificationContext validateIntegrity(
    Insertable<DeckMatchup> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('deck_id')) {
      context.handle(
        _deckIdMeta,
        deckId.isAcceptableOrUnknown(data['deck_id']!, _deckIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deckIdMeta);
    }
    if (data.containsKey('opponent_archetype')) {
      context.handle(
        _opponentArchetypeMeta,
        opponentArchetype.isAcceptableOrUnknown(
          data['opponent_archetype']!,
          _opponentArchetypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_opponentArchetypeMeta);
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('swap_in_item_ids')) {
      context.handle(
        _swapInItemIdsMeta,
        swapInItemIds.isAcceptableOrUnknown(
          data['swap_in_item_ids']!,
          _swapInItemIdsMeta,
        ),
      );
    }
    if (data.containsKey('swap_out_item_ids')) {
      context.handle(
        _swapOutItemIdsMeta,
        swapOutItemIds.isAcceptableOrUnknown(
          data['swap_out_item_ids']!,
          _swapOutItemIdsMeta,
        ),
      );
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DeckMatchup map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DeckMatchup(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      deckId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}deck_id'],
      )!,
      opponentArchetype: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}opponent_archetype'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      swapInItemIds: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}swap_in_item_ids'],
      ),
      swapOutItemIds: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}swap_out_item_ids'],
      ),
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      ),
    );
  }

  @override
  $DeckMatchupsTable createAlias(String alias) {
    return $DeckMatchupsTable(attachedDatabase, alias);
  }
}

class DeckMatchup extends DataClass implements Insertable<DeckMatchup> {
  final String id;
  final String deckId;
  final String opponentArchetype;
  final String? notes;
  final String? swapInItemIds;
  final String? swapOutItemIds;
  final bool isDeleted;
  final DateTime? updatedAt;
  const DeckMatchup({
    required this.id,
    required this.deckId,
    required this.opponentArchetype,
    this.notes,
    this.swapInItemIds,
    this.swapOutItemIds,
    required this.isDeleted,
    this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['deck_id'] = Variable<String>(deckId);
    map['opponent_archetype'] = Variable<String>(opponentArchetype);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    if (!nullToAbsent || swapInItemIds != null) {
      map['swap_in_item_ids'] = Variable<String>(swapInItemIds);
    }
    if (!nullToAbsent || swapOutItemIds != null) {
      map['swap_out_item_ids'] = Variable<String>(swapOutItemIds);
    }
    map['is_deleted'] = Variable<bool>(isDeleted);
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    return map;
  }

  DeckMatchupsCompanion toCompanion(bool nullToAbsent) {
    return DeckMatchupsCompanion(
      id: Value(id),
      deckId: Value(deckId),
      opponentArchetype: Value(opponentArchetype),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      swapInItemIds: swapInItemIds == null && nullToAbsent
          ? const Value.absent()
          : Value(swapInItemIds),
      swapOutItemIds: swapOutItemIds == null && nullToAbsent
          ? const Value.absent()
          : Value(swapOutItemIds),
      isDeleted: Value(isDeleted),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
    );
  }

  factory DeckMatchup.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DeckMatchup(
      id: serializer.fromJson<String>(json['id']),
      deckId: serializer.fromJson<String>(json['deckId']),
      opponentArchetype: serializer.fromJson<String>(json['opponentArchetype']),
      notes: serializer.fromJson<String?>(json['notes']),
      swapInItemIds: serializer.fromJson<String?>(json['swapInItemIds']),
      swapOutItemIds: serializer.fromJson<String?>(json['swapOutItemIds']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'deckId': serializer.toJson<String>(deckId),
      'opponentArchetype': serializer.toJson<String>(opponentArchetype),
      'notes': serializer.toJson<String?>(notes),
      'swapInItemIds': serializer.toJson<String?>(swapInItemIds),
      'swapOutItemIds': serializer.toJson<String?>(swapOutItemIds),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
    };
  }

  DeckMatchup copyWith({
    String? id,
    String? deckId,
    String? opponentArchetype,
    Value<String?> notes = const Value.absent(),
    Value<String?> swapInItemIds = const Value.absent(),
    Value<String?> swapOutItemIds = const Value.absent(),
    bool? isDeleted,
    Value<DateTime?> updatedAt = const Value.absent(),
  }) => DeckMatchup(
    id: id ?? this.id,
    deckId: deckId ?? this.deckId,
    opponentArchetype: opponentArchetype ?? this.opponentArchetype,
    notes: notes.present ? notes.value : this.notes,
    swapInItemIds: swapInItemIds.present
        ? swapInItemIds.value
        : this.swapInItemIds,
    swapOutItemIds: swapOutItemIds.present
        ? swapOutItemIds.value
        : this.swapOutItemIds,
    isDeleted: isDeleted ?? this.isDeleted,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
  );
  DeckMatchup copyWithCompanion(DeckMatchupsCompanion data) {
    return DeckMatchup(
      id: data.id.present ? data.id.value : this.id,
      deckId: data.deckId.present ? data.deckId.value : this.deckId,
      opponentArchetype: data.opponentArchetype.present
          ? data.opponentArchetype.value
          : this.opponentArchetype,
      notes: data.notes.present ? data.notes.value : this.notes,
      swapInItemIds: data.swapInItemIds.present
          ? data.swapInItemIds.value
          : this.swapInItemIds,
      swapOutItemIds: data.swapOutItemIds.present
          ? data.swapOutItemIds.value
          : this.swapOutItemIds,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DeckMatchup(')
          ..write('id: $id, ')
          ..write('deckId: $deckId, ')
          ..write('opponentArchetype: $opponentArchetype, ')
          ..write('notes: $notes, ')
          ..write('swapInItemIds: $swapInItemIds, ')
          ..write('swapOutItemIds: $swapOutItemIds, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    deckId,
    opponentArchetype,
    notes,
    swapInItemIds,
    swapOutItemIds,
    isDeleted,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DeckMatchup &&
          other.id == this.id &&
          other.deckId == this.deckId &&
          other.opponentArchetype == this.opponentArchetype &&
          other.notes == this.notes &&
          other.swapInItemIds == this.swapInItemIds &&
          other.swapOutItemIds == this.swapOutItemIds &&
          other.isDeleted == this.isDeleted &&
          other.updatedAt == this.updatedAt);
}

class DeckMatchupsCompanion extends UpdateCompanion<DeckMatchup> {
  final Value<String> id;
  final Value<String> deckId;
  final Value<String> opponentArchetype;
  final Value<String?> notes;
  final Value<String?> swapInItemIds;
  final Value<String?> swapOutItemIds;
  final Value<bool> isDeleted;
  final Value<DateTime?> updatedAt;
  final Value<int> rowid;
  const DeckMatchupsCompanion({
    this.id = const Value.absent(),
    this.deckId = const Value.absent(),
    this.opponentArchetype = const Value.absent(),
    this.notes = const Value.absent(),
    this.swapInItemIds = const Value.absent(),
    this.swapOutItemIds = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DeckMatchupsCompanion.insert({
    required String id,
    required String deckId,
    required String opponentArchetype,
    this.notes = const Value.absent(),
    this.swapInItemIds = const Value.absent(),
    this.swapOutItemIds = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       deckId = Value(deckId),
       opponentArchetype = Value(opponentArchetype);
  static Insertable<DeckMatchup> custom({
    Expression<String>? id,
    Expression<String>? deckId,
    Expression<String>? opponentArchetype,
    Expression<String>? notes,
    Expression<String>? swapInItemIds,
    Expression<String>? swapOutItemIds,
    Expression<bool>? isDeleted,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (deckId != null) 'deck_id': deckId,
      if (opponentArchetype != null) 'opponent_archetype': opponentArchetype,
      if (notes != null) 'notes': notes,
      if (swapInItemIds != null) 'swap_in_item_ids': swapInItemIds,
      if (swapOutItemIds != null) 'swap_out_item_ids': swapOutItemIds,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DeckMatchupsCompanion copyWith({
    Value<String>? id,
    Value<String>? deckId,
    Value<String>? opponentArchetype,
    Value<String?>? notes,
    Value<String?>? swapInItemIds,
    Value<String?>? swapOutItemIds,
    Value<bool>? isDeleted,
    Value<DateTime?>? updatedAt,
    Value<int>? rowid,
  }) {
    return DeckMatchupsCompanion(
      id: id ?? this.id,
      deckId: deckId ?? this.deckId,
      opponentArchetype: opponentArchetype ?? this.opponentArchetype,
      notes: notes ?? this.notes,
      swapInItemIds: swapInItemIds ?? this.swapInItemIds,
      swapOutItemIds: swapOutItemIds ?? this.swapOutItemIds,
      isDeleted: isDeleted ?? this.isDeleted,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (deckId.present) {
      map['deck_id'] = Variable<String>(deckId.value);
    }
    if (opponentArchetype.present) {
      map['opponent_archetype'] = Variable<String>(opponentArchetype.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (swapInItemIds.present) {
      map['swap_in_item_ids'] = Variable<String>(swapInItemIds.value);
    }
    if (swapOutItemIds.present) {
      map['swap_out_item_ids'] = Variable<String>(swapOutItemIds.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DeckMatchupsCompanion(')
          ..write('id: $id, ')
          ..write('deckId: $deckId, ')
          ..write('opponentArchetype: $opponentArchetype, ')
          ..write('notes: $notes, ')
          ..write('swapInItemIds: $swapInItemIds, ')
          ..write('swapOutItemIds: $swapOutItemIds, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DeckSynergiesTable extends DeckSynergies
    with TableInfo<$DeckSynergiesTable, DeckSynergy> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DeckSynergiesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deckIdMeta = const VerificationMeta('deckId');
  @override
  late final GeneratedColumn<String> deckId = GeneratedColumn<String>(
    'deck_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES decks (id)',
    ),
  );
  static const VerificationMeta _synergyNameMeta = const VerificationMeta(
    'synergyName',
  );
  @override
  late final GeneratedColumn<String> synergyName = GeneratedColumn<String>(
    'synergy_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _vaultItemIdsMeta = const VerificationMeta(
    'vaultItemIds',
  );
  @override
  late final GeneratedColumn<String> vaultItemIds = GeneratedColumn<String>(
    'vault_item_ids',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    deckId,
    synergyName,
    vaultItemIds,
    isDeleted,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'deck_synergies';
  @override
  VerificationContext validateIntegrity(
    Insertable<DeckSynergy> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('deck_id')) {
      context.handle(
        _deckIdMeta,
        deckId.isAcceptableOrUnknown(data['deck_id']!, _deckIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deckIdMeta);
    }
    if (data.containsKey('synergy_name')) {
      context.handle(
        _synergyNameMeta,
        synergyName.isAcceptableOrUnknown(
          data['synergy_name']!,
          _synergyNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_synergyNameMeta);
    }
    if (data.containsKey('vault_item_ids')) {
      context.handle(
        _vaultItemIdsMeta,
        vaultItemIds.isAcceptableOrUnknown(
          data['vault_item_ids']!,
          _vaultItemIdsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_vaultItemIdsMeta);
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DeckSynergy map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DeckSynergy(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      deckId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}deck_id'],
      )!,
      synergyName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}synergy_name'],
      )!,
      vaultItemIds: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}vault_item_ids'],
      )!,
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      ),
    );
  }

  @override
  $DeckSynergiesTable createAlias(String alias) {
    return $DeckSynergiesTable(attachedDatabase, alias);
  }
}

class DeckSynergy extends DataClass implements Insertable<DeckSynergy> {
  final String id;
  final String deckId;
  final String synergyName;
  final String vaultItemIds;
  final bool isDeleted;
  final DateTime? updatedAt;
  const DeckSynergy({
    required this.id,
    required this.deckId,
    required this.synergyName,
    required this.vaultItemIds,
    required this.isDeleted,
    this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['deck_id'] = Variable<String>(deckId);
    map['synergy_name'] = Variable<String>(synergyName);
    map['vault_item_ids'] = Variable<String>(vaultItemIds);
    map['is_deleted'] = Variable<bool>(isDeleted);
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    return map;
  }

  DeckSynergiesCompanion toCompanion(bool nullToAbsent) {
    return DeckSynergiesCompanion(
      id: Value(id),
      deckId: Value(deckId),
      synergyName: Value(synergyName),
      vaultItemIds: Value(vaultItemIds),
      isDeleted: Value(isDeleted),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
    );
  }

  factory DeckSynergy.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DeckSynergy(
      id: serializer.fromJson<String>(json['id']),
      deckId: serializer.fromJson<String>(json['deckId']),
      synergyName: serializer.fromJson<String>(json['synergyName']),
      vaultItemIds: serializer.fromJson<String>(json['vaultItemIds']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'deckId': serializer.toJson<String>(deckId),
      'synergyName': serializer.toJson<String>(synergyName),
      'vaultItemIds': serializer.toJson<String>(vaultItemIds),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
    };
  }

  DeckSynergy copyWith({
    String? id,
    String? deckId,
    String? synergyName,
    String? vaultItemIds,
    bool? isDeleted,
    Value<DateTime?> updatedAt = const Value.absent(),
  }) => DeckSynergy(
    id: id ?? this.id,
    deckId: deckId ?? this.deckId,
    synergyName: synergyName ?? this.synergyName,
    vaultItemIds: vaultItemIds ?? this.vaultItemIds,
    isDeleted: isDeleted ?? this.isDeleted,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
  );
  DeckSynergy copyWithCompanion(DeckSynergiesCompanion data) {
    return DeckSynergy(
      id: data.id.present ? data.id.value : this.id,
      deckId: data.deckId.present ? data.deckId.value : this.deckId,
      synergyName: data.synergyName.present
          ? data.synergyName.value
          : this.synergyName,
      vaultItemIds: data.vaultItemIds.present
          ? data.vaultItemIds.value
          : this.vaultItemIds,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DeckSynergy(')
          ..write('id: $id, ')
          ..write('deckId: $deckId, ')
          ..write('synergyName: $synergyName, ')
          ..write('vaultItemIds: $vaultItemIds, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, deckId, synergyName, vaultItemIds, isDeleted, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DeckSynergy &&
          other.id == this.id &&
          other.deckId == this.deckId &&
          other.synergyName == this.synergyName &&
          other.vaultItemIds == this.vaultItemIds &&
          other.isDeleted == this.isDeleted &&
          other.updatedAt == this.updatedAt);
}

class DeckSynergiesCompanion extends UpdateCompanion<DeckSynergy> {
  final Value<String> id;
  final Value<String> deckId;
  final Value<String> synergyName;
  final Value<String> vaultItemIds;
  final Value<bool> isDeleted;
  final Value<DateTime?> updatedAt;
  final Value<int> rowid;
  const DeckSynergiesCompanion({
    this.id = const Value.absent(),
    this.deckId = const Value.absent(),
    this.synergyName = const Value.absent(),
    this.vaultItemIds = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DeckSynergiesCompanion.insert({
    required String id,
    required String deckId,
    required String synergyName,
    required String vaultItemIds,
    this.isDeleted = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       deckId = Value(deckId),
       synergyName = Value(synergyName),
       vaultItemIds = Value(vaultItemIds);
  static Insertable<DeckSynergy> custom({
    Expression<String>? id,
    Expression<String>? deckId,
    Expression<String>? synergyName,
    Expression<String>? vaultItemIds,
    Expression<bool>? isDeleted,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (deckId != null) 'deck_id': deckId,
      if (synergyName != null) 'synergy_name': synergyName,
      if (vaultItemIds != null) 'vault_item_ids': vaultItemIds,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DeckSynergiesCompanion copyWith({
    Value<String>? id,
    Value<String>? deckId,
    Value<String>? synergyName,
    Value<String>? vaultItemIds,
    Value<bool>? isDeleted,
    Value<DateTime?>? updatedAt,
    Value<int>? rowid,
  }) {
    return DeckSynergiesCompanion(
      id: id ?? this.id,
      deckId: deckId ?? this.deckId,
      synergyName: synergyName ?? this.synergyName,
      vaultItemIds: vaultItemIds ?? this.vaultItemIds,
      isDeleted: isDeleted ?? this.isDeleted,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (deckId.present) {
      map['deck_id'] = Variable<String>(deckId.value);
    }
    if (synergyName.present) {
      map['synergy_name'] = Variable<String>(synergyName.value);
    }
    if (vaultItemIds.present) {
      map['vault_item_ids'] = Variable<String>(vaultItemIds.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DeckSynergiesCompanion(')
          ..write('id: $id, ')
          ..write('deckId: $deckId, ')
          ..write('synergyName: $synergyName, ')
          ..write('vaultItemIds: $vaultItemIds, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncQueueTable extends SyncQueue
    with TableInfo<$SyncQueueTable, SyncQueueEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncQueueTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityTypeMeta = const VerificationMeta(
    'entityType',
  );
  @override
  late final GeneratedColumn<String> entityType = GeneratedColumn<String>(
    'entity_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityIdMeta = const VerificationMeta(
    'entityId',
  );
  @override
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
    'entity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _operationMeta = const VerificationMeta(
    'operation',
  );
  @override
  late final GeneratedColumn<String> operation = GeneratedColumn<String>(
    'operation',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timestampMeta = const VerificationMeta(
    'timestamp',
  );
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
    'timestamp',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _retryCountMeta = const VerificationMeta(
    'retryCount',
  );
  @override
  late final GeneratedColumn<int> retryCount = GeneratedColumn<int>(
    'retry_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    entityType,
    entityId,
    operation,
    timestamp,
    retryCount,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_queue';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncQueueEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('entity_type')) {
      context.handle(
        _entityTypeMeta,
        entityType.isAcceptableOrUnknown(data['entity_type']!, _entityTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_entityTypeMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(
        _entityIdMeta,
        entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('operation')) {
      context.handle(
        _operationMeta,
        operation.isAcceptableOrUnknown(data['operation']!, _operationMeta),
      );
    } else if (isInserting) {
      context.missing(_operationMeta);
    }
    if (data.containsKey('timestamp')) {
      context.handle(
        _timestampMeta,
        timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta),
      );
    } else if (isInserting) {
      context.missing(_timestampMeta);
    }
    if (data.containsKey('retry_count')) {
      context.handle(
        _retryCountMeta,
        retryCount.isAcceptableOrUnknown(data['retry_count']!, _retryCountMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncQueueEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncQueueEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      entityType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_type'],
      )!,
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_id'],
      )!,
      operation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation'],
      )!,
      timestamp: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}timestamp'],
      )!,
      retryCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}retry_count'],
      )!,
    );
  }

  @override
  $SyncQueueTable createAlias(String alias) {
    return $SyncQueueTable(attachedDatabase, alias);
  }
}

class SyncQueueEntry extends DataClass implements Insertable<SyncQueueEntry> {
  /// Unique mutation ID (UUID v4)
  final String id;

  /// Entity table type (e.g. 'vault_item', 'deck', 'binder', 'deck_version', 'deck_version_item')
  final String entityType;

  /// Target entity primary key ID
  final String entityId;

  /// Mutation operation: 'INSERT', 'UPDATE', 'DELETE'
  final String operation;

  /// Timestamp when mutation occurred
  final DateTime timestamp;

  /// Number of sync attempt retries
  final int retryCount;
  const SyncQueueEntry({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.timestamp,
    required this.retryCount,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['entity_type'] = Variable<String>(entityType);
    map['entity_id'] = Variable<String>(entityId);
    map['operation'] = Variable<String>(operation);
    map['timestamp'] = Variable<DateTime>(timestamp);
    map['retry_count'] = Variable<int>(retryCount);
    return map;
  }

  SyncQueueCompanion toCompanion(bool nullToAbsent) {
    return SyncQueueCompanion(
      id: Value(id),
      entityType: Value(entityType),
      entityId: Value(entityId),
      operation: Value(operation),
      timestamp: Value(timestamp),
      retryCount: Value(retryCount),
    );
  }

  factory SyncQueueEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncQueueEntry(
      id: serializer.fromJson<String>(json['id']),
      entityType: serializer.fromJson<String>(json['entityType']),
      entityId: serializer.fromJson<String>(json['entityId']),
      operation: serializer.fromJson<String>(json['operation']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
      retryCount: serializer.fromJson<int>(json['retryCount']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'entityType': serializer.toJson<String>(entityType),
      'entityId': serializer.toJson<String>(entityId),
      'operation': serializer.toJson<String>(operation),
      'timestamp': serializer.toJson<DateTime>(timestamp),
      'retryCount': serializer.toJson<int>(retryCount),
    };
  }

  SyncQueueEntry copyWith({
    String? id,
    String? entityType,
    String? entityId,
    String? operation,
    DateTime? timestamp,
    int? retryCount,
  }) => SyncQueueEntry(
    id: id ?? this.id,
    entityType: entityType ?? this.entityType,
    entityId: entityId ?? this.entityId,
    operation: operation ?? this.operation,
    timestamp: timestamp ?? this.timestamp,
    retryCount: retryCount ?? this.retryCount,
  );
  SyncQueueEntry copyWithCompanion(SyncQueueCompanion data) {
    return SyncQueueEntry(
      id: data.id.present ? data.id.value : this.id,
      entityType: data.entityType.present
          ? data.entityType.value
          : this.entityType,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      operation: data.operation.present ? data.operation.value : this.operation,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
      retryCount: data.retryCount.present
          ? data.retryCount.value
          : this.retryCount,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncQueueEntry(')
          ..write('id: $id, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('operation: $operation, ')
          ..write('timestamp: $timestamp, ')
          ..write('retryCount: $retryCount')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, entityType, entityId, operation, timestamp, retryCount);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncQueueEntry &&
          other.id == this.id &&
          other.entityType == this.entityType &&
          other.entityId == this.entityId &&
          other.operation == this.operation &&
          other.timestamp == this.timestamp &&
          other.retryCount == this.retryCount);
}

class SyncQueueCompanion extends UpdateCompanion<SyncQueueEntry> {
  final Value<String> id;
  final Value<String> entityType;
  final Value<String> entityId;
  final Value<String> operation;
  final Value<DateTime> timestamp;
  final Value<int> retryCount;
  final Value<int> rowid;
  const SyncQueueCompanion({
    this.id = const Value.absent(),
    this.entityType = const Value.absent(),
    this.entityId = const Value.absent(),
    this.operation = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncQueueCompanion.insert({
    required String id,
    required String entityType,
    required String entityId,
    required String operation,
    required DateTime timestamp,
    this.retryCount = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       entityType = Value(entityType),
       entityId = Value(entityId),
       operation = Value(operation),
       timestamp = Value(timestamp);
  static Insertable<SyncQueueEntry> custom({
    Expression<String>? id,
    Expression<String>? entityType,
    Expression<String>? entityId,
    Expression<String>? operation,
    Expression<DateTime>? timestamp,
    Expression<int>? retryCount,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (entityType != null) 'entity_type': entityType,
      if (entityId != null) 'entity_id': entityId,
      if (operation != null) 'operation': operation,
      if (timestamp != null) 'timestamp': timestamp,
      if (retryCount != null) 'retry_count': retryCount,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncQueueCompanion copyWith({
    Value<String>? id,
    Value<String>? entityType,
    Value<String>? entityId,
    Value<String>? operation,
    Value<DateTime>? timestamp,
    Value<int>? retryCount,
    Value<int>? rowid,
  }) {
    return SyncQueueCompanion(
      id: id ?? this.id,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      operation: operation ?? this.operation,
      timestamp: timestamp ?? this.timestamp,
      retryCount: retryCount ?? this.retryCount,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (entityType.present) {
      map['entity_type'] = Variable<String>(entityType.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (operation.present) {
      map['operation'] = Variable<String>(operation.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    if (retryCount.present) {
      map['retry_count'] = Variable<int>(retryCount.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncQueueCompanion(')
          ..write('id: $id, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('operation: $operation, ')
          ..write('timestamp: $timestamp, ')
          ..write('retryCount: $retryCount, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $VaultBindersTable vaultBinders = $VaultBindersTable(this);
  late final $VaultItemsTable vaultItems = $VaultItemsTable(this);
  late final $DecksTable decks = $DecksTable(this);
  late final $DeckVersionsTable deckVersions = $DeckVersionsTable(this);
  late final $DeckVersionItemsTable deckVersionItems = $DeckVersionItemsTable(
    this,
  );
  late final $DeckMatchupsTable deckMatchups = $DeckMatchupsTable(this);
  late final $DeckSynergiesTable deckSynergies = $DeckSynergiesTable(this);
  late final $SyncQueueTable syncQueue = $SyncQueueTable(this);
  late final VaultDao vaultDao = VaultDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    vaultBinders,
    vaultItems,
    decks,
    deckVersions,
    deckVersionItems,
    deckMatchups,
    deckSynergies,
    syncQueue,
  ];
}

typedef $$VaultBindersTableCreateCompanionBuilder =
    VaultBindersCompanion Function({
      required String id,
      required String name,
      required String collectionType,
      required DateTime createdAt,
      Value<bool> isDeleted,
      Value<DateTime?> updatedAt,
      Value<int> rowid,
    });
typedef $$VaultBindersTableUpdateCompanionBuilder =
    VaultBindersCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> collectionType,
      Value<DateTime> createdAt,
      Value<bool> isDeleted,
      Value<DateTime?> updatedAt,
      Value<int> rowid,
    });

final class $$VaultBindersTableReferences
    extends BaseReferences<_$AppDatabase, $VaultBindersTable, VaultBinder> {
  $$VaultBindersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$VaultItemsTable, List<VaultItem>>
  _vaultItemsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.vaultItems,
    aliasName: 'vault_binders__id__vault_items__primary_binder_id',
  );

  $$VaultItemsTableProcessedTableManager get vaultItemsRefs {
    final manager = $$VaultItemsTableTableManager($_db, $_db.vaultItems).filter(
      (f) => f.primaryBinderId.id.sqlEquals($_itemColumn<String>('id')!),
    );

    final cache = $_typedResult.readTableOrNull(_vaultItemsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$VaultBindersTableFilterComposer
    extends Composer<_$AppDatabase, $VaultBindersTable> {
  $$VaultBindersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get collectionType => $composableBuilder(
    column: $table.collectionType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> vaultItemsRefs(
    Expression<bool> Function($$VaultItemsTableFilterComposer f) f,
  ) {
    final $$VaultItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.vaultItems,
      getReferencedColumn: (t) => t.primaryBinderId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VaultItemsTableFilterComposer(
            $db: $db,
            $table: $db.vaultItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$VaultBindersTableOrderingComposer
    extends Composer<_$AppDatabase, $VaultBindersTable> {
  $$VaultBindersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get collectionType => $composableBuilder(
    column: $table.collectionType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$VaultBindersTableAnnotationComposer
    extends Composer<_$AppDatabase, $VaultBindersTable> {
  $$VaultBindersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get collectionType => $composableBuilder(
    column: $table.collectionType,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> vaultItemsRefs<T extends Object>(
    Expression<T> Function($$VaultItemsTableAnnotationComposer a) f,
  ) {
    final $$VaultItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.vaultItems,
      getReferencedColumn: (t) => t.primaryBinderId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VaultItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.vaultItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$VaultBindersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $VaultBindersTable,
          VaultBinder,
          $$VaultBindersTableFilterComposer,
          $$VaultBindersTableOrderingComposer,
          $$VaultBindersTableAnnotationComposer,
          $$VaultBindersTableCreateCompanionBuilder,
          $$VaultBindersTableUpdateCompanionBuilder,
          (VaultBinder, $$VaultBindersTableReferences),
          VaultBinder,
          PrefetchHooks Function({bool vaultItemsRefs})
        > {
  $$VaultBindersTableTableManager(_$AppDatabase db, $VaultBindersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$VaultBindersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$VaultBindersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$VaultBindersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> collectionType = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => VaultBindersCompanion(
                id: id,
                name: name,
                collectionType: collectionType,
                createdAt: createdAt,
                isDeleted: isDeleted,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String collectionType,
                required DateTime createdAt,
                Value<bool> isDeleted = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => VaultBindersCompanion.insert(
                id: id,
                name: name,
                collectionType: collectionType,
                createdAt: createdAt,
                isDeleted: isDeleted,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$VaultBindersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({vaultItemsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (vaultItemsRefs) db.vaultItems],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (vaultItemsRefs)
                    await $_getPrefetchedData<
                      VaultBinder,
                      $VaultBindersTable,
                      VaultItem
                    >(
                      currentTable: table,
                      referencedTable: $$VaultBindersTableReferences
                          ._vaultItemsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$VaultBindersTableReferences(
                            db,
                            table,
                            p0,
                          ).vaultItemsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where(
                            (e) => e.primaryBinderId == item.id,
                          ),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$VaultBindersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $VaultBindersTable,
      VaultBinder,
      $$VaultBindersTableFilterComposer,
      $$VaultBindersTableOrderingComposer,
      $$VaultBindersTableAnnotationComposer,
      $$VaultBindersTableCreateCompanionBuilder,
      $$VaultBindersTableUpdateCompanionBuilder,
      (VaultBinder, $$VaultBindersTableReferences),
      VaultBinder,
      PrefetchHooks Function({bool vaultItemsRefs})
    >;
typedef $$VaultItemsTableCreateCompanionBuilder =
    VaultItemsCompanion Function({
      required String id,
      required String collectionType,
      required String name,
      required String setOrSeries,
      required String imageUrl,
      Value<String?> flavorName,
      required double acquiredPrice,
      required DateTime acquiredDate,
      Value<int> quantity,
      required String condition,
      Value<bool> isGraded,
      Value<bool> isAltered,
      Value<bool> isMisprint,
      Value<bool> isSigned,
      Value<String?> personalNotes,
      Value<DateTime?> dateObtained,
      Value<double?> purchasePrice,
      Value<int?> binderPage,
      Value<String?> binderSlot,
      Value<String?> notes,
      Value<String?> protectionStatus,
      Value<String?> primaryBinderId,
      required double currentMarketPrice,
      required DateTime lastPriceUpdate,
      required String dynamicData,
      Value<bool> isDeleted,
      Value<DateTime?> updatedAt,
      Value<int> rowid,
    });
typedef $$VaultItemsTableUpdateCompanionBuilder =
    VaultItemsCompanion Function({
      Value<String> id,
      Value<String> collectionType,
      Value<String> name,
      Value<String> setOrSeries,
      Value<String> imageUrl,
      Value<String?> flavorName,
      Value<double> acquiredPrice,
      Value<DateTime> acquiredDate,
      Value<int> quantity,
      Value<String> condition,
      Value<bool> isGraded,
      Value<bool> isAltered,
      Value<bool> isMisprint,
      Value<bool> isSigned,
      Value<String?> personalNotes,
      Value<DateTime?> dateObtained,
      Value<double?> purchasePrice,
      Value<int?> binderPage,
      Value<String?> binderSlot,
      Value<String?> notes,
      Value<String?> protectionStatus,
      Value<String?> primaryBinderId,
      Value<double> currentMarketPrice,
      Value<DateTime> lastPriceUpdate,
      Value<String> dynamicData,
      Value<bool> isDeleted,
      Value<DateTime?> updatedAt,
      Value<int> rowid,
    });

final class $$VaultItemsTableReferences
    extends BaseReferences<_$AppDatabase, $VaultItemsTable, VaultItem> {
  $$VaultItemsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $VaultBindersTable _primaryBinderIdTable(_$AppDatabase db) => db
      .vaultBinders
      .createAlias('vault_items__primary_binder_id__vault_binders__id');

  $$VaultBindersTableProcessedTableManager? get primaryBinderId {
    final $_column = $_itemColumn<String>('primary_binder_id');
    if ($_column == null) return null;
    final manager = $$VaultBindersTableTableManager(
      $_db,
      $_db.vaultBinders,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_primaryBinderIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$DeckVersionItemsTable, List<DeckVersionItem>>
  _deckVersionItemsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.deckVersionItems,
    aliasName: 'vault_items__id__deck_version_items__vault_item_id',
  );

  $$DeckVersionItemsTableProcessedTableManager get deckVersionItemsRefs {
    final manager = $$DeckVersionItemsTableTableManager(
      $_db,
      $_db.deckVersionItems,
    ).filter((f) => f.vaultItemId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _deckVersionItemsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$VaultItemsTableFilterComposer
    extends Composer<_$AppDatabase, $VaultItemsTable> {
  $$VaultItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get collectionType => $composableBuilder(
    column: $table.collectionType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get setOrSeries => $composableBuilder(
    column: $table.setOrSeries,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imageUrl => $composableBuilder(
    column: $table.imageUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get flavorName => $composableBuilder(
    column: $table.flavorName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get acquiredPrice => $composableBuilder(
    column: $table.acquiredPrice,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get acquiredDate => $composableBuilder(
    column: $table.acquiredDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get condition => $composableBuilder(
    column: $table.condition,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isGraded => $composableBuilder(
    column: $table.isGraded,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isAltered => $composableBuilder(
    column: $table.isAltered,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isMisprint => $composableBuilder(
    column: $table.isMisprint,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isSigned => $composableBuilder(
    column: $table.isSigned,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get personalNotes => $composableBuilder(
    column: $table.personalNotes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get dateObtained => $composableBuilder(
    column: $table.dateObtained,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get purchasePrice => $composableBuilder(
    column: $table.purchasePrice,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get binderPage => $composableBuilder(
    column: $table.binderPage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get binderSlot => $composableBuilder(
    column: $table.binderSlot,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get protectionStatus => $composableBuilder(
    column: $table.protectionStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get currentMarketPrice => $composableBuilder(
    column: $table.currentMarketPrice,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastPriceUpdate => $composableBuilder(
    column: $table.lastPriceUpdate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dynamicData => $composableBuilder(
    column: $table.dynamicData,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$VaultBindersTableFilterComposer get primaryBinderId {
    final $$VaultBindersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.primaryBinderId,
      referencedTable: $db.vaultBinders,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VaultBindersTableFilterComposer(
            $db: $db,
            $table: $db.vaultBinders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> deckVersionItemsRefs(
    Expression<bool> Function($$DeckVersionItemsTableFilterComposer f) f,
  ) {
    final $$DeckVersionItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.deckVersionItems,
      getReferencedColumn: (t) => t.vaultItemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DeckVersionItemsTableFilterComposer(
            $db: $db,
            $table: $db.deckVersionItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$VaultItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $VaultItemsTable> {
  $$VaultItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get collectionType => $composableBuilder(
    column: $table.collectionType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get setOrSeries => $composableBuilder(
    column: $table.setOrSeries,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imageUrl => $composableBuilder(
    column: $table.imageUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get flavorName => $composableBuilder(
    column: $table.flavorName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get acquiredPrice => $composableBuilder(
    column: $table.acquiredPrice,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get acquiredDate => $composableBuilder(
    column: $table.acquiredDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get condition => $composableBuilder(
    column: $table.condition,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isGraded => $composableBuilder(
    column: $table.isGraded,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isAltered => $composableBuilder(
    column: $table.isAltered,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isMisprint => $composableBuilder(
    column: $table.isMisprint,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isSigned => $composableBuilder(
    column: $table.isSigned,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get personalNotes => $composableBuilder(
    column: $table.personalNotes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get dateObtained => $composableBuilder(
    column: $table.dateObtained,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get purchasePrice => $composableBuilder(
    column: $table.purchasePrice,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get binderPage => $composableBuilder(
    column: $table.binderPage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get binderSlot => $composableBuilder(
    column: $table.binderSlot,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get protectionStatus => $composableBuilder(
    column: $table.protectionStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get currentMarketPrice => $composableBuilder(
    column: $table.currentMarketPrice,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastPriceUpdate => $composableBuilder(
    column: $table.lastPriceUpdate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dynamicData => $composableBuilder(
    column: $table.dynamicData,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$VaultBindersTableOrderingComposer get primaryBinderId {
    final $$VaultBindersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.primaryBinderId,
      referencedTable: $db.vaultBinders,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VaultBindersTableOrderingComposer(
            $db: $db,
            $table: $db.vaultBinders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$VaultItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $VaultItemsTable> {
  $$VaultItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get collectionType => $composableBuilder(
    column: $table.collectionType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get setOrSeries => $composableBuilder(
    column: $table.setOrSeries,
    builder: (column) => column,
  );

  GeneratedColumn<String> get imageUrl =>
      $composableBuilder(column: $table.imageUrl, builder: (column) => column);

  GeneratedColumn<String> get flavorName => $composableBuilder(
    column: $table.flavorName,
    builder: (column) => column,
  );

  GeneratedColumn<double> get acquiredPrice => $composableBuilder(
    column: $table.acquiredPrice,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get acquiredDate => $composableBuilder(
    column: $table.acquiredDate,
    builder: (column) => column,
  );

  GeneratedColumn<int> get quantity =>
      $composableBuilder(column: $table.quantity, builder: (column) => column);

  GeneratedColumn<String> get condition =>
      $composableBuilder(column: $table.condition, builder: (column) => column);

  GeneratedColumn<bool> get isGraded =>
      $composableBuilder(column: $table.isGraded, builder: (column) => column);

  GeneratedColumn<bool> get isAltered =>
      $composableBuilder(column: $table.isAltered, builder: (column) => column);

  GeneratedColumn<bool> get isMisprint => $composableBuilder(
    column: $table.isMisprint,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isSigned =>
      $composableBuilder(column: $table.isSigned, builder: (column) => column);

  GeneratedColumn<String> get personalNotes => $composableBuilder(
    column: $table.personalNotes,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get dateObtained => $composableBuilder(
    column: $table.dateObtained,
    builder: (column) => column,
  );

  GeneratedColumn<double> get purchasePrice => $composableBuilder(
    column: $table.purchasePrice,
    builder: (column) => column,
  );

  GeneratedColumn<int> get binderPage => $composableBuilder(
    column: $table.binderPage,
    builder: (column) => column,
  );

  GeneratedColumn<String> get binderSlot => $composableBuilder(
    column: $table.binderSlot,
    builder: (column) => column,
  );

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<String> get protectionStatus => $composableBuilder(
    column: $table.protectionStatus,
    builder: (column) => column,
  );

  GeneratedColumn<double> get currentMarketPrice => $composableBuilder(
    column: $table.currentMarketPrice,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastPriceUpdate => $composableBuilder(
    column: $table.lastPriceUpdate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get dynamicData => $composableBuilder(
    column: $table.dynamicData,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$VaultBindersTableAnnotationComposer get primaryBinderId {
    final $$VaultBindersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.primaryBinderId,
      referencedTable: $db.vaultBinders,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VaultBindersTableAnnotationComposer(
            $db: $db,
            $table: $db.vaultBinders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> deckVersionItemsRefs<T extends Object>(
    Expression<T> Function($$DeckVersionItemsTableAnnotationComposer a) f,
  ) {
    final $$DeckVersionItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.deckVersionItems,
      getReferencedColumn: (t) => t.vaultItemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DeckVersionItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.deckVersionItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$VaultItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $VaultItemsTable,
          VaultItem,
          $$VaultItemsTableFilterComposer,
          $$VaultItemsTableOrderingComposer,
          $$VaultItemsTableAnnotationComposer,
          $$VaultItemsTableCreateCompanionBuilder,
          $$VaultItemsTableUpdateCompanionBuilder,
          (VaultItem, $$VaultItemsTableReferences),
          VaultItem,
          PrefetchHooks Function({
            bool primaryBinderId,
            bool deckVersionItemsRefs,
          })
        > {
  $$VaultItemsTableTableManager(_$AppDatabase db, $VaultItemsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$VaultItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$VaultItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$VaultItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> collectionType = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> setOrSeries = const Value.absent(),
                Value<String> imageUrl = const Value.absent(),
                Value<String?> flavorName = const Value.absent(),
                Value<double> acquiredPrice = const Value.absent(),
                Value<DateTime> acquiredDate = const Value.absent(),
                Value<int> quantity = const Value.absent(),
                Value<String> condition = const Value.absent(),
                Value<bool> isGraded = const Value.absent(),
                Value<bool> isAltered = const Value.absent(),
                Value<bool> isMisprint = const Value.absent(),
                Value<bool> isSigned = const Value.absent(),
                Value<String?> personalNotes = const Value.absent(),
                Value<DateTime?> dateObtained = const Value.absent(),
                Value<double?> purchasePrice = const Value.absent(),
                Value<int?> binderPage = const Value.absent(),
                Value<String?> binderSlot = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String?> protectionStatus = const Value.absent(),
                Value<String?> primaryBinderId = const Value.absent(),
                Value<double> currentMarketPrice = const Value.absent(),
                Value<DateTime> lastPriceUpdate = const Value.absent(),
                Value<String> dynamicData = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => VaultItemsCompanion(
                id: id,
                collectionType: collectionType,
                name: name,
                setOrSeries: setOrSeries,
                imageUrl: imageUrl,
                flavorName: flavorName,
                acquiredPrice: acquiredPrice,
                acquiredDate: acquiredDate,
                quantity: quantity,
                condition: condition,
                isGraded: isGraded,
                isAltered: isAltered,
                isMisprint: isMisprint,
                isSigned: isSigned,
                personalNotes: personalNotes,
                dateObtained: dateObtained,
                purchasePrice: purchasePrice,
                binderPage: binderPage,
                binderSlot: binderSlot,
                notes: notes,
                protectionStatus: protectionStatus,
                primaryBinderId: primaryBinderId,
                currentMarketPrice: currentMarketPrice,
                lastPriceUpdate: lastPriceUpdate,
                dynamicData: dynamicData,
                isDeleted: isDeleted,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String collectionType,
                required String name,
                required String setOrSeries,
                required String imageUrl,
                Value<String?> flavorName = const Value.absent(),
                required double acquiredPrice,
                required DateTime acquiredDate,
                Value<int> quantity = const Value.absent(),
                required String condition,
                Value<bool> isGraded = const Value.absent(),
                Value<bool> isAltered = const Value.absent(),
                Value<bool> isMisprint = const Value.absent(),
                Value<bool> isSigned = const Value.absent(),
                Value<String?> personalNotes = const Value.absent(),
                Value<DateTime?> dateObtained = const Value.absent(),
                Value<double?> purchasePrice = const Value.absent(),
                Value<int?> binderPage = const Value.absent(),
                Value<String?> binderSlot = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String?> protectionStatus = const Value.absent(),
                Value<String?> primaryBinderId = const Value.absent(),
                required double currentMarketPrice,
                required DateTime lastPriceUpdate,
                required String dynamicData,
                Value<bool> isDeleted = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => VaultItemsCompanion.insert(
                id: id,
                collectionType: collectionType,
                name: name,
                setOrSeries: setOrSeries,
                imageUrl: imageUrl,
                flavorName: flavorName,
                acquiredPrice: acquiredPrice,
                acquiredDate: acquiredDate,
                quantity: quantity,
                condition: condition,
                isGraded: isGraded,
                isAltered: isAltered,
                isMisprint: isMisprint,
                isSigned: isSigned,
                personalNotes: personalNotes,
                dateObtained: dateObtained,
                purchasePrice: purchasePrice,
                binderPage: binderPage,
                binderSlot: binderSlot,
                notes: notes,
                protectionStatus: protectionStatus,
                primaryBinderId: primaryBinderId,
                currentMarketPrice: currentMarketPrice,
                lastPriceUpdate: lastPriceUpdate,
                dynamicData: dynamicData,
                isDeleted: isDeleted,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$VaultItemsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({primaryBinderId = false, deckVersionItemsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (deckVersionItemsRefs) db.deckVersionItems,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (primaryBinderId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.primaryBinderId,
                                    referencedTable: $$VaultItemsTableReferences
                                        ._primaryBinderIdTable(db),
                                    referencedColumn:
                                        $$VaultItemsTableReferences
                                            ._primaryBinderIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (deckVersionItemsRefs)
                        await $_getPrefetchedData<
                          VaultItem,
                          $VaultItemsTable,
                          DeckVersionItem
                        >(
                          currentTable: table,
                          referencedTable: $$VaultItemsTableReferences
                              ._deckVersionItemsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$VaultItemsTableReferences(
                                db,
                                table,
                                p0,
                              ).deckVersionItemsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.vaultItemId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$VaultItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $VaultItemsTable,
      VaultItem,
      $$VaultItemsTableFilterComposer,
      $$VaultItemsTableOrderingComposer,
      $$VaultItemsTableAnnotationComposer,
      $$VaultItemsTableCreateCompanionBuilder,
      $$VaultItemsTableUpdateCompanionBuilder,
      (VaultItem, $$VaultItemsTableReferences),
      VaultItem,
      PrefetchHooks Function({bool primaryBinderId, bool deckVersionItemsRefs})
    >;
typedef $$DecksTableCreateCompanionBuilder =
    DecksCompanion Function({
      required String id,
      required String name,
      required String format,
      Value<String?> description,
      Value<int> wins,
      Value<int> losses,
      Value<int> draws,
      Value<String?> coverItemId,
      Value<String?> coverCropRect,
      required DateTime createdAt,
      Value<String> tcgDomain,
      Value<bool> isRegistered,
      Value<bool> isCompetitive,
      Value<bool> isAssembled,
      Value<bool> isDeleted,
      Value<DateTime?> updatedAt,
      Value<int> rowid,
    });
typedef $$DecksTableUpdateCompanionBuilder =
    DecksCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> format,
      Value<String?> description,
      Value<int> wins,
      Value<int> losses,
      Value<int> draws,
      Value<String?> coverItemId,
      Value<String?> coverCropRect,
      Value<DateTime> createdAt,
      Value<String> tcgDomain,
      Value<bool> isRegistered,
      Value<bool> isCompetitive,
      Value<bool> isAssembled,
      Value<bool> isDeleted,
      Value<DateTime?> updatedAt,
      Value<int> rowid,
    });

final class $$DecksTableReferences
    extends BaseReferences<_$AppDatabase, $DecksTable, Deck> {
  $$DecksTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$DeckVersionsTable, List<DeckVersion>>
  _deckVersionsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.deckVersions,
    aliasName: 'decks__id__deck_versions__deck_id',
  );

  $$DeckVersionsTableProcessedTableManager get deckVersionsRefs {
    final manager = $$DeckVersionsTableTableManager(
      $_db,
      $_db.deckVersions,
    ).filter((f) => f.deckId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_deckVersionsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$DeckMatchupsTable, List<DeckMatchup>>
  _deckMatchupsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.deckMatchups,
    aliasName: 'decks__id__deck_matchups__deck_id',
  );

  $$DeckMatchupsTableProcessedTableManager get deckMatchupsRefs {
    final manager = $$DeckMatchupsTableTableManager(
      $_db,
      $_db.deckMatchups,
    ).filter((f) => f.deckId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_deckMatchupsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$DeckSynergiesTable, List<DeckSynergy>>
  _deckSynergiesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.deckSynergies,
    aliasName: 'decks__id__deck_synergies__deck_id',
  );

  $$DeckSynergiesTableProcessedTableManager get deckSynergiesRefs {
    final manager = $$DeckSynergiesTableTableManager(
      $_db,
      $_db.deckSynergies,
    ).filter((f) => f.deckId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_deckSynergiesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$DecksTableFilterComposer extends Composer<_$AppDatabase, $DecksTable> {
  $$DecksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get format => $composableBuilder(
    column: $table.format,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get wins => $composableBuilder(
    column: $table.wins,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get losses => $composableBuilder(
    column: $table.losses,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get draws => $composableBuilder(
    column: $table.draws,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coverItemId => $composableBuilder(
    column: $table.coverItemId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coverCropRect => $composableBuilder(
    column: $table.coverCropRect,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tcgDomain => $composableBuilder(
    column: $table.tcgDomain,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isRegistered => $composableBuilder(
    column: $table.isRegistered,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isCompetitive => $composableBuilder(
    column: $table.isCompetitive,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isAssembled => $composableBuilder(
    column: $table.isAssembled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> deckVersionsRefs(
    Expression<bool> Function($$DeckVersionsTableFilterComposer f) f,
  ) {
    final $$DeckVersionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.deckVersions,
      getReferencedColumn: (t) => t.deckId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DeckVersionsTableFilterComposer(
            $db: $db,
            $table: $db.deckVersions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> deckMatchupsRefs(
    Expression<bool> Function($$DeckMatchupsTableFilterComposer f) f,
  ) {
    final $$DeckMatchupsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.deckMatchups,
      getReferencedColumn: (t) => t.deckId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DeckMatchupsTableFilterComposer(
            $db: $db,
            $table: $db.deckMatchups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> deckSynergiesRefs(
    Expression<bool> Function($$DeckSynergiesTableFilterComposer f) f,
  ) {
    final $$DeckSynergiesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.deckSynergies,
      getReferencedColumn: (t) => t.deckId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DeckSynergiesTableFilterComposer(
            $db: $db,
            $table: $db.deckSynergies,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$DecksTableOrderingComposer
    extends Composer<_$AppDatabase, $DecksTable> {
  $$DecksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get format => $composableBuilder(
    column: $table.format,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get wins => $composableBuilder(
    column: $table.wins,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get losses => $composableBuilder(
    column: $table.losses,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get draws => $composableBuilder(
    column: $table.draws,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coverItemId => $composableBuilder(
    column: $table.coverItemId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coverCropRect => $composableBuilder(
    column: $table.coverCropRect,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tcgDomain => $composableBuilder(
    column: $table.tcgDomain,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isRegistered => $composableBuilder(
    column: $table.isRegistered,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isCompetitive => $composableBuilder(
    column: $table.isCompetitive,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isAssembled => $composableBuilder(
    column: $table.isAssembled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DecksTableAnnotationComposer
    extends Composer<_$AppDatabase, $DecksTable> {
  $$DecksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get format =>
      $composableBuilder(column: $table.format, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<int> get wins =>
      $composableBuilder(column: $table.wins, builder: (column) => column);

  GeneratedColumn<int> get losses =>
      $composableBuilder(column: $table.losses, builder: (column) => column);

  GeneratedColumn<int> get draws =>
      $composableBuilder(column: $table.draws, builder: (column) => column);

  GeneratedColumn<String> get coverItemId => $composableBuilder(
    column: $table.coverItemId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get coverCropRect => $composableBuilder(
    column: $table.coverCropRect,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get tcgDomain =>
      $composableBuilder(column: $table.tcgDomain, builder: (column) => column);

  GeneratedColumn<bool> get isRegistered => $composableBuilder(
    column: $table.isRegistered,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isCompetitive => $composableBuilder(
    column: $table.isCompetitive,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isAssembled => $composableBuilder(
    column: $table.isAssembled,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> deckVersionsRefs<T extends Object>(
    Expression<T> Function($$DeckVersionsTableAnnotationComposer a) f,
  ) {
    final $$DeckVersionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.deckVersions,
      getReferencedColumn: (t) => t.deckId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DeckVersionsTableAnnotationComposer(
            $db: $db,
            $table: $db.deckVersions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> deckMatchupsRefs<T extends Object>(
    Expression<T> Function($$DeckMatchupsTableAnnotationComposer a) f,
  ) {
    final $$DeckMatchupsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.deckMatchups,
      getReferencedColumn: (t) => t.deckId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DeckMatchupsTableAnnotationComposer(
            $db: $db,
            $table: $db.deckMatchups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> deckSynergiesRefs<T extends Object>(
    Expression<T> Function($$DeckSynergiesTableAnnotationComposer a) f,
  ) {
    final $$DeckSynergiesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.deckSynergies,
      getReferencedColumn: (t) => t.deckId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DeckSynergiesTableAnnotationComposer(
            $db: $db,
            $table: $db.deckSynergies,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$DecksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DecksTable,
          Deck,
          $$DecksTableFilterComposer,
          $$DecksTableOrderingComposer,
          $$DecksTableAnnotationComposer,
          $$DecksTableCreateCompanionBuilder,
          $$DecksTableUpdateCompanionBuilder,
          (Deck, $$DecksTableReferences),
          Deck,
          PrefetchHooks Function({
            bool deckVersionsRefs,
            bool deckMatchupsRefs,
            bool deckSynergiesRefs,
          })
        > {
  $$DecksTableTableManager(_$AppDatabase db, $DecksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DecksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DecksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DecksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> format = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<int> wins = const Value.absent(),
                Value<int> losses = const Value.absent(),
                Value<int> draws = const Value.absent(),
                Value<String?> coverItemId = const Value.absent(),
                Value<String?> coverCropRect = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<String> tcgDomain = const Value.absent(),
                Value<bool> isRegistered = const Value.absent(),
                Value<bool> isCompetitive = const Value.absent(),
                Value<bool> isAssembled = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DecksCompanion(
                id: id,
                name: name,
                format: format,
                description: description,
                wins: wins,
                losses: losses,
                draws: draws,
                coverItemId: coverItemId,
                coverCropRect: coverCropRect,
                createdAt: createdAt,
                tcgDomain: tcgDomain,
                isRegistered: isRegistered,
                isCompetitive: isCompetitive,
                isAssembled: isAssembled,
                isDeleted: isDeleted,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String format,
                Value<String?> description = const Value.absent(),
                Value<int> wins = const Value.absent(),
                Value<int> losses = const Value.absent(),
                Value<int> draws = const Value.absent(),
                Value<String?> coverItemId = const Value.absent(),
                Value<String?> coverCropRect = const Value.absent(),
                required DateTime createdAt,
                Value<String> tcgDomain = const Value.absent(),
                Value<bool> isRegistered = const Value.absent(),
                Value<bool> isCompetitive = const Value.absent(),
                Value<bool> isAssembled = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DecksCompanion.insert(
                id: id,
                name: name,
                format: format,
                description: description,
                wins: wins,
                losses: losses,
                draws: draws,
                coverItemId: coverItemId,
                coverCropRect: coverCropRect,
                createdAt: createdAt,
                tcgDomain: tcgDomain,
                isRegistered: isRegistered,
                isCompetitive: isCompetitive,
                isAssembled: isAssembled,
                isDeleted: isDeleted,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$DecksTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                deckVersionsRefs = false,
                deckMatchupsRefs = false,
                deckSynergiesRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (deckVersionsRefs) db.deckVersions,
                    if (deckMatchupsRefs) db.deckMatchups,
                    if (deckSynergiesRefs) db.deckSynergies,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (deckVersionsRefs)
                        await $_getPrefetchedData<
                          Deck,
                          $DecksTable,
                          DeckVersion
                        >(
                          currentTable: table,
                          referencedTable: $$DecksTableReferences
                              ._deckVersionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$DecksTableReferences(
                                db,
                                table,
                                p0,
                              ).deckVersionsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.deckId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (deckMatchupsRefs)
                        await $_getPrefetchedData<
                          Deck,
                          $DecksTable,
                          DeckMatchup
                        >(
                          currentTable: table,
                          referencedTable: $$DecksTableReferences
                              ._deckMatchupsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$DecksTableReferences(
                                db,
                                table,
                                p0,
                              ).deckMatchupsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.deckId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (deckSynergiesRefs)
                        await $_getPrefetchedData<
                          Deck,
                          $DecksTable,
                          DeckSynergy
                        >(
                          currentTable: table,
                          referencedTable: $$DecksTableReferences
                              ._deckSynergiesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$DecksTableReferences(
                                db,
                                table,
                                p0,
                              ).deckSynergiesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.deckId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$DecksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DecksTable,
      Deck,
      $$DecksTableFilterComposer,
      $$DecksTableOrderingComposer,
      $$DecksTableAnnotationComposer,
      $$DecksTableCreateCompanionBuilder,
      $$DecksTableUpdateCompanionBuilder,
      (Deck, $$DecksTableReferences),
      Deck,
      PrefetchHooks Function({
        bool deckVersionsRefs,
        bool deckMatchupsRefs,
        bool deckSynergiesRefs,
      })
    >;
typedef $$DeckVersionsTableCreateCompanionBuilder =
    DeckVersionsCompanion Function({
      required String id,
      required String deckId,
      required int versionNumber,
      Value<String?> versionNote,
      Value<bool> isActive,
      required DateTime createdAt,
      Value<bool> isDeleted,
      Value<DateTime?> updatedAt,
      Value<int> rowid,
    });
typedef $$DeckVersionsTableUpdateCompanionBuilder =
    DeckVersionsCompanion Function({
      Value<String> id,
      Value<String> deckId,
      Value<int> versionNumber,
      Value<String?> versionNote,
      Value<bool> isActive,
      Value<DateTime> createdAt,
      Value<bool> isDeleted,
      Value<DateTime?> updatedAt,
      Value<int> rowid,
    });

final class $$DeckVersionsTableReferences
    extends BaseReferences<_$AppDatabase, $DeckVersionsTable, DeckVersion> {
  $$DeckVersionsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $DecksTable _deckIdTable(_$AppDatabase db) =>
      db.decks.createAlias('deck_versions__deck_id__decks__id');

  $$DecksTableProcessedTableManager get deckId {
    final $_column = $_itemColumn<String>('deck_id')!;

    final manager = $$DecksTableTableManager(
      $_db,
      $_db.decks,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_deckIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$DeckVersionItemsTable, List<DeckVersionItem>>
  _deckVersionItemsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.deckVersionItems,
    aliasName: 'deck_versions__id__deck_version_items__version_id',
  );

  $$DeckVersionItemsTableProcessedTableManager get deckVersionItemsRefs {
    final manager = $$DeckVersionItemsTableTableManager(
      $_db,
      $_db.deckVersionItems,
    ).filter((f) => f.versionId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _deckVersionItemsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$DeckVersionsTableFilterComposer
    extends Composer<_$AppDatabase, $DeckVersionsTable> {
  $$DeckVersionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get versionNumber => $composableBuilder(
    column: $table.versionNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get versionNote => $composableBuilder(
    column: $table.versionNote,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$DecksTableFilterComposer get deckId {
    final $$DecksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.deckId,
      referencedTable: $db.decks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DecksTableFilterComposer(
            $db: $db,
            $table: $db.decks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> deckVersionItemsRefs(
    Expression<bool> Function($$DeckVersionItemsTableFilterComposer f) f,
  ) {
    final $$DeckVersionItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.deckVersionItems,
      getReferencedColumn: (t) => t.versionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DeckVersionItemsTableFilterComposer(
            $db: $db,
            $table: $db.deckVersionItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$DeckVersionsTableOrderingComposer
    extends Composer<_$AppDatabase, $DeckVersionsTable> {
  $$DeckVersionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get versionNumber => $composableBuilder(
    column: $table.versionNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get versionNote => $composableBuilder(
    column: $table.versionNote,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$DecksTableOrderingComposer get deckId {
    final $$DecksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.deckId,
      referencedTable: $db.decks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DecksTableOrderingComposer(
            $db: $db,
            $table: $db.decks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DeckVersionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DeckVersionsTable> {
  $$DeckVersionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get versionNumber => $composableBuilder(
    column: $table.versionNumber,
    builder: (column) => column,
  );

  GeneratedColumn<String> get versionNote => $composableBuilder(
    column: $table.versionNote,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$DecksTableAnnotationComposer get deckId {
    final $$DecksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.deckId,
      referencedTable: $db.decks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DecksTableAnnotationComposer(
            $db: $db,
            $table: $db.decks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> deckVersionItemsRefs<T extends Object>(
    Expression<T> Function($$DeckVersionItemsTableAnnotationComposer a) f,
  ) {
    final $$DeckVersionItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.deckVersionItems,
      getReferencedColumn: (t) => t.versionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DeckVersionItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.deckVersionItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$DeckVersionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DeckVersionsTable,
          DeckVersion,
          $$DeckVersionsTableFilterComposer,
          $$DeckVersionsTableOrderingComposer,
          $$DeckVersionsTableAnnotationComposer,
          $$DeckVersionsTableCreateCompanionBuilder,
          $$DeckVersionsTableUpdateCompanionBuilder,
          (DeckVersion, $$DeckVersionsTableReferences),
          DeckVersion,
          PrefetchHooks Function({bool deckId, bool deckVersionItemsRefs})
        > {
  $$DeckVersionsTableTableManager(_$AppDatabase db, $DeckVersionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DeckVersionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DeckVersionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DeckVersionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> deckId = const Value.absent(),
                Value<int> versionNumber = const Value.absent(),
                Value<String?> versionNote = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DeckVersionsCompanion(
                id: id,
                deckId: deckId,
                versionNumber: versionNumber,
                versionNote: versionNote,
                isActive: isActive,
                createdAt: createdAt,
                isDeleted: isDeleted,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String deckId,
                required int versionNumber,
                Value<String?> versionNote = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                required DateTime createdAt,
                Value<bool> isDeleted = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DeckVersionsCompanion.insert(
                id: id,
                deckId: deckId,
                versionNumber: versionNumber,
                versionNote: versionNote,
                isActive: isActive,
                createdAt: createdAt,
                isDeleted: isDeleted,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$DeckVersionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({deckId = false, deckVersionItemsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (deckVersionItemsRefs) db.deckVersionItems,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (deckId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.deckId,
                                    referencedTable:
                                        $$DeckVersionsTableReferences
                                            ._deckIdTable(db),
                                    referencedColumn:
                                        $$DeckVersionsTableReferences
                                            ._deckIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (deckVersionItemsRefs)
                        await $_getPrefetchedData<
                          DeckVersion,
                          $DeckVersionsTable,
                          DeckVersionItem
                        >(
                          currentTable: table,
                          referencedTable: $$DeckVersionsTableReferences
                              ._deckVersionItemsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$DeckVersionsTableReferences(
                                db,
                                table,
                                p0,
                              ).deckVersionItemsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.versionId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$DeckVersionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DeckVersionsTable,
      DeckVersion,
      $$DeckVersionsTableFilterComposer,
      $$DeckVersionsTableOrderingComposer,
      $$DeckVersionsTableAnnotationComposer,
      $$DeckVersionsTableCreateCompanionBuilder,
      $$DeckVersionsTableUpdateCompanionBuilder,
      (DeckVersion, $$DeckVersionsTableReferences),
      DeckVersion,
      PrefetchHooks Function({bool deckId, bool deckVersionItemsRefs})
    >;
typedef $$DeckVersionItemsTableCreateCompanionBuilder =
    DeckVersionItemsCompanion Function({
      required String id,
      required String versionId,
      required String vaultItemId,
      Value<int> quantity,
      required String boardZone,
      Value<bool> isProxy,
      Value<bool> isDeleted,
      Value<DateTime?> updatedAt,
      Value<int> rowid,
    });
typedef $$DeckVersionItemsTableUpdateCompanionBuilder =
    DeckVersionItemsCompanion Function({
      Value<String> id,
      Value<String> versionId,
      Value<String> vaultItemId,
      Value<int> quantity,
      Value<String> boardZone,
      Value<bool> isProxy,
      Value<bool> isDeleted,
      Value<DateTime?> updatedAt,
      Value<int> rowid,
    });

final class $$DeckVersionItemsTableReferences
    extends
        BaseReferences<_$AppDatabase, $DeckVersionItemsTable, DeckVersionItem> {
  $$DeckVersionItemsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $DeckVersionsTable _versionIdTable(_$AppDatabase db) => db.deckVersions
      .createAlias('deck_version_items__version_id__deck_versions__id');

  $$DeckVersionsTableProcessedTableManager get versionId {
    final $_column = $_itemColumn<String>('version_id')!;

    final manager = $$DeckVersionsTableTableManager(
      $_db,
      $_db.deckVersions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_versionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $VaultItemsTable _vaultItemIdTable(_$AppDatabase db) => db.vaultItems
      .createAlias('deck_version_items__vault_item_id__vault_items__id');

  $$VaultItemsTableProcessedTableManager get vaultItemId {
    final $_column = $_itemColumn<String>('vault_item_id')!;

    final manager = $$VaultItemsTableTableManager(
      $_db,
      $_db.vaultItems,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_vaultItemIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$DeckVersionItemsTableFilterComposer
    extends Composer<_$AppDatabase, $DeckVersionItemsTable> {
  $$DeckVersionItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get boardZone => $composableBuilder(
    column: $table.boardZone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isProxy => $composableBuilder(
    column: $table.isProxy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$DeckVersionsTableFilterComposer get versionId {
    final $$DeckVersionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.versionId,
      referencedTable: $db.deckVersions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DeckVersionsTableFilterComposer(
            $db: $db,
            $table: $db.deckVersions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$VaultItemsTableFilterComposer get vaultItemId {
    final $$VaultItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.vaultItemId,
      referencedTable: $db.vaultItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VaultItemsTableFilterComposer(
            $db: $db,
            $table: $db.vaultItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DeckVersionItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $DeckVersionItemsTable> {
  $$DeckVersionItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get boardZone => $composableBuilder(
    column: $table.boardZone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isProxy => $composableBuilder(
    column: $table.isProxy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$DeckVersionsTableOrderingComposer get versionId {
    final $$DeckVersionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.versionId,
      referencedTable: $db.deckVersions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DeckVersionsTableOrderingComposer(
            $db: $db,
            $table: $db.deckVersions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$VaultItemsTableOrderingComposer get vaultItemId {
    final $$VaultItemsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.vaultItemId,
      referencedTable: $db.vaultItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VaultItemsTableOrderingComposer(
            $db: $db,
            $table: $db.vaultItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DeckVersionItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DeckVersionItemsTable> {
  $$DeckVersionItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get quantity =>
      $composableBuilder(column: $table.quantity, builder: (column) => column);

  GeneratedColumn<String> get boardZone =>
      $composableBuilder(column: $table.boardZone, builder: (column) => column);

  GeneratedColumn<bool> get isProxy =>
      $composableBuilder(column: $table.isProxy, builder: (column) => column);

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$DeckVersionsTableAnnotationComposer get versionId {
    final $$DeckVersionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.versionId,
      referencedTable: $db.deckVersions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DeckVersionsTableAnnotationComposer(
            $db: $db,
            $table: $db.deckVersions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$VaultItemsTableAnnotationComposer get vaultItemId {
    final $$VaultItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.vaultItemId,
      referencedTable: $db.vaultItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VaultItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.vaultItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DeckVersionItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DeckVersionItemsTable,
          DeckVersionItem,
          $$DeckVersionItemsTableFilterComposer,
          $$DeckVersionItemsTableOrderingComposer,
          $$DeckVersionItemsTableAnnotationComposer,
          $$DeckVersionItemsTableCreateCompanionBuilder,
          $$DeckVersionItemsTableUpdateCompanionBuilder,
          (DeckVersionItem, $$DeckVersionItemsTableReferences),
          DeckVersionItem,
          PrefetchHooks Function({bool versionId, bool vaultItemId})
        > {
  $$DeckVersionItemsTableTableManager(
    _$AppDatabase db,
    $DeckVersionItemsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DeckVersionItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DeckVersionItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DeckVersionItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> versionId = const Value.absent(),
                Value<String> vaultItemId = const Value.absent(),
                Value<int> quantity = const Value.absent(),
                Value<String> boardZone = const Value.absent(),
                Value<bool> isProxy = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DeckVersionItemsCompanion(
                id: id,
                versionId: versionId,
                vaultItemId: vaultItemId,
                quantity: quantity,
                boardZone: boardZone,
                isProxy: isProxy,
                isDeleted: isDeleted,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String versionId,
                required String vaultItemId,
                Value<int> quantity = const Value.absent(),
                required String boardZone,
                Value<bool> isProxy = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DeckVersionItemsCompanion.insert(
                id: id,
                versionId: versionId,
                vaultItemId: vaultItemId,
                quantity: quantity,
                boardZone: boardZone,
                isProxy: isProxy,
                isDeleted: isDeleted,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$DeckVersionItemsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({versionId = false, vaultItemId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (versionId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.versionId,
                                referencedTable:
                                    $$DeckVersionItemsTableReferences
                                        ._versionIdTable(db),
                                referencedColumn:
                                    $$DeckVersionItemsTableReferences
                                        ._versionIdTable(db)
                                        .id,
                              )
                              as T;
                    }
                    if (vaultItemId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.vaultItemId,
                                referencedTable:
                                    $$DeckVersionItemsTableReferences
                                        ._vaultItemIdTable(db),
                                referencedColumn:
                                    $$DeckVersionItemsTableReferences
                                        ._vaultItemIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$DeckVersionItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DeckVersionItemsTable,
      DeckVersionItem,
      $$DeckVersionItemsTableFilterComposer,
      $$DeckVersionItemsTableOrderingComposer,
      $$DeckVersionItemsTableAnnotationComposer,
      $$DeckVersionItemsTableCreateCompanionBuilder,
      $$DeckVersionItemsTableUpdateCompanionBuilder,
      (DeckVersionItem, $$DeckVersionItemsTableReferences),
      DeckVersionItem,
      PrefetchHooks Function({bool versionId, bool vaultItemId})
    >;
typedef $$DeckMatchupsTableCreateCompanionBuilder =
    DeckMatchupsCompanion Function({
      required String id,
      required String deckId,
      required String opponentArchetype,
      Value<String?> notes,
      Value<String?> swapInItemIds,
      Value<String?> swapOutItemIds,
      Value<bool> isDeleted,
      Value<DateTime?> updatedAt,
      Value<int> rowid,
    });
typedef $$DeckMatchupsTableUpdateCompanionBuilder =
    DeckMatchupsCompanion Function({
      Value<String> id,
      Value<String> deckId,
      Value<String> opponentArchetype,
      Value<String?> notes,
      Value<String?> swapInItemIds,
      Value<String?> swapOutItemIds,
      Value<bool> isDeleted,
      Value<DateTime?> updatedAt,
      Value<int> rowid,
    });

final class $$DeckMatchupsTableReferences
    extends BaseReferences<_$AppDatabase, $DeckMatchupsTable, DeckMatchup> {
  $$DeckMatchupsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $DecksTable _deckIdTable(_$AppDatabase db) =>
      db.decks.createAlias('deck_matchups__deck_id__decks__id');

  $$DecksTableProcessedTableManager get deckId {
    final $_column = $_itemColumn<String>('deck_id')!;

    final manager = $$DecksTableTableManager(
      $_db,
      $_db.decks,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_deckIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$DeckMatchupsTableFilterComposer
    extends Composer<_$AppDatabase, $DeckMatchupsTable> {
  $$DeckMatchupsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get opponentArchetype => $composableBuilder(
    column: $table.opponentArchetype,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get swapInItemIds => $composableBuilder(
    column: $table.swapInItemIds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get swapOutItemIds => $composableBuilder(
    column: $table.swapOutItemIds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$DecksTableFilterComposer get deckId {
    final $$DecksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.deckId,
      referencedTable: $db.decks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DecksTableFilterComposer(
            $db: $db,
            $table: $db.decks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DeckMatchupsTableOrderingComposer
    extends Composer<_$AppDatabase, $DeckMatchupsTable> {
  $$DeckMatchupsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get opponentArchetype => $composableBuilder(
    column: $table.opponentArchetype,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get swapInItemIds => $composableBuilder(
    column: $table.swapInItemIds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get swapOutItemIds => $composableBuilder(
    column: $table.swapOutItemIds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$DecksTableOrderingComposer get deckId {
    final $$DecksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.deckId,
      referencedTable: $db.decks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DecksTableOrderingComposer(
            $db: $db,
            $table: $db.decks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DeckMatchupsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DeckMatchupsTable> {
  $$DeckMatchupsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get opponentArchetype => $composableBuilder(
    column: $table.opponentArchetype,
    builder: (column) => column,
  );

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<String> get swapInItemIds => $composableBuilder(
    column: $table.swapInItemIds,
    builder: (column) => column,
  );

  GeneratedColumn<String> get swapOutItemIds => $composableBuilder(
    column: $table.swapOutItemIds,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$DecksTableAnnotationComposer get deckId {
    final $$DecksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.deckId,
      referencedTable: $db.decks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DecksTableAnnotationComposer(
            $db: $db,
            $table: $db.decks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DeckMatchupsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DeckMatchupsTable,
          DeckMatchup,
          $$DeckMatchupsTableFilterComposer,
          $$DeckMatchupsTableOrderingComposer,
          $$DeckMatchupsTableAnnotationComposer,
          $$DeckMatchupsTableCreateCompanionBuilder,
          $$DeckMatchupsTableUpdateCompanionBuilder,
          (DeckMatchup, $$DeckMatchupsTableReferences),
          DeckMatchup,
          PrefetchHooks Function({bool deckId})
        > {
  $$DeckMatchupsTableTableManager(_$AppDatabase db, $DeckMatchupsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DeckMatchupsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DeckMatchupsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DeckMatchupsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> deckId = const Value.absent(),
                Value<String> opponentArchetype = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String?> swapInItemIds = const Value.absent(),
                Value<String?> swapOutItemIds = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DeckMatchupsCompanion(
                id: id,
                deckId: deckId,
                opponentArchetype: opponentArchetype,
                notes: notes,
                swapInItemIds: swapInItemIds,
                swapOutItemIds: swapOutItemIds,
                isDeleted: isDeleted,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String deckId,
                required String opponentArchetype,
                Value<String?> notes = const Value.absent(),
                Value<String?> swapInItemIds = const Value.absent(),
                Value<String?> swapOutItemIds = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DeckMatchupsCompanion.insert(
                id: id,
                deckId: deckId,
                opponentArchetype: opponentArchetype,
                notes: notes,
                swapInItemIds: swapInItemIds,
                swapOutItemIds: swapOutItemIds,
                isDeleted: isDeleted,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$DeckMatchupsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({deckId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (deckId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.deckId,
                                referencedTable: $$DeckMatchupsTableReferences
                                    ._deckIdTable(db),
                                referencedColumn: $$DeckMatchupsTableReferences
                                    ._deckIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$DeckMatchupsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DeckMatchupsTable,
      DeckMatchup,
      $$DeckMatchupsTableFilterComposer,
      $$DeckMatchupsTableOrderingComposer,
      $$DeckMatchupsTableAnnotationComposer,
      $$DeckMatchupsTableCreateCompanionBuilder,
      $$DeckMatchupsTableUpdateCompanionBuilder,
      (DeckMatchup, $$DeckMatchupsTableReferences),
      DeckMatchup,
      PrefetchHooks Function({bool deckId})
    >;
typedef $$DeckSynergiesTableCreateCompanionBuilder =
    DeckSynergiesCompanion Function({
      required String id,
      required String deckId,
      required String synergyName,
      required String vaultItemIds,
      Value<bool> isDeleted,
      Value<DateTime?> updatedAt,
      Value<int> rowid,
    });
typedef $$DeckSynergiesTableUpdateCompanionBuilder =
    DeckSynergiesCompanion Function({
      Value<String> id,
      Value<String> deckId,
      Value<String> synergyName,
      Value<String> vaultItemIds,
      Value<bool> isDeleted,
      Value<DateTime?> updatedAt,
      Value<int> rowid,
    });

final class $$DeckSynergiesTableReferences
    extends BaseReferences<_$AppDatabase, $DeckSynergiesTable, DeckSynergy> {
  $$DeckSynergiesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $DecksTable _deckIdTable(_$AppDatabase db) =>
      db.decks.createAlias('deck_synergies__deck_id__decks__id');

  $$DecksTableProcessedTableManager get deckId {
    final $_column = $_itemColumn<String>('deck_id')!;

    final manager = $$DecksTableTableManager(
      $_db,
      $_db.decks,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_deckIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$DeckSynergiesTableFilterComposer
    extends Composer<_$AppDatabase, $DeckSynergiesTable> {
  $$DeckSynergiesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get synergyName => $composableBuilder(
    column: $table.synergyName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get vaultItemIds => $composableBuilder(
    column: $table.vaultItemIds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$DecksTableFilterComposer get deckId {
    final $$DecksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.deckId,
      referencedTable: $db.decks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DecksTableFilterComposer(
            $db: $db,
            $table: $db.decks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DeckSynergiesTableOrderingComposer
    extends Composer<_$AppDatabase, $DeckSynergiesTable> {
  $$DeckSynergiesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get synergyName => $composableBuilder(
    column: $table.synergyName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get vaultItemIds => $composableBuilder(
    column: $table.vaultItemIds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$DecksTableOrderingComposer get deckId {
    final $$DecksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.deckId,
      referencedTable: $db.decks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DecksTableOrderingComposer(
            $db: $db,
            $table: $db.decks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DeckSynergiesTableAnnotationComposer
    extends Composer<_$AppDatabase, $DeckSynergiesTable> {
  $$DeckSynergiesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get synergyName => $composableBuilder(
    column: $table.synergyName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get vaultItemIds => $composableBuilder(
    column: $table.vaultItemIds,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$DecksTableAnnotationComposer get deckId {
    final $$DecksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.deckId,
      referencedTable: $db.decks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DecksTableAnnotationComposer(
            $db: $db,
            $table: $db.decks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DeckSynergiesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DeckSynergiesTable,
          DeckSynergy,
          $$DeckSynergiesTableFilterComposer,
          $$DeckSynergiesTableOrderingComposer,
          $$DeckSynergiesTableAnnotationComposer,
          $$DeckSynergiesTableCreateCompanionBuilder,
          $$DeckSynergiesTableUpdateCompanionBuilder,
          (DeckSynergy, $$DeckSynergiesTableReferences),
          DeckSynergy,
          PrefetchHooks Function({bool deckId})
        > {
  $$DeckSynergiesTableTableManager(_$AppDatabase db, $DeckSynergiesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DeckSynergiesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DeckSynergiesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DeckSynergiesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> deckId = const Value.absent(),
                Value<String> synergyName = const Value.absent(),
                Value<String> vaultItemIds = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DeckSynergiesCompanion(
                id: id,
                deckId: deckId,
                synergyName: synergyName,
                vaultItemIds: vaultItemIds,
                isDeleted: isDeleted,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String deckId,
                required String synergyName,
                required String vaultItemIds,
                Value<bool> isDeleted = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DeckSynergiesCompanion.insert(
                id: id,
                deckId: deckId,
                synergyName: synergyName,
                vaultItemIds: vaultItemIds,
                isDeleted: isDeleted,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$DeckSynergiesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({deckId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (deckId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.deckId,
                                referencedTable: $$DeckSynergiesTableReferences
                                    ._deckIdTable(db),
                                referencedColumn: $$DeckSynergiesTableReferences
                                    ._deckIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$DeckSynergiesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DeckSynergiesTable,
      DeckSynergy,
      $$DeckSynergiesTableFilterComposer,
      $$DeckSynergiesTableOrderingComposer,
      $$DeckSynergiesTableAnnotationComposer,
      $$DeckSynergiesTableCreateCompanionBuilder,
      $$DeckSynergiesTableUpdateCompanionBuilder,
      (DeckSynergy, $$DeckSynergiesTableReferences),
      DeckSynergy,
      PrefetchHooks Function({bool deckId})
    >;
typedef $$SyncQueueTableCreateCompanionBuilder =
    SyncQueueCompanion Function({
      required String id,
      required String entityType,
      required String entityId,
      required String operation,
      required DateTime timestamp,
      Value<int> retryCount,
      Value<int> rowid,
    });
typedef $$SyncQueueTableUpdateCompanionBuilder =
    SyncQueueCompanion Function({
      Value<String> id,
      Value<String> entityType,
      Value<String> entityId,
      Value<String> operation,
      Value<DateTime> timestamp,
      Value<int> retryCount,
      Value<int> rowid,
    });

class $$SyncQueueTableFilterComposer
    extends Composer<_$AppDatabase, $SyncQueueTable> {
  $$SyncQueueTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get operation => $composableBuilder(
    column: $table.operation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncQueueTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncQueueTable> {
  $$SyncQueueTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get operation => $composableBuilder(
    column: $table.operation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncQueueTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncQueueTable> {
  $$SyncQueueTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<String> get operation =>
      $composableBuilder(column: $table.operation, builder: (column) => column);

  GeneratedColumn<DateTime> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);

  GeneratedColumn<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => column,
  );
}

class $$SyncQueueTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncQueueTable,
          SyncQueueEntry,
          $$SyncQueueTableFilterComposer,
          $$SyncQueueTableOrderingComposer,
          $$SyncQueueTableAnnotationComposer,
          $$SyncQueueTableCreateCompanionBuilder,
          $$SyncQueueTableUpdateCompanionBuilder,
          (
            SyncQueueEntry,
            BaseReferences<_$AppDatabase, $SyncQueueTable, SyncQueueEntry>,
          ),
          SyncQueueEntry,
          PrefetchHooks Function()
        > {
  $$SyncQueueTableTableManager(_$AppDatabase db, $SyncQueueTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncQueueTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncQueueTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncQueueTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> entityType = const Value.absent(),
                Value<String> entityId = const Value.absent(),
                Value<String> operation = const Value.absent(),
                Value<DateTime> timestamp = const Value.absent(),
                Value<int> retryCount = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncQueueCompanion(
                id: id,
                entityType: entityType,
                entityId: entityId,
                operation: operation,
                timestamp: timestamp,
                retryCount: retryCount,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String entityType,
                required String entityId,
                required String operation,
                required DateTime timestamp,
                Value<int> retryCount = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncQueueCompanion.insert(
                id: id,
                entityType: entityType,
                entityId: entityId,
                operation: operation,
                timestamp: timestamp,
                retryCount: retryCount,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncQueueTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncQueueTable,
      SyncQueueEntry,
      $$SyncQueueTableFilterComposer,
      $$SyncQueueTableOrderingComposer,
      $$SyncQueueTableAnnotationComposer,
      $$SyncQueueTableCreateCompanionBuilder,
      $$SyncQueueTableUpdateCompanionBuilder,
      (
        SyncQueueEntry,
        BaseReferences<_$AppDatabase, $SyncQueueTable, SyncQueueEntry>,
      ),
      SyncQueueEntry,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$VaultBindersTableTableManager get vaultBinders =>
      $$VaultBindersTableTableManager(_db, _db.vaultBinders);
  $$VaultItemsTableTableManager get vaultItems =>
      $$VaultItemsTableTableManager(_db, _db.vaultItems);
  $$DecksTableTableManager get decks =>
      $$DecksTableTableManager(_db, _db.decks);
  $$DeckVersionsTableTableManager get deckVersions =>
      $$DeckVersionsTableTableManager(_db, _db.deckVersions);
  $$DeckVersionItemsTableTableManager get deckVersionItems =>
      $$DeckVersionItemsTableTableManager(_db, _db.deckVersionItems);
  $$DeckMatchupsTableTableManager get deckMatchups =>
      $$DeckMatchupsTableTableManager(_db, _db.deckMatchups);
  $$DeckSynergiesTableTableManager get deckSynergies =>
      $$DeckSynergiesTableTableManager(_db, _db.deckSynergies);
  $$SyncQueueTableTableManager get syncQueue =>
      $$SyncQueueTableTableManager(_db, _db.syncQueue);
}
