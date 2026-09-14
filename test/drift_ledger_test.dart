import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/vault/presentation/widgets/polymorphic_attribute_chip.dart';
import 'package:countr/features/vault/presentation/widgets/vault_item_card.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    // In-memory database for fast, isolated tests
    db = AppDatabase(NativeDatabase.memory());
    await db.vaultDao.seedDatabase();
  });

  tearDown(() async {
    await db.close();
  });

  group('Phase 2: Drift Ledger & Polymorphic Architecture Tests', () {
    test('seedDatabase() inserts exactly 4 hyper-detailed mock records',
        () async {
      final items = await db.vaultDao.watchItemsByCollection('all').first;
      expect(items.length, 4);

      // Verify MTG record
      final mtg = items.firstWhere((i) => i.collectionType == 'mtg');
      expect(mtg.name, contains('The One Ring'));
      expect(mtg.acquiredPrice, 15.00);
      expect(mtg.currentMarketPrice, 45.50);
      expect(mtg.condition, 'NM');
      expect(mtg.isGraded, false);
      expect(mtg.dynamicData, contains('"mana": "2UB"'));

      // Verify Pokémon record
      final pokemon = items.firstWhere((i) => i.collectionType == 'pokemon');
      expect(pokemon.name, contains('Charizard ex'));
      expect(pokemon.acquiredPrice, 4.50);
      expect(pokemon.currentMarketPrice, 3.25);
      expect(pokemon.condition, 'LP');
      expect(pokemon.dynamicData, contains('"hp": 120'));

      // Verify Comic Book record
      final comic = items.firstWhere((i) => i.collectionType == 'comic');
      expect(comic.name, contains('Ultimate Fallout #4'));
      expect(comic.acquiredPrice, 150.00);
      expect(comic.currentMarketPrice, 210.00);
      expect(comic.isGraded, true);
      expect(comic.condition, 'CGC 9.8');
      expect(comic.dynamicData, contains('"issue": 1'));

      // Verify Sports Card record
      final sports = items.firstWhere((i) => i.collectionType == 'sports_card');
      expect(sports.name, contains('T.J. Watt'));
      expect(sports.acquiredPrice, 20.00);
      expect(sports.currentMarketPrice, 180.00);
      expect(sports.isGraded, true);
      expect(sports.condition, 'PSA 10');
      expect(sports.dynamicData, contains('"is_rookie": true'));
    });

    test('watchItemsByCollection filters dynamically by collection type',
        () async {
      // All collections
      final allItems =
          await db.vaultDao.watchItemsByCollection('All Collections').first;
      expect(allItems.length, 4);

      // Filter MTG
      final mtgItems =
          await db.vaultDao.watchItemsByCollection('Magic: The Gathering').first;
      expect(mtgItems.length, 1);
      expect(mtgItems.first.collectionType, 'mtg');

      // Filter Pokémon
      final pokeItems =
          await db.vaultDao.watchItemsByCollection('Pokémon TCG').first;
      expect(pokeItems.length, 1);
      expect(pokeItems.first.collectionType, 'pokemon');

      // Filter Comic Books
      final comicItems =
          await db.vaultDao.watchItemsByCollection('Comic Books').first;
      expect(comicItems.length, 1);
      expect(comicItems.first.collectionType, 'comic');

      // Filter Sports Cards
      final sportsItems =
          await db.vaultDao.watchItemsByCollection('Sports Cards').first;
      expect(sportsItems.length, 1);
      expect(sportsItems.first.collectionType, 'sports_card');
    });

    testWidgets(
        'PolymorphicAttributeChip correctly parses dynamic_data switch for all 4 types',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                PolymorphicAttributeChip(
                  collectionType: 'mtg',
                  dynamicDataJson:
                      '{"mana": "2UB", "type": "Creature", "power": 3, "toughness": 2}',
                ),
                PolymorphicAttributeChip(
                  collectionType: 'pokemon',
                  dynamicDataJson: '{"hp": 120, "stage": "Basic"}',
                ),
                PolymorphicAttributeChip(
                  collectionType: 'comic',
                  dynamicDataJson: '{"issue": 1, "publisher": "Marvel"}',
                ),
                PolymorphicAttributeChip(
                  collectionType: 'sports_card',
                  dynamicDataJson:
                      '{"sport": "Football", "team": "Steelers", "is_rookie": true}',
                ),
              ],
            ),
          ),
        ),
      );

      // MTG Polymorphic Chip
      expect(find.text('MTG STATS: '), findsOneWidget);
      expect(find.text('2UB • Creature • 3/2'), findsOneWidget);

      // Pokémon Polymorphic Chip
      expect(find.text('POKÉMON STATS: '), findsOneWidget);
      expect(find.text('HP 120 • Stage: Basic'), findsOneWidget);

      // Comic Book Polymorphic Chip
      expect(find.text('COMIC ISSUE: '), findsOneWidget);
      expect(find.text('Marvel #1'), findsOneWidget);

      // Sports Card Polymorphic Chip
      expect(find.text('★ ROOKIE CARD: '), findsOneWidget);
      expect(find.text('Football • Steelers'), findsOneWidget);
    });

    testWidgets(
        'VaultItemCard renders financial delta in green for profit and red for loss',
        (WidgetTester tester) async {
      final now = DateTime.now();
      final mtgItem = VaultItem(
        id: 'item-mtg-one-ring',
        collectionType: 'mtg',
        name: 'The One Ring (Serialized #007/100)',
        setOrSeries: 'The Lord of the Rings: Tales of Middle-earth',
        imageUrl: 'https://example.com/ring.jpg',
        acquiredPrice: 15.00,
        acquiredDate: now,
        quantity: 1,
        condition: 'NM',
        isGraded: false,
        currentMarketPrice: 45.50,
        lastPriceUpdate: now,
        dynamicData:
            '{"mana": "2UB", "type": "Creature", "power": 3, "toughness": 2}',
      );
      final pokeItem = VaultItem(
        id: 'item-pokemon-charizard',
        collectionType: 'pokemon',
        name: 'Charizard ex',
        setOrSeries: 'Scarlet & Violet: 151',
        imageUrl: 'https://example.com/charizard.jpg',
        acquiredPrice: 4.50,
        acquiredDate: now,
        quantity: 1,
        condition: 'LP',
        isGraded: false,
        currentMarketPrice: 3.25,
        lastPriceUpdate: now,
        dynamicData: '{"hp": 120, "stage": "Basic"}',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                VaultItemCard(item: mtgItem),
                VaultItemCard(item: pokeItem),
              ],
            ),
          ),
        ),
      );

      // MTG Profit: Acquired $15.00, TMV $45.50 -> +203.3% (+$30.50)
      expect(find.text('\$15.00'), findsOneWidget);
      expect(find.text('\$45.50'), findsOneWidget);
      expect(find.text('+203.3% (+\$30.50)'), findsOneWidget);

      // Pokémon Loss: Acquired $4.50, TMV $3.25 -> -27.8% (-$1.25)
      expect(find.text('\$4.50'), findsOneWidget);
      expect(find.text('\$3.25'), findsOneWidget);
      expect(find.text('-27.8% (-\$1.25)'), findsOneWidget);

      // Verify colors: Emerald green for profit, Rose red for loss
      final profitText = tester.widget<Text>(find.text('+203.3% (+\$30.50)'));
      expect(profitText.style?.color, AppColors.accentEmerald);

      final lossText = tester.widget<Text>(find.text('-27.8% (-\$1.25)'));
      expect(lossText.style?.color, AppColors.accentRose);
    });
  });
}
