import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

/// Records immutable audit events via Cloud Functions.
/// The backend appends KMS-signed, hash-chained entries to an append-only collection.
class AuditLogService {
  final FirebaseFunctions _functions;
  AuditLogService({FirebaseFunctions? functions}) : _functions = functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  Future<void> recordRead({required String subjectUid, required String resource, required String resourceType}) async {
    await _record(action: 'read', subjectUid: subjectUid, resource: resource, resourceType: resourceType);
  }

  Future<void> recordChange({required String action, required String subjectUid, required String resource, required String resourceType}) async {
    // action: create | update | delete
    await _record(action: action, subjectUid: subjectUid, resource: resource, resourceType: resourceType);
  }

  Future<void> _record({required String action, required String subjectUid, required String resource, required String resourceType}) async {
    try {
      final callable = _functions.httpsCallable('recordAuditLog');
      await callable.call({
        'action': action,
        'subjectUid': subjectUid,
        'resource': resource,
        'resourceType': resourceType,
      });
    } catch (e) {
      debugPrint('AuditLogService._record error: $e');
      // Swallow errors to avoid disrupting UX; backend triggers will still capture writes.
    }
  }
}
