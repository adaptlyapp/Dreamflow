import 'package:wellspring/models/milestone.dart';

class PlanTimeline {
  final String id;
  final String userId;
  final String conditionId;
  final String name;
  final bool isCurrent;
  final List<Milestone> milestones;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PlanTimeline({
    required this.id,
    required this.userId,
    required this.conditionId,
    required this.name,
    this.isCurrent = false,
    this.milestones = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory PlanTimeline.fromJson(Map<String, dynamic> json) {
    final rawMilestones = (json['milestones'] as List?) ?? const [];
    final milestones = rawMilestones
        .whereType<Map<String, dynamic>>()
        .map((m) => Milestone.fromJson(m))
        .toList();

    DateTime parseDate(dynamic value) {
      if (value is DateTime) return value;
      if (value is String) {
        final parsed = DateTime.tryParse(value);
        if (parsed != null) return parsed;
      }
      return DateTime.now();
    }

    return PlanTimeline(
      id: json['id'],
      userId: json['userId'] ?? json['user_id'],
      conditionId: json['conditionId'] ?? json['condition_id'],
      name: json['name'] ?? '',
      isCurrent: json['isCurrent'] ?? json['is_current'] ?? false,
      milestones: milestones,
      createdAt: parseDate(json['createdAt'] ?? json['created_at']),
      updatedAt: parseDate(json['updatedAt'] ?? json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'conditionId': conditionId,
        'name': name,
        'isCurrent': isCurrent,
        'milestones': milestones.map((m) => m.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  PlanTimeline copyWith({
    String? name,
    bool? isCurrent,
    List<Milestone>? milestones,
  }) =>
      PlanTimeline(
        id: id,
        userId: userId,
        conditionId: conditionId,
        name: name ?? this.name,
        isCurrent: isCurrent ?? this.isCurrent,
        milestones: milestones ?? this.milestones,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );
}