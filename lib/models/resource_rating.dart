import 'package:cloud_firestore/cloud_firestore.dart';

class ResourceRatingSummary {
  final String resourceId;
  final double avgGoogle;
  final int countGoogle;
  final double avgApp;
  final int countApp;
  final double avgCombined;
  final int countCombined;
  final DateTime? updatedAt;

  const ResourceRatingSummary({
    required this.resourceId,
    required this.avgGoogle,
    required this.countGoogle,
    required this.avgApp,
    required this.countApp,
    required this.avgCombined,
    required this.countCombined,
    this.updatedAt,
  });

  factory ResourceRatingSummary.empty(String resourceId) => ResourceRatingSummary(
        resourceId: resourceId,
        avgGoogle: 0,
        countGoogle: 0,
        avgApp: 0,
        countApp: 0,
        avgCombined: 0,
        countCombined: 0,
        updatedAt: null,
      );

  factory ResourceRatingSummary.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    DateTime? ts;
    final raw = data['updatedAt'];
    if (raw is Timestamp) ts = raw.toDate();
    return ResourceRatingSummary(
      resourceId: doc.id,
      avgGoogle: (data['avgGoogle'] is num) ? (data['avgGoogle'] as num).toDouble() : 0,
      countGoogle: (data['countGoogle'] is num) ? (data['countGoogle'] as num).toInt() : 0,
      avgApp: (data['avgApp'] is num) ? (data['avgApp'] as num).toDouble() : 0,
      countApp: (data['countApp'] is num) ? (data['countApp'] as num).toInt() : 0,
      avgCombined: (data['avgCombined'] is num) ? (data['avgCombined'] as num).toDouble() : 0,
      countCombined: (data['countCombined'] is num) ? (data['countCombined'] as num).toInt() : 0,
      updatedAt: ts,
    );
  }

  factory ResourceRatingSummary.fromSupabaseMap(Map<String, dynamic> data, String resourceId) {
    DateTime? ts;
    final raw = data['updated_at'];
    if (raw is String) {
      try {
        ts = DateTime.parse(raw);
      } catch (_) {}
    }
    return ResourceRatingSummary(
      resourceId: resourceId,
      avgGoogle: (data['avg_google'] is num) ? (data['avg_google'] as num).toDouble() : 0,
      countGoogle: (data['count_google'] is num) ? (data['count_google'] as num).toInt() : 0,
      avgApp: (data['avg_app'] is num) ? (data['avg_app'] as num).toDouble() : 0,
      countApp: (data['count_app'] is num) ? (data['count_app'] as num).toInt() : 0,
      avgCombined: (data['avg_combined'] is num) ? (data['avg_combined'] as num).toDouble() : 0,
      countCombined: (data['count_combined'] is num) ? (data['count_combined'] as num).toInt() : 0,
      updatedAt: ts,
    );
  }

  Map<String, dynamic> toJson() => {
        'avgGoogle': avgGoogle,
        'countGoogle': countGoogle,
        'avgApp': avgApp,
        'countApp': countApp,
        'avgCombined': avgCombined,
        'countCombined': countCombined,
        if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
      };
}
