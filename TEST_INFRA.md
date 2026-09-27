# E2E Test Infra: Phase 4.7 "Variant 1" Lifetap MTG Life Counter

## Test Philosophy
- **Requirement-Driven & Opaque-Box**: Tests are derived strictly from `ORIGINAL_REQUEST.md` (Phase 4.7 R1–R7) and `PROJECT.md` specifications, exercising the Lifetap companion utility, dynamic pod layouts (1v1 to 6-player), continuous Drift auto-save, P2P mesh synchronization, commander damage matrix, floating mana drawers, and randomizer utilities as tabletop players and devices would.
- **Methodology**: Systematic 4-Tier test suite:
  - **Tier 1 (Feature Coverage)**: Direct verification of primary behaviors and interface contracts across all 7 core feature areas (>=5 test cases per area).
  - **Tier 2 (Boundary & Corner Cases)**: Edge conditions, empty/corrupted payloads, life total extremes (-99 to 99999), 20 vs 21 commander damage lethal thresholds, 9 vs 10 poison lethal thresholds, zero mana, disconnect/reconnect packet handling, and tablet vs phone boundary (exact 600dp).
  - **Tier 3 (Cross-Feature Combinations & Pairwise Interactions)**: Multi-feature interactions (P2P mesh + Life touch + DB ledger; Tablet tool rail + Commander damage 21 alert + Defeat status; Floating mana pool + Storm counter + Clear pool; Pod-wide Monarch/Initiative exclusivity; Session recovery after app lifecycle termination; Global reset game preserving pod seating; Strict absence of turn timers).
  - **Tier 4 (Real-World MTG Game Scenarios)**: High-fidelity application workloads:
    - Scenario 1: 4-Player Commander (EDH) Pod with Atraxa Infect (10 poison defeat) and Edgar Markov lethal commander damage (21 damage).
    - Scenario 2: 1v1 Competitive Modern Match with fetchlands, shocklands, hold-to-accelerate life reduction, and game 2 reset.
    - Scenario 3: Storm Combo Turn with floating mana pool WUBRGC, storm count 15, and one-tap Clear Pool.
    - Scenario 4: 6-Player Chaos Pod with 2x3 inverted layout, Day/Night pod synchronization, and contested Monarch/Initiative tokens.
    - Scenario 5: P2P Multiplayer Mesh Sync with transient disconnection, catch-up replay, and lifecycle crash recovery.
- **Independence & Isolation**: Every test is self-contained, sets up its own isolated state, utilizes headless in-memory networking and reactive mock DAOs, makes zero external network calls, and leaves no side effects.
- **Strict Turn-Timer Omission**: 100% absence of turn-passing, turn timers, or chess clocks across all widgets and domain models.

---

## Feature Inventory & Test Mapping

Mapping all 48 inventoried features from `PROJECT.md` across all 4 tiers:

| # | Feature | Requirement Source | Milestone | Tier 1 | Tier 2 | Tier 3 | Tier 4 |
|---|---------|-------------------|:---------:|:------:|:------:|:------:|:------:|
| 1 | Drift Schema v10 Upgrade | R3, R7 | M1 | ✓ | ✓ | ✓ | ✓ |
| 2 | `MatchSessions` Table | R3, R7 | M1 | ✓ | ✓ | ✓ | ✓ |
| 3 | `MatchPlayers` Table | R3, R7 | M1 | ✓ | ✓ | ✓ | ✓ |
| 4 | `MatchEvents` Table | R3, R7 | M1 | ✓ | ✓ | ✓ | ✓ |
| 5 | `MatchDao` Implementation | R3, R7 | M1 | ✓ | ✓ | ✓ | ✓ |
| 6 | Continuous DB Logging | R3 | M1 | ✓ | ✓ | ✓ | ✓ |
| 7 | Session State Recovery | R3 | M1 | ✓ | ✓ | ✓ | ✓ |
| 8 | Defensive DB Runtime Migration | R7 | M1 | ✓ | ✓ | ✓ | ✓ |
| 9 | P2P Protocol Packet Schemas | R2 | M2 | ✓ | ✓ | ✓ | ✓ |
| 10 | `P2pTransport` & `InMemoryP2pMesh` | R2 | M2 | ✓ | ✓ | ✓ | ✓ |
| 11 | Host WebSocket Server | R2 | M2 | ✓ | ✓ | ✓ | ✓ |
| 12 | Client WebSocket Connection | R2 | M2 | ✓ | ✓ | ✓ | ✓ |
| 13 | UDP Subnet Discovery | R2 | M2 | ✓ | ✓ | ✓ | ✓ |
| 14 | Room Code & QR Direct Connect | R2 | M2 | ✓ | ✓ | ✓ | ✓ |
| 15 | Delta-Based Conflict Resolution | R2 | M2 | ✓ | ✓ | ✓ | ✓ |
| 16 | 1v1 Split Pod Layout | R2 | M3 | ✓ | ✓ | ✓ | ✓ |
| 17 | 3-Player Asymmetric Pod Layout | R2 | M3 | ✓ | ✓ | ✓ | ✓ |
| 18 | 4-Player 2x2 Quadrant Layout | R2 | M3 | ✓ | ✓ | ✓ | ✓ |
| 19 | 5-Player Hybrid Pod Layout | R2 | M3 | ✓ | ✓ | ✓ | ✓ |
| 20 | 6-Player 2x3 Grid Layout | R2 | M3 | ✓ | ✓ | ✓ | ✓ |
| 21 | Opposing Player Inversion | R2 | M3 | ✓ | ✓ | ✓ | ✓ |
| 22 | Phone Pull-Out Drawers | R2 | M3 | ✓ | ✓ | ✓ | ✓ |
| 23 | Tablet Perpetual Tool Rails | R2 | M3 | ✓ | ✓ | ✓ | ✓ |
| 24 | Center Hub Floating Button | R5 | M3 | ✓ | ✓ | ✓ | ✓ |
| 25 | Primary Life Numeric Display | R4 | M4 | ✓ | ✓ | ✓ | ✓ |
| 26 | Split Touch Hitboxes | R4 | M4 | ✓ | ✓ | ✓ | ✓ |
| 27 | Transient Delta Indicator Badge | R4 | M4 | ✓ | ✓ | ✓ | ✓ |
| 28 | Hold-to-Accelerate Gesture Ticker | R4 | M4 | ✓ | ✓ | ✓ | ✓ |
| 29 | Pre-Game Deck Selection | R1 | M4 | ✓ | ✓ | ✓ | ✓ |
| 30 | Dynamic Commander Art Backdrop | R1 | M4 | ✓ | ✓ | ✓ | ✓ |
| 31 | Scryfall Catalog Art Override | R1 | M4 | ✓ | ✓ | ✓ | ✓ |
| 32 | Commander Damage Ledger | R4 | M4 | ✓ | ✓ | ✓ | ✓ |
| 33 | Opposing Commander Avatars | R4 | M4 | ✓ | ✓ | ✓ | ✓ |
| 34 | 21-Point Lethal Damage Alert | R4 | M4 | ✓ | ✓ | ✓ | ✓ |
| 35 | Poison / Infect Lethal Tracker | R4 | M4 | ✓ | ✓ | ✓ | ✓ |
| 36 | Energy & Experience Counters | R4 | M4 | ✓ | ✓ | ✓ | ✓ |
| 37 | Commander Tax Calculator | R4 | M4 | ✓ | ✓ | ✓ | ✓ |
| 38 | Monarch & Initiative Tokens | R4 | M4 | ✓ | ✓ | ✓ | ✓ |
| 39 | Pod-Wide Shared Day/Night Toggle | R4 | M4 | ✓ | ✓ | ✓ | ✓ |
| 40 | Floating Mana Drawer | R6 | M4 | ✓ | ✓ | ✓ | ✓ |
| 41 | One-Tap "Clear Pool" Action | R6 | M4 | ✓ | ✓ | ✓ | ✓ |
| 42 | Animated 3D Coin Flip | R5 | M5 | ✓ | ✓ | ✓ | ✓ |
| 43 | Polyhedral Dice Roller Suite | R5 | M5 | ✓ | ✓ | ✓ | ✓ |
| 44 | Random Player Roulette Highlight | R5 | M5 | ✓ | ✓ | ✓ | ✓ |
| 45 | Starting Life Templates | R5 | M5 | ✓ | ✓ | ✓ | ✓ |
| 46 | Global "Reset Game" Action | R5 | M5 | ✓ | ✓ | ✓ | ✓ |
| 47 | Command Center Launch Hook | R1 | M5 | ✓ | ✓ | ✓ | ✓ |
| 48 | Strict Turn Logic Omission | R7 | M5 | ✓ | ✓ | ✓ | ✓ |

---

## Test Architecture

- **Primary E2E Test Suite**: `test/e2e_life_counter_variant1_test.dart`
- **Contract & Test Harness**: `test/life_counter_test_contracts.dart`
- **Execution Command**: `flutter test test/e2e_life_counter_variant1_test.dart`
- **Static Analysis Command**: `dart analyze --fatal-infos`
- **Pass Semantics**: Exit code 0, 100% test assertions pass, zero exceptions, zero warnings.

---

## 4-Tier Test Breakdown

### Tier 1: Feature Coverage (>=5 per feature area)
- **Area 1: Persistence, DB Schema v10 & Recovery** (Features 1-8):
  - T1.1.1: Schema v10 structure & table column invariants
  - T1.1.2: Session creation with format presets & starting life
  - T1.1.3: Continuous event logging with monotonic sequence numbers
  - T1.1.4: Real-time life update & watch stream emission
  - T1.1.5: Session recovery detection and board reconstruction
- **Area 2: P2P Mesh Networking & Packet Synchronization** (Features 9-15):
  - T1.2.1: Packet serialization round-trip (toJson/fromJson)
  - T1.2.2: InMemoryP2pMesh routing & multi-peer delivery
  - T1.2.3: Host delta broadcasting & sequence ordering
  - T1.2.4: Commutative conflict resolution across simultaneous updates
  - T1.2.5: Subnet discovery beacon encoding & room code validation
- **Area 3: Pod Layouts & Responsive UI** (Features 16-24):
  - T1.3.1: 1v1 split layout with opposing player 180° inversion
  - T1.3.2: 3-player asymmetric layout structure
  - T1.3.3: 4-player 2x2 quadrant layout structure
  - T1.3.4: 5-player & 6-player (2x3) pod layout rendering
  - T1.3.5: Tablet tool rail (>=600dp) vs Phone drawer (<600dp) toggle
  - T1.3.6: Center crossroads 48px floating hub button
- **Area 4: Core Mechanics, Life Total & Touch/Hold Ticker** (Features 25-31):
  - T1.4.1: Massive life display rendering with tabular figures
  - T1.4.2: Split touch hitboxes (left -1, right +1)
  - T1.4.3: Transient delta pill badge accumulating deltas (+3/-5)
  - T1.4.4: Hold-to-accelerate gesture ticker mechanics
  - T1.4.5: Commander art backdrop rendering & Scryfall override
- **Area 5: Commander Damage Matrix, Lethal Alerts & Secondary Counters** (Features 32-39):
  - T1.5.1: Commander damage ledger tracking incoming damage per opponent
  - T1.5.2: 21-point commander damage lethal alert & crimson border
  - T1.5.3: Poison/infect lethal tracker with 10-point lethal banner
  - T1.5.4: Energy & Experience counters increment/decrement
  - T1.5.5: Monarch & Initiative token claiming and exclusivity
  - T1.5.6: Pod-wide shared Day/Night cycle toggle
- **Area 6: Floating Mana Pool, Storm & Clear Action** (Features 40-41):
  - T1.6.1: Floating mana drawer rendering WUBRGC mana pips
  - T1.6.2: Color mana pool steppers increment and decrement
  - T1.6.3: Storm counter increment with mana additions
  - T1.6.4: One-tap "Clear Pool" zeroes all 6 mana pools and storm counter
  - T1.6.5: Clearing mana pool preserves player life total unchanged
- **Area 7: Randomizer Hub, Life Presets, Reset & Strict Turn-Timer Absence** (Features 42-48):
  - T1.7.1: Coin flip generates valid Heads/Tails result
  - T1.7.2: Polyhedral dice roller suite (D4, D6, D8, D10, D12, D20, D100)
  - T1.7.3: Random player & random opponent roulette selector
  - T1.7.4: Starting life format presets (20, 30, 40, Custom)
  - T1.7.5: Global "Reset Game" reverts counters while preserving pod
  - T1.7.6: Strict turn-timer absence: zero turn-passing widgets or timers

### Tier 2: Boundary & Corner Cases (>=5 per feature area)
- **Area 1: Persistence Boundaries**:
  - T2.1.1: Empty player list or single player session edge handling
  - T2.1.2: Corrupted or malformed event payload JSON recovery
  - T2.1.3: Extreme high sequence numbers without overflow
  - T2.1.4: Session abandon vs complete lifecycle transitions
  - T2.1.5: Max player count boundary (exactly 6 players)
- **Area 2: Network Boundaries**:
  - T2.2.1: Disconnected transport error handling
  - T2.2.2: Reconnection catch-up and state synchronization
  - T2.2.3: Zero/empty payload handling
  - T2.2.4: Out-of-order sequence packet rejection
  - T2.2.5: Rapid burst packet flood resilience
- **Area 3: Layout & Viewport Boundaries**:
  - T2.3.1: Exact 600dp shortestSide tablet vs phone threshold boundary
  - T2.3.2: Extremely narrow aspect ratio layout scaling
  - T2.3.3: Large text accessibility scaling (200% font scale)
  - T2.3.4: Rapid rotation and orientation resizing
  - T2.3.5: Dynamic player addition/removal layout stability
- **Area 4: Life Total Boundaries**:
  - T2.4.1: Life drops to exactly 0 (lethal state triggered)
  - T2.4.2: Negative life values allowed (e.g. -5 for combat calculation)
  - T2.4.3: Extreme high life totals (99,999) without UI overflow
  - T2.4.4: Rapid alternating tap flurry (+1, -1, +1, -1) delta badge math
  - T2.4.5: Simultaneous touch on both hitboxes
- **Area 5: Commander Damage & Lethality Boundaries**:
  - T2.5.1: Exactly 20 commander damage (non-lethal) vs 21 (lethal)
  - T2.5.2: Exactly 9 poison counters (non-lethal) vs 10 (lethal)
  - T2.5.3: Commander damage cannot be negative (< 0 clamped)
  - T2.5.4: Multiple opponents dealing commander damage simultaneously
  - T2.5.5: Simultaneous poison lethal (10) and commander damage lethal (21)
- **Area 6: Mana Pool Boundaries**:
  - T2.6.1: Negative mana protection (cannot drop below 0)
  - T2.6.2: "Clear Pool" on already empty mana pool (no-op/safe)
  - T2.6.3: High mana values (999 colorless mana from Infinite Combo)
  - T2.6.4: Rapid multi-color tapping without state desync
  - T2.6.5: Storm counter bounds and clear verification
- **Area 7: Randomizer & Utility Boundaries**:
  - T2.7.1: D4 rolls strictly bounded in [1, 4]
  - T2.7.2: D100 rolls strictly bounded in [1, 100]
  - T2.7.3: Random player selection in 1v1 pod (strictly 0 or 1)
  - T2.7.4: Random opponent selection never selects self
  - T2.7.5: Re-roll distribution fairness sanity check

### Tier 3: Cross-Feature Interactions & Combinations (Pairwise)
- T3.1: Local P2P sync + Life touch + DB ledger: Host applies local delta, broadcasts over P2P mesh, writes to event ledger.
- T3.2: Tablet tool rail + Commander damage 21 alert + Defeat status: Full UI state reflects lethal alert and red vignette.
- T3.3: Floating mana pool + Storm counter + Clear pool: Floating mana increments trigger storm, one-tap clear resets mana while preserving life.
- T3.4: Pod-wide Monarch/Initiative token exclusivity: Claiming Monarch automatically removes token from previous holder.
- T3.5: Crash recovery dialog restoring exact multi-player state with commander damage, poison, and deck associations.
- T3.6: Global "Reset Game" reverts all player life to startingLife and zeroes counters while strictly preserving pod seating.
- T3.7: Strict turn-timer omission audit: Complete verification that no turn timers or pass buttons exist anywhere.

### Tier 4: Real-World MTG Game Scenarios
- T4.1: **Scenario 1: 4-Player Commander (EDH) Pod**: Edgar Markov vs Urza vs Atraxa vs The Ur-Dragon. Multi-turn combat: Atraxa infect attacks (Poison accumulates to 10 -> defeat), Edgar deals 21 commander damage to Urza -> Urza lethal commander defeat.
- T4.2: **Scenario 2: 1v1 Competitive Modern Match**: 20 starting life, fetchland life loss (-1 per tap), shockland entry (-2), rapid hold-to-accelerate life reduction, coin flip to determine who goes first, match reset for Game 2 preserving decks.
- T4.3: **Scenario 3: Storm Combo Turn with Floating Mana Pool**: Grapeshot storm turn: Player floats {U}{U}{B}{R}{R}{R}, increments storm counter to 15, casts spell, clicks "Clear Pool" -> mana and storm reset to 0 without affecting opponent life totals.
- T4.4: **Scenario 4: 6-Player Chaos Pod**: 6 players in 2x3 layout with inverted top row (P1, P2, P3 rotated 180°), Day/Night cycle flips pod-wide from Day to Night, Initiative and Monarch contested between 3 players, random player roulette selects target opponent.
- T4.5: **Scenario 5: P2P Multiplayer Mesh Sync with Network Interruption & Session Recovery**: Host and client devices exchange deltas, client briefly disconnects, reconnects with catch-up sync, device encounters app lifecycle interrupt, "Continue Match" dialog successfully restores complete match state.

---

## Coverage Thresholds & Quality Gates
- **Tier 1**: >=5 tests per core feature area (7 areas * >=5 = >=35 tests).
- **Tier 2**: >=5 tests per boundary area (7 areas * >=5 = >=35 tests).
- **Tier 3**: Complete pairwise interaction coverage (>=7 comprehensive combinations).
- **Tier 4**: 5 authentic MTG tabletop workloads.
- **Total Suite Target**: >=80 comprehensive, opaque-box, deterministic tests.
- **Pass Semantics**: 100% pass on `flutter test test/e2e_life_counter_variant1_test.dart` and 0 errors/warnings on `dart analyze --fatal-infos`.
