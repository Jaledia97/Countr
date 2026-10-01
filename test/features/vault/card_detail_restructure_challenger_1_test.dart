import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/symbology/presentation/widgets/mana_cost_bar.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/widgets/card_detail_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  VaultItem createTestCard({
    String id = 'challenger-card-1',
    String name = 'Atraxa, Praetors\' Voice',
    String setCode = '2XM',
    String setName = 'Double Masters',
    String collectorNumber = '028',
    double acquiredPrice = 15.00,
    double marketPrice = 24.50,
    int quantity = 0, // default unowned so Add to Vault button is present
    String? typeLine = 'Legendary Creature — Phyrexian Angel Horror',
    String? manaCost = '{G}{W}{U}{B}',
    String? power = '4',
    String? toughness = '4',
    String? loyalty,
    String? flavorName,
    String? dynamicData,
  }) {
    return VaultItem(
      id: id,
      collectionType: 'mtg',
      name: name,
      flavorName: flavorName,
      setOrSeries: setName,
      imageUrl: 'https://cards.scryfall.io/normal/front/atraxa.jpg',
      acquiredPrice: acquiredPrice,
      acquiredDate: DateTime(2023, 1, 1),
      quantity: quantity,
      condition: 'NM',
      isGraded: false,
      isAltered: false,
      isMisprint: false,
      isSigned: false,
      isDeleted: false,
      currentMarketPrice: marketPrice,
      lastPriceUpdate: DateTime(2023, 1, 1),
      personalNotes: 'Empirical challenge test card.',
      dynamicData: dynamicData ??
          jsonEncode({
            'collector_number': collectorNumber,
            'set': setCode.toLowerCase(),
            'set_name': setName,
            'mana_cost': manaCost,
            'type_line': typeLine,
            'power': power,
            'toughness': toughness,
            'loyalty': loyalty,
            'rarity': 'mythic',
            'oracle_text': 'Flying, vigilance, deathtouch, lifelink\nAt the beginning of your end step, proliferate.',
            'flavor_text': 'A terrifying triumph of Phyrexian design.',
          }),
    );
  }

  Widget createHarness(
    Widget child, {
    Size viewportSize = const Size(320, 568),
    TextScaler textScaler = TextScaler.noScaling,
  }) {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        vaultDaoProvider.overrideWithValue(db.vaultDao),
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: viewportSize,
            textScaler: textScaler,
          ),
          child: Scaffold(
            body: child,
          ),
        ),
      ),
    );
  }

  group('CHALLENGER 1 EMPIRICAL SUITE: Milestone 4 (R4)', () {
    testWidgets('1. Empirical Visual Ordering: Card Name Y <= Mana Cost Y <= Set Info Y <= Price Y < Toggle Y < AddToVault Y', (tester) async {
      final item = createTestCard(
        name: 'Urza, Lord High Artificer',
        manaCost: '{2}{U}{U}',
        setCode: 'MH1',
        setName: 'Modern Horizons',
        marketPrice: 38.50,
        quantity: 0, // unowned to show Add to Vault button
      );

      await tester.pumpWidget(createHarness(
        CardDetailSheet(item: item, fetchOnlinePrintings: false),
        viewportSize: const Size(390, 844),
      ));
      await tester.pumpAndSettle();

      // Find individual components
      final nameFinder = find.byWidgetPredicate(
        (w) => w is Text && w.data == 'Urza, Lord High Artificer' && w.style?.fontSize == 18,
      );
      final manaFinder = find.byType(ManaCostBar);
      final setFinder = find.text('MH1');
      final priceFinder = find.text('Market: \$38.50');
      final toggleFinder = find.byKey(const Key('card_detail_segmented_control'));
      final addToVaultFinder = find.byKey(const Key('card_detail_add_to_vault'));

      expect(nameFinder, findsOneWidget);
      expect(manaFinder, findsOneWidget);
      expect(setFinder, findsOneWidget);
      expect(priceFinder, findsOneWidget);
      expect(toggleFinder, findsOneWidget);
      expect(addToVaultFinder, findsOneWidget);

      final nameY = tester.getTopLeft(nameFinder).dy;
      final manaY = tester.getTopLeft(manaFinder).dy;
      final setY = tester.getTopLeft(setFinder).dy;
      final priceY = tester.getTopLeft(priceFinder).dy;
      final toggleY = tester.getTopLeft(toggleFinder).dy;
      final addToVaultY = tester.getTopLeft(addToVaultFinder).dy;

      // Strict requirement verification:
      // Card Name Y <= Mana Cost Y <= Set Info Y <= Price Y < Toggle Y < AddToVault Y
      expect(nameY, lessThanOrEqualTo(manaY), reason: 'Card Name Y <= Mana Cost Y');
      expect(manaY, lessThanOrEqualTo(setY), reason: 'Mana Cost Y <= Set Info Y');
      expect(setY, lessThanOrEqualTo(priceY), reason: 'Set Info Y <= Price Y');
      expect(priceY, lessThan(toggleY), reason: 'Price Y < Toggle Y');
      expect(toggleY, lessThan(addToVaultY), reason: 'Toggle Y < AddToVault Y');

      expect(tester.takeException(), isNull);
    });

    testWidgets('2. Empirical Visual Ordering with colorless card (no mana cost): Card Name Y <= Set Info Y <= Price Y < Toggle Y < AddToVault Y', (tester) async {
      final item = createTestCard(
        name: 'Mox Diamond',
        manaCost: '', // No mana cost
        setCode: 'ST',
        setName: 'Stronghold',
        marketPrice: 650.00,
        quantity: 0,
      );

      await tester.pumpWidget(createHarness(
        CardDetailSheet(item: item, fetchOnlinePrintings: false),
        viewportSize: const Size(390, 844),
      ));
      await tester.pumpAndSettle();

      final nameFinder = find.byWidgetPredicate(
        (w) => w is Text && w.data == 'Mox Diamond' && w.style?.fontSize == 18,
      );
      final setFinder = find.text('ST');
      final priceFinder = find.text('Market: \$650.00');
      final toggleFinder = find.byKey(const Key('card_detail_segmented_control'));
      final addToVaultFinder = find.byKey(const Key('card_detail_add_to_vault'));

      expect(nameFinder, findsOneWidget);
      expect(find.byType(ManaCostBar), findsNothing);
      expect(setFinder, findsOneWidget);
      expect(priceFinder, findsOneWidget);
      expect(toggleFinder, findsOneWidget);
      expect(addToVaultFinder, findsOneWidget);

      final nameY = tester.getTopLeft(nameFinder).dy;
      final setY = tester.getTopLeft(setFinder).dy;
      final priceY = tester.getTopLeft(priceFinder).dy;
      final toggleY = tester.getTopLeft(toggleFinder).dy;
      final addToVaultY = tester.getTopLeft(addToVaultFinder).dy;

      expect(nameY, lessThanOrEqualTo(setY), reason: 'Card Name Y <= Set Info Y');
      expect(setY, lessThanOrEqualTo(priceY), reason: 'Set Info Y <= Price Y');
      expect(priceY, lessThan(toggleY), reason: 'Price Y < Toggle Y');
      expect(toggleY, lessThan(addToVaultY), reason: 'Toggle Y < AddToVault Y');

      expect(tester.takeException(), isNull);
    });

    testWidgets('3. Compact Viewport (320x568) with 1.5x Text Scaling: Zero RenderFlex overflows and strict hierarchy', (tester) async {
      final item = createTestCard(
        name: 'Omnath, Locus of Creation',
        manaCost: '{R}{G}{W}{U}',
        setCode: 'ZNR',
        setName: 'Zendikar Rising',
        marketPrice: 12.99,
        quantity: 0,
      );

      await tester.pumpWidget(createHarness(
        CardDetailSheet(item: item, fetchOnlinePrintings: false),
        viewportSize: const Size(320, 568),
        textScaler: const TextScaler.linear(1.5),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'Zero RenderFlex overflows expected at 1.5x text scale on 320x568');

      // Verify hierarchy holds at 1.5x
      final nameFinder = find.byWidgetPredicate(
        (w) => w is Text && w.data == 'Omnath, Locus of Creation' && w.style?.fontSize == 18,
      );
      final manaFinder = find.byType(ManaCostBar);
      final setFinder = find.text('ZNR');
      final toggleFinder = find.byKey(const Key('card_detail_segmented_control'));
      final addToVaultFinder = find.byKey(const Key('card_detail_add_to_vault'));

      expect(nameFinder, findsOneWidget);
      expect(manaFinder, findsOneWidget);
      expect(setFinder, findsOneWidget);
      expect(toggleFinder, findsOneWidget);
      expect(addToVaultFinder, findsOneWidget);

      final nameY = tester.getTopLeft(nameFinder).dy;
      final manaY = tester.getTopLeft(manaFinder).dy;
      final setY = tester.getTopLeft(setFinder).dy;
      final toggleY = tester.getTopLeft(toggleFinder).dy;
      final addToVaultY = tester.getTopLeft(addToVaultFinder).dy;

      expect(nameY, lessThanOrEqualTo(manaY));
      expect(manaY, lessThanOrEqualTo(setY));
      expect(setY, lessThan(toggleY));
      expect(toggleY, lessThan(addToVaultY));
    });

    testWidgets('4. Compact Viewport (320x568) with 2.0x Text Scaling: Zero RenderFlex overflows, stress test long titles', (tester) async {
      final item = createTestCard(
        name: 'The Lord of the Rings: Tales of Middle-earth — Nazgûl #0332 Ultra Extended Special Art',
        manaCost: '{2}{B}',
        setCode: 'LTR',
        setName: 'The Lord of the Rings: Tales of Middle-earth Commander Expansion Set',
        marketPrice: 199.99,
        quantity: 0,
      );

      await tester.pumpWidget(createHarness(
        CardDetailSheet(item: item, fetchOnlinePrintings: false),
        viewportSize: const Size(320, 568),
        textScaler: const TextScaler.linear(2.0),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'Zero RenderFlex overflows expected at 2.0x text scale on 320x568 with long title');

      final toggleFinder = find.byKey(const Key('card_detail_segmented_control'));
      final addToVaultFinder = find.byKey(const Key('card_detail_add_to_vault'));
      expect(toggleFinder, findsOneWidget);
      expect(addToVaultFinder, findsOneWidget);

      final toggleY = tester.getTopLeft(toggleFinder).dy;
      final addToVaultY = tester.getTopLeft(addToVaultFinder).dy;
      expect(toggleY, lessThan(addToVaultY));

      // Test tab switching at 2.0x scale
      await tester.tap(find.byKey(const Key('card_detail_tab_values')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const Key('card_detail_tab_details')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('5. Ultra Compact Viewport (320x220) with 2.0x Text Scaling: triggers isUltraCompact, 0 overflows', (tester) async {
      final item = createTestCard(
        name: 'Sol Ring',
        manaCost: '{1}',
        setCode: 'C21',
        setName: 'Commander 2021',
        marketPrice: 1.50,
        quantity: 0,
      );

      await tester.pumpWidget(createHarness(
        CardDetailSheet(item: item, fetchOnlinePrintings: false),
        viewportSize: const Size(320, 220),
        textScaler: const TextScaler.linear(2.0),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'Zero RenderFlex overflows on ultra compact viewport (320x220) at 2.0x text scale');
      expect(find.byKey(const Key('card_detail_segmented_control')), findsOneWidget);
      expect(find.byKey(const Key('card_detail_add_to_vault')), findsOneWidget);
    });
  });
}
