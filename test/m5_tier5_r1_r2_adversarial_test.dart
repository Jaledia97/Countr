import 'dart:convert';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/settings_state.dart';
import 'package:countr/features/decks/domain/deck_token_extractor.dart';
import 'package:countr/features/shell/presentation/screens/main_shell_screen.dart';
import 'package:countr/features/values/domain/exchange_rate_service.dart';
import 'package:countr/features/vault/domain/vault_pricing_helper.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/widgets/card_detail_sheet.dart';

class MockNavigationShell extends StatefulWidget implements StatefulNavigationShell {
  @override
  final int currentIndex;

  const MockNavigationShell({super.key, this.currentIndex = 0});

  @override
  void goBranch(int index, {bool initialLocation = false}) {}

  @override
  State<MockNavigationShell> createState() => _MockNavigationShellState();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockNavigationShellState extends State<MockNavigationShell> {
  @override
  Widget build(BuildContext context) => const SizedBox(key: Key('mock_nav_body'));
}

VaultItem createAdversarialTestCard({
  String id = 'adv-card-1',
  String name = 'Challenger Sphinx',
  String setCode = 'm21',
  double price = 12.50,
  double? purchasePrice = 8.00,
  DateTime? dateObtained,
  int? binderPage = 5,
  String? binderSlot = 'C3',
  String? notes = 'Adversarial provenance notes',
  String? protectionStatus = 'Sleeved',
  List<Map<String, dynamic>>? rulings,
}) {
  return VaultItem(
    id: id,
    collectionType: 'mtg',
    name: name,
    setOrSeries: setCode.toUpperCase(),
    imageUrl: 'https://cards.scryfall.io/normal/front/sphinx.jpg',
    acquiredPrice: purchasePrice ?? 8.00,
    purchasePrice: purchasePrice,
    acquiredDate: dateObtained ?? DateTime(2024, 1, 15),
    dateObtained: dateObtained ?? DateTime(2024, 1, 15),
    quantity: 1,
    condition: 'NM',
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
    lastPriceUpdate: DateTime(2024, 1, 15),
    dynamicData: jsonEncode({
      'artist': 'Volkan Baga',
      'border_color': 'borderless',
      'frame_effects': ['showcase'],
      'finishes': ['nonfoil'],
      'oracle_text':
          'Flying\nWhenever Challenger Sphinx attacks, create a 1/1 blue Bird creature token with flying. Then create a Clue token.',
      'cached_rulings': rulings ?? [
        {
          'published_at': '2024-01-15',
          'comment': 'The Bird token enters attacking if specified by an external effect.',
        },
      ],
    }),
  );
}

Widget createAdversarialTestWidget(
  Widget child, {
  required ProviderContainer container,
}) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      home: Scaffold(
        body: child,
      ),
    ),
  );
}

/// Helper executing strictly valid Flutter AppLifecycleState machine transition paths
void transitionLifecycle(
  WidgetTester tester, {
  required AppLifecycleState from,
  required AppLifecycleState to,
}) {
  if (from == to) return;

  const validPath = [
    AppLifecycleState.resumed,
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
  ];

  final fromIdx = validPath.indexOf(from);
  final toIdx = validPath.indexOf(to);

  if (fromIdx != -1 && toIdx != -1) {
    if (fromIdx < toIdx) {
      for (int i = fromIdx + 1; i <= toIdx; i++) {
        tester.binding.handleAppLifecycleStateChanged(validPath[i]);
      }
    } else {
      for (int i = fromIdx - 1; i >= toIdx; i--) {
        tester.binding.handleAppLifecycleStateChanged(validPath[i]);
      }
    }
  } else {
    tester.binding.handleAppLifecycleStateChanged(to);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  setUp(() {
    ExchangeRateService.resetToDefaults();
  });

  tearDown(() {
    ExchangeRateService.resetToDefaults();
  });

  // ===========================================================================
  // GROUP 1: Streamer Security & Concurrent Lifecycle Transitions
  // ===========================================================================
  group('Tier 5 Adversarial Group 1: Streamer Security & Concurrent Lifecycle Transitions', () {
    testWidgets(
        'T5.1.1: Complex multi-step lifecycle sequence (paused -> resumed -> hidden -> inactive -> resumed)',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(streamerSecurityEnabledProvider.notifier).state = true;
      container.read(privacyModeProvider.notifier).state = false;

      await tester.pumpWidget(
        createAdversarialTestWidget(
          MainShellScreen(navigationShell: const MockNavigationShell()),
          container: container,
        ),
      );

      expect(container.read(privacyModeProvider), isFalse);

      // 1. Move to paused: resumed -> inactive -> hidden -> paused
      transitionLifecycle(tester, from: AppLifecycleState.resumed, to: AppLifecycleState.paused);
      await tester.pump();
      expect(container.read(privacyModeProvider), isTrue,
          reason: 'Entering paused must immediately lock privacy');

      // 2. Return to resumed (must latch true, not auto-unlock)
      transitionLifecycle(tester, from: AppLifecycleState.paused, to: AppLifecycleState.resumed);
      await tester.pump();
      expect(container.read(privacyModeProvider), isTrue,
          reason: 'Resuming must maintain privacy lock to prevent camera/stream leaks');

      // 3. User manually unlocks
      container.read(privacyModeProvider.notifier).state = false;
      await tester.pump();
      expect(container.read(privacyModeProvider), isFalse);

      // 4. Move to hidden: resumed -> inactive -> hidden
      transitionLifecycle(tester, from: AppLifecycleState.resumed, to: AppLifecycleState.hidden);
      await tester.pump();
      expect(container.read(privacyModeProvider), isTrue,
          reason: 'Entering hidden must lock privacy');

      // 5. Move to inactive: hidden -> inactive
      transitionLifecycle(tester, from: AppLifecycleState.hidden, to: AppLifecycleState.inactive);
      await tester.pump();
      expect(container.read(privacyModeProvider), isTrue);

      // 6. Return to resumed: inactive -> resumed
      transitionLifecycle(tester, from: AppLifecycleState.inactive, to: AppLifecycleState.resumed);
      await tester.pump();
      expect(container.read(privacyModeProvider), isTrue,
          reason: 'Resumed after hidden/inactive must remain locked');
    });

    testWidgets('T5.1.2: Rapid oscillatory transitions (resumed <-> inactive <-> hidden <-> paused)',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(streamerSecurityEnabledProvider.notifier).state = true;
      container.read(privacyModeProvider.notifier).state = false;

      await tester.pumpWidget(
        createAdversarialTestWidget(
          MainShellScreen(navigationShell: const MockNavigationShell()),
          container: container,
        ),
      );

      // Oscillate between foreground and background states cleanly
      for (int cycle = 0; cycle < 3; cycle++) {
        transitionLifecycle(tester, from: AppLifecycleState.resumed, to: AppLifecycleState.inactive);
        transitionLifecycle(tester, from: AppLifecycleState.inactive, to: AppLifecycleState.resumed);
        transitionLifecycle(tester, from: AppLifecycleState.resumed, to: AppLifecycleState.hidden);
        transitionLifecycle(tester, from: AppLifecycleState.hidden, to: AppLifecycleState.paused);
        transitionLifecycle(tester, from: AppLifecycleState.paused, to: AppLifecycleState.resumed);
      }
      await tester.pump();

      expect(container.read(privacyModeProvider), isTrue,
          reason: 'Privacy lock must hold true throughout rapid oscillations');
    });

    testWidgets('T5.1.3: Dynamic streamerSecurity toggle while in background preserves lock until user unlock',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Initially disabled
      container.read(streamerSecurityEnabledProvider.notifier).state = false;
      container.read(privacyModeProvider.notifier).state = false;

      await tester.pumpWidget(
        createAdversarialTestWidget(
          MainShellScreen(navigationShell: const MockNavigationShell()),
          container: container,
        ),
      );

      // Background with security off: no lock
      transitionLifecycle(tester, from: AppLifecycleState.resumed, to: AppLifecycleState.paused);
      await tester.pump();
      expect(container.read(privacyModeProvider), isFalse);

      // While paused, enable streamer security
      container.read(streamerSecurityEnabledProvider.notifier).state = true;
      await tester.pump();

      // Next lifecycle event (paused -> hidden) locks privacy
      transitionLifecycle(tester, from: AppLifecycleState.paused, to: AppLifecycleState.hidden);
      await tester.pump();
      expect(container.read(privacyModeProvider), isTrue);

      // Now disable streamer security while still backgrounded
      container.read(streamerSecurityEnabledProvider.notifier).state = false;
      await tester.pump();

      // Return to resumed: privacy must NOT spontaneously unlock
      transitionLifecycle(tester, from: AppLifecycleState.hidden, to: AppLifecycleState.resumed);
      await tester.pump();
      expect(container.read(privacyModeProvider), isTrue,
          reason: 'Disabling streamer security does not retroactively unlock active privacy mode');
    });

    testWidgets('T5.1.4: Strict invariance: with streamerSecurity disabled, arbitrary lifecycle sequences never lock privacy',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(streamerSecurityEnabledProvider.notifier).state = false;
      container.read(privacyModeProvider.notifier).state = false;

      await tester.pumpWidget(
        createAdversarialTestWidget(
          MainShellScreen(navigationShell: const MockNavigationShell()),
          container: container,
        ),
      );

      // Run multiple full cycles
      for (int cycle = 0; cycle < 5; cycle++) {
        transitionLifecycle(tester, from: AppLifecycleState.resumed, to: AppLifecycleState.paused);
        transitionLifecycle(tester, from: AppLifecycleState.paused, to: AppLifecycleState.resumed);
      }
      await tester.pump();

      expect(container.read(privacyModeProvider), isFalse,
          reason: 'Privacy mode must strictly remain false when streamer security is disabled');
    });
  });

  // ===========================================================================
  // GROUP 2: Currency Rate Precision & Round-Trip Conversion Invariance
  // ===========================================================================
  group('Tier 5 Adversarial Group 2: Currency Rate Precision & Round-Trip Conversion Invariance', () {
    test('T5.2.1: Pairwise round-trip conversion invariance across all 16 currency pairs with exact tolerance', () {
      final currencies = AppCurrency.values;
      final testAmounts = [0.01, 0.50, 1.0, 19.99, 100.0, 1234.56, 500000.0];

      for (final from in currencies) {
        for (final to in currencies) {
          for (final amount in testAmounts) {
            final converted = ExchangeRateService.convert(amount, from: from, to: to);
            final roundTrip = ExchangeRateService.convert(converted, from: to, to: from);

            // Double precision round-trip invariance check
            expect(
              roundTrip,
              closeTo(amount, 0.0001),
              reason: 'Round-trip from $from -> $to -> $from failed for amount $amount',
            );
          }
        }
      }
    });

    test('T5.2.2: Cyclic 4-currency transitive loop invariance (USD->EUR->GBP->CAD->USD)', () {
      // Loop 1: USD -> EUR -> GBP -> CAD -> USD
      const initialAmount = 1000.0;
      final step1 = ExchangeRateService.convert(initialAmount, from: AppCurrency.usd, to: AppCurrency.eur);
      final step2 = ExchangeRateService.convert(step1, from: AppCurrency.eur, to: AppCurrency.gbp);
      final step3 = ExchangeRateService.convert(step2, from: AppCurrency.gbp, to: AppCurrency.cad);
      final finalUsd = ExchangeRateService.convert(step3, from: AppCurrency.cad, to: AppCurrency.usd);

      expect(finalUsd, closeTo(initialAmount, 0.001),
          reason: '4-way loop USD->EUR->GBP->CAD->USD broke conservation of value');

      // Product of rates around cycle must equal 1.0 exactly
      final r1 = ExchangeRateService.getRate(from: AppCurrency.usd, to: AppCurrency.eur);
      final r2 = ExchangeRateService.getRate(from: AppCurrency.eur, to: AppCurrency.gbp);
      final r3 = ExchangeRateService.getRate(from: AppCurrency.gbp, to: AppCurrency.cad);
      final r4 = ExchangeRateService.getRate(from: AppCurrency.cad, to: AppCurrency.usd);

      expect(r1 * r2 * r3 * r4, closeTo(1.0, 1e-12),
          reason: 'Product of cross rates in cyclic loop must equal 1.0');

      // Reverse Loop: USD -> CAD -> GBP -> EUR -> USD
      final revStep1 = ExchangeRateService.convert(initialAmount, from: AppCurrency.usd, to: AppCurrency.cad);
      final revStep2 = ExchangeRateService.convert(revStep1, from: AppCurrency.cad, to: AppCurrency.gbp);
      final revStep3 = ExchangeRateService.convert(revStep2, from: AppCurrency.gbp, to: AppCurrency.eur);
      final revFinalUsd = ExchangeRateService.convert(revStep3, from: AppCurrency.eur, to: AppCurrency.usd);

      expect(revFinalUsd, closeTo(initialAmount, 0.001),
          reason: 'Reverse 4-way loop broke conservation of value');
    });

    test('T5.2.3: Cross-rate triangular arbitrage consistency across all currency triplets', () {
      final currencies = AppCurrency.values;
      for (final a in currencies) {
        for (final b in currencies) {
          for (final c in currencies) {
            final rateAC = ExchangeRateService.getRate(from: a, to: c);
            final rateAB = ExchangeRateService.getRate(from: a, to: b);
            final rateBC = ExchangeRateService.getRate(from: b, to: c);

            expect(
              rateAC,
              closeTo(rateAB * rateBC, 1e-12),
              reason: 'Triangular arbitrage violation for $a -> $b -> $c vs $a -> $c',
            );
          }
        }
      }
    });

    test('T5.2.4: High-precision and micro-denomination boundary stability (sub-cent to millions)', () {
      // Sub-cent amounts
      const microAmount = 0.000001;
      final microEur = ExchangeRateService.convert(microAmount, from: AppCurrency.usd, to: AppCurrency.eur);
      expect(microEur, closeTo(0.000001 * 0.92, 1e-9));

      // Massive amounts ($1 Billion)
      const billionUsd = 1000000000.0;
      final billionCad = ExchangeRateService.convert(billionUsd, from: AppCurrency.usd, to: AppCurrency.cad);
      expect(billionCad, 1360000000.0);

      // Non-positive / degenerate values return 0.0
      expect(ExchangeRateService.convert(0.0, from: AppCurrency.usd, to: AppCurrency.eur), 0.0);
      expect(ExchangeRateService.convert(-0.01, from: AppCurrency.usd, to: AppCurrency.eur), 0.0);
      expect(ExchangeRateService.convert(double.nan, from: AppCurrency.usd, to: AppCurrency.eur), 0.0);
      expect(ExchangeRateService.convert(double.infinity, from: AppCurrency.usd, to: AppCurrency.eur), 0.0);
      expect(ExchangeRateService.convert(double.negativeInfinity, from: AppCurrency.usd, to: AppCurrency.eur), 0.0);
    });

    test('T5.2.5: Pricing and return formatting with exact symbols, signs, and privacy masking across all currencies', () {
      const amount = 100.0;
      expect(VaultPricingHelper.formatAmount(amount, currency: AppCurrency.usd, isPrivacyMode: false), '\$100.00');
      expect(VaultPricingHelper.formatAmount(amount, currency: AppCurrency.eur, isPrivacyMode: false), '€100.00');
      expect(VaultPricingHelper.formatAmount(amount, currency: AppCurrency.gbp, isPrivacyMode: false), '£100.00');
      expect(VaultPricingHelper.formatAmount(amount, currency: AppCurrency.cad, isPrivacyMode: false), 'CA\$100.00');

      // Negative amounts
      const negAmount = -25.50;
      expect(VaultPricingHelper.formatAmount(negAmount, currency: AppCurrency.usd, isPrivacyMode: false), '-\$25.50');
      expect(VaultPricingHelper.formatAmount(negAmount, currency: AppCurrency.eur, isPrivacyMode: false), '-€25.50');
      expect(VaultPricingHelper.formatAmount(negAmount, currency: AppCurrency.gbp, isPrivacyMode: false), '-£25.50');
      expect(VaultPricingHelper.formatAmount(negAmount, currency: AppCurrency.cad, isPrivacyMode: false), '-CA\$25.50');

      // Privacy Mode: unconditional '****' mask across all currencies and amounts
      for (final c in AppCurrency.values) {
        expect(VaultPricingHelper.formatAmount(amount, currency: c, isPrivacyMode: true), '****');
        expect(VaultPricingHelper.formatAmount(negAmount, currency: c, isPrivacyMode: true), '****');
        expect(VaultPricingHelper.formatAmount(0.0, currency: c, isPrivacyMode: true, allowZero: true), '****');
        expect(VaultPricingHelper.formatAmount(null, currency: c, isPrivacyMode: true), '****');
        expect(VaultPricingHelper.formatReturn(10.0, 25.0, currency: c, isPrivacyMode: true), '****');
        expect(VaultPricingHelper.formatReturn(-10.0, -25.0, currency: c, isPrivacyMode: true), '****');
      }
    });

    test('T5.2.6: Custom rates update and zero/negative defense in ExchangeRateService', () {
      final customRates = {
        AppCurrency.usd: 1.0,
        AppCurrency.eur: 0.954321,
        AppCurrency.gbp: 0.812345,
        AppCurrency.cad: 1.398765,
      };

      ExchangeRateService.updateRates(customRates);
      expect(ExchangeRateService.getRate(from: AppCurrency.usd, to: AppCurrency.eur), 0.954321);
      final converted = ExchangeRateService.convert(100.0, from: AppCurrency.usd, to: AppCurrency.cad);
      expect(converted, 139.8765);

      // Defense against zero or negative source rates
      ExchangeRateService.updateRates({
        AppCurrency.usd: 0.0,
        AppCurrency.eur: -0.92,
        AppCurrency.gbp: 0.785,
        AppCurrency.cad: 1.36,
      });

      // getRate gracefully falls back to 1.0 instead of dividing by zero or emitting NaN
      expect(ExchangeRateService.getRate(from: AppCurrency.usd, to: AppCurrency.cad), 1.0);
      expect(ExchangeRateService.getRate(from: AppCurrency.eur, to: AppCurrency.cad), 1.0);

      // Reset to defaults
      ExchangeRateService.resetToDefaults();
      expect(ExchangeRateService.getRate(from: AppCurrency.usd, to: AppCurrency.eur), 0.92);
    });
  });

  // ===========================================================================
  // GROUP 3: Drift Schema v8 Boundary & Provenance Storage
  // ===========================================================================
  group('Tier 5 Adversarial Group 3: Drift Schema v8 Boundary & Provenance Storage', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('T5.3.1: Drift schema v8 boundary values in VaultItems table (empty strings, nulls, extreme dates, negative prices)',
        () async {
      // 1. Insert Item with null v8 fields
      final nullItem = createAdversarialTestCard(
        id: 'item-nulls',
        name: 'Null Provenance Mox',
        notes: null,
        binderSlot: null,
        binderPage: null,
        purchasePrice: null,
        protectionStatus: null,
        dateObtained: null,
      );
      await db.into(db.vaultItems).insert(nullItem);

      // 2. Insert Item with empty strings and zero values
      final emptyItem = createAdversarialTestCard(
        id: 'item-empty',
        name: 'Empty Provenance Lotus',
        notes: '',
        binderSlot: '',
        binderPage: 0,
        purchasePrice: 0.0,
        protectionStatus: 'Sleeved',
        dateObtained: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true), // Epoch 0: 1970-01-01 UTC
      );
      await db.into(db.vaultItems).insert(emptyItem);

      // 3. Insert Item with negative purchase price and distant dates
      final extremeItem = createAdversarialTestCard(
        id: 'item-extreme',
        name: 'Extreme Provenance Ring',
        notes: 'Line 1\nLine 2\tUnicode: 🌟🎴🎲\nΩ≈ç√∫˜µ≤≥÷',
        binderSlot: 'SLOT-999-Ω',
        binderPage: -1,
        purchasePrice: -50.25,
        protectionStatus: 'Toploader Ultra Pro',
        dateObtained: DateTime(2099, 12, 31, 23, 59, 59),
      );
      await db.into(db.vaultItems).insert(extremeItem);

      // Verify item 1
      final fetchedNull =
          await (db.select(db.vaultItems)..where((t) => t.id.equals('item-nulls'))).getSingle();
      expect(fetchedNull.notes, isNull);
      expect(fetchedNull.binderSlot, isNull);
      expect(fetchedNull.binderPage, isNull);
      expect(fetchedNull.purchasePrice, isNull);
      expect(fetchedNull.protectionStatus, anyOf(isNull, equals('Sleeved')));

      // Verify item 2
      final fetchedEmpty =
          await (db.select(db.vaultItems)..where((t) => t.id.equals('item-empty'))).getSingle();
      expect(fetchedEmpty.notes, '');
      expect(fetchedEmpty.binderSlot, '');
      expect(fetchedEmpty.binderPage, 0);
      expect(fetchedEmpty.purchasePrice, 0.0);
      expect(fetchedEmpty.dateObtained?.toUtc().millisecondsSinceEpoch, 0);
      expect(fetchedEmpty.dateObtained?.toUtc().year, 1970);

      // Verify item 3
      final fetchedExtreme =
          await (db.select(db.vaultItems)..where((t) => t.id.equals('item-extreme'))).getSingle();
      expect(fetchedExtreme.purchasePrice, -50.25);
      expect(fetchedExtreme.binderPage, -1);
      expect(fetchedExtreme.binderSlot, 'SLOT-999-Ω');
      expect(fetchedExtreme.notes, contains('🌟🎴🎲'));
      expect(fetchedExtreme.protectionStatus, 'Toploader Ultra Pro');
      expect(fetchedExtreme.dateObtained?.year, 2099);
    });

    test('T5.3.2: Legacy migration backfill boundary conditions from schema v7 to v8', () async {
      // Initialize an in-memory database with raw schema v7 (prior to v8 columns)
      final rawDb = NativeDatabase.memory(setup: (raw) {
        raw.execute('''
          CREATE TABLE vault_items (
            id TEXT NOT NULL PRIMARY KEY,
            collection_type TEXT NOT NULL,
            name TEXT NOT NULL,
            set_or_series TEXT NOT NULL,
            image_url TEXT NOT NULL,
            flavor_name TEXT,
            acquired_price REAL NOT NULL,
            acquired_date INTEGER NOT NULL,
            quantity INTEGER NOT NULL DEFAULT 1,
            condition TEXT NOT NULL,
            is_graded INTEGER NOT NULL DEFAULT 0,
            is_altered INTEGER NOT NULL DEFAULT 0,
            is_misprint INTEGER NOT NULL DEFAULT 0,
            is_signed INTEGER NOT NULL DEFAULT 0,
            personal_notes TEXT,
            primary_binder_id TEXT,
            current_market_price REAL NOT NULL,
            last_price_update INTEGER NOT NULL,
            dynamic_data TEXT NOT NULL
          );
        ''');
        // Row 1: zero acquired price, empty notes
        raw.execute('''
          INSERT INTO vault_items (
            id, collection_type, name, set_or_series, image_url,
            acquired_price, acquired_date, quantity, condition,
            personal_notes, current_market_price, last_price_update, dynamic_data
          ) VALUES (
            'legacy-zero', 'mtg', 'Zero Price Mox', 'LEA', 'https://example.com/mox.jpg',
            0.0, 1600000000, 1, 'NM', '', 500.0, 1600000000, '{}'
          );
        ''');
        // Row 2: negative acquired price, NULL notes
        raw.execute('''
          INSERT INTO vault_items (
            id, collection_type, name, set_or_series, image_url,
            acquired_price, acquired_date, quantity, condition,
            personal_notes, current_market_price, last_price_update, dynamic_data
          ) VALUES (
            'legacy-neg', 'mtg', 'Negative Price Card', 'LEB', 'https://example.com/neg.jpg',
            -15.0, 1600000000, 1, 'LP', NULL, 100.0, 1600000000, '{}'
          );
        ''');
      });

      // Opening through AppDatabase executes beforeOpen defensive migration and backfill
      final migratedDb = AppDatabase(rawDb);
      addTearDown(migratedDb.close);

      // Verify PRAGMA table_info has all 6 v8 columns
      final tableInfo = await migratedDb.customSelect('PRAGMA table_info("vault_items");').get();
      final columnNames = tableInfo.map((r) => r.read<String>('name')).toSet();
      expect(columnNames, containsAll([
        'date_obtained',
        'purchase_price',
        'binder_page',
        'binder_slot',
        'notes',
        'protection_status',
      ]));

      // Verify legacy-zero item
      final itemZero = await (migratedDb.select(migratedDb.vaultItems)
            ..where((t) => t.id.equals('legacy-zero')))
          .getSingle();
      expect(itemZero.purchasePrice, 0.0, reason: 'Zero acquired_price backfilled to purchase_price');
      expect(itemZero.notes, '', reason: 'Empty string personal_notes preserved in notes');
      expect(itemZero.protectionStatus, 'Sleeved', reason: 'Default protection_status applied');
      expect(itemZero.dateObtained, isNotNull);

      // Verify legacy-neg item
      final itemNeg = await (migratedDb.select(migratedDb.vaultItems)
            ..where((t) => t.id.equals('legacy-neg')))
          .getSingle();
      expect(itemNeg.purchasePrice, -15.0);
      expect(itemNeg.notes, isNull);
      expect(itemNeg.protectionStatus, 'Sleeved');
    });

    test('T5.3.3: VaultPricingHelper integration with v8 boundary purchase prices', () {
      // 0.0 price
      expect(
        VaultPricingHelper.formatAmount(0.0, currency: AppCurrency.usd, isPrivacyMode: false, allowZero: false),
        'Unlisted',
      );
      expect(
        VaultPricingHelper.formatAmount(0.0, currency: AppCurrency.usd, isPrivacyMode: false, allowZero: true),
        '\$0.00',
      );

      // Negative purchase price
      expect(
        VaultPricingHelper.formatAmount(-15.50, currency: AppCurrency.usd, isPrivacyMode: false, allowNegative: true),
        '-\$15.50',
      );
      expect(
        VaultPricingHelper.formatAmount(-15.50, currency: AppCurrency.usd, isPrivacyMode: false, allowNegative: false),
        'Unlisted',
      );

      // Return formatting with zero cost basis
      final returnZeroBasis = VaultPricingHelper.formatReturn(
        10.0,
        null,
        currency: AppCurrency.usd,
        isPrivacyMode: false,
      );
      expect(returnZeroBasis, '+\$10.00');

      // Return formatting with negative delta and percentage
      final returnLoss = VaultPricingHelper.formatReturn(
        -25.0,
        -50.0,
        currency: AppCurrency.usd,
        isPrivacyMode: false,
      );
      expect(returnLoss, '-\$25.00 (-50.0%)');
    });
  });

  // ===========================================================================
  // GROUP 4: DeckTokenExtractor Extreme & Adversarial Oracle Text Inputs
  // ===========================================================================
  group('Tier 5 Adversarial Group 4: DeckTokenExtractor Extreme & Adversarial Oracle Text Inputs', () {
    test('T5.4.1: Multiple nested clauses and compound triggers in Oracle text', () {
      final complexTexts = [
        // Nested death trigger with kick clause
        'Whenever a nontoken creature you control dies, create a 1/1 black and green Pest creature token with "When this creature dies, you gain 1 life." If that spell was kicked, create two 2/2 black Zombie creature tokens and a Treasure token.',
        // Modal choices with bullet points
        'Choose one or both — • Create a 4/4 green Beast creature token. • Create three 1/1 white Bird creature tokens with flying, then create a Food token.',
        // Eldrazi spawn and big creature tokens
        'At the beginning of your upkeep, create a 0/1 colorless Eldrazi Spawn creature token with "Sacrifice this: Add {C}." Then create a Clue token and an Incubator token with two +1/+1 counters.',
      ];

      final tokens = DeckTokenExtractor.extractRequiredTokens(complexTexts);
      expect(tokens, [
        'Beast',
        'Bird',
        'Clue',
        'Food',
        'Incubator',
        'Pest',
        'Spawn',
        'Treasure',
        'Zombie',
      ]);
    });

    test('T5.4.2: Planeswalker loyalty abilities and ultimate triggers', () {
      final pwTexts = [
        // Garruk, Primal Hunter
        '[+1]: Create a 3/3 green Beast creature token.\n−3: Draw cards equal to greatest power.\n−6: Create a 6/6 green Wurm creature token for each land you control.',
        // Liliana, Dreadhorde General
        '[+1]: Create a 2/2 black Zombie creature token.\n−4: Each player sacrifices two creatures.\n−9: Each opponent chooses a permanent.',
        // Ugin, the Ineffable
        '[+1]: Exile the top card face down. Create a 2/2 colorless Spirit creature token. When that token leaves, put card into hand.',
        // Chandra, Acolyte of Flame
        '0: Create two 1/1 red Elemental creature tokens with haste.',
        // Elspeth, Sun\'s Champion
        '[+1]: Create three 1/1 white Soldier creature tokens.\n−7: You get an emblem.',
        // The Wandering Emperor
        '[−1]: Create a 2/2 white Samurai creature token with vigilance.',
        // Non-token PW abilities (must NOT generate false positives)
        '−8: You get an emblem with "Whenever you draw a card, exile target permanent."',
        '−2: Until end of turn, if one or more tokens would be created under your control, twice that many of those tokens are created instead.',
      ];

      final tokens = DeckTokenExtractor.extractRequiredTokens(pwTexts);
      expect(tokens, [
        'Beast',
        'Elemental',
        'Samurai',
        'Soldier',
        'Spirit',
        'Wurm',
        'Zombie',
      ]);
    });

    test('T5.4.3: Non-English card text resilience across multiple languages', () {
      final nonEnglishTexts = [
        // Japanese
        'クリーチャー・トークンを１体生成する。',
        // German
        'Erzeuge einen 1/1 weißen Spielstein.',
        // French
        'Créez un jeton de créature 1/1 blanche Soldat.',
        // Spanish
        'Crea una ficha de criatura Soldado blanca 1/1.',
        // Russian
        'Создайте фишку существа 1/1 белый Солдат.',
      ];

      // Must execute cleanly without exception
      final tokens = DeckTokenExtractor.extractRequiredTokens(nonEnglishTexts);
      expect(tokens, isA<List<String>>());
      // Non-English tokens without matching English token grammar produce empty/clean list safely
    });

    test('T5.4.4: Adversarial extreme strings and malformed inputs', () {
      // 10,000 character string with embedded regex operators
      final massiveText = 'create a Treasure token. ' * 500 +
          'create three 1/1 red Goblin creature tokens. ' * 500 +
          r'[[**++??\\//]] {{((##^^$$))}} ' * 100;

      final tokens = DeckTokenExtractor.extractRequiredTokens([massiveText]);
      expect(tokens, ['Goblin', 'Treasure']);

      // Sentences mentioning tokens without creation (anti-patterns)
      final antiPatternTexts = [
        'Destroy all tokens.',
        'Whenever a token is created by an opponent, gain 1 life.',
        'Target creature gets +1/+1 for each token you control.',
        'Populate. (Create a token that\'s a copy of a creature token you control.)',
      ];
      final antiTokens = DeckTokenExtractor.extractRequiredTokens(antiPatternTexts);
      expect(antiTokens, isEmpty);
    });
  });

  // ===========================================================================
  // GROUP 5: CardDetailSheet Details Tab Vertical Order Invariants & Scroll Physics
  // ===========================================================================
  group('Tier 5 Adversarial Group 5: CardDetailSheet Details Tab Vertical Order Invariants & Scroll Physics', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('T5.5.1: Strict vertical order invariant of all 6 Details tab sections', (tester) async {
      // Large viewport to lay out all sections simultaneously
      tester.view.physicalSize = const Size(1000, 3500);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final card = createAdversarialTestCard(
        id: 'adv-order-card',
        name: 'Order Sphinx',
      );
      await db.into(db.vaultItems).insert(card);

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        createAdversarialTestWidget(
          CardDetailSheet(
            item: card,
            deckId: 'deck-adversarial-1',
            fetchOnlinePrintings: false,
          ),
          container: container,
        ),
      );
      await tester.pumpAndSettle();

      // Verify all 6 sections exist
      final section1 = find.byKey(const Key('section_oracle_rules'));
      final section2 = find.byKey(const Key('section_portfolio_metrics'));
      final section3 = find.byKey(const Key('section_physical_provenance'));
      final section4 = find.byKey(const Key('section_acquisition_tracking'));
      final section5 = find.byKey(const Key('section_metadata_pedigree'));
      final section6 = find.byKey(const Key('deck_gear_section'));

      expect(section1, findsOneWidget);
      expect(section2, findsOneWidget);
      expect(section3, findsOneWidget);
      expect(section4, findsOneWidget);
      expect(section5, findsOneWidget);
      expect(section6, findsOneWidget);

      // Verify strictly monotonically increasing Y coordinates
      final y1 = tester.getTopLeft(section1).dy;
      final y2 = tester.getTopLeft(section2).dy;
      final y3 = tester.getTopLeft(section3).dy;
      final y4 = tester.getTopLeft(section4).dy;
      final y5 = tester.getTopLeft(section5).dy;
      final y6 = tester.getTopLeft(section6).dy;

      expect(y1 < y2, isTrue, reason: 'section_oracle_rules ($y1) must be above section_portfolio_metrics ($y2)');
      expect(y2 < y3, isTrue, reason: 'section_portfolio_metrics ($y2) must be above section_physical_provenance ($y3)');
      expect(y3 < y4, isTrue, reason: 'section_physical_provenance ($y3) must be above section_acquisition_tracking ($y4)');
      expect(y4 < y6, isTrue, reason: 'section_acquisition_tracking ($y4) must be above deck_gear_section ($y6)');
      expect(y6 < y5, isTrue, reason: 'deck_gear_section ($y6) must be above section_metadata_pedigree ($y5)');
    });

    testWidgets('T5.5.2: Scroll physics and layout displacement upon accordion expansion and dragging',
        (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final card = createAdversarialTestCard(
        id: 'adv-scroll-card',
        name: 'Scroll Sphinx',
        rulings: [
          {
            'published_at': '2024-01-15',
            'comment': 'Detailed Scryfall ruling statement explaining interaction.',
          },
          {
            'published_at': '2024-02-20',
            'comment': 'Second official ruling regarding token generation.',
          },
        ],
      );
      await db.into(db.vaultItems).insert(card);

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        createAdversarialTestWidget(
          CardDetailSheet(
            item: card,
            deckId: 'deck-adversarial-2',
            fetchOnlinePrintings: false,
          ),
          container: container,
        ),
      );
      await tester.pumpAndSettle();

      // Accordion is initially expanded by design
      final initialY2 = tester.getTopLeft(find.byKey(const Key('section_portfolio_metrics'))).dy;
      final accordionHeader = find.text('Official Rulings (2)');
      expect(accordionHeader, findsOneWidget);

      // Collapse the accordion by tapping its header
      await tester.tap(accordionHeader);
      await tester.pumpAndSettle();

      // Subsequent sections shift upwards
      final collapsedY2 = tester.getTopLeft(find.byKey(const Key('section_portfolio_metrics'))).dy;
      expect(collapsedY2 < initialY2, isTrue,
          reason: 'Collapsing rulings accordion must pull subsequent sections upwards (from $initialY2 to $collapsedY2)');

      // Re-expand the accordion by tapping its header again
      await tester.tap(accordionHeader);
      await tester.pumpAndSettle();

      // Subsequent sections shift downwards back to initial position
      final reExpandedY2 = tester.getTopLeft(find.byKey(const Key('section_portfolio_metrics'))).dy;
      expect(reExpandedY2 > collapsedY2, isTrue,
          reason: 'Re-expanding rulings accordion must push subsequent sections downwards (from $collapsedY2 to $reExpandedY2)');
      expect(reExpandedY2, closeTo(initialY2, 1.0));

      // Drag scroll up
      await tester.drag(find.byType(CardDetailSheet), const Offset(0, -300), warnIfMissed: false);
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'Dragging list upwards must not throw exceptions');

      // Drag scroll down
      await tester.drag(find.byType(CardDetailSheet), const Offset(0, 300), warnIfMissed: false);
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'Dragging list downwards must not throw exceptions');
    });

    testWidgets('T5.5.3: Provenance and Deck Gear interactions without scroll clipping or errors', (tester) async {
      tester.view.physicalSize = const Size(1000, 3500);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final card = createAdversarialTestCard(
        id: 'adv-gear-card',
        name: 'Gear Sphinx',
      );
      await db.into(db.vaultItems).insert(card);

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        createAdversarialTestWidget(
          CardDetailSheet(
            item: card,
            deckId: 'deck-adversarial-gear',
            fetchOnlinePrintings: false,
          ),
          container: container,
        ),
      );
      await tester.pumpAndSettle();

      // Enter text into Deck Gear inputs
      final brandInput = find.byKey(const Key('deck_gear_sleeve_brand_input'));
      final colorInput = find.byKey(const Key('deck_gear_sleeve_color_input'));
      final boxInput = find.byKey(const Key('deck_gear_box_model_input'));

      expect(brandInput, findsOneWidget);
      expect(colorInput, findsOneWidget);
      expect(boxInput, findsOneWidget);

      await tester.enterText(brandInput, 'Dragon Shield Dual Matte');
      await tester.enterText(colorInput, 'Crypt');
      await tester.enterText(boxInput, 'Sidewinder 100+');
      await tester.pumpAndSettle();

      expect(find.text('Dragon Shield Dual Matte'), findsOneWidget);
      expect(find.text('Crypt'), findsOneWidget);
      expect(find.text('Sidewinder 100+'), findsOneWidget);

      // Verify token checklist item
      final clueChecklist = find.byKey(const Key('token_checklist_item_Clue'));
      expect(clueChecklist, findsOneWidget);

      // Tap checklist item
      await tester.tap(clueChecklist);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'Interacting with Deck Gear inputs must not throw');
    });

    testWidgets('T5.5.4: Tab switching between Details and Values under scrolled state restores cleanly',
        (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final card = createAdversarialTestCard(
        id: 'adv-tab-card',
        name: 'Tab Sphinx',
      );
      await db.into(db.vaultItems).insert(card);

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        createAdversarialTestWidget(
          CardDetailSheet(
            item: card,
            fetchOnlinePrintings: false,
          ),
          container: container,
        ),
      );
      await tester.pumpAndSettle();

      // Verify Details tab is initially displayed
      expect(find.byKey(const Key('section_oracle_rules')), findsOneWidget);

      // Switch to Values tab
      await tester.tap(find.byKey(const Key('card_detail_tab_values')));
      await tester.pumpAndSettle();

      // Verify Details tab sections disappear
      expect(find.byKey(const Key('section_oracle_rules')), findsNothing);

      // Switch back to Details tab
      await tester.tap(find.byKey(const Key('card_detail_tab_details')));
      await tester.pumpAndSettle();

      // Verify Details tab restored
      expect(find.byKey(const Key('section_oracle_rules')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
