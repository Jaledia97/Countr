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
import 'package:countr/features/vault/presentation/widgets/card_detail_sheet.dart';
import 'package:countr/features/decks/presentation/widgets/deck_gear_section.dart';

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
    String id = 'card-sol-ring-v8',
    String name = 'Sol Ring',
    String setCode = 'lea',
    String collectorNumber = '243',
    double price = 2.50,
    int quantity = 1,
    double acquiredPrice = 2.00,
    String condition = 'NM',
    String? protectionStatus = 'Sleeved',
    int? binderPage = 3,
    String? binderSlot = 'B2',
    String? notes = 'Commander staple from Alpha',
    DateTime? dateObtained,
    String? dynamicData,
  }) {
    return VaultItem(
      id: id,
      collectionType: 'mtg',
      name: name,
      setOrSeries: setCode.toUpperCase(),
      imageUrl: 'https://cards.scryfall.io/normal/front/sol_ring.jpg',
      acquiredPrice: acquiredPrice,
      purchasePrice: acquiredPrice,
      acquiredDate: dateObtained ?? DateTime(2023, 5, 10),
      dateObtained: dateObtained ?? DateTime(2023, 5, 10),
      quantity: quantity,
      condition: condition,
      protectionStatus: protectionStatus,
      binderPage: binderPage,
      binderSlot: binderSlot,
      notes: notes,
      personalNotes: notes,
      isGraded: false,
      isAltered: false,
      isMisprint: false,
      isSigned: false, isDeleted: false,
      currentMarketPrice: price,
      lastPriceUpdate: DateTime(2023, 5, 10),
      dynamicData: dynamicData ??
          jsonEncode({
            'collector_number': collectorNumber,
            'set': setCode.toLowerCase(),
            'artist': 'Mark Tedin',
            'border_color': 'borderless',
            'frame_effects': ['showcase'],
            'finishes': ['nonfoil', 'etched'],
            'oracle_text': '{T}: Add {C}{C}.',
            'flavor_text': 'Lost to time is the art of crafting such wonders.',
            'cached_rulings': [
              {
                'published_at': '2020-11-10',
                'comment': '{C} is the colorless mana symbol.',
              },
            ],
          }),
    );
  }

  Widget createTestWidget(
    Widget child, {
    ProviderContainer? container,
    ScryfallService? scryfallService,
    Size viewportSize = const Size(800, 2600),
  }) {
    final mockScryfall = scryfallService ??
        ScryfallService(
          client: MockClient((request) async {
            return http.Response(jsonEncode({'object': 'list', 'data': []}), 200);
          }),
        );

    final widget = MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: viewportSize),
        child: Scaffold(
          body: child,
        ),
      ),
    );

    if (container != null) {
      return UncontrolledProviderScope(
        container: container,
        child: widget,
      );
    }

    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        vaultDaoProvider.overrideWithValue(db.vaultDao),
        scryfallServiceProvider.overrideWithValue(mockScryfall),
      ],
      child: widget,
    );
  }

  group('Milestone 2 CardDetailSheet Two-Tab & 6-Section Layout Tests', () {
    testWidgets('toggles smoothly between [ Details | Values ] tabs', (tester) async {
      tester.view.physicalSize = const Size(800, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final item = createTestCard();
      await db.into(db.vaultItems).insert(item);

      await tester.pumpWidget(createTestWidget(
        CardDetailSheet(item: item, fetchOnlinePrintings: false),
      ));
      await tester.pumpAndSettle();

      // On initial mount: Details tab is active
      expect(find.byKey(const Key('card_detail_segmented_control')), findsOneWidget);
      expect(find.byKey(const Key('card_detail_tab_details')), findsOneWidget);
      expect(find.byKey(const Key('card_detail_tab_values')), findsOneWidget);

      expect(find.byKey(const Key('section_oracle_rules')), findsOneWidget);
      expect(find.byKey(const Key('section_portfolio_metrics')), findsOneWidget);
      expect(find.text('Market Valuation'), findsNothing);

      // Tap on Values tab
      await tester.tap(find.byKey(const Key('card_detail_tab_values')));
      await tester.pumpAndSettle();

      // Values tab is active
      expect(find.text('Market Valuation'), findsOneWidget);
      expect(find.text('Cost Basis'), findsOneWidget);
      expect(find.text('P&L Return'), findsOneWidget);
      expect(find.byKey(const Key('section_oracle_rules')), findsNothing);

      // Tap back on Details tab
      await tester.tap(find.byKey(const Key('card_detail_tab_details')));
      await tester.pumpAndSettle();

      // Details tab is active again
      expect(find.byKey(const Key('section_oracle_rules')), findsOneWidget);
      expect(find.text('Market Valuation'), findsNothing);
    });

    testWidgets('preserves strict 4-tier vertical hierarchy: oracleY < portfolioY < variantY < legalitiesY', (tester) async {
      tester.view.physicalSize = const Size(800, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final item = createTestCard();
      await db.into(db.vaultItems).insert(item);

      await tester.pumpWidget(createTestWidget(
        CardDetailSheet(item: item, fetchOnlinePrintings: false),
      ));
      await tester.pumpAndSettle();

      final oracleSection = find.byKey(const Key('section_oracle_rules'));
      final portfolioSection = find.byKey(const Key('section_portfolio_metrics'));
      final variantSection = find.byKey(const Key('section_variant_price_chart'));
      final legalitiesSection = find.byKey(const Key('section_format_legalities'));

      expect(oracleSection, findsOneWidget);
      expect(portfolioSection, findsOneWidget);
      expect(variantSection, findsOneWidget);
      expect(legalitiesSection, findsOneWidget);

      final oracleY = tester.getTopLeft(oracleSection).dy;
      final portfolioY = tester.getTopLeft(portfolioSection).dy;
      final variantY = tester.getTopLeft(variantSection).dy;
      final legalitiesY = tester.getTopLeft(legalitiesSection).dy;

      expect(oracleY < portfolioY, isTrue, reason: 'Oracle text must be above portfolio metrics');
      expect(portfolioY < variantY, isTrue, reason: 'Portfolio metrics must be above variant chart');
      expect(variantY < legalitiesY, isTrue, reason: 'Variant chart must be above format legalities');
    });

    testWidgets('renders all 6 Details tab sections and initially expanded rulings accordion', (tester) async {
      tester.view.physicalSize = const Size(800, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final item = createTestCard();
      await db.into(db.vaultItems).insert(item);

      await tester.pumpWidget(createTestWidget(
        CardDetailSheet(item: item, fetchOnlinePrintings: false),
      ));
      await tester.pumpAndSettle();

      // Section 1: Oracle text and rulings accordion (initially expanded)
      expect(find.byKey(const Key('section_oracle_rules')), findsOneWidget);
      expect(find.byKey(const Key('card_detail_rulings_accordion')), findsOneWidget);
      expect(find.text('{C} is the colorless mana symbol.'), findsOneWidget);

      // Section 2: Collection Metrics
      expect(find.byKey(const Key('section_portfolio_metrics')), findsOneWidget);
      expect(find.text('Owned Copies'), findsOneWidget);
      expect(find.text('1x'), findsOneWidget);
      expect(find.text('Condition'), findsOneWidget);
      expect(find.text('NM'), findsOneWidget);
      expect(find.text('Language'), findsOneWidget);
      expect(find.text('Treatment'), findsOneWidget);

      // Section 3: Physical Provenance
      expect(find.byKey(const Key('section_physical_provenance')), findsOneWidget);
      expect(find.byKey(const Key('card_detail_edit_card_button')), findsOneWidget);
      expect(find.text('Sleeved'), findsOneWidget);

      // Section 4: Acquisition Tracking
      expect(find.byKey(const Key('section_acquisition_tracking')), findsOneWidget);
      expect(find.textContaining('Date Obtained:'), findsOneWidget);
      expect(find.text('Acquired Price'), findsOneWidget);

      // Section 5: Metadata & Pedigree
      expect(find.byKey(const Key('section_metadata_pedigree')), findsOneWidget);
      expect(find.byKey(const Key('card_detail_artist_filter_button')), findsOneWidget);
      expect(find.text('Artist: Mark Tedin'), findsOneWidget);
      expect(find.byKey(const Key('frame_badge_borderless')), findsOneWidget);
      expect(find.byKey(const Key('frame_badge_showcase')), findsOneWidget);
      expect(find.byKey(const Key('frame_badge_etched_foil')), findsOneWidget);

      // Section 6: Deck History & Assignment Ledger
      expect(find.byKey(const Key('section_deck_history')), findsOneWidget);
      expect(find.byKey(const Key('card_history_ledger')), findsOneWidget);
    });

    testWidgets('Values tab respects Privacy Mode with LockedValuesView and unlock action', (tester) async {
      tester.view.physicalSize = const Size(800, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final item = createTestCard();
      await db.into(db.vaultItems).insert(item);

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
        ],
      );
      addTearDown(container.dispose);

      // Enable Privacy Mode
      container.read(privacyModeProvider.notifier).state = true;

      await tester.pumpWidget(createTestWidget(
        CardDetailSheet(item: item, fetchOnlinePrintings: false),
        container: container,
      ));
      await tester.pumpAndSettle();

      // Switch to Values tab
      await tester.tap(find.byKey(const Key('card_detail_tab_values')));
      await tester.pumpAndSettle();

      // LockedValuesView should be displayed
      expect(find.byKey(const Key('card_detail_values_locked_container')), findsOneWidget);
      expect(
        find.text('Values hidden. Disable Privacy Mode to view market data.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('locked_values_disable_privacy_button')), findsOneWidget);

      // Tap "Disable Privacy Mode" button inside locked state
      await tester.tap(find.byKey(const Key('locked_values_disable_privacy_button')));
      await tester.pumpAndSettle();

      // Privacy Mode should now be disabled and market valuation rendered
      expect(container.read(privacyModeProvider), isFalse);
      expect(find.text('Market Valuation'), findsOneWidget);
      expect(find.text('Cost Basis'), findsOneWidget);
    });

    testWidgets('Artist filter button updates vaultSearchQueryProvider and closes modal', (tester) async {
      tester.view.physicalSize = const Size(800, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final item = createTestCard();
      await db.into(db.vaultItems).insert(item);

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(createTestWidget(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => CardDetailSheet.show(context, item),
            child: const Text('Open Sheet'),
          ),
        ),
        container: container,
      ));
      await tester.pumpAndSettle();

      // Open bottom sheet
      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      // Verify artist button is visible
      final artistBtn = find.byKey(const Key('card_detail_artist_filter_button'));
      expect(artistBtn, findsOneWidget);

      // Click artist filter button
      await tester.tap(artistBtn);
      await tester.pumpAndSettle();

      // Verify vaultSearchQueryProvider is set to the artist name
      expect(container.read(vaultSearchQueryProvider), 'Mark Tedin');

      // Verify sheet is closed
      expect(find.byKey(const Key('card_detail_segmented_control')), findsNothing);
    });

    testWidgets('renders DeckGearSection when opened in Deck Scope', (tester) async {
      tester.view.physicalSize = const Size(800, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final item = createTestCard();
      await db.into(db.vaultItems).insert(item);

      await tester.pumpWidget(createTestWidget(
        CardDetailSheet(
          item: item,
          deckId: 'deck-test-123',
          fetchOnlinePrintings: false,
        ),
      ));
      await tester.pumpAndSettle();

      // DeckGearSection should be present
      expect(find.byType(DeckGearSection), findsOneWidget);
      expect(find.byKey(const Key('deck_gear_sleeve_brand_input')), findsOneWidget);
      expect(find.byKey(const Key('deck_gear_box_model_input')), findsOneWidget);
    });
  });
}
