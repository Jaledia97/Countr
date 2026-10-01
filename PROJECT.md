# Project: Countr Patch 4.9 Master Specification

## Architecture
Countr Patch 4.9 delivers enhancements and defect remediation across catalog search, cross-screen navigation synchronization, card details sliver architecture, inventory metrics, automated deck lifecycle tracking, and image caching resilience:

1. **Catalog & Database Query Engine (`lib/features/vault/`, `lib/core/database/`)**:
   - Case-sensitive SQLite pushdown (`GLOB` and `json_extract`) in `VaultDao._applyMtgFilterStage1` for color filtering, avoiding lowercase substring collisions in JSON metadata.
   - Decoupled SQLite LIMIT and in-memory filtering: ensure query streams collect up to the requested window size from filtered results (`.take(limit)`).
   - Dynamic pagination recovery in `VaultScreen._onScroll` to prevent starvation deadlocks when active catalog filters yield fewer than 70% of raw rows.

2. **Cross-Screen Navigation & State Synchronization (`lib/features/decks/`, `lib/features/vault/`, `lib/core/state/`)**:
   - Bidirectional TCG context synchronization (`TcgContextSync`) between `activeGameContextProvider` (Vault) and `activeDeckTcgFilterProvider` (Decks) hosted in `MainShellScreen`.
   - Inclusion of `'Disney Lorcana'` across Vault collection models, normalization methods, and UI chips.
   - Deep printing navigation in `VariantPriceChart`: tapping candidate printings pushes a distinct `CardDetailSheet` rather than swapping local preview state in-place.

3. **Collapsible Sliver Card Details Architecture (`lib/features/vault/presentation/widgets/`)**:
   - `NestedScrollView` architecture for `CardDetailSheet._buildCardPage` featuring a collapsible hero art header sliver (`_CollapsibleCardArtHeaderDelegate`) and pinned `[ Details | Values ]` tab bar.
   - Consistent art collapse behavior across both Details and Values tabs while preserving inner `ListView` scroll physics.
   - Case-insensitive Set deduplication in `_buildCardMechanicsAndRulings` ensuring 0 duplicate keyword tags and glossary items.

4. **Inventory Action Routing & Terminology (`lib/features/vault/presentation/widgets/`)**:
   - Dynamic inventory status displays `"owned"` or `"unowned"` based on `item.quantity > 0` replacing static `'Catalog Item'`.
   - Omission of the `'quick_action_delete'` button for unowned reference/catalog cards.
   - Removal of the standalone `'card_detail_add_to_vault'` header button.
   - Introduction of `'quick_action_add_to_plus'` on unowned cards routing to Binders or Decks (with unowned-in-deck proxy warnings preserved).

5. **Automated Deck Assignment & Lifecycle Ledger (`lib/features/vault/`, `lib/core/database/daos/`)**:
   - Removal of manual text input for deck assignment history in `_buildDeckHistoryLedger`.
   - Lifecycle-aware synchronization in `VaultDao._syncItemDeckHistory`: cards in assembled decks (`is_assembled == 1`) update formal deck history, while cards in non-assembled decks generate dated ledger entries formatted as `Drafted in - [Deck Name]`.
   - Automatic cascade sync in `VaultDao.setDeckAssembled`, `setDeckRegistered`, and `deleteDeck`.
   - Distinct, compact rendering of draft ledger entries in `_buildLedgerEntryRow`.

6. **Resilient Image Caching & Fast Scroll Recovery (`lib/core/cache/`, `lib/features/`)**:
   - `CountrCachedImage` converted to a self-healing stateful widget with transient cancellation retry and backoff cooldown.
   - Harmonized cache keys using `CountrImageCacheManager.cardArtKey(cardId)` across all screens.
   - Passing `cardName` and `tcgDomain` across all callers to enable Scryfall named redirect fallbacks.
   - Translucent hit testing and thumbnail `IgnorePointer` wrappers ensuring parent card tap gestures pass through cleanly.

---

## Feature Inventory
| # | Feature | Description | Milestone | Source | Status |
|---|---------|-------------|-----------|--------|:------:|
| 1 | Full Scryfall Catalog Filtering | Case-sensitive GLOB/json_extract for colors/formats/stats, decouple SQLite LIMIT from in-memory stream filtering, pagination deadlock fix | M1 | R1 | DONE |
| 2 | Resilient Image Caching & Recovery | Self-healing CountrCachedImage with transient retry, unified cacheKey via cardArtKey, fallback named redirect wiring | M1 | R11 | DONE |
| 3 | Cross-Screen TCG Context Sync | Bidirectional sync between activeGameContextProvider and activeDeckTcgFilterProvider, Lorcana collection normalization | M2 | R2 | DONE |
| 4 | Versions & Printings Navigation | Tapping alternate printing candidate pushes distinct CardDetailSheet route | M2 | R10 | DONE |
| 5 | Collapsible Card Art Header | NestedScrollView with collapsible art sliver and pinned tabs across Details and Values | M3 | R3 | DONE |
| 6 | Card Mechanics Tag Deduplication | Case-insensitive Set deduplication for keyword chips and glossary entries | M3 | R4 | DONE |
| 7 | Portfolio & Metrics Terminology | Accurate "owned" vs "unowned" status based on quantity > 0 replacing static "Catalog Item" | M4 | R5 | DONE |
| 8 | Remove Delete for Unowned Items | Hide quick_action_delete on unowned reference cards in quick action bar | M4 | R6 | DONE |
| 9 | Unowned Routing via "Add to +" | Replace "Add to deck" with "Add to +" modal (Binders/Decks routing with proxy warning), remove standalone "Add to vault" button | M4 | R7 | DONE |
| 10 | Automated Deck Assignment Tracking | Remove manual text input box and button from deck history ledger, fully system-managed | M5 | R8 | DONE |
| 11 | Deck Assignment Lifecycle Ledger | Formal assignment only on is_assembled == 1; non-assembled formatted as "Drafted in - [Deck Name]"; sync on assemble & delete | M5 | R9 | DONE |
| 12 | Comprehensive E2E Regression Tests | Automated regression tests verifying all 11 objectives across Tiers 1-4 | M6 | Acceptance Criteria | DONE |
| 13 | Static Analysis & Integrity Audit | dart/flutter analyze 0 issues, flutter test 100% pass, clean forensic integrity audit | M6 | Acceptance Criteria | DONE |

---

## Milestones

| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| 1 | M1: Catalog Filtering & Image Caching Resilience | R1 (GLOB/json_extract color filter, pagination starvation fix), R11 (Self-healing CountrCachedImage, cacheKey unification) | none | DONE |
| 2 | M2: TCG Context Sync & Printings Navigation | R2 (TcgContextSync bidirectional sync, Lorcana support), R10 (Printing candidate navigation to distinct CardDetailSheet) | none | DONE |
| 3 | M3: Collapsible Art Header & Mechanics Deduplication | R3 (NestedScrollView collapsible header across tabs), R4 (Case-insensitive keyword/glossary deduplication) | none | DONE |
| 4 | M4: Inventory Terminology & Unowned Action Routing | R5 ("owned"/"unowned" status), R6 (Remove delete for unowned), R7 ("Add to +" selector modal, remove standalone "Add to vault") | none | DONE |
| 5 | M5: Deck Assignment Lifecycle Ledger | R8 (Remove manual text input), R9 (Assembled vs Drafted in ledger lifecycle, cascade assemble & delete sync, ledger row styling) | none | DONE |
| 6 | M6: Dual-Track E2E Test Suite & Final Audit | Tiers 1-4 E2E regression tests, 100% test pass, flutter analyze 0 issues, Forensic Integrity Audit | M1, M2, M3, M4, M5 | DONE |

---

## Interface Contracts

### 1. Catalog Filtering & Pagination (`lib/features/vault/data/daos/vault_dao.dart`)
- `_applyMtgFilterStage1`:
  ```dart
  // Colors use case-sensitive SQLite GLOB matching JSON arrays:
  // e.g. json_extract(vault_items.dynamic_data, '$.colors') GLOB '*"R"*'
  // Decoupled SQLite LIMIT from in-memory stream filtering (.take(limit))
  ```
- `VaultScreen._onScroll`:
  ```dart
  // Trigger pagination limit update whenever scroll nears bottom when active filters are engaged
  ```

### 2. Image Caching (`lib/core/cache/countr_cached_image.dart`)
- `CountrCachedImage`:
  ```dart
  class CountrCachedImage extends StatefulWidget {
    final String imageUrl;
    final String? cacheKey;
    final String? cardName;
    final String? tcgDomain;
    // Auto-retries on transient failure with exponential backoff and Scryfall named URL fallback
  }
  ```

### 3. TCG Context Sync (`lib/core/state/tcg_context_sync.dart`)
- Bidirectional translation between `activeGameContextProvider` and `activeDeckTcgFilterProvider`.
- Continuous sync via `TcgContextSync.bindSync` and post-frame branch listener in `MainShellScreen`.

### 4. Card Details Sliver Structure (`lib/features/vault/presentation/widgets/card_detail_sheet.dart`)
- `NestedScrollView` with collapsible hero header sliver and pinned `[ Details | Values ]` tab bar.
- Inner list views pass through scroll notifications without controller conflicts.

### 5. Unowned Card Routing (`lib/features/vault/presentation/widgets/card_detail_sheet.dart`)
- `quick_action_add_to_plus`: Presents modal bottom sheet with Binders and Decks destinations.
- `quick_action_delete`: rendered ONLY if `item.quantity > 0`.
- Standalone `card_detail_add_to_vault` button completely removed.

### 6. Deck Assignment Ledger (`lib/features/vault/data/daos/vault_dao.dart`)
- `_syncItemDeckHistory(String vaultItemId)`:
  - Assembled (`d.is_assembled == 1`): stored in `deck_history`.
  - Non-assembled (`d.is_assembled == 0`): stored in `assignment_history` as `'Drafted in - ${d.name} - $dateStr'`.
- Cascade sync across `setDeckAssembled`, `setDeckRegistered`, and `deleteDeck`.

---

## Code Layout
```
lib/
├── core/
│   ├── cache/
│   │   ├── countr_cached_image.dart         # Self-healing image widget with retry & fallback
│   │   └── countr_image_cache_manager.dart  # Key generation & disk cache helpers
│   ├── database/
│   │   └── daos/vault_dao.dart              # GLOB filtering, deck assignment lifecycle sync, delete cascade
│   └── state/
│       └── tcg_context_sync.dart            # Bidirectional TCG context bridge & bindings
├── features/
│   ├── decks/presentation/screens/
│   │   └── decks_screen.dart                # TCG filter synchronization listener
│   ├── shell/presentation/screens/
│   │   └── main_shell_screen.dart           # Global TCG context bridge attachment
│   └── vault/presentation/
│       ├── screens/vault_screen.dart        # Pagination starvation fix, Lorcana chip & title
│       └── widgets/
│           ├── card_detail_sheet.dart       # Collapsible sliver header, mechanics dedup,
│           │                                # unowned status, "Add to +" modal, auto ledger
│           ├── catalog_card_list_tile.dart  # Standardized cacheKey & cardName
│           ├── variant_price_chart.dart     # Tapping printing pushes distinct CardDetailSheet
│           └── vault_item_card.dart         # Standardized cacheKey & cardName
test/
├── core/cache/
│   ├── countr_cached_image_test.dart
│   ├── countr_cached_image_resilience_patch49_test.dart
│   ├── countr_image_cache_manager_test.dart
│   └── countr_cached_image_adversarial_stress_test.dart
├── features/decks/
│   ├── tcg_context_sync_patch49_test.dart
│   ├── tcg_sync_test.dart
│   ├── automated_deck_ledger_lifecycle_patch49_test.dart
│   └── automated_deck_ledger_adversarial_stress_test.dart
└── features/vault/
    ├── vault_patch49_filtering_pagination_test.dart
    ├── vault_dao_adversarial_stress_test.dart
    ├── card_detail_collapsible_header_patch49_test.dart
    ├── card_detail_collapsible_adversarial_stress_test.dart
    ├── card_detail_printings_nav_test.dart
    ├── card_detail_printings_navigation_patch49_test.dart
    ├── card_mechanics_dedup_patch49_test.dart
    ├── card_mechanics_dedup_adversarial_stress_test.dart
    └── unowned_card_metrics_actions_patch49_test.dart
```
