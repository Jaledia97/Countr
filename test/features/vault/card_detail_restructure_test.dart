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
    String id = 'test-card-1',
    String name = 'Atraxa, Praetors\' Voice',
    String setCode = '2XM',
    String setName = 'Double Masters',
    String collectorNumber = '028',
    double acquiredPrice = 15.00,
    double marketPrice = 24.50,
    int quantity = 1,
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
      personalNotes: 'Commander commander staple.',
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

  Widget createTestWidget(
    Widget child, {
    Size viewportSize = const Size(390, 844),
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

  group('Milestone 4 (R4): Card Details Page Restructuring Tests', () {
    testWidgets('1. Top Hero Section renders artwork on left and basic info hierarchy on right in strict order', (tester) async {
      final item = createTestCard(
        name: 'Atraxa, Praetors\' Voice',
        manaCost: '{G}{W}{U}{B}',
        setCode: '2xm',
        setName: 'Double Masters',
        marketPrice: 24.50,
        typeLine: 'Legendary Creature — Phyrexian Angel Horror',
        power: '4',
        toughness: '4',
      );

      await tester.pumpWidget(createTestWidget(
        CardDetailSheet(item: item, fetchOnlinePrintings: false),
      ));
      await tester.pumpAndSettle();

      // Find Artwork Hero
      final artFinder = find.byKey(Key('card_artwork_${item.id}'));
      expect(artFinder, findsOneWidget);

      // Find Card Name in hero
      final nameFinder = find.byWidgetPredicate(
        (w) => w is Text && w.data == 'Atraxa, Praetors\' Voice' && w.style?.fontSize == 18,
      );
      expect(nameFinder, findsOneWidget);

      // Verify Card Name styling: heading1 with fontSize 18, w800, maxLines 2, ellipsis
      final nameWidget = tester.widget<Text>(nameFinder);
      expect(nameWidget.style?.fontSize, equals(18));
      expect(nameWidget.style?.fontWeight, equals(FontWeight.w800));
      expect(nameWidget.maxLines, equals(2));
      expect(nameWidget.overflow, equals(TextOverflow.ellipsis));

      // Find Mana Cost Bar in hero
      final manaFinder = find.byType(ManaCostBar);
      expect(manaFinder, findsOneWidget);
      final manaWidget = tester.widget<ManaCostBar>(manaFinder);
      expect(manaWidget.manaCost, equals('{G}{W}{U}{B}'));
      expect(manaWidget.symbolSize, equals(14.0));

      // Find Set Symbol & Set Name
      final setCodeFinder = find.text('2XM');
      final setNameFinder = find.text('Double Masters');
      expect(setCodeFinder, findsOneWidget);
      expect(setNameFinder, findsOneWidget);

      // Find Market Price label
      final priceFinder = find.text('Market: \$24.50');
      expect(priceFinder, findsOneWidget);

      // Find Type Line in hero
      final typeLineFinder = find.text('Legendary Creature — Phyrexian Angel Horror');
      expect(typeLineFinder, findsOneWidget);

      // Find Power/Toughness
      final ptFinder = find.text('P/T: 4 / 4');
      expect(ptFinder, findsOneWidget);

      // Verify horizontal arrangement: Artwork is to the left of basic info
      final artLeft = tester.getTopLeft(artFinder).dx;
      final nameLeft = tester.getTopLeft(nameFinder).dx;
      expect(artLeft, lessThan(nameLeft));

      // Verify strict vertical info hierarchy on the right side:
      // a. Card Name -> b. Mana Cost -> c. Set -> d. Price -> e. Type Line -> f. P/T
      final nameY = tester.getTopLeft(nameFinder).dy;
      final manaY = tester.getTopLeft(manaFinder).dy;
      final setY = tester.getTopLeft(setCodeFinder).dy;
      final priceY = tester.getTopLeft(priceFinder).dy;
      final typeLineY = tester.getTopLeft(typeLineFinder).dy;
      final ptY = tester.getTopLeft(ptFinder).dy;

      expect(nameY, lessThan(manaY), reason: 'Name must be above Mana Cost');
      expect(manaY, lessThan(setY), reason: 'Mana Cost must be above Set info');
      expect(setY, lessThan(priceY), reason: 'Set info must be above Price');
      expect(priceY, lessThan(typeLineY), reason: 'Price must be above Type Line');
      expect(typeLineY, lessThan(ptY), reason: 'Type Line must be above P/T');
    });

    testWidgets('2. Sheet Header Bar contains NO duplicate Card Name, only drag handle and close button', (tester) async {
      final item = createTestCard(name: 'Single Face Card');

      await tester.pumpWidget(createTestWidget(
        CardDetailSheet(item: item, fetchOnlinePrintings: false),
      ));
      await tester.pumpAndSettle();

      // Find the Sheet Header Bar Row (which contains the close button)
      final closeButtonFinder = find.byTooltip('Close');
      expect(closeButtonFinder, findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);

      final headerRowFinder = find.ancestor(
        of: closeButtonFinder,
        matching: find.byType(Row),
      );
      expect(headerRowFinder, findsOneWidget);

      // Verify that the Sheet Header Bar does NOT contain the card name
      expect(
        find.descendant(
          of: headerRowFinder,
          matching: find.text('Single Face Card'),
        ),
        findsNothing,
        reason: 'Sheet Header Bar must not contain duplicate Card Name',
      );

      // Verify Card Name heading is present in Hero Section (fontSize 18)
      final heroNameFinder = find.byWidgetPredicate(
        (w) => w is Text && w.data == 'Single Face Card' && w.style?.fontSize == 18,
      );
      expect(heroNameFinder, findsOneWidget);

      // Tap close button and verify it pops
      await tester.tap(closeButtonFinder);
      await tester.pumpAndSettle();
      expect(find.byType(CardDetailSheet), findsNothing);
    });

    testWidgets('3. Segmented Tab Control is positioned below Hero Section and above unowned Add to Vault button', (tester) async {
      final item = createTestCard(
        name: 'Catalog Unowned Card',
        quantity: 0, // Unowned card
      );

      await tester.pumpWidget(createTestWidget(
        CardDetailSheet(item: item, fetchOnlinePrintings: false),
      ));
      await tester.pumpAndSettle();

      final heroArtFinder = find.byKey(Key('card_artwork_${item.id}'));
      final segmentFinder = find.byKey(const Key('card_detail_segmented_control'));
      final addToVaultFinder = find.byKey(const Key('card_detail_add_to_vault'));
      final oracleRulesFinder = find.byKey(const Key('section_oracle_rules'));

      expect(heroArtFinder, findsOneWidget);
      expect(segmentFinder, findsOneWidget);
      expect(addToVaultFinder, findsOneWidget);
      expect(oracleRulesFinder, findsOneWidget);

      // Verify vertical layout sequence:
      // Hero Bottom <= Segmented Control Top < Add to Vault Top < Oracle Rules Section Top
      final heroBottom = tester.getBottomLeft(heroArtFinder).dy;
      final segmentTop = tester.getTopLeft(segmentFinder).dy;
      final segmentBottom = tester.getBottomLeft(segmentFinder).dy;
      final addTop = tester.getTopLeft(addToVaultFinder).dy;
      final addBottom = tester.getBottomLeft(addToVaultFinder).dy;
      final rulesTop = tester.getTopLeft(oracleRulesFinder).dy;

      expect(heroBottom, lessThanOrEqualTo(segmentTop), reason: 'Segmented control must be below Hero');
      expect(segmentBottom, lessThanOrEqualTo(addTop), reason: 'Add to Vault must be below Segmented control');
      expect(addBottom, lessThanOrEqualTo(rulesTop), reason: 'Tab content must be below Add to Vault');
    });

    testWidgets('4. Unowned catalog card (quantity == 0) renders exact "Add to Vault" button and adds to inbox', (tester) async {
      final item = createTestCard(
        id: 'unowned-item-99',
        name: 'Urza, Lord High Artificer',
        quantity: 0,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            vaultDaoProvider.overrideWithValue(db.vaultDao),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (ctx) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => CardDetailSheet.show(ctx, item),
                    child: const Text('Open Sheet'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      // Verify button key and text
      final addButtonFinder = find.byKey(const Key('card_detail_add_to_vault'));
      expect(addButtonFinder, findsOneWidget);
      expect(find.text('Add to Vault'), findsOneWidget);
      // Ensure old 'Add to Vault / Inbox' text is NOT present
      expect(find.text('Add to Vault / Inbox'), findsNothing);

      // Tap Add to Vault and verify action
      await tester.tap(addButtonFinder);
      await tester.pumpAndSettle();

      // Sheet should be popped and snackbar shown
      expect(find.byType(CardDetailSheet), findsNothing);
      expect(find.text('Added "Urza, Lord High Artificer" to Inbox'), findsOneWidget);

      // Verify in database that item was added with quantity 1
      final inboxItem = await db.vaultDao.getItemById('unowned-item-99');
      expect(inboxItem, isNotNull);
      expect(inboxItem!.quantity, equals(1));
    });

    testWidgets('5. Owned card (quantity > 0) does NOT render "Add to Vault" button below segmented control', (tester) async {
      final item = createTestCard(
        name: 'Black Lotus',
        quantity: 1, // Owned card
      );

      await tester.pumpWidget(createTestWidget(
        CardDetailSheet(item: item, fetchOnlinePrintings: false),
      ));
      await tester.pumpAndSettle();

      // Verify Add to Vault button is absent
      expect(find.byKey(const Key('card_detail_add_to_vault')), findsNothing);
      expect(find.text('Add to Vault'), findsNothing);
      expect(find.text('Add to Vault / Inbox'), findsNothing);

      // Segmented control and tab content are directly adjacent
      final segmentFinder = find.byKey(const Key('card_detail_segmented_control'));
      final rulesFinder = find.byKey(const Key('section_oracle_rules'));
      expect(segmentFinder, findsOneWidget);
      expect(rulesFinder, findsOneWidget);
      expect(
        tester.getBottomLeft(segmentFinder).dy,
        lessThanOrEqualTo(tester.getTopLeft(rulesFinder).dy),
      );
    });

    testWidgets('6. Tab switching keeps Top Hero Section visible and intact', (tester) async {
      final item = createTestCard(
        name: 'Ragavan, Nimble Pilferer',
        manaCost: '{R}',
        marketPrice: 42.00,
      );

      await tester.pumpWidget(createTestWidget(
        CardDetailSheet(item: item, fetchOnlinePrintings: false),
      ));
      await tester.pumpAndSettle();

      final heroNameFinder = find.byWidgetPredicate(
        (w) => w is Text && w.data == 'Ragavan, Nimble Pilferer' && w.style?.fontSize == 18,
      );

      // Initial state: Details tab active
      expect(find.byKey(const Key('section_oracle_rules')), findsOneWidget);
      expect(heroNameFinder, findsOneWidget);
      expect(find.byKey(Key('card_artwork_${item.id}')), findsOneWidget);

      // Switch to Values tab
      await tester.tap(find.byKey(const Key('card_detail_tab_values')));
      await tester.pumpAndSettle();

      // Hero section remains completely intact and visible
      expect(heroNameFinder, findsOneWidget);
      expect(find.byKey(Key('card_artwork_${item.id}')), findsOneWidget);
      expect(find.text('\$42.00'), findsOneWidget);

      // Details tab content is no longer shown
      expect(find.byKey(const Key('section_oracle_rules')), findsNothing);

      // Switch back to Details tab
      await tester.tap(find.byKey(const Key('card_detail_tab_details')));
      await tester.pumpAndSettle();

      // Details content reappears
      expect(find.byKey(const Key('section_oracle_rules')), findsOneWidget);
      expect(heroNameFinder, findsOneWidget);
    });

    testWidgets('7. Planeswalker card renders Loyalty badge in hero info hierarchy', (tester) async {
      final item = createTestCard(
        name: 'Liliana of the Veil',
        manaCost: '{1}{B}{B}',
        typeLine: 'Legendary Planeswalker — Liliana',
        power: null,
        toughness: null,
        loyalty: '3',
      );

      await tester.pumpWidget(createTestWidget(
        CardDetailSheet(item: item, fetchOnlinePrintings: false),
      ));
      await tester.pumpAndSettle();

      // Verify Loyalty badge
      final loyaltyFinder = find.text('Loyalty: 3');
      expect(loyaltyFinder, findsOneWidget);

      // P/T should not be rendered
      expect(find.textContaining('P/T:'), findsNothing);

      // Verify Loyalty position is below Type Line in the hero
      final typeLineFinder = find.text('Legendary Planeswalker — Liliana');
      expect(
        tester.getTopLeft(typeLineFinder).dy,
        lessThan(tester.getTopLeft(loyaltyFinder).dy),
      );
    });
  });
}
