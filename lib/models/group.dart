import 'package:cloud_firestore/cloud_firestore.dart';

class Group {
  final String id;
  final String name;
  final String description;
  final String? imageUrl;
  final String type;
  final String? relatedCondition;
  final int memberCount;
  final bool isJoined;
  // membershipStatus: null (no membership), 'approved', 'pending'
  final String? membershipStatus;
  // privacy: 'open' | 'private'
  final String privacy;
  final String? ownerId;
  final String? ownerName;
  final DateTime createdAt;
  final DateTime updatedAt;

  Group({
    required this.id,
    required this.name,
    required this.description,
    this.imageUrl,
    required this.type,
    this.relatedCondition,
    required this.memberCount,
    this.isJoined = false,
    this.membershipStatus,
    this.privacy = 'open',
    this.ownerId,
    this.ownerName,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Group.fromJson(Map<String, dynamic> json) => Group(
    id: json['id'],
    name: json['name'],
    description: json['description'],
    imageUrl: json['image_url'] ?? json['imageUrl'],
    type: json['type'],
    relatedCondition: json['related_condition'] ?? json['relatedCondition'],
    memberCount: json['member_count'] ?? json['memberCount'] ?? 0,
    isJoined: json['isJoined'] ?? false,
    membershipStatus: json['membershipStatus'],
    privacy: json['privacy'] ?? 'open',
    ownerId: json['owner_id'] ?? json['ownerId'],
    ownerName: json['owner_name'] ?? json['ownerName'],
    createdAt: json['created_at'] != null 
      ? (json['created_at'] is Timestamp 
        ? (json['created_at'] as Timestamp).toDate() 
        : DateTime.parse(json['created_at']))
      : (json['createdAt'] is Timestamp 
        ? (json['createdAt'] as Timestamp).toDate() 
        : DateTime.parse(json['createdAt'])),
    updatedAt: json['updated_at'] != null
      ? (json['updated_at'] is Timestamp 
        ? (json['updated_at'] as Timestamp).toDate() 
        : DateTime.parse(json['updated_at']))
      : (json['updatedAt'] is Timestamp 
        ? (json['updatedAt'] as Timestamp).toDate() 
        : DateTime.parse(json['updatedAt'])),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'imageUrl': imageUrl,
    'type': type,
    'relatedCondition': relatedCondition,
    'memberCount': memberCount,
    'isJoined': isJoined,
    'membershipStatus': membershipStatus,
    'privacy': privacy,
    'ownerId': ownerId,
    'ownerName': ownerName,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  Group copyWith({
    bool? isJoined,
    int? memberCount,
    String? membershipStatus,
  }) => Group(
    id: id,
    name: name,
    description: description,
    imageUrl: imageUrl,
    type: type,
    relatedCondition: relatedCondition,
    memberCount: memberCount ?? this.memberCount,
    isJoined: isJoined ?? this.isJoined,
    membershipStatus: membershipStatus ?? this.membershipStatus,
    privacy: privacy,
    ownerId: ownerId,
    ownerName: ownerName,
    createdAt: createdAt,
    updatedAt: DateTime.now(),
  );
}
