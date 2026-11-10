# TEST_INFRA: Countr Multi-Epic Production Overhaul (R1–R8)

⏱️ [Time Spent on This Prompt: 0h 05m 12s | Started: 14:31:16 | Current: 14:36:28]

## 1. Test Philosophy & Architecture
- **Methodology**: Requirement-driven, opaque-box end-to-end testing derived strictly from `ORIGINAL_REQUEST.md` and `PROJECT.md § Feature Inventory`.
- **Integrity**: Zero facade tests. Every test verifies actual logic, invariants, state transitions, and user-facing observable outputs.
- **Independence**: All tests are fully isolated and self-contained with isolated in-memory SQLite fixtures (`NativeDatabase.memory()`) and deterministic test personas.
- **Coverage Strategy**: Four-tier testing methodology:
  - **Tier 1 (Feature Coverage)**: ≥5 comprehensive test cases per feature covering the happy paths and primary behaviors for all 30 features from `PROJECT.md`.
  - **Tier 2 (Boundary & Corner Cases)**: ≥5 boundary, edge, stress, and adversarial cases per feature.
  - **Tier 3 (Cross-Feature Combinations)**: Pairwise interactions across disparate architectural modules.
  - **Tier 4 (Real-World Application Scenarios)**: Full multi-step end-to-end user workflows matching production user journeys.

---

## 2. Feature Inventory & Coverage Matrix

| # | Feature | Requirement | Milestone | Tier 1 Target | Tier 2 Target | Tier 3 Pairwise | Tier 4 Scenarios |
|---|---------|-------------|-----------|:-------------:|:-------------:|:---------------:|:----------------:|
| 1 | Database Schema v16 (Votes, Reactions, Comments, Wishlist) | R1–R3 | M1 | ≥5 | ≥5 | ✓ | ✓ |
| 2 | Reactive Profile Sync in Feed & Comments | R3 | M1 | ≥5 | ≥5 | ✓ | ✓ |
| 3 | Atomic Notification & Friendship Sync ("Accepted"/"Declined") | R6 | M1 | ≥5 | ≥5 | ✓ | ✓ |
| 4 | Trade Lifecycle DAO Methods (Cancel, Counter, Status) | R7 | M1 | ≥5 | ≥5 | ✓ | ✓ |
| 5 | Unsegregated Post Creation Workflow (Text-first, [+ Add Card], [+ Add Image]) | R1 | M2 | ≥5 | ≥5 | ✓ | ✓ |
| 6 | Automatic Dynamic Post Transformation (Text, Single, Multi, Media) | R1 | M2 | ≥5 | ≥5 | ✓ | ✓ |
| 7 | Card Details Share Sheet (`As Link` & `As Post`) | R1 | M2 | ≥5 | ≥5 | ✓ | ✓ |
| 8 | Home Page Card Click Lightbox Overlay (`[See Details]` navigation) | R1 | M2 | ≥5 | ≥5 | ✓ | ✓ |
| 9 | Icons-Only Post Interaction Bar (No text labels) | R2 | M3 | ≥5 | ≥5 | ✓ | ✓ |
| 10 | Reddit-Style Upvote/Downvote Pill (`[ ↑ \| Net Score \| ↓ ]`) | R2 | M3 | ≥5 | ≥5 | ✓ | ✓ |
| 11 | Emoji Reactions on Posts (5 MRU suggestions + full picker) | R2 | M3 | ≥5 | ≥5 | ✓ | ✓ |
| 12 | Relocate Wishlist/Save to Post Header Menu (`'⋮'`) | R2 | M3 | ≥5 | ≥5 | ✓ | ✓ |
| 13 | Command Center Saved Posts Dropdown (Chevron expand + count) | R2 | M3 | ≥5 | ≥5 | ✓ | ✓ |
| 14 | Deep Nested Reply Threads (Arbitrary depth + thread guides + reply banner) | R3 | M3 | ≥5 | ≥5 | ✓ | ✓ |
| 15 | True Total Comment Count (`SELECT COUNT(*)` all depths) | R3 | M3 | ≥5 | ≥5 | ✓ | ✓ |
| 16 | Comment Emoji Reactions (5 MRU suggestion bar + reaction pills) | R3 | M3 | ≥5 | ≥5 | ✓ | ✓ |
| 17 | Log Out Feature (Command Center & Settings, confirmation, signOut) | R4 | M4 | ≥5 | ≥5 | ✓ | ✓ |
| 18 | Complete 3-Step Onboarding Workflow (Individual Discord CTA, Business Places+OTP, Guest merge) | R4 | M4 | ≥5 | ≥5 | ✓ | ✓ |
| 19 | Unified Card Details Resolution (Identifier normalization, slug repair) | R5 | M5 | ≥5 | ≥5 | ✓ | ✓ |
| 20 | Vault Singles Header Spacing Fix (0dp extent when value hidden, flush search) | R5 | M5 | ≥5 | ≥5 | ✓ | ✓ |
| 21 | Vault Singles Live Search (SQLite match on name, type_line, oracle_text) | R5 | M5 | ≥5 | ≥5 | ✓ | ✓ |
| 22 | Vault Collections Set Completion Ratio (Owned / Master Catalog Total) | R5 | M5 | ≥5 | ≥5 | ✓ | ✓ |
| 23 | 3x3 Master Set View (Color with `x$qty` badge vs true grayscale dimmed) | R5 | M5 | ≥5 | ≥5 | ✓ | ✓ |
| 24 | Wishlist Badge & Filter in Vault/Binders (`isWishlisted: true`) | R2, R5 | M5 | ≥5 | ≥5 | ✓ | ✓ |
| 25 | Friends & Groups 2-Tab Restructure (Strictly 2 tabs, no Requests & Find) | R6 | M6 | ≥5 | ≥5 | ✓ | ✓ |
| 26 | Friends Tab 3-Section Layout (Requests, Friends List, Sent Requests) | R6 | M6 | ≥5 | ≥5 | ✓ | ✓ |
| 27 | Inbox Messages Draft Compose Button (Draft button + searchable user picker) | R7 | M6 | ≥5 | ≥5 | ✓ | ✓ |
| 28 | Reactive Trade Proposal Status & Unpinning (Unpin on decline/cancel/counter) | R7 | M6 | ≥5 | ≥5 | ✓ | ✓ |
| 29 | Trade Card Plain English Name Resolution (Join against cards table) | R7 | M6 | ≥5 | ≥5 | ✓ | ✓ |
| 30 | Full Trade Negotiation Lifecycle (Cancel, Edit, Counter + Value Meter) | R7 | M6 | ≥5 | ≥5 | ✓ | ✓ |

---

## 3. Directory Layout & Test Suite Architecture

```
test/e2e_overhaul/
├── e2e_overhaul_test_helpers.dart                  # Deterministic database, seed personas, contracts & widgets
├── tier1_features_m1_m2_test.dart                  # Tier 1 (Features 1–8: Schema, Feeds, Share, Lightbox) [40 tests]
├── tier1_features_m3_test.dart                     # Tier 1 (Features 9–16: Post UI, Voting, Comments Tree) [40 tests]
├── tier1_features_m4_m5_test.dart                  # Tier 1 (Features 17–24: Auth, Onboarding, Vault, Master Set) [40 tests]
├── tier1_features_m6_test.dart                     # Tier 1 (Features 25–30: Friends Hub, Messaging, Trades) [30 tests]
├── tier2_boundaries_m1_m3_test.dart                # Tier 2 (Boundaries for Features 1–16) [80 tests]
├── tier2_boundaries_m4_m6_test.dart                # Tier 2 (Boundaries for Features 17–30) [70 tests]
├── tier3_cross_feature_combinations_test.dart      # Tier 3 (Pairwise cross-epic feature interactions) [20 tests]
├── tier4_real_world_scenarios_test.dart            # Tier 4 (Full multi-step real-world user workflows R1–R8) [8 tests]
└── e2e_overhaul_suite_test.dart                    # Master suite aggregating all tiers
```

---

## 4. Coverage Thresholds
- **Tier 1 (Feature Coverage)**: 150 test cases (30 features × 5 tests).
- **Tier 2 (Boundary & Corner Cases)**: 150 test cases (30 features × 5 tests).
- **Tier 3 (Cross-Feature Combinations)**: 20 test cases covering critical pairwise interactions.
- **Tier 4 (Real-World Scenarios)**: 8 test cases verifying complete end-to-end production journeys.
- **Total Suite Target**: **328 tests**, 100% pass rate, 0 static analysis errors.

---

## 5. Execution Commands
```bash
# Run all tests in the overhaul suite
flutter test test/e2e_overhaul/

# Run individual tiers
flutter test test/e2e_overhaul/tier1_features_m1_m2_test.dart
flutter test test/e2e_overhaul/tier1_features_m3_test.dart
flutter test test/e2e_overhaul/tier1_features_m4_m5_test.dart
flutter test test/e2e_overhaul/tier1_features_m6_test.dart
flutter test test/e2e_overhaul/tier2_boundaries_m1_m3_test.dart
flutter test test/e2e_overhaul/tier2_boundaries_m4_m6_test.dart
flutter test test/e2e_overhaul/tier3_cross_feature_combinations_test.dart
flutter test test/e2e_overhaul/tier4_real_world_scenarios_test.dart

# Static Analysis
flutter analyze test/e2e_overhaul/
```

⏱️ [Time Spent on This Prompt: 0h 05m 12s | Started: 14:31:16 | Current: 14:36:28]
