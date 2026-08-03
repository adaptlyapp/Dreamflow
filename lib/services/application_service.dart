import 'package:flutter/foundation.dart';
import 'package:wellspring/supabase/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Email recipient for incoming applications.
/// Configure this via --dart-define=APPLICATION_NOTIFY_EMAIL=you@example.com when building.
const kApplicationNotifyEmail = String.fromEnvironment('APPLICATION_NOTIFY_EMAIL');

/// Public base URL of your app for approval links (e.g., https://yourapp.web.app)
/// Configure via --dart-define=APP_BASE_URL=https://yourapp.web.app
const kAppBaseUrl = String.fromEnvironment('APP_BASE_URL');

class ApplicationService {
  static const _applicationsTable = 'resource_applications';
  
  final _supabase = SupabaseConfig.client;

  Future<String> submitApplication({
    required String name,
    required String email,
    required String phone,
    required String notes,
  }) async {
    final user = SupabaseConfig.auth.currentUser;
    if (user == null) {
      throw Exception('Not authenticated');
    }

    final response = await _supabase
        .from(_applicationsTable)
        .insert({
          'name': name.trim(),
          'email': email.trim(),
          'phone': phone.trim(),
          'notes': notes.trim(),
          'status': 'pending',
          'user_id': user.id,
          'created_at': DateTime.now().toIso8601String(),
        })
        .select()
        .single();
    
    final appId = response['id'].toString();

    // Try to send notification email to admin via edge function
    try {
      if (kApplicationNotifyEmail.isNotEmpty) {
        final approveUrl = _buildActionUrl(appId, 'approve');
        final rejectUrl = _buildActionUrl(appId, 'reject');

        await _supabase.functions.invoke('send-email', body: {
          'to': [kApplicationNotifyEmail],
          'subject': 'New Application: $name',
          'text': 'A new resource application was submitted.\n\n'
              'Name: $name\nEmail: $email\nPhone: $phone\nNotes: $notes\n\n'
              'Approve: $approveUrl\nReject: $rejectUrl\n\nID: $appId',
          'html': '<h3>New Resource Application</h3>'
              '<p><b>Name:</b> ${_escapeHtml(name)}<br>'
              '<b>Email:</b> ${_escapeHtml(email)}<br>'
              '<b>Phone:</b> ${_escapeHtml(phone)}<br>'
              '<b>Notes:</b> ${_escapeHtml(notes)}</p>'
              '<p><a href="$approveUrl">Approve</a> | <a href="$rejectUrl">Reject</a></p>'
              '<p>ID: $appId</p>',
          'replyTo': email.trim(),
        });
      } else {
        debugPrint('APPLICATION_NOTIFY_EMAIL not set; skipping admin email.');
      }
    } catch (e) {
      debugPrint('Failed to send notification email for application: $e');
    }

    return appId;
  }

  /// Sends a support/feedback email to the configured admin address via the
  /// Firebase Trigger Email extension by creating a document in the `mail` collection.
  ///
  /// If [kApplicationNotifyEmail] is not configured, this will log and no-op.
  Future<void> sendSupportEmail({
    required String subject,
    required String text,
    String? html,
  }) async {
    try {
      if (kApplicationNotifyEmail.isEmpty) {
        debugPrint('APPLICATION_NOTIFY_EMAIL not set; cannot send support email.');
        return;
      }
      final user = SupabaseConfig.auth.currentUser;
      final data = <String, dynamic>{
        'to': [kApplicationNotifyEmail],
        'subject': subject,
        'text': text,
        if (html != null) 'html': html,
      };
      if (user?.email != null && user!.email!.isNotEmpty) {
        data['replyTo'] = user.email;
      }
      await _supabase.functions.invoke('send-email', body: data);
    } catch (e) {
      debugPrint('Failed to enqueue support email: $e');
      rethrow;
    }
  }

  /// Sends product feedback to the dedicated feedback inbox via the
  /// Firebase Trigger Email extension.
  ///
  /// This intentionally bypasses APPLICATION_NOTIFY_EMAIL and sends to
  /// dpaine170014@gmail.com as requested.
  Future<void> sendFeedbackEmail({
    required String subject,
    required String text,
    String? html,
  }) async {
    try {
      final user = SupabaseConfig.auth.currentUser;
      final data = <String, dynamic>{
        'to': ['dpaine170014@gmail.com'],
        'subject': subject,
        'text': text,
        if (html != null) 'html': html,
      };
      if (user?.email != null && user!.email!.isNotEmpty) {
        data['replyTo'] = user.email;
      }
      await _supabase.functions.invoke('send-email', body: data);
    } catch (e) {
      debugPrint('Failed to enqueue feedback email: $e');
      rethrow;
    }
  }

  Future<void> setStatus({required String id, required String status}) async {
    await _supabase
        .from(_applicationsTable)
        .update({
          'status': status,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', id);
  }

  Future<Map<String, dynamic>?> getApplication(String id) async {
    final response = await _supabase
        .from(_applicationsTable)
        .select()
        .eq('id', id)
        .maybeSingle();
    return response;
  }

  Future<void> emailApplicant({required String toEmail, required String subject, required String text, String? html}) async {
    try {
      await _supabase.functions.invoke('send-email', body: {
        'to': [toEmail],
        'subject': subject,
        'text': text,
        if (html != null) 'html': html,
      });
    } catch (e) {
      debugPrint('Failed to send applicant email: $e');
    }
  }

  String _buildActionUrl(String id, String action) {
    final base = kAppBaseUrl.trim();
    final path = '/admin/approval?id=$id&action=$action';
    if (base.isEmpty) return path; // relative path if base unknown
    return Uri.parse(base).replace(path: path, queryParameters: null).toString();
  }

  String _escapeHtml(String input) => input
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#039;');
}
