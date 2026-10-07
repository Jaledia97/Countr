# Project: Major 2-Tab Rework of Countr Decks Experience

## Architecture
Countr's deck management system is partitioned into two distinct tabs ("My Decks" and "Explore Decks") with independent scroll and filter states, backed by local Drift SQLite persistence.

### Data Flow
1. **Explore Catalog & Seeding**:
   - Preconstructed decks (MTGJSON Commander, Challenger, Starter Kits, Duel Decks, Planechase, Archenemy) and mock community decks (@SpicyBrewMaster, @EDH_Rec_Fanatic, @DraftGuru) are bundled as offline assets and backed by a compiled Dart fallback dataset.
   - On database initialization, `ExploreDeckDao` seeds decks into `explore_decks` and `explore_deck_items` via background isolate processing, ensuring zero UI thread jank.
2. **Persistent Voting Engine**:
   - `explore_deck_votes` records user vote (-1, 0, 1) in SQLite.
   - Toggling an upvote or downvote atomically updates `explore_deck_votes` and the net score in `explore_decks`.
   - Reactive Drift streams emit state updates to both `ExploreDeckCard` summary tiles and `ReadOnlyDeckScreen`.
3. **Sharing & Cloning**:
   - "Share to Explore": User decks from `decks` and `deck_version_items` are exported to `explore_decks` with source type `user_shared`.
   - "Add to My Decks" (Clone): Explore decks are cloned into `decks`, `deck_versions`, and `deck_version_items` with `is_cloned = true` and `is_assembled = false`, creating unowned catalog reference `vault_items` (quantity: 0) where needed.
4. **Presentation & Navigation**:
   - `DecksScreen` is the root tabbed host using `TabBarView` with `AutomaticKeepAliveClientMixin` and `PageStorageKey`s.
   - Tab 0 ("My Decks") preserves all 17 legacy test keys (`decks_tab_all`, `decks_new_deck_fab`, `decks_tcg_context_switcher`, `decks_privacy_mode_button`, `deck_setup_wizard_button`, `deck_item_${id}`, `deck_assembly_status_${id}`).
   - Tab 1 ("Explore Decks") houses the discovery feed with 2-column grid, horizontal carousels, embedded sort menu, multi-level search with visual headings, and deep filter modal.

---

## Feature Inventory
| # | Feature | Description | Milestone | Source |
|---|---------|-------------|-----------|--------|
| F1 | Dual-Tab Top Navigation | `DecksScreen` partitioned into "My Decks" and "Explore Decks" tabs with TabBar | M2 | R1 |
| F2 | Independent Scroll & Filter Isolation | Tab states preserved across switches via `AutomaticKeepAliveClientMixin` and `PageStorageKey` | M2 | R1 |
| F3 | "My Decks" Status Badges | Drafts, Ready, and Assembled visual badges on personal deck cards | M2 | R2 |
| F4 | "My Decks" Multi-Tier Search | Personal search matching Deck Name and contained Card Name with visual divider headers | M2 | R2 |
| F5 | "My Decks" Quick Filter Pills | Format chips, status pills (All, Competitive, Draft), and color identity pips | M2 | R2 |
| F6 | 3-Dot Overflow Menu & Sharing | Card overflow menu with "Share to Explore" exporting to SQLite explore tables | M2 | R2 |
| F7 | Press-and-Hold Selection Mode | Long-press selection bringing up bottom footer; "Share to Explore" strictly when 1 deck selected | M2 | R2 |
| F8 | Dedicated Explore SQLite Schema & Migration | `explore_decks`, `explore_deck_items`, `explore_deck_votes` tables, Drift v11 migration | M1 | R3, R5 |
| F9 | Offline MTGJSON Precon & Starter Seeder | Offline bundling & background isolate ingestion of Commander, Challenger, Starter, Duel Decks | M1 | R3 |
| F10 | Mock Community Decks Seeder | Offline seeding of mock community brews with creator usernames (@SpicyBrewMaster, etc.) | M1 | R3 |
| F11 | Top-Level Explore Category Pills | Quick-toggle pills for "All", "Official (WotC)", and "Community" | M3 | R3 |
| F12 | Explore 2-Column Grid Layout | Responsive 2-column deck card grid for rapid discovery | M3 | R3 |
| F13 | Dynamic Horizontal Carousels | Horizontal scrolling carousels ("Suggested Commanders", "From Top Deck Builders", "Popular Standard") | M3 | R3 |
| F14 | Dedicated Explore Filter Modal | Deep modal filtering by Format, Color Identity, Budget ($0-$50, $50-$200, $200+), Commander, Cards | M3 | R3 |
| F15 | Embedded Search Bar & Sort Menu | Inline sort button inside search bar with popup menu offering 5 sort algorithms | M3 | R4 |
| F16 | Multi-Level Contextual Search Headings | Explore search results partitioned under `"in Deck Name"`, `"in Deck Cards"`, `"by Username"` | M3 | R4 |
| F17 | Explore Deck Summary Card UI | High-res art banner, creator tag, mana symbols, market price, popularity score | M4 | R5 |
| F18 | Persistent SQLite Voting System | Interactive Upvote/Downvote buttons, atomic score computation, persistence across restarts | M4 | R5 |
| F19 | Read-Only Deck View Screen | View-only deck detail screen hiding all card/deck mutation and playtest controls | M5 | R6 |
| F20 | Clone Engine ("Add to My Decks") | Prominent clone button copying full decklist into local `decks`, `deck_versions`, `deck_version_items` | M5 | R6 |
| F21 | E2E & Regression Verification | 100% test pass across all new and 17 existing deck test suites, 0 static analysis errors | M6 | Acceptance Criteria |

---

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| M1 | Data Models, Drift v11 Schema, DAO & Offline Seeder | F8, F9, F10 | none | DONE |
| M2 | Dual-Tab Architecture & "My Decks" Search, Badges & Sharing | F1, F2, F3, F4, F5, F6, F7 | M1 | DONE |
| M3 | Explore Feed, 2-Column Grid, Carousels, Search & Filter Modal | F11, F12, F13, F14, F15, F16 | M1, M2 | DONE |
| M4 | Deck Summary Cards & Persistent SQLite Voting System | F17, F18 | M1, M3 | DONE |
| M5 | Read-Only Deck View Screen & Clone Engine | F19, F20 | M1, M4 | DONE |
| M6 | E2E Test Suite Validation, Regression Harmonization & Hardening | F21 | M1, M2, M3, M4, M5 | DONE |

---

## Interface Contracts

### 1. Data Layer ↔ Presentation Layer (`ExploreDeckDao` ↔ Riverpod Providers)
```dart
abstract class ExploreDeckDaoInterface {
  Stream<List<ExploreDeckWithVote>> watchExploreDecks({
    ExploreCategory category = ExploreCategory.all,
    ExploreSortOption sort = ExploreSortOption.popularity,
    ExploreFilterState? filter,
    String searchQuery = '',
  });

  Stream<ExploreDeckDetail?> watchExploreDeckDetail(String deckId);

  Future<void> castVote({
    required String deckId,
    required String userId,
    required int vote, // -1, 0, 1
  });

  Future<void> seedPreconsAndCommunityDecks();

  Future<ExploreDeck> sharePersonalDeckToExplore({
    required String personalDeckId,
    required String creatorName,
  });

  Future<Deck> cloneExploreDeckToPersonal({
    required ExploreDeck exploreDeck,
  });
}
```

### 2. Search & Filter State Models
```dart
enum ExploreCategory { all, official, community }
enum ExploreSortOption { popularity, recentlyAdded, priceLowToHigh, priceHighToLow, alphabetical }

class ExploreFilterState {
  final String? format;
  final List<String> colors;
  final String colorMatchMode;
  final String priceRange; // 'all', 'budget_0_50', 'mid_50_200', 'high_200_plus'
  final String? commanderName;
  final String? cardInclusion;
  ...
}
```

### 3. Clone Engine Contract
- Input: `ExploreDeck` (including full `List<ExploreDeckCardItem> cards`).
- Output: `Future<Deck>` saved in SQLite `DecksTable`, `DeckVersionsTable`, `DeckVersionItemsTable`, and `VaultItemsTable` (if cards unowned).
- Invalidation: Triggers `ref.invalidate(deckListProvider)` and `ref.invalidate(deckSummariesProvider)`.

---

## Code Layout

### Data Layer:
- `lib/core/database/tables/decks/explore_decks_table.dart`: Explore decks table schema
- `lib/core/database/tables/decks/explore_deck_items_table.dart`: Explore deck card items schema
- `lib/core/database/tables/decks/explore_deck_votes_table.dart`: Persistent SQLite voting table
- `lib/core/database/app_database.dart`: Schema v11 upgrade, table registration, defensive DDL in beforeOpen
- `lib/features/decks/data/daos/explore_deck_dao.dart`: Drift DAO with reactive queries, atomic voting, and seeding
- `lib/features/decks/data/services/explore_seeder_service.dart`: Background isolate parser & compiled seed fallback
- `assets/decks/precons.json`: Bundled official MTG precons (Commander, Challenger, Starter, Duel Decks)
- `assets/decks/community.json`: Bundled mock community decks (@SpicyBrewMaster, @EDH_Rec_Fanatic, etc.)

### Domain Models:
- `lib/features/decks/domain/models/explore_deck.dart`
- `lib/features/decks/domain/models/explore_deck_card_item.dart`
- `lib/features/decks/domain/models/explore_filter_state.dart`
- `lib/features/decks/domain/models/my_decks_search_result.dart`
- `lib/features/decks/domain/models/explore_search_result.dart`

### Presentation Layer:
- `lib/features/decks/presentation/providers/explore_deck_providers.dart`: Riverpod state providers
- `lib/features/decks/presentation/screens/decks_screen.dart`: Dual-tab root host (TabBarView, PageStorageKeys)
- `lib/features/decks/presentation/screens/read_only_deck_screen.dart`: Read-only deck viewer
- `lib/features/decks/presentation/controllers/deck_clone_controller.dart`: Cloning logic
- `lib/features/decks/presentation/widgets/my_decks/my_decks_tab_view.dart`: Tab 0 implementation
- `lib/features/decks/presentation/widgets/my_decks/my_decks_search_bar.dart`: Personal search input
- `lib/features/decks/presentation/widgets/my_decks/my_decks_search_results_view.dart`: Divided results
- `lib/features/decks/presentation/widgets/my_decks/my_deck_card.dart`: Personal deck card with 3-dot overflow
- `lib/features/decks/presentation/widgets/my_decks/my_decks_selection_footer.dart`: Press-and-hold selection bar
- `lib/features/decks/presentation/widgets/explore/explore_decks_tab_view.dart`: Tab 1 feed
- `lib/features/decks/presentation/widgets/explore/explore_search_bar.dart`: Search bar with sort button & filter trigger
- `lib/features/decks/presentation/widgets/explore/explore_search_results_view.dart`: Multi-level grouped search
- `lib/features/decks/presentation/widgets/explore/explore_carousel_section.dart`: Horizontal category carousels
- `lib/features/decks/presentation/widgets/explore/explore_deck_card.dart`: 2-column grid summary card with voting
- `lib/features/decks/presentation/widgets/explore/explore_filter_modal.dart`: Dedicated filter sheet

### Test Suites:
- `test/features/decks/decks_dual_tab_architecture_test.dart`: R1 Dual-Tab navigation & state isolation
- `test/features/decks/my_decks_search_and_sharing_test.dart`: R2 Personal search, line breaks & sharing
- `test/features/decks/explore_precon_seeder_test.dart`: R3 Offline seeding & SQLite ingestion
- `test/features/decks/explore_feed_and_carousels_test.dart`: R3 2-column grid, carousels & filter modal
- `test/features/decks/explore_search_and_sort_test.dart`: R4 Embedded sort & multi-level query headings
- `test/features/decks/explore_voting_persistence_test.dart`: R5 Persistent SQLite voting & score updates
- `test/features/decks/explore_deck_clone_engine_test.dart`: R6 Read-only detail view & cloning engine
