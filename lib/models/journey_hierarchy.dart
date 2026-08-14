import 'package:cloud_firestore/cloud_firestore.dart';

/// Priority level for journey items
enum PriorityLevel {
  critical('Critical'),
  high('High'),
  medium('Medium'),
  low('Low');

  final String label;
  const PriorityLevel(this.label);

  static PriorityLevel fromString(String value) {
    return PriorityLevel.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => PriorityLevel.medium,
    );
  }
}

/// Status of journey items
enum JourneyStatus {
  notStarted('Not Started'),
  inProgress('In Progress'),
  completed('Completed'),
  skipped('Skipped'),
  blocked('Blocked');

  final String label;
  const JourneyStatus(this.label);

  static JourneyStatus fromString(String value) {
    return JourneyStatus.values.firstWhere(
      (e) => e.name.toLowerCase().replaceAll(' ', '') == value.toLowerCase().replaceAll('_', ''),
      orElse: () => JourneyStatus.notStarted,
    );
  }
}

/// Top-level: A journey represents a complete recovery pathway for a specific condition
class Journey {
  final String id;
  final String userId;
  final String conditionId;
  final String title;
  final String? description;
  final String domainType; // RecoveryDomainType name
  final JourneyStatus status;
  final int order;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Journey({
    required this.id,
    required this.userId,
    required this.conditionId,
    required this.title,
    this.description,
    required this.domainType,
    this.status = JourneyStatus.notStarted,
    this.order = 0,
    this.startedAt,
    this.completedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Journey.fromJson(Map<String, dynamic> json) => Journey(
    id: json['id'] ?? '',
    userId: json['userId'] ?? json['user_id'] ?? '',
    conditionId: json['conditionId'] ?? json['condition_id'] ?? '',
    title: json['title'] ?? '',
    description: json['description'],
    domainType: json['domainType'] ?? json['domain_type'] ?? 'mobility',
    status: JourneyStatus.fromString(json['status'] ?? 'notStarted'),
    order: json['order'] ?? 0,
    startedAt: json['startedAt'] != null || json['started_at'] != null
        ? _parseDateTime(json['startedAt'] ?? json['started_at'])
        : null,
    completedAt: json['completedAt'] != null || json['completed_at'] != null
        ? _parseDateTime(json['completedAt'] ?? json['completed_at'])
        : null,
    createdAt: _parseDateTime(json['createdAt'] ?? json['created_at'] ?? DateTime.now().toIso8601String()),
    updatedAt: _parseDateTime(json['updatedAt'] ?? json['updated_at'] ?? DateTime.now().toIso8601String()),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'conditionId': conditionId,
    'title': title,
    if (description != null) 'description': description,
    'domainType': domainType,
    'status': status.name,
    'order': order,
    if (startedAt != null) 'startedAt': startedAt!.toIso8601String(),
    if (completedAt != null) 'completedAt': completedAt!.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  static DateTime _parseDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.parse(value);
    return DateTime.now();
  }
}

/// Second level: Phases within a journey (e.g., Hospital, Post-Discharge, Outpatient)
class Phase {
  final String id;
  final String journeyId;
  final String userId;
  final String title;
  final String? description;
  final int order;
  final JourneyStatus status;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Phase({
    required this.id,
    required this.journeyId,
    required this.userId,
    required this.title,
    this.description,
    this.order = 0,
    this.status = JourneyStatus.notStarted,
    this.startedAt,
    this.completedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Phase.fromJson(Map<String, dynamic> json) => Phase(
    id: json['id'] ?? '',
    journeyId: json['journeyId'] ?? json['journey_id'] ?? '',
    userId: json['userId'] ?? json['user_id'] ?? '',
    title: json['title'] ?? '',
    description: json['description'],
    order: json['order'] ?? 0,
    status: JourneyStatus.fromString(json['status'] ?? 'notStarted'),
    startedAt: json['startedAt'] != null || json['started_at'] != null
        ? Journey._parseDateTime(json['startedAt'] ?? json['started_at'])
        : null,
    completedAt: json['completedAt'] != null || json['completed_at'] != null
        ? Journey._parseDateTime(json['completedAt'] ?? json['completed_at'])
        : null,
    createdAt: Journey._parseDateTime(json['createdAt'] ?? json['created_at'] ?? DateTime.now().toIso8601String()),
    updatedAt: Journey._parseDateTime(json['updatedAt'] ?? json['updated_at'] ?? DateTime.now().toIso8601String()),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'journeyId': journeyId,
    'userId': userId,
    'title': title,
    if (description != null) 'description': description,
    'order': order,
    'status': status.name,
    if (startedAt != null) 'startedAt': startedAt!.toIso8601String(),
    if (completedAt != null) 'completedAt': completedAt!.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };
}

/// Third level: Milestones (major checkpoints)
class JourneyMilestone {
  final String id;
  final String phaseId;
  final String userId;
  final String title;
  final String? description;
  final int order;
  final PriorityLevel priority;
  final JourneyStatus status;
  final DateTime? dueDate;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String? educationContent; // Rich text or markdown
  
  // Enhanced milestone metadata
  final String? whyItMatters;
  final String? successDefinition;
  final int? currentProgress; // 0-100 percentage
  final String? aiSummary;
  final List<String>? videos; // Video URLs
  final List<String>? questionsForProviders;
  final List<String>? reflectionQuestions;
  final String? aiAdaptationNotes;
  final String? celebrationMessage;
  final String? nextRecommendedMilestoneId;
  
  final DateTime createdAt;
  final DateTime updatedAt;

  const JourneyMilestone({
    required this.id,
    required this.phaseId,
    required this.userId,
    required this.title,
    this.description,
    this.order = 0,
    this.priority = PriorityLevel.medium,
    this.status = JourneyStatus.notStarted,
    this.dueDate,
    this.startedAt,
    this.completedAt,
    this.educationContent,
    this.whyItMatters,
    this.successDefinition,
    this.currentProgress,
    this.aiSummary,
    this.videos,
    this.questionsForProviders,
    this.reflectionQuestions,
    this.aiAdaptationNotes,
    this.celebrationMessage,
    this.nextRecommendedMilestoneId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory JourneyMilestone.fromJson(Map<String, dynamic> json) => JourneyMilestone(
    id: json['id'] ?? '',
    phaseId: json['phaseId'] ?? json['phase_id'] ?? '',
    userId: json['userId'] ?? json['user_id'] ?? '',
    title: json['title'] ?? '',
    description: json['description'],
    order: json['order'] ?? 0,
    priority: PriorityLevel.fromString(json['priority'] ?? 'medium'),
    status: JourneyStatus.fromString(json['status'] ?? 'notStarted'),
    dueDate: json['dueDate'] != null || json['due_date'] != null
        ? Journey._parseDateTime(json['dueDate'] ?? json['due_date'])
        : null,
    startedAt: json['startedAt'] != null || json['started_at'] != null
        ? Journey._parseDateTime(json['startedAt'] ?? json['started_at'])
        : null,
    completedAt: json['completedAt'] != null || json['completed_at'] != null
        ? Journey._parseDateTime(json['completedAt'] ?? json['completed_at'])
        : null,
    educationContent: json['educationContent'] ?? json['education_content'],
    whyItMatters: json['whyItMatters'] ?? json['why_it_matters'],
    successDefinition: json['successDefinition'] ?? json['success_definition'],
    currentProgress: json['currentProgress'] ?? json['current_progress'],
    aiSummary: json['aiSummary'] ?? json['ai_summary'],
    videos: json['videos'] != null ? List<String>.from(json['videos']) : null,
    questionsForProviders: json['questionsForProviders'] ?? json['questions_for_providers'] != null 
        ? List<String>.from(json['questionsForProviders'] ?? json['questions_for_providers']) 
        : null,
    reflectionQuestions: json['reflectionQuestions'] ?? json['reflection_questions'] != null 
        ? List<String>.from(json['reflectionQuestions'] ?? json['reflection_questions']) 
        : null,
    aiAdaptationNotes: json['aiAdaptationNotes'] ?? json['ai_adaptation_notes'],
    celebrationMessage: json['celebrationMessage'] ?? json['celebration_message'],
    nextRecommendedMilestoneId: json['nextRecommendedMilestoneId'] ?? json['next_recommended_milestone_id'],
    createdAt: Journey._parseDateTime(json['createdAt'] ?? json['created_at'] ?? DateTime.now().toIso8601String()),
    updatedAt: Journey._parseDateTime(json['updatedAt'] ?? json['updated_at'] ?? DateTime.now().toIso8601String()),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'phaseId': phaseId,
    'userId': userId,
    'title': title,
    if (description != null) 'description': description,
    'order': order,
    'priority': priority.name,
    'status': status.name,
    if (dueDate != null) 'dueDate': dueDate!.toIso8601String(),
    if (startedAt != null) 'startedAt': startedAt!.toIso8601String(),
    if (completedAt != null) 'completedAt': completedAt!.toIso8601String(),
    if (educationContent != null) 'educationContent': educationContent,
    if (whyItMatters != null) 'whyItMatters': whyItMatters,
    if (successDefinition != null) 'successDefinition': successDefinition,
    if (currentProgress != null) 'currentProgress': currentProgress,
    if (aiSummary != null) 'aiSummary': aiSummary,
    if (videos != null) 'videos': videos,
    if (questionsForProviders != null) 'questionsForProviders': questionsForProviders,
    if (reflectionQuestions != null) 'reflectionQuestions': reflectionQuestions,
    if (aiAdaptationNotes != null) 'aiAdaptationNotes': aiAdaptationNotes,
    if (celebrationMessage != null) 'celebrationMessage': celebrationMessage,
    if (nextRecommendedMilestoneId != null) 'nextRecommendedMilestoneId': nextRecommendedMilestoneId,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };
}

/// Fourth level: Goals (measurable outcomes)
class JourneyGoal {
  final String id;
  final String milestoneId;
  final String userId;
  final String title;
  final String? description;
  final int order;
  final JourneyStatus status;
  final int targetValue;
  final int currentValue;
  final String? unit; // e.g., "times", "minutes", "days"
  
  // Enhanced goal metadata
  final String? timeEstimate; // e.g., "2-4 weeks", "3 days"
  final String? difficulty; // "Easy", "Medium", "Hard"
  final String? evidenceOfCompletion;
  
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const JourneyGoal({
    required this.id,
    required this.milestoneId,
    required this.userId,
    required this.title,
    this.description,
    this.order = 0,
    this.status = JourneyStatus.notStarted,
    this.targetValue = 1,
    this.currentValue = 0,
    this.unit,
    this.timeEstimate,
    this.difficulty,
    this.evidenceOfCompletion,
    this.startedAt,
    this.completedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory JourneyGoal.fromJson(Map<String, dynamic> json) => JourneyGoal(
    id: json['id'] ?? '',
    milestoneId: json['milestoneId'] ?? json['milestone_id'] ?? '',
    userId: json['userId'] ?? json['user_id'] ?? '',
    title: json['title'] ?? '',
    description: json['description'],
    order: json['order'] ?? 0,
    status: JourneyStatus.fromString(json['status'] ?? 'notStarted'),
    targetValue: json['targetValue'] ?? json['target_value'] ?? 1,
    currentValue: json['currentValue'] ?? json['current_value'] ?? 0,
    unit: json['unit'],
    timeEstimate: json['timeEstimate'] ?? json['time_estimate'],
    difficulty: json['difficulty'],
    evidenceOfCompletion: json['evidenceOfCompletion'] ?? json['evidence_of_completion'],
    startedAt: json['startedAt'] != null || json['started_at'] != null
        ? Journey._parseDateTime(json['startedAt'] ?? json['started_at'])
        : null,
    completedAt: json['completedAt'] != null || json['completed_at'] != null
        ? Journey._parseDateTime(json['completedAt'] ?? json['completed_at'])
        : null,
    createdAt: Journey._parseDateTime(json['createdAt'] ?? json['created_at'] ?? DateTime.now().toIso8601String()),
    updatedAt: Journey._parseDateTime(json['updatedAt'] ?? json['updated_at'] ?? DateTime.now().toIso8601String()),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'milestoneId': milestoneId,
    'userId': userId,
    'title': title,
    if (description != null) 'description': description,
    'order': order,
    'status': status.name,
    'targetValue': targetValue,
    'currentValue': currentValue,
    if (unit != null) 'unit': unit,
    if (timeEstimate != null) 'timeEstimate': timeEstimate,
    if (difficulty != null) 'difficulty': difficulty,
    if (evidenceOfCompletion != null) 'evidenceOfCompletion': evidenceOfCompletion,
    if (startedAt != null) 'startedAt': startedAt!.toIso8601String(),
    if (completedAt != null) 'completedAt': completedAt!.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  double get progressPercentage => targetValue > 0 ? (currentValue / targetValue).clamp(0.0, 1.0) : 0.0;
}

/// Fifth level: Tasks (actionable steps)
class JourneyTask {
  final String id;
  final String goalId;
  final String userId;
  final String title;
  final String? description;
  final int order;
  final bool completed;
  final DateTime? completedAt;
  final DateTime? dueDate;
  final String? assignedTo; // CareTeamMember ID
  final DateTime createdAt;
  final DateTime updatedAt;

  const JourneyTask({
    required this.id,
    required this.goalId,
    required this.userId,
    required this.title,
    this.description,
    this.order = 0,
    this.completed = false,
    this.completedAt,
    this.dueDate,
    this.assignedTo,
    required this.createdAt,
    required this.updatedAt,
  });

  factory JourneyTask.fromJson(Map<String, dynamic> json) => JourneyTask(
    id: json['id'] ?? '',
    goalId: json['goalId'] ?? json['goal_id'] ?? '',
    userId: json['userId'] ?? json['user_id'] ?? '',
    title: json['title'] ?? '',
    description: json['description'],
    order: json['order'] ?? 0,
    completed: json['completed'] ?? false,
    completedAt: json['completedAt'] != null || json['completed_at'] != null
        ? Journey._parseDateTime(json['completedAt'] ?? json['completed_at'])
        : null,
    dueDate: json['dueDate'] != null || json['due_date'] != null
        ? Journey._parseDateTime(json['dueDate'] ?? json['due_date'])
        : null,
    assignedTo: json['assignedTo'] ?? json['assigned_to'],
    createdAt: Journey._parseDateTime(json['createdAt'] ?? json['created_at'] ?? DateTime.now().toIso8601String()),
    updatedAt: Journey._parseDateTime(json['updatedAt'] ?? json['updated_at'] ?? DateTime.now().toIso8601String()),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'goalId': goalId,
    'userId': userId,
    'title': title,
    if (description != null) 'description': description,
    'order': order,
    'completed': completed,
    if (completedAt != null) 'completedAt': completedAt!.toIso8601String(),
    if (dueDate != null) 'dueDate': dueDate!.toIso8601String(),
    if (assignedTo != null) 'assignedTo': assignedTo,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };
}
