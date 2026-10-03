import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/settings_state.dart';
import 'package:countr/features/command_center/presentation/widgets/morphing_command_center.dart';
import 'package:countr/features/feed/presentation/screens/feed_screen.dart';
import 'package:countr/features/hydration/domain/isolate/scryfall_parser.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';

VaultItemsCompanion _createTestVaultItem({
  required String id,
  required String name,
  String collectionType = 'mtg',
  String setOrSeries = 'LEA',
  double acquiredPrice = 10.0,
  double currentMarketPrice = 20.0,
  Map<String, dynamic>? dynamicDataMap,
}) {
  final now = DateTime.now();
  return VaultItemsCompanion.insert(
    id: id,
    collectionType: collectionType,
    name: name,
    setOrSeries: setOrSeries,
    imageUrl: 'https://cards.scryfall.io/large/front/$id.jpg',
    acquiredPrice: acquiredPrice,
    acquiredDate: now,
    condition: 'NM',
    currentMarketPrice: currentMarketPrice,
    lastPriceUpdate: now,
    dynamicData: dynamicDataMap != null ? jsonEncode(dynamicDataMap) : '{}',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Stage 2A: Command Center App Settings Repositioning', () {
    testWidgets(
      'Command Center displays App Settings modal dialog with all three controls when Settings quick action is tapped',
      (WidgetTester tester) async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: Scaffold(body: MorphingCommandCenter()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify inline APP SETTINGS section card is removed from scroll view
        expect(
          find.byKey(const Key('command_center_app_settings_card')),
          findsNothing,
        );

        // Scroll down to reveal Settings action item in footer
        await tester.scrollUntilVisible(
          find.text('Settings'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();

        final settingsBtn = find.text('Settings');
        expect(settingsBtn, findsOneWidget);

        await tester.tap(settingsBtn);
        await tester.pumpAndSettle();

        // Verify modal dialog is rendered with blurred backdrop and header
        expect(find.byType(AppSettingsDialog), findsOneWidget);
        expect(
          find.byKey(const Key('command_center_app_settings_dialog')),
          findsOneWidget,
        );
        expect(find.text('APP SETTINGS'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(AppSettingsDialog),
            matching: find.byIcon(Icons.close_rounded),
          ),
          findsOneWidget,
        );
        expect(find.byType(BackdropFilter), findsWidgets);

        // Verify Privacy Mode toggle inside dialog
        expect(
          find.byKey(const Key('command_center_privacy_mode_toggle')),
          findsOneWidget,
        );
        expect(find.text('Global Privacy Mode'), findsOneWidget);

        // Verify Base Currency dropdown inside dialog
        expect(
          find.byKey(const Key('command_center_base_currency_dropdown')),
          findsOneWidget,
        );
        expect(find.text('Base Currency'), findsOneWidget);

        // Verify Streamer Security toggle inside dialog
        expect(
          find.byKey(const Key('command_center_streamer_security_toggle')),
          findsOneWidget,
        );
        expect(find.text('Streamer Security'), findsOneWidget);

        // Verify obsolete viewing persona toggles are absent
        expect(find.byKey(const Key('persona_toggle_investor')), findsNothing);
        expect(find.byKey(const Key('persona_toggle_player')), findsNothing);
      },
    );

    testWidgets(
      'Toggling Privacy Mode switch inside modal updates privacyModeProvider',
      (WidgetTester tester) async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: Scaffold(body: MorphingCommandCenter()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Open Settings modal
        await tester.scrollUntilVisible(
          find.text('Settings'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Settings'));
        await tester.pumpAndSettle();

        expect(container.read(privacyModeProvider), isFalse);

        final privacyToggle = find.byKey(
          const Key('command_center_privacy_mode_toggle'),
        );
        await tester.tap(privacyToggle);
        await tester.pumpAndSettle();

        expect(container.read(privacyModeProvider), isTrue);

        await tester.tap(privacyToggle);
        await tester.pumpAndSettle();

        expect(container.read(privacyModeProvider), isFalse);
      },
    );

    testWidgets(
      'Changing Base Currency dropdown inside modal updates baseCurrencyProvider',
      (WidgetTester tester) async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: Scaffold(body: MorphingCommandCenter()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Open Settings modal
        await tester.scrollUntilVisible(
          find.text('Settings'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Settings'));
        await tester.pumpAndSettle();

        expect(container.read(baseCurrencyProvider), AppCurrency.usd);

        // Tap dropdown to open menu
        final dropdown = find.byKey(
          const Key('command_center_base_currency_dropdown'),
        );
        await tester.tap(dropdown);
        await tester.pumpAndSettle();

        // Select EUR
        final eurItem = find.text('EUR (€)').last;
        await tester.tap(eurItem);
        await tester.pumpAndSettle();

        expect(container.read(baseCurrencyProvider), AppCurrency.eur);

        // Select GBP
        await tester.tap(dropdown);
        await tester.pumpAndSettle();
        final gbpItem = find.text('GBP (£)').last;
        await tester.tap(gbpItem);
        await tester.pumpAndSettle();

        expect(container.read(baseCurrencyProvider), AppCurrency.gbp);

        // Select CAD
        await tester.tap(dropdown);
        await tester.pumpAndSettle();
        final cadItem = find.text('CAD (CA\$)').last;
        await tester.tap(cadItem);
        await tester.pumpAndSettle();

        expect(container.read(baseCurrencyProvider), AppCurrency.cad);
      },
    );

    testWidgets(
      'Toggling Streamer Security switch inside modal updates streamerSecurityEnabledProvider',
      (WidgetTester tester) async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: Scaffold(body: MorphingCommandCenter()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Open Settings modal
        await tester.scrollUntilVisible(
          find.text('Settings'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Settings'));
        await tester.pumpAndSettle();

        expect(container.read(streamerSecurityEnabledProvider), isFalse);

        final streamerToggle = find.byKey(
          const Key('command_center_streamer_security_toggle'),
        );
        await tester.tap(streamerToggle);
        await tester.pumpAndSettle();

        expect(container.read(streamerSecurityEnabledProvider), isTrue);

        await tester.tap(streamerToggle);
        await tester.pumpAndSettle();

        expect(container.read(streamerSecurityEnabledProvider), isFalse);
      },
    );

    testWidgets(
      'Footer Settings quick action opens modal dialog and close button dismisses cleanly',
      (WidgetTester tester) async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: Scaffold(body: MorphingCommandCenter()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Scroll down to reveal Settings action item in footer
        await tester.scrollUntilVisible(
          find.text('Settings'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();

        final settingsBtn = find.text('Settings');
        expect(settingsBtn, findsOneWidget);

        await tester.tap(settingsBtn);
        await tester.pumpAndSettle();

        // Verify modal is open
        expect(find.byType(AppSettingsDialog), findsOneWidget);

        // Tap close button on dialog
        final closeBtn = find.descendant(
          of: find.byType(AppSettingsDialog),
          matching: find.byIcon(Icons.close_rounded),
        );
        await tester.tap(closeBtn);
        await tester.pumpAndSettle();

        // Verify modal dismissed and command center restored
        expect(find.byType(AppSettingsDialog), findsNothing);
        expect(find.text('COMMAND CENTER'), findsOneWidget);
      },
    );

    testWidgets(
      'Tapping outside App Settings dialog dismisses modal cleanly without altering view',
      (WidgetTester tester) async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: Scaffold(body: MorphingCommandCenter()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Scroll down to reveal Settings action item in footer
        await tester.scrollUntilVisible(
          find.text('Settings'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Settings'));
        await tester.pumpAndSettle();

        expect(find.byType(AppSettingsDialog), findsOneWidget);

        // Tap outside the dialog on the barrier scrim (top-left)
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();

        // Verify modal dismissed and command center view is intact
        expect(find.byType(AppSettingsDialog), findsNothing);
        expect(find.text('COMMAND CENTER'), findsOneWidget);
      },
    );

    testWidgets(
      'Dismissing settings modal via close button or barrier preserves exact scroll position of MorphingCommandCenter',
      (WidgetTester tester) async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: Scaffold(body: MorphingCommandCenter()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final scrollableFinder = find.byType(Scrollable).first;

        // Scroll down to footer Settings button
        await tester.scrollUntilVisible(
          find.text('Settings'),
          200,
          scrollable: scrollableFinder,
        );
        await tester.pumpAndSettle();

        final offsetBeforeOpen = tester
            .state<ScrollableState>(scrollableFinder)
            .position
            .pixels;
        expect(offsetBeforeOpen, greaterThan(100.0));

        // 1. Open modal and dismiss via close button
        await tester.tap(find.text('Settings'));
        await tester.pumpAndSettle();
        expect(find.byType(AppSettingsDialog), findsOneWidget);

        final closeBtn = find.descendant(
          of: find.byType(AppSettingsDialog),
          matching: find.byIcon(Icons.close_rounded),
        );
        await tester.tap(closeBtn);
        await tester.pumpAndSettle();
        expect(find.byType(AppSettingsDialog), findsNothing);

        final offsetAfterCloseBtn = tester
            .state<ScrollableState>(scrollableFinder)
            .position
            .pixels;
        expect(offsetAfterCloseBtn, equals(offsetBeforeOpen));

        // 2. Open modal and dismiss via barrier tap
        await tester.tap(find.text('Settings'));
        await tester.pumpAndSettle();
        expect(find.byType(AppSettingsDialog), findsOneWidget);

        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();
        expect(find.byType(AppSettingsDialog), findsNothing);

        final offsetAfterBarrier = tester
            .state<ScrollableState>(scrollableFinder)
            .position
            .pixels;
        expect(offsetAfterBarrier, equals(offsetBeforeOpen));
      },
    );

    testWidgets(
      'Rapid double-tap on Settings quick action button opens only one modal dialog',
      (WidgetTester tester) async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: Scaffold(body: MorphingCommandCenter()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final scrollableFinder = find.byType(Scrollable).first;
        await tester.scrollUntilVisible(
          find.text('Settings'),
          200,
          scrollable: scrollableFinder,
        );
        await tester.pumpAndSettle();

        final settingsBtn = find.text('Settings');

        // Tap rapidly twice without intermediate pump
        await tester.tap(settingsBtn);
        await tester.tap(settingsBtn, warnIfMissed: false);
        await tester.pumpAndSettle();

        expect(find.byType(AppSettingsDialog), findsOneWidget);

        // One close dismisses cleanly
        final closeBtn = find.descendant(
          of: find.byType(AppSettingsDialog),
          matching: find.byIcon(Icons.close_rounded),
        );
        await tester.tap(closeBtn);
        await tester.pumpAndSettle();

        expect(find.byType(AppSettingsDialog), findsNothing);
      },
    );

    testWidgets(
      'Mutating settings inside modal while scrolled preserves exact scroll offset of MorphingCommandCenter after dismissal',
      (WidgetTester tester) async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: Scaffold(body: MorphingCommandCenter()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final scrollableFinder = find.byType(Scrollable).first;
        await tester.scrollUntilVisible(
          find.text('Settings'),
          200,
          scrollable: scrollableFinder,
        );
        await tester.pumpAndSettle();

        final offsetBeforeOpen = tester
            .state<ScrollableState>(scrollableFinder)
            .position
            .pixels;
        expect(offsetBeforeOpen, greaterThan(100.0));

        // Open modal
        await tester.tap(find.text('Settings'));
        await tester.pumpAndSettle();
        expect(find.byType(AppSettingsDialog), findsOneWidget);

        // 1. Mutate Privacy Mode inside modal
        final privacyToggle = find.byKey(
          const Key('command_center_privacy_mode_toggle'),
        );
        await tester.tap(privacyToggle);
        await tester.pumpAndSettle();
        expect(container.read(privacyModeProvider), isTrue);

        // 2. Mutate Base Currency inside modal
        final dropdown = find.byKey(
          const Key('command_center_base_currency_dropdown'),
        );
        await tester.tap(dropdown);
        await tester.pumpAndSettle();
        await tester.tap(find.text('EUR (€)').last);
        await tester.pumpAndSettle();
        expect(container.read(baseCurrencyProvider), AppCurrency.eur);

        // 3. Mutate Streamer Security inside modal
        final streamerToggle = find.byKey(
          const Key('command_center_streamer_security_toggle'),
        );
        await tester.tap(streamerToggle);
        await tester.pumpAndSettle();
        expect(container.read(streamerSecurityEnabledProvider), isTrue);

        // Dismiss modal via close button
        final closeBtn = find.descendant(
          of: find.byType(AppSettingsDialog),
          matching: find.byIcon(Icons.close_rounded),
        );
        await tester.tap(closeBtn);
        await tester.pumpAndSettle();

        expect(find.byType(AppSettingsDialog), findsNothing);

        // Assert scroll position was not perturbed by state mutations or rebuilds
        final offsetAfterClose = tester
            .state<ScrollableState>(scrollableFinder)
            .position
            .pixels;
        expect(offsetAfterClose, equals(offsetBeforeOpen));
      },
    );
  });

  group('Stage 2A: Feed Screen Eyeball Privacy Toggle Removal', () {
    testWidgets('FeedScreen AppBar does not have feed_privacy_mode_button', (
      WidgetTester tester,
    ) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: FeedScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Privacy toggle must be removed
      expect(find.byKey(const Key('feed_privacy_mode_button')), findsNothing);

      // Feed title and remaining action icons must render cleanly
      expect(find.text('Countr'), findsOneWidget);
      expect(find.byIcon(Icons.search_rounded), findsOneWidget);
      expect(find.byTooltip('Inbox'), findsOneWidget);
      expect(find.byIcon(Icons.notifications_none_rounded), findsOneWidget);
    });
  });

  group('Stage 2A: Scryfall Parser Oracle ID & Finishes Extraction', () {
    test(
      'mapScryfallCardToCompanion extracts oracle_id, finishes list, and primary finish',
      () {
        final scryfallCardJson = {
          'id': 'black-lotus-lea-1',
          'oracle_id': 'c3b53f65-7b56-4c7a-9a99-4c6e949cb6e0',
          'name': 'Black Lotus',
          'mana_cost': '{0}',
          'type_line': 'Artifact',
          'oracle_text':
              '{T}, Sacrifice Black Lotus: Add three mana of any one color.',
          'finishes': ['nonfoil'],
          'prices': {'usd': '50000.0', 'usd_foil': null, 'eur': null},
        };

        final companion = mapScryfallCardToCompanion(scryfallCardJson);
        expect(companion.dynamicData.present, isTrue);

        final dynamicData =
            jsonDecode(companion.dynamicData.value) as Map<String, dynamic>;
        expect(
          dynamicData['oracle_id'],
          'c3b53f65-7b56-4c7a-9a99-4c6e949cb6e0',
        );
        expect(dynamicData['finishes'], equals(['nonfoil']));
        expect(dynamicData['finish'], 'nonfoil');
      },
    );

    test(
      'mapScryfallCardToCompanion extracts oracle_id from card_faces if absent from root',
      () {
        final ddfCardJson = {
          'id': 'delver-of-secrets-isd',
          'name': 'Delver of Secrets // Insectile Aberration',
          'finishes': ['foil', 'etched'],
          'card_faces': [
            {
              'name': 'Delver of Secrets',
              'oracle_id': 'oracle-delver-uuid-1234',
              'mana_cost': '{U}',
              'type_line': 'Creature — Human Wizard',
            },
            {
              'name': 'Insectile Aberration',
              'type_line': 'Creature — Human Insect',
            },
          ],
          'prices': {'usd': '1.50', 'usd_foil': '10.00', 'eur': null},
        };

        final companion = mapScryfallCardToCompanion(ddfCardJson);
        expect(companion.dynamicData.present, isTrue);

        final dynamicData =
            jsonDecode(companion.dynamicData.value) as Map<String, dynamic>;
        expect(dynamicData['oracle_id'], 'oracle-delver-uuid-1234');
        expect(dynamicData['finishes'], containsAll(['foil', 'etched']));
        expect(dynamicData['finish'], 'foil');
      },
    );
  });

  group('Stage 2A: VaultDao Oracle ID Grouping & Finish Enforcement', () {
    late AppDatabase db;
    late VaultDao dao;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      dao = db.vaultDao;
      await db.delete(db.vaultItems).go();
      await dao.ensureSecretLairIndexes();

      // Seed printings for the same abstract card (Lightning Bolt):
      // Printing 1: Alpha Printing (nonfoil)
      await dao
          .into(db.vaultItems)
          .insert(
            _createTestVaultItem(
              id: 'bolt-alpha',
              name: 'Lightning Bolt',
              setOrSeries: 'LEA',
              dynamicDataMap: {
                'oracle_id': 'oracle-bolt-123',
                'finishes': ['nonfoil'],
                'finish': 'nonfoil',
              },
            ),
          );

      // Printing 2: Magic 2010 Printing (foil)
      await dao
          .into(db.vaultItems)
          .insert(
            _createTestVaultItem(
              id: 'bolt-m10',
              name: 'Lightning Bolt',
              setOrSeries: 'M10',
              dynamicDataMap: {
                'oracle_id': 'oracle-bolt-123',
                'finishes': ['nonfoil', 'foil'],
                'finish': 'foil',
              },
            ),
          );

      // Printing 3: Secret Lair Printing (etched)
      await dao
          .into(db.vaultItems)
          .insert(
            _createTestVaultItem(
              id: 'bolt-sld',
              name: 'Lightning Bolt',
              setOrSeries: 'Secret Lair Drop',
              dynamicDataMap: {
                'oracle_id': 'oracle-bolt-123',
                'finishes': ['etched'],
                'finish': 'etched',
              },
            ),
          );

      // Different abstract card: Counterspell
      await dao
          .into(db.vaultItems)
          .insert(
            _createTestVaultItem(
              id: 'counterspell-lea',
              name: 'Counterspell',
              setOrSeries: 'LEA',
              dynamicDataMap: {
                'oracle_id': 'oracle-counterspell-999',
                'finishes': ['nonfoil'],
                'finish': 'nonfoil',
              },
            ),
          );
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'searchCatalogCards with groupByOracleId: true deduplicates printings by oracle_id',
      () async {
        final deduplicatedResults = await dao.searchCatalogCards(
          'Lightning',
          groupByOracleId: true,
        );

        // Expect exactly 1 representative card for Lightning Bolt
        expect(deduplicatedResults.length, 1);
        expect(deduplicatedResults.first.name, 'Lightning Bolt');
      },
    );

    test(
      'searchCatalogCards with groupByOracleId: false returns all distinct printings',
      () async {
        final allPrintings = await dao.searchCatalogCards(
          'Lightning',
          groupByOracleId: false,
        );

        // Expect all 3 printings
        expect(allPrintings.length, 3);
        final printingIds = allPrintings.map((p) => p.id).toList();
        expect(
          printingIds,
          containsAll(['bolt-alpha', 'bolt-m10', 'bolt-sld']),
        );
      },
    );

    test(
      'searchByOracleId returns all printings sharing the same oracle_id',
      () async {
        final boltPrintings = await dao.searchByOracleId('oracle-bolt-123');
        expect(boltPrintings.length, 3);

        final counterspellPrintings = await dao.searchByOracleId(
          'oracle-counterspell-999',
        );
        expect(counterspellPrintings.length, 1);
        expect(counterspellPrintings.first.name, 'Counterspell');

        final emptyPrintings = await dao.searchByOracleId(
          'non-existent-oracle',
        );
        expect(emptyPrintings, isEmpty);
      },
    );

    test(
      'updateItemFinish updates and persists physical finish metadata',
      () async {
        final itemBefore = await dao.getItemById('bolt-alpha');
        expect(itemBefore, isNotNull);
        final dynBefore =
            jsonDecode(itemBefore!.dynamicData) as Map<String, dynamic>;
        expect(dynBefore['finish'], 'nonfoil');

        // Update finish to etched
        await dao.updateItemFinish('bolt-alpha', 'etched');

        final itemAfter = await dao.getItemById('bolt-alpha');
        expect(itemAfter, isNotNull);
        final dynAfter =
            jsonDecode(itemAfter!.dynamicData) as Map<String, dynamic>;
        expect(dynAfter['finish'], 'etched');
        expect(dynAfter['treatment'], 'etched');
      },
    );

    test(
      'updateItemFinish rejects invalid finishes and non-existent IDs',
      () async {
        expect(
          () => dao.updateItemFinish('bolt-alpha', 'invalid_foil_type'),
          throwsA(isA<ArgumentError>()),
        );

        expect(
          () => dao.updateItemFinish('non-existent-card-id', 'foil'),
          throwsA(isA<StateError>()),
        );
      },
    );
  });
}
