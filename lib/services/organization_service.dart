import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wellspring/models/organization.dart';
import 'package:wellspring/supabase/supabase_config.dart';

class OrganizationService {
  final SupabaseClient _supabase = SupabaseConfig.client;

  /// Fetches all active organizations from Supabase, ordered by name
  Future<List<Organization>> getAllOrganizations() async {
    try {
      final data = await _supabase
          .from('organizations')
          .select()
          .eq('status', 'ACTIVE')
          .order('name');
      
      if (data.isNotEmpty) {
        return data.map((item) => Organization.fromJson(item)).toList();
      }
    } catch (e) {
      debugPrint('OrganizationService.getAllOrganizations error: $e');
    }
    return [];
  }

  /// Fetches a single organization by ID
  Future<Organization?> getOrganizationById(String id) async {
    try {
      final data = await _supabase
          .from('organizations')
          .select()
          .eq('id', id)
          .maybeSingle();
      
      if (data != null) return Organization.fromJson(data);
    } catch (e) {
      debugPrint('OrganizationService.getOrganizationById error: $e');
    }
    return null;
  }

  /// Searches organizations by name
  Future<List<Organization>> searchOrganizations(String query) async {
    if (query.trim().isEmpty) return getAllOrganizations();
    
    try {
      final data = await _supabase
          .from('organizations')
          .select()
          .eq('status', 'ACTIVE')
          .ilike('name', '%$query%')
          .order('name');
      
      if (data.isNotEmpty) {
        return data.map((item) => Organization.fromJson(item)).toList();
      }
    } catch (e) {
      debugPrint('OrganizationService.searchOrganizations error: $e');
    }
    return [];
  }
}
