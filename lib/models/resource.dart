import 'package:cloud_firestore/cloud_firestore.dart';

class Resource {
  final String id;
  final String name;
  final String type;
  final List<String> specialty;
  final String location;
  final String address;
  final double distance;
  final double? lat;
  final double? lng;
  final String? contactPhone;
  final String? contactEmail;
  final String? website;
  final String availability;
  final double rating;
  final int reviewCount;
  // Google Places enrichment (optional)
  final String? googleMapsUrl;
  /// 0..4 (free..very_expensive) when known.
  final int? priceLevel;
  final List<String> placeTypes;
  /// Human-readable hours summary when available.
  final String? hours;
  /// Raw Google accessibility options (wheelchair accessible etc.) when available.
  final Map<String, dynamic>? accessibilityOptions;
  /// Raw Google reviews (truncated) when available.
  final List<Map<String, dynamic>> reviews;
  final DateTime createdAt;
  final DateTime updatedAt;

  Resource({
    required this.id,
    required this.name,
    required this.type,
    required this.specialty,
    required this.location,
    required this.address,
    required this.distance,
    this.lat,
    this.lng,
    this.contactPhone,
    this.contactEmail,
    this.website,
    required this.availability,
    required this.rating,
    required this.reviewCount,
    this.googleMapsUrl,
    this.priceLevel,
    this.placeTypes = const [],
    this.hours,
    this.accessibilityOptions,
    this.reviews = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory Resource.fromJson(Map<String, dynamic> json) => Resource(
        id: json['id'],
        name: json['name'],
        type: json['type'],
        specialty: List<String>.from(json['specialty'] ?? []),
        location: json['location'],
        address: json['address'],
        distance: (json['distance'] ?? 0).toDouble(),
        lat: (json['lat'] is num) ? (json['lat'] as num).toDouble() : null,
        lng: (json['lng'] is num) ? (json['lng'] as num).toDouble() : null,
        contactPhone: json['contactPhone'],
        contactEmail: json['contactEmail'],
        website: json['website'],
        availability: json['availability'],
        rating: (json['rating'] ?? 0).toDouble(),
        reviewCount: json['reviewCount'] ?? 0,
        googleMapsUrl: json['googleMapsUrl'] ?? json['google_maps_url'],
        priceLevel: (json['priceLevel'] is num) ? (json['priceLevel'] as num).toInt() : null,
        placeTypes: (json['placeTypes'] is List)
            ? List<String>.from((json['placeTypes'] as List).map((e) => e.toString()))
            : const [],
        hours: json['hours'],
        accessibilityOptions: (json['accessibilityOptions'] is Map)
            ? Map<String, dynamic>.from(json['accessibilityOptions'] as Map)
            : null,
        reviews: (json['reviews'] is List)
            ? List<Map<String, dynamic>>.from(
                (json['reviews'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)),
              )
            : const [],
        createdAt: json['createdAt'] is Timestamp
            ? (json['createdAt'] as Timestamp).toDate()
            : DateTime.parse(json['createdAt']),
        updatedAt: json['updatedAt'] is Timestamp
            ? (json['updatedAt'] as Timestamp).toDate()
            : DateTime.parse(json['updatedAt']),
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type,
    'specialty': specialty,
    'location': location,
    'address': address,
    'distance': distance,
    'lat': lat,
    'lng': lng,
    'contactPhone': contactPhone,
    'contactEmail': contactEmail,
    'website': website,
    'availability': availability,
    'rating': rating,
    'reviewCount': reviewCount,
    'googleMapsUrl': googleMapsUrl,
    'priceLevel': priceLevel,
    'placeTypes': placeTypes,
    'hours': hours,
    'accessibilityOptions': accessibilityOptions,
    'reviews': reviews,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  Resource copyWith({
    String? id,
    String? name,
    String? type,
    List<String>? specialty,
    String? location,
    String? address,
    double? distance,
    double? lat,
    double? lng,
    String? contactPhone,
    String? contactEmail,
    String? website,
    String? availability,
    double? rating,
    int? reviewCount,
    String? googleMapsUrl,
    int? priceLevel,
    List<String>? placeTypes,
    String? hours,
    Map<String, dynamic>? accessibilityOptions,
    List<Map<String, dynamic>>? reviews,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Resource(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      specialty: specialty ?? this.specialty,
      location: location ?? this.location,
      address: address ?? this.address,
      distance: distance ?? this.distance,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      contactPhone: contactPhone ?? this.contactPhone,
      contactEmail: contactEmail ?? this.contactEmail,
      website: website ?? this.website,
      availability: availability ?? this.availability,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      googleMapsUrl: googleMapsUrl ?? this.googleMapsUrl,
      priceLevel: priceLevel ?? this.priceLevel,
      placeTypes: placeTypes ?? this.placeTypes,
      hours: hours ?? this.hours,
      accessibilityOptions: accessibilityOptions ?? this.accessibilityOptions,
      reviews: reviews ?? this.reviews,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
