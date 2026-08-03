import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

class RecordEncryptionService {
  final FirebaseFunctions _functions;
  RecordEncryptionService({FirebaseFunctions? functions}) : _functions = functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  /// Returns a map suitable to be saved under `notesEnc` on the tracker entry doc.
  Future<Map<String, dynamic>> encryptTrackerEntryNotes({required String userId, required String entryId, required String notes}) async {
    try {
      final callable = _functions.httpsCallable('encryptTrackerEntryNotes');
      final result = await callable.call({'userId': userId, 'entryId': entryId, 'notes': notes});
      final data = (result.data as Map).cast<String, dynamic>();
      final notesEnc = (data['notesEnc'] as Map).cast<String, dynamic>();
      return notesEnc;
    } catch (e) {
      debugPrint('RecordEncryptionService.encryptTrackerEntryNotes error: $e');
      rethrow;
    }
  }

  Future<String?> decryptTrackerEntryNotes({required String userId, required String entryId}) async {
    try {
      final callable = _functions.httpsCallable('decryptTrackerEntryNotes');
      final result = await callable.call({'userId': userId, 'entryId': entryId});
      final data = (result.data as Map).cast<String, dynamic>();
      final notes = data['notes'];
      return notes is String ? notes : null;
    } catch (e) {
      debugPrint('RecordEncryptionService.decryptTrackerEntryNotes error: $e');
      rethrow;
    }
  }
}
