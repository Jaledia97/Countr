// Copyright (c) 2026 Countr. All rights reserved.
// Adversarial Viewport Bounds & Zero-Overflow Empirical Challenge Suite.
//
// Target Verification:
// - CardDetailSheet under 320px viewport and [1.0x, 1.5x, 2.0x] font scaling with 0 RenderFlex overflows.
// - DeckBuilderScreen under 320px viewport and [1.0x, 1.5x, 2.0x] font scaling with 0 RenderFlex overflows.
// - PostCard (text, singlePull, multiPull) under 320px viewport and [1.0x, 1.5x, 2.0x] font scaling with 0 RenderFlex overflows.
// - Standalone extreme constraint stress for ManaCostBar and ManaText.

import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/decks/presentation/providers/deck_providers.dart';
import 'package:countr/features/decks/presentation/screens/deck_builder_screen.dart';
import 'package:countr/features/feed/domain/models/feed_post.dart';
import 'package:countr/features/feed/presentation/widgets/post_card.dart';
import 'package:countr/features/symbology/presentation/widgets/mana_cost_bar.dart';
import 'package:countr/features/symbology/presentation/widgets/mana_symbol_icon.dart';
import 'package:countr/features/symbology/presentation/widgets/mana_text.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/widgets/card_detail_sheet.dart';

VaultItem createChallengeCard({
  required String name,
  required String manaCost,
  required String oracleText,
  String? layout,
  List<Map<String, dynamic>>? cardFaces,
  List<Map<String, dynamic>>? cachedRulings,
  String typeLine = 'Creature — Legend',
  String? power = '4',
  String? toughness = '4',
  double price = 15.50,
}) {
  final dataMap = <String, dynamic>{
    'mana_cost': manaCost,
    'oracle_text': oracleText,
    'type_line': typeLine,
    'power': ?power,
    'toughness': ?toughness,
  };
  if (layout != null) dataMap['layout'] = layout;
  if (cardFaces != null) dataMap['card_faces'] = cardFaces;
  if (cachedRulings != null) dataMap['cached_rulings'] = cachedRulings;

  return VaultItem(
    id: 'challenge-card-${name.toLowerCase().replaceAll(' ', '-').replaceAll('//', '-')}',
    collectionType: 'mtg',
    name: name,
    setOrSeries: 'CHAL',
    imageUrl: 'https://example.com/card.jpg',
    acquiredPrice: price,
    acquiredDate: DateTime(2026, 1, 1),
    quantity: 2,
    condition: 'NM',
    isGraded: false,
    isAltered: false,
    isMisprint: false,
    isSigned: false,
    currentMarketPrice: price,
    lastPriceUpdate: DateTime.now(),
    dynamicData: jsonEncode(dataMap),
  );
}

Widget createChallengeCardDetailSubject({
  required AppDatabase db,
  required VaultItem card,
  TextScaler textScaler = const TextScaler.linear(1.0),
}) {
  return ProviderScope(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      vaultDaoProvider.overrideWithValue(db.vaultDao),
    ],
    child: MaterialApp(
      theme: ThemeData.dark(),
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(320, 568),
          textScaler: textScaler,
        ),
        child: Scaffold(
          body: CardDetailSheet(
            item: card,
            fetchOnlinePrintings: false,
          ),
        ),
      ),
    ),
  );
}

Deck createChallengeDeck({
  required String id,
  required String name,
}) {
  return Deck(
    id: id,
    name: name,
    format: 'MTG Commander',
    wins: 0,
    losses: 0,
    draws: 0,
    createdAt: DateTime.now(),
    tcgDomain: 'mtg',
    isRegistered: false,
    isCompetitive: false,
  );
}

Widget createChallengeDeckBuilderSubject({
  required Deck deck,
  required List<Map<String, dynamic>> items,
  TextScaler textScaler = const TextScaler.linear(1.0),
}) {
  return ProviderScope(
    overrides: [
      deckItemsProvider(deck.id).overrideWith(
        (ref) => Stream.value(items),
      ),
    ],
    child: MaterialApp(
      theme: ThemeData.dark(),
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(320, 568),
          textScaler: textScaler,
        ),
        child: DeckBuilderScreen(deck: deck),
      ),
    ),
  );
}

Widget createChallengePostCardSubject({
  required FeedPost post,
  TextScaler textScaler = const TextScaler.linear(1.0),
}) {
  return MaterialApp(
    theme: ThemeData.dark(),
    home: MediaQuery(
      data: MediaQueryData(
        size: const Size(320, 568),
        textScaler: textScaler,
      ),
      child: Scaffold(
        body: SingleChildScrollView(
          child: PostCard(post: post),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  // ===========================================================================
  // SECTION 1: CardDetailSheet Viewport & Font Scaling Stress
  // ===========================================================================
  group('Adversarial 1: CardDetailSheet 320px Viewport & High Font Scaling', () {
    const scales = [1.0, 1.5, 2.0];

    for (final scale in scales) {
      testWidgets('1.1 Card with massive 10-symbol mana cost at 320px viewport with ${scale}x font scaling has ZERO overflows', (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final card = createChallengeCard(
          name: 'Omnath, Mana Overlord',
          manaCost: '{W}{U}{B}{R}{G}{W/U}{B/R}{2/W}{C/W}{P/B}',
          oracleText: 'When Omnath enters the battlefield, add {W}{U}{B}{R}{G}. Then pay {2/W} or tap {T} to gain 3 life.',
          typeLine: 'Legendary Creature — Elemental Avatar God',
        );

        await tester.pumpWidget(
          createChallengeCardDetailSubject(
            db: db,
            card: card,
            textScaler: TextScaler.linear(scale),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(ManaCostBar), findsWidgets);
        expect(tester.takeException(), isNull);

        final listFinder = find.byKey(PageStorageKey('card_detail_list_${card.id}'));
        expect(listFinder, findsOneWidget);

        // Scroll down in small steps to ensure every sliver renders without overflow
        for (int i = 0; i < 3; i++) {
          await tester.drag(listFinder, const Offset(0, -100));
          await tester.pumpAndSettle();
        }

        expect(find.byType(ManaText), findsWidgets);
        expect(tester.takeException(), isNull);

        // Scroll back up
        for (int i = 0; i < 3; i++) {
          await tester.drag(listFinder, const Offset(0, 100));
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull);
      });

      testWidgets('1.2 Card with very long name and complex multi-line rules text at 320px with ${scale}x scale has ZERO overflows', (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final card = createChallengeCard(
          name: 'Our Market Research Shows That Players Like Really Long Card Names So We Made This Card',
          manaCost: '{1}{G}{U}',
          oracleText:
              '{T}: Add {G} or {U}.\n'
              '{1}, {T}, Sacrifice this permanent: Search your library for a basic land card, put it onto the battlefield tapped, then shuffle.\n'
              'Whenever a creature with flying attacks you, untap {Q} this permanent and pay {P/B}.',
          typeLine: 'Legendary Artifact Creature — Juggernaut Construct',
        );

        await tester.pumpWidget(
          createChallengeCardDetailSubject(
            db: db,
            card: card,
            textScaler: TextScaler.linear(scale),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(ManaCostBar), findsWidgets);
        expect(tester.takeException(), isNull);

        // Scroll down systematically to render Oracle Text
        final listFinder = find.byKey(PageStorageKey('card_detail_list_${card.id}'));
        expect(listFinder, findsOneWidget);
        for (int i = 0; i < 3; i++) {
          await tester.drag(listFinder, const Offset(0, -200));
          await tester.pumpAndSettle();
        }

        expect(find.byType(ManaText), findsWidgets);
        expect(tester.takeException(), isNull);
      });

      testWidgets('1.3 Adventure card dual faces at 320px viewport with ${scale}x scale has ZERO overflows', (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final card = createChallengeCard(
          name: 'Bonecrusher Giant // Stomp',
          manaCost: '{2}{R}',
          oracleText: 'Whenever Bonecrusher Giant becomes target, it deals 2 damage.\n//\nDamage can\'t be prevented.',
          layout: 'adventure',
          cardFaces: [
            {
              'name': 'Bonecrusher Giant',
              'mana_cost': '{2}{R}',
              'type_line': 'Creature — Giant Berserker',
              'oracle_text': 'Whenever Bonecrusher Giant becomes the target of a spell, it deals 2 damage to that spell\'s controller.',
            },
            {
              'name': 'Stomp',
              'mana_cost': '{1}{R}',
              'type_line': 'Instant — Adventure',
              'oracle_text': 'Damage can\'t be prevented this turn. Stomp deals 2 damage to any target.',
            },
          ],
        );

        await tester.pumpWidget(
          createChallengeCardDetailSubject(
            db: db,
            card: card,
            textScaler: TextScaler.linear(scale),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(ManaCostBar), findsWidgets);
        expect(tester.takeException(), isNull);

        // Scroll down systematically to render Adventure rules
        final listFinder = find.byKey(PageStorageKey('card_detail_list_${card.id}'));
        expect(listFinder, findsOneWidget);
        for (int i = 0; i < 3; i++) {
          await tester.drag(listFinder, const Offset(0, -200));
          await tester.pumpAndSettle();
        }

        expect(find.byType(ManaText), findsWidgets);
        expect(tester.takeException(), isNull);
      });

      testWidgets('1.4 Card with Scryfall rulings comments at 320px viewport with ${scale}x scale has ZERO overflows', (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final card = createChallengeCard(
          name: 'Chandra, Awakened Inferno',
          manaCost: '{4}{R}{R}',
          oracleText: '+2: Each opponent gets an emblem with "At the beginning of your upkeep, this emblem deals 1 damage to you."',
          cachedRulings: [
            {
              'published_at': '2023-05-01',
              'comment': 'The emblem ability triggers once per upkeep and deals 1 damage. Tapping {T} does not prevent it, nor does paying {2}.',
            },
            {
              'published_at': '2023-05-02',
              'comment': 'Costs {4}{R}{R} and cannot be countered by normal spells like {U}{U}.',
            },
          ],
        );

        await tester.pumpWidget(
          createChallengeCardDetailSubject(
            db: db,
            card: card,
            textScaler: TextScaler.linear(scale),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(ManaCostBar), findsWidgets);
        expect(tester.takeException(), isNull);

        // Scroll down systematically to render Scryfall rulings
        final listFinder = find.byKey(PageStorageKey('card_detail_list_${card.id}'));
        expect(listFinder, findsOneWidget);
        for (int i = 0; i < 4; i++) {
          await tester.drag(listFinder, const Offset(0, -250));
          await tester.pumpAndSettle();
        }

        expect(find.byType(ManaText), findsWidgets);
        expect(tester.takeException(), isNull);
      });
    }
  });

  // ===========================================================================
  // SECTION 2: DeckBuilderScreen Viewport & Font Scaling Stress
  // ===========================================================================
  group('Adversarial 2: DeckBuilderScreen 320px Viewport & High Font Scaling', () {
    const scales = [1.0, 1.5, 2.0];

    for (final scale in scales) {
      testWidgets('2.1 DeckBuilder with commander, massive mana costs in 80px trailing column at 320px with ${scale}x scale has ZERO overflows', (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final testDeck = createChallengeDeck(id: 'deck-chal-$scale', name: 'Five-Color Dragon Storm');
        final items = [
          {
            'id': 'item-ur-dragon',
            'name': 'The Ur-Dragon, Scion of the Primeval Gods',
            'board_zone': 'commander',
            'deck_quantity': 1,
            'acquired_price': 45.00,
            'dynamic_data': jsonEncode({
              'mana_cost': '{4}{W}{U}{B}{R}{G}',
              'cmc': 9,
              'type_line': 'Legendary Creature — Dragon Avatar',
              'rarity': 'mythic',
            }),
          },
          {
            'id': 'item-omnath',
            'name': 'Omnath, Locus of All Elements and Mana',
            'board_zone': 'mainboard',
            'deck_quantity': 1,
            'acquired_price': 12.00,
            'dynamic_data': jsonEncode({
              'mana_cost': '{W}{U}{B}{R}{G}',
              'cmc': 5,
              'type_line': 'Legendary Creature — Elemental',
              'rarity': 'rare',
            }),
          },
          {
            'id': 'item-hybrid',
            'name': 'Tamiyo, Compleated Sage',
            'board_zone': 'mainboard',
            'deck_quantity': 1,
            'acquired_price': 8.50,
            'dynamic_data': jsonEncode({
              'mana_cost': '{2}{G}{G/U/P}{U}',
              'cmc': 5,
              'type_line': 'Legendary Planeswalker — Tamiyo',
              'rarity': 'mythic',
            }),
          },
          {
            'id': 'item-land',
            'name': 'Command Tower',
            'board_zone': 'mainboard',
            'deck_quantity': 1,
            'acquired_price': 1.00,
            'dynamic_data': jsonEncode({
              'mana_cost': '',
              'cmc': 0,
              'type_line': 'Land',
              'rarity': 'common',
            }),
          },
        ];

        await tester.pumpWidget(
          createChallengeDeckBuilderSubject(
            deck: testDeck,
            items: items,
            textScaler: TextScaler.linear(scale),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(ManaCostBar), findsWidgets);
        expect(tester.takeException(), isNull);

        // Scroll the deck view
        await tester.drag(find.byType(DeckBuilderScreen), const Offset(0, -250));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });

      testWidgets('2.2 Fast-Draw 7 playtester modal opened at 320px viewport with ${scale}x scale has ZERO overflows', (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final testDeck = createChallengeDeck(id: 'deck-chal-fastdraw-$scale', name: 'FastDraw Deck');
        final items = List.generate(
          10,
          (i) => {
            'id': 'item-$i',
            'name': 'Card $i Very Long Spell Name',
            'board_zone': 'mainboard',
            'deck_quantity': 1,
            'acquired_price': 2.0,
            'dynamic_data': jsonEncode({
              'mana_cost': '{1}{W}{U}',
              'cmc': 3,
              'type_line': 'Sorcery',
              'rarity': 'rare',
            }),
          },
        );

        await tester.pumpWidget(
          createChallengeDeckBuilderSubject(
            deck: testDeck,
            items: items,
            textScaler: TextScaler.linear(scale),
          ),
        );
        await tester.pumpAndSettle();

        final playtestButton = find.byTooltip('Fast-Draw 7');
        expect(playtestButton, findsOneWidget);
        await tester.tap(playtestButton);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(ManaCostBar), findsWidgets);
      });
    }
  });

  // ===========================================================================
  // SECTION 3: PostCard Viewport & Font Scaling Stress
  // ===========================================================================
  group('Adversarial 3: PostCard 320px Viewport & High Font Scaling', () {
    const scales = [1.0, 1.5, 2.0];

    for (final scale in scales) {
      testWidgets('3.1 PostType.text with dense multi-line primer at 320px with ${scale}x scale has ZERO overflows', (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        const post = FeedPost(
          id: 'post-chal-text',
          type: PostType.text,
          username: 'combo_master',
          avatarInitials: 'CM',
          timestamp: '2h ago',
          locationTag: 'MTG Arena',
          textContent:
              'Deck Primer & Combo Lines:\n'
              'Turn 1: Play land, cast Birds of Paradise for {G}.\n'
              'Turn 2: Tap {T} for {G}, cast Kinnan, Bonder Prodigy for {G}{U}.\n'
              'Turn 3: Cast Basalt Monolith for {3}. Tap {T} for {C}{C}{C}{C}, untap {Q} for {3} -> infinite {C}!\n'
              'Finisher: Cast Walking Ballista for {X}{X}, or Thassa\'s Oracle for {U}{U} with {P/B} backup!',
        );

        await tester.pumpWidget(
          createChallengePostCardSubject(
            post: post,
            textScaler: TextScaler.linear(scale),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(PostCard), findsOneWidget);
        expect(find.byType(ManaText), findsOneWidget);
        expect(find.byType(ManaSymbolIcon), findsWidgets);
        expect(tester.takeException(), isNull);
      });

      testWidgets('3.2 PostType.singlePull with commentary at 320px with ${scale}x scale has ZERO overflows', (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        const post = FeedPost(
          id: 'post-chal-single',
          type: PostType.singlePull,
          username: 'pack_cracker',
          avatarInitials: 'PC',
          timestamp: '3h ago',
          locationTag: 'Local Game Store',
          textContent: 'Insane pull! Look at this foil borderless {W}{U}{B}{R}{G} masterpiece!',
          cardTitle: 'Atraxa, Grand Unifier',
          cardSubtitle: 'Phyrexia: All Will Be One — Mythic Foil',
          cardRarity: 'mythic',
          estimatedValue: '\$65.00',
        );

        await tester.pumpWidget(
          createChallengePostCardSubject(
            post: post,
            textScaler: TextScaler.linear(scale),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(PostCard), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('3.3 PostType.multiPull with commentary at 320px with ${scale}x scale has ZERO overflows', (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        const post = FeedPost(
          id: 'post-chal-multi',
          type: PostType.multiPull,
          username: 'box_breaker',
          avatarInitials: 'BB',
          timestamp: '4h ago',
          locationTag: 'Card Show',
          textContent: 'Full bundle opening: hit {W}, {U}, {B}, {R}, and {G} cards all in one box!',
          pullImages: ['img1.jpg', 'img2.jpg', 'img3.jpg', 'img4.jpg'],
        );

        await tester.pumpWidget(
          createChallengePostCardSubject(
            post: post,
            textScaler: TextScaler.linear(scale),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(PostCard), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });

  // ===========================================================================
  // SECTION 4: Component-Level Extreme Constraint Stress
  // ===========================================================================
  group('Adversarial 4: Component-Level Extreme Constraint Stress', () {
    testWidgets('4.1 20-symbol ManaCostBar in 40px box scales down with zero overflow', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 40.0,
              height: 25.0,
              child: ManaCostBar(
                manaCost: '{W}{U}{B}{R}{G}' * 4,
                symbolSize: 14.0,
                enableFittedBox: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('4.2 ManaText in 40px box with 2.5x font scale wraps without crashing', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 40.0,
              child: ManaText(
                'Cast {W} or {U} then {T}.',
                style: const TextStyle(fontSize: 14.0),
                textScaler: const TextScaler.linear(2.5),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
