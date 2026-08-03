import 'package:cloud_firestore/cloud_firestore.dart';

class ResourceReview {
  final String userId;
  final String? userName;
  final int rating; // 1..5
  final String? comment;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ResourceReview({
    required this.userId,
    this.userName,
    required this.rating,
    this.comment,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ResourceReview.fromJson(Map<String, dynamic> json) => ResourceReview(
        userId: json['userId'] as String,
        userName: json['userName'] as String?,
        rating: (json['rating'] as num).toInt(),
        comment: json['comment'] as String?,
        createdAt: json['createdAt'] is Timestamp
            ? (json['createdAt'] as Timestamp).toDate()
            : DateTime.parse(json['createdAt'] as String),
        updatedAt: json['updatedAt'] is Timestamp
            ? (json['updatedAt'] as Timestamp).toDate()
            : DateTime.parse(json['updatedAt'] as String),
      );

  Map<String, dynamic> toJson() => {
        'userId': userId,
        if (userName != null) 'userName': userName,
        'rating': rating,
        if (comment != null && comment!.trim().isNotEmpty) 'comment': comment,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      };
}
