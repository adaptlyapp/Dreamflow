
import 'package:wellspring/models/medication.dart';

/// User role in the system
enum UserRole {
  patient('patient'),
  family('family');

  final String value;
  const UserRole(this.value);

  static UserRole fromString(String value) {
    switch (value.toLowerCase()) {
      case 'family': return UserRole.family;
      case 'patient':
      default: return UserRole.patient;
    }
  }
}

class User {
  final String id;
  final String name;
  final String email;
  final String? profileImageUrl;
  final String? patientCode; // Short code tied to selected hospital for lookup
  /// User role: patient or family member
  final UserRole role;
  /// Whether the user finished the onboarding questionnaire.
  /// Defaults to true for legacy users (missing field) to avoid blocking them.
  final bool onboardingCompleted;
  final List<String> conditions;
  final DateTime? diagnosisDate;
  final List<String> interests;
  final List<Medication> medications;
  final Map<String, dynamic> preferences;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // Notification preferences helper getters
  bool get notificationsEnabled => 
    (preferences['notificationsEnabled'] as bool?) ?? true;
  bool get socialNotificationsEnabled => 
    (preferences['socialNotificationsEnabled'] as bool?) ?? true;
  bool get achievementNotificationsEnabled => 
    (preferences['achievementNotificationsEnabled'] as bool?) ?? true;
  bool get familyAlertsEnabled => 
    (preferences['familyAlertsEnabled'] as bool?) ?? true;
  bool get medicationRemindersEnabled => 
    (preferences['medicationRemindersEnabled'] as bool?) ?? true;
  bool get goalRemindersEnabled => 
    (preferences['goalRemindersEnabled'] as bool?) ?? true;
  bool get milestoneRemindersEnabled => 
    (preferences['milestoneRemindersEnabled'] as bool?) ?? true;

  User({
    required this.id,
    required this.name,
    required this.email,
    this.profileImageUrl,
    this.patientCode,
    this.role = UserRole.patient,
    this.onboardingCompleted = true,
    required this.conditions,
    this.diagnosisDate,
    required this.interests,
    this.medications = const [],
    required this.preferences,
    required this.createdAt,
    required this.updatedAt,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['id'],
    name: json['name'],
    email: json['email'],
    profileImageUrl: json['profileImageUrl'],
    patientCode: json['patientCode'],
    role: json['role'] != null ? UserRole.fromString(json['role']) : UserRole.patient,
    onboardingCompleted: (json['onboardingCompleted'] as bool?) ?? true,
    conditions: List<String>.from(json['conditions'] ?? []),
    diagnosisDate: json['diagnosisDate'] != null 
      ? DateTime.parse(json['diagnosisDate'])
      : null,
    interests: List<String>.from(json['interests'] ?? []),
    medications: (json['medications'] as List<dynamic>?)
        ?.map((m) => Medication.fromJson(Map<String, dynamic>.from(m)))
        .toList() ?? [],
    preferences: Map<String, dynamic>.from(json['preferences'] ?? {}),
    createdAt: DateTime.parse(json['createdAt']),
    updatedAt: DateTime.parse(json['updatedAt']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'profileImageUrl': profileImageUrl,
    if (patientCode != null) 'patientCode': patientCode,
    'role': role.value,
    'onboardingCompleted': onboardingCompleted,
    'conditions': conditions,
    'diagnosisDate': diagnosisDate?.toIso8601String(),
    'interests': interests,
    'medications': medications.map((m) => m.toJson()).toList(),
    'preferences': preferences,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  User copyWith({
    String? name,
    String? email,
    String? profileImageUrl,
    String? patientCode,
    UserRole? role,
    bool? onboardingCompleted,
    List<String>? conditions,
    DateTime? diagnosisDate,
    List<String>? interests,
    List<Medication>? medications,
    Map<String, dynamic>? preferences,
  }) => User(
    id: id,
    name: name ?? this.name,
    email: email ?? this.email,
    profileImageUrl: profileImageUrl ?? this.profileImageUrl,
    patientCode: patientCode ?? this.patientCode,
    role: role ?? this.role,
    onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
    conditions: conditions ?? this.conditions,
    diagnosisDate: diagnosisDate ?? this.diagnosisDate,
    interests: interests ?? this.interests,
    medications: medications ?? this.medications,
    preferences: preferences ?? this.preferences,
    createdAt: createdAt,
    updatedAt: DateTime.now(),
  );
}
