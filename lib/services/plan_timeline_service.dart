import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:wellspring/models/milestone.dart';
import 'package:wellspring/models/plan_timeline.dart';
import 'package:wellspring/services/milestone_service.dart';
import 'package:wellspring/supabase/supabase_config.dart';

class PlanTimelineService {
  final SupabaseClient _supabase = SupabaseConfig.client;
  final MilestoneService _milestoneService = MilestoneService();
  final Uuid _uuid = const Uuid();

  String _normalizeConditionId(String conditionId) {
    final uuidPattern = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
    if (uuidPattern.hasMatch(conditionId)) return conditionId;
    return _uuid.v5(Uuid.NAMESPACE_URL, conditionId);
  }

  Future<void> _ensureConditionRow(String conditionId, {String? conditionName}) async {
    final name = (conditionName?.trim().isNotEmpty ?? false) ? conditionName!.trim() : conditionId;
    try {
      final existing = await _supabase.from('conditions').select('id').eq('id', conditionId).limit(1);
      if (existing.isNotEmpty) return;
    } catch (e) {
      debugPrint('PlanTimelineService: condition lookup failed $e');
    }

    try {
      await _supabase.from('conditions').upsert({
        'id': conditionId,
        'name': name.isEmpty ? 'Condition' : name,
        'description': '',
        'symptoms': const <String>[],
        'daily_adjustments': const <String>[],
        'resources': const <String>[],
        'ai_generated': false,
        'timeline': const {},
        'related_groups': const <String>[],
      });
    } catch (e) {
      debugPrint('PlanTimelineService: condition upsert failed $e');
    }
  }

  Future<T> _withConditionFallback<T>({
    required String conditionId,
    String? conditionName,
    required Future<T> Function(String dbConditionId) run,
  }) async {
    final normalized = _normalizeConditionId(conditionId);

    Future<T> attempt(String dbConditionId) async {
      try {
        return await run(dbConditionId);
      } on PostgrestException catch (e) {
        if (e.code == '23503') {
          await _ensureConditionRow(dbConditionId, conditionName: conditionName);
          return run(dbConditionId);
        }
        rethrow;
      }
    }

    try {
      return await attempt(conditionId);
    } on PostgrestException catch (e) {
      if (e.code == '22P02' && normalized != conditionId) {
        return attempt(normalized);
      }
      rethrow;
    }
  }

  Future<List<PlanTimeline>> list({required String userId, required String conditionId}) async {
    try {
      final normalizedId = _normalizeConditionId(conditionId);
      List<dynamic> data = await _withConditionFallback(
        conditionId: conditionId,
        conditionName: conditionId,
        run: (dbConditionId) async {
          return _supabase
              .from('plan_timelines')
              .select()
              .eq('user_id', userId)
              .eq('condition_id', dbConditionId)
              .order('created_at');
        },
      );

      // Fallback fetch to normalized UUID if the first lookup succeeds but returns empty rows
      final timelines = data
          .map((row) => PlanTimeline.fromJson({
                'id': row['id'],
                'user_id': row['user_id'],
                'condition_id': row['condition_id'],
                'name': row['name'],
                'is_current': row['is_current'],
                'milestones': row['milestones'],
                'created_at': row['created_at'],
                'updated_at': row['updated_at'],
              }))
          .toList();

      if (timelines.isEmpty && normalizedId != conditionId) {
        try {
          final normalizedData = await _supabase
              .from('plan_timelines')
              .select()
              .eq('user_id', userId)
              .eq('condition_id', normalizedId)
              .order('created_at');
          for (final row in normalizedData) {
            timelines.add(PlanTimeline.fromJson({
              'id': row['id'],
              'user_id': row['user_id'],
              'condition_id': row['condition_id'],
              'name': row['name'],
              'is_current': row['is_current'],
              'milestones': row['milestones'],
              'created_at': row['created_at'],
              'updated_at': row['updated_at'],
            }));
          }
        } catch (_) {}
      }

      timelines.sort((a, b) {
        if (a.isCurrent != b.isCurrent) return a.isCurrent ? -1 : 1;
        return b.updatedAt.compareTo(a.updatedAt);
      });
      // Ensure the UI keeps using the slug/route id
      return timelines
          .map((t) => PlanTimeline(
                id: t.id,
                userId: t.userId,
                conditionId: conditionId,
                name: t.name,
                isCurrent: t.isCurrent,
                milestones: t.milestones,
                createdAt: t.createdAt,
                updatedAt: t.updatedAt,
              ))
          .toList();
    } catch (e) {
      debugPrint('PlanTimelineService.list error: $e');
      return [];
    }
  }

  Future<PlanTimeline> createFromMilestones({
    required String userId,
    required String conditionId,
    String? conditionName,
    required String name,
    required List<Milestone> milestones,
    bool setCurrent = false,
  }) async {
    final now = DateTime.now();
    final id = _uuid.v4();
    final initialIsCurrent = setCurrent ? false : setCurrent;
    await _withConditionFallback(
      conditionId: conditionId,
      conditionName: conditionName,
      run: (dbConditionId) async {
        final encoded = _encodeMilestones(milestones, userId, dbConditionId);
        final insertData = {
          'id': id,
          'user_id': userId,
          'condition_id': dbConditionId,
          'name': name,
          // Insert as non-current first to avoid hitting the unique constraint when another
          // timeline is already current; we'll flip it on via setCurrentAndActivate below.
          'is_current': initialIsCurrent,
          'milestones': encoded,
          'created_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        };

        await _supabase.from('plan_timelines').insert(insertData);
      },
    );
    final timeline = PlanTimeline(
      id: id,
      userId: userId,
      conditionId: conditionId,
      name: name,
      isCurrent: setCurrent,
      milestones: milestones,
      createdAt: now,
      updatedAt: now,
    );

    if (setCurrent) {
      await setCurrentAndActivate(
        timeline: timeline,
        userId: userId,
        conditionId: conditionId,
        replaceActivePlan: false,
      );
    }

    return timeline;
  }

  Future<void> setCurrentAndActivate({
    required PlanTimeline timeline,
    required String userId,
    required String conditionId,
    bool replaceActivePlan = true,
  }) async {
    try {
      final normalizedId = _normalizeConditionId(conditionId);
      String? appliedConditionId;

      Future<bool> applyUpdate(String dbConditionId) async {
        await _supabase
            .from('plan_timelines')
            .update({'is_current': false})
            .eq('user_id', userId)
            .eq('condition_id', dbConditionId);

        final updated = await _supabase
            .from('plan_timelines')
            .update({
              'is_current': true,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', timeline.id)
            .eq('user_id', userId)
            .eq('condition_id', dbConditionId)
            .select('id');

        final success = updated.isNotEmpty;
        if (success) appliedConditionId = dbConditionId;
        return success;
      }

      bool applied = await _withConditionFallback(
        conditionId: conditionId,
        conditionName: conditionId,
        run: (dbConditionId) => applyUpdate(dbConditionId),
      );

      if (!applied && normalizedId != conditionId) {
        applied = await applyUpdate(normalizedId);
      }

      if (!applied) {
        await _ensureConditionRow(normalizedId, conditionName: conditionId);
        applied = await applyUpdate(normalizedId);
      }

      if (!applied) {
        throw PostgrestException(message: 'Timeline not found for condition', code: '0', details: null, hint: null);
      }

      if (replaceActivePlan) {
        final dbConditionId = appliedConditionId ?? normalizedId;
        final hydrated = timeline.milestones
            .map((m) => _withContext(m, userId: userId, conditionId: dbConditionId))
            .toList();

        await _milestoneService.replaceForCondition(
          userId: userId,
          conditionId: dbConditionId,
          items: hydrated,
        );
      }
    } catch (e) {
      debugPrint('PlanTimelineService.setCurrentAndActivate error: $e');
      rethrow;
    }
  }

  Future<void> deleteTimeline({
    required String timelineId,
    required String userId,
    required String conditionId,
  }) async {
    try {
      await _withConditionFallback(
        conditionId: conditionId,
        conditionName: conditionId,
        run: (dbConditionId) async {
          await _supabase
              .from('plan_timelines')
              .delete()
              .eq('id', timelineId)
              .eq('user_id', userId)
              .eq('condition_id', dbConditionId);
        },
      );
    } catch (e) {
      debugPrint('PlanTimelineService.deleteTimeline error: $e');
      rethrow;
    }
  }

  Future<void> updateSnapshot({
    required String timelineId,
    required String userId,
    required String conditionId,
    required List<Milestone> milestones,
  }) async {
    try {
      await _withConditionFallback(
        conditionId: conditionId,
        conditionName: conditionId,
        run: (dbConditionId) async {
          await _supabase
              .from('plan_timelines')
              .update({
                'milestones': _encodeMilestones(milestones, userId, dbConditionId),
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('id', timelineId)
              .eq('user_id', userId)
              .eq('condition_id', dbConditionId);
        },
      );
    } catch (e) {
      debugPrint('PlanTimelineService.updateSnapshot error: $e');
      rethrow;
    }
  }

  List<Map<String, dynamic>> _encodeMilestones(List<Milestone> items, String userId, String conditionId) {
    return items
        .map((m) => _withContext(m, userId: userId, conditionId: conditionId).toJson())
        .toList();
  }

  Milestone _withContext(Milestone m, {required String userId, required String conditionId}) {
    return Milestone(
      id: m.id,
      userId: userId,
      conditionId: conditionId,
      title: m.title,
      description: m.description,
      dueDate: m.dueDate,
      completed: m.completed,
      order: m.order,
      helpType: m.helpType,
      createdAt: m.createdAt,
      updatedAt: DateTime.now(),
    );
  }

  /// Get all timelines for a user across all conditions
  Future<List<PlanTimeline>> getTimelinesForUser(String userId) async {
    try {
      final data = await _supabase
          .from('plan_timelines')
          .select()
          .eq('user_id', userId)
          .order('is_current', ascending: false)
          .order('updated_at', ascending: false);

      final timelines = (data as List<dynamic>)
          .map((row) => PlanTimeline.fromJson({
                'id': row['id'],
                'user_id': row['user_id'],
                'condition_id': row['condition_id'],
                'name': row['name'],
                'is_current': row['is_current'],
                'milestones': row['milestones'],
                'created_at': row['created_at'],
                'updated_at': row['updated_at'],
              }))
          .toList();

      return timelines;
    } catch (e) {
      debugPrint('PlanTimelineService.getTimelinesForUser error: $e');
      return [];
    }
  }
}