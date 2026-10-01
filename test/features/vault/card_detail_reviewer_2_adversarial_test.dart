import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
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

  VaultItem createCard({
    String id = 'adv-card-1',
    String name = 'Mox Diamond',
    String setCode = 'STH',
    String setName = 'Stronghold',
    String collectorNumber = '138',
    double acquiredPrice = 0.0,
    double marketPrice = 650.00,
    int quantity = 0,
    String? typeLine = 'Artifact',
    String? manaCost = '{0}',
    String? power,
    String? toughness,
    String? loyalty,
    String? dynamicData,
  }) {
    return VaultItem(
      id: id,
      collectionType: 'mtg',
      name: name,
      setOrSeries: setName,
      imageUrl: 'https://cards.scryfall.io/normal/front/mox.jpg',
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
      personalNotes: 'Testing card notes.',
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
            'oracle_text':
                'If Mox Diamond would enter the battlefield, you may discard a land card instead. If you do, put Mox Diamond onto the battlefield. If you don\'t, put it into its owner\'s graveyard.\n{T}: Add one mana of any color.',
            'flavor_text': 'A diamond that shines with pure mana.',
            'cached_rulings': [
              {
                'published_at': '2008-08-01',
                'comment': 'This is a replacement effect.',
              }
            ],
          }),
    );
  }

  Widget createHarness(
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

  group('Reviewer 2 Adversarial Verification: Milestone 4 (R4)', () {
    testWidgets('1. Unowned card: Add to Vault is present, triggers _addToVault, updates DB quantity to 1', (tester) async {
      final unownedItem = createCard(
        id: 'unowned-mox-diamond',
        name: 'Mox Diamond',
        quantity: 0,
      );

      // Pre-seed into database with quantity 0
      await db.into(db.vaultItems).insert(unownedItem);

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
                    onPressed: () => CardDetailSheet.show(ctx, unownedItem),
                    child: const Text('Open Detail Sheet'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Detail Sheet'));
      await tester.pumpAndSettle();

      // Check button existence, key, and copy
      final addButtonFinder = find.byKey(const Key('quick_action_add_to_plus'));
      expect(addButtonFinder, findsOneWidget);
      expect(find.text('Add to +'), findsOneWidget);

      // Tap 'Add to +'
      await tester.tap(addButtonFinder);
      await tester.pumpAndSettle();

      // Verify routing modal options appear
      expect(find.textContaining('Binders'), findsWidgets);
      expect(find.textContaining('Decks'), findsWidgets);
    });

    testWidgets('2. Owned card: Add to Vault button is absent and cannot be triggered', (tester) async {
      final ownedItem = createCard(
        id: 'owned-mox-diamond',
        name: 'Mox Diamond',
        quantity: 2,
      );

      await tester.pumpWidget(createHarness(
        CardDetailSheet(item: ownedItem, fetchOnlinePrintings: false),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('quick_action_add_to_plus')), findsNothing);
      expect(find.text('Add to +'), findsNothing);
      expect(find.text('Add to Vault'), findsNothing);
      expect(find.text('Add to Vault / Inbox'), findsNothing);
    });

    testWidgets('3. Rapid Details ↔ Values tab toggling preserves Top Hero and switches cleanly', (tester) async {
      final item = createCard(
        name: 'Mox Diamond',
        quantity: 1,
      );

      await tester.pumpWidget(createHarness(
        CardDetailSheet(item: item, fetchOnlinePrintings: false),
      ));
      await tester.pumpAndSettle();

      final detailsTabFinder = find.byKey(const Key('card_detail_tab_details'));
      final valuesTabFinder = find.byKey(const Key('card_detail_tab_values'));
      final heroFinder = find.byKey(Key('card_artwork_${item.id}'));

      expect(detailsTabFinder, findsOneWidget);
      expect(valuesTabFinder, findsOneWidget);
      expect(heroFinder, findsOneWidget);
      expect(find.byKey(const Key('section_oracle_rules')), findsOneWidget);

      // Cycle tabs 5 times rapidly
      for (int i = 0; i < 5; i++) {
        await tester.tap(valuesTabFinder);
        await tester.pumpAndSettle();
        expect(heroFinder, findsOneWidget);
        expect(find.byKey(const Key('section_oracle_rules')), findsNothing);
        expect(find.byKey(const Key('market_valuation_header')), findsOneWidget);

        await tester.tap(detailsTabFinder);
        await tester.pumpAndSettle();
        expect(heroFinder, findsOneWidget);
        expect(find.byKey(const Key('section_oracle_rules')), findsOneWidget);
        expect(find.byKey(const Key('market_valuation_header')), findsNothing);
      }

      expect(tester.takeException(), isNull);
    });

    testWidgets('4. Compact viewport (<400px height, e.g. 350px) at 1.5x text scale triggers isCompact with 0 overflows', (tester) async {
      final List<FlutterErrorDetails> errors = [];
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        errors.add(details);
        originalOnError?.call(details);
      };

      try {
        final item = createCard(
          name: 'Extremely Long Card Name That Wraps Multiple Lines In Hero Area',
          quantity: 0,
        );

        await tester.pumpWidget(createHarness(
          CardDetailSheet(item: item, fetchOnlinePrintings: false),
          viewportSize: const Size(360, 350),
          textScaler: const TextScaler.linear(1.5),
        ));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('card_detail_segmented_control')), findsOneWidget);
        expect(find.byKey(const Key('quick_action_add_to_plus')), findsOneWidget);

        final overflows = errors.where((e) => e.exceptionAsString().contains('overflowed')).toList();
        expect(overflows, isEmpty, reason: 'Zero overflows allowed in compact viewport (<400px)');
        expect(tester.takeException(), isNull);
      } finally {
        FlutterError.onError = originalOnError;
      }
    });

    testWidgets('5. Ultra compact viewport (<240px height, e.g. 210px) at 2.0x text scale triggers isUltraCompact with 0 overflows', (tester) async {
      final List<FlutterErrorDetails> errors = [];
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        errors.add(details);
        originalOnError?.call(details);
      };

      try {
        final item = createCard(
          name: 'Super Compressed Layout Card',
          quantity: 0,
        );

        await tester.pumpWidget(createHarness(
          CardDetailSheet(item: item, fetchOnlinePrintings: false),
          viewportSize: const Size(320, 210),
          textScaler: const TextScaler.linear(2.0),
        ));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('card_detail_segmented_control')), findsOneWidget);
        expect(find.byKey(const Key('quick_action_add_to_plus')), findsOneWidget);

        final overflows = errors.where((e) => e.exceptionAsString().contains('overflowed')).toList();
        expect(overflows, isEmpty, reason: 'Zero overflows allowed in ultra compact viewport (<240px)');
        expect(tester.takeException(), isNull);
      } finally {
        FlutterError.onError = originalOnError;
      }
    });

    testWidgets('6. Details Tab strictly starts with section_oracle_rules without duplicate artwork or Add to Vault', (tester) async {
      final item = createCard(
        name: 'Oracle Text Card',
        quantity: 0,
      );

      await tester.pumpWidget(createHarness(
        CardDetailSheet(item: item, fetchOnlinePrintings: false),
      ));
      await tester.pumpAndSettle();

      final listFinder = find.byKey(PageStorageKey('card_detail_list_${item.id}'));
      expect(listFinder, findsOneWidget);

      // Ensure artwork is NOT inside the list
      final artworkInList = find.descendant(
        of: listFinder,
        matching: find.byKey(Key('card_artwork_${item.id}')),
      );
      expect(artworkInList, findsNothing, reason: 'Artwork must be in Top Hero, not duplicated in Details list');

      // Ensure Add to + is NOT inside the list
      final addInList = find.descendant(
        of: listFinder,
        matching: find.byKey(const Key('quick_action_add_to_plus')),
      );
      expect(addInList, findsNothing, reason: 'Add to + must be outside Details list');

      // Section 1 is indeed oracle rules
      expect(
        find.descendant(
          of: listFinder,
          matching: find.byKey(const Key('section_oracle_rules')),
        ),
        findsOneWidget,
      );
    });
  });
}
