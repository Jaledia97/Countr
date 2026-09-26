import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/app_state.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/widgets/vault_item_tile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  VaultItem createTestCard({
    required String id,
    required String name,
    int quantity = 1,
    String? flavorName,
    bool isGraded = false,
    String setOrSeries = 'MH3',
    double price = 15.0,
  }) {
    return VaultItem(
      id: id,
      collectionType: 'mtg',
      name: name,
      flavorName: flavorName,
      setOrSeries: setOrSeries,
      imageUrl: '',
      acquiredPrice: price,
      acquiredDate: DateTime(2026, 1, 1),
      quantity: quantity,
      condition: 'Near Mint',
      isGraded: isGraded,
      isAltered: false,
      isMisprint: false,
      isSigned: false, isDeleted: false,
      personalNotes: null,
      primaryBinderId: null,
      currentMarketPrice: price,
      lastPriceUpdate: DateTime(2026, 1, 1),
      dynamicData: jsonEncode({}),
    );
  }

  Widget wrapWithHarness(
    Widget child, {
    Map<String, List<String>> activeDecksMap = const {},
    bool includeProviderScope = true,
  }) {
    final app = MaterialApp(
      theme: ThemeData.dark(),
      home: Scaffold(
        body: child,
      ),
    );

    if (!includeProviderScope) {
      return app;
    }

    return ProviderScope(
      overrides: [
        userPersonaProvider.overrideWith((ref) => UserPersona.investor),
        allCardActiveDecksProvider.overrideWith(
          (ref) => Stream.value(activeDecksMap),
        ),
      ],
      child: app,
    );
  }

  group('VaultItemTile Empirical Stress & Performance Suite', () {
    // -------------------------------------------------------------------------
    // 1. Heavy List Rendering & Smooth Virtualized Scrolling
    // -------------------------------------------------------------------------
    testWidgets(
      'Heavy List: Renders 100 items in GridView and scrolls without jank or exceptions',
      (tester) async {
        final items = List.generate(
          100,
          (i) => createTestCard(
            id: 'item_$i',
            name: 'Card Name Number $i',
            price: 10.0 + i,
          ),
        );

        await tester.pumpWidget(
          wrapWithHarness(
            GridView.builder(
              key: const Key('vault_grid_view'),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.65,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) {
                return VaultItemTile(item: items[index]);
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Initial visible items rendered
        expect(find.byKey(const Key('vault_tile_item_0')), findsOneWidget);
        expect(find.byKey(const Key('vault_tile_item_1')), findsOneWidget);

        // Rapid fling down
        await tester.fling(find.byKey(const Key('vault_grid_view')), const Offset(0, -2000), 3000);
        await tester.pumpAndSettle();

        // Item 0 should have been recycled out of viewport
        expect(find.byKey(const Key('vault_tile_item_0')), findsNothing);
        // Later items rendered
        expect(find.byType(VaultItemTile), findsWidgets);

        // Fling back to top
        await tester.fling(find.byKey(const Key('vault_grid_view')), const Offset(0, 2000), 3000);
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('vault_tile_item_0')), findsOneWidget);
      },
    );

    // -------------------------------------------------------------------------
    // 2. Gesture Interactions
    // -------------------------------------------------------------------------
    testWidgets('Gesture: Custom onTap callback executes accurately upon tap', (tester) async {
      var tapped = false;
      final card = createTestCard(id: 'tap_card', name: 'Tappable Sol Ring');

      await tester.pumpWidget(
        wrapWithHarness(
          Center(
            child: SizedBox(
              width: 140,
              height: 210,
              child: VaultItemTile(
                item: card,
                onTap: () => tapped = true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('vault_tile_tap_card')));
      await tester.pump();

      expect(tapped, isTrue);
    });

    // -------------------------------------------------------------------------
    // 3. ProviderScope Absence Guard
    // -------------------------------------------------------------------------
    testWidgets(
      'Resilience: Safely renders outside ProviderScope ancestor without throwing',
      (tester) async {
        final card = createTestCard(id: 'raw_card', name: 'Raw Widget Tree Card');

        await tester.pumpWidget(
          wrapWithHarness(
            Center(
              child: SizedBox(
                width: 140,
                height: 210,
                child: VaultItemTile(item: card),
              ),
            ),
            includeProviderScope: false,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('vault_tile_raw_card')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    // -------------------------------------------------------------------------
    // 4. Batch Assigned Decks Badging
    // -------------------------------------------------------------------------
    testWidgets(
      'Deck Badges: Displays batch active deck badges from allCardActiveDecksProvider',
      (tester) async {
        final card = createTestCard(id: 'deck_card', name: 'Atraxa, Praetors Voice');

        await tester.pumpWidget(
          wrapWithHarness(
            Center(
              child: SizedBox(
                width: 160,
                height: 240,
                child: VaultItemTile(item: card),
              ),
            ),
            activeDecksMap: {
              'deck_card': ['Commander 1', 'Historic Brawl'],
            },
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('⚔️ Commander 1'), findsOneWidget);
        expect(find.text('⚔️ Historic Brawl'), findsOneWidget);
      },
    );

    // -------------------------------------------------------------------------
    // 5. Extreme Responsive Widths & Zero Layout Overflows
    // -------------------------------------------------------------------------
    testWidgets(
      'Layout: Renders across 90px, 112px, 140px, 240px tile widths without RenderFlex overflow',
      (tester) async {
        final widths = [90.0, 112.0, 140.0, 240.0];
        final card = createTestCard(
          id: 'responsive_card',
          name: 'Extremely Long Card Name That Might Wrap Or Overflow The Inner Container',
          flavorName: 'Special Extended God-Pharaoh Flavor Name',
          isGraded: true,
          quantity: 4,
        );

        for (final width in widths) {
          await tester.pumpWidget(
            wrapWithHarness(
              Center(
                child: SizedBox(
                  width: width,
                  height: width * 1.5,
                  child: VaultItemTile(item: card),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.byKey(const Key('vault_tile_responsive_card')), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
      },
    );
  });
}
