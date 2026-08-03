import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:health/health.dart';

/// HealthService provides a wrapper around the `health` plugin
/// to request authorization and read health data from Apple Watch and iPhone.
///
/// Notes:
/// - Only supported on iOS via HealthKit in this project. On other platforms
///   this will safely no-op and return null/false.
/// - Supports background delivery and auto-sync for real-time health monitoring
class HealthService {
  final Health _health = Health();
  Timer? _backgroundSyncTimer;
  final List<Function(Map<String, dynamic>)> _listeners = [];
  bool _isAuthorized = false;

  bool get _isIOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// All health data types we request permission for
  static final List<HealthDataType> _allTypes = [
    HealthDataType.STEPS,
    HealthDataType.HEART_RATE,
    HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
    HealthDataType.BLOOD_PRESSURE_DIASTOLIC,
    HealthDataType.WEIGHT,
    HealthDataType.BODY_TEMPERATURE,
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.WORKOUT,
  ];

  /// Request read permission for all health metrics. Returns true if authorized.
  /// Only requests permission once and caches the result.
  Future<bool> requestAuthorization() async {
    if (!_isIOS) return false;
    
    // Return cached authorization state if already checked
    if (_isAuthorized) {
      debugPrint('HealthService: Already authorized, using cached state');
      return true;
    }
    
    try {
      final perms = _allTypes.map((_) => HealthDataAccess.READ).toList();
      final alreadyHas = await _health.hasPermissions(_allTypes, permissions: perms) ?? false;
      if (alreadyHas) {
        debugPrint('HealthService: Permissions already granted');
        _isAuthorized = true;
        return true;
      }
      
      debugPrint('HealthService: Requesting permissions from user');
      final ok = await _health.requestAuthorization(_allTypes, permissions: perms);
      _isAuthorized = ok;
      debugPrint('HealthService: Permission request result: $ok');
      return ok;
    } catch (e) {
      debugPrint('HealthService.requestAuthorization error: $e');
      return false;
    }
  }

  /// Returns whether we currently have read access for health data.
  /// Uses cached state if available, otherwise checks with HealthKit.
  Future<bool> hasAuthorization() async {
    if (!_isIOS) return false;
    
    // Return cached state if available
    if (_isAuthorized) return true;
    
    try {
      final perms = _allTypes.map((_) => HealthDataAccess.READ).toList();
      final hasPerms = await _health.hasPermissions(_allTypes, permissions: perms) ?? false;
      _isAuthorized = hasPerms;
      return hasPerms;
    } catch (e) {
      debugPrint('HealthService.hasAuthorization error: $e');
      return false;
    }
  }

  /// Fetches the total steps from midnight to now. Returns null on error or if unsupported.
  Future<int?> getTodaySteps() async {
    if (!_isIOS) return null;
    try {
      final hasAuth = await hasAuthorization();
      if (!hasAuth) {
        final ok = await requestAuthorization();
        if (!ok) return null;
      }
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day);
      final total = await _health.getTotalStepsInInterval(start, now);
      return total;
    } catch (e) {
      debugPrint('HealthService.getTodaySteps error: $e');
      return null;
    }
  }

  /// Fetches the most recent heart rate reading. Returns null if unavailable.
  Future<int?> getLatestHeartRate() async {
    if (!_isIOS) return null;
    try {
      final hasAuth = await hasAuthorization();
      if (!hasAuth) {
        final ok = await requestAuthorization();
        if (!ok) return null;
      }
      
      final now = DateTime.now();
      final start = now.subtract(const Duration(hours: 2));
      final data = await _health.getHealthDataFromTypes(
        types: [HealthDataType.HEART_RATE],
        startTime: start,
        endTime: now,
      );
      
      if (data.isEmpty) return null;
      // Get the most recent reading
      final sorted = data.toList()..sort((a, b) => b.dateTo.compareTo(a.dateTo));
      final bpm = sorted.first.value.toJson()['numericValue'] as num?;
      return bpm?.round();
    } catch (e) {
      debugPrint('HealthService.getLatestHeartRate error: $e');
      return null;
    }
  }

  /// Fetches the most recent blood pressure reading. Returns a map with 'systolic' and 'diastolic'.
  Future<Map<String, int>?> getLatestBloodPressure() async {
    if (!_isIOS) return null;
    try {
      final hasAuth = await hasAuthorization();
      if (!hasAuth) {
        final ok = await requestAuthorization();
        if (!ok) return null;
      }
      
      final now = DateTime.now();
      final start = now.subtract(const Duration(days: 1));
      final sysData = await _health.getHealthDataFromTypes(
        types: [HealthDataType.BLOOD_PRESSURE_SYSTOLIC],
        startTime: start,
        endTime: now,
      );
      
      final diaData = await _health.getHealthDataFromTypes(
        types: [HealthDataType.BLOOD_PRESSURE_DIASTOLIC],
        startTime: start,
        endTime: now,
      );
      
      if (sysData.isEmpty || diaData.isEmpty) return null;
      
      final sysSorted = sysData.toList()..sort((a, b) => b.dateTo.compareTo(a.dateTo));
      final diaSorted = diaData.toList()..sort((a, b) => b.dateTo.compareTo(a.dateTo));
      
      final sys = sysSorted.first.value.toJson()['numericValue'] as num?;
      final dia = diaSorted.first.value.toJson()['numericValue'] as num?;
      
      if (sys == null || dia == null) return null;
      
      return {
        'systolic': sys.round(),
        'diastolic': dia.round(),
      };
    } catch (e) {
      debugPrint('HealthService.getLatestBloodPressure error: $e');
      return null;
    }
  }

  /// Fetches the most recent weight reading in kg. Returns null if unavailable.
  Future<double?> getLatestWeight() async {
    if (!_isIOS) return null;
    try {
      final hasAuth = await hasAuthorization();
      if (!hasAuth) {
        final ok = await requestAuthorization();
        if (!ok) return null;
      }
      
      final now = DateTime.now();
      final start = now.subtract(const Duration(days: 7));
      final data = await _health.getHealthDataFromTypes(
        types: [HealthDataType.WEIGHT],
        startTime: start,
        endTime: now,
      );
      
      if (data.isEmpty) return null;
      final sorted = data.toList()..sort((a, b) => b.dateTo.compareTo(a.dateTo));
      final kg = sorted.first.value.toJson()['numericValue'] as num?;
      return kg?.toDouble();
    } catch (e) {
      debugPrint('HealthService.getLatestWeight error: $e');
      return null;
    }
  }

  /// Fetches the most recent body temperature in Celsius. Returns null if unavailable.
  Future<double?> getLatestTemperature() async {
    if (!_isIOS) return null;
    try {
      final hasAuth = await hasAuthorization();
      if (!hasAuth) {
        final ok = await requestAuthorization();
        if (!ok) return null;
      }
      
      final now = DateTime.now();
      final start = now.subtract(const Duration(days: 1));
      final data = await _health.getHealthDataFromTypes(
        types: [HealthDataType.BODY_TEMPERATURE],
        startTime: start,
        endTime: now,
      );
      
      if (data.isEmpty) return null;
      final sorted = data.toList()..sort((a, b) => b.dateTo.compareTo(a.dateTo));
      final celsius = sorted.first.value.toJson()['numericValue'] as num?;
      return celsius?.toDouble();
    } catch (e) {
      debugPrint('HealthService.getLatestTemperature error: $e');
      return null;
    }
  }

  /// Fetches total sleep duration for last night in hours. Returns null if unavailable.
  Future<double?> getLastNightSleep() async {
    if (!_isIOS) return null;
    try {
      final hasAuth = await hasAuthorization();
      if (!hasAuth) {
        final ok = await requestAuthorization();
        if (!ok) return null;
      }
      
      final now = DateTime.now();
      // Get sleep from yesterday 6PM to today 12PM
      final start = DateTime(now.year, now.month, now.day - 1, 18);
      final end = DateTime(now.year, now.month, now.day, 12);
      final data = await _health.getHealthDataFromTypes(
        types: [HealthDataType.SLEEP_ASLEEP],
        startTime: start,
        endTime: end,
      );
      
      if (data.isEmpty) return null;
      
      // Sum all sleep intervals
      double totalMinutes = 0;
      for (final point in data) {
        final duration = point.dateTo.difference(point.dateFrom).inMinutes;
        totalMinutes += duration;
      }
      
      return totalMinutes / 60.0; // Convert to hours
    } catch (e) {
      debugPrint('HealthService.getLastNightSleep error: $e');
      return null;
    }
  }

  /// Fetches all available health data for today and returns it as a map.
  /// Useful for auto-filling tracker entries.
  Future<Map<String, dynamic>> getTodayHealthData() async {
    if (!_isIOS) return {};
    try {
      final hasAuth = await hasAuthorization();
      if (!hasAuth) {
        final ok = await requestAuthorization();
        if (!ok) return {};
      }

      final results = <String, dynamic>{};
      
      // Fetch all metrics in parallel
      final futures = await Future.wait([
        getTodaySteps(),
        getLatestHeartRate(),
        getLatestBloodPressure(),
        getLatestWeight(),
        getLatestTemperature(),
        getLastNightSleep(),
      ]);

      if (futures[0] != null) results['steps'] = futures[0];
      if (futures[1] != null) results['heartRate'] = futures[1];
      if (futures[2] != null) {
        final bp = futures[2] as Map<String, int>;
        results['systolicBP'] = bp['systolic'];
        results['diastolicBP'] = bp['diastolic'];
      }
      if (futures[3] != null) results['weight'] = futures[3];
      if (futures[4] != null) results['temperature'] = futures[4];
      if (futures[5] != null) {
        final sleepHours = futures[5] as double;
        // Convert hours to 0-10 quality scale (8 hours = 10/10)
        results['sleepQuality'] = (sleepHours / 0.8).round().clamp(0, 10);
      }

      return results;
    } catch (e) {
      debugPrint('HealthService.getTodayHealthData error: $e');
      return {};
    }
  }

  /// Enables continuous health data syncing with automatic updates.
  /// Uses periodic polling (every 5 minutes) to keep health data fresh.
  Future<bool> enableBackgroundDelivery() async {
    if (!_isIOS) return false;
    try {
      final hasAuth = await hasAuthorization();
      if (!hasAuth) {
        final ok = await requestAuthorization();
        if (!ok) return false;
      }

      // Start periodic sync to ensure data stays fresh
      _startPeriodicSync();
      
      debugPrint('HealthService: Continuous health sync enabled');
      return true;
    } catch (e) {
      debugPrint('HealthService.enableBackgroundDelivery error: $e');
      return false;
    }
  }

  /// Disables continuous health data syncing.
  Future<void> disableBackgroundDelivery() async {
    if (!_isIOS) return;
    _stopPeriodicSync();
    debugPrint('HealthService: Continuous health sync disabled');
  }

  /// Starts periodic background sync (every 5 minutes) while app is active.
  void _startPeriodicSync() {
    _backgroundSyncTimer?.cancel();
    _backgroundSyncTimer = Timer.periodic(const Duration(minutes: 5), (_) async {
      debugPrint('HealthService: Running periodic sync...');
      final data = await getTodayHealthData();
      _notifyListeners(data);
    });
    debugPrint('HealthService: Periodic sync started (every 5 minutes)');
  }

  /// Stops periodic background sync.
  void _stopPeriodicSync() {
    _backgroundSyncTimer?.cancel();
    _backgroundSyncTimer = null;
  }

  /// Registers a listener to be notified when health data is synced.
  void addListener(Function(Map<String, dynamic>) listener) {
    _listeners.add(listener);
  }

  /// Removes a previously registered listener.
  void removeListener(Function(Map<String, dynamic>) listener) {
    _listeners.remove(listener);
  }

  /// Notifies all listeners of new health data.
  void _notifyListeners(Map<String, dynamic> data) {
    if (data.isNotEmpty) {
      for (final listener in _listeners) {
        listener(data);
      }
    }
  }

  /// Performs an immediate sync and returns the latest health data.
  /// This should be called on app launch and periodically.
  Future<Map<String, dynamic>> syncNow() async {
    if (!_isIOS) return {};
    debugPrint('HealthService: Syncing health data now...');
    final data = await getTodayHealthData();
    _notifyListeners(data);
    return data;
  }

  /// Clean up resources when service is disposed.
  void dispose() {
    _stopPeriodicSync();
    _listeners.clear();
  }
}
