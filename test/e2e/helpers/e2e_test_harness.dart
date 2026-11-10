import 'dart:convert';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/app_state.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';

/// Instantiates an isolated in-memory [AppDatabase] for E2E testing.
AppDatabase createE2ETestDatabase() {
  return AppDatabase(NativeDatabase.memory());
}

/// Factory to generate robust, complete test card entities for Milestone 1.
VaultItem createE2ETestCard({
  required String id,
  required String name,
  String collectionType = 'mtg',
  String setOrSeries = 'Dominaria',
  String setCode = 'dom',
  String collectorNumber = '1',
  String rarity = 'rare',
  double cmc = 1.0,
  String typeLine = 'Creature',
  List<String> colors = const [],
  List<String> colorIdentity = const [],
  String layout = 'normal',
  String? oracleText,
  String? manaCost,
  String? imageUrl,
  String? flavorName,
  double acquiredPrice = 5.0,
  double currentMarketPrice = 10.0,
  int quantity = 0,
  String condition = 'NM',
  String? primaryBinderId,
  bool isGraded = false,
  bool isAltered = false,
  bool isMisprint = false,
  bool isSigned = false,
  String? personalNotes,
  Map<String, dynamic>? extraDynamicData,
}) {
  final dynamicMap = <String, dynamic>{
    'set_code': setCode.toLowerCase(),
    'collector_number': collectorNumber,
    'rarity': rarity.toLowerCase(),
    'cmc': cmc,
    'mana_value': cmc,
    'type_line': typeLine,
    'type': typeLine,
    'colors': colors,
    'color_identity': colorIdentity,
    'layout': layout,
    'legalities': {
      'standard': 'legal',
      'modern': 'legal',
      'commander': 'legal',
      'legacy': 'legal',
      'vintage': 'legal',
    },
    'prices': {
      'usd': currentMarketPrice.toStringAsFixed(2),
      'usd_foil': (currentMarketPrice * 1.5).toStringAsFixed(2),
    },
    'image_uris': {
      'small': 'https://cards.scryfall.io/small/front/$id.jpg',
      'normal': imageUrl ?? 'https://cards.scryfall.io/normal/front/$id.jpg',
      'large': 'https://cards.scryfall.io/large/front/$id.jpg',
      'art_crop': 'https://cards.scryfall.io/art_crop/front/$id.jpg',
    },
    'oracle_text': ?oracleText,
    'mana_cost': ?manaCost,
    ...?extraDynamicData,
  };

  final defaultImage = imageUrl ?? 'https://cards.scryfall.io/normal/front/$id.jpg';

  return VaultItem(
    id: id,
    collectionType: collectionType,
    name: name,
    setOrSeries: setOrSeries,
    imageUrl: defaultImage,
    flavorName: flavorName,
    acquiredPrice: acquiredPrice,
    acquiredDate: DateTime.now().subtract(const Duration(days: 30)),
    quantity: quantity,
    condition: condition,
    isGraded: isGraded,
    isAltered: isAltered,
    isMisprint: isMisprint,
    isSigned: isSigned,
    personalNotes: personalNotes,
    currentMarketPrice: currentMarketPrice,
    lastPriceUpdate: DateTime.now(),
    dynamicData: jsonEncode(dynamicMap),
    primaryBinderId: primaryBinderId,
    isDeleted: false,
    updatedAt: DateTime.now(),
  );
}

/// Factory to generate binder entities.
VaultBinder createE2ETestBinder({
  required String id,
  required String name,
  String collectionType = 'mtg',
  DateTime? createdAt,
}) {
  return VaultBinder(
    id: id,
    name: name,
    collectionType: collectionType,
    createdAt: createdAt ?? DateTime.now(),
    isDeleted: false,
    updatedAt: DateTime.now(),
  );
}

/// Seeds a comprehensive, multi-attribute catalog fixture for Milestone 1.
Future<void> seedStandardM1Catalog(VaultDao dao) async {
  await dao.clearAllItems();

  final binders = [
    createE2ETestBinder(id: 'power-nine', name: 'Power Nine Vault'),
    createE2ETestBinder(id: 'edh-staples', name: 'Commander Staples'),
    createE2ETestBinder(id: 'trade-binder', name: 'Trade Block'),
  ];

  for (final b in binders) {
    await dao.into(dao.vaultBinders).insert(
          VaultBindersCompanion.insert(
            id: b.id,
            name: b.name,
            collectionType: b.collectionType,
            createdAt: b.createdAt,
            isDeleted: drift.Value(b.isDeleted),
            updatedAt: drift.Value(b.updatedAt),
          ),
        );
  }

  final cards = [
    // 1. Black Lotus (0 CMC Artifact, rare, catalog only: quantity = 0)
    createE2ETestCard(
      id: 'c-lotus',
      name: 'Black Lotus',
      setOrSeries: 'Vintage Masters',
      setCode: 'vma',
      collectorNumber: '232',
      rarity: 'rare',
      cmc: 0,
      typeLine: 'Artifact',
      oracleText: '{T}, Sacrifice Black Lotus: Add three mana of any one color.',
      manaCost: '{0}',
      currentMarketPrice: 5000.0,
      quantity: 0,
    ),

    // 2. Mox Sapphire (0 CMC Artifact, rare, owned in Power Nine binder)
    createE2ETestCard(
      id: 'c-mox-sapphire',
      name: 'Mox Sapphire',
      setOrSeries: 'Vintage Masters',
      setCode: 'vma',
      collectorNumber: '233',
      rarity: 'rare',
      cmc: 0,
      typeLine: 'Artifact',
      oracleText: '{T}: Add {U}.',
      manaCost: '{0}',
      currentMarketPrice: 3000.0,
      quantity: 1,
      primaryBinderId: 'power-nine',
    ),

    // 3. Sol Ring (1 CMC Artifact, uncommon, owned in Commander Staples)
    createE2ETestCard(
      id: 'c-sol-ring',
      name: 'Sol Ring',
      setOrSeries: 'Commander',
      setCode: 'cmd',
      collectorNumber: '101',
      rarity: 'uncommon',
      cmc: 1,
      typeLine: 'Artifact',
      oracleText: '{T}: Add {C}{C}.',
      manaCost: '{1}',
      currentMarketPrice: 2.0,
      quantity: 2,
      primaryBinderId: 'edh-staples',
    ),

    // 4. Lightning Bolt (1 CMC Red Instant, common, 4 copies in Vault)
    createE2ETestCard(
      id: 'c-bolt',
      name: 'Lightning Bolt',
      setOrSeries: 'Magic 2010',
      setCode: 'm10',
      collectorNumber: '146',
      rarity: 'common',
      cmc: 1,
      typeLine: 'Instant',
      colors: ['R'],
      colorIdentity: ['R'],
      oracleText: 'Lightning Bolt deals 3 damage to any target.',
      manaCost: '{R}',
      currentMarketPrice: 1.5,
      quantity: 4,
    ),

    // 5. Counterspell (2 CMC Blue Instant, uncommon, unowned catalog)
    createE2ETestCard(
      id: 'c-counterspell',
      name: 'Counterspell',
      setOrSeries: 'Eternal Masters',
      setCode: 'ema',
      collectorNumber: '43',
      rarity: 'uncommon',
      cmc: 2,
      typeLine: 'Instant',
      colors: ['U'],
      colorIdentity: ['U'],
      oracleText: 'Counter target spell.',
      manaCost: '{U}{U}',
      currentMarketPrice: 2.5,
      quantity: 0,
    ),

    // 6. Birds of Paradise (1 CMC Green Creature, rare, owned)
    createE2ETestCard(
      id: 'c-bop',
      name: 'Birds of Paradise',
      setOrSeries: 'Magic 2012',
      setCode: 'm12',
      collectorNumber: '165',
      rarity: 'rare',
      cmc: 1,
      typeLine: 'Creature — Bird',
      colors: ['G'],
      colorIdentity: ['G'],
      oracleText: 'Flying\n{T}: Add one mana of any color.',
      manaCost: '{G}',
      currentMarketPrice: 8.0,
      quantity: 1,
    ),

    // 7. Wrath of God (4 CMC White Sorcery, rare, unowned catalog)
    createE2ETestCard(
      id: 'c-wrath',
      name: 'Wrath of God',
      setOrSeries: 'Tenth Edition',
      setCode: '10e',
      collectorNumber: '61',
      rarity: 'rare',
      cmc: 4,
      typeLine: 'Sorcery',
      colors: ['W'],
      colorIdentity: ['W'],
      oracleText: "Destroy all creatures. They can't be regenerated.",
      manaCost: '{2}{W}{W}',
      currentMarketPrice: 4.0,
      quantity: 0,
    ),

    // 8. Demonic Tutor (2 CMC Black Sorcery, uncommon, owned in Trade Block)
    createE2ETestCard(
      id: 'c-demonic-tutor',
      name: 'Demonic Tutor',
      setOrSeries: 'Duel Decks: Anthology',
      setCode: 'dvd',
      collectorNumber: '49',
      rarity: 'uncommon',
      cmc: 2,
      typeLine: 'Sorcery',
      colors: ['B'],
      colorIdentity: ['B'],
      oracleText: 'Search your library for a card, put that card into your hand, then shuffle.',
      manaCost: '{1}{B}',
      currentMarketPrice: 40.0,
      quantity: 1,
      primaryBinderId: 'trade-binder',
    ),

    // 9. Nicol Bolas, the Ravager (Transform DFC, mythic, unowned catalog)
    createE2ETestCard(
      id: 'c-nicol-bolas',
      name: 'Nicol Bolas, the Ravager // Nicol Bolas, the Arisen',
      setOrSeries: 'Core Set 2019',
      setCode: 'm19',
      collectorNumber: '218',
      rarity: 'mythic',
      cmc: 4,
      typeLine: 'Legendary Creature — Elder Dragon // Legendary Planeswalker',
      colors: ['U', 'B', 'R'],
      colorIdentity: ['U', 'B', 'R'],
      layout: 'transform',
      oracleText: 'Flying\nWhen Nicol Bolas, the Ravager enters the battlefield...',
      manaCost: '{1}{U}{B}{R}',
      currentMarketPrice: 28.0,
      quantity: 0,
      extraDynamicData: {
        'card_faces': [
          {
            'name': 'Nicol Bolas, the Ravager',
            'type_line': 'Legendary Creature — Elder Dragon',
            'mana_cost': '{1}{U}{B}{R}',
            'oracle_text': 'Flying\nWhen Nicol Bolas, the Ravager enters the battlefield...',
            'image_uris': {
              'normal': 'https://cards.scryfall.io/normal/front/nicol-front.jpg',
            },
          },
          {
            'name': 'Nicol Bolas, the Arisen',
            'type_line': 'Legendary Planeswalker — Bolas',
            'mana_cost': '',
            'oracle_text': '+2: Draw two cards.\n-3: Deal 10 damage...',
            'image_uris': {
              'normal': 'https://cards.scryfall.io/normal/front/nicol-back.jpg',
            },
          },
        ],
      },
    ),

    // 10. The Ozolith (with flavor_name: "Adamantium Bonding Tank")
    createE2ETestCard(
      id: 'c-ozolith',
      name: 'The Ozolith',
      flavorName: 'Adamantium Bonding Tank',
      setOrSeries: 'Ikoria: Lair of Behemoths',
      setCode: 'iko',
      collectorNumber: '237',
      rarity: 'rare',
      cmc: 1,
      typeLine: 'Legendary Artifact',
      oracleText: 'Whenever a creature you control leaves the battlefield...',
      manaCost: '{1}',
      currentMarketPrice: 12.0,
      quantity: 1,
    ),

    // 11. Pokémon card: Pikachu (Base Set, quantity = 0)
    createE2ETestCard(
      id: 'pkm-pikachu',
      name: 'Pikachu',
      collectionType: 'pokemon',
      setOrSeries: 'Base Set',
      setCode: 'base',
      collectorNumber: '58',
      rarity: 'common',
      typeLine: 'Basic Pokémon',
      currentMarketPrice: 15.0,
      quantity: 0,
    ),
  ];

  for (final c in cards) {
    await dao.into(dao.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: c.id,
            collectionType: c.collectionType,
            name: c.name,
            setOrSeries: c.setOrSeries,
            imageUrl: c.imageUrl,
            flavorName: drift.Value(c.flavorName),
            acquiredPrice: c.acquiredPrice,
            acquiredDate: c.acquiredDate,
            quantity: drift.Value(c.quantity),
            condition: c.condition,
            isGraded: drift.Value(c.isGraded),
            isAltered: drift.Value(c.isAltered),
            isMisprint: drift.Value(c.isMisprint),
            isSigned: drift.Value(c.isSigned),
            personalNotes: drift.Value(c.personalNotes),
            currentMarketPrice: c.currentMarketPrice,
            lastPriceUpdate: c.lastPriceUpdate,
            dynamicData: c.dynamicData,
            primaryBinderId: drift.Value(c.primaryBinderId),
            isDeleted: drift.Value(c.isDeleted),
            updatedAt: drift.Value(c.updatedAt),
          ),
        );
  }
}

/// Helper method to insert a list of test cards into the database.
Future<void> insertTestCards(VaultDao dao, List<VaultItem> cards) async {
  for (final c in cards) {
    await dao.into(dao.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: c.id,
            collectionType: c.collectionType,
            name: c.name,
            setOrSeries: c.setOrSeries,
            imageUrl: c.imageUrl,
            flavorName: drift.Value(c.flavorName),
            acquiredPrice: c.acquiredPrice,
            acquiredDate: c.acquiredDate,
            quantity: drift.Value(c.quantity),
            condition: c.condition,
            isGraded: drift.Value(c.isGraded),
            isAltered: drift.Value(c.isAltered),
            isMisprint: drift.Value(c.isMisprint),
            isSigned: drift.Value(c.isSigned),
            personalNotes: drift.Value(c.personalNotes),
            currentMarketPrice: c.currentMarketPrice,
            lastPriceUpdate: c.lastPriceUpdate,
            dynamicData: c.dynamicData,
            primaryBinderId: drift.Value(c.primaryBinderId),
            isDeleted: drift.Value(c.isDeleted),
            updatedAt: drift.Value(c.updatedAt),
          ),
        );
  }
}

/// Helper method to safely clean and recreate tables if necessary in memory.
Future<void> resetTestDatabase(AppDatabase db) async {
  await db.vaultDao.clearAllItems();
  await db.delete(db.vaultBinders).go();
}

/// Standard test widget wrapper with ProviderScope, Drift DB, and theme.
Widget buildE2ETestWidget({
  required Widget child,
  required AppDatabase db,
  String activeGame = 'Magic: The Gathering',
  List<Override> overrides = const [],
}) {
  return ProviderScope(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      vaultDaoProvider.overrideWithValue(db.vaultDao),
      activeGameContextProvider.overrideWith((ref) => activeGame),
      ...overrides,
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.accentCyan,
          secondary: AppColors.accentAmber,
          surface: AppColors.surface,
        ),
      ),
      home: child,
    ),
  );
}
