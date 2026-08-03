import 'package:flutter/material.dart';

/// Hospital model with optional brand colors used to theme the app.
class Hospital {
  final String id;
  final String name;
  final String? city;
  final String? metro; // e.g., 'stl' for St. Louis
  final Color? brandPrimary;
  final Color? brandSecondary;
  final Color? brandTertiary;

  const Hospital({
    required this.id,
    required this.name,
    this.city,
    this.metro,
    this.brandPrimary,
    this.brandSecondary,
    this.brandTertiary,
  });

  factory Hospital.fromJson(Map<String, dynamic> json, String id) {
    Color? _parseColor(dynamic v) {
      if (v is int) return Color(v);
      if (v is String) {
        final s = v.trim();
        // Accept formats like '#RRGGBB' or '0xFFRRGGBB'
        if (s.startsWith('#') && (s.length == 7 || s.length == 9)) {
          final hex = s.replaceFirst('#', '');
          // If no alpha, assume FF
          final full = hex.length == 6 ? 'FF$hex' : hex;
          return Color(int.parse('0x$full'));
        }
        if (s.startsWith('0x')) {
          return Color(int.parse(s));
        }
      }
      return null;
    }

    return Hospital(
      id: id,
      name: (json['name'] as String?)?.trim() ?? 'Hospital',
      city: (json['city'] as String?)?.trim(),
      metro: (json['metro'] as String?)?.trim(),
      brandPrimary: _parseColor(json['brandPrimary']),
      brandSecondary: _parseColor(json['brandSecondary']),
      brandTertiary: _parseColor(json['brandTertiary']),
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    if (city != null) 'city': city,
    if (metro != null) 'metro': metro,
    if (brandPrimary != null) 'brandPrimary': brandPrimary!.value,
    if (brandSecondary != null) 'brandSecondary': brandSecondary!.value,
    if (brandTertiary != null) 'brandTertiary': brandTertiary!.value,
  };
}
