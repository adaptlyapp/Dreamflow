/// Stores user-specific details about their condition that help personalize
/// milestones and AI recommendations.
class ConditionDetail {
  final String conditionId;
  
  /// Injury level for spinal cord injury (e.g., C4-C5, T6, L1)
  final String? injuryLevel;
  
  /// Sub-type for conditions like diabetes (Type 1, Type 2), MS (RRMS, PPMS), etc.
  final String? subType;
  
  /// Mobility status (e.g., manual chair, power chair, ambulatory, walker)
  final String? mobilityStatus;
  
  /// Level of upper extremity function (e.g., full, limited grip, no hand function)
  final String? upperExtremityFunction;
  
  /// Level of lower extremity function (e.g., full, partial, none)
  final String? lowerExtremityFunction;
  
  /// Whether user requires assistance for daily activities
  final bool requiresAssistance;
  
  /// Specific assistive devices used
  final List<String> assistiveDevices;
  
  /// Key functional abilities the user has
  final List<String> functionalAbilities;
  
  /// Key challenges or limitations the user faces
  final List<String> challenges;
  
  /// Any additional notes the user wants to share
  final String? additionalNotes;
  
  /// When these details were last updated
  final DateTime updatedAt;

  ConditionDetail({
    required this.conditionId,
    this.injuryLevel,
    this.subType,
    this.mobilityStatus,
    this.upperExtremityFunction,
    this.lowerExtremityFunction,
    this.requiresAssistance = false,
    this.assistiveDevices = const [],
    this.functionalAbilities = const [],
    this.challenges = const [],
    this.additionalNotes,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  factory ConditionDetail.fromJson(Map<String, dynamic> json) => ConditionDetail(
    conditionId: json['conditionId'] ?? '',
    injuryLevel: json['injuryLevel'],
    subType: json['subType'],
    mobilityStatus: json['mobilityStatus'],
    upperExtremityFunction: json['upperExtremityFunction'],
    lowerExtremityFunction: json['lowerExtremityFunction'],
    requiresAssistance: json['requiresAssistance'] ?? false,
    assistiveDevices: List<String>.from(json['assistiveDevices'] ?? []),
    functionalAbilities: List<String>.from(json['functionalAbilities'] ?? []),
    challenges: List<String>.from(json['challenges'] ?? []),
    additionalNotes: json['additionalNotes'],
    updatedAt: json['updatedAt'] != null 
        ? DateTime.parse(json['updatedAt']) 
        : DateTime.now(),
  );

  Map<String, dynamic> toJson() => {
    'conditionId': conditionId,
    if (injuryLevel != null) 'injuryLevel': injuryLevel,
    if (subType != null) 'subType': subType,
    if (mobilityStatus != null) 'mobilityStatus': mobilityStatus,
    if (upperExtremityFunction != null) 'upperExtremityFunction': upperExtremityFunction,
    if (lowerExtremityFunction != null) 'lowerExtremityFunction': lowerExtremityFunction,
    'requiresAssistance': requiresAssistance,
    'assistiveDevices': assistiveDevices,
    'functionalAbilities': functionalAbilities,
    'challenges': challenges,
    if (additionalNotes != null) 'additionalNotes': additionalNotes,
    'updatedAt': updatedAt.toIso8601String(),
  };

  ConditionDetail copyWith({
    String? conditionId,
    String? injuryLevel,
    String? subType,
    String? mobilityStatus,
    String? upperExtremityFunction,
    String? lowerExtremityFunction,
    bool? requiresAssistance,
    List<String>? assistiveDevices,
    List<String>? functionalAbilities,
    List<String>? challenges,
    String? additionalNotes,
  }) => ConditionDetail(
    conditionId: conditionId ?? this.conditionId,
    injuryLevel: injuryLevel ?? this.injuryLevel,
    subType: subType ?? this.subType,
    mobilityStatus: mobilityStatus ?? this.mobilityStatus,
    upperExtremityFunction: upperExtremityFunction ?? this.upperExtremityFunction,
    lowerExtremityFunction: lowerExtremityFunction ?? this.lowerExtremityFunction,
    requiresAssistance: requiresAssistance ?? this.requiresAssistance,
    assistiveDevices: assistiveDevices ?? this.assistiveDevices,
    functionalAbilities: functionalAbilities ?? this.functionalAbilities,
    challenges: challenges ?? this.challenges,
    additionalNotes: additionalNotes ?? this.additionalNotes,
    updatedAt: DateTime.now(),
  );

  /// Returns true if the user has entered any meaningful details
  bool get hasDetails =>
      (injuryLevel?.isNotEmpty ?? false) ||
      (subType?.isNotEmpty ?? false) ||
      (mobilityStatus?.isNotEmpty ?? false) ||
      (upperExtremityFunction?.isNotEmpty ?? false) ||
      (lowerExtremityFunction?.isNotEmpty ?? false) ||
      assistiveDevices.isNotEmpty ||
      functionalAbilities.isNotEmpty ||
      challenges.isNotEmpty ||
      (additionalNotes?.isNotEmpty ?? false);

  /// Generates a summary string for AI prompts
  String toAiSummary(String conditionName) {
    final parts = <String>[];
    
    if (subType?.isNotEmpty ?? false) {
      parts.add('Type: $subType');
    }
    if (injuryLevel?.isNotEmpty ?? false) {
      parts.add('Level: $injuryLevel');
    }
    if (mobilityStatus?.isNotEmpty ?? false) {
      parts.add('Mobility: $mobilityStatus');
    }
    if (upperExtremityFunction?.isNotEmpty ?? false) {
      parts.add('Upper body function: $upperExtremityFunction');
    }
    if (lowerExtremityFunction?.isNotEmpty ?? false) {
      parts.add('Lower body function: $lowerExtremityFunction');
    }
    if (assistiveDevices.isNotEmpty) {
      parts.add('Uses: ${assistiveDevices.join(', ')}');
    }
    if (functionalAbilities.isNotEmpty) {
      parts.add('Can do: ${functionalAbilities.join(', ')}');
    }
    if (challenges.isNotEmpty) {
      parts.add('Challenges: ${challenges.join(', ')}');
    }
    if (requiresAssistance) {
      parts.add('Requires daily assistance');
    }
    if (additionalNotes?.isNotEmpty ?? false) {
      parts.add('Notes: $additionalNotes');
    }
    
    if (parts.isEmpty) return '';
    
    return 'User\'s $conditionName details: ${parts.join('; ')}.';
  }

  /// Best-effort: read the per-condition details from the user's preferences map.
  ///
  /// Expected shape:
  /// prefs['conditionDetails'] = { '<conditionId>': { ...ConditionDetail json... } }
  static ConditionDetail? tryFromUserPreferences({
    required Map<String, dynamic> preferences,
    required String conditionId,
  }) {
    try {
      final details = (preferences['conditionDetails'] as Map<String, dynamic>?) ?? const {};
      final raw = details[conditionId];
      if (raw == null) return null;
      return ConditionDetail.fromJson(Map<String, dynamic>.from(raw));
    } catch (_) {
      return null;
    }
  }
}

/// Common injury levels for spinal cord injury
class InjuryLevelOptions {
  static const cervical = ['C1', 'C2', 'C3', 'C4', 'C5', 'C6', 'C7', 'C8'];
  static const thoracic = ['T1', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'T8', 'T9', 'T10', 'T11', 'T12'];
  static const lumbar = ['L1', 'L2', 'L3', 'L4', 'L5'];
  static const sacral = ['S1', 'S2', 'S3', 'S4', 'S5'];
  
  static List<String> all = [...cervical, ...thoracic, ...lumbar, ...sacral];
  
  static String formatLevel(String level) {
    final upper = level.toUpperCase().trim();
    if (cervical.contains(upper)) return '$upper (Cervical)';
    if (thoracic.contains(upper)) return '$upper (Thoracic)';
    if (lumbar.contains(upper)) return '$upper (Lumbar)';
    if (sacral.contains(upper)) return '$upper (Sacral)';
    return upper;
  }
}

/// Common sub-types for various conditions
class ConditionSubTypes {
  static const diabetes = ['Type 1', 'Type 2', 'Gestational', 'LADA', 'MODY'];
  static const ms = ['RRMS (Relapsing-Remitting)', 'PPMS (Primary Progressive)', 'SPMS (Secondary Progressive)', 'PRMS (Progressive-Relapsing)'];
  static const arthritis = ['Rheumatoid', 'Osteoarthritis', 'Psoriatic', 'Juvenile'];
  static const sci = ['Complete', 'Incomplete', 'ASIA A', 'ASIA B', 'ASIA C', 'ASIA D'];
}

/// Common mobility options
class MobilityOptions {
  static const all = [
    'Manual wheelchair',
    'Power wheelchair',
    'Walker',
    'Cane/Crutches',
    'Ambulatory (walking)',
    'Ambulatory with assistance',
    'Bedbound',
    'Variable (depends on day)',
  ];
}

/// Common assistive devices
class AssistiveDeviceOptions {
  static const all = [
    'Manual wheelchair',
    'Power wheelchair',
    'Standing frame',
    'Walker',
    'Cane',
    'Crutches',
    'AFO/Leg braces',
    'Hand splints',
    'Voice control (Alexa/Google)',
    'Eye tracking',
    'Sip-and-puff',
    'Adaptive utensils',
    'Reacher/grabber',
    'Transfer board',
    'Hoyer lift',
    'Hospital bed',
    'Shower chair',
    'Catheter supplies',
    'CPAP/BiPAP',
    'Insulin pump',
    'CGM (Continuous Glucose Monitor)',
  ];
}

/// Common functional abilities
class FunctionalAbilityOptions {
  static const all = [
    'Independent transfers',
    'Self-feeding',
    'Self-dressing (upper body)',
    'Self-dressing (lower body)',
    'Driving (with modifications)',
    'Cooking independently',
    'Managing medications',
    'Using phone/tablet',
    'Typing on keyboard',
    'Writing by hand',
    'Bathing independently',
    'Toileting independently',
    'Standing briefly',
    'Walking short distances',
    'Climbing stairs',
    'Carrying objects',
    'Opening jars/bottles',
    'Gripping objects',
  ];
}

/// Common challenges
class ChallengeOptions {
  static const all = [
    'Chronic pain',
    'Fatigue',
    'Spasticity',
    'Pressure sores risk',
    'Bladder management',
    'Bowel management',
    'Temperature regulation',
    'Blood pressure issues',
    'Respiratory challenges',
    'Sleep difficulties',
    'Depression/Anxiety',
    'Cognitive fog',
    'Balance issues',
    'Vision changes',
    'Hearing changes',
    'Numbness/Tingling',
    'Muscle weakness',
    'Joint stiffness',
    'Blood sugar management',
    'Medication side effects',
  ];
}
