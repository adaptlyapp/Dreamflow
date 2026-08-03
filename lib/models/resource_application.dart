import 'package:cloud_firestore/cloud_firestore.dart';

class ResourceApplication {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String notes;
  final String status; // pending | approved | rejected
  final String userId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ResourceApplication({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.notes,
    required this.status,
    required this.userId,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        'email': email,
        'phone': phone,
        'notes': notes,
        'status': status,
        'userId': userId,
        'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
        if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
      };

  factory ResourceApplication.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return ResourceApplication(
      id: doc.id,
      name: (data['name'] ?? '') as String,
      email: (data['email'] ?? '') as String,
      phone: (data['phone'] ?? '') as String,
      notes: (data['notes'] ?? '') as String,
      status: (data['status'] ?? 'pending') as String,
      userId: (data['userId'] ?? '') as String,
      createdAt: (data['createdAt'] is Timestamp) ? (data['createdAt'] as Timestamp).toDate() : null,
      updatedAt: (data['updatedAt'] is Timestamp) ? (data['updatedAt'] as Timestamp).toDate() : null,
    );
  }
}
