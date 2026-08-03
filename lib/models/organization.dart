import 'package:flutter/material.dart';

/// Organization model with optional brand colors used to theme the app.
class Organization {
  final String id;
  final String name;
  final String slug;
  final String status;
  final Map<String, dynamic>? settings;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  
  // Brand colors extracted from settings
  final Color? brandPrimary;
  final Color? brandSecondary;
  final Color? brandTertiary;

  const Organization({
    required this.id,
    required this.name,
    required this.slug,
    this.status = 'active',
    this.settings,
    this.createdAt,
    this.updatedAt,
    this.brandPrimary,
    this.brandSecondary,
    this.brandTertiary,
  });

  factory Organization.fromJson(Map<String, dynamic> json) {
    Color? _parseColor(dynamic v) {
      if (v is int) return Color(v);
      if (v is String) {
        final s = v.trim();
        if (s.startsWith('#') && (s.length == 7 || s.length == 9)) {
          final hex = s.replaceFirst('#', '');
          final full = hex.length == 6 ? 'FF$hex' : hex;
          return Color(int.parse('0x$full'));
        }
        if (s.startsWith('0x')) {
          return Color(int.parse(s));
        }
      }
      return null;
    }

    final settingsMap = json['settings'] as Map<String, dynamic>?;
    
    return Organization(
      id: json['id'] as String,
      name: (json['name'] as String?)?.trim() ?? 'Organization',
      slug: (json['slug'] as String?)?.trim() ?? '',
      status: (json['status'] as String?) ?? 'active',
      settings: settingsMap,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : null,
      brandPrimary: _parseColor(settingsMap?['brandPrimary']),
      brandSecondary: _parseColor(settingsMap?['brandSecondary']),
      brandTertiary: _parseColor(settingsMap?['brandTertiary']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'slug': slug,
    'status': status,
    if (settings != null) 'settings': settings,
    if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
  };
}
