/// Visibility levels for patient notes
enum NoteVisibility { staffOnly, patientVisible, familyVisible }

/// Note types matching the database enum
enum NoteType { session, progress, observation, goalUpdate, general }

/// A note created by a therapist/healthcare provider for a patient.
class PatientNote {
  final String id;
  final String patientId;
  final String authorId;
  final String title;
  final String body;
  final NoteType noteType;
  final bool pinned;
  final NoteVisibility visibility;
  final DateTime createdAt;
  final DateTime updatedAt;

  PatientNote({
    required this.id,
    required this.patientId,
    required this.authorId,
    required this.title,
    required this.body,
    this.noteType = NoteType.general,
    this.pinned = false,
    this.visibility = NoteVisibility.patientVisible,
    required this.createdAt,
    required this.updatedAt,
  });

  static NoteVisibility _parseVisibility(dynamic value) {
    if (value == null) return NoteVisibility.patientVisible;
    final str = value.toString().toLowerCase();
    if (str == 'staff_only') return NoteVisibility.staffOnly;
    if (str == 'family_visible') return NoteVisibility.familyVisible;
    return NoteVisibility.patientVisible;
  }

  static String _visibilityToString(NoteVisibility v) {
    switch (v) {
      case NoteVisibility.staffOnly: return 'staff_only';
      case NoteVisibility.familyVisible: return 'family_visible';
      case NoteVisibility.patientVisible: return 'patient_visible';
    }
  }

  static NoteType _parseNoteType(dynamic value) {
    if (value == null) return NoteType.general;
    final str = value.toString().toLowerCase();
    switch (str) {
      case 'session': return NoteType.session;
      case 'progress': return NoteType.progress;
      case 'observation': return NoteType.observation;
      case 'goal_update': return NoteType.goalUpdate;
      default: return NoteType.general;
    }
  }

  static String _noteTypeToString(NoteType t) {
    switch (t) {
      case NoteType.session: return 'session';
      case NoteType.progress: return 'progress';
      case NoteType.observation: return 'observation';
      case NoteType.goalUpdate: return 'goal_update';
      case NoteType.general: return 'general';
    }
  }

  String get noteTypeLabel {
    switch (noteType) {
      case NoteType.session: return 'Session Note';
      case NoteType.progress: return 'Progress Update';
      case NoteType.observation: return 'Observation';
      case NoteType.goalUpdate: return 'Goal Update';
      case NoteType.general: return 'General';
    }
  }

  factory PatientNote.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is DateTime) return value;
      return DateTime.tryParse(value.toString()) ?? DateTime.now();
    }

    return PatientNote(
      id: json['id']?.toString() ?? '',
      patientId: json['patient_id']?.toString() ?? '',
      authorId: json['author_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      noteType: _parseNoteType(json['note_type']),
      pinned: json['pinned'] == true,
      visibility: _parseVisibility(json['visibility']),
      createdAt: parseDate(json['created_at']),
      updatedAt: parseDate(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'patient_id': patientId,
    'author_id': authorId,
    'title': title,
    'body': body,
    'note_type': _noteTypeToString(noteType),
    'pinned': pinned,
    'visibility': _visibilityToString(visibility),
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  PatientNote copyWith({
    String? patientId,
    String? authorId,
    String? title,
    String? body,
    NoteType? noteType,
    bool? pinned,
    NoteVisibility? visibility,
  }) => PatientNote(
    id: id,
    patientId: patientId ?? this.patientId,
    authorId: authorId ?? this.authorId,
    title: title ?? this.title,
    body: body ?? this.body,
    noteType: noteType ?? this.noteType,
    pinned: pinned ?? this.pinned,
    visibility: visibility ?? this.visibility,
    createdAt: createdAt,
    updatedAt: DateTime.now(),
  );
}
