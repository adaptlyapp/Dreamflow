import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Permission-aware location helper for ARIE.
///
/// Design goals:
/// - Use OS-level permission (no in-app enable toggle).
/// - Prefer coarse precision for recommendations (privacy-by-default).
/// - Provide simple helpers to round/truncate coordinates before use.
class LocationIntelligenceService {
  static const String prefKey = 'arieLocation';

  /// We intentionally default to *coarse* precision.
  /// - 2 decimals ~ 1.1km latitude.
  /// - 3 decimals ~ 110m latitude.
  static const int defaultRoundingDecimals = 2;

  Future<LocationPermission> ensurePermission({bool requestIfNeeded = true}) async {
    if (kIsWeb) {
      // Web is handled by the browser prompt; Geolocator still returns a permission.
    }
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) return LocationPermission.denied;

    var permission = await Geolocator.checkPermission();
    if (!requestIfNeeded) return permission;

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission;
  }

  bool isUsablePermission(LocationPermission p) =>
      p == LocationPermission.whileInUse || p == LocationPermission.always;

  /// Returns a *coarsened* position suitable for resource recommendations.
  ///
  /// If permission isn't granted, returns null.
  Future<ArieApproxLocation?> getApproxLocation({
    int roundingDecimals = defaultRoundingDecimals,
    Duration timeout = const Duration(seconds: 6),
  }) async {
    try {
      final permission = await ensurePermission(requestIfNeeded: false);
      if (!isUsablePermission(permission)) return null;

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: timeout,
      );
      return ArieApproxLocation(
        lat: _round(pos.latitude, roundingDecimals),
        lng: _round(pos.longitude, roundingDecimals),
        precision: roundingDecimals,
      );
    } catch (e) {
      debugPrint('LocationIntelligenceService.getApproxLocation error: $e');
      return null;
    }
  }

  double _round(double v, int decimals) {
    final mod = math.pow(10, decimals).toDouble();
    return (v * mod).round() / mod;
  }
}

class ArieApproxLocation {
  final double lat;
  final double lng;
  final int precision;

  const ArieApproxLocation({
    required this.lat,
    required this.lng,
    required this.precision,
  });

  Map<String, dynamic> toJson() => {
        'lat': lat,
        'lng': lng,
        'precisionDecimals': precision,
      };
}
