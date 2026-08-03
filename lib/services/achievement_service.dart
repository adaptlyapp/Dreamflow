import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:wellspring/models/achievement.dart';
import 'package:wellspring/services/notification_service.dart';
import 'package:wellspring/supabase/supabase_config.dart';

class AchievementService {
  final SupabaseClient _supabase = SupabaseConfig.client;
  final _uuid = const Uuid();

  // Pre-defined achievements
  final List<Achievement> _baseAchievements = [
    // Health tracking achievements
    Achievement(
      id: 'first_entry',
      title: 'First Step',
      description: 'Log your first health entry',
      icon: 'edit_note',
      category: 'health',
      tier: 1,
      requirement: 1,
      createdAt: DateTime.now(),
    ),
    Achievement(
      id: 'tracker_week',
      title: 'Week Warrior',
      description: 'Log health entries for 7 days',
      icon: 'calendar_today',
      category: 'health',
      tier: 2,
      requirement: 7,
      createdAt: DateTime.now(),
    ),
    Achievement(
      id: 'tracker_month',
      title: 'Monthly Milestone',
      description: 'Log health entries for 30 days',
      icon: 'event',
      category: 'health',
      tier: 3,
      requirement: 30,
      createdAt: DateTime.now(),
    ),
    Achievement(
      id: 'tracker_streak_7',
      title: 'Consistency Champion',
      description: 'Log entries for 7 consecutive days',
      icon: 'local_fire_department',
      category: 'consistency',
      tier: 2,
      requirement: 7,
      createdAt: DateTime.now(),
    ),
    Achievement(
      id: 'tracker_streak_30',
      title: 'Unstoppable',
      description: 'Log entries for 30 consecutive days',
      icon: 'trending_up',
      category: 'consistency',
      tier: 4,
      requirement: 30,
      createdAt: DateTime.now(),
    ),
    // Social achievements
    Achievement(
      id: 'first_post',
      title: 'Voice Heard',
      description: 'Share your first community post',
      icon: 'chat_bubble',
      category: 'social',
      tier: 1,
      requirement: 1,
      createdAt: DateTime.now(),
    ),
    Achievement(
      id: 'social_butterfly',
      title: 'Social Butterfly',
      description: 'Create 10 community posts',
      icon: 'groups',
      category: 'social',
      tier: 2,
      requirement: 10,
      createdAt: DateTime.now(),
    ),
    Achievement(
      id: 'supporter',
      title: 'Supporter',
      description: 'Like 25 community posts',
      icon: 'favorite',
      category: 'social',
      tier: 2,
      requirement: 25,
      createdAt: DateTime.now(),
    ),
    Achievement(
      id: 'commenter',
      title: 'Conversationalist',
      description: 'Leave 20 helpful comments',
      icon: 'comment',
      category: 'social',
      tier: 2,
      requirement: 20,
      createdAt: DateTime.now(),
    ),
    // Goals achievements
    Achievement(
      id: 'first_goal',
      title: 'Goal Setter',
      description: 'Create your first goal',
      icon: 'flag',
      category: 'goals',
      tier: 1,
      requirement: 1,
      createdAt: DateTime.now(),
    ),
    Achievement(
      id: 'goal_complete',
      title: 'Achiever',
      description: 'Complete a goal',
      icon: 'check_circle',
      category: 'goals',
      tier: 2,
      requirement: 1,
      createdAt: DateTime.now(),
    ),
    Achievement(
      id: 'goal_master',
      title: 'Goal Master',
      description: 'Complete 10 goals',
      icon: 'emoji_events',
      category: 'goals',
      tier: 3,
      requirement: 10,
      createdAt: DateTime.now(),
    ),
    // Learning achievements
    Achievement(
      id: 'explorer',
      title: 'Explorer',
      description: 'View 5 educational resources',
      icon: 'explore',
      category: 'learning',
      tier: 1,
      requirement: 5,
      createdAt: DateTime.now(),
    ),
    Achievement(
      id: 'knowledge_seeker',
      title: 'Knowledge Seeker',
      description: 'View 25 educational resources',
      icon: 'school',
      category: 'learning',
      tier: 2,
      requirement: 25,
      createdAt: DateTime.now(),
    ),
    Achievement(
      id: 'researcher',
      title: 'Researcher',
      description: 'Conduct 10 further research searches',
      icon: 'search',
      category: 'learning',
      tier: 2,
      requirement: 10,
      createdAt: DateTime.now(),
    ),
    // Special milestones
    Achievement(
      id: 'one_month',
      title: 'First Month',
      description: 'Been with the community for 1 month',
      icon: 'cake',
      category: 'consistency',
      tier: 2,
      requirement: 30,
      createdAt: DateTime.now(),
    ),
    Achievement(
      id: 'six_months',
      title: 'Half Year Hero',
      description: 'Been with the community for 6 months',
      icon: 'celebration',
      category: 'consistency',
      tier: 3,
      requirement: 180,
      createdAt: DateTime.now(),
    ),
    Achievement(
      id: 'one_year',
      title: 'Anniversary',
      description: 'Been with the community for 1 year',
      icon: 'stars',
      category: 'consistency',
      tier: 4,
      requirement: 365,
      createdAt: DateTime.now(),
    ),
  ];

  /// Cleans up corrupt achievement records with invalid UUIDs
  /// This fixes records created before the UUID fix was implemented
  Future<void> cleanupCorruptRecords(String userId) async {
    try {
      debugPrint('Cleaning up corrupt achievement records for user: $userId');
      
      // Get all user achievements
      final data = await _supabase
          .from('user_achievements')
          .select()
          .eq('user_id', userId);
      
      // Find and delete records with invalid UUID format
      final validUuidPattern = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$');
      
      for (final record in data) {
        final id = record['id']?.toString() ?? '';
        if (!validUuidPattern.hasMatch(id.toLowerCase())) {
          debugPrint('Deleting corrupt record with id: $id');
          await _supabase
              .from('user_achievements')
              .delete()
              .eq('id', id);
        }
      }
      
      debugPrint('Cleanup complete');
    } catch (e) {
      debugPrint('AchievementService.cleanupCorruptRecords error: $e');
    }
  }

  Future<void> initializeAchievementsForUser(String userId) async {
    try {
      final now = DateTime.now();
      final userAchievements = _baseAchievements.map((achievement) => {
        'id': _uuid.v4(), // Generate UUID for id
        'user_id': userId,
        'achievement_id': achievement.id, // Store string identifier
        'progress': 0,
        'unlocked': false,
        'unlocked_at': null,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      }).toList();

      await _supabase.from('user_achievements').insert(userAchievements);
    } catch (e) {
      debugPrint('AchievementService.initializeAchievementsForUser error: $e');
    }
  }

  List<Achievement> getAllAchievements() => _baseAchievements;

  Achievement? getAchievementById(String id) {
    try {
      return _baseAchievements.firstWhere((a) => a.id == id);
    } catch (e) {
      return null;
    }
  }

  Stream<List<UserAchievement>> watchUserAchievements(String userId) {
    try {
      return _supabase
          .from('user_achievements')
          .stream(primaryKey: ['id'])
          .eq('user_id', userId)
          .map((data) => data
              .map((item) => UserAchievement.fromJson({
                'id': item['id'],
                'userId': item['user_id'],
                'achievementId': item['achievement_id'],
                'progress': item['progress'],
                'unlocked': item['unlocked'],
                'unlockedAt': item['unlocked_at'],
                'createdAt': item['created_at'],
                'updatedAt': item['updated_at'],
              }))
              .toList());
    } catch (e) {
      debugPrint('AchievementService.watchUserAchievements error: $e');
      return const Stream.empty();
    }
  }

  Future<List<UserAchievement>> getUserAchievements(String userId) async {
    try {
      final data = await _supabase
          .from('user_achievements')
          .select()
          .eq('user_id', userId);

      // If empty, initialize achievements
      if (data.isEmpty) {
        await initializeAchievementsForUser(userId);
        final retryData = await _supabase
            .from('user_achievements')
            .select()
            .eq('user_id', userId);
        return retryData
            .map((item) => UserAchievement.fromJson({
              'id': item['id'],
              'userId': item['user_id'],
              'achievementId': item['achievement_id'],
              'progress': item['progress'],
              'unlocked': item['unlocked'],
              'unlockedAt': item['unlocked_at'],
              'createdAt': item['created_at'],
              'updatedAt': item['updated_at'],
            }))
            .toList();
      }

      // Check for corrupt records and clean them up if found
      final validUuidPattern = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$');
      final hasCorruptRecords = data.any((record) {
        final id = record['id']?.toString() ?? '';
        return !validUuidPattern.hasMatch(id.toLowerCase());
      });

      if (hasCorruptRecords) {
        debugPrint('Detected corrupt achievement records, cleaning up...');
        await cleanupCorruptRecords(userId);
        await initializeAchievementsForUser(userId);
        
        // Fetch fresh data after cleanup
        final cleanData = await _supabase
            .from('user_achievements')
            .select()
            .eq('user_id', userId);
        
        return cleanData
            .map((item) => UserAchievement.fromJson({
              'id': item['id'],
              'userId': item['user_id'],
              'achievementId': item['achievement_id'],
              'progress': item['progress'],
              'unlocked': item['unlocked'],
              'unlockedAt': item['unlocked_at'],
              'createdAt': item['created_at'],
              'updatedAt': item['updated_at'],
            }))
            .toList();
      }

      return data
          .map((item) => UserAchievement.fromJson({
            'id': item['id'],
            'userId': item['user_id'],
            'achievementId': item['achievement_id'],
            'progress': item['progress'],
            'unlocked': item['unlocked'],
            'unlockedAt': item['unlocked_at'],
            'createdAt': item['created_at'],
            'updatedAt': item['updated_at'],
          }))
          .toList();
    } catch (e) {
      debugPrint('AchievementService.getUserAchievements error: $e');
      return [];
    }
  }

  Future<void> updateProgress(String userId, String achievementId, int progress) async {
    try {
      final data = await _supabase
          .from('user_achievements')
          .select()
          .eq('user_id', userId)
          .eq('achievement_id', achievementId)
          .maybeSingle();

      if (data == null) return;

      final userAchievement = UserAchievement.fromJson({
        'id': data['id'],
        'userId': data['user_id'],
        'achievementId': data['achievement_id'],
        'progress': data['progress'],
        'unlocked': data['unlocked'],
        'unlockedAt': data['unlocked_at'],
        'createdAt': data['created_at'],
        'updatedAt': data['updated_at'],
      });
      
      final achievement = getAchievementById(achievementId);
      if (achievement == null) return;

      final newProgress = progress.clamp(0, achievement.requirement);
      final shouldUnlock = newProgress >= achievement.requirement && !userAchievement.unlocked;

      final updateData = {
        'progress': newProgress,
        'unlocked': shouldUnlock ? true : userAchievement.unlocked,
        'unlocked_at': shouldUnlock ? DateTime.now().toIso8601String() : data['unlocked_at'],
        'updated_at': DateTime.now().toIso8601String(),
      };

      await _supabase
          .from('user_achievements')
          .update(updateData)
          .eq('user_id', userId)
          .eq('achievement_id', achievementId);
      
      // Send notification if achievement was just unlocked
      if (shouldUnlock) {
        try {
          await NotificationService.instance.notifyAchievementUnlocked(
            title: achievement.title,
            description: achievement.description,
          );
        } catch (e) {
          debugPrint('AchievementService.updateProgress: notification error: $e');
        }
      }
    } catch (e) {
      debugPrint('AchievementService.updateProgress error: $e');
    }
  }

  Future<void> incrementProgress(String userId, String achievementId, {int amount = 1}) async {
    try {
      // First check if user has any achievements initialized
      final allData = await _supabase
          .from('user_achievements')
          .select()
          .eq('user_id', userId);

      // If no achievements exist, initialize them first
      if (allData.isEmpty) {
        debugPrint('No achievements found, initializing for user: $userId');
        await initializeAchievementsForUser(userId);
      } else {
        // Check for corrupt records and clean them up if found
        final validUuidPattern = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$');
        final hasCorruptRecords = allData.any((record) {
          final id = record['id']?.toString() ?? '';
          return !validUuidPattern.hasMatch(id.toLowerCase());
        });

        if (hasCorruptRecords) {
          debugPrint('Detected corrupt achievement records in incrementProgress, cleaning up...');
          await cleanupCorruptRecords(userId);
          await initializeAchievementsForUser(userId);
        }
      }

      // Now fetch the specific achievement
      final data = await _supabase
          .from('user_achievements')
          .select()
          .eq('user_id', userId)
          .eq('achievement_id', achievementId)
          .maybeSingle();

      if (data == null) {
        debugPrint('Achievement not found: $achievementId for user: $userId');
        return;
      }

      final userAchievement = UserAchievement.fromJson({
        'id': data['id'],
        'userId': data['user_id'],
        'achievementId': data['achievement_id'],
        'progress': data['progress'],
        'unlocked': data['unlocked'],
        'unlockedAt': data['unlocked_at'],
        'createdAt': data['created_at'],
        'updatedAt': data['updated_at'],
      });
      
      final achievement = getAchievementById(achievementId);
      if (achievement == null) return;

      if (userAchievement.unlocked) return; // Already unlocked

      final newProgress = (userAchievement.progress + amount).clamp(0, achievement.requirement);
      final shouldUnlock = newProgress >= achievement.requirement;

      final updateData = {
        'progress': newProgress,
        'unlocked': shouldUnlock,
        'unlocked_at': shouldUnlock ? DateTime.now().toIso8601String() : data['unlocked_at'],
        'updated_at': DateTime.now().toIso8601String(),
      };

      await _supabase
          .from('user_achievements')
          .update(updateData)
          .eq('user_id', userId)
          .eq('achievement_id', achievementId);

      if (shouldUnlock) {
        debugPrint('Achievement unlocked! ${achievement.title}');
        
        // Send notification
        try {
          await NotificationService.instance.notifyAchievementUnlocked(
            title: achievement.title,
            description: achievement.description,
          );
        } catch (e) {
          debugPrint('AchievementService.incrementProgress: notification error: $e');
        }
      }
    } catch (e) {
      debugPrint('AchievementService.incrementProgress error: $e');
    }
  }

  Future<Map<String, dynamic>> getAchievementStats(String userId) async {
    try {
      final achievements = await getUserAchievements(userId);
      final unlocked = achievements.where((a) => a.unlocked).length;
      final total = achievements.length;
      
      // Calculate points (tier 1=10, tier 2=25, tier 3=50, tier 4=100)
      int totalPoints = 0;
      for (final ua in achievements.where((a) => a.unlocked)) {
        final achievement = getAchievementById(ua.achievementId);
        if (achievement != null) {
          switch (achievement.tier) {
            case 1:
              totalPoints += 10;
              break;
            case 2:
              totalPoints += 25;
              break;
            case 3:
              totalPoints += 50;
              break;
            case 4:
              totalPoints += 100;
              break;
          }
        }
      }

      return {
        'unlocked': unlocked,
        'total': total,
        'points': totalPoints,
        'percentage': total > 0 ? (unlocked / total * 100).round() : 0,
      };
    } catch (e) {
      debugPrint('AchievementService.getAchievementStats error: $e');
      return {'unlocked': 0, 'total': 0, 'points': 0, 'percentage': 0};
    }
  }

  Future<List<UserAchievement>> getRecentlyUnlocked(String userId, {int limit = 5}) async {
    try {
      final data = await _supabase
          .from('user_achievements')
          .select()
          .eq('user_id', userId)
          .eq('unlocked', true)
          .order('unlocked_at', ascending: false)
          .limit(limit);

      return data
          .map((item) => UserAchievement.fromJson({
            'id': item['id'],
            'userId': item['user_id'],
            'achievementId': item['achievement_id'],
            'progress': item['progress'],
            'unlocked': item['unlocked'],
            'unlockedAt': item['unlocked_at'],
            'createdAt': item['created_at'],
            'updatedAt': item['updated_at'],
          }))
          .toList();
    } catch (e) {
      debugPrint('AchievementService.getRecentlyUnlocked error: $e');
      return [];
    }
  }
}
