import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:wellspring/models/pain_detail.dart';

class MedicationLog {
  final String name;
  final int? doseMg;
  /// ISO8601 datetime string (local) for when the dose was taken.
  final String? takenAt;
  final bool? isPrn;
  /// 0..5 (higher = better)
  final int? effectScore;

  const MedicationLog({
    required this.name,
    this.doseMg,
    this.takenAt,
    this.isPrn,
    this.effectScore,
  });

  factory MedicationLog.fromJson(Map<String, dynamic> json) => MedicationLog(
    name: (json['name'] ?? '').toString(),
    doseMg: (json['doseMg'] as num?)?.toInt(),
    takenAt: json['takenAt']?.toString(),
    isPrn: json['isPrn'] as bool?,
    effectScore: (json['effectScore'] as num?)?.toInt(),
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    if (doseMg != null) 'doseMg': doseMg,
    if (takenAt != null) 'takenAt': takenAt,
    if (isPrn != null) 'isPrn': isPrn,
    if (effectScore != null) 'effectScore': effectScore,
  };
}

class SymptomLog {
  final String name;
  /// 1..10
  final int? intensity;
  final int? durationMin;
  /// ISO8601 datetime string (local)
  final String? onsetAt;
  final String? bodyArea;

  const SymptomLog({
    required this.name,
    this.intensity,
    this.durationMin,
    this.onsetAt,
    this.bodyArea,
  });

  factory SymptomLog.fromJson(Map<String, dynamic> json) => SymptomLog(
    name: (json['name'] ?? '').toString(),
    intensity: (json['intensity'] as num?)?.toInt(),
    durationMin: (json['durationMin'] as num?)?.toInt(),
    onsetAt: json['onsetAt']?.toString(),
    bodyArea: json['bodyArea']?.toString(),
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    if (intensity != null) 'intensity': intensity,
    if (durationMin != null) 'durationMin': durationMin,
    if (onsetAt != null) 'onsetAt': onsetAt,
    if (bodyArea != null) 'bodyArea': bodyArea,
  };
}

class TriggerLog {
  final String name;
  final int? temperatureF;
  final int? durationMin;
  final bool? jacket;
  final bool? gloves;

  const TriggerLog({
    required this.name,
    this.temperatureF,
    this.durationMin,
    this.jacket,
    this.gloves,
  });

  factory TriggerLog.fromJson(Map<String, dynamic> json) => TriggerLog(
    name: (json['name'] ?? '').toString(),
    temperatureF: (json['temperatureF'] as num?)?.toInt(),
    durationMin: (json['durationMin'] as num?)?.toInt(),
    jacket: json['jacket'] as bool?,
    gloves: json['gloves'] as bool?,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    if (temperatureF != null) 'temperatureF': temperatureF,
    if (durationMin != null) 'durationMin': durationMin,
    if (jacket != null) 'jacket': jacket,
    if (gloves != null) 'gloves': gloves,
  };
}

class ActivityLog {
  final String name;
  final String? purpose;
  final double? distanceMi;
  final String? assist;
  /// 0..5
  final int? fatigueAfter;

  const ActivityLog({
    required this.name,
    this.purpose,
    this.distanceMi,
    this.assist,
    this.fatigueAfter,
  });

  factory ActivityLog.fromJson(Map<String, dynamic> json) => ActivityLog(
    name: (json['name'] ?? '').toString(),
    purpose: json['purpose']?.toString(),
    distanceMi: (json['distanceMi'] as num?)?.toDouble(),
    assist: json['assist']?.toString(),
    fatigueAfter: (json['fatigueAfter'] as num?)?.toInt(),
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    if (purpose != null) 'purpose': purpose,
    if (distanceMi != null) 'distanceMi': distanceMi,
    if (assist != null) 'assist': assist,
    if (fatigueAfter != null) 'fatigueAfter': fatigueAfter,
  };
}

class TrackerEntry {
  final String id;
  final String userId;
  final DateTime date;
  final int? painLevel;
  final List<PainDetail>? painMap; // Detailed pain mapping
  final String? mood;
  final int? spasmFrequency;
  final bool? bladderSuccess;
  final bool? bowelProgram;
  final int? sleepQuality;
  final int? energyLevel;
  // New metrics
  final int? systolicBP; // mmHg
  final int? diastolicBP; // mmHg
  final int? heartRate; // bpm
  final int? steps; // step count
  final double? weight; // kg
  final double? temperature; // celsius
  final String? notes;
  final List<String>? medications;
  final List<String>? symptoms;
  final List<String>? triggers;
  final List<String>? activities;
  /// Structured, clinical context for tags. Stored inside `customFields`.
  final List<MedicationLog>? medicationLogs;
  final List<SymptomLog>? symptomLogs;
  final List<TriggerLog>? triggerLogs;
  final List<ActivityLog>? activityLogs;
  final Map<String, dynamic>? customFields;
  final DateTime createdAt;
  final DateTime updatedAt;

  TrackerEntry({
    required this.id,
    required this.userId,
    required this.date,
    this.painLevel,
    this.painMap,
    this.mood,
    this.spasmFrequency,
    this.bladderSuccess,
    this.bowelProgram,
    this.sleepQuality,
    this.energyLevel,
    this.systolicBP,
    this.diastolicBP,
    this.heartRate,
    this.steps,
    this.weight,
    this.temperature,
    this.notes,
    this.medications,
    this.symptoms,
    this.triggers,
    this.activities,
    this.medicationLogs,
    this.symptomLogs,
    this.triggerLogs,
    this.activityLogs,
    this.customFields,
    required this.createdAt,
    required this.updatedAt,
  });

  static List<T>? _decodeList<T>(dynamic value, T Function(Map<String, dynamic>) fromMap) {
    if (value is! List) return null;
    final out = <T>[];
    for (final e in value) {
      if (e is Map<String, dynamic>) {
        out.add(fromMap(e));
      } else if (e is Map) {
        out.add(fromMap(e.cast<String, dynamic>()));
      }
    }
    return out.isEmpty ? null : out;
  }

  factory TrackerEntry.fromJson(Map<String, dynamic> json) {
    // Support both camelCase (Firestore) and snake_case (Supabase) field names
    final custom = json['customFields'] ?? json['custom_fields'];
    final customMap = custom != null ? Map<String, dynamic>.from(custom) : null;
    final medicationLogs = _decodeList<MedicationLog>(customMap?['medicationLogs'], (m) => MedicationLog.fromJson(m));
    final symptomLogs = _decodeList<SymptomLog>(customMap?['symptomLogs'], (m) => SymptomLog.fromJson(m));
    final triggerLogs = _decodeList<TriggerLog>(customMap?['triggerLogs'], (m) => TriggerLog.fromJson(m));
    final activityLogs = _decodeList<ActivityLog>(customMap?['activityLogs'], (m) => ActivityLog.fromJson(m));

    return TrackerEntry(
      id: json['id'] as String,
      userId: (json['userId'] ?? json['user_id']) as String,
      date: json['date'] is Timestamp ? (json['date'] as Timestamp).toDate() : DateTime.parse(json['date'] as String),
      painLevel: (json['painLevel'] ?? json['pain_level']) as int?,
      painMap: (json['painMap'] ?? json['pain_map']) != null 
        ? ((json['painMap'] ?? json['pain_map']) as List).map((e) => PainDetail.fromJson(e)).toList() 
        : null,
      mood: json['mood'] as String?,
      spasmFrequency: (json['spasmFrequency'] ?? json['spasm_frequency']) as int?,
      bladderSuccess: (json['bladderSuccess'] ?? json['bladder_success']) as bool?,
      bowelProgram: (json['bowelProgram'] ?? json['bowel_program']) as bool?,
      sleepQuality: (json['sleepQuality'] ?? json['sleep_quality']) as int?,
      energyLevel: (json['energyLevel'] ?? json['energy_level']) as int?,
      systolicBP: (json['systolicBP'] ?? json['systolic_bp']) as int?,
      diastolicBP: (json['diastolicBP'] ?? json['diastolic_bp']) as int?,
      heartRate: (json['heartRate'] ?? json['heart_rate']) as int?,
      steps: json['steps'] as int?,
      weight: (json['weight'] as num?)?.toDouble(),
      temperature: (json['temperature'] as num?)?.toDouble(),
      notes: json['notes'] as String?,
      medications: json['medications'] != null ? List<String>.from(json['medications'] as List) : null,
      symptoms: json['symptoms'] != null ? List<String>.from(json['symptoms'] as List) : null,
      triggers: json['triggers'] != null ? List<String>.from(json['triggers'] as List) : null,
      activities: json['activities'] != null ? List<String>.from(json['activities'] as List) : null,
      medicationLogs: medicationLogs,
      symptomLogs: symptomLogs,
      triggerLogs: triggerLogs,
      activityLogs: activityLogs,
      customFields: customMap,
      createdAt: (json['createdAt'] ?? json['created_at']) is Timestamp 
        ? ((json['createdAt'] ?? json['created_at']) as Timestamp).toDate() 
        : DateTime.parse((json['createdAt'] ?? json['created_at']) as String),
      updatedAt: (json['updatedAt'] ?? json['updated_at']) is Timestamp 
        ? ((json['updatedAt'] ?? json['updated_at']) as Timestamp).toDate() 
        : DateTime.parse((json['updatedAt'] ?? json['updated_at']) as String),
    );
  }

  Map<String, dynamic> toJson() {
    final mergedCustom = <String, dynamic>{...(customFields ?? {})};
    if (medicationLogs != null) mergedCustom['medicationLogs'] = medicationLogs!.map((e) => e.toJson()).toList();
    if (symptomLogs != null) mergedCustom['symptomLogs'] = symptomLogs!.map((e) => e.toJson()).toList();
    if (triggerLogs != null) mergedCustom['triggerLogs'] = triggerLogs!.map((e) => e.toJson()).toList();
    if (activityLogs != null) mergedCustom['activityLogs'] = activityLogs!.map((e) => e.toJson()).toList();

    return {
    'id': id,
    'userId': userId,
    'date': date.toIso8601String(),
    'painLevel': painLevel,
    if (painMap != null) 'painMap': painMap!.map((e) => e.toJson()).toList(),
    'mood': mood,
    'spasmFrequency': spasmFrequency,
    'bladderSuccess': bladderSuccess,
    'bowelProgram': bowelProgram,
    'sleepQuality': sleepQuality,
    'energyLevel': energyLevel,
    'systolicBP': systolicBP,
    'diastolicBP': diastolicBP,
    'heartRate': heartRate,
    'steps': steps,
    'weight': weight,
    'temperature': temperature,
    'notes': notes,
    'medications': medications,
    'symptoms': symptoms,
    'triggers': triggers,
    'activities': activities,
    'customFields': mergedCustom.isEmpty ? null : mergedCustom,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Returns true if this entry is a "medication-only" entry
  /// (contains medications but no significant health metrics)
  bool get isMedicationOnlyEntry {
    final hasMedications = (medications?.isNotEmpty ?? false) || 
                           (medicationLogs?.isNotEmpty ?? false);
    final hasHealthData = painLevel != null ||
        (painMap?.isNotEmpty ?? false) ||
        mood != null ||
        spasmFrequency != null ||
        bladderSuccess != null ||
        bowelProgram != null ||
        sleepQuality != null ||
        energyLevel != null ||
        systolicBP != null ||
        diastolicBP != null ||
        heartRate != null ||
        steps != null ||
        weight != null ||
        temperature != null ||
        (symptoms?.isNotEmpty ?? false) ||
        (triggers?.isNotEmpty ?? false) ||
        (activities?.isNotEmpty ?? false);
    return hasMedications && !hasHealthData;
  }

  bool get hasNutritionV1 => (customFields ?? const {})['nutritionV1'] != null;

  /// Returns true if this entry only contains nutrition data stored under
  /// `customFields['nutritionV1']` (and no other health metrics or meds).
  ///
  /// This is used to keep nutrition-only tracker rows out of the Health-side
  /// tracker feeds (Recent Entries, snapshot refresh triggers, etc.).
  bool get isNutritionOnlyEntry {
    final hasMedications = (medications?.isNotEmpty ?? false) ||
        (medicationLogs?.isNotEmpty ?? false);
    final hasHealthData = painLevel != null ||
        (painMap?.isNotEmpty ?? false) ||
        mood != null ||
        spasmFrequency != null ||
        bladderSuccess != null ||
        bowelProgram != null ||
        sleepQuality != null ||
        energyLevel != null ||
        systolicBP != null ||
        diastolicBP != null ||
        heartRate != null ||
        steps != null ||
        weight != null ||
        temperature != null ||
        (symptoms?.isNotEmpty ?? false) ||
        (triggers?.isNotEmpty ?? false) ||
        (activities?.isNotEmpty ?? false);

    // Notes are allowed for nutrition-only entries, so we intentionally ignore `notes`.
    return hasNutritionV1 && !hasHealthData && !hasMedications;
  }

  TrackerEntry copyWith({
    int? painLevel,
    List<PainDetail>? painMap,
    String? mood,
    int? spasmFrequency,
    bool? bladderSuccess,
    bool? bowelProgram,
    int? sleepQuality,
    int? energyLevel,
    int? systolicBP,
    int? diastolicBP,
    int? heartRate,
    int? steps,
    double? weight,
    double? temperature,
    String? notes,
    List<String>? medications,
    List<String>? symptoms,
    List<String>? triggers,
    List<String>? activities,
    List<MedicationLog>? medicationLogs,
    List<SymptomLog>? symptomLogs,
    List<TriggerLog>? triggerLogs,
    List<ActivityLog>? activityLogs,
    Map<String, dynamic>? customFields,
  }) => TrackerEntry(
    id: id,
    userId: userId,
    date: date,
    painLevel: painLevel ?? this.painLevel,
    painMap: painMap ?? this.painMap,
    mood: mood ?? this.mood,
    spasmFrequency: spasmFrequency ?? this.spasmFrequency,
    bladderSuccess: bladderSuccess ?? this.bladderSuccess,
    bowelProgram: bowelProgram ?? this.bowelProgram,
    sleepQuality: sleepQuality ?? this.sleepQuality,
    energyLevel: energyLevel ?? this.energyLevel,
    systolicBP: systolicBP ?? this.systolicBP,
    diastolicBP: diastolicBP ?? this.diastolicBP,
    heartRate: heartRate ?? this.heartRate,
    steps: steps ?? this.steps,
    weight: weight ?? this.weight,
    temperature: temperature ?? this.temperature,
    notes: notes ?? this.notes,
    medications: medications ?? this.medications,
    symptoms: symptoms ?? this.symptoms,
    triggers: triggers ?? this.triggers,
    activities: activities ?? this.activities,
    medicationLogs: medicationLogs ?? this.medicationLogs,
    symptomLogs: symptomLogs ?? this.symptomLogs,
    triggerLogs: triggerLogs ?? this.triggerLogs,
    activityLogs: activityLogs ?? this.activityLogs,
    customFields: customFields ?? this.customFields,
    createdAt: createdAt,
    updatedAt: DateTime.now(),
  );
}
