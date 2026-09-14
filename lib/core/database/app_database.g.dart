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
    acquiredPrice,
    acquiredDate,
    quantity,
    condition,
    isGraded,
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
  final double acquiredPrice;
  final DateTime acquiredDate;
  final int quantity;
  final String condition;
  final bool isGraded;
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
    required this.acquiredPrice,
    required this.acquiredDate,
    required this.quantity,
    required this.condition,
    required this.isGraded,
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
    map['acquired_price'] = Variable<double>(acquiredPrice);
    map['acquired_date'] = Variable<DateTime>(acquiredDate);
    map['quantity'] = Variable<int>(quantity);
    map['condition'] = Variable<String>(condition);
    map['is_graded'] = Variable<bool>(isGraded);
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
      acquiredPrice: Value(acquiredPrice),
      acquiredDate: Value(acquiredDate),
      quantity: Value(quantity),
      condition: Value(condition),
      isGraded: Value(isGraded),
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
      acquiredPrice: serializer.fromJson<double>(json['acquiredPrice']),
      acquiredDate: serializer.fromJson<DateTime>(json['acquiredDate']),
      quantity: serializer.fromJson<int>(json['quantity']),
      condition: serializer.fromJson<String>(json['condition']),
      isGraded: serializer.fromJson<bool>(json['isGraded']),
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
      'acquiredPrice': serializer.toJson<double>(acquiredPrice),
      'acquiredDate': serializer.toJson<DateTime>(acquiredDate),
      'quantity': serializer.toJson<int>(quantity),
      'condition': serializer.toJson<String>(condition),
      'isGraded': serializer.toJson<bool>(isGraded),
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
    double? acquiredPrice,
    DateTime? acquiredDate,
    int? quantity,
    String? condition,
    bool? isGraded,
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
    acquiredPrice: acquiredPrice ?? this.acquiredPrice,
    acquiredDate: acquiredDate ?? this.acquiredDate,
    quantity: quantity ?? this.quantity,
    condition: condition ?? this.condition,
    isGraded: isGraded ?? this.isGraded,
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
      acquiredPrice: data.acquiredPrice.present
          ? data.acquiredPrice.value
          : this.acquiredPrice,
      acquiredDate: data.acquiredDate.present
          ? data.acquiredDate.value
          : this.acquiredDate,
      quantity: data.quantity.present ? data.quantity.value : this.quantity,
      condition: data.condition.present ? data.condition.value : this.condition,
      isGraded: data.isGraded.present ? data.isGraded.value : this.isGraded,
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
          ..write('acquiredPrice: $acquiredPrice, ')
          ..write('acquiredDate: $acquiredDate, ')
          ..write('quantity: $quantity, ')
          ..write('condition: $condition, ')
          ..write('isGraded: $isGraded, ')
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
    acquiredPrice,
    acquiredDate,
    quantity,
    condition,
    isGraded,
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
          other.acquiredPrice == this.acquiredPrice &&
          other.acquiredDate == this.acquiredDate &&
          other.quantity == this.quantity &&
          other.condition == this.condition &&
          other.isGraded == this.isGraded &&
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
  final Value<double> acquiredPrice;
  final Value<DateTime> acquiredDate;
  final Value<int> quantity;
  final Value<String> condition;
  final Value<bool> isGraded;
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
    this.acquiredPrice = const Value.absent(),
    this.acquiredDate = const Value.absent(),
    this.quantity = const Value.absent(),
    this.condition = const Value.absent(),
    this.isGraded = const Value.absent(),
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
    required double acquiredPrice,
    required DateTime acquiredDate,
    this.quantity = const Value.absent(),
    required String condition,
    this.isGraded = const Value.absent(),
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
    Expression<double>? acquiredPrice,
    Expression<DateTime>? acquiredDate,
    Expression<int>? quantity,
    Expression<String>? condition,
    Expression<bool>? isGraded,
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
      if (acquiredPrice != null) 'acquired_price': acquiredPrice,
      if (acquiredDate != null) 'acquired_date': acquiredDate,
      if (quantity != null) 'quantity': quantity,
      if (condition != null) 'condition': condition,
      if (isGraded != null) 'is_graded': isGraded,
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
    Value<double>? acquiredPrice,
    Value<DateTime>? acquiredDate,
    Value<int>? quantity,
    Value<String>? condition,
    Value<bool>? isGraded,
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
      acquiredPrice: acquiredPrice ?? this.acquiredPrice,
      acquiredDate: acquiredDate ?? this.acquiredDate,
      quantity: quantity ?? this.quantity,
      condition: condition ?? this.condition,
      isGraded: isGraded ?? this.isGraded,
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
          ..write('acquiredPrice: $acquiredPrice, ')
          ..write('acquiredDate: $acquiredDate, ')
          ..write('quantity: $quantity, ')
          ..write('condition: $condition, ')
          ..write('isGraded: $isGraded, ')
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

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $VaultBindersTable vaultBinders = $VaultBindersTable(this);
  late final $VaultItemsTable vaultItems = $VaultItemsTable(this);
  late final VaultDao vaultDao = VaultDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    vaultBinders,
    vaultItems,
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
      required double acquiredPrice,
      required DateTime acquiredDate,
      Value<int> quantity,
      required String condition,
      Value<bool> isGraded,
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
      Value<double> acquiredPrice,
      Value<DateTime> acquiredDate,
      Value<int> quantity,
      Value<String> condition,
      Value<bool> isGraded,
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
          PrefetchHooks Function({bool primaryBinderId})
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
                Value<double> acquiredPrice = const Value.absent(),
                Value<DateTime> acquiredDate = const Value.absent(),
                Value<int> quantity = const Value.absent(),
                Value<String> condition = const Value.absent(),
                Value<bool> isGraded = const Value.absent(),
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
                acquiredPrice: acquiredPrice,
                acquiredDate: acquiredDate,
                quantity: quantity,
                condition: condition,
                isGraded: isGraded,
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
                required double acquiredPrice,
                required DateTime acquiredDate,
                Value<int> quantity = const Value.absent(),
                required String condition,
                Value<bool> isGraded = const Value.absent(),
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
                acquiredPrice: acquiredPrice,
                acquiredDate: acquiredDate,
                quantity: quantity,
                condition: condition,
                isGraded: isGraded,
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
          prefetchHooksCallback: ({primaryBinderId = false}) {
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
                    if (primaryBinderId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.primaryBinderId,
                                referencedTable: $$VaultItemsTableReferences
                                    ._primaryBinderIdTable(db),
                                referencedColumn: $$VaultItemsTableReferences
                                    ._primaryBinderIdTable(db)
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
      PrefetchHooks Function({bool primaryBinderId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$VaultBindersTableTableManager get vaultBinders =>
      $$VaultBindersTableTableManager(_db, _db.vaultBinders);
  $$VaultItemsTableTableManager get vaultItems =>
      $$VaultItemsTableTableManager(_db, _db.vaultItems);
}
