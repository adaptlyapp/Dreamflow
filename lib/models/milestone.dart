import 'package:cloud_firestore/cloud_firestore.dart';

class Milestone {
  final String id;
  final String userId;
  final String? conditionId; // optional: plan tied to a condition
  final String title;
  final String? description;
  final DateTime? dueDate;
  final bool completed;
  final int order; // for manual ordering
  final DateTime createdAt;
  final DateTime updatedAt;

  const Milestone({
    required this.id,
    required this.userId,
    required this.title,
    this.conditionId,
    this.description,
    this.dueDate,
    this.completed = false,
    this.order = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Milestone.fromJson(Map<String, dynamic> json) => Milestone(
        id: json['id'],
        userId: json['userId'] ?? '',
        conditionId: json['conditionId'],
        title: json['title'] ?? '',
        description: json['description'],
        dueDate: json['dueDate'] == null
            ? null
            : (json['dueDate'] is Timestamp
                ? (json['dueDate'] as Timestamp).toDate()
                : DateTime.tryParse(json['dueDate'])),
        completed: json['completed'] ?? false,
        order: json['order'] ?? 0,
        createdAt: () {
          final ca = json['createdAt'];
          if (ca is Timestamp) return ca.toDate();
          if (ca is String) {
            final d = DateTime.tryParse(ca);
            if (d != null) return d;
          }
          return DateTime.now();
        }(),
        updatedAt: () {
          final ua = json['updatedAt'];
          if (ua is Timestamp) return ua.toDate();
          if (ua is String) {
            final d = DateTime.tryParse(ua);
            if (d != null) return d;
          }
          return DateTime.now();
        }(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'conditionId': conditionId,
        'title': title,
        'description': description,
        'dueDate': dueDate?.toIso8601String(),
        'completed': completed,
        'order': order,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  Milestone copyWith({
    String? title,
    String? description,
    DateTime? dueDate,
    bool? completed,
    int? order,
  }) =>
      Milestone(
        id: id,
        userId: userId,
        conditionId: conditionId,
        title: title ?? this.title,
        description: description ?? this.description,
        dueDate: dueDate ?? this.dueDate,
        completed: completed ?? this.completed,
        order: order ?? this.order,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );
}
