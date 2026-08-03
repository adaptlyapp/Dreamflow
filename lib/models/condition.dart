import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:wellspring/models/condition_detail.dart';

class Condition {
  final String id;
  final String name;
  final String description;
  final List<String> symptoms;
  final List<String> dailyAdjustments;
  final List<String> resources;
  final bool aiGenerated;
  final ConditionTimeline timeline;
  final List<String> relatedGroups;
  /// User-specific details for this condition (mobility, injury level, devices, etc.).
  ///
  /// This is NOT part of the condition catalog itself; it is typically hydrated
  /// from the signed-in user's preferences.
  final ConditionDetail? userDetail;
  final DateTime createdAt;
  final DateTime updatedAt;

  Condition({
    required this.id,
    required this.name,
    required this.description,
    required this.symptoms,
    required this.dailyAdjustments,
    required this.resources,
    required this.aiGenerated,
    required this.timeline,
    required this.relatedGroups,
    this.userDetail,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Condition.fromJson(Map<String, dynamic> json) => Condition(
    id: json['id'],
    name: json['name'],
    description: json['description'],
    symptoms: List<String>.from(json['symptoms'] ?? []),
    dailyAdjustments: List<String>.from(json['dailyAdjustments'] ?? []),
    resources: List<String>.from(json['resources'] ?? []),
    aiGenerated: json['aiGenerated'] ?? false,
    timeline: ConditionTimeline.fromJson(json['timeline'] ?? {}),
    relatedGroups: List<String>.from(json['relatedGroups'] ?? []),
    userDetail: json['userDetail'] != null
        ? ConditionDetail.fromJson(Map<String, dynamic>.from(json['userDetail']))
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
    'name': name,
    'description': description,
    'symptoms': symptoms,
    'dailyAdjustments': dailyAdjustments,
    'resources': resources,
    'aiGenerated': aiGenerated,
    'timeline': timeline.toJson(),
    'relatedGroups': relatedGroups,
    if (userDetail != null) 'userDetail': userDetail!.toJson(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  Condition copyWith({
    String? id,
    String? name,
    String? description,
    List<String>? symptoms,
    List<String>? dailyAdjustments,
    List<String>? resources,
    bool? aiGenerated,
    ConditionTimeline? timeline,
    List<String>? relatedGroups,
    ConditionDetail? userDetail,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Condition(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description ?? this.description,
    symptoms: symptoms ?? this.symptoms,
    dailyAdjustments: dailyAdjustments ?? this.dailyAdjustments,
    resources: resources ?? this.resources,
    aiGenerated: aiGenerated ?? this.aiGenerated,
    timeline: timeline ?? this.timeline,
    relatedGroups: relatedGroups ?? this.relatedGroups,
    userDetail: userDetail ?? this.userDetail,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}

class ConditionTimeline {
  final String week1;
  final String month1;
  final String month3;
  final String longTerm;

  ConditionTimeline({
    required this.week1,
    required this.month1,
    required this.month3,
    required this.longTerm,
  });

  factory ConditionTimeline.fromJson(Map<String, dynamic> json) => ConditionTimeline(
    week1: json['week1'] ?? '',
    month1: json['month1'] ?? '',
    month3: json['month3'] ?? '',
    longTerm: json['longTerm'] ?? '',
  );

  Map<String, dynamic> toJson() => {
    'week1': week1,
    'month1': month1,
    'month3': month3,
    'longTerm': longTerm,
  };
}
