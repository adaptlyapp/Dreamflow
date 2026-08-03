import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wellspring/models/group.dart';
import 'package:wellspring/supabase/supabase_config.dart';

class GroupService {
  final SupabaseClient _supabase = SupabaseConfig.client;

  // Legacy keys for local sample data migration
  static const String _groupsKey = 'groups_data';

  Future<void> _seedCommunitiesIfEmpty() async {
    try {
      final data = await _supabase.from('communities').select('id').limit(1);
      if (data.isNotEmpty) return;
      // Seed from legacy local data if present, otherwise use a small default set
      final prefs = await SharedPreferences.getInstance();
      final localData = prefs.getString(_groupsKey);
      final now = DateTime.now();
      final List<Group> seeds;
      if (localData != null) {
        final List<dynamic> decoded = jsonDecode(localData);
        seeds = decoded.map((j) => Group.fromJson(j)).toList();
      } else {
        seeds = [
          Group(id: 'seed-ms', name: 'MS Warriors', description: 'Support and experiences around Multiple Sclerosis.', type: 'condition', relatedCondition: '1', memberCount: 0, privacy: 'open', ownerId: 'system', ownerName: 'System', createdAt: now, updatedAt: now),
          Group(id: 'seed-fibro', name: 'Fibromyalgia Support Circle', description: 'Share pain management strategies and emotional support.', type: 'condition', relatedCondition: '2', memberCount: 0, privacy: 'open', ownerId: 'system', ownerName: 'System', createdAt: now, updatedAt: now),
          Group(id: 'seed-fitness', name: 'Adaptive Fitness Enthusiasts', description: 'Adaptive exercises and fitness goals regardless of ability.', type: 'interest', relatedCondition: null, memberCount: 0, privacy: 'open', ownerId: 'system', ownerName: 'System', createdAt: now, updatedAt: now),
        ];
      }
      final insertData = seeds.map((g) => {
        'id': g.id,
        'name': g.name,
        'description': g.description,
        'image_url': g.imageUrl,
        'type': g.type,
        'related_condition': g.relatedCondition,
        'member_count': 0,
        'privacy': g.privacy,
        'owner_id': g.ownerId ?? 'system',
        'owner_name': g.ownerName ?? 'System',
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      }).toList();
      await _supabase.from('communities').insert(insertData);
    } catch (e) {
      debugPrint('GroupService._seedCommunitiesIfEmpty error: $e');
    }
  }

  Future<List<Group>> getAllGroups() async {
    // Note: Seeding default communities from the client caused Firestore permission errors
    // under locked-down rules. We disable auto-seeding to avoid noisy failures.
    try {
      final uid = _supabase.auth.currentUser?.id;
      final data = await _supabase.from('communities').select().order('member_count', ascending: false).limit(100);
      final groups = data.map((d) => Group.fromJson({...d, 'id': d['id']})).toList();
      if (uid == null) return groups;

      // Fetch memberships for this user across communities (approved and pending)
      final membershipByCommunity = <String, String>{};
      try {
        final memberData = await _supabase
            .from('community_members')
            .select()
            .eq('user_id', uid)
            .limit(200);
        for (final member in memberData) {
          final communityId = member['community_id'] as String?;
          if (communityId != null) {
            membershipByCommunity[communityId] =
                (member['status'] as String? ?? 'approved');
          }
        }
      } catch (e) {
        debugPrint('GroupService.getAllGroups membership query error: $e');
      }

      return groups.map((g) {
        // Owners are implicitly joined even if the members subcollection write/read is blocked
        final isOwner = (uid != null && uid.isNotEmpty) && (g.ownerId == uid);
        final status = membershipByCommunity[g.id];
        final resolvedStatus = isOwner ? 'approved' : status;
        return g.copyWith(
          isJoined: resolvedStatus == 'approved',
          membershipStatus: resolvedStatus,
        );
      }).toList();
    } catch (e) {
      debugPrint('GroupService.getAllGroups error: $e');
      return [];
    }
  }

  Future<Group?> getGroupById(String id) async {
    try {
      final data = await _supabase.from('communities').select().eq('id', id).maybeSingle();
      if (data == null) return null;
      final uid = _supabase.auth.currentUser?.id;
      final base = Group.fromJson({...data, 'id': data['id']});
      if (uid == null) return base;
      // If current user is the owner, treat as joined even if members doc is missing
      if ((base.ownerId ?? '') == uid) {
        return base.copyWith(isJoined: true, membershipStatus: 'approved');
      }
      final memberData = await _supabase
          .from('community_members')
          .select()
          .eq('community_id', id)
          .eq('user_id', uid)
          .maybeSingle();
      if (memberData != null) {
        final status = memberData['status'] as String?;
        return base.copyWith(isJoined: status == 'approved', membershipStatus: status);
      }
      return base;
    } catch (e) {
      debugPrint('GroupService.getGroupById error: $e');
      return null;
    }
  }

  Future<List<Group>> getJoinedGroups() async {
    try {
      final uid = _supabase.auth.currentUser?.id;
      if (uid == null) return [];
      final memberData = await _supabase
          .from('community_members')
          .select('community_id')
          .eq('user_id', uid)
          .eq('status', 'approved');
      final ids = memberData.map((d) => d['community_id'] as String).toList();
      if (ids.isEmpty) return [];
      final communitiesData = await _supabase
          .from('communities')
          .select()
          .inFilter('id', ids);
      return communitiesData.map((d) => Group.fromJson({...d, 'id': d['id']}).copyWith(isJoined: true, membershipStatus: 'approved')).toList();
    } catch (e) {
      debugPrint('GroupService.getJoinedGroups error: $e');
      return [];
    }
  }

  Future<List<Group>> getGroupsByCondition(String conditionId) async {
    try {
      final uid = _supabase.auth.currentUser?.id;
      final data = await _supabase.from('communities')
          .select()
          .eq('related_condition', conditionId)
          .order('member_count', ascending: false)
          .limit(100);
      final groups = data.map((d) => Group.fromJson({...d, 'id': d['id']})).toList();
      if (uid == null) return groups;
      final membership = <String, String>{};
      try {
        final memberData = await _supabase
            .from('community_members')
            .select('community_id, status')
            .eq('user_id', uid);
        for (final m in memberData) {
          final gid = m['community_id'] as String?;
          if (gid != null) {
            membership[gid] = (m['status'] as String? ?? 'approved');
          }
        }
      } catch (e) {
        debugPrint('GroupService.getGroupsByCondition membership error: $e');
      }
      return groups.map((g) {
        final s = membership[g.id];
        return g.copyWith(isJoined: s == 'approved', membershipStatus: s);
      }).toList();
    } catch (e) {
      debugPrint('GroupService.getGroupsByCondition error: $e');
      return [];
    }
  }

  Future<String> joinGroup(String groupId) async {
    // Returns status: 'approved' or 'pending'
    try {
      final uid = _supabase.auth.currentUser?.id;
      final displayName = _supabase.auth.currentUser?.userMetadata?['display_name'] ?? 'Member';
      if (uid == null) {
        throw Exception('Not signed in');
      }
      final communityData = await _supabase.from('communities').select().eq('id', groupId).maybeSingle();
      if (communityData == null) throw Exception('Community not found');
      final privacy = (communityData['privacy'] as String?) ?? 'open';
      
      final existingMember = await _supabase
          .from('community_members')
          .select()
          .eq('community_id', groupId)
          .eq('user_id', uid)
          .maybeSingle();
      
      String status = privacy == 'private' ? 'pending' : 'approved';
      final memberData = {
        'community_id': groupId,
        'user_id': uid,
        'role': existingMember?['role'] ?? 'member',
        'status': status,
        'display_name': displayName,
        'joined_at': DateTime.now().toIso8601String(),
      };
      
      await _supabase.from('community_members').upsert(memberData);
      
      if (status == 'approved' && !(existingMember != null && existingMember['status'] == 'approved')) {
        final currentCount = (communityData['member_count'] as int?) ?? 0;
        await _supabase.from('communities').update({
          'member_count': currentCount + 1
        }).eq('id', groupId);
      }
      return status;
    } catch (e) {
      debugPrint('GroupService.joinGroup error: $e');
      rethrow;
    }
  }

  Future<void> leaveGroup(String groupId) async {
    try {
      final uid = _supabase.auth.currentUser?.id;
      if (uid == null) return;
      
      // Prevent the owner from leaving their own community
      final communityData = await _supabase.from('communities').select().eq('id', groupId).maybeSingle();
      if (communityData != null) {
        final ownerId = communityData['owner_id'] as String?;
        if (ownerId != null && ownerId == uid) {
          throw Exception('Owners cannot leave their own community');
        }
      }
      
      final memberData = await _supabase
          .from('community_members')
          .select()
          .eq('community_id', groupId)
          .eq('user_id', uid)
          .maybeSingle();
      
      if (memberData == null) return;
      final wasApproved = memberData['status'] == 'approved';
      
      await _supabase
          .from('community_members')
          .delete()
          .eq('community_id', groupId)
          .eq('user_id', uid);
      
      if (wasApproved && communityData != null) {
        final currentCount = (communityData['member_count'] as int?) ?? 0;
        await _supabase.from('communities').update({
          'member_count': (currentCount - 1).clamp(0, double.infinity).toInt()
        }).eq('id', groupId);
      }
    } catch (e) {
      debugPrint('GroupService.leaveGroup error: $e');
      // Bubble up so UI can show an error (e.g., owners trying to leave)
      rethrow;
    }
  }

  Future<Group> createGroup({
    required String name,
    required String description,
    required String type, // 'condition' | 'interest'
    String? relatedCondition,
    String privacy = 'open',
  }) async {
    try {
      final uid = _supabase.auth.currentUser?.id;
      final ownerName = _supabase.auth.currentUser?.userMetadata?['display_name'] ?? 'Owner';
      if (uid == null) throw Exception('Not signed in');
      
      final now = DateTime.now().toIso8601String();
      final communityData = {
        'name': name,
        'description': description,
        'image_url': null,
        'type': type,
        'related_condition': relatedCondition,
        'member_count': 1,
        'privacy': privacy,
        'owner_id': uid,
        'owner_name': ownerName,
        'created_at': now,
        'updated_at': now,
      };
      
      final result = await _supabase.from('communities').insert(communityData).select().single();
      final createdId = result['id'] as String;
      
      // Add owner as approved member with role 'owner'
      try {
        await _supabase.from('community_members').insert({
          'community_id': createdId,
          'user_id': uid,
          'role': 'owner',
          'status': 'approved',
          'display_name': ownerName,
          'joined_at': now,
        });
      } catch (e) {
        // Don't fail the entire creation if membership write is blocked by rules
        debugPrint('GroupService.createGroup member write skipped due to error: $e');
      }
      
      return Group.fromJson({...result, 'id': createdId}).copyWith(isJoined: true, membershipStatus: 'approved');
    } catch (e) {
      debugPrint('GroupService.createGroup error: $e');
      rethrow;
    }
  }

  Future<void> deleteGroup(String groupId) async {
    // Only the owner can delete. Attempts to cascade delete members, posts, and comments.
    // This is best-effort: if some reads are blocked by rules, we still try to delete what we can.
    try {
      final uid = _supabase.auth.currentUser?.id;
      if (uid == null) {
        throw Exception('Not signed in');
      }
      
      final communityData = await _supabase.from('communities').select().eq('id', groupId).maybeSingle();
      if (communityData == null) {
        throw Exception('Community not found');
      }
      final ownerId = communityData['owner_id'] as String?;
      if (ownerId == null || ownerId != uid) {
        throw Exception('Only the owner can delete this community');
      }

      // 1) Delete members
      try {
        await _supabase
            .from('community_members')
            .delete()
            .eq('community_id', groupId);
      } catch (e) {
        debugPrint('GroupService.deleteGroup members cleanup error: $e');
        // continue
      }

      // 2) Delete posts under this community and their comments
      try {
        // Get all posts for this community
        final postsData = await _supabase
            .from('posts')
            .select('id')
            .eq('community_id', groupId);
        
        final postIds = postsData.map((p) => p['id'] as String).toList();
        
        // Delete comments for all posts
        if (postIds.isNotEmpty) {
          await _supabase
              .from('comments')
              .delete()
              .inFilter('post_id', postIds);
        }
        
        // Delete all posts
        await _supabase
            .from('posts')
            .delete()
            .eq('community_id', groupId);
      } catch (e) {
        debugPrint('GroupService.deleteGroup posts cleanup error: $e');
        // continue
      }

      // 3) Finally delete the community document
      await _supabase
          .from('communities')
          .delete()
          .eq('id', groupId);
    } catch (e) {
      debugPrint('GroupService.deleteGroup error: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getPendingRequests(String groupId) async {
    try {
      final data = await _supabase
          .from('community_members')
          .select()
          .eq('community_id', groupId)
          .eq('status', 'pending')
          .limit(50);
      return data.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('GroupService.getPendingRequests error: $e');
      return [];
    }
  }

  Future<void> approveMember(String groupId, String userId) async {
    try {
      final memberData = await _supabase
          .from('community_members')
          .select('status')
          .eq('community_id', groupId)
          .eq('user_id', userId)
          .maybeSingle();
      
      if (memberData == null) return;
      final wasApproved = memberData['status'] == 'approved';
      
      await _supabase
          .from('community_members')
          .update({'status': 'approved'})
          .eq('community_id', groupId)
          .eq('user_id', userId);
      
      if (!wasApproved) {
        final communityData = await _supabase.from('communities').select('member_count').eq('id', groupId).maybeSingle();
        if (communityData != null) {
          final currentCount = (communityData['member_count'] as int?) ?? 0;
          await _supabase.from('communities').update({
            'member_count': currentCount + 1
          }).eq('id', groupId);
        }
      }
    } catch (e) {
      debugPrint('GroupService.approveMember error: $e');
      rethrow;
    }
  }

  Future<void> rejectMember(String groupId, String userId) async {
    try {
      await _supabase
          .from('community_members')
          .delete()
          .eq('community_id', groupId)
          .eq('user_id', userId);
    } catch (e) {
      debugPrint('GroupService.rejectMember error: $e');
      rethrow;
    }
  }
}
