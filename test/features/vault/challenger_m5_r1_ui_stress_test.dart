// Copyright (c) 2026 Countr. All rights reserved.
// Challenger M5-R1-2 (Replacement): Empirical UI & Interaction Stress Suite
//
// Verification Scope:
// 1. 320px viewport with 2.0x font scaling:
//    - CardDetailSheet under 320x640 with TextScaler.linear(2.0).
//    - Verify ZERO RenderFlex overflows occur across top-to-bottom scroll.
//    - Verify 10-format Legalities grid and Treatments chips wrap or ellipsize cleanly.
// 2. Privacy mode masking:
//    - Verify finish chips render masked prices (****) when privacy mode is active.
//    - Formatted prices ($XX.XX) when inactive.
//    - Dynamic reactive toggling (false -> true -> false).
//    - Modal masking in VersionsAndPrintingsModal.
// 3. Rapid finish switching (burst tapping):
//    - High-frequency successive taps across finish chips.
//    - Verification of zero race conditions, database state integrity, and no unmount crashes.
//    - Unowned card optimistic switching without SQLite errors.
// 4. VersionsAndPrintingsModal lifecycle & navigation:
//    - Lazy opening via Key('card_detail_see_more_versions_button').
//    - Versions and Printings tab switching.
//    - Upper-left Back Button (Key('versions_printings_back_button')) dismisses cleanly.
//    - Tapping current active printing dismisses modal without pushing duplicate routes.
//    - Tapping alternative printing pushes distinct CardDetailSheet page.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/settings_state.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/widgets/card_detail_sheet.dart';
import 'package:countr/features/vault/presentation/widgets/versions_printings_modal.dart';

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
    String id = 'owned-ring-001',
    String name = 'The One Ring',
    String setCode = 'ltr',
    String setName = 'The Lord of the Rings: Tales of Middle-earth',
    String collectorNumber = '0269',
    double price = 65.00,
    int quantity = 1,
    List<String> finishes = const [
      'nonfoil',
      'foil',
      'etched',
      'surgefoil',
      'textured',
    ],
    Map<String, dynamic>? pricesMap,
    Map<String, dynamic>? legalitiesMap,
  }) {
    return VaultItem(
      id: id,
      collectionType: 'mtg',
      name: name,
      setOrSeries: setName,
      imageUrl: 'https://cards.scryfall.io/normal/front/ltr/0269.jpg',
      acquiredPrice: price,
      acquiredDate: DateTime(2023, 6, 23),
      quantity: quantity,
      condition: 'NM',
      isGraded: false,
      isAltered: false,
      isMisprint: false,
      isSigned: false,
      isDeleted: false,
      currentMarketPrice: price,
      lastPriceUpdate: DateTime(2023, 6, 23),
      dynamicData: jsonEncode({
        'collector_number': collectorNumber,
        'set': setCode.toLowerCase(),
        'set_name': setName,
        'oracle_text':
            'Indestructible\nWhen The One Ring enters the battlefield, if you cast it, you gain protection from everything until your next turn.\nAt the beginning of your upkeep, you lose 1 life for each burden counter on The One Ring.\n{T}: Put a burden counter on The One Ring, then draw a card for each burden counter on The One Ring.',
        'flavor_text': 'One Ring to rule them all, One Ring to find them...',
        'artist': 'Tania Sanchez Fortun',
        'type_line': 'Legendary Artifact',
        'finishes': finishes,
        'prices': pricesMap ?? {
          'usd': '65.00',
          'usd_foil': '95.00',
          'usd_etched': '120.00',
          'usd_surge': '250.00',
          'usd_textured': '350.00',
        },
        'finish': 'nonfoil',
        'treatment': 'Non-Foil',
        'legalities': legalitiesMap ?? {
          'commander': 'legal',
          'standard': 'not_legal',
          'modern': 'legal',
          'pioneer': 'not_legal',
          'legacy': 'legal',
          'vintage': 'restricted',
          'pauper': 'not_legal',
          'brawl': 'legal',
          'oathbreaker': 'legal',
          'historic': 'banned',
        },
      }),
    );
  }

  VaultItem createCatalogVariant({
    required String id,
    required String name,
    required String setCode,
    required String setName,
    required String collectorNumber,
    required double price,
    String? borderColor,
    List<String> frameEffects = const [],
    List<String> finishes = const ['nonfoil', 'foil'],
  }) {
    return VaultItem(
      id: id,
      collectionType: 'mtg',
      name: name,
      setOrSeries: setName,
      imageUrl: 'https://cards.scryfall.io/normal/front/$setCode/$collectorNumber.jpg',
      acquiredPrice: price,
      acquiredDate: DateTime(2023, 6, 23),
      quantity: 0,
      condition: 'NM',
      isGraded: false,
      isAltered: false,
      isMisprint: false,
      isSigned: false,
      isDeleted: false,
      currentMarketPrice: price,
      lastPriceUpdate: DateTime(2023, 6, 23),
      dynamicData: jsonEncode({
        'collector_number': collectorNumber,
        'set': setCode.toLowerCase(),
        'set_name': setName,
        'border_color': borderColor,
        'frame_effects': frameEffects,
        'finishes': finishes,
        'prices': {'usd': price.toStringAsFixed(2)},
        'legalities': {
          'commander': 'legal',
          'modern': 'legal',
          'legacy': 'legal',
          'vintage': 'restricted',
        },
      }),
    );
  }

  Widget createHarness({
    required Widget child,
    StateProvider<bool>? dynamicPrivacyProvider,
    bool staticPrivacyMode = false,
    Size viewportSize = const Size(800, 2600),
    TextScaler textScaler = TextScaler.noScaling,
  }) {
    return ProviderScope(
      key: UniqueKey(),
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        vaultDaoProvider.overrideWithValue(db.vaultDao),
        if (dynamicPrivacyProvider != null)
          privacyModeProvider.overrideWith((ref) => ref.watch(dynamicPrivacyProvider))
        else
          privacyModeProvider.overrideWith((ref) => staticPrivacyMode),
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

  Future<void> scrollDownUntil(WidgetTester tester, Finder finder, {int maxDrags = 12}) async {
    final scrollable = find.byType(Scrollable).last;
    for (int i = 0; i < maxDrags; i++) {
      if (finder.evaluate().isNotEmpty) return;
      await tester.drag(scrollable, const Offset(0, -320));
      await tester.pumpAndSettle();
    }
  }

  // ===========================================================================
  // Requirement 1: 320px Viewport with 2.0x Font Scaling Stress Testing
  // ===========================================================================
  group('1. 320px Viewport & 2.0x Font Scaling Constraint Stress', () {
    testWidgets(
      'Render CardDetailSheet with 10-format Legalities grid and Treatments chips at 320x640 with 2.0x font scaling without RenderFlex overflows',
      (tester) async {
        // Enforce physical constraints for 320x640 logical screen
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final card = createTestCard();
        await db.into(db.vaultItems).insert(card);

        final List<FlutterErrorDetails> recordedErrors = [];
        final oldOnError = FlutterError.onError;
        FlutterError.onError = (FlutterErrorDetails details) {
          recordedErrors.add(details);
          oldOnError?.call(details);
        };
        addTearDown(() => FlutterError.onError = oldOnError);

        await tester.pumpWidget(
          createHarness(
            child: CardDetailSheet(item: card, fetchOnlinePrintings: false),
            viewportSize: const Size(320, 640),
            textScaler: const TextScaler.linear(2.0),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Initial render verification
        expect(tester.takeException(), isNull);
        expect(find.byType(CardDetailSheet), findsOneWidget);

        // 2. Scroll down until Treatments section is visible
        final treatmentsFinder = find.byKey(const Key('section_variant_price_chart'));
        await scrollDownUntil(tester, treatmentsFinder);
        expect(treatmentsFinder, findsOneWidget);
        expect(find.text('Treatments'), findsOneWidget);

        // Verify treatment chips are present
        expect(find.byKey(const Key('treatment_chip_nonfoil')), findsOneWidget);
        expect(find.byKey(const Key('treatment_chip_foil')), findsOneWidget);
        expect(find.byKey(const Key('treatment_chip_etched')), findsOneWidget);

        // Verify [See More Versions & Printings] button is rendered
        final seeMoreButton = find.byKey(const Key('card_detail_see_more_versions_button'));
        expect(seeMoreButton, findsOneWidget);

        // Scroll down until Section 8 Format Legalities is visible
        final legalitiesFinder = find.byKey(const Key('section_format_legalities'));
        await scrollDownUntil(tester, legalitiesFinder);
        expect(legalitiesFinder, findsOneWidget);
        expect(find.text('Format Legalities'), findsOneWidget);

        // Verify all 10 major format legalities pills exist
        final expectedFormats = [
          'commander',
          'standard',
          'modern',
          'pioneer',
          'legacy',
          'vintage',
          'pauper',
          'brawl',
          'oathbreaker',
          'historic',
        ];

        for (final slug in expectedFormats) {
          final pillFinder = find.byKey(Key('legality_pill_$slug'));
          expect(pillFinder, findsOneWidget, reason: 'Legality pill for $slug must be rendered');

          // Verify format pill layout bounding box is fully contained within 320px width
          final pillRect = tester.getRect(pillFinder);
          expect(pillRect.left, greaterThanOrEqualTo(0.0));
          expect(pillRect.right, lessThanOrEqualTo(320.0 + 1.0)); // allow fractional subpixel rounding
        }

        // Scroll to Section 9 Metadata & Pedigree at the bottom
        final metadataFinder = find.byKey(const Key('section_metadata_pedigree'));
        await scrollDownUntil(tester, metadataFinder);
        expect(metadataFinder, findsOneWidget);
        expect(find.byKey(const Key('card_detail_collector_number')), findsOneWidget);

        // 3. ZERO RenderFlex overflow errors occurred throughout entire scroll journey
        final overflowErrors = recordedErrors
            .where((e) => e.toString().toLowerCase().contains('overflowed'))
            .toList();
        for (final err in overflowErrors) {
          final lines = err.toString().split('\n');
          final relevant = lines.firstWhere((l) => l.contains('Row:') || l.contains('Column:') || l.contains('.dart:'), orElse: () => lines.first);
          debugPrint('>>> OVERFLOW: ${err.exception} -> $relevant');
        }
        expect(
          overflowErrors,
          isEmpty,
          reason: 'Expected 0 RenderFlex overflow errors, but found: ${overflowErrors.map((e) => e.exception).toList()}',
        );
      },
    );

    testWidgets(
      'Adversarial test: Extreme prices and long status labels scale down and wrap cleanly under 320px',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        // Card with extreme 5-figure prices and all 10 formats set to 'restricted' (longest label)
        final extremeCard = createTestCard(
          price: 99999.00,
          pricesMap: {
            'usd': '99999.00',
            'usd_foil': '149999.00',
            'usd_etched': '199999.00',
            'usd_surge': '249999.00',
            'usd_textured': '349999.00',
          },
          legalitiesMap: {
            'commander': 'restricted',
            'standard': 'restricted',
            'modern': 'restricted',
            'pioneer': 'restricted',
            'legacy': 'restricted',
            'vintage': 'restricted',
            'pauper': 'restricted',
            'brawl': 'restricted',
            'oathbreaker': 'restricted',
            'historic': 'restricted',
          },
        );
        await db.into(db.vaultItems).insert(extremeCard);

        await tester.pumpWidget(
          createHarness(
            child: CardDetailSheet(item: extremeCard, fetchOnlinePrintings: false),
            viewportSize: const Size(320, 640),
            textScaler: const TextScaler.linear(2.0),
          ),
        );
        await tester.pumpAndSettle();

        // Scroll to treatments
        final treatmentsFinder = find.byKey(const Key('section_variant_price_chart'));
        await scrollDownUntil(tester, treatmentsFinder);
        expect(treatmentsFinder, findsOneWidget);

        // Verify chips wrap and render extreme prices without overflow
        expect(find.byKey(const Key('treatment_chip_nonfoil')), findsOneWidget);
        expect(find.byKey(const Key('treatment_chip_foil')), findsOneWidget);
        expect(find.text('\$99999.00'), findsWidgets);

        // Scroll to legalities
        final legalitiesFinder = find.byKey(const Key('section_format_legalities'));
        await scrollDownUntil(tester, legalitiesFinder);
        expect(legalitiesFinder, findsOneWidget);

        // All 10 pills render 'Restricted'
        final restrictedFinders = find.text('Restricted');
        expect(restrictedFinders, findsNWidgets(10));

        expect(tester.takeException(), isNull);
      },
    );
  });

  // ===========================================================================
  // Requirement 2: Privacy Mode Masking Stress Testing
  // ===========================================================================
  group('2. Privacy Mode Price Masking Suite', () {
    testWidgets(
      r'Finish chips render formatted prices ($XX.XX) when privacy mode is inactive',
      (tester) async {
        tester.view.physicalSize = const Size(800, 2600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final card = createTestCard();
        await db.into(db.vaultItems).insert(card);

        await tester.pumpWidget(
          createHarness(
            child: CardDetailSheet(item: card, fetchOnlinePrintings: false),
            staticPrivacyMode: false,
          ),
        );
        await tester.pumpAndSettle();

        // Verify formatted prices appear on treatment chips
        expect(find.text('\$65.00'), findsWidgets);
        expect(find.text('\$95.00'), findsOneWidget);
        expect(find.text('\$120.00'), findsOneWidget);
        expect(find.text('\$250.00'), findsOneWidget);
        expect(find.text('\$350.00'), findsOneWidget);

        // In treatments container, zero '****' exists
        final treatmentsFinder = find.byKey(const Key('section_variant_price_chart'));
        final maskedInTreatments = find.descendant(
          of: treatmentsFinder,
          matching: find.text('****'),
        );
        expect(maskedInTreatments, findsNothing);
      },
    );

    testWidgets(
      'Finish chips render masked prices (****) when privacy mode is active',
      (tester) async {
        tester.view.physicalSize = const Size(800, 2600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final card = createTestCard();
        await db.into(db.vaultItems).insert(card);

        await tester.pumpWidget(
          createHarness(
            child: CardDetailSheet(item: card, fetchOnlinePrintings: false),
            staticPrivacyMode: true,
          ),
        );
        await tester.pumpAndSettle();

        // Formatted prices must NOT appear on treatment chips
        expect(find.text('\$95.00'), findsNothing);
        expect(find.text('\$120.00'), findsNothing);
        expect(find.text('\$250.00'), findsNothing);
        expect(find.text('\$350.00'), findsNothing);

        // '****' must appear on all 5 treatment chips
        final treatmentsFinder = find.byKey(const Key('section_variant_price_chart'));
        final maskedPills = find.descendant(
          of: treatmentsFinder,
          matching: find.text('****'),
        );
        expect(maskedPills, findsNWidgets(5));
      },
    );

    testWidgets(
      'Dynamic reactive toggle: Privacy mode flips false -> true -> false on live active sheet without rebuild errors',
      (tester) async {
        tester.view.physicalSize = const Size(800, 2600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final card = createTestCard();
        await db.into(db.vaultItems).insert(card);

        final dynamicPrivacy = StateProvider<bool>((ref) => false);

        await tester.pumpWidget(
          createHarness(
            child: CardDetailSheet(item: card, fetchOnlinePrintings: false),
            dynamicPrivacyProvider: dynamicPrivacy,
          ),
        );
        await tester.pumpAndSettle();

        // 1. Initial State: Unmasked ($95.00 visible)
        expect(find.text('\$95.00'), findsOneWidget);

        // 2. Flip to Privacy Mode: TRUE
        final container = ProviderScope.containerOf(tester.element(find.byType(CardDetailSheet)));
        container.read(dynamicPrivacy.notifier).state = true;
        await tester.pumpAndSettle();

        // Verified masked immediately
        expect(find.text('\$95.00'), findsNothing);
        expect(find.text('****'), findsWidgets);

        // 3. Flip back to Privacy Mode: FALSE
        container.read(dynamicPrivacy.notifier).state = false;
        await tester.pumpAndSettle();

        // Verified unmasked restored cleanly
        expect(find.text('\$95.00'), findsOneWidget);
        final treatmentsFinder = find.byKey(const Key('section_variant_price_chart'));
        expect(
          find.descendant(of: treatmentsFinder, matching: find.text('****')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'VersionsAndPrintingsModal respects privacy mode in both Versions and Printings tabs',
      (tester) async {
        tester.view.physicalSize = const Size(800, 2600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final card = createTestCard();
        await db.into(db.vaultItems).insert(card);

        final altCard = createCatalogVariant(
          id: 'alt-ring-showcase',
          name: 'The One Ring',
          setCode: 'ltr',
          setName: 'The Lord of the Rings: Tales of Middle-earth',
          collectorNumber: '0451',
          price: 180.00,
          borderColor: 'borderless',
          frameEffects: ['showcase'],
        );
        await db.into(db.vaultItems).insert(altCard);

        await tester.pumpWidget(
          createHarness(
            child: CardDetailSheet(item: card, fetchOnlinePrintings: false),
            staticPrivacyMode: true,
          ),
        );
        await tester.pumpAndSettle();

        // Open modal
        await tester.tap(find.byKey(const Key('card_detail_see_more_versions_button')));
        await tester.pumpAndSettle();

        expect(find.byType(VersionsAndPrintingsModal), findsOneWidget);

        // In Versions tab: prices masked with '****', $180.00 hidden
        expect(find.text('\$180.00'), findsNothing);
        expect(find.text('****'), findsWidgets);

        // Switch to Printings tab
        await tester.tap(find.text('Printings'));
        await tester.pumpAndSettle();

        // In Printings tab: prices masked with '****', $180.00 hidden
        expect(find.text('\$180.00'), findsNothing);
        expect(find.text('****'), findsWidgets);

        // Close modal
        await tester.tap(find.byKey(const Key('versions_printings_back_button')));
        await tester.pumpAndSettle();

        expect(find.byType(VersionsAndPrintingsModal), findsNothing);
      },
    );
  });

  // ===========================================================================
  // Requirement 3: Rapid Finish Switching (Burst Tapping)
  // ===========================================================================
  group('3. Rapid Finish Switching (Burst Tapping) Stress', () {
    testWidgets(
      'Burst-tap 8 times across finish chips: updates SQLite, resolves cleanly without race conditions or corrupted price',
      (tester) async {
        tester.view.physicalSize = const Size(800, 2600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final card = createTestCard();
        await db.into(db.vaultItems).insert(card);

        await tester.pumpWidget(
          createHarness(
            child: CardDetailSheet(item: card, fetchOnlinePrintings: false),
          ),
        );
        await tester.pumpAndSettle();

        // Rapid burst sequence:
        // nonfoil -> foil -> etched -> surge -> textured -> foil -> etched -> surge
        final burstSequence = [
          'foil',
          'etched',
          'surge',
          'textured',
          'foil',
          'etched',
          'nonfoil',
          'surge', // final target: Surge Foil ($250.00)
        ];

        for (final finish in burstSequence) {
          final chipFinder = find.byKey(Key('treatment_chip_$finish'));
          expect(chipFinder, findsOneWidget);
          await tester.tap(chipFinder);
          // Micro-pump 15ms simulating ultra-rapid human/automated multi-tap without settling
          await tester.pump(const Duration(milliseconds: 15));
        }

        // Allow all in-flight asynchronous SQLite writes and SnackBar transitions to settle
        await tester.pumpAndSettle();

        // 1. Verify zero unhandled exceptions
        expect(tester.takeException(), isNull);

        // 2. Verify database final state strictly matches LAST tapped finish ('surge' -> $250.00)
        final updatedInDb = await db.vaultDao.getItemById(card.id);
        expect(updatedInDb, isNotNull);
        expect(updatedInDb!.currentMarketPrice, equals(250.00));

        final dynamicData = jsonDecode(updatedInDb.dynamicData) as Map<String, dynamic>;
        expect(dynamicData['finish'], equals('surge'));
        expect(dynamicData['treatment'], equals('Surge Foil'));

        // 3. Verify UI state: surge chip is active with checkmark icon
        final surgeChip = find.byKey(const Key('treatment_chip_surge'));
        final checkmarkFinder = find.descendant(
          of: surgeChip,
          matching: find.byIcon(Icons.check_circle),
        );
        expect(checkmarkFinder, findsOneWidget);

        // Nonfoil chip does NOT have checkmark
        final nonfoilChip = find.byKey(const Key('treatment_chip_nonfoil'));
        final nonfoilCheckmark = find.descendant(
          of: nonfoilChip,
          matching: find.byIcon(Icons.check_circle),
        );
        expect(nonfoilCheckmark, findsNothing);
      },
    );

    testWidgets(
      'Unowned preview card (quantity: 0): rapid finish burst tap updates optimistic in-memory preview without throwing database error',
      (tester) async {
        tester.view.physicalSize = const Size(800, 2600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final unownedCard = createTestCard(id: 'unowned-ring-preview', quantity: 0);

        await tester.pumpWidget(
          createHarness(
            child: CardDetailSheet(item: unownedCard, fetchOnlinePrintings: false),
          ),
        );
        await tester.pumpAndSettle();

        // Rapidly burst-tap 5 chips
        await tester.tap(find.byKey(const Key('treatment_chip_foil')));
        await tester.pump(const Duration(milliseconds: 10));
        await tester.tap(find.byKey(const Key('treatment_chip_etched')));
        await tester.pump(const Duration(milliseconds: 10));
        await tester.tap(find.byKey(const Key('treatment_chip_textured')));
        await tester.pump(const Duration(milliseconds: 10));

        await tester.pumpAndSettle();

        // Verify no exception was thrown
        expect(tester.takeException(), isNull);

        // Textured chip is selected with checkmark
        final texturedChip = find.byKey(const Key('treatment_chip_textured'));
        final checkmarkFinder = find.descendant(
          of: texturedChip,
          matching: find.byIcon(Icons.check_circle),
        );
        expect(checkmarkFinder, findsOneWidget);
      },
    );

    testWidgets(
      'Unmount resilience: Tapping finish chip and immediately unmounting does NOT trigger setState after dispose crash',
      (tester) async {
        tester.view.physicalSize = const Size(800, 2600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final card = createTestCard();
        await db.into(db.vaultItems).insert(card);

        bool showSheet = true;

        await tester.pumpWidget(
          StatefulBuilder(
            builder: (context, setState) {
              return ProviderScope(
                key: UniqueKey(),
                overrides: [
                  appDatabaseProvider.overrideWithValue(db),
                  vaultDaoProvider.overrideWithValue(db.vaultDao),
                  privacyModeProvider.overrideWith((ref) => false),
                ],
                child: MaterialApp(
                  home: Scaffold(
                    body: showSheet
                        ? CardDetailSheet(item: card, fetchOnlinePrintings: false)
                        : const SizedBox(key: Key('placeholder')),
                    floatingActionButton: FloatingActionButton(
                      key: const Key('toggle_sheet_button'),
                      onPressed: () => setState(() => showSheet = !showSheet),
                    ),
                  ),
                ),
              );
            },
          ),
        );
        await tester.pumpAndSettle();

        // Tap finish chip to fire async operation
        await tester.tap(find.byKey(const Key('treatment_chip_foil')));
        // Immediately unmount before the async write finishes
        await tester.tap(find.byKey(const Key('toggle_sheet_button')));
        await tester.pumpAndSettle();

        // Sheet is unmounted
        expect(find.byType(CardDetailSheet), findsNothing);
        expect(find.byKey(const Key('placeholder')), findsOneWidget);

        // Zero exceptions thrown
        expect(tester.takeException(), isNull);
      },
    );
  });

  // ===========================================================================
  // Requirement 4: VersionsAndPrintingsModal Navigation & Lifecycle
  // ===========================================================================
  group('4. VersionsAndPrintingsModal Lifecycle & Gesture Stress', () {
    testWidgets(
      'Open modal via See More button, switch tabs, dismiss with upper-left Back button, ensure sheet remains intact',
      (tester) async {
        tester.view.physicalSize = const Size(800, 2600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final card = createTestCard();
        await db.into(db.vaultItems).insert(card);

        final alt1 = createCatalogVariant(
          id: 'ring-borderless',
          name: 'The One Ring',
          setCode: 'ltr',
          setName: 'The Lord of the Rings: Tales of Middle-earth',
          collectorNumber: '0451',
          price: 180.00,
          borderColor: 'borderless',
          frameEffects: ['showcase'],
        );
        final alt2 = createCatalogVariant(
          id: 'ring-extended',
          name: 'The One Ring',
          setCode: 'ltr',
          setName: 'The Lord of the Rings: Tales of Middle-earth',
          collectorNumber: '0705',
          price: 210.00,
          frameEffects: ['extendedart'],
        );
        await db.into(db.vaultItems).insert(alt1);
        await db.into(db.vaultItems).insert(alt2);

        await tester.pumpWidget(
          createHarness(
            child: CardDetailSheet(item: card, fetchOnlinePrintings: false),
          ),
        );
        await tester.pumpAndSettle();

        // Modal is NOT open yet
        expect(find.byType(VersionsAndPrintingsModal), findsNothing);

        // Tap [See More Versions & Printings]
        final seeMoreButton = find.byKey(const Key('card_detail_see_more_versions_button'));
        expect(seeMoreButton, findsOneWidget);
        await tester.tap(seeMoreButton);
        await tester.pumpAndSettle();

        // Modal is now mounted
        expect(find.byType(VersionsAndPrintingsModal), findsOneWidget);
        expect(find.text('Versions'), findsOneWidget);
        expect(find.text('Printings'), findsOneWidget);

        // Upper-left back button is present
        final backButton = find.byKey(const Key('versions_printings_back_button'));
        expect(backButton, findsOneWidget);

        // Switch to Printings tab
        await tester.tap(find.text('Printings'));
        await tester.pumpAndSettle();

        // Verify candidates in Printings list
        expect(find.byKey(const Key('variant_card_ltr_0269')), findsOneWidget);
        expect(find.byKey(const Key('variant_card_ltr_0451')), findsOneWidget);
        expect(find.byKey(const Key('variant_card_ltr_0705')), findsOneWidget);

        // Switch back to Versions tab
        await tester.tap(find.text('Versions'));
        await tester.pumpAndSettle();

        // Verify version badge
        expect(find.text('Showcase'), findsOneWidget);

        // Tap upper-left Back Button (Key('versions_printings_back_button'))
        await tester.tap(backButton);
        await tester.pumpAndSettle();

        // Modal is dismissed cleanly
        expect(find.byType(VersionsAndPrintingsModal), findsNothing);

        // Underlying CardDetailSheet remains intact and functional!
        expect(find.byType(CardDetailSheet), findsOneWidget);
        expect(find.byKey(const Key('card_detail_see_more_versions_button')), findsOneWidget);
      },
    );

    testWidgets(
      'Tapping the current active printing candidate dismisses modal without pushing duplicate routes',
      (tester) async {
        tester.view.physicalSize = const Size(800, 2600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final card = createTestCard(collectorNumber: '0269', setCode: 'ltr');
        await db.into(db.vaultItems).insert(card);

        await tester.pumpWidget(
          createHarness(
            child: CardDetailSheet(item: card, fetchOnlinePrintings: false),
          ),
        );
        await tester.pumpAndSettle();

        // 1 CardDetailSheet initially
        expect(find.byType(CardDetailSheet), findsOneWidget);

        // Open modal
        await tester.tap(find.byKey(const Key('card_detail_see_more_versions_button')));
        await tester.pumpAndSettle();

        expect(find.byType(VersionsAndPrintingsModal), findsOneWidget);

        // Switch to Printings tab
        await tester.tap(find.text('Printings'));
        await tester.pumpAndSettle();

        // The current active printing is variant_card_ltr_0269
        final activePrinting = find.byKey(const Key('variant_card_ltr_0269'));
        expect(activePrinting, findsOneWidget);

        // Tap active printing
        await tester.tap(activePrinting);
        await tester.pumpAndSettle();

        // Modal is dismissed
        expect(find.byType(VersionsAndPrintingsModal), findsNothing);

        // STRICT INVARIANT: ZERO duplicate CardDetailSheet routes pushed!
        expect(find.byType(CardDetailSheet), findsOneWidget);
      },
    );

    testWidgets(
      'Tapping an alternative candidate in modal pushes distinct CardDetailSheet page, popping returns to initial sheet',
      (tester) async {
        tester.view.physicalSize = const Size(800, 2600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final initialCard = createTestCard(collectorNumber: '0269', setCode: 'ltr', price: 65.0);
        await db.into(db.vaultItems).insert(initialCard);

        final altCard = createCatalogVariant(
          id: 'alt-ring-0451',
          name: 'The One Ring',
          setCode: 'ltr',
          setName: 'The Lord of the Rings: Tales of Middle-earth',
          collectorNumber: '0451',
          price: 180.00,
          borderColor: 'borderless',
          frameEffects: ['showcase'],
        );
        await db.into(db.vaultItems).insert(altCard);

        await tester.pumpWidget(
          createHarness(
            child: CardDetailSheet(item: initialCard, fetchOnlinePrintings: false),
          ),
        );
        await tester.pumpAndSettle();

        // Open modal
        await tester.tap(find.byKey(const Key('card_detail_see_more_versions_button')));
        await tester.pumpAndSettle();

        // Switch to Printings tab
        await tester.tap(find.text('Printings'));
        await tester.pumpAndSettle();

        // Tap alternative candidate (LTR #0451)
        final altCandidate = find.byKey(const Key('variant_card_ltr_0451'));
        expect(altCandidate, findsOneWidget);
        await tester.tap(altCandidate);
        await tester.pumpAndSettle();

        // A second distinct CardDetailSheet has been pushed!
        expect(find.byType(CardDetailSheet), findsNWidgets(2));
        expect(find.textContaining('180.00'), findsWidgets);
        expect(find.textContaining('0451'), findsWidgets);

        // Dismiss the newly pushed sheet
        Navigator.of(tester.element(find.byType(CardDetailSheet).last)).pop();
        await tester.pumpAndSettle();

        // Returned cleanly to the initial sheet
        expect(find.byType(CardDetailSheet), findsOneWidget);
        expect(find.textContaining('65.00'), findsWidgets);
      },
    );
  });
}
