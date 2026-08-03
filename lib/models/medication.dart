/// Represents a medication with its name and scheduled times.
class Medication {
  final String id;
  final String name;
  final String? dosage;
  final List<String> times; // e.g., ['08:00', '14:00', '20:00']
  final String? notes;

  const Medication({
    required this.id,
    required this.name,
    this.dosage,
    this.times = const [],
    this.notes,
  });

  factory Medication.fromJson(Map<String, dynamic> json) => Medication(
    id: json['id'] as String,
    name: json['name'] as String,
    dosage: json['dosage'] as String?,
    times: List<String>.from(json['times'] ?? []),
    notes: json['notes'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    if (dosage != null) 'dosage': dosage,
    'times': times,
    if (notes != null) 'notes': notes,
  };

  Medication copyWith({
    String? name,
    String? dosage,
    List<String>? times,
    String? notes,
  }) => Medication(
    id: id,
    name: name ?? this.name,
    dosage: dosage ?? this.dosage,
    times: times ?? this.times,
    notes: notes ?? this.notes,
  );

  /// Returns a formatted string of scheduled times (e.g., "Morning, Noon, Night")
  String get formattedTimes {
    if (times.isEmpty) return 'No times set';
    return times.map((t) {
      final parts = t.split(':');
      if (parts.length != 2) return t;
      final hour = int.tryParse(parts[0]) ?? 0;
      final minute = int.tryParse(parts[1]) ?? 0;
      
      // Check for preset times
      if (hour == 8 && minute == 0) return 'Morning';
      if (hour == 12 && minute == 0) return 'Noon';
      if (hour == 20 && minute == 0) return 'Night';
      
      final period = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      return '$displayHour:${minute.toString().padLeft(2, '0')} $period';
    }).join(', ');
  }
}
