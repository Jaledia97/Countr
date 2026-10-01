import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/app_state.dart';
import 'package:countr/features/command_center/presentation/widgets/morphing_command_center.dart';
import 'package:countr/features/hydration/presentation/controllers/hydration_controller.dart';
import 'package:countr/features/hydration/presentation/controllers/hydration_state.dart';
import 'package:countr/features/hydration/presentation/providers/hydration_providers.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/screens/vault_screen.dart';
import 'package:countr/features/vault/presentation/widgets/vault_item_card.dart';
import 'package:countr/features/vault/presentation/widgets/vault_item_tile.dart';

/// Test Spy for HydrationController to empirically track invocation
class _SpyHydrationController extends StateNotifier<HydrationState>
    implements HydrationController {
  bool startHydrationCalled = false;
  int startHydrationCallCount = 0;

  _SpyHydrationController([HydrationState? initialState])
      : super(initialState ?? const HydrationState());

  @override
  Future<void> startHydration({
    String? overrideDownloadUri,
    File? localFileToHydrate,
    int? estimatedTotal,
  }) async {
    startHydrationCalled = true;
    startHydrationCallCount++;
    state = state.copyWith(
      status: HydrationStatus.downloading,
      statusMessage: 'Downloading Scryfall bulk cards...',
    );
  }

  @override
  void reset() {
    state = const HydrationState();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Challenger 2 Milestone 1: Command Center Relocation & Responsive Layout Empirical Suite', () {
    late AppDatabase db;
    late _SpyHydrationController spyHydrationController;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      spyHydrationController = _SpyHydrationController();
    });

    tearDown(() async {
      await db.close();
    });

    Widget createCommandCenterHarness({
      required WidgetRef? Function(WidgetRef)? onRef,
      Size viewportSize = const Size(500, 1000),
    }) {
      return ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
          activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
          hydrationControllerProvider.overrideWith((ref) => spyHydrationController),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return const MorphingCommandCenter();
              },
            ),
          ),
        ),
      );
    }

    Widget createVaultScreenHarness({
      TextScaler textScaler = TextScaler.noScaling,
      Size viewportSize = const Size(390, 844),
      List<Override> extraOverrides = const [],
    }) {
      return ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
          activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
          hydrationControllerProvider.overrideWith((ref) => spyHydrationController),
          ...extraOverrides,
        ],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              size: viewportSize,
              textScaler: textScaler,
            ),
            child: child!,
          ),
          home: const VaultScreen(),
        ),
      );
    }

    // =========================================================================
    // TASK ITEM 1: MorphingCommandCenter Renders Dev Tools Card & Buttons
    // =========================================================================
    group('Task Item 1: Command Center Developer Tools Card Rendering', () {
      testWidgets('MorphingCommandCenter renders command_center_developer_tools_card with hydrate & verify database buttons', (tester) async {
        tester.view.physicalSize = const Size(600, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(createCommandCenterHarness(onRef: null));
        await tester.pumpAndSettle();

        // 1. Scroll card into view
        final devToolsCardFinder = find.byKey(const Key('command_center_developer_tools_card'));
        await tester.scrollUntilVisible(devToolsCardFinder, 200);
        await tester.pumpAndSettle();

        // 2. Verify developer tools card is mounted
        expect(devToolsCardFinder, findsOneWidget);

        // 3. Verify card header title and DEV badge
        expect(find.text('TEST & DEVELOPER TOOLS'), findsOneWidget);
        expect(find.text('DEV'), findsOneWidget);

        // 4. Verify Hydration Engine section & button
        expect(find.text('Hydration Engine'), findsOneWidget);
        final hydrateBtnFinder = find.byKey(const Key('command_center_hydrate_button'));
        expect(hydrateBtnFinder, findsOneWidget);
        expect(find.descendant(of: hydrateBtnFinder, matching: find.text('Hydrate')), findsOneWidget);

        // 5. Verify Database Verification section & button
        expect(find.text('Database Verification'), findsOneWidget);
        final verifyBtnFinder = find.byKey(const Key('command_center_verify_database_button'));
        expect(verifyBtnFinder, findsOneWidget);
        expect(find.descendant(of: verifyBtnFinder, matching: find.text('Verify')), findsOneWidget);
      });
    });

    // =========================================================================
    // TASK ITEM 2: Interaction Triggers (Hydration Controller & Database Seeding)
    // =========================================================================
    group('Task Item 2: Developer Tool Button Triggers', () {
      testWidgets('Tapping command_center_hydrate_button triggers hydrationController.startHydration() and shows SnackBar', (tester) async {
        tester.view.physicalSize = const Size(600, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(createCommandCenterHarness(onRef: null));
        await tester.pumpAndSettle();

        final hydrateBtnFinder = find.byKey(const Key('command_center_hydrate_button'));
        await tester.scrollUntilVisible(hydrateBtnFinder, 200);
        await tester.pumpAndSettle();

        // Verify initial state
        expect(spyHydrationController.startHydrationCalled, isFalse);
        expect(spyHydrationController.startHydrationCallCount, 0);

        // Tap hydrate button
        await tester.tap(hydrateBtnFinder);
        await tester.pump();

        // Empirically verify startHydration was invoked
        expect(spyHydrationController.startHydrationCalled, isTrue);
        expect(spyHydrationController.startHydrationCallCount, 1);

        // Verify SnackBar feedback
        expect(find.text('Starting MTG bulk hydration...'), findsOneWidget);
      });

      testWidgets('Tapping command_center_verify_database_button calls seedDatabase() and populates SQLite ledger', (tester) async {
        tester.view.physicalSize = const Size(600, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        // Hard clear all items first to test re-seeding
        await db.delete(db.vaultItems).go();
        final initialItems = await db.select(db.vaultItems).get();
        expect(initialItems, isEmpty);

        await tester.pumpWidget(createCommandCenterHarness(onRef: null));
        await tester.pumpAndSettle();

        final verifyBtnFinder = find.byKey(const Key('command_center_verify_database_button'));
        await tester.scrollUntilVisible(verifyBtnFinder, 200);
        await tester.pumpAndSettle();

        // Tap database verification button
        await tester.tap(verifyBtnFinder);
        await tester.pump();
        await tester.pumpAndSettle();

        // Empirically verify database was seeded with cards
        final seededItems = await db.select(db.vaultItems).get();
        expect(seededItems.length, greaterThanOrEqualTo(8));
        expect(seededItems.any((card) => card.name.contains('The One Ring')), isTrue);
        expect(seededItems.any((card) => card.name.contains('Black Lotus')), isTrue);
        expect(seededItems.any((card) => card.name.contains('Sol Ring')), isTrue);

        // Verify confirmation SnackBar feedback
        expect(find.text('Database verified and seeded.'), findsOneWidget);
      });
    });

    // =========================================================================
    // TASK ITEM 3: High Text Scale Factors (1.5x and 2.0x) on VaultScreen
    // =========================================================================
    group('Task Item 3: Responsive Layout & Text Scaling Without RenderFlex Overflow', () {
      testWidgets('VaultScreen renders cleanly under 1.5x text scale with 0 RenderFlex overflows', (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        // Seed database
        await db.vaultDao.seedDatabase();

        // Collect any Flutter layout errors
        final List<FlutterErrorDetails> overflowErrors = [];
        final originalOnError = FlutterError.onError;
        FlutterError.onError = (details) {
          if (details.toString().contains('overflowed') || details.toString().contains('RenderFlex')) {
            overflowErrors.add(details);
          }
        };

        try {
          await tester.pumpWidget(
            createVaultScreenHarness(
              textScaler: const TextScaler.linear(1.5),
              viewportSize: const Size(390, 844),
            ),
          );
          await tester.pump();
          await tester.pumpAndSettle();

          // Assert zero RenderFlex overflows occurred
          expect(overflowErrors, isEmpty, reason: 'RenderFlex overflow errors detected at 1.5x scale');

          // Verify dynamic aspect ratio applied on Grid (0.44 for textScale > 1.3)
          final gridFinder = find.byKey(const PageStorageKey<String>('vault_cards_sliver_grid'));
          expect(gridFinder, findsOneWidget);
          final gridWidget = tester.widget<SliverGrid>(gridFinder);
          final gridDelegate = gridWidget.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
          expect(gridDelegate.childAspectRatio, equals(0.44));

          // Verify cards are visible
          expect(find.textContaining('The One Ring'), findsWidgets);
          expect(find.textContaining('Black Lotus'), findsWidgets);

          // Verify Portfolio summary card values and Import button
          expect(find.byKey(const Key('vault_portfolio_summary_card')), findsOneWidget);
          expect(find.byKey(const Key('vault_import_button')), findsOneWidget);

          // Verify AppBar actions is clean (no buttons in app bar)
          final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
          final appBar = scaffold.appBar as AppBar;
          expect(appBar.actions, isEmpty);

          // Verify search expand/collapse under 1.5x
          final searchExpandBtn = find.byKey(const Key('vault_search_expand_button'));
          await tester.tap(searchExpandBtn);
          await tester.pumpAndSettle();
          expect(overflowErrors, isEmpty);

          // Enter search text
          final searchField = find.byKey(const Key('vault_search_text_field'));
          expect(searchField, findsOneWidget);
          await tester.enterText(searchField, 'Ring');
          await tester.pumpAndSettle();
          expect(overflowErrors, isEmpty);

          // Tap clear button (1st step: clear text)
          final clearBtn = find.byKey(const Key('vault_search_clear_button'));
          expect(clearBtn, findsOneWidget);
          await tester.tap(clearBtn);
          await tester.pumpAndSettle();
          expect(overflowErrors, isEmpty);

          // Tap collapse button (2nd step: collapse search)
          final collapseBtn = find.byKey(const Key('vault_search_collapse_button'));
          expect(collapseBtn, findsOneWidget);
          await tester.tap(collapseBtn);
          await tester.pumpAndSettle();
          expect(overflowErrors, isEmpty);

          // Switch to List layout under 1.5x
          final listLayoutBtn = find.byKey(const Key('vault_layout_list_button'));
          await tester.tap(listLayoutBtn);
          await tester.pumpAndSettle();
          expect(overflowErrors, isEmpty);

          // Return to Grid layout
          final gridLayoutBtn = find.byKey(const Key('vault_layout_grid_button'));
          await tester.tap(gridLayoutBtn);
          await tester.pumpAndSettle();
          expect(overflowErrors, isEmpty);
        } finally {
          FlutterError.onError = originalOnError;
        }

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 100));
      });

      testWidgets('VaultScreen renders cleanly in Grid mode under 2.0x text scale on standard viewport (390x844)', (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await db.vaultDao.seedDatabase();

        final List<FlutterErrorDetails> overflowErrors = [];
        final originalOnError = FlutterError.onError;
        FlutterError.onError = (details) {
          if (details.toString().contains('overflowed') || details.toString().contains('RenderFlex')) {
            overflowErrors.add(details);
          }
        };

        try {
          await tester.pumpWidget(
            createVaultScreenHarness(
              textScaler: const TextScaler.linear(2.0),
              viewportSize: const Size(390, 844),
            ),
          );
          await tester.pump();
          await tester.pumpAndSettle();

          // Verify dynamic aspect ratio applied on Grid (0.36 for textScale > 1.8)
          final gridFinder = find.byKey(const PageStorageKey<String>('vault_cards_sliver_grid'));
          expect(gridFinder, findsOneWidget);
          final gridWidget = tester.widget<SliverGrid>(gridFinder);
          final gridDelegate = gridWidget.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
          expect(gridDelegate.childAspectRatio, equals(0.36));

          // Verify summary card elements fit within bounds
          expect(find.text('ESTIMATED VAULT VALUE'), findsOneWidget);
          expect(find.byKey(const Key('vault_import_button')), findsOneWidget);

          // Verify cards are mounted without layout crash
          expect(find.byType(VaultItemTile), findsWidgets);
          await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
          await tester.pumpAndSettle();
          expect(find.textContaining('The One Ring'), findsWidgets);
          expect(find.textContaining('Sol Ring'), findsWidgets);

          // In pure Grid mode on 390px, check if overflow occurs
          expect(overflowErrors, isEmpty, reason: 'Grid layout overflow at 2.0x on 390px');
        } finally {
          FlutterError.onError = originalOnError;
        }

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 100));
      });

      testWidgets('VaultScreen List layout under 2.0x text scale renders cleanly with 0 RenderFlex overflows', (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await db.vaultDao.seedDatabase();

        final List<FlutterErrorDetails> overflowErrors = [];
        final originalOnError = FlutterError.onError;
        FlutterError.onError = (details) {
          if (details.toString().contains('overflowed') || details.toString().contains('RenderFlex')) {
            overflowErrors.add(details);
          }
        };

        try {
          await tester.pumpWidget(
            createVaultScreenHarness(
              textScaler: const TextScaler.linear(2.0),
              viewportSize: const Size(390, 844),
            ),
          );
          await tester.pump();
          await tester.pumpAndSettle();

          // Switch to List layout under 2.0x
          final listLayoutBtn = find.byKey(const Key('vault_layout_list_button'));
          await tester.tap(listLayoutBtn);
          await tester.pumpAndSettle();

          // Assert zero RenderFlex overflows occurred
          expect(
            overflowErrors,
            isEmpty,
            reason: 'RenderFlex overflow errors detected in List layout under 2.0x scale',
          );
          expect(find.byType(VaultItemCard), findsWidgets);
        } finally {
          FlutterError.onError = originalOnError;
        }

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 100));
      });

      testWidgets('VaultScreen Grid layout on narrow viewport (320px) under 2.0x text scale renders cleanly with 0 RenderFlex overflows', (tester) async {
        // iPhone SE / 320px width stress test
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await db.vaultDao.seedDatabase();

        final List<FlutterErrorDetails> overflowErrors = [];
        final originalOnError = FlutterError.onError;
        FlutterError.onError = (details) {
          if (details.toString().contains('overflowed') || details.toString().contains('RenderFlex')) {
            overflowErrors.add(details);
          }
        };

        try {
          await tester.pumpWidget(
            createVaultScreenHarness(
              textScaler: const TextScaler.linear(2.0),
              viewportSize: const Size(320, 568),
            ),
          );
          await tester.pump();
          await tester.pumpAndSettle();

          // Assert zero RenderFlex overflows occurred
          expect(
            overflowErrors,
            isEmpty,
            reason: 'RenderFlex overflow errors detected in Grid layout on 320px viewport under 2.0x scale',
          );
          expect(find.byType(VaultItemTile), findsWidgets);
        } finally {
          FlutterError.onError = originalOnError;
        }

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 100));
      });
    });
  });
}
