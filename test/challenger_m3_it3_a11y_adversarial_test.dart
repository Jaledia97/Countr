import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/widgets/card_detail_sheet.dart';
import 'package:countr/features/vault/presentation/widgets/full_screen_card_viewer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FullScreenCardViewer Adversarial Accessibility Suite', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    final dfcItem = VaultItem(
      id: 'test-dfc-a11y-001',
      collectionType: 'mtg',
      name: 'Delver of Secrets // Insectile Aberration',
      setOrSeries: 'ISD',
      imageUrl: 'https://cards.scryfall.io/front/delver.jpg',
      acquiredPrice: 4.50,
      acquiredDate: DateTime(2023, 5, 10),
      quantity: 1,
      condition: 'NM',
      isGraded: false, isAltered: false, isMisprint: false, isSigned: false,
      currentMarketPrice: 5.00,
      lastPriceUpdate: DateTime(2023, 5, 10),
      dynamicData: jsonEncode({
        'card_faces': [
          {
            'name': 'Delver of Secrets',
            'image_uris': {'normal': 'https://cards.scryfall.io/front/delver.jpg'},
          },
          {
            'name': 'Insectile Aberration',
            'image_uris': {'normal': 'https://cards.scryfall.io/back/insectile.jpg'},
          },
        ],
      }),
    );

    final singleFacedItem = VaultItem(
      id: 'test-single-a11y-002',
      collectionType: 'mtg',
      name: 'Black Lotus',
      setOrSeries: 'LEA',
      imageUrl: 'https://cards.scryfall.io/front/lotus.jpg',
      acquiredPrice: 10000.0,
      acquiredDate: DateTime(2023, 1, 1),
      quantity: 1,
      condition: 'NM',
      isGraded: true, isAltered: false, isMisprint: false, isSigned: false,
      currentMarketPrice: 25000.0,
      lastPriceUpdate: DateTime(2023, 1, 1),
      dynamicData: '{}',
    );

    testWidgets('DFC initial state: passes labeledTapTargetGuideline', (tester) async {
      final handle = tester.ensureSemantics();
      try {
        await tester.pumpWidget(MaterialApp(home: FullScreenCardViewer(item: dfcItem)));
        await tester.pumpAndSettle();

        final eval = await labeledTapTargetGuideline.evaluate(tester);
        expect(eval.passed, isTrue, reason: 'DFC initial state failed labeledTapTargetGuideline: ${eval.reason}');
      } finally {
        handle.dispose();
      }
    });

    testWidgets('Single-faced item: passes labeledTapTargetGuideline', (tester) async {
      final handle = tester.ensureSemantics();
      try {
        await tester.pumpWidget(MaterialApp(home: FullScreenCardViewer(item: singleFacedItem)));
        await tester.pumpAndSettle();

        final eval = await labeledTapTargetGuideline.evaluate(tester);
        expect(eval.passed, isTrue, reason: 'Single-faced failed labeledTapTargetGuideline: ${eval.reason}');
      } finally {
        handle.dispose();
      }
    });

    testWidgets('Flipped state: passes labeledTapTargetGuideline after card flip animation', (tester) async {
      final handle = tester.ensureSemantics();
      try {
        await tester.pumpWidget(MaterialApp(home: FullScreenCardViewer(item: dfcItem)));
        await tester.pumpAndSettle();

        final flipBtn = find.byKey(const Key('fullscreen_flip_button'));
        expect(flipBtn, findsOneWidget);

        await tester.tap(flipBtn);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();

        final eval = await labeledTapTargetGuideline.evaluate(tester);
        expect(eval.passed, isTrue, reason: 'Flipped state failed labeledTapTargetGuideline: ${eval.reason}');
      } finally {
        handle.dispose();
      }
    });

    testWidgets('Foil finish active: passes labeledTapTargetGuideline', (tester) async {
      final handle = tester.ensureSemantics();
      try {
        await tester.pumpWidget(MaterialApp(home: FullScreenCardViewer(item: dfcItem)));
        await tester.pumpAndSettle();

        final foilToggle = find.byKey(const Key('fullscreen_foil_toggle'));
        expect(foilToggle, findsOneWidget);

        await tester.tap(foilToggle);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        final eval = await labeledTapTargetGuideline.evaluate(tester);
        expect(eval.passed, isTrue, reason: 'Foil active failed labeledTapTargetGuideline: ${eval.reason}');
      } finally {
        handle.dispose();
      }
    });

    testWidgets('All tappable elements meet Android (48x48) & iOS (44x44) touch target guidelines', (tester) async {
      final handle = tester.ensureSemantics();
      try {
        await tester.pumpWidget(MaterialApp(home: FullScreenCardViewer(item: dfcItem)));
        await tester.pumpAndSettle();

        // 1. Close button
        final closeBtn = find.byKey(const Key('fullscreen_close_button'));
        final closeBox = tester.renderObject<RenderBox>(closeBtn);
        expect(closeBox.size.width, greaterThanOrEqualTo(48.0), reason: 'Close button width < 48');
        expect(closeBox.size.height, greaterThanOrEqualTo(48.0), reason: 'Close button height < 48');

        // 2. Flip button
        final flipBtn = find.byKey(const Key('fullscreen_flip_button'));
        final flipBox = tester.renderObject<RenderBox>(flipBtn);
        expect(flipBox.size.width, greaterThanOrEqualTo(48.0), reason: 'Flip button width < 48');
        expect(flipBox.size.height, greaterThanOrEqualTo(48.0), reason: 'Flip button height < 48');

        // 3. Foil toggle chip
        final foilBtn = find.byKey(const Key('fullscreen_foil_toggle'));
        final foilBox = tester.renderObject<RenderBox>(foilBtn);
        expect(foilBox.size.height, greaterThanOrEqualTo(32.0));
      } finally {
        handle.dispose();
      }
    });

    testWidgets('androidTapTargetGuideline evaluation on FullScreenCardViewer', (tester) async {
      final handle = tester.ensureSemantics();
      try {
        await tester.pumpWidget(MaterialApp(home: FullScreenCardViewer(item: dfcItem)));
        await tester.pumpAndSettle();

        final eval = await androidTapTargetGuideline.evaluate(tester);
        expect(eval.passed, isTrue, reason: 'androidTapTargetGuideline reason: ${eval.reason}');
      } finally {
        handle.dispose();
      }
    });

    testWidgets('iOSTapTargetGuideline evaluation on FullScreenCardViewer', (tester) async {
      final handle = tester.ensureSemantics();
      try {
        await tester.pumpWidget(MaterialApp(home: FullScreenCardViewer(item: dfcItem)));
        await tester.pumpAndSettle();

        final eval = await iOSTapTargetGuideline.evaluate(tester);
        expect(eval.passed, isTrue, reason: 'iOSTapTargetGuideline reason: ${eval.reason}');
      } finally {
        handle.dispose();
      }
    });

    testWidgets('CardDetailSheet a11y: evaluate labeledTapTargetGuideline across CardDetailSheet', (tester) async {
      final handle = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              vaultDaoProvider.overrideWithValue(db.vaultDao),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: CardDetailSheet(item: dfcItem),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final eval = await labeledTapTargetGuideline.evaluate(tester);
        expect(eval.passed, isTrue, reason: 'CardDetailSheet failed labeledTapTargetGuideline: ${eval.reason}');
      } finally {
        handle.dispose();
      }
    });
  });
}
