import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wellspring/supabase/supabase_config.dart';
import 'package:wellspring/models/recovery_blueprint.dart';

class RecoveryBlueprintService {
  static const _collectionName = 'recovery_blueprints';
  static const _collaboratorsTable = 'blueprint_collaborators';

  /// Get blueprint for a specific user
  Future<RecoveryBlueprint?> getByUserId(String userId) async {
    try {
      debugPrint('RecoveryBlueprintService.getByUserId: Querying for userId=$userId');
      final response = await SupabaseConfig.client
          .from(_collectionName)
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) {
        debugPrint('RecoveryBlueprintService.getByUserId: No blueprint found for userId=$userId');
        return null;
      }
      debugPrint('RecoveryBlueprintService.getByUserId: Found blueprint ${response['id']}');
      return RecoveryBlueprint.fromJson(_fromSupabase(response));
    } catch (e) {
      debugPrint('RecoveryBlueprintService.getByUserId error: $e');
      return null;
    }
  }

  /// Create a new blueprint
  Future<RecoveryBlueprint> create(RecoveryBlueprint blueprint) async {
    try {
      debugPrint('RecoveryBlueprintService.create: Creating blueprint ${blueprint.id} for userId=${blueprint.userId}');
      final data = _toSupabase(blueprint.toJson());
      await SupabaseConfig.client
          .from(_collectionName)
          .insert(data);

      // Ensure the creating user is registered as the blueprint owner so
      // collaborator-aware queries (and future invitee lookups) work.
      try {
        await SupabaseConfig.client.from(_collaboratorsTable).upsert({
          'blueprint_id': blueprint.id,
          'user_id': blueprint.userId,
          'role': 'owner',
          'added_by': blueprint.userId,
        }, onConflict: 'blueprint_id,user_id');
      } catch (e) {
        debugPrint('RecoveryBlueprintService.create: owner-collaborator seed failed: $e');
      }

      debugPrint('RecoveryBlueprintService.create: ✅ Successfully created blueprint ${blueprint.id}');
      return blueprint;
    } catch (e) {
      debugPrint('RecoveryBlueprintService.create error: $e');
      rethrow;
    }
  }

  /// Update an existing blueprint. Tags the edit with the current auth user
  /// for last-write-wins / "edited by" UI.
  Future<RecoveryBlueprint> update(RecoveryBlueprint blueprint) async {
    try {
      final editorId = SupabaseConfig.client.auth.currentUser?.id;
      debugPrint('RecoveryBlueprintService.update: ═══ UPDATE STARTED ═══');
      debugPrint('RecoveryBlueprintService.update: Updating blueprint ${blueprint.id} for userId=${blueprint.userId} editor=$editorId');
      debugPrint('RecoveryBlueprintService.update: dailyRoutines count=${blueprint.dailyRoutines.length}');
      for (var routine in blueprint.dailyRoutines) {
        debugPrint('RecoveryBlueprintService.update:   - ${routine.type}: ${routine.timesOfDay}');
      }
      
      final updated = RecoveryBlueprint(
        id: blueprint.id,
        userId: blueprint.userId,
        patientProfile: blueprint.patientProfile,
        careTeam: blueprint.careTeam,
        independenceAssessment: blueprint.independenceAssessment,
        homeReadiness: blueprint.homeReadiness,
        dailyRoutines: blueprint.dailyRoutines,
        equipment: blueprint.equipment,
        supplies: blueprint.supplies,
        roadmap: blueprint.roadmap,
        createdAt: blueprint.createdAt,
        updatedAt: DateTime.now(),
        updatedBy: editorId ?? blueprint.updatedBy,
      );

      final data = _toSupabase(updated.toJson());
      debugPrint('RecoveryBlueprintService.update: Calling Supabase update...');
      final response = await SupabaseConfig.client
          .from(_collectionName)
          .update(data)
          .eq('id', blueprint.id)
          .select();
      
      debugPrint('RecoveryBlueprintService.update: ✓ Supabase update completed');
      debugPrint('RecoveryBlueprintService.update: Response: $response');
      debugPrint('RecoveryBlueprintService.update: ═══ UPDATE COMPLETED ═══');
      return updated;
    } catch (e, stackTrace) {
      debugPrint('RecoveryBlueprintService.update ❌ ERROR: $e');
      debugPrint('RecoveryBlueprintService.update Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Delete a blueprint
  Future<void> delete(String blueprintId) async {
    try {
      await SupabaseConfig.client
          .from(_collectionName)
          .delete()
          .eq('id', blueprintId);
      
      debugPrint('RecoveryBlueprintService.delete: Deleted blueprint $blueprintId');
    } catch (e) {
      debugPrint('RecoveryBlueprintService.delete error: $e');
      rethrow;
    }
  }

  /// Generate roadmap based on blueprint data
  RecoveryRoadmap generateRoadmap(RecoveryBlueprint blueprint) {
    final immediate = <String>[];
    final shortTerm = <String>[];
    final longTerm = <String>[];
    final warnings = <String>[];

    // Check for supplies that need reordering
    for (final supply in blueprint.supplies) {
      if (supply.needsReorder) {
        if (supply.daysRemaining <= 5) {
          immediate.add('Order ${supply.name} (${supply.daysRemaining} days remaining)');
          warnings.add('${supply.name} running low');
        } else if (supply.daysRemaining <= 14) {
          shortTerm.add('Reorder ${supply.name}');
        }
      }
    }

    // Check for incomplete home modifications
    final incompleteTasks = blueprint.homeReadiness.actionItems.where((a) => !a.completed).toList();
    for (final task in incompleteTasks) {
      if (task.estimatedCompletion != null) {
        final daysUntil = task.estimatedCompletion!.difference(DateTime.now()).inDays;
        if (daysUntil <= 7) {
          immediate.add(task.description);
        } else if (daysUntil <= 30) {
          shortTerm.add(task.description);
        } else {
          longTerm.add(task.description);
        }
      } else {
        shortTerm.add(task.description);
      }
    }

    // Check for coverage gaps
    final coverageGaps = _findCoverageGaps(blueprint);
    for (final gap in coverageGaps) {
      warnings.add(gap);
      immediate.add('Arrange coverage for $gap');
    }

    // Check for scheduled routines without assigned caregivers
    for (final routine in blueprint.dailyRoutines) {
      if (routine.assignedCaregiverId == null || routine.assignedCaregiverId!.isEmpty) {
        warnings.add('No caregiver assigned for ${routine.type} routine');
        immediate.add('Assign caregiver for ${routine.type}');
      }
    }

    // Add therapy goals to long-term if specified
    for (final goal in blueprint.patientProfile.therapyGoals) {
      longTerm.add(goal);
    }

    // Equipment maintenance checks
    for (final eq in blueprint.equipment) {
      if (eq.maintenanceSchedule != null) {
        final daysUntil = eq.maintenanceSchedule!.difference(DateTime.now()).inDays;
        if (daysUntil <= 7) {
          immediate.add('Schedule maintenance for ${eq.name}');
        } else if (daysUntil <= 30) {
          shortTerm.add('${eq.name} maintenance due');
        }
      }
    }

    // Default priorities based on recovery phase
    switch (blueprint.patientProfile.recoveryPhase) {
      case RecoveryPhase.acute:
        if (immediate.isEmpty) {
          immediate.add('Complete discharge planning');
          immediate.add('Arrange home modifications');
        }
        if (shortTerm.isEmpty) {
          shortTerm.add('Attend all therapy appointments');
          shortTerm.add('Establish medication adherence');
        }
        break;
      case RecoveryPhase.postDischarge:
        if (immediate.isEmpty) {
          immediate.add('Establish bowel & bladder schedule');
          immediate.add('Complete home setup');
        }
        if (shortTerm.isEmpty) {
          shortTerm.add('Maintain therapy routine');
          shortTerm.add('Monitor for complications');
        }
        break;
      case RecoveryPhase.outpatient:
        if (shortTerm.isEmpty) {
          shortTerm.add('Continue therapy progress');
          shortTerm.add('Reduce caregiver burden');
        }
        if (longTerm.isEmpty) {
          longTerm.add('Improve transfer independence');
          longTerm.add('Return to community activities');
        }
        break;
      case RecoveryPhase.longTerm:
        if (longTerm.isEmpty) {
          longTerm.add('Maintain independence gains');
          longTerm.add('Prevent secondary complications');
          longTerm.add('Enhance quality of life');
        }
        break;
    }

    return RecoveryRoadmap(
      immediatePriorities: immediate,
      shortTermGoals: shortTerm,
      longTermGoals: longTerm,
      warnings: warnings,
    );
  }

  /// Find coverage gaps in care team availability
  List<String> _findCoverageGaps(RecoveryBlueprint blueprint) {
    final gaps = <String>[];
    final daysOfWeek = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
    final timePeriods = ['morning', 'afternoon', 'evening', 'overnight'];

    for (final day in daysOfWeek) {
      for (final period in timePeriods) {
        bool hasCoverage = false;
        for (final member in blueprint.careTeam) {
          final dayAvailability = member.availability[day] ?? [];
          if (dayAvailability.contains(period)) {
            hasCoverage = true;
            break;
          }
        }
        if (!hasCoverage) {
          gaps.add('$day $period');
        }
      }
    }

    return gaps;
  }

  /// Check for conflicts between scheduled routines and caregiver availability
  List<String> findScheduleConflicts(RecoveryBlueprint blueprint) {
    final conflicts = <String>[];

    for (final routine in blueprint.dailyRoutines) {
      if (routine.assignedCaregiverId == null) continue;

      final caregiver = blueprint.careTeam
          .where((m) => m.id == routine.assignedCaregiverId)
          .firstOrNull;

      if (caregiver == null) {
        conflicts.add('${routine.type} assigned to unknown caregiver');
        continue;
      }

      // Check if caregiver is available for this routine
      for (final day in routine.daysPerformed) {
        final dayAvailability = caregiver.availability[day.toLowerCase()] ?? [];
        
        // Determine time period from timeOfDay
        String? period;
        if (routine.timesOfDay.isNotEmpty) {
          final hour = _parseHour(routine.timesOfDay.first);
          if (hour != null) {
            if (hour >= 6 && hour < 12) period = 'morning';
            else if (hour >= 12 && hour < 17) period = 'afternoon';
            else if (hour >= 17 && hour < 22) period = 'evening';
            else period = 'overnight';
          }
        }

        if (period != null && !dayAvailability.contains(period)) {
          conflicts.add('${routine.type} scheduled on $day but ${caregiver.name} unavailable');
        }
      }
    }

    return conflicts;
  }

  int? _parseHour(String timeStr) {
    try {
      final parts = timeStr.replaceAll(RegExp(r'[^0-9:]'), '').split(':');
      if (parts.isEmpty) return null;
      int hour = int.parse(parts[0]);
      // Handle PM times
      if (timeStr.toLowerCase().contains('pm') && hour < 12) {
        hour += 12;
      }
      return hour;
    } catch (e) {
      return null;
    }
  }

  /// Update roadmap for an existing blueprint
  Future<RecoveryBlueprint> updateRoadmap(String blueprintId) async {
    final blueprint = await SupabaseConfig.client
        .from(_collectionName)
        .select()
        .eq('id', blueprintId)
        .single()
        .then((data) => RecoveryBlueprint.fromJson(_fromSupabase(data)));

    final roadmap = generateRoadmap(blueprint);

    final updated = RecoveryBlueprint(
      id: blueprint.id,
      userId: blueprint.userId,
      patientProfile: blueprint.patientProfile,
      careTeam: blueprint.careTeam,
      independenceAssessment: blueprint.independenceAssessment,
      homeReadiness: blueprint.homeReadiness,
      dailyRoutines: blueprint.dailyRoutines,
      equipment: blueprint.equipment,
      supplies: blueprint.supplies,
      roadmap: roadmap,
      createdAt: blueprint.createdAt,
      updatedAt: DateTime.now(),
    );

    return await update(updated);
  }

  /// Convert Supabase snake_case to Dart camelCase
  Map<String, dynamic> _fromSupabase(Map<String, dynamic> data) => {
    'id': data['id'],
    'userId': data['user_id'],
    'patientProfile': data['patient_profile'],
    'careTeam': data['care_team'],
    'independenceAssessment': data['independence_assessment'],
    'homeReadiness': data['home_readiness'],
    'dailyRoutines': data['daily_routines'],
    'equipment': data['equipment'],
    'supplies': data['supplies'],
    'roadmap': data['roadmap'],
    'createdAt': data['created_at'],
    'updatedAt': data['updated_at'],
    'updatedBy': data['updated_by'],
  };

  /// Convert Dart camelCase to Supabase snake_case
  Map<String, dynamic> _toSupabase(Map<String, dynamic> data) => {
    'id': data['id'],
    'user_id': data['userId'],
    'patient_profile': data['patientProfile'],
    'care_team': data['careTeam'],
    'independence_assessment': data['independenceAssessment'],
    'home_readiness': data['homeReadiness'],
    'daily_routines': data['dailyRoutines'],
    'equipment': data['equipment'],
    'supplies': data['supplies'],
    'roadmap': data['roadmap'],
    'created_at': data['createdAt'],
    'updated_at': data['updatedAt'],
    if (data['updatedBy'] != null) 'updated_by': data['updatedBy'],
  };

  // ─── Collaboration ─────────────────────────────────────────────────────────

  /// List collaborators on a blueprint, enriched with display name / avatar
  /// from the users table when available.
  Future<List<BlueprintCollaborator>> listCollaborators(String blueprintId) async {
    try {
      final rows = await SupabaseConfig.client
          .from(_collaboratorsTable)
          .select('blueprint_id, user_id, role, added_by, added_at')
          .eq('blueprint_id', blueprintId);

      if (rows.isEmpty) return [];

      // Look up auth_user_id -> profile (name, avatar)
      final userIds = rows.map((r) => r['user_id'] as String).toSet().toList();
      Map<String, Map<String, dynamic>> profilesById = {};
      try {
        final profiles = await SupabaseConfig.client
            .from('users')
            .select('auth_user_id, name, profile_image_url')
            .inFilter('auth_user_id', userIds);
        for (final p in profiles) {
          profilesById[p['auth_user_id'] as String] = Map<String, dynamic>.from(p);
        }
      } catch (e) {
        debugPrint('RecoveryBlueprintService.listCollaborators: profile lookup failed: $e');
      }

      return rows.map((r) {
        final uid = r['user_id'] as String;
        final profile = profilesById[uid];
        return BlueprintCollaborator(
          blueprintId: r['blueprint_id'] as String,
          userId: uid,
          role: r['role'] as String? ?? 'viewer',
          addedBy: r['added_by'] as String?,
          addedAt: DateTime.parse(r['added_at'] as String),
          displayName: profile?['name'] as String?,
          avatarUrl: profile?['profile_image_url'] as String?,
        );
      }).toList();
    } catch (e) {
      debugPrint('RecoveryBlueprintService.listCollaborators error: $e');
      return [];
    }
  }

  /// Add (or upsert) a collaborator. Defaults to viewer.
  Future<void> addCollaborator({
    required String blueprintId,
    required String userId,
    String role = 'viewer',
    String? addedBy,
  }) async {
    try {
      await SupabaseConfig.client.from(_collaboratorsTable).upsert({
        'blueprint_id': blueprintId,
        'user_id': userId,
        'role': role,
        if (addedBy != null) 'added_by': addedBy,
      }, onConflict: 'blueprint_id,user_id');
      debugPrint('RecoveryBlueprintService.addCollaborator: $userId -> $blueprintId ($role)');
    } catch (e) {
      debugPrint('RecoveryBlueprintService.addCollaborator error: $e');
      rethrow;
    }
  }

  /// Change a collaborator's role (owner only via RLS).
  Future<void> updateCollaboratorRole({
    required String blueprintId,
    required String userId,
    required String role,
  }) async {
    try {
      await SupabaseConfig.client
          .from(_collaboratorsTable)
          .update({'role': role})
          .eq('blueprint_id', blueprintId)
          .eq('user_id', userId);
    } catch (e) {
      debugPrint('RecoveryBlueprintService.updateCollaboratorRole error: $e');
      rethrow;
    }
  }

  /// Remove a collaborator (owner can remove anyone; a user can remove self).
  Future<void> removeCollaborator({
    required String blueprintId,
    required String userId,
  }) async {
    try {
      await SupabaseConfig.client
          .from(_collaboratorsTable)
          .delete()
          .eq('blueprint_id', blueprintId)
          .eq('user_id', userId);
    } catch (e) {
      debugPrint('RecoveryBlueprintService.removeCollaborator error: $e');
      rethrow;
    }
  }

  /// Auto-link a family member to a patient's blueprint as a viewer.
  /// No-op if the patient has no blueprint yet, or if already a collaborator.
  /// [patientUserId] is the patient's `auth_user_id`; [familyAuthId] is the
  /// family member's `auth_user_id`.
  Future<void> autoLinkFamilyViewer({
    required String patientUserId,
    required String familyAuthId,
  }) async {
    try {
      final bp = await SupabaseConfig.client
          .from(_collectionName)
          .select('id')
          .eq('user_id', patientUserId)
          .maybeSingle();
      if (bp == null) {
        debugPrint('autoLinkFamilyViewer: no blueprint exists for patient $patientUserId yet');
        return;
      }
      await addCollaborator(
        blueprintId: bp['id'] as String,
        userId: familyAuthId,
        role: 'viewer',
        addedBy: familyAuthId,
      );
    } catch (e) {
      debugPrint('autoLinkFamilyViewer error: $e');
    }
  }

  /// Realtime subscription to UPDATEs on a single blueprint row.
  /// Returns a [RealtimeChannel]; caller must dispose with `unsubscribe()`.
  RealtimeChannel subscribeToBlueprint({
    required String blueprintId,
    required void Function(RecoveryBlueprint) onChange,
  }) {
    final client = SupabaseConfig.client;
    final channel = client.channel('blueprint:$blueprintId');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: _collectionName,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: blueprintId,
          ),
          callback: (payload) {
            try {
              final newRow = payload.newRecord;
              final bp = RecoveryBlueprint.fromJson(
                  _fromSupabase(Map<String, dynamic>.from(newRow)));
              onChange(bp);
            } catch (e) {
              debugPrint('subscribeToBlueprint payload error: $e');
            }
          },
        )
        .subscribe();
    return channel;
  }
}
