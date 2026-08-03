import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:wellspring/services/resource_service.dart';
import 'package:wellspring/supabase/supabase_config.dart';
class ResourceSuggestionService {
  final _supabase = SupabaseConfig.client;

  // Generates a simple random approval token for one-click moderation links
  String _generateToken() {
    const alphabet = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final r = Random.secure();
    final codeUnits = List.generate(24, (_) => alphabet.codeUnitAt(r.nextInt(alphabet.length)));
    return String.fromCharCodes(codeUnits);
  }

  /// Submits a resource suggestion by writing directly to Firestore.
  /// Then best-effort queues an email via the Trigger Email extension (mail collection).
  /// Returns the created suggestion document ID.
  Future<String> submitSuggestion(Map<String, dynamic> form) async {
    final user = SupabaseConfig.auth.currentUser;
    debugPrint('ResourceSuggestionService: submitSuggestion start, uid=${user?.id}, email=${user?.email}');

    final resourceName = (form['name'] ?? '').toString().trim();
    if (resourceName.isEmpty) {
      throw Exception('Resource name is required');
    }

    final type = (form['type'] ?? 'service').toString().trim();
    final addressLine = (form['address'] ?? '').toString().trim();
    final city = (form['city'] ?? '').toString().trim();
    final stateProvince = (form['state'] ?? '').toString().trim();
    final postalCode = (form['postalCode'] ?? '').toString().trim();
    final country = (form['country'] ?? '').toString().trim();
    final phone = (form['phone'] ?? '').toString().trim();
    final website = (form['website'] ?? '').toString().trim();
    final contactEmail = (form['contactEmail'] ?? '').toString().trim();
    final notes = (form['description'] ?? '').toString().trim();
    final lat = (form['lat'] is num) ? (form['lat'] as num).toDouble() : null;
    final lng = (form['lng'] is num) ? (form['lng'] as num).toDouble() : null;
    final specialties = (form['specialties'] as List<dynamic>? ?? []).map((e) => e.toString()).toList();

    // Build suggestion document
    final approvalToken = _generateToken();
    final suggestion = <String, dynamic>{
      'name': resourceName,
      'type': type,
      'address': addressLine,
      if (city.isNotEmpty) 'city': city,
      if (stateProvince.isNotEmpty) 'state': stateProvince,
      if (postalCode.isNotEmpty) 'postal_code': postalCode,
      if (country.isNotEmpty) 'country': country,
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
      if (phone.isNotEmpty) 'phone': phone,
      if (website.isNotEmpty) 'website': website,
      if (contactEmail.isNotEmpty) 'contact_email': contactEmail,
      if (notes.isNotEmpty) 'description': notes,
      if (specialties.isNotEmpty) 'specialties': specialties,
      'status': 'pending',
      'submitted_by_uid': user?.id,
      if (user?.email != null) 'submitted_by_email': user!.email,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
      // Token used by the approval page when coming from email (no sign-in required)
      'approval_token': approvalToken,
    };

    try {
      debugPrint('ResourceSuggestionService: writing suggestion directly to Supabase');
      final response = await _supabase
          .from('resource_suggestions')
          .insert(suggestion)
          .select()
          .single();
      final id = response['id'].toString();
      debugPrint('ResourceSuggestionService: suggestion written to Supabase, id=$id');
      debugPrint('ResourceSuggestionService: suggestion is now pending admin approval in the queue');

      return id;
    } catch (e, st) {
      debugPrint('ResourceSuggestionService: Firestore submit failed: $e\n$st');
      rethrow;
    }
  }

  /// Admin: Approve a suggestion and publish as curated resource in a batch.
  Future<void> approveSuggestionAndPublish(String suggestionId) async {
    try {
      final response = await _supabase
          .from('resource_suggestions')
          .select()
          .eq('id', suggestionId)
          .maybeSingle();
      if (response == null) throw Exception('Suggestion not found');
      final m = response;

      final name = (m['resourceName'] ?? m['name'] ?? '').toString();
      final type = (m['type'] ?? 'service').toString();
      final address = (m['addressLine'] ?? m['address'] ?? '').toString();
      final city = (m['city'] ?? '').toString();
      final state = (m['stateProvince'] ?? m['state'] ?? '').toString();
      final postal = (m['postal_code'] ?? m['postalCode'] ?? '').toString();
      final country = (m['country'] ?? '').toString();
      double? lat;
      double? lng;
      try {
        if (m['coordinates'] is Map) {
          final c = (m['coordinates'] as Map).cast<String, dynamic>();
          lat = (c['lat'] is num) ? (c['lat'] as num).toDouble() : null;
          lng = (c['lng'] is num) ? (c['lng'] as num).toDouble() : null;
        } else {
          lat = (m['lat'] is num) ? (m['lat'] as num).toDouble() : null;
          lng = (m['lng'] is num) ? (m['lng'] as num).toDouble() : null;
        }
      } catch (_) {}
      final phone = (m['phone'] ?? '').toString();
      final website = (m['website'] ?? '').toString();
      final contactEmail = (m['contact_email'] ?? m['contactEmail'] ?? '').toString();
      final specialties = (m['specialties'] as List<dynamic>? ?? []).map((e) => e.toString()).toList();

      // Geocode if missing lat/lng
      if (lat == null || lng == null) {
        try {
          final rs = ResourceService();
          final addrParts = [address, city, state, postal, country].where((e) => (e).toString().trim().isNotEmpty).join(', ');
          final geo = await rs.geocodeAddress(addrParts.isEmpty ? name : addrParts);
          if (geo != null) {
            lat = (geo['lat'] as num?)?.toDouble();
            lng = (geo['lng'] as num?)?.toDouble();
          }
        } catch (e) {
          debugPrint('ResourceSuggestionService: geocode on approve failed: $e');
        }
      }

      final curated = <String, dynamic>{
        'name': name,
        'type': type,
        'address': address,
        if (city.isNotEmpty) 'city': city,
        if (state.isNotEmpty) 'state': state,
        if (postal.isNotEmpty) 'postal_code': postal,
        if (country.isNotEmpty) 'country': country,
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
        if (phone.isNotEmpty) 'phone': phone,
        if (website.isNotEmpty) 'website': website,
        if (contactEmail.isNotEmpty) 'contact_email': contactEmail,
        if (specialties.isNotEmpty) 'specialties': specialties,
        'status': 'approved',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'source': 'suggestion',
        'source_id': suggestionId,
      };

      // Use RPC for atomic batch operation
      await _supabase.rpc('approve_suggestion_and_publish', 
          params: {
            'suggestion_id': suggestionId,
            'curated_resource': curated,
            'approved_by_uid': SupabaseConfig.auth.currentUser?.id,
          });
    } catch (e, st) {
      debugPrint('ResourceSuggestionService.approveSuggestionAndPublish failed: $e\n$st');
      rethrow;
    }
  }

  /// Admin: Reject a suggestion with status change only.
  Future<void> rejectSuggestion(String suggestionId, {String? reason}) async {
    try {
      final payload = <String, dynamic>{
        'status': 'rejected',
        'updated_at': DateTime.now().toIso8601String(),
        'rejected_at': DateTime.now().toIso8601String(),
        'rejected_by_uid': SupabaseConfig.auth.currentUser?.id,
      };
      if (reason != null && reason.trim().isNotEmpty) payload['rejected_reason'] = reason.trim();
      await _supabase
          .from('resource_suggestions')
          .update(payload)
          .eq('id', suggestionId);
    } catch (e, st) {
      debugPrint('ResourceSuggestionService.rejectSuggestion failed: $e\n$st');
      rethrow;
    }
  }

  /// Fetch recent suggestion notes authored by the current user for AI context.
  /// Returns a small list of {name, note, type} maps (most recent first).
  Future<List<Map<String, String>>> listMyRecentSuggestionNotes({int limit = 6}) async {
    try {
      final uid = SupabaseConfig.auth.currentUser?.id;
      if (uid == null) return [];
      // Sort by created_at desc
      final response = await _supabase
          .from('resource_suggestions')
          .select()
          .eq('submitted_by_uid', uid)
          .order('created_at', ascending: false)
          .limit(50); // small cap; we filter locally
      final list = <Map<String, String>>[];
      for (final row in response) {
        final m = row;
        final name = (m['name'] ?? m['resourceName'] ?? '').toString().trim();
        final type = (m['type'] ?? 'service').toString().trim();
        final note = (m['description'] ?? '').toString().trim();
        if (name.isEmpty || note.isEmpty) continue;
        final clipped = note.length > 240 ? note.substring(0, 240).trim() + '…' : note;
        list.add({'name': name, 'note': clipped, 'type': type});
        if (list.length >= limit) break;
      }
      return list;
    } catch (e, st) {
      debugPrint('ResourceSuggestionService.listMyRecentSuggestionNotes failed: $e\n$st');
      return [];
    }
  }
}

// Basic HTML escaper to avoid malformed email content
