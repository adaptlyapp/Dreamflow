import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:wellspring/models/resource_rating.dart';
import 'package:wellspring/supabase/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RatingsService {
  RatingsService();

  final _supabase = SupabaseConfig.client;

  // Local cache to avoid repeated reads per session
  static final Map<String, ResourceRatingSummary> _cache = {};

  Future<ResourceRatingSummary> getSummary(String resourceId) async {
    // Debug: surface auth context for read failures
    try {
      debugPrint('RatingsService.getSummary(signedIn=${SupabaseConfig.auth.currentUser != null}) for $resourceId');
    } catch (e) {
      debugPrint('RatingsService.getSummary: failed to read auth status: $e');
    }
    if (_cache.containsKey(resourceId)) return _cache[resourceId]!;
    try {
      final response = await _supabase
          .from('resource_ratings')
          .select()
          .eq('resource_id', resourceId)
          .maybeSingle();
      if (response != null) {
        final s = ResourceRatingSummary.fromSupabaseMap(response, resourceId);
        _cache[resourceId] = s;
        return s;
      }
    } catch (e) {
      debugPrint('RatingsService.getSummary error for $resourceId: $e');
    }
    final empty = ResourceRatingSummary.empty(resourceId);
    _cache[resourceId] = empty;
    return empty;
  }

  Future<Map<String, ResourceRatingSummary>> getSummariesBatch(List<String> resourceIds) async {
    // Debug: one-time auth info for batch reads
    try {
      debugPrint('RatingsService.getSummariesBatch(signedIn=${SupabaseConfig.auth.currentUser != null}) for ${resourceIds.length} ids');
    } catch (e) {
      debugPrint('RatingsService.getSummariesBatch: failed to read auth status: $e');
    }
    final Map<String, ResourceRatingSummary> out = {};
    final List<String> toFetch = [];
    for (final id in resourceIds) {
      if (_cache.containsKey(id)) {
        out[id] = _cache[id]!;
      } else {
        toFetch.add(id);
      }
    }
    try {
      final response = await _supabase
          .from('resource_ratings')
          .select()
          .inFilter('resource_id', toFetch);
      final Map<String, dynamic> found = {};
      for (final row in response) {
        found[row['resource_id']] = row;
      }
      for (final id in toFetch) {
        try {
          if (found.containsKey(id)) {
            final s = ResourceRatingSummary.fromSupabaseMap(found[id], id);
            _cache[id] = s;
            out[id] = s;
          } else {
            final empty = ResourceRatingSummary.empty(id);
            _cache[id] = empty;
            out[id] = empty;
          }
        } catch (e) {
          debugPrint('RatingsService.getSummariesBatch error for $id: $e');
          final empty = ResourceRatingSummary.empty(id);
          _cache[id] = empty;
          out[id] = empty;
        }
      }
    } catch (e) {
      debugPrint('RatingsService.getSummariesBatch batch error: $e');
      // Fall back to individual requests
      for (final id in toFetch) {
        final empty = ResourceRatingSummary.empty(id);
        _cache[id] = empty;
        out[id] = empty;
      }
    }
    return out;
  }

  /// If resource is a Google Place (id starts with 'gpl_'), refresh server-side rating when stale (>7 days).
  /// Requires a deployed edge function named 'fetch-google-place-rating'.
  Future<ResourceRatingSummary> ensureFreshGoogleSummary(String resourceId) async {
    try {
      if (!resourceId.startsWith('gpl_')) return getSummary(resourceId);
      final current = await getSummary(resourceId);
      final now = DateTime.now();
      final stale = current.updatedAt == null || now.difference(current.updatedAt!).inDays >= 7;
      if (!stale) return current;
      debugPrint('RatingsService.ensureFreshGoogleSummary: refreshing $resourceId via edge function');
      final placeId = resourceId.substring(4);
      final response = await _supabase.functions.invoke('fetch-google-place-rating', body: {'placeId': placeId});
      final data = Map<String, dynamic>.from(response.data as Map);
      // After function writes to Supabase, read back
      final refreshed = await _supabase
          .from('resource_ratings')
          .select()
          .eq('resource_id', resourceId)
          .maybeSingle();
      if (refreshed != null) {
        final s = ResourceRatingSummary.fromSupabaseMap(refreshed, resourceId);
        _cache[resourceId] = s;
        return s;
      }
      // If not found, build from response as a fallback
      final s = ResourceRatingSummary(
        resourceId: resourceId,
        avgGoogle: (data['avgGoogle'] is num) ? (data['avgGoogle'] as num).toDouble() : 0,
        countGoogle: (data['countGoogle'] is num) ? (data['countGoogle'] as num).toInt() : 0,
        avgApp: current.avgApp,
        countApp: current.countApp,
        avgCombined: (data['avgCombined'] is num) ? (data['avgCombined'] as num).toDouble() : current.avgCombined,
        countCombined: (data['countCombined'] is num) ? (data['countCombined'] as num).toInt() : current.countCombined,
        updatedAt: DateTime.now(),
      );
      _cache[resourceId] = s;
      return s;
    } catch (e, st) {
      debugPrint('RatingsService.ensureFreshGoogleSummary error for $resourceId: $e\n$st');
      return getSummary(resourceId);
    }
  }

  /// Submit or update a user's in-app review.
  /// Writes to resource_reviews table.
  /// Summary is recomputed server-side by a database trigger.
  Future<void> submitReview({
    required String resourceId,
    required int stars,
    String? comment,
    String? userDisplayName,
  }) async {
    final u = SupabaseConfig.auth.currentUser;
    if (u == null) throw Exception('Not signed in');
    if (stars < 1 || stars > 5) throw Exception('Invalid rating');

    // Create or update the review. CreatedAt is only set on first write.
    try {
      // Debug: log exact path and auth uid
      debugPrint('RatingsService.submitReview resourceId=$resourceId userId=${u.id}');
      
      final data = <String, dynamic>{
        'resource_id': resourceId,
        'user_id': u.id,
        if (userDisplayName != null && userDisplayName.trim().isNotEmpty) 'user_name': userDisplayName.trim(),
        'rating': stars,
        if (comment != null && comment.trim().isNotEmpty) 'comment': comment.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      };
      
      await _supabase
          .from('resource_reviews')
          .upsert(data);
    } catch (e, st) {
      debugPrint('RatingsService.submitReview write error for $resourceId: $e\n$st');
      rethrow;
    }

    // Let the database trigger recalculate the summary.
    // We optimistically keep cache stale; UI will refresh when summaries are next fetched.
  }
}
