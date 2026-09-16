import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:wellspring/models/condition_detail.dart';
import 'package:wellspring/models/provider_directory_entry.dart';
import 'package:wellspring/models/resource.dart';
import 'package:wellspring/models/tracker_entry.dart';
import 'package:wellspring/models/user.dart' as models;
import 'package:wellspring/openai/openai_config.dart';
import 'package:wellspring/services/condition_service.dart';
import 'package:wellspring/services/location_intelligence_service.dart';
import 'package:wellspring/services/provider_directory_service.dart';
import 'package:wellspring/services/resource_service.dart';
import 'package:wellspring/services/tracker_service.dart';
import 'package:wellspring/services/user_service.dart';
import 'package:wellspring/utils/tracker_analytics.dart';

/// ARIE's contextual intelligence layer.
///
/// This service is intentionally "thin":
/// - Builds a structured, permission-aware context bundle.
/// - Finds candidate resources (when location is permitted) and scores them.
/// - Asks OpenAI to turn that bundle into a patient-facing explanation + next steps.
///
/// It does NOT diagnose, and it avoids using precise location unless necessary.
class ArieSupportEngine {
  final UserService _users;
  final ConditionService _conditions;
  final TrackerService _tracker;
  final ResourceService _resources;
  final LocationIntelligenceService _location;
  final ProviderDirectoryService _directory;
  final OpenAIClient _ai;

  ArieSupportEngine({
    UserService? users,
    ConditionService? conditions,
    TrackerService? tracker,
    ResourceService? resources,
    LocationIntelligenceService? location,
    ProviderDirectoryService? directory,
    OpenAIClient? ai,
  })  : _users = users ?? UserService(),
        _conditions = conditions ?? ConditionService(),
        _tracker = tracker ?? TrackerService(),
        _resources = resources ?? ResourceService(),
        _location = location ?? LocationIntelligenceService(),
        _directory = directory ?? ProviderDirectoryService(),
        _ai = ai ?? OpenAIClient();

  Future<ArieSupportResponse> answer({
    required String question,
    required String requesterUserId,
    String? patientId,
    bool includeLocationIfPermitted = true,
  }) async {
    final targetUserId = patientId ?? requesterUserId;

    final user = await _users.getUserById(targetUserId);
    if (user == null) {
      return const ArieSupportResponse(
        answer: 'I could not load your profile right now. Please try again in a moment.',
        steps: [],
        recommendations: [],
        safetyNotes: [],
      );
    }

    final conditionNamesById = await _loadConditionNames(user.conditions);
    final conditionDetailsSummary = _buildConditionDetailsSummary(user, conditionNamesById);

    // Longitudinal tracker analysis: last 45 entries is a good balance.
    final entries = await _tracker.getRecentEntries(targetUserId, limit: 45, includeNutrition: false);
    final trackerSummary = _summarizeTracker(entries);

    // Location is OS-permission-aware and privacy-by-default.
    // There is no in-app enable toggle: if the OS grants permission, we use a
    // coarse/rounded location for local recommendations.
    final Map<String, dynamic> arieLocPref =
        (user.preferences[LocationIntelligenceService.prefKey] as Map<String, dynamic>?)?.cast<String, dynamic>() ??
            <String, dynamic>{};

    final int rounding =
        (arieLocPref['precisionDecimals'] as int?) ?? LocationIntelligenceService.defaultRoundingDecimals;
    final double maxMiles = (arieLocPref['maxTravelMiles'] as num?)?.toDouble() ?? 20;

    // Single source of truth for "Preferred location": the existing user profile field.
    // This is already shown on Profile and used by Resources.
    final Map<String, dynamic> savedPreferredLoc =
        (user.preferences['location'] as Map<String, dynamic>?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    final double? savedLat = (savedPreferredLoc['lat'] as num?)?.toDouble();
    final double? savedLng = (savedPreferredLoc['lng'] as num?)?.toDouble();
    final String? savedLabel = (savedPreferredLoc['label'] as String?)?.trim();
    final String? preferredLocationText = (savedLabel == null || savedLabel.isEmpty) ? null : savedLabel;

    ArieApproxLocation? approx;
    if (includeLocationIfPermitted) {
      final p = await _location.ensurePermission(requestIfNeeded: false);
      if (_location.isUsablePermission(p)) {
        debugPrint('ArieSupportEngine: OS location permission granted; using coarse location (rounding=$rounding)');
        approx = await _location.getApproxLocation(roundingDecimals: rounding);
      } else {
        debugPrint('ArieSupportEngine: OS location permission not granted; skipping device location');
      }
    }

    // If device location isn't available, fall back to the user's saved Preferred location coords.
    if (approx == null && savedLat != null && savedLng != null) {
      approx = ArieApproxLocation(
        lat: _roundForPrivacy(savedLat, rounding),
        lng: _roundForPrivacy(savedLng, rounding),
        precision: rounding,
      );
      debugPrint(
        'ArieSupportEngine: using saved Preferred location fallback (rounding=$rounding, label="${preferredLocationText ?? ''}")',
      );
    }

    final arieCategory = _inferCategory(question);

    // Curated, geolocation-based provider directory (intent -> typed capabilities).
    // This takes priority over web/Places results because entries are vetted and
    // tagged (CRT vendor vs repair shop vs seating clinic vs ramp installer).
    final int? userAgeForDirectory = _inferUserAge(user);
    ProviderDirectoryResult? directoryResult;
    if (approx != null) {
      try {
        directoryResult = await _directory.searchForRequest(
          request: question,
          userLat: approx.lat,
          userLng: approx.lng,
          radiusMiles: maxMiles <= 0 ? ProviderDirectoryService.defaultRadiusMiles : maxMiles,
          userAge: userAgeForDirectory,
        );
        debugPrint(
          'ArieSupportEngine: directory intent=${directoryResult.query.intent.name} '
          'returned ${directoryResult.entries.length} curated providers',
        );
      } catch (e) {
        debugPrint('ArieSupportEngine: provider directory lookup failed: $e');
      }
    }

    final candidates = await _findCandidateResources(
      category: arieCategory,
      user: user,
      approx: approx,
      maxMiles: maxMiles,
      preferredLocationText: preferredLocationText,
    );

    final scored = _scoreResources(
      resources: candidates,
      user: user,
      approx: approx,
      arieCategory: arieCategory,
      conditionNamesById: conditionNamesById,
    );

    // Keep the AI context small: every extra candidate costs tokens, and the
    // gpt-4o-family per-minute token budget is what caused intermittent
    // "trouble generating a response" failures. When we already have vetted
    // curated providers, we only need a few web/Places candidates as backup.
    final int candidateLimit = (directoryResult?.entries.isNotEmpty ?? false) ? 4 : 6;
    final top = scored.take(candidateLimit).toList(growable: false);

    String sourceFromId(String id) {
      if (id.startsWith('gpl_')) return 'google_places';
      if (id.startsWith('osm_')) return 'openstreetmap';
      if (id.startsWith('cur_')) return 'curated';
      if (id.startsWith('sug_')) return 'suggestion';
      if (id.startsWith('nom_')) return 'openstreetmap';
      return 'unknown';
    }

    String reliabilityForSource(String source) {
      switch (source) {
        case 'curated':
          return 'high';
        case 'google_places':
          return 'medium';
        case 'openstreetmap':
          return 'medium';
        case 'suggestion':
          return 'low';
        default:
          return 'unknown';
      }
    }

    final aiBundle = {
      'question': question,
      'targetUser': {
        'role': user.role.value,
        'conditions': [for (final id in user.conditions) {'id': id, 'name': conditionNamesById[id] ?? id}],
        'diagnosisDate': user.diagnosisDate?.toIso8601String(),
        'interests': user.interests,
        'preferences': _minimizePreferences(user.preferences),
        'conditionDetailsSummary': conditionDetailsSummary,
      },
      'trackerSummary': trackerSummary,
      'location': approx?.toJson(),
      'preferredLocationText': preferredLocationText,
      'resourceCategoryGuess': arieCategory,
      'resourceDetailFields': _detailFieldsForCategory(arieCategory),
      'universalRecordFields': const [
        'name',
        'category',
        'subcategory',
        'description',
        'location',
        'serviceArea',
        'onlineInPersonAvailability',
        'contactInformation',
        'website',
        'populationsServed',
        'disabilityFocus',
        'ageRestrictions',
        'eligibility',
        'insuranceAccepted',
        'fundingAccepted',
        'cost',
        'financialAssistance',
        'accessibilityFeatures',
        'servicesOffered',
        'availabilityWaitlist',
        'hours',
        'referralRequirements',
        'applicationProcess',
        'requiredDocumentation',
        'deadlines',
        'languages',
        'transportationOptions',
        'caregiverPolicies',
        'reviews',
        'userNotes',
        'source',
        'sourceReliability',
        'lastVerifiedDate',
        'currentStatus',
      ],
      // Highest-trust source: curated directory matched by intent + geolocation.
      'directoryIntent': directoryResult?.query.intent.name,
      'directoryIntentRationale': directoryResult?.query.rationale,
      'curatedDirectoryProviders': [
        for (final e in (directoryResult?.entries ?? const <ProviderDirectoryEntry>[]).take(6))
          {
            'id': e.id,
            'name': e.name,
            'providerType': e.providerType,
            'providerTypeLabel': e.providerTypeLabel,
            'address': e.address,
            'city': e.city,
            'state': e.state,
            'distanceMiles': e.distanceMiles,
            'phone': e.phone,
            'contactEmail': e.contactEmail,
            'website': e.website,
            'hours': e.hours ?? e.availability,
            'servicesOffered': e.servicesOffered,
            'serviceArea': e.serviceArea,
            'serviceKinds': e.serviceKinds,
            'capabilities': e.capabilities,
            'populationsServed': e.populationsServed,
            'conditionsServed': e.conditionsServed,
            'insuranceAccepted': e.insuranceAccepted,
            'doesRepairs': e.doesRepairs,
            'doesRentals': e.doesRentals,
            'doesSales': e.doesSales,
            'doesCrtCustomWheelchairs': e.doesCrtCustomWheelchairs,
            'doesWheelchairEvalsClinical': e.doesWheelchairEvalsClinical,
            'doesSeatingPositioning': e.doesSeatingPositioning,
            'doesHomeModifications': e.doesHomeModifications,
            'doesInstallation': e.doesInstallation,
            'doesInHomeService': e.doesInHomeService,
            'doesInsuranceCoordination': e.doesInsuranceCoordination,
            'acceptsMedicaid': e.acceptsMedicaid,
            'acceptsMedicare': e.acceptsMedicare,
            'geoPrecision': e.geoPrecision,
            'needsVerification': e.needsVerification,
            'source': 'curated_directory',
            'sourceReliability': 'high',
            'lastVerifiedDate': e.lastVerifiedAt?.toIso8601String(),
          }
      ],
      'recommendationGuidance': const {
        'preferCuratedDirectory': true,
        'minRecommendations': 3,
        'rules': [
          'Prefer curatedDirectoryProviders over candidateResources when both are present.',
          'Offer multiple distinct options (at least 3 when available), not a single pick.',
          'Do not mix service kinds: a repair request should not return a custom-wheelchair-only vendor as the top option.',
          'For adults, never recommend pediatric-only providers.',
          'For a new custom chair, pair a clinical evaluation clinic with a CRT vendor.',
          'Flag entries with needsVerification=true as "confirm details by phone".',
        ],
      },
      'candidateResources': [
        for (final r in top)
          {
            'id': r.resource.id,
            'name': r.resource.name,
            'type': r.resource.type,
            'address': r.resource.address,
            'locationLabel': r.resource.location,
            'distanceMiles': r.resource.distance,
            'lat': r.resource.lat,
            'lng': r.resource.lng,
            'contactPhone': r.resource.contactPhone,
            'contactEmail': r.resource.contactEmail,
            'website': r.resource.website,
            'googleMapsUrl': r.resource.googleMapsUrl,
            'availability': r.resource.availability,
            'hours': r.resource.hours,
            'rating': r.resource.rating,
            'reviewCount': r.resource.reviewCount,
            'priceLevel': r.resource.priceLevel,
            'placeTypes': r.resource.placeTypes,
            'accessibilityOptions': r.resource.accessibilityOptions,
            // Full review text is by far the largest part of the payload and adds
            // little value for recommendations; send only a couple of snippets.
            'reviews': _trimReviews(r.resource.reviews),
            'specialtyConditionIds': r.resource.specialty,
            'source': sourceFromId(r.resource.id),
            'sourceReliability': reliabilityForSource(sourceFromId(r.resource.id)),
            // We don't have a true verification timestamp for external sources;
            // we treat "last verified" as "when fetched".
            'lastVerifiedDate': DateTime.now().toIso8601String(),
            'currentStatus': 'unknown',
            'score': r.totalScore,
            'scoreBreakdown': r.breakdown,
          }
      ],
      'safety': {
        'noDiagnosis': true,
        'noCausation': true,
        'locationPrecision': approx == null ? 'none' : 'coarse',
      },
    };

    final ai = await _ai.generatePersonalizedSupport(contextJson: jsonEncode(aiBundle));
    return ai;
  }

  /// Reduces review payload size: at most 2 reviews, each truncated.
  List<Map<String, dynamic>> _trimReviews(List<Map<String, dynamic>> reviews) {
    final out = <Map<String, dynamic>>[];
    for (final r in reviews.take(2)) {
      final text = (r['text'] ?? r['comment'] ?? '').toString().trim();
      out.add({
        'rating': r['rating'],
        if (text.isNotEmpty) 'text': text.length > 220 ? '${text.substring(0, 220)}…' : text,
      });
    }
    return out;
  }

  Future<Map<String, String>> _loadConditionNames(List<String> ids) async {
    try {
      final all = await _conditions.getAllConditions();
      final byId = {for (final c in all) c.id: c.name};
      return {for (final id in ids) id: (byId[id] ?? id)};
    } catch (e) {
      debugPrint('ArieSupportEngine._loadConditionNames error: $e');
      return {for (final id in ids) id: id};
    }
  }

  String? _buildConditionDetailsSummary(models.User user, Map<String, String> conditionNamesById) {
    try {
      final buf = StringBuffer();
      for (final id in user.conditions) {
        final detail = ConditionDetail.tryFromUserPreferences(preferences: user.preferences, conditionId: id);
        if (detail == null || !detail.hasDetails) continue;
        final name = conditionNamesById[id] ?? id;
        buf.writeln(detail.toAiSummary(name));
        buf.writeln('');
      }
      final out = buf.toString().trim();
      return out.isEmpty ? null : out;
    } catch (e) {
      debugPrint('ArieSupportEngine._buildConditionDetailsSummary error: $e');
      return null;
    }
  }

  Map<String, dynamic> _summarizeTracker(List<TrackerEntry> entries) {
    // We keep the tracker summary small & non-identifying.
    try {
      final autoInsights = TrackerAnalytics.generateAutoInsights(entries);
      final mobility = TrackerAnalytics.calculateMobilityIndex(entries);
      return {
        'entryCount': entries.length,
        'range': entries.isEmpty
            ? null
            : {
                'from': entries.last.date.toIso8601String(),
                'to': entries.first.date.toIso8601String(),
              },
        'mobilityIndex': mobility,
        'autoInsights': autoInsights.take(8).toList(growable: false),
      };
    } catch (e) {
      debugPrint('ArieSupportEngine._summarizeTracker error: $e');
      return {'entryCount': entries.length};
    }
  }

  Map<String, dynamic> _minimizePreferences(Map<String, dynamic> prefs) {
    // Only the small subset relevant to recommendations.
    final out = <String, dynamic>{};
    try {
      final loc = (prefs['location'] as Map<String, dynamic>?) ?? const {};
      out['preferredLocation'] = {
        'label': loc['label'],
        'countryCode': loc['countryCode'],
        'lat': loc['lat'],
        'lng': loc['lng'],
      };
      final arieLoc = (prefs[LocationIntelligenceService.prefKey] as Map<String, dynamic>?) ?? const {};
      out['arieLocationCoarsening'] = {
        'maxTravelMiles': (arieLoc['maxTravelMiles'] as num?)?.toDouble(),
        'precisionDecimals': arieLoc['precisionDecimals'],
      };
      out['virtualPreferred'] = prefs['virtualPreferred'];
      out['costSensitivity'] = prefs['costSensitivity'];
      out['accessibility'] = prefs['accessibility'];
    } catch (e) {
      debugPrint('ArieSupportEngine._minimizePreferences error: $e');
    }
    return out;
  }

  double _roundForPrivacy(double value, int decimals) {
    final mod = math.pow(10, decimals).toDouble();
    return (value * mod).round() / mod;
  }

  String _inferCategory(String question) {
    final q = question.toLowerCase();
    if (q.contains('transport') || q.contains('ride') || q.contains('bus') || q.contains('uber')) return 'Transportation Services';
    if (q.contains('wheelchair') && (q.contains('repair') || q.contains('fix'))) return 'Equipment Repair & Maintenance';
    if (q.contains('equipment') || q.contains('dme') || q.contains('supplies')) return 'Durable Medical Equipment Providers';
    if (q.contains('therapy') || q.contains('pt') || q.contains('ot') || q.contains('rehab')) return 'Therapy & Rehabilitation Facilities';
    if (q.contains('home health')) return 'Home Health Agencies';
    if (q.contains('aide') || q.contains('attendant') || q.contains('caregiver')) return 'Aide / Personal Care / Attendant Providers';
    if (q.contains('support group') || q.contains('peer')) return 'Support Groups';
    if (q.contains('insurance') || q.contains('medicaid') || q.contains('waiver')) return 'Insurance / Medicaid / State Insurance';
    return 'General';
  }

  List<String> _detailFieldsForCategory(String category) {
    // These are the fields ARIE should try to provide for each recommended resource.
    // If information is unavailable, ARIE should mark it as unknown and suggest
    // specific questions to ask.
    switch (category) {
      case 'Therapy & Rehabilitation Facilities':
        return const [
          'locationOrServiceArea',
          'disabilityFocus',
          'insuranceCoverage',
          'accessibility',
          'prices',
          'reviews',
          'scheduling',
          'waitlists',
          'telehealth',
          'referralRequirements',
          'frequency',
          'sessionLength',
          'inpatientOutpatient',
          'therapyTypes',
          'specializedEquipmentPrograms',
          'transportationOptions',
          'outcomesExperienceRatings',
        ];
      case 'Transportation Services':
        return const [
          'geographicCoverage',
          'eligibility',
          'accessibility',
          'prices',
          'insuranceFunding',
          'reservationRequirements',
          'sameDayService',
          'operatingHours',
          'transportationType',
          'wheelchairAccommodation',
          'attendantPolicies',
          'reviews',
        ];
      case 'Equipment Repair & Maintenance':
        return const [
          'serviceArea',
          'insuranceWarrantyCoverage',
          'prices',
          'reviews',
          'turnaroundTime',
          'inHomeMobileRepair',
          'equipmentCategoriesServiced',
          'manufacturersSupported',
          'emergencyRepair',
          'partsAvailability',
          'temporaryLoanerEquipment',
        ];
      case 'Durable Medical Equipment Providers':
        return const [
          'locationOrServiceArea',
          'insuranceCoverage',
          'medicaidMedicareParticipation',
          'pricesCopays',
          'reviews',
          'delivery',
          'authorizationRequirements',
          'equipmentCategories',
          'rentalsPurchases',
          'customEquipment',
          'assessmentsFittings',
          'setupTraining',
          'maintenance',
          'repairServices',
          'loanerEquipment',
        ];
      default:
        return const [
          'locationOrServiceArea',
          'eligibility',
          'insuranceCoverage',
          'accessibility',
          'prices',
          'reviews',
          'availabilityScheduling',
          'referralRequirements',
          'virtualOptions',
          'contactMethods',
        ];
    }
  }

  Future<List<Resource>> _findCandidateResources({
    required String category,
    required models.User user,
    required ArieApproxLocation? approx,
    required double maxMiles,
    required String? preferredLocationText,
  }) async {
    if (approx == null && (preferredLocationText == null || preferredLocationText.trim().isEmpty)) return const [];

    debugPrint(
      'ArieSupportEngine: _findCandidateResources(category="$category", maxMiles=$maxMiles, '
      'lat=${approx?.lat}, lng=${approx?.lng}, preferred="${preferredLocationText ?? ''}")',
    );

    // Translate ARIE category to ResourceService query knobs.
    final query = switch (category) {
      'Transportation Services' => 'wheelchair accessible transportation',
      'Equipment Repair & Maintenance' => 'wheelchair repair',
      // Expand intent so Places returns better adult mobility equipment options.
      'Durable Medical Equipment Providers' => 'wheelchair store',
      'Therapy & Rehabilitation Facilities' => 'rehabilitation',
      'Home Health Agencies' => 'home health',
      'Aide / Personal Care / Attendant Providers' => 'personal care aide',
      'Support Groups' => 'support group',
      _ => 'disability services',
    };

    final userAge = _inferUserAge(user);

    try {
      final resources = await _resources.searchResources(
        query: query,
        userLat: approx?.lat,
        userLng: approx?.lng,
        maxDistance: maxMiles,
        location: preferredLocationText,
        sortByRating: false,
        // If the user has known conditions, pass them through so curated items can be filtered.
        conditions: user.conditions,
        userAge: userAge,
      );
      debugPrint('ArieSupportEngine: _findCandidateResources returned ${resources.length} resources');
      return resources;
    } catch (e) {
      debugPrint('ArieSupportEngine._findCandidateResources error: $e');
      return const [];
    }
  }

  int? _inferUserAge(models.User user) {
    try {
      final prefs = user.preferences;
      final ageRaw = prefs['age'];
      if (ageRaw is int && ageRaw > 0 && ageRaw < 120) return ageRaw;
      if (ageRaw is num) {
        final a = ageRaw.toInt();
        if (a > 0 && a < 120) return a;
      }
      if (ageRaw is String) {
        final a = int.tryParse(ageRaw.trim());
        if (a != null && a > 0 && a < 120) return a;
      }

      final dobRaw = prefs['dateOfBirth'] ?? prefs['dob'] ?? prefs['date_of_birth'];
      if (dobRaw is String && dobRaw.trim().isNotEmpty) {
        final dob = DateTime.tryParse(dobRaw.trim());
        if (dob != null) {
          final now = DateTime.now();
          var age = now.year - dob.year;
          final hadBirthday = (now.month > dob.month) || (now.month == dob.month && now.day >= dob.day);
          if (!hadBirthday) age -= 1;
          if (age > 0 && age < 120) return age;
        }
      }
    } catch (_) {}
    return null;
  }

  List<_ScoredResource> _scoreResources({
    required List<Resource> resources,
    required models.User user,
    required ArieApproxLocation? approx,
    required String arieCategory,
    required Map<String, String> conditionNamesById,
  }) {
    final out = <_ScoredResource>[];
    for (final r in resources) {
      final breakdown = <String, double>{};

      // Condition match (0..1)
      final condOverlap = _overlapScore(user.conditions.toSet(), r.specialty.toSet());
      breakdown['conditionMatch'] = condOverlap;

      // Geographic (0..1). Prefer within max range; don't over-penalize slightly further.
      final dist = (r.distance ?? 9999).toDouble();
      final geo = dist.isInfinite || dist.isNaN
          ? 0.4
          : (1 / (1 + (dist / 10))).clamp(0.0, 1.0);
      breakdown['geographicMatch'] = geo;

      // Quality (0..1)
      final rating = (r.rating ?? 0).toDouble();
      final reviews = (r.reviewCount ?? 0).toDouble();
      final ratingNorm = (rating / 5).clamp(0.0, 1.0);
      final reviewsNorm = (math.log(1 + reviews) / math.log(1 + 500)).clamp(0.0, 1.0);
      breakdown['quality'] = (ratingNorm * 0.7 + reviewsNorm * 0.3).clamp(0.0, 1.0);

      // Accessibility: we only score if the user declared needs.
      final accessibility = (user.preferences['accessibility'] as Map<String, dynamic>?) ?? const {};
      final needsWheelchair = (accessibility['wheelchairUser'] as bool?) ?? false;
      // Resource model doesn't guarantee accessibility flags, so we infer gently.
      final nameHints = r.name.toLowerCase();
      final access = !needsWheelchair
          ? 0.5
          : (nameHints.contains('accessible') || nameHints.contains('wheelchair') ? 0.9 : 0.45);
      breakdown['accessibilityMatch'] = access;

      // Category fit (0..1) is heuristic based on the query/returned type.
      final cat = _categoryFit(arieCategory, r.type);
      breakdown['categoryFit'] = cat;

      final weights = _weightsForCategory(arieCategory);
      double total = 0;
      for (final w in weights.entries) {
        total += (breakdown[w.key] ?? 0) * w.value;
      }

      out.add(_ScoredResource(resource: r, totalScore: (total * 100).round(), breakdown: breakdown));
    }

    out.sort((a, b) => b.totalScore.compareTo(a.totalScore));
    return out;
  }

  Map<String, double> _weightsForCategory(String category) {
    // Sum should be ~1.
    switch (category) {
      case 'Therapy & Rehabilitation Facilities':
        return {
          'conditionMatch': 0.30,
          'accessibilityMatch': 0.20,
          'geographicMatch': 0.20,
          'quality': 0.20,
          'categoryFit': 0.10,
        };
      case 'Transportation Services':
        return {
          'accessibilityMatch': 0.30,
          'geographicMatch': 0.30,
          'quality': 0.20,
          'categoryFit': 0.20,
        };
      default:
        return {
          'conditionMatch': 0.20,
          'accessibilityMatch': 0.20,
          'geographicMatch': 0.25,
          'quality': 0.20,
          'categoryFit': 0.15,
        };
    }
  }

  double _overlapScore(Set<String> a, Set<String> b) {
    if (a.isEmpty || b.isEmpty) return 0.25; // unknown specialty
    final inter = a.intersection(b).length;
    final union = a.union(b).length;
    if (union == 0) return 0;
    return (inter / union).clamp(0.0, 1.0);
  }

  double _categoryFit(String category, String type) {
    final t = type.toLowerCase();
    if (category == 'Therapy & Rehabilitation Facilities') {
      return (t.contains('therap') || t.contains('center') || t.contains('service')) ? 0.9 : 0.6;
    }
    if (category == 'Transportation Services') {
      return (t.contains('transport') || t.contains('service')) ? 0.9 : 0.55;
    }
    return 0.7;
  }
}

class _ScoredResource {
  final Resource resource;
  final int totalScore;
  final Map<String, double> breakdown;

  const _ScoredResource({
    required this.resource,
    required this.totalScore,
    required this.breakdown,
  });
}
