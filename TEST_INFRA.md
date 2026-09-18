# E2E Test Infra: Countr Phase 3.9

## Test Philosophy
- Opaque-box, requirement-driven testing derived from `ORIGINAL_REQUEST.md`.
- No internal coupling or brittle implementation mocks.
- Systematic 4-tier methodology:
  - **Tier 1: Feature Coverage** (>=5 per feature) - Happy-path isolation verification.
  - **Tier 2: Boundary & Corner Cases** (>=5 per feature) - Limits, empty states, extremes, malformed inputs.
  - **Tier 3: Cross-Feature Interactions** (Pairwise coverage) - Swiping while filtering, DFC flipping during background scroll sync, pricing fallbacks with duplicate badges.
  - **Tier 4: Real-World Application Workloads** - ManaBox-style card exploration, collection management, deck inspection scenarios.
- Run Command: `DEVELOPER_DIR=/Library/Developer/CommandLineTools flutter test test/phase_3_9_e2e_test.dart`

## Feature Inventory Mapping (N = 17 Core Features)
| # | Feature | Requirement Source | Tier 1 | Tier 2 | Tier 3 |
|---|---------|-------------------|:------:|:------:|:------:|
| 1 | DFC Flip Animation Retention | ORIGINAL_REQUEST §R1 | 5 | 5 | ✓ |
| 2 | Adventure Flip Suppression | ORIGINAL_REQUEST §R1 | 5 | 5 | ✓ |
| 3 | Adventure Unified Rules Box | ORIGINAL_REQUEST §R1 | 5 | 5 | ✓ |
| 4 | Universes Beyond Detection | ORIGINAL_REQUEST §R1 | 5 | 5 | ✓ |
| 5 | Secret Lairs & Flavor Search | ORIGINAL_REQUEST §R1 | 5 | 5 | ✓ |
| 6 | Eliminate Literal "Check" | ORIGINAL_REQUEST §R2 | 5 | 5 | ✓ |
| 7 | Pricing Fallback Hierarchy | ORIGINAL_REQUEST §R2 | 5 | 5 | ✓ |
| 8 | Unlisted Price Labeling | ORIGINAL_REQUEST §R2 | 5 | 5 | ✓ |
| 9 | 3x Grid Quantity Badges | ORIGINAL_REQUEST §R3 | 5 | 5 | ✓ |
| 10 | List View Art Thumbnails | ORIGINAL_REQUEST §R3 | 5 | 5 | ✓ |
| 11 | Card Detail Swiping | ORIGINAL_REQUEST §R4 | 5 | 5 | ✓ |
| 12 | Background Scroll Tracking | ORIGINAL_REQUEST §R4 | 5 | 5 | ✓ |
| 13 | FullScreenCardViewer Sync | ORIGINAL_REQUEST §R4 | 5 | 5 | ✓ |
| 14 | MTG Filter State & Provider | ORIGINAL_REQUEST §R5 | 5 | 5 | ✓ |
| 15 | MTG Filter Sheet Modal | ORIGINAL_REQUEST §R5 | 5 | 5 | ✓ |
| 16 | MTG Filter Criteria Logic | ORIGINAL_REQUEST §R5 | 5 | 5 | ✓ |
| 17 | VaultDao Reactive Filtering | ORIGINAL_REQUEST §R5 | 5 | 5 | ✓ |

## Test Architecture
- **Test Runner Location**: `test/phase_3_9_e2e_test.dart` (modularized with helper suites)
- **Invocation**: `DEVELOPER_DIR=/Library/Developer/CommandLineTools flutter test test/phase_3_9_e2e_test.dart`
- **Pass / Fail Semantics**: Zero failures, zero errors, exit code 0.
- **Coverage Thresholds**:
  - Tier 1: ≥85 tests (5 × 17 features)
  - Tier 2: ≥85 tests (5 × 17 features)
  - Tier 3: ≥17 tests (Cross-feature pairwise interactions)
  - Tier 4: ≥9 tests (End-to-end user journeys)
  - **Total Minimum**: ≥196 test cases

## Real-World Application Scenarios (Tier 4)
| # | Scenario | Features Exercised | Complexity |
|---|----------|--------------------|------------|
| 1 | Secret Lair Collector Journey | Secret Lair search ('sld'), flavor name lookup, unlisted pricing fallback, 3x grid duplicate badge | High |
| 2 | Universes Beyond Commander Filter | MTG filter (Commander color identity, UB treatment, CMC slider), reactive DAO update, list view thumbnails | High |
| 3 | Adventure Card Inspection | Vault grid tap, Adventure rules box verification, flip button absence, swipe to DFC, flip DFC | High |
| 4 | Continuous Vault Swiping & Background Sync | 20-card Vault list, swiping through 10 cards in CardDetailSheet, dismiss modal, verify underlying grid scroll position | High |
| 5 | FullScreen Immersive Zoom & Flip Flow | Open FullScreenCardViewer at index 4, pinch zoom, swipe to next, toggle foil shader, flip face | High |
| 6 | ManaBox Advanced Filter Combinatorial Query | Color match 'Exactly' {W, U}, CMC range 2-4, Type 'Creature', Power > 2, Condition 'NM' | High |
| 7 | Zero Price Edge Cases & Fallback Chain | Multi-currency pricing chain (`usd: 0.00`, `usd_foil: null`, `usd_etched: 12.50`), verify 'Unlisted' display when missing | Medium |
| 8 | Dynamic Grid View Resize & Badge Alignment | Switch between 3-column singles grid and list view, verify badge placement and thumbnail fallbacks | Medium |
| 9 | Filter Reset & Vault Reactive Restoration | Apply 5 active filters, verify count badge, reset all filters, verify active list restores completely | Medium |
