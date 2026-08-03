import 'package:flutter/foundation.dart';

enum MealType { breakfast, lunch, dinner, snack }

extension MealTypeLabel on MealType {
  String get label => switch (this) {
    MealType.breakfast => 'Breakfast',
    MealType.lunch => 'Lunch',
    MealType.dinner => 'Dinner',
    MealType.snack => 'Snack',
  };

  String get storageKey => name;

  static MealType? tryParse(String? raw) {
    if (raw == null) return null;
    for (final t in MealType.values) {
      if (t.name == raw) return t;
    }
    return null;
  }
}

@immutable
class NutritionMacros {
  final int calories;
  final double proteinG;
  final double carbsG;
  final double fatsG;
  final double fiberG;
  final double sugarG;
  final int sodiumMg;

  const NutritionMacros({
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatsG,
    required this.fiberG,
    required this.sugarG,
    required this.sodiumMg,
  });

  const NutritionMacros.zero()
      : calories = 0,
        proteinG = 0,
        carbsG = 0,
        fatsG = 0,
        fiberG = 0,
        sugarG = 0,
        sodiumMg = 0;

  NutritionMacros copyWith({
    int? calories,
    double? proteinG,
    double? carbsG,
    double? fatsG,
    double? fiberG,
    double? sugarG,
    int? sodiumMg,
  }) =>
      NutritionMacros(
        calories: calories ?? this.calories,
        proteinG: proteinG ?? this.proteinG,
        carbsG: carbsG ?? this.carbsG,
        fatsG: fatsG ?? this.fatsG,
        fiberG: fiberG ?? this.fiberG,
        sugarG: sugarG ?? this.sugarG,
        sodiumMg: sodiumMg ?? this.sodiumMg,
      );

  NutritionMacros operator +(NutritionMacros other) => NutritionMacros(
        calories: calories + other.calories,
        proteinG: proteinG + other.proteinG,
        carbsG: carbsG + other.carbsG,
        fatsG: fatsG + other.fatsG,
        fiberG: fiberG + other.fiberG,
        sugarG: sugarG + other.sugarG,
        sodiumMg: sodiumMg + other.sodiumMg,
      );

  factory NutritionMacros.fromJson(Map<String, dynamic> json) => NutritionMacros(
        calories: (json['calories'] as num?)?.toInt() ?? 0,
        proteinG: (json['proteinG'] as num?)?.toDouble() ?? 0,
        carbsG: (json['carbsG'] as num?)?.toDouble() ?? 0,
        fatsG: (json['fatsG'] as num?)?.toDouble() ?? 0,
        fiberG: (json['fiberG'] as num?)?.toDouble() ?? 0,
        sugarG: (json['sugarG'] as num?)?.toDouble() ?? 0,
        sodiumMg: (json['sodiumMg'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'calories': calories,
        'proteinG': proteinG,
        'carbsG': carbsG,
        'fatsG': fatsG,
        'fiberG': fiberG,
        'sugarG': sugarG,
        'sodiumMg': sodiumMg,
      };
}

@immutable
class FoodItemLog {
  final String name;
  final NutritionMacros macros;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const FoodItemLog({
    required this.name,
    required this.macros,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  FoodItemLog copyWith({
    String? name,
    NutritionMacros? macros,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      FoodItemLog(
        name: name ?? this.name,
        macros: macros ?? this.macros,
        notes: notes ?? this.notes,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  factory FoodItemLog.fromJson(Map<String, dynamic> json) {
    final created = DateTime.tryParse((json['createdAt'] ?? '').toString());
    final updated = DateTime.tryParse((json['updatedAt'] ?? '').toString());
    final now = DateTime.now();
    return FoodItemLog(
      name: (json['name'] ?? '').toString(),
      macros: NutritionMacros.fromJson((json['macros'] as Map?)?.cast<String, dynamic>() ?? const {}),
      notes: json['notes']?.toString(),
      createdAt: created ?? now,
      updatedAt: updated ?? created ?? now,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'macros': macros.toJson(),
        if (notes != null) 'notes': notes,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };
}

@immutable
class MealLog {
  final MealType type;
  final List<FoodItemLog> items;
  final String? notes;
  final List<String> symptomTags;
  final bool completed;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MealLog({
    required this.type,
    required this.items,
    this.notes,
    required this.symptomTags,
    required this.completed,
    required this.createdAt,
    required this.updatedAt,
  });

  NutritionMacros get totalMacros => items.fold(const NutritionMacros.zero(), (sum, i) => sum + i.macros);

  MealLog copyWith({
    MealType? type,
    List<FoodItemLog>? items,
    String? notes,
    List<String>? symptomTags,
    bool? completed,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      MealLog(
        type: type ?? this.type,
        items: items ?? this.items,
        notes: notes ?? this.notes,
        symptomTags: symptomTags ?? this.symptomTags,
        completed: completed ?? this.completed,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  factory MealLog.empty(MealType type) {
    final now = DateTime.now();
    return MealLog(
      type: type,
      items: const [],
      symptomTags: const [],
      completed: false,
      createdAt: now,
      updatedAt: now,
    );
  }

  factory MealLog.fromJson(Map<String, dynamic> json) {
    final type = MealTypeLabel.tryParse(json['type']?.toString()) ?? MealType.breakfast;
    final itemsRaw = json['items'];
    final items = <FoodItemLog>[];
    if (itemsRaw is List) {
      for (final e in itemsRaw) {
        if (e is Map<String, dynamic>) {
          items.add(FoodItemLog.fromJson(e));
        } else if (e is Map) {
          items.add(FoodItemLog.fromJson(e.cast<String, dynamic>()));
        }
      }
    }
    final created = DateTime.tryParse((json['createdAt'] ?? '').toString());
    final updated = DateTime.tryParse((json['updatedAt'] ?? '').toString());
    final now = DateTime.now();
    return MealLog(
      type: type,
      items: items,
      notes: json['notes']?.toString(),
      symptomTags: (json['symptomTags'] is List)
          ? (json['symptomTags'] as List).whereType<String>().map((s) => s.trim()).where((s) => s.isNotEmpty).toList()
          : const [],
      completed: json['completed'] == true,
      createdAt: created ?? now,
      updatedAt: updated ?? created ?? now,
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type.storageKey,
        'items': items.map((e) => e.toJson()).toList(),
        if (notes != null) 'notes': notes,
        'symptomTags': symptomTags,
        'completed': completed,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };
}

@immutable
class NutritionDayLog {
  static const String customFieldKey = 'nutritionV1';

  final DateTime date; // Local day
  final int waterMl;
  final int waterGoalMl;
  final Map<MealType, MealLog> meals;
  final String? dayNotes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const NutritionDayLog({
    required this.date,
    required this.waterMl,
    required this.waterGoalMl,
    required this.meals,
    this.dayNotes,
    required this.createdAt,
    required this.updatedAt,
  });

  NutritionMacros get totalMacros => meals.values.fold(const NutritionMacros.zero(), (sum, m) => sum + m.totalMacros);

  int get completedMealsCount => meals.values.where((m) => m.completed).length;

  int get totalMealsCount => MealType.values.length;

  NutritionDayLog copyWith({
    DateTime? date,
    int? waterMl,
    int? waterGoalMl,
    Map<MealType, MealLog>? meals,
    String? dayNotes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      NutritionDayLog(
        date: date ?? this.date,
        waterMl: waterMl ?? this.waterMl,
        waterGoalMl: waterGoalMl ?? this.waterGoalMl,
        meals: meals ?? this.meals,
        dayNotes: dayNotes ?? this.dayNotes,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  factory NutritionDayLog.empty(DateTime date, {int waterGoalMl = 2000}) {
    final day = DateTime(date.year, date.month, date.day);
    final now = DateTime.now();
    return NutritionDayLog(
      date: day,
      waterMl: 0,
      waterGoalMl: waterGoalMl,
      meals: {for (final t in MealType.values) t: MealLog.empty(t)},
      createdAt: now,
      updatedAt: now,
    );
  }

  factory NutritionDayLog.fromJson(Map<String, dynamic> json) {
    final date = DateTime.tryParse((json['date'] ?? '').toString()) ?? DateTime.now();
    
    // Handle both Map and List formats for meals (due to JSONB storage quirks)
    final mealsRawValue = json['meals'];
    Map<String, dynamic> mealsRaw;
    
    if (mealsRawValue is Map<String, dynamic>) {
      mealsRaw = mealsRawValue;
    } else if (mealsRawValue is Map) {
      mealsRaw = mealsRawValue.cast<String, dynamic>();
    } else if (mealsRawValue is List) {
      // If meals was somehow stored as a list, convert it back to empty map
      // This handles corrupted data gracefully
      debugPrint('NutritionDayLog.fromJson: meals stored as List, resetting to empty');
      mealsRaw = <String, dynamic>{};
    } else {
      mealsRaw = <String, dynamic>{};
    }
    
    final meals = <MealType, MealLog>{};
    for (final t in MealType.values) {
      final raw = mealsRaw[t.storageKey];
      if (raw is Map<String, dynamic>) {
        meals[t] = MealLog.fromJson(raw);
      } else if (raw is Map) {
        meals[t] = MealLog.fromJson(raw.cast<String, dynamic>());
      } else {
        meals[t] = MealLog.empty(t);
      }
    }
    final created = DateTime.tryParse((json['createdAt'] ?? '').toString());
    final updated = DateTime.tryParse((json['updatedAt'] ?? '').toString());
    final now = DateTime.now();
    return NutritionDayLog(
      date: DateTime(date.year, date.month, date.day),
      waterMl: (json['waterMl'] as num?)?.toInt() ?? 0,
      waterGoalMl: (json['waterGoalMl'] as num?)?.toInt() ?? 2000,
      meals: meals,
      dayNotes: json['dayNotes']?.toString(),
      createdAt: created ?? now,
      updatedAt: updated ?? created ?? now,
    );
  }

  Map<String, dynamic> toJson() => {
        'date': DateTime(date.year, date.month, date.day).toIso8601String(),
        'waterMl': waterMl,
        'waterGoalMl': waterGoalMl,
        'meals': {for (final e in meals.entries) e.key.storageKey: e.value.toJson()},
        if (dayNotes != null) 'dayNotes': dayNotes,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };
}
