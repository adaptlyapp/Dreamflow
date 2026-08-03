import 'package:flutter/foundation.dart';
import 'package:wellspring/models/nutrition.dart';

/// Represents a nutrition entry that can be from either:
/// 1. A family member (stored in SharedPreferences)
/// 2. The patient (fetched from tracker_entries.custom_fields['nutritionV1'])
/// 
/// This unified model allows family members to view and compare nutrition data
/// across all family members and the patient in one place.
@immutable
class FamilyNutritionEntry {
  final String id;
  final String userId; // Can be patient or family member
  final String userName;
  final String? userPhotoUrl;
  final DateTime date;
  final NutritionDayLog nutritionLog;
  final DateTime createdAt;
  final DateTime updatedAt;

  const FamilyNutritionEntry({
    required this.id,
    required this.userId,
    required this.userName,
    this.userPhotoUrl,
    required this.date,
    required this.nutritionLog,
    required this.createdAt,
    required this.updatedAt,
  });

  FamilyNutritionEntry copyWith({
    String? id,
    String? userId,
    String? userName,
    String? userPhotoUrl,
    DateTime? date,
    NutritionDayLog? nutritionLog,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      FamilyNutritionEntry(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        userName: userName ?? this.userName,
        userPhotoUrl: userPhotoUrl ?? this.userPhotoUrl,
        date: date ?? this.date,
        nutritionLog: nutritionLog ?? this.nutritionLog,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  factory FamilyNutritionEntry.fromJson(Map<String, dynamic> json) {
    final date = DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now();
    final created = DateTime.tryParse(json['createdAt']?.toString() ?? '');
    final updated = DateTime.tryParse(json['updatedAt']?.toString() ?? '');
    final now = DateTime.now();

    return FamilyNutritionEntry(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      userName: json['userName']?.toString() ?? 'Unknown',
      userPhotoUrl: json['userPhotoUrl']?.toString(),
      date: DateTime(date.year, date.month, date.day),
      nutritionLog: json['nutritionLog'] != null
          ? NutritionDayLog.fromJson(
              json['nutritionLog'] is Map<String, dynamic>
                  ? json['nutritionLog']
                  : Map<String, dynamic>.from(json['nutritionLog'] as Map))
          : NutritionDayLog.empty(date),
      createdAt: created ?? now,
      updatedAt: updated ?? created ?? now,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'userName': userName,
        if (userPhotoUrl != null) 'userPhotoUrl': userPhotoUrl,
        'date': DateTime(date.year, date.month, date.day).toIso8601String(),
        'nutritionLog': nutritionLog.toJson(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };
}

/// Food database entry for comprehensive search
@immutable
class FoodDatabaseEntry {
  final String id;
  final String name;
  final String brand; // e.g., "McDonald's", "Generic", "Starbucks"
  final String category; // e.g., "Fast Food", "Beverages", "Fruits"
  final NutritionMacros macros;
  final String servingSize;
  final double servingSizeG;
  final List<String> searchTags; // For fuzzy search

  const FoodDatabaseEntry({
    required this.id,
    required this.name,
    required this.brand,
    required this.category,
    required this.macros,
    required this.servingSize,
    required this.servingSizeG,
    required this.searchTags,
  });

  factory FoodDatabaseEntry.fromJson(Map<String, dynamic> json) => FoodDatabaseEntry(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        brand: json['brand']?.toString() ?? 'Generic',
        category: json['category']?.toString() ?? 'Other',
        macros: json['macros'] != null
            ? NutritionMacros.fromJson(
                json['macros'] is Map<String, dynamic>
                    ? json['macros']
                    : Map<String, dynamic>.from(json['macros'] as Map))
            : const NutritionMacros.zero(),
        servingSize: json['servingSize']?.toString() ?? '100g',
        servingSizeG: (json['servingSizeG'] as num?)?.toDouble() ?? 100.0,
        searchTags: (json['searchTags'] as List?)?.cast<String>() ?? [],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'brand': brand,
        'category': category,
        'macros': macros.toJson(),
        'servingSize': servingSize,
        'servingSizeG': servingSizeG,
        'searchTags': searchTags,
      };

  FoodItemLog toFoodItemLog() {
    final now = DateTime.now();
    return FoodItemLog(
      name: brand == 'Generic' ? name : '$brand - $name',
      macros: macros,
      notes: '$servingSize • $category',
      createdAt: now,
      updatedAt: now,
    );
  }
}

/// Custom food entry created by users
@immutable
class CustomFoodEntry {
  final String id;
  final String name;
  final String servingSize;
  final double servingSizeG;
  final NutritionMacros macros;
  final String notes;
  final DateTime createdAt;

  const CustomFoodEntry({
    required this.id,
    required this.name,
    required this.servingSize,
    required this.servingSizeG,
    required this.macros,
    required this.notes,
    required this.createdAt,
  });

  factory CustomFoodEntry.fromJson(Map<String, dynamic> json) {
    final created = DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now();
    return CustomFoodEntry(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      servingSize: json['servingSize']?.toString() ?? '100g',
      servingSizeG: (json['servingSizeG'] as num?)?.toDouble() ?? 100.0,
      macros: json['macros'] != null
          ? NutritionMacros.fromJson(
              json['macros'] is Map<String, dynamic>
                  ? json['macros']
                  : Map<String, dynamic>.from(json['macros'] as Map))
          : const NutritionMacros.zero(),
      notes: json['notes']?.toString() ?? '',
      createdAt: created,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'servingSize': servingSize,
        'servingSizeG': servingSizeG,
        'macros': macros.toJson(),
        'notes': notes,
        'createdAt': createdAt.toIso8601String(),
      };

  FoodDatabaseEntry toFoodDatabaseEntry() => FoodDatabaseEntry(
        id: 'custom_$id',
        name: name,
        brand: 'My Foods',
        category: 'Custom',
        macros: macros,
        servingSize: servingSize,
        servingSizeG: servingSizeG,
        searchTags: [name.toLowerCase(), 'custom', 'my food'],
      );
}
