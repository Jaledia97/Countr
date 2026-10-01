# E2E Test Infra: Countr Patch 4.9

## Test Philosophy
- Requirement-driven, opaque-box testing covering all 11 Patch 4.9 objectives (R1-R11).
- Methodology: Category-Partition + Boundary Value Analysis + Pairwise Combinations + Real-World Workload Scenarios.

## Feature Inventory & Test Mapping
| # | Feature | Requirement | Tier 1 (Isolated) | Tier 2 (Boundary) | Tier 3 (Pairwise) | Tier 4 (E2E Scenario) |
|---|---------|-------------|:-----------------:|:-----------------:|:-----------------:|:---------------------:|
| 1 | Full Scryfall Catalog Filtering | R1 | 5 | 5 | ✓ | ✓ |
| 2 | Cross-Screen TCG Context Sync | R2 | 5 | 5 | ✓ | ✓ |
| 3 | Collapsible Card Art Header | R3 | 5 | 5 | ✓ | ✓ |
| 4 | Card Mechanics Tag Deduplication | R4 | 5 | 5 | ✓ | ✓ |
| 5 | Portfolio & Metrics Terminology | R5 | 5 | 5 | ✓ | ✓ |
| 6 | Remove Delete for Unowned Items | R6 | 5 | 5 | ✓ | ✓ |
| 7 | Unowned Card Routing via "Add to +" | R7 | 5 | 5 | ✓ | ✓ |
| 8 | Automated Deck Assignment Tracking | R8 | 5 | 5 | ✓ | ✓ |
| 9 | Deck Assignment Lifecycle Ledger | R9 | 5 | 5 | ✓ | ✓ |
| 10 | Versions & Printings Navigation | R10 | 5 | 5 | ✓ | ✓ |
| 11 | Resilient Image Caching & Recovery | R11 | 5 | 5 | ✓ | ✓ |

## Test Target Files
- `test/features/vault/vault_patch49_filtering_pagination_test.dart`
- `test/features/decks/tcg_context_sync_patch49_test.dart`
- `test/features/vault/card_detail_collapsible_header_patch49_test.dart`
- `test/features/vault/card_mechanics_dedup_patch49_test.dart`
- `test/features/vault/unowned_card_metrics_actions_patch49_test.dart`
- `test/features/decks/automated_deck_ledger_lifecycle_patch49_test.dart`
- `test/features/vault/card_detail_printings_navigation_patch49_test.dart`
- `test/core/cache/countr_cached_image_resilience_patch49_test.dart`
