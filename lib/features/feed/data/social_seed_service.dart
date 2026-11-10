import 'dart:convert';
import 'package:drift/drift.dart';
import '../../../../core/database/app_database.dart';

/// Seeds rich unified social mock data across feed posts, comments, likes,
/// notifications, friend requests, conversations, and trade proposals.
class SocialSeedService {
  final AppDatabase db;

  SocialSeedService(this.db);

  /// Seeds all social data if the tables are empty or forced.
  Future<void> seedSocialData({bool force = false}) async {
    final existingPosts = await (db.select(db.feedPosts)..limit(1)).get();
    final existingNotifs = await (db.select(db.notifications)..limit(1)).get();
    final existingMsgs = await (db.select(db.messages)..limit(1)).get();
    final hasComboPost = await (db.select(db.feedPosts)..where((t) => t.id.equals('post-edh-combo-showcase'))).getSingleOrNull();

    if (existingPosts.isNotEmpty && existingNotifs.isNotEmpty && existingMsgs.isNotEmpty && hasComboPost != null && !force) {
      return;
    }

    final now = DateTime.now();

    // 1. Seed System Binders & Cards for Mock Personas
    await _seedPersonaBindersAndCards(now);

    // 2. Seed Feed Posts
    if (existingPosts.isEmpty || hasComboPost == null || force) {
      await _seedFeedPosts(now);
      await _seedCommentsAndLikes(now);
    }

    // 4. Seed Friendships
    await _seedFriendships(now);

    // 5. Seed Notifications
    if (existingNotifs.isEmpty || force) {
      await _seedNotifications(now);
    }

    // 6. Seed Conversations & Messages with Trade Proposal
    if (existingMsgs.isEmpty || force) {
      await _seedMessagesAndTradeProposals(now);
    }
  }

  Future<void> _seedPersonaBindersAndCards(DateTime now) async {
    final binders = [
      VaultBindersCompanion.insert(
        id: 'system_trade_block_user-spicy-brew-master',
        name: 'Trade Block',
        collectionType: 'mtg',
        isSystemBinder: const Value(true),
        systemBinderType: const Value('trade_block'),
        userId: const Value('user-spicy-brew-master'),
        createdAt: now.subtract(const Duration(days: 10)),
      ),
      VaultBindersCompanion.insert(
        id: 'system_trade_block_user-foil-collector-99',
        name: 'Trade Block',
        collectionType: 'mtg',
        isSystemBinder: const Value(true),
        systemBinderType: const Value('trade_block'),
        userId: const Value('user-foil-collector-99'),
        createdAt: now.subtract(const Duration(days: 15)),
      ),
      VaultBindersCompanion.insert(
        id: 'system_trade_block_user-edh-rec-fanatic',
        name: 'Trade Block',
        collectionType: 'mtg',
        isSystemBinder: const Value(true),
        systemBinderType: const Value('trade_block'),
        userId: const Value('user-edh-rec-fanatic'),
        createdAt: now.subtract(const Duration(days: 20)),
      ),
      VaultBindersCompanion.insert(
        id: 'system_store_inventory_store-tbs-comics',
        name: 'Store Inventory',
        collectionType: 'mtg',
        isSystemBinder: const Value(true),
        systemBinderType: const Value('store_inventory'),
        userId: const Value('store-tbs-comics'),
        createdAt: now.subtract(const Duration(days: 30)),
      ),
      VaultBindersCompanion.insert(
        id: 'system_trade_block_user-current-me',
        name: 'Trade Block',
        collectionType: 'mtg',
        isSystemBinder: const Value(true),
        systemBinderType: const Value('trade_block'),
        userId: const Value('user-current-me'),
        createdAt: now.subtract(const Duration(days: 5)),
      ),
    ];

    for (final binder in binders) {
      await db.into(db.vaultBinders).insert(binder, mode: InsertMode.insertOrReplace);
    }

    // Persona cards
    final cards = [
      VaultItemsCompanion.insert(
        id: 'item-card-dockside-extortionist',
        name: 'Dockside Extortionist',
        setOrSeries: 'Double Masters 2022',
        collectionType: 'mtg',
        quantity: const Value(1),
        acquiredDate: now.subtract(const Duration(days: 3)),
        acquiredPrice: 78.00,
        currentMarketPrice: 78.00,
        lastPriceUpdate: now,
        condition: 'Near Mint',
        primaryBinderId: const Value('system_trade_block_user-spicy-brew-master'),
        userId: const Value('user-spicy-brew-master'),
        imageUrl: 'https://cards.scryfall.io/normal/front/9/e/9e2e3efb-75cb-430f-b9f4-cb58f3aeb91b.jpg',
        dynamicData: jsonEncode({
          'scryfall_id': '9e2e3efb-75cb-430f-b9f4-cb58f3aeb91b',
          'oracle_text': 'When Dockside Extortionist enters the battlefield, create X Treasure tokens, where X is the number of artifacts and enchantments your opponents control.',
          'mana_cost': '{1}{R}',
          'type_line': 'Creature — Goblin Pirate',
          'power': '1',
          'toughness': '2',
          'rarity': 'mythic',
          'set_code': '2x2',
          'prices': {'usd': '78.00', 'usd_foil': '85.00'},
        }),
      ),
      VaultItemsCompanion.insert(
        id: 'item-card-ragavan',
        name: 'Ragavan, Nimble Pilferer',
        setOrSeries: 'Modern Horizons 2',
        collectionType: 'mtg',
        quantity: const Value(1),
        acquiredDate: now.subtract(const Duration(days: 5)),
        acquiredPrice: 48.00,
        currentMarketPrice: 48.00,
        lastPriceUpdate: now,
        condition: 'Near Mint',
        primaryBinderId: const Value('system_trade_block_user-spicy-brew-master'),
        userId: const Value('user-spicy-brew-master'),
        imageUrl: 'https://cards.scryfall.io/normal/front/a/9/a9738cda-adb1-47fb-9f4c-ecd930228c4d.jpg',
        dynamicData: jsonEncode({
          'scryfall_id': 'a9738cda-adb1-47fb-9f4c-ecd930228c4d',
          'mana_cost': '{R}',
          'type_line': 'Legendary Creature — Monkey Pirate',
          'power': '2',
          'toughness': '1',
          'rarity': 'mythic',
          'set_code': 'mh2',
          'prices': {'usd': '48.00'},
        }),
      ),
      VaultItemsCompanion.insert(
        id: 'item-card-force-of-negation',
        name: 'Force of Negation',
        setOrSeries: 'Modern Horizons',
        collectionType: 'mtg',
        quantity: const Value(1),
        acquiredDate: now.subtract(const Duration(days: 7)),
        acquiredPrice: 42.00,
        currentMarketPrice: 42.00,
        lastPriceUpdate: now,
        condition: 'Near Mint',
        primaryBinderId: const Value('system_trade_block_user-edh-rec-fanatic'),
        userId: const Value('user-edh-rec-fanatic'),
        imageUrl: 'https://cards.scryfall.io/normal/front/e/8/e80e3868-2331-4032-867cbcb378f956d1.jpg',
        dynamicData: jsonEncode({
          'scryfall_id': 'e80e3868-2331-4032-867cbcb378f956d1',
          'mana_cost': '{1}{U}{U}',
          'type_line': 'Instant',
          'rarity': 'rare',
          'set_code': 'mh1',
          'prices': {'usd': '42.00'},
        }),
      ),
      VaultItemsCompanion.insert(
        id: 'item-card-isochron-scepter',
        name: 'Isochron Scepter',
        setOrSeries: 'Double Masters',
        collectionType: 'mtg',
        quantity: const Value(1),
        acquiredDate: now.subtract(const Duration(days: 8)),
        acquiredPrice: 24.99,
        currentMarketPrice: 24.99,
        lastPriceUpdate: now,
        condition: 'Near Mint',
        primaryBinderId: const Value('system_trade_block_user-edh-rec-fanatic'),
        userId: const Value('user-edh-rec-fanatic'),
        imageUrl: 'https://cards.scryfall.io/normal/front/2/a/2aa24fe0-e275-4307-b26c-2a656068a451.jpg',
        dynamicData: jsonEncode({
          'scryfall_id': '2aa24fe0-e275-4307-b26c-2a656068a451',
          'mana_cost': '{2}',
          'type_line': 'Artifact',
          'rarity': 'rare',
          'set_code': '2xm',
          'prices': {'usd': '24.99'},
        }),
      ),
      VaultItemsCompanion.insert(
        id: 'item-card-mox-diamond',
        name: 'Mox Diamond',
        setOrSeries: 'Stronghold',
        collectionType: 'mtg',
        quantity: const Value(1),
        acquiredDate: now.subtract(const Duration(days: 12)),
        acquiredPrice: 650.00,
        currentMarketPrice: 650.00,
        lastPriceUpdate: now,
        condition: 'Lightly Played',
        primaryBinderId: const Value('system_trade_block_user-foil-collector-99'),
        userId: const Value('user-foil-collector-99'),
        imageUrl: 'https://cards.scryfall.io/normal/front/b/f/bf9fecfd-d122-422f-bd0a-5bf69b434dec.jpg',
        dynamicData: jsonEncode({
          'scryfall_id': 'bf9fecfd-d122-422f-bd0a-5bf69b434dec',
          'mana_cost': '{0}',
          'type_line': 'Artifact',
          'rarity': 'rare',
          'set_code': 'sth',
          'prices': {'usd': '650.00'},
        }),
      ),
      VaultItemsCompanion.insert(
        id: 'item-card-urza-high-artificer',
        name: 'Urza, Lord High Artificer',
        setOrSeries: 'Modern Horizons',
        collectionType: 'mtg',
        quantity: const Value(1),
        acquiredDate: now.subtract(const Duration(days: 9)),
        acquiredPrice: 55.00,
        currentMarketPrice: 55.00,
        lastPriceUpdate: now,
        condition: 'Near Mint',
        primaryBinderId: const Value('system_trade_block_user-edh-rec-fanatic'),
        userId: const Value('user-edh-rec-fanatic'),
        imageUrl: 'https://cards.scryfall.io/normal/front/9/e/9e7fb3c0-5159-4d1f-8490-ce4c9a60f567.jpg',
        dynamicData: jsonEncode({
          'scryfall_id': '9e7fb3c0-5159-4d1f-8490-ce4c9a60f567',
          'mana_cost': '{2}{U}{U}',
          'type_line': 'Legendary Creature — Human Artificer',
          'rarity': 'mythic',
          'set_code': 'mh1',
          'prices': {'usd': '55.00'},
        }),
      ),
      VaultItemsCompanion.insert(
        id: 'item-card-dramatic-reversal',
        name: 'Dramatic Reversal',
        setOrSeries: 'Kaladesh',
        collectionType: 'mtg',
        quantity: const Value(1),
        acquiredDate: now.subtract(const Duration(days: 9)),
        acquiredPrice: 3.50,
        currentMarketPrice: 3.50,
        lastPriceUpdate: now,
        condition: 'Near Mint',
        primaryBinderId: const Value('system_trade_block_user-edh-rec-fanatic'),
        userId: const Value('user-edh-rec-fanatic'),
        imageUrl: 'https://cards.scryfall.io/normal/front/d/c/dcb59045-2743-48ae-8063-727e551b1c41.jpg',
        dynamicData: jsonEncode({
          'scryfall_id': 'dcb59045-2743-48ae-8063-727e551b1c41',
          'mana_cost': '{1}{U}',
          'type_line': 'Instant',
          'rarity': 'common',
          'set_code': 'kld',
          'prices': {'usd': '3.50'},
        }),
      ),
    ];

    for (final card in cards) {
      await db.into(db.vaultItems).insert(card, mode: InsertMode.insertOrReplace);
    }
  }

  Future<void> _seedFeedPosts(DateTime now) async {
    final posts = [
      FeedPostsCompanion.insert(
        id: 'post-spicy-pull',
        authorId: 'user-spicy-brew-master',
        authorUsername: '@SpicyBrewMaster',
        authorDisplayName: 'Spicy Brew Master',
        authorAvatarUrl: const Value('https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400&auto=format&fit=crop&q=80'),
        type: 'single_pull',
        textContent: const Value('Just pulled this Foil Extended Art beauty at TBS Comics FNM! Trading for modern staples.'),
        locationTag: const Value('TBS Comics - Fort Walton Beach'),
        cardId: const Value('item-card-dockside-extortionist'),
        cardTitle: const Value('Dockside Extortionist'),
        cardSubtitle: const Value('Double Masters 2022 • Borderless Foil'),
        cardRarity: const Value('Mythic Rare'),
        estimatedValue: const Value(78.00),
        cardImageUrl: const Value('https://cards.scryfall.io/normal/front/9/e/9e2e3efb-75cb-430f-b9f4-cb58f3aeb91b.jpg'),
        likeCount: const Value(14),
        commentCount: const Value(3),
        createdAt: Value(now.subtract(const Duration(hours: 2))),
        updatedAt: Value(now.subtract(const Duration(hours: 2))),
      ),
      FeedPostsCompanion.insert(
        id: 'post-foil-showcase',
        authorId: 'user-foil-collector-99',
        authorUsername: '@FoilCollector99',
        authorDisplayName: 'Foil Collector 99',
        authorAvatarUrl: const Value('https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=400&auto=format&fit=crop&q=80'),
        type: 'single_pull',
        textContent: const Value('Grail mail day! Acquired Serialized #007/100. Absolutely pristine foil finish.'),
        locationTag: const Value('Fort Walton Beach, FL'),
        cardId: const Value('item-mtg-one-ring'),
        cardTitle: const Value('The One Ring (Serialized #007/100)'),
        cardSubtitle: const Value('The Lord of the Rings: Tales of Middle-earth'),
        cardRarity: const Value('Mythic Rare'),
        estimatedValue: const Value(3200.00),
        cardImageUrl: const Value('https://cards.scryfall.io/large/front/d/5/d5806e68-1054-458e-866d-1f2470f682b2.jpg?1790212038'),
        pullCardIdsJson: Value(jsonEncode(['item-mtg-one-ring', 'item-mtg-sol-ring'])),
        likeCount: const Value(42),
        commentCount: const Value(8),
        createdAt: Value(now.subtract(const Duration(hours: 5))),
        updatedAt: Value(now.subtract(const Duration(hours: 5))),
      ),
      FeedPostsCompanion.insert(
        id: 'post-edh-combo-showcase',
        authorId: 'user-edh-rec-fanatic',
        authorUsername: '@EDH_Rec_Fanatic',
        authorDisplayName: 'EDH Rec Fanatic',
        authorAvatarUrl: const Value('https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=400&auto=format&fit=crop&q=80'),
        type: 'multi_pull',
        textContent: const Value('Assembling the engine: Urza + Isochron Scepter imprinting Dramatic Reversal for infinite mana and deck draw! Tap any card for full details.'),
        locationTag: const Value('EDH Rec Lab'),
        pullImagesJson: Value(jsonEncode([
          'https://cards.scryfall.io/normal/front/9/e/9e7fb3c0-5159-4d1f-8490-ce4c9a60f567.jpg',
          'https://cards.scryfall.io/normal/front/2/a/2aa24fe0-e275-4307-b26c-2a656068a451.jpg',
          'https://cards.scryfall.io/normal/front/d/c/dcb59045-2743-48ae-8063-727e551b1c41.jpg',
        ])),
        pullCardIdsJson: Value(jsonEncode([
          'item-card-urza-high-artificer',
          'item-card-isochron-scepter',
          'item-card-dramatic-reversal',
        ])),
        likeCount: const Value(38),
        commentCount: const Value(4),
        createdAt: Value(now.subtract(const Duration(hours: 6))),
        updatedAt: Value(now.subtract(const Duration(hours: 6))),
      ),
      FeedPostsCompanion.insert(
        id: 'post-edh-deck-share',
        authorId: 'user-edh-rec-fanatic',
        authorUsername: '@EDH_Rec_Fanatic',
        authorDisplayName: 'EDH Rec Fanatic',
        authorAvatarUrl: const Value('https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=400&auto=format&fit=crop&q=80'),
        type: 'text',
        textContent: const Value('Updated my Urza High-Power combo list! Swapped in {2} Isochron Scepter and {1}{U}{U} Force of Negation. Ready for Friday night pods.'),
        locationTag: const Value('EDH Rec Lab'),
        cardTitle: const Value('Urza, Lord High Artificer'),
        likeCount: const Value(29),
        commentCount: const Value(5),
        createdAt: Value(now.subtract(const Duration(hours: 8))),
        updatedAt: Value(now.subtract(const Duration(hours: 8))),
      ),
      FeedPostsCompanion.insert(
        id: 'post-media-16-9-pod',
        authorId: 'user-edh-rec-fanatic',
        authorUsername: '@EDH_Rec_Fanatic',
        authorDisplayName: 'EDH Rec Fanatic',
        authorAvatarUrl: const Value('https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=400&auto=format&fit=crop&q=80'),
        type: 'media',
        cardImageUrl: const Value('https://images.unsplash.com/photo-1610890716171-6b1bb98ffd09?w=1200&auto=format&fit=crop&q=80'),
        cardSubtitle: const Value('16:9'),
        textContent: const Value('Turn 8 four-player showdown at the store! The stack had 6 spells on it before the board wiped.'),
        locationTag: const Value('TBS Comics - Fort Walton Beach'),
        likeCount: const Value(27),
        commentCount: const Value(2),
        createdAt: Value(now.subtract(const Duration(hours: 10))),
        updatedAt: Value(now.subtract(const Duration(hours: 10))),
      ),
      FeedPostsCompanion.insert(
        id: 'post-tbs-fnm-event',
        authorId: 'store-tbs-comics',
        authorUsername: '@TBSComics',
        authorDisplayName: 'TBS Comics - Fort Walton Beach',
        authorAvatarUrl: const Value('https://images.unsplash.com/photo-1568602471122-7832951cc4c5?w=400&auto=format&fit=crop&q=80'),
        type: 'text',
        textContent: const Value('Friday Night Magic: Commander Celebration tonight at 6:30 PM! Extended trade tables, pack-per-win pods, and newly restocked Collector Boosters.'),
        locationTag: const Value('TBS Comics - Fort Walton Beach'),
        likeCount: const Value(56),
        commentCount: const Value(12),
        createdAt: Value(now.subtract(const Duration(hours: 12))),
        updatedAt: Value(now.subtract(const Duration(hours: 12))),
      ),
      FeedPostsCompanion.insert(
        id: 'post-media-1-1-tournament',
        authorId: 'store-tbs-comics',
        authorUsername: '@TBSComics',
        authorDisplayName: 'TBS Comics - Fort Walton Beach',
        authorAvatarUrl: const Value('https://images.unsplash.com/photo-1568602471122-7832951cc4c5?w=400&auto=format&fit=crop&q=80'),
        type: 'media',
        cardImageUrl: const Value('https://images.unsplash.com/photo-1511512578047-dfb367046420?w=800&auto=format&fit=crop&q=80'),
        cardSubtitle: const Value('1:1'),
        textContent: const Value('Store Championship announcement: Modern 1K Swiss + Top 8 cut this Saturday at 10 AM! Pre-registration open now.'),
        locationTag: const Value('TBS Comics - Fort Walton Beach'),
        likeCount: const Value(45),
        commentCount: const Value(3),
        createdAt: Value(now.subtract(const Duration(hours: 14))),
        updatedAt: Value(now.subtract(const Duration(hours: 14))),
      ),
      FeedPostsCompanion.insert(
        id: 'post-media-4-5-playmat',
        authorId: 'user-foil-collector-99',
        authorUsername: '@FoilCollector99',
        authorDisplayName: 'Foil Collector 99',
        authorAvatarUrl: const Value('https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=400&auto=format&fit=crop&q=80'),
        type: 'media',
        cardImageUrl: const Value('https://images.unsplash.com/photo-1544717305-2782549b5136?w=800&auto=format&fit=crop&q=80'),
        cardSubtitle: const Value('4:5'),
        textContent: const Value('Handcrafted full-grain leather double deckbox arrived today with stitched felt lining. Ready for the foil cube!'),
        locationTag: const Value('Fort Walton Beach, FL'),
        likeCount: const Value(33),
        commentCount: const Value(2),
        createdAt: Value(now.subtract(const Duration(hours: 16))),
        updatedAt: Value(now.subtract(const Duration(hours: 16))),
      ),
    ];

    for (final post in posts) {
      await db.into(db.feedPosts).insert(post, mode: InsertMode.insertOrReplace);
    }
  }

  Future<void> _seedCommentsAndLikes(DateTime now) async {
    final comments = [
      // post-spicy-pull (3 comments)
      PostCommentsCompanion.insert(
        id: 'c1-spicy-1',
        postId: 'post-spicy-pull',
        authorId: 'user-edh-rec-fanatic',
        authorUsername: '@EDH_Rec_Fanatic',
        authorDisplayName: 'EDH Rec Fanatic',
        authorAvatarUrl: const Value('https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=400&auto=format&fit=crop&q=80'),
        content: 'Need that for my Korvold list! Check my Trade Block, got Force of Negation available.',
        createdAt: Value(now.subtract(const Duration(hours: 1, minutes: 45))),
      ),
      PostCommentsCompanion.insert(
        id: 'c1-spicy-2',
        postId: 'post-spicy-pull',
        authorId: 'user-current-me',
        authorUsername: '@collector_me',
        authorDisplayName: 'Current Collector',
        authorAvatarUrl: const Value('https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=400&auto=format&fit=crop&q=80'),
        content: 'Insane pull! Sent you a message with my Sol Ring.',
        createdAt: Value(now.subtract(const Duration(hours: 1, minutes: 30))),
      ),
      PostCommentsCompanion.insert(
        id: 'c1-spicy-3',
        postId: 'post-spicy-pull',
        authorId: 'store-tbs-comics',
        authorUsername: '@TBSComics',
        authorDisplayName: 'TBS Comics - Fort Walton Beach',
        authorAvatarUrl: const Value('https://images.unsplash.com/photo-1568602471122-7832951cc4c5?w=400&auto=format&fit=crop&q=80'),
        content: 'Congrats on the pull! We have Dragon Shield sleeves ready at the counter.',
        createdAt: Value(now.subtract(const Duration(hours: 1, minutes: 15))),
      ),

      // post-foil-showcase (8 comments)
      PostCommentsCompanion.insert(
        id: 'c2-foil-1',
        postId: 'post-foil-showcase',
        authorId: 'user-spicy-brew-master',
        authorUsername: '@SpicyBrewMaster',
        authorDisplayName: 'Spicy Brew Master',
        authorAvatarUrl: const Value('https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400&auto=format&fit=crop&q=80'),
        content: 'The serialized ring! Unbelievable grab 🔥',
        createdAt: Value(now.subtract(const Duration(hours: 4, minutes: 30))),
      ),
      PostCommentsCompanion.insert(
        id: 'c2-foil-2',
        postId: 'post-foil-showcase',
        authorId: 'user-current-me',
        authorUsername: '@collector_me',
        authorDisplayName: 'Current Collector',
        authorAvatarUrl: const Value('https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=400&auto=format&fit=crop&q=80'),
        content: 'Absolute grail piece. Congrats!',
        createdAt: Value(now.subtract(const Duration(hours: 4, minutes: 10))),
      ),
      PostCommentsCompanion.insert(
        id: 'c2-foil-3',
        postId: 'post-foil-showcase',
        authorId: 'user-edh-rec-fanatic',
        authorUsername: '@EDH_Rec_Fanatic',
        authorDisplayName: 'EDH Rec Fanatic',
        authorAvatarUrl: const Value('https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=400&auto=format&fit=crop&q=80'),
        content: 'Serialized 007 is the ultimate collector flex. Are you keeping it in a slab or double sleeving for Commander?',
        createdAt: Value(now.subtract(const Duration(hours: 3, minutes: 55))),
      ),
      PostCommentsCompanion.insert(
        id: 'c2-foil-4',
        postId: 'post-foil-showcase',
        authorId: 'store-tbs-comics',
        authorUsername: '@TBSComics',
        authorDisplayName: 'TBS Comics - Fort Walton Beach',
        authorAvatarUrl: const Value('https://images.unsplash.com/photo-1568602471122-7832951cc4c5?w=400&auto=format&fit=crop&q=80'),
        content: 'We can grade that with PSA or BGS at our next submission event! Swing by the shop.',
        createdAt: Value(now.subtract(const Duration(hours: 3, minutes: 40))),
      ),
      PostCommentsCompanion.insert(
        id: 'c2-foil-5',
        postId: 'post-foil-showcase',
        authorId: 'user-spicy-brew-master',
        authorUsername: '@SpicyBrewMaster',
        authorDisplayName: 'Spicy Brew Master',
        authorAvatarUrl: const Value('https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400&auto=format&fit=crop&q=80'),
        content: 'Imagine dropping that turn 1 off a Sol Ring. Pure intimidation factor.',
        createdAt: Value(now.subtract(const Duration(hours: 3, minutes: 20))),
      ),
      PostCommentsCompanion.insert(
        id: 'c2-foil-6',
        postId: 'post-foil-showcase',
        authorId: 'user-current-me',
        authorUsername: '@collector_me',
        authorDisplayName: 'Current Collector',
        authorAvatarUrl: const Value('https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=400&auto=format&fit=crop&q=80'),
        content: 'The centering on the border looks spotless too. What an incredible find!',
        createdAt: Value(now.subtract(const Duration(hours: 3, minutes: 5))),
      ),
      PostCommentsCompanion.insert(
        id: 'c2-foil-7',
        postId: 'post-foil-showcase',
        authorId: 'user-edh-rec-fanatic',
        authorUsername: '@EDH_Rec_Fanatic',
        authorDisplayName: 'EDH Rec Fanatic',
        authorAvatarUrl: const Value('https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=400&auto=format&fit=crop&q=80'),
        content: 'I wonder where the 001 and 100 are right now. Definitely keep that locked in the vault.',
        createdAt: Value(now.subtract(const Duration(hours: 2, minutes: 50))),
      ),
      PostCommentsCompanion.insert(
        id: 'c2-foil-8',
        postId: 'post-foil-showcase',
        authorId: 'user-foil-collector-99',
        authorUsername: '@FoilCollector99',
        authorDisplayName: 'Foil Collector 99',
        authorAvatarUrl: const Value('https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=400&auto=format&fit=crop&q=80'),
        content: 'Thanks everyone! Definitely headed into a recessed magnetic slab for display.',
        createdAt: Value(now.subtract(const Duration(hours: 2, minutes: 30))),
      ),

      // post-edh-combo-showcase (4 comments)
      PostCommentsCompanion.insert(
        id: 'c-combo-1',
        postId: 'post-edh-combo-showcase',
        authorId: 'user-spicy-brew-master',
        authorUsername: '@SpicyBrewMaster',
        authorDisplayName: 'Spicy Brew Master',
        authorAvatarUrl: const Value('https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400&auto=format&fit=crop&q=80'),
        content: 'Classic infinite mana combo! Don\'t forget you can exile your entire library with Urza and cast everything.',
        createdAt: Value(now.subtract(const Duration(hours: 5, minutes: 40))),
      ),
      PostCommentsCompanion.insert(
        id: 'c-combo-2',
        postId: 'post-edh-combo-showcase',
        authorId: 'user-foil-collector-99',
        authorUsername: '@FoilCollector99',
        authorDisplayName: 'Foil Collector 99',
        authorAvatarUrl: const Value('https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=400&auto=format&fit=crop&q=80'),
        content: 'Love the foil Kaladesh printing of Dramatic Reversal. Pure nostalgia.',
        createdAt: Value(now.subtract(const Duration(hours: 5, minutes: 20))),
      ),
      PostCommentsCompanion.insert(
        id: 'c-combo-3',
        postId: 'post-edh-combo-showcase',
        authorId: 'user-current-me',
        authorUsername: '@collector_me',
        authorDisplayName: 'Current Collector',
        authorAvatarUrl: const Value('https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=400&auto=format&fit=crop&q=80'),
        content: 'How do you protect Scepter from getting blown out by Krosan Grip or Boseiju?',
        createdAt: Value(now.subtract(const Duration(hours: 4, minutes: 50))),
      ),
      PostCommentsCompanion.insert(
        id: 'c-combo-4',
        postId: 'post-edh-combo-showcase',
        authorId: 'user-edh-rec-fanatic',
        authorUsername: '@EDH_Rec_Fanatic',
        authorDisplayName: 'EDH Rec Fanatic',
        authorAvatarUrl: const Value('https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=400&auto=format&fit=crop&q=80'),
        content: 'We hold Force of Will or Swan Song for interaction before casting Scepter, or activate in response!',
        createdAt: Value(now.subtract(const Duration(hours: 4, minutes: 30))),
      ),

      // post-edh-deck-share (5 comments)
      PostCommentsCompanion.insert(
        id: 'c3-edh-1',
        postId: 'post-edh-deck-share',
        authorId: 'user-spicy-brew-master',
        authorUsername: '@SpicyBrewMaster',
        authorDisplayName: 'Spicy Brew Master',
        authorAvatarUrl: const Value('https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400&auto=format&fit=crop&q=80'),
        content: 'Force of Negation is huge for tapping out on Urza and still holding free interaction.',
        createdAt: Value(now.subtract(const Duration(hours: 7, minutes: 30))),
      ),
      PostCommentsCompanion.insert(
        id: 'c3-edh-2',
        postId: 'post-edh-deck-share',
        authorId: 'user-foil-collector-99',
        authorUsername: '@FoilCollector99',
        authorDisplayName: 'Foil Collector 99',
        authorAvatarUrl: const Value('https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=400&auto=format&fit=crop&q=80'),
        content: 'Are you running the retro frame foil Urza or modern border? Got a retro available if looking.',
        createdAt: Value(now.subtract(const Duration(hours: 7, minutes: 10))),
      ),
      PostCommentsCompanion.insert(
        id: 'c3-edh-3',
        postId: 'post-edh-deck-share',
        authorId: 'store-tbs-comics',
        authorUsername: '@TBSComics',
        authorDisplayName: 'TBS Comics - Fort Walton Beach',
        authorAvatarUrl: const Value('https://images.unsplash.com/photo-1568602471122-7832951cc4c5?w=400&auto=format&fit=crop&q=80'),
        content: 'Testing pods start at 6 PM this Friday! We\'ll have a competitive pod table reserved.',
        createdAt: Value(now.subtract(const Duration(hours: 6, minutes: 45))),
      ),
      PostCommentsCompanion.insert(
        id: 'c3-edh-4',
        postId: 'post-edh-deck-share',
        authorId: 'user-current-me',
        authorUsername: '@collector_me',
        authorDisplayName: 'Current Collector',
        authorAvatarUrl: const Value('https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=400&auto=format&fit=crop&q=80'),
        content: 'Isochron Scepter with Dramatic Reversal is pure gas. Infinite mana with Urza is basically game on the spot.',
        createdAt: Value(now.subtract(const Duration(hours: 6, minutes: 20))),
      ),
      PostCommentsCompanion.insert(
        id: 'c3-edh-5',
        postId: 'post-edh-deck-share',
        authorId: 'user-edh-rec-fanatic',
        authorUsername: '@EDH_Rec_Fanatic',
        authorDisplayName: 'EDH Rec Fanatic',
        authorAvatarUrl: const Value('https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=400&auto=format&fit=crop&q=80'),
        content: 'Exactly! Once Urza\'s ability is online with infinite mana you exile the library and cast whatever you want.',
        createdAt: Value(now.subtract(const Duration(hours: 6, minutes: 0))),
      ),

      // post-media-16-9-pod (2 comments)
      PostCommentsCompanion.insert(
        id: 'c-pod-1',
        postId: 'post-media-16-9-pod',
        authorId: 'user-spicy-brew-master',
        authorUsername: '@SpicyBrewMaster',
        authorDisplayName: 'Spicy Brew Master',
        authorAvatarUrl: const Value('https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400&auto=format&fit=crop&q=80'),
        content: 'That board state looks wild! Who ended up taking the game?',
        createdAt: Value(now.subtract(const Duration(hours: 9, minutes: 20))),
      ),
      PostCommentsCompanion.insert(
        id: 'c-pod-2',
        postId: 'post-media-16-9-pod',
        authorId: 'user-edh-rec-fanatic',
        authorUsername: '@EDH_Rec_Fanatic',
        authorDisplayName: 'EDH Rec Fanatic',
        authorAvatarUrl: const Value('https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=400&auto=format&fit=crop&q=80'),
        content: 'Urza survived the wipe and closed it out with construct tokens!',
        createdAt: Value(now.subtract(const Duration(hours: 9, minutes: 0))),
      ),

      // post-tbs-fnm-event (12 comments)
      PostCommentsCompanion.insert(
        id: 'c4-tbs-1',
        postId: 'post-tbs-fnm-event',
        authorId: 'user-edh-rec-fanatic',
        authorUsername: '@EDH_Rec_Fanatic',
        authorDisplayName: 'EDH Rec Fanatic',
        authorAvatarUrl: const Value('https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=400&auto=format&fit=crop&q=80'),
        content: 'Count me in! Bringing the tuned Urza deck for the high power pod.',
        createdAt: Value(now.subtract(const Duration(hours: 11, minutes: 40))),
      ),
      PostCommentsCompanion.insert(
        id: 'c4-tbs-2',
        postId: 'post-tbs-fnm-event',
        authorId: 'user-spicy-brew-master',
        authorUsername: '@SpicyBrewMaster',
        authorDisplayName: 'Spicy Brew Master',
        authorAvatarUrl: const Value('https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400&auto=format&fit=crop&q=80'),
        content: 'I\'ll be there with my Pauper battlebox too if anyone wants between-round matches.',
        createdAt: Value(now.subtract(const Duration(hours: 11, minutes: 20))),
      ),
      PostCommentsCompanion.insert(
        id: 'c4-tbs-3',
        postId: 'post-tbs-fnm-event',
        authorId: 'user-foil-collector-99',
        authorUsername: '@FoilCollector99',
        authorDisplayName: 'Foil Collector 99',
        authorAvatarUrl: const Value('https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=400&auto=format&fit=crop&q=80'),
        content: 'Will the trade binders be out before 6:30? Looking to trade for some MH3 foils.',
        createdAt: Value(now.subtract(const Duration(hours: 11, minutes: 5))),
      ),
      PostCommentsCompanion.insert(
        id: 'c4-tbs-4',
        postId: 'post-tbs-fnm-event',
        authorId: 'store-tbs-comics',
        authorUsername: '@TBSComics',
        authorDisplayName: 'TBS Comics - Fort Walton Beach',
        authorAvatarUrl: const Value('https://images.unsplash.com/photo-1568602471122-7832951cc4c5?w=400&auto=format&fit=crop&q=80'),
        content: '@FoilCollector99 Trade tables open at 5:00 PM! Staff will also have store buylist processing open.',
        createdAt: Value(now.subtract(const Duration(hours: 10, minutes: 45))),
      ),
      PostCommentsCompanion.insert(
        id: 'c4-tbs-5',
        postId: 'post-tbs-fnm-event',
        authorId: 'user-current-me',
        authorUsername: '@collector_me',
        authorDisplayName: 'Current Collector',
        authorAvatarUrl: const Value('https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=400&auto=format&fit=crop&q=80'),
        content: 'Looking forward to it! Bringing two trade binders and my precon upgrade.',
        createdAt: Value(now.subtract(const Duration(hours: 10, minutes: 30))),
      ),
      PostCommentsCompanion.insert(
        id: 'c4-tbs-6',
        postId: 'post-tbs-fnm-event',
        authorId: 'user-spicy-brew-master',
        authorUsername: '@SpicyBrewMaster',
        authorDisplayName: 'Spicy Brew Master',
        authorAvatarUrl: const Value('https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400&auto=format&fit=crop&q=80'),
        content: 'Save a spot in the casual pod for my mono-red jank brew!',
        createdAt: Value(now.subtract(const Duration(hours: 10, minutes: 15))),
      ),
      PostCommentsCompanion.insert(
        id: 'c4-tbs-7',
        postId: 'post-tbs-fnm-event',
        authorId: 'user-edh-rec-fanatic',
        authorUsername: '@EDH_Rec_Fanatic',
        authorDisplayName: 'EDH Rec Fanatic',
        authorAvatarUrl: const Value('https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=400&auto=format&fit=crop&q=80'),
        content: 'Anyone interested in a Rule 0 discussion for bracket 3-4 before we start?',
        createdAt: Value(now.subtract(const Duration(hours: 10, minutes: 0))),
      ),
      PostCommentsCompanion.insert(
        id: 'c4-tbs-8',
        postId: 'post-tbs-fnm-event',
        authorId: 'user-current-me',
        authorUsername: '@collector_me',
        authorDisplayName: 'Current Collector',
        authorAvatarUrl: const Value('https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=400&auto=format&fit=crop&q=80'),
        content: '@EDH_Rec_Fanatic I\'m down for a bracket 3 match. No fast mana on my end.',
        createdAt: Value(now.subtract(const Duration(hours: 9, minutes: 45))),
      ),
      PostCommentsCompanion.insert(
        id: 'c4-tbs-9',
        postId: 'post-tbs-fnm-event',
        authorId: 'store-tbs-comics',
        authorUsername: '@TBSComics',
        authorDisplayName: 'TBS Comics - Fort Walton Beach',
        authorAvatarUrl: const Value('https://images.unsplash.com/photo-1568602471122-7832951cc4c5?w=400&auto=format&fit=crop&q=80'),
        content: 'Reminder: prize support includes promo packs for all participants and foil promos for pod winners!',
        createdAt: Value(now.subtract(const Duration(hours: 9, minutes: 30))),
      ),
      PostCommentsCompanion.insert(
        id: 'c4-tbs-10',
        postId: 'post-tbs-fnm-event',
        authorId: 'user-foil-collector-99',
        authorUsername: '@FoilCollector99',
        authorDisplayName: 'Foil Collector 99',
        authorAvatarUrl: const Value('https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=400&auto=format&fit=crop&q=80'),
        content: 'Sounds awesome! Bringing serialized cards for showcase.',
        createdAt: Value(now.subtract(const Duration(hours: 9, minutes: 15))),
      ),
      PostCommentsCompanion.insert(
        id: 'c4-tbs-11',
        postId: 'post-tbs-fnm-event',
        authorId: 'user-spicy-brew-master',
        authorUsername: '@SpicyBrewMaster',
        authorDisplayName: 'Spicy Brew Master',
        authorAvatarUrl: const Value('https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400&auto=format&fit=crop&q=80'),
        content: 'See everyone in an hour! Let\'s get some great games in.',
        createdAt: Value(now.subtract(const Duration(hours: 9, minutes: 0))),
      ),
      PostCommentsCompanion.insert(
        id: 'c4-tbs-12',
        postId: 'post-tbs-fnm-event',
        authorId: 'store-tbs-comics',
        authorUsername: '@TBSComics',
        authorDisplayName: 'TBS Comics - Fort Walton Beach',
        authorAvatarUrl: const Value('https://images.unsplash.com/photo-1568602471122-7832951cc4c5?w=400&auto=format&fit=crop&q=80'),
        content: 'Doors are open, pairings go up in 30 minutes!',
        createdAt: Value(now.subtract(const Duration(hours: 8, minutes: 45))),
      ),

      // post-media-1-1-tournament (3 comments)
      PostCommentsCompanion.insert(
        id: 'c-tourn-1',
        postId: 'post-media-1-1-tournament',
        authorId: 'user-spicy-brew-master',
        authorUsername: '@SpicyBrewMaster',
        authorDisplayName: 'Spicy Brew Master',
        authorAvatarUrl: const Value('https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400&auto=format&fit=crop&q=80'),
        content: 'Registered! Bringing Asmor Food Storm to the Swiss.',
        createdAt: Value(now.subtract(const Duration(hours: 13, minutes: 20))),
      ),
      PostCommentsCompanion.insert(
        id: 'c-tourn-2',
        postId: 'post-media-1-1-tournament',
        authorId: 'user-foil-collector-99',
        authorUsername: '@FoilCollector99',
        authorDisplayName: 'Foil Collector 99',
        authorAvatarUrl: const Value('https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=400&auto=format&fit=crop&q=80'),
        content: 'Will decklists be open or closed sheet?',
        createdAt: Value(now.subtract(const Duration(hours: 13, minutes: 0))),
      ),
      PostCommentsCompanion.insert(
        id: 'c-tourn-3',
        postId: 'post-media-1-1-tournament',
        authorId: 'store-tbs-comics',
        authorUsername: '@TBSComics',
        authorDisplayName: 'TBS Comics - Fort Walton Beach',
        authorAvatarUrl: const Value('https://images.unsplash.com/photo-1568602471122-7832951cc4c5?w=400&auto=format&fit=crop&q=80'),
        content: 'Competitive REL with open decklists for Top 8.',
        createdAt: Value(now.subtract(const Duration(hours: 12, minutes: 40))),
      ),

      // post-media-4-5-playmat (2 comments)
      PostCommentsCompanion.insert(
        id: 'c-playmat-1',
        postId: 'post-media-4-5-playmat',
        authorId: 'user-edh-rec-fanatic',
        authorUsername: '@EDH_Rec_Fanatic',
        authorDisplayName: 'EDH Rec Fanatic',
        authorAvatarUrl: const Value('https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=400&auto=format&fit=crop&q=80'),
        content: 'That stitching is gorgeous! Where did you commission it?',
        createdAt: Value(now.subtract(const Duration(hours: 15, minutes: 30))),
      ),
      PostCommentsCompanion.insert(
        id: 'c-playmat-2',
        postId: 'post-media-4-5-playmat',
        authorId: 'user-foil-collector-99',
        authorUsername: '@FoilCollector99',
        authorDisplayName: 'Foil Collector 99',
        authorAvatarUrl: const Value('https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=400&auto=format&fit=crop&q=80'),
        content: 'Local leatherworker in Pensacola, top notch craftsmanship.',
        createdAt: Value(now.subtract(const Duration(hours: 15, minutes: 10))),
      ),
    ];

    for (final comment in comments) {
      await db.into(db.postComments).insert(comment, mode: InsertMode.insertOrReplace);
    }
  }

  Future<void> _seedFriendships(DateTime now) async {
    final friendshipsList = [
      FriendshipsCompanion.insert(
        id: 'friend_current_edh',
        userId: 'user-current-me',
        friendId: 'user-edh-rec-fanatic',
        status: const Value('accepted'),
        createdAt: Value(now.subtract(const Duration(days: 5))),
        updatedAt: Value(now.subtract(const Duration(days: 5))),
      ),
      FriendshipsCompanion.insert(
        id: 'friend_foil_current_pending',
        userId: 'user-foil-collector-99',
        friendId: 'user-current-me',
        status: const Value('pending'),
        createdAt: Value(now.subtract(const Duration(hours: 3))),
        updatedAt: Value(now.subtract(const Duration(hours: 3))),
      ),
      FriendshipsCompanion.insert(
        id: 'friend_current_spicy_pending',
        userId: 'user-current-me',
        friendId: 'user-spicy-brew-master',
        status: const Value('accepted'),
        createdAt: Value(now.subtract(const Duration(days: 2))),
        updatedAt: Value(now.subtract(const Duration(days: 2))),
      ),
    ];

    for (final f in friendshipsList) {
      await db.into(db.friendships).insert(f, mode: InsertMode.insertOrReplace);
    }
  }

  Future<void> _seedNotifications(DateTime now) async {
    final notifs = [
      NotificationsCompanion.insert(
        id: 'notif_fr_foil_collector',
        userId: 'user-current-me',
        actorId: 'user-foil-collector-99',
        actorUsername: '@FoilCollector99',
        actorDisplayName: const Value('Foil Collector 99'),
        actorAvatarUrl: const Value('https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=150'),
        type: 'friend_request',
        title: 'Friend Request',
        body: 'sent you a friend request',
        targetEntityId: const Value('user-foil-collector-99'),
        targetEntityType: const Value('profile'),
        status: const Value('unread'),
        isRead: const Value(false),
        isActioned: const Value(false),
        createdAt: Value(now.subtract(const Duration(hours: 3))),
      ),
      NotificationsCompanion.insert(
        id: 'notif_trade_spicy_offer',
        userId: 'user-current-me',
        actorId: 'user-spicy-brew-master',
        actorUsername: '@SpicyBrewMaster',
        actorDisplayName: const Value('Spicy Brew Master'),
        actorAvatarUrl: const Value('https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150'),
        type: 'trade_proposal',
        title: 'New Trade Offer',
        body: 'proposed a trade: Dockside Extortionist (\$78.00) for your Sol Ring (\$65.00)',
        targetEntityId: const Value('trade-spicy-dockside'),
        targetEntityType: const Value('trade'),
        status: const Value('unread'),
        isRead: const Value(false),
        isActioned: const Value(false),
        createdAt: Value(now.subtract(const Duration(hours: 2))),
      ),
      NotificationsCompanion.insert(
        id: 'notif_like_edh_rec',
        userId: 'user-current-me',
        actorId: 'user-edh-rec-fanatic',
        actorUsername: '@EDH_Rec_Fanatic',
        actorDisplayName: const Value('EDH Rec Fanatic'),
        actorAvatarUrl: const Value('https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150'),
        type: 'post_like',
        title: 'New Like',
        body: 'hyped your binder showcase',
        targetEntityId: const Value('post-spicy-pull'),
        targetEntityType: const Value('post'),
        status: const Value('unread'),
        isRead: const Value(false),
        createdAt: Value(now.subtract(const Duration(hours: 6))),
      ),
    ];

    for (final notif in notifs) {
      await db.into(db.notifications).insert(notif, mode: InsertMode.insertOrReplace);
    }
  }

  Future<void> _seedMessagesAndTradeProposals(DateTime now) async {
    const conversationId = 'user-current-me_user-spicy-brew-master';

    // Proposal record
    final proposal = TradeProposalsCompanion.insert(
      id: 'trade-spicy-dockside',
      proposerId: 'user-spicy-brew-master',
      receiverId: 'user-current-me',
      offeredCardIdsJson: jsonEncode(['item-card-dockside-extortionist']),
      requestedCardIdsJson: jsonEncode(['item-mtg-sol-ring']),
      offeredCardsSnapshotJson: Value(jsonEncode([
        {
          'id': 'item-card-dockside-extortionist',
          'name': 'Dockside Extortionist',
          'price': 78.00,
          'rarity': 'Mythic Rare',
          'imageUrl': 'https://cards.scryfall.io/normal/front/9/e/9e2e3efb-75cb-430f-b9f4-cb58f3aeb91b.jpg',
        }
      ])),
      requestedCardsSnapshotJson: Value(jsonEncode([
        {
          'id': 'item-mtg-sol-ring',
          'name': 'Sol Ring',
          'price': 65.00,
          'rarity': 'Rare',
          'imageUrl': 'https://cards.scryfall.io/large/front/d/5/d5806e68-1054-458e-866d-1f2470f682b2.jpg?1790212038',
        }
      ])),
      proposerCashDelta: const Value(0.0),
      offeredTotalValue: const Value(78.00),
      requestedTotalValue: const Value(65.00),
      status: const Value('pending'),
      note: const Value('Dockside Extortionist (Foil) for your Sol Ring (Retro Artifact) + \$13 delta'),
      createdAt: Value(now.subtract(const Duration(hours: 2))),
      updatedAt: Value(now.subtract(const Duration(hours: 2))),
    );

    await db.into(db.tradeProposals).insert(proposal, mode: InsertMode.insertOrReplace);

    // Messages
    final msgs = [
      MessagesCompanion.insert(
        id: 'msg-spicy-1',
        conversationId: conversationId,
        senderId: 'user-spicy-brew-master',
        recipientId: 'user-current-me',
        messageText: 'Hey! Saw your Retro Sol Ring in your Trade Block.',
        attachmentType: const Value('none'),
        isRead: const Value(true),
        createdAt: Value(now.subtract(const Duration(hours: 2, minutes: 15))),
      ),
      MessagesCompanion.insert(
        id: 'msg-spicy-2',
        conversationId: conversationId,
        senderId: 'user-spicy-brew-master',
        recipientId: 'user-current-me',
        messageText: 'Would you be open to trading it for my fresh Foil Dockside?',
        attachmentType: const Value('card'),
        attachmentCardId: const Value('item-card-dockside-extortionist'),
        attachmentCardJson: Value(jsonEncode({
          'name': 'Dockside Extortionist',
          'price': 78.00,
          'set': 'Double Masters 2022',
          'condition': 'NM',
          'foil': true,
        })),
        isRead: const Value(true),
        createdAt: Value(now.subtract(const Duration(hours: 2, minutes: 10))),
      ),
      MessagesCompanion.insert(
        id: 'msg-spicy-3',
        conversationId: conversationId,
        senderId: 'user-spicy-brew-master',
        recipientId: 'user-current-me',
        messageText: 'Proposed a trade offer below:',
        attachmentType: const Value('trade_proposal'),
        attachmentTradeProposalId: const Value('trade-spicy-dockside'),
        isRead: const Value(false),
        createdAt: Value(now.subtract(const Duration(hours: 2))),
      ),
    ];

    for (final msg in msgs) {
      await db.into(db.messages).insert(msg, mode: InsertMode.insertOrReplace);
    }
  }
}
