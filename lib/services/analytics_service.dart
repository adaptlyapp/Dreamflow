import 'package:flutter/foundation.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:wellspring/supabase/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Centralized Analytics wrapper.
/// - Initializes listeners for Supabase auth user changes to set userId.
/// - Provides safe helpers to log screen views and custom events.
class AnalyticsService {
  AnalyticsService._();
  static final AnalyticsService instance = AnalyticsService._();

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  Future<void> init() async {
    // Attach Supabase auth listener so we can associate analytics with the current user
    try {
      SupabaseConfig.auth.onAuthStateChange.listen(
        (data) async {
          final user = data.session?.user;
          try {
            await _analytics.setUserId(id: user?.id);
          } catch (e) {
            debugPrint('AnalyticsService.setUserId error: $e');
          }
        },
        onError: (error) {
          debugPrint('AnalyticsService auth listener error: $error');
        },
        cancelOnError: false,
      );
    } catch (e) {
      debugPrint('AnalyticsService.init error: $e');
    }
  }

  Future<void> logScreenView(String screenName, {String? screenClass}) async {
    try {
      await _analytics.logScreenView(
        screenName: screenName,
        screenClass: screenClass ?? screenName,
      );
    } catch (e) {
      debugPrint('AnalyticsService.logScreenView("$screenName") error: $e');
    }
  }

  Future<void> logEvent(String name, {Map<String, Object> parameters = const {}}) async {
    try {
      await _analytics.logEvent(name: name, parameters: parameters);
    } catch (e) {
      debugPrint('AnalyticsService.logEvent("$name") error: $e');
    }
  }
}
