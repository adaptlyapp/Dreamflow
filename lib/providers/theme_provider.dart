import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:wellspring/models/hospital.dart';
import 'package:wellspring/models/organization.dart';
import 'package:wellspring/services/hospital_service.dart';
import 'package:wellspring/services/organization_service.dart';
import 'package:wellspring/services/user_service.dart';
import 'package:wellspring/theme.dart' as app_theme;

class BrandPalette {
  final Color primary;
  final Color secondary;
  final Color tertiary;
  const BrandPalette({required this.primary, required this.secondary, required this.tertiary});
}

class ThemeProvider extends ChangeNotifier {
  final HospitalService _hospitalService = HospitalService();
  final OrganizationService _organizationService = OrganizationService();
  final UserService _userService = UserService();

  BrandPalette? _brand;
  Hospital? _hospital;
  Organization? _organization;

  BrandPalette? get brand => _brand;
  Hospital? get hospital => _hospital;
  Organization? get organization => _organization;

  ThemeData get lightTheme => _brand == null
      ? app_theme.lightTheme
      : _branded(app_theme.lightTheme, _brand!);
  ThemeData get darkTheme => _brand == null
      ? app_theme.darkTheme
      : _branded(app_theme.darkTheme, _brand!);

  Future<void> loadFromUserPreferences() async {
    try {
      final u = await _userService.getCurrentUser();
      final prefs = u?.preferences ?? const {};
      
      // Try loading organization first (new system)
      final organizationId = (prefs['organizationId'] as String?)?.trim();
      if (organizationId != null && organizationId.isNotEmpty) {
        await applyOrganizationById(organizationId);
        return;
      }
      
      // Fallback to hospital for backwards compatibility
      final hospitalId = (prefs['hospitalId'] as String?)?.trim();
      if (hospitalId != null && hospitalId.isNotEmpty) {
        await applyHospitalById(hospitalId);
      }
    } catch (e) {
      debugPrint('ThemeProvider.loadFromUserPreferences error: $e');
    }
  }

  Future<void> applyHospitalById(String hospitalId) async {
    try {
      final h = await _hospitalService.getHospitalById(hospitalId);
      if (h != null) {
        await applyHospital(h);
      }
    } catch (e) {
      debugPrint('ThemeProvider.applyHospitalById error: $e');
    }
  }

  Future<void> applyHospital(Hospital hospital) async {
    _hospital = hospital;
    _organization = null;
    if (hospital.brandPrimary != null && hospital.brandSecondary != null && hospital.brandTertiary != null) {
      _brand = BrandPalette(
        primary: hospital.brandPrimary!,
        secondary: hospital.brandSecondary!,
        tertiary: hospital.brandTertiary!,
      );
    } else {
      _brand = null; // If no brand colors, fall back to default theme
    }
    notifyListeners();
  }

  Future<void> applyOrganizationById(String organizationId) async {
    try {
      final org = await _organizationService.getOrganizationById(organizationId);
      if (org != null) {
        await applyOrganization(org);
      }
    } catch (e) {
      debugPrint('ThemeProvider.applyOrganizationById error: $e');
    }
  }

  Future<void> applyOrganization(Organization organization) async {
    _organization = organization;
    _hospital = null;
    if (organization.brandPrimary != null && organization.brandSecondary != null && organization.brandTertiary != null) {
      _brand = BrandPalette(
        primary: organization.brandPrimary!,
        secondary: organization.brandSecondary!,
        tertiary: organization.brandTertiary!,
      );
    } else {
      _brand = null; // If no brand colors, fall back to default theme
    }
    notifyListeners();
  }

  ThemeData _branded(ThemeData base, BrandPalette palette) {
    final cs = base.colorScheme;
    return base.copyWith(
      colorScheme: cs.copyWith(
        primary: palette.primary,
        secondary: palette.secondary,
        tertiary: palette.tertiary,
        // Maintain text/icon contrast from the base theme
        onPrimary: cs.onPrimary,
        onSecondary: cs.onSecondary,
        onTertiary: cs.onTertiary,
      ),
    );
  }
}
