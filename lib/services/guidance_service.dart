import 'package:flutter/foundation.dart';
import 'package:wellspring/models/condition.dart';
import 'package:wellspring/services/tracker_service.dart';

class GoalBadge {
  final String title;
  final String iconName; // material icon name hint
  final String? linkedTrackerKey; // e.g., 'pain', 'energy', 'sleep', 'steps'

  const GoalBadge({
    required this.title,
    required this.iconName,
    this.linkedTrackerKey,
  });
}

class GuidanceService {
  final TrackerService _trackerService = TrackerService();

  String stageLabel(DateTime? diagnosisDate) {
    if (diagnosisDate == null) return 'Getting Started';
    final now = DateTime.now();
    final months = (now.difference(diagnosisDate).inDays / 30).floor().clamp(0, 120);
    if (months < 1) return 'Week 1 · Onboarding';
    if (months < 3) return 'Early Management · Month $months';
    if (months < 6) return 'Building Foundation · Month $months';
    return 'Long‑term Optimization · Month $months';
  }

  List<GoalBadge> topBadgesFor(Condition condition) {
    switch (condition.name.toLowerCase()) {
      case 'multiple sclerosis':
        return const [
          GoalBadge(title: 'Pain Regulation', iconName: 'self_improvement', linkedTrackerKey: 'pain'),
          GoalBadge(title: 'Energy Management', iconName: 'battery_full', linkedTrackerKey: 'energy'),
          GoalBadge(title: 'Cognitive Clarity', iconName: 'psychology', linkedTrackerKey: 'focus'),
          GoalBadge(title: 'Mobility Training', iconName: 'directions_walk', linkedTrackerKey: 'steps'),
        ];
      case 'fibromyalgia':
        return const [
          GoalBadge(title: 'Pain Mapping', iconName: 'stylus_note', linkedTrackerKey: 'pain'),
          GoalBadge(title: 'Sleep Quality', iconName: 'bedtime', linkedTrackerKey: 'sleep'),
          GoalBadge(title: 'Stress Balance', iconName: 'spa', linkedTrackerKey: 'mood'),
        ];
      case 'type 1 diabetes':
        return const [
          GoalBadge(title: 'Glucose Control', iconName: 'monitor_heart', linkedTrackerKey: 'glucose'),
          GoalBadge(title: 'Meal Timing', iconName: 'restaurant', linkedTrackerKey: 'meals'),
          GoalBadge(title: 'Daily Activity', iconName: 'directions_walk', linkedTrackerKey: 'steps'),
        ];
      case 'rheumatoid arthritis':
        return const [
          GoalBadge(title: 'Joint Care', iconName: 'health_and_safety', linkedTrackerKey: 'pain'),
          GoalBadge(title: 'Morning Routine', iconName: 'wb_sunny', linkedTrackerKey: 'stiffness'),
          GoalBadge(title: 'Anti‑inflammation', iconName: 'restaurant', linkedTrackerKey: 'meals'),
        ];
      case 'spinal cord injury':
        return const [
          GoalBadge(title: 'Bladder Routine', iconName: 'water_drop', linkedTrackerKey: 'bladder'),
          GoalBadge(title: 'Skin Checks', iconName: 'visibility', linkedTrackerKey: 'skin'),
          GoalBadge(title: 'PT Sessions', iconName: 'fitness_center', linkedTrackerKey: 'pt'),
        ];
      default:
        return const [
          GoalBadge(title: 'Sleep', iconName: 'bedtime', linkedTrackerKey: 'sleep'),
          GoalBadge(title: 'Energy', iconName: 'battery_full', linkedTrackerKey: 'energy'),
          GoalBadge(title: 'Movement', iconName: 'directions_walk', linkedTrackerKey: 'steps'),
        ];
    }
  }

  Future<String> adviceSnapshot({
    required String userId,
    required Condition condition,
  }) async {
    try {
      final now = DateTime.now();
      final stats = await _trackerService.getStatistics(
        userId,
        now.subtract(const Duration(days: 7)),
        now,
      );

      // Simple heuristic advice using tracker stats + condition daily adjustments
      final tips = <String>[];
      final avgSleep = (stats['avgSleep'] ?? 0).toDouble();
      final avgEnergy = (stats['avgEnergy'] ?? 0).toDouble();
      final avgPain = (stats['avgPain'] ?? 0).toDouble();

      if (avgSleep > 0 && avgSleep < 6.5) {
        tips.add('Try a consistent wind‑down routine to lift sleep quality.');
      }
      if (avgEnergy > 0 && avgEnergy < 5) {
        tips.add('Batch tasks and schedule micro‑breaks to protect energy.');
      }
      if (avgPain >= 6) {
        tips.add('Use heat/ice and gentle mobility to reduce pain spikes.');
      }
      if (tips.isEmpty && condition.dailyAdjustments.isNotEmpty) {
        tips.add(condition.dailyAdjustments.first);
      }

      final stage = stageLabel(null);
      final base = tips.isNotEmpty
          ? tips.first
          : 'Keep steady progress with small, consistent steps.';
      return '💡 $base';
    } catch (e) {
      debugPrint('adviceSnapshot error: $e');
      return '💡 Keep steady progress with small, consistent steps.';
    }
  }
}
