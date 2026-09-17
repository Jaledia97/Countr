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
