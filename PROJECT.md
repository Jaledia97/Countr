# Project: Countr Phase 3.9

## Architecture
Countr is a Flutter / Dart application for trading card portfolio management and gameplay tracking.
- **Frontend / Presentation**: Flutter Material 3 with Riverpod state management (`flutter_riverpod`).
- **Data Persistence**: Drift SQLite database (`app_database.dart`) with reactive DAOs (`VaultDao`).
- **Data Ingestion / Hydration**: Scryfall JSON parsing in background isolates (`scryfall_parser.dart`).
- **Core Feature Areas in Phase 3.9**:
  - `lib/features/hydration/domain/isolate/scryfall_parser.dart`: Card parsing, DFCs vs Adventures, Universes Beyond detection, Secret Lair code preservation.
  - `lib/features/vault/presentation/widgets/card_detail_sheet.dart` & `full_screen_card_viewer.dart`: Flip suppression for Adventures, unified rules box, `PageView.builder` swiping across active list, full-screen sync.
  - `lib/features/vault/presentation/widgets/vault_item_tile.dart` & `vault_item_card.dart`: Pricing fallback hierarchy ("Check" -> "Unlisted"), top-right 3x grid duplicate badges, list view artwork thumbnails.
  - `lib/features/vault/presentation/screens/vault_screen.dart`: Background scroll synchronization (`_scrollToCardIndex`), filter button with active badge.
  - `lib/features/vault/presentation/providers/mtg_filter_state.dart` & `lib/features/vault/presentation/widgets/mtg_filter_sheet.dart`: ManaBox-style filter state and modal bottom sheet with [Collection] and [General] tabs.
  - `lib/features/vault/data/daos/vault_dao.dart`: Reactive filtering matching `MtgFilterState` criteria.

## Feature Inventory
| # | Feature | Description | Milestone | Source |
|---|---------|-------------|-----------|--------|
| 1 | DFC Flip Animation Retention | DFCs (`transform`, `modal_dfc`, `reversible_card`) retain 3D flip animation & face toggles | M1 | Survey R1 |
| 2 | Adventure Flip Suppression | Adventure cards (`layout == 'adventure'`) strictly disable 3D flip buttons and face switchers | M1 | Survey R1 |
| 3 | Adventure Unified Rules Box | Adventure cards render creature permanent and adventure spell text together in a single rules box | M1 | Survey R1 |
| 4 | Universes Beyond Detection | Detect via `promo_types` contains `'universes_beyond'`, `frame_effects` contains `'universesbeyond'`, or `security_stamp == 'triangle'`; store boolean `is_universes_beyond` in SQLite | M1 | Survey R1 |
| 5 | Secret Lairs & Flavor Search | Preserve set code `'sld'` and `'Secret Lair Drop'` so they are indexed, queryable, and filterable; retain flavor name search | M1 | Survey R1 |
| 6 | Eliminate Literal "Check" | Remove literal string `"Check"` across `VaultItemTile`, `VaultItemCard`, and `CardDetailSheet` | M2 | Survey R2 |
| 7 | Pricing Fallback Hierarchy | Evaluate price in order: `usd` -> `usd_foil` -> `usd_etched` -> `eur` -> `eur_foil`, resolving `0.00` parsing bug | M2 | Survey R2 |
| 8 | Unlisted Price Labeling | Display `"Unlisted"` or `"—"` when no market price exists | M2 | Survey R2 |
| 9 | 3x Grid Quantity Badges | Position badge at top-right corner, high contrast semi-opaque dark background (alpha >= 0.85), bold white text, visible when `quantity > 1` (or unowned `quantity == 0`) | M3 | Survey R3 |
| 10 | List View Art Thumbnails | Replace 38x38 placeholder type icon with rounded art thumbnail (`image_uris['small']` or fallback) | M3 | Survey R3 |
| 11 | Card Detail Swiping | Wrap `CardDetailSheet` and `FullScreenCardViewer` in `PageView.builder` bound to active filtered Vault list | M4 | Survey R4 |
| 12 | Background Scroll Tracking | Programmatically scroll underlying Vault list/grid on swiping (`onPageChanged`) so dismiss centers on current card | M4 | Survey R4 |
| 13 | FullScreenCardViewer Sync | Opens at exact current index with continuous swiping, synchronizing back with detail sheet | M4 | Survey R4 |
| 14 | MTG Filter State & Provider | Riverpod `MtgFilterState` model and `mtgFilterProvider` managing all active filter criteria | M5 | Survey R5 |
| 15 | MTG Filter Sheet Modal | ManaBox-style modal bottom sheet accessible from Vault search/filter bar with `[ Collection ]` and `[ General ]` tabs | M5 | Survey R5 |
| 16 | MTG Filter Criteria Implementation | All filters: Colors & Identity (modes: Exactly, At most, Including, Commander; Target; WUBRGC; Count slider), Types & Oracle text clauses, Mana Cost & CMC range slider, Sets & Rarity, Stats (=, >, <), Layouts pills, Treatments (Reserved, UB, Promo, Reprint, Altered, Misprint, Finishes), Collection (Condition, Language) | M5 | Survey R5 |
| 17 | VaultDao Reactive Filtering | Extend `VaultDao` queries to filter reactively on all active `MtgFilterState` criteria | M5 | Survey R5 |
| 18 | E2E Test Suite Pass (Tiers 1-4) | Pass 100% of requirement-derived E2E test suite with zero regressions | M6 | Acceptance |
| 19 | Adversarial Coverage Hardening | Tier 5 adversarial stress testing and gap audit | M6 | Acceptance |

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| M1 | Card Parsing & Layout Metadata | `scryfall_parser.dart`, Universes Beyond detection, Secret Lair preservation, DFC vs Adventure flip suppression & unified rules box | none | DONE |
| M2 | Pricing Fallbacks & Labeling | Eliminate "Check", robust price resolution hierarchy (`usd` -> `usd_foil` -> `usd_etched` -> `eur` -> `eur_foil`), "Unlisted" fallback | M1 | DONE |
| M3 | Vault UI Polish | 3x grid top-right high-contrast quantity badge, list view artwork thumbnails with graceful fallbacks | M2 | DONE |
| M4 | Swiping & Scroll Synchronization | `PageView.builder` in `CardDetailSheet` and `FullScreenCardViewer`, background scroll tracking in `VaultScreen` | M3 | DONE |
| M5 | Advanced MTG Filter Sheet & DAO | `MtgFilterState`, `mtgFilterProvider`, `MtgFilterSheet` modal UI, reactive `VaultDao` queries | M1, M4 | DONE |
| M6 | Final E2E Pass & Hardening | 100% pass on E2E test suite (Tiers 1-4) + Tier 5 adversarial coverage hardening | M1, M2, M3, M4, M5 | DONE |

## Interface Contracts
### `scryfall_parser.dart` ↔ `VaultDao` / `VaultItems`
- `dynamicData['is_universes_beyond']`: `bool` indicating Universes Beyond card.
- `dynamicData['promo_types']`: `List<dynamic>` from Scryfall card.
- `dynamicData['frame_effects']`: `List<dynamic>` from Scryfall card.
- `dynamicData['security_stamp']`: `String` from Scryfall card.
- `dynamicData['set']` / `set_code`: `String` (lowercase 3-letter set code, e.g. `'sld'`).
- `dynamicData['layout']`: `String` (`'adventure'`, `'transform'`, `'modal_dfc'`, etc.).

### `CardDetailSheet` & `FullScreenCardViewer`
- Constructor:
  ```dart
  const CardDetailSheet({
    super.key,
    this.item,
    this.items,
    this.initialIndex = 0,
    this.onPageChanged,
  });
  ```
- Static show:
  ```dart
  static Future<void> show(
    BuildContext context,
    VaultItem item, {
    List<VaultItem>? items,
    int? initialIndex,
    ValueChanged<int>? onPageChanged,
  });
  ```

### `MtgFilterState` & `mtgFilterProvider`
- Model definition in `lib/features/vault/presentation/providers/mtg_filter_state.dart`:
  - Enums: `ColorMatchMode { exactly, atMost, including, commander }`, `ColorTarget { cardColor, colorIdentity }`
  - Sets: `colors` (W, U, B, R, G, C), `rarities`, `layouts`, `finishes`, `conditions`, `languages`
  - Sliders: `colorCountRange` (0 to 5), `cmcRange` (0 to 16+)
  - Inputs: `typeLine`, `oracleTextClauses`, `manaCost`, `setCode`, `setOperator`
  - Stats: `List<MtgStatFilter>` (stat: power/toughness/loyalty/defense, operator: '=', '>', '<', value: String)
  - Flags: `isReserved`, `isUniversesBeyond`, `isPromo`, `isReprint`, `isAltered`, `isMisprint`, `isGraded`, `isSigned`
  - Methods: `copyWith()`, `reset()`, `matches(VaultItem item) -> bool`, `activeCount -> int`, `isActive -> bool`

## Code Layout
- `lib/features/hydration/domain/isolate/scryfall_parser.dart` — Scryfall card mapping
- `lib/features/vault/domain/vault_pricing_helper.dart` — Canonical price resolution helper
- `lib/features/vault/presentation/widgets/vault_item_tile.dart` — 3x grid card tile, badges, pricing
- `lib/features/vault/presentation/widgets/vault_item_card.dart` — List view card row, thumbnail, pricing
- `lib/features/vault/presentation/widgets/card_detail_sheet.dart` — Card detail modal, swiping, DFC/Adventure handling
- `lib/features/vault/presentation/widgets/full_screen_card_viewer.dart` — Full screen viewer, swiping, foil, DFC flip
- `lib/features/vault/presentation/screens/vault_screen.dart` — Vault UI, background scroll tracking, filter trigger
- `lib/features/vault/presentation/providers/mtg_filter_state.dart` — MTG filter state and Riverpod provider
- `lib/features/vault/presentation/widgets/mtg_filter_sheet.dart` — ManaBox-style MTG filter sheet
- `lib/features/vault/data/daos/vault_dao.dart` — Reactive database queries and filtering
- `test/` — Comprehensive unit, widget, and integration tests
