import 'package:cloud_firestore/cloud_firestore.dart';

class Achievement {
  final String id;
  final String title;
  final String description;
  final String icon; // Material icon name
  final String category; // 'health', 'social', 'learning', 'goals', 'consistency'
  final int tier; // 1 = bronze, 2 = silver, 3 = gold, 4 = platinum
  final int requirement; // number needed to unlock
  final String? condition; // optional condition type
  final DateTime createdAt;

  Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.category,
    required this.tier,
    required this.requirement,
    this.condition,
    required this.createdAt,
  });

  factory Achievement.fromJson(Map<String, dynamic> json) => Achievement(
    id: json['id'],
    title: json['title'],
    description: json['description'],
    icon: json['icon'],
    category: json['category'],
    tier: json['tier'],
    requirement: json['requirement'],
    condition: json['condition'],
    createdAt: json['createdAt'] is Timestamp
        ? (json['createdAt'] as Timestamp).toDate()
        : DateTime.parse(json['createdAt']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'icon': icon,
    'category': category,
    'tier': tier,
    'requirement': requirement,
    if (condition != null) 'condition': condition,
    'createdAt': createdAt.toIso8601String(),
  };
}

class UserAchievement {
  final String id;
  final String userId;
  final String achievementId;
  final int progress;
  final bool unlocked;
  final DateTime? unlockedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserAchievement({
    required this.id,
    required this.userId,
    required this.achievementId,
    required this.progress,
    required this.unlocked,
    this.unlockedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserAchievement.fromJson(Map<String, dynamic> json) => UserAchievement(
    id: json['id'],
    userId: json['userId'],
    achievementId: json['achievementId'],
    progress: json['progress'],
    unlocked: json['unlocked'],
    unlockedAt: json['unlockedAt'] != null
        ? (json['unlockedAt'] is Timestamp
            ? (json['unlockedAt'] as Timestamp).toDate()
            : DateTime.parse(json['unlockedAt']))
        : null,
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
    'achievementId': achievementId,
    'progress': progress,
    'unlocked': unlocked,
    if (unlockedAt != null) 'unlockedAt': unlockedAt!.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  UserAchievement copyWith({
    int? progress,
    bool? unlocked,
    DateTime? unlockedAt,
  }) => UserAchievement(
    id: id,
    userId: userId,
    achievementId: achievementId,
    progress: progress ?? this.progress,
    unlocked: unlocked ?? this.unlocked,
    unlockedAt: unlockedAt ?? this.unlockedAt,
    createdAt: createdAt,
    updatedAt: DateTime.now(),
  );
}
