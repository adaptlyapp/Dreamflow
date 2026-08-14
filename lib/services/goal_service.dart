import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wellspring/models/goal.dart';
import 'package:wellspring/services/achievement_service.dart';
import 'package:wellspring/services/notification_service.dart';
import 'package:wellspring/supabase/supabase_config.dart';

class GoalService {
  final SupabaseClient _supabase = SupabaseConfig.client;
  final AchievementService _achievements = AchievementService();

  /// Get all goals for a user (active and inactive)
  Future<List<Goal>> list({required String userId}) async {
    try {
      final data = await _supabase
          .from('goals')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return data.map((item) => Goal.fromJson({
        'id': item['id'],
        'userId': item['user_id'],
        'title': item['title'],
        'description': item['description'],
        'targetPerPeriod': item['target_per_period'],
        'progressThisPeriod': item['progress_this_period'],
        'period': item['period'],
        'active': item['active'],
        'linkedTrackerKey': item['linked_tracker_key'],
        'createdAt': item['created_at'],
        'updatedAt': item['updated_at'],
        'lastResetAt': item['last_reset_at'],
      })).toList();
    } catch (e) {
      debugPrint('GoalService.list error: $e');
      return [];
    }
  }

  /// Upsert (create or update) a goal
  Future<void> upsert(Goal goal) async {
    try {
      await _supabase.from('goals').upsert({
        'id': goal.id,
        'user_id': goal.userId,
        'title': goal.title,
        'description': goal.description,
        'target_per_period': goal.targetPerPeriod,
        'progress_this_period': goal.progressThisPeriod,
        'period': goal.period,
        'active': goal.active,
        'linked_tracker_key': goal.linkedTrackerKey,
        'created_at': goal.createdAt.toIso8601String(),
        'updated_at': goal.updatedAt.toIso8601String(),
        'last_reset_at': goal.lastResetAt?.toIso8601String(),
      });
    } catch (e) {
      debugPrint('GoalService.upsert error: $e');
      rethrow;
    }
  }

  Future<List<Goal>> getActiveGoals(String userId) async {
    try {
      final data = await _supabase
          .from('goals')
          .select()
          .eq('user_id', userId)
          .eq('active', true)
          .order('created_at', ascending: false)
          .limit(20);

      final goals = data.map((item) => Goal.fromJson({
        'id': item['id'],
        'userId': item['user_id'],
        'title': item['title'],
        'description': item['description'],
        'category': item['category'],
        'targetPerPeriod': item['target_per_period'],
        'progressThisPeriod': item['progress_this_period'],
        'period': item['period'],
        'active': item['active'],
        'createdAt': item['created_at'],
        'updatedAt': item['updated_at'],
        'lastResetAt': item['last_reset_at'],
      })).toList();

      final now = DateTime.now();
      bool hasChanges = false;
      final updatedGoals = <Goal>[];

      for (final goal in goals) {
        if (goal.period == 'weekly') {
          final last = goal.lastResetAt ?? goal.createdAt;
          if (now.difference(last).inDays >= 7) {
            hasChanges = true;
            final reset = goal.copyWith(progressThisPeriod: 0, lastResetAt: now);
            updatedGoals.add(reset);
            await _supabase.from('goals').update({
              'progress_this_period': 0,
              'last_reset_at': now.toIso8601String(),
              'updated_at': now.toIso8601String(),
            }).eq('id', goal.id);
          } else {
            updatedGoals.add(goal);
          }
        } else {
          updatedGoals.add(goal);
        }
      }

      // Compute relevance: lower completion percentage first, then most recently updated
      List<Goal> list = hasChanges ? updatedGoals : goals;
      list.sort((a, b) {
        double pctA = a.targetPerPeriod == 0 ? 1.0 : (a.progressThisPeriod / a.targetPerPeriod).clamp(0, 1).toDouble();
        double pctB = b.targetPerPeriod == 0 ? 1.0 : (b.progressThisPeriod / b.targetPerPeriod).clamp(0, 1).toDouble();
        final byPct = pctA.compareTo(pctB);
        if (byPct != 0) return byPct; // less complete first
        return b.updatedAt.compareTo(a.updatedAt); // recent activity next
      });
      return list.take(4).toList();
    } catch (e) {
      debugPrint('GoalService.getActiveGoals error: $e');
      return [];
    }
  }

  Future<void> incrementProgress(String goalId) async {
    try {
      final goalData = await _supabase
          .from('goals')
          .select()
          .eq('id', goalId)
          .maybeSingle();

      if (goalData != null) {
        final goal = Goal.fromJson({
          'id': goalData['id'],
          'userId': goalData['user_id'],
          'title': goalData['title'],
          'description': goalData['description'],
          'category': goalData['category'],
          'targetPerPeriod': goalData['target_per_period'],
          'progressThisPeriod': goalData['progress_this_period'],
          'period': goalData['period'],
          'active': goalData['active'],
          'createdAt': goalData['created_at'],
          'updatedAt': goalData['updated_at'],
          'lastResetAt': goalData['last_reset_at'],
        });
        
        final wasComplete = goal.progressThisPeriod >= goal.targetPerPeriod;
        final next = (goal.progressThisPeriod + 1).clamp(0, goal.targetPerPeriod);
        
        await _supabase.from('goals').update({
          'progress_this_period': next,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', goalId);
        
        // Track goal completion achievements (only increment when newly completed)
        if (!wasComplete && next >= goal.targetPerPeriod) {
          await _achievements.incrementProgress(goal.userId, 'goal_complete');
          await _achievements.incrementProgress(goal.userId, 'goal_master');
        }
      }
    } catch (e) {
      debugPrint('GoalService.incrementProgress error: $e');
      rethrow;
    }
  }

  Future<void> addGoal(Goal goal) async {
    try {
      await _supabase.from('goals').upsert({
        'id': goal.id,
        'user_id': goal.userId,
        'title': goal.title,
        'description': goal.description,
        'target_per_period': goal.targetPerPeriod,
        'progress_this_period': goal.progressThisPeriod,
        'period': goal.period,
        'active': goal.active,
        'created_at': goal.createdAt.toIso8601String(),
        'updated_at': goal.updatedAt.toIso8601String(),
        'last_reset_at': goal.lastResetAt?.toIso8601String(),
      });
      // Track first goal achievement
      await _achievements.incrementProgress(goal.userId, 'first_goal');
      // Schedule weekly reminder so users remember to log progress.
      try {
        await NotificationService.instance.scheduleGoal(goal);
      } catch (e) {
        debugPrint('GoalService.addGoal: schedule reminder error: $e');
      }
    } catch (e) {
      debugPrint('GoalService.addGoal error: $e');
      rethrow;
    }
  }

  Future<void> updateGoal(Goal goal) async {
    try {
      await _supabase.from('goals').update({
        'user_id': goal.userId,
        'title': goal.title,
        'description': goal.description,
        'target_per_period': goal.targetPerPeriod,
        'progress_this_period': goal.progressThisPeriod,
        'period': goal.period,
        'active': goal.active,
        'updated_at': goal.updatedAt.toIso8601String(),
        'last_reset_at': goal.lastResetAt?.toIso8601String(),
      }).eq('id', goal.id);
      // Refresh reminder so changes to active/title are reflected.
      try {
        if (goal.active) {
          await NotificationService.instance.scheduleGoal(goal);
        } else {
          await NotificationService.instance.cancelGoal(goal.id);
        }
      } catch (e) {
        debugPrint('GoalService.updateGoal: reschedule error: $e');
      }
    } catch (e) {
      debugPrint('GoalService.updateGoal error: $e');
      rethrow;
    }
  }

  Future<void> archiveGoal(String goalId) async {
    try {
      await _supabase.from('goals').update({
        'active': false,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', goalId);
      try {
        await NotificationService.instance.cancelGoal(goalId);
      } catch (e) {
        debugPrint('GoalService.archiveGoal: cancel reminder error: $e');
      }
    } catch (e) {
      debugPrint('GoalService.archiveGoal error: $e');
      rethrow;
    }
  }

  /// Permanently deletes a goal owned by [userId].
  ///
  /// This is a hard delete (not archival).
  ///
  /// Note: The app's `milestones` table is used for condition timelines and is
  /// keyed by `condition_id` (see [MilestoneService]). It is **not** related to
  /// goals, so we must not attempt to delete milestones by a `goal_id` column.
  Future<void> deleteGoalForever({required String goalId, required String userId}) async {
    try {
      // Delete the goal (scoped to owner).
      await _supabase.from('goals').delete().eq('id', goalId).eq('user_id', userId);
      try {
        await NotificationService.instance.cancelGoal(goalId);
      } catch (e) {
        debugPrint('GoalService.deleteGoalForever: cancel reminder error: $e');
      }
    } catch (e) {
      debugPrint('GoalService.deleteGoalForever error: $e');
      rethrow;
    }
  }
}
