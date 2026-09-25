import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/settings_state.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/widgets/variant_price_chart.dart';
import 'package:countr/features/vault/presentation/widgets/card_detail_sheet.dart';
import 'package:countr/features/vault/presentation/widgets/switch_printing_modal.dart';
import 'package:countr/features/vault/presentation/widgets/manual_add_bottom_sheet.dart';

VaultItem createItem({
  String id = 'test_item_1',
  String name = 'Black Lotus',
  double currentMarketPrice = 852.00,
  double acquiredPrice = 520.00,
  int quantity = 1,
}) {
  return VaultItem(
    id: id,
    collectionType: 'mtg',
    name: name,
    setOrSeries: 'LEA',
    imageUrl: 'https://example.com/lotus.jpg',
    quantity: quantity,
    condition: 'NM',
    isGraded: false,
    isAltered: false,
    isMisprint: false,
    isSigned: false,
    acquiredPrice: acquiredPrice,
    acquiredDate: DateTime(2021, 5, 1),
    currentMarketPrice: currentMarketPrice,
    lastPriceUpdate: DateTime(2026, 9, 24),
    dynamicData:
        '{"prices":{"usd":"${currentMarketPrice.toStringAsFixed(2)}"},"set_code":"lea","collector_number":"232"}',
  );
}

List<CardPrintCandidate> createTestVariants() {
  return [
    CardPrintCandidate(
      setCode: 'lea',
      setName: 'Limited Edition Alpha',
      collectorNumber: '232',
      imageUrl: '',
      marketPrice: 852.00,
      rarity: 'rare',
      finishes: ['nonfoil'],
      frameEffects: [],
      rawData: {},
    ),
    CardPrintCandidate(
      setCode: 'leb',
      setName: 'Limited Edition Beta',
      collectorNumber: '232',
      imageUrl: '',
      marketPrice: 650.50,
      rarity: 'rare',
      finishes: ['nonfoil'],
      frameEffects: [],
      rawData: {},
    ),
    CardPrintCandidate(
      setCode: '2ed',
      setName: 'Unlimited Edition',
      collectorNumber: '232',
      imageUrl: '',
      marketPrice: 420.00,
      rarity: 'rare',
      finishes: ['nonfoil'],
      frameEffects: [],
      rawData: {},
    ),
    CardPrintCandidate(
      setCode: 'ced',
      setName: 'Collector\'s Edition',
      collectorNumber: '232',
      imageUrl: '',
      marketPrice: 0.0,
      rarity: 'rare',
      finishes: ['nonfoil'],
      frameEffects: [],
      rawData: {},
    ),
  ];
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('Empirical Challenge: VariantPriceChart Privacy and Non-Privacy Correctness', () {
    testWidgets('VariantPriceChart: Masks all variants to **** when privacyModeProvider is true', (tester) async {
      final item = createItem();
      final variants = createTestVariants();

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
        ],
      );
      addTearDown(container.dispose);
      container.read(privacyModeProvider.notifier).state = true;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: VariantPriceChart(
                item: item,
                initialVariants: variants,
                enableOnlineFetch: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Zero numeric price leakage across the entire widget
      final textWidgets = tester.widgetList<Text>(find.byType(Text));
      for (final t in textWidgets) {
        final content = t.data ?? '';
        expect(content.contains(r'$'), isFalse,
            reason: 'Dollar sign leaked in VariantPriceChart under privacy mode: "$content"');
        expect(content.contains('852'), isFalse,
            reason: 'Price 852 leaked in VariantPriceChart: "$content"');
        expect(content.contains('650'), isFalse,
            reason: 'Price 650 leaked in VariantPriceChart: "$content"');
        expect(content.contains('420'), isFalse,
            reason: 'Price 420 leaked in VariantPriceChart: "$content"');
      }

      // Check that **** is displayed for variants
      expect(find.text('****'), findsAtLeast(3));
    });

    testWidgets('VariantPriceChart: Renders clean prices when privacyModeProvider is false', (tester) async {
      final item = createItem();
      final variants = createTestVariants();

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
        ],
      );
      addTearDown(container.dispose);
      container.read(privacyModeProvider.notifier).state = false;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: VariantPriceChart(
                item: item,
                initialVariants: variants,
                enableOnlineFetch: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Non-privacy mode must render accurate prices and dash for zero
      expect(find.text(r'$852.00'), findsOneWidget);
      expect(find.text(r'$650.50'), findsOneWidget);
      expect(find.text(r'$420.00'), findsOneWidget);
      expect(find.text('—'), findsOneWidget); // zero price variant
      expect(find.text('****'), findsNothing);
    });

    testWidgets('VariantPriceChart: Explicit isPrivacyMode parameter takes precedence over Riverpod state', (tester) async {
      final item = createItem();
      final variants = createTestVariants();

      final container = ProviderContainer();
      addTearDown(container.dispose);
      // Riverpod is FALSE, but explicit widget.isPrivacyMode is TRUE
      container.read(privacyModeProvider.notifier).state = false;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: VariantPriceChart(
                item: item,
                initialVariants: variants,
                enableOnlineFetch: false,
                isPrivacyMode: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('****'), findsAtLeast(3));
      expect(find.text(r'$852.00'), findsNothing);

      // Now reverse: Riverpod is TRUE, but explicit widget.isPrivacyMode is FALSE
      container.read(privacyModeProvider.notifier).state = true;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: VariantPriceChart(
                item: item,
                initialVariants: variants,
                enableOnlineFetch: false,
                isPrivacyMode: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(r'$852.00'), findsOneWidget);
      expect(find.text('****'), findsNothing);
    });

    testWidgets('VariantPriceChart: Graceful execution in un-scoped environment (no ProviderScope)', (tester) async {
      final item = createItem();
      final variants = createTestVariants();

      // Test with isPrivacyMode: true without ProviderScope
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VariantPriceChart(
              item: item,
              initialVariants: variants,
              enableOnlineFetch: false,
              isPrivacyMode: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('****'), findsAtLeast(3));
      expect(find.text(r'$852.00'), findsNothing);

      // Test with isPrivacyMode: false without ProviderScope
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VariantPriceChart(
              item: item,
              initialVariants: variants,
              enableOnlineFetch: false,
              isPrivacyMode: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(r'$852.00'), findsOneWidget);

      // Test default (isPrivacyMode: null) without ProviderScope -> safely falls back to false
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VariantPriceChart(
              item: item,
              initialVariants: variants,
              enableOnlineFetch: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(r'$852.00'), findsOneWidget);
    });
  });

  group('Empirical Challenge: CardDetailSheet Full Embedded Redaction & Dynamic Toggling', () {
    testWidgets('CardDetailSheet: Embedded VariantPriceChart, header pill, and metrics are all masked under privacy mode', (tester) async {
      final item = createItem(currentMarketPrice: 852.00, acquiredPrice: 520.00);
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
        ],
      );
      addTearDown(container.dispose);
      container.read(privacyModeProvider.notifier).state = true;

      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: CardDetailSheet(
                item: item,
                fetchOnlinePrintings: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Header pill: "Market: ****"
      expect(find.text('Market: ****'), findsOneWidget);
      expect(find.text('Market: \$852.00'), findsNothing);

      // Embedded VariantPriceChart must mask current candidate price
      expect(find.text(r'$852.00'), findsNothing);

      // Scroll down to check metrics
      await tester.scrollUntilVisible(
        find.text('Acquired Price'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('****'), findsAtLeast(2));

      // Scan all visible Text widgets for zero leakage of 852 or 520
      final textWidgets = tester.widgetList<Text>(find.byType(Text));
      for (final t in textWidgets) {
        final content = t.data ?? '';
        expect(content.contains(r'$852'), isFalse,
            reason: 'CardDetailSheet leaked market price: "$content"');
        expect(content.contains(r'$520'), isFalse,
            reason: 'CardDetailSheet leaked acquired price: "$content"');
      }
    });

    testWidgets('CardDetailSheet: Dynamic toggling between privacy mode and non-privacy mode updates seamlessly', (tester) async {
      final item = createItem(currentMarketPrice: 852.00, acquiredPrice: 520.00);
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
        ],
      );
      addTearDown(container.dispose);
      // Start in Privacy Mode
      container.read(privacyModeProvider.notifier).state = true;

      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: CardDetailSheet(
                item: item,
                fetchOnlinePrintings: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Market: ****'), findsOneWidget);
      expect(find.text(r'$852.00'), findsNothing);

      // Dynamic toggle to OFF
      container.read(privacyModeProvider.notifier).state = false;
      await tester.pumpAndSettle();

      expect(find.text('Market: \$852.00'), findsOneWidget);
      expect(find.text('Market: ****'), findsNothing);
      expect(find.text(r'$852.00'), findsAtLeast(1));

      // Dynamic toggle back to ON
      container.read(privacyModeProvider.notifier).state = true;
      await tester.pumpAndSettle();

      expect(find.text('Market: ****'), findsOneWidget);
      expect(find.text('Market: \$852.00'), findsNothing);
      expect(find.text(r'$852.00'), findsNothing);
    });
  });

  group('Empirical Challenge: SwitchPrintingModal Redaction & Non-Privacy Fidelity', () {
    testWidgets('SwitchPrintingModal: Redacts active price, was-price, and candidate tile prices under privacy mode', (tester) async {
      final item = createItem(currentMarketPrice: 852.00, acquiredPrice: 520.00);

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
        ],
      );
      addTearDown(container.dispose);
      container.read(privacyModeProvider.notifier).state = true;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: SwitchPrintingModal(item: item),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify active price is masked
      expect(find.text('****'), findsAtLeast(1));
      expect(find.text(r'$852.00'), findsNothing);

      // Verify no dollar prices in text widgets
      final textWidgets = tester.widgetList<Text>(find.byType(Text));
      for (final t in textWidgets) {
        final content = t.data ?? '';
        expect(content.contains(r'$'), isFalse,
            reason: 'Dollar sign leaked in SwitchPrintingModal: "$content"');
        expect(content.contains('852'), isFalse,
            reason: 'Numeric price 852 leaked in SwitchPrintingModal: "$content"');
      }
    });

    testWidgets('SwitchPrintingModal: Renders clear prices in non-privacy mode', (tester) async {
      final item = createItem(currentMarketPrice: 852.00, acquiredPrice: 520.00);

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
        ],
      );
      addTearDown(container.dispose);
      container.read(privacyModeProvider.notifier).state = false;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: SwitchPrintingModal(item: item),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(r'$852.00'), findsAtLeast(1));
      expect(find.text('****'), findsNothing);
    });

    testWidgets('SwitchPrintingModal: Renders correctly with candidate printings', (tester) async {
      final item = createItem(currentMarketPrice: 852.00);
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: SwitchPrintingModal(item: item),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(SwitchPrintingModal), findsOneWidget);
    });
  });

  group('Empirical Challenge: ManualAddBottomSheet Redaction & Non-Privacy Fidelity', () {
    testWidgets('ManualAddBottomSheet: Zero cleartext dollar prices under privacy mode', (tester) async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
        ],
      );
      addTearDown(container.dispose);
      container.read(privacyModeProvider.notifier).state = true;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: ManualAddBottomSheet(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final textWidgets = tester.widgetList<Text>(find.byType(Text));
      for (final t in textWidgets) {
        final content = t.data ?? '';
        expect(content.contains(r'$'), isFalse,
            reason: 'Dollar sign leaked in ManualAddBottomSheet: "$content"');
      }
    });

    testWidgets('ManualAddBottomSheet: Toggles between privacy and non-privacy without leaks', (tester) async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
        ],
      );
      addTearDown(container.dispose);
      container.read(privacyModeProvider.notifier).state = false;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: ManualAddBottomSheet(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ManualAddBottomSheet), findsOneWidget);

      // Now toggle privacy mode ON
      container.read(privacyModeProvider.notifier).state = true;
      await tester.pumpAndSettle();

      final textWidgets = tester.widgetList<Text>(find.byType(Text));
      for (final t in textWidgets) {
        final content = t.data ?? '';
        expect(content.contains(r'$'), isFalse,
            reason: 'Dollar sign leaked in ManualAddBottomSheet after privacy enable: "$content"');
      }
    });
  });
}
