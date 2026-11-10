// Copyright (c) 2026 Countr. All rights reserved.
// Unit and Widget verification tests for Milestone 1 (F1–F5):
// - F1: High-res avatars for all mock profiles, circular PostHeader CountrCachedImage, zero initial bubbles.
// - F2: Seeded MTG comments match commentCount; reactive watchCommentCount stream updates PostCard counter.
// - F3: SinglePullPostBody has 8px padding, 63/88 aspect ratio, and BoxFit.contain.
// - F4: MultiPullPostBody renders 3-card combo row and 2x2 grid, cards tappable opening CardDetailSheet.
// - F5: Seeded media posts (16:9, 1:1, 4:5), MediaPostBody adaptive aspect ratio, and tap-to-zoom MediaLightboxViewer.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/cache/countr_cached_image.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/feed/data/social_seed_service.dart';
import 'package:countr/features/feed/domain/models/feed_post.dart';
import 'package:countr/features/feed/presentation/providers/feed_providers.dart';
import 'package:countr/features/feed/presentation/widgets/media_lightbox_viewer.dart';
import 'package:countr/features/feed/presentation/widgets/media_post_body.dart';
import 'package:countr/features/feed/presentation/widgets/multi_pull_post_body.dart';
import 'package:countr/features/feed/presentation/widgets/post_action_bar.dart';
import 'package:countr/features/feed/presentation/widgets/post_card.dart';
import 'package:countr/features/feed/presentation/widgets/post_header.dart';
import 'package:countr/features/feed/presentation/widgets/single_pull_post_body.dart';
import 'package:countr/features/profile/presentation/providers/profile_providers.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late SocialSeedService seedService;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.userProfileDao.seedDefaultProfiles();
    seedService = SocialSeedService(db);
    await seedService.seedSocialData();
  });

  tearDown(() async {
    await db.close();
  });

  Widget wrapWithScope({required Widget child}) {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        currentUserIdProvider.overrideWith((ref) => 'user-current-me'),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: child),
        ),
      ),
    );
  }

  group('F1: User Avatars and PostHeader Rendering', () {
    test('default seeded profiles have valid high-resolution avatar URLs', () async {
      final expectedUserIds = [
        'user-current-me',
        'user-spicy-brew-master',
        'user-foil-collector-99',
        'user-edh-rec-fanatic',
        'store-tbs-comics',
      ];

      for (final userId in expectedUserIds) {
        final profile = await db.userProfileDao.getProfile(userId);
        expect(profile, isNotNull, reason: 'Profile should exist for $userId');
        expect(profile!.avatarUrl, isNotNull, reason: 'Avatar URL should not be null for $userId');
        expect(profile.avatarUrl!.isNotEmpty, isTrue, reason: 'Avatar URL should not be empty for $userId');
        expect(profile.avatarUrl!.startsWith('https://images.unsplash.com'), isTrue,
            reason: 'Avatar URL should be a high-res Unsplash image for $userId');
      }
    });

    test('watchFeedPosts populates authorAvatarUrl from joined user_profiles', () async {
      final postRecords = await db.feedDao.watchFeedPosts().first;
      expect(postRecords, isNotEmpty);

      for (final record in postRecords) {
        expect(record.authorAvatarUrl, isNotNull, reason: 'Post ${record.id} authorAvatarUrl should not be null');
        expect(record.authorAvatarUrl!.isNotEmpty, isTrue, reason: 'Post ${record.id} authorAvatarUrl should not be empty');
        expect(record.authorAvatarUrl!.startsWith('https://images.unsplash.com'), isTrue,
            reason: 'Post ${record.id} should have a valid high-res avatar URL');

        final post = FeedPost.fromRecord(record);
        expect(post.avatarUrl, isNotNull);
        expect(post.avatarUrl!.isNotEmpty, isTrue);
      }
    });

    testWidgets('PostHeader renders circular CountrCachedImage when avatarUrl is provided', (tester) async {
      const avatarUrl = 'https://images.unsplash.com/photo-1534528741775-53994a69daeb';
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: PostHeader(
            username: '@SpicyBrewMaster',
            avatarInitials: 'SB',
            avatarUrl: avatarUrl,
            timestamp: '2h ago',
            locationTag: 'TBS Comics',
          ),
        ),
      ));
      await tester.pump();

      // Should find CountrCachedImage inside PostHeader
      expect(find.byType(CountrCachedImage), findsOneWidget);
      final cachedImage = tester.widget<CountrCachedImage>(find.byType(CountrCachedImage));
      expect(cachedImage.imageUrl, equals(avatarUrl));
    });

    testWidgets('PostHeader falls back to avatar initials if avatarUrl is null', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: PostHeader(
            username: '@UnknownUser',
            avatarInitials: 'UU',
            avatarUrl: null,
            timestamp: '10m ago',
            locationTag: 'Online',
          ),
        ),
      ));
      await tester.pump();

      expect(find.text('UU'), findsOneWidget);
      expect(find.byType(CountrCachedImage), findsNothing);
    });
  });

  group('F2: Mock Comments Population and Reactive Counter', () {
    test('seeded SQLite feed comments strictly equal commentCount on all posts', () async {
      final postRecords = await db.feedDao.watchFeedPosts().first;
      expect(postRecords, isNotEmpty);

      // Verify each post has actual comments matching its commentCount property
      for (final record in postRecords) {
        final commentCountInDb = await db.feedDao.watchCommentCount(record.id).first;
        expect(
          commentCountInDb,
          equals(record.commentCount),
          reason: 'Post ${record.id} SQLite COUNT(*) ($commentCountInDb) must equal record.commentCount (${record.commentCount})',
        );
      }

      // Verify exact counts specified in requirements
      expect(await db.feedDao.watchCommentCount('post-foil-showcase').first, equals(8));
      expect(await db.feedDao.watchCommentCount('post-edh-deck-share').first, equals(5));
      expect(await db.feedDao.watchCommentCount('post-tbs-fnm-event').first, equals(12));
      expect(await db.feedDao.watchCommentCount('post-spicy-pull').first, equals(3));
      expect(await db.feedDao.watchCommentCount('post-edh-combo-showcase').first, equals(4));
      expect(await db.feedDao.watchCommentCount('post-media-16-9-pod').first, equals(2));
      expect(await db.feedDao.watchCommentCount('post-media-1-1-tournament').first, equals(3));
      expect(await db.feedDao.watchCommentCount('post-media-4-5-playmat').first, equals(2));
    });

    test('watchCommentCount emits updated count when new comment added', () async {
      const postId = 'post-spicy-pull';
      final initialCount = await db.feedDao.watchCommentCount(postId).first;
      expect(initialCount, equals(3));

      // Add a comment
      await db.feedDao.addComment(
        postId: postId,
        authorId: 'user-current-me',
        authorUsername: '@collector_me',
        authorDisplayName: 'Collector Me',
        content: 'Insane pull, congrats!',
      );

      final updatedCount = await db.feedDao.watchCommentCount(postId).first;
      expect(updatedCount, equals(4));
    });

    test('postCommentCountProvider streams reactive count updates across Riverpod', () async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          currentUserIdProvider.overrideWith((ref) => 'user-current-me'),
        ],
      );
      addTearDown(container.dispose);

      const postId = 'post-spicy-pull';
      container.listen(postCommentCountProvider(postId), (previous, next) {});
      await pumpEventQueue();
      expect(container.read(postCommentCountProvider(postId)).value, equals(3));

      // Insert new comment into SQLite
      await db.feedDao.addComment(
        postId: postId,
        authorId: 'user-current-me',
        authorUsername: '@collector_me',
        authorDisplayName: 'Collector Me',
        content: 'Riverpod reactive comment test',
      );

      await pumpEventQueue();
      expect(container.read(postCommentCountProvider(postId)).value, equals(4));
    });

    testWidgets('PostActionBar renders comment count and updates when widget property changes', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: PostActionBar(
            initialHypeCount: 15,
            commentCount: 3,
          ),
        ),
      ));
      await tester.pump();

      expect(find.text('COMMENT (3)'), findsOneWidget);

      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: PostActionBar(
            initialHypeCount: 15,
            commentCount: 4,
          ),
        ),
      ));
      await tester.pump();

      expect(find.text('COMMENT (4)'), findsOneWidget);
    });

    testWidgets('PostCard renders with reactive comment count from scope', (tester) async {
      // Create a text post for post-foil-showcase (8 comments in SQLite).
      // Initial post model has commentCount: 0; reactive stream will update it to 8.
      const textPost = FeedPost(
        id: 'post-foil-showcase',
        type: PostType.text,
        username: '@FoilCollector99',
        avatarInitials: 'FC',
        avatarUrl: null,
        timestamp: '1h ago',
        locationTag: 'TBS Comics',
        textContent: 'Testing reactive counter on text post',
        commentCount: 0,
      );

      await tester.pumpWidget(wrapWithScope(
        child: const PostCard(post: textPost),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // PostCard action bar renders COMMENT (8) based on SQLite postComments COUNT(*)
      expect(find.text('COMMENT (8)'), findsOneWidget);
    });
  });

  group('F3: SinglePullPostBody Card Art Area Prominence', () {
    testWidgets('SinglePullPostBody renders with 8px horizontal padding and 63/88 aspect ratio', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SinglePullPostBody(
              commentary: 'Opening a collector booster pack!',
              cardTitle: 'The One Ring (Serialized #007/100)',
              cardSubtitle: 'The Lord of the Rings: Tales of Middle-earth',
              cardRarity: 'Mythic Rare',
              estimatedValue: '\$1,250.00',
              cardId: 'item-mtg-one-ring',
              imageUrl: 'https://cards.scryfall.io/large/front/d/5/d5806e68-1054-458e-866d-1f2470f682b2.jpg',
            ),
          ),
        ),
      ));
      await tester.pump();

      // Verify outer card artwork container padding is 8px horizontal
      final paddingFinder = find.byWidgetPredicate((widget) {
        return widget is Padding && widget.padding == const EdgeInsets.symmetric(horizontal: 8);
      });
      expect(paddingFinder, findsOneWidget);

      // Verify AspectRatio 63 / 88 is present
      final aspectRatioFinder = find.byWidgetPredicate((widget) {
        return widget is AspectRatio && (widget.aspectRatio - (63.0 / 88.0)).abs() < 0.001;
      });
      expect(aspectRatioFinder, findsAtLeastNWidgets(1));

      // Verify CountrCachedImage has fit: BoxFit.contain
      final imageFinder = find.byType(CountrCachedImage);
      expect(imageFinder, findsOneWidget);
      final cachedImage = tester.widget<CountrCachedImage>(imageFinder);
      expect(cachedImage.fit, equals(BoxFit.contain));
    });
  });

  group('F4: MultiPullPostBody Layout and Card Interaction', () {
    test('seeded EDH combo showcase post exists and has 3 cards', () async {
      final records = await db.feedDao.watchFeedPosts().first;
      final comboRecord = records.firstWhere((p) => p.id == 'post-edh-combo-showcase');
      final comboPost = FeedPost.fromRecord(comboRecord);

      expect(comboPost.type, equals(PostType.multiPull));
      expect(comboPost.pullImages.length, equals(3));
      expect(comboPost.pullCardIds.length, equals(3));
      expect(comboPost.pullCardIds[0], equals('item-card-urza-high-artificer'));
      expect(comboPost.pullCardIds[2], equals('item-card-dramatic-reversal'));
      expect(comboPost.textContent, contains('Urza'));
    });

    testWidgets('MultiPullPostBody with 3 cards renders side-by-side combo row', (tester) async {
      int? tappedIndex;
      String? tappedCardId;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MultiPullPostBody(
              commentary: 'Urza + Isochron Scepter + Dramatic Reversal combo ready!',
              pullItems: const [
                'https://cards.scryfall.io/large/front/1/7/17b429bd-d7da-444e-9882-070a25e754dd.jpg',
                'https://cards.scryfall.io/large/front/0/4/04945da0-ade0-4f50-b970-746977311388.jpg',
                'https://cards.scryfall.io/large/front/2/c/2c1d02d4-7c65-491c-836d-4b14ee909b22.jpg',
              ],
              pullCardIds: const [
                'item-card-urza-high-artificer',
                'item-mtg-sol-ring',
                'item-card-dramatic-reversal',
              ],
              onCardTap: (index, cardId) {
                tappedIndex = index;
                tappedCardId = cardId;
              },
            ),
          ),
        ),
      ));
      await tester.pump();

      // Verify 3 aspect ratio cards (63/88) in row
      final aspectRatios = find.byWidgetPredicate((widget) {
        return widget is AspectRatio && (widget.aspectRatio - (63.0 / 88.0)).abs() < 0.001;
      });
      expect(aspectRatios, findsNWidgets(3));

      // Verify tapping on the first card triggers callback with resolvedCardId
      await tester.tap(aspectRatios.at(0));
      await tester.pump();
      expect(tappedIndex, equals(0));
      expect(tappedCardId, equals('item-card-urza-high-artificer'));

      // Verify tapping on the third card triggers callback
      await tester.tap(aspectRatios.at(2));
      await tester.pump();
      expect(tappedIndex, equals(2));
      expect(tappedCardId, equals('item-card-dramatic-reversal'));
    });

    testWidgets('MultiPullPostBody with 4 cards renders 2x2 grid with + SEE MORE', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1000));
      bool seeMoreTapped = false;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MultiPullPostBody(
              commentary: 'Opening 4 collector boosters',
              pullItems: const [
                'Card 1',
                'Card 2',
                'Card 3',
                'Card 4',
              ],
              onSeeMoreTap: () {
                seeMoreTapped = true;
              },
            ),
          ),
        ),
      ));
      await tester.pump();

      expect(find.byType(GridView), findsOneWidget);
      expect(find.text('+ SEE MORE'), findsOneWidget);

      await tester.tap(find.text('+ SEE MORE'));
      await tester.pump();
      expect(seeMoreTapped, isTrue);
    });
  });

  group('F5: MediaPostBody and MediaLightboxViewer', () {
    test('seeded media posts exist with correct aspect ratios and tags', () async {
      final records = await db.feedDao.watchFeedPosts().first;

      final podRecord = records.firstWhere((p) => p.id == 'post-media-16-9-pod');
      final podPost = FeedPost.fromRecord(podRecord);
      expect(podPost.type, equals(PostType.media));
      expect(podPost.cardSubtitle, equals('16:9'));

      final tourneyRecord = records.firstWhere((p) => p.id == 'post-media-1-1-tournament');
      final tourneyPost = FeedPost.fromRecord(tourneyRecord);
      expect(tourneyPost.type, equals(PostType.media));
      expect(tourneyPost.cardSubtitle, equals('1:1'));

      final playmatRecord = records.firstWhere((p) => p.id == 'post-media-4-5-playmat');
      final playmatPost = FeedPost.fromRecord(playmatRecord);
      expect(playmatPost.type, equals(PostType.media));
      expect(playmatPost.cardSubtitle, equals('4:5'));
    });

    testWidgets('MediaPostBody renders 16:9, 1:1, and 4:5 without overflow', (tester) async {
      const media169 = MediaPostBody(
        imageUrl: 'https://images.unsplash.com/photo-1511512578047-dfb367046420',
        aspectRatioTag: '16:9',
        caption: 'Commander Night at TBS Comics',
      );
      expect(media169.resolvedAspectRatio, closeTo(16.0 / 9.0, 0.01));

      const media11 = MediaPostBody(
        imageUrl: 'https://images.unsplash.com/photo-1607604276583-eef5d076aa5f',
        aspectRatioTag: '1:1',
        caption: 'TBS Comics FNM Top 8 Standings',
      );
      expect(media11.resolvedAspectRatio, closeTo(1.0, 0.01));

      const media45 = MediaPostBody(
        imageUrl: 'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe',
        aspectRatioTag: '4:5',
        caption: 'Custom hand-painted leather deck box',
      );
      expect(media45.resolvedAspectRatio, closeTo(4.0 / 5.0, 0.01));

      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                media169,
                SizedBox(height: 16),
                media11,
                SizedBox(height: 16),
                media45,
              ],
            ),
          ),
        ),
      ));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(MediaPostBody), findsNWidgets(3));
    });

    testWidgets('MediaLightboxViewer displays InteractiveViewer, caption, and closes on button tap', (tester) async {
      const testImageUrl = 'https://images.unsplash.com/photo-1511512578047-dfb367046420';
      const testCaption = 'Full pod photo in lightbox';
      bool closed = false;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                key: const Key('open_lightbox_btn'),
                onPressed: () {
                  MediaLightboxViewer.show(
                    context,
                    imageUrl: testImageUrl,
                    caption: testCaption,
                  ).then((_) => closed = true);
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      ));
      await tester.pump();

      // Tap open button
      await tester.tap(find.byKey(const Key('open_lightbox_btn')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // Lightbox modal should be open
      expect(find.byType(MediaLightboxViewer), findsOneWidget);
      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(find.text(testCaption), findsOneWidget);

      // Tap close button to dismiss lightbox
      final closeBtn = find.byKey(const Key('media_lightbox_close_button'));
      expect(closeBtn, findsOneWidget);
      await tester.tap(closeBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // Lightbox should be closed
      expect(find.byType(MediaLightboxViewer), findsNothing);
      expect(closed, isTrue);
    });

    testWidgets('MediaPostBody tap triggers onTap callback or lightbox show', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MediaPostBody(
            imageUrl: '',
            aspectRatioTag: '16:9',
            caption: 'Test Pod',
            onTap: () {
              tapped = true;
            },
          ),
        ),
      ));
      await tester.pump();

      await tester.tap(find.byType(AspectRatio));
      await tester.pump();

      expect(tapped, isTrue);
    });
  });
}
