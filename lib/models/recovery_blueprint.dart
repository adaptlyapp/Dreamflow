import 'package:cloud_firestore/cloud_firestore.dart';

/// Recovery phase for patient classification
enum RecoveryPhase {
  acute('Acute'),
  postDischarge('Post-Discharge'),
  outpatient('Outpatient'),
  longTerm('Long-Term');

  final String label;
  const RecoveryPhase(this.label);

  static RecoveryPhase fromString(String value) {
    switch (value.toLowerCase()) {
      case 'acute': return RecoveryPhase.acute;
      case 'postdischarge':
      case 'post-discharge': return RecoveryPhase.postDischarge;
      case 'outpatient': return RecoveryPhase.outpatient;
      case 'longterm':
      case 'long-term': return RecoveryPhase.longTerm;
      default: return RecoveryPhase.postDischarge;
    }
  }
}

/// Independence level scale
enum IndependenceLevel {
  independent('Independent'),
  needsReminders('Needs Reminders'),
  needsAssistance('Needs Assistance'),
  fullyDependent('Fully Dependent');

  final String label;
  const IndependenceLevel(this.label);

  static IndependenceLevel fromString(String value) {
    switch (value.toLowerCase()) {
      case 'independent': return IndependenceLevel.independent;
      case 'needsreminders':
      case 'needs reminders': return IndependenceLevel.needsReminders;
      case 'needsassistance':
      case 'needs assistance': return IndependenceLevel.needsAssistance;
      case 'fullydependent':
      case 'fully dependent': return IndependenceLevel.fullyDependent;
      default: return IndependenceLevel.needsAssistance;
    }
  }
}

/// Patient profile information
class PatientProfile {
  final String primaryDiagnosis;
  final List<String> secondaryDiagnoses;
  final DateTime? dateOfInjury;
  final RecoveryPhase recoveryPhase;
  final String? functionalClassification; // e.g., "C4 ASIA A"
  final List<String> therapyGoals;
  final List<String> physicianRestrictions;

  const PatientProfile({
    required this.primaryDiagnosis,
    this.secondaryDiagnoses = const [],
    this.dateOfInjury,
    required this.recoveryPhase,
    this.functionalClassification,
    this.therapyGoals = const [],
    this.physicianRestrictions = const [],
  });

  factory PatientProfile.fromJson(Map<String, dynamic> json) => PatientProfile(
    primaryDiagnosis: json['primaryDiagnosis'] ?? '',
    secondaryDiagnoses: List<String>.from(json['secondaryDiagnoses'] ?? []),
    dateOfInjury: json['dateOfInjury'] != null
        ? (json['dateOfInjury'] is Timestamp
            ? (json['dateOfInjury'] as Timestamp).toDate()
            : DateTime.parse(json['dateOfInjury']))
        : null,
    recoveryPhase: RecoveryPhase.fromString(json['recoveryPhase'] ?? 'postDischarge'),
    functionalClassification: json['functionalClassification'],
    therapyGoals: List<String>.from(json['therapyGoals'] ?? []),
    physicianRestrictions: List<String>.from(json['physicianRestrictions'] ?? []),
  );

  Map<String, dynamic> toJson() => {
    'primaryDiagnosis': primaryDiagnosis,
    'secondaryDiagnoses': secondaryDiagnoses,
    if (dateOfInjury != null) 'dateOfInjury': dateOfInjury!.toIso8601String(),
    'recoveryPhase': recoveryPhase.name,
    if (functionalClassification != null) 'functionalClassification': functionalClassification,
    'therapyGoals': therapyGoals,
    'physicianRestrictions': physicianRestrictions,
  };
}

/// Time slot with activities
class TimeSlot {
  final String period; // 'morning', 'afternoon', 'evening', 'overnight'
  final List<String> activities; // What they'll do during this time

  const TimeSlot({
    required this.period,
    this.activities = const [],
  });

  factory TimeSlot.fromJson(Map<String, dynamic> json) => TimeSlot(
    period: json['period'] ?? '',
    activities: List<String>.from(json['activities'] ?? []),
  );

  Map<String, dynamic> toJson() => {
    'period': period,
    'activities': activities,
  };
}

/// Care team member with roles and availability
class CareTeamMember {
  final String id;
  final String name;
  final String relationship;
  final String? phone;
  final String? email;
  final List<String> roles; // e.g., 'primary_caregiver', 'transportation', 'medication_manager'
  final Map<String, List<String>> availability; // date -> ['morning', 'afternoon', 'evening', 'overnight'] (backward compat)
  final Map<String, List<TimeSlot>> schedule; // date -> [TimeSlot(period, activities)]

  const CareTeamMember({
    required this.id,
    required this.name,
    required this.relationship,
    this.phone,
    this.email,
    this.roles = const [],
    this.availability = const {},
    this.schedule = const {},
  });

  factory CareTeamMember.fromJson(Map<String, dynamic> json) => CareTeamMember(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    relationship: json['relationship'] ?? '',
    phone: json['phone'],
    email: json['email'],
    roles: List<String>.from(json['roles'] ?? []),
    availability: (json['availability'] as Map<String, dynamic>?)?.map(
      (k, v) => MapEntry(k, List<String>.from(v as List)),
    ) ?? {},
    schedule: (json['schedule'] as Map<String, dynamic>?)?.map(
      (k, v) => MapEntry(k, (v as List).map((e) => TimeSlot.fromJson(e as Map<String, dynamic>)).toList()),
    ) ?? {},
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'relationship': relationship,
    if (phone != null) 'phone': phone,
    if (email != null) 'email': email,
    'roles': roles,
    'availability': availability,
    'schedule': schedule.map((k, v) => MapEntry(k, v.map((e) => e.toJson()).toList())),
  };
}

/// Independence assessment for cognitive and physical capabilities
class IndependenceAssessment {
  final Map<String, IndependenceLevel> cognitive; // 'decisions', 'instructions', 'communication', 'phone', 'appointments'
  final Map<String, IndependenceLevel> physical; // 'transfer', 'dress', 'bathe', 'toilet', 'feed', 'mobility', 'drive'

  const IndependenceAssessment({
    this.cognitive = const {},
    this.physical = const {},
  });

  factory IndependenceAssessment.fromJson(Map<String, dynamic> json) => IndependenceAssessment(
    cognitive: (json['cognitive'] as Map<String, dynamic>?)?.map(
      (k, v) => MapEntry(k, IndependenceLevel.fromString(v.toString())),
    ) ?? {},
    physical: (json['physical'] as Map<String, dynamic>?)?.map(
      (k, v) => MapEntry(k, IndependenceLevel.fromString(v.toString())),
    ) ?? {},
  );

  Map<String, dynamic> toJson() => {
    'cognitive': cognitive.map((k, v) => MapEntry(k, v.name)),
    'physical': physical.map((k, v) => MapEntry(k, v.name)),
  };
}

/// Home readiness checklist and action items
class HomeReadiness {
  final Map<String, bool> checklist; // e.g., 'ramp_available', 'grab_bars', 'shower_chair'
  final List<ActionItem> actionItems;

  const HomeReadiness({
    this.checklist = const {},
    this.actionItems = const [],
  });

  factory HomeReadiness.fromJson(Map<String, dynamic> json) => HomeReadiness(
    checklist: (json['checklist'] as Map<String, dynamic>?)?.map(
      (k, v) => MapEntry(k, v as bool),
    ) ?? {},
    actionItems: (json['actionItems'] as List?)?.map((e) => ActionItem.fromJson(e)).toList() ?? [],
  );

  Map<String, dynamic> toJson() => {
    'checklist': checklist,
    'actionItems': actionItems.map((e) => e.toJson()).toList(),
  };
}

/// Action item with assignment and timeline
class ActionItem {
  final String id;
  final String description;
  final String? assignedTo; // CareTeamMember ID
  final DateTime? estimatedCompletion;
  final bool completed;

  const ActionItem({
    required this.id,
    required this.description,
    this.assignedTo,
    this.estimatedCompletion,
    this.completed = false,
  });

  factory ActionItem.fromJson(Map<String, dynamic> json) => ActionItem(
    id: json['id'] ?? '',
    description: json['description'] ?? '',
    assignedTo: json['assignedTo'],
    estimatedCompletion: json['estimatedCompletion'] != null
        ? (json['estimatedCompletion'] is Timestamp
            ? (json['estimatedCompletion'] as Timestamp).toDate()
            : DateTime.parse(json['estimatedCompletion']))
        : null,
    completed: json['completed'] ?? false,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'description': description,
    if (assignedTo != null) 'assignedTo': assignedTo,
    if (estimatedCompletion != null) 'estimatedCompletion': estimatedCompletion!.toIso8601String(),
    'completed': completed,
  };
}

/// Daily care routine (bowel, bladder, therapy, etc.)
class DailyRoutine {
  final String type; // 'bowel', 'bladder', 'skin_check', 'therapy', 'nutrition'
  final List<String> daysPerformed; // ['monday', 'wednesday', 'friday']
  final List<String> timesOfDay; // e.g., ['8:00 AM', '12:00 PM', '6:00 PM']
  final List<String> suppliesNeeded;
  final String? assignedCaregiverId;

  const DailyRoutine({
    required this.type,
    this.daysPerformed = const [],
    this.timesOfDay = const [],
    this.suppliesNeeded = const [],
    this.assignedCaregiverId,
  });

  factory DailyRoutine.fromJson(Map<String, dynamic> json) {
    // Support both old single timeOfDay and new timesOfDay array
    List<String> times = [];
    if (json['timesOfDay'] != null) {
      times = List<String>.from(json['timesOfDay']);
    } else if (json['timeOfDay'] != null) {
      // Migrate old single time to array
      times = [json['timeOfDay']];
    }
    
    return DailyRoutine(
      type: json['type'] ?? '',
      daysPerformed: List<String>.from(json['daysPerformed'] ?? []),
      timesOfDay: times,
      suppliesNeeded: List<String>.from(json['suppliesNeeded'] ?? []),
      assignedCaregiverId: json['assignedCaregiverId'],
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type,
    'daysPerformed': daysPerformed,
    'timesOfDay': timesOfDay,
    'suppliesNeeded': suppliesNeeded,
    if (assignedCaregiverId != null) 'assignedCaregiverId': assignedCaregiverId,
  };
}

/// Durable medical equipment item
class EquipmentItem {
  final String id;
  final String name;
  final String? vendor;
  final String? serialNumber;
  final DateTime? maintenanceSchedule;
  final String? insuranceInfo;
  final DateTime? replacementDate;

  const EquipmentItem({
    required this.id,
    required this.name,
    this.vendor,
    this.serialNumber,
    this.maintenanceSchedule,
    this.insuranceInfo,
    this.replacementDate,
  });

  factory EquipmentItem.fromJson(Map<String, dynamic> json) => EquipmentItem(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    vendor: json['vendor'],
    serialNumber: json['serialNumber'],
    maintenanceSchedule: json['maintenanceSchedule'] != null
        ? (json['maintenanceSchedule'] is Timestamp
            ? (json['maintenanceSchedule'] as Timestamp).toDate()
            : DateTime.parse(json['maintenanceSchedule']))
        : null,
    insuranceInfo: json['insuranceInfo'],
    replacementDate: json['replacementDate'] != null
        ? (json['replacementDate'] is Timestamp
            ? (json['replacementDate'] as Timestamp).toDate()
            : DateTime.parse(json['replacementDate']))
        : null,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    if (vendor != null) 'vendor': vendor,
    if (serialNumber != null) 'serialNumber': serialNumber,
    if (maintenanceSchedule != null) 'maintenanceSchedule': maintenanceSchedule!.toIso8601String(),
    if (insuranceInfo != null) 'insuranceInfo': insuranceInfo,
    if (replacementDate != null) 'replacementDate': replacementDate!.toIso8601String(),
  };
}

/// Supply inventory item with usage tracking
class SupplyItem {
  final String id;
  final String name;
  final String category; // 'bowel', 'bladder', 'skin', 'general'
  final int currentQuantity;
  final int monthlyUsage;
  final int reorderThreshold;
  final String? supplier;

  const SupplyItem({
    required this.id,
    required this.name,
    required this.category,
    this.currentQuantity = 0,
    this.monthlyUsage = 0,
    this.reorderThreshold = 0,
    this.supplier,
  });

  factory SupplyItem.fromJson(Map<String, dynamic> json) => SupplyItem(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    category: json['category'] ?? '',
    currentQuantity: json['currentQuantity'] ?? 0,
    monthlyUsage: json['monthlyUsage'] ?? 0,
    reorderThreshold: json['reorderThreshold'] ?? 0,
    supplier: json['supplier'],
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'category': category,
    'currentQuantity': currentQuantity,
    'monthlyUsage': monthlyUsage,
    'reorderThreshold': reorderThreshold,
    if (supplier != null) 'supplier': supplier,
  };

  bool get needsReorder => currentQuantity <= reorderThreshold;
  int get daysRemaining => monthlyUsage > 0 ? (currentQuantity / (monthlyUsage / 30)).floor() : 999;
}

/// Recovery roadmap with priorities
class RecoveryRoadmap {
  final List<String> immediatePriorities; // Next 7 days
  final List<String> shortTermGoals; // Next 30 days
  final List<String> longTermGoals; // 90+ days
  final List<String> warnings; // Coverage gaps, missing items, etc.

  const RecoveryRoadmap({
    this.immediatePriorities = const [],
    this.shortTermGoals = const [],
    this.longTermGoals = const [],
    this.warnings = const [],
  });

  factory RecoveryRoadmap.fromJson(Map<String, dynamic> json) => RecoveryRoadmap(
    immediatePriorities: List<String>.from(json['immediatePriorities'] ?? []),
    shortTermGoals: List<String>.from(json['shortTermGoals'] ?? []),
    longTermGoals: List<String>.from(json['longTermGoals'] ?? []),
    warnings: List<String>.from(json['warnings'] ?? []),
  );

  Map<String, dynamic> toJson() => {
    'immediatePriorities': immediatePriorities,
    'shortTermGoals': shortTermGoals,
    'longTermGoals': longTermGoals,
    'warnings': warnings,
  };
}

/// Main Recovery Blueprint model
class RecoveryBlueprint {
  final String id;
  final String userId;
  final PatientProfile patientProfile;
  final List<CareTeamMember> careTeam;
  final IndependenceAssessment independenceAssessment;
  final HomeReadiness homeReadiness;
  final List<DailyRoutine> dailyRoutines;
  final List<EquipmentItem> equipment;
  final List<SupplyItem> supplies;
  final RecoveryRoadmap? roadmap; // Generated
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? updatedBy; // auth user id of last editor (collaborative)

  const RecoveryBlueprint({
    required this.id,
    required this.userId,
    required this.patientProfile,
    this.careTeam = const [],
    required this.independenceAssessment,
    required this.homeReadiness,
    this.dailyRoutines = const [],
    this.equipment = const [],
    this.supplies = const [],
    this.roadmap,
    required this.createdAt,
    required this.updatedAt,
    this.updatedBy,
  });

  factory RecoveryBlueprint.fromJson(Map<String, dynamic> json) => RecoveryBlueprint(
    id: json['id'] ?? '',
    userId: json['userId'] ?? '',
    patientProfile: PatientProfile.fromJson(json['patientProfile'] ?? {}),
    careTeam: (json['careTeam'] as List?)?.map((e) => CareTeamMember.fromJson(e)).toList() ?? [],
    independenceAssessment: IndependenceAssessment.fromJson(json['independenceAssessment'] ?? {}),
    homeReadiness: HomeReadiness.fromJson(json['homeReadiness'] ?? {}),
    dailyRoutines: (json['dailyRoutines'] as List?)?.map((e) => DailyRoutine.fromJson(e)).toList() ?? [],
    equipment: (json['equipment'] as List?)?.map((e) => EquipmentItem.fromJson(e)).toList() ?? [],
    supplies: (json['supplies'] as List?)?.map((e) => SupplyItem.fromJson(e)).toList() ?? [],
    roadmap: json['roadmap'] != null ? RecoveryRoadmap.fromJson(json['roadmap']) : null,
    createdAt: json['createdAt'] is Timestamp
        ? (json['createdAt'] as Timestamp).toDate()
        : DateTime.parse(json['createdAt']),
    updatedAt: json['updatedAt'] is Timestamp
        ? (json['updatedAt'] as Timestamp).toDate()
        : DateTime.parse(json['updatedAt']),
    updatedBy: json['updatedBy'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'patientProfile': patientProfile.toJson(),
    'careTeam': careTeam.map((e) => e.toJson()).toList(),
    'independenceAssessment': independenceAssessment.toJson(),
    'homeReadiness': homeReadiness.toJson(),
    'dailyRoutines': dailyRoutines.map((e) => e.toJson()).toList(),
    'equipment': equipment.map((e) => e.toJson()).toList(),
    'supplies': supplies.map((e) => e.toJson()).toList(),
    if (roadmap != null) 'roadmap': roadmap!.toJson(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    if (updatedBy != null) 'updatedBy': updatedBy,
  };
}

/// A collaborator on a Recovery Blueprint (owner / editor / viewer).
class BlueprintCollaborator {
  final String blueprintId;
  final String userId;
  final String role; // 'owner' | 'editor' | 'viewer'
  final String? addedBy;
  final DateTime addedAt;
  final String? displayName;
  final String? avatarUrl;

  const BlueprintCollaborator({
    required this.blueprintId,
    required this.userId,
    required this.role,
    this.addedBy,
    required this.addedAt,
    this.displayName,
    this.avatarUrl,
  });

  bool get canEdit => role == 'owner' || role == 'editor';
  bool get isOwner => role == 'owner';
}
