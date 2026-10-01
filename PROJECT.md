# Project: Countr 4.8 Patch Master Specification

## Architecture
Countr 4.8 Patch addresses key UI refinements, critical crash fixes, and UX streamline enhancements across five core functional domains:

1. **Vault Screen & Collections Presentation (`lib/features/vault/`)**:
   - Decoupled two-row header architecture separating the primary 3-way view switcher `[ Singles | Binders | Collections ]` from a dedicated, persistent layout toggle row `[ List | Tile ]`.
   - Tuned tile card aspect ratio (~0.54) and image scaling (`BoxFit.contain`) eliminating card art and border clipping.
   - Calibrated horizontal swiping physics and zoom interaction thresholds in `FullScreenCardViewer` preventing accidental lockouts and partial scroll states.
   - Responsive 2x2 grid presentation for the Collections tab with composite sorting: primary by completion percentage descending, secondary by release date descending.

2. **Card Details Sheet Restructuring & Dynamic Binding (`lib/features/vault/`)**:
   - Reactive printing variant synchronization between `SwitchPrintingModal`, `VariantPriceChart`, and `CardDetailSheet` ensuring full card hero art updates immediately without reverting.
   - Cleaned typography and layout hierarchy:
     - Set identity line formatted as `[Set Symbol] [Set Code] [Set Name]`.
     - Oracle text typography with paragraph separation and italicized reminder text `(...)`.
     - Grouped mechanics attribute chips, `[ Mechanic ] Definition` glossary, and progressive rulings disclosure (1 initial ruling with "See All" expander).
     - Conditional suppression of Acquisition Tracking for unowned catalog cards.
     - Full card image preview filling ~66% of the Versions & Printings container.
     - Relocation of Metadata & Pedigree to the very bottom of the details sheet.

3. **Decks Screen Bug Fixes & Builder Polish (`lib/features/decks/`)**:
   - Defect remediation for `DeckThumbnailPickerModal`: provides bounded vertical constraints (`0.85 * screenHeight` and `Expanded` child) preventing RenderFlex unbounded layout crashes.
   - Database and mock data integrity: populates authentic `oracle_text` in dynamic JSON metadata for Edgar Markov and seeded cards.
   - Connected `decks_new_deck_fab` to launch `DeckSetupWizardModal`.
   - Streamlined top app bar by removing the redundant Deck Analytics action button.
   - Added dedicated User Notes container in the inline expandable Deck Analytics card.
   - Restyled `ProportionalBubbleScrollbar` with a slim rail spine between indicator nodes.

4. **Command Center Play/Track UX (`lib/features/command_center/`)**:
   - Replaced nested accordion expansion in `PlayTrackAccordion`: tapping a TCG card directly sets active TCG context and launches `PregameSetupSheet`.

5. **Game Setup Pod Enhancements (`lib/features/life_counter/`)**:
   - Pod table seating orientation picker in `PregameSetupSheet`.
   - Interactive starting life slider featuring snap nodes for standard formats (40 Commander, 20 Standard, 30 Brawl, etc.).
   - OLED / Battery Saver mode toggle rendering `#000000` true black in `PodScaffoldWidget`.
   - Immersive Mode toggle toggling system UI overlays via `SystemChrome`.

6. **Quality Assurance & Testing (`test/`)**:
   - Static analysis verification (`dart analyze` with 0 issues).
   - Test suite maintenance and 100% test pass verification (`flutter test`).

---

## Feature Inventory
| # | Feature | Description | Milestone | Source |
|---|---------|-------------|-----------|--------|
| 1 | Dedicated Layout Toggle Row | Reposition List/Tile toggle to persistent row below 3-way view switcher | M1 | R1 |
| 2 | Tile Mode Aspect Ratio & Sizing | Adjust aspect ratio (~0.54) and use BoxFit.contain to eliminate card clipping | M1 | R1 |
| 3 | PageView Scroll Physics Calibration | Prevent partial scroll zoom locks and high resistance in horizontal viewer | M1 | R1 |
| 4 | Collections 2x2 Grid & Sorting | 2x2 collections grid sorted by completion % desc, then release date desc | M1 | R1 |
| 5 | Dynamic Variant Art Binding | Synchronize variant art selection to full card hero art in CardDetailSheet | M2 | R2 |
| 6 | Set Identity Reordering | Order Line 3 as [Set Symbol] [Set Code] [Set Name] | M2 | R2 |
| 7 | Oracle Text Layout & Typography | Line breaks, paragraph spacing, and italics for reminder text in (...) | M2 | R2 |
| 8 | Mechanics & Rulings Restructure | Top attribute chips, [ Mechanic ] Definition, 1 initial ruling with "See All" | M2 | R2 |
| 9 | Hide Acquisition on Unowned | Completely suppress Acquisition Tracking section on unowned catalog cards | M2 | R2 |
| 10 | Versions Container Proportions | Thumbnail uses full card image filling ~66% of container height | M2 | R2 |
| 11 | Metadata Bottom Relocation | Move Metadata & Pedigree section to the very bottom of Details tab | M2 | R2 |
| 12 | Cover Art Picker Bounded Layout | Provide bounded height and Expanded child to DeckThumbnailPickerModal | M3 | R3 |
| 13 | Seeded Card Oracle Text Population | Populate authentic oracle_text in dynamicData for Edgar Markov and seeded cards | M3 | R3 |
| 14 | Decks FAB Wizard Wiring | Connect decks_new_deck_fab to DeckSetupWizardModal.show | M3 | R3 |
| 15 | Deck Analytics App Bar Cleanup | Remove redundant analytics icon from deck_builder_screen app bar | M3 | R3 |
| 16 | Inline Analytics User Notes | Add dedicated User Notes container inside InlineDeckAnalyticsCard | M3 | R3 |
| 17 | Slim Bubble Scrollbar Rail | Restyle scrollbar track to a slim spine between bubble nodes | M3 | R3 |
| 18 | Direct Play/Track Setup Launch | Tapping TCG card sets active context and opens PregameSetupSheet directly | M4 | R4 |
| 19 | Pod Seating Orientation Picker | Add seating/layout orientation picker for pod table in PregameSetupSheet | M4 | R5 |
| 20 | Starting Life Snap Slider | Interactive slider with snap nodes at 40 (Commander), 20 (Standard), 30 (Brawl) | M4 | R5 |
| 21 | OLED True Black Mode | Toggle applying #000000 background to life counter screens | M4 | R5 |
| 22 | Immersive Gameplay Mode | Toggle hiding system navigation and status bars during gameplay | M4 | R5 |
| 23 | Static Analysis Compliance | Verify dart analyze passes with 0 errors, 0 warnings, and 0 lints | M5 | R6 |
| 24 | Regression & Unit Test Pass | Verify flutter test passes 100% across all unit, widget, and integration tests | M5 | R6 |
| 25 | Forensic Audit Verification | Clean audit report verifying genuine implementation and zero cheats | M5 | R6 |

---

## Milestones

| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| 1 | M1: Vault Screen & Collections Tab Refinements | Dedicated layout toggle row, Tile aspect ratio & BoxFit.contain, horizontal scroll physics calibration, 2x2 collections grid with completion % and release date sorting | M0 (Survey) | DONE |
| 2 | M2: Card Details Screen Restructuring & Variant Binding | Dynamic variant art binding, Set Identity [Symbol] [Code] [Name], Oracle text typography & italics, mechanics chips & glossary & 1 ruling with "See All", hide acquisition on unowned, versions container proportions, bottom metadata | M1 | DONE |
| 3 | M3: Decks Screen Bug Fixes & UI Enhancements | DeckThumbnailPickerModal bounded layout constraints, seeded card oracle_text in SQLite & mock data, FAB wired to DeckSetupWizardModal, remove app bar analytics button, User Notes container in inline analytics, slim scrollbar rail | M1 | DONE |
| 4 | M4: Command Center & Game Setup Pod Enhancements | PlayTrackAccordion direct setup launch on card tap, pod seating orientation picker, starting life slider with format snap points, OLED true black toggle, immersive mode toggle | M1 | DONE |
| 5 | M5: Quality Standards & E2E Verification | Run dart analyze ensuring 0 issues, run full flutter test ensuring 100% pass, verify test updates for FAB and accordion interactions, final forensic audit | M1, M2, M3, M4 | DONE |

---

## Interface Contracts

### 1. Vault Screen Layout & Collections (`lib/features/vault/`)
- `VaultSetCollection`:
  ```dart
  class VaultSetCollection {
    final String setCode;
    final String setName;
    final int totalCards;
    final int ownedCards;
    final double completionPercentage;
    final DateTime? releaseDate;
  }
  ```
- `VaultCollectionViewSliver`: Renders 2-column grid (`SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, ...)`), preserving keys:
  - `vault_collection_tile_${setCode}`
  - `vault_collection_header_${setCode}`
  - `vault_collection_progress_${setCode}`
  - `vault_collection_grid_${setCode}`

### 2. Card Details Variant Binding & Layout (`lib/features/vault/presentation/widgets/`)
- `SwitchPrintingModal.show`:
  ```dart
  static Future<void> show(
    BuildContext context,
    VaultItem item, {
    void Function(VaultItem updatedItem)? onUpdated,
  });
  ```
- `CardDetailSheet`:
  - `_currentItem` state dynamically updated upon printing switch.
  - Set Identity row keys: `card_detail_set_symbol_icon`, `card_detail_set_code_badge`, `card_detail_set_name`.
  - Acquisition tracking rendered only when `isOwned == true`.
  - Metadata rendered as the final section of `_buildDetailsTab`.

### 3. Decks & Builder Interfaces (`lib/features/decks/`)
- `DeckThumbnailPickerModal.show`:
  - Enforces bounded height (`MediaQuery.of(context).size.height * 0.85`).
  - Child `TabBarView` wrapped in `Expanded`.
- `InlineDeckAnalyticsCard`:
  - Contains User Notes container bound to `deck.description`.
- `ProportionalBubbleScrollbar`:
  - Rail spine width: 4.0 - 6.0 dp centered within gesture area.

### 4. Command Center & Game Setup Interfaces
- `PlayTrackAccordion`:
  - Tapping a TCG card sets `activeGameContextProvider` and calls `PregameSetupSheet.show(context, initialTcg: tcg)`.
- `PregameSetupSheet`:
  - `seatingOrientation`: Table orientation enum (`standard`, `opposed`, `radial`).
  - `startingLife`: Slider bound to integer life with format snap nodes (20, 30, 40).
  - `isOledMode`: Boolean state passing true black `#000000` to `PodScaffoldWidget`.
  - `isImmersiveMode`: Boolean state triggering `SystemChrome.setEnabledSystemUIMode`.

---

## Code Layout
```
lib/
├── core/
│   ├── database/daos/vault_dao.dart                 # Seeded dynamicData oracle_text & switchCardPrinting
│   └── theme/                                       # OLED black styling
├── features/
│   ├── command_center/presentation/widgets/
│   │   └── play_track_accordion.dart                # Direct card tap pregame launch
│   ├── decks/
│   │   ├── data/mock_deck_data.dart                 # Seeded card oracle_text
│   │   └── presentation/
│   │       ├── screens/
│   │       │   ├── decks_screen.dart                # FAB wiring to wizard
│   │       │   └── deck_builder_screen.dart         # App bar analytics cleanup
│   │       └── widgets/
│   │           ├── deck_thumbnail_picker_modal.dart # Bounded height layout constraints
│   │           ├── inline_deck_analytics_card.dart  # User Notes container
│   │           └── proportional_bubble_scrollbar.dart # Slim rail styling
│   ├── life_counter/presentation/
│   │   ├── dialogs/pregame_setup_sheet.dart         # Seating picker, snap slider, OLED & immersive toggles
│   │   └── widgets/pod_scaffold_widget.dart         # OLED true black background handling
│   ├── symbology/domain/mana_text_parser.dart       # Italicized reminder text (...) parsing
│   └── vault/presentation/
│       ├── screens/vault_screen.dart                # Two-row switcher layout, tile aspect ratio
│       └── widgets/
│           ├── card_detail_sheet.dart               # Variant binding, set identity, rulings, metadata bottom
│           ├── full_screen_card_viewer.dart         # Horizontal swiping physics & zoom lockout fix
│           ├── switch_printing_modal.dart           # Variant callback invocation
│           ├── variant_price_chart.dart             # Full card preview thumbnail
│           └── vault_collection_view_sliver.dart    # 2x2 grid & completion % sorting
```
