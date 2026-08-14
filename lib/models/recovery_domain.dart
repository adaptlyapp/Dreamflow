/// Recovery domain categories for organizing the patient journey
enum RecoveryDomainType {
  mobility('Mobility', 'Moving and positioning'),
  selfCare('Self-Care', 'Daily living activities'),
  bowelBladder('Bowel & Bladder', 'Continence management'),
  skinIntegrity('Skin Integrity', 'Pressure injury prevention'),
  respiratory('Respiratory', 'Breathing and lung health'),
  cardiovascular('Cardiovascular', 'Heart and circulation'),
  painManagement('Pain Management', 'Comfort and pain control'),
  mental('Mental Health', 'Emotional wellbeing'),
  nutrition('Nutrition', 'Diet and hydration'),
  equipment('Equipment', 'Assistive devices'),
  homeModification('Home Modification', 'Environmental adaptations'),
  advocacy('Advocacy', 'Rights and benefits');

  final String label;
  final String description;
  const RecoveryDomainType(this.label, this.description);

  static RecoveryDomainType fromString(String value) {
    return RecoveryDomainType.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => RecoveryDomainType.mobility,
    );
  }
}

/// A recovery domain with user-specific progress
class RecoveryDomain {
  final String id;
  final RecoveryDomainType type;
  final String userId;
  final int completedPhases;
  final int totalPhases;
  final DateTime? lastActivityAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const RecoveryDomain({
    required this.id,
    required this.type,
    required this.userId,
    this.completedPhases = 0,
    this.totalPhases = 0,
    this.lastActivityAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory RecoveryDomain.fromJson(Map<String, dynamic> json) => RecoveryDomain(
    id: json['id'] ?? '',
    type: RecoveryDomainType.fromString(json['type'] ?? 'mobility'),
    userId: json['userId'] ?? json['user_id'] ?? '',
    completedPhases: json['completedPhases'] ?? json['completed_phases'] ?? 0,
    totalPhases: json['totalPhases'] ?? json['total_phases'] ?? 0,
    lastActivityAt: json['lastActivityAt'] != null || json['last_activity_at'] != null
        ? DateTime.tryParse(json['lastActivityAt'] ?? json['last_activity_at'])
        : null,
    createdAt: DateTime.parse(json['createdAt'] ?? json['created_at'] ?? DateTime.now().toIso8601String()),
    updatedAt: DateTime.parse(json['updatedAt'] ?? json['updated_at'] ?? DateTime.now().toIso8601String()),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'userId': userId,
    'completedPhases': completedPhases,
    'totalPhases': totalPhases,
    if (lastActivityAt != null) 'lastActivityAt': lastActivityAt!.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  double get progressPercentage => totalPhases > 0 ? (completedPhases / totalPhases) : 0.0;
}
