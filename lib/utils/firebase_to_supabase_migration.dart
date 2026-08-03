import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:wellspring/supabase/supabase_config.dart';

/// One-time migration script to transfer all Firebase data to Supabase
/// 
/// Usage:
/// 1. Call FirebaseToSupabaseMigration.migrateAllData() from a button or screen
/// 2. Monitor progress in the Debug Console
/// 3. Verify data in Supabase dashboard after completion
class FirebaseToSupabaseMigration {
  static final _firestore = FirebaseFirestore.instance;
  static final _supabase = SupabaseConfig.client;

  /// Main migration function - migrates all collections in order
  static Future<void> migrateAllData() async {
    debugPrint('🚀 Starting Firebase to Supabase migration...');
    
    try {
      // Migrate in dependency order (parent tables before child tables)
      await _migrateUsers();
      await _migrateHospitals();
      await _migrateConditions();
      await _migratePosts();
      await _migrateComments();
      await _migrateGroups();
      await _migrateGroupMembers();
      await _migratePostLikes();
      await _migrateMessages();
      await _migrateGoals();
      await _migrateMilestones();
      await _migrateTrackerEntries();
      await _migrateAchievements();
      await _migrateUserAchievements();
      await _migrateResources();
      await _migrateResourceRatings();
      await _migrateResourceSuggestions();
      await _migrateResourceApplications();
      
      debugPrint('✅ Migration completed successfully!');
    } catch (e) {
      debugPrint('❌ Migration failed: $e');
      rethrow;
    }
  }

  /// Migrate users collection
  static Future<void> _migrateUsers() async {
    debugPrint('📦 Migrating users...');
    final snapshot = await _firestore.collection('users').get();
    
    if (snapshot.docs.isEmpty) {
      debugPrint('⚠️ No users to migrate');
      return;
    }

    final users = snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        'email': data['email'],
        'display_name': data['displayName'],
        'avatar_url': data['avatarUrl'],
        'phone_number': data['phoneNumber'],
        'bio': data['bio'],
        'location': data['location'],
        'is_anonymous': data['isAnonymous'] ?? false,
        'hospital_code': data['hospitalCode'],
        'date_of_birth': _parseTimestamp(data['dateOfBirth']),
        'medical_conditions': data['medicalConditions'] != null 
            ? List<String>.from(data['medicalConditions']) 
            : [],
        'allergies': data['allergies'] != null 
            ? List<String>.from(data['allergies']) 
            : [],
        'medications': data['medications'] != null 
            ? List<String>.from(data['medications']) 
            : [],
        'is_admin': data['isAdmin'] ?? false,
        'created_at': _parseTimestamp(data['createdAt']),
        'updated_at': _parseTimestamp(data['updatedAt']),
      };
    }).toList();

    await _batchInsert('users', users);
    debugPrint('✅ Migrated ${users.length} users');
  }

  /// Migrate hospitals collection
  static Future<void> _migrateHospitals() async {
    debugPrint('📦 Migrating hospitals...');
    final snapshot = await _firestore.collection('hospitals').get();
    
    if (snapshot.docs.isEmpty) {
      debugPrint('⚠️ No hospitals to migrate');
      return;
    }

    final hospitals = snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        'name': data['name'],
        'code': data['code'],
        'address': data['address'],
        'phone': data['phone'],
        'email': data['email'],
        'website': data['website'],
        'created_at': _parseTimestamp(data['createdAt']),
        'updated_at': _parseTimestamp(data['updatedAt']),
      };
    }).toList();

    await _batchInsert('hospitals', hospitals);
    debugPrint('✅ Migrated ${hospitals.length} hospitals');
  }

  /// Migrate conditions collection
  static Future<void> _migrateConditions() async {
    debugPrint('📦 Migrating conditions...');
    final snapshot = await _firestore.collection('conditions').get();
    
    if (snapshot.docs.isEmpty) {
      debugPrint('⚠️ No conditions to migrate');
      return;
    }

    final conditions = snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        'name': data['name'],
        'description': data['description'],
        'category': data['category'],
        'created_at': _parseTimestamp(data['createdAt']),
        'updated_at': _parseTimestamp(data['updatedAt']),
      };
    }).toList();

    await _batchInsert('conditions', conditions);
    debugPrint('✅ Migrated ${conditions.length} conditions');
  }

  /// Migrate posts collection
  static Future<void> _migratePosts() async {
    debugPrint('📦 Migrating posts...');
    final snapshot = await _firestore.collection('posts').get();
    
    if (snapshot.docs.isEmpty) {
      debugPrint('⚠️ No posts to migrate');
      return;
    }

    final posts = snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        'author_id': data['authorId'],
        'content': data['content'],
        'image_url': data['imageUrl'],
        'like_count': data['likeCount'] ?? 0,
        'comment_count': data['commentCount'] ?? 0,
        'is_anonymous': data['isAnonymous'] ?? false,
        'group_id': data['groupId'],
        'created_at': _parseTimestamp(data['createdAt']),
        'updated_at': _parseTimestamp(data['updatedAt']),
      };
    }).toList();

    await _batchInsert('posts', posts);
    debugPrint('✅ Migrated ${posts.length} posts');
  }

  /// Migrate comments collection
  static Future<void> _migrateComments() async {
    debugPrint('📦 Migrating comments...');
    final snapshot = await _firestore.collection('comments').get();
    
    if (snapshot.docs.isEmpty) {
      debugPrint('⚠️ No comments to migrate');
      return;
    }

    final comments = snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        'post_id': data['postId'],
        'author_id': data['authorId'],
        'content': data['content'],
        'is_anonymous': data['isAnonymous'] ?? false,
        'created_at': _parseTimestamp(data['createdAt']),
        'updated_at': _parseTimestamp(data['updatedAt']),
      };
    }).toList();

    await _batchInsert('comments', comments);
    debugPrint('✅ Migrated ${comments.length} comments');
  }

  /// Migrate groups collection
  static Future<void> _migrateGroups() async {
    debugPrint('📦 Migrating groups...');
    final snapshot = await _firestore.collection('groups').get();
    
    if (snapshot.docs.isEmpty) {
      debugPrint('⚠️ No groups to migrate');
      return;
    }

    final groups = snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        'name': data['name'],
        'description': data['description'],
        'image_url': data['imageUrl'],
        'creator_id': data['creatorId'],
        'member_count': data['memberCount'] ?? 0,
        'is_private': data['isPrivate'] ?? false,
        'created_at': _parseTimestamp(data['createdAt']),
        'updated_at': _parseTimestamp(data['updatedAt']),
      };
    }).toList();

    await _batchInsert('groups', groups);
    debugPrint('✅ Migrated ${groups.length} groups');
  }

  /// Migrate group_members collection
  static Future<void> _migrateGroupMembers() async {
    debugPrint('📦 Migrating group members...');
    final snapshot = await _firestore.collection('groupMembers').get();
    
    if (snapshot.docs.isEmpty) {
      debugPrint('⚠️ No group members to migrate');
      return;
    }

    final members = snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        'group_id': data['groupId'],
        'user_id': data['userId'],
        'role': data['role'] ?? 'member',
        'joined_at': _parseTimestamp(data['joinedAt']),
      };
    }).toList();

    await _batchInsert('group_members', members);
    debugPrint('✅ Migrated ${members.length} group members');
  }

  /// Migrate post_likes collection
  static Future<void> _migratePostLikes() async {
    debugPrint('📦 Migrating post likes...');
    final snapshot = await _firestore.collection('postLikes').get();
    
    if (snapshot.docs.isEmpty) {
      debugPrint('⚠️ No post likes to migrate');
      return;
    }

    final likes = snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        'post_id': data['postId'],
        'user_id': data['userId'],
        'created_at': _parseTimestamp(data['createdAt']),
      };
    }).toList();

    await _batchInsert('post_likes', likes);
    debugPrint('✅ Migrated ${likes.length} post likes');
  }

  /// Migrate messages collection
  static Future<void> _migrateMessages() async {
    debugPrint('📦 Migrating messages...');
    final snapshot = await _firestore.collection('messages').get();
    
    if (snapshot.docs.isEmpty) {
      debugPrint('⚠️ No messages to migrate');
      return;
    }

    final messages = snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        'sender_id': data['senderId'],
        'receiver_id': data['receiverId'],
        'content': data['content'],
        'is_read': data['isRead'] ?? false,
        'created_at': _parseTimestamp(data['createdAt']),
      };
    }).toList();

    await _batchInsert('messages', messages);
    debugPrint('✅ Migrated ${messages.length} messages');
  }

  /// Migrate goals collection
  static Future<void> _migrateGoals() async {
    debugPrint('📦 Migrating goals...');
    final snapshot = await _firestore.collection('goals').get();
    
    if (snapshot.docs.isEmpty) {
      debugPrint('⚠️ No goals to migrate');
      return;
    }

    final goals = snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        'user_id': data['userId'],
        'title': data['title'],
        'description': data['description'],
        'category': data['category'],
        'target_date': _parseTimestamp(data['targetDate']),
        'status': data['status'] ?? 'active',
        'progress': data['progress'] ?? 0,
        'created_at': _parseTimestamp(data['createdAt']),
        'updated_at': _parseTimestamp(data['updatedAt']),
      };
    }).toList();

    await _batchInsert('goals', goals);
    debugPrint('✅ Migrated ${goals.length} goals');
  }

  /// Migrate milestones collection
  static Future<void> _migrateMilestones() async {
    debugPrint('📦 Migrating milestones...');
    final snapshot = await _firestore.collection('milestones').get();
    
    if (snapshot.docs.isEmpty) {
      debugPrint('⚠️ No milestones to migrate');
      return;
    }

    final milestones = snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        'goal_id': data['goalId'],
        'title': data['title'],
        'description': data['description'],
        'target_date': _parseTimestamp(data['targetDate']),
        'is_completed': data['isCompleted'] ?? false,
        'completed_at': _parseTimestamp(data['completedAt']),
        'order_index': data['orderIndex'] ?? 0,
        'created_at': _parseTimestamp(data['createdAt']),
        'updated_at': _parseTimestamp(data['updatedAt']),
      };
    }).toList();

    await _batchInsert('milestones', milestones);
    debugPrint('✅ Migrated ${milestones.length} milestones');
  }

  /// Migrate tracker_entries collection
  static Future<void> _migrateTrackerEntries() async {
    debugPrint('📦 Migrating tracker entries...');
    final snapshot = await _firestore.collection('trackerEntries').get();
    
    if (snapshot.docs.isEmpty) {
      debugPrint('⚠️ No tracker entries to migrate');
      return;
    }

    final entries = snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        'user_id': data['userId'],
        'type': data['type'],
        'value': data['value'],
        'unit': data['unit'],
        'notes': data['notes'],
        'recorded_at': _parseTimestamp(data['recordedAt']),
        'created_at': _parseTimestamp(data['createdAt']),
        'updated_at': _parseTimestamp(data['updatedAt']),
      };
    }).toList();

    await _batchInsert('tracker_entries', entries);
    debugPrint('✅ Migrated ${entries.length} tracker entries');
  }

  /// Migrate achievements collection
  static Future<void> _migrateAchievements() async {
    debugPrint('📦 Migrating achievements...');
    final snapshot = await _firestore.collection('achievements').get();
    
    if (snapshot.docs.isEmpty) {
      debugPrint('⚠️ No achievements to migrate');
      return;
    }

    final achievements = snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        'title': data['title'],
        'description': data['description'],
        'icon': data['icon'],
        'category': data['category'],
        'points': data['points'] ?? 0,
        'created_at': _parseTimestamp(data['createdAt']),
        'updated_at': _parseTimestamp(data['updatedAt']),
      };
    }).toList();

    await _batchInsert('achievements', achievements);
    debugPrint('✅ Migrated ${achievements.length} achievements');
  }

  /// Migrate user_achievements collection
  static Future<void> _migrateUserAchievements() async {
    debugPrint('📦 Migrating user achievements...');
    final snapshot = await _firestore.collection('userAchievements').get();
    
    if (snapshot.docs.isEmpty) {
      debugPrint('⚠️ No user achievements to migrate');
      return;
    }

    final userAchievements = snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        'user_id': data['userId'],
        'achievement_id': data['achievementId'],
        'earned_at': _parseTimestamp(data['earnedAt']),
      };
    }).toList();

    await _batchInsert('user_achievements', userAchievements);
    debugPrint('✅ Migrated ${userAchievements.length} user achievements');
  }

  /// Migrate resources collection
  static Future<void> _migrateResources() async {
    debugPrint('📦 Migrating resources...');
    final snapshot = await _firestore.collection('resources').get();
    
    if (snapshot.docs.isEmpty) {
      debugPrint('⚠️ No resources to migrate');
      return;
    }

    final resources = snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        'title': data['title'],
        'description': data['description'],
        'category': data['category'],
        'type': data['type'],
        'url': data['url'],
        'phone': data['phone'],
        'email': data['email'],
        'address': data['address'],
        'hours': data['hours'],
        'services': data['services'] != null 
            ? List<String>.from(data['services']) 
            : [],
        'eligibility': data['eligibility'],
        'cost': data['cost'],
        'language_support': data['languageSupport'] != null 
            ? List<String>.from(data['languageSupport']) 
            : [],
        'accessibility': data['accessibility'],
        'image_url': data['imageUrl'],
        'is_approved': data['isApproved'] ?? false,
        'submitted_by': data['submittedBy'],
        'created_at': _parseTimestamp(data['createdAt']),
        'updated_at': _parseTimestamp(data['updatedAt']),
      };
    }).toList();

    await _batchInsert('resources', resources);
    debugPrint('✅ Migrated ${resources.length} resources');
  }

  /// Migrate resource_ratings collection
  static Future<void> _migrateResourceRatings() async {
    debugPrint('📦 Migrating resource ratings...');
    final snapshot = await _firestore.collection('resourceRatings').get();
    
    if (snapshot.docs.isEmpty) {
      debugPrint('⚠️ No resource ratings to migrate');
      return;
    }

    final ratings = snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        'resource_id': data['resourceId'],
        'user_id': data['userId'],
        'google_rating': data['googleRating'],
        'app_rating': data['appRating'],
        'review': data['review'],
        'created_at': _parseTimestamp(data['createdAt']),
        'updated_at': _parseTimestamp(data['updatedAt']),
      };
    }).toList();

    await _batchInsert('resource_ratings', ratings);
    debugPrint('✅ Migrated ${ratings.length} resource ratings');
  }

  /// Migrate resource_suggestions collection
  static Future<void> _migrateResourceSuggestions() async {
    debugPrint('📦 Migrating resource suggestions...');
    final snapshot = await _firestore.collection('resourceSuggestions').get();
    
    if (snapshot.docs.isEmpty) {
      debugPrint('⚠️ No resource suggestions to migrate');
      return;
    }

    final suggestions = snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        'user_id': data['userId'],
        'title': data['title'],
        'description': data['description'],
        'category': data['category'],
        'type': data['type'],
        'url': data['url'],
        'phone': data['phone'],
        'email': data['email'],
        'address': data['address'],
        'status': data['status'] ?? 'pending',
        'admin_notes': data['adminNotes'],
        'created_at': _parseTimestamp(data['createdAt']),
        'updated_at': _parseTimestamp(data['updatedAt']),
      };
    }).toList();

    await _batchInsert('resource_suggestions', suggestions);
    debugPrint('✅ Migrated ${suggestions.length} resource suggestions');
  }

  /// Migrate resource_applications collection
  static Future<void> _migrateResourceApplications() async {
    debugPrint('📦 Migrating resource applications...');
    final snapshot = await _firestore.collection('resourceApplications').get();
    
    if (snapshot.docs.isEmpty) {
      debugPrint('⚠️ No resource applications to migrate');
      return;
    }

    final applications = snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        'resource_id': data['resourceId'],
        'user_id': data['userId'],
        'status': data['status'] ?? 'pending',
        'application_data': data['applicationData'],
        'submitted_at': _parseTimestamp(data['submittedAt']),
        'updated_at': _parseTimestamp(data['updatedAt']),
      };
    }).toList();

    await _batchInsert('resource_applications', applications);
    debugPrint('✅ Migrated ${applications.length} resource applications');
  }

  /// Helper: Parse Firestore Timestamp to ISO8601 string
  static String? _parseTimestamp(dynamic timestamp) {
    if (timestamp == null) return null;
    if (timestamp is Timestamp) {
      return timestamp.toDate().toIso8601String();
    }
    if (timestamp is DateTime) {
      return timestamp.toIso8601String();
    }
    return null;
  }

  /// Helper: Batch insert data into Supabase (handles large datasets)
  static Future<void> _batchInsert(
    String table,
    List<Map<String, dynamic>> data,
  ) async {
    const batchSize = 100; // Supabase recommends batches of 100-1000 records
    
    for (int i = 0; i < data.length; i += batchSize) {
      final batch = data.skip(i).take(batchSize).toList();
      
      try {
        await _supabase.from(table).insert(batch);
        debugPrint('  ⏳ Inserted ${i + batch.length}/${data.length} records');
      } catch (e) {
        debugPrint('  ❌ Failed to insert batch at index $i: $e');
        
        // Try inserting records one by one to identify problematic records
        for (int j = 0; j < batch.length; j++) {
          try {
            await _supabase.from(table).insert(batch[j]);
          } catch (recordError) {
            debugPrint('    ⚠️ Failed record ${i + j}: ${batch[j]}');
            debugPrint('    Error: $recordError');
          }
        }
      }
    }
  }

  /// Optional: Clear all Supabase data before migration (use with caution!)
  static Future<void> clearSupabaseData() async {
    debugPrint('⚠️ WARNING: Clearing all Supabase data...');
    
    final tables = [
      'resource_applications',
      'resource_suggestions',
      'resource_ratings',
      'resources',
      'user_achievements',
      'achievements',
      'tracker_entries',
      'milestones',
      'goals',
      'messages',
      'post_likes',
      'group_members',
      'groups',
      'comments',
      'posts',
      'conditions',
      'hospitals',
      'users',
    ];

    for (final table in tables) {
      try {
        // Delete all records (requires appropriate RLS policies)
        await _supabase.from(table).delete().neq('id', '00000000-0000-0000-0000-000000000000');
        debugPrint('✅ Cleared $table');
      } catch (e) {
        debugPrint('❌ Failed to clear $table: $e');
      }
    }
  }
}
