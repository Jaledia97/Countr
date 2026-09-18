import 'dart:convert';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/hydration/domain/isolate/scryfall_parser.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/widgets/card_detail_sheet.dart';
import 'package:countr/features/vault/presentation/widgets/full_screen_card_viewer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('Adversarial Challenge 1: Universes Beyond Parser Edge Cases', () {
    test('casing variations in promo_types evaluate correctly to is_universes_beyond == true', () {
      final variations = [
        'UNIVERSES_BEYOND',
        'universes_beyond',
        'uNiVeRsEs_BeYoNd',
        'UNIVERSESBEYOND',
        'universesbeyond',
        'UnIvErSeSbEyOnD',
      ];

      for (final pt in variations) {
        final card = {
          'id': 'ub-pt-$pt',
          'name': 'Test Card $pt',
          'set': 'ltr',
          'set_name': 'The Lord of the Rings: Tales of Middle-earth',
          'promo_types': [pt, 'boosterfun'],
        };
        final comp = mapScryfallCardToCompanion(card);
        final dyn = jsonDecode(comp.dynamicData.value) as Map<String, dynamic>;
        expect(
          dyn['is_universes_beyond'],
          isTrue,
          reason: 'Failed to identify Universes Beyond for promo_type: "$pt"',
        );
        expect((dyn['promo_types'] as List).contains(pt.toLowerCase()), isTrue);
      }
    });

    test('casing variations in frame_effects evaluate correctly to is_universes_beyond == true', () {
      final variations = [
        'UNIVERSESBEYOND',
        'universesbeyond',
        'uNiVeRsEsBeYoNd',
        'UNIVERSES_BEYOND',
        'universes_beyond',
      ];

      for (final fe in variations) {
        final card = {
          'id': 'ub-fe-$fe',
          'name': 'Test Transformer $fe',
          'set': 'bot',
          'set_name': 'Transformers',
          'frame_effects': [fe, 'showcase'],
        };
        final comp = mapScryfallCardToCompanion(card);
        final dyn = jsonDecode(comp.dynamicData.value) as Map<String, dynamic>;
        expect(
          dyn['is_universes_beyond'],
          isTrue,
          reason: 'Failed to identify Universes Beyond for frame_effect: "$fe"',
        );
      }
    });

    test('security_stamp case-insensitivity: TRIANGLE vs triangle', () {
      for (final stamp in ['TRIANGLE', 'triangle', 'TrIaNgLe', 'Triangle']) {
        final card = {
          'id': 'ub-stamp-$stamp',
          'name': 'Warhammer Card $stamp',
          'set': '40k',
          'security_stamp': stamp,
        };
        final comp = mapScryfallCardToCompanion(card);
        final dyn = jsonDecode(comp.dynamicData.value) as Map<String, dynamic>;
        expect(
          dyn['is_universes_beyond'],
          isTrue,
          reason: 'Failed for security_stamp: "$stamp"',
        );
        expect(dyn['security_stamp'], equals('triangle'));
      }
    });

    test('negative controls: in-universe promo types, frame effects, and stamps', () {
      final card = {
        'id': 'in-universe-1',
        'name': 'Standard Card',
        'set': 'neo',
        'set_name': 'Kamigawa: Neon Dynasty',
        'promo_types': ['boosterfun', 'prerelease', 'stamped', 'not_universes_beyond'],
        'frame_effects': ['showcase', 'extendedart', 'legendary', 'snow'],
        'security_stamp': 'oval',
      };
      final comp = mapScryfallCardToCompanion(card);
      final dyn = jsonDecode(comp.dynamicData.value) as Map<String, dynamic>;
      expect(dyn['is_universes_beyond'], isFalse);
      expect(dyn['security_stamp'], 'oval');
    });

    test('null, empty lists, and missing metadata fields parse safely without crashing', () {
      final emptyCard = <String, dynamic>{};
      final compEmpty = mapScryfallCardToCompanion(emptyCard);
      final dynEmpty = jsonDecode(compEmpty.dynamicData.value) as Map<String, dynamic>;
      expect(dynEmpty['is_universes_beyond'], isFalse);
      expect(dynEmpty['promo_types'], isEmpty);
      expect(dynEmpty['frame_effects'], isEmpty);
      expect(dynEmpty['security_stamp'], isEmpty);

      final nullListsCard = <String, dynamic>{
        'id': 'card-null-lists',
        'name': 'Null List Card',
        'promo_types': null,
        'frame_effects': null,
        'security_stamp': null,
        'card_faces': null,
        'image_uris': null,
        'prices': null,
      };
      final compNull = mapScryfallCardToCompanion(nullListsCard);
      final dynNull = jsonDecode(compNull.dynamicData.value) as Map<String, dynamic>;
      expect(dynNull['is_universes_beyond'], isFalse);
      expect(dynNull['promo_types'], isEmpty);
      expect(dynNull['frame_effects'], isEmpty);
      expect(dynNull['security_stamp'], isEmpty);
    });

    test('non-string items inside promo_types and frame_effects lists parse safely', () {
      final corruptedListsCard = <String, dynamic>{
        'id': 'card-corrupted-lists',
        'name': 'Corrupted List Card',
        'promo_types': [123, null, true, {'not': 'string'}, [1, 2], 'UNIVERSES_BEYOND'],
        'frame_effects': [456, false, null, {'obj': 1}],
      };
      final comp = mapScryfallCardToCompanion(corruptedListsCard);
      final dyn = jsonDecode(comp.dynamicData.value) as Map<String, dynamic>;
      expect(dyn['is_universes_beyond'], isTrue);
      expect((dyn['promo_types'] as List).contains('universes_beyond'), isTrue);

      final nonUbCorruptedCard = <String, dynamic>{
        'id': 'card-corrupted-non-ub',
        'name': 'Corrupted Non UB',
        'promo_types': [789, null, false, {'a': 'b'}],
        'frame_effects': [999, true, null],
        'security_stamp': 42,
      };
      final compNonUb = mapScryfallCardToCompanion(nonUbCorruptedCard);
      final dynNonUb = jsonDecode(compNonUb.dynamicData.value) as Map<String, dynamic>;
      expect(dynNonUb['is_universes_beyond'], isFalse);
    });

    test('security_stamp values taxonomy: triangle vs oval vs null vs non-standard', () {
      final tests = {
        'triangle': true,
        'TRIANGLE': true,
        'oval': false,
        'OVAL': false,
        null: false,
        '': false,
        'acorn': false, // Un-sets
        'arena': false, // Arena digital stamp
        'heart': false, // Extra Life / Ponies: The Galloping
        'circle': false, // Mystery Booster / The List
      };

      for (final entry in tests.entries) {
        final card = {
          'id': 'stamp-taxonomy-${entry.key}',
          'name': 'Stamp Test Card',
          if (entry.key != null) 'security_stamp': entry.key,
        };
        final comp = mapScryfallCardToCompanion(card);
        final dyn = jsonDecode(comp.dynamicData.value) as Map<String, dynamic>;
        expect(
          dyn['is_universes_beyond'],
          equals(entry.value),
          reason: 'Failed security_stamp taxonomy check for stamp: "${entry.key}"',
        );
      }
    });

    test('crossover sets without promo_types are identified via triangle stamp or frame effects', () {
      // 1. Warhammer 40,000 (40k) card without promo_types, identified via security_stamp == triangle
      final wh40kCard = {
        'id': 'wh40k-card-1',
        'name': 'Inquisitor Greyfax',
        'set': '40k',
        'set_name': 'Warhammer 40,000',
        'security_stamp': 'triangle',
        'promo_types': null,
        'frame_effects': null,
      };
      final whComp = mapScryfallCardToCompanion(wh40kCard);
      final whDyn = jsonDecode(whComp.dynamicData.value) as Map<String, dynamic>;
      expect(whDyn['is_universes_beyond'], isTrue);
      expect(whDyn['set'], '40k');

      // 2. Transformers (bot) card without promo_types, identified via frame_effects == universesbeyond
      final botCard = {
        'id': 'bot-card-1',
        'name': 'Starscream, Power Hungry',
        'set': 'bot',
        'set_name': 'Transformers',
        'promo_types': <String>[],
        'frame_effects': ['universesbeyond'],
      };
      final botComp = mapScryfallCardToCompanion(botCard);
      final botDyn = jsonDecode(botComp.dynamicData.value) as Map<String, dynamic>;
      expect(botDyn['is_universes_beyond'], isTrue);
      expect(botDyn['set'], 'bot');

      // 3. Doctor Who (who) card without promo_types, identified via security_stamp == triangle
      final whoCard = {
        'id': 'who-card-1',
        'name': 'The Tenth Doctor',
        'set': 'who',
        'set_name': 'Doctor Who',
        'security_stamp': 'TRIANGLE',
      };
      final whoComp = mapScryfallCardToCompanion(whoCard);
      final whoDyn = jsonDecode(whoComp.dynamicData.value) as Map<String, dynamic>;
      expect(whoDyn['is_universes_beyond'], isTrue);
      expect(whoDyn['set'], 'who');

      // 4. Fallout (pip) card without promo_types, identified via security_stamp == triangle
      final pipCard = {
        'id': 'pip-card-1',
        'name': 'Dogmeat, Danger Hound',
        'set': 'pip',
        'set_name': 'Fallout',
        'security_stamp': 'triangle',
      };
      final pipComp = mapScryfallCardToCompanion(pipCard);
      final pipDyn = jsonDecode(pipComp.dynamicData.value) as Map<String, dynamic>;
      expect(pipDyn['is_universes_beyond'], isTrue);
      expect(pipDyn['set'], 'pip');

      // 5. Regular in-universe card from Dominaria United (dmu) with security_stamp == oval
      final dmuCard = {
        'id': 'dmu-card-1',
        'name': 'Sheoldred, the Apocalypse',
        'set': 'dmu',
        'set_name': 'Dominaria United',
        'security_stamp': 'oval',
        'promo_types': null,
      };
      final dmuComp = mapScryfallCardToCompanion(dmuCard);
      final dmuDyn = jsonDecode(dmuComp.dynamicData.value) as Map<String, dynamic>;
      expect(dmuDyn['is_universes_beyond'], isFalse);
      expect(dmuDyn['set'], 'dmu');
    });

    test('crossover multi-faced card with promo_types or stamp on face level is detected', () {
      final faceLevelUbCard = {
        'id': 'dfc-face-ub',
        'name': 'Slicen Dice // Autobot',
        'set': 'bot',
        'set_name': 'Transformers',
        'layout': 'transform',
        'card_faces': [
          {
            'name': 'Slicen Dice',
            'security_stamp': 'triangle',
            'oracle_text': 'More Than Meets the Eye',
            'image_uris': {'normal': 'https://example.com/slice.jpg'},
          },
          {
            'name': 'Autobot',
            'oracle_text': 'Living Metal',
            'image_uris': {'normal': 'https://example.com/autobot.jpg'},
          },
        ],
      };
      final comp = mapScryfallCardToCompanion(faceLevelUbCard);
      final dyn = jsonDecode(comp.dynamicData.value) as Map<String, dynamic>;
      expect(dyn['is_universes_beyond'], isTrue);
      expect(dyn['security_stamp'], 'triangle');
    });
  });

  group('Adversarial Challenge 2: Adventure vs DFC Layout & Flip Controls Suppression', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    Widget createSheetApp(VaultItem item) {
      return ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
        ],
        child: MaterialApp(home: Scaffold(body: CardDetailSheet(item: item))),
      );
    }

    testWidgets('Adventure cards with various unusual type lines strictly suppress flip controls',
        (WidgetTester tester) async {
      final unusualTypeLines = [
        'Creature — Elf Knight // Instant — Adventure',
        'Legendary Creature — Human Noble // Sorcery — Adventure',
        'Artifact Creature — Construct // Instant — Adventure',
        'Enchantment Creature — Nymph // Instant — Adventure',
        'Kindred Instant — Adventure',
        'Creature — Giant Adventure',
        'Instant - Adventure', // Hyphen instead of em-dash
        'Creature — Dragon // Sorcery — Adventure',
      ];

      for (int i = 0; i < unusualTypeLines.length; i++) {
        final typeLine = unusualTypeLines[i];
        final cardItem = VaultItem(
          id: 'adv-unusual-$i',
          collectionType: 'mtg',
          name: 'Adventure Hero $i // Spell $i',
          setOrSeries: 'Throne of Eldraine',
          imageUrl: 'https://example.com/adv_$i.jpg',
          acquiredPrice: 1.0,
          acquiredDate: DateTime(2023, 1, 1),
          quantity: 1,
          condition: 'NM',
          isGraded: false,
          isAltered: false,
          isMisprint: false,
          isSigned: false,
          currentMarketPrice: 2.0,
          lastPriceUpdate: DateTime(2023, 1, 1),
          dynamicData: jsonEncode({
            'layout': 'adventure',
            'type_line': typeLine,
            'oracle_text': 'Creature ability // Adventure spell effect',
            'card_faces': [
              {
                'name': 'Adventure Hero $i',
                'type_line': typeLine.split('//').first.trim(),
                'oracle_text': 'Creature ability',
                'power': '3',
                'toughness': '3',
              },
              {
                'name': 'Spell $i',
                'type_line': typeLine.contains('//') ? typeLine.split('//').last.trim() : 'Instant — Adventure',
                'oracle_text': 'Adventure spell effect',
              },
            ],
          }),
        );

        // 1. Verify CardDetailSheet flip controls are NEVER rendered
        await tester.pumpWidget(createSheetApp(cardItem));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('card_detail_flip_button')),
          findsNothing,
          reason: 'card_detail_flip_button should not exist for typeLine: "$typeLine"',
        );
        expect(
          find.byKey(const Key('card_detail_switch_face_button')),
          findsNothing,
          reason: 'card_detail_switch_face_button should not exist for typeLine: "$typeLine"',
        );

        // Verify unified rules box renders ADVENTURE SPELL banner and both texts
        expect(find.text('ADVENTURE SPELL'), findsOneWidget);
        expect(find.text('Creature ability'), findsOneWidget);
        expect(find.text('Adventure spell effect'), findsOneWidget);

        // 2. Verify FullScreenCardViewer flip controls are NEVER rendered
        await tester.pumpWidget(MaterialApp(home: FullScreenCardViewer(item: cardItem)));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('fullscreen_appbar_flip_button')),
          findsNothing,
          reason: 'fullscreen_appbar_flip_button should not exist for typeLine: "$typeLine"',
        );
        expect(
          find.byKey(const Key('fullscreen_flip_button')),
          findsNothing,
          reason: 'fullscreen_flip_button should not exist for typeLine: "$typeLine"',
        );
        expect(
          find.textContaining('Face 1 of 2'),
          findsNothing,
          reason: 'FullScreenCardViewer should not claim 2 faces for adventure card',
        );
      }
    });

    testWidgets('Adventure cards with various split names suppress flip controls and never flip on tap',
        (WidgetTester tester) async {
      final splitNames = [
        'Brazen Borrower // Petty Theft',
        'Murderous Rider // Swift End',
        'Lovestruck Beast // Heart\'s Desire',
        'Fae of Wishes // Granted',
        'Giant Killer // Chop Down',
        'Bonecrusher Giant  //  Stomp', // extra whitespace
        'Realm-Cloaked Giant//Cast Off', // no space around slash
      ];

      for (int i = 0; i < splitNames.length; i++) {
        final splitName = splitNames[i];
        final cardItem = VaultItem(
          id: 'adv-split-$i',
          collectionType: 'mtg',
          name: splitName,
          setOrSeries: 'Throne of Eldraine',
          imageUrl: 'https://example.com/split_$i.jpg',
          acquiredPrice: 2.0,
          acquiredDate: DateTime(2023, 1, 1),
          quantity: 1,
          condition: 'NM',
          isGraded: false,
          isAltered: false,
          isMisprint: false,
          isSigned: false,
          currentMarketPrice: 3.5,
          lastPriceUpdate: DateTime(2023, 1, 1),
          dynamicData: jsonEncode({
            'layout': 'adventure',
            'type_line': 'Creature // Instant — Adventure',
            'oracle_text': 'Permanent effect // Adventure effect',
          }),
        );

        await tester.pumpWidget(createSheetApp(cardItem));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('card_detail_flip_button')), findsNothing);
        expect(find.byKey(const Key('card_detail_switch_face_button')), findsNothing);

        // Attempt to tap the artwork Hero
        final artworkHero = find.byKey(Key('card_artwork_${cardItem.id}'));
        expect(artworkHero, findsOneWidget);
        await tester.tap(artworkHero);
        await tester.pumpAndSettle();

        // Verify still no flip button or flip state change
        expect(find.text('View Face 1'), findsNothing);
        expect(find.text('View Face 2'), findsNothing);
      }
    });

    testWidgets('Adventure card where layout is missing from dynamicData but type_line indicates adventure',
        (WidgetTester tester) async {
      final unhydratedAdventure = VaultItem(
        id: 'adv-missing-layout',
        collectionType: 'mtg',
        name: 'Curious Pair // Treats to Share',
        setOrSeries: 'ELD',
        imageUrl: 'https://example.com/curious.jpg',
        acquiredPrice: 0.25,
        acquiredDate: DateTime(2023, 1, 1),
        quantity: 1,
        condition: 'NM',
        isGraded: false,
        isAltered: false,
        isMisprint: false,
        isSigned: false,
        currentMarketPrice: 0.25,
        lastPriceUpdate: DateTime(2023, 1, 1),
        dynamicData: jsonEncode({
          'type_line': 'Creature — Human Peasant // Sorcery — Adventure',
          'oracle_text': 'Vanilla creature // Create a Food token.',
        }),
      );

      await tester.pumpWidget(createSheetApp(unhydratedAdventure));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('card_detail_flip_button')), findsNothing);
      expect(find.byKey(const Key('card_detail_switch_face_button')), findsNothing);
      expect(find.text('ADVENTURE SPELL'), findsOneWidget);
    });
  });

  group('Adversarial Challenge 3: DFC Cards Retain 3D Flip Animation', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    Widget createSheetApp(VaultItem item) {
      return ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
        ],
        child: MaterialApp(home: Scaffold(body: CardDetailSheet(item: item))),
      );
    }

    testWidgets('Modal DFC (modal_dfc) card: 3D flip animation, face switching, and interactive toggle',
        (WidgetTester tester) async {
      final mdfcCard = VaultItem(
        id: 'valki-mdfc',
        collectionType: 'mtg',
        name: 'Valki, God of Lies // Tibalt, Cosmic Impostor',
        setOrSeries: 'Kaldheim',
        imageUrl: 'https://cards.scryfall.io/front/valki.jpg',
        acquiredPrice: 8.0,
        acquiredDate: DateTime(2023, 1, 1),
        quantity: 1,
        condition: 'NM',
        isGraded: false,
        isAltered: false,
        isMisprint: false,
        isSigned: false,
        currentMarketPrice: 12.0,
        lastPriceUpdate: DateTime(2023, 1, 1),
        dynamicData: jsonEncode({
          'layout': 'modal_dfc',
          'card_faces': [
            {
              'name': 'Valki, God of Lies',
              'mana_cost': '{1}{B}',
              'type_line': 'Legendary Creature — God',
              'oracle_text': 'When Valki enters the battlefield...',
              'power': '2',
              'toughness': '1',
              'image_uris': {'normal': 'https://cards.scryfall.io/front/valki.jpg'},
            },
            {
              'name': 'Tibalt, Cosmic Impostor',
              'mana_cost': '{5}{B}{R}',
              'type_line': 'Legendary Planeswalker — Tibalt',
              'oracle_text': 'As Tibalt enters the battlefield...',
              'loyalty': '5',
              'image_uris': {'normal': 'https://cards.scryfall.io/back/tibalt.jpg'},
            },
          ],
        }),
      );

      await tester.pumpWidget(createSheetApp(mdfcCard));
      await tester.pumpAndSettle();

      // Verify controls exist
      final flipBtn = find.byKey(const Key('card_detail_flip_button'));
      final switchBtn = find.byKey(const Key('card_detail_switch_face_button'));
      expect(flipBtn, findsOneWidget);
      expect(switchBtn, findsOneWidget);
      expect(find.text('View Face 2'), findsOneWidget);
      expect(find.text('Valki, God of Lies'), findsWidgets);

      // Tap flip button to trigger 3D animation
      await tester.tap(flipBtn);
      // Pump halfway (200ms of 400ms duration) to inspect in-flight 3D transform
      await tester.pump(const Duration(milliseconds: 200));

      // Settle to complete animation
      await tester.pumpAndSettle();

      // Face toggle button now indicates Face 1
      expect(find.text('View Face 1'), findsOneWidget);

      // Tap switch face button to return to Front face
      await tester.tap(switchBtn);
      await tester.pumpAndSettle();
      expect(find.text('View Face 2'), findsOneWidget);

      // Now verify in FullScreenCardViewer
      await tester.pumpWidget(MaterialApp(home: FullScreenCardViewer(item: mdfcCard)));
      await tester.pumpAndSettle();

      final fsFlipBtn = find.byKey(const Key('fullscreen_flip_button'));
      final fsAppBarFlip = find.byKey(const Key('fullscreen_appbar_flip_button'));
      expect(fsFlipBtn, findsOneWidget);
      expect(fsAppBarFlip, findsOneWidget);
      expect(find.text('Back Face'), findsOneWidget);

      // Tap fullscreen floating flip button
      await tester.tap(fsFlipBtn);
      await tester.pumpAndSettle();
      expect(find.text('Front Face'), findsOneWidget);

      // Tap fullscreen appbar flip button to flip back
      await tester.tap(fsAppBarFlip);
      await tester.pumpAndSettle();
      expect(find.text('Back Face'), findsOneWidget);
    });

    testWidgets('Transform DFC (transform) card: 3D flip animation, face switching, and interactive toggle',
        (WidgetTester tester) async {
      final transformCard = VaultItem(
        id: 'avacyn-dfc',
        collectionType: 'mtg',
        name: 'Archangel Avacyn // Avacyn, the Purifier',
        setOrSeries: 'Shadows over Innistrad',
        imageUrl: 'https://cards.scryfall.io/front/avacyn.jpg',
        acquiredPrice: 15.0,
        acquiredDate: DateTime(2023, 1, 1),
        quantity: 1,
        condition: 'NM',
        isGraded: false,
        isAltered: false,
        isMisprint: false,
        isSigned: false,
        currentMarketPrice: 22.0,
        lastPriceUpdate: DateTime(2023, 1, 1),
        dynamicData: jsonEncode({
          'layout': 'transform',
          'card_faces': [
            {
              'name': 'Archangel Avacyn',
              'mana_cost': '{3}{W}{W}',
              'type_line': 'Legendary Creature — Angel',
              'oracle_text': 'Flash, flying, vigilance',
              'power': '4',
              'toughness': '4',
              'image_uris': {'normal': 'https://cards.scryfall.io/front/avacyn.jpg'},
            },
            {
              'name': 'Avacyn, the Purifier',
              'type_line': 'Legendary Creature — Angel',
              'oracle_text': 'Flying. When this creature transforms...',
              'power': '6',
              'toughness': '5',
              'image_uris': {'normal': 'https://cards.scryfall.io/back/purifier.jpg'},
            },
          ],
        }),
      );

      await tester.pumpWidget(createSheetApp(transformCard));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('card_detail_flip_button')), findsOneWidget);
      expect(find.byKey(const Key('card_detail_switch_face_button')), findsOneWidget);
      expect(find.text('View Face 2'), findsOneWidget);

      // Tap flip button
      await tester.tap(find.byKey(const Key('card_detail_flip_button')));
      await tester.pumpAndSettle();

      expect(find.text('View Face 1'), findsOneWidget);
    });

    testWidgets('Non-DFC single-faced cards (normal, split, flip, saga) strictly suppress flip controls',
        (WidgetTester tester) async {
      final nonDfcLayouts = ['normal', 'split', 'flip', 'saga', 'leveler', 'class'];

      for (final layout in nonDfcLayouts) {
        final card = VaultItem(
          id: 'non-dfc-$layout',
          collectionType: 'mtg',
          name: 'Non DFC $layout',
          setOrSeries: 'Test Set',
          imageUrl: 'https://example.com/$layout.jpg',
          acquiredPrice: 1.0,
          acquiredDate: DateTime(2023, 1, 1),
          quantity: 1,
          condition: 'NM',
          isGraded: false,
          isAltered: false,
          isMisprint: false,
          isSigned: false,
          currentMarketPrice: 1.0,
          lastPriceUpdate: DateTime(2023, 1, 1),
          dynamicData: jsonEncode({
            'layout': layout,
            'type_line': 'Sorcery',
            'oracle_text': 'Rules text for $layout',
          }),
        );

        await tester.pumpWidget(createSheetApp(card));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('card_detail_flip_button')),
          findsNothing,
          reason: 'Flip button must not render for layout: $layout',
        );
        expect(
          find.byKey(const Key('card_detail_switch_face_button')),
          findsNothing,
          reason: 'Switch face button must not render for layout: $layout',
        );

        await tester.pumpWidget(MaterialApp(home: FullScreenCardViewer(item: card)));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('fullscreen_appbar_flip_button')),
          findsNothing,
          reason: 'Fullscreen appbar flip must not render for layout: $layout',
        );
        expect(
          find.byKey(const Key('fullscreen_flip_button')),
          findsNothing,
          reason: 'Fullscreen flip button must not render for layout: $layout',
        );
      }
    });
  });
}
