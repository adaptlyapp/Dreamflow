import 'package:flutter/foundation.dart';
import 'package:wellspring/models/patient_note.dart';
import 'package:wellspring/models/patient_resource.dart';
import 'package:wellspring/supabase/supabase_config.dart';

/// Service for managing therapist/provider communications with patients.
/// Handles patient notes and resources shared by healthcare providers.
/// 
/// Uses direct Supabase queries with visibility filtering:
/// - patient_notes: filters for patient_visible and family_visible
/// - patient_resources: filters for patient_only and family_visible
class TherapistService {
  final _supabase = SupabaseConfig.client;

  // ==================== Patient Lookup ====================

  /// Look up the patient record ID for a given user ID.
  /// The patients table has user_id -> id mapping.
  Future<String?> _getPatientIdForUser(String userId) async {
    try {
      final response = await _supabase
          .from('patients')
          .select('id')
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) {
        debugPrint('TherapistService: No patient record found for user $userId');
        return null;
      }
      return response['id'] as String?;
    } catch (e) {
      debugPrint('TherapistService._getPatientIdForUser error: $e');
      return null;
    }
  }

  // ==================== Patient Notes ====================

  /// Get all visible notes for a specific user (looks up patient record first)
  /// Filters for patient_visible and family_visible notes
  Future<List<PatientNote>> getNotesForPatient(String userId) async {
    try {
      // First look up the patient record ID from the user ID
      final patientId = await _getPatientIdForUser(userId);
      if (patientId == null) {
        debugPrint('TherapistService.getNotesForPatient: No patient record for user');
        return [];
      }

      debugPrint('TherapistService: Looking up notes for patient_id=$patientId (user_id=$userId)');

      final response = await _supabase
          .from('patient_notes')
          .select()
          .eq('patient_id', patientId)
          .or('visibility.eq.patient_visible,visibility.eq.family_visible')
          .order('pinned', ascending: false)
          .order('created_at', ascending: false);

      debugPrint('TherapistService.getNotesForPatient: Found ${(response as List).length} notes');

      final notes = (response as List)
          .map((json) => PatientNote.fromJson(json))
          .toList();
      return notes;
    } catch (e) {
      debugPrint('TherapistService.getNotesForPatient error: $e');
      return [];
    }
  }

  /// Get pinned notes for a user (for quick access)
  Future<List<PatientNote>> getPinnedNotes(String userId) async {
    try {
      final patientId = await _getPatientIdForUser(userId);
      if (patientId == null) return [];

      final response = await _supabase
          .from('patient_notes')
          .select()
          .eq('patient_id', patientId)
          .or('visibility.eq.patient_visible,visibility.eq.family_visible')
          .eq('pinned', true)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => PatientNote.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('TherapistService.getPinnedNotes error: $e');
      return [];
    }
  }

  /// Get recent notes (last 30 days)
  Future<List<PatientNote>> getRecentNotes(String userId, {int limit = 10}) async {
    try {
      final patientId = await _getPatientIdForUser(userId);
      if (patientId == null) return [];

      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      final response = await _supabase
          .from('patient_notes')
          .select()
          .eq('patient_id', patientId)
          .or('visibility.eq.patient_visible,visibility.eq.family_visible')
          .gte('created_at', thirtyDaysAgo.toIso8601String())
          .order('created_at', ascending: false)
          .limit(limit);

      return (response as List)
          .map((json) => PatientNote.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('TherapistService.getRecentNotes error: $e');
      return [];
    }
  }

  /// Get notes by note_type
  Future<List<PatientNote>> getNotesByType(String userId, String noteType) async {
    try {
      final patientId = await _getPatientIdForUser(userId);
      if (patientId == null) return [];

      final response = await _supabase
          .from('patient_notes')
          .select()
          .eq('patient_id', patientId)
          .or('visibility.eq.patient_visible,visibility.eq.family_visible')
          .eq('note_type', noteType)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => PatientNote.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('TherapistService.getNotesByType error: $e');
      return [];
    }
  }

  // ==================== Patient Resources ====================

  /// Get all visible resources for a user (looks up patient record first)
  /// Filters for patient_only and family_visible resources
  Future<List<PatientResource>> getResourcesForPatient(String userId) async {
    try {
      final patientId = await _getPatientIdForUser(userId);
      if (patientId == null) {
        debugPrint('TherapistService.getResourcesForPatient: No patient record for user');
        return [];
      }

      debugPrint('TherapistService: Looking up resources for patient_id=$patientId');

      final response = await _supabase
          .from('patient_resources')
          .select()
          .eq('patient_id', patientId)
          .or('visibility.eq.patient_only,visibility.eq.family_visible')
          .order('created_at', ascending: false);

      debugPrint('TherapistService.getResourcesForPatient: Found ${(response as List).length} resources');

      return (response as List)
          .map((json) => PatientResource.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('TherapistService.getResourcesForPatient error: $e');
      return [];
    }
  }

  /// Get resources by type
  Future<List<PatientResource>> getResourcesByType(String userId, String resourceType) async {
    try {
      final patientId = await _getPatientIdForUser(userId);
      if (patientId == null) return [];

      final response = await _supabase
          .from('patient_resources')
          .select()
          .eq('patient_id', patientId)
          .or('visibility.eq.patient_only,visibility.eq.family_visible')
          .eq('type', resourceType)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => PatientResource.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('TherapistService.getResourcesByType error: $e');
      return [];
    }
  }

  /// Get file resources (those with blob_pathname)
  Future<List<PatientResource>> getFileResources(String userId) async {
    try {
      final patientId = await _getPatientIdForUser(userId);
      if (patientId == null) return [];

      final response = await _supabase
          .from('patient_resources')
          .select()
          .eq('patient_id', patientId)
          .or('visibility.eq.patient_only,visibility.eq.family_visible')
          .not('blob_pathname', 'is', null)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => PatientResource.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('TherapistService.getFileResources error: $e');
      return [];
    }
  }

  /// Get link resources (those with external_url)
  Future<List<PatientResource>> getLinkResources(String userId) async {
    try {
      final patientId = await _getPatientIdForUser(userId);
      if (patientId == null) return [];

      final response = await _supabase
          .from('patient_resources')
          .select()
          .eq('patient_id', patientId)
          .or('visibility.eq.patient_only,visibility.eq.family_visible')
          .not('external_url', 'is', null)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => PatientResource.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('TherapistService.getLinkResources error: $e');
      return [];
    }
  }

  // ==================== Stats & Summary ====================

  /// Get summary counts for the therapist page
  Future<Map<String, int>> getPatientSummary(String patientId) async {
    try {
      final notes = await getNotesForPatient(patientId);
      final resources = await getResourcesForPatient(patientId);
      final fileResources = resources.where((r) => r.isFileUpload).length;
      final linkResources = resources.where((r) => !r.isFileUpload).length;

      return {
        'totalNotes': notes.length,
        'pinnedNotes': notes.where((n) => n.pinned).length,
        'totalResources': resources.length,
        'fileResources': fileResources,
        'linkResources': linkResources,
      };
    } catch (e) {
      debugPrint('TherapistService.getPatientSummary error: $e');
      return {
        'totalNotes': 0,
        'pinnedNotes': 0,
        'totalResources': 0,
        'fileResources': 0,
        'linkResources': 0,
      };
    }
  }
}
