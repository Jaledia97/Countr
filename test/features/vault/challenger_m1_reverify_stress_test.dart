import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/app_state.dart';
import 'package:countr/features/hydration/data/services/scryfall_service.dart';
import 'package:countr/features/hydration/presentation/providers/hydration_providers.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/screens/vault_screen.dart';
import 'package:countr/features/vault/presentation/widgets/card_detail_sheet.dart';
import 'package:countr/features/vault/presentation/widgets/vault_item_tile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.vaultDao.clearAllItems();
  });

  tearDown(() async {
    await db.close();
  });

  VaultItem createCard({
    required String id,
    required String name,
    required int quantity,
    double marketPrice = 15.0,
    double acquiredPrice = 0.0,
    String? primaryBinderId,
    String condition = 'NM',
    String collectionType = 'mtg',
  }) {
    return VaultItem(
      id: id,
      collectionType: collectionType,
      name: name,
      setOrSeries: 'MH3',
      imageUrl: 'https://example.com/$id.jpg',
      acquiredPrice: acquiredPrice,
      acquiredDate: DateTime(2026, 1, 1),
      quantity: quantity,
      condition: condition,
      isGraded: false,
      isAltered: false,
      isMisprint: false,
      isSigned: false,
      isDeleted: false,
      currentMarketPrice: marketPrice,
      lastPriceUpdate: DateTime.now(),
      dynamicData: jsonEncode({
        'collector_number': '101',
        'set': 'mh3',
        'oracle_text': 'Re-verification stress card',
      }),
      personalNotes: null,
      primaryBinderId: primaryBinderId,
    );
  }

  Widget createHarness({
    required Widget child,
    List<Override> overrides = const [],
  }) {
    final mockScryfall = ScryfallService(
      client: MockClient((request) async {
        return http.Response(jsonEncode({'object': 'list', 'data': []}), 200);
      }),
    );

    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        vaultDaoProvider.overrideWithValue(db.vaultDao),
        scryfallServiceProvider.overrideWithValue(mockScryfall),
        activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
        vaultViewModeProvider.overrideWith((ref) => VaultViewMode.allVault),
        cardDisplayLayoutProvider.overrideWith((ref) => CardDisplayLayout.grid),
        ...overrides,
      ],
      child: MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(size: Size(1080, 2400)),
            child: child,
          ),
        ),
      ),
    );
  }

  group('Challenger Re-verification Stress Harness', () {
    testWidgets('Quadruple tap on binder destination does not pop CardDetailSheet', (tester) async {
      final binder = await db.vaultDao.createBinder(
        name: 'Target Binder 4x',
        collectionType: 'mtg',
      );

      final card = createCard(
        id: 'stress-quad-tap',
        name: 'Force of Will',
        quantity: 1,
      );
      await db.vaultDao.into(db.vaultItems).insert(card);

      await tester.pumpWidget(createHarness(
        child: Builder(
          builder: (context) => ElevatedButton(
            key: const Key('open_quad'),
            onPressed: () => CardDetailSheet.show(
              context,
              card,
              fetchOnlinePrintings: false,
            ),
            child: const Text('Open'),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open_quad')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('quick_action_move_binder')));
      await tester.pumpAndSettle();

      final destinationTile = find.byKey(Key('move_to_binder_${binder.id}'));
      expect(destinationTile, findsOneWidget);

      // Simulate 4 rapid taps
      await tester.tap(destinationTile);
      await tester.tap(destinationTile, warnIfMissed: false);
      await tester.tap(destinationTile, warnIfMissed: false);
      await tester.tap(destinationTile, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.byType(CardDetailSheet), findsOneWidget,
          reason: 'Quadruple tap caused CardDetailSheet to pop!');

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('Rapid double tap on "Add to +" -> "Binders" does not pop CardDetailSheet', (tester) async {
      await db.vaultDao.createBinder(
        name: 'Collector Binder',
        collectionType: 'mtg',
      );

      final card = createCard(
        id: 'stress-add-to-plus',
        name: 'Catalog Mox',
        quantity: 0,
      );
      await db.vaultDao.into(db.vaultItems).insert(card);

      await tester.pumpWidget(createHarness(
        child: Builder(
          builder: (context) => ElevatedButton(
            key: const Key('open_catalog_card'),
            onPressed: () => CardDetailSheet.show(
              context,
              card,
              fetchOnlinePrintings: false,
            ),
            child: const Text('Open'),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open_catalog_card')));
      await tester.pumpAndSettle();

      // Open Add to +
      await tester.tap(find.byKey(const Key('quick_action_add_to_plus')));
      await tester.pumpAndSettle();

      final bindersOption = find.byKey(const Key('add_to_binders_option'));
      expect(bindersOption, findsOneWidget);

      // Rapidly double tap 'Binders' option in Add to + selector
      await tester.tap(bindersOption);
      await tester.tap(bindersOption, warnIfMissed: false);
      await tester.pumpAndSettle();

      // CardDetailSheet should still exist
      expect(find.byType(CardDetailSheet), findsOneWidget,
          reason: 'Double tapping "Binders" in Add to + modal popped CardDetailSheet!');

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('Rapid double tap on "New Binder" in multi-select modal does not pop VaultScreen', (tester) async {
      final card = createCard(
        id: 'stress-multiselect-new-binder',
        name: 'Llanowar Elves',
        quantity: 1,
      );
      await db.vaultDao.into(db.vaultItems).insert(card);

      await tester.pumpWidget(createHarness(
        child: Builder(
          builder: (context) => ElevatedButton(
            key: const Key('push_vault_screen_stress'),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const VaultScreen()),
              );
            },
            child: const Text('Go Vault'),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('push_vault_screen_stress')));
      await tester.pumpAndSettle();

      expect(find.byType(VaultScreen), findsOneWidget);

      // Select card
      await tester.longPress(find.widgetWithText(VaultItemTile, 'Llanowar Elves'));
      await tester.pumpAndSettle();

      // Open multi-select modal
      await tester.tap(find.byKey(const Key('vault_selection_move_binder_button')));
      await tester.pumpAndSettle();

      // Tap "+ Create First Binder"
      final createButton = find.text('+ Create First Binder');
      expect(createButton, findsOneWidget);

      await tester.tap(createButton);
      await tester.tap(createButton, warnIfMissed: false);
      await tester.pumpAndSettle();

      // VaultScreen must still exist!
      expect(find.byType(VaultScreen), findsOneWidget,
          reason: 'Double tapping Create First Binder popped VaultScreen!');

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
    });
  });
}
