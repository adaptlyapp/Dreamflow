import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wellspring/models/tracker_entry.dart';
import 'package:wellspring/models/user.dart';
import 'package:wellspring/services/audit_log_service.dart';
import 'package:wellspring/services/achievement_service.dart';
import 'package:wellspring/services/family_service.dart';
import 'package:wellspring/services/user_service.dart';
import 'package:wellspring/supabase/supabase_config.dart';

class TrackerService {
  final SupabaseClient _supabase = SupabaseConfig.client;
  final AuditLogService _audit = AuditLogService();
  final AchievementService _achievements = AchievementService();

  /// Fetch the most recent structured medication details the user saved for
  /// a given medication name.
  ///
  /// This is used to prefill the "Medication Details" sheet so users don't
  /// have to re-enter the same dose/time/PRN/effect each day.
  Future<MedicationLog?> getLastMedicationLog(
    String userId,
    String medicationName, {
    DateTime? before,
    String? excludeEntryId,
    int searchLimit = 25,
  }) async {
    final needle = medicationName.trim().toLowerCase();
    if (needle.isEmpty) return null;

    try {
      dynamic query = _supabase
          .from('tracker_entries')
          .select('id, date, custom_fields')
          .eq('user_id', userId)
          .contains('medications', [medicationName]);

      if (before != null) {
        query = query.lt('date', before.toIso8601String());
      }
      if (excludeEntryId != null && excludeEntryId.trim().isNotEmpty) {
        query = query.neq('id', excludeEntryId);
      }

      final rows = await query.order('date', ascending: false).limit(searchLimit);
      for (final row in rows) {
        final cfRaw = row['custom_fields'];
        if (cfRaw is! Map) continue;
        final cf = cfRaw.cast<String, dynamic>();
        final logsRaw = cf['medicationLogs'];
        if (logsRaw is! List) continue;

        for (final item in logsRaw) {
          if (item is Map<String, dynamic>) {
            final log = MedicationLog.fromJson(item);
            if (log.name.trim().toLowerCase() == needle) return log;
          } else if (item is Map) {
            final log = MedicationLog.fromJson(item.cast<String, dynamic>());
            if (log.name.trim().toLowerCase() == needle) return log;
          }
        }
      }
      return null;
    } catch (e) {
      debugPrint('TrackerService.getLastMedicationLog error: $e');
      return null;
    }
  }

  // User preference key for suggestions the user has explicitly removed.
  // Stored in `users.preferences` as:
  // {
  //   "trackerSuggestionExclusions": {
  //     "medications": ["baclofen"],
  //     "symptoms": ["headache"],
  //     "triggers": [],
  //     "activities": []
  //   }
  // }
  static const String _prefSuggestionExclusionsKey = 'trackerSuggestionExclusions';

  // Simple in-memory caches to reduce repeated Supabase reads within a short window.
  // This notably speeds up the Home snapshot which calls statistics for two ranges
  // and also loads recent entries for charts.
  final Map<String, _EntriesCache> _mergedCacheByUser = {};
  Duration mergedCacheTtl = const Duration(seconds: 60);

  // Suggestions derived from historical entries (meds/symptoms/triggers/activities)
  final Map<String, _SuggestionsCache> _suggestionsCacheByUser = {};
  Duration suggestionsCacheTtl = const Duration(minutes: 5);

  final Map<String, _ExclusionsCache> _exclusionsCacheByUser = {};
  Duration exclusionsCacheTtl = const Duration(minutes: 10);

  void _invalidateMergedCache(String userId) {
    _mergedCacheByUser.remove(userId);
  }

  void _invalidateExclusionsCache(String userId) {
    _exclusionsCacheByUser.remove(userId);
  }

  /// Which list field to derive suggestions for.
  ///
  /// These map to `TrackerEntry.medications/symptoms/triggers/activities`.
  static const suggestionKinds = {
    TrackerSuggestionKind.medications,
    TrackerSuggestionKind.symptoms,
    TrackerSuggestionKind.triggers,
    TrackerSuggestionKind.activities,
  };

  // --- Internal helpers ----------------------------------------------------
  Future<List<TrackerEntry>> _fetchFromTable(String userId, {int limit = 200}) async {
    try {
      debugPrint('TrackerService._fetchFromTable: Querying for userId=$userId, limit=$limit');
      final data = await _supabase
          .from('tracker_entries')
          .select()
          .eq('user_id', userId)
          .order('date', ascending: false)
          .limit(limit);
      debugPrint('TrackerService._fetchFromTable: Retrieved ${data.length} entries');
      return data
          .map((item) => TrackerEntry.fromJson({
            'id': item['id'],
            'userId': item['user_id'],
            'date': item['date'],
            'painLevel': item['pain_level'],
            'painMap': item['pain_map'],
            'sleepQuality': item['sleep_quality'],
            'energyLevel': item['energy_level'],
            'mood': item['mood'],
            'spasmFrequency': item['spasm_frequency'],
            'bladderSuccess': item['bladder_success'],
            'bowelProgram': item['bowel_program'],
            'steps': item['steps'],
            'systolicBP': item['systolic_bp'],
            'diastolicBP': item['diastolic_bp'],
            'heartRate': item['heart_rate'],
            'weight': item['weight'],
            'temperature': item['temperature'],
            'notes': item['notes'],
            'medications': item['medications'],
            'symptoms': item['symptoms'],
            'triggers': item['triggers'],
            'activities': item['activities'],
            'customFields': item['custom_fields'],
            'createdAt': item['created_at'],
            'updatedAt': item['updated_at'],
          }))
          .toList();
    } catch (e) {
      debugPrint('TrackerService._fetchFromTable error: $e');
      return [];
    }
  }

  // Backward-compat: No longer needed since we're migrating from Firebase to Supabase

  Future<List<TrackerEntry>> _getMergedEntriesCached(String userId,
      {int limit = 500}) async {
    final now = DateTime.now();
    final cached = _mergedCacheByUser[userId];
    if (cached != null && now.difference(cached.fetchedAt) < mergedCacheTtl) {
      return cached.entries; // Already sorted desc by date
    }
    // Fetch fresh
    final entries = await _fetchFromTable(userId, limit: limit);
    _mergedCacheByUser[userId] = _EntriesCache(entries: entries, fetchedAt: now);
    return entries;
  }


  Future<void> addEntry(
    TrackerEntry entry, {
    Map<String, dynamic>? extraFields,
    bool recordAudit = true,
    bool trackAchievements = true,
  }) async {
    try {
      final data = {
        'id': entry.id,
        'user_id': entry.userId,
        'date': entry.date.toIso8601String(),
        'pain_level': entry.painLevel,
        'pain_map': entry.painMap?.map((p) => p.toJson()).toList(),
        'sleep_quality': entry.sleepQuality,
        'energy_level': entry.energyLevel,
        'mood': entry.mood,
        'spasm_frequency': entry.spasmFrequency,
        'bladder_success': entry.bladderSuccess,
        'bowel_program': entry.bowelProgram,
        'steps': entry.steps,
        'systolic_bp': entry.systolicBP,
        'diastolic_bp': entry.diastolicBP,
        'heart_rate': entry.heartRate,
        'weight': entry.weight,
        'temperature': entry.temperature,
        'notes': entry.notes,
        'medications': entry.medications,
        'symptoms': entry.symptoms,
        'triggers': entry.triggers,
        'activities': entry.activities,
        'custom_fields': entry.customFields,
        'created_at': entry.createdAt.toIso8601String(),
        'updated_at': entry.updatedAt.toIso8601String(),
      };
      if (extraFields != null) {
        data.addAll(extraFields);
      }
      await _supabase.from('tracker_entries').upsert(data);

      // Ensure subsequent reads don't serve stale data (stats, charts, etc.).
      _invalidateMergedCache(entry.userId);

      // New entry changes what we should suggest next time.
      _invalidateSuggestionsCache(entry.userId);

      if (recordAudit) {
        // Record audit log (create)
        await _audit.recordChange(
          action: 'create',
          subjectUid: entry.userId,
          resource: 'tracker_entries/${entry.id}',
          resourceType: 'tracker_entry',
        );
      }
      if (trackAchievements) {
        // Track achievements
        _trackAchievements(entry.userId);
      }
      
      // Check if family members should be notified about alerts
      _checkFamilyAlerts(entry.userId, entry);
    } catch (e) {
      debugPrint('TrackerService.addEntry error: $e');
      rethrow;
    }
  }
  
  Future<void> _checkFamilyAlerts(String userId, TrackerEntry entry) async {
    try {
      // Get patient info
      final user = await UserService().getUserById(userId);
      if (user == null) return;
      
      // Get current user to check if they're a family member
      // Only family members should receive family alerts
      final userService = UserService();
      final currentUser = await userService.getCurrentUser();
      
      // Only proceed if current user is a family member
      // (They are monitoring health data for this patient)
      if (currentUser?.role != UserRole.family) {
        debugPrint(
            'TrackerService._checkFamilyAlerts: Current user is not a family member, skipping family alerts');
        return;
      }
      
      // Build a summary of the logged entry
      final summaryParts = <String>[];
      if (entry.painLevel != null) summaryParts.add('Pain: ${entry.painLevel}/10');
      if (entry.energyLevel != null) summaryParts.add('Energy: ${entry.energyLevel}/10');
      if (entry.mood != null && entry.mood!.isNotEmpty) summaryParts.add('Mood: ${entry.mood}');
      if (entry.temperature != null) summaryParts.add('Temp: ${entry.temperature}°F');
      
      final logSummary = summaryParts.isNotEmpty 
          ? summaryParts.join(', ')
          : 'New health entry logged';
      
      // Notify family members about new health log
      final familyService = FamilyService();
      await familyService.notifyFamilyNewHealthLog(
        patientId: userId,
        patientName: user.name,
        logSummary: logSummary,
      );
      
      // Trigger family alert check (runs in background)
      familyService.checkAndNotifyAlerts(userId, user.name);
    } catch (e) {
      debugPrint('TrackerService._checkFamilyAlerts error: $e');
    }
  }

  Future<void> _trackAchievements(String userId) async {
    try {
      // Get all entries to calculate stats
      final entries = await _getMergedEntriesCached(userId);
      
      // First entry achievement
      await _achievements.updateProgress(userId, 'first_entry', entries.isNotEmpty ? 1 : 0);
      
      // Total entries achievements (set absolute progress)
      await _achievements.updateProgress(userId, 'tracker_week', entries.length);
      await _achievements.updateProgress(userId, 'tracker_month', entries.length);
      
      // Calculate consecutive days streak
      final streak = _calculateStreak(entries);
      await _achievements.updateProgress(userId, 'tracker_streak_7', streak);
      await _achievements.updateProgress(userId, 'tracker_streak_30', streak);
    } catch (e) {
      debugPrint('TrackerService._trackAchievements error: $e');
    }
  }

  int _calculateStreak(List<TrackerEntry> entries) {
    if (entries.isEmpty) return 0;
    
    // Sort by date descending
    final sorted = List<TrackerEntry>.from(entries);
    sorted.sort((a, b) => b.date.compareTo(a.date));
    
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    
    // Check if most recent entry is today or yesterday
    final mostRecent = sorted.first;
    final mostRecentStart = DateTime(mostRecent.date.year, mostRecent.date.month, mostRecent.date.day);
    final daysDiff = todayStart.difference(mostRecentStart).inDays;
    
    if (daysDiff > 1) return 0; // Streak broken
    
    int streak = 0;
    DateTime? lastDate;
    
    for (final entry in sorted) {
      final entryStart = DateTime(entry.date.year, entry.date.month, entry.date.day);
      
      if (lastDate == null) {
        streak = 1;
        lastDate = entryStart;
      } else {
        final diff = lastDate.difference(entryStart).inDays;
        if (diff == 1) {
          streak++;
          lastDate = entryStart;
        } else if (diff > 1) {
          break; // Streak broken
        }
        // If diff == 0, it's the same day, skip to next
      }
    }
    
    return streak;
  }

  /// Returns a live stream of the most recent entries for a user.
  /// Ordered by `date` descending to surface the latest first.
  Stream<List<TrackerEntry>> recentEntriesStream(
    String userId, {
    int limit = 25,
    bool includeNutrition = true,
  }) {
    try {
      return _supabase
          .from('tracker_entries')
          .stream(primaryKey: ['id'])
          .eq('user_id', userId)
          .order('date', ascending: false)
          .limit(limit)
          .map((data) {
            final entries = data
                .map((item) => TrackerEntry.fromJson({
                  'id': item['id'],
                  'userId': item['user_id'],
                  'date': item['date'],
                  'painLevel': item['pain_level'],
                  'painMap': item['pain_map'],
                  'sleepQuality': item['sleep_quality'],
                  'energyLevel': item['energy_level'],
                  'mood': item['mood'],
                  'spasmFrequency': item['spasm_frequency'],
                  'bladderSuccess': item['bladder_success'],
                  'bowelProgram': item['bowel_program'],
                  'steps': item['steps'],
                  'systolicBP': item['systolic_bp'],
                  'diastolicBP': item['diastolic_bp'],
                  'heartRate': item['heart_rate'],
                  'weight': item['weight'],
                  'temperature': item['temperature'],
                  'notes': item['notes'],
                  'medications': item['medications'],
                  'symptoms': item['symptoms'],
                  'triggers': item['triggers'],
                  'activities': item['activities'],
                  'customFields': item['custom_fields'],
                  'createdAt': item['created_at'],
                  'updatedAt': item['updated_at'],
                }))
                .toList();

            if (includeNutrition) return entries;
            return entries.where((e) => !e.isNutritionOnlyEntry).toList();
          })
          .handleError((e) {
            debugPrint('TrackerService.recentEntriesStream error: $e');
          });
    } catch (e) {
      debugPrint('TrackerService.recentEntriesStream init error: $e');
      // Fallback to an empty stream to avoid breaking callers
      return const Stream<List<TrackerEntry>>.empty();
    }
  }

  /// Fetch the most recent entries once for a user.
  Future<List<TrackerEntry>> getRecentEntries(
    String userId, {
    int limit = 25,
    bool includeNutrition = true,
  }) async {
    try {
      final entries = await _getMergedEntriesCached(userId, limit: limit);
      final filtered = includeNutrition
          ? entries
          : entries.where((e) => !e.isNutritionOnlyEntry).toList();
      if (filtered.length > limit) return filtered.sublist(0, limit);
      return filtered;
    } catch (e) {
      debugPrint('TrackerService.getRecentEntries error: $e');
      return [];
    }
  }

  Future<List<TrackerEntry>> getEntriesByDateRange(String userId, DateTime start, DateTime end) async {
    try {
      // Use cached merged entries when available to avoid duplicate reads.
      final all = await _getMergedEntriesCached(userId, limit: 1000);

      final filtered = all.where((e) {
        final afterStart = !e.date.isBefore(start); // e.date >= start
        final beforeEnd = !e.date.isAfter(end); // e.date <= end
        return afterStart && beforeEnd;
      }).toList();
      return filtered;
    } catch (e) {
      debugPrint('TrackerService.getEntriesByDateRange error: $e');
      return [];
    }
  }

  Future<TrackerEntry?> getEntryByDate(String userId, DateTime date) async {
    try {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

      final data = await _supabase
          .from('tracker_entries')
          .select()
          .eq('user_id', userId)
          .gte('date', startOfDay.toIso8601String())
          .lte('date', endOfDay.toIso8601String())
          .order('date', ascending: false)
          .limit(1);

      if (data.isNotEmpty) {
        final item = data.first;
        return TrackerEntry.fromJson({
          'id': item['id'],
          'userId': item['user_id'],
          'date': item['date'],
          'painLevel': item['pain_level'],
          'painMap': item['pain_map'],
          'sleepQuality': item['sleep_quality'],
          'energyLevel': item['energy_level'],
          'mood': item['mood'],
          'spasmFrequency': item['spasm_frequency'],
          'bladderSuccess': item['bladder_success'],
          'bowelProgram': item['bowel_program'],
          'steps': item['steps'],
          'systolicBP': item['systolic_bp'],
          'diastolicBP': item['diastolic_bp'],
          'heartRate': item['heart_rate'],
          'weight': item['weight'],
          'temperature': item['temperature'],
          'notes': item['notes'],
          'medications': item['medications'],
          'symptoms': item['symptoms'],
          'triggers': item['triggers'],
          'activities': item['activities'],
          'customFields': item['custom_fields'],
          'createdAt': item['created_at'],
          'updatedAt': item['updated_at'],
        });
      }
    } catch (e) {
      debugPrint('TrackerService.getEntryByDate error: $e');
    }
    return null;
  }

  /// Get a medication-only entry for a specific date.
  /// Returns null if no medication-only entry exists for that date.
  Future<TrackerEntry?> getMedicationOnlyEntryByDate(String userId, DateTime date) async {
    try {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

      final data = await _supabase
          .from('tracker_entries')
          .select()
          .eq('user_id', userId)
          .gte('date', startOfDay.toIso8601String())
          .lte('date', endOfDay.toIso8601String())
          .order('date', ascending: false);

      for (final item in data) {
        final entry = TrackerEntry.fromJson({
          'id': item['id'],
          'userId': item['user_id'],
          'date': item['date'],
          'painLevel': item['pain_level'],
          'painMap': item['pain_map'],
          'sleepQuality': item['sleep_quality'],
          'energyLevel': item['energy_level'],
          'mood': item['mood'],
          'spasmFrequency': item['spasm_frequency'],
          'bladderSuccess': item['bladder_success'],
          'bowelProgram': item['bowel_program'],
          'steps': item['steps'],
          'systolicBP': item['systolic_bp'],
          'diastolicBP': item['diastolic_bp'],
          'heartRate': item['heart_rate'],
          'weight': item['weight'],
          'temperature': item['temperature'],
          'notes': item['notes'],
          'medications': item['medications'],
          'symptoms': item['symptoms'],
          'triggers': item['triggers'],
          'activities': item['activities'],
          'customFields': item['custom_fields'],
          'createdAt': item['created_at'],
          'updatedAt': item['updated_at'],
        });
        if (entry.isMedicationOnlyEntry) {
          return entry;
        }
      }
    } catch (e) {
      debugPrint('TrackerService.getMedicationOnlyEntryByDate error: $e');
    }
    return null;
  }

  Future<void> updateEntry(
    TrackerEntry entry, {
    Map<String, dynamic>? extraFields,
    bool recordAudit = true,
  }) async {
    try {
      final data = {
        'user_id': entry.userId,
        'date': entry.date.toIso8601String(),
        'pain_level': entry.painLevel,
        'pain_map': entry.painMap?.map((p) => p.toJson()).toList(),
        'sleep_quality': entry.sleepQuality,
        'energy_level': entry.energyLevel,
        'mood': entry.mood,
        'spasm_frequency': entry.spasmFrequency,
        'bladder_success': entry.bladderSuccess,
        'bowel_program': entry.bowelProgram,
        'steps': entry.steps,
        'systolic_bp': entry.systolicBP,
        'diastolic_bp': entry.diastolicBP,
        'heart_rate': entry.heartRate,
        'weight': entry.weight,
        'temperature': entry.temperature,
        'notes': entry.notes,
        'medications': entry.medications,
        'symptoms': entry.symptoms,
        'triggers': entry.triggers,
        'activities': entry.activities,
        'custom_fields': entry.customFields,
        'updated_at': entry.updatedAt.toIso8601String(),
      };
      if (extraFields != null) {
        data.addAll(extraFields);
      }
      await _supabase
          .from('tracker_entries')
          .update(data)
          .eq('id', entry.id);

      // Ensure subsequent reads don't serve stale data (stats, charts, etc.).
      _invalidateMergedCache(entry.userId);

      // Updated entry can add/remove suggestion candidates.
      _invalidateSuggestionsCache(entry.userId);

      if (recordAudit) {
        // Record audit log (update)
        await _audit.recordChange(
          action: 'update',
          subjectUid: entry.userId,
          resource: 'tracker_entries/${entry.id}',
          resourceType: 'tracker_entry',
        );
      }
    } catch (e) {
      debugPrint('TrackerService.updateEntry error: $e');
      rethrow;
    }
  }

  Future<void> deleteEntry(String userId, String entryId) async {
    try {
      await _supabase
          .from('tracker_entries')
          .delete()
          .eq('id', entryId)
          .eq('user_id', userId);

      // Ensure subsequent reads don't serve stale data (stats, charts, etc.).
      _invalidateMergedCache(userId);

      // Deleting can change suggestion frequency.
      _invalidateSuggestionsCache(userId);

      // Record audit log (delete)
      await _audit.recordChange(
        action: 'delete',
        subjectUid: userId,
        resource: 'tracker_entries/$entryId',
        resourceType: 'tracker_entry',
      );
    } catch (e) {
      debugPrint('TrackerService.deleteEntry error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getSignMeta(String userId, String entryId) async {
    try {
      final data = await _supabase
          .from('tracker_entries')
          .select('sign_meta')
          .eq('id', entryId)
          .eq('user_id', userId)
          .maybeSingle();
      if (data == null) return null;
      final sm = data['sign_meta'];
      if (sm is Map<String, dynamic>) return sm;
      if (sm is Map) return sm.cast<String, dynamic>();
      return null;
    } catch (e) {
      debugPrint('TrackerService.getSignMeta error: $e');
      return null;
    }
  }

  Future<Map<String, double>> getStatistics(String userId, DateTime start, DateTime end) async {
    try {
      // Fetch once from cache/remote and filter locally for speed.
      final all = await _getMergedEntriesCached(userId, limit: 1000);
      final entries = all.where((e) {
        final afterStart = !e.date.isBefore(start);
        final beforeEnd = !e.date.isAfter(end);
        return afterStart && beforeEnd;
      }).toList();
      if (entries.isEmpty) return {};

      final painLevels = entries.where((e) => e.painLevel != null).map((e) => e.painLevel!).toList();
      final sleepQuality = entries.where((e) => e.sleepQuality != null).map((e) => e.sleepQuality!).toList();
      final energyLevels = entries.where((e) => e.energyLevel != null).map((e) => e.energyLevel!).toList();
      final stepsVals = entries.where((e) => e.steps != null).map((e) => e.steps!).toList();
      final sysVals = entries.where((e) => e.systolicBP != null).map((e) => e.systolicBP!).toList();
      final diaVals = entries.where((e) => e.diastolicBP != null).map((e) => e.diastolicBP!).toList();
      final hrVals = entries.where((e) => e.heartRate != null).map((e) => e.heartRate!).toList();

      return {
        'avgPain': painLevels.isEmpty ? 0 : painLevels.reduce((a, b) => a + b) / painLevels.length,
        'avgSleep': sleepQuality.isEmpty ? 0 : sleepQuality.reduce((a, b) => a + b) / sleepQuality.length,
        'avgEnergy': energyLevels.isEmpty ? 0 : energyLevels.reduce((a, b) => a + b) / energyLevels.length,
        'avgSteps': stepsVals.isEmpty ? 0 : stepsVals.reduce((a, b) => a + b) / stepsVals.length,
        'totalSteps': stepsVals.isEmpty ? 0 : stepsVals.fold<int>(0, (sum, v) => sum + v).toDouble(),
        'avgSys': sysVals.isEmpty ? 0 : sysVals.reduce((a, b) => a + b) / sysVals.length,
        'avgDia': diaVals.isEmpty ? 0 : diaVals.reduce((a, b) => a + b) / diaVals.length,
        'avgHeartRate': hrVals.isEmpty ? 0 : hrVals.reduce((a, b) => a + b) / hrVals.length,
        'totalEntries': entries.length.toDouble(),
      };
    } catch (e) {
      debugPrint('TrackerService.getStatistics error: $e');
      return {};
    }
  }

  // --- Suggestions ----------------------------------------------------------

  void _invalidateSuggestionsCache(String userId) {
    _suggestionsCacheByUser.remove(userId);
  }

  String _kindKey(TrackerSuggestionKind kind) => kind.name;

  String? _cleanSuggestionKey(String raw) {
    final cleaned = _cleanSuggestion(raw);
    if (cleaned == null) return null;
    return cleaned.toLowerCase();
  }

  Future<Set<String>> _getExcludedKeysForKind(String userId, TrackerSuggestionKind kind) async {
    try {
      final now = DateTime.now();
      final cached = _exclusionsCacheByUser[userId];
      if (cached != null && now.difference(cached.fetchedAt) < exclusionsCacheTtl) {
        return cached.keysByKind[_kindKey(kind)] ?? <String>{};
      }

      final row = await _supabase.from('users').select('preferences').eq('id', userId).maybeSingle();
      final prefs = (row?['preferences'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
      final rawExclusions = (prefs[_prefSuggestionExclusionsKey] as Map?)?.cast<String, dynamic>() ??
          <String, dynamic>{};

      final keysByKind = <String, Set<String>>{};
      for (final k in suggestionKinds) {
        final kindKey = _kindKey(k);
        final list = rawExclusions[kindKey];
        if (list is List) {
          keysByKind[kindKey] = list
              .whereType<String>()
              .map((s) => s.trim().toLowerCase())
              .where((s) => s.isNotEmpty)
              .toSet();
        } else {
          keysByKind[kindKey] = <String>{};
        }
      }

      _exclusionsCacheByUser[userId] = _ExclusionsCache(keysByKind: keysByKind, fetchedAt: now);
      return keysByKind[_kindKey(kind)] ?? <String>{};
    } catch (e) {
      debugPrint('TrackerService._getExcludedKeysForKind error: $e');
      return <String>{};
    }
  }

  /// Permanently hide a suggestion from future recommendation lists for this user.
  ///
  /// Note: This does NOT edit past tracker entries; it only adds an exclusion
  /// preference so derived suggestions won't surface this string again.
  Future<void> excludeSuggestion(
    String userId,
    TrackerSuggestionKind kind,
    String suggestion,
  ) async {
    try {
      final key = _cleanSuggestionKey(suggestion);
      if (key == null) return;

      final row = await _supabase.from('users').select('preferences').eq('id', userId).maybeSingle();
      final prefs = Map<String, dynamic>.from((row?['preferences'] as Map?)?.cast<String, dynamic>() ?? {});

      final rawExclusions = Map<String, dynamic>.from((prefs[_prefSuggestionExclusionsKey] as Map?)?.cast<String, dynamic>() ?? {});
      final kindKey = _kindKey(kind);

      final existing = <String>{};
      final list = rawExclusions[kindKey];
      if (list is List) {
        existing.addAll(list.whereType<String>().map((s) => s.trim().toLowerCase()).where((s) => s.isNotEmpty));
      }
      if (existing.contains(key)) return;

      existing.add(key);
      rawExclusions[kindKey] = existing.toList()..sort();
      prefs[_prefSuggestionExclusionsKey] = rawExclusions;

      await _supabase.from('users').update({'preferences': prefs, 'updated_at': DateTime.now().toIso8601String()}).eq('id', userId);

      // Invalidate caches so the removed item disappears immediately.
      _invalidateSuggestionsCache(userId);
      _invalidateExclusionsCache(userId);
    } catch (e) {
      debugPrint('TrackerService.excludeSuggestion error: $e');
      rethrow;
    }
  }

  /// Returns a ranked list of suggestions for a given [kind], derived from the
  /// user's saved tracker entries.
  ///
  /// Ranking favors:
  /// - More recent usage
  /// - Higher frequency
  Future<List<String>> getSuggestionsForKind(
    String userId,
    TrackerSuggestionKind kind, {
    int limit = 12,
    String? query,
  }) async {
    if (!suggestionKinds.contains(kind)) return [];

    try {
      final now = DateTime.now();
      final excluded = await _getExcludedKeysForKind(userId, kind);
      final cached = _suggestionsCacheByUser[userId];
      if (cached != null && now.difference(cached.fetchedAt) < suggestionsCacheTtl) {
        final base = cached.byKind[kind] ?? const [];
        final filteredOut = base.where((s) => !excluded.contains(s.toLowerCase())).toList();
        return _filterSuggestions(filteredOut, limit: limit, query: query);
      }

      // Use our existing merged entries cache to avoid extra reads.
      final entries = await _getMergedEntriesCached(userId, limit: 500);
      final byKind = <TrackerSuggestionKind, List<String>>{};

      for (final k in suggestionKinds) {
        byKind[k] = _rankSuggestions(entries, k);
      }

      _suggestionsCacheByUser[userId] = _SuggestionsCache(byKind: byKind, fetchedAt: now);
      final base = byKind[kind] ?? const [];
      final filteredOut = base.where((s) => !excluded.contains(s.toLowerCase())).toList();
      return _filterSuggestions(filteredOut, limit: limit, query: query);
    } catch (e) {
      debugPrint('TrackerService.getSuggestionsForKind error: $e');
      return [];
    }
  }

  List<String> _filterSuggestions(List<String> all, {required int limit, String? query}) {
    final q = query?.trim().toLowerCase();
    final filtered = (q == null || q.isEmpty)
        ? all
        : all.where((s) => s.toLowerCase().contains(q)).toList();
    if (filtered.length <= limit) return filtered;
    return filtered.sublist(0, limit);
  }

  List<String> _rankSuggestions(List<TrackerEntry> entries, TrackerSuggestionKind kind) {
    final Map<String, _SuggestionStat> statsByKey = {};

    for (final e in entries) {
      final values = switch (kind) {
        TrackerSuggestionKind.medications => e.medications,
        TrackerSuggestionKind.symptoms => e.symptoms,
        TrackerSuggestionKind.triggers => e.triggers,
        TrackerSuggestionKind.activities => e.activities,
      };
      if (values == null) continue;

      for (final raw in values) {
        final cleaned = _cleanSuggestion(raw);
        if (cleaned == null) continue;
        final key = cleaned.toLowerCase();
        final existing = statsByKey[key];
        if (existing == null) {
          statsByKey[key] = _SuggestionStat(label: cleaned, count: 1, lastUsedAt: e.date);
        } else {
          existing.count += 1;
          if (e.date.isAfter(existing.lastUsedAt)) {
            existing.lastUsedAt = e.date;
            // Prefer the most recently used capitalization.
            existing.label = cleaned;
          }
        }
      }
    }

    final stats = statsByKey.values.toList();
    stats.sort((a, b) {
      final dateCmp = b.lastUsedAt.compareTo(a.lastUsedAt);
      if (dateCmp != 0) return dateCmp;
      final countCmp = b.count.compareTo(a.count);
      if (countCmp != 0) return countCmp;
      return a.label.toLowerCase().compareTo(b.label.toLowerCase());
    });
    return stats.map((s) => s.label).toList();
  }

  String? _cleanSuggestion(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    // Collapse repeated whitespace.
    final normalized = trimmed.replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.length > 60) return normalized.substring(0, 60).trim();
    return normalized;
  }
}

class _EntriesCache {
  final List<TrackerEntry> entries; // sorted desc by date
  final DateTime fetchedAt;
  _EntriesCache({required this.entries, required this.fetchedAt});
}

enum TrackerSuggestionKind { medications, symptoms, triggers, activities }

class _SuggestionsCache {
  final Map<TrackerSuggestionKind, List<String>> byKind;
  final DateTime fetchedAt;
  _SuggestionsCache({required this.byKind, required this.fetchedAt});
}

class _ExclusionsCache {
  final Map<String, Set<String>> keysByKind; // kindKey -> excluded lowercase keys
  final DateTime fetchedAt;
  _ExclusionsCache({required this.keysByKind, required this.fetchedAt});
}

class _SuggestionStat {
  String label;
  int count;
  DateTime lastUsedAt;
  _SuggestionStat({required this.label, required this.count, required this.lastUsedAt});
}
