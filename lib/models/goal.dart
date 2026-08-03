import 'package:cloud_firestore/cloud_firestore.dart';

class Goal {
  final String id;
  final String userId;
  final String title;
  final String? description;
  final int targetPerPeriod; // e.g., 4 times per week
  final int progressThisPeriod;
  final String period; // 'weekly' | 'none'
  final DateTime? lastResetAt;
  final String? linkedTrackerKey; // e.g., 'sleep', 'pain', 'bowel'
  final bool active;
  final DateTime createdAt;
  final DateTime updatedAt;

  Goal({
    required this.id,
    required this.userId,
    required this.title,
    this.description,
    required this.targetPerPeriod,
    required this.progressThisPeriod,
    required this.period,
    this.lastResetAt,
    this.linkedTrackerKey,
    this.active = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Goal.fromJson(Map<String, dynamic> json) => Goal(
        id: json['id'],
        userId: json['userId'],
        title: json['title'],
        description: json['description'],
        targetPerPeriod: json['targetPerPeriod'] ?? 0,
        progressThisPeriod: json['progressThisPeriod'] ?? 0,
        period: json['period'] ?? 'none',
        lastResetAt: json['lastResetAt'] != null 
          ? (json['lastResetAt'] is Timestamp 
            ? (json['lastResetAt'] as Timestamp).toDate() 
            : DateTime.parse(json['lastResetAt']))
          : null,
        linkedTrackerKey: json['linkedTrackerKey'],
        active: json['active'] ?? true,
        createdAt: json['createdAt'] is Timestamp 
          ? (json['createdAt'] as Timestamp).toDate() 
          : DateTime.parse(json['createdAt']),
        updatedAt: json['updatedAt'] is Timestamp 
          ? (json['updatedAt'] as Timestamp).toDate() 
          : DateTime.parse(json['updatedAt']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'title': title,
        'description': description,
        'targetPerPeriod': targetPerPeriod,
        'progressThisPeriod': progressThisPeriod,
        'period': period,
        'lastResetAt': lastResetAt?.toIso8601String(),
        'linkedTrackerKey': linkedTrackerKey,
        'active': active,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  Goal copyWith({
    String? title,
    String? description,
    int? targetPerPeriod,
    int? progressThisPeriod,
    String? period,
    DateTime? lastResetAt,
    String? linkedTrackerKey,
    bool? active,
  }) =>
      Goal(
        id: id,
        userId: userId,
        title: title ?? this.title,
        description: description ?? this.description,
        targetPerPeriod: targetPerPeriod ?? this.targetPerPeriod,
        progressThisPeriod: progressThisPeriod ?? this.progressThisPeriod,
        period: period ?? this.period,
        lastResetAt: lastResetAt ?? this.lastResetAt,
        linkedTrackerKey: linkedTrackerKey ?? this.linkedTrackerKey,
        active: active ?? this.active,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );
}
