/// Visibility levels for patient resources
/// Note: patient_only and family_visible only (no staff_only for resources)
enum ResourceVisibility { patientOnly, familyVisible }

/// Resource types matching the database
enum PatientResourceType { exercise, pdf, video, article, link, other }

/// A resource shared by a therapist/healthcare provider for a patient.
class PatientResource {
  final String id;
  final String patientId;
  final String uploadedBy;
  final String title;
  final String? description;
  final PatientResourceType type;
  final String? blobPathname; // Vercel Blob path for uploaded files
  final String? externalUrl; // External links
  final String? mimeType;
  final int? fileSize;
  final ResourceVisibility visibility;
  final DateTime createdAt;
  final DateTime updatedAt;

  PatientResource({
    required this.id,
    required this.patientId,
    required this.uploadedBy,
    required this.title,
    this.description,
    required this.type,
    this.blobPathname,
    this.externalUrl,
    this.mimeType,
    this.fileSize,
    this.visibility = ResourceVisibility.patientOnly,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Get the URL to access this resource
  String? get url => externalUrl ?? blobPathname;

  /// Whether this is a file upload (vs external link)
  bool get isFileUpload => blobPathname != null && blobPathname!.isNotEmpty;

  static ResourceVisibility _parseVisibility(dynamic value) {
    if (value == null) return ResourceVisibility.patientOnly;
    final str = value.toString().toLowerCase();
    if (str == 'family_visible') return ResourceVisibility.familyVisible;
    return ResourceVisibility.patientOnly;
  }

  static String _visibilityToString(ResourceVisibility v) {
    switch (v) {
      case ResourceVisibility.familyVisible: return 'family_visible';
      case ResourceVisibility.patientOnly: return 'patient_only';
    }
  }

  static PatientResourceType _parseType(dynamic value) {
    if (value == null) return PatientResourceType.other;
    final str = value.toString().toLowerCase();
    switch (str) {
      case 'exercise': return PatientResourceType.exercise;
      case 'pdf': return PatientResourceType.pdf;
      case 'video': return PatientResourceType.video;
      case 'article': return PatientResourceType.article;
      case 'link': return PatientResourceType.link;
      default: return PatientResourceType.other;
    }
  }

  static String _typeToString(PatientResourceType t) {
    switch (t) {
      case PatientResourceType.exercise: return 'exercise';
      case PatientResourceType.pdf: return 'pdf';
      case PatientResourceType.video: return 'video';
      case PatientResourceType.article: return 'article';
      case PatientResourceType.link: return 'link';
      case PatientResourceType.other: return 'other';
    }
  }

  String get typeLabel {
    switch (type) {
      case PatientResourceType.exercise: return 'Exercise';
      case PatientResourceType.pdf: return 'PDF Document';
      case PatientResourceType.video: return 'Video';
      case PatientResourceType.article: return 'Article';
      case PatientResourceType.link: return 'Link';
      case PatientResourceType.other: return 'Resource';
    }
  }

  IconType get iconType {
    switch (type) {
      case PatientResourceType.video: return IconType.video;
      case PatientResourceType.article: return IconType.article;
      case PatientResourceType.pdf: return IconType.pdf;
      case PatientResourceType.exercise: return IconType.exercise;
      case PatientResourceType.link: return IconType.link;
      case PatientResourceType.other: return IconType.link;
    }
  }

  factory PatientResource.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is DateTime) return value;
      return DateTime.tryParse(value.toString()) ?? DateTime.now();
    }

    return PatientResource(
      id: json['id']?.toString() ?? '',
      patientId: json['patient_id']?.toString() ?? '',
      uploadedBy: json['uploaded_by']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString(),
      type: _parseType(json['type']),
      blobPathname: json['blob_pathname']?.toString(),
      externalUrl: json['external_url']?.toString(),
      mimeType: json['mime_type']?.toString(),
      fileSize: json['file_size'] is int ? json['file_size'] : null,
      visibility: _parseVisibility(json['visibility']),
      createdAt: parseDate(json['created_at']),
      updatedAt: parseDate(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'patient_id': patientId,
    'uploaded_by': uploadedBy,
    'title': title,
    'description': description,
    'type': _typeToString(type),
    'blob_pathname': blobPathname,
    'external_url': externalUrl,
    'mime_type': mimeType,
    'file_size': fileSize,
    'visibility': _visibilityToString(visibility),
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  PatientResource copyWith({
    String? patientId,
    String? uploadedBy,
    String? title,
    String? description,
    PatientResourceType? type,
    String? blobPathname,
    String? externalUrl,
    String? mimeType,
    int? fileSize,
    ResourceVisibility? visibility,
  }) => PatientResource(
    id: id,
    patientId: patientId ?? this.patientId,
    uploadedBy: uploadedBy ?? this.uploadedBy,
    title: title ?? this.title,
    description: description ?? this.description,
    type: type ?? this.type,
    blobPathname: blobPathname ?? this.blobPathname,
    externalUrl: externalUrl ?? this.externalUrl,
    mimeType: mimeType ?? this.mimeType,
    fileSize: fileSize ?? this.fileSize,
    visibility: visibility ?? this.visibility,
    createdAt: createdAt,
    updatedAt: DateTime.now(),
  );
}

enum IconType { video, article, pdf, exercise, link }
