/// Models for the Nutrition Hub — a curated, NIH/MedlinePlus-backed nutrition
/// knowledge base surfaced inside the app.
///
/// All data is intentionally local + immutable so the hub works offline and
/// renders instantly. Links point at stable MedlinePlus / NIH landing pages.

/// A food in the curated database (NIH MyPlate / MedlinePlus-aligned).
class FoodEntry {
  final String id;
  final String name;
  final String emoji;
  final FoodCategory category;
  final int caloriesPerServing;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final double fiberG;
  final String servingLabel;
  final List<String> healthBenefits;
  final List<String> tags; // e.g. anti-inflammatory, high-fiber, brain-health
  final List<String> goodForConditions; // free-form condition keywords
  final String? note;

  const FoodEntry({
    required this.id,
    required this.name,
    required this.emoji,
    required this.category,
    required this.caloriesPerServing,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.fiberG,
    required this.servingLabel,
    required this.healthBenefits,
    required this.tags,
    required this.goodForConditions,
    this.note,
  });

  bool matches(String query) {
    final q = query.toLowerCase().trim();
    if (q.isEmpty) return true;
    if (name.toLowerCase().contains(q)) return true;
    if (category.label.toLowerCase().contains(q)) return true;
    for (final t in tags) {
      if (t.toLowerCase().contains(q)) return true;
    }
    for (final b in healthBenefits) {
      if (b.toLowerCase().contains(q)) return true;
    }
    for (final c in goodForConditions) {
      if (c.toLowerCase().contains(q)) return true;
    }
    return false;
  }
}

enum FoodCategory {
  vegetables,
  fruits,
  wholeGrains,
  protein,
  dairy,
  legumes,
  nutsSeeds,
  fatsOils,
  herbsSpices,
  beverages,
  fermented,
  seafood,
}

extension FoodCategoryX on FoodCategory {
  String get label => switch (this) {
        FoodCategory.vegetables => 'Vegetables',
        FoodCategory.fruits => 'Fruits',
        FoodCategory.wholeGrains => 'Whole Grains',
        FoodCategory.protein => 'Lean Protein',
        FoodCategory.dairy => 'Dairy',
        FoodCategory.legumes => 'Legumes & Beans',
        FoodCategory.nutsSeeds => 'Nuts & Seeds',
        FoodCategory.fatsOils => 'Healthy Fats',
        FoodCategory.herbsSpices => 'Herbs & Spices',
        FoodCategory.beverages => 'Beverages',
        FoodCategory.fermented => 'Fermented',
        FoodCategory.seafood => 'Seafood',
      };

  String get emoji => switch (this) {
        FoodCategory.vegetables => '🥦',
        FoodCategory.fruits => '🍎',
        FoodCategory.wholeGrains => '🌾',
        FoodCategory.protein => '🍗',
        FoodCategory.dairy => '🥛',
        FoodCategory.legumes => '🫘',
        FoodCategory.nutsSeeds => '🥜',
        FoodCategory.fatsOils => '🫒',
        FoodCategory.herbsSpices => '🌿',
        FoodCategory.beverages => '🫖',
        FoodCategory.fermented => '🥬',
        FoodCategory.seafood => '🐟',
      };
}

/// A MedlinePlus / NIH-backed healthy recipe collection.
class NutritionRecipe {
  final String id;
  final String title;
  final String description;
  final List<String> tags;
  final List<String> goodForConditions;
  final String sourceName; // MedlinePlus, NHLBI, NIDDK, etc.
  final String url;
  final int estMinutes;

  const NutritionRecipe({
    required this.id,
    required this.title,
    required this.description,
    required this.tags,
    required this.goodForConditions,
    required this.sourceName,
    required this.url,
    this.estMinutes = 30,
  });

  bool matches(String query) {
    final q = query.toLowerCase().trim();
    if (q.isEmpty) return true;
    if (title.toLowerCase().contains(q)) return true;
    if (description.toLowerCase().contains(q)) return true;
    for (final t in tags) {
      if (t.toLowerCase().contains(q)) return true;
    }
    for (final c in goodForConditions) {
      if (c.toLowerCase().contains(q)) return true;
    }
    return false;
  }
}

/// A nutrition-education article from MedlinePlus / NIH.
class NutritionArticle {
  final String id;
  final String title;
  final String summary;
  final List<String> keyPoints;
  final String sourceName;
  final String url;
  final int estReadMinutes;
  final List<String> tags;

  const NutritionArticle({
    required this.id,
    required this.title,
    required this.summary,
    required this.keyPoints,
    required this.sourceName,
    required this.url,
    required this.tags,
    this.estReadMinutes = 5,
  });

  bool matches(String query) {
    final q = query.toLowerCase().trim();
    if (q.isEmpty) return true;
    if (title.toLowerCase().contains(q)) return true;
    if (summary.toLowerCase().contains(q)) return true;
    for (final t in tags) {
      if (t.toLowerCase().contains(q)) return true;
    }
    return false;
  }
}

/// A curated nutrition plan (DASH, Mediterranean, anti-inflammatory, etc.).
class NutritionPlan {
  final String id;
  final String name;
  final String tagline;
  final String description;
  final List<String> goodFor;
  final List<String> dailyTargets;
  final List<String> emphasize;
  final List<String> limit;
  final String sourceName;
  final String url;

  const NutritionPlan({
    required this.id,
    required this.name,
    required this.tagline,
    required this.description,
    required this.goodFor,
    required this.dailyTargets,
    required this.emphasize,
    required this.limit,
    required this.sourceName,
    required this.url,
  });
}
