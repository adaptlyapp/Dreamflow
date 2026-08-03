import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:wellspring/models/vr_agency.dart';
import 'package:csv/csv.dart';

class VRAgencyService {
  static final VRAgencyService _instance = VRAgencyService._internal();
  factory VRAgencyService() => _instance;
  VRAgencyService._internal();

  List<VRAgency>? _agencies;
  bool _isLoaded = false;

  /// Loads all VR agencies from the CSV file
  Future<void> _ensureLoaded() async {
    if (_isLoaded) return;
    
    try {
      final csvString = await rootBundle.loadString('assets/text/adaptly_nationwide_vocational_rehabilitation_directory.csv');
      final rows = const CsvToListConverter(eol: '\n').convert(csvString);
      
      if (rows.isEmpty) {
        _agencies = [];
        _isLoaded = true;
        return;
      }

      // First row is headers
      final headers = rows[0].map((h) => h.toString()).toList();
      final dataRows = rows.skip(1);

      _agencies = dataRows.map((row) {
        final Map<String, dynamic> rowMap = {};
        for (int i = 0; i < headers.length && i < row.length; i++) {
          rowMap[headers[i]] = row[i];
        }
        return VRAgency.fromCsv(rowMap);
      }).toList();

      _isLoaded = true;
      debugPrint('VRAgencyService: Loaded ${_agencies!.length} VR agencies');
    } catch (e) {
      debugPrint('VRAgencyService._ensureLoaded error: $e');
      _agencies = [];
      _isLoaded = true;
    }
  }

  /// Returns all VR agencies
  Future<List<VRAgency>> getAllAgencies() async {
    await _ensureLoaded();
    return _agencies ?? [];
  }

  /// Returns agencies for a specific state (by abbreviation, e.g., "CA", "NY")
  Future<List<VRAgency>> getAgenciesByState(String stateAbbr) async {
    await _ensureLoaded();
    if (_agencies == null) return [];
    
    final abbr = stateAbbr.trim().toUpperCase();
    return _agencies!.where((agency) => agency.abbr == abbr).toList();
  }

  /// Returns agencies for a specific state by full name (e.g., "California", "New York")
  Future<List<VRAgency>> getAgenciesByStateName(String stateName) async {
    await _ensureLoaded();
    if (_agencies == null) return [];
    
    final name = stateName.trim().toLowerCase();
    return _agencies!.where((agency) => 
      agency.jurisdiction.toLowerCase() == name
    ).toList();
  }

  /// Returns only general VR agencies (excludes blind services)
  Future<List<VRAgency>> getGeneralVRAgencies() async {
    await _ensureLoaded();
    if (_agencies == null) return [];
    
    return _agencies!.where((agency) => agency.isGeneralVR).toList();
  }

  /// Returns only blind/vision services agencies
  Future<List<VRAgency>> getBlindServicesAgencies() async {
    await _ensureLoaded();
    if (_agencies == null) return [];
    
    return _agencies!.where((agency) => agency.isBlindServices).toList();
  }

  /// Searches agencies by name
  Future<List<VRAgency>> searchAgencies(String query) async {
    await _ensureLoaded();
    if (_agencies == null) return [];
    
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return _agencies!;
    
    return _agencies!.where((agency) =>
      agency.agencyName.toLowerCase().contains(q) ||
      agency.jurisdiction.toLowerCase().contains(q) ||
      agency.abbr.toLowerCase().contains(q)
    ).toList();
  }

  /// Returns agencies relevant to a user's location
  /// Accepts state abbreviation (e.g., "CA"), state name (e.g., "California"), 
  /// or null to return all
  Future<List<VRAgency>> getRelevantAgencies({
    String? stateAbbr,
    String? stateName,
    bool includeBlindServices = true,
    bool includeGeneralVR = true,
  }) async {
    await _ensureLoaded();
    if (_agencies == null) return [];

    List<VRAgency> filtered = _agencies!;

    // Filter by state if provided
    if (stateAbbr != null && stateAbbr.isNotEmpty) {
      final abbr = stateAbbr.trim().toUpperCase();
      filtered = filtered.where((a) => a.abbr == abbr).toList();
    } else if (stateName != null && stateName.isNotEmpty) {
      final name = stateName.trim().toLowerCase();
      filtered = filtered.where((a) => a.jurisdiction.toLowerCase() == name).toList();
    }

    // Filter by agency type
    if (!includeBlindServices) {
      filtered = filtered.where((a) => !a.isBlindServices).toList();
    }
    if (!includeGeneralVR) {
      filtered = filtered.where((a) => !a.isGeneralVR).toList();
    }

    return filtered;
  }

  /// Checks if VR agencies are applicable based on patient conditions
  /// Returns true if patient has conditions that benefit from vocational rehabilitation
  bool areVRAgenciesApplicable({
    List<String>? conditionIds,
    String? recoveryPhase,
  }) {
    // VR agencies are most relevant during mid-to-late recovery phases
    // when patients are working towards returning to work or developing new skills
    
    if (recoveryPhase != null) {
      final phase = recoveryPhase.toLowerCase();
      // Most applicable during active recovery and community reintegration phases
      if (phase.contains('community') || 
          phase.contains('reintegration') ||
          phase.contains('independence') ||
          phase.contains('active')) {
        return true;
      }
    }

    // VR is highly relevant for SCI, TBI, stroke, and other conditions
    // affecting mobility, cognition, or functional abilities
    if (conditionIds != null && conditionIds.isNotEmpty) {
      final relevantConditions = [
        'sci', 'spinal', 'cord injury',
        'tbi', 'traumatic brain', 'brain injury',
        'stroke', 'cva',
        'amputation',
        'ms', 'multiple sclerosis',
        'paralysis', 'paraplegia', 'tetraplegia', 'quadriplegia',
      ];
      
      for (final conditionId in conditionIds) {
        final id = conditionId.toLowerCase();
        if (relevantConditions.any((rc) => id.contains(rc))) {
          return true;
        }
      }
    }

    // Default: VR agencies are generally applicable for recovery journeys
    return true;
  }
}
