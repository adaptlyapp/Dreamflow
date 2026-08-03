import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:wellspring/models/family_nutrition.dart';
import 'package:wellspring/models/nutrition.dart';
import 'package:wellspring/services/user_service.dart';
import 'package:wellspring/services/family_service.dart';

/// Service for managing family-collaborative nutrition logs
/// Integrates both family member entries and patient nutrition data
class FamilyNutritionService {
  static const String _storageKey = 'family_nutrition_entries';
  final UserService _users = UserService();
  final FamilyService _familyService = FamilyService();
  final _uuid = const Uuid();

  /// Get all family nutrition entries for a patient connection
  /// This includes BOTH family member entries AND patient's own nutrition data
  Future<List<FamilyNutritionEntry>> getFamilyEntries({
    required String patientId,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 90,
  }) async {
    try {
      // 1. Get family member entries from local storage
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString('$_storageKey\_$patientId');

      final List<FamilyNutritionEntry> familyEntries = [];
      if (jsonString != null && jsonString.isNotEmpty) {
        final List<dynamic> jsonList = jsonDecode(jsonString);
        familyEntries.addAll(
          jsonList.map((json) => FamilyNutritionEntry.fromJson(Map<String, dynamic>.from(json)))
        );
      }
      
      debugPrint('[FamilyNutritionService] Found ${familyEntries.length} family member entries');

      // 2. Get patient's nutrition data from edge function
      try {
        final patientNutritionData = await _familyService.getPatientNutritionEntries(patientId, limit: 90);
        
        for (final entry in patientNutritionData) {
          try {
            final date = DateTime.parse(entry['date'] as String);
            final nutritionLogData = entry['nutritionLog'] as Map<String, dynamic>?;
            
            if (nutritionLogData != null) {
              final nutritionLog = NutritionDayLog.fromJson(nutritionLogData);
              
              familyEntries.add(FamilyNutritionEntry(
                id: entry['id'] as String,
                userId: entry['userId'] as String,
                userName: 'Patient', // Will be replaced with actual name if available
                userPhotoUrl: null,
                date: DateTime(date.year, date.month, date.day),
                nutritionLog: nutritionLog,
                createdAt: DateTime.parse(entry['createdAt'] as String),
                updatedAt: DateTime.parse(entry['updatedAt'] as String),
              ));
            }
          } catch (e) {
            debugPrint('[FamilyNutritionService] Error parsing patient nutrition entry: $e');
          }
        }
        
        debugPrint('[FamilyNutritionService] Added ${patientNutritionData.length} patient nutrition entries');
      } catch (e) {
        debugPrint('[FamilyNutritionService] Error fetching patient nutrition: $e');
      }

      // 3. Filter by date range
      var filtered = familyEntries;
      if (startDate != null) {
        filtered = filtered.where((e) => !e.date.isBefore(startDate)).toList();
      }
      if (endDate != null) {
        filtered = filtered.where((e) => !e.date.isAfter(endDate)).toList();
      }

      // 4. Sort by date descending
      filtered.sort((a, b) => b.date.compareTo(a.date));

      debugPrint('[FamilyNutritionService] Returning ${filtered.length} total nutrition entries');
      return filtered.take(limit).toList();
    } catch (e) {
      debugPrint('[FamilyNutritionService] getFamilyEntries error: $e');
      return [];
    }
  }

  /// Get a specific family nutrition entry by user and date
  Future<FamilyNutritionEntry?> getEntryByUserAndDate({
    required String patientId,
    required String userId,
    required DateTime date,
  }) async {
    try {
      final normalizedDate = DateTime(date.year, date.month, date.day);
      final entries = await getFamilyEntries(
        patientId: patientId,
        startDate: normalizedDate,
        endDate: normalizedDate.add(const Duration(days: 1)),
      );

      return entries.where((e) => e.userId == userId && _isSameDay(e.date, normalizedDate)).firstOrNull;
    } catch (e) {
      debugPrint('[FamilyNutritionService] getEntryByUserAndDate error: $e');
      return null;
    }
  }

  /// Save or update a family nutrition entry
  Future<void> saveEntry({
    required String patientId,
    required FamilyNutritionEntry entry,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_storageKey\_$patientId';
      
      // Load existing entries
      final existing = await getFamilyEntries(patientId: patientId, limit: 1000);
      
      // Remove existing entry for this user/date if it exists
      existing.removeWhere((e) => 
        e.userId == entry.userId && _isSameDay(e.date, entry.date)
      );
      
      // Add updated entry
      existing.add(entry.copyWith(updatedAt: DateTime.now()));
      
      // Save to storage
      final jsonList = existing.map((e) => e.toJson()).toList();
      await prefs.setString(key, jsonEncode(jsonList));
      
      debugPrint('[FamilyNutritionService] Saved entry for user ${entry.userName} on ${entry.date}');
    } catch (e) {
      debugPrint('[FamilyNutritionService] saveEntry error: $e');
      rethrow;
    }
  }

  /// Delete a family nutrition entry
  Future<void> deleteEntry({
    required String patientId,
    required String entryId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_storageKey\_$patientId';
      
      final existing = await getFamilyEntries(patientId: patientId, limit: 1000);
      existing.removeWhere((e) => e.id == entryId);
      
      final jsonList = existing.map((e) => e.toJson()).toList();
      await prefs.setString(key, jsonEncode(jsonList));
      
      debugPrint('[FamilyNutritionService] Deleted entry: $entryId');
    } catch (e) {
      debugPrint('[FamilyNutritionService] deleteEntry error: $e');
      rethrow;
    }
  }

  /// Get or create entry for current user
  Future<FamilyNutritionEntry> getOrCreateEntry({
    required String patientId,
    required String userId,
    required String userName,
    String? userPhotoUrl,
    required DateTime date,
  }) async {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    
    // Try to get existing
    final existing = await getEntryByUserAndDate(
      patientId: patientId,
      userId: userId,
      date: normalizedDate,
    );

    if (existing != null) return existing;

    // Create new
    final now = DateTime.now();
    return FamilyNutritionEntry(
      id: _uuid.v4(),
      userId: userId,
      userName: userName,
      userPhotoUrl: userPhotoUrl,
      date: normalizedDate,
      nutritionLog: NutritionDayLog.empty(normalizedDate),
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Add water to a user's daily log
  Future<void> addWater({
    required String patientId,
    required String userId,
    required String userName,
    String? userPhotoUrl,
    required DateTime date,
    required int ml,
  }) async {
    final entry = await getOrCreateEntry(
      patientId: patientId,
      userId: userId,
      userName: userName,
      userPhotoUrl: userPhotoUrl,
      date: date,
    );

    final updatedLog = entry.nutritionLog.copyWith(
      waterMl: (entry.nutritionLog.waterMl + ml).clamp(0, 12000),
      updatedAt: DateTime.now(),
    );

    await saveEntry(
      patientId: patientId,
      entry: entry.copyWith(nutritionLog: updatedLog),
    );
  }

  /// Add food item to a meal
  Future<void> addFoodToMeal({
    required String patientId,
    required String userId,
    required String userName,
    String? userPhotoUrl,
    required DateTime date,
    required MealType mealType,
    required FoodItemLog foodItem,
  }) async {
    final entry = await getOrCreateEntry(
      patientId: patientId,
      userId: userId,
      userName: userName,
      userPhotoUrl: userPhotoUrl,
      date: date,
    );

    final existingMeal = entry.nutritionLog.meals[mealType] ?? MealLog.empty(mealType);
    final updatedMeal = existingMeal.copyWith(
      items: [...existingMeal.items, foodItem],
      completed: true,
      updatedAt: DateTime.now(),
    );

    final updatedMeals = {...entry.nutritionLog.meals, mealType: updatedMeal};
    final updatedLog = entry.nutritionLog.copyWith(
      meals: updatedMeals,
      updatedAt: DateTime.now(),
    );

    await saveEntry(
      patientId: patientId,
      entry: entry.copyWith(nutritionLog: updatedLog),
    );
  }

  /// Update entire meal
  Future<void> updateMeal({
    required String patientId,
    required String userId,
    required String userName,
    String? userPhotoUrl,
    required DateTime date,
    required MealLog meal,
  }) async {
    final entry = await getOrCreateEntry(
      patientId: patientId,
      userId: userId,
      userName: userName,
      userPhotoUrl: userPhotoUrl,
      date: date,
    );

    final updatedMeals = {...entry.nutritionLog.meals, meal.type: meal};
    final updatedLog = entry.nutritionLog.copyWith(
      meals: updatedMeals,
      updatedAt: DateTime.now(),
    );

    await saveEntry(
      patientId: patientId,
      entry: entry.copyWith(nutritionLog: updatedLog),
    );
  }

  /// Get family-wide statistics
  Future<Map<String, dynamic>> getFamilyStatistics({
    required String patientId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final entries = await getFamilyEntries(
      patientId: patientId,
      startDate: startDate,
      endDate: endDate,
      limit: 1000,
    );

    if (entries.isEmpty) {
      return {
        'totalDays': 0,
        'avgCalories': 0.0,
        'avgProtein': 0.0,
        'avgCarbs': 0.0,
        'avgFat': 0.0,
        'avgWater': 0.0,
        'userBreakdown': <String, dynamic>{},
      };
    }

    double totalCalories = 0;
    double totalProtein = 0;
    double totalCarbs = 0;
    double totalFat = 0;
    double totalWater = 0;
    int dayCount = 0;

    final userStats = <String, Map<String, dynamic>>{};

    for (final entry in entries) {
      final macros = entry.nutritionLog.totalMacros;
      totalCalories += macros.calories;
      totalProtein += macros.proteinG;
      totalCarbs += macros.carbsG;
      totalFat += macros.fatsG;
      totalWater += entry.nutritionLog.waterMl / 1000.0; // Convert to L
      dayCount++;

      // Per-user stats
      if (!userStats.containsKey(entry.userId)) {
        userStats[entry.userId] = {
          'userName': entry.userName,
          'userPhotoUrl': entry.userPhotoUrl,
          'totalCalories': 0.0,
          'totalProtein': 0.0,
          'totalCarbs': 0.0,
          'totalFat': 0.0,
          'totalWater': 0.0,
          'dayCount': 0,
        };
      }

      final userStat = userStats[entry.userId]!;
      userStat['totalCalories'] = (userStat['totalCalories'] as double) + macros.calories;
      userStat['totalProtein'] = (userStat['totalProtein'] as double) + macros.proteinG;
      userStat['totalCarbs'] = (userStat['totalCarbs'] as double) + macros.carbsG;
      userStat['totalFat'] = (userStat['totalFat'] as double) + macros.fatsG;
      userStat['totalWater'] = (userStat['totalWater'] as double) + (entry.nutritionLog.waterMl / 1000.0);
      userStat['dayCount'] = (userStat['dayCount'] as int) + 1;
    }

    // Calculate averages for each user
    for (final stat in userStats.values) {
      final count = stat['dayCount'] as int;
      if (count > 0) {
        stat['avgCalories'] = (stat['totalCalories'] as double) / count;
        stat['avgProtein'] = (stat['totalProtein'] as double) / count;
        stat['avgCarbs'] = (stat['totalCarbs'] as double) / count;
        stat['avgFat'] = (stat['totalFat'] as double) / count;
        stat['avgWater'] = (stat['totalWater'] as double) / count;
      }
    }

    return {
      'totalDays': dayCount,
      'avgCalories': dayCount > 0 ? totalCalories / dayCount : 0.0,
      'avgProtein': dayCount > 0 ? totalProtein / dayCount : 0.0,
      'avgCarbs': dayCount > 0 ? totalCarbs / dayCount : 0.0,
      'avgFat': dayCount > 0 ? totalFat / dayCount : 0.0,
      'avgWater': dayCount > 0 ? totalWater / dayCount : 0.0,
      'userBreakdown': userStats,
    };
  }

  /// Get entries for a specific date (all family members + patient)
  Future<List<FamilyNutritionEntry>> getEntriesForDate({
    required String patientId,
    required DateTime date,
  }) async {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final entries = await getFamilyEntries(
      patientId: patientId,
      startDate: normalizedDate,
      endDate: normalizedDate.add(const Duration(days: 1)),
    );

    return entries.where((e) => _isSameDay(e.date, normalizedDate)).toList();
  }
  
  /// Get patient's own nutrition entry for a specific date
  Future<FamilyNutritionEntry?> getPatientNutritionForDate({
    required String patientId,
    required DateTime date,
  }) async {
    try {
      final normalizedDate = DateTime(date.year, date.month, date.day);
      final patientNutritionData = await _familyService.getPatientNutritionEntries(patientId, limit: 90);
      
      for (final entry in patientNutritionData) {
        final entryDate = DateTime.parse(entry['date'] as String);
        if (_isSameDay(entryDate, normalizedDate)) {
          final nutritionLogData = entry['nutritionLog'] as Map<String, dynamic>?;
          if (nutritionLogData != null) {
            return FamilyNutritionEntry(
              id: entry['id'] as String,
              userId: entry['userId'] as String,
              userName: 'Patient',
              userPhotoUrl: null,
              date: normalizedDate,
              nutritionLog: NutritionDayLog.fromJson(nutritionLogData),
              createdAt: DateTime.parse(entry['createdAt'] as String),
              updatedAt: DateTime.parse(entry['updatedAt'] as String),
            );
          }
        }
      }
      return null;
    } catch (e) {
      debugPrint('[FamilyNutritionService] getPatientNutritionForDate error: $e');
      return null;
    }
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
