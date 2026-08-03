import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:wellspring/models/diet_plan.dart';
import 'package:wellspring/models/nutrition.dart';
import 'package:wellspring/models/tracker_entry.dart';
import 'package:wellspring/services/tracker_service.dart';
import 'package:wellspring/services/user_service.dart';

/// Nutrition is stored inside the existing `tracker_entries.custom_fields` JSON.
/// This keeps the feature tightly integrated with the current Tracker (no new
/// Supabase schema needed), while still providing a typed model layer.
class NutritionService {
  final TrackerService _tracker = TrackerService();
  final UserService _users = UserService();
  static const String _prefWaterGoalKey = 'nutritionWaterGoalMl';
  static const String _prefDietPlanKey = 'nutritionDietPlanV1';
  final _uuid = const Uuid();

  /// Returns recent distinct days that contain nutrition logs.
  ///
  /// Nutrition is stored in `tracker_entries.custom_fields[nutritionV1]`.
  /// This helper scans the user's recent tracker entries and extracts only
  /// those that contain nutrition data.
  Future<List<NutritionDayLog>> getRecentNutritionDays(
    String userId, {
    int entryLimit = 120,
    int maxDays = 14,
  }) async {
    try {
      final entries = await _tracker.getRecentEntries(userId, limit: entryLimit);
      final byDay = <String, NutritionDayLog>{};

      String dayKey(DateTime d) {
        final nd = DateTime(d.year, d.month, d.day);
        return '${nd.year.toString().padLeft(4, '0')}-${nd.month.toString().padLeft(2, '0')}-${nd.day.toString().padLeft(2, '0')}';
      }

      for (final e in entries) {
        final cf = e.customFields ?? const <String, dynamic>{};
        final raw = cf[NutritionDayLog.customFieldKey];
        if (raw == null) continue;
        
        NutritionDayLog? log;
        try {
          if (raw is Map<String, dynamic>) {
            log = NutritionDayLog.fromJson(raw);
          } else if (raw is Map) {
            log = NutritionDayLog.fromJson(raw.cast<String, dynamic>());
          }
        } catch (err) {
          debugPrint('NutritionService: Failed to parse nutrition entry ${e.id}: $err');
          continue;
        }
        if (log == null) continue;

        final key = dayKey(e.date);
        // Prefer the most recently updated log if duplicates exist.
        final existing = byDay[key];
        if (existing == null || log.updatedAt.isAfter(existing.updatedAt)) {
          byDay[key] = log.copyWith(date: DateTime(e.date.year, e.date.month, e.date.day));
        }
      }

      final list = byDay.values.toList(growable: false)
        ..sort((a, b) => b.date.compareTo(a.date));
      return list.length > maxDays ? list.sublist(0, maxDays) : list;
    } catch (e) {
      debugPrint('NutritionService.getRecentNutritionDays error: $e');
      return const [];
    }
  }

  Future<int> getWaterGoalMl() async {
    try {
      final user = await _users.getCurrentUser();
      final prefs = user?.preferences ?? <String, dynamic>{};
      final raw = prefs[_prefWaterGoalKey];
      final v = (raw as num?)?.toInt();
      return (v != null && v >= 500 && v <= 6000) ? v : 2000;
    } catch (e) {
      debugPrint('NutritionService.getWaterGoalMl error: $e');
      return 2000;
    }
  }

  Future<void> setWaterGoalMl(int ml) async {
    try {
      final user = await _users.getCurrentUser();
      if (user == null) throw Exception('Sign in required');
      final prefs = Map<String, dynamic>.from(user.preferences ?? <String, dynamic>{});
      prefs[_prefWaterGoalKey] = ml.clamp(500, 6000);
      await _users.updatePreferences(prefs);
    } catch (e) {
      debugPrint('NutritionService.setWaterGoalMl error: $e');
      rethrow;
    }
  }

  Future<NutritionDayLog> getDay(String userId, DateTime date) async {
    final goal = await getWaterGoalMl();
    try {
      final entry = await _tracker.getEntryByDate(userId, date);
      final cf = entry?.customFields ?? <String, dynamic>{};
      final raw = cf[NutritionDayLog.customFieldKey];
      if (raw == null) return NutritionDayLog.empty(date, waterGoalMl: goal);
      
      try {
        NutritionDayLog parsed;
        if (raw is Map<String, dynamic>) {
          parsed = NutritionDayLog.fromJson(raw);
        } else if (raw is Map) {
          parsed = NutritionDayLog.fromJson(raw.cast<String, dynamic>());
        } else {
          return NutritionDayLog.empty(date, waterGoalMl: goal);
        }
        // If a user updated their goal in settings, apply it forward.
        return parsed.waterGoalMl == goal ? parsed : parsed.copyWith(waterGoalMl: goal);
      } catch (parseErr) {
        debugPrint('NutritionService.getDay: Failed to parse nutrition data: $parseErr');
        return NutritionDayLog.empty(date, waterGoalMl: goal);
      }
    } catch (e) {
      debugPrint('NutritionService.getDay error: $e');
      return NutritionDayLog.empty(date, waterGoalMl: goal);
    }
  }

  Future<void> saveDay(String userId, NutritionDayLog day) async {
    final normalizedDay = DateTime(day.date.year, day.date.month, day.date.day);
    try {
      final existing = await _tracker.getEntryByDate(userId, normalizedDay);
      final now = DateTime.now();
      final updatedDay = day.copyWith(date: normalizedDay, updatedAt: now);
      if (existing == null) {
        final entry = TrackerEntry(
          id: _uuid.v4(),
          userId: userId,
          date: normalizedDay,
          customFields: {NutritionDayLog.customFieldKey: updatedDay.toJson()},
          createdAt: now,
          updatedAt: now,
        );
        // Nutrition writes should not produce Health-side audit/achievement logs.
        await _tracker.addEntry(entry, recordAudit: false, trackAchievements: false);
        return;
      }

      final cf = <String, dynamic>{...(existing.customFields ?? <String, dynamic>{})};
      cf[NutritionDayLog.customFieldKey] = updatedDay.toJson();
      final updatedEntry = existing.copyWith(customFields: cf);
      // Nutrition writes should not produce Health-side audit logs.
      await _tracker.updateEntry(updatedEntry, recordAudit: false);
    } catch (e) {
      debugPrint('NutritionService.saveDay error: $e');
      rethrow;
    }
  }

  Future<void> addWater(String userId, DateTime date, int ml) async {
    final day = await getDay(userId, date);
    final updated = day.copyWith(waterMl: (day.waterMl + ml).clamp(0, 12000), updatedAt: DateTime.now());
    await saveDay(userId, updated);
  }

  Future<void> setMealCompleted(String userId, DateTime date, MealType type, bool completed) async {
    final day = await getDay(userId, date);
    final meal = day.meals[type] ?? MealLog.empty(type);
    final updatedMeal = meal.copyWith(completed: completed, updatedAt: DateTime.now());
    final meals = {...day.meals, type: updatedMeal};
    await saveDay(userId, day.copyWith(meals: meals, updatedAt: DateTime.now()));
  }

  Future<void> upsertMeal(String userId, DateTime date, MealLog meal) async {
    final day = await getDay(userId, date);
    final meals = {...day.meals, meal.type: meal.copyWith(updatedAt: DateTime.now())};
    await saveDay(userId, day.copyWith(meals: meals, updatedAt: DateTime.now()));
  }

  Future<void> addFoodToMeal(
    String userId,
    DateTime date,
    MealType type,
    FoodItemLog item,
  ) async {
    final day = await getDay(userId, date);
    final existingMeal = day.meals[type] ?? MealLog.empty(type);
    final updatedMeal = existingMeal.copyWith(
      items: [...existingMeal.items, item],
      updatedAt: DateTime.now(),
      completed: existingMeal.completed || existingMeal.items.isNotEmpty,
    );
    await saveDay(userId, day.copyWith(meals: {...day.meals, type: updatedMeal}, updatedAt: DateTime.now()));
  }

  Future<DietPlanResult?> getSavedDietPlan() async {
    try {
      final user = await _users.getCurrentUser();
      final prefs = user?.preferences ?? <String, dynamic>{};
      final raw = prefs[_prefDietPlanKey];
      if (raw is Map<String, dynamic>) return DietPlanResult.fromJson(raw);
      if (raw is Map) return DietPlanResult.fromJson(raw.cast<String, dynamic>());
      return null;
    } catch (e) {
      debugPrint('NutritionService.getSavedDietPlan error: $e');
      return null;
    }
  }

  Future<void> saveDietPlan(DietPlanResult plan) async {
    try {
      final user = await _users.getCurrentUser();
      if (user == null) throw Exception('Sign in required');
      final prefs = Map<String, dynamic>.from(user.preferences ?? <String, dynamic>{});
      prefs[_prefDietPlanKey] = plan.copyWith(updatedAt: DateTime.now()).toJson();
      await _users.updatePreferences(prefs);
    } catch (e) {
      debugPrint('NutritionService.saveDietPlan error: $e');
      rethrow;
    }
  }

  Future<void> clearDietPlan() async {
    try {
      final user = await _users.getCurrentUser();
      if (user == null) throw Exception('Sign in required');
      final prefs = Map<String, dynamic>.from(user.preferences ?? <String, dynamic>{});
      prefs.remove(_prefDietPlanKey);
      await _users.updatePreferences(prefs);
    } catch (e) {
      debugPrint('NutritionService.clearDietPlan error: $e');
      rethrow;
    }
  }

  /// Returns a list of recently logged foods for the given user.
  ///
  /// This scans the user's recent tracker history and extracts nutrition items
  /// from `tracker_entries.custom_fields[nutritionV1]`.
  Future<List<FoodItemLog>> getRecentFoods(
    String userId, {
    int entryLimit = 120,
    int maxItems = 60,
  }) async {
    try {
      final entries = await _tracker.getRecentEntries(userId, limit: entryLimit);
      final byName = <String, FoodItemLog>{};

      DateTime bestTime(FoodItemLog i) => i.updatedAt.isAfter(i.createdAt) ? i.updatedAt : i.createdAt;

      for (final e in entries) {
        final cf = e.customFields ?? const <String, dynamic>{};
        final raw = cf[NutritionDayLog.customFieldKey];
        if (raw == null) continue;
        
        NutritionDayLog? log;
        try {
          if (raw is Map<String, dynamic>) {
            log = NutritionDayLog.fromJson(raw);
          } else if (raw is Map) {
            log = NutritionDayLog.fromJson(raw.cast<String, dynamic>());
          }
        } catch (err) {
          debugPrint('NutritionService: Failed to parse nutrition entry ${e.id}: $err');
          continue;
        }
        if (log == null) continue;

        for (final meal in log.meals.values) {
          for (final item in meal.items) {
            final name = item.name.trim();
            if (name.isEmpty) continue;
            final key = name.toLowerCase();
            final existing = byName[key];
            if (existing == null || bestTime(item).isAfter(bestTime(existing))) {
              byName[key] = item;
            }
          }
        }
      }

      final list = byName.values.toList(growable: false)
        ..sort((a, b) => bestTime(b).compareTo(bestTime(a)));

      return list.length > maxItems ? list.sublist(0, maxItems) : list;
    } catch (e) {
      debugPrint('NutritionService.getRecentFoods error: $e');
      return const [];
    }
  }
}