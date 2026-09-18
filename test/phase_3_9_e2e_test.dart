/// Phase 3.9 Comprehensive End-to-End (E2E) Test Suite
///
/// Assembles all four test tiers:
/// - Tier 1: Feature Coverage (85 tests - 5 tests x 17 features)
/// - Tier 2: Boundary & Corner Cases (85 tests - 5 tests x 17 features)
/// - Tier 3: Cross-Feature Interactions (17 tests - pairwise feature matrix)
/// - Tier 4: Real-World Application Workloads (9 tests - end-to-end user journeys)
///
/// Total: 196 comprehensive E2E tests validating the full MTG Catalog & Vault experience.
library;

import 'package:flutter_test/flutter_test.dart';

import 'phase_3_9/tier1_feature_coverage_test.dart' as tier1;
import 'phase_3_9/tier2_boundary_corner_test.dart' as tier2;
import 'phase_3_9/tier3_cross_feature_test.dart' as tier3;
import 'phase_3_9/tier4_real_world_scenarios_test.dart' as tier4;

void main() {
  group('Phase 3.9 Comprehensive End-to-End Suite', () {
    tier1.main();
    tier2.main();
    tier3.main();
    tier4.main();
  });
}
