import 'package:flutter/material.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/features/decks/data/daos/explore_deck_dao.dart';
import 'package:countr/features/decks/domain/models/explore_deck_models.dart';

/// Extension providing deterministic calendar day and week numbers.
extension DateTimeDayOfYear on DateTime {
  int get dayOfYear => difference(DateTime(year, 1, 1)).inDays + 1;
  int get weekOfYear => ((dayOfYear - 1) / 7).floor() + 1;
}

/// Represents the dynamic vote velocity window for the lead trending carousel.
enum LeadVelocityWindow {
  /// 48-hour activity >= threshold N (lead carousel title: "Today's Picks")
  todaysPicks,

  /// 48-hour activity < N, but 7-day activity >= threshold N (lead carousel title: "This Week's Picks")
  thisWeeksPicks,

  /// Both 48-hour and 7-day activity < N (lead carousel title: "This Month's Picks")
  thisMonthsPicks,
}

extension LeadVelocityWindowX on LeadVelocityWindow {
  String get title {
    switch (this) {
      case LeadVelocityWindow.todaysPicks:
        return "Today's Picks";
      case LeadVelocityWindow.thisWeeksPicks:
        return "This Week's Picks";
      case LeadVelocityWindow.thisMonthsPicks:
        return "This Month's Picks";
    }
  }

  Duration get duration {
    switch (this) {
      case LeadVelocityWindow.todaysPicks:
        return const Duration(hours: 48);
      case LeadVelocityWindow.thisWeeksPicks:
        return const Duration(days: 7);
      case LeadVelocityWindow.thisMonthsPicks:
        return const Duration(days: 30);
    }
  }
}

/// Metadata definition for a lateral rotating category.
class AlgorithmicCategoryDefinition {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;

  const AlgorithmicCategoryDefinition({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
  });
}

/// Service managing dynamic vote velocity windows and date-seeded lateral rotating categories.
class ExploreCategoryEngine {
  final ExploreDeckDao _dao;
  final int velocityThreshold;

  ExploreCategoryEngine(
    this._dao, {
    this.velocityThreshold = 5,
  });

  // ===========================================================================
  // 1. LEAD VELOCITY WINDOW
  // ===========================================================================

  /// Evaluates vote volume over 48h and 7d to resolve the lead velocity window.
  Future<LeadVelocityWindow> resolveLeadVelocityWindow({
    DateTime? now,
    int? customThreshold,
  }) async {
    final effectiveNow = now ?? DateTime.now();
    final threshold = customThreshold ?? velocityThreshold;

    // 1. Check 48h activity
    final cutoff48h = effectiveNow.subtract(const Duration(hours: 48));
    final count48h = await _dao.getVoteCountSince(cutoff48h);
    if (count48h >= threshold) {
      return LeadVelocityWindow.todaysPicks;
    }

    // 2. Fallback to 7-day activity
    final cutoff7d = effectiveNow.subtract(const Duration(days: 7));
    final count7d = await _dao.getVoteCountSince(cutoff7d);
    if (count7d >= threshold) {
      return LeadVelocityWindow.thisWeeksPicks;
    }

    // 3. Fallback to 30-day / all-time
    return LeadVelocityWindow.thisMonthsPicks;
  }

  /// Reactive stream watching vote mutations and emitting the current lead velocity window.
  Stream<LeadVelocityWindow> watchLeadVelocityWindow({
    DateTime? now,
    int? customThreshold,
  }) async* {
    yield await resolveLeadVelocityWindow(
      now: now,
      customThreshold: customThreshold,
    );
    yield* _dao.watchVoteActivity().asyncMap((_) async {
      return resolveLeadVelocityWindow(
        now: now,
        customThreshold: customThreshold,
      );
    });
  }

  /// Streams decks for the lead trending carousel according to the active velocity window.
  Stream<List<ExploreDeckWithVote>> watchLeadTrendingDecks({
    required LeadVelocityWindow window,
    DateTime? now,
    int limit = 15,
    String userId = 'local_user',
  }) {
    final effectiveNow = now ?? DateTime.now();
    final cutoff = effectiveNow.subtract(window.duration);
    return _dao.watchDecksByVoteVelocity(
      cutoff: cutoff,
      limit: limit,
      userId: userId,
    );
  }

  // ===========================================================================
  // 2. DETERMINISTIC DATE-SEEDED LATERAL CATEGORIES
  // ===========================================================================

  static const List<AlgorithmicCategoryDefinition> dailyPool = [
    AlgorithmicCategoryDefinition(
      id: 'trending_budget_brews',
      title: r'Trending Budget Brews (<$100)',
      subtitle: 'Competitively tuned lists that keep costs under \$100',
      icon: Icons.savings_rounded,
      accentColor: AppColors.accentEmerald,
    ),
    AlgorithmicCategoryDefinition(
      id: 'mono_color_commanders',
      title: 'Most Upvoted Mono-Color Commanders',
      subtitle: 'Pure devotion to a single slice of the color pie',
      icon: Icons.palette_rounded,
      accentColor: AppColors.accentViolet,
    ),
    AlgorithmicCategoryDefinition(
      id: 'tribal_spotlight',
      title: 'Tribal Spotlight',
      subtitle: 'Dragons, Vampires, Elves, and kindred creature synergies',
      icon: Icons.pets_rounded,
      accentColor: AppColors.accentCyan,
    ),
    AlgorithmicCategoryDefinition(
      id: 'rising_community_builders',
      title: 'Rising Community Builders',
      subtitle: 'Fresh brews authored and shared by community brewers',
      icon: Icons.group_rounded,
      accentColor: AppColors.accentAmber,
    ),
    AlgorithmicCategoryDefinition(
      id: 'top_modern_decks',
      title: 'Top Modern Decks',
      subtitle: 'Tiered 60-card Modern metagame powerhouses',
      icon: Icons.flash_on_rounded,
      accentColor: AppColors.accentRose,
    ),
    AlgorithmicCategoryDefinition(
      id: 'popular_standard_decks',
      title: 'Popular Standard Decks',
      subtitle: 'Current Standard format competitive strategies',
      icon: Icons.trending_up_rounded,
      accentColor: AppColors.accentEmerald,
    ),
  ];

  static const List<AlgorithmicCategoryDefinition> weeklyPool = [
    AlgorithmicCategoryDefinition(
      id: 'hot_new_precons',
      title: 'Hot New Precons',
      subtitle: 'Official WotC preconstructed releases ready out of the box',
      icon: Icons.whatshot_rounded,
      accentColor: AppColors.accentAmber,
    ),
    AlgorithmicCategoryDefinition(
      id: 'pioneer_showdown',
      title: 'Pioneer Showdown',
      subtitle: 'High-velocity Pioneer format contenders',
      icon: Icons.military_tech_rounded,
      accentColor: AppColors.accentRose,
    ),
    AlgorithmicCategoryDefinition(
      id: 'tribal_spotlight',
      title: 'Tribal Spotlight',
      subtitle: 'Dragons, Vampires, Elves, and kindred creature synergies',
      icon: Icons.pets_rounded,
      accentColor: AppColors.accentCyan,
    ),
    AlgorithmicCategoryDefinition(
      id: 'trending_budget_brews',
      title: r'Trending Budget Brews (<$100)',
      subtitle: 'Competitively tuned lists that keep costs under \$100',
      icon: Icons.savings_rounded,
      accentColor: AppColors.accentEmerald,
    ),
    AlgorithmicCategoryDefinition(
      id: 'suggested_commanders',
      title: 'Suggested Commanders',
      subtitle: 'Featured legendary creatures leading Commander pods',
      icon: Icons.shield_rounded,
      accentColor: AppColors.accentCyan,
    ),
    AlgorithmicCategoryDefinition(
      id: 'from_top_deck_builders',
      title: 'From Top Deck Builders',
      subtitle: 'Highly upvoted community innovations',
      icon: Icons.workspace_premium_rounded,
      accentColor: AppColors.accentAmber,
    ),
  ];

  /// Deterministically resolves the daily rotating category based on `dayOfYear`.
  AlgorithmicCategoryDefinition resolveDailyRotatingCategory([DateTime? date]) {
    final d = date ?? DateTime.now();
    final index = (d.dayOfYear - 1) % dailyPool.length;
    return dailyPool[index];
  }

  /// Deterministically resolves the weekly rotating category based on `weekOfYear`.
  AlgorithmicCategoryDefinition resolveWeeklyRotatingCategory([DateTime? date]) {
    final d = date ?? DateTime.now();
    var index = (d.weekOfYear - 1) % weeklyPool.length;
    final daily = resolveDailyRotatingCategory(d);

    // Collision avoidance: if weekly category matches daily category, shift by 1
    if (weeklyPool[index].id == daily.id) {
      index = (index + 1) % weeklyPool.length;
    }
    return weeklyPool[index];
  }

  /// Streams decks for a specific lateral rotating category.
  Stream<List<ExploreDeckWithVote>> watchCategoryDecks(
    String categoryKeyOrTitle, {
    int limit = 15,
    String userId = 'local_user',
  }) {
    return _dao.watchDecksForAlgorithmicCategory(
      categoryKeyOrTitle,
      limit: limit,
      userId: userId,
    );
  }
}
