import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:wellspring/models/milestone.dart';
import 'package:wellspring/services/notification_service.dart';
import 'package:wellspring/supabase/supabase_config.dart';

class MilestoneService {
  final SupabaseClient _supabase = SupabaseConfig.client;

  String _normalizeConditionId(String conditionId) {
    final uuidPattern = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
    if (uuidPattern.hasMatch(conditionId)) return conditionId;
    return const Uuid().v5(Uuid.NAMESPACE_URL, conditionId);
  }

  Future<List<Milestone>> list({required String userId, String? conditionId}) async {
    try {
      var query = _supabase.from('milestones').select().eq('user_id', userId);
      final normalized = conditionId != null ? _normalizeConditionId(conditionId) : null;

      if (conditionId != null) {
        query = query.eq('condition_id', conditionId);
      }

      List<dynamic> data = [];
      try {
        data = await query;
      } on PostgrestException catch (e) {
        if (e.code == '22P02' && normalized != null && normalized != conditionId) {
          data = await _supabase.from('milestones').select().eq('user_id', userId).eq('condition_id', normalized);
        } else {
          rethrow;
        }
      }

      if (data.isEmpty && normalized != null && normalized != conditionId) {
        try {
          data = await _supabase.from('milestones').select().eq('user_id', userId).eq('condition_id', normalized);
        } catch (_) {}
      }
      
      final list = data
          .map((item) => Milestone.fromJson({
                'id': item['id'],
                'userId': item['user_id'],
                'conditionId': conditionId ?? item['condition_id'],
                'title': item['title'],
                'description': item['description'],
                'order': item['order'],
                'dueDate': item['due_date'],
                'completed': item['completed'],
                'createdAt': item['created_at'],
                'updatedAt': item['updated_at'],
              }))
          .toList();
      
      // Secondary sort by order then dueDate (nulls last)
      list.sort((a, b) {
        final byOrder = (a.order).compareTo(b.order);
        if (byOrder != 0) return byOrder;
        final ad = a.dueDate?.millisecondsSinceEpoch ?? 1 << 62;
        final bd = b.dueDate?.millisecondsSinceEpoch ?? 1 << 62;
        return ad.compareTo(bd);
      });
      return list;
    } catch (e) {
      debugPrint('MilestoneService.list error: $e');
      return [];
    }
  }

  Future<Milestone?> getById({required String userId, required String id}) async {
    try {
      final data = await _supabase
          .from('milestones')
          .select()
          .eq('id', id)
          .eq('user_id', userId)
          .maybeSingle();
      
      if (data == null) return null;
      
      return Milestone.fromJson({
        'id': data['id'],
        'userId': data['user_id'],
        'conditionId': data['condition_id'],
        'title': data['title'],
        'description': data['description'],
        'order': data['order'],
        'dueDate': data['due_date'],
        'completed': data['completed'],
        'createdAt': data['created_at'],
        'updatedAt': data['updated_at'],
      });
    } catch (e) {
      debugPrint('MilestoneService.getById error: $e');
      return null;
    }
  }

  Future<void> upsert(Milestone m) async {
    try {
      await _supabase.from('milestones').upsert({
        'id': m.id,
        'user_id': m.userId,
        'condition_id': m.conditionId,
        'title': m.title,
        'description': m.description,
        'order': m.order,
        'due_date': m.dueDate?.toIso8601String(),
        'completed': m.completed,
        'created_at': m.createdAt.toIso8601String(),
        'updated_at': m.updatedAt.toIso8601String(),
      });
      // Schedule local reminder (lock screen) for due date.
      try {
        await NotificationService.instance.scheduleMilestone(m);
      } catch (e) {
        debugPrint('scheduleMilestone (upsert) error: $e');
      }
    } catch (e) {
      debugPrint('MilestoneService.upsert error: $e');
      rethrow;
    }
  }

  Future<void> updateFields(String userId, String id, Map<String, dynamic> fields) async {
    try {
      debugPrint('MilestoneService.updateFields: userId=$userId, id=$id, fields=$fields');
      // Convert field names to snake_case
      final updateData = <String, dynamic>{};
      for (final entry in fields.entries) {
        switch (entry.key) {
          case 'conditionId':
            updateData['condition_id'] = entry.value;
            break;
          case 'dueDate':
            updateData['due_date'] = entry.value;
            break;
          case 'completedAt':
            updateData['completed_at'] = entry.value;
            break;
          case 'createdAt':
            updateData['created_at'] = entry.value;
            break;
          case 'updatedAt':
            updateData['updated_at'] = entry.value;
            break;
          default:
            updateData[entry.key] = entry.value;
        }
      }
      updateData['updated_at'] = DateTime.now().toIso8601String();
      debugPrint('MilestoneService.updateFields: updateData=$updateData');
      
      await _supabase
          .from('milestones')
          .update(updateData)
          .eq('id', id)
          .eq('user_id', userId);
      debugPrint('MilestoneService.updateFields: Update successful');
      // Re-sync notification for this milestone (handles completion + due date changes).
      try {
        final updated = await getById(userId: userId, id: id);
        if (updated != null) {
          await NotificationService.instance.scheduleMilestone(updated);
        }
      } catch (e) {
        debugPrint('milestone reminder resync error: $e');
      }
    } catch (e) {
      debugPrint('MilestoneService.updateFields error: $e');
      rethrow;
    }
  }

  Future<void> delete(String userId, String id) async {
    try {
      await _supabase
          .from('milestones')
          .delete()
          .eq('id', id)
          .eq('user_id', userId);
      try {
        await NotificationService.instance.cancelMilestone(id);
      } catch (e) {
        debugPrint('cancelMilestone (delete) error: $e');
      }
    } catch (e) {
      debugPrint('MilestoneService.delete error: $e');
      rethrow;
    }
  }

  /// Replace all milestones for a given user + condition with the provided list.
  /// This deletes existing ones and inserts new ones.
  Future<void> replaceForCondition({
    required String userId,
    required String conditionId,
    required List<Milestone> items,
  }) async {
    try {
      final dbConditionId = _normalizeConditionId(conditionId);
      // Delete existing milestones for this user/condition
      await _supabase
          .from('milestones')
          .delete()
          .eq('user_id', userId)
          .eq('condition_id', dbConditionId);

      if (dbConditionId != conditionId) {
        try {
          await _supabase
              .from('milestones')
              .delete()
              .eq('user_id', userId)
              .eq('condition_id', conditionId);
        } catch (_) {}
      }

      // Insert new milestones
      if (items.isNotEmpty) {
        final insertData = items.map((m) => {
          'id': m.id,
          'user_id': m.userId,
          'condition_id': dbConditionId,
          'title': m.title,
          'description': m.description,
          'order': m.order,
          'due_date': m.dueDate?.toIso8601String(),
          'completed': m.completed,
          'created_at': m.createdAt.toIso8601String(),
          'updated_at': m.updatedAt.toIso8601String(),
        }).toList();
        
        await _supabase.from('milestones').insert(insertData);
      }
      try {
        await NotificationService.instance.syncMilestones(items);
      } catch (e) {
        debugPrint('syncMilestones (replaceForCondition) error: $e');
      }
    } catch (e) {
      debugPrint('MilestoneService.replaceForCondition error: $e');
      rethrow;
    }
  }
}
