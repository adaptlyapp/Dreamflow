import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wellspring/models/patient_connection.dart';
import 'package:wellspring/models/family_shared_data.dart';
import 'package:wellspring/models/user.dart';
import 'package:wellspring/models/tracker_entry.dart';
import 'package:wellspring/models/patient_note.dart';
import 'package:wellspring/models/patient_resource.dart';
import 'package:wellspring/services/user_service.dart';
import 'package:wellspring/services/tracker_service.dart';
import 'package:wellspring/services/recovery_blueprint_service.dart';
import 'package:wellspring/services/notification_service.dart';
import 'package:wellspring/supabase/supabase_config.dart';

class FamilyService {
  static const String _connectionsKey = 'patient_connections';
  static const String _sharedDataKey = 'family_shared_data';
  static const String _lastAlertCheckKey = 'last_alert_check';
  
  final UserService _userService = UserService();
  final TrackerService _trackerService = TrackerService();
  final _supabase = SupabaseConfig.client;

  /// Validate a patient connection code and return patient info if valid
  Future<User?> validatePatientCode(String code) async {
    try {
      final trimmedCode = code.trim().toUpperCase();
      debugPrint('[FamilyService] Validating patient code: $trimmedCode');
      
      // Query database for patient with matching patient_code
      final data = await _supabase
          .from('users')
          .select('*, auth_user_id')
          .eq('role', 'patient')
          .eq('patient_code', trimmedCode)
          .maybeSingle();
      
      if (data == null) {
        debugPrint('[FamilyService] No patient found with exact code match: $trimmedCode');
        
        // FALLBACK: Try to find by regenerating the code from user data
        // This handles the case where codes were generated with old format (profile ID)
        // Parse the code format: PREFIX-SUFFIX (e.g., "SDX-93F3B4")
        final parts = trimmedCode.split('-');
        if (parts.length == 2) {
          final suffix = parts[1]; // Last 6 chars of UUID
          debugPrint('[FamilyService] Attempting fallback search with suffix: $suffix');
          
          // Search for patients whose ID or auth_user_id ends with this suffix
          final patients = await _supabase
              .from('users')
              .select('*, auth_user_id')
              .eq('role', 'patient');
          
          for (final patientData in patients) {
            final patientId = (patientData['id'] as String).replaceAll(RegExp('[^A-Za-z0-9]'), '').toUpperCase();
            final authUserId = (patientData['auth_user_id'] as String?)?.replaceAll(RegExp('[^A-Za-z0-9]'), '').toUpperCase();
            
            // Check if either ID ends with the suffix (handles both old and new format)
            final patientIdMatch = patientId.endsWith(suffix);
            final authUserIdMatch = authUserId != null && authUserId.endsWith(suffix);
            
            if (patientIdMatch || authUserIdMatch) {
              debugPrint('[FamilyService] ✓ Found patient via fallback: ${patientData['name']} (suffix match)');
              
              // Convert to User model
              final patient = User.fromJson({
                'id': patientData['id'],
                'name': patientData['name'],
                'email': patientData['email'],
                'profileImageUrl': patientData['profile_image_url'],
                'patientCode': patientData['patient_code'],
                'role': patientData['role'],
                'onboardingCompleted': patientData['onboarding_completed'] ?? false,
                'conditions': patientData['conditions'] ?? [],
                'diagnosisDate': patientData['diagnosis_date'],
                'interests': patientData['interests'] ?? [],
                'medications': patientData['medications'] ?? [],
                'preferences': patientData['preferences'] ?? {},
                'createdAt': patientData['created_at'],
                'updatedAt': patientData['updated_at'],
              });
              
              return patient;
            }
          }
        }
        
        debugPrint('[FamilyService] ✗ No patient found with code: $trimmedCode (tried fallback)');
        return null;
      }
      
      // Convert to User model
      final patient = User.fromJson({
        'id': data['id'],
        'name': data['name'],
        'email': data['email'],
        'profileImageUrl': data['profile_image_url'],
        'patientCode': data['patient_code'],
        'role': data['role'],
        'onboardingCompleted': data['onboarding_completed'] ?? false,
        'conditions': data['conditions'] ?? [],
        'diagnosisDate': data['diagnosis_date'],
        'interests': data['interests'] ?? [],
        'medications': data['medications'] ?? [],
        'preferences': data['preferences'] ?? {},
        'createdAt': data['created_at'],
        'updatedAt': data['updated_at'],
      });
      
      debugPrint('[FamilyService] Found patient: ${patient.name} (${patient.id})');
      return patient;
    } catch (e) {
      debugPrint('[FamilyService] validatePatientCode error: $e');
      return null;
    }
  }

  /// Connect a family member to a patient
  Future<PatientConnection> connectToPatient({
    required String familyMemberId,
    required String patientId,
    required String patientName,
    required String relationship,
    String? patientProfileImageUrl,
    String? patientCode,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      
      final connection = PatientConnection(
        id: 'conn_${DateTime.now().millisecondsSinceEpoch}',
        familyMemberId: familyMemberId,
        patientId: patientId,
        patientName: patientName,
        patientProfileImageUrl: patientProfileImageUrl,
        patientCode: patientCode,
        relationship: relationship,
        connectedAt: now,
        updatedAt: now,
      );

      // Load existing connections
      final connections = await getConnectionsForFamily(familyMemberId);
      connections.add(connection);
      
      // Save to local storage
      final jsonList = connections.map((c) => c.toJson()).toList();
      await prefs.setString(_connectionsKey, jsonEncode(jsonList));
      
      debugPrint('[FamilyService] Connected family member $familyMemberId to patient $patientId');

      // CRITICAL FIX: Also save connection to Supabase for persistence across devices/reinstalls
      try {
        final authUser = _supabase.auth.currentUser;
        if (authUser != null) {
          debugPrint('[FamilyService] Saving connection to Supabase for persistence...');
          
          // First, ensure a family_members record exists for this auth user
          var familyMemberRecord = await _supabase
              .from('family_members')
              .select('id')
              .eq('auth_user_id', authUser.id)
              .maybeSingle();
          
          String dbFamilyMemberId;
          if (familyMemberRecord == null) {
            // Create family_members record if it doesn't exist
            debugPrint('[FamilyService] Creating family_members record for auth_user_id: ${authUser.id}');
            final insertResult = await _supabase
                .from('family_members')
                .insert({
                  'auth_user_id': authUser.id,
                  'name': authUser.userMetadata?['name'] ?? authUser.email ?? 'Family Member',
                  'email': authUser.email,
                })
                .select('id')
                .single();
            dbFamilyMemberId = insertResult['id'] as String;
            debugPrint('[FamilyService] ✓ Created family_members record: $dbFamilyMemberId');
          } else {
            dbFamilyMemberId = familyMemberRecord['id'] as String;
            debugPrint('[FamilyService] ✓ Using existing family_members record: $dbFamilyMemberId');
          }
          
          // Now create the patient link in family_patient_links
          // Check if link already exists first
          final existingLink = await _supabase
              .from('family_patient_links')
              .select('id')
              .eq('family_member_id', dbFamilyMemberId)
              .eq('patient_id', patientId)
              .maybeSingle();
          
          if (existingLink == null) {
            await _supabase
                .from('family_patient_links')
                .insert({
                  'family_member_id': dbFamilyMemberId,
                  'patient_id': patientId,
                });
            debugPrint('[FamilyService] ✓ Created family_patient_links record');
          } else {
            debugPrint('[FamilyService] ✓ family_patient_links record already exists');
          }
        }
      } catch (e) {
        debugPrint('[FamilyService] ⚠️ Failed to save connection to Supabase (non-fatal): $e');
        // Don't fail the whole operation if Supabase save fails
      }

      // Auto-link as viewer on the patient's recovery blueprint (Option 2).
      try {
        final familyAuthId = _supabase.auth.currentUser?.id;
        if (familyAuthId != null) {
          // The blueprint's user_id references auth.users(id). The patient
          // record in our users table stores the auth id under auth_user_id.
          final patientRow = await _supabase
              .from('users')
              .select('auth_user_id')
              .eq('id', patientId)
              .maybeSingle();
          final patientAuthId = patientRow?['auth_user_id'] as String?;
          if (patientAuthId != null) {
            await RecoveryBlueprintService().autoLinkFamilyViewer(
              patientUserId: patientAuthId,
              familyAuthId: familyAuthId,
            );
          }
        }
      } catch (e) {
        debugPrint('[FamilyService] Blueprint auto-link skipped: $e');
      }

      return connection;
    } catch (e) {
      debugPrint('[FamilyService] connectToPatient error: $e');
      rethrow;
    }
  }

  /// Get all patient connections for a family member
  Future<List<PatientConnection>> getConnectionsForFamily(String familyMemberId) async {
    try {
      debugPrint('[FamilyService] ========================================');
      debugPrint('[FamilyService] getConnectionsForFamily called');
      debugPrint('[FamilyService] familyMemberId (profile ID): $familyMemberId');
      debugPrint('[FamilyService] ========================================');
      
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_connectionsKey);
      
      if (jsonString == null || jsonString.isEmpty) {
        debugPrint('[FamilyService] No connections found in local storage');
        
        // Try to sync from Supabase (partner web portal connections)
        debugPrint('[FamilyService] Attempting to sync connections from Supabase...');
        final syncedConnections = await _syncConnectionsFromSupabase(familyMemberId);
        
        if (syncedConnections.isNotEmpty) {
          debugPrint('[FamilyService] ✓ Synced ${syncedConnections.length} connections from Supabase');
          return syncedConnections;
        }
        
        debugPrint('[FamilyService] No connections found in Supabase either');
        return [];
      }
      
      final List<dynamic> jsonList = jsonDecode(jsonString);
      final allConnections = jsonList
          .map((json) => PatientConnection.fromJson(Map<String, dynamic>.from(json)))
          .toList();
      
      debugPrint('[FamilyService] Found ${allConnections.length} total connections in storage');
      
      // IMPORTANT: First try exact match with familyMemberId
      var userConnections = allConnections
          .where((c) => c.familyMemberId == familyMemberId && c.isActive)
          .toList();
      
      debugPrint('[FamilyService] Found ${userConnections.length} connections with exact familyMemberId match');
      
      // If no exact match, the user might have re-logged in and the familyMemberId changed
      // In this case, sync from Supabase to get fresh connections with correct familyMemberId
      if (userConnections.isEmpty) {
        debugPrint('[FamilyService] No exact matches - attempting Supabase sync to refresh connections...');
        final syncedConnections = await _syncConnectionsFromSupabase(familyMemberId);
        
        if (syncedConnections.isNotEmpty) {
          debugPrint('[FamilyService] ✓ Synced ${syncedConnections.length} connections from Supabase');
          debugPrint('[FamilyService] ✓ All connections now have correct familyMemberId: $familyMemberId');
          return syncedConnections;
        }
        
        debugPrint('[FamilyService] No connections found in Supabase either');
        return [];
      }
      
      // Remove duplicates by patientId (keep the most recent connection)
      final Map<String, PatientConnection> uniqueConnections = {};
      for (final conn in userConnections) {
        final existing = uniqueConnections[conn.patientId];
        if (existing == null || conn.connectedAt.isAfter(existing.connectedAt)) {
          uniqueConnections[conn.patientId] = conn;
        }
      }
      
      userConnections = uniqueConnections.values.toList();
      
      // If we found duplicates, clean up storage
      if (userConnections.length < allConnections.where((c) => c.familyMemberId == familyMemberId && c.isActive).length) {
        debugPrint('[FamilyService] ⚠️ Found duplicate connections! Cleaning up storage...');
        await _cleanupDuplicateConnections(familyMemberId, userConnections);
      }
      
      debugPrint('[FamilyService] ========================================');
      debugPrint('[FamilyService] Returning ${userConnections.length} unique connections');
      for (final conn in userConnections) {
        debugPrint('[FamilyService]   - Patient: ${conn.patientName} (ID: ${conn.patientId})');
        debugPrint('[FamilyService]   - familyMemberId: ${conn.familyMemberId}');
      }
      debugPrint('[FamilyService] ========================================');
      
      return userConnections;
    } catch (e) {
      debugPrint('[FamilyService] getConnectionsForFamily error: $e');
      return [];
    }
  }
  
  /// Sync patient connections from Supabase (partner web portal) to local storage
  Future<List<PatientConnection>> _syncConnectionsFromSupabase(String familyMemberId) async {
    try {
      final authUser = _supabase.auth.currentUser;
      if (authUser == null) {
        debugPrint('[FamilyService] No authenticated user for sync');
        return [];
      }
      
      debugPrint('[FamilyService] Syncing for familyMemberId (profile ID): $familyMemberId');
      debugPrint('[FamilyService] Auth user ID: ${authUser.id}');
      
      // CRITICAL FIX: Query the users table directly instead of family_members table
      // The familyMemberId passed in is the profile ID from users table with role='family'
      // We need to verify this profile exists and belongs to the current auth user
      final familyProfile = await _supabase
          .from('users')
          .select('id, role')
          .eq('id', familyMemberId)
          .eq('auth_user_id', authUser.id)
          .eq('role', 'family')
          .maybeSingle();
      
      if (familyProfile == null) {
        debugPrint('[FamilyService] No family profile found for user.id: $familyMemberId');
        return [];
      }
      
      debugPrint('[FamilyService] ✓ Verified family profile exists (ID: $familyMemberId, role: ${familyProfile['role']})');
      
      // Now check if there's also a family_members table entry (for web portal compatibility)
      final familyMemberData = await _supabase
          .from('family_members')
          .select('id')
          .eq('auth_user_id', authUser.id)
          .maybeSingle();
      
      if (familyMemberData == null) {
        debugPrint('[FamilyService] No family_member record found in family_members table');
        debugPrint('[FamilyService] This is normal for mobile-only users who never used the web portal');
        return [];
      }
      
      final dbFamilyMemberId = familyMemberData['id'] as String;
      debugPrint('[FamilyService] ✓ Found family_member record in family_members table (DB ID: $dbFamilyMemberId)');
      
      // Get all patient links from family_patient_links
      final links = await _supabase
          .from('family_patient_links')
          .select('id, patient_id')
          .eq('family_member_id', dbFamilyMemberId);
      
      if (links.isEmpty) {
        debugPrint('[FamilyService] No patient links found in family_patient_links');
        return [];
      }
      
      debugPrint('[FamilyService] Found ${links.length} patient links in family_patient_links');
      
      // Fetch patient details for each link
      final List<PatientConnection> connections = [];
      for (final link in links) {
        final patientId = link['patient_id'] as String;
        debugPrint('[FamilyService] Processing patient link for patient_id: $patientId');
        
        try {
          // Get patient details - first try without role filter to see if record exists at all
          debugPrint('[FamilyService] Querying users table for patient (without role filter)...');
          final patientData = await _supabase
              .from('users')
              .select('id, name, email, profile_image_url, role')
              .eq('id', patientId)
              .maybeSingle();
          
          debugPrint('[FamilyService] Patient query result: ${patientData != null ? "found" : "null"}');
          
          if (patientData != null) {
            final patientRole = patientData['role'] as String?;
            debugPrint('[FamilyService] Patient data: name=${patientData['name']}, id=${patientData['id']}, role=$patientRole');
            
            // Accept the patient regardless of role (some patients might not have role set correctly)
            final connection = PatientConnection(
              id: link['id'] as String,
              familyMemberId: familyMemberId, // CRITICAL: Use the user.id (profile ID) from the users table
              patientId: patientId,
              patientName: patientData['name'] as String? ?? 'Unknown Patient',
              patientProfileImageUrl: patientData['profile_image_url'] as String?,
              relationship: 'Family Member', // Default relationship
              connectedAt: DateTime.now(), // Use current time since created_at doesn't exist
              updatedAt: DateTime.now(),
            );
            
            connections.add(connection);
            debugPrint('[FamilyService]   ✓ Loaded patient: ${connection.patientName} (ID: $patientId)');
            debugPrint('[FamilyService]   ✓ Set familyMemberId to: $familyMemberId');
          } else {
            debugPrint('[FamilyService]   ⚠️ Patient not found in users table for patient_id: $patientId');
            debugPrint('[FamilyService]   ⚠️ This patient_id might not exist in the users table at all');
          }
        } catch (e, stackTrace) {
          debugPrint('[FamilyService]   ✗ Failed to load patient $patientId: $e');
          debugPrint('[FamilyService]   StackTrace: $stackTrace');
        }
      }
      
      debugPrint('[FamilyService] Total connections created from sync: ${connections.length}');
      
      // CRITICAL: Save connections and ensure old mismatched connections are cleared
      final prefs = await SharedPreferences.getInstance();
      
      // ALWAYS clear and replace with fresh data from Supabase to avoid stale familyMemberId issues
      if (connections.isNotEmpty) {
        debugPrint('[FamilyService] ✓ Replacing local storage with fresh Supabase connections');
        final jsonList = connections.map((c) => c.toJson()).toList();
        await prefs.setString(_connectionsKey, jsonEncode(jsonList));
        debugPrint('[FamilyService] ✓ Saved ${connections.length} synced connections to local storage');
        debugPrint('[FamilyService] ✓ All connections use correct familyMemberId: $familyMemberId');
      } else {
        debugPrint('[FamilyService] ⚠️ No connections to save from Supabase sync');
      }
      
      return connections;
    } catch (e) {
      debugPrint('[FamilyService] _syncConnectionsFromSupabase error: $e');
      return [];
    }
  }
  
  /// Clean up duplicate patient connections in storage
  Future<void> _cleanupDuplicateConnections(String familyMemberId, List<PatientConnection> uniqueConnections) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_connectionsKey);
      
      if (jsonString == null) return;
      
      final List<dynamic> jsonList = jsonDecode(jsonString);
      final allConnections = jsonList
          .map((json) => PatientConnection.fromJson(Map<String, dynamic>.from(json)))
          .toList();
      
      // Keep connections for other users + unique connections for this user
      final cleanedConnections = [
        ...allConnections.where((c) => c.familyMemberId != familyMemberId),
        ...uniqueConnections,
      ];
      
      final jsonListCleaned = cleanedConnections.map((c) => c.toJson()).toList();
      await prefs.setString(_connectionsKey, jsonEncode(jsonListCleaned));
      
      debugPrint('[FamilyService] ✓ Cleaned up duplicate connections. Before: ${allConnections.length}, After: ${cleanedConnections.length}');
    } catch (e) {
      debugPrint('[FamilyService] _cleanupDuplicateConnections error: $e');
    }
  }

  /// Get the primary patient connection for a family member
  Future<PatientConnection?> getPrimaryConnection(String familyMemberId) async {
    final connections = await getConnectionsForFamily(familyMemberId);
    return connections.isNotEmpty ? connections.first : null;
  }

  /// Get shared data for a patient
  Future<Map<String, FamilySharedData>> getSharedDataForPatient(String patientId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString('${_sharedDataKey}_$patientId');
      
      if (jsonString == null || jsonString.isEmpty) {
        // Return demo shared data
        return _generateDemoSharedData(patientId);
      }
      
      final Map<String, dynamic> jsonMap = jsonDecode(jsonString);
      return jsonMap.map((key, value) => 
        MapEntry(key, FamilySharedData.fromJson(Map<String, dynamic>.from(value)))
      );
    } catch (e) {
      debugPrint('[FamilyService] getSharedDataForPatient error: $e');
      return _generateDemoSharedData(patientId);
    }
  }

  /// Generate demo shared data for testing
  Map<String, FamilySharedData> _generateDemoSharedData(String patientId) {
    final now = DateTime.now();
    
    return {
      'overview': FamilySharedData(
        id: 'overview_$patientId',
        patientId: patientId,
        dataType: 'overview',
        data: {
          'recoveryStatus': 'On track',
          'lastActivity': now.subtract(const Duration(hours: 2)).toIso8601String(),
          'overallProgress': 0.72,
          'keyMetrics': {
            'painLevel': 3,
            'energyLevel': 4,
            'mood': 'positive',
          },
        },
        sharedAt: now.subtract(const Duration(days: 7)),
        updatedAt: now.subtract(const Duration(hours: 2)),
      ),
      'health_tracker': FamilySharedData(
        id: 'health_$patientId',
        patientId: patientId,
        dataType: 'health_tracker',
        data: {
          'recentEntries': [
            {
              'date': now.subtract(const Duration(days: 0)).toIso8601String(),
              'painLevel': 3,
              'mood': 'Neutral',
              'energyLevel': 4,
            },
            {
              'date': now.subtract(const Duration(days: 1)).toIso8601String(),
              'painLevel': 4,
              'mood': 'Tired',
              'energyLevel': 3,
            },
            {
              'date': now.subtract(const Duration(days: 2)).toIso8601String(),
              'painLevel': 2,
              'mood': 'Good',
              'energyLevel': 5,
            },
          ],
          'trends': {
            'painTrend': 'stable',
            'moodTrend': 'improving',
            'energyTrend': 'stable',
          },
        },
        sharedAt: now.subtract(const Duration(days: 7)),
        updatedAt: now,
      ),
      'goals': FamilySharedData(
        id: 'goals_$patientId',
        patientId: patientId,
        dataType: 'goals',
        data: {
          'activeGoals': [
            {
              'id': 'goal1',
              'title': 'Increase mobility',
              'progress': 0.65,
              'target': 'Walk 30 minutes daily',
              'status': 'In progress',
            },
            {
              'id': 'goal2',
              'title': 'Improve sleep quality',
              'progress': 0.80,
              'target': '7+ hours nightly',
              'status': 'Nearly complete',
            },
          ],
          'milestones': [
            {
              'title': 'First physical therapy session',
              'completed': true,
              'date': now.subtract(const Duration(days: 14)).toIso8601String(),
            },
            {
              'title': 'Return to work (part-time)',
              'completed': false,
              'targetDate': now.add(const Duration(days: 21)).toIso8601String(),
            },
          ],
        },
        sharedAt: now.subtract(const Duration(days: 7)),
        updatedAt: now.subtract(const Duration(days: 1)),
      ),
    };
  }

  /// Mark a tutorial as seen for a family member
  Future<void> markTutorialSeen(String familyMemberId, String pageName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'family_tutorial_${familyMemberId}_$pageName';
      await prefs.setBool(key, true);
    } catch (e) {
      debugPrint('[FamilyService] markTutorialSeen error: $e');
    }
  }

  /// Check if a tutorial has been seen
  Future<bool> hasTutorialBeenSeen(String familyMemberId, String pageName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'family_tutorial_${familyMemberId}_$pageName';
      return prefs.getBool(key) ?? false;
    } catch (e) {
      debugPrint('[FamilyService] hasTutorialBeenSeen error: $e');
      return false;
    }
  }

  /// Get patient nutrition entries
  Future<List<Map<String, dynamic>>> getPatientNutritionEntries(String patientId, {int limit = 30}) async {
    try {
      final apiData = await _fetchPatientDataFromApi(patientId);
      
      debugPrint('[FamilyService] ========================================');
      debugPrint('[FamilyService] NUTRITION EXTRACTION DEBUG');
      debugPrint('[FamilyService] API response keys: ${apiData.keys.toList()}');
      debugPrint('[FamilyService] Has nutritionEntries key: ${apiData.containsKey('nutritionEntries')}');
      debugPrint('[FamilyService] nutritionEntries value: ${apiData['nutritionEntries']}');
      debugPrint('[FamilyService] nutritionEntries type: ${apiData['nutritionEntries']?.runtimeType}');
      debugPrint('[FamilyService] ========================================');
      
      final entries = (apiData['nutritionEntries'] as List<dynamic>?)
          ?.map((json) => Map<String, dynamic>.from(json))
          .take(limit)
          .toList() ?? [];
      
      debugPrint('[FamilyService] Returning ${entries.length} nutrition entries for patient $patientId');
      return entries;
    } catch (e) {
      debugPrint('[FamilyService] getPatientNutritionEntries error: $e');
      return [];
    }
  }

  /// Fetch patient data from Family Portal API (authenticated and authorized)
  Future<Map<String, dynamic>> _fetchPatientDataFromApi(String patientId) async {
    try {
      debugPrint('[FamilyService] ========================================');
      debugPrint('[FamilyService] ========================================');
      debugPrint('[FamilyService] FETCHING DATA FOR PATIENT: $patientId');
      debugPrint('[FamilyService] Patient ID type: ${patientId.runtimeType}');
      debugPrint('[FamilyService] Patient ID length: ${patientId.length}');
      debugPrint('[FamilyService] Patient ID format check: ${RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$').hasMatch(patientId) ? "Valid UUID" : "Invalid UUID format"}');
      debugPrint('[FamilyService] ========================================');
      
      final session = _supabase.auth.currentSession;
      if (session == null) {
        debugPrint('[FamilyService] ❌ No active session - user not authenticated');
        debugPrint('[FamilyService] → Family member must be signed in to view patient data');
        return {
          'trackerEntries': [], 
          'userId': null,
          'error': 'Not authenticated',
        };
      }
      
      debugPrint('[FamilyService] ✓ Session active for user: ${session.user.id}');
      debugPrint('[FamilyService] ✓ Calling edge function: family-portal-patient-data');
      debugPrint('[FamilyService] ✓ Query params: patientId=$patientId');

      final response = await _supabase.functions.invoke(
        'family-portal-patient-data',
        queryParameters: {'patientId': patientId},
      );

      debugPrint('[FamilyService] ========================================');
      debugPrint('[FamilyService] EDGE FUNCTION RESPONSE');
      debugPrint('[FamilyService] Status: ${response.status}');
      debugPrint('[FamilyService] ========================================');
      
      if (response.status != 200) {
        debugPrint('[FamilyService] ❌ API ERROR');
        debugPrint('[FamilyService] Status: ${response.status}');
        debugPrint('[FamilyService] Response: ${response.data}');
        debugPrint('[FamilyService] ========================================');
        
        // Check for common errors
        if (response.status == 404) {
          debugPrint('[FamilyService] → Edge function not deployed OR patient not found');
          debugPrint('[FamilyService] → Please deploy the edge function via Supabase panel');
        } else if (response.status == 401 || response.status == 403) {
          debugPrint('[FamilyService] → Authorization issue');
          debugPrint('[FamilyService] → Check if patient has family_portal_enabled = true');
        }
        
        return {
          'trackerEntries': [], 
          'userId': null,
          'error': 'API error: ${response.status}',
          'errorDetails': response.data,
        };
      }

      final data = response.data as Map<String, dynamic>;
      final entryCount = data['entryCount'] ?? 0;
      final milestonesCount = (data['milestones'] as List?)?.length ?? 0;
      final goalsCount = (data['goals'] as List?)?.length ?? 0;
      
      debugPrint('[FamilyService] ✅ SUCCESS');
      debugPrint('[FamilyService] → Tracker entries: $entryCount');
      debugPrint('[FamilyService] → Milestones: $milestonesCount');
      debugPrint('[FamilyService] → Goals: $goalsCount');
      debugPrint('[FamilyService] ========================================');
      
      if (entryCount == 0) {
        debugPrint('[FamilyService] ⚠️  WARNING: No tracker entries found');
        debugPrint('[FamilyService] → Patient may not have logged any health data yet');
        debugPrint('[FamilyService] → Or patient ID might not match database user_id');
        debugPrint('[FamilyService] ========================================');
      }
      
      return data;
    } catch (e, stackTrace) {
      debugPrint('[FamilyService] ========================================');
      debugPrint('[FamilyService] ❌ EXCEPTION in _fetchPatientDataFromApi');
      debugPrint('[FamilyService] Error: $e');
      debugPrint('[FamilyService] Stack trace: $stackTrace');
      debugPrint('[FamilyService] ========================================');
      return {
        'trackerEntries': [], 
        'userId': null,
        'error': 'Exception: $e',
      };
    }
  }

  /// Get real-time tracker entries stream for a patient
  Stream<List<TrackerEntry>> getPatientTrackerStream(String patientId, {int limit = 30}) async* {
    // Fetch from API first
    final apiData = await _fetchPatientDataFromApi(patientId);
    final entries = (apiData['trackerEntries'] as List<dynamic>?)
        ?.map((json) => TrackerEntry.fromJson(Map<String, dynamic>.from(json)))
        .take(limit)
        .toList() ?? [];
    
    yield entries;
    
    // Note: Real-time updates would require a subscription to the tracker_entries table
    // For now, we return a single snapshot from the API
  }

  /// Get tracker statistics for a patient over a date range
  Future<Map<String, double>> getPatientStatistics(String patientId, DateTime start, DateTime end) async {
    final apiData = await _fetchPatientDataFromApi(patientId);
    final entries = (apiData['trackerEntries'] as List<dynamic>?)
        ?.map((json) => TrackerEntry.fromJson(Map<String, dynamic>.from(json)))
        .where((e) => e.date.isAfter(start) && e.date.isBefore(end))
        .toList() ?? [];
    
    if (entries.isEmpty) {
      return {
        'avgPain': 0,
        'avgSleep': 0,
        'avgEnergy': 0,
        'avgSteps': 0,
      };
    }

    // Calculate averages
    double totalPain = 0;
    double totalSleep = 0;
    double totalEnergy = 0;
    double totalSteps = 0;
    int painCount = 0;
    int sleepCount = 0;
    int energyCount = 0;
    int stepsCount = 0;

    for (final entry in entries) {
      if (entry.painLevel != null) {
        totalPain += entry.painLevel!;
        painCount++;
      }
      if (entry.sleepQuality != null) {
        totalSleep += entry.sleepQuality!;
        sleepCount++;
      }
      if (entry.energyLevel != null) {
        totalEnergy += entry.energyLevel!;
        energyCount++;
      }
      if (entry.steps != null) {
        totalSteps += entry.steps!;
        stepsCount++;
      }
    }

    return {
      'avgPain': painCount > 0 ? totalPain / painCount : 0,
      'avgSleep': sleepCount > 0 ? totalSleep / sleepCount : 0,
      'avgEnergy': energyCount > 0 ? totalEnergy / energyCount : 0,
      'avgSteps': stepsCount > 0 ? totalSteps / stepsCount : 0,
    };
  }

  /// Get recent tracker entries for a patient
  Future<List<TrackerEntry>> getPatientRecentEntries(String patientId, {int limit = 30}) async {
    final apiData = await _fetchPatientDataFromApi(patientId);
    final entries = (apiData['trackerEntries'] as List<dynamic>?)
        ?.map((json) => TrackerEntry.fromJson(Map<String, dynamic>.from(json)))
        .take(limit)
        .toList() ?? [];
    
    debugPrint('[FamilyService] Returning ${entries.length} recent entries for patient $patientId');
    return entries;
  }

  /// Calculate health score from tracker data
  int calculateHealthScore(Map<String, double> stats, List<TrackerEntry> recentEntries) {
    // Base score
    int score = 100;
    
    // Pain impact (higher pain = lower score)
    final avgPain = stats['avgPain'] ?? 0;
    score -= (avgPain * 3).round(); // Each pain point reduces score by 3
    
    // Sleep quality impact (better sleep = higher score)
    final avgSleep = stats['avgSleep'] ?? 0;
    if (avgSleep < 6) {
      score -= ((6 - avgSleep) * 2).round();
    }
    
    // Energy impact (higher energy = higher score)
    final avgEnergy = stats['avgEnergy'] ?? 0;
    if (avgEnergy < 5) {
      score -= ((5 - avgEnergy) * 2).round();
    }
    
    // Activity bonus (steps tracked = bonus)
    final avgSteps = stats['avgSteps'] ?? 0;
    if (avgSteps > 1000) {
      score += 5;
    }
    
    // Consistency bonus (regular entries)
    if (recentEntries.length >= 7) {
      score += 10;
    }
    
    // Keep score in valid range
    return score.clamp(0, 150);
  }

  /// Get health status label from score
  String getHealthStatusLabel(int score) {
    if (score >= 120) return 'Excellent';
    if (score >= 100) return 'Good';
    if (score >= 80) return 'Fair';
    if (score >= 60) return 'Needs Attention';
    return 'Critical';
  }

  /// Calculate trend for a metric
  String calculateTrend(List<TrackerEntry> entries, String metric) {
    if (entries.length < 2) return 'Stable';
    
    // Get first and second half averages
    final mid = entries.length ~/ 2;
    final recent = entries.sublist(0, mid);
    final older = entries.sublist(mid);
    
    double recentAvg = 0;
    double olderAvg = 0;
    int recentCount = 0;
    int olderCount = 0;
    
    for (final entry in recent) {
      final value = _getMetricValue(entry, metric);
      if (value != null) {
        recentAvg += value;
        recentCount++;
      }
    }
    
    for (final entry in older) {
      final value = _getMetricValue(entry, metric);
      if (value != null) {
        olderAvg += value;
        olderCount++;
      }
    }
    
    if (recentCount == 0 || olderCount == 0) return 'Stable';
    
    recentAvg /= recentCount;
    olderAvg /= olderCount;
    
    final diff = recentAvg - olderAvg;
    final threshold = 0.5; // 0.5 point change to be considered trending
    
    // For pain, lower is better
    if (metric == 'pain') {
      if (diff < -threshold) return 'Improving';
      if (diff > threshold) return 'Worsening';
      return 'Stable';
    }
    
    // For sleep and energy, higher is better
    if (diff > threshold) return 'Improving';
    if (diff < -threshold) return 'Worsening';
    return 'Stable';
  }

  double? _getMetricValue(TrackerEntry entry, String metric) {
    switch (metric) {
      case 'pain':
        return entry.painLevel?.toDouble();
      case 'sleep':
        return entry.sleepQuality?.toDouble();
      case 'energy':
        return entry.energyLevel?.toDouble();
      case 'steps':
        return entry.steps?.toDouble();
      default:
        return null;
    }
  }

  /// Get chart data for health trends (last 14 entries)
  List<Map<String, dynamic>> getChartData(List<TrackerEntry> entries, {int limit = 14}) {
    final sorted = entries.take(limit).toList();
    sorted.sort((a, b) => a.date.compareTo(b.date)); // Chronological for charts
    
    return sorted.map((entry) => {
      'date': entry.date,
      'pain': entry.painLevel?.toDouble(),
      'sleep': entry.sleepQuality?.toDouble(),
      'energy': entry.energyLevel?.toDouble(),
      'steps': entry.steps?.toDouble(),
    }).toList();
  }

  /// Detect infection risk signals from tracker data
  List<Map<String, dynamic>> detectInfectionSignals(List<TrackerEntry> recentEntries) {
    final signals = <Map<String, dynamic>>[];
    
    // Check for fever (using Fahrenheit)
    final recentTemp = recentEntries.where((e) => e.temperature != null && e.temperature! > 99.5).toList();
    if (recentTemp.isNotEmpty) {
      signals.add({
        'severity': 'critical',
        'title': 'Elevated Temperature',
        'description': 'Temperature above 99.5°F detected. This could indicate infection.',
        'date': recentTemp.first.date,
      });
    }
    
    // Check for infection-related symptoms
    final infectionSymptoms = ['fever', 'chills', 'sweating', 'infection', 'drainage', 'pus', 'redness', 'swelling'];
    for (final entry in recentEntries.take(7)) {
      if (entry.symptoms != null) {
        final foundSymptoms = entry.symptoms!.where((s) => 
          infectionSymptoms.any((inf) => s.toLowerCase().contains(inf))
        ).toList();
        if (foundSymptoms.isNotEmpty) {
          signals.add({
            'severity': 'warning',
            'title': 'Infection-Related Symptoms',
            'description': 'Reported: ${foundSymptoms.join(", ")}',
            'date': entry.date,
          });
        }
      }
    }
    
    // Check for high pain with fever (severe risk, using Fahrenheit)
    final highPainWithTemp = recentEntries.where((e) => 
      e.painLevel != null && e.painLevel! >= 7 && e.temperature != null && e.temperature! > 99.5
    ).toList();
    if (highPainWithTemp.isNotEmpty) {
      signals.add({
        'severity': 'critical',
        'title': 'High Pain + Temperature',
        'description': 'Combination of severe pain and elevated temperature requires attention.',
        'date': highPainWithTemp.first.date,
      });
    }
    
    return signals;
  }

  /// Get journey data for a patient (milestones, goals, achievements)
  Future<Map<String, dynamic>> getJourneyData(String patientId) async {
    try {
      debugPrint('[FamilyService] getJourneyData: Fetching journey data for patient $patientId');
      
      // Fetch patient's conditions first
      final patientData = await _supabase
          .from('users')
          .select('conditions')
          .eq('id', patientId)
          .maybeSingle();
      
      final patientConditionIds = (patientData?['conditions'] as List<dynamic>?)?.cast<String>() ?? [];
      debugPrint('[FamilyService] Patient condition IDs: $patientConditionIds');
      
      // Fetch milestones and goals from edge function (bypasses RLS)
      debugPrint('[FamilyService] Calling edge function to fetch milestones and goals...');
      final apiData = await _fetchPatientDataFromApi(patientId);
      
      final milestonesData = (apiData['milestones'] as List<dynamic>?) ?? [];
      final goalsData = (apiData['goals'] as List<dynamic>?) ?? [];
      
      debugPrint('[FamilyService] ========================================');
      debugPrint('[FamilyService] EDGE FUNCTION RESULT');
      debugPrint('[FamilyService] Found: ${milestonesData.length} milestones');
      debugPrint('[FamilyService] Found: ${goalsData.length} goals');
      if (milestonesData.isNotEmpty) {
        debugPrint('[FamilyService] Sample milestone:');
        debugPrint('[FamilyService]   - ID: ${milestonesData.first['id']}');
        debugPrint('[FamilyService]   - Title: ${milestonesData.first['title']}');
        debugPrint('[FamilyService]   - User ID: ${milestonesData.first['user_id']}');
      }
      debugPrint('[FamilyService] ========================================');
      
      final milestones = milestonesData.map((row) => {
        'id': row['id'],
        'title': row['title'],
        'description': row['description'],
        'completed': row['completed'] ?? false,
        'dueDate': row['due_date'],
        'conditionId': row['condition_id'],
        'order': row['order'] ?? 0,
      }).toList();

      final goals = goalsData.map((row) => {
        'id': row['id'],
        'title': row['title'],
        'description': row['description'],
        'active': row['active'] ?? true,
        'period': row['period'] ?? 'weekly',
        'progressThisPeriod': row['progress_this_period'] ?? 0,
        'targetPerPeriod': row['target_per_period'] ?? 0,
        'linkedTrackerKey': row['linked_tracker_key'],
      }).toList();

      // Fetch user achievements
      final achievementsData = await _supabase
          .from('user_achievements')
          .select()
          .eq('user_id', patientId)
          .eq('unlocked', true);
      
      final achievements = achievementsData.map((row) => {
        'achievementId': row['achievement_id'],
        'unlocked': row['unlocked'] ?? false,
        'unlockedAt': row['unlocked_at'],
      }).toList();

      // Fetch plan timelines
      final timelinesData = await _supabase
          .from('plan_timelines')
          .select()
          .eq('user_id', patientId)
          .order('created_at', ascending: false);
      
      final timelines = timelinesData.map((row) => {
        'id': row['id'],
        'name': row['name'],
        'conditionId': row['condition_id'],
        'isCurrent': row['is_current'] ?? false,
        'milestones': row['milestones'] ?? [],
      }).toList();

      // Fetch ONLY the patient's conditions (not all conditions)
      final conditions = <String, String>{};
      if (patientConditionIds.isNotEmpty) {
        debugPrint('[FamilyService] Patient conditions to fetch: $patientConditionIds');
        
        for (final conditionIdentifier in patientConditionIds) {
          try {
            // The condition identifier might be a slug like "achilles-tendon-rupture"
            // or a UUID or just a plain name. Try different approaches:
            
            // Check if it looks like a UUID
            final isUuid = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$').hasMatch(conditionIdentifier.toLowerCase());
            
            dynamic conditionData;
            
            if (isUuid) {
              // Try as UUID first
              conditionData = await _supabase
                  .from('conditions')
                  .select('id, name')
                  .eq('id', conditionIdentifier)
                  .maybeSingle();
            } else {
              // For non-UUID values (like slugs), search by name with fuzzy matching
              // Convert slug format to readable: "achilles-tendon-rupture" -> "achilles tendon rupture"
              final searchTerm = conditionIdentifier.replaceAll('-', ' ');
              
              conditionData = await _supabase
                  .from('conditions')
                  .select('id, name')
                  .ilike('name', '%$searchTerm%')
                  .limit(1)
                  .maybeSingle();
            }
            
            if (conditionData != null) {
              conditions[conditionData['id'] as String] = conditionData['name'] as String;
              debugPrint('[FamilyService] ✓ Found condition: ${conditionData['name']} (${conditionData['id']})');
            } else {
              debugPrint('[FamilyService] ✗ Condition not found in database: $conditionIdentifier');
              // Use the identifier as a fallback display name
              conditions[conditionIdentifier] = conditionIdentifier.replaceAll('-', ' ').split(' ').map((w) => w[0].toUpperCase() + w.substring(1)).join(' ');
            }
          } catch (e) {
            debugPrint('[FamilyService] Error fetching condition $conditionIdentifier: $e');
            // Use the identifier as a fallback display name
            conditions[conditionIdentifier] = conditionIdentifier.replaceAll('-', ' ').split(' ').map((w) => w[0].toUpperCase() + w.substring(1)).join(' ');
          }
        }
        
        debugPrint('[FamilyService] Final conditions map: $conditions');
      }

      debugPrint('[FamilyService] Journey data summary: ${milestones.length} milestones, ${goals.length} goals, ${achievements.length} achievements, ${timelines.length} timelines');
      
      return {
        'milestones': milestones,
        'goals': goals,
        'achievements': achievements,
        'timelines': timelines,
        'conditions': conditions,
      };
    } catch (e) {
      debugPrint('[FamilyService] getJourneyData error: $e');
      return {
        'milestones': [],
        'goals': [],
        'achievements': [],
        'timelines': [],
        'conditions': {},
      };
    }
  }

  /// Generate alerts based on patient data
  Future<List<Map<String, dynamic>>> generateAlerts(String patientId) async {
    try {
      final alerts = <Map<String, dynamic>>[];
      
      // Fetch recent tracker entries
      final apiData = await _fetchPatientDataFromApi(patientId);
      final entries = (apiData['trackerEntries'] as List<dynamic>?)
          ?.map((json) => TrackerEntry.fromJson(Map<String, dynamic>.from(json)))
          .toList() ?? [];
      
      if (entries.isEmpty) return alerts;
      
      // Sort entries by date descending
      entries.sort((a, b) => b.date.compareTo(a.date));
      final recentEntries = entries.take(7).toList();
      
      // Check for high pain levels (3+ consecutive days >= 7)
      int highPainDays = 0;
      for (var entry in recentEntries.take(3)) {
        if ((entry.painLevel ?? 0) >= 7) highPainDays++;
      }
      if (highPainDays >= 3) {
        alerts.add({
          'type': 'warning',
          'icon': Icons.warning,
          'title': 'High Pain Levels',
          'subtitle': 'Pain levels have been 7+ for $highPainDays consecutive days',
          'time': _getTimeAgo(recentEntries.first.date),
          'priority': 1,
        });
      }
      
      // Check for low energy (< 3 for 2+ days)
      int lowEnergyDays = 0;
      for (var entry in recentEntries.take(3)) {
        if ((entry.energyLevel ?? 0) > 0 && (entry.energyLevel ?? 0) < 3) lowEnergyDays++;
      }
      if (lowEnergyDays >= 2) {
        alerts.add({
          'type': 'caution',
          'icon': Icons.battery_1_bar,
          'title': 'Low Energy Levels',
          'subtitle': 'Energy has been below 3/10 for $lowEnergyDays days',
          'time': _getTimeAgo(recentEntries.first.date),
          'priority': 2,
        });
      }
      
      // Check for poor sleep (< 5 hours for 2+ nights)
      int poorSleepDays = 0;
      for (var entry in recentEntries.take(3)) {
        if ((entry.sleepQuality ?? 0) > 0 && (entry.sleepQuality ?? 0) < 5) poorSleepDays++;
      }
      if (poorSleepDays >= 2) {
        alerts.add({
          'type': 'info',
          'icon': Icons.bedtime,
          'title': 'Poor Sleep Pattern',
          'subtitle': 'Sleep has been under 5 hours for $poorSleepDays nights',
          'time': _getTimeAgo(recentEntries.first.date),
          'priority': 3,
        });
      }
      
      // Check for missed logging (no entry in last 2 days)
      final now = DateTime.now();
      final daysSinceLastEntry = now.difference(recentEntries.first.date).inDays;
      if (daysSinceLastEntry >= 2) {
        alerts.add({
          'type': 'warning',
          'icon': Icons.event_busy,
          'title': 'No Recent Health Logs',
          'subtitle': 'Last entry was ${daysSinceLastEntry}d ago',
          'time': '${daysSinceLastEntry}d',
          'priority': 1,
        });
      }
      
      // Check for positive trends (improving pain)
      if (recentEntries.length >= 5) {
        final recent3 = recentEntries.take(3).map((e) => e.painLevel ?? 0).where((p) => p > 0).toList();
        final older2 = recentEntries.skip(3).take(2).map((e) => e.painLevel ?? 0).where((p) => p > 0).toList();
        
        if (recent3.isNotEmpty && older2.isNotEmpty) {
          final recentAvg = recent3.reduce((a, b) => a + b) / recent3.length;
          final olderAvg = older2.reduce((a, b) => a + b) / older2.length;
          
          if (olderAvg - recentAvg >= 2) {
            alerts.add({
              'type': 'success',
              'icon': Icons.trending_down,
              'title': 'Pain Improving',
              'subtitle': 'Pain levels decreased by ${(olderAvg - recentAvg).toStringAsFixed(1)} points',
              'time': _getTimeAgo(recentEntries.first.date),
              'priority': 4,
            });
          }
        }
      }
      
      // Fetch milestones for completion alerts
      final milestonesData = (apiData['milestones'] as List<dynamic>?) ?? [];
      final recentCompletions = milestonesData.where((m) {
        final completed = m['completed'] ?? false;
        return completed;
      }).toList();
      
      if (recentCompletions.isNotEmpty) {
        alerts.add({
          'type': 'success',
          'icon': Icons.emoji_events,
          'title': 'Milestone Completed',
          'subtitle': '${recentCompletions.first['title']}',
          'time': '1d',
          'priority': 4,
        });
      }
      
      // Sort by priority (lower = more important)
      alerts.sort((a, b) => (a['priority'] as int).compareTo(b['priority'] as int));
      
      return alerts;
    } catch (e) {
      debugPrint('[FamilyService] generateAlerts error: $e');
      return [];
    }
  }
  
  String _getTimeAgo(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    
    if (diff.inDays > 0) return '${diff.inDays}d';
    if (diff.inHours > 0) return '${diff.inHours}h';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m';
    return 'now';
  }

  /// Get family-visible notes for a patient (via edge function)
  Future<List<PatientNote>> getPatientNotes(String patientId) async {
    try {
      final apiData = await _fetchPatientDataFromApi(patientId);
      final list = (apiData['notes'] as List<dynamic>?) ?? [];
      return list
          .map((j) => PatientNote.fromJson(Map<String, dynamic>.from(j)))
          .toList();
    } catch (e) {
      debugPrint('[FamilyService] getPatientNotes error: $e');
      return [];
    }
  }

  /// Get family-visible resources for a patient (via edge function)
  Future<List<PatientResource>> getPatientResources(String patientId) async {
    try {
      final apiData = await _fetchPatientDataFromApi(patientId);
      final list = (apiData['resources'] as List<dynamic>?) ?? [];
      return list
          .map((j) => PatientResource.fromJson(Map<String, dynamic>.from(j)))
          .toList();
    } catch (e) {
      debugPrint('[FamilyService] getPatientResources error: $e');
      return [];
    }
  }

  /// Get contextual labels for vital signs
  Map<String, String> getVitalContext(double? value, String metric) {
    if (value == null) return {'label': '—', 'status': 'normal'};
    
    switch (metric) {
      case 'temperature':
        if (value >= 38.0) return {'label': 'High', 'status': 'warning'};
        if (value >= 37.5) return {'label': 'Elevated', 'status': 'caution'};
        return {'label': 'Normal', 'status': 'normal'};
      
      case 'heartRate':
        if (value > 100) return {'label': 'Elevated', 'status': 'caution'};
        if (value < 60) return {'label': 'Low', 'status': 'caution'};
        return {'label': 'Normal', 'status': 'normal'};
      
      case 'pain':
        if (value >= 7) return {'label': 'Severe', 'status': 'warning'};
        if (value >= 4) return {'label': 'Moderate', 'status': 'caution'};
        return {'label': 'Well managed', 'status': 'normal'};
      
      case 'sleep':
        if (value >= 7) return {'label': 'Good', 'status': 'normal'};
        if (value >= 5) return {'label': 'Fair', 'status': 'caution'};
        return {'label': 'Poor', 'status': 'warning'};
      
      case 'steps':
        if (value >= 5000) return {'label': 'Active', 'status': 'normal'};
        if (value >= 2000) return {'label': 'Moderate', 'status': 'caution'};
        return {'label': 'Low', 'status': 'caution'};
      
      case 'energy':
        if (value >= 7) return {'label': 'High', 'status': 'normal'};
        if (value >= 4) return {'label': 'Moderate', 'status': 'caution'};
        return {'label': 'Low', 'status': 'warning'};
      
      default:
        return {'label': value.toStringAsFixed(1), 'status': 'normal'};
    }
  }

  /// Check for alerts and send notifications to family members
  /// This should be called periodically (e.g., every hour when app is active)
  Future<void> checkAndNotifyAlerts(String patientId, String patientName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastCheckKey = '${_lastAlertCheckKey}_$patientId';
      final lastCheck = prefs.getString(lastCheckKey);
      final now = DateTime.now();
      
      // Only check once per hour to avoid notification spam
      if (lastCheck != null) {
        final lastCheckTime = DateTime.parse(lastCheck);
        if (now.difference(lastCheckTime).inHours < 1) {
          return;
        }
      }
      
      // Fetch recent entries
      final apiData = await _fetchPatientDataFromApi(patientId);
      final entries = (apiData['trackerEntries'] as List<dynamic>?)
          ?.map((json) => TrackerEntry.fromJson(Map<String, dynamic>.from(json)))
          .toList() ?? [];
      
      if (entries.isEmpty) return;
      
      // Sort by date descending
      entries.sort((a, b) => b.date.compareTo(a.date));
      final recentEntries = entries.take(7).toList();
      
      // Check for high pain (3+ consecutive days >= 7)
      int highPainDays = 0;
      for (var entry in recentEntries.take(3)) {
        if ((entry.painLevel ?? 0) >= 7) highPainDays++;
      }
      if (highPainDays >= 3) {
        await NotificationService.instance.notifyFamilyHighPain(
          patientName: patientName,
          painLevel: recentEntries.first.painLevel ?? 7,
          patientId: patientId,
        );
      }
      
      // Check for missed logging (no entry in last 2 days)
      final daysSinceLastEntry = now.difference(recentEntries.first.date).inDays;
      if (daysSinceLastEntry >= 2) {
        await NotificationService.instance.notifyFamilyMissedLogs(
          patientName: patientName,
          daysMissed: daysSinceLastEntry,
          patientId: patientId,
        );
      }
      
      // Check for infection risk signals
      final infectionSignals = detectInfectionSignals(recentEntries);
      if (infectionSignals.isNotEmpty) {
        final criticalSignals = infectionSignals.where((s) => s['severity'] == 'critical').toList();
        if (criticalSignals.isNotEmpty) {
          final signal = criticalSignals.first;
          await NotificationService.instance.notifyFamilyInfectionRisk(
            patientName: patientName,
            symptomDescription: signal['description'] as String,
            patientId: patientId,
          );
        }
      }
      
      // Check for completed milestones
      final milestonesData = (apiData['milestones'] as List<dynamic>?) ?? [];
      for (final m in milestonesData) {
        final completed = m['completed'] ?? false;
        if (completed) {
          final milestoneTitle = m['title'] as String? ?? 'a milestone';
          await NotificationService.instance.notifyFamilyMilestoneCompleted(
            patientName: patientName,
            milestoneTitle: milestoneTitle,
            patientId: patientId,
          );
          break; // Only notify for one milestone at a time
        }
      }
      
      // Save last check time
      await prefs.setString(lastCheckKey, now.toIso8601String());
    } catch (e) {
      debugPrint('[FamilyService] checkAndNotifyAlerts error: $e');
    }
  }
}
