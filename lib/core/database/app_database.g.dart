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

class $MatchSessionsTable extends MatchSessions
    with TableInfo<$MatchSessionsTable, MatchSession> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MatchSessionsTable(this.attachedDatabase, [this._alias]);
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
    requiredDuringInsert: false,
    defaultValue: const Constant('MTG Match'),
  );
  static const VerificationMeta _formatMeta = const VerificationMeta('format');
  @override
  late final GeneratedColumn<String> format = GeneratedColumn<String>(
    'format',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('Commander'),
  );
  static const VerificationMeta _startingLifeMeta = const VerificationMeta(
    'startingLife',
  );
  @override
  late final GeneratedColumn<int> startingLife = GeneratedColumn<int>(
    'starting_life',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(40),
  );
  static const VerificationMeta _playerCountMeta = const VerificationMeta(
    'playerCount',
  );
  @override
  late final GeneratedColumn<int> playerCount = GeneratedColumn<int>(
    'player_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(4),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('active'),
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
  static const VerificationMeta _endedAtMeta = const VerificationMeta(
    'endedAt',
  );
  @override
  late final GeneratedColumn<DateTime> endedAt = GeneratedColumn<DateTime>(
    'ended_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isP2pHostMeta = const VerificationMeta(
    'isP2pHost',
  );
  @override
  late final GeneratedColumn<bool> isP2pHost = GeneratedColumn<bool>(
    'is_p2p_host',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_p2p_host" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _p2pSessionCodeMeta = const VerificationMeta(
    'p2pSessionCode',
  );
  @override
  late final GeneratedColumn<String> p2pSessionCode = GeneratedColumn<String>(
    'p2p_session_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _settingsJsonMeta = const VerificationMeta(
    'settingsJson',
  );
  @override
  late final GeneratedColumn<String> settingsJson = GeneratedColumn<String>(
    'settings_json',
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
    name,
    format,
    startingLife,
    playerCount,
    status,
    createdAt,
    endedAt,
    isP2pHost,
    p2pSessionCode,
    settingsJson,
    isDeleted,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'match_sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<MatchSession> instance, {
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
    }
    if (data.containsKey('format')) {
      context.handle(
        _formatMeta,
        format.isAcceptableOrUnknown(data['format']!, _formatMeta),
      );
    }
    if (data.containsKey('starting_life')) {
      context.handle(
        _startingLifeMeta,
        startingLife.isAcceptableOrUnknown(
          data['starting_life']!,
          _startingLifeMeta,
        ),
      );
    }
    if (data.containsKey('player_count')) {
      context.handle(
        _playerCountMeta,
        playerCount.isAcceptableOrUnknown(
          data['player_count']!,
          _playerCountMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
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
    if (data.containsKey('ended_at')) {
      context.handle(
        _endedAtMeta,
        endedAt.isAcceptableOrUnknown(data['ended_at']!, _endedAtMeta),
      );
    }
    if (data.containsKey('is_p2p_host')) {
      context.handle(
        _isP2pHostMeta,
        isP2pHost.isAcceptableOrUnknown(data['is_p2p_host']!, _isP2pHostMeta),
      );
    }
    if (data.containsKey('p2p_session_code')) {
      context.handle(
        _p2pSessionCodeMeta,
        p2pSessionCode.isAcceptableOrUnknown(
          data['p2p_session_code']!,
          _p2pSessionCodeMeta,
        ),
      );
    }
    if (data.containsKey('settings_json')) {
      context.handle(
        _settingsJsonMeta,
        settingsJson.isAcceptableOrUnknown(
          data['settings_json']!,
          _settingsJsonMeta,
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
  MatchSession map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MatchSession(
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
      startingLife: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}starting_life'],
      )!,
      playerCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}player_count'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      endedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}ended_at'],
      ),
      isP2pHost: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_p2p_host'],
      )!,
      p2pSessionCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}p2p_session_code'],
      ),
      settingsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}settings_json'],
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
  $MatchSessionsTable createAlias(String alias) {
    return $MatchSessionsTable(attachedDatabase, alias);
  }
}

class MatchSession extends DataClass implements Insertable<MatchSession> {
  /// Unique session identifier (UUID v4)
  final String id;

  /// Human-readable match name (e.g. "Commander Night - Pod 1")
  final String name;

  /// Match format (e.g. 'Commander', 'Standard', 'Brawl', 'Draft', 'Modern', 'Two-Headed Giant', 'Custom')
  final String format;

  /// Starting life total per player (e.g. 40 for Commander, 20 for Standard, 30 for Brawl)
  final int startingLife;

  /// Total number of player seats configured for this session (1..6)
  final int playerCount;

  /// Lifecycle status: 'active', 'completed', 'abandoned'
  final String status;

  /// Timestamp when match was created
  final DateTime createdAt;

  /// Timestamp when match ended or was abandoned
  final DateTime? endedAt;

  /// True if this device is the P2P host authority for this match
  final bool isP2pHost;

  /// 5-character alphanumeric room code for P2P mesh discovery and direct connect
  final String? p2pSessionCode;

  /// Arbitrary JSON configuration payload for extensible session settings
  final String? settingsJson;

  /// Soft deletion flag for offline-first data retention
  final bool isDeleted;

  /// Timestamp of last modification for sync conflict resolution
  final DateTime? updatedAt;
  const MatchSession({
    required this.id,
    required this.name,
    required this.format,
    required this.startingLife,
    required this.playerCount,
    required this.status,
    required this.createdAt,
    this.endedAt,
    required this.isP2pHost,
    this.p2pSessionCode,
    this.settingsJson,
    required this.isDeleted,
    this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['format'] = Variable<String>(format);
    map['starting_life'] = Variable<int>(startingLife);
    map['player_count'] = Variable<int>(playerCount);
    map['status'] = Variable<String>(status);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || endedAt != null) {
      map['ended_at'] = Variable<DateTime>(endedAt);
    }
    map['is_p2p_host'] = Variable<bool>(isP2pHost);
    if (!nullToAbsent || p2pSessionCode != null) {
      map['p2p_session_code'] = Variable<String>(p2pSessionCode);
    }
    if (!nullToAbsent || settingsJson != null) {
      map['settings_json'] = Variable<String>(settingsJson);
    }
    map['is_deleted'] = Variable<bool>(isDeleted);
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    return map;
  }

  MatchSessionsCompanion toCompanion(bool nullToAbsent) {
    return MatchSessionsCompanion(
      id: Value(id),
      name: Value(name),
      format: Value(format),
      startingLife: Value(startingLife),
      playerCount: Value(playerCount),
      status: Value(status),
      createdAt: Value(createdAt),
      endedAt: endedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(endedAt),
      isP2pHost: Value(isP2pHost),
      p2pSessionCode: p2pSessionCode == null && nullToAbsent
          ? const Value.absent()
          : Value(p2pSessionCode),
      settingsJson: settingsJson == null && nullToAbsent
          ? const Value.absent()
          : Value(settingsJson),
      isDeleted: Value(isDeleted),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
    );
  }

  factory MatchSession.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MatchSession(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      format: serializer.fromJson<String>(json['format']),
      startingLife: serializer.fromJson<int>(json['startingLife']),
      playerCount: serializer.fromJson<int>(json['playerCount']),
      status: serializer.fromJson<String>(json['status']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      endedAt: serializer.fromJson<DateTime?>(json['endedAt']),
      isP2pHost: serializer.fromJson<bool>(json['isP2pHost']),
      p2pSessionCode: serializer.fromJson<String?>(json['p2pSessionCode']),
      settingsJson: serializer.fromJson<String?>(json['settingsJson']),
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
      'startingLife': serializer.toJson<int>(startingLife),
      'playerCount': serializer.toJson<int>(playerCount),
      'status': serializer.toJson<String>(status),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'endedAt': serializer.toJson<DateTime?>(endedAt),
      'isP2pHost': serializer.toJson<bool>(isP2pHost),
      'p2pSessionCode': serializer.toJson<String?>(p2pSessionCode),
      'settingsJson': serializer.toJson<String?>(settingsJson),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
    };
  }

  MatchSession copyWith({
    String? id,
    String? name,
    String? format,
    int? startingLife,
    int? playerCount,
    String? status,
    DateTime? createdAt,
    Value<DateTime?> endedAt = const Value.absent(),
    bool? isP2pHost,
    Value<String?> p2pSessionCode = const Value.absent(),
    Value<String?> settingsJson = const Value.absent(),
    bool? isDeleted,
    Value<DateTime?> updatedAt = const Value.absent(),
  }) => MatchSession(
    id: id ?? this.id,
    name: name ?? this.name,
    format: format ?? this.format,
    startingLife: startingLife ?? this.startingLife,
    playerCount: playerCount ?? this.playerCount,
    status: status ?? this.status,
    createdAt: createdAt ?? this.createdAt,
    endedAt: endedAt.present ? endedAt.value : this.endedAt,
    isP2pHost: isP2pHost ?? this.isP2pHost,
    p2pSessionCode: p2pSessionCode.present
        ? p2pSessionCode.value
        : this.p2pSessionCode,
    settingsJson: settingsJson.present ? settingsJson.value : this.settingsJson,
    isDeleted: isDeleted ?? this.isDeleted,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
  );
  MatchSession copyWithCompanion(MatchSessionsCompanion data) {
    return MatchSession(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      format: data.format.present ? data.format.value : this.format,
      startingLife: data.startingLife.present
          ? data.startingLife.value
          : this.startingLife,
      playerCount: data.playerCount.present
          ? data.playerCount.value
          : this.playerCount,
      status: data.status.present ? data.status.value : this.status,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      endedAt: data.endedAt.present ? data.endedAt.value : this.endedAt,
      isP2pHost: data.isP2pHost.present ? data.isP2pHost.value : this.isP2pHost,
      p2pSessionCode: data.p2pSessionCode.present
          ? data.p2pSessionCode.value
          : this.p2pSessionCode,
      settingsJson: data.settingsJson.present
          ? data.settingsJson.value
          : this.settingsJson,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MatchSession(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('format: $format, ')
          ..write('startingLife: $startingLife, ')
          ..write('playerCount: $playerCount, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('isP2pHost: $isP2pHost, ')
          ..write('p2pSessionCode: $p2pSessionCode, ')
          ..write('settingsJson: $settingsJson, ')
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
    startingLife,
    playerCount,
    status,
    createdAt,
    endedAt,
    isP2pHost,
    p2pSessionCode,
    settingsJson,
    isDeleted,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MatchSession &&
          other.id == this.id &&
          other.name == this.name &&
          other.format == this.format &&
          other.startingLife == this.startingLife &&
          other.playerCount == this.playerCount &&
          other.status == this.status &&
          other.createdAt == this.createdAt &&
          other.endedAt == this.endedAt &&
          other.isP2pHost == this.isP2pHost &&
          other.p2pSessionCode == this.p2pSessionCode &&
          other.settingsJson == this.settingsJson &&
          other.isDeleted == this.isDeleted &&
          other.updatedAt == this.updatedAt);
}

class MatchSessionsCompanion extends UpdateCompanion<MatchSession> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> format;
  final Value<int> startingLife;
  final Value<int> playerCount;
  final Value<String> status;
  final Value<DateTime> createdAt;
  final Value<DateTime?> endedAt;
  final Value<bool> isP2pHost;
  final Value<String?> p2pSessionCode;
  final Value<String?> settingsJson;
  final Value<bool> isDeleted;
  final Value<DateTime?> updatedAt;
  final Value<int> rowid;
  const MatchSessionsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.format = const Value.absent(),
    this.startingLife = const Value.absent(),
    this.playerCount = const Value.absent(),
    this.status = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.endedAt = const Value.absent(),
    this.isP2pHost = const Value.absent(),
    this.p2pSessionCode = const Value.absent(),
    this.settingsJson = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MatchSessionsCompanion.insert({
    required String id,
    this.name = const Value.absent(),
    this.format = const Value.absent(),
    this.startingLife = const Value.absent(),
    this.playerCount = const Value.absent(),
    this.status = const Value.absent(),
    required DateTime createdAt,
    this.endedAt = const Value.absent(),
    this.isP2pHost = const Value.absent(),
    this.p2pSessionCode = const Value.absent(),
    this.settingsJson = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       createdAt = Value(createdAt);
  static Insertable<MatchSession> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? format,
    Expression<int>? startingLife,
    Expression<int>? playerCount,
    Expression<String>? status,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? endedAt,
    Expression<bool>? isP2pHost,
    Expression<String>? p2pSessionCode,
    Expression<String>? settingsJson,
    Expression<bool>? isDeleted,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (format != null) 'format': format,
      if (startingLife != null) 'starting_life': startingLife,
      if (playerCount != null) 'player_count': playerCount,
      if (status != null) 'status': status,
      if (createdAt != null) 'created_at': createdAt,
      if (endedAt != null) 'ended_at': endedAt,
      if (isP2pHost != null) 'is_p2p_host': isP2pHost,
      if (p2pSessionCode != null) 'p2p_session_code': p2pSessionCode,
      if (settingsJson != null) 'settings_json': settingsJson,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MatchSessionsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? format,
    Value<int>? startingLife,
    Value<int>? playerCount,
    Value<String>? status,
    Value<DateTime>? createdAt,
    Value<DateTime?>? endedAt,
    Value<bool>? isP2pHost,
    Value<String?>? p2pSessionCode,
    Value<String?>? settingsJson,
    Value<bool>? isDeleted,
    Value<DateTime?>? updatedAt,
    Value<int>? rowid,
  }) {
    return MatchSessionsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      format: format ?? this.format,
      startingLife: startingLife ?? this.startingLife,
      playerCount: playerCount ?? this.playerCount,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      endedAt: endedAt ?? this.endedAt,
      isP2pHost: isP2pHost ?? this.isP2pHost,
      p2pSessionCode: p2pSessionCode ?? this.p2pSessionCode,
      settingsJson: settingsJson ?? this.settingsJson,
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
    if (startingLife.present) {
      map['starting_life'] = Variable<int>(startingLife.value);
    }
    if (playerCount.present) {
      map['player_count'] = Variable<int>(playerCount.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (endedAt.present) {
      map['ended_at'] = Variable<DateTime>(endedAt.value);
    }
    if (isP2pHost.present) {
      map['is_p2p_host'] = Variable<bool>(isP2pHost.value);
    }
    if (p2pSessionCode.present) {
      map['p2p_session_code'] = Variable<String>(p2pSessionCode.value);
    }
    if (settingsJson.present) {
      map['settings_json'] = Variable<String>(settingsJson.value);
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
    return (StringBuffer('MatchSessionsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('format: $format, ')
          ..write('startingLife: $startingLife, ')
          ..write('playerCount: $playerCount, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('isP2pHost: $isP2pHost, ')
          ..write('p2pSessionCode: $p2pSessionCode, ')
          ..write('settingsJson: $settingsJson, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MatchPlayersTable extends MatchPlayers
    with TableInfo<$MatchPlayersTable, MatchPlayer> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MatchPlayersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES match_sessions (id)',
    ),
  );
  static const VerificationMeta _seatOrderMeta = const VerificationMeta(
    'seatOrder',
  );
  @override
  late final GeneratedColumn<int> seatOrder = GeneratedColumn<int>(
    'seat_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _playerNameMeta = const VerificationMeta(
    'playerName',
  );
  @override
  late final GeneratedColumn<String> playerName = GeneratedColumn<String>(
    'player_name',
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
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES decks (id)',
    ),
  );
  static const VerificationMeta _commanderCardIdMeta = const VerificationMeta(
    'commanderCardId',
  );
  @override
  late final GeneratedColumn<String> commanderCardId = GeneratedColumn<String>(
    'commander_card_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES vault_items (id)',
    ),
  );
  static const VerificationMeta _commanderNameMeta = const VerificationMeta(
    'commanderName',
  );
  @override
  late final GeneratedColumn<String> commanderName = GeneratedColumn<String>(
    'commander_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _artCropUrlMeta = const VerificationMeta(
    'artCropUrl',
  );
  @override
  late final GeneratedColumn<String> artCropUrl = GeneratedColumn<String>(
    'art_crop_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _colorThemeMeta = const VerificationMeta(
    'colorTheme',
  );
  @override
  late final GeneratedColumn<String> colorTheme = GeneratedColumn<String>(
    'color_theme',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _currentLifeMeta = const VerificationMeta(
    'currentLife',
  );
  @override
  late final GeneratedColumn<int> currentLife = GeneratedColumn<int>(
    'current_life',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(40),
  );
  static const VerificationMeta _poisonMeta = const VerificationMeta('poison');
  @override
  late final GeneratedColumn<int> poison = GeneratedColumn<int>(
    'poison',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _energyMeta = const VerificationMeta('energy');
  @override
  late final GeneratedColumn<int> energy = GeneratedColumn<int>(
    'energy',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _experienceMeta = const VerificationMeta(
    'experience',
  );
  @override
  late final GeneratedColumn<int> experience = GeneratedColumn<int>(
    'experience',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _commanderTaxMeta = const VerificationMeta(
    'commanderTax',
  );
  @override
  late final GeneratedColumn<int> commanderTax = GeneratedColumn<int>(
    'commander_tax',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _isMonarchMeta = const VerificationMeta(
    'isMonarch',
  );
  @override
  late final GeneratedColumn<bool> isMonarch = GeneratedColumn<bool>(
    'is_monarch',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_monarch" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _hasInitiativeMeta = const VerificationMeta(
    'hasInitiative',
  );
  @override
  late final GeneratedColumn<bool> hasInitiative = GeneratedColumn<bool>(
    'has_initiative',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("has_initiative" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isEliminatedMeta = const VerificationMeta(
    'isEliminated',
  );
  @override
  late final GeneratedColumn<bool> isEliminated = GeneratedColumn<bool>(
    'is_eliminated',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_eliminated" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _eliminatedAtMeta = const VerificationMeta(
    'eliminatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> eliminatedAt = GeneratedColumn<DateTime>(
    'eliminated_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isLocalDeviceMeta = const VerificationMeta(
    'isLocalDevice',
  );
  @override
  late final GeneratedColumn<bool> isLocalDevice = GeneratedColumn<bool>(
    'is_local_device',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_local_device" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _peerDeviceIdMeta = const VerificationMeta(
    'peerDeviceId',
  );
  @override
  late final GeneratedColumn<String> peerDeviceId = GeneratedColumn<String>(
    'peer_device_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _commanderDamageJsonMeta =
      const VerificationMeta('commanderDamageJson');
  @override
  late final GeneratedColumn<String> commanderDamageJson =
      GeneratedColumn<String>(
        'commander_damage_json',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _floatingManaJsonMeta = const VerificationMeta(
    'floatingManaJson',
  );
  @override
  late final GeneratedColumn<String> floatingManaJson = GeneratedColumn<String>(
    'floating_mana_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _stormCountMeta = const VerificationMeta(
    'stormCount',
  );
  @override
  late final GeneratedColumn<int> stormCount = GeneratedColumn<int>(
    'storm_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _countersJsonMeta = const VerificationMeta(
    'countersJson',
  );
  @override
  late final GeneratedColumn<String> countersJson = GeneratedColumn<String>(
    'counters_json',
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
    sessionId,
    seatOrder,
    playerName,
    deckId,
    commanderCardId,
    commanderName,
    artCropUrl,
    colorTheme,
    currentLife,
    poison,
    energy,
    experience,
    commanderTax,
    isMonarch,
    hasInitiative,
    isEliminated,
    eliminatedAt,
    isLocalDevice,
    peerDeviceId,
    commanderDamageJson,
    floatingManaJson,
    stormCount,
    countersJson,
    isDeleted,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'match_players';
  @override
  VerificationContext validateIntegrity(
    Insertable<MatchPlayer> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('seat_order')) {
      context.handle(
        _seatOrderMeta,
        seatOrder.isAcceptableOrUnknown(data['seat_order']!, _seatOrderMeta),
      );
    } else if (isInserting) {
      context.missing(_seatOrderMeta);
    }
    if (data.containsKey('player_name')) {
      context.handle(
        _playerNameMeta,
        playerName.isAcceptableOrUnknown(data['player_name']!, _playerNameMeta),
      );
    } else if (isInserting) {
      context.missing(_playerNameMeta);
    }
    if (data.containsKey('deck_id')) {
      context.handle(
        _deckIdMeta,
        deckId.isAcceptableOrUnknown(data['deck_id']!, _deckIdMeta),
      );
    }
    if (data.containsKey('commander_card_id')) {
      context.handle(
        _commanderCardIdMeta,
        commanderCardId.isAcceptableOrUnknown(
          data['commander_card_id']!,
          _commanderCardIdMeta,
        ),
      );
    }
    if (data.containsKey('commander_name')) {
      context.handle(
        _commanderNameMeta,
        commanderName.isAcceptableOrUnknown(
          data['commander_name']!,
          _commanderNameMeta,
        ),
      );
    }
    if (data.containsKey('art_crop_url')) {
      context.handle(
        _artCropUrlMeta,
        artCropUrl.isAcceptableOrUnknown(
          data['art_crop_url']!,
          _artCropUrlMeta,
        ),
      );
    }
    if (data.containsKey('color_theme')) {
      context.handle(
        _colorThemeMeta,
        colorTheme.isAcceptableOrUnknown(data['color_theme']!, _colorThemeMeta),
      );
    }
    if (data.containsKey('current_life')) {
      context.handle(
        _currentLifeMeta,
        currentLife.isAcceptableOrUnknown(
          data['current_life']!,
          _currentLifeMeta,
        ),
      );
    }
    if (data.containsKey('poison')) {
      context.handle(
        _poisonMeta,
        poison.isAcceptableOrUnknown(data['poison']!, _poisonMeta),
      );
    }
    if (data.containsKey('energy')) {
      context.handle(
        _energyMeta,
        energy.isAcceptableOrUnknown(data['energy']!, _energyMeta),
      );
    }
    if (data.containsKey('experience')) {
      context.handle(
        _experienceMeta,
        experience.isAcceptableOrUnknown(data['experience']!, _experienceMeta),
      );
    }
    if (data.containsKey('commander_tax')) {
      context.handle(
        _commanderTaxMeta,
        commanderTax.isAcceptableOrUnknown(
          data['commander_tax']!,
          _commanderTaxMeta,
        ),
      );
    }
    if (data.containsKey('is_monarch')) {
      context.handle(
        _isMonarchMeta,
        isMonarch.isAcceptableOrUnknown(data['is_monarch']!, _isMonarchMeta),
      );
    }
    if (data.containsKey('has_initiative')) {
      context.handle(
        _hasInitiativeMeta,
        hasInitiative.isAcceptableOrUnknown(
          data['has_initiative']!,
          _hasInitiativeMeta,
        ),
      );
    }
    if (data.containsKey('is_eliminated')) {
      context.handle(
        _isEliminatedMeta,
        isEliminated.isAcceptableOrUnknown(
          data['is_eliminated']!,
          _isEliminatedMeta,
        ),
      );
    }
    if (data.containsKey('eliminated_at')) {
      context.handle(
        _eliminatedAtMeta,
        eliminatedAt.isAcceptableOrUnknown(
          data['eliminated_at']!,
          _eliminatedAtMeta,
        ),
      );
    }
    if (data.containsKey('is_local_device')) {
      context.handle(
        _isLocalDeviceMeta,
        isLocalDevice.isAcceptableOrUnknown(
          data['is_local_device']!,
          _isLocalDeviceMeta,
        ),
      );
    }
    if (data.containsKey('peer_device_id')) {
      context.handle(
        _peerDeviceIdMeta,
        peerDeviceId.isAcceptableOrUnknown(
          data['peer_device_id']!,
          _peerDeviceIdMeta,
        ),
      );
    }
    if (data.containsKey('commander_damage_json')) {
      context.handle(
        _commanderDamageJsonMeta,
        commanderDamageJson.isAcceptableOrUnknown(
          data['commander_damage_json']!,
          _commanderDamageJsonMeta,
        ),
      );
    }
    if (data.containsKey('floating_mana_json')) {
      context.handle(
        _floatingManaJsonMeta,
        floatingManaJson.isAcceptableOrUnknown(
          data['floating_mana_json']!,
          _floatingManaJsonMeta,
        ),
      );
    }
    if (data.containsKey('storm_count')) {
      context.handle(
        _stormCountMeta,
        stormCount.isAcceptableOrUnknown(data['storm_count']!, _stormCountMeta),
      );
    }
    if (data.containsKey('counters_json')) {
      context.handle(
        _countersJsonMeta,
        countersJson.isAcceptableOrUnknown(
          data['counters_json']!,
          _countersJsonMeta,
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
  MatchPlayer map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MatchPlayer(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      seatOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}seat_order'],
      )!,
      playerName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}player_name'],
      )!,
      deckId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}deck_id'],
      ),
      commanderCardId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}commander_card_id'],
      ),
      commanderName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}commander_name'],
      ),
      artCropUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}art_crop_url'],
      ),
      colorTheme: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color_theme'],
      ),
      currentLife: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}current_life'],
      )!,
      poison: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}poison'],
      )!,
      energy: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}energy'],
      )!,
      experience: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}experience'],
      )!,
      commanderTax: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}commander_tax'],
      )!,
      isMonarch: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_monarch'],
      )!,
      hasInitiative: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}has_initiative'],
      )!,
      isEliminated: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_eliminated'],
      )!,
      eliminatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}eliminated_at'],
      ),
      isLocalDevice: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_local_device'],
      )!,
      peerDeviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}peer_device_id'],
      ),
      commanderDamageJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}commander_damage_json'],
      ),
      floatingManaJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}floating_mana_json'],
      ),
      stormCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}storm_count'],
      )!,
      countersJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}counters_json'],
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
  $MatchPlayersTable createAlias(String alias) {
    return $MatchPlayersTable(attachedDatabase, alias);
  }
}

class MatchPlayer extends DataClass implements Insertable<MatchPlayer> {
  /// Unique player seat identifier (UUID v4)
  final String id;

  /// Foreign key referencing parent match session
  final String sessionId;

  /// 0-indexed seating order in pod grid (0..playerCount - 1)
  final int seatOrder;

  /// Display name of the player
  final String playerName;

  /// Optional foreign key to a local constructed deck from Vault
  final String? deckId;

  /// Optional foreign key to commander card in VaultItems
  final String? commanderCardId;

  /// Commander card name (e.g. "Atraxa, Praetors' Voice")
  final String? commanderName;

  /// High-resolution art crop URL for dynamic quadrant background
  final String? artCropUrl;

  /// Primary color theme / MTG color identity string (e.g. "WUBG")
  final String? colorTheme;

  /// Current life total
  final int currentLife;

  /// Poison counters (10 = lethal defeat in standard/commander rules)
  final int poison;

  /// Energy counters ({E})
  final int energy;

  /// Experience counters (XP)
  final int experience;

  /// Additional commander tax in generic mana (+2 per previous cast)
  final int commanderTax;

  /// True if this player is currently the Monarch
  final bool isMonarch;

  /// True if this player currently holds the Initiative
  final bool hasInitiative;

  /// True if this player has been eliminated from the match
  final bool isEliminated;

  /// Timestamp when player was eliminated (or null if still active)
  final DateTime? eliminatedAt;

  /// True if this player is running on the local device; false if connected via P2P
  final bool isLocalDevice;

  /// Network peer device identifier if connected via P2P
  final String? peerDeviceId;

  /// JSON map of commander damage taken from opponents: `{"opponentPlayerId": 14}`
  final String? commanderDamageJson;

  /// JSON map of floating mana per color: `{"W":0,"U":1,"B":0,"R":2,"G":0,"C":0}`
  final String? floatingManaJson;

  /// Storm count for current phase/turn
  final int stormCount;

  /// Arbitrary JSON map for secondary or custom counters
  final String? countersJson;

  /// Soft deletion flag for offline-first data retention
  final bool isDeleted;

  /// Timestamp of last modification for sync conflict resolution
  final DateTime? updatedAt;
  const MatchPlayer({
    required this.id,
    required this.sessionId,
    required this.seatOrder,
    required this.playerName,
    this.deckId,
    this.commanderCardId,
    this.commanderName,
    this.artCropUrl,
    this.colorTheme,
    required this.currentLife,
    required this.poison,
    required this.energy,
    required this.experience,
    required this.commanderTax,
    required this.isMonarch,
    required this.hasInitiative,
    required this.isEliminated,
    this.eliminatedAt,
    required this.isLocalDevice,
    this.peerDeviceId,
    this.commanderDamageJson,
    this.floatingManaJson,
    required this.stormCount,
    this.countersJson,
    required this.isDeleted,
    this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['session_id'] = Variable<String>(sessionId);
    map['seat_order'] = Variable<int>(seatOrder);
    map['player_name'] = Variable<String>(playerName);
    if (!nullToAbsent || deckId != null) {
      map['deck_id'] = Variable<String>(deckId);
    }
    if (!nullToAbsent || commanderCardId != null) {
      map['commander_card_id'] = Variable<String>(commanderCardId);
    }
    if (!nullToAbsent || commanderName != null) {
      map['commander_name'] = Variable<String>(commanderName);
    }
    if (!nullToAbsent || artCropUrl != null) {
      map['art_crop_url'] = Variable<String>(artCropUrl);
    }
    if (!nullToAbsent || colorTheme != null) {
      map['color_theme'] = Variable<String>(colorTheme);
    }
    map['current_life'] = Variable<int>(currentLife);
    map['poison'] = Variable<int>(poison);
    map['energy'] = Variable<int>(energy);
    map['experience'] = Variable<int>(experience);
    map['commander_tax'] = Variable<int>(commanderTax);
    map['is_monarch'] = Variable<bool>(isMonarch);
    map['has_initiative'] = Variable<bool>(hasInitiative);
    map['is_eliminated'] = Variable<bool>(isEliminated);
    if (!nullToAbsent || eliminatedAt != null) {
      map['eliminated_at'] = Variable<DateTime>(eliminatedAt);
    }
    map['is_local_device'] = Variable<bool>(isLocalDevice);
    if (!nullToAbsent || peerDeviceId != null) {
      map['peer_device_id'] = Variable<String>(peerDeviceId);
    }
    if (!nullToAbsent || commanderDamageJson != null) {
      map['commander_damage_json'] = Variable<String>(commanderDamageJson);
    }
    if (!nullToAbsent || floatingManaJson != null) {
      map['floating_mana_json'] = Variable<String>(floatingManaJson);
    }
    map['storm_count'] = Variable<int>(stormCount);
    if (!nullToAbsent || countersJson != null) {
      map['counters_json'] = Variable<String>(countersJson);
    }
    map['is_deleted'] = Variable<bool>(isDeleted);
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    return map;
  }

  MatchPlayersCompanion toCompanion(bool nullToAbsent) {
    return MatchPlayersCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      seatOrder: Value(seatOrder),
      playerName: Value(playerName),
      deckId: deckId == null && nullToAbsent
          ? const Value.absent()
          : Value(deckId),
      commanderCardId: commanderCardId == null && nullToAbsent
          ? const Value.absent()
          : Value(commanderCardId),
      commanderName: commanderName == null && nullToAbsent
          ? const Value.absent()
          : Value(commanderName),
      artCropUrl: artCropUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(artCropUrl),
      colorTheme: colorTheme == null && nullToAbsent
          ? const Value.absent()
          : Value(colorTheme),
      currentLife: Value(currentLife),
      poison: Value(poison),
      energy: Value(energy),
      experience: Value(experience),
      commanderTax: Value(commanderTax),
      isMonarch: Value(isMonarch),
      hasInitiative: Value(hasInitiative),
      isEliminated: Value(isEliminated),
      eliminatedAt: eliminatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(eliminatedAt),
      isLocalDevice: Value(isLocalDevice),
      peerDeviceId: peerDeviceId == null && nullToAbsent
          ? const Value.absent()
          : Value(peerDeviceId),
      commanderDamageJson: commanderDamageJson == null && nullToAbsent
          ? const Value.absent()
          : Value(commanderDamageJson),
      floatingManaJson: floatingManaJson == null && nullToAbsent
          ? const Value.absent()
          : Value(floatingManaJson),
      stormCount: Value(stormCount),
      countersJson: countersJson == null && nullToAbsent
          ? const Value.absent()
          : Value(countersJson),
      isDeleted: Value(isDeleted),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
    );
  }

  factory MatchPlayer.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MatchPlayer(
      id: serializer.fromJson<String>(json['id']),
      sessionId: serializer.fromJson<String>(json['sessionId']),
      seatOrder: serializer.fromJson<int>(json['seatOrder']),
      playerName: serializer.fromJson<String>(json['playerName']),
      deckId: serializer.fromJson<String?>(json['deckId']),
      commanderCardId: serializer.fromJson<String?>(json['commanderCardId']),
      commanderName: serializer.fromJson<String?>(json['commanderName']),
      artCropUrl: serializer.fromJson<String?>(json['artCropUrl']),
      colorTheme: serializer.fromJson<String?>(json['colorTheme']),
      currentLife: serializer.fromJson<int>(json['currentLife']),
      poison: serializer.fromJson<int>(json['poison']),
      energy: serializer.fromJson<int>(json['energy']),
      experience: serializer.fromJson<int>(json['experience']),
      commanderTax: serializer.fromJson<int>(json['commanderTax']),
      isMonarch: serializer.fromJson<bool>(json['isMonarch']),
      hasInitiative: serializer.fromJson<bool>(json['hasInitiative']),
      isEliminated: serializer.fromJson<bool>(json['isEliminated']),
      eliminatedAt: serializer.fromJson<DateTime?>(json['eliminatedAt']),
      isLocalDevice: serializer.fromJson<bool>(json['isLocalDevice']),
      peerDeviceId: serializer.fromJson<String?>(json['peerDeviceId']),
      commanderDamageJson: serializer.fromJson<String?>(
        json['commanderDamageJson'],
      ),
      floatingManaJson: serializer.fromJson<String?>(json['floatingManaJson']),
      stormCount: serializer.fromJson<int>(json['stormCount']),
      countersJson: serializer.fromJson<String?>(json['countersJson']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sessionId': serializer.toJson<String>(sessionId),
      'seatOrder': serializer.toJson<int>(seatOrder),
      'playerName': serializer.toJson<String>(playerName),
      'deckId': serializer.toJson<String?>(deckId),
      'commanderCardId': serializer.toJson<String?>(commanderCardId),
      'commanderName': serializer.toJson<String?>(commanderName),
      'artCropUrl': serializer.toJson<String?>(artCropUrl),
      'colorTheme': serializer.toJson<String?>(colorTheme),
      'currentLife': serializer.toJson<int>(currentLife),
      'poison': serializer.toJson<int>(poison),
      'energy': serializer.toJson<int>(energy),
      'experience': serializer.toJson<int>(experience),
      'commanderTax': serializer.toJson<int>(commanderTax),
      'isMonarch': serializer.toJson<bool>(isMonarch),
      'hasInitiative': serializer.toJson<bool>(hasInitiative),
      'isEliminated': serializer.toJson<bool>(isEliminated),
      'eliminatedAt': serializer.toJson<DateTime?>(eliminatedAt),
      'isLocalDevice': serializer.toJson<bool>(isLocalDevice),
      'peerDeviceId': serializer.toJson<String?>(peerDeviceId),
      'commanderDamageJson': serializer.toJson<String?>(commanderDamageJson),
      'floatingManaJson': serializer.toJson<String?>(floatingManaJson),
      'stormCount': serializer.toJson<int>(stormCount),
      'countersJson': serializer.toJson<String?>(countersJson),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
    };
  }

  MatchPlayer copyWith({
    String? id,
    String? sessionId,
    int? seatOrder,
    String? playerName,
    Value<String?> deckId = const Value.absent(),
    Value<String?> commanderCardId = const Value.absent(),
    Value<String?> commanderName = const Value.absent(),
    Value<String?> artCropUrl = const Value.absent(),
    Value<String?> colorTheme = const Value.absent(),
    int? currentLife,
    int? poison,
    int? energy,
    int? experience,
    int? commanderTax,
    bool? isMonarch,
    bool? hasInitiative,
    bool? isEliminated,
    Value<DateTime?> eliminatedAt = const Value.absent(),
    bool? isLocalDevice,
    Value<String?> peerDeviceId = const Value.absent(),
    Value<String?> commanderDamageJson = const Value.absent(),
    Value<String?> floatingManaJson = const Value.absent(),
    int? stormCount,
    Value<String?> countersJson = const Value.absent(),
    bool? isDeleted,
    Value<DateTime?> updatedAt = const Value.absent(),
  }) => MatchPlayer(
    id: id ?? this.id,
    sessionId: sessionId ?? this.sessionId,
    seatOrder: seatOrder ?? this.seatOrder,
    playerName: playerName ?? this.playerName,
    deckId: deckId.present ? deckId.value : this.deckId,
    commanderCardId: commanderCardId.present
        ? commanderCardId.value
        : this.commanderCardId,
    commanderName: commanderName.present
        ? commanderName.value
        : this.commanderName,
    artCropUrl: artCropUrl.present ? artCropUrl.value : this.artCropUrl,
    colorTheme: colorTheme.present ? colorTheme.value : this.colorTheme,
    currentLife: currentLife ?? this.currentLife,
    poison: poison ?? this.poison,
    energy: energy ?? this.energy,
    experience: experience ?? this.experience,
    commanderTax: commanderTax ?? this.commanderTax,
    isMonarch: isMonarch ?? this.isMonarch,
    hasInitiative: hasInitiative ?? this.hasInitiative,
    isEliminated: isEliminated ?? this.isEliminated,
    eliminatedAt: eliminatedAt.present ? eliminatedAt.value : this.eliminatedAt,
    isLocalDevice: isLocalDevice ?? this.isLocalDevice,
    peerDeviceId: peerDeviceId.present ? peerDeviceId.value : this.peerDeviceId,
    commanderDamageJson: commanderDamageJson.present
        ? commanderDamageJson.value
        : this.commanderDamageJson,
    floatingManaJson: floatingManaJson.present
        ? floatingManaJson.value
        : this.floatingManaJson,
    stormCount: stormCount ?? this.stormCount,
    countersJson: countersJson.present ? countersJson.value : this.countersJson,
    isDeleted: isDeleted ?? this.isDeleted,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
  );
  MatchPlayer copyWithCompanion(MatchPlayersCompanion data) {
    return MatchPlayer(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      seatOrder: data.seatOrder.present ? data.seatOrder.value : this.seatOrder,
      playerName: data.playerName.present
          ? data.playerName.value
          : this.playerName,
      deckId: data.deckId.present ? data.deckId.value : this.deckId,
      commanderCardId: data.commanderCardId.present
          ? data.commanderCardId.value
          : this.commanderCardId,
      commanderName: data.commanderName.present
          ? data.commanderName.value
          : this.commanderName,
      artCropUrl: data.artCropUrl.present
          ? data.artCropUrl.value
          : this.artCropUrl,
      colorTheme: data.colorTheme.present
          ? data.colorTheme.value
          : this.colorTheme,
      currentLife: data.currentLife.present
          ? data.currentLife.value
          : this.currentLife,
      poison: data.poison.present ? data.poison.value : this.poison,
      energy: data.energy.present ? data.energy.value : this.energy,
      experience: data.experience.present
          ? data.experience.value
          : this.experience,
      commanderTax: data.commanderTax.present
          ? data.commanderTax.value
          : this.commanderTax,
      isMonarch: data.isMonarch.present ? data.isMonarch.value : this.isMonarch,
      hasInitiative: data.hasInitiative.present
          ? data.hasInitiative.value
          : this.hasInitiative,
      isEliminated: data.isEliminated.present
          ? data.isEliminated.value
          : this.isEliminated,
      eliminatedAt: data.eliminatedAt.present
          ? data.eliminatedAt.value
          : this.eliminatedAt,
      isLocalDevice: data.isLocalDevice.present
          ? data.isLocalDevice.value
          : this.isLocalDevice,
      peerDeviceId: data.peerDeviceId.present
          ? data.peerDeviceId.value
          : this.peerDeviceId,
      commanderDamageJson: data.commanderDamageJson.present
          ? data.commanderDamageJson.value
          : this.commanderDamageJson,
      floatingManaJson: data.floatingManaJson.present
          ? data.floatingManaJson.value
          : this.floatingManaJson,
      stormCount: data.stormCount.present
          ? data.stormCount.value
          : this.stormCount,
      countersJson: data.countersJson.present
          ? data.countersJson.value
          : this.countersJson,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MatchPlayer(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('seatOrder: $seatOrder, ')
          ..write('playerName: $playerName, ')
          ..write('deckId: $deckId, ')
          ..write('commanderCardId: $commanderCardId, ')
          ..write('commanderName: $commanderName, ')
          ..write('artCropUrl: $artCropUrl, ')
          ..write('colorTheme: $colorTheme, ')
          ..write('currentLife: $currentLife, ')
          ..write('poison: $poison, ')
          ..write('energy: $energy, ')
          ..write('experience: $experience, ')
          ..write('commanderTax: $commanderTax, ')
          ..write('isMonarch: $isMonarch, ')
          ..write('hasInitiative: $hasInitiative, ')
          ..write('isEliminated: $isEliminated, ')
          ..write('eliminatedAt: $eliminatedAt, ')
          ..write('isLocalDevice: $isLocalDevice, ')
          ..write('peerDeviceId: $peerDeviceId, ')
          ..write('commanderDamageJson: $commanderDamageJson, ')
          ..write('floatingManaJson: $floatingManaJson, ')
          ..write('stormCount: $stormCount, ')
          ..write('countersJson: $countersJson, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    sessionId,
    seatOrder,
    playerName,
    deckId,
    commanderCardId,
    commanderName,
    artCropUrl,
    colorTheme,
    currentLife,
    poison,
    energy,
    experience,
    commanderTax,
    isMonarch,
    hasInitiative,
    isEliminated,
    eliminatedAt,
    isLocalDevice,
    peerDeviceId,
    commanderDamageJson,
    floatingManaJson,
    stormCount,
    countersJson,
    isDeleted,
    updatedAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MatchPlayer &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.seatOrder == this.seatOrder &&
          other.playerName == this.playerName &&
          other.deckId == this.deckId &&
          other.commanderCardId == this.commanderCardId &&
          other.commanderName == this.commanderName &&
          other.artCropUrl == this.artCropUrl &&
          other.colorTheme == this.colorTheme &&
          other.currentLife == this.currentLife &&
          other.poison == this.poison &&
          other.energy == this.energy &&
          other.experience == this.experience &&
          other.commanderTax == this.commanderTax &&
          other.isMonarch == this.isMonarch &&
          other.hasInitiative == this.hasInitiative &&
          other.isEliminated == this.isEliminated &&
          other.eliminatedAt == this.eliminatedAt &&
          other.isLocalDevice == this.isLocalDevice &&
          other.peerDeviceId == this.peerDeviceId &&
          other.commanderDamageJson == this.commanderDamageJson &&
          other.floatingManaJson == this.floatingManaJson &&
          other.stormCount == this.stormCount &&
          other.countersJson == this.countersJson &&
          other.isDeleted == this.isDeleted &&
          other.updatedAt == this.updatedAt);
}

class MatchPlayersCompanion extends UpdateCompanion<MatchPlayer> {
  final Value<String> id;
  final Value<String> sessionId;
  final Value<int> seatOrder;
  final Value<String> playerName;
  final Value<String?> deckId;
  final Value<String?> commanderCardId;
  final Value<String?> commanderName;
  final Value<String?> artCropUrl;
  final Value<String?> colorTheme;
  final Value<int> currentLife;
  final Value<int> poison;
  final Value<int> energy;
  final Value<int> experience;
  final Value<int> commanderTax;
  final Value<bool> isMonarch;
  final Value<bool> hasInitiative;
  final Value<bool> isEliminated;
  final Value<DateTime?> eliminatedAt;
  final Value<bool> isLocalDevice;
  final Value<String?> peerDeviceId;
  final Value<String?> commanderDamageJson;
  final Value<String?> floatingManaJson;
  final Value<int> stormCount;
  final Value<String?> countersJson;
  final Value<bool> isDeleted;
  final Value<DateTime?> updatedAt;
  final Value<int> rowid;
  const MatchPlayersCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.seatOrder = const Value.absent(),
    this.playerName = const Value.absent(),
    this.deckId = const Value.absent(),
    this.commanderCardId = const Value.absent(),
    this.commanderName = const Value.absent(),
    this.artCropUrl = const Value.absent(),
    this.colorTheme = const Value.absent(),
    this.currentLife = const Value.absent(),
    this.poison = const Value.absent(),
    this.energy = const Value.absent(),
    this.experience = const Value.absent(),
    this.commanderTax = const Value.absent(),
    this.isMonarch = const Value.absent(),
    this.hasInitiative = const Value.absent(),
    this.isEliminated = const Value.absent(),
    this.eliminatedAt = const Value.absent(),
    this.isLocalDevice = const Value.absent(),
    this.peerDeviceId = const Value.absent(),
    this.commanderDamageJson = const Value.absent(),
    this.floatingManaJson = const Value.absent(),
    this.stormCount = const Value.absent(),
    this.countersJson = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MatchPlayersCompanion.insert({
    required String id,
    required String sessionId,
    required int seatOrder,
    required String playerName,
    this.deckId = const Value.absent(),
    this.commanderCardId = const Value.absent(),
    this.commanderName = const Value.absent(),
    this.artCropUrl = const Value.absent(),
    this.colorTheme = const Value.absent(),
    this.currentLife = const Value.absent(),
    this.poison = const Value.absent(),
    this.energy = const Value.absent(),
    this.experience = const Value.absent(),
    this.commanderTax = const Value.absent(),
    this.isMonarch = const Value.absent(),
    this.hasInitiative = const Value.absent(),
    this.isEliminated = const Value.absent(),
    this.eliminatedAt = const Value.absent(),
    this.isLocalDevice = const Value.absent(),
    this.peerDeviceId = const Value.absent(),
    this.commanderDamageJson = const Value.absent(),
    this.floatingManaJson = const Value.absent(),
    this.stormCount = const Value.absent(),
    this.countersJson = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sessionId = Value(sessionId),
       seatOrder = Value(seatOrder),
       playerName = Value(playerName);
  static Insertable<MatchPlayer> custom({
    Expression<String>? id,
    Expression<String>? sessionId,
    Expression<int>? seatOrder,
    Expression<String>? playerName,
    Expression<String>? deckId,
    Expression<String>? commanderCardId,
    Expression<String>? commanderName,
    Expression<String>? artCropUrl,
    Expression<String>? colorTheme,
    Expression<int>? currentLife,
    Expression<int>? poison,
    Expression<int>? energy,
    Expression<int>? experience,
    Expression<int>? commanderTax,
    Expression<bool>? isMonarch,
    Expression<bool>? hasInitiative,
    Expression<bool>? isEliminated,
    Expression<DateTime>? eliminatedAt,
    Expression<bool>? isLocalDevice,
    Expression<String>? peerDeviceId,
    Expression<String>? commanderDamageJson,
    Expression<String>? floatingManaJson,
    Expression<int>? stormCount,
    Expression<String>? countersJson,
    Expression<bool>? isDeleted,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (seatOrder != null) 'seat_order': seatOrder,
      if (playerName != null) 'player_name': playerName,
      if (deckId != null) 'deck_id': deckId,
      if (commanderCardId != null) 'commander_card_id': commanderCardId,
      if (commanderName != null) 'commander_name': commanderName,
      if (artCropUrl != null) 'art_crop_url': artCropUrl,
      if (colorTheme != null) 'color_theme': colorTheme,
      if (currentLife != null) 'current_life': currentLife,
      if (poison != null) 'poison': poison,
      if (energy != null) 'energy': energy,
      if (experience != null) 'experience': experience,
      if (commanderTax != null) 'commander_tax': commanderTax,
      if (isMonarch != null) 'is_monarch': isMonarch,
      if (hasInitiative != null) 'has_initiative': hasInitiative,
      if (isEliminated != null) 'is_eliminated': isEliminated,
      if (eliminatedAt != null) 'eliminated_at': eliminatedAt,
      if (isLocalDevice != null) 'is_local_device': isLocalDevice,
      if (peerDeviceId != null) 'peer_device_id': peerDeviceId,
      if (commanderDamageJson != null)
        'commander_damage_json': commanderDamageJson,
      if (floatingManaJson != null) 'floating_mana_json': floatingManaJson,
      if (stormCount != null) 'storm_count': stormCount,
      if (countersJson != null) 'counters_json': countersJson,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MatchPlayersCompanion copyWith({
    Value<String>? id,
    Value<String>? sessionId,
    Value<int>? seatOrder,
    Value<String>? playerName,
    Value<String?>? deckId,
    Value<String?>? commanderCardId,
    Value<String?>? commanderName,
    Value<String?>? artCropUrl,
    Value<String?>? colorTheme,
    Value<int>? currentLife,
    Value<int>? poison,
    Value<int>? energy,
    Value<int>? experience,
    Value<int>? commanderTax,
    Value<bool>? isMonarch,
    Value<bool>? hasInitiative,
    Value<bool>? isEliminated,
    Value<DateTime?>? eliminatedAt,
    Value<bool>? isLocalDevice,
    Value<String?>? peerDeviceId,
    Value<String?>? commanderDamageJson,
    Value<String?>? floatingManaJson,
    Value<int>? stormCount,
    Value<String?>? countersJson,
    Value<bool>? isDeleted,
    Value<DateTime?>? updatedAt,
    Value<int>? rowid,
  }) {
    return MatchPlayersCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      seatOrder: seatOrder ?? this.seatOrder,
      playerName: playerName ?? this.playerName,
      deckId: deckId ?? this.deckId,
      commanderCardId: commanderCardId ?? this.commanderCardId,
      commanderName: commanderName ?? this.commanderName,
      artCropUrl: artCropUrl ?? this.artCropUrl,
      colorTheme: colorTheme ?? this.colorTheme,
      currentLife: currentLife ?? this.currentLife,
      poison: poison ?? this.poison,
      energy: energy ?? this.energy,
      experience: experience ?? this.experience,
      commanderTax: commanderTax ?? this.commanderTax,
      isMonarch: isMonarch ?? this.isMonarch,
      hasInitiative: hasInitiative ?? this.hasInitiative,
      isEliminated: isEliminated ?? this.isEliminated,
      eliminatedAt: eliminatedAt ?? this.eliminatedAt,
      isLocalDevice: isLocalDevice ?? this.isLocalDevice,
      peerDeviceId: peerDeviceId ?? this.peerDeviceId,
      commanderDamageJson: commanderDamageJson ?? this.commanderDamageJson,
      floatingManaJson: floatingManaJson ?? this.floatingManaJson,
      stormCount: stormCount ?? this.stormCount,
      countersJson: countersJson ?? this.countersJson,
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
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (seatOrder.present) {
      map['seat_order'] = Variable<int>(seatOrder.value);
    }
    if (playerName.present) {
      map['player_name'] = Variable<String>(playerName.value);
    }
    if (deckId.present) {
      map['deck_id'] = Variable<String>(deckId.value);
    }
    if (commanderCardId.present) {
      map['commander_card_id'] = Variable<String>(commanderCardId.value);
    }
    if (commanderName.present) {
      map['commander_name'] = Variable<String>(commanderName.value);
    }
    if (artCropUrl.present) {
      map['art_crop_url'] = Variable<String>(artCropUrl.value);
    }
    if (colorTheme.present) {
      map['color_theme'] = Variable<String>(colorTheme.value);
    }
    if (currentLife.present) {
      map['current_life'] = Variable<int>(currentLife.value);
    }
    if (poison.present) {
      map['poison'] = Variable<int>(poison.value);
    }
    if (energy.present) {
      map['energy'] = Variable<int>(energy.value);
    }
    if (experience.present) {
      map['experience'] = Variable<int>(experience.value);
    }
    if (commanderTax.present) {
      map['commander_tax'] = Variable<int>(commanderTax.value);
    }
    if (isMonarch.present) {
      map['is_monarch'] = Variable<bool>(isMonarch.value);
    }
    if (hasInitiative.present) {
      map['has_initiative'] = Variable<bool>(hasInitiative.value);
    }
    if (isEliminated.present) {
      map['is_eliminated'] = Variable<bool>(isEliminated.value);
    }
    if (eliminatedAt.present) {
      map['eliminated_at'] = Variable<DateTime>(eliminatedAt.value);
    }
    if (isLocalDevice.present) {
      map['is_local_device'] = Variable<bool>(isLocalDevice.value);
    }
    if (peerDeviceId.present) {
      map['peer_device_id'] = Variable<String>(peerDeviceId.value);
    }
    if (commanderDamageJson.present) {
      map['commander_damage_json'] = Variable<String>(
        commanderDamageJson.value,
      );
    }
    if (floatingManaJson.present) {
      map['floating_mana_json'] = Variable<String>(floatingManaJson.value);
    }
    if (stormCount.present) {
      map['storm_count'] = Variable<int>(stormCount.value);
    }
    if (countersJson.present) {
      map['counters_json'] = Variable<String>(countersJson.value);
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
    return (StringBuffer('MatchPlayersCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('seatOrder: $seatOrder, ')
          ..write('playerName: $playerName, ')
          ..write('deckId: $deckId, ')
          ..write('commanderCardId: $commanderCardId, ')
          ..write('commanderName: $commanderName, ')
          ..write('artCropUrl: $artCropUrl, ')
          ..write('colorTheme: $colorTheme, ')
          ..write('currentLife: $currentLife, ')
          ..write('poison: $poison, ')
          ..write('energy: $energy, ')
          ..write('experience: $experience, ')
          ..write('commanderTax: $commanderTax, ')
          ..write('isMonarch: $isMonarch, ')
          ..write('hasInitiative: $hasInitiative, ')
          ..write('isEliminated: $isEliminated, ')
          ..write('eliminatedAt: $eliminatedAt, ')
          ..write('isLocalDevice: $isLocalDevice, ')
          ..write('peerDeviceId: $peerDeviceId, ')
          ..write('commanderDamageJson: $commanderDamageJson, ')
          ..write('floatingManaJson: $floatingManaJson, ')
          ..write('stormCount: $stormCount, ')
          ..write('countersJson: $countersJson, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MatchEventsTable extends MatchEvents
    with TableInfo<$MatchEventsTable, MatchEvent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MatchEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES match_sessions (id)',
    ),
  );
  static const VerificationMeta _playerIdMeta = const VerificationMeta(
    'playerId',
  );
  @override
  late final GeneratedColumn<String> playerId = GeneratedColumn<String>(
    'player_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourcePlayerIdMeta = const VerificationMeta(
    'sourcePlayerId',
  );
  @override
  late final GeneratedColumn<String> sourcePlayerId = GeneratedColumn<String>(
    'source_player_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _eventTypeMeta = const VerificationMeta(
    'eventType',
  );
  @override
  late final GeneratedColumn<String> eventType = GeneratedColumn<String>(
    'event_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deltaMeta = const VerificationMeta('delta');
  @override
  late final GeneratedColumn<int> delta = GeneratedColumn<int>(
    'delta',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<int> value = GeneratedColumn<int>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _sequenceNumberMeta = const VerificationMeta(
    'sequenceNumber',
  );
  @override
  late final GeneratedColumn<int> sequenceNumber = GeneratedColumn<int>(
    'sequence_number',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
  static const VerificationMeta _isUndoneMeta = const VerificationMeta(
    'isUndone',
  );
  @override
  late final GeneratedColumn<bool> isUndone = GeneratedColumn<bool>(
    'is_undone',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_undone" IN (0, 1))',
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
    sessionId,
    playerId,
    sourcePlayerId,
    eventType,
    delta,
    value,
    sequenceNumber,
    payloadJson,
    timestamp,
    isUndone,
    isDeleted,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'match_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<MatchEvent> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('player_id')) {
      context.handle(
        _playerIdMeta,
        playerId.isAcceptableOrUnknown(data['player_id']!, _playerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_playerIdMeta);
    }
    if (data.containsKey('source_player_id')) {
      context.handle(
        _sourcePlayerIdMeta,
        sourcePlayerId.isAcceptableOrUnknown(
          data['source_player_id']!,
          _sourcePlayerIdMeta,
        ),
      );
    }
    if (data.containsKey('event_type')) {
      context.handle(
        _eventTypeMeta,
        eventType.isAcceptableOrUnknown(data['event_type']!, _eventTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_eventTypeMeta);
    }
    if (data.containsKey('delta')) {
      context.handle(
        _deltaMeta,
        delta.isAcceptableOrUnknown(data['delta']!, _deltaMeta),
      );
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    }
    if (data.containsKey('sequence_number')) {
      context.handle(
        _sequenceNumberMeta,
        sequenceNumber.isAcceptableOrUnknown(
          data['sequence_number']!,
          _sequenceNumberMeta,
        ),
      );
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    }
    if (data.containsKey('timestamp')) {
      context.handle(
        _timestampMeta,
        timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta),
      );
    } else if (isInserting) {
      context.missing(_timestampMeta);
    }
    if (data.containsKey('is_undone')) {
      context.handle(
        _isUndoneMeta,
        isUndone.isAcceptableOrUnknown(data['is_undone']!, _isUndoneMeta),
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
  MatchEvent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MatchEvent(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      playerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}player_id'],
      )!,
      sourcePlayerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_player_id'],
      ),
      eventType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}event_type'],
      )!,
      delta: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}delta'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}value'],
      )!,
      sequenceNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sequence_number'],
      )!,
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      ),
      timestamp: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}timestamp'],
      )!,
      isUndone: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_undone'],
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
  $MatchEventsTable createAlias(String alias) {
    return $MatchEventsTable(attachedDatabase, alias);
  }
}

class MatchEvent extends DataClass implements Insertable<MatchEvent> {
  /// Unique event identifier (UUID v4)
  final String id;

  /// Foreign key referencing parent match session
  final String sessionId;

  /// Target player receiving the adjustment (or session/table identifier for global events)
  final String playerId;

  /// Source player inflicting damage or causing the effect (e.g. opposing commander damage dealer)
  final String? sourcePlayerId;

  /// Event type identifier:
  /// - 'session_created'
  /// - 'life_delta'
  /// - 'commander_damage'
  /// - 'poison'
  /// - 'energy'
  /// - 'experience'
  /// - 'commander_tax'
  /// - 'monarch'
  /// - 'initiative'
  /// - 'day_night'
  /// - 'mana_change'
  /// - 'mana_clear'
  /// - 'storm'
  /// - 'dice_roll'
  /// - 'coin_flip'
  /// - 'reset'
  /// - 'undo'
  final String eventType;

  /// Integer delta for this event (e.g. +3, -5, +1 poison)
  final int delta;

  /// Resulting or absolute value after applying the delta
  final int value;

  /// Monotonically increasing sequence number assigned by host authority for P2P ordering
  final int sequenceNumber;

  /// Extended payload for structured details (e.g. dice roll sides/results, mana color, coin result)
  final String? payloadJson;

  /// Timestamp when event occurred
  final DateTime timestamp;

  /// True if this event was undone by the player
  final bool isUndone;

  /// Soft deletion flag for offline-first data retention
  final bool isDeleted;

  /// Timestamp of last modification for sync conflict resolution
  final DateTime? updatedAt;
  const MatchEvent({
    required this.id,
    required this.sessionId,
    required this.playerId,
    this.sourcePlayerId,
    required this.eventType,
    required this.delta,
    required this.value,
    required this.sequenceNumber,
    this.payloadJson,
    required this.timestamp,
    required this.isUndone,
    required this.isDeleted,
    this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['session_id'] = Variable<String>(sessionId);
    map['player_id'] = Variable<String>(playerId);
    if (!nullToAbsent || sourcePlayerId != null) {
      map['source_player_id'] = Variable<String>(sourcePlayerId);
    }
    map['event_type'] = Variable<String>(eventType);
    map['delta'] = Variable<int>(delta);
    map['value'] = Variable<int>(value);
    map['sequence_number'] = Variable<int>(sequenceNumber);
    if (!nullToAbsent || payloadJson != null) {
      map['payload_json'] = Variable<String>(payloadJson);
    }
    map['timestamp'] = Variable<DateTime>(timestamp);
    map['is_undone'] = Variable<bool>(isUndone);
    map['is_deleted'] = Variable<bool>(isDeleted);
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    return map;
  }

  MatchEventsCompanion toCompanion(bool nullToAbsent) {
    return MatchEventsCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      playerId: Value(playerId),
      sourcePlayerId: sourcePlayerId == null && nullToAbsent
          ? const Value.absent()
          : Value(sourcePlayerId),
      eventType: Value(eventType),
      delta: Value(delta),
      value: Value(value),
      sequenceNumber: Value(sequenceNumber),
      payloadJson: payloadJson == null && nullToAbsent
          ? const Value.absent()
          : Value(payloadJson),
      timestamp: Value(timestamp),
      isUndone: Value(isUndone),
      isDeleted: Value(isDeleted),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
    );
  }

  factory MatchEvent.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MatchEvent(
      id: serializer.fromJson<String>(json['id']),
      sessionId: serializer.fromJson<String>(json['sessionId']),
      playerId: serializer.fromJson<String>(json['playerId']),
      sourcePlayerId: serializer.fromJson<String?>(json['sourcePlayerId']),
      eventType: serializer.fromJson<String>(json['eventType']),
      delta: serializer.fromJson<int>(json['delta']),
      value: serializer.fromJson<int>(json['value']),
      sequenceNumber: serializer.fromJson<int>(json['sequenceNumber']),
      payloadJson: serializer.fromJson<String?>(json['payloadJson']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
      isUndone: serializer.fromJson<bool>(json['isUndone']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sessionId': serializer.toJson<String>(sessionId),
      'playerId': serializer.toJson<String>(playerId),
      'sourcePlayerId': serializer.toJson<String?>(sourcePlayerId),
      'eventType': serializer.toJson<String>(eventType),
      'delta': serializer.toJson<int>(delta),
      'value': serializer.toJson<int>(value),
      'sequenceNumber': serializer.toJson<int>(sequenceNumber),
      'payloadJson': serializer.toJson<String?>(payloadJson),
      'timestamp': serializer.toJson<DateTime>(timestamp),
      'isUndone': serializer.toJson<bool>(isUndone),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
    };
  }

  MatchEvent copyWith({
    String? id,
    String? sessionId,
    String? playerId,
    Value<String?> sourcePlayerId = const Value.absent(),
    String? eventType,
    int? delta,
    int? value,
    int? sequenceNumber,
    Value<String?> payloadJson = const Value.absent(),
    DateTime? timestamp,
    bool? isUndone,
    bool? isDeleted,
    Value<DateTime?> updatedAt = const Value.absent(),
  }) => MatchEvent(
    id: id ?? this.id,
    sessionId: sessionId ?? this.sessionId,
    playerId: playerId ?? this.playerId,
    sourcePlayerId: sourcePlayerId.present
        ? sourcePlayerId.value
        : this.sourcePlayerId,
    eventType: eventType ?? this.eventType,
    delta: delta ?? this.delta,
    value: value ?? this.value,
    sequenceNumber: sequenceNumber ?? this.sequenceNumber,
    payloadJson: payloadJson.present ? payloadJson.value : this.payloadJson,
    timestamp: timestamp ?? this.timestamp,
    isUndone: isUndone ?? this.isUndone,
    isDeleted: isDeleted ?? this.isDeleted,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
  );
  MatchEvent copyWithCompanion(MatchEventsCompanion data) {
    return MatchEvent(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      playerId: data.playerId.present ? data.playerId.value : this.playerId,
      sourcePlayerId: data.sourcePlayerId.present
          ? data.sourcePlayerId.value
          : this.sourcePlayerId,
      eventType: data.eventType.present ? data.eventType.value : this.eventType,
      delta: data.delta.present ? data.delta.value : this.delta,
      value: data.value.present ? data.value.value : this.value,
      sequenceNumber: data.sequenceNumber.present
          ? data.sequenceNumber.value
          : this.sequenceNumber,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
      isUndone: data.isUndone.present ? data.isUndone.value : this.isUndone,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MatchEvent(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('playerId: $playerId, ')
          ..write('sourcePlayerId: $sourcePlayerId, ')
          ..write('eventType: $eventType, ')
          ..write('delta: $delta, ')
          ..write('value: $value, ')
          ..write('sequenceNumber: $sequenceNumber, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('timestamp: $timestamp, ')
          ..write('isUndone: $isUndone, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sessionId,
    playerId,
    sourcePlayerId,
    eventType,
    delta,
    value,
    sequenceNumber,
    payloadJson,
    timestamp,
    isUndone,
    isDeleted,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MatchEvent &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.playerId == this.playerId &&
          other.sourcePlayerId == this.sourcePlayerId &&
          other.eventType == this.eventType &&
          other.delta == this.delta &&
          other.value == this.value &&
          other.sequenceNumber == this.sequenceNumber &&
          other.payloadJson == this.payloadJson &&
          other.timestamp == this.timestamp &&
          other.isUndone == this.isUndone &&
          other.isDeleted == this.isDeleted &&
          other.updatedAt == this.updatedAt);
}

class MatchEventsCompanion extends UpdateCompanion<MatchEvent> {
  final Value<String> id;
  final Value<String> sessionId;
  final Value<String> playerId;
  final Value<String?> sourcePlayerId;
  final Value<String> eventType;
  final Value<int> delta;
  final Value<int> value;
  final Value<int> sequenceNumber;
  final Value<String?> payloadJson;
  final Value<DateTime> timestamp;
  final Value<bool> isUndone;
  final Value<bool> isDeleted;
  final Value<DateTime?> updatedAt;
  final Value<int> rowid;
  const MatchEventsCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.playerId = const Value.absent(),
    this.sourcePlayerId = const Value.absent(),
    this.eventType = const Value.absent(),
    this.delta = const Value.absent(),
    this.value = const Value.absent(),
    this.sequenceNumber = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.isUndone = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MatchEventsCompanion.insert({
    required String id,
    required String sessionId,
    required String playerId,
    this.sourcePlayerId = const Value.absent(),
    required String eventType,
    this.delta = const Value.absent(),
    this.value = const Value.absent(),
    this.sequenceNumber = const Value.absent(),
    this.payloadJson = const Value.absent(),
    required DateTime timestamp,
    this.isUndone = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sessionId = Value(sessionId),
       playerId = Value(playerId),
       eventType = Value(eventType),
       timestamp = Value(timestamp);
  static Insertable<MatchEvent> custom({
    Expression<String>? id,
    Expression<String>? sessionId,
    Expression<String>? playerId,
    Expression<String>? sourcePlayerId,
    Expression<String>? eventType,
    Expression<int>? delta,
    Expression<int>? value,
    Expression<int>? sequenceNumber,
    Expression<String>? payloadJson,
    Expression<DateTime>? timestamp,
    Expression<bool>? isUndone,
    Expression<bool>? isDeleted,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (playerId != null) 'player_id': playerId,
      if (sourcePlayerId != null) 'source_player_id': sourcePlayerId,
      if (eventType != null) 'event_type': eventType,
      if (delta != null) 'delta': delta,
      if (value != null) 'value': value,
      if (sequenceNumber != null) 'sequence_number': sequenceNumber,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (timestamp != null) 'timestamp': timestamp,
      if (isUndone != null) 'is_undone': isUndone,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MatchEventsCompanion copyWith({
    Value<String>? id,
    Value<String>? sessionId,
    Value<String>? playerId,
    Value<String?>? sourcePlayerId,
    Value<String>? eventType,
    Value<int>? delta,
    Value<int>? value,
    Value<int>? sequenceNumber,
    Value<String?>? payloadJson,
    Value<DateTime>? timestamp,
    Value<bool>? isUndone,
    Value<bool>? isDeleted,
    Value<DateTime?>? updatedAt,
    Value<int>? rowid,
  }) {
    return MatchEventsCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      playerId: playerId ?? this.playerId,
      sourcePlayerId: sourcePlayerId ?? this.sourcePlayerId,
      eventType: eventType ?? this.eventType,
      delta: delta ?? this.delta,
      value: value ?? this.value,
      sequenceNumber: sequenceNumber ?? this.sequenceNumber,
      payloadJson: payloadJson ?? this.payloadJson,
      timestamp: timestamp ?? this.timestamp,
      isUndone: isUndone ?? this.isUndone,
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
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (playerId.present) {
      map['player_id'] = Variable<String>(playerId.value);
    }
    if (sourcePlayerId.present) {
      map['source_player_id'] = Variable<String>(sourcePlayerId.value);
    }
    if (eventType.present) {
      map['event_type'] = Variable<String>(eventType.value);
    }
    if (delta.present) {
      map['delta'] = Variable<int>(delta.value);
    }
    if (value.present) {
      map['value'] = Variable<int>(value.value);
    }
    if (sequenceNumber.present) {
      map['sequence_number'] = Variable<int>(sequenceNumber.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    if (isUndone.present) {
      map['is_undone'] = Variable<bool>(isUndone.value);
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
    return (StringBuffer('MatchEventsCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('playerId: $playerId, ')
          ..write('sourcePlayerId: $sourcePlayerId, ')
          ..write('eventType: $eventType, ')
          ..write('delta: $delta, ')
          ..write('value: $value, ')
          ..write('sequenceNumber: $sequenceNumber, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('timestamp: $timestamp, ')
          ..write('isUndone: $isUndone, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('updatedAt: $updatedAt, ')
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
  late final $MatchSessionsTable matchSessions = $MatchSessionsTable(this);
  late final $MatchPlayersTable matchPlayers = $MatchPlayersTable(this);
  late final $MatchEventsTable matchEvents = $MatchEventsTable(this);
  late final VaultDao vaultDao = VaultDao(this as AppDatabase);
  late final MatchDao matchDao = MatchDao(this as AppDatabase);
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
    matchSessions,
    matchPlayers,
    matchEvents,
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

  static MultiTypedResultKey<$MatchPlayersTable, List<MatchPlayer>>
  _matchPlayersRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.matchPlayers,
    aliasName: 'vault_items__id__match_players__commander_card_id',
  );

  $$MatchPlayersTableProcessedTableManager get matchPlayersRefs {
    final manager = $$MatchPlayersTableTableManager($_db, $_db.matchPlayers)
        .filter(
          (f) => f.commanderCardId.id.sqlEquals($_itemColumn<String>('id')!),
        );

    final cache = $_typedResult.readTableOrNull(_matchPlayersRefsTable($_db));
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

  Expression<bool> matchPlayersRefs(
    Expression<bool> Function($$MatchPlayersTableFilterComposer f) f,
  ) {
    final $$MatchPlayersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.matchPlayers,
      getReferencedColumn: (t) => t.commanderCardId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MatchPlayersTableFilterComposer(
            $db: $db,
            $table: $db.matchPlayers,
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

  Expression<T> matchPlayersRefs<T extends Object>(
    Expression<T> Function($$MatchPlayersTableAnnotationComposer a) f,
  ) {
    final $$MatchPlayersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.matchPlayers,
      getReferencedColumn: (t) => t.commanderCardId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MatchPlayersTableAnnotationComposer(
            $db: $db,
            $table: $db.matchPlayers,
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
            bool matchPlayersRefs,
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
              ({
                primaryBinderId = false,
                deckVersionItemsRefs = false,
                matchPlayersRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (deckVersionItemsRefs) db.deckVersionItems,
                    if (matchPlayersRefs) db.matchPlayers,
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
                      if (matchPlayersRefs)
                        await $_getPrefetchedData<
                          VaultItem,
                          $VaultItemsTable,
                          MatchPlayer
                        >(
                          currentTable: table,
                          referencedTable: $$VaultItemsTableReferences
                              ._matchPlayersRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$VaultItemsTableReferences(
                                db,
                                table,
                                p0,
                              ).matchPlayersRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.commanderCardId == item.id,
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
      PrefetchHooks Function({
        bool primaryBinderId,
        bool deckVersionItemsRefs,
        bool matchPlayersRefs,
      })
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

  static MultiTypedResultKey<$MatchPlayersTable, List<MatchPlayer>>
  _matchPlayersRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.matchPlayers,
    aliasName: 'decks__id__match_players__deck_id',
  );

  $$MatchPlayersTableProcessedTableManager get matchPlayersRefs {
    final manager = $$MatchPlayersTableTableManager(
      $_db,
      $_db.matchPlayers,
    ).filter((f) => f.deckId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_matchPlayersRefsTable($_db));
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

  Expression<bool> matchPlayersRefs(
    Expression<bool> Function($$MatchPlayersTableFilterComposer f) f,
  ) {
    final $$MatchPlayersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.matchPlayers,
      getReferencedColumn: (t) => t.deckId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MatchPlayersTableFilterComposer(
            $db: $db,
            $table: $db.matchPlayers,
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

  Expression<T> matchPlayersRefs<T extends Object>(
    Expression<T> Function($$MatchPlayersTableAnnotationComposer a) f,
  ) {
    final $$MatchPlayersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.matchPlayers,
      getReferencedColumn: (t) => t.deckId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MatchPlayersTableAnnotationComposer(
            $db: $db,
            $table: $db.matchPlayers,
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
            bool matchPlayersRefs,
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
                matchPlayersRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (deckVersionsRefs) db.deckVersions,
                    if (deckMatchupsRefs) db.deckMatchups,
                    if (deckSynergiesRefs) db.deckSynergies,
                    if (matchPlayersRefs) db.matchPlayers,
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
                      if (matchPlayersRefs)
                        await $_getPrefetchedData<
                          Deck,
                          $DecksTable,
                          MatchPlayer
                        >(
                          currentTable: table,
                          referencedTable: $$DecksTableReferences
                              ._matchPlayersRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$DecksTableReferences(
                                db,
                                table,
                                p0,
                              ).matchPlayersRefs,
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
        bool matchPlayersRefs,
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
typedef $$MatchSessionsTableCreateCompanionBuilder =
    MatchSessionsCompanion Function({
      required String id,
      Value<String> name,
      Value<String> format,
      Value<int> startingLife,
      Value<int> playerCount,
      Value<String> status,
      required DateTime createdAt,
      Value<DateTime?> endedAt,
      Value<bool> isP2pHost,
      Value<String?> p2pSessionCode,
      Value<String?> settingsJson,
      Value<bool> isDeleted,
      Value<DateTime?> updatedAt,
      Value<int> rowid,
    });
typedef $$MatchSessionsTableUpdateCompanionBuilder =
    MatchSessionsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> format,
      Value<int> startingLife,
      Value<int> playerCount,
      Value<String> status,
      Value<DateTime> createdAt,
      Value<DateTime?> endedAt,
      Value<bool> isP2pHost,
      Value<String?> p2pSessionCode,
      Value<String?> settingsJson,
      Value<bool> isDeleted,
      Value<DateTime?> updatedAt,
      Value<int> rowid,
    });

final class $$MatchSessionsTableReferences
    extends BaseReferences<_$AppDatabase, $MatchSessionsTable, MatchSession> {
  $$MatchSessionsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$MatchPlayersTable, List<MatchPlayer>>
  _matchPlayersRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.matchPlayers,
    aliasName: 'match_sessions__id__match_players__session_id',
  );

  $$MatchPlayersTableProcessedTableManager get matchPlayersRefs {
    final manager = $$MatchPlayersTableTableManager(
      $_db,
      $_db.matchPlayers,
    ).filter((f) => f.sessionId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_matchPlayersRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$MatchEventsTable, List<MatchEvent>>
  _matchEventsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.matchEvents,
    aliasName: 'match_sessions__id__match_events__session_id',
  );

  $$MatchEventsTableProcessedTableManager get matchEventsRefs {
    final manager = $$MatchEventsTableTableManager(
      $_db,
      $_db.matchEvents,
    ).filter((f) => f.sessionId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_matchEventsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$MatchSessionsTableFilterComposer
    extends Composer<_$AppDatabase, $MatchSessionsTable> {
  $$MatchSessionsTableFilterComposer({
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

  ColumnFilters<int> get startingLife => $composableBuilder(
    column: $table.startingLife,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get playerCount => $composableBuilder(
    column: $table.playerCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isP2pHost => $composableBuilder(
    column: $table.isP2pHost,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get p2pSessionCode => $composableBuilder(
    column: $table.p2pSessionCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get settingsJson => $composableBuilder(
    column: $table.settingsJson,
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

  Expression<bool> matchPlayersRefs(
    Expression<bool> Function($$MatchPlayersTableFilterComposer f) f,
  ) {
    final $$MatchPlayersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.matchPlayers,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MatchPlayersTableFilterComposer(
            $db: $db,
            $table: $db.matchPlayers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> matchEventsRefs(
    Expression<bool> Function($$MatchEventsTableFilterComposer f) f,
  ) {
    final $$MatchEventsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.matchEvents,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MatchEventsTableFilterComposer(
            $db: $db,
            $table: $db.matchEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MatchSessionsTableOrderingComposer
    extends Composer<_$AppDatabase, $MatchSessionsTable> {
  $$MatchSessionsTableOrderingComposer({
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

  ColumnOrderings<int> get startingLife => $composableBuilder(
    column: $table.startingLife,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get playerCount => $composableBuilder(
    column: $table.playerCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isP2pHost => $composableBuilder(
    column: $table.isP2pHost,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get p2pSessionCode => $composableBuilder(
    column: $table.p2pSessionCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get settingsJson => $composableBuilder(
    column: $table.settingsJson,
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

class $$MatchSessionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $MatchSessionsTable> {
  $$MatchSessionsTableAnnotationComposer({
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

  GeneratedColumn<int> get startingLife => $composableBuilder(
    column: $table.startingLife,
    builder: (column) => column,
  );

  GeneratedColumn<int> get playerCount => $composableBuilder(
    column: $table.playerCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get endedAt =>
      $composableBuilder(column: $table.endedAt, builder: (column) => column);

  GeneratedColumn<bool> get isP2pHost =>
      $composableBuilder(column: $table.isP2pHost, builder: (column) => column);

  GeneratedColumn<String> get p2pSessionCode => $composableBuilder(
    column: $table.p2pSessionCode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get settingsJson => $composableBuilder(
    column: $table.settingsJson,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> matchPlayersRefs<T extends Object>(
    Expression<T> Function($$MatchPlayersTableAnnotationComposer a) f,
  ) {
    final $$MatchPlayersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.matchPlayers,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MatchPlayersTableAnnotationComposer(
            $db: $db,
            $table: $db.matchPlayers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> matchEventsRefs<T extends Object>(
    Expression<T> Function($$MatchEventsTableAnnotationComposer a) f,
  ) {
    final $$MatchEventsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.matchEvents,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MatchEventsTableAnnotationComposer(
            $db: $db,
            $table: $db.matchEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MatchSessionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MatchSessionsTable,
          MatchSession,
          $$MatchSessionsTableFilterComposer,
          $$MatchSessionsTableOrderingComposer,
          $$MatchSessionsTableAnnotationComposer,
          $$MatchSessionsTableCreateCompanionBuilder,
          $$MatchSessionsTableUpdateCompanionBuilder,
          (MatchSession, $$MatchSessionsTableReferences),
          MatchSession,
          PrefetchHooks Function({bool matchPlayersRefs, bool matchEventsRefs})
        > {
  $$MatchSessionsTableTableManager(_$AppDatabase db, $MatchSessionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MatchSessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MatchSessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MatchSessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> format = const Value.absent(),
                Value<int> startingLife = const Value.absent(),
                Value<int> playerCount = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> endedAt = const Value.absent(),
                Value<bool> isP2pHost = const Value.absent(),
                Value<String?> p2pSessionCode = const Value.absent(),
                Value<String?> settingsJson = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MatchSessionsCompanion(
                id: id,
                name: name,
                format: format,
                startingLife: startingLife,
                playerCount: playerCount,
                status: status,
                createdAt: createdAt,
                endedAt: endedAt,
                isP2pHost: isP2pHost,
                p2pSessionCode: p2pSessionCode,
                settingsJson: settingsJson,
                isDeleted: isDeleted,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String> name = const Value.absent(),
                Value<String> format = const Value.absent(),
                Value<int> startingLife = const Value.absent(),
                Value<int> playerCount = const Value.absent(),
                Value<String> status = const Value.absent(),
                required DateTime createdAt,
                Value<DateTime?> endedAt = const Value.absent(),
                Value<bool> isP2pHost = const Value.absent(),
                Value<String?> p2pSessionCode = const Value.absent(),
                Value<String?> settingsJson = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MatchSessionsCompanion.insert(
                id: id,
                name: name,
                format: format,
                startingLife: startingLife,
                playerCount: playerCount,
                status: status,
                createdAt: createdAt,
                endedAt: endedAt,
                isP2pHost: isP2pHost,
                p2pSessionCode: p2pSessionCode,
                settingsJson: settingsJson,
                isDeleted: isDeleted,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$MatchSessionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({matchPlayersRefs = false, matchEventsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (matchPlayersRefs) db.matchPlayers,
                    if (matchEventsRefs) db.matchEvents,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (matchPlayersRefs)
                        await $_getPrefetchedData<
                          MatchSession,
                          $MatchSessionsTable,
                          MatchPlayer
                        >(
                          currentTable: table,
                          referencedTable: $$MatchSessionsTableReferences
                              ._matchPlayersRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MatchSessionsTableReferences(
                                db,
                                table,
                                p0,
                              ).matchPlayersRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.sessionId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (matchEventsRefs)
                        await $_getPrefetchedData<
                          MatchSession,
                          $MatchSessionsTable,
                          MatchEvent
                        >(
                          currentTable: table,
                          referencedTable: $$MatchSessionsTableReferences
                              ._matchEventsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MatchSessionsTableReferences(
                                db,
                                table,
                                p0,
                              ).matchEventsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.sessionId == item.id,
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

typedef $$MatchSessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MatchSessionsTable,
      MatchSession,
      $$MatchSessionsTableFilterComposer,
      $$MatchSessionsTableOrderingComposer,
      $$MatchSessionsTableAnnotationComposer,
      $$MatchSessionsTableCreateCompanionBuilder,
      $$MatchSessionsTableUpdateCompanionBuilder,
      (MatchSession, $$MatchSessionsTableReferences),
      MatchSession,
      PrefetchHooks Function({bool matchPlayersRefs, bool matchEventsRefs})
    >;
typedef $$MatchPlayersTableCreateCompanionBuilder =
    MatchPlayersCompanion Function({
      required String id,
      required String sessionId,
      required int seatOrder,
      required String playerName,
      Value<String?> deckId,
      Value<String?> commanderCardId,
      Value<String?> commanderName,
      Value<String?> artCropUrl,
      Value<String?> colorTheme,
      Value<int> currentLife,
      Value<int> poison,
      Value<int> energy,
      Value<int> experience,
      Value<int> commanderTax,
      Value<bool> isMonarch,
      Value<bool> hasInitiative,
      Value<bool> isEliminated,
      Value<DateTime?> eliminatedAt,
      Value<bool> isLocalDevice,
      Value<String?> peerDeviceId,
      Value<String?> commanderDamageJson,
      Value<String?> floatingManaJson,
      Value<int> stormCount,
      Value<String?> countersJson,
      Value<bool> isDeleted,
      Value<DateTime?> updatedAt,
      Value<int> rowid,
    });
typedef $$MatchPlayersTableUpdateCompanionBuilder =
    MatchPlayersCompanion Function({
      Value<String> id,
      Value<String> sessionId,
      Value<int> seatOrder,
      Value<String> playerName,
      Value<String?> deckId,
      Value<String?> commanderCardId,
      Value<String?> commanderName,
      Value<String?> artCropUrl,
      Value<String?> colorTheme,
      Value<int> currentLife,
      Value<int> poison,
      Value<int> energy,
      Value<int> experience,
      Value<int> commanderTax,
      Value<bool> isMonarch,
      Value<bool> hasInitiative,
      Value<bool> isEliminated,
      Value<DateTime?> eliminatedAt,
      Value<bool> isLocalDevice,
      Value<String?> peerDeviceId,
      Value<String?> commanderDamageJson,
      Value<String?> floatingManaJson,
      Value<int> stormCount,
      Value<String?> countersJson,
      Value<bool> isDeleted,
      Value<DateTime?> updatedAt,
      Value<int> rowid,
    });

final class $$MatchPlayersTableReferences
    extends BaseReferences<_$AppDatabase, $MatchPlayersTable, MatchPlayer> {
  $$MatchPlayersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $MatchSessionsTable _sessionIdTable(_$AppDatabase db) => db
      .matchSessions
      .createAlias('match_players__session_id__match_sessions__id');

  $$MatchSessionsTableProcessedTableManager get sessionId {
    final $_column = $_itemColumn<String>('session_id')!;

    final manager = $$MatchSessionsTableTableManager(
      $_db,
      $_db.matchSessions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sessionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $DecksTable _deckIdTable(_$AppDatabase db) =>
      db.decks.createAlias('match_players__deck_id__decks__id');

  $$DecksTableProcessedTableManager? get deckId {
    final $_column = $_itemColumn<String>('deck_id');
    if ($_column == null) return null;
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

  static $VaultItemsTable _commanderCardIdTable(_$AppDatabase db) => db
      .vaultItems
      .createAlias('match_players__commander_card_id__vault_items__id');

  $$VaultItemsTableProcessedTableManager? get commanderCardId {
    final $_column = $_itemColumn<String>('commander_card_id');
    if ($_column == null) return null;
    final manager = $$VaultItemsTableTableManager(
      $_db,
      $_db.vaultItems,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_commanderCardIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$MatchPlayersTableFilterComposer
    extends Composer<_$AppDatabase, $MatchPlayersTable> {
  $$MatchPlayersTableFilterComposer({
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

  ColumnFilters<int> get seatOrder => $composableBuilder(
    column: $table.seatOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get playerName => $composableBuilder(
    column: $table.playerName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get commanderName => $composableBuilder(
    column: $table.commanderName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get artCropUrl => $composableBuilder(
    column: $table.artCropUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get colorTheme => $composableBuilder(
    column: $table.colorTheme,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get currentLife => $composableBuilder(
    column: $table.currentLife,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get poison => $composableBuilder(
    column: $table.poison,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get energy => $composableBuilder(
    column: $table.energy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get experience => $composableBuilder(
    column: $table.experience,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get commanderTax => $composableBuilder(
    column: $table.commanderTax,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isMonarch => $composableBuilder(
    column: $table.isMonarch,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get hasInitiative => $composableBuilder(
    column: $table.hasInitiative,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isEliminated => $composableBuilder(
    column: $table.isEliminated,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get eliminatedAt => $composableBuilder(
    column: $table.eliminatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isLocalDevice => $composableBuilder(
    column: $table.isLocalDevice,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get peerDeviceId => $composableBuilder(
    column: $table.peerDeviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get commanderDamageJson => $composableBuilder(
    column: $table.commanderDamageJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get floatingManaJson => $composableBuilder(
    column: $table.floatingManaJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get stormCount => $composableBuilder(
    column: $table.stormCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get countersJson => $composableBuilder(
    column: $table.countersJson,
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

  $$MatchSessionsTableFilterComposer get sessionId {
    final $$MatchSessionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.matchSessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MatchSessionsTableFilterComposer(
            $db: $db,
            $table: $db.matchSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

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

  $$VaultItemsTableFilterComposer get commanderCardId {
    final $$VaultItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.commanderCardId,
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

class $$MatchPlayersTableOrderingComposer
    extends Composer<_$AppDatabase, $MatchPlayersTable> {
  $$MatchPlayersTableOrderingComposer({
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

  ColumnOrderings<int> get seatOrder => $composableBuilder(
    column: $table.seatOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get playerName => $composableBuilder(
    column: $table.playerName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get commanderName => $composableBuilder(
    column: $table.commanderName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get artCropUrl => $composableBuilder(
    column: $table.artCropUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get colorTheme => $composableBuilder(
    column: $table.colorTheme,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get currentLife => $composableBuilder(
    column: $table.currentLife,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get poison => $composableBuilder(
    column: $table.poison,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get energy => $composableBuilder(
    column: $table.energy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get experience => $composableBuilder(
    column: $table.experience,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get commanderTax => $composableBuilder(
    column: $table.commanderTax,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isMonarch => $composableBuilder(
    column: $table.isMonarch,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get hasInitiative => $composableBuilder(
    column: $table.hasInitiative,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isEliminated => $composableBuilder(
    column: $table.isEliminated,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get eliminatedAt => $composableBuilder(
    column: $table.eliminatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isLocalDevice => $composableBuilder(
    column: $table.isLocalDevice,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get peerDeviceId => $composableBuilder(
    column: $table.peerDeviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get commanderDamageJson => $composableBuilder(
    column: $table.commanderDamageJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get floatingManaJson => $composableBuilder(
    column: $table.floatingManaJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get stormCount => $composableBuilder(
    column: $table.stormCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get countersJson => $composableBuilder(
    column: $table.countersJson,
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

  $$MatchSessionsTableOrderingComposer get sessionId {
    final $$MatchSessionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.matchSessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MatchSessionsTableOrderingComposer(
            $db: $db,
            $table: $db.matchSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

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

  $$VaultItemsTableOrderingComposer get commanderCardId {
    final $$VaultItemsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.commanderCardId,
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

class $$MatchPlayersTableAnnotationComposer
    extends Composer<_$AppDatabase, $MatchPlayersTable> {
  $$MatchPlayersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get seatOrder =>
      $composableBuilder(column: $table.seatOrder, builder: (column) => column);

  GeneratedColumn<String> get playerName => $composableBuilder(
    column: $table.playerName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get commanderName => $composableBuilder(
    column: $table.commanderName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get artCropUrl => $composableBuilder(
    column: $table.artCropUrl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get colorTheme => $composableBuilder(
    column: $table.colorTheme,
    builder: (column) => column,
  );

  GeneratedColumn<int> get currentLife => $composableBuilder(
    column: $table.currentLife,
    builder: (column) => column,
  );

  GeneratedColumn<int> get poison =>
      $composableBuilder(column: $table.poison, builder: (column) => column);

  GeneratedColumn<int> get energy =>
      $composableBuilder(column: $table.energy, builder: (column) => column);

  GeneratedColumn<int> get experience => $composableBuilder(
    column: $table.experience,
    builder: (column) => column,
  );

  GeneratedColumn<int> get commanderTax => $composableBuilder(
    column: $table.commanderTax,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isMonarch =>
      $composableBuilder(column: $table.isMonarch, builder: (column) => column);

  GeneratedColumn<bool> get hasInitiative => $composableBuilder(
    column: $table.hasInitiative,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isEliminated => $composableBuilder(
    column: $table.isEliminated,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get eliminatedAt => $composableBuilder(
    column: $table.eliminatedAt,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isLocalDevice => $composableBuilder(
    column: $table.isLocalDevice,
    builder: (column) => column,
  );

  GeneratedColumn<String> get peerDeviceId => $composableBuilder(
    column: $table.peerDeviceId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get commanderDamageJson => $composableBuilder(
    column: $table.commanderDamageJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get floatingManaJson => $composableBuilder(
    column: $table.floatingManaJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get stormCount => $composableBuilder(
    column: $table.stormCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get countersJson => $composableBuilder(
    column: $table.countersJson,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$MatchSessionsTableAnnotationComposer get sessionId {
    final $$MatchSessionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.matchSessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MatchSessionsTableAnnotationComposer(
            $db: $db,
            $table: $db.matchSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

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

  $$VaultItemsTableAnnotationComposer get commanderCardId {
    final $$VaultItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.commanderCardId,
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

class $$MatchPlayersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MatchPlayersTable,
          MatchPlayer,
          $$MatchPlayersTableFilterComposer,
          $$MatchPlayersTableOrderingComposer,
          $$MatchPlayersTableAnnotationComposer,
          $$MatchPlayersTableCreateCompanionBuilder,
          $$MatchPlayersTableUpdateCompanionBuilder,
          (MatchPlayer, $$MatchPlayersTableReferences),
          MatchPlayer,
          PrefetchHooks Function({
            bool sessionId,
            bool deckId,
            bool commanderCardId,
          })
        > {
  $$MatchPlayersTableTableManager(_$AppDatabase db, $MatchPlayersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MatchPlayersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MatchPlayersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MatchPlayersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> sessionId = const Value.absent(),
                Value<int> seatOrder = const Value.absent(),
                Value<String> playerName = const Value.absent(),
                Value<String?> deckId = const Value.absent(),
                Value<String?> commanderCardId = const Value.absent(),
                Value<String?> commanderName = const Value.absent(),
                Value<String?> artCropUrl = const Value.absent(),
                Value<String?> colorTheme = const Value.absent(),
                Value<int> currentLife = const Value.absent(),
                Value<int> poison = const Value.absent(),
                Value<int> energy = const Value.absent(),
                Value<int> experience = const Value.absent(),
                Value<int> commanderTax = const Value.absent(),
                Value<bool> isMonarch = const Value.absent(),
                Value<bool> hasInitiative = const Value.absent(),
                Value<bool> isEliminated = const Value.absent(),
                Value<DateTime?> eliminatedAt = const Value.absent(),
                Value<bool> isLocalDevice = const Value.absent(),
                Value<String?> peerDeviceId = const Value.absent(),
                Value<String?> commanderDamageJson = const Value.absent(),
                Value<String?> floatingManaJson = const Value.absent(),
                Value<int> stormCount = const Value.absent(),
                Value<String?> countersJson = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MatchPlayersCompanion(
                id: id,
                sessionId: sessionId,
                seatOrder: seatOrder,
                playerName: playerName,
                deckId: deckId,
                commanderCardId: commanderCardId,
                commanderName: commanderName,
                artCropUrl: artCropUrl,
                colorTheme: colorTheme,
                currentLife: currentLife,
                poison: poison,
                energy: energy,
                experience: experience,
                commanderTax: commanderTax,
                isMonarch: isMonarch,
                hasInitiative: hasInitiative,
                isEliminated: isEliminated,
                eliminatedAt: eliminatedAt,
                isLocalDevice: isLocalDevice,
                peerDeviceId: peerDeviceId,
                commanderDamageJson: commanderDamageJson,
                floatingManaJson: floatingManaJson,
                stormCount: stormCount,
                countersJson: countersJson,
                isDeleted: isDeleted,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String sessionId,
                required int seatOrder,
                required String playerName,
                Value<String?> deckId = const Value.absent(),
                Value<String?> commanderCardId = const Value.absent(),
                Value<String?> commanderName = const Value.absent(),
                Value<String?> artCropUrl = const Value.absent(),
                Value<String?> colorTheme = const Value.absent(),
                Value<int> currentLife = const Value.absent(),
                Value<int> poison = const Value.absent(),
                Value<int> energy = const Value.absent(),
                Value<int> experience = const Value.absent(),
                Value<int> commanderTax = const Value.absent(),
                Value<bool> isMonarch = const Value.absent(),
                Value<bool> hasInitiative = const Value.absent(),
                Value<bool> isEliminated = const Value.absent(),
                Value<DateTime?> eliminatedAt = const Value.absent(),
                Value<bool> isLocalDevice = const Value.absent(),
                Value<String?> peerDeviceId = const Value.absent(),
                Value<String?> commanderDamageJson = const Value.absent(),
                Value<String?> floatingManaJson = const Value.absent(),
                Value<int> stormCount = const Value.absent(),
                Value<String?> countersJson = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MatchPlayersCompanion.insert(
                id: id,
                sessionId: sessionId,
                seatOrder: seatOrder,
                playerName: playerName,
                deckId: deckId,
                commanderCardId: commanderCardId,
                commanderName: commanderName,
                artCropUrl: artCropUrl,
                colorTheme: colorTheme,
                currentLife: currentLife,
                poison: poison,
                energy: energy,
                experience: experience,
                commanderTax: commanderTax,
                isMonarch: isMonarch,
                hasInitiative: hasInitiative,
                isEliminated: isEliminated,
                eliminatedAt: eliminatedAt,
                isLocalDevice: isLocalDevice,
                peerDeviceId: peerDeviceId,
                commanderDamageJson: commanderDamageJson,
                floatingManaJson: floatingManaJson,
                stormCount: stormCount,
                countersJson: countersJson,
                isDeleted: isDeleted,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$MatchPlayersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({sessionId = false, deckId = false, commanderCardId = false}) {
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
                        if (sessionId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.sessionId,
                                    referencedTable:
                                        $$MatchPlayersTableReferences
                                            ._sessionIdTable(db),
                                    referencedColumn:
                                        $$MatchPlayersTableReferences
                                            ._sessionIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (deckId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.deckId,
                                    referencedTable:
                                        $$MatchPlayersTableReferences
                                            ._deckIdTable(db),
                                    referencedColumn:
                                        $$MatchPlayersTableReferences
                                            ._deckIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (commanderCardId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.commanderCardId,
                                    referencedTable:
                                        $$MatchPlayersTableReferences
                                            ._commanderCardIdTable(db),
                                    referencedColumn:
                                        $$MatchPlayersTableReferences
                                            ._commanderCardIdTable(db)
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

typedef $$MatchPlayersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MatchPlayersTable,
      MatchPlayer,
      $$MatchPlayersTableFilterComposer,
      $$MatchPlayersTableOrderingComposer,
      $$MatchPlayersTableAnnotationComposer,
      $$MatchPlayersTableCreateCompanionBuilder,
      $$MatchPlayersTableUpdateCompanionBuilder,
      (MatchPlayer, $$MatchPlayersTableReferences),
      MatchPlayer,
      PrefetchHooks Function({
        bool sessionId,
        bool deckId,
        bool commanderCardId,
      })
    >;
typedef $$MatchEventsTableCreateCompanionBuilder =
    MatchEventsCompanion Function({
      required String id,
      required String sessionId,
      required String playerId,
      Value<String?> sourcePlayerId,
      required String eventType,
      Value<int> delta,
      Value<int> value,
      Value<int> sequenceNumber,
      Value<String?> payloadJson,
      required DateTime timestamp,
      Value<bool> isUndone,
      Value<bool> isDeleted,
      Value<DateTime?> updatedAt,
      Value<int> rowid,
    });
typedef $$MatchEventsTableUpdateCompanionBuilder =
    MatchEventsCompanion Function({
      Value<String> id,
      Value<String> sessionId,
      Value<String> playerId,
      Value<String?> sourcePlayerId,
      Value<String> eventType,
      Value<int> delta,
      Value<int> value,
      Value<int> sequenceNumber,
      Value<String?> payloadJson,
      Value<DateTime> timestamp,
      Value<bool> isUndone,
      Value<bool> isDeleted,
      Value<DateTime?> updatedAt,
      Value<int> rowid,
    });

final class $$MatchEventsTableReferences
    extends BaseReferences<_$AppDatabase, $MatchEventsTable, MatchEvent> {
  $$MatchEventsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $MatchSessionsTable _sessionIdTable(_$AppDatabase db) => db
      .matchSessions
      .createAlias('match_events__session_id__match_sessions__id');

  $$MatchSessionsTableProcessedTableManager get sessionId {
    final $_column = $_itemColumn<String>('session_id')!;

    final manager = $$MatchSessionsTableTableManager(
      $_db,
      $_db.matchSessions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sessionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$MatchEventsTableFilterComposer
    extends Composer<_$AppDatabase, $MatchEventsTable> {
  $$MatchEventsTableFilterComposer({
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

  ColumnFilters<String> get playerId => $composableBuilder(
    column: $table.playerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourcePlayerId => $composableBuilder(
    column: $table.sourcePlayerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get eventType => $composableBuilder(
    column: $table.eventType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get delta => $composableBuilder(
    column: $table.delta,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sequenceNumber => $composableBuilder(
    column: $table.sequenceNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isUndone => $composableBuilder(
    column: $table.isUndone,
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

  $$MatchSessionsTableFilterComposer get sessionId {
    final $$MatchSessionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.matchSessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MatchSessionsTableFilterComposer(
            $db: $db,
            $table: $db.matchSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MatchEventsTableOrderingComposer
    extends Composer<_$AppDatabase, $MatchEventsTable> {
  $$MatchEventsTableOrderingComposer({
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

  ColumnOrderings<String> get playerId => $composableBuilder(
    column: $table.playerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourcePlayerId => $composableBuilder(
    column: $table.sourcePlayerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get eventType => $composableBuilder(
    column: $table.eventType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get delta => $composableBuilder(
    column: $table.delta,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sequenceNumber => $composableBuilder(
    column: $table.sequenceNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isUndone => $composableBuilder(
    column: $table.isUndone,
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

  $$MatchSessionsTableOrderingComposer get sessionId {
    final $$MatchSessionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.matchSessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MatchSessionsTableOrderingComposer(
            $db: $db,
            $table: $db.matchSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MatchEventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $MatchEventsTable> {
  $$MatchEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get playerId =>
      $composableBuilder(column: $table.playerId, builder: (column) => column);

  GeneratedColumn<String> get sourcePlayerId => $composableBuilder(
    column: $table.sourcePlayerId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get eventType =>
      $composableBuilder(column: $table.eventType, builder: (column) => column);

  GeneratedColumn<int> get delta =>
      $composableBuilder(column: $table.delta, builder: (column) => column);

  GeneratedColumn<int> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<int> get sequenceNumber => $composableBuilder(
    column: $table.sequenceNumber,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);

  GeneratedColumn<bool> get isUndone =>
      $composableBuilder(column: $table.isUndone, builder: (column) => column);

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$MatchSessionsTableAnnotationComposer get sessionId {
    final $$MatchSessionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.matchSessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MatchSessionsTableAnnotationComposer(
            $db: $db,
            $table: $db.matchSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MatchEventsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MatchEventsTable,
          MatchEvent,
          $$MatchEventsTableFilterComposer,
          $$MatchEventsTableOrderingComposer,
          $$MatchEventsTableAnnotationComposer,
          $$MatchEventsTableCreateCompanionBuilder,
          $$MatchEventsTableUpdateCompanionBuilder,
          (MatchEvent, $$MatchEventsTableReferences),
          MatchEvent,
          PrefetchHooks Function({bool sessionId})
        > {
  $$MatchEventsTableTableManager(_$AppDatabase db, $MatchEventsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MatchEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MatchEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MatchEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> sessionId = const Value.absent(),
                Value<String> playerId = const Value.absent(),
                Value<String?> sourcePlayerId = const Value.absent(),
                Value<String> eventType = const Value.absent(),
                Value<int> delta = const Value.absent(),
                Value<int> value = const Value.absent(),
                Value<int> sequenceNumber = const Value.absent(),
                Value<String?> payloadJson = const Value.absent(),
                Value<DateTime> timestamp = const Value.absent(),
                Value<bool> isUndone = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MatchEventsCompanion(
                id: id,
                sessionId: sessionId,
                playerId: playerId,
                sourcePlayerId: sourcePlayerId,
                eventType: eventType,
                delta: delta,
                value: value,
                sequenceNumber: sequenceNumber,
                payloadJson: payloadJson,
                timestamp: timestamp,
                isUndone: isUndone,
                isDeleted: isDeleted,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String sessionId,
                required String playerId,
                Value<String?> sourcePlayerId = const Value.absent(),
                required String eventType,
                Value<int> delta = const Value.absent(),
                Value<int> value = const Value.absent(),
                Value<int> sequenceNumber = const Value.absent(),
                Value<String?> payloadJson = const Value.absent(),
                required DateTime timestamp,
                Value<bool> isUndone = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MatchEventsCompanion.insert(
                id: id,
                sessionId: sessionId,
                playerId: playerId,
                sourcePlayerId: sourcePlayerId,
                eventType: eventType,
                delta: delta,
                value: value,
                sequenceNumber: sequenceNumber,
                payloadJson: payloadJson,
                timestamp: timestamp,
                isUndone: isUndone,
                isDeleted: isDeleted,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$MatchEventsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({sessionId = false}) {
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
                    if (sessionId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.sessionId,
                                referencedTable: $$MatchEventsTableReferences
                                    ._sessionIdTable(db),
                                referencedColumn: $$MatchEventsTableReferences
                                    ._sessionIdTable(db)
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

typedef $$MatchEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MatchEventsTable,
      MatchEvent,
      $$MatchEventsTableFilterComposer,
      $$MatchEventsTableOrderingComposer,
      $$MatchEventsTableAnnotationComposer,
      $$MatchEventsTableCreateCompanionBuilder,
      $$MatchEventsTableUpdateCompanionBuilder,
      (MatchEvent, $$MatchEventsTableReferences),
      MatchEvent,
      PrefetchHooks Function({bool sessionId})
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
  $$MatchSessionsTableTableManager get matchSessions =>
      $$MatchSessionsTableTableManager(_db, _db.matchSessions);
  $$MatchPlayersTableTableManager get matchPlayers =>
      $$MatchPlayersTableTableManager(_db, _db.matchPlayers);
  $$MatchEventsTableTableManager get matchEvents =>
      $$MatchEventsTableTableManager(_db, _db.matchEvents);
}
