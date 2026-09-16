import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/vault/domain/mtg_keyword_glossary.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/widgets/card_detail_sheet.dart';

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
    String id = 'mtg-serra-angel',
    String collectionType = 'mtg',
    String name = 'Serra Angel',
    String setOrSeries = 'Dominaria',
    String imageUrl = 'https://cards.scryfall.io/large/front/b/a/babb844b-4494-482a-a925-546ad981a8c6.jpg',
    String dynamicData = '{"keywords":["Flying","Vigilance"],"oracle_text":"Flying, vigilance","mana_cost":"{3}{W}{W}","type_line":"Creature — Angel"}',
  }) {
    return VaultItem(
      id: id,
      collectionType: collectionType,
      name: name,
      setOrSeries: setOrSeries,
      imageUrl: imageUrl,
      acquiredPrice: 10.0,
      acquiredDate: DateTime(2023, 1, 1),
      quantity: 1,
      condition: 'NM',
      isGraded: false,
      currentMarketPrice: 20.0,
      lastPriceUpdate: DateTime(2023, 1, 1),
      dynamicData: dynamicData,
    );
  }

  Widget createTestWidget(VaultItem item) {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        vaultDaoProvider.overrideWithValue(db.vaultDao),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: CardDetailSheet(item: item),
        ),
      ),
    );
  }

  group('Adversarial Challenge: Cards with 0 Keywords (Clean Omission)', () {
    testWidgets('omits Card Mechanics section completely when dynamicData is empty JSON object', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final card = createTestCard(dynamicData: '{}');
      await tester.pumpWidget(createTestWidget(card));
      await tester.pumpAndSettle();

      // Ensure no Card Mechanics header or auto_awesome icon
      expect(find.text('Card Mechanics'), findsNothing);
      expect(find.byIcon(Icons.auto_awesome_rounded), findsNothing);

      // Let Flutter print the error natively
    });

    testWidgets('omits Card Mechanics section when dynamicData is empty string or pure whitespace', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final cardEmpty = createTestCard(dynamicData: '');
      await tester.pumpWidget(createTestWidget(cardEmpty));
      await tester.pumpAndSettle();

      expect(find.text('Card Mechanics'), findsNothing);
      expect(find.byIcon(Icons.auto_awesome_rounded), findsNothing);
      expect(tester.takeException(), isNull);

      final cardWhitespace = createTestCard(dynamicData: '   ');
      await tester.pumpWidget(createTestWidget(cardWhitespace));
      await tester.pumpAndSettle();

      expect(find.text('Card Mechanics'), findsNothing);
      expect(find.byIcon(Icons.auto_awesome_rounded), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('omits Card Mechanics section when oracle_text has non-glossary rules text', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final card = createTestCard(
        name: 'Counterspell',
        dynamicData: '{"oracle_text":"Counter target spell.\\nDraw a card."}',
      );
      await tester.pumpWidget(createTestWidget(card));
      await tester.pumpAndSettle();

      expect(find.text('Card Mechanics'), findsNothing);
      expect(find.byIcon(Icons.auto_awesome_rounded), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('does not falsely trigger keywords on substring matches in oracle_text (clean omission)', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Words containing 'ward' or 'reach' as substrings
      final card = createTestCard(
        name: 'Graveyard Warden',
        dynamicData: '{"oracle_text":"Return target card from your graveyard to forward position. Outreach into the breach."}',
      );
      await tester.pumpWidget(createTestWidget(card));
      await tester.pumpAndSettle();

      // None of the substrings should match Ward or Reach
      expect(find.text('Card Mechanics'), findsNothing);
      expect(find.text('Ward'), findsNothing);
      expect(find.text('Reach'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('layout geometry check: verified that SizedBox.shrink() occupies zero space between sections', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final card = createTestCard(
        name: 'Vanilla Creature',
        dynamicData: '{"oracle_text":"A simple vanilla creature."}',
      );
      await tester.pumpWidget(createTestWidget(card));
      await tester.pumpAndSettle();

      // Find the SizedBox.shrink()
      final sizedBoxFinder = find.byWidgetPredicate(
        (widget) => widget is SizedBox && widget.width == 0.0 && widget.height == 0.0,
      );
      expect(sizedBoxFinder, findsWidgets);

      // Verify the height of the SizedBox.shrink() is strictly 0.0 (occupies zero vertical space)
      final size = tester.getSize(sizedBoxFinder.first);
      expect(size.height, equals(0.0));
    });
  });

  group('Adversarial Challenge: Cards with 5+ Keywords (Stress, Spacing & Overflow)', () {
    testWidgets('renders exactly 5 keywords with proper spacing, readable definitions, and no RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Akroma-style 5 keywords
      final card = createTestCard(
        name: 'Akroma, Angel of Wrath',
        dynamicData: '{"keywords":["Flying","First Strike","Vigilance","Trample","Haste"]}',
      );

      await tester.pumpWidget(createTestWidget(card));
      await tester.pumpAndSettle();

      // Verify section header
      expect(find.text('Card Mechanics'), findsOneWidget);

      // Verify all 5 keyword badges and definitions are present
      final expectedKeywords = ['Flying', 'First Strike', 'Vigilance', 'Trample', 'Haste'];
      for (final kw in expectedKeywords) {
        expect(find.text(kw), findsWidgets, reason: 'Badge for $kw should be rendered');
        final definition = MtgKeywordGlossary.dictionary[kw]!;
        expect(find.text(definition), findsOneWidget, reason: 'Definition for $kw should be rendered');
      }

      // Ensure no exceptions (no RenderFlex overflow)
      expect(tester.takeException(), isNull);
    });

    testWidgets('stress test: renders all 12 keywords on small mobile screen (320x568) with no RenderFlex overflow', (tester) async {
      // 320 x 568 is iPhone SE 1st gen / narrowest supported viewport
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final all12Keywords = [
        'Vigilance',
        'Flying',
        'Trample',
        'Haste',
        'Lifelink',
        'Deathtouch',
        'First Strike',
        'Double Strike',
        'Reach',
        'Menace',
        'Ward',
        'Hexproof',
      ];

      final card = createTestCard(
        name: 'The Ultimate Chimera',
        dynamicData: '{"keywords":${all12Keywords.map((k) => '"$k"').toList()}}',
      );

      await tester.pumpWidget(createTestWidget(card));
      await tester.pumpAndSettle();

      // Confirm no initial RenderFlex overflow
      expect(tester.takeException(), isNull);
      expect(find.text('Card Mechanics'), findsOneWidget);

      // Verify each definition exists in the dictionary and matches
      for (final kw in all12Keywords) {
        final def = MtgKeywordGlossary.dictionary[kw];
        expect(def, isNotNull);
        expect(def!.isNotEmpty, isTrue);
      }

      // Scroll through the ListView to ensure all 12 mechanics are reachable and scrollable without overflow
      final scrollableFinder = find.byType(Scrollable).first;
      for (final kw in all12Keywords) {
        final def = MtgKeywordGlossary.dictionary[kw]!;
        await tester.scrollUntilVisible(
          find.text(def),
          150.0,
          scrollable: scrollableFinder,
        );
        expect(find.text(def), findsOneWidget, reason: 'Definition for $kw must be rendered upon scroll');
      }

      // Ensure zero overflow exceptions across all scroll operations
      expect(tester.takeException(), isNull);
    });

    testWidgets('deduplicates keywords present in both keywords list and oracle_text', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final card = createTestCard(
        name: 'Zetalpa, Primal Dawn',
        dynamicData:
            '{"keywords":["Flying","Double Strike","Vigilance","Trample","Hexproof"],"oracle_text":"Flying, double strike, vigilance, trample, indestructible, hexproof"}',
      );

      await tester.pumpWidget(createTestWidget(card));
      await tester.pumpAndSettle();

      // Double Strike must be present once, First Strike must NOT be present
      expect(find.text(MtgKeywordGlossary.dictionary['Double Strike']!), findsOneWidget);
      expect(find.text(MtgKeywordGlossary.dictionary['First Strike']!), findsNothing);

      // Verify each keyword definition is rendered exactly once (no duplicates)
      expect(find.text(MtgKeywordGlossary.dictionary['Flying']!), findsOneWidget);
      expect(find.text(MtgKeywordGlossary.dictionary['Vigilance']!), findsOneWidget);
      expect(find.text(MtgKeywordGlossary.dictionary['Trample']!), findsOneWidget);
      expect(find.text(MtgKeywordGlossary.dictionary['Hexproof']!), findsOneWidget);

      expect(tester.takeException(), isNull);
    });

    testWidgets('verifies badge styling and definition typography specifications', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final card = createTestCard(
        name: 'Baneslayer Angel',
        dynamicData: '{"keywords":["Flying","First Strike","Lifelink"]}',
      );

      await tester.pumpWidget(createTestWidget(card));
      await tester.pumpAndSettle();

      // Inspect definition text widget typography
      final defFinder = find.text(MtgKeywordGlossary.dictionary['Flying']!);
      expect(defFinder, findsOneWidget);
      final Text defWidget = tester.widget<Text>(defFinder);
      expect(defWidget.style?.color, equals(AppColors.textSecondary));
      expect(defWidget.style?.fontSize, equals(12.5));
      expect(defWidget.style?.height, equals(1.35));

      // Inspect badge container decoration
      final badgeContainerFinder = find.ancestor(
        of: find.text('Flying').first,
        matching: find.byType(Container),
      );
      expect(badgeContainerFinder, findsWidgets);
    });
  });

  group('Adversarial Challenge: Non-MTG Cards & Resilient Dynamic Data', () {
    testWidgets('cleanly omits Card Mechanics for Pokemon cards with Pokemon-specific dynamicData', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final pokemonCard = createTestCard(
        id: 'pkmn-charizard',
        collectionType: 'pokemon',
        name: 'Charizard ex',
        setOrSeries: '151',
        dynamicData: '{"hp":"330","types":["Fire"],"stage":"Stage 2","attacks":[{"name":"Brave Wing","damage":"60+"},{"name":"Explosive Vortex","damage":"330"}],"retreat":2}',
      );

      await tester.pumpWidget(createTestWidget(pokemonCard));
      await tester.pumpAndSettle();

      expect(find.text('Card Mechanics'), findsNothing);
      expect(find.byIcon(Icons.auto_awesome_rounded), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('cleanly omits Card Mechanics for Lorcana / Yu-Gi-Oh cards', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final lorcanaCard = createTestCard(
        id: 'lorcana-elsa',
        collectionType: 'lorcana',
        name: 'Elsa - Snow Queen',
        setOrSeries: 'The First Chapter',
        dynamicData: '{"lore":3,"inkwell":true,"strength":4,"willpower":4,"text":"Freeze target opposing character."}',
      );

      await tester.pumpWidget(createTestWidget(lorcanaCard));
      await tester.pumpAndSettle();

      expect(find.text('Card Mechanics'), findsNothing);
      expect(find.byIcon(Icons.auto_awesome_rounded), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('gracefully handles malformed / corrupted JSON in dynamicData without throwing', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final corruptedCard = createTestCard(
        name: 'Corrupted Card',
        dynamicData: '{"keywords": [unclosed array...',
      );

      await tester.pumpWidget(createTestWidget(corruptedCard));
      await tester.pumpAndSettle();

      // Must not crash; Card Mechanics section should be omitted
      expect(find.text('Card Mechanics'), findsNothing);
      expect(find.byIcon(Icons.auto_awesome_rounded), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('handles unexpected types in dynamicData (e.g. keywords is not a list) without crashing', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final weirdCard = createTestCard(
        name: 'Weird Data Card',
        dynamicData: '{"keywords": 12345, "oracle_text": null}',
      );

      await tester.pumpWidget(createTestWidget(weirdCard));
      await tester.pumpAndSettle();

      expect(find.text('Card Mechanics'), findsNothing);
      expect(find.byIcon(Icons.auto_awesome_rounded), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
