import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:wellspring/models/goal.dart';
import 'package:wellspring/models/milestone.dart';
import 'package:wellspring/openai/openai_config.dart';
import 'package:wellspring/services/goal_service.dart';
import 'package:wellspring/services/milestone_service.dart';

/// Creates and persists an "action plan" when a user chooses a specific ARIE
/// recommendation.
///
/// Persistence:
/// - A top-level Goal (period: none)
/// - 4-7 Milestones (helpType aligned with ARIE step helpType)
class ArieActionPlanService {
  static const _uuid = Uuid();
  final OpenAIClient _ai;
  final MilestoneService _milestones;
  final GoalService _goals;

  ArieActionPlanService({
    OpenAIClient? ai,
    MilestoneService? milestones,
    GoalService? goals,
  })  : _ai = ai ?? OpenAIClient(),
        _milestones = milestones ?? MilestoneService(),
        _goals = goals ?? GoalService();

  Future<ArieActionPlan> createPlanFromRecommendation({
    required String userId,
    String? conditionId,
    required String question,
    required ArieResourceRecommendation recommendation,
  }) async {
    final context = {
      'question': question,
      'selectedRecommendation': recommendation.toJson(),
    };
    return _ai.generateActionPlanForSelectedResource(contextJson: jsonEncode(context));
  }

  /// Creates a Goal + Milestones for the plan.
  ///
  /// Returns the created goal id.
  Future<String> persistPlan({
    required String userId,
    String? conditionId,
    required ArieResourceRecommendation recommendation,
    required ArieActionPlan plan,
  }) async {
    final now = DateTime.now();
    final goalId = _uuid.v4();

    final goal = Goal(
      id: goalId,
      userId: userId,
      title: plan.title.trim().isEmpty ? 'Action plan: ${recommendation.name}' : plan.title.trim(),
      description: plan.summary?.trim().isEmpty ?? true
          ? 'Steps to connect with ${recommendation.name}.'
          : plan.summary?.trim(),
      targetPerPeriod: 0,
      progressThisPeriod: 0,
      period: 'none',
      active: true,
      createdAt: now,
      updatedAt: now,
    );

    try {
      await _goals.addGoal(goal);
    } catch (e) {
      debugPrint('ArieActionPlanService.persistPlan: failed creating goal: $e');
      rethrow;
    }

    for (int i = 0; i < plan.steps.length; i++) {
      final step = plan.steps[i];
      final due = step.dueInDays == null ? null : now.add(Duration(days: step.dueInDays!.clamp(0, 3650)));

      final milestone = Milestone(
        id: _uuid.v4(),
        userId: userId,
        conditionId: conditionId,
        title: step.title.trim(),
        description: _buildMilestoneDescription(recommendation, step),
        dueDate: due,
        completed: false,
        order: i,
        helpType: step.helpType,
        createdAt: now,
        updatedAt: now,
      );
      try {
        await _milestones.upsert(milestone);
      } catch (e) {
        debugPrint('ArieActionPlanService.persistPlan: failed milestone upsert: $e');
        // Continue persisting remaining steps; partial plan is better than none.
      }
    }

    return goalId;
  }

  String? _buildMilestoneDescription(ArieResourceRecommendation rec, ArieActionPlanStep step) {
    final parts = <String>[];
    final desc = step.description?.trim();
    if (desc != null && desc.isNotEmpty) parts.add(desc);

    final addr = (rec.universalRecord['location'] ?? rec.details['locationOrServiceArea'] ?? rec.details['location'] ?? rec.details['address'])?.toString();
    if (addr != null && addr.trim().isNotEmpty) parts.add('Location: ${addr.trim()}');

    final phone = (rec.universalRecord['contactInformation'] is Map)
        ? (rec.universalRecord['contactInformation'] as Map)['phone']?.toString()
        : null;
    if (phone != null && phone.trim().isNotEmpty) parts.add('Phone: ${phone.trim()}');

    final website = rec.universalRecord['website']?.toString() ?? rec.details['website']?.toString();
    if (website != null && website.trim().isNotEmpty) parts.add('Website: ${website.trim()}');

    return parts.isEmpty ? null : parts.join('\n');
  }
}
