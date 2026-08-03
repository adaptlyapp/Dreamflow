import 'package:cloud_firestore/cloud_firestore.dart';

class ResourceSuggestion {
  final String id;
  final String name;
  final String type; // therapist | center | hospital | service | pharmacy
  final String address; // free-form address
  final double? lat;
  final double? lng;
  final String? city;
  final String? state;
  final String? postalCode;
  final String? country;
  final String? phone;
  final String? website;
  final String? contactEmail;
  final String? description;
  final List<String> specialties;
  final String status; // pending | approved | rejected
  final String? createdBy;
  final String? createdByEmail;
  final DateTime createdAt;
  final DateTime updatedAt;

  ResourceSuggestion({
    required this.id,
    required this.name,
    required this.type,
    required this.address,
    required this.lat,
    required this.lng,
    this.city,
    this.state,
    this.postalCode,
    this.country,
    this.phone,
    this.website,
    this.contactEmail,
    this.description,
    this.specialties = const [],
    this.status = 'pending',
    this.createdBy,
    this.createdByEmail,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ResourceSuggestion.fromJson(Map<String, dynamic> json, String id) => ResourceSuggestion(
        id: id,
        name: json['name'] ?? '',
        type: json['type'] ?? 'service',
        address: json['address'] ?? '',
        lat: (json['lat'] is num) ? (json['lat'] as num).toDouble() : null,
        lng: (json['lng'] is num) ? (json['lng'] as num).toDouble() : null,
        city: json['city'],
        state: json['state'],
        postalCode: json['postal_code'] ?? json['postalCode'],
        country: json['country'],
        phone: json['phone'],
        website: json['website'],
        contactEmail: json['contact_email'] ?? json['contactEmail'],
        description: json['description'],
        specialties: (json['specialties'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
        status: json['status'] ?? 'pending',
        createdBy: json['created_by'] ?? json['createdBy'],
        createdByEmail: json['created_by_email'] ?? json['createdByEmail'],
        createdAt: json['created_at'] is Timestamp
            ? (json['created_at'] as Timestamp).toDate()
            : DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
        updatedAt: json['updated_at'] is Timestamp
            ? (json['updated_at'] as Timestamp).toDate()
            : DateTime.tryParse(json['updated_at']?.toString() ?? '') ?? DateTime.now(),
      );

  Map<String, dynamic> toMapForSubmit() => {
        'name': name,
        'type': type,
        'address': address,
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
        if (city != null && city!.isNotEmpty) 'city': city,
        if (state != null && state!.isNotEmpty) 'state': state,
        if (postalCode != null && postalCode!.isNotEmpty) 'postal_code': postalCode,
        if (country != null && country!.isNotEmpty) 'country': country,
        if (phone != null && phone!.isNotEmpty) 'phone': phone,
        if (website != null && website!.isNotEmpty) 'website': website,
        if (contactEmail != null && contactEmail!.isNotEmpty) 'contact_email': contactEmail,
        if (description != null && description!.isNotEmpty) 'description': description,
        if (specialties.isNotEmpty) 'specialties': specialties,
      };
}
