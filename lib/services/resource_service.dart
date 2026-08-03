import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wellspring/models/resource.dart';
import 'package:wellspring/supabase/supabase_config.dart';

class ResourceService {
  static const String _resourcesKey = 'resources_data';
  // WARNING: Client-side API key usage is suitable for testing only.
  // Restrict this key in Google Cloud Console to your preview domain.
  // For production, proxy requests through a secure backend (e.g., Firebase Functions).
  static const String _googlePlacesKey = 'AIzaSyA3iFM7lQ4Pu7gn8U19kk4Pr6cmVXOm244';

  // Shared HTTP client for keep-alive and connection reuse
  static final http.Client _client = http.Client();
  
  // Supabase client for curated resources
  final SupabaseClient _supabase = SupabaseConfig.client;

  // Simple in-memory cache with TTL and LRU eviction for faster repeat queries
  static final _searchCache = _MemoryCache<List<Resource>>(maxEntries: 50, ttl: const Duration(minutes: 10));
  static final _detailsCache = _MemoryCache<Map<String, String>>(maxEntries: 200, ttl: const Duration(hours: 1));

  bool get _isWeb => kIsWeb;

  // Infer simple specialty tags from free text (name) for better local filtering.
  List<String> _inferSpecialtiesFromText(String text) {
    final t = text.toLowerCase();
    final out = <String>{};
    if (t.contains('independent living')) out.add('Independent Living');
    if (t.contains('disability') || t.contains('paraquad')) out.add('Disability Services');
    if (t.contains('assistive')) out.add('Assistive Technology');
    if (t.contains('rehab')) out.add('Rehabilitation');
    return out.toList(growable: false);
  }

  // Extract specialty tags from OSM tags map.
  List<String> _specialtiesFromOsmTags(Map<String, dynamic> tags, String name) {
    final out = <String>{};
    try {
      final sf = (tags['social_facility'] ?? '').toString().toLowerCase();
      final sff = (tags['social_facility:for'] ?? '').toString().toLowerCase();
      final wheelchair = (tags['wheelchair'] ?? '').toString().toLowerCase();
      if (sf.contains('independent') || sf == 'independent_living') out.add('Independent Living');
      if (sf.contains('assisted') || sf == 'assisted_living') out.add('Assisted Living');
      if (sf.contains('shelter')) out.add('Shelter');
      if (sf.contains('residential')) out.add('Residential Home');
      if (sff.contains('disabled') || sff.contains('disability')) out.add('Disability Services');
      if (wheelchair == 'yes' || wheelchair == 'designated') out.add('Wheelchair Accessible');
    } catch (_) {}
    // Merge with name-inferred specialties
    out.addAll(_inferSpecialtiesFromText(name));
    return out.toList(growable: false);
  }

  String _cacheKeyForSearch({
    String? query,
    String? type,
    String? location,
    List<String>? conditions,
    double? maxDistance,
    double? userLat,
    double? userLng,
    bool? openNow,
    double? minRating,
    int? minUserRatings,
    List<int>? priceLevels,
    bool sortByRating = false,
    String? language,
    String? region,
    String? rankBy,
    List<String>? includeGoogleTypes,
  }) {
    final sb = StringBuffer('v5'); // bump to invalidate old keys
    sb
      ..write('|q=')
      ..write(query?.trim().toLowerCase() ?? '')
      ..write('|t=')
      ..write(type ?? '')
      ..write('|loc=')
      ..write(location ?? '')
      ..write('|lat=')
      ..write(userLat?.toStringAsFixed(5) ?? '')
      ..write('|lng=')
      ..write(userLng?.toStringAsFixed(5) ?? '')
      ..write('|max=')
      ..write(maxDistance?.toStringAsFixed(1) ?? '')
      ..write('|open=')
      ..write(openNow == true ? '1' : '0')
      ..write('|minR=')
      ..write(minRating?.toStringAsFixed(1) ?? '')
      ..write('|minU=')
      ..write(minUserRatings?.toString() ?? '')
      ..write('|prices=')
      ..write((priceLevels == null || priceLevels.isEmpty) ? '' : (priceLevels..sort()).join(','))
      ..write('|sort=')
      ..write(sortByRating ? 'rating' : 'distance')
      ..write('|lang=')
      ..write(language ?? '')
      ..write('|region=')
      ..write(region ?? '')
      ..write('|rank=')
      ..write(rankBy ?? '')
      ..write('|gtypes=')
      ..write((includeGoogleTypes == null || includeGoogleTypes.isEmpty) ? '' : (List.of(includeGoogleTypes)..sort()).join(','))
      ..write('|conds=')
      ..write((conditions == null || conditions.isEmpty) ? '' : (List.of(conditions)..sort()).join(','));
    return sb.toString();
  }

  Future<void> _initSampleData() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(_resourcesKey)) {
      final now = DateTime.now();
      // Base around a central coordinate (example: Chicago downtown)
      const baseLat = 41.8781;
      const baseLng = -87.6298;
      final sampleResources = [
        Resource(id: '1', name: 'City Medical Center - Neurology', type: 'center', specialty: ['1', '5'], location: 'Downtown', address: '123 Medical Plaza, Suite 200', distance: 2.3, lat: baseLat + 0.01, lng: baseLng - 0.01, contactPhone: '(555) 123-4567', contactEmail: 'neuro@citymedical.com', website: 'www.citymedical.com/neuro', availability: 'Mon-Fri 8AM-6PM', rating: 4.8, reviewCount: 127, createdAt: now, updatedAt: now),
        Resource(id: '2', name: 'Dr. Sarah Thompson', type: 'therapist', specialty: ['2', '4'], location: 'West Side', address: '456 Wellness Ave', distance: 3.7, lat: baseLat + 0.025, lng: baseLng - 0.035, contactPhone: '(555) 234-5678', contactEmail: 'dr.thompson@example.com', availability: 'Mon, Wed, Fri 9AM-5PM', rating: 4.9, reviewCount: 89, createdAt: now, updatedAt: now),
        Resource(id: '3', name: 'Diabetes Care Specialists', type: 'center', specialty: ['3'], location: 'North End', address: '789 Health Street', distance: 5.1, lat: baseLat + 0.06, lng: baseLng - 0.02, contactPhone: '(555) 345-6789', contactEmail: 'info@diabetescare.com', website: 'www.diabetescare.com', availability: 'Mon-Sat 7AM-7PM', rating: 4.7, reviewCount: 203, createdAt: now, updatedAt: now),
        Resource(id: '4', name: 'Riverside Physical Therapy', type: 'service', specialty: ['4', '5'], location: 'Riverside', address: '321 River Road', distance: 4.2, lat: baseLat - 0.03, lng: baseLng - 0.05, contactPhone: '(555) 456-7890', contactEmail: 'contact@riversidept.com', website: 'www.riversidept.com', availability: 'Mon-Fri 7AM-8PM, Sat 8AM-2PM', rating: 4.6, reviewCount: 156, createdAt: now, updatedAt: now),
        Resource(id: '5', name: 'Dr. Michael Chen - Pain Management', type: 'therapist', specialty: ['2', '4', '5'], location: 'Downtown', address: '567 Pain Relief Center', distance: 2.8, lat: baseLat - 0.015, lng: baseLng + 0.01, contactPhone: '(555) 567-8901', contactEmail: 'dr.chen@painrelief.com', availability: 'Tue, Thu 10AM-6PM', rating: 4.8, reviewCount: 94, createdAt: now, updatedAt: now),
        Resource(id: '6', name: 'Adaptive Living Center', type: 'service', specialty: ['5'], location: 'East Side', address: '890 Independence Way', distance: 6.3, lat: baseLat + 0.08, lng: baseLng + 0.03, contactPhone: '(555) 678-9012', contactEmail: 'info@adaptiveliving.com', website: 'www.adaptiveliving.com', availability: 'Mon-Sat 9AM-6PM', rating: 4.9, reviewCount: 178, createdAt: now, updatedAt: now),
        Resource(id: '7', name: 'MS Treatment Center', type: 'center', specialty: ['1'], location: 'Medical District', address: '234 Specialty Blvd', distance: 7.5, lat: baseLat - 0.09, lng: baseLng + 0.02, contactPhone: '(555) 789-0123', contactEmail: 'info@mscenter.com', website: 'www.mscenter.com', availability: 'Mon-Fri 8AM-5PM', rating: 4.9, reviewCount: 245, createdAt: now, updatedAt: now),
        Resource(id: '8', name: 'Wellness Mind Therapy', type: 'therapist', specialty: ['1', '2', '3', '4', '5'], location: 'Uptown', address: '678 Mental Health Lane', distance: 3.4, lat: baseLat + 0.015, lng: baseLng + 0.02, contactPhone: '(555) 890-1234', contactEmail: 'contact@wellnessmind.com', availability: 'Mon-Fri 9AM-7PM', rating: 4.7, reviewCount: 112, createdAt: now, updatedAt: now),
      ];
      await prefs.setString(_resourcesKey, jsonEncode(sampleResources.map((r) => r.toJson()).toList()));
    }
  }

  Future<List<Resource>> searchResources({
    String? query,
    String? type,
    String? location,
    List<String>? conditions,
    double? maxDistance,
    double? userLat,
    double? userLng,
    // Advanced tuning
    bool? openNow,
    double? minRating,
    int? minUserRatings,
    List<int>? priceLevels, // 0..4
    bool sortByRating = false,
    String? language, // e.g., 'en'
    String? region, // e.g., 'US' for country bias (TextSearch)
    String? rankBy, // 'distance' | 'prominence' (Nearby)
    List<String>? includeGoogleTypes, // explicit Google place types
  }) async {
    // Cache check first
    final cacheKey = _cacheKeyForSearch(
      query: query,
      type: type,
      location: location,
      conditions: conditions,
      maxDistance: maxDistance,
      userLat: userLat,
      userLng: userLng,
      openNow: openNow,
      minRating: minRating,
      minUserRatings: minUserRatings,
      priceLevels: priceLevels,
      sortByRating: sortByRating,
      language: language,
      region: region,
      rankBy: rankBy,
      includeGoogleTypes: includeGoogleTypes,
    );
    final cached = _searchCache.get(cacheKey);
    if (cached != null) {
      debugPrint('ResourceService: cache hit for search ($cacheKey) -> ${cached.length} items');
      return cached;
    }

    // Track whether any network failure occurred; don't cache empty on failures
    bool hadNetworkFailure = false;

    // Prefer live results via Google Places when coordinates are available
    if (userLat != null && userLng != null) {
      // 1) Try Google Places
      try {
        final gp = await _fetchNearbyFromGooglePlaces(
          userLat: userLat,
          userLng: userLng,
          query: query,
          typeFilter: type,
          maxDistanceMiles: maxDistance,
          openNow: openNow,
          minRating: minRating,
          minUserRatings: minUserRatings,
          priceLevels: priceLevels,
          sortByRating: sortByRating,
          language: language,
          region: region,
          rankBy: rankBy,
          includeGoogleTypes: includeGoogleTypes,
        );
        if (gp.isNotEmpty) {
          // Merge curated resources nearby
          final merged = await _mergeWithCurated(
            base: gp,
            userLat: userLat,
            userLng: userLng,
            maxDistanceMiles: maxDistance,
            typeFilter: type,
          );
          debugPrint('ResourceService: returning ${merged.length} Google+curated results');
          _searchCache.set(cacheKey, merged);
          return merged;
        }
      } catch (e, st) {
        hadNetworkFailure = true;
        debugPrint('ResourceService: Google Places fetch failed: $e\n$st');
      }

      // 2) Fallback to OpenStreetMap Overpass (with Cloud Functions proxy on web)
      try {
        final results = await _fetchNearbyFromOverpass(
          userLat: userLat,
          userLng: userLng,
          query: query,
          typeFilter: type,
          maxDistanceMiles: maxDistance,
        );
        if (results.isNotEmpty) {
          final merged = await _mergeWithCurated(
            base: results,
            userLat: userLat,
            userLng: userLng,
            maxDistanceMiles: maxDistance,
            typeFilter: type,
          );
          debugPrint('ResourceService: returning ${merged.length} OSM+curated results');
          _searchCache.set(cacheKey, merged);
          return merged;
        } else {
          debugPrint('ResourceService: Overpass returned 0 results, trying Nominatim fallback');
        }
      } catch (e, st) {
        hadNetworkFailure = true;
        debugPrint('ResourceService: Overpass fetch failed: $e\n$st');
        debugPrint('ResourceService: trying Nominatim fallback…');
      }
      try {
        final nom = await _fetchNearbyFromNominatim(
          userLat: userLat,
          userLng: userLng,
          query: query,
          typeFilter: type,
          maxDistanceMiles: maxDistance,
        );
        if (nom.isNotEmpty) {
          final merged = await _mergeWithCurated(
            base: nom,
            userLat: userLat,
            userLng: userLng,
            maxDistanceMiles: maxDistance,
            typeFilter: type,
          );
          debugPrint('ResourceService: returning ${merged.length} Nominatim+curated results');
          _searchCache.set(cacheKey, merged);
          return merged;
        }
      } catch (e, st) {
        hadNetworkFailure = true;
        debugPrint('ResourceService: Nominatim fallback failed: $e\n$st');
      }
    }

    // Also try curated resources even if live results are empty or coords missing
    List<Resource> curated = [];
    if (userLat != null && userLng != null) {
      try {
        curated = await _fetchCuratedResourcesNearby(
          userLat: userLat,
          userLng: userLng,
          maxDistanceMiles: maxDistance ?? 5,
          typeFilter: type,
        );
      } catch (e, st) {
        debugPrint('ResourceService: curated fetch failed: $e\n$st');
      }
    }
    debugPrint('ResourceService: no live results; curated=${curated.length}');
    if (!hadNetworkFailure) {
      _searchCache.set(cacheKey, curated);
    }
    return curated;
  }

  /// Geocode a free-form address/city/ZIP. Tries Google first, then falls back to Nominatim.
  /// Returns {
  ///   'lat': double,
  ///   'lng': double,
  ///   'label': String,
  ///   'viewport': { 'swLat': double, 'swLng': double, 'neLat': double, 'neLng': double },
  ///   'countryCode': String?
  /// } on success; null otherwise.
  Future<Map<String, dynamic>?> geocodeAddress(String query) async {
    Map<String, dynamic>? result;
    // Prefer Google unless we are on web and get blocked by CORS
    try {
      result = await _geocodeWithGoogle(query);
    } catch (e, st) {
      debugPrint('ResourceService: geocode (Google) error: $e\n$st');
    }
    if (result != null) return result;
    // Fallback to Nominatim (no key, generally CORS-friendly)
    try {
      result = await _geocodeWithNominatim(query);
    } catch (e, st) {
      debugPrint('ResourceService: geocode (Nominatim) error: $e\n$st');
    }
    return result;
  }

  Future<Map<String, dynamic>?> _geocodeWithGoogle(String query) async {
    final params = <String, String>{
      'key': _googlePlacesKey,
      'address': query,
    };
    final uri = Uri.https('maps.googleapis.com', '/maps/api/geocode/json', params);
    debugPrint('ResourceService: geocoding "$query" (Google)');
    final resp = await _client.get(uri).timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) {
      debugPrint('ResourceService: geocode status ${resp.statusCode}: ${resp.body}');
      return null;
    }
    final decoded = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    final status = decoded['status'] as String?;
    if (status != 'OK') {
      debugPrint('ResourceService: geocode returned status=$status, message=${decoded['error_message']}');
      return null;
    }
    final results = (decoded['results'] as List<dynamic>? ?? []);
    if (results.isEmpty) return null;
    final first = results.first as Map<String, dynamic>;
    final geometry = first['geometry'] as Map<String, dynamic>?;
    final loc = geometry != null ? geometry['location'] as Map<String, dynamic>? : null;
    final lat = (loc?['lat'] is num) ? (loc!['lat'] as num).toDouble() : null;
    final lng = (loc?['lng'] is num) ? (loc!['lng'] as num).toDouble() : null;
    final label = (first['formatted_address'] ?? '').toString();
    Map<String, dynamic>? viewportOut;
    try {
      final viewport = geometry?['viewport'] as Map<String, dynamic>?;
      if (viewport != null) {
        final ne = viewport['northeast'] as Map<String, dynamic>?;
        final sw = viewport['southwest'] as Map<String, dynamic>?;
        final neLat = (ne?['lat'] is num) ? (ne!['lat'] as num).toDouble() : null;
        final neLng = (ne?['lng'] is num) ? (ne!['lng'] as num).toDouble() : null;
        final swLat = (sw?['lat'] is num) ? (sw!['lat'] as num).toDouble() : null;
        final swLng = (sw?['lng'] is num) ? (sw!['lng'] as num).toDouble() : null;
        if (neLat != null && neLng != null && swLat != null && swLng != null) {
          viewportOut = {'neLat': neLat, 'neLng': neLng, 'swLat': swLat, 'swLng': swLng};
        }
      }
    } catch (_) {}
    String? countryCode;
    try {
      final comps = (first['address_components'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
      for (final c in comps) {
        final types = (c['types'] as List<dynamic>? ?? []).map((e) => e.toString()).toList();
        if (types.contains('country')) {
          countryCode = (c['short_name'] ?? '').toString();
          break;
        }
      }
    } catch (_) {}
    if (lat == null || lng == null) return null;
    return {
      'lat': lat,
      'lng': lng,
      'label': label.isNotEmpty ? label : query,
      if (viewportOut != null) 'viewport': viewportOut,
      if (countryCode != null && countryCode!.isNotEmpty) 'countryCode': countryCode,
    };
  }

  Future<Map<String, dynamic>?> _geocodeWithNominatim(String query) async {
    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': query,
      'format': 'json',
      'addressdetails': '1',
      'limit': '1',
    });
    debugPrint('ResourceService: geocoding "$query" (Nominatim)');
    final resp = await _client.get(uri, headers: {
      'User-Agent': 'wellspring-app/1.0 (https://example.com)'
    }).timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) return null;
    final arr = jsonDecode(utf8.decode(resp.bodyBytes)) as List<dynamic>;
    if (arr.isEmpty) return null;
    final m = arr.first as Map<String, dynamic>;
    final lat = double.tryParse(m['lat']?.toString() ?? '');
    final lng = double.tryParse(m['lon']?.toString() ?? '');
    final displayName = (m['display_name'] ?? '').toString();
    if (lat == null || lng == null) return null;
    String? countryCode;
    try {
      final addr = m['address'] as Map<String, dynamic>?;
      countryCode = (addr?['country_code'] ?? '').toString().toUpperCase();
    } catch (_) {}
    return {
      'lat': lat,
      'lng': lng,
      'label': displayName.isNotEmpty ? displayName : query,
      if (countryCode != null && countryCode!.isNotEmpty) 'countryCode': countryCode,
    };
  }

  // Haversine distance in miles
  double _distanceMiles(double lat1, double lon1, double lat2, double lon2) {
    const earthRadiusMiles = 3958.7613; // miles
    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRad(lat1)) * math.cos(_toRad(lat2)) *
            math.sin(dLon / 2) * math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusMiles * c;
  }

  double? _readDouble(Map<String, dynamic> map, List<String> keys) {
    for (final k in keys) {
      final v = map[k];
      if (v is num) return v.toDouble();
      if (v is String) {
        final parsed = double.tryParse(v);
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  double _toRad(double deg) => deg * math.pi / 180.0;

  // --- Live data via Google Places Nearby Search ---
  Future<List<Resource>> _fetchNearbyFromGooglePlaces({
    required double userLat,
    required double userLng,
    String? query,
    String? typeFilter, // 'therapist' | 'center' | 'service' | 'hospital' | 'pharmacy' | 'all'
    double? maxDistanceMiles,
    bool? openNow,
    double? minRating,
    int? minUserRatings,
    List<int>? priceLevels,
    bool sortByRating = false,
    String? language,
    String? region,
    String? rankBy,
    List<String>? includeGoogleTypes,
  }) async {
    if (_isWeb) {
      return _fetchGooglePlacesViaEdge(
        userLat: userLat,
        userLng: userLng,
        query: query,
        typeFilter: typeFilter,
        maxDistance: maxDistanceMiles,
        openNow: openNow,
        minRating: minRating,
        minUserRatings: minUserRatings,
        includeGoogleTypes: includeGoogleTypes,
        sortByRating: sortByRating,
        language: language,
        region: region,
        mode: (query != null && query.trim().isNotEmpty) ? 'textsearch' : 'nearby',
      );
    }

    // If a query is present, prefer Text Search to better reflect geospecific intent.
    if (query != null && query.trim().isNotEmpty) {
      return _fetchFromGooglePlacesTextSearch(
        userLat: userLat,
        userLng: userLng,
        query: query,
        typeFilter: typeFilter,
        maxDistanceMiles: maxDistanceMiles,
        openNow: openNow,
        minRating: minRating,
        minUserRatings: minUserRatings,
        priceLevels: priceLevels,
        sortByRating: sortByRating,
        language: language,
        region: region,
        includeGoogleTypes: includeGoogleTypes,
      );
    }

    // Determine radius (meters). Google Nearby Search max radius is 50,000 meters.
    // Default to 5 miles when a specific maxDistance is not provided.
    final miles = (maxDistanceMiles == null || maxDistanceMiles <= 0)
        ? 5.0
        : maxDistanceMiles.clamp(1, 50);
    final radiusMeters = (miles * 1609.344).toInt().clamp(1, 50000);

    // Map our UI type filter to Google place types (list to broaden coverage)
    List<String> googleTypes;
    if (includeGoogleTypes != null && includeGoogleTypes.isNotEmpty) {
      googleTypes = includeGoogleTypes;
    } else {
      switch (typeFilter) {
        case 'therapist':
          googleTypes = ['doctor', 'physiotherapist', 'psychologist'];
          break;
        case 'center':
          googleTypes = ['hospital', 'clinic'];
          break;
        case 'hospital':
          googleTypes = ['hospital'];
          break;
        case 'pharmacy':
          googleTypes = ['pharmacy'];
          break;
        case 'service':
          googleTypes = ['pharmacy'];
          break;
        default:
          googleTypes = ['hospital', 'clinic', 'doctor', 'physiotherapist', 'psychologist', 'pharmacy'];
      }
    }

    final Map<String, Resource> byPlaceId = {};
    final now = DateTime.now();

    Future<void> fetchForType(String gType) async {
      try {
        final params = <String, String>{
          'key': _googlePlacesKey,
          'location': '$userLat,$userLng',
          'type': gType,
        };
        final useDistanceRank = (rankBy == 'distance');
        if (useDistanceRank) {
          params['rankby'] = 'distance';
        } else {
          params['radius'] = radiusMeters.toString();
        }
        if (query != null && query.trim().isNotEmpty) params['keyword'] = query.trim();
        if (openNow == true) params['opennow'] = 'true';
        if (priceLevels != null && priceLevels.isNotEmpty) {
          final minP = priceLevels.reduce((a, b) => a < b ? a : b);
          final maxP = priceLevels.reduce((a, b) => a > b ? a : b);
          params['minprice'] = minP.clamp(0, 4).toString();
          params['maxprice'] = maxP.clamp(0, 4).toString();
        }
        if (language != null && language.isNotEmpty) params['language'] = language;
        final uri = Uri.https('maps.googleapis.com', '/maps/api/place/nearbysearch/json', params);

        debugPrint('ResourceService: Nearby type=$gType, radius=$miles mi, q="$query"');

        final resp = await _client.get(uri).timeout(const Duration(seconds: 15));
        if (resp.statusCode != 200) {
          debugPrint('ResourceService: Nearby status ${resp.statusCode}: ${resp.body}');
          return;
        }
        final decoded = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
        final status = decoded['status'] as String?;
        if (status != 'OK' && status != 'ZERO_RESULTS') {
          debugPrint('ResourceService: Nearby returned status=$status message=${decoded['error_message']}');
          return;
        }
        final results = (decoded['results'] as List<dynamic>? ?? []);
        for (final r in results) {
          final m = r as Map<String, dynamic>;
          final placeId = (m['place_id'] ?? '').toString();
          if (placeId.isEmpty) continue;

          final geometry = m['geometry'] as Map<String, dynamic>?;
          final loc = geometry != null ? geometry['location'] as Map<String, dynamic>? : null;
          final lat = (loc?['lat'] is num) ? (loc!['lat'] as num).toDouble() : null;
          final lng = (loc?['lng'] is num) ? (loc!['lng'] as num).toDouble() : null;
          if (lat == null || lng == null) continue;

          final name = (m['name'] ?? '').toString().trim();
          if (name.isEmpty) continue;

          final vicinity = (m['vicinity'] ?? '').toString();
          final address = vicinity.isNotEmpty ? vicinity : (m['plus_code']?['compound_code']?.toString() ?? '');

          final types = (m['types'] as List<dynamic>? ?? []).map((e) => e.toString().toLowerCase()).toList();
          String mappedType = 'service';
          if (types.contains('hospital')) mappedType = 'hospital';
          else if (types.contains('clinic')) mappedType = 'center';
          else if (types.contains('doctor') || types.contains('physiotherapist') || types.contains('psychologist') || types.contains('dentist')) mappedType = 'therapist';
          else if (types.contains('pharmacy')) mappedType = 'pharmacy';
          else if (types.contains('health')) mappedType = 'service';

          final openNowVal = (m['opening_hours'] is Map && (m['opening_hours']['open_now'] is bool)) ? (m['opening_hours']['open_now'] as bool) : false;
          final availability = (m['opening_hours'] is Map) ? (openNowVal ? 'Open now' : 'Closed now') : 'Hours not available';
          final rating = (m['rating'] is num) ? (m['rating'] as num).toDouble() : 0.0;
          final reviews = (m['user_ratings_total'] is num) ? (m['user_ratings_total'] as num).toInt() : 0;
          final distance = _distanceMiles(userLat, userLng, lat, lng);

          final specialties = _inferSpecialtiesFromText(name);
          final res = Resource(
            id: 'gpl_$placeId',
            name: name,
            type: mappedType,
            specialty: specialties,
            location: vicinity.isNotEmpty ? vicinity : 'Nearby',
            address: address,
            distance: distance,
            lat: lat,
            lng: lng,
            contactPhone: null,
            contactEmail: null,
            website: null,
            availability: availability,
            rating: rating,
            reviewCount: reviews,
            createdAt: now,
            updatedAt: now,
          );

          final existing = byPlaceId[placeId];
          if (existing == null || res.distance < existing.distance) {
            byPlaceId[placeId] = res;
          }
        }
      } catch (e, st) {
        debugPrint('ResourceService: Nearby type=$gType failed: $e\n$st');
      }
    }

    await Future.wait(googleTypes.map(fetchForType));

    var out = byPlaceId.values.toList();
    if (minRating != null) {
      out = out.where((r) => r.rating >= minRating).toList();
    }
    if (minUserRatings != null) {
      out = out.where((r) => r.reviewCount >= minUserRatings).toList();
    }
    // Filter by max distance; enforce default 5 miles when not provided
    final effectiveMaxMiles = (maxDistanceMiles == null || maxDistanceMiles <= 0) ? 5.0 : maxDistanceMiles;
    out = out.where((r) => r.distance <= effectiveMaxMiles).toList();
    // If explicit Google types were provided, we already narrowed results; skip post-filtering by our coarse type.
    if (includeGoogleTypes == null || includeGoogleTypes.isEmpty) {
      // Enforce coarse UI type when not using explicit Google types
      if (typeFilter != null && typeFilter != 'all') {
        out = out.where((r) => r.type == typeFilter).toList();
      }
    }
    if (sortByRating) {
      out.sort((a, b) {
        final byRating = b.rating.compareTo(a.rating);
        return byRating != 0 ? byRating : a.distance.compareTo(b.distance);
      });
    } else {
      out.sort((a, b) => a.distance.compareTo(b.distance));
    }
    return out;
  }

  // --- Google Places Text Search with pagination and location bias ---
  Future<List<Resource>> _fetchFromGooglePlacesTextSearch({
    required double userLat,
    required double userLng,
    required String query,
    String? typeFilter, // 'therapist' | 'center' | 'service' | 'hospital' | 'pharmacy' | 'all'
    double? maxDistanceMiles,
    int pageLimit = 2, // up to 60 results (3 pages max); we cap for performance
    bool? openNow,
    double? minRating,
    int? minUserRatings,
    List<int>? priceLevels,
    bool sortByRating = false,
    String? language,
    String? region,
    List<String>? includeGoogleTypes,
  }) async {
    if (_isWeb) {
      return _fetchGooglePlacesViaEdge(
        userLat: userLat,
        userLng: userLng,
        query: query,
        typeFilter: typeFilter,
        maxDistance: maxDistanceMiles,
        openNow: openNow,
        minRating: minRating,
        minUserRatings: minUserRatings,
        includeGoogleTypes: includeGoogleTypes,
        sortByRating: sortByRating,
        language: language,
        region: region,
        mode: 'textsearch',
      );
    }

    // Determine radius (meters) and clamp to 50km as per API limits
    // Default to 5 miles when a specific maxDistance is not provided.
    final miles = (maxDistanceMiles == null || maxDistanceMiles <= 0)
        ? 5.0
        : maxDistanceMiles.clamp(1, 50);
    final radiusMeters = (miles * 1609.344).toInt().clamp(1, 50000);

    // Map UI filter to Google types
    List<String> googleTypes;
    if (includeGoogleTypes != null && includeGoogleTypes.isNotEmpty) {
      googleTypes = includeGoogleTypes;
    } else {
      switch (typeFilter) {
        case 'therapist':
          googleTypes = ['doctor', 'physiotherapist', 'psychologist'];
          break;
        case 'center':
          googleTypes = ['hospital', 'clinic'];
          break;
        case 'hospital':
          googleTypes = ['hospital'];
          break;
        case 'pharmacy':
          googleTypes = ['pharmacy'];
          break;
        case 'service':
          googleTypes = ['pharmacy'];
          break;
        default:
          googleTypes = ['hospital', 'clinic', 'doctor', 'physiotherapist', 'psychologist', 'pharmacy'];
      }
    }

    final Map<String, Resource> byPlaceId = {};
    final now = DateTime.now();

    Future<void> fetchOne({String? type}) async {
      String? pageToken;
      int page = 0;
      do {
        final params = <String, String>{
          'key': _googlePlacesKey,
          'query': query.trim(),
          'location': '$userLat,$userLng',
          'radius': radiusMeters.toString(),
          if (type != null) 'type': type,
        };
        if (openNow == true) params['opennow'] = 'true';
        if (priceLevels != null && priceLevels.isNotEmpty) {
          final minP = priceLevels.reduce((a, b) => a < b ? a : b);
          final maxP = priceLevels.reduce((a, b) => a > b ? a : b);
          params['minprice'] = minP.clamp(0, 4).toString();
          params['maxprice'] = maxP.clamp(0, 4).toString();
        }
        if (language != null && language.isNotEmpty) params['language'] = language;
        if (region != null && region.isNotEmpty) params['region'] = region;
        if (pageToken != null) params['pagetoken'] = pageToken;
        final uri = Uri.https('maps.googleapis.com', '/maps/api/place/textsearch/json', params);
        debugPrint('ResourceService: Places TextSearch type=${type ?? 'any'}, radius=$miles mi, q="$query", page=$page');
        final resp = await _client.get(uri).timeout(const Duration(seconds: 15));
        if (resp.statusCode != 200) {
          debugPrint('ResourceService: TextSearch status ${resp.statusCode}: ${resp.body}');
          break;
        }
        final decoded = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
        final status = decoded['status'] as String?;
        if (status != 'OK' && status != 'ZERO_RESULTS' && status != 'INVALID_REQUEST') {
          debugPrint('ResourceService: TextSearch returned status=$status message=${decoded['error_message']}');
          break;
        }
        final results = (decoded['results'] as List<dynamic>? ?? []);
        for (final r in results) {
          final m = r as Map<String, dynamic>;
          final placeId = (m['place_id'] ?? '').toString();
          if (placeId.isEmpty) continue;

          final geometry = m['geometry'] as Map<String, dynamic>?;
          final loc = geometry != null ? geometry['location'] as Map<String, dynamic>? : null;
          final lat = (loc?['lat'] is num) ? (loc!['lat'] as num).toDouble() : null;
          final lng = (loc?['lng'] is num) ? (loc!['lng'] as num).toDouble() : null;
          if (lat == null || lng == null) continue;

          final name = (m['name'] ?? '').toString().trim();
          if (name.isEmpty) continue;

          final address = (m['formatted_address'] ?? m['vicinity'] ?? '').toString();

          final types = (m['types'] as List<dynamic>? ?? []).map((e) => e.toString().toLowerCase()).toList();
          String mappedType = 'service';
          if (types.contains('hospital')) {
            mappedType = 'hospital';
          } else if (types.contains('clinic')) {
            mappedType = 'center';
          } else if (types.contains('doctor') || types.contains('physiotherapist') || types.contains('psychologist') || types.contains('dentist')) {
            mappedType = 'therapist';
          } else if (types.contains('pharmacy')) {
            mappedType = 'pharmacy';
          } else if (types.contains('health')) {
            mappedType = 'service';
          }

          final openNow = (m['opening_hours'] is Map && (m['opening_hours']['open_now'] is bool))
              ? (m['opening_hours']['open_now'] as bool)
              : false;
          final availability = (m['opening_hours'] is Map)
              ? (openNow ? 'Open now' : 'Closed now')
              : 'Hours not available';

          final rating = (m['rating'] is num) ? (m['rating'] as num).toDouble() : 0.0;
          final reviews = (m['user_ratings_total'] is num) ? (m['user_ratings_total'] as num).toInt() : 0;

          final distance = _distanceMiles(userLat, userLng, lat, lng);

          final specialties = _inferSpecialtiesFromText(name);
          final res = Resource(
            id: 'gpl_$placeId',
            name: name,
            type: mappedType,
            specialty: specialties,
            location: address.isNotEmpty ? address : 'Nearby',
            address: address,
            distance: distance,
            lat: lat,
            lng: lng,
            contactPhone: null,
            contactEmail: null,
            website: null,
            availability: availability,
            rating: rating,
            reviewCount: reviews,
            createdAt: now,
            updatedAt: now,
          );
          final existing = byPlaceId[placeId];
          if (existing == null || res.distance < existing.distance) {
            byPlaceId[placeId] = res;
          }
        }

        final token = decoded['next_page_token']?.toString();
        if (token != null && token.isNotEmpty && page + 1 < pageLimit) {
          pageToken = token;
          page += 1;
          // As per Google docs, wait a short delay before requesting next page
          await Future<void>.delayed(const Duration(seconds: 2));
        } else {
          pageToken = null;
        }
      } while (pageToken != null);
    }

    if (typeFilter != null && typeFilter != 'all') {
      await Future.wait(googleTypes.map((t) => fetchOne(type: t)));
    } else {
      // Broad search without a specific type to capture more matches
      await fetchOne(type: null);
    }

    var out = byPlaceId.values.toList();
    if (minRating != null) {
      out = out.where((r) => r.rating >= minRating).toList();
    }
    if (minUserRatings != null) {
      out = out.where((r) => r.reviewCount >= minUserRatings).toList();
    }
    // Filter by max distance; enforce default 5 miles when not provided
    final effectiveMaxMiles = (maxDistanceMiles == null || maxDistanceMiles <= 0) ? 5.0 : maxDistanceMiles;
    out = out.where((r) => r.distance <= effectiveMaxMiles).toList();
    if (includeGoogleTypes == null || includeGoogleTypes.isEmpty) {
      if (typeFilter != null && typeFilter != 'all') {
        out = out.where((r) => r.type == typeFilter).toList();
      }
    }
    if (sortByRating) {
      out.sort((a, b) {
        final byRating = b.rating.compareTo(a.rating);
        return byRating != 0 ? byRating : a.distance.compareTo(b.distance);
      });
    } else {
      out.sort((a, b) => a.distance.compareTo(b.distance));
    }

    // Enrich a smaller top slice with phone/website via Place Details
    await _enrichTopWithPlaceDetails(out, top: 4);
    return out;
  }

  Future<List<Resource>> _fetchGooglePlacesViaEdge({
    required double userLat,
    required double userLng,
    String? query,
    String? typeFilter,
    double? maxDistance,
    bool? openNow,
    double? minRating,
    int? minUserRatings,
    List<String>? includeGoogleTypes,
    bool sortByRating = false,
    String? language,
    String? region,
    String? mode,
  }) async {
    try {
      final body = <String, dynamic>{
        'userLat': userLat,
        'userLng': userLng,
      };
      if (query != null && query.trim().isNotEmpty) body['query'] = query.trim();
      if (typeFilter != null && typeFilter.isNotEmpty) body['type'] = typeFilter;
      if (maxDistance != null && maxDistance > 0) body['maxDistanceMiles'] = maxDistance;
      if (openNow != null) body['openNow'] = openNow;
      if (minRating != null) body['minRating'] = minRating;
      if (minUserRatings != null) body['minUserRatings'] = minUserRatings;
      if (language != null && language.isNotEmpty) body['language'] = language;
      if (region != null && region.isNotEmpty) body['region'] = region;
      if (includeGoogleTypes != null && includeGoogleTypes.isNotEmpty) body['includeGoogleTypes'] = includeGoogleTypes;
      if (sortByRating) body['sortByRating'] = true;
      if (mode != null && mode.isNotEmpty) body['mode'] = mode;

      final response = await _supabase.functions.invoke('places_search', body: body);
      if (response.status != 200) {
        debugPrint('ResourceService: places_search edge function returned ${response.status}: ${response.data}');
        return [];
      }

      final dynamic payload = response.data;
      final List<Map<String, dynamic>> items = [];
      if (payload is Map && payload['results'] is List) {
        for (final entry in payload['results'] as List) {
          if (entry is Map) {
            items.add(Map<String, dynamic>.from(entry));
          }
        }
      }

      final now = DateTime.now();
      return items.map((m) {
        final name = (m['name'] ?? '').toString().trim();
        if (name.isEmpty) return null;
        final type = (m['type'] ?? '').toString().trim();
        final address = (m['address'] ?? '').toString();
        final location = (m['location'] ?? (address.isNotEmpty ? address : 'Nearby')).toString();
        final specialties = (m['specialties'] is List)
            ? List<String>.from((m['specialties'] as List).map((e) => e.toString()))
            : _inferSpecialtiesFromText(name);
        final rating = (m['rating'] is num) ? (m['rating'] as num).toDouble() : 0.0;
        final reviewCount = (m['reviewCount'] is num) ? (m['reviewCount'] as num).toInt() : 0;
        final distance = (m['distanceMiles'] is num) ? (m['distanceMiles'] as num).toDouble() : 0.0;
        return Resource(
          id: (m['id'] ?? '').toString(),
          name: name,
          type: type.isNotEmpty ? type : (typeFilter?.isNotEmpty == true ? typeFilter! : 'service'),
          specialty: specialties,
          location: location,
          address: address,
          distance: distance,
          lat: (m['lat'] is num) ? (m['lat'] as num).toDouble() : null,
          lng: (m['lng'] is num) ? (m['lng'] as num).toDouble() : null,
          contactPhone: (m['contactPhone']?.toString().isNotEmpty == true) ? m['contactPhone'].toString() : null,
          contactEmail: null,
          website: (m['website']?.toString().isNotEmpty == true) ? m['website'].toString() : null,
          availability: (m['availability'] ?? 'Hours not available').toString(),
          rating: rating,
          reviewCount: reviewCount,
          createdAt: now,
          updatedAt: now,
        );
      }).whereType<Resource>().toList();
    } catch (e, st) {
      debugPrint('ResourceService: places_search edge call failed: $e\n$st');
      return [];
    }
  }

  Future<void> _enrichTopWithPlaceDetails(List<Resource> items, {int top = 6}) async {
    final slice = items.take(top).toList();
    Future<void> enrich(Resource r) async {
      final placeId = r.id.startsWith('gpl_') ? r.id.substring(4) : null;
      if (placeId == null || placeId.isEmpty) return;
      final cached = _detailsCache.get(placeId);
      if (cached != null) {
        final idx = items.indexOf(r);
        if (idx != -1) {
          items[idx] = r.copyWith(
            contactPhone: cached['phone']?.isNotEmpty == true ? cached['phone'] : r.contactPhone,
            website: cached['website']?.isNotEmpty == true ? cached['website'] : r.website,
            availability: cached['availability'] ?? r.availability,
          );
        }
        return;
      }
      try {
        final params = <String, String>{
          'key': _googlePlacesKey,
          'place_id': placeId,
          'fields': 'formatted_phone_number,website,opening_hours',
        };
        final uri = Uri.https('maps.googleapis.com', '/maps/api/place/details/json', params);
        final resp = await _client.get(uri).timeout(const Duration(seconds: 12));
        if (resp.statusCode != 200) return;
        final decoded = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
        final status = decoded['status']?.toString();
        if (status != 'OK') return;
        final result = decoded['result'] as Map<String, dynamic>?;
        if (result == null) return;
        final phone = (result['formatted_phone_number'] ?? '').toString();
        final website = (result['website'] ?? '').toString();
        String availability = r.availability;
        try {
          final oh = result['opening_hours'] as Map<String, dynamic>?;
          if (oh != null && (oh['open_now'] is bool)) {
            final on = (oh['open_now'] as bool);
            availability = on ? 'Open now' : 'Closed now';
          }
        } catch (_) {}
        _detailsCache.set(placeId, {
          'phone': phone,
          'website': website,
          'availability': availability,
        });
        final idx = items.indexOf(r);
        if (idx != -1) {
          items[idx] = r.copyWith(
            contactPhone: phone.isNotEmpty ? phone : r.contactPhone,
            website: website.isNotEmpty ? website : r.website,
            availability: availability,
          );
        }
      } catch (e) {
        debugPrint('ResourceService: place details failed for ${r.id}: $e');
      }
    }
    await Future.wait(slice.map(enrich));
  }

  // --- Live data via OpenStreetMap Overpass API ---
  Future<List<Resource>> _fetchNearbyFromOverpass({
    required double userLat,
    required double userLng,
    String? query,
    String? typeFilter, // 'therapist' | 'center' | 'service' | 'hospital' | 'pharmacy' | 'all'
    double? maxDistanceMiles,
  }) async {
    // On web, skip CF proxy entirely and try direct; if blocked by CORS, we'll
    // fall back to Nominatim in the caller chain. This avoids firebase_functions errors.
    // Cap radius to something reasonable for performance. Default 5 miles.
    final radiusMiles = (maxDistanceMiles == null || maxDistanceMiles <= 0)
        ? 5.0
        : maxDistanceMiles.clamp(1, 50);
    final radiusMeters = (radiusMiles * 1609.344).toInt();

    // Build an Overpass query that finds common healthcare resources.
    // We include amenities and healthcare keys, and we search nodes/ways/relations.
    final amenities = ['hospital', 'clinic', 'doctors', 'pharmacy', 'social_facility'];
    final healthcare = ['physiotherapist', 'psychotherapist', 'counselling', 'occupational_therapist'];

    String nameFilter = '';
    if (query != null && query.trim().isNotEmpty) {
      final safe = query.replaceAll('"', '');
      nameFilter = '["name"~"$safe",i]';
    }

    // Apply type filter by limiting which tags we include
    List<String> filteredAmenities = List.from(amenities);
    List<String> filteredHealthcare = List.from(healthcare);
    if (typeFilter != null && typeFilter != 'all') {
      if (typeFilter == 'therapist') {
        filteredAmenities = ['doctors'];
        filteredHealthcare = healthcare; // therapist-related
      } else if (typeFilter == 'center') {
        filteredAmenities = ['hospital', 'clinic'];
        filteredHealthcare = [];
      } else if (typeFilter == 'hospital') {
        filteredAmenities = ['hospital'];
        filteredHealthcare = [];
      } else if (typeFilter == 'service') {
        filteredAmenities = ['pharmacy', 'social_facility'];
        filteredHealthcare = [];
      } else if (typeFilter == 'pharmacy') {
        filteredAmenities = ['pharmacy'];
        filteredHealthcare = [];
      }
    }

    String amenityRegex = filteredAmenities.isEmpty ? '' : filteredAmenities.join('|');
    String healthcareRegex = filteredHealthcare.isEmpty ? '' : filteredHealthcare.join('|');

    final buffer = StringBuffer();
    buffer.writeln('[out:json][timeout:25];');
    buffer.writeln('(');
    if (amenityRegex.isNotEmpty) {
      for (final kind in ['node', 'way', 'relation']) {
        buffer.writeln('  $kind["amenity"~"($amenityRegex)"]$nameFilter(around:$radiusMeters,$userLat,$userLng);');
      }
    }
    if (healthcareRegex.isNotEmpty) {
      for (final kind in ['node', 'way', 'relation']) {
        buffer.writeln('  $kind["healthcare"~"($healthcareRegex)"]$nameFilter(around:$radiusMeters,$userLat,$userLng);');
      }
    }
    buffer.writeln(');');
    buffer.writeln('out center tags 120;');

    final body = buffer.toString();
    debugPrint('ResourceService: Overpass query radius=$radiusMiles mi, type=$typeFilter, q="$query"');

    // Try multiple Overpass endpoints to avoid occasional 5xx or rate limits
    final endpoints = <String>[
      'https://overpass-api.de/api/interpreter',
      'https://overpass.kumi.systems/api/interpreter',
      'https://overpass.openstreetmap.ru/api/interpreter',
    ];

    http.Response? resp;
    Object? lastError;
    for (final base in endpoints) {
      try {
        final uri = Uri.parse(base);
        resp = await _client.post(
          uri,
          headers: {'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8'},
          body: {'data': body},
        ).timeout(const Duration(seconds: 25));
        if (resp.statusCode == 200) break;
        lastError = Exception('Overpass status ${resp.statusCode}: ${resp.body}');
      } catch (e) {
        lastError = e;
      }
    }
    if (resp == null || resp.statusCode != 200) {
      throw Exception('Overpass request failed: $lastError');
    }

    final decoded = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    final elements = (decoded['elements'] as List<dynamic>? ?? []);

    final now = DateTime.now();
    final out = <Resource>[];

    for (final el in elements) {
      final map = el as Map<String, dynamic>;
      final tags = (map['tags'] as Map<String, dynamic>?) ?? {};
      // Get center for ways/relations
      double? lat = (map['lat'] is num) ? (map['lat'] as num).toDouble() : null;
      double? lon = (map['lon'] is num) ? (map['lon'] as num).toDouble() : null;
      if (lat == null || lon == null) {
        final center = map['center'];
        if (center is Map) {
          lat = (center['lat'] is num) ? (center['lat'] as num).toDouble() : null;
          lon = (center['lon'] is num) ? (center['lon'] as num).toDouble() : null;
        }
      }
      if (lat == null || lon == null) continue;

      final amenity = (tags['amenity'] as String?)?.toLowerCase();
      final healthcareKind = (tags['healthcare'] as String?)?.toLowerCase();

      // Map to our three broad types
      String mappedType = 'service';
      if (amenity == 'hospital' || amenity == 'clinic') {
        mappedType = (amenity == 'hospital') ? 'hospital' : 'center';
      } else if (amenity == 'doctors' || (healthcareKind != null && filteredHealthcare.contains(healthcareKind))) {
        mappedType = 'therapist';
      } else if (amenity == 'pharmacy') {
        mappedType = 'pharmacy';
      } else if (amenity == 'social_facility') {
        mappedType = 'service';
      }

      final name = (tags['name'] as String?)?.trim();
      if (name == null || name.isEmpty) continue;

      // Extract specialties from OSM tags and name heuristics
      final specialties = _specialtiesFromOsmTags(tags, name);

      // Build address/location labels when available
      final house = (tags['addr:housenumber'] ?? '').toString();
      final street = (tags['addr:street'] ?? '').toString();
      final city = (tags['addr:city'] ?? '').toString();
      final suburb = (tags['addr:suburb'] ?? '').toString();
      final neigh = (tags['addr:neighbourhood'] ?? '').toString();
      final addrParts = [house, street].where((s) => s.trim().isNotEmpty).toList();
      final address = addrParts.isEmpty ? (city.isNotEmpty ? city : '') : addrParts.join(' ');
      final locLabel = suburb.isNotEmpty
          ? suburb
          : (neigh.isNotEmpty
              ? neigh
              : (city.isNotEmpty ? city : 'Nearby'));

      final phone = (tags['phone'] ?? tags['contact:phone'])?.toString();
      final website = (tags['website'] ?? tags['contact:website'])?.toString();
      final opening = (tags['opening_hours'] ?? '').toString();
      final availability = opening.isNotEmpty ? opening : 'Hours not available';

      final distance = _distanceMiles(userLat, userLng, lat, lon);

      final res = Resource(
        id: 'osm_${map['type']}_${map['id']}',
        name: name,
        type: mappedType,
        specialty: specialties,
        location: locLabel,
        address: address,
        distance: distance,
        lat: lat,
        lng: lon,
        contactPhone: phone?.isNotEmpty == true ? phone : null,
        contactEmail: null,
        website: website?.isNotEmpty == true ? website : null,
        availability: availability,
        rating: 0,
        reviewCount: 0,
        createdAt: now,
        updatedAt: now,
      );
      out.add(res);
    }

    // Distance filter/sort
    if (maxDistanceMiles != null) {
      out.removeWhere((r) => r.distance > maxDistanceMiles);
    }
    out.sort((a, b) => a.distance.compareTo(b.distance));

    return out;
  }

  // --- Fallback: Nearby search via Nominatim (bounded box) ---
  // NOTE: Nominatim is primarily a geocoder; this is a light fallback for web when
  // Overpass is unreachable due to CORS or transient outages. We keep requests
  // bounded and limited to reduce load and respect usage policies.
  Future<List<Resource>> _fetchNearbyFromNominatim({
    required double userLat,
    required double userLng,
    String? query,
    String? typeFilter, // 'therapist' | 'center' | 'service' | 'hospital' | 'pharmacy' | 'all'
    double? maxDistanceMiles,
  }) async {
    // Default radius: 5 miles if not provided
    final radiusMiles = (maxDistanceMiles == null || maxDistanceMiles <= 0) ? 5.0 : maxDistanceMiles.clamp(1, 50);
    final milesPerLat = 69.0; // approx
    final milesPerLon = 69.0 * math.cos(_toRad(userLat)).abs().clamp(0.1, 1.0);
    final dLat = radiusMiles / milesPerLat;
    final dLon = radiusMiles / milesPerLon;

    final south = userLat - dLat;
    final north = userLat + dLat;
    final west = userLng - dLon;
    final east = userLng + dLon;

    // Build a lightweight query string
    String q = '';
    final qTrim = (query ?? '').trim();
    if (qTrim.isNotEmpty) q = qTrim;
    // Bias by type when present
    String typeBias = '';
    switch (typeFilter) {
      case 'therapist':
        typeBias = ' doctor physiotherapist psychologist therapist health';
        break;
      case 'center':
        typeBias = ' hospital clinic health center';
        break;
      case 'hospital':
        typeBias = ' hospital';
        break;
      case 'pharmacy':
        typeBias = ' pharmacy';
        break;
      case 'service':
        typeBias = ' pharmacy health';
        break;
      default:
        typeBias = ' hospital clinic doctor physiotherapist psychologist pharmacy';
    }
    final effectiveQ = (q + typeBias).trim();

    final params = <String, String>{
      'q': effectiveQ.isEmpty ? typeBias.trim() : effectiveQ,
      'format': 'json',
      'addressdetails': '1',
      'limit': '30',
      'bounded': '1',
      // viewbox uses: left, top, right, bottom -> lonmin, latmax, lonmax, latmin
      'viewbox': '$west,$north,$east,$south',
    };

    final uri = Uri.https('nominatim.openstreetmap.org', '/search', params);
    debugPrint('ResourceService: Nominatim fallback radius=$radiusMiles mi, type=$typeFilter, q="$effectiveQ"');
    final resp = await _client.get(uri, headers: {
      'User-Agent': 'wellspring-app/1.0 (https://example.com)'
    }).timeout(const Duration(seconds: 20));
    if (resp.statusCode != 200) {
      debugPrint('ResourceService: Nominatim fallback status ${resp.statusCode}: ${resp.body}');
      return [];
    }
    final arr = jsonDecode(utf8.decode(resp.bodyBytes)) as List<dynamic>;
    final now = DateTime.now();
    final out = <Resource>[];
    for (final item in arr) {
      final m = item as Map<String, dynamic>;
      final name = (m['display_name'] ?? '').toString();
      final lat = double.tryParse(m['lat']?.toString() ?? '');
      final lon = double.tryParse(m['lon']?.toString() ?? '');
      if (name.isEmpty || lat == null || lon == null) continue;

      final addr = (m['address'] as Map<String, dynamic>?) ?? {};
      final house = (addr['house_number'] ?? '').toString();
      final road = (addr['road'] ?? '').toString();
      final city = (addr['city'] ?? addr['town'] ?? addr['village'] ?? '').toString();
      final suburb = (addr['suburb'] ?? addr['neighbourhood'] ?? '').toString();
      final address = [house, road].where((s) => s.trim().isNotEmpty).join(' ').trim();
      final locLabel = suburb.isNotEmpty ? suburb : (city.isNotEmpty ? city : 'Nearby');

      // Map class/type heuristically to our type categories
      final cls = (m['class'] ?? '').toString().toLowerCase();
      final typ = (m['type'] ?? '').toString().toLowerCase();
      String mappedType = 'service';
      if (cls == 'amenity') {
        if (typ == 'hospital') mappedType = 'hospital';
        else if (typ == 'clinic') mappedType = 'center';
        else if (typ == 'pharmacy') mappedType = 'pharmacy';
        else if (typ == 'doctors') mappedType = 'therapist';
      } else if (cls == 'healthcare') {
        if (typ.contains('physio') || typ.contains('psychologist') || typ.contains('counsell') || typ.contains('occupational')) mappedType = 'therapist';
      }

      final distance = _distanceMiles(userLat, userLng, lat, lon);
      final shortName = name.split(',').first.trim();
      final specialties = _inferSpecialtiesFromText(shortName);
      final resource = Resource(
        id: 'nom_${m['osm_type'] ?? 'n'}_${m['osm_id'] ?? name.hashCode}',
        name: shortName,
        type: mappedType,
        specialty: specialties,
        location: locLabel,
        address: address.isNotEmpty ? address : (m['display_name']?.toString() ?? ''),
        distance: distance,
        lat: lat,
        lng: lon,
        contactPhone: null,
        contactEmail: null,
        website: null,
        availability: 'Hours not available',
        rating: 0,
        reviewCount: 0,
        createdAt: now,
        updatedAt: now,
      );
      out.add(resource);
    }
    // Filter/sort within radius
    if (maxDistanceMiles != null) {
      out.removeWhere((r) => r.distance > maxDistanceMiles);
    }
    out.sort((a, b) => a.distance.compareTo(b.distance));
    return out;
  }

  /// Fetches *approved* nearby support resources from Supabase only:
  /// - `resources_curated` (approved)
  /// - `resource_suggestions` (approved + not yet published)
  ///
  /// This intentionally does **not** hit Google Places / Overpass, so it works
  /// even when external network/CORS restrictions apply.
  Future<List<Resource>> getApprovedNearbyResources({
    required double userLat,
    required double userLng,
    required double maxDistanceMiles,
    String? typeFilter,
    String? query,
  }) async {
    try {
      debugPrint('ResourceService.getApprovedNearbyResources: START (lat=$userLat, lng=$userLng, radius=${maxDistanceMiles}mi, type=$typeFilter, query=$query)');
      final curated = await _fetchCuratedResourcesNearby(
        userLat: userLat,
        userLng: userLng,
        maxDistanceMiles: maxDistanceMiles,
        typeFilter: typeFilter,
      );
      debugPrint('ResourceService.getApprovedNearbyResources: curated returned ${curated.length} resources');
      final suggestions = await _fetchApprovedSuggestionsNearby(
        userLat: userLat,
        userLng: userLng,
        maxDistanceMiles: maxDistanceMiles,
        typeFilter: typeFilter,
      );
      debugPrint('ResourceService.getApprovedNearbyResources: suggestions returned ${suggestions.length} resources');

      final merged = <Resource>[];
      bool isDup(Resource a, Resource b) {
        final keyA = '${a.name.trim().toLowerCase()}@${a.address.trim().toLowerCase()}';
        final keyB = '${b.name.trim().toLowerCase()}@${b.address.trim().toLowerCase()}';
        if (keyA.isNotEmpty && keyA == keyB) return true;
        if (a.lat != null && a.lng != null && b.lat != null && b.lng != null) {
          final d = _distanceMiles(a.lat!, a.lng!, b.lat!, b.lng!);
          if (d < 0.05) {
            final nA = a.name.trim().toLowerCase();
            final nB = b.name.trim().toLowerCase();
            if (nA == nB || nA.contains(nB) || nB.contains(nA)) return true;
          }
        }
        return false;
      }

      for (final r in [...curated, ...suggestions]) {
        if (!merged.any((m) => isDup(m, r))) merged.add(r);
      }
      merged.sort((a, b) => a.distance.compareTo(b.distance));
      debugPrint('ResourceService.getApprovedNearbyResources: merged ${merged.length} unique resources after de-duping');

      final q = query?.trim().toLowerCase() ?? '';
      if (q.isEmpty) {
        debugPrint('ResourceService.getApprovedNearbyResources: DONE (no query filter), returning ${merged.length}');
        return merged;
      }
      final filtered = merged.where((r) {
        final name = r.name.toLowerCase();
        final addr = r.address.toLowerCase();
        final loc = r.location.toLowerCase();
        final typ = r.type.toLowerCase();
        final specs = r.specialty.map((e) => e.toLowerCase());
        return name.contains(q) || addr.contains(q) || loc.contains(q) || typ.contains(q) || specs.any((s) => s.contains(q));
      }).toList(growable: false);
      debugPrint('ResourceService.getApprovedNearbyResources: DONE (with query filter "$q"), returning ${filtered.length}');
      return filtered;
    } catch (e, st) {
      debugPrint('ResourceService.getApprovedNearbyResources failed: $e\n$st');
      return [];
    }
  }
}

extension on ResourceService {
  Future<List<Resource>> _fetchApprovedSuggestionsNearby({
    required double userLat,
    required double userLng,
    required double maxDistanceMiles,
    required String? typeFilter,
  }) async {
    final milesPerLat = 69.0; // approx
    final milesPerLon = 69.0 * math.cos(_toRad(userLat)).abs().clamp(0.1, 1.0);
    final dLat = maxDistanceMiles / milesPerLat;
    final dLon = maxDistanceMiles / milesPerLon;
    final south = userLat - dLat;
    final north = userLat + dLat;
    final west = userLng - dLon;
    final east = userLng + dLon;

    // Only include suggestions that have not been published to curated yet
    // Note: some projects may store coordinates as strings, but the DB filters
    // require numeric columns; we still guard at parse-time below.
    var query = _supabase.from('resource_suggestions')
      .select()
      .eq('status', 'approved')
      .isFilter('published_resource_id', null)
      .gte('lat', south)
      .lte('lat', north)
      .gte('lng', west)
      .lte('lng', east);
    if (typeFilter != null && typeFilter.isNotEmpty && typeFilter != 'all') {
      query = query.eq('type', typeFilter);
    }
    List<Map<String, dynamic>> data;
    try {
      data = await query.limit(100);
      if (data.isEmpty) {
        // Some deployments may not use a strict status workflow on suggestions.
        // If the approved-only query returns nothing, retry without status but
        // keep the bounding box + unpublished guard.
        var relaxed = _supabase.from('resource_suggestions')
          .select()
          .isFilter('published_resource_id', null)
          .gte('lat', south)
          .lte('lat', north)
          .gte('lng', west)
          .lte('lng', east);
        if (typeFilter != null && typeFilter.isNotEmpty && typeFilter != 'all') {
          relaxed = relaxed.eq('type', typeFilter);
        }
        final relaxedData = await relaxed.limit(100);
        if (relaxedData.isNotEmpty) {
          debugPrint('ResourceService: suggestions approved-only returned 0; using relaxed status-less results (${relaxedData.length}).');
          data = relaxedData;
        }
      }
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST205') {
        debugPrint('ResourceService: resource_suggestions table missing; skipping suggestions.');
        return [];
      }
      debugPrint('ResourceService: suggestions geo-query failed (${e.message}). Using status-only fallback.');
      var fb = _supabase.from('resource_suggestions')
        .select()
        .eq('status', 'approved')
        .isFilter('published_resource_id', null);
      if (typeFilter != null && typeFilter.isNotEmpty && typeFilter != 'all') {
        fb = fb.eq('type', typeFilter);
      }
      try {
        data = await fb.limit(200);
      } on PostgrestException catch (inner) {
        if (inner.code == 'PGRST205') {
          debugPrint('ResourceService: resource_suggestions table missing during fallback; skipping suggestions.');
          return [];
        }
        debugPrint('ResourceService: suggestions fallback failed (${inner.message}).');
        return [];
      }
    } catch (e, st) {
      debugPrint('ResourceService: suggestions geo-query unexpected error: $e\n$st');
      return [];
    }
    final now = DateTime.now();
    final out = <Resource>[];
    var skippedMissingCoords = 0;
    for (final m in data) {
      // Extra guard in case the query fallback couldn't apply isNull
      if (m.containsKey('published_resource_id') && m['published_resource_id'] != null) {
        continue; // skip already-published suggestions
      }
      final lat = _readDouble(m, const ['lat', 'latitude']);
      final lng = _readDouble(m, const ['lng', 'lon', 'longitude']);
      if (lat == null || lng == null) {
        skippedMissingCoords++;
        continue;
      }
      final dist = _distanceMiles(userLat, userLng, lat, lng);
      if (dist > maxDistanceMiles) continue;
      out.add(Resource(
        id: 'sug_${m['id']}',
        name: (m['name'] ?? m['resource_name'] ?? '').toString(),
        type: (m['type'] ?? 'service').toString(),
        specialty: ((m['specialties'] as List<dynamic>? ?? []).map((e) => e.toString()).toList()),
        location: (m['city'] ?? m['state'] ?? m['country'] ?? 'Nearby').toString(),
        address: (m['address'] ?? m['address_line'] ?? '').toString(),
        distance: dist,
        lat: lat,
        lng: lng,
        contactPhone: (m['phone']?.toString().isNotEmpty == true) ? m['phone'].toString() : null,
        contactEmail: (m['contact_email']?.toString().isNotEmpty == true) ? m['contact_email'].toString() : null,
        website: (m['website']?.toString().isNotEmpty == true) ? m['website'].toString() : null,
        availability: (m['availability'] ?? 'Hours not available').toString(),
        rating: 0,
        reviewCount: 0,
        createdAt: now,
        updatedAt: now,
      ));
    }
    if (out.isEmpty && data.isNotEmpty) {
      debugPrint(
        'ResourceService: approved suggestions query returned ${data.length} rows but 0 usable within ${maxDistanceMiles.toStringAsFixed(1)}mi (skippedMissingCoords=$skippedMissingCoords).',
      );
    }
    out.sort((a, b) => a.distance.compareTo(b.distance));
    return out;
  }
  Future<List<Resource>> _mergeWithCurated({
    required List<Resource> base,
    required double userLat,
    required double userLng,
    required double? maxDistanceMiles,
    required String? typeFilter,
  }) async {
    try {
      final curated = await _fetchCuratedResourcesNearby(
        userLat: userLat,
        userLng: userLng,
        maxDistanceMiles: (maxDistanceMiles == null || maxDistanceMiles <= 0) ? 5.0 : maxDistanceMiles,
        typeFilter: typeFilter,
      );
      // Merge curated into base
      final byId = {for (final r in base) r.id: r};
      for (final c in curated) {
        if (!byId.containsKey(c.id)) byId[c.id] = c;
      }

      // Also merge in approved suggestions that are not yet published, de-duping against curated
      try {
        final sugg = await _fetchApprovedSuggestionsNearby(
          userLat: userLat,
          userLng: userLng,
          maxDistanceMiles: (maxDistanceMiles == null || maxDistanceMiles <= 0) ? 5.0 : maxDistanceMiles,
          typeFilter: typeFilter,
        );
        if (sugg.isNotEmpty) {
          // Build simple dedupe set using name+address and proximity
          final curatedList = curated;
          bool isDuplicate(Resource s) {
            for (final c in curatedList) {
              // If same normalized name and address, consider duplicate
              final keyS = '${s.name.trim().toLowerCase()}@${s.address.trim().toLowerCase()}';
              final keyC = '${c.name.trim().toLowerCase()}@${c.address.trim().toLowerCase()}';
              if (keyS == keyC && keyS.isNotEmpty) return true;
              // Or very close distance with similar name
              final d = _distanceMiles(
                s.lat ?? userLat,
                s.lng ?? userLng,
                c.lat ?? userLat,
                c.lng ?? userLng,
              );
              if (d < 0.05) { // ~264 feet
                final nS = s.name.trim().toLowerCase();
                final nC = c.name.trim().toLowerCase();
                if (nS == nC || (nS.contains(nC) || nC.contains(nS))) return true;
              }
            }
            return false;
          }
          for (final s in sugg) {
            if (isDuplicate(s)) continue;
            if (!byId.containsKey(s.id)) byId[s.id] = s;
          }
        }
      } catch (e) {
        debugPrint('ResourceService: merge suggestions failed: $e');
      }

      final list = byId.values.toList();
      list.sort((a, b) => a.distance.compareTo(b.distance));
      return list;
    } catch (e) {
      debugPrint('ResourceService: mergeWithCurated failed: $e');
      return base;
    }
  }

  Future<List<Resource>> _fetchCuratedResourcesNearby({
    required double userLat,
    required double userLng,
    required double maxDistanceMiles,
    required String? typeFilter,
  }) async {
    final milesPerLat = 69.0; // approx
    final milesPerLon = 69.0 * math.cos(_toRad(userLat)).abs().clamp(0.1, 1.0);
    final dLat = maxDistanceMiles / milesPerLat;
    final dLon = maxDistanceMiles / milesPerLon;
    final south = userLat - dLat;
    final north = userLat + dLat;
    final west = userLng - dLon;
    final east = userLng + dLon;

    var query = _supabase.from('resources_curated')
      .select()
      .gte('lat', south)
      .lte('lat', north)
      .gte('lng', west)
      .lte('lng', east)
      .eq('status', 'approved');
    if (typeFilter != null && typeFilter.isNotEmpty && typeFilter != 'all') {
      query = query.eq('type', typeFilter);
    }
    List<Map<String, dynamic>> data;
    try {
      data = await query.limit(100);
      if (data.isEmpty) {
        // Some deployments may not store an explicit 'approved' status.
        // If the approved-only query returns nothing, retry without status but
        // keep the bounding box.
        var relaxed = _supabase.from('resources_curated')
          .select()
          .gte('lat', south)
          .lte('lat', north)
          .gte('lng', west)
          .lte('lng', east);
        if (typeFilter != null && typeFilter.isNotEmpty && typeFilter != 'all') {
          relaxed = relaxed.eq('type', typeFilter);
        }
        final relaxedData = await relaxed.limit(100);
        if (relaxedData.isNotEmpty) {
          debugPrint('ResourceService: curated approved-only returned 0; using relaxed status-less results (${relaxedData.length}).');
          data = relaxedData;
        }
      }
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST205') {
        debugPrint('ResourceService: resources_curated table missing; skipping curated records.');
        return [];
      }
      debugPrint('ResourceService: curated geo-query failed (${e.message}). Using status-only fallback.');
      var fb = _supabase.from('resources_curated')
        .select()
        .eq('status', 'approved');
      if (typeFilter != null && typeFilter.isNotEmpty && typeFilter != 'all') {
        fb = fb.eq('type', typeFilter);
      }
      try {
        data = await fb.limit(200);
      } on PostgrestException catch (inner) {
        if (inner.code == 'PGRST205') {
          debugPrint('ResourceService: resources_curated table missing during fallback; skipping curated records.');
          return [];
        }
        debugPrint('ResourceService: curated fallback failed (${inner.message}).');
        return [];
      }
    } catch (e, st) {
      debugPrint('ResourceService: curated geo-query unexpected error: $e\n$st');
      return [];
    }
    final now = DateTime.now();
    final out = <Resource>[];
    var skippedMissingCoords = 0;
    for (final m in data) {
      final lat = _readDouble(m, const ['lat', 'latitude']);
      final lng = _readDouble(m, const ['lng', 'lon', 'longitude']);
      if (lat == null || lng == null) {
        skippedMissingCoords++;
        continue;
      }
      final dist = _distanceMiles(userLat, userLng, lat, lng);
      if (dist > maxDistanceMiles) continue;
      out.add(Resource(
        id: 'cur_${m['id']}',
        name: (m['name'] ?? '').toString(),
        type: (m['type'] ?? 'service').toString(),
        specialty: ((m['specialties'] as List<dynamic>? ?? []).map((e) => e.toString()).toList()),
        location: (m['city'] ?? m['state'] ?? m['country'] ?? 'Nearby').toString(),
        address: (m['address'] ?? '').toString(),
        distance: dist,
        lat: lat,
        lng: lng,
        contactPhone: (m['phone']?.toString().isNotEmpty == true) ? m['phone'].toString() : null,
        contactEmail: (m['contact_email']?.toString().isNotEmpty == true) ? m['contact_email'].toString() : null,
        website: (m['website']?.toString().isNotEmpty == true) ? m['website'].toString() : null,
        availability: (m['availability'] ?? 'Hours not available').toString(),
        rating: 0,
        reviewCount: 0,
        createdAt: now,
        updatedAt: now,
      ));
    }
    if (out.isEmpty && data.isNotEmpty) {
      debugPrint(
        'ResourceService: curated query returned ${data.length} rows but 0 usable within ${maxDistanceMiles.toStringAsFixed(1)}mi (skippedMissingCoords=$skippedMissingCoords).',
      );
    }
    // Curated-only here; suggestions are merged higher up with de-duping
    out.sort((a, b) => a.distance.compareTo(b.distance));
    return out;
  }
}

// Simple in-memory cache with TTL and LRU eviction.
class _MemoryCache<T> {
  final int maxEntries;
  final Duration ttl;
  final _store = <String, _CacheEntry<T>>{};
  final _lru = <String>[]; // track keys by recent use (end = most recent)

  _MemoryCache({required this.maxEntries, required this.ttl});

  T? get(String key) {
    final entry = _store[key];
    if (entry == null) return null;
    if (DateTime.now().isAfter(entry.expiresAt)) {
      _store.remove(key);
      _lru.remove(key);
      return null;
    }
    // mark as used
    _lru.remove(key);
    _lru.add(key);
    return entry.value;
  }

  void set(String key, T value) {
    final expiresAt = DateTime.now().add(ttl);
    _store[key] = _CacheEntry(value: value, expiresAt: expiresAt);
    _lru.remove(key);
    _lru.add(key);
    _prune();
  }

  void _prune() {
    // remove expired first
    final now = DateTime.now();
    final expired = _store.entries.where((e) => now.isAfter(e.value.expiresAt)).map((e) => e.key).toList();
    for (final k in expired) {
      _store.remove(k);
      _lru.remove(k);
    }
    // enforce size
    while (_lru.length > maxEntries) {
      final oldest = _lru.first;
      _lru.removeAt(0);
      _store.remove(oldest);
    }
  }
}

class _CacheEntry<T> {
  final T value;
  final DateTime expiresAt;
  _CacheEntry({required this.value, required this.expiresAt});
}
