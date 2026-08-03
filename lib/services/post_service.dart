import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wellspring/models/post.dart';
import 'package:wellspring/models/comment.dart';
import 'package:wellspring/services/user_service.dart';
import 'package:wellspring/services/achievement_service.dart';
import 'package:wellspring/services/notification_service.dart';
import 'package:wellspring/supabase/supabase_config.dart';

class PostService {
  final SupabaseClient _supabase = SupabaseConfig.client;
  final AchievementService _achievements = AchievementService();

  Future<void> addPost(Post post) async {
    try {
      final json = post.toJson();
      // Remove runtime-only fields that don't exist in the database
      json.remove('is_liked');
      debugPrint('PostService.addPost JSON: $json');
      await _supabase.from('posts').upsert(json);
      debugPrint('PostService.addPost: Post created successfully!');
      // Track achievement
      _trackPostAchievements(post.authorId);
    } catch (e) {
      debugPrint('PostService.addPost error: $e');
      rethrow;
    }
  }

  Future<void> _trackPostAchievements(String userId) async {
    try {
      final posts = await getUserPosts(userId);
      if (posts.length >= 1) {
        await _achievements.updateProgress(userId, 'first_post', 1);
      }
      if (posts.length >= 10) {
        await _achievements.updateProgress(userId, 'social_butterfly', posts.length);
      }
    } catch (e) {
      debugPrint('PostService._trackPostAchievements error: $e');
    }
  }

  Future<List<Post>> getPersonalizedFeed({List<String>? userConditions, String? typeFilter}) async {
    try {
      var query = _supabase.from('posts').select();

      if (userConditions != null && userConditions.isNotEmpty) {
        query = query.overlaps('related_conditions', userConditions);
      }

      if (typeFilter != null && typeFilter != 'all') {
        query = query.eq('type', typeFilter);
      }

      final data = await query.order('created_at', ascending: false).limit(50);
      final all = data.map((item) => Post.fromJson({...item, 'id': item['id']})).toList();
      // Privacy filter: hide posts from private users (except your own). Community-only requires sign-in.
      final me = _supabase.auth.currentUser;
      final myId = me?.id;
      final authorIds = all.map((p) => p.authorId).toSet().toList();
      final visMap = await UserService().getVisibilityForUserIds(authorIds);
      bool canSee(String authorId) {
        final v = visMap[authorId] ?? 'community';
        if (myId != null && authorId == myId) return true; // always see your own
        if (v == 'private') return false;
        if (v == 'community') return me != null; // require sign-in
        return true; // public
      }
      return all.where((p) => canSee(p.authorId)).toList();
    } catch (e) {
      debugPrint('PostService.getPersonalizedFeed error: $e');
      return [];
    }
  }

  Future<List<Post>> getCommunityPosts(String communityId) async {
    try {
      final data = await _supabase
          .from('posts')
          .select()
          .eq('community_id', communityId)
          .order('created_at', ascending: false)
          .limit(50);
      final all = data.map((item) => Post.fromJson({...item, 'id': item['id']})).toList();
      // Privacy filter: same rules as feed
      final me = _supabase.auth.currentUser;
      final myId = me?.id;
      final authorIds = all.map((p) => p.authorId).toSet().toList();
      final visMap = await UserService().getVisibilityForUserIds(authorIds);
      bool canSee(String authorId) {
        final v = visMap[authorId] ?? 'community';
        if (myId != null && authorId == myId) return true;
        if (v == 'private') return false;
        if (v == 'community') return me != null;
        return true;
      }
      return all.where((p) => canSee(p.authorId)).toList();
    } catch (e) {
      debugPrint('PostService.getCommunityPosts error: $e');
      return [];
    }
  }

  Future<List<Post>> getUserPosts(String userId) async {
    try {
      final data = await _supabase
          .from('posts')
          .select()
          .eq('author_id', userId)
          .order('created_at', ascending: false)
          .limit(100);
      return data
          .map((item) => Post.fromJson({...item, 'id': item['id']}))
          .toList();
    } catch (e) {
      debugPrint('PostService.getUserPosts error: $e');
      return [];
    }
  }

  Future<void> likePost(String postId) async {
    try {
      final me = _supabase.auth.currentUser;
      if (me == null) return;
      
      final data = await _supabase
          .from('posts')
          .select()
          .eq('id', postId)
          .maybeSingle();
      
      if (data != null) {
        final post = Post.fromJson({...data, 'id': data['id']});
        final isLiking = !post.isLiked;
        final updated = post.copyWith(
          isLiked: isLiking,
          likesCount: post.isLiked ? post.likesCount - 1 : post.likesCount + 1,
        );
        final json = updated.toJson();
        // Remove runtime-only fields that don't exist in the database
        json.remove('is_liked');
        await _supabase.from('posts').update(json).eq('id', postId);
        
        // Track like achievement when liking (not unliking)
        if (isLiking) {
          await _achievements.incrementProgress(me.id, 'supporter');
          
          // Notify post author (but not if they liked their own post)
          if (post.authorId != me.id) {
            try {
              final userData = await UserService().getUserById(me.id);
              await NotificationService.instance.notifyPostLiked(
                likerName: userData?.name ?? 'Someone',
                postTitle: post.content.length > 50 
                  ? '${post.content.substring(0, 50)}...' 
                  : post.content,
                postId: postId,
              );
            } catch (e) {
              debugPrint('PostService.likePost: notification error: $e');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('PostService.likePost error: $e');
      rethrow;
    }
  }

  Future<List<Comment>> getComments(String postId) async {
    try {
      final data = await _supabase
          .from('comments')
          .select()
          .eq('post_id', postId)
          .order('created_at', ascending: false);

      return data.map((item) => Comment.fromJson({...item, 'id': item['id']})).toList();
    } catch (e) {
      debugPrint('PostService.getComments error: $e');
      return [];
    }
  }

  Future<void> addComment(Comment comment) async {
    try {
      await _supabase.from('comments').upsert(comment.toJson()..['id'] = comment.id);

      // Update post comment count
      final postData = await _supabase
          .from('posts')
          .select('comments_count, author_id, content')
          .eq('id', comment.postId)
          .maybeSingle();
      
      if (postData != null) {
        final currentCount = (postData['comments_count'] as int?) ?? 0;
        await _supabase.from('posts').update({
          'comments_count': currentCount + 1
        }).eq('id', comment.postId);
        
        // Notify post author (but not if they commented on their own post)
        final postAuthorId = postData['author_id'] as String?;
        if (postAuthorId != null && postAuthorId != comment.authorId) {
          try {
            final postContent = postData['content'] as String? ?? 'your post';
            await NotificationService.instance.notifyPostCommented(
              commenterName: comment.authorName,
              postTitle: postContent.length > 50 
                ? '${postContent.substring(0, 50)}...' 
                : postContent,
              commentPreview: comment.content.length > 100 
                ? '${comment.content.substring(0, 100)}...' 
                : comment.content,
              postId: comment.postId,
            );
          } catch (e) {
            debugPrint('PostService.addComment: notification error: $e');
          }
        }
      }
      
      // Track comment achievement
      await _achievements.incrementProgress(comment.authorId, 'commenter');
    } catch (e) {
      debugPrint('PostService.addComment error: $e');
      rethrow;
    }
  }

  Future<void> deletePost(String postId) async {
    try {
      final me = _supabase.auth.currentUser;
      if (me == null) throw Exception('Not signed in');

      final postData = await _supabase
          .from('posts')
          .select()
          .eq('id', postId)
          .maybeSingle();
      
      if (postData == null) {
        debugPrint('PostService.deletePost: post $postId does not exist');
        return;
      }
      
      final authorId = postData['author_id'] as String?;
      if (authorId == null) throw Exception('Malformed post: missing authorId');
      if (authorId != me.id) throw Exception('Not authorized to delete this post');

      // Delete all comments for this post
      await _supabase
          .from('comments')
          .delete()
          .eq('post_id', postId);

      // Delete the post
      await _supabase
          .from('posts')
          .delete()
          .eq('id', postId);
      
      debugPrint('PostService.deletePost: deleted $postId and its comments');
    } catch (e) {
      debugPrint('PostService.deletePost error: $e');
      rethrow;
    }
  }
}
