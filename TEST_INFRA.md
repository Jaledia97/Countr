# E2E Test Infra: Phase 4.4 Values Engine & Privacy Mode

## Test Philosophy
- **Requirement-Driven & Opaque-Box**: Tests are derived strictly from `ORIGINAL_REQUEST.md` (Phase 4.4 R1–R4) and `PROJECT.md` specifications, exercising the values engine, privacy security, and financial analytics as client screens and end users would.
- **Methodology**: Systematic 4-Tier test suite:
  - **Tier 1 (Feature Coverage)**: Direct verification of primary behaviors and interface contracts across all features.
  - **Tier 2 (Boundary & Corner Cases)**: Edge conditions, empty sets, penny minimums ($0.02), zero cost basis, and extreme values.
  - **Tier 3 (Cross-Feature Combinations)**: Multi-feature interactions (Currency normalization + trimmed mean + P&L; Streamer security lifecycle backgrounding + privacy redaction; Locked tab unlock flow).
  - **Tier 4 (Real-World Application Scenarios)**: High-fidelity card, deck, and portfolio workloads (Edgar Markov 100-card Commander Pareto distribution, Black Lotus multi-vendor market spread, multi-currency portfolio conversion).
- **Independence & Isolation**: Every test is self-contained, sets up its own isolated state/container, makes zero network calls, and leaves no side effects.

---

## Feature Inventory & Test Mapping

Mapping every feature from `PROJECT.md` § Feature Inventory across all 4 tiers:

| # | Feature | Requirement Source | Milestone | Tier 1 | Tier 2 | Tier 3 | Tier 4 |
|---|---------|-------------------|:---------:|:------:|:------:|:------:|:------:|
| 1 | Base Currency Selector (USD, EUR, GBP, CAD) | R1 | M1 | ✓ | ✓ | ✓ | ✓ |
| 2 | Exchange Rate Service (Cached Rates & Freshness) | R1 | M1 | ✓ | ✓ | ✓ | ✓ |
| 3 | Dynamic Currency Formatter ($, €, £, CA$) | R1 | M1 | ✓ | ✓ | ✓ | ✓ |
| 4 | Multi-market Price Normalization (FX to Base) | R1 | M1 | ✓ | ✓ | ✓ | ✓ |
| 5 | Streamer Security Preference Toggle | R1 | M1 | ✓ | ✓ | ✓ | ✓ |
| 6 | AppLifecycle Observer (Background Lock) | R1 | M1 | ✓ | ✓ | ✓ | ✓ |
| 7 | Global Privacy AppBar Toggle (Visibility Icons) | R1 | M1 | ✓ | ✓ | ✓ | ✓ |
| 8 | Financial Data Redaction ('****' / Blur) | R1 | M1 | ✓ | ✓ | ✓ | ✓ |
| 9 | Locked Values Tab UI ("Values hidden...") | R1 | M1 | ✓ | ✓ | ✓ | ✓ |
| 10 | Drift Schema v8 Migration | R2 | M2 | ✓ | ✓ | ✓ | ✓ |
| 11 | Extended VaultItem Columns (6 new fields) | R2 | M2 | ✓ | ✓ | ✓ | ✓ |
| 12 | Safe Legacy Backfill (Data Preservation) | R2 | M2 | ✓ | ✓ | ✓ | ✓ |
| 13 | 2-Tab Segmented Control ([ Details \| Values ]) | R2 | M2 | ✓ | ✓ | ✓ | ✓ |
| 14 | Scryfall Rulings Accordion | R2 | M2 | ✓ | ✓ | ✓ | ✓ |
| 15 | Physical Collection Metrics (Qty, Condition, etc.) | R2 | M2 | ✓ | ✓ | ✓ | ✓ |
| 16 | Physical Provenance Section (Protection, Binder/Page/Slot) | R2 | M2 | ✓ | ✓ | ✓ | ✓ |
| 17 | Acquisition Tracking (date_obtained, purchase_price) | R2 | M2 | ✓ | ✓ | ✓ | ✓ |
| 18 | Metadata Pedigree (Artist Filter, Frame Details) | R2 | M2 | ✓ | ✓ | ✓ | ✓ |
| 19 | Deck Gear Metadata (Sleeves, Deck Box) | R2 | M2 | ✓ | ✓ | ✓ | ✓ |
| 20 | Auto-Generated Token Checklist (Oracle Parser) | R2 | M2 | ✓ | ✓ | ✓ | ✓ |
| 21 | Deck Item Tap Navigation (Opens 2-Tab Sheet) | R2 | M2 | ✓ | ✓ | ✓ | ✓ |
| 22 | Trimmed Market Average (Outlier Rejection) | R3 | M3 | ✓ | ✓ | ✓ | ✓ |
| 23 | Freshness Badge & Pull-to-Refresh Sync | R3 | M3 | ✓ | ✓ | ✓ | ✓ |
| 24 | Interactive Multi-Line Chart (7D..ALL Ranges) | R3 | M3 | ✓ | ✓ | ✓ | ✓ |
| 25 | Interactive Vendor Toggles & Crosshair Tooltip | R3 | M3 | ✓ | ✓ | ✓ | ✓ |
| 26 | Cost Basis & P&L Widget ($ and % Green/Red) | R3 | M3 | ✓ | ✓ | ✓ | ✓ |
| 27 | Liquidity Reality Check (Retail vs Cash Out) | R3 | M3 | ✓ | ✓ | ✓ | ✓ |
| 28 | Reserved List Warning Badge | R3 | M3 | ✓ | ✓ | ✓ | ✓ |
| 29 | 52-Week Range Bar (Low/High Position) | R3 | M3 | ✓ | ✓ | ✓ | ✓ |
| 30 | Condition/Treatment Matrix (3x3 Spread Grid) | R3 | M3 | ✓ | ✓ | ✓ | ✓ |
| 31 | Market Spread Table (Lowest Retail/Highest Buylist) | R3 | M3 | ✓ | ✓ | ✓ | ✓ |
| 32 | DAO Query Extension (watchDeckItems P&L fields) | R4 | M4 | ✓ | ✓ | ✓ | ✓ |
| 33 | Aggregate Deck & Vault P&L | R4 | M4 | ✓ | ✓ | ✓ | ✓ |
| 34 | Pareto Distribution Widget ("Top 5 cards represent X%") | R4 | M4 | ✓ | ✓ | ✓ | ✓ |
| 35 | Values Tab Mount Integration | R3/R4 | M4 | ✓ | ✓ | ✓ | ✓ |
| 36 | Currency Normalization Unit Tests | Gates | M5 | ✓ | ✓ | ✓ | ✓ |
| 37 | Trimmed Average Unit Tests | Gates | M5 | ✓ | ✓ | ✓ | ✓ |
| 38 | P&L & Pareto Unit Tests | Gates | M5 | ✓ | ✓ | ✓ | ✓ |
| 39 | Privacy Redaction Widget Tests | Gates | M5 | ✓ | ✓ | ✓ | ✓ |
| 40 | Streamer Security Widget Tests | Gates | M5 | ✓ | ✓ | ✓ | ✓ |
| 41 | Locked Values Tab Widget Tests | Gates | M5 | ✓ | ✓ | ✓ | ✓ |
| 42 | 2-Tab Details Layout Widget Tests | Gates | M5 | ✓ | ✓ | ✓ | ✓ |
| 43 | Drift v8 Migration Tests | Gates | M5 | ✓ | ✓ | ✓ | ✓ |
| 44 | Opaque-box E2E Test Suite | Gates | E2E | ✓ | ✓ | ✓ | ✓ |
| 45 | Repository Test Suite Pass (100% Pass) | Gates | M5 | ✓ | ✓ | ✓ | ✓ |
| 46 | Clean Static Analysis Pass (0 Errors/Warnings) | Gates | M5 | ✓ | ✓ | ✓ | ✓ |

---

## Test Architecture

- **Primary E2E Test Suite**: `test/values_engine_e2e_test.dart`
- **Contract & Test Harness**: `test/values_engine_test_contracts.dart`
- **Execution Command**: `flutter test test/values_engine_e2e_test.dart`
- **Static Analysis Command**: `dart analyze --fatal-infos`
- **Pass Semantics**: Exit code 0, 100% test assertions pass, zero exceptions, zero warnings.

---

## Real-World Application Scenarios (Tier 4)

| # | Workload Scenario | Features Exercised | Expected Observable Behavior |
|---|-------------------|--------------------|------------------------------|
| 1 | **Edgar Markov Commander Deck** (100 Cards) | Pareto distribution, heavy hitters micro-list, aggregate deck valuation | The top 5 cards represent 62.5% of deck value ($250 of $400 total); micro-list ranks #1 Edgar Markov ($115) through #5 Urza's Incubator ($25). |
| 2 | **Alpha Black Lotus Market Valuation** | Multi-vendor spread, EUR-USD conversion, $0.02 floor rejection, trimmed mean, P&L return | Discards $0.02 corrupt quote; trims lowest and highest among 5 remaining vendors; returns trimmed average of $90,666.67; computes +$75,666.67 (+504.4%) return over $15,000 cost basis. |
| 3 | **Multi-Currency Global Portfolio Conversion** | Base currency switching (USD -> EUR -> GBP -> CAD), dynamic symbols | Converts entire collection value dynamically using cached daily exchange rates; preserves relative valuation consistency across all 4 currencies. |
| 4 | **Streamer Live Broadcast Background Lock** | Streamer security toggle, AppLifecycleState, global privacy mode, locked UI state | When app transitions to background (`paused`), privacy mode auto-locks instantly; all amounts redact to `'****'`; `LockedValuesView` renders *"Values hidden. Disable Privacy Mode to view market data."* |
| 5 | **Dual-Face / Token Extraction Workflow** | `DeckTokenExtractor`, physical token checklist | Extracts auto-generated token requirements (`Construct`, `Vampire`, `Treasure`) from deck Oracle text rules. |

---

## Coverage Thresholds & Quality Gates

- **Tier 1 (Feature Coverage)**: Direct verification of primary paths for currency conversion, trimmed averages, P&L delta math, privacy mode redactions, streamer security, and locked values tab.
- **Tier 2 (Boundary & Corner Cases)**: Zero/empty inputs, single vendor quote, exactly $0.02 floor boundary vs $0.0201, zero cost basis division protection, negative P&L, extreme values ($1,000,000+).
- **Tier 3 (Cross-Feature Combinations)**: Pairwise and multi-feature interaction flows: currency conversion feeding trimmed average feeding P&L; privacy toggle interacting with streamer lifecycle events; locked values view unlock action.
- **Tier 4 (Real-World Application Scenarios)**: High-fidelity application workloads exercising full system contracts under realistic conditions.
- **Overall**: 100% pass on `flutter test test/values_engine_e2e_test.dart` and 0 errors/warnings on `dart analyze --fatal-infos`.
