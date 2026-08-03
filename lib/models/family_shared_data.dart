/// Represents data that has been shared with family members
class FamilySharedData {
  final String id;
  final String patientId;
  final String dataType; // overview, health_tracker, goals, notes, resources, alerts
  final Map<String, dynamic> data;
  final DateTime sharedAt;
  final DateTime updatedAt;

  FamilySharedData({
    required this.id,
    required this.patientId,
    required this.dataType,
    required this.data,
    required this.sharedAt,
    required this.updatedAt,
  });

  factory FamilySharedData.fromJson(Map<String, dynamic> json) => FamilySharedData(
    id: json['id'],
    patientId: json['patientId'],
    dataType: json['dataType'],
    data: Map<String, dynamic>.from(json['data'] ?? {}),
    sharedAt: DateTime.parse(json['sharedAt']),
    updatedAt: DateTime.parse(json['updatedAt']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'patientId': patientId,
    'dataType': dataType,
    'data': data,
    'sharedAt': sharedAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };
}
