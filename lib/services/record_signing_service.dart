import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

class RecordSigningService {
  final FirebaseFunctions _functions;
  RecordSigningService({FirebaseFunctions? functions}) : _functions = functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  Future<Map<String, dynamic>> signTrackerEntry({required String userId, required String entryId}) async {
    try {
      final callable = _functions.httpsCallable('signTrackerEntry');
      final result = await callable.call({'userId': userId, 'entryId': entryId});
      final data = (result.data as Map).cast<String, dynamic>();
      return data;
    } catch (e) {
      debugPrint('RecordSigningService.signTrackerEntry error: $e');
      rethrow;
    }
  }
}
