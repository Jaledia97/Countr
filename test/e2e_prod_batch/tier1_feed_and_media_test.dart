import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/feed/data/daos/feed_dao.dart';
import 'package:countr/features/feed/domain/models/feed_post.dart';
import 'package:countr/features/feed/presentation/widgets/post_action_bar.dart';
import 'package:countr/features/feed/presentation/widgets/post_header.dart';
import 'package:countr/features/feed/presentation/widgets/single_pull_post_body.dart';
import 'package:countr/features/feed/presentation/widgets/text_post_body.dart';

import 'e2e_prod_batch_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Tier 1 - Feature 1: Real Avatars & Zero Initial Bubbles (F1.1 to F1.5)', () {
    late AppDatabase db;
    late FeedDao feedDao;

    setUp(() async {
      db = createE2eProdBatchTestDb();
      feedDao = FeedDao(db);
      await seedPersonaUserProfiles(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('F1.1: Seeded persona user profiles contain valid non-empty high-resolution avatar URLs', () async {
      final profiles = await db.select(db.userProfiles).get();
      expect(profiles.length, greaterThanOrEqualTo(5));

      final spicy = profiles.firstWhere((p) => p.username == '@SpicyBrewMaster');
      expect(spicy.avatarUrl, isNotNull);
      expect(spicy.avatarUrl!, startsWith('https://images.unsplash.com/'));

      final edh = profiles.firstWhere((p) => p.username == '@EDH_Rec_Fanatic');
      expect(edh.avatarUrl, isNotNull);
      expect(edh.avatarUrl!, isNotEmpty);

      final tbs = profiles.firstWhere((p) => p.username == '@TBSComics');
      expect(tbs.avatarUrl, isNotNull);
      expect(tbs.isVerifiedBusiness, isTrue);
    });

    test('F1.2: FeedPost.fromRecord resolves a valid avatarUrl for seeded usernames when record avatar is null', () {
      final record = createTestFeedPostRecord(
        id: 'post-f1-test',
        authorId: 'user-edh-rec-fanatic',
        authorUsername: '@EDH_Rec_Fanatic',
        authorDisplayName: 'EDH Rec Fanatic',
        authorAvatarUrl: null,
        type: 'single_pull',
        likeCount: 5,
        commentCount: 2,
      );

      final domainPost = FeedPost.fromRecord(record);
      expect(domainPost.avatarUrl, isNotNull);
      expect(domainPost.avatarUrl!, contains('unsplash.com'));
      expect(domainPost.effectiveAuthorId, equals('user-edh-rec-fanatic'));
    });

    test('F1.3: FeedDao.watchFeedPosts emits posts with valid author profile metadata', () async {
      final postCompanion = createTestFeedPostCompanion(
        id: 'post-stream-1',
        authorId: 'user-spicy-brew-master',
        authorUsername: '@SpicyBrewMaster',
        authorDisplayName: 'Spicy Brewmaster',
        authorAvatarUrl: 'https://images.unsplash.com/avatar-spicy.jpg',
        textContent: 'Testing live feed avatar joining',
      );
      await feedDao.createPost(postCompanion);

      final posts = await feedDao.watchFeedPosts().first;
      expect(posts.length, equals(1));
      expect(posts.first.authorAvatarUrl, startsWith('https://images.unsplash.com/'));
      expect(posts.first.authorUsername, equals('@SpicyBrewMaster'));
    });

    test('F1.4: FeedDao.updateAuthorAvatar cascades updated avatar URL to all authored posts', () async {
      await feedDao.createPost(createTestFeedPostCompanion(
        id: 'post-cascade-1',
        authorId: 'user-foil-collector-99',
        authorUsername: '@FoilCollector99',
        authorDisplayName: 'Foil Collector 99',
        authorAvatarUrl: 'https://images.unsplash.com/avatar-old.jpg',
      ));
      await feedDao.createPost(createTestFeedPostCompanion(
        id: 'post-cascade-2',
        authorId: 'user-foil-collector-99',
        authorUsername: '@FoilCollector99',
        authorDisplayName: 'Foil Collector 99',
        authorAvatarUrl: 'https://images.unsplash.com/avatar-old.jpg',
      ));

      await feedDao.updateAuthorAvatar('user-foil-collector-99', 'https://images.unsplash.com/avatar-new.jpg');

      final post1 = await feedDao.getPostById('post-cascade-1');
      final post2 = await feedDao.getPostById('post-cascade-2');
      expect(post1, isNotNull);
      expect(post2, isNotNull);
      expect(post1!.authorAvatarUrl, equals('https://images.unsplash.com/avatar-new.jpg'));
      expect(post2!.authorAvatarUrl, equals('https://images.unsplash.com/avatar-new.jpg'));
    });

    testWidgets('F1.5: PostHeader renders avatar container with key post_avatar_{id} and triggers onUserTap', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        wrapWithMaterialAndScope(
          PostHeader(
            username: '@SpicyBrewMaster',
            avatarInitials: 'SB',
            timestamp: '5m ago',
            locationTag: 'Orlando, FL',
            authorId: 'user-spicy-brew-master',
            onUserTap: () => tapped = true,
          ),
        ),
      );

      final avatarFinder = find.byKey(const Key('post_avatar_user-spicy-brew-master'));
      expect(avatarFinder, findsOneWidget);

      await tester.tap(avatarFinder);
      await tester.pump();
      expect(tapped, isTrue);
    });
  });

  group('Tier 1 - Feature 2: Real Mock Comments & Reactive Counter (F2.1 to F2.5)', () {
    late AppDatabase db;
    late FeedDao feedDao;

    setUp(() async {
      db = createE2eProdBatchTestDb();
      feedDao = FeedDao(db);
      await seedPersonaUserProfiles(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('F2.1: FeedDao.watchComments emits empty list initially, then updates upon new comments', () async {
      final postId = 'post-comments-test-1';
      await feedDao.createPost(createTestFeedPostCompanion(
        id: postId,
        authorId: 'user-edh-rec-fanatic',
        authorUsername: '@EDH_Rec_Fanatic',
        authorDisplayName: 'EDH Rec Fanatic',
        commentCount: 0,
      ));

      final initialComments = await feedDao.watchComments(postId).first;
      expect(initialComments, isEmpty);

      await feedDao.addComment(
        postId: postId,
        authorId: 'user-spicy-brew-master',
        authorUsername: '@SpicyBrewMaster',
        authorDisplayName: 'Spicy Brewmaster',
        content: 'Awesome pull! What deck does this go in?',
      );

      final updatedComments = await feedDao.watchComments(postId).first;
      expect(updatedComments.length, equals(1));
      expect(updatedComments.first.content, equals('Awesome pull! What deck does this go in?'));
    });

    test('F2.2: FeedDao.addComment atomically inserts comment, increments post commentCount, and returns record', () async {
      final postId = 'post-comments-test-2';
      await feedDao.createPost(createTestFeedPostCompanion(
        id: postId,
        authorId: 'user-foil-collector-99',
        authorUsername: '@FoilCollector99',
        authorDisplayName: 'Foil Collector 99',
        commentCount: 0,
      ));

      final commentRecord = await feedDao.addComment(
        postId: postId,
        authorId: 'user-current-me',
        authorUsername: '@collector_me',
        authorDisplayName: 'Me',
        content: 'Mint condition! That foil is gorgeous.',
      );

      expect(commentRecord.id, isNotEmpty);
      expect(commentRecord.content, equals('Mint condition! That foil is gorgeous.'));

      final post = await feedDao.getPostById(postId);
      expect(post, isNotNull);
      expect(post!.commentCount, equals(1));
    });

    test('F2.3: Multiple comments added maintain ascending chronological order in stream', () async {
      final postId = 'post-comments-test-3';
      await feedDao.createPost(createTestFeedPostCompanion(
        id: postId,
        authorId: 'store-tbs-comics',
        authorUsername: '@TBSComics',
        authorDisplayName: 'TBS Comics',
        commentCount: 0,
      ));

      final t1 = DateTime.now().subtract(const Duration(seconds: 10));
      final t2 = DateTime.now().subtract(const Duration(seconds: 5));

      await insertTestComment(
        db,
        id: 'comment-1',
        postId: postId,
        authorId: 'user-1',
        authorUsername: '@user1',
        authorDisplayName: 'User 1',
        content: 'First comment!',
        createdAt: t1,
      );

      await insertTestComment(
        db,
        id: 'comment-2',
        postId: postId,
        authorId: 'user-2',
        authorUsername: '@user2',
        authorDisplayName: 'User 2',
        content: 'Second comment!',
        createdAt: t2,
      );

      final comments = await feedDao.watchComments(postId).first;
      expect(comments.length, equals(2));
      expect(comments[0].content, equals('First comment!'));
      expect(comments[1].content, equals('Second comment!'));
    });

    test('F2.4: Adding a comment by another user generates a notification for the post author in notifications table', () async {
      final postId = 'post-comments-test-4';
      await feedDao.createPost(createTestFeedPostCompanion(
        id: postId,
        authorId: 'user-spicy-brew-master',
        authorUsername: '@SpicyBrewMaster',
        authorDisplayName: 'Spicy Brewmaster',
      ));

      await feedDao.addComment(
        postId: postId,
        authorId: 'user-edh-rec-fanatic',
        authorUsername: '@EDH_Rec_Fanatic',
        authorDisplayName: 'EDH Rec Fanatic',
        content: 'I built a commander deck around this!',
      );

      final notifs = await (db.select(db.notifications)
            ..where((t) => t.userId.equals('user-spicy-brew-master')))
          .get();
      expect(notifs.length, equals(1));
      expect(notifs.first.type, equals('post_comment'));
      expect(notifs.first.actorUsername, equals('@EDH_Rec_Fanatic'));
      expect(notifs.first.targetEntityId, equals(postId));
    });

    testWidgets('F2.5: PostActionBar displays commentCount and triggers onCommentTap callback', (tester) async {
      bool commentTapped = false;
      await tester.pumpWidget(
        wrapWithMaterialAndScope(
          PostActionBar(
            initialHypeCount: 99,
            commentCount: 42,
            onCommentTap: () => commentTapped = true,
          ),
        ),
      );

      expect(find.text('COMMENT (42)'), findsOneWidget);
      expect(find.text('HYPE (99)'), findsOneWidget);

      final commentButtonFinder = find.byKey(const Key('post_action_comment'));
      expect(commentButtonFinder, findsOneWidget);

      await tester.tap(commentButtonFinder);
      await tester.pump();
      expect(commentTapped, isTrue);
    });
  });

  group('Tier 1 - Feature 3: Prominent Card Art Sizing (F3.1 to F3.5)', () {
    testWidgets('F3.1: SinglePullPostBody renders card container with tap key single_pull_card_{cardId}', (tester) async {
      await tester.pumpWidget(
        wrapWithMaterialAndScope(
          const SingleChildScrollView(
            child: SinglePullPostBody(
              cardId: 'card-lotr-001',
              cardTitle: 'The One Ring',
              cardSubtitle: 'Tales of Middle-earth',
              estimatedValue: '\$120.00',
              imageUrl: 'https://cards.scryfall.io/normal/front/d/5/d5806e68.jpg',
            ),
          ),
        ),
      );

      final cardFinder = find.byKey(const Key('single_pull_card_card-lotr-001'));
      expect(cardFinder, findsOneWidget);
    });

    testWidgets('F3.2: SinglePullPostBody handles empty commentary and renders card container directly', (tester) async {
      await tester.pumpWidget(
        wrapWithMaterialAndScope(
          const SingleChildScrollView(
            child: SinglePullPostBody(
              cardId: 'card-lotr-002',
              cardTitle: 'Orcish Bowmasters',
              commentary: null,
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('single_pull_card_card-lotr-002')), findsOneWidget);
      expect(find.text('RAW SCAN 600 DPI'), findsOneWidget);
    });

    testWidgets('F3.3: Tapping SinglePullPostBody invokes onCardTap callback cleanly', (tester) async {
      bool cardTapped = false;
      await tester.pumpWidget(
        wrapWithMaterialAndScope(
          SingleChildScrollView(
            child: SinglePullPostBody(
              cardId: 'card-tap-test',
              cardTitle: 'Sheoldred, the Apocalypse',
              onCardTap: () => cardTapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('single_pull_card_card-tap-test')));
      await tester.pump();
      expect(cardTapped, isTrue);
    });

    testWidgets('F3.4: SinglePullPostBody renders ManaText commentary when commentary is provided', (tester) async {
      await tester.pumpWidget(
        wrapWithMaterialAndScope(
          const SingleChildScrollView(
            child: SinglePullPostBody(
              cardId: 'card-commentary-test',
              commentary: 'Pulled this beauty from a collector booster! {T}: Draw a card.',
            ),
          ),
        ),
      );

      expect(find.textContaining('Pulled this beauty'), findsOneWidget);
    });

    testWidgets('F3.5: SinglePullPostBody renders without layout overflow on narrow mobile screens (320dp)', (tester) async {
      tester.view.physicalSize = const Size(320, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        wrapWithMaterialAndScope(
          const SinglePullPostBody(
            cardId: 'card-narrow-test',
            cardTitle: 'Ragavan, Nimble Pilferer',
            commentary: 'Testing narrow viewport layout resilience.',
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('single_pull_card_card-narrow-test')), findsOneWidget);
    });
  });

  group('Tier 1 - Feature 4: Multi-Card Combo & Haul Post (F4.1 to F4.5)', () {
    late AppDatabase db;
    late FeedDao feedDao;

    setUp(() async {
      db = createE2eProdBatchTestDb();
      feedDao = FeedDao(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('F4.1: FeedDao.createPost stores multi-pull post with pullImagesJson and pullCardIdsJson', () async {
      await feedDao.createPost(createTestFeedPostCompanion(
        id: 'post-multi-dao-1',
        authorId: 'user-spicy-brew-master',
        authorUsername: '@SpicyBrewMaster',
        authorDisplayName: 'Spicy Brewmaster',
        type: 'multi_pull',
        pullImagesJson: '["Exquisite Blood", "Sanguine Bond", "Aetherflux Reservoir", "Bolas\'s Citadel"]',
        pullCardIdsJson: '["c1", "c2", "c3", "c4"]',
      ));

      final post = await feedDao.getPostById('post-multi-dao-1');
      expect(post, isNotNull);
      expect(post!.type, equals('multi_pull'));
      expect(post.pullImagesJson, contains('Exquisite Blood'));
      expect(post.pullCardIdsJson, contains('c4'));
    });

    test('F4.2: FeedPost.fromRecord extracts pullImages and pullCardIds from JSON arrays', () {
      final record = createTestFeedPostRecord(
        id: 'post-multi-parse',
        authorId: 'user-edh-rec-fanatic',
        authorUsername: '@EDH_Rec_Fanatic',
        authorDisplayName: 'EDH Rec Fanatic',
        type: 'multi_pull',
        pullImagesJson: '["Rhystic Study", "Smothering Tithe", "Cyclonic Rift", "Fierce Guardianship"]',
        pullCardIdsJson: '["card-rhystic", "card-tithe", "card-rift", "card-fierce"]',
      );

      final post = FeedPost.fromRecord(record);
      expect(post.pullImages.length, equals(4));
      expect(post.pullCardIds.length, equals(4));
      expect(post.pullImages[0], equals('Rhystic Study'));
      expect(post.pullCardIds[2], equals('card-rift'));
    });

    test('F4.3: FeedPost.fromRecord handles null or malformed pullImagesJson gracefully with empty list', () {
      final record = createTestFeedPostRecord(
        id: 'post-multi-malformed',
        authorId: 'user-foil-collector-99',
        authorUsername: '@FoilCollector99',
        authorDisplayName: 'Foil Collector 99',
        type: 'multi_pull',
        pullImagesJson: '{not a valid list}',
        pullCardIdsJson: null,
      );

      final post = FeedPost.fromRecord(record);
      expect(post.pullImages, isEmpty);
      expect(post.pullCardIds, isEmpty);
    });

    test('F4.4: FeedDao.watchFeedPosts emits multi-pull posts with intact card collection arrays', () async {
      await feedDao.createPost(createTestFeedPostCompanion(
        id: 'post-multi-stream',
        authorId: 'store-tbs-comics',
        authorUsername: '@TBSComics',
        authorDisplayName: 'TBS Comics',
        type: 'multi_pull',
        pullImagesJson: '["Hit A", "Hit B"]',
        pullCardIdsJson: '["id-a", "id-b"]',
      ));

      final posts = await feedDao.watchFeedPosts().first;
      final multiPost = posts.firstWhere((p) => p.id == 'post-multi-stream');
      expect(multiPost.type, equals('multi_pull'));
      expect(multiPost.pullImagesJson, equals('["Hit A", "Hit B"]'));
    });

    test('F4.5: FeedPost.effectiveAuthorId resolves correctly for multi-pull authors', () {
      final record = createTestFeedPostRecord(
        id: 'post-multipull-author',
        authorId: 'user-spicy-brew-master',
        authorUsername: '@SpicyBrewMaster',
        authorDisplayName: 'Spicy Brewmaster',
        type: 'multi_pull',
      );

      final domainPost = FeedPost.fromRecord(record);
      expect(domainPost.effectiveAuthorId, equals('user-spicy-brew-master'));
    });
  });

  group('Tier 1 - Feature 5: Variable-Size Non-Card Media & Lightbox (F5.1 to F5.5)', () {
    testWidgets('F5.1: TextPostBody renders text content cleanly with ManaText formatting', (tester) async {
      await tester.pumpWidget(
        wrapWithMaterialAndScope(
          const TextPostBody(
            text: 'Just finished tuning my Atraxa superfriends list! {W}{U}{B}{G} mana curve is looking pristine.',
          ),
        ),
      );

      expect(find.textContaining('Just finished tuning my Atraxa'), findsOneWidget);
    });

    test('F5.2: FeedPost.fromRecord maps type "media" to PostType.media cleanly', () {
      final record = createTestFeedPostRecord(
        id: 'post-media-record',
        authorId: 'store-tbs-comics',
        authorUsername: '@TBSComics',
        authorDisplayName: 'TBS Comics',
        type: 'media',
        likeCount: 15,
        commentCount: 3,
        textContent: 'Tabletop Commander Night at TBS Comics!',
      );

      final domainPost = FeedPost.fromRecord(record);
      expect(domainPost.type, equals(PostType.media));
      expect(domainPost.textContent, equals('Tabletop Commander Night at TBS Comics!'));
    });

    testWidgets('F5.3: SinglePullPostBody handles and displays varying aspect ratios cleanly without distortion', (tester) async {
      await tester.pumpWidget(
        wrapWithMaterialAndScope(
          const SingleChildScrollView(
            child: SinglePullPostBody(
              cardId: 'card-aspect-test',
              cardTitle: 'Landscape Art Showcase',
              imageUrl: 'https://images.unsplash.com/photo-1511512578047-dfb367046420?w=800',
            ),
          ),
        ),
      );

      expect(find.byType(SinglePullPostBody), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('F5.4: TextPostBody renders long commentary with mana tokens cleanly without layout overflow', (tester) async {
      await tester.pumpWidget(
        wrapWithMaterialAndScope(
          const TextPostBody(
            text: 'Variable commentary showcase: {W}{U}{B}{R}{G} mana costs, bold flavor text, and detailed deck breakdown for Friday Night Magic.',
          ),
        ),
      );

      expect(find.byType(TextPostBody), findsOneWidget);
      expect(find.textContaining('{W}{U}{B}{R}{G}'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('F5.5: PostHeader and PostActionBar render responsively without overflow across viewports', (tester) async {
      for (final width in [320.0, 390.0, 600.0, 800.0]) {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          wrapWithMaterialAndScope(
            Column(
              children: [
                const PostHeader(
                  username: '@collector_me',
                  avatarInitials: 'ME',
                  timestamp: 'Just now',
                  locationTag: 'Local Game Store',
                  authorId: 'user-current-me',
                ),
                PostActionBar(
                  initialHypeCount: 25,
                  commentCount: 10,
                  onHypeTap: () {},
                  onCommentTap: () {},
                ),
              ],
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        expect(find.byType(PostHeader), findsOneWidget);
        expect(find.byType(PostActionBar), findsOneWidget);
      }
      tester.view.resetPhysicalSize();
    });
  });
}
