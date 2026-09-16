/// A curated service provider in the geolocation-based Resource Directory.
///
/// Unlike [Resource] (which is a generic, mostly web/Places-derived record),
/// a directory entry carries **typed capabilities** so ARIE can distinguish
/// intents such as "my power chair is broken" (repairs) from "I need a new
/// custom chair" (CRT) or "I need a ramp installed" (home modifications).
class ProviderDirectoryEntry {
  final String id;
  final String name;

  /// Primary classification. See [ProviderType].
  final String providerType;

  /// Legacy generic resource type (`service`, `center`, ...).
  final String type;

  final String address;
  final String? city;
  final String? state;
  final String? postalCode;
  final double? lat;
  final double? lng;

  /// Distance from the user in miles (computed server-side).
  final double distanceMiles;

  final String? phone;
  final String? contactEmail;
  final String? website;
  final String? hours;
  final String availability;
  final String? description;
  final String? servicesOffered;
  final String? serviceArea;

  final List<String> serviceKinds;
  final List<String> capabilities;
  final List<String> populationsServed;
  final List<String> conditionsServed;
  final List<String> insuranceAccepted;

  final bool doesRepairs;
  final bool doesRentals;
  final bool doesSales;
  final bool doesCrtCustomWheelchairs;
  final bool doesWheelchairEvalsClinical;
  final bool doesSeatingPositioning;
  final bool doesHomeModifications;
  final bool doesInstallation;
  final bool doesInHomeService;
  final bool doesInsuranceCoordination;
  final bool? acceptsMedicaid;
  final bool? acceptsMedicare;

  /// `exact` | `approximate` | `service_area_only`
  final String geoPrecision;
  final bool needsVerification;
  final DateTime? lastVerifiedAt;

  const ProviderDirectoryEntry({
    required this.id,
    required this.name,
    required this.providerType,
    required this.type,
    required this.address,
    this.city,
    this.state,
    this.postalCode,
    this.lat,
    this.lng,
    required this.distanceMiles,
    this.phone,
    this.contactEmail,
    this.website,
    this.hours,
    required this.availability,
    this.description,
    this.servicesOffered,
    this.serviceArea,
    this.serviceKinds = const [],
    this.capabilities = const [],
    this.populationsServed = const [],
    this.conditionsServed = const [],
    this.insuranceAccepted = const [],
    this.doesRepairs = false,
    this.doesRentals = false,
    this.doesSales = false,
    this.doesCrtCustomWheelchairs = false,
    this.doesWheelchairEvalsClinical = false,
    this.doesSeatingPositioning = false,
    this.doesHomeModifications = false,
    this.doesInstallation = false,
    this.doesInHomeService = false,
    this.doesInsuranceCoordination = false,
    this.acceptsMedicaid,
    this.acceptsMedicare,
    this.geoPrecision = 'approximate',
    this.needsVerification = false,
    this.lastVerifiedAt,
  });

  static List<String> _stringList(dynamic value) {
    if (value is List) return value.map((e) => e.toString()).where((e) => e.isNotEmpty).toList(growable: false);
    return const [];
  }

  static bool _bool(dynamic value) => value == true;

  static bool? _nullableBool(dynamic value) => value is bool ? value : null;

  static String? _text(dynamic value) {
    final s = value?.toString().trim();
    return (s == null || s.isEmpty) ? null : s;
  }

  static double? _double(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  factory ProviderDirectoryEntry.fromJson(Map<String, dynamic> json) => ProviderDirectoryEntry(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        providerType: _text(json['provider_type']) ?? ProviderType.other,
        type: _text(json['type']) ?? 'service',
        address: json['address']?.toString() ?? '',
        city: _text(json['city']),
        state: _text(json['state']),
        postalCode: _text(json['postal_code']),
        lat: _double(json['lat']),
        lng: _double(json['lng']),
        distanceMiles: _double(json['distance_miles']) ?? 0,
        phone: _text(json['phone']),
        contactEmail: _text(json['contact_email']),
        website: _text(json['website']),
        hours: _text(json['hours']),
        availability: _text(json['availability']) ?? 'Hours not available',
        description: _text(json['description']),
        servicesOffered: _text(json['services_offered']),
        serviceArea: _text(json['service_area']),
        serviceKinds: _stringList(json['service_kinds']),
        capabilities: _stringList(json['capabilities']),
        populationsServed: _stringList(json['populations_served']),
        conditionsServed: _stringList(json['conditions_served']),
        insuranceAccepted: _stringList(json['insurance_accepted']),
        doesRepairs: _bool(json['does_repairs']),
        doesRentals: _bool(json['does_rentals']),
        doesSales: _bool(json['does_sales']),
        doesCrtCustomWheelchairs: _bool(json['does_crt_custom_wheelchairs']),
        doesWheelchairEvalsClinical: _bool(json['does_wheelchair_evals_clinical']),
        doesSeatingPositioning: _bool(json['does_seating_positioning']),
        doesHomeModifications: _bool(json['does_home_modifications']),
        doesInstallation: _bool(json['does_installation']),
        doesInHomeService: _bool(json['does_in_home_service']),
        doesInsuranceCoordination: _bool(json['does_insurance_coordination']),
        acceptsMedicaid: _nullableBool(json['accepts_medicaid']),
        acceptsMedicare: _nullableBool(json['accepts_medicare']),
        geoPrecision: _text(json['geo_precision']) ?? 'approximate',
        needsVerification: _bool(json['needs_verification']),
        lastVerifiedAt: json['last_verified_at'] == null ? null : DateTime.tryParse(json['last_verified_at'].toString()),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'provider_type': providerType,
        'type': type,
        'address': address,
        'city': city,
        'state': state,
        'postal_code': postalCode,
        'lat': lat,
        'lng': lng,
        'distance_miles': distanceMiles,
        'phone': phone,
        'contact_email': contactEmail,
        'website': website,
        'hours': hours,
        'availability': availability,
        'description': description,
        'services_offered': servicesOffered,
        'service_area': serviceArea,
        'service_kinds': serviceKinds,
        'capabilities': capabilities,
        'populations_served': populationsServed,
        'conditions_served': conditionsServed,
        'insurance_accepted': insuranceAccepted,
        'does_repairs': doesRepairs,
        'does_rentals': doesRentals,
        'does_sales': doesSales,
        'does_crt_custom_wheelchairs': doesCrtCustomWheelchairs,
        'does_wheelchair_evals_clinical': doesWheelchairEvalsClinical,
        'does_seating_positioning': doesSeatingPositioning,
        'does_home_modifications': doesHomeModifications,
        'does_installation': doesInstallation,
        'does_in_home_service': doesInHomeService,
        'does_insurance_coordination': doesInsuranceCoordination,
        'accepts_medicaid': acceptsMedicaid,
        'accepts_medicare': acceptsMedicare,
        'geo_precision': geoPrecision,
        'needs_verification': needsVerification,
        'last_verified_at': lastVerifiedAt?.toIso8601String(),
      };

  ProviderDirectoryEntry copyWith({
    String? id,
    String? name,
    String? providerType,
    String? type,
    String? address,
    String? city,
    String? state,
    String? postalCode,
    double? lat,
    double? lng,
    double? distanceMiles,
    String? phone,
    String? contactEmail,
    String? website,
    String? hours,
    String? availability,
    String? description,
    String? servicesOffered,
    String? serviceArea,
    List<String>? serviceKinds,
    List<String>? capabilities,
    List<String>? populationsServed,
    List<String>? conditionsServed,
    List<String>? insuranceAccepted,
    bool? doesRepairs,
    bool? doesRentals,
    bool? doesSales,
    bool? doesCrtCustomWheelchairs,
    bool? doesWheelchairEvalsClinical,
    bool? doesSeatingPositioning,
    bool? doesHomeModifications,
    bool? doesInstallation,
    bool? doesInHomeService,
    bool? doesInsuranceCoordination,
    bool? acceptsMedicaid,
    bool? acceptsMedicare,
    String? geoPrecision,
    bool? needsVerification,
    DateTime? lastVerifiedAt,
  }) =>
      ProviderDirectoryEntry(
        id: id ?? this.id,
        name: name ?? this.name,
        providerType: providerType ?? this.providerType,
        type: type ?? this.type,
        address: address ?? this.address,
        city: city ?? this.city,
        state: state ?? this.state,
        postalCode: postalCode ?? this.postalCode,
        lat: lat ?? this.lat,
        lng: lng ?? this.lng,
        distanceMiles: distanceMiles ?? this.distanceMiles,
        phone: phone ?? this.phone,
        contactEmail: contactEmail ?? this.contactEmail,
        website: website ?? this.website,
        hours: hours ?? this.hours,
        availability: availability ?? this.availability,
        description: description ?? this.description,
        servicesOffered: servicesOffered ?? this.servicesOffered,
        serviceArea: serviceArea ?? this.serviceArea,
        serviceKinds: serviceKinds ?? this.serviceKinds,
        capabilities: capabilities ?? this.capabilities,
        populationsServed: populationsServed ?? this.populationsServed,
        conditionsServed: conditionsServed ?? this.conditionsServed,
        insuranceAccepted: insuranceAccepted ?? this.insuranceAccepted,
        doesRepairs: doesRepairs ?? this.doesRepairs,
        doesRentals: doesRentals ?? this.doesRentals,
        doesSales: doesSales ?? this.doesSales,
        doesCrtCustomWheelchairs: doesCrtCustomWheelchairs ?? this.doesCrtCustomWheelchairs,
        doesWheelchairEvalsClinical: doesWheelchairEvalsClinical ?? this.doesWheelchairEvalsClinical,
        doesSeatingPositioning: doesSeatingPositioning ?? this.doesSeatingPositioning,
        doesHomeModifications: doesHomeModifications ?? this.doesHomeModifications,
        doesInstallation: doesInstallation ?? this.doesInstallation,
        doesInHomeService: doesInHomeService ?? this.doesInHomeService,
        doesInsuranceCoordination: doesInsuranceCoordination ?? this.doesInsuranceCoordination,
        acceptsMedicaid: acceptsMedicaid ?? this.acceptsMedicaid,
        acceptsMedicare: acceptsMedicare ?? this.acceptsMedicare,
        geoPrecision: geoPrecision ?? this.geoPrecision,
        needsVerification: needsVerification ?? this.needsVerification,
        lastVerifiedAt: lastVerifiedAt ?? this.lastVerifiedAt,
      );

  bool get servesAdults => populationsServed.isEmpty || populationsServed.contains('adults') || populationsServed.contains('all_ages');

  bool get isPediatricOnly => populationsServed.length == 1 && populationsServed.first == 'pediatric';

  /// Short human label for the provider type.
  String get providerTypeLabel => ProviderType.label(providerType);
}

/// Canonical provider type values stored in `resources_curated.provider_type`.
class ProviderType {
  static const String crtVendor = 'crt_vendor';
  static const String clinicalEval = 'clinical_eval';
  static const String repairRentalRetail = 'repair_rental_retail';
  static const String generalDme = 'general_dme';
  static const String homeAccessibility = 'home_accessibility';
  static const String independentLiving = 'independent_living';
  static const String other = 'other';

  static const List<String> all = [
    crtVendor,
    clinicalEval,
    repairRentalRetail,
    generalDme,
    homeAccessibility,
    independentLiving,
    other,
  ];

  static String label(String value) {
    switch (value) {
      case crtVendor:
        return 'Complex rehab (CRT) vendor';
      case clinicalEval:
        return 'Clinical seating/wheelchair evaluation';
      case repairRentalRetail:
        return 'Repair, rental & retail mobility';
      case generalDme:
        return 'General DME / medical supply';
      case homeAccessibility:
        return 'Home accessibility (ramps, lifts)';
      case independentLiving:
        return 'Independent living / disability resource';
      default:
        return 'Service provider';
    }
  }
}
