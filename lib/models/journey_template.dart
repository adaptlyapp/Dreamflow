/// Template library for ARIE to generate personalized journeys

/// A template for a milestone that can be personalized
class MilestoneTemplate {
  final String id;
  final String domainType; // RecoveryDomainType name
  final String phaseName; // Hospital, Post-Discharge, Outpatient, Long-Term
  final String titleTemplate; // e.g., "Establish {program_type} program"
  final String? descriptionTemplate;
  final int order;
  final String priority; // critical, high, medium, low
  final List<String> applicableConditions; // ['SCI', 'TBI', '*'] (* = universal)
  final Map<String, dynamic> relevanceCriteria; // Conditions for this milestone to appear
  final List<GoalTemplate> goalTemplates;
  final String? educationContent;

  const MilestoneTemplate({
    required this.id,
    required this.domainType,
    required this.phaseName,
    required this.titleTemplate,
    this.descriptionTemplate,
    this.order = 0,
    this.priority = 'medium',
    this.applicableConditions = const ['*'],
    this.relevanceCriteria = const {},
    this.goalTemplates = const [],
    this.educationContent,
  });

  factory MilestoneTemplate.fromJson(Map<String, dynamic> json) => MilestoneTemplate(
    id: json['id'] ?? '',
    domainType: json['domainType'] ?? json['domain_type'] ?? 'mobility',
    phaseName: json['phaseName'] ?? json['phase_name'] ?? 'Post-Discharge',
    titleTemplate: json['titleTemplate'] ?? json['title_template'] ?? '',
    descriptionTemplate: json['descriptionTemplate'] ?? json['description_template'],
    order: json['order'] ?? 0,
    priority: json['priority'] ?? 'medium',
    applicableConditions: List<String>.from(json['applicableConditions'] ?? json['applicable_conditions'] ?? ['*']),
    relevanceCriteria: Map<String, dynamic>.from(json['relevanceCriteria'] ?? json['relevance_criteria'] ?? {}),
    goalTemplates: (json['goalTemplates'] ?? json['goal_templates'] ?? [])
        .map<GoalTemplate>((e) => GoalTemplate.fromJson(e))
        .toList(),
    educationContent: json['educationContent'] ?? json['education_content'],
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'domainType': domainType,
    'phaseName': phaseName,
    'titleTemplate': titleTemplate,
    if (descriptionTemplate != null) 'descriptionTemplate': descriptionTemplate,
    'order': order,
    'priority': priority,
    'applicableConditions': applicableConditions,
    'relevanceCriteria': relevanceCriteria,
    'goalTemplates': goalTemplates.map((e) => e.toJson()).toList(),
    if (educationContent != null) 'educationContent': educationContent,
  };

  /// Calculate relevance score (0-100) based on patient profile
  int calculateRelevance(Map<String, dynamic> patientProfile) {
    int score = 50; // Base score

    // Check if condition matches
    final patientCondition = patientProfile['primaryDiagnosis'] as String? ?? '';
    if (applicableConditions.contains('*')) {
      score += 10; // Universal template
    } else if (applicableConditions.any((c) => patientCondition.toLowerCase().contains(c.toLowerCase()))) {
      score += 30; // Condition-specific match
    } else {
      score -= 20; // Not relevant to condition
    }

    // Check recovery phase
    final patientPhase = patientProfile['recoveryPhase'] as String? ?? 'postDischarge';
    if (phaseName.toLowerCase().replaceAll('-', '').replaceAll(' ', '') == 
        patientPhase.toLowerCase().replaceAll('-', '').replaceAll(' ', '')) {
      score += 20; // Phase match
    }

    // Apply custom relevance criteria
    for (final entry in relevanceCriteria.entries) {
      final key = entry.key;
      final requirement = entry.value;
      final patientValue = patientProfile[key];

      if (patientValue == requirement) {
        score += 15;
      }
    }

    return score.clamp(0, 100);
  }
}

/// A template for a goal within a milestone
class GoalTemplate {
  final String id;
  final String titleTemplate;
  final String? descriptionTemplate;
  final int order;
  final int targetValue;
  final String? unit;
  final List<TaskTemplate> taskTemplates;

  const GoalTemplate({
    required this.id,
    required this.titleTemplate,
    this.descriptionTemplate,
    this.order = 0,
    this.targetValue = 1,
    this.unit,
    this.taskTemplates = const [],
  });

  factory GoalTemplate.fromJson(Map<String, dynamic> json) => GoalTemplate(
    id: json['id'] ?? '',
    titleTemplate: json['titleTemplate'] ?? json['title_template'] ?? '',
    descriptionTemplate: json['descriptionTemplate'] ?? json['description_template'],
    order: json['order'] ?? 0,
    targetValue: json['targetValue'] ?? json['target_value'] ?? 1,
    unit: json['unit'],
    taskTemplates: (json['taskTemplates'] ?? json['task_templates'] ?? [])
        .map<TaskTemplate>((e) => TaskTemplate.fromJson(e))
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'titleTemplate': titleTemplate,
    if (descriptionTemplate != null) 'descriptionTemplate': descriptionTemplate,
    'order': order,
    'targetValue': targetValue,
    if (unit != null) 'unit': unit,
    'taskTemplates': taskTemplates.map((e) => e.toJson()).toList(),
  };
}

/// A template for a task within a goal
class TaskTemplate {
  final String id;
  final String titleTemplate;
  final String? descriptionTemplate;
  final int order;
  final int estimatedDaysFromStart; // Suggested timing

  const TaskTemplate({
    required this.id,
    required this.titleTemplate,
    this.descriptionTemplate,
    this.order = 0,
    this.estimatedDaysFromStart = 0,
  });

  factory TaskTemplate.fromJson(Map<String, dynamic> json) => TaskTemplate(
    id: json['id'] ?? '',
    titleTemplate: json['titleTemplate'] ?? json['title_template'] ?? '',
    descriptionTemplate: json['descriptionTemplate'] ?? json['description_template'],
    order: json['order'] ?? 0,
    estimatedDaysFromStart: json['estimatedDaysFromStart'] ?? json['estimated_days_from_start'] ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'titleTemplate': titleTemplate,
    if (descriptionTemplate != null) 'descriptionTemplate': descriptionTemplate,
    'order': order,
    'estimatedDaysFromStart': estimatedDaysFromStart,
  };
}

/// Patient profile inputs for ARIE generation
class PatientProfileInput {
  final String primaryDiagnosis;
  final List<String> secondaryDiagnoses;
  final DateTime? dateOfInjury;
  final String recoveryPhase; // acute, postDischarge, outpatient, longTerm
  final String? functionalClassification; // e.g., "C4 ASIA A" for SCI
  final String? severity; // mild, moderate, severe
  
  // Current abilities
  final Map<String, String> cognitiveIndependence; // key -> independenceLevel
  final Map<String, String> physicalIndependence;
  
  // Therapy goals (from clinicians)
  final List<String> therapyGoals;
  final List<String> physicianRestrictions;
  
  // Care context
  final List<String> careTeamRoles; // primary_caregiver, transportation, etc.
  final String therapySchedule; // daily, weekly, etc.
  
  // Patient priorities
  final List<String> patientPriorities; // What matters most to them
  final List<String> concerns; // What they're worried about

  const PatientProfileInput({
    required this.primaryDiagnosis,
    this.secondaryDiagnoses = const [],
    this.dateOfInjury,
    required this.recoveryPhase,
    this.functionalClassification,
    this.severity,
    this.cognitiveIndependence = const {},
    this.physicalIndependence = const {},
    this.therapyGoals = const [],
    this.physicianRestrictions = const [],
    this.careTeamRoles = const [],
    this.therapySchedule = '',
    this.patientPriorities = const [],
    this.concerns = const [],
  });

  factory PatientProfileInput.fromJson(Map<String, dynamic> json) => PatientProfileInput(
    primaryDiagnosis: json['primaryDiagnosis'] ?? json['primary_diagnosis'] ?? '',
    secondaryDiagnoses: List<String>.from(json['secondaryDiagnoses'] ?? json['secondary_diagnoses'] ?? []),
    dateOfInjury: json['dateOfInjury'] != null || json['date_of_injury'] != null
        ? DateTime.tryParse(json['dateOfInjury'] ?? json['date_of_injury'])
        : null,
    recoveryPhase: json['recoveryPhase'] ?? json['recovery_phase'] ?? 'postDischarge',
    functionalClassification: json['functionalClassification'] ?? json['functional_classification'],
    severity: json['severity'],
    cognitiveIndependence: Map<String, String>.from(json['cognitiveIndependence'] ?? json['cognitive_independence'] ?? {}),
    physicalIndependence: Map<String, String>.from(json['physicalIndependence'] ?? json['physical_independence'] ?? {}),
    therapyGoals: List<String>.from(json['therapyGoals'] ?? json['therapy_goals'] ?? []),
    physicianRestrictions: List<String>.from(json['physicianRestrictions'] ?? json['physician_restrictions'] ?? []),
    careTeamRoles: List<String>.from(json['careTeamRoles'] ?? json['care_team_roles'] ?? []),
    therapySchedule: json['therapySchedule'] ?? json['therapy_schedule'] ?? '',
    patientPriorities: List<String>.from(json['patientPriorities'] ?? json['patient_priorities'] ?? []),
    concerns: List<String>.from(json['concerns'] ?? []),
  );

  Map<String, dynamic> toJson() => {
    'primaryDiagnosis': primaryDiagnosis,
    'secondaryDiagnoses': secondaryDiagnoses,
    if (dateOfInjury != null) 'dateOfInjury': dateOfInjury!.toIso8601String(),
    'recoveryPhase': recoveryPhase,
    if (functionalClassification != null) 'functionalClassification': functionalClassification,
    if (severity != null) 'severity': severity,
    'cognitiveIndependence': cognitiveIndependence,
    'physicalIndependence': physicalIndependence,
    'therapyGoals': therapyGoals,
    'physicianRestrictions': physicianRestrictions,
    'careTeamRoles': careTeamRoles,
    'therapySchedule': therapySchedule,
    'patientPriorities': patientPriorities,
    'concerns': concerns,
  };
}
