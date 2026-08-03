import 'package:cloud_firestore/cloud_firestore.dart';

class Comment {
  final String id;
  final String postId;
  final String authorId;
  final String authorName;
  final String? authorImageUrl;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;

  Comment({
    required this.id,
    required this.postId,
    required this.authorId,
    required this.authorName,
    this.authorImageUrl,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Comment.fromJson(Map<String, dynamic> json) => Comment(
    id: json['id'],
    postId: json['post_id'] ?? json['postId'],
    authorId: json['author_id'] ?? json['authorId'],
    authorName: json['author_name'] ?? json['authorName'],
    authorImageUrl: json['author_image_url'] ?? json['authorImageUrl'],
    content: json['content'],
    createdAt: json['created_at'] is Timestamp 
      ? (json['created_at'] as Timestamp).toDate() 
      : (json['createdAt'] is Timestamp 
        ? (json['createdAt'] as Timestamp).toDate()
        : DateTime.parse(json['created_at'] ?? json['createdAt'])),
    updatedAt: json['updated_at'] is Timestamp 
      ? (json['updated_at'] as Timestamp).toDate() 
      : (json['updatedAt'] is Timestamp 
        ? (json['updatedAt'] as Timestamp).toDate()
        : DateTime.parse(json['updated_at'] ?? json['updatedAt'])),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'post_id': postId,
    'author_id': authorId,
    'author_name': authorName,
    'author_image_url': authorImageUrl,
    'content': content,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };
}
