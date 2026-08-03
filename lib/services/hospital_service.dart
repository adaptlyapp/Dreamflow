import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wellspring/models/hospital.dart';
import 'package:wellspring/supabase/supabase_config.dart';

class HospitalService {
  final SupabaseClient _supabase = SupabaseConfig.client;

  Future<List<Hospital>> getHospitalsByMetro(String metroKey) async {
    try {
      final data = await _supabase
          .from('hospitals')
          .select()
          .eq('metro', metroKey)
          .order('name');
      
      if (data.isNotEmpty) {
        return data.map((item) => Hospital.fromJson(item, item['id'])).toList();
      }
    } catch (e) {
      debugPrint('HospitalService.getHospitalsByMetro Supabase error: $e');
    }
    // Fallback to built-in list if Supabase is empty or unavailable
    if (metroKey == 'stl') return _stLouisDefaults;
    return [];
  }

  Future<Hospital?> getHospitalById(String id) async {
    // Check fallback list first (handles both old string IDs and offline mode)
    final localMatch = _stLouisDefaults.firstWhere(
      (h) => h.id == id,
      orElse: () => const Hospital(id: '', name: ''),
    );
    if (localMatch.id.isNotEmpty) return localMatch;

    // Only query Supabase if ID looks like a UUID
    if (!_isValidUuid(id)) {
      debugPrint('HospitalService.getHospitalById: Invalid UUID "$id", skipping Supabase query');
      return null;
    }

    try {
      final data = await _supabase
          .from('hospitals')
          .select()
          .eq('id', id)
          .maybeSingle();
      
      if (data != null) return Hospital.fromJson(data, data['id']);
    } catch (e) {
      debugPrint('HospitalService.getHospitalById error: $e');
    }
    return null;
  }

  bool _isValidUuid(String id) {
    final uuidPattern = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false,
    );
    return uuidPattern.hasMatch(id);
  }

  // Built-in St. Louis area hospitals with tasteful brand colors
  List<Hospital> get _stLouisDefaults => const [
        Hospital(
          id: 'bjc_barnes_jewish',
          name: 'Barnes-Jewish Hospital',
          city: 'St. Louis',
          metro: 'stl',
          brandPrimary: Color(0xFF003B5C), // Deep blue
          brandSecondary: Color(0xFF0072CE), // Accent blue
          brandTertiary: Color(0xFF00A3E0), // Light blue
        ),
        Hospital(
          id: 'stl_childrens',
          name: "St. Louis Children's Hospital",
          city: 'St. Louis',
          metro: 'stl',
          brandPrimary: Color(0xFF004B87),
          brandSecondary: Color(0xFF009FDA),
          brandTertiary: Color(0xFF7FC6E8),
        ),
        Hospital(
          id: 'mo_baptist',
          name: 'Missouri Baptist Medical Center',
          city: 'Town and Country',
          metro: 'stl',
          brandPrimary: Color(0xFF003B5C),
          brandSecondary: Color(0xFF6AA2B8),
          brandTertiary: Color(0xFFBCD9EA),
        ),
        Hospital(
          id: 'christian_hospital',
          name: 'Christian Hospital',
          city: 'St. Louis',
          metro: 'stl',
          brandPrimary: Color(0xFF0E4A7E),
          brandSecondary: Color(0xFF0FA3B1),
          brandTertiary: Color(0xFFB8E1F9),
        ),
        Hospital(
          id: 'mercy_stl',
          name: 'Mercy Hospital St. Louis',
          city: 'Creve Coeur',
          metro: 'stl',
          brandPrimary: Color(0xFF006778),
          brandSecondary: Color(0xFF00A3AD),
          brandTertiary: Color(0xFF7FD1D8),
        ),
        Hospital(
          id: 'mercy_south',
          name: 'Mercy Hospital South',
          city: 'St. Louis',
          metro: 'stl',
          brandPrimary: Color(0xFF006778),
          brandSecondary: Color(0xFF00A3AD),
          brandTertiary: Color(0xFF7FD1D8),
        ),
        Hospital(
          id: 'mercy_washington',
          name: 'Mercy Hospital Washington',
          city: 'Washington',
          metro: 'stl',
          brandPrimary: Color(0xFF006778),
          brandSecondary: Color(0xFF00A3AD),
          brandTertiary: Color(0xFF7FD1D8),
        ),
        Hospital(
          id: 'ssm_slu',
          name: 'SSM Health Saint Louis University Hospital',
          city: 'St. Louis',
          metro: 'stl',
          brandPrimary: Color(0xFF003DA5),
          brandSecondary: Color(0xFF00A9E0),
          brandTertiary: Color(0xFF8CC8EA),
        ),
        Hospital(
          id: 'ssm_depaul',
          name: 'SSM Health DePaul Hospital - St. Louis',
          city: 'Bridgeton',
          metro: 'stl',
          brandPrimary: Color(0xFF003DA5),
          brandSecondary: Color(0xFF00A9E0),
          brandTertiary: Color(0xFF8CC8EA),
        ),
        Hospital(
          id: 'ssm_st_marys',
          name: 'SSM Health St. Mary’s Hospital - St. Louis',
          city: 'Richmond Heights',
          metro: 'stl',
          brandPrimary: Color(0xFF003DA5),
          brandSecondary: Color(0xFF00A9E0),
          brandTertiary: Color(0xFF8CC8EA),
        ),
      ];
}
