import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wellspring/models/provider_directory_entry.dart';
import 'package:wellspring/supabase/supabase_config.dart';

/// The kind of help the user is asking for.
///
/// This is the bridge between free-text ("my power chair is broken") and the
/// typed capability columns in the curated directory.
enum ProviderIntent {
  wheelchairRepair,
  customWheelchair,
  wheelchairEvaluation,
  homeAccessibility,
  generalDme,
  unknown,
}

/// A resolved intent, translated into concrete directory filters.
class ProviderDirectoryQuery {
  final ProviderIntent intent;

  /// Provider types to include, in priority order (first = preferred).
  final List<String> providerTypes;
  final bool requireRepairs;
  final bool requireRentals;
  final bool requireSales;
  final bool requireCrt;
  final bool requireClinicalEval;
  final bool requireSeating;
  final bool requireHomeModifications;
  final bool requireInstallation;

  /// When true, boost providers that are currently open (used for urgent repair).
  final bool boostOpenNow;

  /// Human-readable explanation of why these filters were used.
  final String rationale;

  const ProviderDirectoryQuery({
    required this.intent,
    this.providerTypes = const [],
    this.requireRepairs = false,
    this.requireRentals = false,
    this.requireSales = false,
    this.requireCrt = false,
    this.requireClinicalEval = false,
    this.requireSeating = false,
    this.requireHomeModifications = false,
    this.requireInstallation = false,
    this.boostOpenNow = false,
    this.rationale = '',
  });

  ProviderDirectoryQuery relaxed() => ProviderDirectoryQuery(
        intent: intent,
        providerTypes: providerTypes,
        rationale: 'Relaxed capability filters to widen results.',
      );
}

/// Maps free-text requests to directory filters and queries Supabase by geolocation.
class ProviderDirectoryService {
  final SupabaseClient _supabase;

  ProviderDirectoryService({SupabaseClient? client}) : _supabase = client ?? SupabaseConfig.client;

  static const double defaultRadiusMiles = 40;

  /// Words that carry no directory signal and must never be ANDed into search.
  static const Set<String> _stopWords = {
    'i', 'a', 'an', 'the', 'my', 'me', 'we', 'our', 'is', 'am', 'are', 'was', 'were',
    'need', 'needs', 'needed', 'want', 'wants', 'looking', 'look', 'for', 'to', 'of',
    'in', 'on', 'at', 'and', 'or', 'please', 'help', 'find', 'get', 'getting', 'got',
    'can', 'could', 'would', 'should', 'do', 'does', 'did', 'have', 'has', 'had',
    'someone', 'somewhere', 'place', 'near', 'nearby', 'around', 'here', 'there',
    'it', 'its', 'with', 'about', 'new', 'now', 'asap', 'today',
  };

  /// Domain vocabulary expansion: if the user's words hit a key, we also search
  /// the related directory terms so CRT/repair providers surface correctly.
  static const Map<String, List<String>> _synonyms = {
    'wheelchair': ['wheelchair', 'mobility', 'powerchair', 'power chair', 'manual wheelchair', 'complex rehab', 'crt', 'seating'],
    'wheel chair': ['wheelchair', 'mobility', 'complex rehab', 'crt'],
    'chair': ['wheelchair', 'mobility', 'seating'],
    'broken': ['repair', 'repairs', 'service', 'maintenance'],
    'repair': ['repair', 'repairs', 'service', 'maintenance'],
    'fix': ['repair', 'repairs', 'service'],
    'battery': ['repair', 'service', 'power wheelchair'],
    'tire': ['repair', 'service'],
    'custom': ['custom wheelchair', 'complex rehab', 'crt', 'seating', 'positioning'],
    'seating': ['seating', 'positioning', 'complex seating', 'crt'],
    'cushion': ['cushions', 'seating', 'positioning'],
    'evaluation': ['evaluation', 'assessment', 'clinical', 'assistive technology'],
    'ramp': ['ramps', 'home accessibility', 'installation'],
    'stairlift': ['stairlifts', 'lifts', 'home accessibility'],
    'lift': ['lifts', 'patient lifts', 'home accessibility'],
    'scooter': ['scooter', 'mobility equipment', 'rentals'],
    'rent': ['rentals', 'rental'],
    'rental': ['rentals', 'rental'],
    'bed': ['hospital bed', 'dme'],
    'walker': ['walker', 'dme'],
    'dme': ['dme', 'medical supplies', 'mobility equipment'],
  };

  /// Normalizes a free-text query into a Postgres `websearch_to_tsquery` string.
  ///
  /// Critical detail: `websearch_to_tsquery` ANDs bare words, so passing the raw
  /// sentence ("i need a new wheelchair") requires *every* word to appear in a
  /// provider record and matches nothing. We therefore strip stop words and
  /// build an **OR** query of the meaningful terms plus domain synonyms.
  String? normalizeTextQuery(String? raw) {
    final q = raw?.trim();
    if (q == null || q.isEmpty) return null;

    final lower = q.toLowerCase();

    final terms = <String>{};

    // Multi-word synonym keys first (e.g. "wheel chair").
    for (final entry in _synonyms.entries) {
      if (lower.contains(entry.key)) terms.addAll(entry.value);
    }

    // Remaining meaningful single words from the user's own phrasing.
    for (final word in lower.split(RegExp(r'[^a-z0-9]+'))) {
      if (word.length < 3) continue;
      if (_stopWords.contains(word)) continue;
      terms.add(word);
    }

    if (terms.isEmpty) return null;

    // OR them together; quote multi-word phrases.
    final parts = terms.map((t) => t.contains(' ') ? '"$t"' : t).toList();
    return parts.join(' OR ');
  }

  /// Detects the user's intent from free text.
  ProviderIntent detectIntent(String text) {
    final q = text.toLowerCase();

    bool has(List<String> words) => words.any(q.contains);

    final mentionsWheelchair = has(['wheelchair', 'wheel chair', 'power chair', 'powerchair', 'manual chair', 'my chair']);

    final mentionsRepair = has([
      'repair', 'repairs', 'broken', 'break', 'fix', 'fixed', 'not working', 'stopped working',
      'flat tire', 'tire', 'battery died', 'battery', 'wont turn on', "won't turn on",
      'service my chair', 'maintenance', 'tune up', 'squeak', 'wheel came off',
    ]);
    final mentionsEval = has(['evaluation', 'eval', 'assessment', 'assess', 'seating clinic', 'atp', 'measured for', 'fitted for']);
    final mentionsCustom = has([
      'custom', 'custom chair', 'custom wheelchair', 'new chair', 'new wheelchair', 'another wheelchair',
      'replace my chair', 'replacement chair', 'complex rehab', 'crt', 'seating and positioning',
      'positioning', 'cushion', 'tilt', 'recline', 'power chair quote', 'upgrade my chair',
    ]);
    final mentionsHome = has(['ramp', 'stairlift', 'stair lift', 'chair lift', 'elevator', 'grab bar', 'bathroom modification', 'accessible bathroom', 'threshold', 'platform lift', 'home modification']);
    final mentionsDme = has(['dme', 'durable medical', 'medical supply', 'medical supplies', 'hospital bed', 'walker', 'commode', 'shower chair', 'rental', 'rent a']);

    // Repair wins when something is already broken — even if they also say
    // "custom", because they need a service department today.
    if (mentionsRepair && mentionsWheelchair) return ProviderIntent.wheelchairRepair;
    if (mentionsRepair && !mentionsHome) return ProviderIntent.wheelchairRepair;
    if (mentionsEval && !mentionsCustom) return ProviderIntent.wheelchairEvaluation;
    if (mentionsCustom) return ProviderIntent.customWheelchair;
    if (mentionsHome) return ProviderIntent.homeAccessibility;

    // Any bare wheelchair request ("i need a new wheelchair", "help with a
    // wheelchair") should be treated as a complex/custom mobility need: those
    // users almost always require a CRT vendor plus a clinical evaluation.
    if (mentionsWheelchair) return ProviderIntent.customWheelchair;

    if (mentionsDme) return ProviderIntent.generalDme;
    return ProviderIntent.unknown;
  }

  /// Translates an intent into the directory filter set.
  ProviderDirectoryQuery buildQuery(ProviderIntent intent) {
    switch (intent) {
      case ProviderIntent.wheelchairRepair:
        return const ProviderDirectoryQuery(
          intent: ProviderIntent.wheelchairRepair,
          providerTypes: [
            ProviderType.crtVendor,
            ProviderType.repairRentalRetail,
            ProviderType.generalDme,
          ],
          requireRepairs: true,
          boostOpenNow: true,
          rationale:
              'Repair/service: complex rehab (CRT) service departments first (they can repair custom chairs), then mobility repair shops.',
        );
      case ProviderIntent.customWheelchair:
        return const ProviderDirectoryQuery(
          intent: ProviderIntent.customWheelchair,
          providerTypes: [ProviderType.crtVendor, ProviderType.clinicalEval],
          rationale:
              'New or custom chair: complex rehab (CRT) vendors, paired with a clinical seating/mobility evaluation, since custom needs require both.',
        );
      case ProviderIntent.wheelchairEvaluation:
        return const ProviderDirectoryQuery(
          intent: ProviderIntent.wheelchairEvaluation,
          providerTypes: [ProviderType.clinicalEval, ProviderType.crtVendor],
          requireClinicalEval: true,
          rationale: 'Evaluation first: clinical seating/mobility evaluation clinics, then CRT vendors to build the chair.',
        );
      case ProviderIntent.homeAccessibility:
        return const ProviderDirectoryQuery(
          intent: ProviderIntent.homeAccessibility,
          providerTypes: [ProviderType.homeAccessibility, ProviderType.repairRentalRetail],
          requireHomeModifications: true,
          requireInstallation: true,
          rationale: 'Ramps/lifts: home-accessibility companies that both supply and install.',
        );
      case ProviderIntent.generalDme:
        return const ProviderDirectoryQuery(
          intent: ProviderIntent.generalDme,
          providerTypes: [ProviderType.generalDme, ProviderType.repairRentalRetail],
          rationale: 'General DME: suppliers with sales and rentals.',
        );
      case ProviderIntent.unknown:
        return const ProviderDirectoryQuery(
          intent: ProviderIntent.unknown,
          rationale: 'No specific intent detected: showing all nearby curated providers.',
        );
    }
  }

  /// Convenience: detect intent from free text then search.
  Future<ProviderDirectoryResult> searchForRequest({
    required String request,
    required double userLat,
    required double userLng,
    double radiusMiles = defaultRadiusMiles,
    int? userAge,
    int maxResults = 25,
  }) async {
    final intent = detectIntent(request);
    final query = buildQuery(intent);
    final entries = await search(
      query: query,
      userLat: userLat,
      userLng: userLng,
      radiusMiles: radiusMiles,
      userAge: userAge,
      maxResults: maxResults,
      textQuery: request,
    );
    return ProviderDirectoryResult(query: query, entries: entries);
  }

  /// Geolocation-based curated directory search.
  ///
  /// Widening strategy (so users always get *several* options):
  /// 1. strict capability filters
  /// 2. same provider types, relaxed capabilities
  /// 3. any provider type in radius
  /// 4. double the radius
  Future<List<ProviderDirectoryEntry>> search({
    required ProviderDirectoryQuery query,
    required double userLat,
    required double userLng,
    double radiusMiles = defaultRadiusMiles,
    int? userAge,
    int maxResults = 25,
    String? textQuery,
  }) async {
    final excludePediatricOnly = userAge == null ? false : userAge >= 18;

    Future<List<ProviderDirectoryEntry>> run({
      required List<String> providerTypes,
      required bool strict,
      required double radius,
    }) =>
        _rpc(
          userLat: userLat,
          userLng: userLng,
          radiusMiles: radius,
          providerTypes: providerTypes,
          query: strict ? query : query.relaxed(),
          excludePediatricOnly: excludePediatricOnly,
          maxResults: maxResults,
          textQuery: textQuery,
        );

    var results = await run(providerTypes: query.providerTypes, strict: true, radius: radiusMiles);
    if (results.length < 3) {
      final relaxed = await run(providerTypes: query.providerTypes, strict: false, radius: radiusMiles);
      results = _merge(results, relaxed);
    }
    if (results.length < 3) {
      final anyType = await run(providerTypes: const [], strict: false, radius: radiusMiles);
      results = _merge(results, anyType);
    }
    if (results.isEmpty) {
      final wider = await run(providerTypes: const [], strict: false, radius: radiusMiles * 2);
      results = _merge(results, wider);
    }

    return _rank(results, query);
  }

  /// All curated providers near a point, no capability filtering.
  Future<List<ProviderDirectoryEntry>> nearby({
    required double userLat,
    required double userLng,
    double radiusMiles = defaultRadiusMiles,
    List<String> providerTypes = const [],
    int maxResults = 50,
  }) =>
      _rpc(
        userLat: userLat,
        userLng: userLng,
        radiusMiles: radiusMiles,
        providerTypes: providerTypes,
        query: const ProviderDirectoryQuery(intent: ProviderIntent.unknown),
        excludePediatricOnly: false,
        maxResults: maxResults,
        textQuery: null,
      );

  Future<List<ProviderDirectoryEntry>> _rpc({
    required double userLat,
    required double userLng,
    required double radiusMiles,
    required List<String> providerTypes,
    required ProviderDirectoryQuery query,
    required bool excludePediatricOnly,
    required int maxResults,
    required String? textQuery,
  }) async {
    try {
      final normalizedTextQuery = normalizeTextQuery(textQuery);
      final params = <String, dynamic>{
        'user_lat': userLat,
        'user_lng': userLng,
        'radius_miles': radiusMiles,
        'provider_types': providerTypes.isEmpty ? null : providerTypes,
        'require_repairs': query.requireRepairs,
        'require_rentals': query.requireRentals,
        'require_sales': query.requireSales,
        'require_crt': query.requireCrt,
        'require_clinical_eval': query.requireClinicalEval,
        'require_seating': query.requireSeating,
        'require_home_modifications': query.requireHomeModifications,
        'require_installation': query.requireInstallation,
        'exclude_pediatric_only': excludePediatricOnly,
        'max_results': maxResults,
      };

      // Important: PostgREST resolves RPC overloads by the set of named params.
      // Sending `text_query: null` still counts as providing that arg and can
      // trigger PGRST202 if the deployed function signature doesn't include it.
      if (normalizedTextQuery != null && normalizedTextQuery.isNotEmpty) {
        params['text_query'] = normalizedTextQuery;
      }

      dynamic data;
      try {
        data = await _supabase.rpc('search_provider_directory', params: params);
      } on PostgrestException catch (e) {
        // Backward compatibility: if the database function hasn't been updated
        // to include `text_query` yet, transparently retry without it.
        final isMissingFunction = e.code == 'PGRST202';
        final sentTextQuery = params.containsKey('text_query');
        if (isMissingFunction && sentTextQuery) {
          debugPrint(
            'ProviderDirectoryService: search_provider_directory signature mismatch (text_query not deployed yet). Retrying without text_query.',
          );
          params.remove('text_query');
          data = await _supabase.rpc('search_provider_directory', params: params);
        } else {
          rethrow;
        }
      }
      if (data is! List) return const [];
      return data
          .whereType<Map>()
          .map((e) => ProviderDirectoryEntry.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false);
    } on PostgrestException catch (e) {
      debugPrint('ProviderDirectoryService: search_provider_directory failed (${e.code}): ${e.message}');
      return const [];
    } catch (e, st) {
      debugPrint('ProviderDirectoryService: unexpected error: $e\n$st');
      return const [];
    }
  }

  List<ProviderDirectoryEntry> _merge(List<ProviderDirectoryEntry> a, List<ProviderDirectoryEntry> b) {
    final byId = <String, ProviderDirectoryEntry>{for (final e in a) e.id: e};
    for (final e in b) {
      byId.putIfAbsent(e.id, () => e);
    }
    return byId.values.toList();
  }

  /// Ranks by intent fit first, then distance.
  List<ProviderDirectoryEntry> _rank(List<ProviderDirectoryEntry> entries, ProviderDirectoryQuery query) {
    final priority = {for (var i = 0; i < query.providerTypes.length; i++) query.providerTypes[i]: i};

    double fit(ProviderDirectoryEntry e) {
      var score = 0.0;
      final rank = priority[e.providerType];
      if (rank != null) score += (query.providerTypes.length - rank) * 2.0;
      switch (query.intent) {
        case ProviderIntent.wheelchairRepair:
          if (e.doesRepairs) score += 4;
          if (e.doesInHomeService) score += 1.5;
          break;
        case ProviderIntent.customWheelchair:
          if (e.doesCrtCustomWheelchairs) score += 4;
          if (e.doesSeatingPositioning) score += 2;
          if (e.doesInsuranceCoordination) score += 1;
          // Custom needs usually require a clinical evaluation too, so keep
          // evaluation clinics visible rather than burying them.
          if (e.doesWheelchairEvalsClinical) score += 1.5;
          break;
        case ProviderIntent.wheelchairEvaluation:
          if (e.doesWheelchairEvalsClinical) score += 4;
          if (e.doesSeatingPositioning) score += 1.5;
          break;
        case ProviderIntent.homeAccessibility:
          if (e.doesHomeModifications) score += 3;
          if (e.doesInstallation) score += 2;
          break;
        case ProviderIntent.generalDme:
          if (e.doesSales) score += 2;
          if (e.doesRentals) score += 2;
          break;
        case ProviderIntent.unknown:
          break;
      }
      if (e.needsVerification) score -= 0.5;
      // Nearby bonus, gently decaying with distance.
      score += 3.0 / (1 + (e.distanceMiles / 10));
      return score;
    }

    final ranked = [...entries];
    ranked.sort((a, b) {
      final c = fit(b).compareTo(fit(a));
      if (c != 0) return c;
      return a.distanceMiles.compareTo(b.distanceMiles);
    });
    return ranked;
  }
}

/// Search output bundled with the filters that produced it.
class ProviderDirectoryResult {
  final ProviderDirectoryQuery query;
  final List<ProviderDirectoryEntry> entries;

  const ProviderDirectoryResult({required this.query, required this.entries});

  bool get isEmpty => entries.isEmpty;

  /// Grouped by provider type so a UI (or ARIE) can present distinct sections
  /// such as "CRT vendors" vs "Repair shops" vs "Home accessibility".
  Map<String, List<ProviderDirectoryEntry>> get groupedByProviderType {
    final out = <String, List<ProviderDirectoryEntry>>{};
    for (final e in entries) {
      out.putIfAbsent(e.providerType, () => []).add(e);
    }
    return out;
  }
}
