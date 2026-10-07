# E2E Test Infra: Countr Decks 2-Tab Rework

## Test Philosophy
- Opaque-box, requirement-driven. Derives from ORIGINAL_REQUEST.md, not implementation internals.
- Methodology: Category-Partition + Boundary Value Analysis (BVA) + Pairwise + Real-World Workload Testing.

## Feature Inventory & Test Mapping
| # | Feature | Requirement Source | Tier 1 (Feature) | Tier 2 (Boundary) | Tier 3 (Cross-Feature) | Tier 4 (Scenario) |
|---|---------|-------------------|:----------------:|:-----------------:|:---------------------:|:-----------------:|
| F1 | Dual-Tab Top Navigation | R1 | 5 | 5 | ✓ | ✓ |
| F2 | Independent Scroll & Filter Isolation | R1 | 5 | 5 | ✓ | ✓ |
| F3 | "My Decks" Status Badges (Draft/Assembled) | R2 | 5 | 5 | ✓ | ✓ |
| F4 | "My Decks" Multi-Tier Personal Search | R2 | 5 | 5 | ✓ | ✓ |
| F5 | "My Decks" Quick Filter Pills | R2 | 5 | 5 | ✓ | ✓ |
| F6 | 3-Dot Overflow Menu & "Share to Explore" | R2 | 5 | 5 | ✓ | ✓ |
| F7 | Press-and-Hold Selection Mode & Footer | R2 | 5 | 5 | ✓ | ✓ |
| F8 | Dedicated Explore SQLite Schema & Migration | R3, R5 | 5 | 5 | ✓ | ✓ |
| F9 | Offline MTGJSON Precon & Starter Seeder | R3 | 5 | 5 | ✓ | ✓ |
| F10 | Mock Community Decks Seeder | R3 | 5 | 5 | ✓ | ✓ |
| F11 | Top-Level Explore Category Pills | R3 | 5 | 5 | ✓ | ✓ |
| F12 | Explore 2-Column Grid Layout | R3 | 5 | 5 | ✓ | ✓ |
| F13 | Dynamic Horizontal Carousels | R3 | 5 | 5 | ✓ | ✓ |
| F14 | Dedicated Explore Filter Modal | R3 | 5 | 5 | ✓ | ✓ |
| F15 | Embedded Search Bar & Sort Menu | R4 | 5 | 5 | ✓ | ✓ |
| F16 | Multi-Level Contextual Search Headings | R4 | 5 | 5 | ✓ | ✓ |
| F17 | Explore Deck Summary Card UI | R5 | 5 | 5 | ✓ | ✓ |
| F18 | Persistent SQLite Voting System | R5 | 5 | 5 | ✓ | ✓ |
| F19 | Read-Only Deck View Screen | R6 | 5 | 5 | ✓ | ✓ |
| F20 | Clone Engine ("Add to My Decks") | R6 | 5 | 5 | ✓ | ✓ |
| F21 | Zero Regressions across 17 Legacy Suites | Acceptance Criteria | 5 | 5 | ✓ | ✓ |

## Test Architecture
- **In-Memory Drift Database**: `AppDatabase(NativeDatabase.memory())` with `driftRuntimeOptions.dontWarnAboutMultipleDatabases = true`.
- **Test Runner Command**: `flutter test`
- **Target Test Suites**:
  1. `test/features/decks/decks_dual_tab_architecture_test.dart` (R1)
  2. `test/features/decks/my_decks_search_and_sharing_test.dart` (R2)
  3. `test/features/decks/explore_precon_seeder_test.dart` (R3 Data)
  4. `test/features/decks/explore_feed_and_carousels_test.dart` (R3 UI)
  5. `test/features/decks/explore_search_and_sort_test.dart` (R4)
  6. `test/features/decks/explore_voting_persistence_test.dart` (R5)
  7. `test/features/decks/explore_deck_clone_engine_test.dart` (R6)
  8. `test/features/decks/explore_and_my_decks_e2e_journey_test.dart` (E2E Integration Journey)

## Real-World Application Scenarios (Tier 4)
| # | Scenario | Features Exercised | Complexity |
|---|----------|--------------------|------------|
| 1 | Personal Deck Search & Filtering | F3, F4, F5 | Medium |
| 2 | Share Personal Deck to Explore | F6, F7, F8, F11 | High |
| 3 | Explore Discovery, Carousel Browsing & Sorting | F11, F12, F13, F14, F15, F16 | High |
| 4 | Offline Precon Seeding, Voting & SQLite Persistence | F8, F9, F10, F17, F18 | High |
| 5 | Explore Deck Read-Only Inspection & Clone to My Decks | F17, F19, F20, F1, F3 | Very High |
| 6 | Full E2E User Journey (Browse -> Vote -> Clone -> Edit -> Share) | F1-F21 | Comprehensive |
