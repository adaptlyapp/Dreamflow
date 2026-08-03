import 'package:flutter/foundation.dart';

@immutable
class DietPlanInput {
  final String primaryGoal;
  final String? diagnosisOrNeed;
  final List<String> allergies;
  final List<String> restrictions;
  final String? budget;
  final String? cookingAbility;
  final List<String> preferredFoods;
  final List<String> foodsToAvoid;
  final int mealsPerDay;
  final int? targetCalories;
  final int? targetProteinG;
  final int? targetCarbsG;
  final int? targetFatsG;

  const DietPlanInput({
    required this.primaryGoal,
    this.diagnosisOrNeed,
    required this.allergies,
    required this.restrictions,
    this.budget,
    this.cookingAbility,
    required this.preferredFoods,
    required this.foodsToAvoid,
    required this.mealsPerDay,
    this.targetCalories,
    this.targetProteinG,
    this.targetCarbsG,
    this.targetFatsG,
  });

  Map<String, dynamic> toJson() => {
        'primaryGoal': primaryGoal,
        if (diagnosisOrNeed != null) 'diagnosisOrNeed': diagnosisOrNeed,
        'allergies': allergies,
        'restrictions': restrictions,
        if (budget != null) 'budget': budget,
        if (cookingAbility != null) 'cookingAbility': cookingAbility,
        'preferredFoods': preferredFoods,
        'foodsToAvoid': foodsToAvoid,
        'mealsPerDay': mealsPerDay,
        if (targetCalories != null) 'targetCalories': targetCalories,
        if (targetProteinG != null) 'targetProteinG': targetProteinG,
        if (targetCarbsG != null) 'targetCarbsG': targetCarbsG,
        if (targetFatsG != null) 'targetFatsG': targetFatsG,
      };
}

@immutable
class DietPlanMeal {
  final String title;
  final String description;
  final String? approxMacros;

  const DietPlanMeal({
    required this.title,
    required this.description,
    this.approxMacros,
  });

  factory DietPlanMeal.fromJson(Map<String, dynamic> json) => DietPlanMeal(
        title: (json['title'] ?? '').toString(),
        description: (json['description'] ?? '').toString(),
        approxMacros: json['approxMacros']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        'title': title,
        'description': description,
        if (approxMacros != null) 'approxMacros': approxMacros,
      };
}

@immutable
class DietPlanDay {
  final String dayLabel;
  final Map<String, DietPlanMeal> meals; // breakfast/lunch/dinner/snack...
  final String? notes;

  const DietPlanDay({
    required this.dayLabel,
    required this.meals,
    this.notes,
  });

  factory DietPlanDay.fromJson(Map<String, dynamic> json) {
    final mealsRaw = (json['meals'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
    final meals = <String, DietPlanMeal>{};
    for (final e in mealsRaw.entries) {
      final v = e.value;
      if (v is Map<String, dynamic>) {
        meals[e.key] = DietPlanMeal.fromJson(v);
      } else if (v is Map) {
        meals[e.key] = DietPlanMeal.fromJson(v.cast<String, dynamic>());
      }
    }
    return DietPlanDay(
      dayLabel: (json['day'] ?? '').toString(),
      meals: meals,
      notes: json['notes']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'day': dayLabel,
        'meals': {for (final e in meals.entries) e.key: e.value.toJson()},
        if (notes != null) 'notes': notes,
      };
}

@immutable
class DietPlanResult {
  final String title;
  final Map<String, dynamic> nutritionTargets;
  final List<DietPlanDay> days;
  final List<String> groceryList;
  final List<String> mealPrepSuggestions;
  final List<String> whyThisFits;
  final String medicalSafetyDisclaimer;
  final DateTime createdAt;
  final DateTime updatedAt;

  const DietPlanResult({
    required this.title,
    required this.nutritionTargets,
    required this.days,
    required this.groceryList,
    required this.mealPrepSuggestions,
    required this.whyThisFits,
    required this.medicalSafetyDisclaimer,
    required this.createdAt,
    required this.updatedAt,
  });

  DietPlanResult copyWith({
    String? title,
    Map<String, dynamic>? nutritionTargets,
    List<DietPlanDay>? days,
    List<String>? groceryList,
    List<String>? mealPrepSuggestions,
    List<String>? whyThisFits,
    String? medicalSafetyDisclaimer,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      DietPlanResult(
        title: title ?? this.title,
        nutritionTargets: nutritionTargets ?? this.nutritionTargets,
        days: days ?? this.days,
        groceryList: groceryList ?? this.groceryList,
        mealPrepSuggestions: mealPrepSuggestions ?? this.mealPrepSuggestions,
        whyThisFits: whyThisFits ?? this.whyThisFits,
        medicalSafetyDisclaimer: medicalSafetyDisclaimer ?? this.medicalSafetyDisclaimer,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  factory DietPlanResult.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    final created = DateTime.tryParse((json['createdAt'] ?? '').toString());
    final updated = DateTime.tryParse((json['updatedAt'] ?? '').toString());
    final daysRaw = json['days'];
    final days = <DietPlanDay>[];
    if (daysRaw is List) {
      for (final d in daysRaw) {
        if (d is Map<String, dynamic>) days.add(DietPlanDay.fromJson(d));
        if (d is Map) days.add(DietPlanDay.fromJson(d.cast<String, dynamic>()));
      }
    }
    return DietPlanResult(
      title: (json['title'] ?? 'Your 7‑Day Plan').toString(),
      nutritionTargets: (json['nutritionTargets'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{},
      days: days,
      groceryList: (json['groceryList'] is List)
          ? (json['groceryList'] as List).map((e) => e.toString()).toList()
          : const [],
      mealPrepSuggestions: (json['mealPrepSuggestions'] is List)
          ? (json['mealPrepSuggestions'] as List).map((e) => e.toString()).toList()
          : const [],
      whyThisFits: (json['whyThisFits'] is List)
          ? (json['whyThisFits'] as List).map((e) => e.toString()).toList()
          : const [],
      medicalSafetyDisclaimer: (json['medicalSafetyDisclaimer'] ?? '').toString(),
      createdAt: created ?? now,
      updatedAt: updated ?? created ?? now,
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'nutritionTargets': nutritionTargets,
        'days': days.map((d) => d.toJson()).toList(),
        'groceryList': groceryList,
        'mealPrepSuggestions': mealPrepSuggestions,
        'whyThisFits': whyThisFits,
        'medicalSafetyDisclaimer': medicalSafetyDisclaimer,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };
}
