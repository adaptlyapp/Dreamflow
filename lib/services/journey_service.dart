import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:wellspring/models/journey_hierarchy.dart';
import 'package:wellspring/models/journey_template.dart';
import 'package:wellspring/models/recovery_domain.dart';
import 'package:wellspring/services/journey_template_library.dart';
import 'package:wellspring/supabase/supabase_config.dart';
import 'package:wellspring/openai/openai_config.dart';

/// Service for managing personalized recovery journeys using ARIE generation
class JourneyService {
  final SupabaseClient _supabase = SupabaseConfig.client;
  static const _uuid = Uuid();

  // ═══════════════════════════════════════════════════════════════
  // ARIE GENERATION: Create Personalized Journey
  // ═══════════════════════════════════════════════════════════════

  /// Generate a personalized recovery pathway for a patient
  Future<void> generatePersonalizedJourney({
    required String userId,
    required String conditionId,
    required PatientProfileInput profile,
  }) async {
    try {
      debugPrint('🤖 ARIE: Generating personalized journey for user $userId');

      // Check if user already has journeys for this condition
      final existingJourneys = await getJourneysForUser(userId);
      final existingForCondition = existingJourneys.where((j) => j.conditionId == conditionId).toList();
      
      if (existingForCondition.isNotEmpty) {
        debugPrint('⚠️ User already has ${existingForCondition.length} journeys for condition $conditionId. Skipping duplicate creation.');
        return;
      }

      // 1. Get relevant templates based on patient profile
      final relevantTemplates = JourneyTemplateLibrary.getRelevantTemplates(profile);
      debugPrint('✓ Found ${relevantTemplates.length} relevant milestone templates');

      // 2. Group templates by domain
      final domainGroups = <String, List<MilestoneTemplate>>{};
      for (final template in relevantTemplates) {
        domainGroups.putIfAbsent(template.domainType, () => []).add(template);
      }
      debugPrint('✓ Grouped into ${domainGroups.length} recovery domains');

      // 3. Create journeys for each domain
      int journeyOrder = 0;
      for (final entry in domainGroups.entries) {
        final domainType = entry.key;
        final templates = entry.value;

        // Create journey
        final journey = Journey(
          id: _uuid.v4(),
          userId: userId,
          conditionId: conditionId,
          title: RecoveryDomainType.fromString(domainType).label,
          description: RecoveryDomainType.fromString(domainType).description,
          domainType: domainType,
          status: JourneyStatus.notStarted,
          order: journeyOrder++,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await _upsertJourney(journey);

        // 4. Create phases for this journey
        final phaseNames = JourneyTemplateLibrary.getPhaseNamesForRecoveryPhase(profile.recoveryPhase);
        int phaseOrder = 0;
        
        for (final phaseName in phaseNames) {
          final phase = Phase(
            id: _uuid.v4(),
            journeyId: journey.id,
            userId: userId,
            title: phaseName,
            description: 'Recovery milestones for $phaseName phase',
            order: phaseOrder++,
            status: JourneyStatus.notStarted,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

          await _upsertPhase(phase);

          // 5. Create milestones for this phase
          final phaseTemplates = templates.where((t) => t.phaseName == phaseName).toList();
          
          for (final template in phaseTemplates) {
            final milestone = await _generateMilestoneFromTemplate(
              template: template,
              phaseId: phase.id,
              userId: userId,
              profile: profile,
            );

            await _upsertMilestone(milestone);

            // 6. Create goals for this milestone
            for (final goalTemplate in template.goalTemplates) {
              final goal = await _generateGoalFromTemplate(
                template: goalTemplate,
                milestoneId: milestone.id,
                userId: userId,
                profile: profile,
              );

              await _upsertGoal(goal);

              // 7. Create tasks for this goal
              for (final taskTemplate in goalTemplate.taskTemplates) {
                final task = await _generateTaskFromTemplate(
                  template: taskTemplate,
                  goalId: goal.id,
                  userId: userId,
                  startDate: DateTime.now(),
                );

                await _upsertTask(task);
              }
            }
          }
        }
      }

      // 8. Create recovery domains summary (only if they don't exist)
      final existingDomains = await getDomainsForUser(userId);
      final existingDomainTypes = existingDomains.map((d) => d.type.name).toSet();
      
      for (final domainType in domainGroups.keys) {
        if (!existingDomainTypes.contains(domainType)) {
          final domain = RecoveryDomain(
            id: _uuid.v4(),
            type: RecoveryDomainType.fromString(domainType),
            userId: userId,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
          await _upsertDomain(domain);
        }
      }

      debugPrint('✅ ARIE: Journey generation complete!');
    } catch (e) {
      debugPrint('❌ JourneyService.generatePersonalizedJourney error: $e');
      rethrow;
    }
  }

  /// Generate milestone from template with optional OpenAI personalization
  Future<JourneyMilestone> _generateMilestoneFromTemplate({
    required MilestoneTemplate template,
    required String phaseId,
    required String userId,
    required PatientProfileInput profile,
  }) async {
    // Personalize title using simple template variable replacement
    String title = template.titleTemplate;
    String? description = template.descriptionTemplate;

    // OpenAI personalization is available but optional
    // You can add personalization later by checking OpenAIConfig from openai/openai_config.dart
    final useAI = false; // Set to true to enable AI personalization
    if (useAI) {
      try {
        final personalized = await _personalizeWithAI(
          title: title,
          description: description,
          profile: profile,
        );
        title = personalized['title'] ?? title;
        description = personalized['description'] ?? description;
      } catch (e) {
        debugPrint('AI personalization failed (using template): $e');
      }
    }

    // Calculate due date based on phase timing
    DateTime? dueDate;
    if (template.priority == 'critical') {
      dueDate = DateTime.now().add(const Duration(days: 7)); // 1 week for critical
    } else if (template.priority == 'high') {
      dueDate = DateTime.now().add(const Duration(days: 30)); // 1 month for high
    }

    return JourneyMilestone(
      id: _uuid.v4(),
      phaseId: phaseId,
      userId: userId,
      title: title,
      description: description,
      order: template.order,
      priority: PriorityLevel.fromString(template.priority),
      status: JourneyStatus.notStarted,
      dueDate: dueDate,
      educationContent: template.educationContent,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  /// Generate goal from template
  Future<JourneyGoal> _generateGoalFromTemplate({
    required GoalTemplate template,
    required String milestoneId,
    required String userId,
    required PatientProfileInput profile,
  }) async {
    String title = template.titleTemplate;
    String? description = template.descriptionTemplate;

    return JourneyGoal(
      id: _uuid.v4(),
      milestoneId: milestoneId,
      userId: userId,
      title: title,
      description: description,
      order: template.order,
      status: JourneyStatus.notStarted,
      targetValue: template.targetValue,
      currentValue: 0,
      unit: template.unit,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  /// Generate task from template
  Future<JourneyTask> _generateTaskFromTemplate({
    required TaskTemplate template,
    required String goalId,
    required String userId,
    required DateTime startDate,
  }) async {
    final dueDate = startDate.add(Duration(days: template.estimatedDaysFromStart));

    return JourneyTask(
      id: _uuid.v4(),
      goalId: goalId,
      userId: userId,
      title: template.titleTemplate,
      description: template.descriptionTemplate,
      order: template.order,
      completed: false,
      dueDate: dueDate,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  /// Personalize milestone text using OpenAI
  Future<Map<String, String>> _personalizeWithAI({
    required String title,
    String? description,
    required PatientProfileInput profile,
  }) async {
    // This would call OpenAI API to personalize the language
    // For now, return original (implementation in separate PR)
    return {
      'title': title,
      'description': description ?? '',
    };
  }

  // ═══════════════════════════════════════════════════════════════
  // DATABASE OPERATIONS
  // ═══════════════════════════════════════════════════════════════

  Future<void> _upsertJourney(Journey journey) async {
    debugPrint('💾 Saving journey: ${journey.title} (conditionId: ${journey.conditionId})');
    await _supabase.from('journeys').upsert({
      'id': journey.id,
      'user_id': journey.userId,
      'condition_id': journey.conditionId,
      'title': journey.title,
      'description': journey.description,
      'domain_type': journey.domainType,
      'status': journey.status.name,
      'order': journey.order,
      'started_at': journey.startedAt?.toIso8601String(),
      'completed_at': journey.completedAt?.toIso8601String(),
      'created_at': journey.createdAt.toIso8601String(),
      'updated_at': journey.updatedAt.toIso8601String(),
    });
    debugPrint('✅ Journey saved successfully');
  }

  Future<void> _upsertPhase(Phase phase) async {
    await _supabase.from('phases').upsert({
      'id': phase.id,
      'journey_id': phase.journeyId,
      'user_id': phase.userId,
      'title': phase.title,
      'description': phase.description,
      'order': phase.order,
      'status': phase.status.name,
      'started_at': phase.startedAt?.toIso8601String(),
      'completed_at': phase.completedAt?.toIso8601String(),
      'created_at': phase.createdAt.toIso8601String(),
      'updated_at': phase.updatedAt.toIso8601String(),
    });
  }

  Future<void> _upsertMilestone(JourneyMilestone milestone) async {
    await _supabase.from('journey_milestones').upsert({
      'id': milestone.id,
      'phase_id': milestone.phaseId,
      'user_id': milestone.userId,
      'title': milestone.title,
      'description': milestone.description,
      'order': milestone.order,
      'priority': milestone.priority.name,
      'status': milestone.status.name,
      'due_date': milestone.dueDate?.toIso8601String(),
      'started_at': milestone.startedAt?.toIso8601String(),
      'completed_at': milestone.completedAt?.toIso8601String(),
      'education_content': milestone.educationContent,
      'created_at': milestone.createdAt.toIso8601String(),
      'updated_at': milestone.updatedAt.toIso8601String(),
    });
  }

  Future<void> _upsertGoal(JourneyGoal goal) async {
    await _supabase.from('journey_goals').upsert({
      'id': goal.id,
      'milestone_id': goal.milestoneId,
      'user_id': goal.userId,
      'title': goal.title,
      'description': goal.description,
      'order': goal.order,
      'status': goal.status.name,
      'target_value': goal.targetValue,
      'current_value': goal.currentValue,
      'unit': goal.unit,
      'started_at': goal.startedAt?.toIso8601String(),
      'completed_at': goal.completedAt?.toIso8601String(),
      'created_at': goal.createdAt.toIso8601String(),
      'updated_at': goal.updatedAt.toIso8601String(),
    });
  }

  Future<void> _upsertTask(JourneyTask task) async {
    await _supabase.from('journey_tasks').upsert({
      'id': task.id,
      'goal_id': task.goalId,
      'user_id': task.userId,
      'title': task.title,
      'description': task.description,
      'order': task.order,
      'completed': task.completed,
      'completed_at': task.completedAt?.toIso8601String(),
      'due_date': task.dueDate?.toIso8601String(),
      'assigned_to': task.assignedTo,
      'created_at': task.createdAt.toIso8601String(),
      'updated_at': task.updatedAt.toIso8601String(),
    });
  }

  Future<void> _upsertDomain(RecoveryDomain domain) async {
    await _supabase.from('recovery_domains').upsert({
      'id': domain.id,
      'type': domain.type.name,
      'user_id': domain.userId,
      'completed_phases': domain.completedPhases,
      'total_phases': domain.totalPhases,
      'last_activity_at': domain.lastActivityAt?.toIso8601String(),
      'created_at': domain.createdAt.toIso8601String(),
      'updated_at': domain.updatedAt.toIso8601String(),
    });
  }

  // ═══════════════════════════════════════════════════════════════
  // RETRIEVAL OPERATIONS
  // ═══════════════════════════════════════════════════════════════

  Future<List<Journey>> getJourneysForUser(String userId) async {
    try {
      debugPrint('🔍 Fetching journeys for user: $userId');
      final data = await _supabase
          .from('journeys')
          .select()
          .eq('user_id', userId)
          .order('order', ascending: true);

      final journeys = data.map<Journey>((item) => Journey.fromJson(item)).toList();
      debugPrint('📦 Found ${journeys.length} journeys');
      for (final j in journeys) {
        debugPrint('  - ${j.title} (conditionId: ${j.conditionId}, status: ${j.status.name})');
      }
      return journeys;
    } catch (e) {
      debugPrint('❌ JourneyService.getJourneysForUser error: $e');
      return [];
    }
  }

  Future<List<Phase>> getPhasesForJourney(String journeyId) async {
    try {
      final data = await _supabase
          .from('phases')
          .select()
          .eq('journey_id', journeyId)
          .order('order', ascending: true);

      return data.map<Phase>((item) => Phase.fromJson(item)).toList();
    } catch (e) {
      debugPrint('JourneyService.getPhasesForJourney error: $e');
      return [];
    }
  }

  Future<List<JourneyMilestone>> getMilestonesForPhase(String phaseId) async {
    try {
      final data = await _supabase
          .from('journey_milestones')
          .select()
          .eq('phase_id', phaseId)
          .order('order', ascending: true);

      return data.map<JourneyMilestone>((item) => JourneyMilestone.fromJson(item)).toList();
    } catch (e) {
      debugPrint('JourneyService.getMilestonesForPhase error: $e');
      return [];
    }
  }

  Future<List<JourneyGoal>> getGoalsForMilestone(String milestoneId) async {
    try {
      final data = await _supabase
          .from('journey_goals')
          .select()
          .eq('milestone_id', milestoneId)
          .order('order', ascending: true);

      return data.map<JourneyGoal>((item) => JourneyGoal.fromJson(item)).toList();
    } catch (e) {
      debugPrint('JourneyService.getGoalsForMilestone error: $e');
      return [];
    }
  }

  Future<List<JourneyTask>> getTasksForGoal(String goalId) async {
    try {
      final data = await _supabase
          .from('journey_tasks')
          .select()
          .eq('goal_id', goalId)
          .order('order', ascending: true);

      return data.map<JourneyTask>((item) => JourneyTask.fromJson(item)).toList();
    } catch (e) {
      debugPrint('JourneyService.getTasksForGoal error: $e');
      return [];
    }
  }

  Future<List<RecoveryDomain>> getDomainsForUser(String userId) async {
    try {
      final data = await _supabase
          .from('recovery_domains')
          .select()
          .eq('user_id', userId)
          .order('type', ascending: true);

      return data.map<RecoveryDomain>((item) => RecoveryDomain.fromJson(item)).toList();
    } catch (e) {
      debugPrint('JourneyService.getDomainsForUser error: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // UPDATE OPERATIONS
  // ═══════════════════════════════════════════════════════════════

  Future<void> updateTaskCompletion(String taskId, bool completed) async {
    try {
      await _supabase.from('journey_tasks').update({
        'completed': completed,
        'completed_at': completed ? DateTime.now().toIso8601String() : null,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', taskId);
    } catch (e) {
      debugPrint('JourneyService.updateTaskCompletion error: $e');
      rethrow;
    }
  }

  Future<void> updateGoalProgress(String goalId, int currentValue) async {
    try {
      await _supabase.from('journey_goals').update({
        'current_value': currentValue,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', goalId);
    } catch (e) {
      debugPrint('JourneyService.updateGoalProgress error: $e');
      rethrow;
    }
  }

  Future<void> updateMilestoneStatus(String milestoneId, JourneyStatus status) async {
    try {
      final updates = <String, dynamic>{
        'status': status.name,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (status == JourneyStatus.inProgress && updates['started_at'] == null) {
        updates['started_at'] = DateTime.now().toIso8601String();
      } else if (status == JourneyStatus.completed) {
        updates['completed_at'] = DateTime.now().toIso8601String();
      }

      await _supabase.from('journey_milestones').update(updates).eq('id', milestoneId);
    } catch (e) {
      debugPrint('JourneyService.updateMilestoneStatus error: $e');
      rethrow;
    }
  }
}
