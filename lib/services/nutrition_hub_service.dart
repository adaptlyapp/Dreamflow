import 'package:wellspring/models/nutrition_hub.dart';

/// Curated, NIH / MedlinePlus-aligned nutrition knowledge base used by the
/// Nutrition Hub inside the Nutrition tracker tab.
///
/// All data is local + immutable so the hub feels instant and works offline.
/// Links point at stable MedlinePlus / NIH landing pages (no fragile deep IDs).
class NutritionHubService {
  NutritionHubService._();
  static final NutritionHubService instance = NutritionHubService._();

  /// The full food database (curated).
  List<FoodEntry> get foods => _foods;

  /// All curated MedlinePlus / NIH recipes.
  List<NutritionRecipe> get recipes => _recipes;

  /// All curated MedlinePlus / NIH articles.
  List<NutritionArticle> get articles => _articles;

  /// All curated eating plans (DASH, Mediterranean, anti-inflammatory, …).
  List<NutritionPlan> get plans => _plans;

  // Filtering helpers -------------------------------------------------------

  List<FoodEntry> searchFoods({String query = '', FoodCategory? category}) {
    return _foods.where((f) {
      if (category != null && f.category != category) return false;
      return f.matches(query);
    }).toList(growable: false);
  }

  List<NutritionRecipe> searchRecipes({String query = ''}) =>
      _recipes.where((r) => r.matches(query)).toList(growable: false);

  List<NutritionArticle> searchArticles({String query = ''}) =>
      _articles.where((a) => a.matches(query)).toList(growable: false);

  /// Suggest foods that match the patient's conditions (free-form keyword match).
  List<FoodEntry> recommendedForConditions(List<String> conditions, {int max = 8}) {
    if (conditions.isEmpty) return _foods.take(max).toList(growable: false);
    final keys = conditions.map((c) => c.toLowerCase().trim()).where((c) => c.isNotEmpty).toList();
    final scored = <_Scored<FoodEntry>>[];
    for (final f in _foods) {
      int s = 0;
      for (final k in keys) {
        for (final c in f.goodForConditions) {
          if (c.toLowerCase().contains(k) || k.contains(c.toLowerCase())) s += 3;
        }
        for (final t in f.tags) {
          if (t.toLowerCase().contains(k)) s += 1;
        }
      }
      if (s > 0) scored.add(_Scored(f, s));
    }
    scored.sort((a, b) => b.score.compareTo(a.score));
    final out = scored.map((s) => s.value).take(max).toList(growable: false);
    return out.isEmpty ? _foods.take(max).toList(growable: false) : out;
  }

  List<NutritionRecipe> recommendedRecipesForConditions(List<String> conditions, {int max = 6}) {
    if (conditions.isEmpty) return _recipes.take(max).toList(growable: false);
    final keys = conditions.map((c) => c.toLowerCase().trim()).where((c) => c.isNotEmpty).toList();
    final scored = <_Scored<NutritionRecipe>>[];
    for (final r in _recipes) {
      int s = 0;
      for (final k in keys) {
        for (final c in r.goodForConditions) {
          if (c.toLowerCase().contains(k) || k.contains(c.toLowerCase())) s += 3;
        }
        for (final t in r.tags) {
          if (t.toLowerCase().contains(k)) s += 1;
        }
      }
      if (s > 0) scored.add(_Scored(r, s));
    }
    scored.sort((a, b) => b.score.compareTo(a.score));
    final out = scored.map((s) => s.value).take(max).toList(growable: false);
    return out.isEmpty ? _recipes.take(max).toList(growable: false) : out;
  }
}

class _Scored<T> {
  final T value;
  final int score;
  _Scored(this.value, this.score);
}

// =============================================================================
// Curated database
// =============================================================================

const _foods = <FoodEntry>[
  // Vegetables
  FoodEntry(
    id: 'spinach',
    name: 'Spinach',
    emoji: '🥬',
    category: FoodCategory.vegetables,
    caloriesPerServing: 23,
    proteinG: 2.9,
    carbsG: 3.6,
    fatG: 0.4,
    fiberG: 2.2,
    servingLabel: '1 cup raw (~100g)',
    healthBenefits: ['Rich in iron and folate', 'Supports bone health (vitamin K)', 'High in antioxidants (lutein)'],
    tags: ['leafy-green', 'iron', 'folate', 'anti-inflammatory', 'low-calorie'],
    goodForConditions: ['anemia', 'pregnancy', 'recovery', 'bone health', 'stroke', 'heart'],
  ),
  FoodEntry(
    id: 'broccoli',
    name: 'Broccoli',
    emoji: '🥦',
    category: FoodCategory.vegetables,
    caloriesPerServing: 55,
    proteinG: 3.7,
    carbsG: 11.2,
    fatG: 0.6,
    fiberG: 5.1,
    servingLabel: '1 cup cooked',
    healthBenefits: ['Sulforaphane supports cellular detox', 'Vitamin C immune support', 'High fiber'],
    tags: ['cruciferous', 'fiber', 'vitamin-c', 'anti-inflammatory'],
    goodForConditions: ['cancer recovery', 'heart', 'inflammation', 'gut health'],
  ),
  FoodEntry(
    id: 'sweet_potato',
    name: 'Sweet Potato',
    emoji: '🍠',
    category: FoodCategory.vegetables,
    caloriesPerServing: 112,
    proteinG: 2,
    carbsG: 26,
    fatG: 0.1,
    fiberG: 3.9,
    servingLabel: '1 medium baked',
    healthBenefits: ['Beta-carotene for vision', 'Steady energy', 'Potassium for blood pressure'],
    tags: ['complex-carb', 'beta-carotene', 'potassium', 'gut-health'],
    goodForConditions: ['diabetes', 'recovery', 'heart', 'eye health'],
  ),
  FoodEntry(
    id: 'kale',
    name: 'Kale',
    emoji: '🥬',
    category: FoodCategory.vegetables,
    caloriesPerServing: 33,
    proteinG: 2.9,
    carbsG: 6.7,
    fatG: 0.6,
    fiberG: 1.3,
    servingLabel: '1 cup raw',
    healthBenefits: ['Very high in vitamin K', 'Anti-inflammatory', 'Calcium-rich for plants'],
    tags: ['leafy-green', 'vitamin-k', 'calcium', 'anti-inflammatory'],
    goodForConditions: ['bone health', 'heart', 'inflammation'],
  ),
  FoodEntry(
    id: 'beets',
    name: 'Beets',
    emoji: '🥕',
    category: FoodCategory.vegetables,
    caloriesPerServing: 44,
    proteinG: 1.7,
    carbsG: 10,
    fatG: 0.2,
    fiberG: 2,
    servingLabel: '1/2 cup cooked',
    healthBenefits: ['Nitrates support blood flow', 'Lowers blood pressure', 'Endurance support'],
    tags: ['nitrates', 'blood-flow', 'endurance'],
    goodForConditions: ['hypertension', 'heart', 'stroke recovery'],
  ),
  FoodEntry(
    id: 'carrots',
    name: 'Carrots',
    emoji: '🥕',
    category: FoodCategory.vegetables,
    caloriesPerServing: 41,
    proteinG: 0.9,
    carbsG: 9.6,
    fatG: 0.2,
    fiberG: 2.8,
    servingLabel: '1 medium',
    healthBenefits: ['Beta-carotene', 'Eye health', 'Fiber'],
    tags: ['beta-carotene', 'eye-health', 'fiber'],
    goodForConditions: ['eye health', 'inflammation'],
  ),
  FoodEntry(
    id: 'bell_pepper',
    name: 'Bell Pepper',
    emoji: '🫑',
    category: FoodCategory.vegetables,
    caloriesPerServing: 31,
    proteinG: 1,
    carbsG: 7,
    fatG: 0.3,
    fiberG: 2.5,
    servingLabel: '1 medium',
    healthBenefits: ['3x vitamin C of an orange (red)', 'Antioxidants', 'Low calorie'],
    tags: ['vitamin-c', 'antioxidant'],
    goodForConditions: ['immune', 'inflammation'],
  ),

  // Fruits
  FoodEntry(
    id: 'blueberries',
    name: 'Blueberries',
    emoji: '🫐',
    category: FoodCategory.fruits,
    caloriesPerServing: 84,
    proteinG: 1.1,
    carbsG: 21,
    fatG: 0.5,
    fiberG: 3.6,
    servingLabel: '1 cup',
    healthBenefits: ['Anthocyanins for brain health', 'Supports memory', 'Anti-inflammatory'],
    tags: ['antioxidant', 'brain-health', 'anti-inflammatory'],
    goodForConditions: ['stroke', 'tbi', 'dementia', 'inflammation'],
  ),
  FoodEntry(
    id: 'banana',
    name: 'Banana',
    emoji: '🍌',
    category: FoodCategory.fruits,
    caloriesPerServing: 105,
    proteinG: 1.3,
    carbsG: 27,
    fatG: 0.4,
    fiberG: 3.1,
    servingLabel: '1 medium',
    healthBenefits: ['Potassium supports blood pressure', 'Quick energy', 'Easy on stomach'],
    tags: ['potassium', 'quick-energy', 'gut-friendly'],
    goodForConditions: ['hypertension', 'gi recovery', 'cramps'],
  ),
  FoodEntry(
    id: 'apple',
    name: 'Apple',
    emoji: '🍎',
    category: FoodCategory.fruits,
    caloriesPerServing: 95,
    proteinG: 0.5,
    carbsG: 25,
    fatG: 0.3,
    fiberG: 4.4,
    servingLabel: '1 medium with skin',
    healthBenefits: ['Pectin fiber for gut', 'Steady blood sugar', 'Cholesterol support'],
    tags: ['fiber', 'gut-health', 'pectin'],
    goodForConditions: ['diabetes', 'cholesterol', 'gut health'],
  ),
  FoodEntry(
    id: 'orange',
    name: 'Orange',
    emoji: '🍊',
    category: FoodCategory.fruits,
    caloriesPerServing: 62,
    proteinG: 1.2,
    carbsG: 15,
    fatG: 0.2,
    fiberG: 3.1,
    servingLabel: '1 medium',
    healthBenefits: ['Vitamin C immune support', 'Hydrating', 'Folate'],
    tags: ['vitamin-c', 'immune', 'hydration'],
    goodForConditions: ['immune', 'recovery'],
  ),
  FoodEntry(
    id: 'avocado',
    name: 'Avocado',
    emoji: '🥑',
    category: FoodCategory.fruits,
    caloriesPerServing: 234,
    proteinG: 2.9,
    carbsG: 12,
    fatG: 21,
    fiberG: 9.8,
    servingLabel: '1 medium',
    healthBenefits: ['Monounsaturated fats for heart', 'Potassium', 'Fiber'],
    tags: ['healthy-fat', 'potassium', 'heart-health'],
    goodForConditions: ['heart', 'cholesterol', 'blood pressure'],
  ),
  FoodEntry(
    id: 'strawberries',
    name: 'Strawberries',
    emoji: '🍓',
    category: FoodCategory.fruits,
    caloriesPerServing: 49,
    proteinG: 1,
    carbsG: 11.7,
    fatG: 0.5,
    fiberG: 3,
    servingLabel: '1 cup sliced',
    healthBenefits: ['Vitamin C', 'Low glycemic', 'Anti-inflammatory'],
    tags: ['antioxidant', 'low-gi', 'vitamin-c'],
    goodForConditions: ['inflammation', 'diabetes', 'heart'],
  ),

  // Whole grains
  FoodEntry(
    id: 'oats',
    name: 'Rolled Oats',
    emoji: '🌾',
    category: FoodCategory.wholeGrains,
    caloriesPerServing: 150,
    proteinG: 5,
    carbsG: 27,
    fatG: 2.5,
    fiberG: 4,
    servingLabel: '1/2 cup dry',
    healthBenefits: ['Beta-glucan lowers cholesterol', 'Steady energy', 'Gut-friendly fiber'],
    tags: ['beta-glucan', 'cholesterol', 'fiber'],
    goodForConditions: ['cholesterol', 'heart', 'diabetes', 'gut health'],
  ),
  FoodEntry(
    id: 'quinoa',
    name: 'Quinoa',
    emoji: '🌾',
    category: FoodCategory.wholeGrains,
    caloriesPerServing: 222,
    proteinG: 8,
    carbsG: 39,
    fatG: 3.6,
    fiberG: 5,
    servingLabel: '1 cup cooked',
    healthBenefits: ['Complete plant protein', 'Magnesium', 'Gluten-free'],
    tags: ['complete-protein', 'gluten-free', 'magnesium'],
    goodForConditions: ['celiac', 'diabetes', 'muscle recovery'],
  ),
  FoodEntry(
    id: 'brown_rice',
    name: 'Brown Rice',
    emoji: '🍚',
    category: FoodCategory.wholeGrains,
    caloriesPerServing: 216,
    proteinG: 5,
    carbsG: 45,
    fatG: 1.8,
    fiberG: 3.5,
    servingLabel: '1 cup cooked',
    healthBenefits: ['Sustained energy', 'B vitamins', 'Fiber'],
    tags: ['whole-grain', 'fiber'],
    goodForConditions: ['diabetes', 'gi recovery'],
  ),

  // Protein
  FoodEntry(
    id: 'salmon',
    name: 'Salmon',
    emoji: '🐟',
    category: FoodCategory.seafood,
    caloriesPerServing: 208,
    proteinG: 22,
    carbsG: 0,
    fatG: 13,
    fiberG: 0,
    servingLabel: '3 oz cooked',
    healthBenefits: ['Omega-3 (EPA/DHA) for brain & heart', 'Vitamin D', 'Anti-inflammatory'],
    tags: ['omega-3', 'brain-health', 'anti-inflammatory'],
    goodForConditions: ['stroke', 'tbi', 'heart', 'inflammation', 'depression'],
  ),
  FoodEntry(
    id: 'eggs',
    name: 'Eggs',
    emoji: '🥚',
    category: FoodCategory.protein,
    caloriesPerServing: 72,
    proteinG: 6,
    carbsG: 0.4,
    fatG: 5,
    fiberG: 0,
    servingLabel: '1 large',
    healthBenefits: ['Choline for brain', 'Complete protein', 'Affordable'],
    tags: ['choline', 'protein', 'budget'],
    goodForConditions: ['recovery', 'brain', 'muscle'],
  ),
  FoodEntry(
    id: 'chicken_breast',
    name: 'Chicken Breast',
    emoji: '🍗',
    category: FoodCategory.protein,
    caloriesPerServing: 165,
    proteinG: 31,
    carbsG: 0,
    fatG: 3.6,
    fiberG: 0,
    servingLabel: '3 oz cooked',
    healthBenefits: ['Lean protein', 'B6', 'Muscle recovery'],
    tags: ['lean-protein', 'muscle'],
    goodForConditions: ['recovery', 'wound healing', 'sarcopenia'],
  ),
  FoodEntry(
    id: 'greek_yogurt',
    name: 'Greek Yogurt',
    emoji: '🥛',
    category: FoodCategory.dairy,
    caloriesPerServing: 100,
    proteinG: 17,
    carbsG: 6,
    fatG: 0.7,
    fiberG: 0,
    servingLabel: '6 oz nonfat',
    healthBenefits: ['Probiotics for gut', 'High protein', 'Calcium'],
    tags: ['probiotic', 'calcium', 'protein'],
    goodForConditions: ['gut health', 'bone health', 'recovery'],
  ),
  FoodEntry(
    id: 'cottage_cheese',
    name: 'Cottage Cheese',
    emoji: '🧀',
    category: FoodCategory.dairy,
    caloriesPerServing: 110,
    proteinG: 12,
    carbsG: 5,
    fatG: 5,
    fiberG: 0,
    servingLabel: '1/2 cup low-fat',
    healthBenefits: ['Slow-digesting casein protein', 'Calcium'],
    tags: ['casein', 'protein', 'calcium'],
    goodForConditions: ['recovery', 'muscle'],
  ),

  // Legumes
  FoodEntry(
    id: 'lentils',
    name: 'Lentils',
    emoji: '🫘',
    category: FoodCategory.legumes,
    caloriesPerServing: 230,
    proteinG: 18,
    carbsG: 40,
    fatG: 0.8,
    fiberG: 16,
    servingLabel: '1 cup cooked',
    healthBenefits: ['Plant protein + fiber', 'Iron + folate', 'Blood sugar friendly'],
    tags: ['plant-protein', 'fiber', 'iron'],
    goodForConditions: ['anemia', 'diabetes', 'heart', 'cholesterol'],
  ),
  FoodEntry(
    id: 'black_beans',
    name: 'Black Beans',
    emoji: '🫘',
    category: FoodCategory.legumes,
    caloriesPerServing: 227,
    proteinG: 15,
    carbsG: 41,
    fatG: 0.9,
    fiberG: 15,
    servingLabel: '1 cup cooked',
    healthBenefits: ['Fiber', 'Plant protein', 'Antioxidants'],
    tags: ['fiber', 'plant-protein'],
    goodForConditions: ['diabetes', 'cholesterol', 'gut health'],
  ),
  FoodEntry(
    id: 'chickpeas',
    name: 'Chickpeas',
    emoji: '🫘',
    category: FoodCategory.legumes,
    caloriesPerServing: 269,
    proteinG: 14.5,
    carbsG: 45,
    fatG: 4.2,
    fiberG: 12.5,
    servingLabel: '1 cup cooked',
    healthBenefits: ['Plant protein', 'Resistant starch', 'Iron'],
    tags: ['plant-protein', 'fiber'],
    goodForConditions: ['diabetes', 'gut health'],
  ),

  // Nuts/seeds
  FoodEntry(
    id: 'walnuts',
    name: 'Walnuts',
    emoji: '🌰',
    category: FoodCategory.nutsSeeds,
    caloriesPerServing: 185,
    proteinG: 4.3,
    carbsG: 3.9,
    fatG: 18.5,
    fiberG: 1.9,
    servingLabel: '1 oz',
    healthBenefits: ['Plant omega-3 (ALA)', 'Brain & heart support'],
    tags: ['omega-3', 'brain-health'],
    goodForConditions: ['stroke', 'heart', 'cognition'],
  ),
  FoodEntry(
    id: 'almonds',
    name: 'Almonds',
    emoji: '🥜',
    category: FoodCategory.nutsSeeds,
    caloriesPerServing: 164,
    proteinG: 6,
    carbsG: 6,
    fatG: 14,
    fiberG: 3.5,
    servingLabel: '1 oz (23 nuts)',
    healthBenefits: ['Vitamin E', 'Magnesium', 'Heart healthy fats'],
    tags: ['vitamin-e', 'magnesium', 'heart-health'],
    goodForConditions: ['heart', 'diabetes', 'cholesterol'],
  ),
  FoodEntry(
    id: 'chia',
    name: 'Chia Seeds',
    emoji: '🌱',
    category: FoodCategory.nutsSeeds,
    caloriesPerServing: 138,
    proteinG: 4.7,
    carbsG: 12,
    fatG: 8.7,
    fiberG: 9.8,
    servingLabel: '2 tbsp',
    healthBenefits: ['Plant omega-3', 'Hydration support', 'Fiber'],
    tags: ['omega-3', 'fiber', 'hydration'],
    goodForConditions: ['heart', 'gut health', 'constipation'],
  ),
  FoodEntry(
    id: 'flaxseed',
    name: 'Ground Flaxseed',
    emoji: '🌱',
    category: FoodCategory.nutsSeeds,
    caloriesPerServing: 75,
    proteinG: 2.6,
    carbsG: 4,
    fatG: 6,
    fiberG: 3.8,
    servingLabel: '2 tbsp ground',
    healthBenefits: ['Lignans', 'Omega-3 ALA', 'Cholesterol support'],
    tags: ['omega-3', 'fiber', 'lignan'],
    goodForConditions: ['cholesterol', 'heart', 'hormone balance'],
  ),

  // Healthy fats
  FoodEntry(
    id: 'olive_oil',
    name: 'Extra Virgin Olive Oil',
    emoji: '🫒',
    category: FoodCategory.fatsOils,
    caloriesPerServing: 119,
    proteinG: 0,
    carbsG: 0,
    fatG: 13.5,
    fiberG: 0,
    servingLabel: '1 tbsp',
    healthBenefits: ['Monounsaturated fat', 'Polyphenols', 'Anti-inflammatory'],
    tags: ['mediterranean', 'anti-inflammatory', 'heart-health'],
    goodForConditions: ['heart', 'stroke', 'inflammation', 'cognition'],
  ),

  // Herbs/spices
  FoodEntry(
    id: 'turmeric',
    name: 'Turmeric',
    emoji: '🌿',
    category: FoodCategory.herbsSpices,
    caloriesPerServing: 8,
    proteinG: 0.3,
    carbsG: 1.4,
    fatG: 0.3,
    fiberG: 0.5,
    servingLabel: '1 tsp ground',
    healthBenefits: ['Curcumin anti-inflammatory', 'Pairs with black pepper'],
    tags: ['anti-inflammatory', 'curcumin'],
    goodForConditions: ['inflammation', 'arthritis', 'pain'],
    note: 'Talk to your provider if on blood thinners.',
  ),
  FoodEntry(
    id: 'ginger',
    name: 'Ginger',
    emoji: '🌿',
    category: FoodCategory.herbsSpices,
    caloriesPerServing: 5,
    proteinG: 0.1,
    carbsG: 1.1,
    fatG: 0.0,
    fiberG: 0.1,
    servingLabel: '1 tsp fresh',
    healthBenefits: ['Soothes nausea', 'Anti-inflammatory'],
    tags: ['anti-inflammatory', 'anti-nausea'],
    goodForConditions: ['nausea', 'gi recovery', 'inflammation'],
  ),
  FoodEntry(
    id: 'garlic',
    name: 'Garlic',
    emoji: '🧄',
    category: FoodCategory.herbsSpices,
    caloriesPerServing: 5,
    proteinG: 0.2,
    carbsG: 1,
    fatG: 0,
    fiberG: 0.1,
    servingLabel: '1 clove',
    healthBenefits: ['Allicin supports immunity', 'Heart health'],
    tags: ['immune', 'heart-health'],
    goodForConditions: ['immune', 'cholesterol', 'blood pressure'],
  ),

  // Beverages
  FoodEntry(
    id: 'green_tea',
    name: 'Green Tea',
    emoji: '🍵',
    category: FoodCategory.beverages,
    caloriesPerServing: 0,
    proteinG: 0,
    carbsG: 0,
    fatG: 0,
    fiberG: 0,
    servingLabel: '1 cup brewed',
    healthBenefits: ['EGCG antioxidant', 'Gentle caffeine + L-theanine focus'],
    tags: ['antioxidant', 'focus', 'metabolism'],
    goodForConditions: ['cognition', 'metabolism', 'heart'],
  ),
  FoodEntry(
    id: 'water',
    name: 'Water',
    emoji: '💧',
    category: FoodCategory.beverages,
    caloriesPerServing: 0,
    proteinG: 0,
    carbsG: 0,
    fatG: 0,
    fiberG: 0,
    servingLabel: '8 oz (240ml)',
    healthBenefits: ['Hydration', 'Joint lubrication', 'Cognition'],
    tags: ['hydration'],
    goodForConditions: ['recovery', 'kidney', 'uti prevention'],
  ),

  // Fermented
  FoodEntry(
    id: 'kefir',
    name: 'Kefir',
    emoji: '🥛',
    category: FoodCategory.fermented,
    caloriesPerServing: 110,
    proteinG: 11,
    carbsG: 12,
    fatG: 2,
    fiberG: 0,
    servingLabel: '1 cup low-fat',
    healthBenefits: ['Diverse probiotics', 'Bone support', 'Lactose-friendlier than milk'],
    tags: ['probiotic', 'calcium', 'gut-health'],
    goodForConditions: ['gut health', 'antibiotics recovery'],
  ),
  FoodEntry(
    id: 'sauerkraut',
    name: 'Sauerkraut',
    emoji: '🥬',
    category: FoodCategory.fermented,
    caloriesPerServing: 27,
    proteinG: 1.3,
    carbsG: 6,
    fatG: 0.2,
    fiberG: 4,
    servingLabel: '1 cup',
    healthBenefits: ['Live cultures', 'Vitamin K2', 'Fiber'],
    tags: ['probiotic', 'fiber', 'fermented'],
    goodForConditions: ['gut health', 'immune'],
  ),
];

// =============================================================================

const _recipes = <NutritionRecipe>[
  NutritionRecipe(
    id: 'dash_eating_plan',
    title: 'DASH Eating Plan Recipes',
    description: 'NHLBI heart-healthy recipes proven to lower blood pressure.',
    tags: ['heart-health', 'low-sodium', 'dash'],
    goodForConditions: ['hypertension', 'heart', 'stroke'],
    sourceName: 'NHLBI / NIH',
    url: 'https://www.nhlbi.nih.gov/education/dash-eating-plan',
    estMinutes: 30,
  ),
  NutritionRecipe(
    id: 'mediterranean_diet',
    title: 'Mediterranean Diet Guide',
    description: 'NIH overview of the Mediterranean eating pattern with recipe ideas.',
    tags: ['mediterranean', 'olive-oil', 'fish', 'anti-inflammatory'],
    goodForConditions: ['heart', 'cognition', 'diabetes', 'inflammation'],
    sourceName: 'MedlinePlus',
    url: 'https://medlineplus.gov/ency/patientinstructions/000110.htm',
  ),
  NutritionRecipe(
    id: 'medlineplus_recipes',
    title: 'MedlinePlus Healthy Recipes',
    description: 'Curated, condition-friendly recipes from MedlinePlus.',
    tags: ['recipes', 'healthy', 'family'],
    goodForConditions: ['general wellness'],
    sourceName: 'MedlinePlus',
    url: 'https://medlineplus.gov/recipes/',
  ),
  NutritionRecipe(
    id: 'keep_heart_healthy',
    title: 'Keep Your Heart Healthy: Recipes & Tips',
    description: 'health.gov MyHealthfinder collection for heart-healthy eating.',
    tags: ['heart-health', 'cholesterol', 'low-sodium'],
    goodForConditions: ['heart', 'cholesterol', 'hypertension'],
    sourceName: 'health.gov',
    url: 'https://health.gov/myhealthfinder/healthy-living/nutrition/heart-healthy-foods-shopping-list',
  ),
  NutritionRecipe(
    id: 'diabetes_meal_planning',
    title: 'Diabetes Meal Planning',
    description: 'CDC plate method + sample meals for blood-sugar control.',
    tags: ['diabetes', 'plate-method', 'low-gi'],
    goodForConditions: ['diabetes', 'prediabetes'],
    sourceName: 'CDC',
    url: 'https://www.cdc.gov/diabetes/healthy-eating/diabetes-meal-planning.html',
  ),
  NutritionRecipe(
    id: 'kidney_friendly',
    title: 'Kidney-Friendly Cooking',
    description: 'NIDDK guidance on low-potassium, low-sodium meals.',
    tags: ['kidney', 'low-sodium', 'low-potassium'],
    goodForConditions: ['kidney disease', 'ckd'],
    sourceName: 'NIDDK / NIH',
    url: 'https://www.niddk.nih.gov/health-information/kidney-disease/chronic-kidney-disease-ckd/eating-nutrition',
  ),
  NutritionRecipe(
    id: 'anti_inflammatory',
    title: 'Anti-Inflammatory Foods',
    description: 'Inflammation-focused eating with omega-3, produce, whole grains.',
    tags: ['anti-inflammatory', 'omega-3'],
    goodForConditions: ['inflammation', 'arthritis', 'autoimmune'],
    sourceName: 'MedlinePlus',
    url: 'https://medlineplus.gov/dietaryfats.html',
  ),
];

const _articles = <NutritionArticle>[
  NutritionArticle(
    id: 'nutrition_basics',
    title: 'Nutrition Basics',
    summary: 'How nutrients work and how to build a balanced plate.',
    keyPoints: [
      'Aim for half your plate fruits and vegetables.',
      'Choose whole grains over refined.',
      'Include lean protein at every meal.',
      'Limit added sugars and sodium.',
    ],
    sourceName: 'MedlinePlus',
    url: 'https://medlineplus.gov/nutrition.html',
    tags: ['basics', 'balance', 'plate-method'],
    estReadMinutes: 6,
  ),
  NutritionArticle(
    id: 'dietary_guidelines',
    title: 'Dietary Guidelines for Americans',
    summary: 'The federal recommendations updated every 5 years.',
    keyPoints: [
      'Follow a healthy dietary pattern at every life stage.',
      'Customize and enjoy nutrient-dense foods.',
      'Focus on meeting food group needs with nutrient-dense choices.',
      'Limit foods/beverages higher in added sugars, saturated fat, and sodium.',
    ],
    sourceName: 'USDA / HHS',
    url: 'https://www.dietaryguidelines.gov/',
    tags: ['guidelines', 'patterns'],
    estReadMinutes: 8,
  ),
  NutritionArticle(
    id: 'myplate',
    title: 'MyPlate: What a Healthy Plate Looks Like',
    summary: 'Simple visual for building meals from the 5 food groups.',
    keyPoints: [
      'Make half your plate fruits and veggies.',
      'Make at least half your grains whole grains.',
      'Vary your protein routine.',
      'Move to low-fat or fat-free dairy/fortified soy.',
    ],
    sourceName: 'USDA MyPlate',
    url: 'https://www.myplate.gov/',
    tags: ['myplate', 'visual', 'basics'],
    estReadMinutes: 4,
  ),
  NutritionArticle(
    id: 'fiber',
    title: 'Dietary Fiber',
    summary: 'Why fiber matters for the heart, gut, and blood sugar.',
    keyPoints: [
      'Adults: aim for 25–34g/day depending on age and sex.',
      'Soluble fiber helps lower cholesterol and blood sugar.',
      'Insoluble fiber supports regularity.',
      'Drink water as you increase fiber.',
    ],
    sourceName: 'MedlinePlus',
    url: 'https://medlineplus.gov/dietaryfiber.html',
    tags: ['fiber', 'gut-health'],
  ),
  NutritionArticle(
    id: 'omega3',
    title: 'Omega-3 Fatty Acids',
    summary: 'How EPA, DHA, and ALA support brain, heart, and inflammation.',
    keyPoints: [
      'Best sources: fatty fish (salmon, sardines), walnuts, chia, flax.',
      'Aim for 2 servings of fatty fish per week.',
      'Talk to your provider before high-dose supplements.',
    ],
    sourceName: 'NIH ODS',
    url: 'https://ods.od.nih.gov/factsheets/Omega3FattyAcids-Consumer/',
    tags: ['omega-3', 'brain', 'heart'],
  ),
  NutritionArticle(
    id: 'sodium',
    title: 'Sodium in Your Diet',
    summary: 'Why sodium matters and how to spot it on labels.',
    keyPoints: [
      'Most Americans eat 50% more sodium than recommended.',
      'Aim for <2300mg/day; lower if you have high blood pressure.',
      'Check labels — most sodium hides in packaged foods.',
    ],
    sourceName: 'FDA',
    url: 'https://www.fda.gov/food/nutrition-education-resources-materials/sodium-your-diet',
    tags: ['sodium', 'blood-pressure'],
  ),
  NutritionArticle(
    id: 'protein_recovery',
    title: 'Protein for Recovery',
    summary: 'Protein needs increase after injury, surgery, or illness.',
    keyPoints: [
      'Spread protein across all meals (20–35g/meal).',
      'Combine plant and animal sources for variety.',
      'Older adults benefit from higher per-meal protein.',
    ],
    sourceName: 'MedlinePlus',
    url: 'https://medlineplus.gov/ency/article/002467.htm',
    tags: ['protein', 'recovery', 'wound healing'],
  ),
  NutritionArticle(
    id: 'hydration',
    title: 'Hydration: Why Water Matters',
    summary: 'Hydration affects energy, cognition, and recovery.',
    keyPoints: [
      'Thirst can be a late signal — sip throughout the day.',
      'Urine color is a quick check (pale yellow = good).',
      'Caffeinated drinks count, but plain water is best.',
    ],
    sourceName: 'MedlinePlus',
    url: 'https://medlineplus.gov/dehydration.html',
    tags: ['hydration', 'water'],
  ),
];

const _plans = <NutritionPlan>[
  NutritionPlan(
    id: 'dash',
    name: 'DASH',
    tagline: 'Heart & blood pressure',
    description: 'Dietary Approaches to Stop Hypertension — emphasizes produce, whole grains, lean protein, and limits sodium.',
    goodFor: ['Hypertension', 'Heart disease', 'Stroke recovery'],
    dailyTargets: ['Sodium <2300mg (1500mg if HTN)', '4–5 servings veg', '4–5 servings fruit', '6–8 servings whole grains'],
    emphasize: ['Vegetables', 'Fruit', 'Whole grains', 'Lean protein', 'Low-fat dairy', 'Nuts/seeds/legumes'],
    limit: ['Sodium', 'Sweets', 'Red meat', 'Sugary drinks'],
    sourceName: 'NHLBI / NIH',
    url: 'https://www.nhlbi.nih.gov/education/dash-eating-plan',
  ),
  NutritionPlan(
    id: 'mediterranean',
    name: 'Mediterranean',
    tagline: 'Brain, heart, & longevity',
    description: 'Plant-forward pattern rich in olive oil, fish, legumes, and produce — strong evidence for heart and brain health.',
    goodFor: ['Heart', 'Cognition', 'Diabetes', 'Inflammation'],
    dailyTargets: ['Olive oil as main fat', 'Fish 2x/week', 'Beans/legumes daily'],
    emphasize: ['Olive oil', 'Fish', 'Vegetables', 'Whole grains', 'Legumes', 'Nuts'],
    limit: ['Red meat', 'Ultraprocessed foods', 'Added sugar'],
    sourceName: 'MedlinePlus',
    url: 'https://medlineplus.gov/ency/patientinstructions/000110.htm',
  ),
  NutritionPlan(
    id: 'mind',
    name: 'MIND',
    tagline: 'Brain protection',
    description: 'Hybrid of DASH and Mediterranean designed to support cognition.',
    goodFor: ['TBI', 'Stroke', 'Cognition', 'Dementia prevention'],
    dailyTargets: ['Leafy greens daily', 'Berries 2x/week', 'Nuts daily'],
    emphasize: ['Leafy greens', 'Berries', 'Nuts', 'Olive oil', 'Fish', 'Whole grains'],
    limit: ['Butter', 'Cheese', 'Red meat', 'Sweets'],
    sourceName: 'NIH NIA',
    url: 'https://www.nia.nih.gov/health/healthy-eating-nutrition-and-diet',
  ),
  NutritionPlan(
    id: 'plate',
    name: 'Diabetes Plate Method',
    tagline: 'Blood sugar control',
    description: 'Half non-starchy veg, quarter lean protein, quarter complex carbs — no counting required.',
    goodFor: ['Diabetes', 'Prediabetes', 'Weight'],
    dailyTargets: ['Plate method at every meal', 'Water instead of sweetened drinks'],
    emphasize: ['Non-starchy veg', 'Lean protein', 'Whole grains', 'Beans'],
    limit: ['Refined carbs', 'Sugary drinks', 'Fried foods'],
    sourceName: 'CDC',
    url: 'https://www.cdc.gov/diabetes/healthy-eating/diabetes-meal-planning.html',
  ),
  NutritionPlan(
    id: 'antiinflammatory',
    name: 'Anti-Inflammatory',
    tagline: 'Pain & autoimmune support',
    description: 'Focuses on omega-3s, produce, spices, and whole foods that lower inflammation markers.',
    goodFor: ['Arthritis', 'Autoimmune', 'Chronic pain', 'Inflammation'],
    dailyTargets: ['Omega-3 source daily', '5+ servings produce', 'Limit added sugar'],
    emphasize: ['Fatty fish', 'Berries', 'Leafy greens', 'Turmeric', 'Olive oil'],
    limit: ['Ultraprocessed foods', 'Added sugar', 'Refined oils'],
    sourceName: 'MedlinePlus',
    url: 'https://medlineplus.gov/dietaryfats.html',
  ),
  NutritionPlan(
    id: 'kidney',
    name: 'Kidney-Friendly',
    tagline: 'CKD-aware eating',
    description: 'Adjusted protein, potassium, phosphorus, and sodium for chronic kidney disease.',
    goodFor: ['CKD', 'Kidney disease'],
    dailyTargets: ['Watch potassium & phosphorus', 'Limit sodium', 'Right-size protein with provider'],
    emphasize: ['Lower-potassium produce', 'Refined grains if advised', 'Lean protein'],
    limit: ['High-potassium foods (per provider)', 'Sodium', 'Phosphate additives'],
    sourceName: 'NIDDK / NIH',
    url: 'https://www.niddk.nih.gov/health-information/kidney-disease/chronic-kidney-disease-ckd/eating-nutrition',
  ),
];
