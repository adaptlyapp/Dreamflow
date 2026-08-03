import 'package:cloud_firestore/cloud_firestore.dart';

class Post {
  final String id;
  final String authorId;
  final String authorName;
  final String? authorImageUrl;
  final String content;
  // Deprecated: use mediaUrl + mediaType instead
  final String? imageUrl;
  // New media fields
  final String? mediaUrl; // image or video URL
  final String? mediaType; // 'image' | 'video'
  // Optional: community this post belongs to
  final String? communityId;
  final String type;
  final List<String> relatedConditions;
  final int likesCount;
  final int commentsCount;
  final bool isLiked;
  final DateTime createdAt;
  final DateTime updatedAt;

  Post({
    required this.id,
    required this.authorId,
    required this.authorName,
    this.authorImageUrl,
    required this.content,
    this.imageUrl,
    this.mediaUrl,
    this.mediaType,
    this.communityId,
    required this.type,
    required this.relatedConditions,
    required this.likesCount,
    required this.commentsCount,
    this.isLiked = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Post.fromJson(Map<String, dynamic> json) => Post(
    id: json['id'],
    authorId: json['author_id'] ?? json['authorId'],
    authorName: json['author_name'] ?? json['authorName'],
    authorImageUrl: json['author_image_url'] ?? json['authorImageUrl'],
    content: json['content'],
    imageUrl: json['image_url'] ?? json['imageUrl'],
    mediaUrl: json['media_url'] ?? json['mediaUrl'] ?? json['image_url'] ?? json['imageUrl'],
    mediaType: json['media_type'] ?? json['mediaType'] ?? (json['imageUrl'] != null ? 'image' : null),
    communityId: json['community_id'] ?? json['communityId'],
    type: json['type'],
    relatedConditions: List<String>.from(json['related_conditions'] ?? json['relatedConditions'] ?? []),
    likesCount: json['likes_count'] ?? json['likesCount'] ?? 0,
    commentsCount: json['comments_count'] ?? json['commentsCount'] ?? 0,
    isLiked: json['is_liked'] ?? json['isLiked'] ?? false,
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
    'author_id': authorId,
    'author_name': authorName,
    'author_image_url': authorImageUrl,
    'content': content,
    'image_url': imageUrl,
    'media_url': mediaUrl,
    'media_type': mediaType,
    'community_id': communityId,
    'type': type,
    'related_conditions': relatedConditions,
    'likes_count': likesCount,
    'comments_count': commentsCount,
    'is_liked': isLiked,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  Post copyWith({
    int? likesCount,
    int? commentsCount,
    bool? isLiked,
  }) => Post(
    id: id,
    authorId: authorId,
    authorName: authorName,
    authorImageUrl: authorImageUrl,
    content: content,
    imageUrl: imageUrl,
    mediaUrl: mediaUrl,
    mediaType: mediaType,
    communityId: communityId,
    type: type,
    relatedConditions: relatedConditions,
    likesCount: likesCount ?? this.likesCount,
    commentsCount: commentsCount ?? this.commentsCount,
    isLiked: isLiked ?? this.isLiked,
    createdAt: createdAt,
    updatedAt: DateTime.now(),
  );
}
