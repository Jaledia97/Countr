# Project: Countr Phase 4.4 (Values Engine & Privacy Mode)

## Architecture
Countr Phase 4.4 unifies physical card provenance with financial market analytics and privacy security. The architecture comprises:

1. **Global Settings & Privacy Layer (`lib/core/state/settings_state.dart`, `lib/features/shell/`)**:
   - `baseCurrencyProvider`: Reactive enum state (`Currency.usd`, `eur`, `gbp`, `cad`).
   - `privacyModeProvider`: Global boolean state toggling financial data visibility.
   - `streamerSecurityEnabledProvider`: Auto-locks `privacyModeProvider` when app lifecycle transitions to background (`paused`, `inactive`, `hidden`) via `AppLifecycleListener` in `MainShellScreen`.
   - `ExchangeRateService`: Cached exchange rates normalizing multi-market vendor quotes (TCGplayer, Cardmarket, eBay) to base currency.
   - `LockedValuesView`: Locked UI state rendered when accessing financial data with Privacy Mode enabled (*"Values hidden. Disable Privacy Mode to view market data."*).

2. **Persistence & Data Layer (`lib/core/database/`, `lib/features/vault/data/daos/`)**:
   - Drift database schema version incremented from v7 to v8.
   - `VaultItems` table extended with: `date_obtained` (`DateTime?`), `purchase_price` (`Real?`), `binder_page` (`Int?`), `binder_slot` (`Text?`), `notes` (`Text?`), and `protection_status` (`Text`, default 'Sleeved').
   - Dual-layer migration: `onUpgrade` step for `from < 8` and `beforeOpen` defensive PRAGMA queries with safe non-destructive backfill from legacy fields.
   - `vault_dao.dart:watchDeckItems` updated to select `vi.acquired_price` and `vi.purchase_price`.

3. **Unified 2-Tab Details & Values Layout (`lib/features/vault/presentation/widgets/card_detail_sheet.dart`)**:
   - Segmented control directly beneath sheet header toggling `[ Details | Values ]`.
   - **Details Tab**:
     1. Oracle Text & Rulings: Scryfall rulings & errata in an expandable accordion with `published_at` date, comment, and `ManaText`.
     2. Collection Metrics: Quantity, Condition, Language, Treatment.
     3. Physical Provenance: Protection status, custom notes, and Binder/Page/Slot coordinates.
     4. Acquisition Tracking: Date picker for `date_obtained` and numeric input for `purchase_price`.
     5. Metadata Pedigree: Clickable artist name filter button linking to Vault search, frame detail badges.
     6. Deck Gear (Deck Scope): Sleeve profile (Brand/Color), Deck Box model inputs, and auto-generated physical Token Checklist (`DeckTokenExtractor`).
   - **Values Tab**:
     - When Privacy Mode is active: renders `LockedValuesView`.
     - When Privacy Mode is disabled: renders full financial analytics suite.

4. **Collector & Investor Values Engine (`lib/features/values/`)**:
   - `TrimmedMarketAverageCalculator`: Discards floor anomalies ($p \le \$0.02$) and applies symmetrical outlier trimming across converted 5+ market sources.
   - `InteractiveMultiLineChart`: High-performance CustomPainter rendering 7D, 30D, 90D, 1Y, ALL date ranges with vendor toggle checkboxes and crosshair tooltips.
   - `CostBasisPnLWidget`: `Market Avg - Purchase Price`, absolute dollar and percentage return color-coded emerald green or rose red.
   - `LiquidityRealityCheckWidget`: Replacement Value (Retail) vs Cash Out Value (Buylist estimate), Liquidity Tag (High/Low), and Reserved List warning badge.
   - `FiftyTwoWeekRangeBar`: Horizontal bar showing current price relative to 52-week low and high.
   - `ConditionTreatmentMatrix`: Compact grid of market spreads across conditions (NM/LP/MP) and finishes (Non-Foil/Foil/Etched).
   - `MarketSpreadTable`: Tabular breakdown of raw converted vendor quotes highlighting highest buylist and lowest retail.

5. **Aggregate Deck & Vault Analytics (`lib/features/decks/`, `lib/features/vault/`)**:
   - Total cost basis vs current market value.
   - Pareto distribution concentration widget ("The top 5 cards represent X% of this deck's total value") with ranked micro-list of top 3-5 heavy hitters.

---

## Feature Inventory
| # | Feature | Description | Milestone | Source |
|---|---------|-------------|-----------|--------|
| 1 | Base Currency Selector | Support USD, EUR, GBP, CAD in settings state with reactive updates | M1 | R1 |
| 2 | Exchange Rate Service | Cached rates normalizing TCGplayer, Cardmarket, eBay to base currency | M1 | R1 |
| 3 | Dynamic Currency Formatter | Dynamic symbols ($, €, £, CA$) and formatting across all pricing helpers | M1 | R1 |
| 4 | Multi-market Price Normalization | Convert source prices to base currency before aggregation and display | M1 | R1 |
| 5 | Streamer Security Preference | Toggle for auto-locking privacy mode when app is backgrounded | M1 | R1 |
| 6 | AppLifecycle Observer | `AppLifecycleListener` in `MainShellScreen` auto-locking privacy on paused/inactive | M1 | R1 |
| 7 | Global Privacy AppBar Toggle | Replace view switcher in main AppBars with `Icons.visibility` / `visibility_off` | M1 | R1 |
| 8 | Financial Data Redaction | Redact Vault totals, card prices, deck values, P&L to '****' or blur | M1 | R1 |
| 9 | Locked Values Tab UI | Render *"Values hidden. Disable Privacy Mode to view market data."* with unlock button | M1 | R1 |
| 10 | Drift Schema v8 Migration | Increment to v8, add 6 columns to `VaultItems` in `app_database.dart` | M2 | R2 |
| 11 | Extended VaultItem Columns | date_obtained, purchase_price, binder_page, binder_slot, notes, protection_status | M2 | R2 |
| 12 | Safe Legacy Backfill | Backfill acquired_date -> date_obtained, acquired_price -> purchase_price, etc. | M2 | R2 |
| 13 | 2-Tab Segmented Control | Top segmented control beneath header toggling `[ Details | Values ]` | M2 | R2 |
| 14 | Scryfall Rulings Accordion | Expandable accordion showing publication date, comment, and `ManaText` | M2 | R2 |
| 15 | Physical Collection Metrics | Quantity, Condition, Language, Treatment display and editing | M2 | R2 |
| 16 | Physical Provenance Section | Protection status (default 'Sleeved'), custom notes, Binder/Page/Slot inputs | M2 | R2 |
| 17 | Acquisition Tracking | Date picker for `date_obtained` and currency input for `purchase_price` | M2 | R2 |
| 18 | Metadata Pedigree | Clickable artist name filter link to Vault, frame detail badges | M2 | R2 |
| 19 | Deck Gear Metadata | Sleeve profile (Brand/Color) and Deck Box model inputs in deck scope | M2 | R2 |
| 20 | Auto-Generated Token Checklist | Derive physical token checklist from card Oracle texts in deck scope | M2 | R2 |
| 21 | Deck Item Tap Navigation | Wire card list item taps in `DeckBuilderScreen` to open 2-tab `CardDetailSheet` | M2 | R2 |
| 22 | Trimmed Market Average | Compute average across 5+ sources filtering $0.02 floor anomalies & outliers | M3 | R3 |
| 23 | Freshness Badge & Pull-to-Refresh | Freshness badge (`Updated 2h ago`) with pull-to-refresh on-demand syncing | M3 | R3 |
| 24 | Interactive Multi-Line Chart | Zero-dependency CustomPainter rendering 7D, 30D, 90D, 1Y, ALL ranges | M3 | R3 |
| 25 | Interactive Vendor Toggles | Checkboxes toggling vendor curves alongside Trimmed Average + crosshair tooltips | M3 | R3 |
| 26 | Cost Basis & P&L Widget | Current Market Avg - Purchase Price ($ and % return color-coded green/red) | M3 | R3 |
| 27 | Liquidity Reality Check | Replacement Value vs Buylist Cash Out, Liquidity Tag (High/Low) | M3 | R3 |
| 28 | Reserved List Warning Badge | Reserved list alert badge (persisting `reserved` flag from Scryfall) | M3 | R3 |
| 29 | 52-Week Range Bar | Horizontal slider showing current price relative to 52-week low and high | M3 | R3 |
| 30 | Condition/Treatment Matrix | Compact grid of market spreads across NM/LP/MP vs Non-Foil/Foil/Etched | M3 | R3 |
| 31 | Market Spread Table | Tabular breakdown of raw converted vendor quotes with buylist/retail highlights | M3 | R3 |
| 32 | DAO Query Extension | Update `watchDeckItems` in `vault_dao.dart` to select acquired & purchase price | M4 | R4 |
| 33 | Aggregate Deck & Vault P&L | Total cost basis vs current market value at Deck and Vault level | M4 | R4 |
| 34 | Pareto Distribution Widget | "Top 5 cards represent X% of value" with ranked micro-list of heavy hitters | M4 | R4 |
| 35 | Values Tab Mount Integration | Assemble all Values engine components into `[ Values ]` tab on Card/Deck/Vault | M4 | R3/R4 |
| 36 | Currency Normalization Unit Tests | Unit tests covering exchange rate math and multi-currency conversions | M5 | Gates |
| 37 | Trimmed Average Unit Tests | Unit tests verifying floor anomaly rejection and outlier trimming | M5 | Gates |
| 38 | P&L & Pareto Unit Tests | Unit tests verifying cost basis, returns, and Pareto concentration calculations | M5 | Gates |
| 39 | Privacy Redaction Widget Tests | Widget tests verifying app-wide redaction to '****' on toggle | M5 | Gates |
| 40 | Streamer Security Widget Tests | Widget tests verifying background state auto-locks privacy mode | M5 | Gates |
| 41 | Locked Values Tab Widget Tests | Widget tests verifying locked UI state and unlock button functionality | M5 | Gates |
| 42 | 2-Tab Details Layout Widget Tests | Widget tests verifying tab switching, rulings accordion, and provenance inputs | M5 | Gates |
| 43 | Drift v8 Migration Tests | Test migration from v7 to v8 verifying schema version and column data safety | M5 | Gates |
| 44 | Opaque-box E2E Test Suite | 4-tier requirement-driven E2E tests published via `TEST_READY.md` | E2E | Gates |
| 45 | Repository Test Suite Pass | 100% test pass rate across `flutter test` | M5 | Gates |
| 46 | Clean Static Analysis Pass | `dart analyze --fatal-infos` passes with 0 errors and 0 warnings | M5 | Gates |

---

## Milestones

| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| 1 | M1: Global Settings, Currency & Privacy Engine | Base Currency selector, `ExchangeRateService`, `VaultPricingHelper` dynamic formatting, `MainShellScreen` `AppLifecycleListener` for Streamer Security, AppBar privacy toggle, financial redaction to '****' across screens/tiles, and `LockedValuesView`. Outputs: All M1 tests pass, 100% repo tests pass, zero privacy leakage, gate PASSED. | none | DONE |
| 2 | M2: Drift Schema v8 & 2-Tab Details Architecture | Increment Drift to schema v8, add 6 columns to `VaultItems`, safe legacy backfills, segmented control `[ Details | Values ]` on `CardDetailSheet`, 6 Details sections (rulings accordion, collection metrics, provenance, acquisition tracking, artist filter, deck gear & token checklist), wire deck card taps. Outputs: 2,776/2,776 tests pass, 0 lints, 0 overflows, gate PASSED. | M1 | DONE |
| 3 | M3: Collector & Investor Values Engine Core Components | Trimmed market average algorithm, freshness badge & sync, `InteractiveMultiLineChart`, P&L widget, liquidity reality check, Reserved List badge, 52W range bar, condition/treatment matrix, market spread table. Outputs: 176/176 values tests pass, 17/17 stress tests pass, 0 overflows on 320x568 at 2.0x scaling, gate PASSED. | M1, M2 | DONE |
| 4 | M4: Aggregate Deck/Vault Analytics & Tab Integration | `watchDeckItems` DAO query extension for cost basis, aggregate Deck/Vault P&L, Pareto distribution concentration widget with ranked micro-list, mounting full Values engine into `[ Values ]` tab across Card/Deck/Vault. Outputs: 2,931/2,931 tests pass (100%), MapView backward compatibility verified, 0 overflows, gate PASSED. | M2, M3 | DONE |
| 5 | M5: E2E Test Suite Pass & Adversarial Hardening | Pass 100% of E2E tests from `TEST_READY.md`, adversarial coverage hardening (Tier 5), 100% test pass rate on `flutter test`, and 0 errors/warnings on `dart analyze --fatal-infos`. Outputs: 43/43 E2E pass (100%), 44/44 Tier 5 adversarial pass (100%), 3,016/3,016 repo tests pass (100%), 0 lints, gate PASSED. | M4, E2E Track | DONE |
| E2E | E2E Testing Track | Independent opaque-box test track creating 4-tier test suite (Category-Partition, BVA, Pairwise, Real-World Scenarios) and publishing `TEST_READY.md`. Outputs: 43/43 tests pass (100%), TEST_READY.md published. | none | DONE |

---

## Interface Contracts

### 1. `SettingsState` (`lib/core/state/settings_state.dart`)
```dart
enum AppCurrency { usd, eur, gbp, cad }

final baseCurrencyProvider = StateProvider<AppCurrency>((ref) => AppCurrency.usd);
final privacyModeProvider = StateProvider<bool>((ref) => false);
final streamerSecurityEnabledProvider = StateProvider<bool>((ref) => false);
```

### 2. `ExchangeRateService` (`lib/features/values/domain/exchange_rate_service.dart`)
```dart
class ExchangeRateService {
  static double getRate({required AppCurrency from, required AppCurrency to});
  static double convert(double amount, {required AppCurrency from, required AppCurrency to});
  static String getCurrencySymbol(AppCurrency currency);
}
```

### 3. `VaultPricingHelper` (`lib/features/vault/domain/vault_pricing_helper.dart`)
```dart
class VaultPricingHelper {
  static String formatAmount(double? amount, {required AppCurrency currency, required bool isPrivacyMode});
  static String formatReturn(double? delta, double? percentage, {required AppCurrency currency, required bool isPrivacyMode});
}
```

### 4. `TrimmedMarketAverageCalculator` (`lib/features/values/domain/trimmed_market_average_calculator.dart`)
```dart
class TrimmedMarketAverageCalculator {
  static const double minimumFloorPrice = 0.02;
  static double? computeTrimmedAverage({
    required Map<String, double> rawQuotes, // vendor -> raw price
    required Map<String, AppCurrency> vendorCurrencies,
    required AppCurrency targetCurrency,
  });
}
```

### 5. `DeckTokenExtractor` (`lib/features/decks/domain/deck_token_extractor.dart`)
```dart
class DeckTokenExtractor {
  static List<String> extractRequiredTokens(List<String> oracleTexts);
}
```

### 6. `LockedValuesView` (`lib/features/values/presentation/widgets/locked_values_view.dart`)
```dart
class LockedValuesView extends ConsumerWidget {
  // Renders: "Values hidden. Disable Privacy Mode to view market data." with unlock button.
}
```

---

## Code Layout
```
lib/
├── core/
│   ├── database/
│   │   ├── app_database.dart                 # Drift schema v8, onUpgrade & beforeOpen migrations
│   │   └── tables/vault_items_table.dart     # 6 new physical inventory columns
│   └── state/
│       └── settings_state.dart               # baseCurrencyProvider, privacyModeProvider, streamerSecurityEnabledProvider
├── features/
│   ├── decks/
│   │   ├── domain/deck_token_extractor.dart  # Oracle text parser extracting required token checklist
│   │   └── presentation/widgets/             # Deck gear inputs, deck aggregate financial analytics
│   ├── values/                               # NEW values engine module
│   │   ├── domain/
│   │   │   ├── exchange_rate_service.dart    # Daily cached FX conversion rates
│   │   │   ├── trimmed_market_average_calculator.dart # Outlier rejection & trimmed average math
│   │   │   └── pareto_analytics_calculator.dart       # Heavy hitters & Pareto distribution math
│   │   └── presentation/widgets/
│   │       ├── interactive_multi_line_chart.dart      # CustomPainter 7D..ALL interactive chart
│   │       ├── cost_basis_pnl_widget.dart             # Cost basis & P&L delta display
│   │       ├── liquidity_reality_check_widget.dart    # Replacement vs buylist cashout & Reserved List badge
│   │       ├── fifty_two_week_range_bar.dart          # 52-week price range slider
│   │       ├── condition_treatment_matrix.dart        # Condition & finish spread grid
│   │       ├── market_spread_table.dart               # Raw vendor quotes breakdown
│   │       ├── pareto_distribution_widget.dart        # Deck/Vault Pareto concentration & micro-list
│   │       └── locked_values_view.dart                # Locked UI state when privacy mode active
│   └── vault/
│       ├── domain/vault_pricing_helper.dart           # Dynamic currency symbols & '****' redaction
│       └── presentation/widgets/
│           ├── card_detail_sheet.dart                 # 2-tab [ Details | Values ] segmented controller
│           ├── card_details_tab.dart                  # Rulings accordion, physical provenance, acquisition
│           └── card_values_tab.dart                   # Integrated values engine presentation
test/
├── core/state/settings_state_test.dart                # Settings and privacy mode unit/widget tests
├── features/
│   ├── values/
│   │   ├── domain/
│   │   │   ├── exchange_rate_service_test.dart        # Currency normalization unit tests
│   │   │   ├── trimmed_market_average_test.dart       # Anomaly rejection & trimmed average tests
│   │   │   └── pareto_analytics_test.dart             # Pareto math unit tests
│   │   └── presentation/widgets/
│   │       ├── locked_values_view_test.dart           # Locked tab widget tests
│   │       └── interactive_chart_test.dart            # Multi-line chart widget tests
│   └── vault/presentation/widgets/
│       └── card_detail_two_tab_test.dart              # 2-tab segmented control & rulings widget tests
├── migration_test.dart                                # Drift schema v8 migration test
└── values_engine_e2e_test.dart                        # 4-tier opaque-box E2E test suite
```
