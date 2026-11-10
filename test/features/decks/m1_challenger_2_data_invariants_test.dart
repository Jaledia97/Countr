import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/cache/countr_cached_image.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/decks/data/daos/explore_deck_dao.dart';
import 'package:countr/features/decks/domain/models/explore_deck_models.dart';
import 'package:countr/features/decks/presentation/providers/explore_deck_providers.dart';
import 'package:countr/features/decks/presentation/widgets/explore/explore_deck_card.dart';
import 'package:countr/features/decks/presentation/widgets/explore/explore_decks_tab_view.dart';

class _AdversarialTestNavigatorObserver extends NavigatorObserver {
  final List<Route<dynamic>> pushedRoutes = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushedRoutes.add(route);
    super.didPush(route, previousRoute);
  }
}

ExploreDeck _createTestDeck({
  String id = 'deck_test_adv_1',
  String name = 'Test Deck',
  String format = 'Commander',
  String tcgDomain = 'mtg',
  String sourceType = 'community',
  String creatorName = '@TestCreator',
  String? description,
  String? commanderName = 'Atraxa, Praetors\' Voice',
  String? commanderImageUrl = 'https://cards.scryfall.io/normal/front/d/0/d0d077d8-344f-4e00-835c-ee26e956bf6e.jpg',
  String? commanderArtCrop = 'https://cards.scryfall.io/art_crop/front/d/0/d0d077d8-344f-4e00-835c-ee26e956bf6e.jpg',
  String colorIdentity = '["W","U","B","G"]',
  int cardCount = 100,
  double estimatedPrice = 249.99,
  int upvotes = 10,
  int downvotes = 2,
  int score = 8,
  String? featuredCategory,
  String? releaseCode,
  int? releaseYear,
  String? tags,
  DateTime? createdAt,
  DateTime? updatedAt,
  bool isDeleted = false,
}) {
  return ExploreDeck(
    id: id,
    name: name,
    format: format,
    tcgDomain: tcgDomain,
    sourceType: sourceType,
    creatorName: creatorName,
    description: description,
    commanderName: commanderName,
    commanderImageUrl: commanderImageUrl,
    commanderArtCrop: commanderArtCrop,
    colorIdentity: colorIdentity,
    cardCount: cardCount,
    estimatedPrice: estimatedPrice,
    upvotes: upvotes,
    downvotes: downvotes,
    score: score,
    featuredCategory: featuredCategory,
    releaseCode: releaseCode,
    releaseYear: releaseYear,
    tags: tags,
    createdAt: createdAt ?? DateTime.now(),
    updatedAt: updatedAt,
    isDeleted: isDeleted,
  );
}

ExploreDeckWithVote _createTestDeckWithVote({
  ExploreDeck? deck,
  int userVote = 0,
}) {
  return ExploreDeckWithVote(
    deck: deck ?? _createTestDeck(),
    userVote: userVote,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  late AppDatabase db;
  late VaultDao vaultDao;
  late ExploreDeckDao exploreDao;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    vaultDao = VaultDao(db);
    exploreDao = ExploreDeckDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildCardSubject(
    ExploreDeckWithVote deckWithVote, {
    VoidCallback? onTap,
    bool isCompact = false,
    double? width = 200,
    NavigatorObserver? navigatorObserver,
  }) {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        vaultDaoProvider.overrideWithValue(vaultDao),
        exploreDeckDaoProvider.overrideWithValue(exploreDao),
      ],
      child: MaterialApp(
        navigatorObservers:
            navigatorObserver != null ? [navigatorObserver] : const [],
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              child: ExploreDeckCard(
                deckWithVote: deckWithVote,
                onTap: onTap,
                isCompact: isCompact,
              ),
            ),
          ),
        ),
      ),
    );
  }

  group('Milestone 1 Challenger 2: Data Invariants & Interaction Adversarial Verification', () {
    // =========================================================================
    // GROUP 1: Extreme Deck Titles (100+ chars, empty string, UTF-8, emojis)
    // =========================================================================
    group('1. Extreme Deck Titles & String Encodings', () {
      testWidgets('1.1 Extreme length deck title (120+ chars) truncates with ellipsis without RenderFlex overflow',
          (tester) async {
        final longTitle = 'Extremely Long Deck Title That Exceeds Standard Boundaries '
            'And Continues On And On With Superfluous Text To Test Ellipsis And Prevent Layout Breaks In Grid View';
        final deck = _createTestDeck(id: 'deck_title_long', name: longTitle);
        final deckWithVote = _createTestDeckWithVote(deck: deck);

        // Constrained width typical of a 2-column mobile grid cell (174px)
        await tester.pumpWidget(buildCardSubject(deckWithVote, width: 174));
        await tester.pump();

        expect(tester.takeException(), isNull);
        final textFinder = find.text(longTitle);
        expect(textFinder, findsOneWidget);

        final textWidget = tester.widget<Text>(textFinder);
        expect(textWidget.maxLines, 1);
        expect(textWidget.overflow, TextOverflow.ellipsis);
      });

      testWidgets('1.2 Empty string deck title ("") renders gracefully without collapsing card geometry',
          (tester) async {
        final deck = _createTestDeck(id: 'deck_title_empty', name: '');
        final deckWithVote = _createTestDeckWithVote(deck: deck);

        await tester.pumpWidget(buildCardSubject(deckWithVote, width: 180));
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.byType(ExploreDeckCard), findsOneWidget);
        expect(find.byType(AspectRatio), findsOneWidget);
      });

      testWidgets('1.3 Non-Latin UTF-8 glyphs (Japanese, Cyrillic, Arabic) render without encoding crash',
          (tester) async {
        const unicodeTitle = '龍の嵐 // Таркирские Драконы // عاصفة التنانين الأسطورية';
        final deck = _createTestDeck(id: 'deck_title_utf8', name: unicodeTitle);
        final deckWithVote = _createTestDeckWithVote(deck: deck);

        await tester.pumpWidget(buildCardSubject(deckWithVote, width: 220));
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.text(unicodeTitle), findsOneWidget);
      });

      testWidgets('1.4 Multi-codepoint emoji strings render without text layout exception',
          (tester) async {
        const emojiTitle = '🔥💀💧🌳☀️ ✨🎉🃏 🚀💥🤖⚔️🛡️';
        final deck = _createTestDeck(id: 'deck_title_emoji', name: emojiTitle);
        final deckWithVote = _createTestDeckWithVote(deck: deck);

        await tester.pumpWidget(buildCardSubject(deckWithVote, width: 200));
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.text(emojiTitle), findsOneWidget);
      });
    });

    // =========================================================================
    // GROUP 2: Creator Names (Official WotC, Long Handles, Empty Strings)
    // =========================================================================
    group('2. Creator Names & Official Verification Badges', () {
      testWidgets('2.1 Official deck renders verified checkmark icon and cyan "Official WotC" badge',
          (tester) async {
        final deck = _createTestDeck(
          id: 'deck_official_wotc',
          sourceType: 'official',
          creatorName: 'Wizards of the Coast',
        );
        final deckWithVote = _createTestDeckWithVote(deck: deck);

        await tester.pumpWidget(buildCardSubject(deckWithVote));
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.byIcon(Icons.verified_rounded), findsOneWidget);
        expect(find.text('Official WotC'), findsOneWidget);
      });

      testWidgets('2.2 Extreme long community creator handle truncates cleanly with ellipsis',
          (tester) async {
        const longHandle = '@SuperDuperLongCommunityUsernameThatExceedsAllReasonableLimitsOfScreenRealEstate';
        final deck = _createTestDeck(
          id: 'deck_creator_long',
          sourceType: 'community',
          creatorName: longHandle,
        );
        final deckWithVote = _createTestDeckWithVote(deck: deck);

        await tester.pumpWidget(buildCardSubject(deckWithVote, width: 174));
        await tester.pump();

        expect(tester.takeException(), isNull);
        final handleFinder = find.text(longHandle);
        expect(handleFinder, findsOneWidget);
        final textWidget = tester.widget<Text>(handleFinder);
        expect(textWidget.maxLines, 1);
        expect(textWidget.overflow, TextOverflow.ellipsis);
      });

      testWidgets('2.3 Creator handle without leading "@" automatically prepends "@"',
          (tester) async {
        final deck = _createTestDeck(
          id: 'deck_creator_no_at',
          sourceType: 'community',
          creatorName: 'SpicyBrewMaster',
        );
        final deckWithVote = _createTestDeckWithVote(deck: deck);

        await tester.pumpWidget(buildCardSubject(deckWithVote));
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.text('@SpicyBrewMaster'), findsOneWidget);
      });

      testWidgets('2.4 Empty creator name ("") renders "@" without index or substring crash',
          (tester) async {
        final deck = _createTestDeck(
          id: 'deck_creator_empty',
          sourceType: 'community',
          creatorName: '',
        );
        final deckWithVote = _createTestDeckWithVote(deck: deck);

        await tester.pumpWidget(buildCardSubject(deckWithVote));
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.text('@'), findsOneWidget);
      });
    });

    // =========================================================================
    // GROUP 3: Commander Art/Image States & Fallback Chains
    // =========================================================================
    group('3. Commander Art/Image States & Fallbacks', () {
      testWidgets('3.1 Both commanderImageUrl and commanderArtCrop null -> displays fallback banner in 63/88 aspect ratio',
          (tester) async {
        final deck = _createTestDeck(
          id: 'deck_art_null',
          commanderImageUrl: null,
          commanderArtCrop: null,
        );
        final deckWithVote = _createTestDeckWithVote(deck: deck);

        await tester.pumpWidget(buildCardSubject(deckWithVote));
        await tester.pump();

        expect(tester.takeException(), isNull);
        // Fallback banner displays auto_awesome icon
        expect(find.byIcon(Icons.auto_awesome_rounded), findsOneWidget);
        expect(find.byType(CountrCachedImage), findsNothing);

        // AspectRatio container is strictly 63 / 88
        final aspectFinder = find.byType(AspectRatio);
        expect(aspectFinder, findsOneWidget);
        final aspectWidget = tester.widget<AspectRatio>(aspectFinder);
        expect(aspectWidget.aspectRatio, closeTo(63 / 88, 0.0001));
      });

      testWidgets('3.2 Both URLs empty strings ("") -> displays fallback banner without crash',
          (tester) async {
        final deck = _createTestDeck(
          id: 'deck_art_empty',
          commanderImageUrl: '',
          commanderArtCrop: '',
        );
        final deckWithVote = _createTestDeckWithVote(deck: deck);

        await tester.pumpWidget(buildCardSubject(deckWithVote));
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.byIcon(Icons.auto_awesome_rounded), findsOneWidget);
        expect(find.byType(CountrCachedImage), findsNothing);
      });

      testWidgets('3.3 art_series in commanderImageUrl triggers Scryfall named fallback rewriting to version: normal',
          (tester) async {
        final deck = _createTestDeck(
          id: 'deck_art_series_full',
          commanderName: 'Atraxa, Praetors\' Voice',
          commanderImageUrl: 'https://cards.scryfall.io/art_series/front/d/0/d0d077d8-344f.jpg',
          commanderArtCrop: null,
        );
        final deckWithVote = _createTestDeckWithVote(deck: deck);

        await tester.pumpWidget(buildCardSubject(deckWithVote));
        await tester.pump();

        expect(tester.takeException(), isNull);
        final cachedImageFinder = find.byType(CountrCachedImage);
        expect(cachedImageFinder, findsOneWidget);
        final imageWidget = tester.widget<CountrCachedImage>(cachedImageFinder);
        // Full card image source must resolve to Scryfall normal version
        expect(imageWidget.imageUrl, contains('version=normal'));
        expect(imageWidget.cacheKey, contains('fallback'));
      });

      testWidgets('3.4 art_series in commanderArtCrop (with null commanderImageUrl) rewrites to version: art_crop',
          (tester) async {
        final deck = _createTestDeck(
          id: 'deck_art_series_crop',
          commanderName: 'Atraxa, Praetors\' Voice',
          commanderImageUrl: null,
          commanderArtCrop: 'https://cards.scryfall.io/art_series/front/d/0/d0d077d8-344f.jpg',
        );
        final deckWithVote = _createTestDeckWithVote(deck: deck);

        await tester.pumpWidget(buildCardSubject(deckWithVote));
        await tester.pump();

        expect(tester.takeException(), isNull);
        final cachedImageFinder = find.byType(CountrCachedImage);
        expect(cachedImageFinder, findsOneWidget);
        final imageWidget = tester.widget<CountrCachedImage>(cachedImageFinder);
        // Art crop source must resolve to Scryfall art_crop version
        expect(imageWidget.imageUrl, contains('version=art_crop'));
      });

      testWidgets('3.5 Broken URL strings mount cleanly without throwing uncaught exceptions',
          (tester) async {
        final deck = _createTestDeck(
          id: 'deck_art_broken',
          commanderImageUrl: 'ht!tp://broken-domain.invalid/nonexistent_image_404.jpg',
        );
        final deckWithVote = _createTestDeckWithVote(deck: deck);

        await tester.pumpWidget(buildCardSubject(deckWithVote));
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.byType(CountrCachedImage), findsOneWidget);
      });

      testWidgets('3.6 Various file extensions (.png, .jpg, .svg, .webp) mount into image container cleanly',
          (tester) async {
        for (final ext in ['png', 'jpg', 'svg', 'webp']) {
          final deck = _createTestDeck(
            id: 'deck_art_ext_$ext',
            commanderImageUrl: 'https://cards.scryfall.io/normal/front/0/0/00000000.$ext',
          );
          final deckWithVote = _createTestDeckWithVote(deck: deck);

          await tester.pumpWidget(buildCardSubject(deckWithVote));
          await tester.pump();

          expect(tester.takeException(), isNull);
          expect(find.byType(CountrCachedImage), findsOneWidget);
        }
      });
    });

    // =========================================================================
    // GROUP 4: Voting Cluster Interaction & Hit-Testing
    // =========================================================================
    group('4. Voting Cluster Hit-Testing & Score Transitions', () {
      testWidgets('4.1 Voting buttons are vertically disjoint from upper card art container (no tap interception)',
          (tester) async {
        final deck = _createTestDeck(id: 'deck_hit_test_1');
        final deckWithVote = _createTestDeckWithVote(deck: deck);

        await tester.pumpWidget(buildCardSubject(deckWithVote, width: 200));
        await tester.pump();

        final artBannerRect = tester.getRect(find.byType(AspectRatio).first);
        final upvoteRect = tester.getRect(find.byKey(Key('explore_upvote_${deck.id}')));
        final downvoteRect = tester.getRect(find.byKey(Key('explore_downvote_${deck.id}')));

        // Voting cluster must sit strictly below the 63/88 art banner
        expect(upvoteRect.top, greaterThanOrEqualTo(artBannerRect.bottom));
        expect(downvoteRect.top, greaterThanOrEqualTo(artBannerRect.bottom));

        // Both voting buttons must have valid positive hit areas
        expect(upvoteRect.width, greaterThan(15));
        expect(upvoteRect.height, greaterThan(15));
        expect(downvoteRect.width, greaterThan(15));
        expect(downvoteRect.height, greaterThan(15));
      });

      testWidgets('4.2 Rapid alternating vote sequence updates SQLite and score: neutral (0) -> up (+1) -> neutral (0) -> down (-1) -> up (+1)',
          (tester) async {
        final now = DateTime.now();
        const deckId = 'deck_vote_cycle_1';

        // Seed deck in SQLite
        await db.into(db.exploreDecks).insert(
          ExploreDecksCompanion.insert(
            id: deckId,
            name: 'Voting Stress Deck',
            format: 'Commander',
            tcgDomain: const Value('mtg'),
            sourceType: const Value('community'),
            creatorName: const Value('@VoteTester'),
            commanderName: const Value('Atraxa'),
            colorIdentity: const Value('["W","U","B","G"]'),
            cardCount: const Value(100),
            estimatedPrice: const Value(150.0),
            upvotes: const Value(10),
            downvotes: const Value(2),
            score: const Value(8),
            createdAt: now,
            isDeleted: const Value(false),
          ),
        );

        // Verify initial state
        var deckRow = await (db.select(db.exploreDecks)..where((t) => t.id.equals(deckId))).getSingle();
        expect(deckRow.score, 8);
        expect(deckRow.upvotes, 10);
        expect(deckRow.downvotes, 2);

        // Step 1: Upvote (neutral 0 -> 1)
        var voteRes = await exploreDao.castVote(deckId: deckId, targetVote: 1);
        expect(voteRes.newVote, 1);
        expect(voteRes.newScore, 9);
        expect(voteRes.upvotes, 11);
        expect(voteRes.downvotes, 2);

        // Step 2: Toggle upvote (1 -> 0)
        voteRes = await exploreDao.castVote(deckId: deckId, targetVote: 1);
        expect(voteRes.newVote, 0);
        expect(voteRes.newScore, 8);
        expect(voteRes.upvotes, 10);
        expect(voteRes.downvotes, 2);

        // Step 3: Downvote (0 -> -1)
        voteRes = await exploreDao.castVote(deckId: deckId, targetVote: -1);
        expect(voteRes.newVote, -1);
        expect(voteRes.newScore, 7);
        expect(voteRes.upvotes, 10);
        expect(voteRes.downvotes, 3);

        // Step 4: Direct switch to upvote (-1 -> 1)
        voteRes = await exploreDao.castVote(deckId: deckId, targetVote: 1);
        expect(voteRes.newVote, 1);
        expect(voteRes.newScore, 9);
        expect(voteRes.upvotes, 11);
        expect(voteRes.downvotes, 2);

        // Verify final persistent SQLite state
        deckRow = await (db.select(db.exploreDecks)..where((t) => t.id.equals(deckId))).getSingle();
        expect(deckRow.score, 9);
        expect(deckRow.upvotes, 11);
        expect(deckRow.downvotes, 2);

        final voteRecord = await (db.select(db.exploreDeckVotes)
              ..where((t) => t.exploreDeckId.equals(deckId) & t.userId.equals('local_user')))
            .getSingle();
        expect(voteRecord.vote, 1);
      });

      testWidgets('4.3 Visual colors adapt dynamically to vote state (-1, 0, 1)',
          (tester) async {
        const deckId = 'deck_visual_state_1';
        final deck = _createTestDeck(id: deckId, score: 5);

        // 1. Upvoted State (userVote = 1) -> Emerald
        await tester.pumpWidget(buildCardSubject(
          _createTestDeckWithVote(deck: deck, userVote: 1),
        ));
        await tester.pump();

        var scoreText = tester.widget<Text>(find.byKey(const Key('explore_score_$deckId')));
        expect(scoreText.style?.color, AppColors.accentEmerald);
        var upIcon = tester.widget<Icon>(find.descendant(
          of: find.byKey(const Key('explore_upvote_$deckId')),
          matching: find.byType(Icon),
        ));
        expect(upIcon.color, AppColors.accentEmerald);

        // 2. Downvoted State (userVote = -1) -> Amber
        await tester.pumpWidget(buildCardSubject(
          _createTestDeckWithVote(deck: deck, userVote: -1),
        ));
        await tester.pump();

        scoreText = tester.widget<Text>(find.byKey(const Key('explore_score_$deckId')));
        expect(scoreText.style?.color, AppColors.accentAmber);
        var downIcon = tester.widget<Icon>(find.descendant(
          of: find.byKey(const Key('explore_downvote_$deckId')),
          matching: find.byType(Icon),
        ));
        expect(downIcon.color, AppColors.accentAmber);

        // 3. Neutral State (userVote = 0) -> Secondary / Muted
        await tester.pumpWidget(buildCardSubject(
          _createTestDeckWithVote(deck: deck, userVote: 0),
        ));
        await tester.pump();

        scoreText = tester.widget<Text>(find.byKey(const Key('explore_score_$deckId')));
        expect(scoreText.style?.color, AppColors.textSecondary);
        upIcon = tester.widget<Icon>(find.descendant(
          of: find.byKey(const Key('explore_upvote_$deckId')),
          matching: find.byType(Icon),
        ));
        expect(upIcon.color, AppColors.textMuted);
      });
    });

    // =========================================================================
    // GROUP 5: Tap Navigation vs. Voting Gesture Isolation
    // =========================================================================
    group('5. Tap Navigation vs. Voting Isolation', () {
      testWidgets('5.1 Tapping card body triggers custom onTap callback',
          (tester) async {
        int cardTapCount = 0;
        final deck = _createTestDeck(id: 'deck_tap_card_1');
        final deckWithVote = _createTestDeckWithVote(deck: deck);

        await tester.pumpWidget(buildCardSubject(
          deckWithVote,
          onTap: () => cardTapCount++,
        ));
        await tester.pumpAndSettle();

        // Tap the card boundary
        await tester.tap(find.byKey(Key('explore_card_${deck.id}')));
        await tester.pumpAndSettle();

        expect(cardTapCount, 1);
      });

      testWidgets('5.2 Tapping upvote button does NOT trigger card onTap navigation callback',
          (tester) async {
        int cardTapCount = 0;
        final deck = _createTestDeck(id: 'deck_tap_upvote_1');
        await db.into(db.exploreDecks).insert(
          ExploreDecksCompanion.insert(
            id: deck.id,
            name: deck.name,
            format: deck.format,
            tcgDomain: Value(deck.tcgDomain),
            sourceType: Value(deck.sourceType),
            creatorName: Value(deck.creatorName),
            createdAt: deck.createdAt,
            isDeleted: const Value(false),
          ),
        );
        final deckWithVote = _createTestDeckWithVote(deck: deck);

        await tester.pumpWidget(buildCardSubject(
          deckWithVote,
          onTap: () => cardTapCount++,
        ));
        await tester.pump();

        // Tap the upvote button directly
        await tester.tap(find.byKey(Key('explore_upvote_${deck.id}')));
        await tester.pumpAndSettle();

        // Card tap callback MUST NOT fire
        expect(cardTapCount, 0);
      });

      testWidgets('5.3 Tapping downvote button does NOT trigger card onTap navigation callback',
          (tester) async {
        int cardTapCount = 0;
        final deck = _createTestDeck(id: 'deck_tap_downvote_1');
        await db.into(db.exploreDecks).insert(
          ExploreDecksCompanion.insert(
            id: deck.id,
            name: deck.name,
            format: deck.format,
            tcgDomain: Value(deck.tcgDomain),
            sourceType: Value(deck.sourceType),
            creatorName: Value(deck.creatorName),
            createdAt: deck.createdAt,
            isDeleted: const Value(false),
          ),
        );
        final deckWithVote = _createTestDeckWithVote(deck: deck);

        await tester.pumpWidget(buildCardSubject(
          deckWithVote,
          onTap: () => cardTapCount++,
        ));
        await tester.pump();

        // Tap the downvote button directly
        await tester.tap(find.byKey(Key('explore_downvote_${deck.id}')));
        await tester.pumpAndSettle();

        // Card tap callback MUST NOT fire
        expect(cardTapCount, 0);
      });

      testWidgets('5.4 Default card tap pushes ReadOnlyDeckScreen while voting taps do not push routes',
          (tester) async {
        final navObserver = _AdversarialTestNavigatorObserver();
        final deck = _createTestDeck(id: 'deck_nav_push_1');
        await db.into(db.exploreDecks).insert(
          ExploreDecksCompanion.insert(
            id: deck.id,
            name: deck.name,
            format: deck.format,
            tcgDomain: Value(deck.tcgDomain),
            sourceType: Value(deck.sourceType),
            creatorName: Value(deck.creatorName),
            createdAt: deck.createdAt,
            isDeleted: const Value(false),
          ),
        );
        final deckWithVote = _createTestDeckWithVote(deck: deck);

        await tester.pumpWidget(buildCardSubject(
          deckWithVote,
          onTap: null, // use default navigation
          navigatorObserver: navObserver,
        ));
        await tester.pump();

        // Initial pushed routes: only initial '/' route
        final initialRoutes = navObserver.pushedRoutes.length;

        // 1. Tap Upvote
        await tester.tap(find.byKey(Key('explore_upvote_${deck.id}')));
        await tester.pumpAndSettle();
        expect(navObserver.pushedRoutes.length, initialRoutes);

        // 2. Tap Downvote
        await tester.tap(find.byKey(Key('explore_downvote_${deck.id}')));
        await tester.pumpAndSettle();
        expect(navObserver.pushedRoutes.length, initialRoutes);

        // 3. Tap Card -> pushes ReadOnlyDeckScreen
        await tester.tap(find.byKey(Key('explore_card_${deck.id}')));
        await tester.pumpAndSettle();

        expect(navObserver.pushedRoutes.length, initialRoutes + 1);
      });
    });

    // =========================================================================
    // GROUP 6: "All Explore Decks" Section Header Invariants
    // =========================================================================
    group('6. Section Header Invariants with Deck Counts (0, 1, 100)', () {
      Widget buildHeaderStandalone(int deckCount) {
        return MaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    key: const Key('all_explore_decks_header'),
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: AppColors.accentCyan.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.accentCyan.withValues(alpha: 0.3),
                            ),
                          ),
                          child: const Icon(
                            Icons.grid_view_rounded,
                            size: 16,
                            color: AppColors.accentCyan,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'All Explore Decks',
                            key: const Key('explore_all_decks_header'),
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (deckCount > 0)
                          Text(
                            '$deckCount decks',
                            key: const Key('explore_deck_count_badge'),
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }

      testWidgets('6.1 Header with deckCount = 0 renders "All Explore Decks" title and omits count badge',
          (tester) async {
        await tester.pumpWidget(buildHeaderStandalone(0));
        await tester.pump();

        expect(find.byKey(const Key('all_explore_decks_header')), findsOneWidget);
        expect(find.text('All Explore Decks'), findsOneWidget);
        expect(find.byIcon(Icons.grid_view_rounded), findsOneWidget);
        // Count badge is omitted when deckCount is 0
        expect(find.byKey(const Key('explore_deck_count_badge')), findsNothing);
      });

      testWidgets('6.2 Header with deckCount = 1 renders "All Explore Decks" title and "1 decks" count badge',
          (tester) async {
        await tester.pumpWidget(buildHeaderStandalone(1));
        await tester.pump();

        expect(find.byKey(const Key('all_explore_decks_header')), findsOneWidget);
        expect(find.text('All Explore Decks'), findsOneWidget);
        expect(find.byKey(const Key('explore_deck_count_badge')), findsOneWidget);
        expect(find.text('1 decks'), findsOneWidget);
      });

      testWidgets('6.3 Header with deckCount = 100 renders "All Explore Decks" title and "100 decks" count badge',
          (tester) async {
        await tester.pumpWidget(buildHeaderStandalone(100));
        await tester.pump();

        expect(find.byKey(const Key('all_explore_decks_header')), findsOneWidget);
        expect(find.text('All Explore Decks'), findsOneWidget);
        expect(find.byKey(const Key('explore_deck_count_badge')), findsOneWidget);
        expect(find.text('100 decks'), findsOneWidget);
      });

      testWidgets('6.4 Header inside ExploreDecksTabView displays correctly when decks are populated',
          (tester) async {
        tester.view.physicalSize = const Size(800, 3000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final now = DateTime.now();
        // Seed 3 explore decks
        for (int i = 1; i <= 3; i++) {
          await db.into(db.exploreDecks).insert(
            ExploreDecksCompanion.insert(
              id: 'deck_tab_header_$i',
              name: 'Header Test Deck $i',
              format: 'Commander',
              tcgDomain: const Value('mtg'),
              sourceType: const Value('official'),
              creatorName: const Value('Official WotC'),
              commanderName: const Value('Urza'),
              colorIdentity: const Value('["U"]'),
              cardCount: const Value(100),
              estimatedPrice: const Value(99.0),
              upvotes: const Value(5),
              downvotes: const Value(1),
              score: const Value(4),
              createdAt: now,
              isDeleted: const Value(false),
            ),
          );
        }

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              vaultDaoProvider.overrideWithValue(vaultDao),
              exploreDeckDaoProvider.overrideWithValue(exploreDao),
              activeExploreCategoryProvider.overrideWith((ref) => ExploreCategory.all),
              exploreSearchQueryProvider.overrideWith((ref) => ''),
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: ExploreDecksTabView(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('all_explore_decks_header')), findsOneWidget);
        expect(find.byKey(const Key('explore_all_decks_header')), findsOneWidget);
        expect(find.text('All Explore Decks'), findsOneWidget);
        expect(find.text('3 decks'), findsOneWidget);
      });
    });
  });
}
