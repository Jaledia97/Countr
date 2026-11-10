// Copyright (c) 2026 Countr. All rights reserved.
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/feed/presentation/widgets/post_composer_modal.dart';
import 'package:countr/features/feed/presentation/providers/feed_providers.dart';
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

  Widget createTestApp({required Widget child}) {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        vaultDaoProvider.overrideWithValue(db.vaultDao),
        feedDaoProvider.overrideWithValue(db.feedDao),
        currentUserIdProvider.overrideWith((ref) => 'user-current-me'),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: child,
        ),
      ),
    );
  }

  group('Challenger M2-IT2: Deep Adversarial Ghost Card Stress Tests', () {
    testWidgets('CS1: Rapid multi-type churn: 5 cards -> odd deletions -> 2 images -> remove all cards -> remove 1 image -> publish', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestApp(
        child: const Center(child: PostComposerModal()),
      ));
      await tester.pumpAndSettle();

      // Attach 5 cards
      for (int i = 0; i < 5; i++) {
        await tester.tap(find.byKey(const Key('post_add_card_button')));
        await tester.pumpAndSettle();
      }
      expect(find.text('multiCard'), findsOneWidget);

      // Remove index 3, then index 1
      await tester.tap(find.byKey(const Key('remove_attached_card_3')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('remove_attached_card_1')));
      await tester.pumpAndSettle();

      // Attach 2 images
      await tester.tap(find.byKey(const Key('post_add_image_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('post_add_image_button')));
      await tester.pumpAndSettle();
      expect(find.text('mixedMedia'), findsOneWidget);

      // Remove all 3 remaining cards: index 0, 0, 0
      for (int i = 0; i < 3; i++) {
        await tester.tap(find.byKey(const Key('remove_attached_card_0')));
        await tester.pumpAndSettle();
      }
      expect(find.text('image'), findsOneWidget);

      // Remove 1 image: index 1
      await tester.tap(find.byKey(const Key('remove_attached_image_1')));
      await tester.pumpAndSettle();
      expect(find.text('image'), findsOneWidget);

      // Publish
      await tester.tap(find.byKey(const Key('post_composer_publish_button')));
      await tester.pumpAndSettle();

      final posts = await db.feedDao.select(db.feedDao.feedPosts).get();
      expect(posts.length, equals(1));
      final post = posts.first;
      expect(post.type, equals('media'));
      expect(post.cardTitle, isNull);
      expect(post.cardId, isNull);
      final images = jsonDecode(post.pullImagesJson!) as List;
      expect(images.length, equals(1));
      expect(images.first, equals('image_1.jpg'));
    });

    testWidgets('CS2: Pre-attached card + image toggles -> all removed -> pure text publish', (tester) async {
      await tester.pumpWidget(createTestApp(
        child: const Center(
          child: PostComposerModal(
            preAttachedCardId: 'c_ghost',
            preAttachedCardName: 'Ghost Hunter',
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('singleCard'), findsOneWidget);
      expect(find.text('Ghost Hunter'), findsOneWidget);

      // Add image
      await tester.tap(find.byKey(const Key('post_add_image_button')));
      await tester.pumpAndSettle();
      expect(find.text('mixedMedia'), findsOneWidget);

      // Remove pre-attached card
      await tester.tap(find.byKey(const Key('remove_attached_card_0')));
      await tester.pumpAndSettle();
      expect(find.text('image'), findsOneWidget);

      // Remove image
      await tester.tap(find.byKey(const Key('remove_attached_image_0')));
      await tester.pumpAndSettle();
      expect(find.text('textOnly'), findsOneWidget);

      // Enter pure text
      await tester.enterText(find.byKey(const Key('post_composer_text_input')), 'Clean note without cards');
      await tester.pumpAndSettle();

      // Publish
      await tester.tap(find.byKey(const Key('post_composer_publish_button')));
      await tester.pumpAndSettle();

      final posts = await db.feedDao.select(db.feedDao.feedPosts).get();
      expect(posts.length, equals(1));
      final post = posts.first;
      expect(post.type, equals('text'));
      expect(post.textContent, equals('Clean note without cards'));
      expect(post.cardTitle, isNull);
      expect(post.cardId, isNull);
      expect(post.estimatedValue, isNull);
      expect(post.pullImagesJson, isNull);
    });

    testWidgets('CS3: Pre-attached card removed + whitespace text -> multiple rapid publish taps rejected', (tester) async {
      await tester.pumpWidget(createTestApp(
        child: const Center(
          child: PostComposerModal(
            preAttachedCardId: 'c_ghost',
            preAttachedCardName: 'Ghost Hunter',
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Remove pre-attached card
      await tester.tap(find.byKey(const Key('remove_attached_card_0')));
      await tester.pumpAndSettle();
      expect(find.text('textOnly'), findsOneWidget);

      // Enter whitespace text
      await tester.enterText(find.byKey(const Key('post_composer_text_input')), '   \n\t \n  ');
      await tester.pumpAndSettle();

      // Rapidly tap publish 5 times
      for (int i = 0; i < 5; i++) {
        await tester.tap(find.byKey(const Key('post_composer_publish_button')));
      }
      await tester.pumpAndSettle();

      final posts = await db.feedDao.select(db.feedDao.feedPosts).get();
      expect(posts.isEmpty, isTrue, reason: 'Whitespace-only post after card removal must never insert rows into feedPosts table');
    });

    testWidgets('CS4: Pre-attached card removed, then new card added -> new card identity must replace old', (tester) async {
      await tester.pumpWidget(createTestApp(
        child: const Center(
          child: PostComposerModal(
            preAttachedCardId: 'c_ghost',
            preAttachedCardName: 'Ghost Hunter',
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Remove Ghost Hunter
      await tester.tap(find.byKey(const Key('remove_attached_card_0')));
      await tester.pumpAndSettle();
      expect(find.text('textOnly'), findsOneWidget);
      expect(find.text('Ghost Hunter'), findsNothing);

      // Add a fresh card
      await tester.tap(find.byKey(const Key('post_add_card_button')));
      await tester.pumpAndSettle();
      expect(find.text('singleCard'), findsOneWidget);
      expect(find.text('Card 1'), findsOneWidget);

      // Publish
      await tester.tap(find.byKey(const Key('post_composer_publish_button')));
      await tester.pumpAndSettle();

      final posts = await db.feedDao.select(db.feedDao.feedPosts).get();
      expect(posts.length, equals(1));
      final post = posts.first;
      expect(post.type, equals('single_pull'));
      expect(post.cardTitle, equals('Card 1'));
      expect(post.cardTitle, isNot(equals('Ghost Hunter')));
      expect(post.cardId, equals('card_1'));
    });

    testWidgets('CS5: Legacy input with card title overridden when modern card is attached', (tester) async {
      await tester.pumpWidget(createTestApp(
        child: const Center(
          child: PostComposerModal(
            initialPostType: 'single_pull',
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Legacy mode has title input
      expect(find.byKey(const Key('post_composer_card_title_input')), findsOneWidget);
      await tester.enterText(find.byKey(const Key('post_composer_card_title_input')), 'Mox Diamond');
      await tester.pumpAndSettle();

      // Now attach a modern card
      await tester.tap(find.byKey(const Key('post_add_card_button')));
      await tester.pumpAndSettle();
      expect(find.text('singleCard'), findsOneWidget);

      // Publish
      await tester.tap(find.byKey(const Key('post_composer_publish_button')));
      await tester.pumpAndSettle();

      final posts = await db.feedDao.select(db.feedDao.feedPosts).get();
      expect(posts.length, equals(1));
      final post = posts.first;
      expect(post.type, equals('single_pull'));
      expect(post.cardTitle, equals('Card 1'));
      expect(post.cardId, equals('card_1'));
    });
  });
}
