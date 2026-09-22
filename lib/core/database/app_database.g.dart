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
  @override
  List<GeneratedColumn> get $columns => [id, name, collectionType, createdAt];
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
  const VaultBinder({
    required this.id,
    required this.name,
    required this.collectionType,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['collection_type'] = Variable<String>(collectionType);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  VaultBindersCompanion toCompanion(bool nullToAbsent) {
    return VaultBindersCompanion(
      id: Value(id),
      name: Value(name),
      collectionType: Value(collectionType),
      createdAt: Value(createdAt),
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
    };
  }

  VaultBinder copyWith({
    String? id,
    String? name,
    String? collectionType,
    DateTime? createdAt,
  }) => VaultBinder(
    id: id ?? this.id,
    name: name ?? this.name,
    collectionType: collectionType ?? this.collectionType,
    createdAt: createdAt ?? this.createdAt,
  );
  VaultBinder copyWithCompanion(VaultBindersCompanion data) {
    return VaultBinder(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      collectionType: data.collectionType.present
          ? data.collectionType.value
          : this.collectionType,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('VaultBinder(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('collectionType: $collectionType, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, collectionType, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VaultBinder &&
          other.id == this.id &&
          other.name == this.name &&
          other.collectionType == this.collectionType &&
          other.createdAt == this.createdAt);
}

class VaultBindersCompanion extends UpdateCompanion<VaultBinder> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> collectionType;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const VaultBindersCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.collectionType = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  VaultBindersCompanion.insert({
    required String id,
    required String name,
    required String collectionType,
    required DateTime createdAt,
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
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (collectionType != null) 'collection_type': collectionType,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  VaultBindersCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? collectionType,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return VaultBindersCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      collectionType: collectionType ?? this.collectionType,
      createdAt: createdAt ?? this.createdAt,
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
    primaryBinderId,
    currentMarketPrice,
    lastPriceUpdate,
    dynamicData,
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
  final String? primaryBinderId;
  final double currentMarketPrice;
  final DateTime lastPriceUpdate;
  final String dynamicData;
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
    this.primaryBinderId,
    required this.currentMarketPrice,
    required this.lastPriceUpdate,
    required this.dynamicData,
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
    if (!nullToAbsent || primaryBinderId != null) {
      map['primary_binder_id'] = Variable<String>(primaryBinderId);
    }
    map['current_market_price'] = Variable<double>(currentMarketPrice);
    map['last_price_update'] = Variable<DateTime>(lastPriceUpdate);
    map['dynamic_data'] = Variable<String>(dynamicData);
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
      primaryBinderId: primaryBinderId == null && nullToAbsent
          ? const Value.absent()
          : Value(primaryBinderId),
      currentMarketPrice: Value(currentMarketPrice),
      lastPriceUpdate: Value(lastPriceUpdate),
      dynamicData: Value(dynamicData),
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
      primaryBinderId: serializer.fromJson<String?>(json['primaryBinderId']),
      currentMarketPrice: serializer.fromJson<double>(
        json['currentMarketPrice'],
      ),
      lastPriceUpdate: serializer.fromJson<DateTime>(json['lastPriceUpdate']),
      dynamicData: serializer.fromJson<String>(json['dynamicData']),
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
      'primaryBinderId': serializer.toJson<String?>(primaryBinderId),
      'currentMarketPrice': serializer.toJson<double>(currentMarketPrice),
      'lastPriceUpdate': serializer.toJson<DateTime>(lastPriceUpdate),
      'dynamicData': serializer.toJson<String>(dynamicData),
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
    Value<String?> primaryBinderId = const Value.absent(),
    double? currentMarketPrice,
    DateTime? lastPriceUpdate,
    String? dynamicData,
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
    primaryBinderId: primaryBinderId.present
        ? primaryBinderId.value
        : this.primaryBinderId,
    currentMarketPrice: currentMarketPrice ?? this.currentMarketPrice,
    lastPriceUpdate: lastPriceUpdate ?? this.lastPriceUpdate,
    dynamicData: dynamicData ?? this.dynamicData,
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
          ..write('primaryBinderId: $primaryBinderId, ')
          ..write('currentMarketPrice: $currentMarketPrice, ')
          ..write('lastPriceUpdate: $lastPriceUpdate, ')
          ..write('dynamicData: $dynamicData')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
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
    primaryBinderId,
    currentMarketPrice,
    lastPriceUpdate,
    dynamicData,
  );
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
          other.primaryBinderId == this.primaryBinderId &&
          other.currentMarketPrice == this.currentMarketPrice &&
          other.lastPriceUpdate == this.lastPriceUpdate &&
          other.dynamicData == this.dynamicData);
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
  final Value<String?> primaryBinderId;
  final Value<double> currentMarketPrice;
  final Value<DateTime> lastPriceUpdate;
  final Value<String> dynamicData;
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
    this.primaryBinderId = const Value.absent(),
    this.currentMarketPrice = const Value.absent(),
    this.lastPriceUpdate = const Value.absent(),
    this.dynamicData = const Value.absent(),
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
    this.primaryBinderId = const Value.absent(),
    required double currentMarketPrice,
    required DateTime lastPriceUpdate,
    required String dynamicData,
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
    Expression<String>? primaryBinderId,
    Expression<double>? currentMarketPrice,
    Expression<DateTime>? lastPriceUpdate,
    Expression<String>? dynamicData,
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
      if (primaryBinderId != null) 'primary_binder_id': primaryBinderId,
      if (currentMarketPrice != null)
        'current_market_price': currentMarketPrice,
      if (lastPriceUpdate != null) 'last_price_update': lastPriceUpdate,
      if (dynamicData != null) 'dynamic_data': dynamicData,
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
    Value<String?>? primaryBinderId,
    Value<double>? currentMarketPrice,
    Value<DateTime>? lastPriceUpdate,
    Value<String>? dynamicData,
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
      primaryBinderId: primaryBinderId ?? this.primaryBinderId,
      currentMarketPrice: currentMarketPrice ?? this.currentMarketPrice,
      lastPriceUpdate: lastPriceUpdate ?? this.lastPriceUpdate,
      dynamicData: dynamicData ?? this.dynamicData,
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
          ..write('primaryBinderId: $primaryBinderId, ')
          ..write('currentMarketPrice: $currentMarketPrice, ')
          ..write('lastPriceUpdate: $lastPriceUpdate, ')
          ..write('dynamicData: $dynamicData, ')
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
          ..write('createdAt: $createdAt')
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
          other.createdAt == this.createdAt);
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    deckId,
    versionNumber,
    versionNote,
    isActive,
    createdAt,
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
  const DeckVersion({
    required this.id,
    required this.deckId,
    required this.versionNumber,
    this.versionNote,
    required this.isActive,
    required this.createdAt,
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
    };
  }

  DeckVersion copyWith({
    String? id,
    String? deckId,
    int? versionNumber,
    Value<String?> versionNote = const Value.absent(),
    bool? isActive,
    DateTime? createdAt,
  }) => DeckVersion(
    id: id ?? this.id,
    deckId: deckId ?? this.deckId,
    versionNumber: versionNumber ?? this.versionNumber,
    versionNote: versionNote.present ? versionNote.value : this.versionNote,
    isActive: isActive ?? this.isActive,
    createdAt: createdAt ?? this.createdAt,
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
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, deckId, versionNumber, versionNote, isActive, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DeckVersion &&
          other.id == this.id &&
          other.deckId == this.deckId &&
          other.versionNumber == this.versionNumber &&
          other.versionNote == this.versionNote &&
          other.isActive == this.isActive &&
          other.createdAt == this.createdAt);
}

class DeckVersionsCompanion extends UpdateCompanion<DeckVersion> {
  final Value<String> id;
  final Value<String> deckId;
  final Value<int> versionNumber;
  final Value<String?> versionNote;
  final Value<bool> isActive;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const DeckVersionsCompanion({
    this.id = const Value.absent(),
    this.deckId = const Value.absent(),
    this.versionNumber = const Value.absent(),
    this.versionNote = const Value.absent(),
    this.isActive = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DeckVersionsCompanion.insert({
    required String id,
    required String deckId,
    required int versionNumber,
    this.versionNote = const Value.absent(),
    this.isActive = const Value.absent(),
    required DateTime createdAt,
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
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (deckId != null) 'deck_id': deckId,
      if (versionNumber != null) 'version_number': versionNumber,
      if (versionNote != null) 'version_note': versionNote,
      if (isActive != null) 'is_active': isActive,
      if (createdAt != null) 'created_at': createdAt,
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
    Value<int>? rowid,
  }) {
    return DeckVersionsCompanion(
      id: id ?? this.id,
      deckId: deckId ?? this.deckId,
      versionNumber: versionNumber ?? this.versionNumber,
      versionNote: versionNote ?? this.versionNote,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    versionId,
    vaultItemId,
    quantity,
    boardZone,
    isProxy,
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
  const DeckVersionItem({
    required this.id,
    required this.versionId,
    required this.vaultItemId,
    required this.quantity,
    required this.boardZone,
    required this.isProxy,
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
    };
  }

  DeckVersionItem copyWith({
    String? id,
    String? versionId,
    String? vaultItemId,
    int? quantity,
    String? boardZone,
    bool? isProxy,
  }) => DeckVersionItem(
    id: id ?? this.id,
    versionId: versionId ?? this.versionId,
    vaultItemId: vaultItemId ?? this.vaultItemId,
    quantity: quantity ?? this.quantity,
    boardZone: boardZone ?? this.boardZone,
    isProxy: isProxy ?? this.isProxy,
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
          ..write('isProxy: $isProxy')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, versionId, vaultItemId, quantity, boardZone, isProxy);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DeckVersionItem &&
          other.id == this.id &&
          other.versionId == this.versionId &&
          other.vaultItemId == this.vaultItemId &&
          other.quantity == this.quantity &&
          other.boardZone == this.boardZone &&
          other.isProxy == this.isProxy);
}

class DeckVersionItemsCompanion extends UpdateCompanion<DeckVersionItem> {
  final Value<String> id;
  final Value<String> versionId;
  final Value<String> vaultItemId;
  final Value<int> quantity;
  final Value<String> boardZone;
  final Value<bool> isProxy;
  final Value<int> rowid;
  const DeckVersionItemsCompanion({
    this.id = const Value.absent(),
    this.versionId = const Value.absent(),
    this.vaultItemId = const Value.absent(),
    this.quantity = const Value.absent(),
    this.boardZone = const Value.absent(),
    this.isProxy = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DeckVersionItemsCompanion.insert({
    required String id,
    required String versionId,
    required String vaultItemId,
    this.quantity = const Value.absent(),
    required String boardZone,
    this.isProxy = const Value.absent(),
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
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (versionId != null) 'version_id': versionId,
      if (vaultItemId != null) 'vault_item_id': vaultItemId,
      if (quantity != null) 'quantity': quantity,
      if (boardZone != null) 'board_zone': boardZone,
      if (isProxy != null) 'is_proxy': isProxy,
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
    Value<int>? rowid,
  }) {
    return DeckVersionItemsCompanion(
      id: id ?? this.id,
      versionId: versionId ?? this.versionId,
      vaultItemId: vaultItemId ?? this.vaultItemId,
      quantity: quantity ?? this.quantity,
      boardZone: boardZone ?? this.boardZone,
      isProxy: isProxy ?? this.isProxy,
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    deckId,
    opponentArchetype,
    notes,
    swapInItemIds,
    swapOutItemIds,
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
  const DeckMatchup({
    required this.id,
    required this.deckId,
    required this.opponentArchetype,
    this.notes,
    this.swapInItemIds,
    this.swapOutItemIds,
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
    };
  }

  DeckMatchup copyWith({
    String? id,
    String? deckId,
    String? opponentArchetype,
    Value<String?> notes = const Value.absent(),
    Value<String?> swapInItemIds = const Value.absent(),
    Value<String?> swapOutItemIds = const Value.absent(),
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
          ..write('swapOutItemIds: $swapOutItemIds')
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
          other.swapOutItemIds == this.swapOutItemIds);
}

class DeckMatchupsCompanion extends UpdateCompanion<DeckMatchup> {
  final Value<String> id;
  final Value<String> deckId;
  final Value<String> opponentArchetype;
  final Value<String?> notes;
  final Value<String?> swapInItemIds;
  final Value<String?> swapOutItemIds;
  final Value<int> rowid;
  const DeckMatchupsCompanion({
    this.id = const Value.absent(),
    this.deckId = const Value.absent(),
    this.opponentArchetype = const Value.absent(),
    this.notes = const Value.absent(),
    this.swapInItemIds = const Value.absent(),
    this.swapOutItemIds = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DeckMatchupsCompanion.insert({
    required String id,
    required String deckId,
    required String opponentArchetype,
    this.notes = const Value.absent(),
    this.swapInItemIds = const Value.absent(),
    this.swapOutItemIds = const Value.absent(),
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
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (deckId != null) 'deck_id': deckId,
      if (opponentArchetype != null) 'opponent_archetype': opponentArchetype,
      if (notes != null) 'notes': notes,
      if (swapInItemIds != null) 'swap_in_item_ids': swapInItemIds,
      if (swapOutItemIds != null) 'swap_out_item_ids': swapOutItemIds,
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
    Value<int>? rowid,
  }) {
    return DeckMatchupsCompanion(
      id: id ?? this.id,
      deckId: deckId ?? this.deckId,
      opponentArchetype: opponentArchetype ?? this.opponentArchetype,
      notes: notes ?? this.notes,
      swapInItemIds: swapInItemIds ?? this.swapInItemIds,
      swapOutItemIds: swapOutItemIds ?? this.swapOutItemIds,
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
  @override
  List<GeneratedColumn> get $columns => [id, deckId, synergyName, vaultItemIds];
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
  const DeckSynergy({
    required this.id,
    required this.deckId,
    required this.synergyName,
    required this.vaultItemIds,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['deck_id'] = Variable<String>(deckId);
    map['synergy_name'] = Variable<String>(synergyName);
    map['vault_item_ids'] = Variable<String>(vaultItemIds);
    return map;
  }

  DeckSynergiesCompanion toCompanion(bool nullToAbsent) {
    return DeckSynergiesCompanion(
      id: Value(id),
      deckId: Value(deckId),
      synergyName: Value(synergyName),
      vaultItemIds: Value(vaultItemIds),
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
    };
  }

  DeckSynergy copyWith({
    String? id,
    String? deckId,
    String? synergyName,
    String? vaultItemIds,
  }) => DeckSynergy(
    id: id ?? this.id,
    deckId: deckId ?? this.deckId,
    synergyName: synergyName ?? this.synergyName,
    vaultItemIds: vaultItemIds ?? this.vaultItemIds,
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
    );
  }

  @override
  String toString() {
    return (StringBuffer('DeckSynergy(')
          ..write('id: $id, ')
          ..write('deckId: $deckId, ')
          ..write('synergyName: $synergyName, ')
          ..write('vaultItemIds: $vaultItemIds')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, deckId, synergyName, vaultItemIds);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DeckSynergy &&
          other.id == this.id &&
          other.deckId == this.deckId &&
          other.synergyName == this.synergyName &&
          other.vaultItemIds == this.vaultItemIds);
}

class DeckSynergiesCompanion extends UpdateCompanion<DeckSynergy> {
  final Value<String> id;
  final Value<String> deckId;
  final Value<String> synergyName;
  final Value<String> vaultItemIds;
  final Value<int> rowid;
  const DeckSynergiesCompanion({
    this.id = const Value.absent(),
    this.deckId = const Value.absent(),
    this.synergyName = const Value.absent(),
    this.vaultItemIds = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DeckSynergiesCompanion.insert({
    required String id,
    required String deckId,
    required String synergyName,
    required String vaultItemIds,
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
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (deckId != null) 'deck_id': deckId,
      if (synergyName != null) 'synergy_name': synergyName,
      if (vaultItemIds != null) 'vault_item_ids': vaultItemIds,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DeckSynergiesCompanion copyWith({
    Value<String>? id,
    Value<String>? deckId,
    Value<String>? synergyName,
    Value<String>? vaultItemIds,
    Value<int>? rowid,
  }) {
    return DeckSynergiesCompanion(
      id: id ?? this.id,
      deckId: deckId ?? this.deckId,
      synergyName: synergyName ?? this.synergyName,
      vaultItemIds: vaultItemIds ?? this.vaultItemIds,
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
  ];
}

typedef $$VaultBindersTableCreateCompanionBuilder =
    VaultBindersCompanion Function({
      required String id,
      required String name,
      required String collectionType,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$VaultBindersTableUpdateCompanionBuilder =
    VaultBindersCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> collectionType,
      Value<DateTime> createdAt,
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
                Value<int> rowid = const Value.absent(),
              }) => VaultBindersCompanion(
                id: id,
                name: name,
                collectionType: collectionType,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String collectionType,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => VaultBindersCompanion.insert(
                id: id,
                name: name,
                collectionType: collectionType,
                createdAt: createdAt,
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
      Value<String?> primaryBinderId,
      required double currentMarketPrice,
      required DateTime lastPriceUpdate,
      required String dynamicData,
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
      Value<String?> primaryBinderId,
      Value<double> currentMarketPrice,
      Value<DateTime> lastPriceUpdate,
      Value<String> dynamicData,
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
                Value<String?> primaryBinderId = const Value.absent(),
                Value<double> currentMarketPrice = const Value.absent(),
                Value<DateTime> lastPriceUpdate = const Value.absent(),
                Value<String> dynamicData = const Value.absent(),
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
                primaryBinderId: primaryBinderId,
                currentMarketPrice: currentMarketPrice,
                lastPriceUpdate: lastPriceUpdate,
                dynamicData: dynamicData,
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
                Value<String?> primaryBinderId = const Value.absent(),
                required double currentMarketPrice,
                required DateTime lastPriceUpdate,
                required String dynamicData,
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
                primaryBinderId: primaryBinderId,
                currentMarketPrice: currentMarketPrice,
                lastPriceUpdate: lastPriceUpdate,
                dynamicData: dynamicData,
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
                Value<int> rowid = const Value.absent(),
              }) => DeckVersionsCompanion(
                id: id,
                deckId: deckId,
                versionNumber: versionNumber,
                versionNote: versionNote,
                isActive: isActive,
                createdAt: createdAt,
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
                Value<int> rowid = const Value.absent(),
              }) => DeckVersionsCompanion.insert(
                id: id,
                deckId: deckId,
                versionNumber: versionNumber,
                versionNote: versionNote,
                isActive: isActive,
                createdAt: createdAt,
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
                Value<int> rowid = const Value.absent(),
              }) => DeckVersionItemsCompanion(
                id: id,
                versionId: versionId,
                vaultItemId: vaultItemId,
                quantity: quantity,
                boardZone: boardZone,
                isProxy: isProxy,
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
                Value<int> rowid = const Value.absent(),
              }) => DeckVersionItemsCompanion.insert(
                id: id,
                versionId: versionId,
                vaultItemId: vaultItemId,
                quantity: quantity,
                boardZone: boardZone,
                isProxy: isProxy,
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
                Value<int> rowid = const Value.absent(),
              }) => DeckMatchupsCompanion(
                id: id,
                deckId: deckId,
                opponentArchetype: opponentArchetype,
                notes: notes,
                swapInItemIds: swapInItemIds,
                swapOutItemIds: swapOutItemIds,
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
                Value<int> rowid = const Value.absent(),
              }) => DeckMatchupsCompanion.insert(
                id: id,
                deckId: deckId,
                opponentArchetype: opponentArchetype,
                notes: notes,
                swapInItemIds: swapInItemIds,
                swapOutItemIds: swapOutItemIds,
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
      Value<int> rowid,
    });
typedef $$DeckSynergiesTableUpdateCompanionBuilder =
    DeckSynergiesCompanion Function({
      Value<String> id,
      Value<String> deckId,
      Value<String> synergyName,
      Value<String> vaultItemIds,
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
                Value<int> rowid = const Value.absent(),
              }) => DeckSynergiesCompanion(
                id: id,
                deckId: deckId,
                synergyName: synergyName,
                vaultItemIds: vaultItemIds,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String deckId,
                required String synergyName,
                required String vaultItemIds,
                Value<int> rowid = const Value.absent(),
              }) => DeckSynergiesCompanion.insert(
                id: id,
                deckId: deckId,
                synergyName: synergyName,
                vaultItemIds: vaultItemIds,
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
}
