import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wellspring/supabase/supabase_config.dart';

/// Service for managing user consent to Terms & Conditions and PHI authorization.
/// Handles consent document versions, audit logging, and HIPAA-compliant tracking.
class ConsentService {
  final SupabaseClient _supabase = SupabaseConfig.client;

  /// Get the active consent document by type
  Future<ConsentDocument?> getActiveDocument(String documentType) async {
    try {
      final response = await _supabase
          .from('consent_documents')
          .select()
          .eq('document_type', documentType)
          .eq('is_active', true)
          .order('effective_date', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) return null;
      return ConsentDocument.fromJson(response);
    } catch (e) {
      debugPrint('ConsentService.getActiveDocument error: $e');
      return null;
    }
  }

  /// Record user consent with full audit trail
  Future<void> recordConsent({
    required String userId,
    required String documentId,
    required String documentType,
    required String documentVersion,
    required String consentMethod,
    String? ipAddress,
    String? userAgent,
    Map<String, dynamic>? deviceInfo,
  }) async {
    try {
      // Insert into consent logs
      await _supabase.from('user_consent_logs').insert({
        'user_id': userId,
        'document_id': documentId,
        'document_type': documentType,
        'document_version': documentVersion,
        'action': 'accepted',
        'ip_address': ipAddress,
        'user_agent': userAgent,
        'device_info': deviceInfo ?? {},
        'consent_method': consentMethod,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });

      // Upsert into consent status (creates or updates)
      await _supabase.from('user_consent_status').upsert({
        'user_id': userId,
        'document_type': documentType,
        'document_id': documentId,
        'document_version': documentVersion,
        'is_consented': true,
        'consented_at': DateTime.now().toUtc().toIso8601String(),
        'ip_address': ipAddress,
        'user_agent': userAgent,
        'consent_method': consentMethod,
        'last_updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'user_id,document_type');

      debugPrint(
          'ConsentService: Recorded consent for user $userId, document $documentType v$documentVersion');
    } catch (e) {
      debugPrint('ConsentService.recordConsent error: $e');
      rethrow;
    }
  }

  /// Get user's current consent status for a document type
  Future<UserConsentStatus?> getUserConsentStatus(
      String userId, String documentType) async {
    try {
      final response = await _supabase
          .from('user_consent_status')
          .select()
          .eq('user_id', userId)
          .eq('document_type', documentType)
          .maybeSingle();

      if (response == null) return null;
      return UserConsentStatus.fromJson(response);
    } catch (e) {
      debugPrint('ConsentService.getUserConsentStatus error: $e');
      return null;
    }
  }

  /// Get all consent logs for a user (for audit trail display)
  Future<List<ConsentLog>> getUserConsentLogs(String userId) async {
    try {
      final response = await _supabase
          .from('user_consent_logs')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => ConsentLog.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('ConsentService.getUserConsentLogs error: $e');
      return [];
    }
  }

  /// Check if user needs to accept updated terms
  Future<bool> needsToAcceptUpdatedTerms(String userId) async {
    try {
      final activeDoc = await getActiveDocument('terms_and_conditions');
      if (activeDoc == null) return false;

      final userStatus =
          await getUserConsentStatus(userId, 'terms_and_conditions');
      if (userStatus == null) return true;

      // Check if user's version matches active version
      return userStatus.documentVersion != activeDoc.version;
    } catch (e) {
      debugPrint('ConsentService.needsToAcceptUpdatedTerms error: $e');
      return false;
    }
  }

  /// Revoke consent (user withdraws consent)
  Future<void> revokeConsent({
    required String userId,
    required String documentType,
    String? notes,
  }) async {
    try {
      final currentStatus = await getUserConsentStatus(userId, documentType);
      if (currentStatus == null) return;

      // Log the revocation
      await _supabase.from('user_consent_logs').insert({
        'user_id': userId,
        'document_id': currentStatus.documentId,
        'document_type': documentType,
        'document_version': currentStatus.documentVersion,
        'action': 'revoked',
        'consent_method': 'account_settings',
        'notes': notes,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });

      // Update status
      await _supabase
          .from('user_consent_status')
          .update({
            'is_consented': false,
            'last_updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('user_id', userId)
          .eq('document_type', documentType);

      debugPrint('ConsentService: Revoked consent for user $userId, $documentType');
    } catch (e) {
      debugPrint('ConsentService.revokeConsent error: $e');
      rethrow;
    }
  }
}

/// Consent document model
class ConsentDocument {
  final String id;
  final String documentType;
  final String version;
  final String title;
  final String content;
  final DateTime effectiveDate;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  ConsentDocument({
    required this.id,
    required this.documentType,
    required this.version,
    required this.title,
    required this.content,
    required this.effectiveDate,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ConsentDocument.fromJson(Map<String, dynamic> json) {
    return ConsentDocument(
      id: json['id'] as String,
      documentType: json['document_type'] as String,
      version: json['version'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      effectiveDate: DateTime.parse(json['effective_date'] as String),
      isActive: json['is_active'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'document_type': documentType,
        'version': version,
        'title': title,
        'content': content,
        'effective_date': effectiveDate.toIso8601String(),
        'is_active': isActive,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}

/// User consent status model
class UserConsentStatus {
  final String id;
  final String userId;
  final String documentType;
  final String documentId;
  final String documentVersion;
  final bool isConsented;
  final DateTime consentedAt;
  final String? ipAddress;
  final String? userAgent;
  final String? consentMethod;
  final DateTime lastUpdatedAt;

  UserConsentStatus({
    required this.id,
    required this.userId,
    required this.documentType,
    required this.documentId,
    required this.documentVersion,
    required this.isConsented,
    required this.consentedAt,
    this.ipAddress,
    this.userAgent,
    this.consentMethod,
    required this.lastUpdatedAt,
  });

  factory UserConsentStatus.fromJson(Map<String, dynamic> json) {
    return UserConsentStatus(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      documentType: json['document_type'] as String,
      documentId: json['document_id'] as String,
      documentVersion: json['document_version'] as String,
      isConsented: json['is_consented'] as bool,
      consentedAt: DateTime.parse(json['consented_at'] as String),
      ipAddress: json['ip_address'] as String?,
      userAgent: json['user_agent'] as String?,
      consentMethod: json['consent_method'] as String?,
      lastUpdatedAt: DateTime.parse(json['last_updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'document_type': documentType,
        'document_id': documentId,
        'document_version': documentVersion,
        'is_consented': isConsented,
        'consented_at': consentedAt.toIso8601String(),
        'ip_address': ipAddress,
        'user_agent': userAgent,
        'consent_method': consentMethod,
        'last_updated_at': lastUpdatedAt.toIso8601String(),
      };
}

/// Consent log model
class ConsentLog {
  final String id;
  final String userId;
  final String documentId;
  final String documentType;
  final String documentVersion;
  final String action;
  final String? ipAddress;
  final String? userAgent;
  final Map<String, dynamic> deviceInfo;
  final String? consentMethod;
  final String? notes;
  final DateTime createdAt;

  ConsentLog({
    required this.id,
    required this.userId,
    required this.documentId,
    required this.documentType,
    required this.documentVersion,
    required this.action,
    this.ipAddress,
    this.userAgent,
    required this.deviceInfo,
    this.consentMethod,
    this.notes,
    required this.createdAt,
  });

  factory ConsentLog.fromJson(Map<String, dynamic> json) {
    return ConsentLog(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      documentId: json['document_id'] as String,
      documentType: json['document_type'] as String,
      documentVersion: json['document_version'] as String,
      action: json['action'] as String,
      ipAddress: json['ip_address'] as String?,
      userAgent: json['user_agent'] as String?,
      deviceInfo: (json['device_info'] as Map<String, dynamic>?) ?? {},
      consentMethod: json['consent_method'] as String?,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'document_id': documentId,
        'document_type': documentType,
        'document_version': documentVersion,
        'action': action,
        'ip_address': ipAddress,
        'user_agent': userAgent,
        'device_info': deviceInfo,
        'consent_method': consentMethod,
        'notes': notes,
        'created_at': createdAt.toIso8601String(),
      };
}
