// Copyright (c) 2026 Countr. All rights reserved.
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/app_state.dart';
import 'package:countr/features/auth/presentation/providers/auth_providers.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/widgets/card_detail_sheet.dart';
import 'package:countr/features/vault/presentation/widgets/expanded_card_view_modal.dart';
import 'package:countr/features/feed/presentation/widgets/post_composer_modal.dart';
import 'package:countr/features/feed/presentation/widgets/post_card.dart';
import 'package:countr/features/feed/presentation/providers/inbox_providers.dart';
import 'package:countr/features/feed/presentation/providers/feed_providers.dart';
import 'package:countr/features/feed/domain/models/feed_post.dart';
import 'package:countr/features/profile/presentation/providers/profile_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.userProfileDao.seedDefaultProfiles();
    await db.vaultDao.clearAllItems();
  });

  tearDown(() async {
    await db.close();
  });

  VaultItem createTestCard({
    String id = 'card_one_ring',
    String name = 'The One Ring',
    String setOrSeries = 'LTR',
    double acquiredPrice = 45.0,
    double currentMarketPrice = 95.0,
    int quantity = 1,
  }) {
    return VaultItem(
      id: id,
      collectionType: 'mtg',
      name: name,
      setOrSeries: setOrSeries,
      imageUrl: 'https://cards.scryfall.io/large/front/d/5/d5806e68.jpg',
      acquiredPrice: acquiredPrice,
      acquiredDate: DateTime(2023, 6, 23),
      quantity: quantity,
      condition: 'NM',
      isGraded: false,
      isAltered: false,
      isMisprint: false,
      isSigned: false,
      isDeleted: false,
      currentMarketPrice: currentMarketPrice,
      lastPriceUpdate: DateTime.now(),
      dynamicData: jsonEncode({
        'oracle_text': 'Indestructible',
        'type_line': 'Legendary Artifact',
        'mana_cost': '{4}',
        'rarity': 'Mythic Rare',
      }),
    );
  }

  Future<void> seedCard(VaultItem card) async {
    await db.vaultDao.into(db.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: card.id,
            collectionType: card.collectionType,
            name: card.name,
            setOrSeries: card.setOrSeries,
            imageUrl: card.imageUrl,
            acquiredPrice: card.acquiredPrice,
            acquiredDate: card.acquiredDate,
            quantity: drift.Value(card.quantity),
            condition: card.condition,
            currentMarketPrice: card.currentMarketPrice,
            lastPriceUpdate: card.lastPriceUpdate,
            dynamicData: card.dynamicData,
          ),
        );
  }

  Widget createTestApp({
    required Widget child,
    List<Override> extraOverrides = const [],
  }) {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        vaultDaoProvider.overrideWithValue(db.vaultDao),
        feedDaoProvider.overrideWithValue(db.feedDao),
        inboxDaoProvider.overrideWithValue(db.inboxDao),
        currentUserIdProvider.overrideWith((ref) => 'user-current-me'),
        ...extraOverrides,
      ],
      child: MaterialApp(
        home: Scaffold(
          body: child,
        ),
      ),
    );
  }

  // =========================================================================
  // SUITE 1: DYNAMIC POST COMPOSER LAYOUTS & STATE FLAPPING
  // =========================================================================
  group('Milestone 2 Challenge 1: Dynamic Post Composer Layouts & State Flapping', () {
    testWidgets('T1.1: Complex multi-step state flapping through arbitrary sequences', (tester) async {
      await tester.pumpWidget(createTestApp(
        child: const Center(child: PostComposerModal()),
      ));
      await tester.pumpAndSettle();

      // Starts strictly as textOnly
      expect(find.byKey(const Key('post_current_layout_type')), findsOneWidget);
      expect(find.text('textOnly'), findsOneWidget);

      // Transition 1: Add card -> singleCard
      await tester.tap(find.byKey(const Key('post_add_card_button')));
      await tester.pumpAndSettle();
      expect(find.text('singleCard'), findsOneWidget);
      expect(find.byKey(const Key('attached_card_0')), findsOneWidget);

      // Transition 2: Add second card -> multiCard
      await tester.tap(find.byKey(const Key('post_add_card_button')));
      await tester.pumpAndSettle();
      expect(find.text('multiCard'), findsOneWidget);
      expect(find.byKey(const Key('attached_card_0')), findsOneWidget);
      expect(find.byKey(const Key('attached_card_1')), findsOneWidget);

      // Transition 3: Add image -> mixedMedia (2 cards + 1 image)
      await tester.tap(find.byKey(const Key('post_add_image_button')));
      await tester.pumpAndSettle();
      expect(find.text('mixedMedia'), findsOneWidget);
      expect(find.byKey(const Key('attached_image_0')), findsOneWidget);

      // Transition 4: Remove card 1 -> still mixedMedia (1 card + 1 image)
      await tester.tap(find.byKey(const Key('remove_attached_card_1')));
      await tester.pumpAndSettle();
      expect(find.text('mixedMedia'), findsOneWidget);

      // Transition 5: Remove card 0 -> image format (0 cards + 1 image)
      await tester.tap(find.byKey(const Key('remove_attached_card_0')));
      await tester.pumpAndSettle();
      expect(find.text('image'), findsOneWidget);

      // Transition 6: Add card -> mixedMedia again
      await tester.tap(find.byKey(const Key('post_add_card_button')));
      await tester.pumpAndSettle();
      expect(find.text('mixedMedia'), findsOneWidget);

      // Transition 7: Remove image -> singleCard
      await tester.tap(find.byKey(const Key('remove_attached_image_0')));
      await tester.pumpAndSettle();
      expect(find.text('singleCard'), findsOneWidget);

      // Transition 8: Remove card -> textOnly
      await tester.tap(find.byKey(const Key('remove_attached_card_0')));
      await tester.pumpAndSettle();
      expect(find.text('textOnly'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('T1.2: Rapid multi-card addition and non-sequential out-of-order deletion', (tester) async {
      await tester.pumpWidget(createTestApp(
        child: const Center(child: PostComposerModal()),
      ));
      await tester.pumpAndSettle();

      // Add 4 cards
      for (int i = 0; i < 4; i++) {
        await tester.tap(find.byKey(const Key('post_add_card_button')));
        await tester.pumpAndSettle();
      }
      expect(find.text('multiCard'), findsOneWidget);
      expect(find.byKey(const Key('attached_card_0')), findsOneWidget);
      expect(find.byKey(const Key('attached_card_1')), findsOneWidget);
      expect(find.byKey(const Key('attached_card_2')), findsOneWidget);
      expect(find.byKey(const Key('attached_card_3')), findsOneWidget);

      // Delete middle card (index 2)
      await tester.tap(find.byKey(const Key('remove_attached_card_2')));
      await tester.pumpAndSettle();
      expect(find.text('multiCard'), findsOneWidget);

      // 3 cards remaining: remove index 0, then index 0, then index 0
      await tester.tap(find.byKey(const Key('remove_attached_card_0')));
      await tester.pumpAndSettle();
      expect(find.text('multiCard'), findsOneWidget);

      await tester.tap(find.byKey(const Key('remove_attached_card_0')));
      await tester.pumpAndSettle();
      expect(find.text('singleCard'), findsOneWidget);

      await tester.tap(find.byKey(const Key('remove_attached_card_0')));
      await tester.pumpAndSettle();
      expect(find.text('textOnly'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('T1.3: Text input persistence across heavy attachment churn', (tester) async {
      await tester.pumpWidget(createTestApp(
        child: const Center(child: PostComposerModal()),
      ));
      await tester.pumpAndSettle();

      const longDraft = 'Drafting a modern brew with {W}{U} countermagic and {B}{R} burn spells!';
      await tester.enterText(find.byKey(const Key('post_composer_text_input')), longDraft);
      await tester.pumpAndSettle();

      // Add cards and images
      await tester.tap(find.byKey(const Key('post_add_card_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('post_add_image_button')));
      await tester.pumpAndSettle();

      // Verify text did not wipe
      expect(find.text(longDraft), findsOneWidget);

      // Remove attachments
      await tester.tap(find.byKey(const Key('remove_attached_card_0')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('remove_attached_image_0')));
      await tester.pumpAndSettle();

      expect(find.text('textOnly'), findsOneWidget);
      expect(find.text(longDraft), findsOneWidget);
    });
  });

  // =========================================================================
  // SUITE 2: EMPTY VALIDATIONS & DATABASE INSERTION INTEGRITY
  // =========================================================================
  group('Milestone 2 Challenge 2: Empty Post Validations & Publishing Invariants', () {
    testWidgets('T2.1: Completely empty post cannot be published', (tester) async {
      bool publishedCallbackInvoked = false;
      await tester.pumpWidget(createTestApp(
        child: Center(
          child: PostComposerModal(
            onPublish: (_) => publishedCallbackInvoked = true,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Tap Publish
      await tester.tap(find.byKey(const Key('post_composer_publish_button')));
      await tester.pumpAndSettle();

      // Verify callback NOT called
      expect(publishedCallbackInvoked, isFalse);

      // Verify 0 rows in database
      final posts = await db.feedDao.select(db.feedDao.feedPosts).get();
      expect(posts.isEmpty, isTrue);
    });

    testWidgets('T2.2: Whitespace-only post is strictly rejected', (tester) async {
      bool publishedCallbackInvoked = false;
      await tester.pumpWidget(createTestApp(
        child: Center(
          child: PostComposerModal(
            onPublish: (_) => publishedCallbackInvoked = true,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('post_composer_text_input')), '   \n\t  \n  ');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('post_composer_publish_button')));
      await tester.pumpAndSettle();

      expect(publishedCallbackInvoked, isFalse);
      final posts = await db.feedDao.select(db.feedDao.feedPosts).get();
      expect(posts.isEmpty, isTrue);
    });

    testWidgets('T2.3: Valid text-only post publishes with correct schema record', (tester) async {
      await tester.pumpWidget(createTestApp(
        child: const Center(child: PostComposerModal()),
      ));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('post_composer_text_input')), 'Heading to FNM tonight!');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('post_composer_publish_button')));
      await tester.pumpAndSettle();

      final posts = await db.feedDao.select(db.feedDao.feedPosts).get();
      expect(posts.length, equals(1));
      final post = posts.first;
      expect(post.type, equals('text'));
      expect(post.textContent, equals('Heading to FNM tonight!'));
      expect(post.cardId, isNull);
      expect(post.cardImageUrl, isNull);
      expect(post.pullImagesJson, isNull);
    });

    testWidgets('T2.4: Empty text with 1 attached card publishes single_pull post', (tester) async {
      await tester.pumpWidget(createTestApp(
        child: const Center(child: PostComposerModal()),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('post_add_card_button')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('post_composer_publish_button')));
      await tester.pumpAndSettle();

      final posts = await db.feedDao.select(db.feedDao.feedPosts).get();
      expect(posts.length, equals(1));
      final post = posts.first;
      expect(post.type, equals('single_pull'));
      expect(post.cardTitle, equals('Card 1'));
      expect(post.textContent, isNull);
    });

    testWidgets('T2.5: Empty text with 2 attached cards publishes multi_pull post', (tester) async {
      await tester.pumpWidget(createTestApp(
        child: const Center(child: PostComposerModal()),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('post_add_card_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('post_add_card_button')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('post_composer_publish_button')));
      await tester.pumpAndSettle();

      final posts = await db.feedDao.select(db.feedDao.feedPosts).get();
      expect(posts.length, equals(1));
      final post = posts.first;
      expect(post.type, equals('multi_pull'));
      final decodedCardIds = jsonDecode(post.pullCardIdsJson!) as List;
      expect(decodedCardIds.length, equals(2));
    });

    testWidgets('T2.6: Empty text with attached image publishes media post', (tester) async {
      await tester.pumpWidget(createTestApp(
        child: const Center(child: PostComposerModal()),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('post_add_image_button')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('post_composer_publish_button')));
      await tester.pumpAndSettle();

      final posts = await db.feedDao.select(db.feedDao.feedPosts).get();
      expect(posts.length, equals(1));
      final post = posts.first;
      expect(post.type, equals('media'));
      expect(post.cardImageUrl, equals('image_1.jpg'));
    });

    testWidgets('T2.7: Attached card and image publishes mixed_media post', (tester) async {
      await tester.pumpWidget(createTestApp(
        child: const Center(child: PostComposerModal()),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('post_add_card_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('post_add_image_button')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('post_composer_publish_button')));
      await tester.pumpAndSettle();

      final posts = await db.feedDao.select(db.feedDao.feedPosts).get();
      expect(posts.length, equals(1));
      final post = posts.first;
      expect(post.type, equals('mixed_media'));
      expect(post.cardTitle, equals('Card 1'));
      final images = jsonDecode(post.pullImagesJson!) as List;
      expect(images.length, equals(2));
    });
  });

  // =========================================================================
  // SUITE 3: PRE-ATTACHED INITIALIZATION & ATTACHMENT ALTERATION STRESS
  // =========================================================================
  group('Milestone 2 Challenge 3: Pre-attached Card Initialization & Alterations', () {
    testWidgets('T3.1: Pre-attached card starts in singleCard layout', (tester) async {
      await tester.pumpWidget(createTestApp(
        child: const Center(
          child: PostComposerModal(
            preAttachedCardId: 'card_lotus_1',
            preAttachedCardName: 'Black Lotus',
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('singleCard'), findsOneWidget);
      expect(find.text('Black Lotus'), findsOneWidget);
    });

    testWidgets('T3.2: Adding second card switches pre-attached composer to multiCard', (tester) async {
      await tester.pumpWidget(createTestApp(
        child: const Center(
          child: PostComposerModal(
            preAttachedCardId: 'card_lotus_1',
            preAttachedCardName: 'Black Lotus',
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('post_add_card_button')));
      await tester.pumpAndSettle();

      expect(find.text('multiCard'), findsOneWidget);
      expect(find.text('Black Lotus'), findsOneWidget);
      expect(find.text('Card 2'), findsOneWidget);
    });

    testWidgets('T3.3: Adversarial Check: Removing pre-attached card with empty text MUST NOT publish ghost card', (tester) async {
      await tester.pumpWidget(createTestApp(
        child: const Center(
          child: PostComposerModal(
            preAttachedCardId: 'card_lotus_1',
            preAttachedCardName: 'Black Lotus',
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Remove the pre-attached card
      await tester.tap(find.byKey(const Key('remove_attached_card_0')));
      await tester.pumpAndSettle();

      // Layout indicator must revert to textOnly
      expect(find.text('textOnly'), findsOneWidget);
      expect(find.byKey(const Key('attached_card_0')), findsNothing);

      // Attempt to publish empty post
      await tester.tap(find.byKey(const Key('post_composer_publish_button')));
      await tester.pumpAndSettle();

      // Empirical verification: Did it publish a ghost card to SQLite?
      final posts = await db.feedDao.select(db.feedDao.feedPosts).get();
      expect(
        posts.isEmpty,
        isTrue,
        reason: 'CRITICAL BUG: Removing pre-attached card must not leave ghost card and publish empty post!',
      );
    });

    testWidgets('T3.4: Adversarial Check: Removing pre-attached card and entering text MUST publish as text post, NOT single_pull', (tester) async {
      await tester.pumpWidget(createTestApp(
        child: const Center(
          child: PostComposerModal(
            preAttachedCardId: 'card_lotus_1',
            preAttachedCardName: 'Black Lotus',
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Remove the pre-attached card
      await tester.tap(find.byKey(const Key('remove_attached_card_0')));
      await tester.pumpAndSettle();
      expect(find.text('textOnly'), findsOneWidget);

      // Enter pure text
      await tester.enterText(find.byKey(const Key('post_composer_text_input')), 'Drafting a new Cube deck!');
      await tester.pumpAndSettle();

      // Publish
      await tester.tap(find.byKey(const Key('post_composer_publish_button')));
      await tester.pumpAndSettle();

      final posts = await db.feedDao.select(db.feedDao.feedPosts).get();
      expect(posts.length, equals(1));
      final post = posts.first;
      expect(
        post.type,
        equals('text'),
        reason: 'CRITICAL BUG: Post must be published as "text", NOT resurrected as "single_pull" with ghost card!',
      );
      expect(post.cardTitle, isNull);
    });

    testWidgets('T3.5: Adversarial Check: Removing pre-attached card and adding image MUST publish as media post, NOT single_pull', (tester) async {
      await tester.pumpWidget(createTestApp(
        child: const Center(
          child: PostComposerModal(
            preAttachedCardId: 'card_lotus_1',
            preAttachedCardName: 'Black Lotus',
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Remove pre-attached card
      await tester.tap(find.byKey(const Key('remove_attached_card_0')));
      await tester.pumpAndSettle();

      // Add image
      await tester.tap(find.byKey(const Key('post_add_image_button')));
      await tester.pumpAndSettle();
      expect(find.text('image'), findsOneWidget);

      // Publish
      await tester.tap(find.byKey(const Key('post_composer_publish_button')));
      await tester.pumpAndSettle();

      final posts = await db.feedDao.select(db.feedDao.feedPosts).get();
      expect(posts.length, equals(1));
      final post = posts.first;
      expect(
        post.type,
        equals('media'),
        reason: 'CRITICAL BUG: Post must be published as "media", NOT overwritten as "single_pull"!',
      );
    });
  });

  // =========================================================================
  // SUITE 4: CARD DETAILS SHARE SHEET (AS LINK, AS POST, AUTH GATE)
  // =========================================================================
  group('Milestone 2 Challenge 4: Card Details Share Sheet Options', () {
    testWidgets('T4.1: Guest user is blocked by auth gate dialog', (tester) async {
      final card = createTestCard();
      await seedCard(card);

      await tester.pumpWidget(createTestApp(
        extraOverrides: [
          isUserLoggedInProvider.overrideWith((ref) => false),
        ],
        child: Builder(
          builder: (context) => ElevatedButton(
            key: const Key('open_card_btn'),
            onPressed: () => CardDetailSheet.show(context, card),
            child: const Text('Open'),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open_card_btn')));
      await tester.pumpAndSettle();

      // Tap Share
      await tester.tap(find.byKey(const Key('quick_action_share')));
      await tester.pumpAndSettle();

      // Must see login dialog
      expect(find.byKey(const Key('share_login_dialog')), findsOneWidget);
      expect(find.byKey(const Key('card_share_dialog')), findsNothing);

      // Cancel dismisses without opening share
      await tester.tap(find.byKey(const Key('share_login_cancel')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('share_login_dialog')), findsNothing);
      expect(find.byKey(const Key('card_share_dialog')), findsNothing);
    });

    testWidgets('T4.2: As Link formats deep link, summary, and copies to clipboard', (tester) async {
      final card = createTestCard(id: 'c_one_ring', name: 'The One Ring', currentMarketPrice: 95.0);
      await seedCard(card);

      await tester.pumpWidget(createTestApp(
        extraOverrides: [
          isUserLoggedInProvider.overrideWith((ref) => true),
        ],
        child: Builder(
          builder: (context) => ElevatedButton(
            key: const Key('open_card_btn'),
            onPressed: () => CardDetailSheet.show(context, card),
            child: const Text('Open'),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open_card_btn')));
      await tester.pumpAndSettle();

      // Tap Share
      await tester.tap(find.byKey(const Key('quick_action_share')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('card_share_dialog')), findsOneWidget);
      expect(find.byKey(const Key('share_as_link_option')), findsOneWidget);
      expect(find.byKey(const Key('share_copy_link_button')), findsOneWidget);

      // Tap Copy Card Info button
      await tester.tap(find.byKey(const Key('share_copy_link_button')));
      await tester.pumpAndSettle();

      // Dialog dismissed and SnackBar displayed
      expect(find.byKey(const Key('card_share_dialog')), findsNothing);
      expect(find.textContaining('Copied "The One Ring" link to clipboard'), findsOneWidget);
    });

    testWidgets('T4.3: Quick Send in Messages delivers direct message to selected target', (tester) async {
      final card = createTestCard(id: 'c_one_ring', name: 'The One Ring');
      await seedCard(card);

      await tester.pumpWidget(createTestApp(
        extraOverrides: [
          isUserLoggedInProvider.overrideWith((ref) => true),
        ],
        child: Builder(
          builder: (context) => ElevatedButton(
            key: const Key('open_card_btn'),
            onPressed: () => CardDetailSheet.show(context, card),
            child: const Text('Open'),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open_card_btn')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('quick_action_share')));
      await tester.pumpAndSettle();

      // Find quick send target for @SpicyBrewMaster
      final quickSendTarget = find.byKey(const Key('quick_send_target_@SpicyBrewMaster'));
      expect(quickSendTarget, findsOneWidget);

      await tester.tap(quickSendTarget);
      await tester.pumpAndSettle();

      // Dialog popped, confirmation snackbar shown
      expect(find.byKey(const Key('card_share_dialog')), findsNothing);
      expect(find.textContaining('Sent "The One Ring" to @SpicyBrewMaster!'), findsOneWidget);

      // Verify message was stored in messages table
      final messages = await db.inboxDao.select(db.inboxDao.messages).get();
      expect(messages.length, equals(1));
      expect(messages.first.recipientId, equals('user_spicy'));
      expect(messages.first.attachmentType, equals('card'));
      expect(messages.first.attachmentCardId, equals('c_one_ring'));
    });

    testWidgets('T4.4: As Post launches PostComposerModal pre-attached with current card', (tester) async {
      final card = createTestCard(id: 'c_one_ring', name: 'The One Ring', currentMarketPrice: 95.0);
      await seedCard(card);

      await tester.pumpWidget(createTestApp(
        extraOverrides: [
          isUserLoggedInProvider.overrideWith((ref) => true),
        ],
        child: Builder(
          builder: (context) => ElevatedButton(
            key: const Key('open_card_btn'),
            onPressed: () => CardDetailSheet.show(context, card),
            child: const Text('Open'),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open_card_btn')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('quick_action_share')));
      await tester.pumpAndSettle();

      // Tap As Post option
      await tester.tap(find.byKey(const Key('share_as_post_option')));
      await tester.pumpAndSettle();

      // Share dialog popped, composer modal opened
      expect(find.byKey(const Key('card_share_dialog')), findsNothing);
      expect(find.byKey(const Key('unified_post_composer')), findsOneWidget);
      expect(find.text('singleCard'), findsOneWidget);
      expect(find.text('The One Ring'), findsWidgets);
    });
  });

  // =========================================================================
  // SUITE 5: EXPANDED CARD LIGHTBOX MODAL OVERLAY & FEED WIRING
  // =========================================================================
  group('Milestone 2 Challenge 5: Expanded Card Lightbox Modal Overlay', () {
    testWidgets('T5.1: Lightbox renders high-res art crop, page counter, and close button', (tester) async {
      final cards = [
        const ExpandedCardItem(
          cardId: 'c1',
          cardTitle: 'Sol Ring',
          cardSubtitle: 'Commander Essentials',
          estimatedValue: '\$2.50',
        ),
        const ExpandedCardItem(
          cardId: 'c2',
          cardTitle: 'Mana Crypt',
          cardSubtitle: 'Double Masters',
          estimatedValue: '\$180.00',
        ),
      ];

      await tester.pumpWidget(createTestApp(
        child: Builder(
          builder: (context) => ElevatedButton(
            key: const Key('open_lightbox_btn'),
            onPressed: () => ExpandedCardViewModal.show(context, cards: cards),
            child: const Text('Lightbox'),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open_lightbox_btn')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('expanded_card_view_lightbox')), findsOneWidget);
      expect(find.byKey(const Key('expanded_card_high_res_art')), findsOneWidget);
      expect(find.text('Sol Ring'), findsOneWidget);
      expect(find.text('1 / 2'), findsOneWidget);

      final closeBtnFinder = find.byKey(const Key('expanded_card_close_button'));
      expect(closeBtnFinder, findsOneWidget);

      // Verify close button position: Must be at top of screen (y <= 60), NOT vertically centered at y=300
      final center = tester.getCenter(closeBtnFinder);
      expect(
        center.dy,
        lessThan(60.0),
        reason: 'CRITICAL BUG: Close button is vertically centered at y=${center.dy} because SafeArea is not positioned in Stack(fit: StackFit.expand)',
      );

      // Close button dismisses
      await tester.tap(closeBtnFinder);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('expanded_card_view_lightbox')), findsNothing);
    });

    testWidgets('T5.2: Lightbox horizontal swipe navigation updates page counter and active card', (tester) async {
      final cards = [
        const ExpandedCardItem(cardId: 'c1', cardTitle: 'Alpha Lotus'),
        const ExpandedCardItem(cardId: 'c2', cardTitle: 'Beta Mox'),
        const ExpandedCardItem(cardId: 'c3', cardTitle: 'Time Walk'),
      ];

      await tester.pumpWidget(createTestApp(
        child: Builder(
          builder: (context) => ElevatedButton(
            key: const Key('open_lightbox_btn'),
            onPressed: () => ExpandedCardViewModal.show(context, cards: cards),
            child: const Text('Lightbox'),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open_lightbox_btn')));
      await tester.pumpAndSettle();

      expect(find.text('Alpha Lotus'), findsOneWidget);
      expect(find.text('1 / 3'), findsOneWidget);

      // Fling left to page 2
      await tester.fling(find.byType(PageView), const Offset(-600, 0), 1000);
      await tester.pumpAndSettle();

      expect(find.text('Beta Mox'), findsWidgets);
      expect(find.text('2 / 3'), findsOneWidget);

      // Fling left to page 3
      await tester.fling(find.byType(PageView), const Offset(-600, 0), 1000);
      await tester.pumpAndSettle();

      expect(find.text('Time Walk'), findsWidgets);
      expect(find.text('3 / 3'), findsOneWidget);
    });

    testWidgets('T5.3: [See Details] navigates to CardDetailSheet for currently swiped card', (tester) async {
      final item1 = createTestCard(id: 'c_lotus', name: 'Alpha Lotus');
      final item2 = createTestCard(id: 'c_mox', name: 'Beta Mox');
      await seedCard(item1);
      await seedCard(item2);

      final cards = [
        ExpandedCardItem(cardId: item1.id, cardTitle: item1.name, item: item1),
        ExpandedCardItem(cardId: item2.id, cardTitle: item2.name, item: item2),
      ];

      await tester.pumpWidget(createTestApp(
        child: Builder(
          builder: (context) => ElevatedButton(
            key: const Key('open_lightbox_btn'),
            onPressed: () => ExpandedCardViewModal.show(context, cards: cards),
            child: const Text('Lightbox'),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open_lightbox_btn')));
      await tester.pumpAndSettle();

      // Fling to item 2
      await tester.fling(find.byType(PageView), const Offset(-600, 0), 1000);
      await tester.pumpAndSettle();
      expect(find.text('2 / 2'), findsOneWidget);

      // Tap See Details
      await tester.tap(find.byKey(const Key('expanded_card_see_details_button')));
      await tester.pumpAndSettle();

      // Lightbox popped, CardDetailSheet open for Beta Mox
      expect(find.byKey(const Key('expanded_card_view_lightbox')), findsNothing);
      expect(find.byKey(const Key('card_detail_quick_action_bar')), findsOneWidget);
      expect(find.text('Beta Mox'), findsWidgets);
    });

    testWidgets('T5.4: PostCard single pull card tap routes to ExpandedCardViewModal', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      const post = FeedPost(
        id: 'post_sp_1',
        type: PostType.singlePull,
        username: '@collector_me',
        avatarInitials: 'ME',
        timestamp: 'Just now',
        locationTag: 'TBS Comics',
        textContent: 'Fresh booster pull!',
        cardTitle: 'The One Ring',
        cardId: 'c_one_ring',
      );

      await tester.pumpWidget(createTestApp(
        child: const SingleChildScrollView(
          child: PostCard(post: post),
        ),
      ));
      await tester.pumpAndSettle();

      // Tap card art area in single pull body
      final artFinder = find.byType(AspectRatio).first;
      await tester.tap(artFinder);
      await tester.pumpAndSettle();

      // Verifies Lightbox modal opened
      expect(find.byKey(const Key('expanded_card_view_lightbox')), findsOneWidget);
      expect(find.text('The One Ring'), findsWidgets);
    });
  });
}
