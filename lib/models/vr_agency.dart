/// Vocational Rehabilitation Agency model
class VRAgency {
  final String id;
  final String jurisdiction;
  final String abbr;
  final String jurisdictionType;
  final String agencyType;
  final String agencyName;
  final String? phone;
  final String? tollFree;
  final String? website;
  final String serviceArea;
  final String resourceClassification;
  final String sourceName;
  final String sourceUrl;
  final DateTime? lastVerified;
  final String verificationStatus;
  final String? notes;

  const VRAgency({
    required this.id,
    required this.jurisdiction,
    required this.abbr,
    required this.jurisdictionType,
    required this.agencyType,
    required this.agencyName,
    this.phone,
    this.tollFree,
    this.website,
    required this.serviceArea,
    required this.resourceClassification,
    required this.sourceName,
    required this.sourceUrl,
    this.lastVerified,
    required this.verificationStatus,
    this.notes,
  });

  factory VRAgency.fromCsv(Map<String, dynamic> row) {
    return VRAgency(
      id: row['source_id'] as String,
      jurisdiction: row['jurisdiction'] as String,
      abbr: row['abbr'] as String,
      jurisdictionType: row['jurisdiction_type'] as String,
      agencyType: row['agency_type'] as String,
      agencyName: row['agency_name'] as String,
      phone: row['phone']?.toString().trim(),
      tollFree: row['toll_free']?.toString().trim(),
      website: row['website']?.toString().trim(),
      serviceArea: row['service_area'] as String,
      resourceClassification: row['resource_classification'] as String,
      sourceName: row['source_name'] as String,
      sourceUrl: row['source_url'] as String,
      lastVerified: row['last_verified'] != null 
          ? DateTime.tryParse(row['last_verified'] as String)
          : null,
      verificationStatus: row['verification_status'] as String,
      notes: row['notes']?.toString().trim(),
    );
  }

  Map<String, dynamic> toJson() => {
    'source_id': id,
    'jurisdiction': jurisdiction,
    'abbr': abbr,
    'jurisdiction_type': jurisdictionType,
    'agency_type': agencyType,
    'agency_name': agencyName,
    if (phone != null && phone!.isNotEmpty) 'phone': phone,
    if (tollFree != null && tollFree!.isNotEmpty) 'toll_free': tollFree,
    if (website != null && website!.isNotEmpty) 'website': website,
    'service_area': serviceArea,
    'resource_classification': resourceClassification,
    'source_name': sourceName,
    'source_url': sourceUrl,
    if (lastVerified != null) 'last_verified': lastVerified!.toIso8601String(),
    'verification_status': verificationStatus,
    if (notes != null && notes!.isNotEmpty) 'notes': notes,
  };

  /// Returns true if this is a general VR agency (not blind-specific)
  bool get isGeneralVR => agencyType.toLowerCase().contains('general');

  /// Returns true if this is a blind/vision services agency
  bool get isBlindServices => agencyType.toLowerCase().contains('blind');

  /// Returns the primary contact number (toll-free if available, otherwise phone)
  String? get primaryPhone {
    if (tollFree != null && tollFree!.isNotEmpty) return tollFree;
    return phone;
  }

  /// Returns a display-friendly agency type label
  String get agencyTypeLabel {
    if (isBlindServices) return 'Blind & Vision Services';
    if (isGeneralVR) return 'General Vocational Rehabilitation';
    return agencyType;
  }
}
