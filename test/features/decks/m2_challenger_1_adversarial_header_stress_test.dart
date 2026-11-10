import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/decks/data/daos/explore_deck_dao.dart';
import 'package:countr/features/decks/presentation/providers/explore_deck_providers.dart';
import 'package:countr/features/decks/presentation/widgets/explore/explore_category_drill_down_view.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Milestone 2 Challenger 1: Adversarial Header Stress Test Suite', () {
    late AppDatabase db;
    late ExploreDeckDao exploreDao;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      exploreDao = ExploreDeckDao(db);
    });

    tearDown(() async {
      await db.close();
    });

    Widget buildTestWidget({
      required double width,
      required double height,
      required double textScale,
      required String category,
      VoidCallback? onBack,
    }) {
      return ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          exploreDeckDaoProvider.overrideWithValue(exploreDao),
        ],
        child: MediaQuery(
          data: MediaQueryData(
            size: Size(width, height),
            textScaler: TextScaler.linear(textScale),
          ),
          child: MaterialApp(
            home: Scaffold(
              body: ExploreCategoryDrillDownView(
                category: category,
                onBack: onBack,
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('1. 360px standard mobile viewport: zero RenderFlex overflows with 1.5x font scale', (tester) async {
      tester.view.physicalSize = const Size(360, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      FlutterErrorDetails? caughtDetails;
      final origOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        caughtDetails = details;
        origOnError?.call(details);
      };
      addTearDown(() {
        FlutterError.onError = origOnError;
      });

      await tester.pumpWidget(
        buildTestWidget(
          width: 360,
          height: 600,
          textScale: 1.5,
          category: 'Suggested Commanders',
        ),
      );
      await tester.pumpAndSettle();

      if (caughtDetails != null) {
        // ignore: avoid_print
        print('=== TEST 1 CAUGHT FLUTTER ERROR ===\n$caughtDetails\n===================================');
      }

      final error = tester.takeException();
      expect(
        error,
        isNull,
        reason: '360px screen with 1.5x text scaling must not produce any RenderFlex overflow',
      );
    });

    testWidgets('2. 375px mobile viewport: zero RenderFlex overflows with 1.5x font scale', (tester) async {
      tester.view.physicalSize = const Size(375, 667);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      FlutterErrorDetails? caughtDetails;
      final origOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        caughtDetails = details;
        origOnError?.call(details);
      };
      addTearDown(() {
        FlutterError.onError = origOnError;
      });

      await tester.pumpWidget(
        buildTestWidget(
          width: 375,
          height: 667,
          textScale: 1.5,
          category: 'Suggested Commanders',
        ),
      );
      await tester.pumpAndSettle();

      if (caughtDetails != null) {
        // ignore: avoid_print
        print('=== TEST 2 CAUGHT FLUTTER ERROR ===\n$caughtDetails\n===================================');
      }

      final error = tester.takeException();
      expect(
        error,
        isNull,
        reason: '375px screen with 1.5x text scaling must not produce any RenderFlex overflow',
      );
    });

    testWidgets('3. 300px extreme narrow viewport: zero RenderFlex overflows with 2.0x font scale', (tester) async {
      tester.view.physicalSize = const Size(300, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      FlutterErrorDetails? caughtDetails;
      final origOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        caughtDetails = details;
        origOnError?.call(details);
      };
      addTearDown(() {
        FlutterError.onError = origOnError;
      });

      await tester.pumpWidget(
        buildTestWidget(
          width: 300,
          height: 600,
          textScale: 2.0,
          category: 'Suggested Commanders',
        ),
      );
      await tester.pumpAndSettle();

      if (caughtDetails != null) {
        // ignore: avoid_print
        print('=== TEST 3 CAUGHT FLUTTER ERROR ===\n$caughtDetails\n===================================');
      }

      final error = tester.takeException();
      expect(
        error,
        isNull,
        reason: '300px screen with 2.0x text scaling must not produce any RenderFlex overflow',
      );
    });

    testWidgets('4. 320px narrow mobile viewport: zero RenderFlex overflows across 1.0x to 2.0x font scale', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      for (final scale in [1.0, 1.2, 1.5, 2.0]) {
        await tester.pumpWidget(
          buildTestWidget(
            width: 320,
            height: 568,
            textScale: scale,
            category: 'Suggested Commanders',
          ),
        );
        await tester.pumpAndSettle();

        expect(
          tester.takeException(),
          isNull,
          reason: '320px viewport must not overflow at scale factor $scale',
        );
      }
    });

    testWidgets('5. Long category titles on narrow viewports truncate with ellipsis without overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const longTitle = 'Super Long Category Title That Exceeds The Maximum Available Horizontal Bounds';

      await tester.pumpWidget(
        buildTestWidget(
          width: 320,
          height: 568,
          textScale: 1.2,
          category: longTitle,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('explore_drill_down_title')), findsOneWidget);
      expect(find.text(longTitle), findsOneWidget);
    });

    testWidgets('6. Back and Reset buttons hit targets remain responsive under narrow viewports', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      bool backInvoked = false;

      await tester.pumpWidget(
        buildTestWidget(
          width: 320,
          height: 568,
          textScale: 1.2,
          category: 'Suggested Commanders',
          onBack: () => backInvoked = true,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      // Verify back button tap
      await tester.tap(find.byKey(const Key('explore_drill_down_back_button')));
      await tester.pumpAndSettle();
      expect(backInvoked, isTrue);

      backInvoked = false;

      // Verify reset button tap
      await tester.tap(find.byKey(const Key('explore_drill_down_reset_button')));
      await tester.pumpAndSettle();
      expect(backInvoked, isTrue);
    });
  });
}
