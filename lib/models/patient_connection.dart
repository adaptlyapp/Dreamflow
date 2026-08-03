/// Represents a connection between a family member and a patient
class PatientConnection {
  final String id;
  final String familyMemberId;
  final String patientId;
  final String patientName;
  final String? patientProfileImageUrl;
  final String? patientCode; // Store the patient code for re-login
  final String relationship; // Parent, Spouse, Sibling, Child, Friend, Caregiver, Other
  final bool isActive;
  final DateTime connectedAt;
  final DateTime updatedAt;

  PatientConnection({
    required this.id,
    required this.familyMemberId,
    required this.patientId,
    required this.patientName,
    this.patientProfileImageUrl,
    this.patientCode,
    required this.relationship,
    this.isActive = true,
    required this.connectedAt,
    required this.updatedAt,
  });

  factory PatientConnection.fromJson(Map<String, dynamic> json) => PatientConnection(
    id: json['id'],
    familyMemberId: json['familyMemberId'],
    patientId: json['patientId'],
    patientName: json['patientName'],
    patientProfileImageUrl: json['patientProfileImageUrl'],
    patientCode: json['patientCode'],
    relationship: json['relationship'],
    isActive: (json['isActive'] as bool?) ?? true,
    connectedAt: DateTime.parse(json['connectedAt']),
    updatedAt: DateTime.parse(json['updatedAt']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'familyMemberId': familyMemberId,
    'patientId': patientId,
    'patientName': patientName,
    'patientProfileImageUrl': patientProfileImageUrl,
    'patientCode': patientCode,
    'relationship': relationship,
    'isActive': isActive,
    'connectedAt': connectedAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  PatientConnection copyWith({
    String? patientName,
    String? patientProfileImageUrl,
    String? patientCode,
    String? relationship,
    bool? isActive,
  }) => PatientConnection(
    id: id,
    familyMemberId: familyMemberId,
    patientId: patientId,
    patientName: patientName ?? this.patientName,
    patientProfileImageUrl: patientProfileImageUrl ?? this.patientProfileImageUrl,
    patientCode: patientCode ?? this.patientCode,
    relationship: relationship ?? this.relationship,
    isActive: isActive ?? this.isActive,
    connectedAt: connectedAt,
    updatedAt: DateTime.now(),
  );
}
