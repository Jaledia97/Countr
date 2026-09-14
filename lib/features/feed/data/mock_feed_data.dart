import '../domain/models/feed_post.dart';

abstract class MockFeedData {
  static List<FeedPost> get posts => [
        // Variant 1: Text Post
        const FeedPost(
          id: 'post-1',
          type: PostType.text,
          username: '@Jomel',
          avatarInitials: 'JA',
          timestamp: '2 Hours ago',
          locationTag: 'TBS Comics',
          textContent:
              'Looking for a 4th for commander tonight! Bringing an optimized bracket-3 Edgar Markov and high-synergy Yuriko. Anyone at the store ready to sling some cardboard?',
          hypeCount: 42,
          commentCount: 14,
          isHyped: true,
          isWishlisted: false,
        ),

        // Variant 2: Single Pull Post
        const FeedPost(
          id: 'post-2',
          type: PostType.singlePull,
          username: '@CollectorAlex',
          avatarInitials: 'CA',
          timestamp: '3 Hours ago',
          locationTag: 'PULLED @ TBS Comics',
          textContent:
              'No way... 2nd pack into the collector booster box! The foiling and centering look absolutely pristine. Straight to a penny sleeve and top-loader.',
          cardTitle: 'The One Ring (Serialized #007/100)',
          cardSubtitle: 'Lord of the Rings: Tales of Middle-earth',
          cardRarity: 'MYTHIC RARE • FOIL',
          estimatedValue: '\$12,450.00',
          hypeCount: 289,
          commentCount: 63,
          isHyped: false,
          isWishlisted: true,
        ),

        // Variant 3: Multi-Pull Post (2x2 grid, 4th item has "+ SEE MORE" overlay)
        const FeedPost(
          id: 'post-3',
          type: PostType.multiPull,
          username: '@PokéMaster_Dan',
          avatarInitials: 'PD',
          timestamp: '5 Hours ago',
          locationTag: 'Pallet Town Hobby Shop',
          textContent:
              'Friday night box break was pure fire! Pulled these gems plus 12 more secret rares. Check out the condition on the Charizard ex!',
          pullImages: [
            'Charizard ex (Special Illustration Rare)',
            'Mew ex (Hyper Rare Gold)',
            'Gardevoir ex (Illustration Rare)',
            'Iono (Special Illustration Rare)',
          ],
          hypeCount: 178,
          commentCount: 39,
          isHyped: true,
          isWishlisted: false,
        ),

        // Variant 4: Another Single Pull Post (Comic Book variant)
        const FeedPost(
          id: 'post-4',
          type: PostType.singlePull,
          username: '@ComicHunter_Sarah',
          avatarInitials: 'CS',
          timestamp: '8 Hours ago',
          locationTag: 'PULLED @ Emerald City Con',
          textContent:
              'Grail acquisition unlocked! Graded CGC 9.8 white pages. First appearance of Miles Morales.',
          cardTitle: 'Ultimate Fallout #4 (1st Miles Morales)',
          cardSubtitle: 'Marvel Comics • 1st Print 2011',
          cardRarity: 'CGC 9.8 WHITE PAGES',
          estimatedValue: '\$2,100.00',
          hypeCount: 312,
          commentCount: 45,
          isHyped: true,
          isWishlisted: true,
        ),

        // Variant 5: Another Text Post
        const FeedPost(
          id: 'post-5',
          type: PostType.text,
          username: '@LorcanaLegends',
          avatarInitials: 'LL',
          timestamp: '12 Hours ago',
          locationTag: 'Dragon’s Lair Games',
          textContent:
              'Set Championship results: Ruby/Amethyst control took 1st and 2nd place today! Bounce package still dominant in the current meta.',
          hypeCount: 88,
          commentCount: 22,
          isHyped: false,
          isWishlisted: false,
        ),
      ];
}
