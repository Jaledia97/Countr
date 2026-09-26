import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/settings_state.dart';
import 'package:countr/features/hydration/data/services/scryfall_service.dart';
import 'package:countr/features/hydration/presentation/providers/hydration_providers.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/widgets/card_detail_sheet.dart';
import 'package:countr/features/symbology/presentation/widgets/mana_text.dart';
import 'package:countr/features/values/presentation/widgets/locked_values_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  VaultItem buildCard({
    String id = 'challenger2-card-1',
    String name = 'Urza, Lord High Artificer',
    String setCode = 'mh1',
    String collectorNumber = '075',
    double price = 42.50,
    int quantity = 1,
    double acquiredPrice = 30.00,
    String condition = 'NM',
    String? dynamicData,
  }) {
    return VaultItem(
      id: id,
      collectionType: 'mtg',
      name: name,
      setOrSeries: setCode.toUpperCase(),
      imageUrl: 'https://cards.scryfall.io/normal/front/urza.jpg',
      acquiredPrice: acquiredPrice,
      purchasePrice: acquiredPrice,
      acquiredDate: DateTime(2023, 6, 15),
      dateObtained: DateTime(2023, 6, 15),
      quantity: quantity,
      condition: condition,
      protectionStatus: 'Toploader',
      binderPage: 4,
      binderSlot: 'C1',
      notes: 'Commander deck centerpiece',
      personalNotes: 'Commander deck centerpiece',
      isGraded: false,
      isAltered: false,
      isMisprint: false,
      isSigned: false, isDeleted: false,
      currentMarketPrice: price,
      lastPriceUpdate: DateTime(2023, 6, 15),
      dynamicData: dynamicData ??
          jsonEncode({
            'collector_number': collectorNumber,
            'set': setCode.toLowerCase(),
            'oracle_id': 'urza-oracle-uuid',
            'oracle_text':
                'When Urza enters the battlefield, create a 0/0 colorless Construct artifact creature token with "This creature gets +1/+1 for each artifact you control."\n{T}, Tap an untapped artifact you control: Add {U}.\n{5}: Shuffle your library, then exile the top card. Until end of turn, you may play that card without paying its mana cost.',
            'flavor_text': 'Master artificer of the Brothers\' War.',
            'cached_rulings': [
              {
                'published_at': '2019-06-14',
                'comment': 'Urza\'s first ability creates a Construct token.',
              },
              {
                'published_at': '2019-06-14',
                'comment':
                    'You can tap any untapped artifact to pay the cost of Urza\'s second ability, including Urza itself if it\'s an artifact.',
              },
            ],
          }),
    );
  }

  Widget createHarness(
    Widget child, {
    ProviderContainer? container,
    Size viewportSize = const Size(800, 2600),
    TextScaler textScaler = TextScaler.noScaling,
  }) {
    final mockScryfall = ScryfallService(
      client: MockClient((request) async {
        return http.Response(jsonEncode({'object': 'list', 'data': []}), 200);
      }),
    );

    final app = MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: viewportSize,
          textScaler: textScaler,
        ),
        child: Scaffold(
          body: child,
        ),
      ),
    );

    if (container != null) {
      return UncontrolledProviderScope(
        container: container,
        child: app,
      );
    }

    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        vaultDaoProvider.overrideWithValue(db.vaultDao),
        scryfallServiceProvider.overrideWithValue(mockScryfall),
      ],
      child: app,
    );
  }

  group('CHALLENGER 2: Empirical Stress Tests', () {
    testWidgets('1. Vertical order invariant: strictly validates oracleY < portfolioY < variantY < legalitiesY', (tester) async {
      tester.view.physicalSize = const Size(800, 3600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final card = buildCard();
      await db.into(db.vaultItems).insert(card);

      await tester.pumpWidget(createHarness(
        CardDetailSheet(item: card, fetchOnlinePrintings: false),
        viewportSize: const Size(800, 3600),
      ));
      await tester.pumpAndSettle();

      final oracleFinder = find.byKey(const Key('section_oracle_rules'));
      final portfolioFinder = find.byKey(const Key('section_portfolio_metrics'));
      final variantFinder = find.byKey(const Key('section_variant_price_chart'));
      final legalitiesFinder = find.byKey(const Key('section_format_legalities'));

      expect(oracleFinder, findsOneWidget);
      expect(portfolioFinder, findsOneWidget);
      expect(variantFinder, findsOneWidget);
      expect(legalitiesFinder, findsOneWidget);

      final double oracleY = tester.getTopLeft(oracleFinder).dy;
      final double portfolioY = tester.getTopLeft(portfolioFinder).dy;
      final double variantY = tester.getTopLeft(variantFinder).dy;
      final double legalitiesY = tester.getTopLeft(legalitiesFinder).dy;

      expect(
        oracleY < portfolioY,
        isTrue,
        reason: 'oracleY ($oracleY) must be strictly less than portfolioY ($portfolioY)',
      );
      expect(
        portfolioY < variantY,
        isTrue,
        reason: 'portfolioY ($portfolioY) must be strictly less than variantY ($variantY)',
      );
      expect(
        variantY < legalitiesY,
        isTrue,
        reason: 'variantY ($variantY) must be strictly less than legalitiesY ($legalitiesY)',
      );

      // Total invariant
      expect(
        oracleY < portfolioY && portfolioY < variantY && variantY < legalitiesY,
        isTrue,
        reason: 'Strict 4-tier vertical order violated: oracleY=$oracleY, portfolioY=$portfolioY, variantY=$variantY, legalitiesY=$legalitiesY',
      );
    });

    testWidgets('2. Rulings Accordion: renders published dates and comments formatted with ManaText, handles multiline & empty cleanly', (tester) async {
      tester.view.physicalSize = const Size(800, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Card with complex multi-line rulings and mana symbols in rulings
      final complexRulingCard = buildCard(
        id: 'ruling-test-card',
        dynamicData: jsonEncode({
          'collector_number': '001',
          'set': 'test',
          'oracle_text': '{T}: Do something.',
          'cached_rulings': [
            {
              'published_at': '2023-01-15',
              'comment': 'This ruling has mana symbols like {T}, {U}, and {W/U}.\nLine 2 explains the interaction in detail.\nLine 3 concludes it.',
            },
            {
              'published_at': '2023-02-20',
              'comment': 'Second ruling comment with {2}{B}.',
            },
            {
              'published_at': '',
              'comment': 'Ruling with empty published date.',
            },
          ],
        }),
      );
      await db.into(db.vaultItems).insert(complexRulingCard);

      await tester.pumpWidget(createHarness(
        CardDetailSheet(item: complexRulingCard, fetchOnlinePrintings: false),
        viewportSize: const Size(800, 2600),
      ));
      await tester.pumpAndSettle();

      final accordionFinder = find.byKey(const Key('card_detail_rulings_accordion'));
      expect(accordionFinder, findsOneWidget);
      expect(find.text('Official Rulings (3)'), findsOneWidget);

      // Check dates
      expect(find.text('2023-01-15'), findsOneWidget);
      expect(find.text('2023-02-20'), findsOneWidget);

      // Check ManaText widgets rendered inside the rulings accordion
      final manaTextInAccordion = find.descendant(
        of: accordionFinder,
        matching: find.byType(ManaText),
      );
      expect(manaTextInAccordion, findsAtLeastNWidgets(3));

      // Verify that ManaText contains the expected comments
      expect(
        find.textContaining('This ruling has mana symbols like'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Second ruling comment with'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Ruling with empty published date.'),
        findsOneWidget,
      );

      // Test Empty Rulings cleanly
      final emptyRulingsCard = buildCard(
        id: 'empty-ruling-card',
        dynamicData: jsonEncode({
          'collector_number': '002',
          'set': 'test',
          'oracle_text': 'Vanilla creature.',
          'cached_rulings': [],
        }),
      );
      await db.into(db.vaultItems).insert(emptyRulingsCard);

      await tester.pumpWidget(createHarness(
        CardDetailSheet(item: emptyRulingsCard, fetchOnlinePrintings: false),
        viewportSize: const Size(800, 2600),
      ));
      await tester.pumpAndSettle();

      // Clean handling: when rulings is empty, rulings accordion is not rendered and no exception thrown
      expect(find.byKey(const Key('card_detail_rulings_accordion')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('3. Values tab: displays LockedValuesView with verbatim message when Privacy Mode enabled, reveals metrics when disabled', (tester) async {
      tester.view.physicalSize = const Size(800, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final card = buildCard();
      await db.into(db.vaultItems).insert(card);

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
        ],
      );
      addTearDown(container.dispose);

      // Start with Privacy Mode = true
      container.read(privacyModeProvider.notifier).state = true;

      await tester.pumpWidget(createHarness(
        CardDetailSheet(item: card, fetchOnlinePrintings: false),
        container: container,
        viewportSize: const Size(800, 2600),
      ));
      await tester.pumpAndSettle();

      // Tap on Values tab
      await tester.tap(find.byKey(const Key('card_detail_tab_values')));
      await tester.pumpAndSettle();

      // Verify LockedValuesView is rendered
      expect(find.byType(LockedValuesView), findsOneWidget);
      expect(find.byKey(const Key('card_detail_values_locked_container')), findsOneWidget);
      expect(find.byKey(const Key('locked_values_lock_icon')), findsOneWidget);
      expect(
        find.text('Values hidden. Disable Privacy Mode to view market data.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('locked_values_disable_privacy_button')), findsOneWidget);

      // Verify financial data is NOT rendered
      expect(find.text('Market Valuation'), findsNothing);
      expect(find.text('Cost Basis'), findsNothing);

      // Tap unlock button
      await tester.tap(find.byKey(const Key('locked_values_disable_privacy_button')));
      await tester.pumpAndSettle();

      // Privacy Mode is now false
      expect(container.read(privacyModeProvider), isFalse);

      // Market metrics revealed
      expect(find.byType(LockedValuesView), findsNothing);
      expect(find.text('Market Valuation'), findsOneWidget);
      expect(find.text('Cost Basis'), findsOneWidget);
      expect(find.text('P&L Return'), findsOneWidget);

      // Toggle Privacy Mode back to true
      container.read(privacyModeProvider.notifier).state = true;
      await tester.pumpAndSettle();

      // Relocked immediately
      expect(find.byType(LockedValuesView), findsOneWidget);
      expect(find.text('Market Valuation'), findsNothing);
    });

    testWidgets('4a. Details Tab ultra-constrained viewport stress: 320x568 screen with 2.0x font scaling across drag gestures (minChildSize: 0.45) has ZERO RenderFlex overflows', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final card = buildCard(
        name: 'Urza, Lord High Artificer // Super Long Subtitle Card Name',
        collectorNumber: '345b',
      );
      await db.into(db.vaultItems).insert(card);

      final List<FlutterErrorDetails> errors = [];
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        errors.add(details);
      };
      addTearDown(() {
        FlutterError.onError = originalOnError;
      });

      await tester.pumpWidget(createHarness(
        CardDetailSheet(item: card, fetchOnlinePrintings: false),
        viewportSize: const Size(320, 568),
        textScaler: const TextScaler.linear(2.0),
      ));
      await tester.pumpAndSettle();

      // Verify zero RenderFlex overflows on initial render
      final overflowsInitial = errors.where((e) {
        final msg = e.exceptionAsString();
        return msg.contains('RenderFlex overflowed') || msg.contains('A RenderFlex overflowed');
      }).toList();
      expect(overflowsInitial, isEmpty, reason: 'Zero overflows on initial render at 320x568 with 2.0x text scaling');

      // Drag sheet downwards towards minChildSize (0.45)
      final dragHandleFinder = find.byType(PageView);
      await tester.drag(dragHandleFinder, const Offset(0, 250));
      await tester.pumpAndSettle();

      final overflowsAfterDragDown = errors.where((e) {
        final msg = e.exceptionAsString();
        return msg.contains('RenderFlex overflowed') || msg.contains('A RenderFlex overflowed');
      }).toList();
      expect(overflowsAfterDragDown, isEmpty, reason: 'Zero overflows when dragged down to minChildSize on 320x568 at 2.0x scaling');

      // Drag sheet upwards towards maxChildSize (0.96)
      await tester.drag(dragHandleFinder, const Offset(0, -350));
      await tester.pumpAndSettle();

      final overflowsAfterDragUp = errors.where((e) {
        final msg = e.exceptionAsString();
        return msg.contains('RenderFlex overflowed') || msg.contains('A RenderFlex overflowed');
      }).toList();
      expect(overflowsAfterDragUp, isEmpty, reason: 'Zero overflows when dragged up to maxChildSize on 320x568 at 2.0x scaling');
      expect(tester.takeException(), isNull);
    });

    testWidgets('4b. Values Tab ultra-constrained viewport stress: 320x568 screen with 2.0x font scaling has ZERO RenderFlex overflows', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final card = buildCard();
      await db.into(db.vaultItems).insert(card);

      final List<FlutterErrorDetails> errors = [];
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        errors.add(details);
      };
      addTearDown(() {
        FlutterError.onError = originalOnError;
      });

      await tester.pumpWidget(createHarness(
        CardDetailSheet(item: card, fetchOnlinePrintings: false),
        viewportSize: const Size(320, 568),
        textScaler: const TextScaler.linear(2.0),
      ));
      await tester.pumpAndSettle();

      // Switch to Values tab
      await tester.tap(find.byKey(const Key('card_detail_tab_values')));
      await tester.pumpAndSettle();

      final overflows = errors.where((e) {
        final msg = e.exceptionAsString();
        return msg.contains('RenderFlex overflowed') || msg.contains('A RenderFlex overflowed');
      }).toList();

      expect(overflows, isEmpty, reason: 'Zero RenderFlex overflows across Values tab on 320x568 at 2.0x scaling');
      expect(tester.takeException(), isNull);
    });

    testWidgets('4c. Locked Values View ultra-constrained viewport stress: 320x568 screen with 2.0x font scaling has ZERO RenderFlex overflows', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final card = buildCard();
      await db.into(db.vaultItems).insert(card);

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
        ],
      );
      addTearDown(container.dispose);
      container.read(privacyModeProvider.notifier).state = true;

      final List<FlutterErrorDetails> errors = [];
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        errors.add(details);
      };
      addTearDown(() {
        FlutterError.onError = originalOnError;
      });

      await tester.pumpWidget(createHarness(
        CardDetailSheet(item: card, fetchOnlinePrintings: false),
        container: container,
        viewportSize: const Size(320, 568),
        textScaler: const TextScaler.linear(2.0),
      ));
      await tester.pumpAndSettle();

      // Switch to Values tab while Privacy Mode is active
      await tester.tap(find.byKey(const Key('card_detail_tab_values')));
      await tester.pumpAndSettle();

      final overflows = errors.where((e) {
        final msg = e.exceptionAsString();
        return msg.contains('RenderFlex overflowed') || msg.contains('A RenderFlex overflowed');
      }).toList();

      expect(overflows, isEmpty, reason: 'LockedValuesView should have zero overflows on 320x568 at 2.0x scaling');
      expect(tester.takeException(), isNull);
    });
  });
}
