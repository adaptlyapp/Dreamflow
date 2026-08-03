import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wellspring/models/condition.dart';
import 'package:uuid/uuid.dart';

class ConditionService {
  static const String _conditionsKey = 'conditions_data';
  static const String _catalogAssetPath = 'assets/data/conditions_catalog.json';
  // Bump this when we ship a newer built-in catalog so existing users refresh.
  // Increment this to force-refresh bundled catalog into local storage for all users
  static const int _dataVersion = 7;
  static const String _versionKey = 'conditions_data_version';
  static const String _recentlyAddedKey = 'conditions_recently_added_ids';

  // Legacy sample ID -> Name crosswalk (from the original built-in sample list)
  static const Map<String, String> _legacyIdToName = {
    '1': 'Multiple Sclerosis',
    '2': 'Fibromyalgia',
    '3': 'Type 1 Diabetes',
    '4': 'Rheumatoid Arthritis',
    '5': 'Spinal Cord Injury',
  };

  Future<void> _ensureConditionsData() async {
    final prefs = await SharedPreferences.getInstance();
    final currentVersion = prefs.getInt(_versionKey) ?? 0;
    // If we have data and version is current, nothing to do.
    if (prefs.containsKey(_conditionsKey) && currentVersion >= _dataVersion) return;

    // Try to load a comprehensive catalog from assets first
    try {
      final catalogJson = await rootBundle.loadString(_catalogAssetPath);
      final parsed = jsonDecode(catalogJson);
      final List<dynamic> list = parsed is List ? parsed : (parsed['items'] as List<dynamic>);

      final now = DateTime.now();
      final conditions = <Condition>[];

      for (final item in list) {
        try {
          // Accept either a string (name) or an object { name, description }
          String name;
          String description = '';
          if (item is String) {
            name = item.trim();
          } else if (item is Map<String, dynamic>) {
            name = (item['name'] as String?)?.trim() ?? '';
            description = (item['description'] as String?)?.trim() ?? '';
          } else {
            continue;
          }
          if (name.isEmpty) continue;

          final id = _slugify(name);
          conditions.add(
            Condition(
              id: id,
              name: name,
              description: description,
              symptoms: const [],
              dailyAdjustments: const [],
              resources: const [],
              aiGenerated: false,
              timeline: ConditionTimeline(week1: '', month1: '', month3: '', longTerm: ''),
              relatedGroups: const [],
              createdAt: now,
              updatedAt: now,
            ),
          );
        } catch (e) {
          debugPrint('Skipping catalog item due to parse error: $e');
        }
      }

      if (conditions.isNotEmpty) {
        // If there were existing conditions, try to merge any unique legacy entries
        // (by slugified name) to avoid losing user context entirely during refresh.
        try {
          final existingJson = prefs.getString(_conditionsKey);
          if (existingJson != null) {
            final List<dynamic> existingList = jsonDecode(existingJson);
            final existing = <Condition>[];
            for (final e in existingList) {
              try { existing.add(Condition.fromJson(e)); } catch (_) {}
            }
            final bySlug = <String, Condition>{
              for (final c in conditions) _slugify(c.name): c,
            };
            // Track which slugs are newly added compared to previous data
            final existingSlugs = <String>{ for (final c in existing) _slugify(c.name) };
            final newSlugs = <String>{ for (final c in conditions) _slugify(c.name) };
            final addedSlugs = newSlugs.difference(existingSlugs);
            for (final old in existing) {
              final slug = _slugify(old.name);
              if (!bySlug.containsKey(slug)) {
                bySlug[slug] = old;
              }
            }
            await prefs.setString(
              _conditionsKey,
              jsonEncode(bySlug.values.map((c) => c.toJson()).toList()),
            );
            // Save recently added IDs for UI surfacing
            try {
              final addedIds = addedSlugs
                  .map((s) => bySlug[s])
                  .where((c) => c != null)
                  .map((c) => c!.id)
                  .toList();
              if (addedIds.isNotEmpty) {
                await prefs.setStringList(_recentlyAddedKey, addedIds);
              }
            } catch (e) {
              debugPrint('Failed recording recently added conditions: $e');
            }
          } else {
            // Fresh write
            await prefs.setString(
              _conditionsKey,
              jsonEncode(conditions.map((c) => c.toJson()).toList()),
            );
            // All of these are effectively new on first write; surface a small subset to avoid overload
            try {
              final ids = conditions.take(6).map((c) => c.id).toList();
              if (ids.isNotEmpty) {
                await prefs.setStringList(_recentlyAddedKey, ids);
              }
            } catch (e) {
              debugPrint('Failed to store initial recently added conditions: $e');
            }
          }
        } catch (e) {
          debugPrint('Failed merging existing conditions, writing catalog only. $e');
          await prefs.setString(
            _conditionsKey,
            jsonEncode(conditions.map((c) => c.toJson()).toList()),
          );
          try {
            final ids = conditions.take(6).map((c) => c.id).toList();
            if (ids.isNotEmpty) {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setStringList(_recentlyAddedKey, ids);
            }
          } catch (e2) {
            debugPrint('Also failed saving recently added after fallback write: $e2');
          }
        }
        await prefs.setInt(_versionKey, _dataVersion);
        return;
      }
    } catch (e) {
      debugPrint('Condition catalog asset not available or invalid: $e');
    }

    // Fallback to a small built-in sample if asset catalog isn't available
    try {
      final now = DateTime.now();
      final sampleConditions = [
        Condition(
          id: '1',
          name: 'Multiple Sclerosis',
          description: 'Multiple sclerosis (MS) is a chronic disease affecting the central nervous system. The immune system attacks the protective covering of nerve fibers, causing communication problems between the brain and the rest of the body.',
          symptoms: ['Fatigue', 'Numbness or weakness', 'Vision problems', 'Difficulty walking', 'Muscle spasms'],
          dailyAdjustments: ['Regular exercise and physical therapy', 'Balanced diet rich in vitamin D', 'Adequate rest and stress management', 'Cool environment to manage heat sensitivity'],
          resources: ['MS Society support groups', 'Physical therapy centers', 'Neurologist specialists'],
          aiGenerated: true,
          timeline: ConditionTimeline(
            week1: 'Focus on understanding your diagnosis. Connect with your healthcare team and start learning about MS. Begin documenting symptoms and triggers.',
            month1: 'Establish routines for medication and self-care. Join support groups to connect with others. Start physical therapy if recommended.',
            month3: 'Adapt your lifestyle based on what works. Continue therapies and monitor progress. Explore assistive technologies if needed.',
            longTerm: 'Develop a sustainable management plan. Regular check-ups with specialists. Stay connected with your support network and advocate for your needs.',
          ),
          relatedGroups: ['1', '2'],
          createdAt: now,
          updatedAt: now,
        ),
        Condition(
          id: '2',
          name: 'Fibromyalgia',
          description: 'Fibromyalgia is a disorder characterized by widespread musculoskeletal pain accompanied by fatigue, sleep, memory and mood issues. It amplifies painful sensations by affecting the way the brain processes pain signals.',
          symptoms: ['Widespread pain', 'Fatigue', 'Sleep disturbances', 'Cognitive difficulties', 'Mood changes'],
          dailyAdjustments: ['Gentle exercise like yoga or swimming', 'Consistent sleep schedule', 'Stress reduction techniques', 'Pain management strategies'],
          resources: ['Pain management clinics', 'Sleep specialists', 'Mental health counselors'],
          aiGenerated: true,
          timeline: ConditionTimeline(
            week1: 'Begin tracking your pain patterns and triggers. Work with your doctor on initial treatment options. Start gentle stretching exercises.',
            month1: 'Establish sleep hygiene routines. Try different pain management techniques to find what works. Consider joining a support group.',
            month3: 'Refine your treatment plan based on results. Continue building healthy habits. Explore complementary therapies like massage or acupuncture.',
            longTerm: 'Maintain a balanced lifestyle with regular exercise, good sleep, and stress management. Stay informed about new treatments and research.',
          ),
          relatedGroups: ['3'],
          createdAt: now,
          updatedAt: now,
        ),
        Condition(
          id: '3',
          name: 'Type 1 Diabetes',
          description: 'Type 1 diabetes is a chronic condition in which the pancreas produces little or no insulin, a hormone needed to allow sugar to enter cells to produce energy. It requires lifelong insulin therapy.',
          symptoms: ['Increased thirst', 'Frequent urination', 'Extreme hunger', 'Fatigue', 'Blurred vision'],
          dailyAdjustments: ['Regular blood glucose monitoring', 'Insulin administration as prescribed', 'Carbohydrate counting', 'Regular meals and snacks'],
          resources: ['Endocrinologists', 'Diabetes educators', 'Nutritionists'],
          aiGenerated: true,
          timeline: ConditionTimeline(
            week1: 'Learn blood glucose monitoring and insulin administration. Understand signs of high and low blood sugar. Start carb counting basics.',
            month1: 'Develop a meal plan with a nutritionist. Establish a monitoring routine. Learn to adjust insulin based on activity and food.',
            month3: 'Fine-tune your management routine. Explore continuous glucose monitors if appropriate. Build confidence in managing different situations.',
            longTerm: 'Maintain regular check-ups for complications screening. Stay current with technology advances. Connect with the diabetes community for ongoing support.',
          ),
          relatedGroups: ['4'],
          createdAt: now,
          updatedAt: now,
        ),
        Condition(
          id: '4',
          name: 'Rheumatoid Arthritis',
          description: 'Rheumatoid arthritis is an autoimmune disorder that primarily affects joints. It occurs when the immune system mistakenly attacks the body\'s tissues, causing painful swelling and potential joint deformity.',
          symptoms: ['Joint pain and swelling', 'Morning stiffness', 'Fatigue', 'Fever', 'Loss of appetite'],
          dailyAdjustments: ['Joint-friendly exercises', 'Use of assistive devices', 'Anti-inflammatory diet', 'Regular rest periods'],
          resources: ['Rheumatologists', 'Occupational therapists', 'Physical therapists'],
          aiGenerated: true,
          timeline: ConditionTimeline(
            week1: 'Start prescribed medications and track response. Learn joint protection techniques. Begin gentle range-of-motion exercises.',
            month1: 'Work with occupational therapy on daily living adaptations. Adjust activities to manage fatigue. Explore pain management options.',
            month3: 'Assess medication effectiveness and adjust as needed. Continue therapy exercises. Learn stress management techniques.',
            longTerm: 'Regular monitoring with rheumatologist to prevent joint damage. Maintain physical activity within limits. Stay informed about new treatment options.',
          ),
          relatedGroups: ['5'],
          createdAt: now,
          updatedAt: now,
        ),
        Condition(
          id: '5',
          name: 'Spinal Cord Injury',
          description: 'A spinal cord injury is damage to the spinal cord that results in a loss of function such as mobility or feeling. It can result in complete or incomplete loss of motor and sensory function below the injury level.',
          symptoms: ['Loss of movement', 'Loss of sensation', 'Pain or intense stinging', 'Difficulty breathing', 'Loss of bladder or bowel control'],
          dailyAdjustments: ['Specialized mobility equipment', 'Bladder and bowel management programs', 'Pressure sore prevention', 'Regular physical therapy'],
          resources: ['Spinal cord injury centers', 'Rehabilitation specialists', 'Adaptive equipment providers'],
          aiGenerated: true,
          timeline: ConditionTimeline(
            week1: 'Focus on acute medical stabilization and initial rehabilitation. Learn about your injury level and prognosis. Begin working with the rehabilitation team.',
            month1: 'Intensive rehabilitation therapy. Learn bladder and bowel management. Start exploring mobility options and adaptive equipment.',
            month3: 'Continue building strength and independence. Adapt home environment for accessibility. Connect with peer mentors who have similar injuries.',
            longTerm: 'Maintain health through regular exercise and check-ups. Prevent secondary complications. Live independently with appropriate support and equipment.',
          ),
          relatedGroups: ['6'],
          createdAt: now,
          updatedAt: now,
        ),
      ];
      await prefs.setString(_conditionsKey, jsonEncode(sampleConditions.map((c) => c.toJson()).toList()));
      await prefs.setInt(_versionKey, _dataVersion);
    } catch (e) {
      debugPrint('Failed to write fallback sample conditions: $e');
    }
  }

  Future<List<Condition>> getAllConditions() async {
    await _ensureConditionsData();
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_conditionsKey);
      if (data != null) {
        final List<dynamic> decoded = jsonDecode(data);
        final results = <Condition>[];
        for (final item in decoded) {
          try {
            results.add(Condition.fromJson(item));
          } catch (e) {
            debugPrint('Skipping corrupted condition entry: $e');
          }
        }
        // Auto-sanitize by writing back the clean list
        await prefs.setString(_conditionsKey, jsonEncode(results.map((c) => c.toJson()).toList()));
        // Sort alphabetically for consistent UX across the app
        results.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        return results;
      }
    } catch (e) {
      debugPrint('Failed loading conditions: $e');
      return [];
    }
    return [];
  }

  /// Returns any condition entries that were newly added by the most recent
  /// catalog refresh. Optionally clears the marker after reading.
  Future<List<Condition>> getRecentlyAddedConditions({bool clearAfterRead = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ids = prefs.getStringList(_recentlyAddedKey) ?? const [];
      if (ids.isEmpty) return [];
      final all = await getAllConditions();
      final byId = {for (final c in all) c.id: c};
      final results = <Condition>[];
      for (final id in ids) {
        final c = byId[id];
        if (c != null) results.add(c);
      }
      if (clearAfterRead) {
        await prefs.remove(_recentlyAddedKey);
      }
      return results;
    } catch (e) {
      debugPrint('Failed to load recently added conditions: $e');
      return [];
    }
  }

  Future<void> clearRecentlyAddedConditions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_recentlyAddedKey);
    } catch (e) {
      debugPrint('Failed clearing recently added conditions: $e');
    }
  }

  Future<Condition?> getConditionById(String id) async {
    final conditions = await getAllConditions();
    try {
      return conditions.firstWhere((c) => c.id == id);
    } catch (e) {
      // Legacy compatibility: if id is from the early sample set, resolve by name
      final name = _legacyIdToName[id];
      if (name != null) {
        try {
          return conditions.firstWhere((c) => c.name.toLowerCase() == name.toLowerCase());
        } catch (_) {}
      }
      return null;
    }
  }

  Future<List<Condition>> searchConditions(String query) async {
    final conditions = await getAllConditions();
    if (query.isEmpty) return conditions;

    final lowerQuery = query.toLowerCase().trim();

    // Common acronyms and synonym shortcuts
    // Key: search token; Value: list of name substrings to match
    const Map<String, List<String>> synonyms = {
      'pots': ['postural orthostatic tachycardia syndrome', 'pots'],
      'me/cfs': ['myalgic encephalomyelitis', 'chronic fatigue syndrome', 'me/cfs'],
      'eds': ['ehlers–danlos', 'ehlers-danlos', 'ehlers danlos'],
      'asd': ['autism spectrum disorder', 'autism'],
      'adhd': ['attention deficit hyperactivity', 'adhd'],
      'ms': ['multiple sclerosis'],
      'ra': ['rheumatoid arthritis'],
      't1d': ['type 1 diabetes'],
      't2d': ['type 2 diabetes'],
      'gerd': ['gastroesophageal reflux disease', 'gerd'],
      'copd': ['chronic obstructive pulmonary disease', 'copd'],
      'ibs': ['irritable bowel syndrome'],
      'ptsd': ['post-traumatic stress', 'ptsd', 'posttraumatic stress'],
      'ocd': ['obsessive compulsive disorder', 'ocd'],
      'crps': ['complex regional pain syndrome', 'crps'],
      'ckd': ['chronic kidney disease'],
    };

    bool containsNormalized(String haystack, String needle) {
      final h = haystack.toLowerCase();
      if (h.contains(needle)) return true;
      // Also try removing punctuation and extra spaces
      final normalize = (String s) => s
          .toLowerCase()
          .replaceAll(RegExp(r"[\u2013\u2014\-_/()']"), ' ')
          .replaceAll(RegExp(r"\s+"), ' ')
          .trim();
      return normalize(h).contains(normalize(needle));
    }

    List<Condition> results = conditions.where((c) {
      final n = c.name.toLowerCase();
      final d = c.description.toLowerCase();
      return n.contains(lowerQuery) || d.contains(lowerQuery);
    }).toList();

    // If nothing matched, try synonym expansions
    if (results.isEmpty && synonyms.containsKey(lowerQuery)) {
      final terms = synonyms[lowerQuery]!;
      results = conditions.where((c) {
        final n = c.name;
        final d = c.description;
        return terms.any((t) => containsNormalized(n, t) || containsNormalized(d, t));
      }).toList();
    }

    // Always return results alphabetized
    results.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return results;
  }

  Future<ConditionTimeline?> getConditionTimeline(String conditionId) async {
    final condition = await getConditionById(conditionId);
    return condition?.timeline;
  }

  String _slugify(String input) {
    final slug = input
        .toLowerCase()
        .replaceAll(RegExp(r"[^a-z0-9]+"), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return slug.isEmpty ? const Uuid().v4() : slug;
  }
}
