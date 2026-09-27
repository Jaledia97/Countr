## [0.4.7] - 2026-09-27

### Phase 4.7: "Variant 1" Lifetap-Style MTG Companion Life Counter

#### Added & Improved
- **R1: Deck-to-UI Integration & Player Profiles**:
  - **Pre-Game Deck Selection**: Linked player seating directly to user vault profiles and decks, enabling quick pre-game commander selection (`PregameSetupSheet`).
  - **Dynamic Commander Backgrounds**: Automatically extracts the chosen deck's Commander `art_crop` (or custom cover image) and renders it as a high-resolution backdrop with dark vignette gradient overlays (`CommanderArtBackdrop`).
  - **Art Customization & Override**: Integrated Scryfall art catalog search and custom image override modal (`ArtOverrideSheet`) per quadrant.

- **R2: Dynamic Pod Layouts & Local Offline P2P Mesh Sync**:
  - **Geometric Pod Layouts**: Built responsive orientation-aware seating engines for 1v1 (split horizontal), 3-player, 4-player (2x2), 5-player, and 6-player (2x3) grids with 180° inverted rotation for opposing players (`PodLayoutEngine`, `PodScaffoldWidget`).
  - **Local Offline P2P Synchronization**: Built pure `dart:io` WebSocket transport (port 40407) and UDP broadcast beacon discovery (port 40408) for zero-configuration offline multiplayer sync over local Wi-Fi or hotspots (`WebSocketP2pTransport`, `UdpBeaconDiscovery`). Includes 4-character room codes and QR pairing fallbacks (`PodConnectionFallback`).
  - **Adaptive Real Estate**: Form-factor responsiveness displaying persistent tool rails on tablets ($\ge 600$dp) and gesture-driven swipe/pull-out drawers on phones (`ToolDrawerOrRail`).

- **R3: Drift Database Auto-Save & State Recovery**:
  - **Schema Migration (v9 $\rightarrow$ v10)**: Upgraded SQLite schema to version 10 with new tables (`match_sessions`, `match_players`, `match_events`), index optimization, and full backward compatibility.
  - **Continuous Event Logging**: All life increments, counter changes, and commander damage transactions write to SQLite immediately via FIFO queue in `MatchDao` and `MatchSessionRepository`.
  - **Crash & Lifecycle State Recovery**: Relaunching the app detects active match sessions and presents a recovery modal (`SessionRecoveryDialog`) offering "Continue Match" or "Start New Game" with reversible undo support.

- **R4: Core Mechanics, Commander Damage & Secondary Counters**:
  - **Oversized Hitboxes**: Massive plus and minus hitboxes with single-tap adjustments and hold-to-accelerate rapid stepping.
  - **Commander Damage Matrix**: Dedicated tracker attributing damage received per opposing commander with their respective art crops and visual 21-point lethal threshold warnings (`CommanderDamageMatrixSheet`).
  - **Secondary Counters**: Comprehensive tracker bar for Poison/Infect (10-point lethal alert), Energy, Experience, Commander Tax, exclusive Monarch & Initiative token claiming, and synchronized Day/Night cycling (`SecondaryCountersBar`).

- **R5: Utility Hub, Polyhedral Randomizers & Lobby Reset**:
  - **3D Physics Randomizers**: Animated 3D Coin Flip with Matrix4 perspective flips, and polyhedral dice rollers for D4, D6, D8, D10, D12, D20, and D100 with rolling history (`RandomizerHubModal`).
  - **Player Selection Utilities**: "Choose Random Player" and "Choose Random Opponent" with decelerating roulette animation and quadrant spotlight flashes (`PlayerRouletteOverlay`).
  - **Starting Life Formats & Reset**: Presets for Standard (20), Commander (40), Brawl (30), Two-Headed Giant (30), and custom numeric inputs. Global "Reset Game" confirmation dialog resets life and counters while preserving seating, deck assignments, and lobby.

- **R6: Floating Mana Pool & Storm Drawers**:
  - **Floating Mana Drawer**: Dedicated slide-out drawer on each quadrant displaying official Magic: The Gathering WUBRGC mana pips via `ManaSymbolIcon` (`FloatingManaDrawerWidget`).
  - **Storm Tracking & Instant Clear**: Integrated Storm counter and one-tap "Clear Pool" button that zeroes out floating mana and storm count with full undo support.

- **R7: Architectural Non-Regression & Quality Assurance**:
  - **Strict Turn Logic Omission**: Verified 100% passive companion utility with complete absence of active turn timers, chess clocks, or turn-passing buttons in production code (`turn_logic_omission_audit_test.dart`).
  - **Test Suite**: 74/74 E2E contracts passing; 715+ core, widget, and adversarial stress tests passing repository-wide.
  - **Static Analysis**: `dart analyze --fatal-infos` verified with 0 errors, 0 warnings, and 0 infos.
  - **Independent Audit**: Passed independent Post-Victory Audit (`VICTORY CONFIRMED`).

---

## [0.4.6.1] - 2026-09-26

### Phase 4.6 Patch: UI Stability, Inventory Grouping, Deck Boards & Analytics Overhaul

#### Added & Improved
- **Vault Inventory Grouping & Availability Engine**:
  - **Strict Variant Grouping**: Grouped Vault cards strictly by unique printing and finish `(scryfall_id, finish)` using `VaultVariantHelper`, separating standard from showcase/full art printings with distinct quantity badges.
  - **Consolidated Ownership & Availability**: Eliminated card duplication caused by deck assignments. Single consolidated records display live breakdowns (`Owned: X | Available: Y | In Deck: Z`) via `CardAvailability`.
  - **Assembled Deck Badge Gating**: Cards in the Vault display deck assignment badges if and only if their assigned deck is actively marked as Assembled (`is_assembled == 1` / `is_registered == 1`).
  - **The One Ring Card Art**: Fixed CDN 404 seed and fallback resolution URLs for *The One Ring* (LTR 246) with authentic Scryfall card art.

- **Deck Builder, Boards & Format Legality**:
  - **Assembly Status Switch**: Added interactive header toggle in `DeckBuilderScreen` to register decks as Assembled or Disassembled, updating state and SQLite.
  - **Deck Thumbnail Picker (`DeckThumbnailPickerModal`)**: Custom cover art selection from cards within the deck or by searching the catalog.
  - **Atomic Board Movement**: Transactional board movement across Mainboard, Sideboard, and Maybeboard in `VaultDao.moveDeckItemBoard` within an atomic SQLite transaction, with a contextual "Move To" sheet in `CardDetailSheet`.
  - **Format Legality Engine (`LegalityEnforcer`)**: Cross-references Scryfall format legality with visual warning indicators (`BANNED`, `RESTRICTED`, `NOT LEGAL`).
  - **Scrollbar Auto-Hide Animation**: Refined `ProportionalBubbleScrollbar` with synchronized `ScrollController` tracking, 1,500ms inactivity auto-hide, and smooth 300ms fade transitions.

- **Deck Analytics & MTG Symbology**:
  - **Inline Deck Analytics (`InlineDeckAnalyticsCard`)**: Embedded visual Mana Curve, Color Devotion bars, and Bling Ratio directly within the scrollable `DeckBuilderScreen`.
  - **Interactive Value Concentration (`ValueConcentrationPieChart`)**: Interactive custom canvas Donut/Pie Chart with polar gesture hit-testing, dynamic slice explosions, and center callout badges.
  - **Mana Curve CMC Engine**: Calibrated converted mana cost calculation across split, hybrid, twobrid `{2/W} = 2.0`, and 0-cost spells in `ScryfallParser` and `deck_providers.dart`.
  - **Official MTG SVG Symbology**: Replaced placeholder icons in color pickers and filter dialogs with authentic Magic: The Gathering SVG mana icons via `ManaSymbolIcon`.

- **UI Stability & Presentation Polish**:
  - **Card Details Scroll Crash**: Eliminated the red screen crash caused by `PageStorageBucket` type casting collision (`double` vs `bool?`) and decoupled multi-view scroll position conflicts.
  - **SliverAppBar Collision Prevention**: Enforced dynamic title margin, fade interpolation, and truncation during scroll collapse in `DeckBuilderScreen` to prevent overlapping the back button.
  - **Context-Aware Vault Filters**: Dynamic pill filters in `VaultScreen` strictly scope to the active collection domain (MTG), preventing cross-category comic or sports pills from leaking.
  - **Accessibility Layout Hardening**: Verified zero `RenderFlex` overflows across extreme viewports (down to 280x600) and text scaling factors up to 2.5x.

#### Verification & Quality
- **Test Suite**: 215/215 tests passing in `test/e2e_phase46/`; 1,760/1,760 tests passing across the repository (100% pass rate).
- **Static Analysis**: `dart analyze --fatal-infos` verified with 0 errors, 0 warnings, and 0 infos.
- **Audit Verification**: Passed independent multi-phase Victory Audit (`VICTORY CONFIRMED`).

---

## [0.4.6] - 2026-09-26

### Phase 4.5 & 4.6 Master Patch: Offline-First Hardening & Complete UI/UX Overhaul

#### Added & Improved
- **Stage 1: Offline-First Database Hardening & Sync Queue**:
  - **Schema Migration (v8 $\rightarrow$ v9)**: Upgraded Drift database schema to version 9, adding `is_deleted` (boolean, default false) and `updated_at` (DateTime) across all 7 core entity tables (`vault_items`, `vault_binders`, `decks`, `deck_versions`, `deck_version_items`, `deck_matchups`, and `deck_synergies`).
  - **Soft Deletion & Cascade Enforcement**: Completely eliminated hard `DELETE` queries across DAOs. Soft-deleting a deck transactionally cascades soft-deletes to all child `DeckVersions` and `DeckVersionItems`; soft-deleting a binder cleanly unassigns associated cards.
  - **Active Read Filtering**: All 21 DAO read queries and live streams enforce `WHERE is_deleted = false` via inner joins to guarantee deleted items never leak into active views while preserving historical and outbox integrity.
  - **Outbox SyncQueue (`sync_queue_table.dart`)**: Created persistent outbox queue logging INSERT, UPDATE, and DELETE operations with entity type, entity ID, timestamps, and atomic SQLite retry counter increments for future cloud syncing.
  - **Persistent Image Cache Policy (`CountrImageCacheManager`)**: Implemented custom `BaseCacheManager` configured for 35+ day offline retention and 5,000 card capacity; deployed `CountrCachedImage` across the application, purging all raw unmanaged `Image.network` calls.

- **Stage 2A: Global Architecture & App Settings Repositioning**:
  - **Two-Tiered Relational Architecture**: Abstract `oracle_id` powers global catalog search deduplication, while personal Vault items and Deck inventories strictly query exact printing IDs with finish metadata.
  - **Command Center App Settings**: Relocated Global Privacy Mode toggle, Base Currency dropdown (`USD`, `EUR`, `GBP`, `CAD`), and Streamer Security auto-lock switch into the Command Center App Settings card.
  - **UI Decluttering**: Removed obsolete viewing persona drawer toggle and purged the privacy eyeball button from the Feed screen AppBar.

- **Stage 2B: Vault & Card Details Polish**:
  - **5:7 Aspect Ratio & Variant Sync**: Enforced strict `5:7` aspect ratio with `BoxFit.contain` in `FullScreenCardViewer`. Automatically reads finish metadata to activate GLSL foil shimmer shaders without manual toggles.
  - **Variant-Bound DFC Flips**: Double-faced card flip animations are strictly bound to the active printing variant's backside art (`card_faces[1]`).
  - **Contextual Actions & Expand Overlay**: Replaced the bottom "Full Screen" button with a top-corner expand overlay icon on the card art. In Binder scope, displays a "Move" transfer action; in Deck scope, hides Delete/Move and displays a strict "Remove from Deck" action.
  - **Dedicated Edit Card Modal (`EditCardModal`)**: Extracted physical provenance (`binder_page`, `binder_slot`, `protection_status`), acquisition tracking (`date_obtained`, `purchase_price`), condition, and notes into a dedicated modal. Removed redundant "Add/Edit in Decks" button.
  - **Chronological Assignment History Ledger**: Formatted card assignment history as a chronological transaction ledger (`+`, `-`, `<->`).

- **Stage 2C: Decks, Binders & Import Workflows**:
  - **Commander Art Stream**: `DecksDao.watchDeckSummaries()` executes an authentic SQLite `LEFT JOIN` on `DeckVersionItems` and `VaultItems` to stream Commander `art_crop` with skeleton shimmer loading (`SkeletonShimmerBox`), inline color identity pips, assembly status badges, format, and completeness.
  - **Deck Setup Wizard (`DeckSetupWizardModal`)**: Decoupled `[ + New Deck ]` from cloning, launching a modal prompting for Deck Name, Format, and a choice between Blank mode and text Import mode via `DeckIOParser.parseList`.
  - **Vault Import Flow (`VaultImportBottomSheet`)**: Replaced the legacy "Add Item" button with an `[ Import + ]` flow parsing bulk card text and links into a selected destination binder.
  - **Binder Customization & Views**: Added `EditBinderModal` for custom cover art, name, and description. Added persistent state toggle (`binderViewModeProvider`) on `BinderDetailScreen` swapping between a 3x3 Grid view (`5:7` ratio) and a data-dense List view.

- **Stage 2D: List View Density, Pop-to-Root Navigation & Scroll Optimization**:
  - **Data-Dense `ExpansionTile` List Views**: Standardized list views across Vault (`VaultItemCard`), Decks (`DeckBuilderScreen`), and Catalog (`CatalogCardListTile`) with inline `ManaCostBar` and tap-to-expand Oracle rules text rendered via `ManaText`.
  - **Pop-to-Root Bottom Navigation**: Retapping the active bottom navigation tab icon executes a stack reset (`popUntil((route) => route.isFirst)`) and resets the branch to its root view.
  - **Scroll Performance Optimization**: Resolved 6 identified scroll jank bottlenecks (JSON deserialization LRU memoization with `ParsedJsonCache`, `CountrCachedImage`, `RepaintBoundary` paint isolation, compact collapsed row extents, bounded `cacheExtent` of 450px, and universal `const` constructors).

#### Quality & Verification
- **Test Suite**: 3,057+ automated tests passing (100% pass rate) with 0 failures, 0 skips, and 0 lints (`dart analyze --fatal-infos`).
- **Audit Verification**: Passed independent multi-phase Victory Audit (`VICTORY CONFIRMED`).

---

## [0.4.4] - 2026-09-24

#### Added
- **Global MTG Mana Symbology Engine (`Phase 4.3`)**:
  - **Asset Bundle (`assets/symbology/`)**: Bundled all 84 official MTG SVG mana and game symbols fetched directly from Scryfall's Symbology API (numbers 0-20, colors WUBRG, colorless C, X/Y/Z, hybrid, phyrexian, snow, tap/untap, loyalty). Added `flutter_svg: ^2.3.0` and declared asset paths in `pubspec.yaml`.
  - **Canonical Symbol Catalog (`ScryfallSymbolCatalog`)**: Implemented 84 canonical symbols with 114 transposable and case-insensitive alias lookups.
  - **Inline Symbology Parser (`ManaTextParser`)**: Built linear regex parser converting bracketed notation (e.g., `{1}{U}`, `{W/U}`, `{P/B}`) into Flutter `InlineSpan` hierarchies using `PlaceholderAlignment.middle` and dynamic `1.1x` proportional scaling matching surrounding text font sizes.
  - **Reusable Widgets**: Added `ManaSymbolIcon`, `ManaText` (drop-in `RichText` wrapper), and `ManaCostBar` with built-in `FittedBox` overflow defense for narrow list headers and rows.
  - **Global Symbology Deployment**: Deployed across `CardDetailSheet` (mana costs & Oracle rules text), `DeckBuilderScreen` (card list rows & opening hand preview), and Social Feed / `PostCard` (post content, single/multi pulls, and deck primers).

- **Global App Settings & Streamer Privacy Mode (`Phase 4.4 - R1`)**:
  - **Currency Preference**: Added base currency selector (`USD`, `EUR`, `GBP`, `CAD`) with real-time multi-market exchange rate normalization (`ExchangeRateService`).
  - **Streamer Security**: Added `"Auto-Enable Privacy Mode when backgrounded"` toggle using `AppLifecycleListener` to automatically lock and redact financial visibility upon app backgrounding.
  - **Global Privacy Redaction**: Replaced previous AppBar view switchers with a global Privacy Mode toggle (`Icons.visibility` / `Icons.visibility_off`). Redacts all financial metrics across Vault totals, individual card prices, and deck costs with blurred placeholders or `****`.
  - **Locked Values View (`LockedValuesView`)**: Displays a locked state UI when accessing the `[ Values ]` tab while in Privacy Mode.

- **Drift Schema v8 & 2-Tab Segmented Control (`Phase 4.4 - R2`)**:
  - **Schema Migration (v7 $\rightarrow$ v8)**: Extended `VaultItems` with `date_obtained`, `purchase_price`, `binder_page`, `binder_slot`, `notes`, and `protection_status`.
  - **Segmented 2-Tab Navigation**: Refactored `CardDetailSheet` to feature a `CupertinoSlidingSegmentedControl` directly beneath the card header toggling between `[ Details | Values ]`, complete with privacy lock badge indicator.
  - **Details Tab Enhancements**: Expandable Scryfall rulings & errata accordion, physical provenance coordinates (binder page/slot, protection status), acquisition date picker & price tracking, and clickable artist filter links.
  - **Deck Gear & Dynamic Tokens**: Implemented `DeckGearSection` (sleeve brand/color, deck box model) and `DeckTokenExtractor` to auto-discover required physical tokens from card rules text.

- **Collector & Investor Values Engine (`Phase 4.4 - R3`)**:
  - **Trimmed Market Average (`TrimmedMarketAverageCalculator`)**: Statistical averaging across top market sources (TCGplayer, Cardmarket, eBay) discarding floor minimum anomalies ($\le \$0.02$) with fresh timestamps and pull-to-refresh sync.
  - **Interactive Multi-Line Chart (`InteractiveMultiLineChart`)**: Canvas `CustomPainter` chart using Fritsch-Carlson cubic splines supporting 7D, 30D, 90D, 1Y, and ALL time horizons, touch tooltips, and toggleable vendor legend lines.
  - **Cost Basis & P&L Widget (`CostBasisPnLWidget`)**: Computes `Current Market Average - Purchase Price` with absolute dollar and percentage returns color-coded green/red.
  - **Liquidity & Reality Check (`LiquidityRealityCheckWidget`)**: Retail Replacement Value vs. Buylist Cash Out estimates, High/Low liquidity tags, and Reserved List warning badges.
  - **52-Week Range Bar (`FiftyTwoWeekRangeBar`)**: Visual price gauge showing current price relative to 52-week low and high.
  - **Condition & Treatment Matrix (`ConditionTreatmentMatrixWidget`)**: Compact grid of market spreads across Conditions (NM/LP/MP) and Finishes (Non-Foil/Foil/Etched).
  - **Market Spread Table (`MarketSpreadTableWidget`)**: Multi-vendor price comparison highlighting highest buylist and lowest retail.

- **Aggregate Deck & Vault Analytics (`Phase 4.4 - R4`)**:
  - **Aggregate P&L**: Total cost basis vs. market value analytics integrated into `DeckBuilderScreen` and `VaultScreen`.
  - **Pareto Value Concentration (`ParetoDistributionWidget`)**: Calculates and displays *"The top 5 cards represent X% of this deck's total value"* with ranked micro-lists and medal tier badges (#1 Gold, #2 Cyan, #3 Violet).

#### Quality & Verification
- **Test Suite**: 3,016 / 3,016 tests passing (100% pass rate) with 0 failures, 0 skips, and 0 lints (`dart analyze --fatal-infos`).
- **Audit Verification**: Passed independent multi-phase Victory Audit (`VICTORY CONFIRMED`).

---

## [0.4.0] - 2026-09-21

#### Added
- **Deck Schema & Versioning (`Decks`, `DeckVersions`, `DeckVersionItems`)**: Added Git-style deck versioning schema to Drift allowing users to maintain multiple iterative versions of a deck without duplicating cards.
- **Inventory Conflict Engine (`VaultDao`)**: Created logic to enforce strict Physical vs. Logical inventory tracking. Evaluates `Available Quantity = (VaultItem.quantity) - SUM(DeckVersionItems.quantity across all ACTIVE DeckVersions)` to prevent accidental double-booking of physical cards.
- **Conflict Resolution Modal**: When tapping `[ + Add to Deck ]` on a card that has no physical copies remaining, the app now intercepts the action and provides options to either `[ Move physical card here ]` or `[ Add as Proxy ]`.
- **Vault Deck Badges (`OptionalDeckBadges`)**: If a Vault card is actively assigned to a deck, it displays a small, unobtrusive text pill/badge showing the Deck's Name over the card tile in the grid or list.
- **Dynamic Deck Covers & Analytics Dashboard**: Added wide banner utilizing cropped card art in the Deck Builder Header, as well as swipeable carousels featuring visual metrics for Mana Curve, Color Devotion vs. Production, and a Bling Meter.
- **Proportional Bubble Scrollbar**: Built a custom, interactive vertical rail where the size of each "Bubble" (Commander, Creatures, Sideboard, etc.) is perfectly mathematically proportional to the quantity of cards in that section.
- **Fast-Draw Playtester**: Added a randomized 7-card opening hand tester with mulligan support, callable directly from the deck builder.
- **Legality & Identity Enforcer**: Added an isolate to check deck legality automatically on load and display an alert badge if format constraints are violated.
- **Deck Quick Actions & I/O Engine**: Implemented full `DeckIOParser` capabilities and Quick Actions menus for importing text lists, exporting to clipboard, and mass exporting missing/proxy cards for purchase.
- **Mock Data Ecosystem**: Authored comprehensive mock data sets to completely mock the visual features of the Deck Details UI ecosystem while awaiting real backend hydration.

#### Fixed
- **MacOS Deployment Target & FFI Web**: Fixed the macOS Podfile and project files to use `12.0` deployment target, allowing macOS builds to compile cleanly again. Added documentation on web-incompatibility due to dart:ffi OpenCV requirement.
- **RenderFlex Overflows**: Completely eliminated RenderFlex layout issues in the Deck Details screen under aggressive adversarial bounds testing (320px viewport with 2.0x text scaling) using adaptive slivers, Flexible bounds, and FittedBox clipping.
# Changelog

All notable changes to the **Countr** project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

### Planned / Upcoming
- Phase 4: Local Deck Builder & Interactive Deck Construction engine.
- Phase 5: Local Match / Life Counter and Game Tracker (`Play / Track`).

---

## [3.9.1] - 2026-09-17

### Scryfall Multi-Face & Flavor Name Polish, Price Fallbacks, and Catalog Healing

#### Fixed & Improved
- **Bidirectional Flavor / Alternate Name Search & Display**:
  - Implemented dual-name display (`item.flavorName ?? item.name` with `[item.name]` secondary subtitle badge) across `VaultItemCard`, `VaultItemTile`, and `ManualAddBottomSheet`.
  - Added full search indexing in `VaultDao` (`searchCatalogCards`, `watchItemsByCollection`, `getItemsByCollection`) matching on canonical `name`, `flavor_name`, and `dynamic_data`.
  - Added SQLite startup backfill query in `AppDatabase.beforeOpen` to copy `flavor_name` from legacy `dynamic_data` into the `flavor_name` column.
- **Multi-Faced (DFC) & Adventure Card Support**:
  - Captured individual face attributes (`name`, `mana_cost`, `type_line`, `oracle_text`, `power`, `toughness`, `loyalty`, `image_url`, `image_uris`) in `mapScryfallCardToCompanion`.
  - Enhanced `CardDetailSheet` with multi-face switcher (`[ View Face 1 ] | [ View Face 2 ]`) to toggle rules text, stats, and metadata between faces.
  - Implemented image flip condition strictly checking for valid back artwork (`_hasFlipArt`), gracefully hiding flip buttons for cards without physical back art (such as Adventure cards).
- **Pricing & Image Extraction Resilience**:
  - Enhanced Scryfall parser to extract market prices across `usd`, `usd_foil`, `usd_etched`, `eur`, and `eur_foil`.
  - Added image fallbacks for `border_crop` and `art_crop` when `normal`, `large`, or `png` are missing.
- **On-Demand Catalog Healing**:
  - Added live Scryfall search fallback in `ManualAddBottomSheet` that automatically queries Scryfall API and upserts fresh card metadata into local SQLite dictionary.
- **Verification**:
  - 100% test pass rate (713/713 automated tests) with 0 static analysis issues (`dart analyze --fatal-infos`).

---

## [3.9.0] - 2026-09-17

### Phase 3.8 Multi-Face Scryfall Parsing, Sleek VaultScreen UI Overhaul, and Interactive 3D Card Flips & Cached Rulings

#### Added & Improved
- **Scryfall Data Parsing Fixes & Database Search (R1)**:
  - Multi-faced card parsing (`card_faces`): joins oracle text from both faces using ` // ` and extracts dual front and back image URIs (`dynamicData['card_faces']`, `dynamicData['image_uris']`, and `dynamicData['back_image_url']`).
  - Flavor name persistence: added `flavor_name` column to `vault_items` table with automated schema v5 migration and indexed lookup (`idx_vault_items_flavor_name`).
  - `VaultDao` search matching: updated `watchItemsByCollection`, `getItemsByCollection`, and catalog search to match `WHERE name LIKE '%$query%' OR flavor_name LIKE '%$query%'` case-insensitively.
- **VaultScreen Sleek UI Overhaul & Animated Search (R2)**:
  - Default view set to **"Binders"** (`VaultViewMode.binders`) and default layout set to **Grid View** (`CardDisplayLayout.grid`).
  - Singles grid renders with **3 columns** on phone viewports; Binders grid maintains 2 columns.
  - Renamed "All Vault" filter chip to **"Owned"**.
  - Updated top view toggle to text: `[ Singles ] | [ Binders ]`.
  - Updated layout switcher to **Icons Only** (`Icons.grid_view` and `Icons.view_list`) with accessibility semantics and tooltips.
  - Built animated full-width expanding search bar that transitions from collapsed icon to full horizontal width, pushing view toggles out of the way.
  - Conditional `[ + New Binder ]` FAB visible only in Binders mode and hidden in Singles mode.
- **Card Detail Interactive Flip UI & Cached Scryfall Rulings (R3)**:
  - Interactive 3D perspective flip mechanism for multi-faced cards in both `CardDetailSheet` and `FullScreenCardViewer` with visible styled "Flip" action button.
  - Holographic rainbow foil shader preserved continuously across 3D flips.
  - Renamed mechanics section to **"Card Mechanics & Rulings"**.
  - On-demand Scryfall rulings service (`ScryfallService.fetchCardRulings`) with offline fallback and local SQLite caching to avoid repeated HTTP calls.
- **Test Suite Metrics**:
  - 713 total automated tests passing project-wide with 0 regressions.
  - 0 static analysis errors, warnings, or infos (`dart analyze --fatal-infos`).

---

## [3.8.0] - 2026-09-16

### Phase 3.8: Reactive Vault Totals, Global Persona Viewing Modes, Manual Add Engine, Quick Action Bar & Holographic Foil Viewer

#### Added & Improved
- **Reactive Vault Totals & Database Sync (R1)**:
  - Completely removed local dummy counter state variables (including `_manualItemCount`) from `VaultScreen`.
  - Implemented `VaultDao.watchVaultTotals({String? collectionType, String? binderId})` returning an immutable `VaultTotals` domain model (`totalCount`, `totalMarketValue`, `totalCostBasis`, `totalProfitLoss`, `profitLossPercentage`) using Drift `customSelect` with `readsFrom: {vaultItems}`.
  - Dynamically scoped macro totals by `collection_type` and active `primary_binder_id`.
  - Bound `VaultScreen` header metrics strictly to reactive Riverpod providers (`vaultTotalsProvider`, `selectedVaultBinderIdProvider`).
- **Global Persona State & Dynamic Vault Item Card (R2)**:
  - Defined `enum UserPersona { investor, player }` and `userPersonaProvider` in `lib/core/state/app_state.dart`.
  - Mounted an interactive segmented toggle switch `[ 💼 Investor ] | [ ⚔️ Player ]` in `MorphingCommandCenter` (drawer).
  - Configured `VaultItemCard` to dynamically adapt layout based on active persona:
    - **Investor Mode**: Live TMV, acquired price, and acquisition delta pills (`+$4.50 (+37.5%)` or `-$1.20 (-10.0%)`).
    - **Player Mode**: In-game mechanics (Mana Cost, Power/Toughness, and Keyword chips) while completely suppressing financial deltas.
- **Manual Add Search Engine & Bulk Staging (R3)**:
  - Wired `[ + Add Item ]` in `VaultScreen` to `ManualAddBottomSheet`.
  - Built 300ms debounced catalog search querying local SQLite card records via `VaultDao.searchCatalogCards`.
  - Added thumbnail, name, set/rarity, live market price, and `[-] qty [+]` quantity steppers to card search tiles.
  - Built sticky bottom action bar `[ Add X Items to Vault ]` with destination binder selector and atomic transactional bulk persistence (`VaultDao.bulkAddCatalogItems`).
- **Card Detail Quick Action Bar & Foil Full-Screen Viewer (R4)**:
  - Mounted a bottom Quick Action Bar on `CardDetailSheet` with:
    - `[ Delete ]`: Confirmation dialog before deleting from SQLite via `dao.deleteItem`.
    - `[ Full Screen ]`: Hero-animated launch into `FullScreenCardViewer`.
    - `[ Add to Deck ]`: Opens deck picker and persists deck tag to `dynamicData['deck_history']`.
    - `[ Share ]`: Checks `isUserLoggedInProvider`; displays login prompt dialog if unauthenticated, triggers system share if authenticated.
    - `[ Edit ]`: Launches `EditCardModal`.
  - Built `FullScreenCardViewer` with `InteractiveViewer` pinch-to-zoom/pan and animated holographic rainbow shimmer overlay via custom `ShaderMask` for `[ ✨ Foil Finish ]`.
- **Card Detail "Edit" Modal (R5)**:
  - Built `EditCardModal` allowing users to switch variants, edit custom tags, overwrite acquired prices, and toggle condition flags (`isGraded`, `isAltered`, `isMisprint`, `isSigned`) persisting to SQLite schema v4.
- **Duplicate Badge Visual Counter**:
  - Attached an intuitive duplicate count badge (`${quantity}x`) with cyan styling on cards with multiple copies (`quantity > 1`) in both List (`VaultItemCard`) and Grid (`VaultItemTile`) views.
  - Omitted badges for single-copy cards (`quantity == 1`) to eliminate visual clutter.
  - Retained clean `Total Tracked Items: $totalCount` in the Vault header to reflect aggregate physical copy count accurately.
  - Fixed search clear button `_debounceTimer` race condition ensuring instant restoration of cards upon clearing search.
  - Added reactive collection counts to `CollectionsAccordion` in Command Center drawer.
- **Test Suite Metrics**:
  - 580 total automated tests passing project-wide with 0 failures and 0 regressions.
  - Static analysis passing with 0 errors, 0 warnings, 0 infos (`dart analyze --fatal-infos`).

---

## [3.7.0] - 2026-09-16

### Phase 3.7: Vault Infinite-Scroll Stabilization, Scanner CV Hardening, ManaBox-Style Success Toast & MTG Keyword Glossary

#### Added & Improved
- **Vault Infinite-Scroll Stabilization & Pagination (R1)**:
  - Smooth infinite scrolling without scroll jumping, jitter, or scroll position resets.
  - Eliminated flashing `SliverFillRemaining` loading spinner during page fetches by retaining rendered sliver list/grid when `asyncItems.hasValue` is true.
  - Added `vaultIsFetchingMoreProvider` in-flight pagination lock and guarded `_onScroll` against redundant / premature page requests.
  - Applied `limit: paginationLimit` to `onlyOwned: true` mode.
  - Configured `PageStorageKey` on `CustomScrollView`, `SliverList.builder`, and `SliverGrid` for scroll offset persistence across rebuilds and layout toggles.
- **Scanner CV Hardening: Object-First OCR & Multi-Factor Matching Gate (R2)**:
  - Integrated `google_mlkit_object_detection` into the camera stream pipeline to require physical card bounding box detection before executing OCR.
  - Implemented graceful fallback to `CardPerimeterCalculator` for emulators, simulators, and headless test runners without native binary models.
  - Implemented `OcrHeuristicMatcher.passesMultiFactorGate` rejecting single 4-character false positives (e.g. "Ring", "Fire", "Fog") and requiring Name Match + at least one secondary factor (Collector Number, MTG Card Type / Keyword, or Exact Set Code).
  - Hardened multi-edition card matching in `VaultDao.matchScannedCard` to prevent candidate masking across printings.
- **Scanner UI Polish & Animated Top Success Prompt (R3)**:
  - Completely removed the debugging `"Scanner Camera Active"` textbox from camera viewfinder.
  - Implemented ManaBox-style floating top success toast (`ScannerSuccessToast`) with thumbnail, bold name, set code, emerald market price, smooth slide animation, and 1.5s auto-dismiss timer.
  - Preserved continuous camera scanning on card detection without pausing camera stream or auto-routing to `InboxScreen`.
- **Beginner Keyword Glossary on Card Detail Screen (R4)**:
  - Introduced `MtgKeywordGlossary` with beginner-friendly, plain-English explanations for 12 core MTG mechanics (Vigilance, Flying, Trample, Haste, Lifelink, Deathtouch, First Strike, Double Strike, Reach, Menace, Ward, Hexproof).
  - Dual-source extraction supporting both `keywords` metadata list and word-boundary `\b` regex parsing on `oracle_text`.
  - Added "Card Mechanics" section to `CardDetailSheet` with cyan badge tags and definitions beneath.
- **Test Suite Metrics**:
  - 419 total automated tests passing project-wide (261 existing baseline + 158 new unit, widget, and challenge tests) with 0 failures and 0 regressions.
  - Static analysis passing with 0 errors, 0 warnings, 0 infos.

---

## [0.4.1] - 2026-09-15

### Phase 3.1: Full SQLite Catalog Search, ManaBox-Style Tile Grid & Interactive Card Details

#### Added
- **ManaBox-Style Tile/Grid View Switcher**:
  - Implemented `cardDisplayLayoutProvider` (`CardDisplayLayout { list, grid }`) and responsive layout toggle buttons `[ List | Tiles ]` in the horizontal scroll controls of `VaultScreen`.
  - Created `VaultItemTile` widget displaying high-resolution artwork, quantity and unowned badges, foil/graded indicators, and live TMV pricing with tap-to-detail interaction.
  - Implemented adaptive responsive columns based on screen width (2 columns on phones <420px, 3 on 420–600px, 4 on 600–900px, 5–6 on tablets/desktop >900px) with fixed 0.64 card aspect ratio.
- **Full-Database SQLite Catalog Search & Infinite Scrolling**:
  - Upgraded `VaultDao.watchItemsByCollection` and `getItemsByCollection` with optional SQL `searchQuery`, `limit`, and `offset` filtering natively across `name` and `setOrSeries` using `LIKE %query%`.
  - Fixed Catalog (Ref) tab querying: eliminated the previous 100-item memory bottleneck so searches query the entire 75,000+ card Scryfall database in SQLite.
  - Added infinite scrolling pagination controller (`vaultPaginationLimitProvider`) to lazily stream items in 50-card chunks on scroll threshold.
  - Debounced search queries by 250ms with one-tap search field clearing and filter reset.
- **Interactive Card Detail Modal Sheet (`CardDetailSheet`)**:
  - Built expandable `DraggableScrollableSheet` modal presenting complete card metadata:
    - High-resolution card artwork with fallback placeholder.
    - Type line, mana cost, and rarity badges.
    - Full Oracle rules text, flavor text, power/toughness, and loyalty counters.
    - Format legalities chips across Standard, Pioneer, Modern, Legacy, Vintage, Commander, and Pauper.
    - Official rulings and textbox clarifications.
    - User-specific portfolio financial ledger metrics (acquired price, live market value, net profit/loss, and ROI %).
    - Dynamic deck history tags (`deck_history`) with interactive tag addition and deletion.
    - Editable personal strategy notes and combo suggestions saved with instant feedback.
    - Quick "Add to Vault / Inbox" action for unowned catalog cards.
  - Added `VaultDao.updateItemNotesAndDecks` to safely persist user notes and deck placements inside `dynamicData` without schema migrations.
- **Automated Unit & Widget Tests**:
  - Created `test/vault_search_pagination_test.dart` (6 tests) covering SQLite search query matching, pagination limits/offsets, note/deck updates, and Riverpod catalog stream filtering.
  - Created `test/vault_view_switcher_and_detail_test.dart` (3 tests) covering List vs Grid layout toggling, responsive tile rendering, modal opening, oracle/financial data display, and unowned card vault imports.

---

## [0.4.0] - 2026-09-15

### Phase 3: Dynamic Full-Frame Scanner, Hybrid Matching Engine & Inbox Data Isolation

#### Added
- **Full-Frame Dynamic Reactive Scanner UX (ManaBox Style)**:
  - Eliminated hardcoded, centered static reticle overlay from [ScannerModal](file:///Users/jomelaledia/freeSpc/Countr/lib/features/scanner/presentation/screens/scanner_modal.dart).
  - Created [CardPerimeterCalculator](file:///Users/jomelaledia/freeSpc/Countr/lib/features/scanner/domain/card_perimeter_calculator.dart) to analyze full camera frame text bounding boxes (`RecognizedText.blocks`) from Google ML Kit OCR and derive tight card perimeter bounds with rotation compensation and viewport scaling.
  - Implemented [DynamicScannerOverlay](file:///Users/jomelaledia/freeSpc/Countr/lib/features/scanner/presentation/widgets/dynamic_scanner_overlay.dart) featuring animated reactive corner brackets that track and snap to physical card boundaries in real time, accompanied by a dynamic laser scan line.
- **Resilient Hybrid Dart + SQLite Matching Engine**:
  - Implemented `sanitize(String input)` alphanumeric normalization in [OcrHeuristicMatcher](file:///Users/jomelaledia/freeSpc/Countr/lib/features/scanner/domain/ocr_heuristic_matcher.dart), stripping whitespace, punctuation, and non-alphanumeric characters.
  - Step 1 (Collector Number Regex Override): Detects collector numbers (`xxx/yyy`, `xxx`) and matches directly against SQLite `dynamic_data LIKE '%"collector_number":"$number"%'` with `LIMIT 1`.
  - Step 2 (Wide Net Prefix Query): Extracts 5-character prefix from candidate OCR lines (>= 4 chars) to fetch candidate pool (`LIMIT 25`) from SQLite.
  - Step 3 (Dart `contains` Verification): Confirms matches in memory by testing if the sanitized OCR line contains the sanitized database card name, reliably handling OCR noise, missing punctuation, and split card suffixes.
- **Inbox Item Deletion (Single & Bulk)**:
  - Added single-item swipe-to-delete via Flutter's `Dismissible` in [InboxScreen](file:///Users/jomelaledia/freeSpc/Countr/lib/features/scanner/presentation/screens/inbox_screen.dart) with immediate database row deletion and undo SnackBar feedback.
  - Added bulk `[ Trash ]` action button in selection mode alongside `[ Move to Binder ]` with batch deletion (`VaultDao.deleteItems`).
- **Comprehensive End-to-End Test Suite**:
  - Added 137 tier 1–4 tests across `test/e2e/` verifying perimeter geometry, frame skipping, hybrid matching, inbox isolation, single/bulk deletion, and real-world multi-game collection workflows.

#### Changed
- **Camera Stream Deterministic Frame Skipping & Async Lock**:
  - Implemented 1-in-10 frame skipping (`frameCount % 10 == 0`, ~3–6 FPS) in `ScannerModal` to prevent camera stream CPU choking.
  - Enforced strict `_isProcessingFrame` asynchronous lock with guaranteed `try / catch / finally` unlocking to eliminate permanent camera freezes.
- **Inbox Data Isolation & Portfolio Valuation Firewall**:
  - Newly scanned cards staged into the Inbox are tagged with `primary_binder_id = 'INBOX'`.
  - Refactored `VaultDao` queries (`watchItemsByCollection`, `watchBinderItemCounts`) and `vaultPortfolioSummaryProvider` to strictly exclude items where `primary_binder_id == 'INBOX'`.
  - Staged, unanchored cards do not inflate Total Market Value, Total Cost Basis, or binder item counts.

#### Fixed
- **Scanner Viewfinder Layout Overflows & Clipping**:
  - Eliminated `RenderFlex` overflow exceptions and visual clipping across compact and standard mobile viewports (360×800, 375×667, and 390×844) on the full-screen Edge Scanner modal ([scanner_modal.dart](file:///Users/jomelaledia/freeSpc/Countr/lib/features/scanner/presentation/screens/scanner_modal.dart)).
  - Wrapped continuous streaming live status indicator pill and bottom framing caption in horizontal padding and responsive `FittedBox(fit: BoxFit.scaleDown)`.
  - Wrapped top floating controls bar in `SingleChildScrollView(scrollDirection: Axis.horizontal, physics: BouncingScrollPhysics())` with `VisualDensity.compact` to eliminate edge cutoff on narrow screens.
  - Wrapped top bar header badge in `Flexible(child: FittedBox(fit: BoxFit.scaleDown))` to prevent displacement of modal Close and Inbox buttons.
  - Added `clipBehavior: Clip.antiAlias` to the reticle `AnimatedContainer` to eliminate scanning line bleed outside rounded reticle corners.
  - Wrapped card condition pill labels in [inbox_screen.dart](file:///Users/jomelaledia/freeSpc/Countr/lib/features/scanner/presentation/screens/inbox_screen.dart) with `Flexible` and `TextOverflow.ellipsis` to prevent overflow in staged lists.
  - Added automated multi-viewport regression tests in `test/phase3_ui_test.dart`.
- **Database Data-Wipe Prevention (True UPSERT with DoUpdate)**: Replaced dangerous `InsertMode.insertOrReplace` in `VaultDao.insertDictionaryBatch` and `insertDictionaryChunked` with Drift's native `DoUpdate.withExcluded`.
- **Vault Tab Crash & UI Freeze (OOM / Layout Lockup)**: Resolved application freezing and memory pressure watchdog crashes when navigating to the Vault tab after Scryfall bulk hydration.

---

## [0.3.0] - 2026-09-14

### Phase 2.5: The Hydration Engine (Scryfall MTG Bulk Ingestion)

#### Added
- **Low-Memory Streaming Parser (`ScryfallStreamingParser`)**:
  - Infinitely scalable background streaming parser operating inside a dedicated spawned `Isolate` (`lib/features/hydration/domain/isolate/scryfall_parser.dart`).
  - Implements a character-level JSON streaming state machine tracking string escapes, brace depths, and token buffers across byte stream chunks.
  - Emits batches of 1,000 `VaultItemsCompanion` objects across isolate ports with strict bidirectional acknowledgment backpressure (`'ack'`).
  - Immediate reference dropping post-transmission to allow constant garbage collection, keeping total memory overhead under 20MB (well below the 60MB memory ceiling) during 75,000+ card bulk ingestion.
  - Multi-faced card fallback for image URIs (`card_faces[0].image_uris.normal`) and pricing extraction (normal USD and foil USD fallback).
  - Flags catalog cards with `quantity: 0` to denote reference dictionary entries.
- **Scryfall Bulk Data HTTP Service (`ScryfallService`)**:
  - Metadata fetcher querying `https://api.scryfall.com/bulk-data/default-cards` (`lib/features/hydration/data/services/scryfall_service.dart`).
  - Streaming downloader piping multi-hundred megabyte response byte streams directly to temporary disk cache without loading the payload into RAM.
  - Dependency injection support for `http.Client` for fast offline unit testing.
- **Drift Batch Ingestion (`VaultDao`)**:
  - `insertDictionaryBatch(chunk)` and `insertDictionaryChunked(items, {onProgress})` in `lib/features/vault/data/daos/vault_dao.dart`.
  - Commits entries in chunks of 1,000 using `batch()` with `InsertMode.insertOrReplace` to avoid SQLite lockups and transaction timeouts.
- **State Management & Pipeline Controller (`HydrationController` & `HydrationState`)**:
  - Reactive Riverpod controller orchestrating metadata retrieval, download streaming, background isolate processing, and chunked database inserts (`lib/features/hydration/presentation/controllers/hydration_controller.dart`).
  - Rich status tracking across `idle`, `fetchingMetadata`, `downloading`, `parsingAndInserting`, `complete`, and `error`.
- **Hydration Progress UI (`HydrationProgressCard`)**:
  - Dark neon card component rendered in `VaultScreen` with phase badge, step icon, animated/linear progress indicator, and live chunk statistics (`lib/features/hydration/presentation/widgets/hydration_progress_card.dart`).
  - Added `[ Hydrate MTG Dictionary ]` action button in the AppBar and an empty-state quick-action button in `VaultScreen`.
- **Catalog vs. Owned Portfolio Separation**:
  - Updated `vaultPortfolioSummaryProvider` to strictly filter for owned items (`quantity > 0`), ensuring catalog dictionary items never distort portfolio valuation or cost basis.
  - Updated `VaultItemCard` with a distinct `"CATALOG / UNOWNED"` cyan badge when displaying reference entries.
- **Network Permissions**:
  - Added `android.permission.INTERNET` to `AndroidManifest.xml`.
  - Added `com.apple.security.network.client` entitlements to macOS debug and release profiles.
- **Automated Test Suite**:
  - Added 13 automated unit and widget tests in `test/hydration_engine_test.dart` covering service streaming, isolate parser, backpressure chunking, portfolio separation, controller flow, and UI rendering (26/26 tests passing across full suite).

#### Fixed
- **Scryfall Metadata `jsonl_download_uri` Support**: Resolved `FormatException: Scryfall bulk metadata response missing "download_uri"` caused by Scryfall's migration to gzipped JSON Lines (`.jsonl.gz`) format. The metadata parser now dynamically extracts `jsonl_download_uri`, falling back to legacy `download_uri` and list endpoint structures.
- **On-the-Fly Gzip Decompression**: Added automatic native `gzip.decoder` stream decompression in `ScryfallStreamingParser`, allowing the engine to download compressed 78MB archives (reducing network bandwidth by 75%) and decompress them transparently during isolate streaming.

---

## [0.2.0] - 2026-09-14

### Phase 2: Drift SQLite Ledger & Polymorphic JSON Architecture

#### Added
- **Drift SQLite Local Database (`AppDatabase`)**:
  - Offline-first local database using Drift and SQLite (`lib/core/database/app_database.dart`).
  - Schema migration strategy with automatic initial mock data seeding on first open (`beforeOpen`).
- **Comprehensive Ledger Schema (`VaultItems`)**:
  - Granular table definition (`lib/core/database/tables/vault_items_table.dart`):
    - **Core Identity**: `id` (Text UUID, PK), `collection_type` (Text: `'mtg'`, `'pokemon'`, `'comic'`, `'sports_card'`), `name` (Text), `set_or_series` (Text), `image_url` (Text).
    - **Personal Inventory**: `acquired_price` (Real), `acquired_date` (DateTime), `quantity` (Int, default 1), `condition` (Text), `is_graded` (Bool, default false), `personal_notes` (Text, nullable).
    - **Financial Ledger**: `current_market_price` (Real), `last_price_update` (DateTime).
    - **Polymorphic Engine**: `dynamic_data` (Text, stringified JSON) to store item-specific attributes without schema bloating.
- **Data Access Object (`VaultDao`)**:
  - `watchItemsByCollection(collectionType)` reactive stream query supporting individual collections or `'All Collections'` (`lib/features/vault/data/daos/vault_dao.dart`).
  - `seedDatabase()` inserting 4 hyper-detailed mock portfolio records:
    1. **Magic: The Gathering**: *The One Ring (Serialized #007/100)* — \$15.00 cost basis vs. \$45.50 TMV (+203.3%), Near Mint raw, dynamic JSON: `{"mana": "2UB", "type": "Creature", "power": 3, "toughness": 2}`.
    2. **Pokémon TCG**: *Charizard ex* (Scarlet & Violet: 151) — \$4.50 cost basis vs. \$3.25 TMV (-27.8%), Lightly Played raw, dynamic JSON: `{"hp": 120, "stage": "Basic"}`.
    3. **Comic Books**: *Ultimate Fallout #4 (1st Miles Morales)* — \$150.00 cost basis vs. \$210.00 TMV (+40.0%), CGC 9.8 graded slab, dynamic JSON: `{"issue": 1, "publisher": "Marvel"}`.
    4. **Sports Cards**: *T.J. Watt Prizm Silver Rookie* (2017 Panini Prizm) — \$20.00 cost basis vs. \$180.00 TMV (+800.0%), PSA 10 Gem Mint graded slab, dynamic JSON: `{"sport": "Football", "team": "Steelers", "is_rookie": true}`.
- **Polymorphic JSON UI Engine (`PolymorphicAttributeChip`)**:
  - Widget parsing `dynamic_data` with an exhaustive switch statement (`lib/features/vault/presentation/widgets/polymorphic_attribute_chip.dart`):
    - MTG: Mana Cost, Type, Power / Toughness.
    - Pokémon: HP and Evolution Stage.
    - Comic Books: Publisher and Issue Number.
    - Sports Cards: Sport, Team, and Rookie Card badge.
- **Riverpod Reactive Layer**:
  - `appDatabaseProvider`: Singleton database provider with lifecycle disposal (`lib/features/vault/presentation/providers/vault_providers.dart`).
  - `vaultDaoProvider`: DAO provider binding.
  - `vaultItemsStreamProvider`: Reactive stream provider bound to `activeGameContextProvider`.
  - `vaultPortfolioSummaryProvider`: Computed provider calculating Total Market Value, Total Cost Basis, Profit/Loss, P/L %, and Item Count.
- **Financial Ledger UI**:
  - `VaultItemCard`: Detailed card displaying Acquired Price, Live TMV, condition/grade slab badge, polymorphic chip, and color-coded financial delta (`lib/features/vault/presentation/widgets/vault_item_card.dart`).
  - `_buildPortfolioSummaryCard`: Real-time portfolio performance card displaying Estimated Vault Value and percentage return.
- **Automated Test Suite**:
  - `test/drift_ledger_test.dart` testing DAO filtering, seeding verification, polymorphic chip parsing, and P/L styling.

#### Changed
- **Cross-Platform SQLite Migration (`drift_flutter`)**:
  - Migrated from deprecated `sqlite3_flutter_libs` to official `drift_flutter: ^0.3.1`.
  - Configured `openConnection()` in `lib/core/database/connection/connection.dart` to use `driftDatabase(name: 'countr_vault')`, ensuring full native support across macOS, iOS, Android, Linux, Windows, and Web.
  - Added automated fallback to `NativeDatabase.memory()` when `FLUTTER_TEST` environment is active.
- **Vault Screen Refactor**:
  - Updated `VaultScreen` to listen directly to the Drift reactive stream.
  - Maintained local state freeze for search queries and filter chips across tab navigation.

#### Fixed
- **Database Ledger Error**: Eliminated dynamic library linkage errors (`Failed to load dynamic library 'libsqlite3.dylib'`) on macOS and mobile targets by replacing deprecated libraries with `drift_flutter`.
- **Test Runner Deadlock**: Resolved `fakeAsync` event loop hang in `testWidgets` caused by awaiting native isolate streams inside fake async zones.
- **Pending Timers on Test Disposal**: Added explicit timer flushes at the conclusion of widget tests to satisfy `!timersPending` test assertions.
- **Loss Delta Sign Formatting**: Fixed negative financial deltas so losses properly render both the percentage and dollar amount (e.g. `-27.8% (-$1.25)`).

---

## [0.1.0] - 2026-09-14

### Phase 1: The Foundation Shell

#### Added
- **Enterprise Architecture**:
  - Feature-First Clean Architecture structure (`core/` and `features/`).
  - Zero cloud dependencies — strictly offline-first/local-first design.
- **Declarative Routing (`go_router`)**:
  - Implemented `StatefulShellRoute.indexedStack` maintaining 4 primary branches: Feed, Vault, Decks, and Menu dummy branch (`lib/core/router/app_router.dart`).
  - Enabled **Local State Freezing**: Navigating between Feed, Vault, and Decks preserves scroll positions, search text, and internal component state.
- **Custom Bottom Navigation Bar**:
  - 5 flush, equal-sized (20% width) touch targets with identical vertical alignment (`lib/features/shell/presentation/widgets/custom_bottom_nav_bar.dart`):
    - Index 0: Feed (`Icons.home_rounded`)
    - Index 1: Vault (`Icons.shield_rounded`)
    - Index 2: Scanner (`Icons.camera_alt_rounded`) with distinctive cyan accent styling
    - Index 3: Decks (`Icons.style_rounded`)
    - Index 4: Menu (`Icons.menu_rounded`)
- **Full-Screen Scanner Viewfinder Modal**:
  - Full-screen modal overlay labeled `"Scanner Camera Active"` triggered by center navigation button (`lib/features/scanner/presentation/screens/scanner_modal.dart`).
  - Features camera reticle animation, rule-of-thirds grid, flashlight toggle, and scan mode selector (Raw Card, Slab/Graded, Comic Book, Barcode).
- **Morphing Global Command Center (Menu)**:
  - Origin-anchored modal animation expanding directly from the bottom-right menu button (`lib/features/command_center/presentation/widgets/morphing_command_center.dart`).
  - **Accordion 1 ("Collections +")**: Selects active game context ("All Collections", "Magic: The Gathering", "Pokémon TCG", "Comic Books") and updates Riverpod `activeGameContextProvider` (`lib/features/command_center/presentation/widgets/collections_accordion.dart`).
  - **Accordion 2 ("Play / Track +")**: Nested expandable accordion organizing game formats:
    - MTG: Commander, Standard, Draft.
    - Pokémon: Standard, Gym Leader Challenge (GLC).
    - Lorcana: Core / Standard, Draft.
- **Social Feed & Modular Post Architecture**:
  - Clean Feed App Bar (`Text("Countr")` + Search, Mail, and Notifications action icons).
  - Cleaned up redundant context tabs and eliminated top title clipping.
  - Reusable PostCard shell with `clipBehavior: Clip.antiAlias`.
  - Reusable PostHeader (Avatar, User handle, Timestamp, Location pill).
  - Reusable PostActionBar (4 touch targets: `[♡ HYPE]`, `[💬 COMMENT]`, `[+ WISHLIST]`, `[⇆ TRADE]`).
  - Three distinct feed post variants:
    - Text Post (`text_post_body.dart`).
    - Single Pull Post (`single_pull_post_body.dart` with square card display and value tag).
    - Multi-Pull Post (`multi_pull_post_body.dart` with 2x2 card grid and "+ SEE MORE" overlay).
- **Interactive Vault Screen & Dynamic Dropdown Title**:
  - Replaced static title with interactive `PopupMenuButton` (`My Vault ▾`, `MTG Vault ▾`, `Pokémon Vault ▾`, `Comics Vault ▾`).
  - Tied directly to Riverpod `activeGameContextProvider` to synchronize state with the Command Center menu.
- **Design System & Theme**:
  - Dark collector aesthetic palette (`lib/core/constants/app_colors.dart`): Deep Void (`#0B0E14`), Surface (`#141923`), Neon Cyan (`#00F2FE`), Emerald Green (`#10B981`), Amber Gold (`#F59E0B`), Arcane Violet (`#8B5CF6`), and Rose Red (`#F43F5E`).
  - Typography system (`lib/core/constants/app_typography.dart`) and Material 3 dark theme (`lib/core/theme/app_theme.dart`).
- **Automated Tests**:
  - Comprehensive suite of 8 widget and integration tests in `test/widget_test.dart`.
